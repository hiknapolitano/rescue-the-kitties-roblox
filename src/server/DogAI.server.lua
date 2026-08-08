local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local SoundManager = require(Shared:WaitForChild("SoundManager"))

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local playerCaughtRemote = remotesFolder:WaitForChild("PlayerCaught")
local playSoundRemote = remotesFolder:WaitForChild("PlaySoundClient")

local dogs = {}
local cachedSafeZoneParts = {}
local cachedObstacles = {}

local function initCaches()
    local safeZoneFolder = workspace:WaitForChild("Base", 10)
    if safeZoneFolder then
        for _, part in ipairs(safeZoneFolder:GetDescendants()) do
            if part:IsA("BasePart") then
                table.insert(cachedSafeZoneParts, part)
            end
        end
    end
    
    local mazeElements = workspace:WaitForChild("MazeElements", 10)
    if mazeElements then
        for _, obj in ipairs(mazeElements:GetChildren()) do
            if obj.Name == "Tree" or obj.Name == "Shop" or string.find(obj.Name, "Wall") or obj.Name == "FireTree" or obj.Name == "LavaObby" or obj.Name == "JustLava" or obj.Name == "SpikeObby" or obj.Name == "SpikeTile" then
                table.insert(cachedObstacles, obj)
            end
            if obj.Name == "SafeZone2" then
                table.insert(cachedSafeZoneParts, obj)
            end
        end
    end
end

-- Initialize caches at startup
task.spawn(function()
    if not workspace:GetAttribute("MazeGenerated") then
        workspace:GetAttributeChangedSignal("MazeGenerated"):Wait()
    end
    task.wait(0.5) -- Give a small window for instances to fully settle
    initCaches()
end)

local function createDogModel(position, dogName)
    dogName = dogName or "Dog"
    local dogModel = Instance.new("Model")
    dogModel.Name = "ChaserDog"
    
    local rootPart = Instance.new("Part")
    rootPart.Name = "HumanoidRootPart"
    rootPart.Size = Vector3.new(2, 2, 2)
    rootPart.Position = position + Vector3.new(0, 2, 0)
    rootPart.Transparency = 1 -- Make placeholder invisible
    rootPart.CanCollide = true
    rootPart.CollisionGroup = "Dogs"
    rootPart.CustomPhysicalProperties = PhysicalProperties.new(1, 0, 0, 1, 1)
    rootPart.Parent = dogModel
    
    dogModel.PrimaryPart = rootPart
    
    local humanoid = Instance.new("Humanoid")
    humanoid.RigType = Enum.HumanoidRigType.R6
    humanoid.MaxSlopeAngle = 0
    humanoid.WalkSpeed = Constants.DogSpeed
    humanoid.Parent = dogModel
    
    local redLight = Instance.new("PointLight")
    redLight.Name = "Aura"
    redLight.Color = Constants.DogLightColor
    redLight.Brightness = Constants.DogLightBrightness
    redLight.Range = Constants.DogLightRange
    redLight.Shadows = false -- Disable shadows so the dog's own geometry doesn't block its aura
    redLight.Parent = rootPart
    
    -- Clone user's custom Dog model
    local template = ReplicatedStorage:FindFirstChild("Animals") and ReplicatedStorage.Animals:FindFirstChild(dogName)
    if template then
        local customDog = template:Clone()
        customDog.Name = "Dog"
        
        local bboxCFrame, bboxSize
        if customDog:IsA("Model") then
            bboxCFrame, bboxSize = customDog:GetBoundingBox()
        else
            bboxCFrame = customDog.CFrame
            bboxSize = customDog.Size
        end
        local pivot = customDog:GetPivot()
        local pivotToBottom = pivot.Position.Y - (bboxCFrame.Position.Y - bboxSize.Y / 2)
        
        -- Resize HumanoidRootPart to match the exact visual size of the dog, so that
        -- its bounding volume (including the head) collides with walls!
        rootPart.Size = bboxSize
        
        -- Set a small HipHeight to keep the rootPart collider suspended 0.15 studs above the floor.
        -- This prevents floor scraping/collisions, avoiding physics jitter, bounces, or random rotation.
        local hipHeight = 0.15
        humanoid.HipHeight = hipHeight
        
        -- Position the visual paws touching the ground exactly (offset visual center down by hipHeight)
        local yOffset = (pivot.Position.Y - bboxCFrame.Position.Y) - hipHeight
        
        -- Position it perfectly at the root part with the offset
        if customDog:IsA("Model") then
            customDog:PivotTo(rootPart.CFrame * CFrame.new(0, yOffset, 0))
        else
            customDog.CFrame = rootPart.CFrame * CFrame.new(0, yOffset, 0)
        end
        
        local dogVisualRoot = customDog:FindFirstChild("body", true) or customDog:FindFirstChild("Torso", true) or customDog:FindFirstChild("Body", true) or customDog.PrimaryPart or customDog:FindFirstChildWhichIsA("BasePart", true)
        
        local baseParts = {}
        for _, child in ipairs(customDog:GetDescendants()) do
            if child:IsA("BasePart") then
                child.Anchored = false 
                child.CanCollide = false
                child.Massless = true
                child.CollisionGroup = "Dogs"
                if child ~= dogVisualRoot then
                    table.insert(baseParts, child)
                end
            elseif child:IsA("Humanoid") then
                child.PlatformStand = true
            elseif child:IsA("Script") or child:IsA("LocalScript") then
                child.Disabled = true
            elseif child:IsA("JointInstance") or child:IsA("WeldConstraint") then
                child:Destroy()
            end
        end

        local quadrants = {
            FrontLeft = {}, FrontRight = {}, BackLeft = {}, BackRight = {}
        }
        
        local function getBoneLevel(name)
            if string.find(name, "shoulder") or string.find(name, "hind") or string.find(name, "hip") then return 1 end
            if string.find(name, "leg") or string.find(name, "thigh") or string.find(name, "arm") or string.find(name, "knee") or string.find(name, "calf") or string.find(name, "shin") then return 2 end
            if string.find(name, "paw") or string.find(name, "foot") or string.find(name, "hand") then return 3 end
            if string.find(name, "claw") or string.find(name, "toe") then return 4 end
            return 99
        end
        
        local function getEffectiveName(child)
            local name = string.lower(child.Name)
            if getBoneLevel(name) == 99 and child.Parent and child.Parent ~= customDog and child.Parent.Name ~= "Dog" and child.Parent ~= dogVisualRoot then
                name = name .. " " .. string.lower(child.Parent.Name)
            end
            return name
        end
        local frontPos, backPos, leftPos, rightPos = Vector3.new(), Vector3.new(), Vector3.new(), Vector3.new()
        local fCount, bCount, lCount, rCount = 0, 0, 0, 0
        for _, child in ipairs(baseParts) do
            local n = getEffectiveName(child)
            if string.find(n, "shoulder") or (string.find(n, "paw") and not string.find(n, "paw2")) then
                frontPos = frontPos + child.Position; fCount = fCount + 1
            elseif string.find(n, "hind") or string.find(n, "paw2") then
                backPos = backPos + child.Position; bCount = bCount + 1
            end
            if string.find(n, "left") then
                leftPos = leftPos + child.Position; lCount = lCount + 1
            elseif string.find(n, "right") then
                rightPos = rightPos + child.Position; rCount = rCount + 1
            end
        end
        local avgFront = fCount > 0 and (frontPos / fCount) or dogVisualRoot.Position
        local avgBack = bCount > 0 and (backPos / bCount) or dogVisualRoot.Position
        local avgLeft = lCount > 0 and (leftPos / lCount) or dogVisualRoot.Position
        local avgRight = rCount > 0 and (rightPos / rCount) or dogVisualRoot.Position
        
        -- Categorize leg parts into quadrants based on exact names or geometric proximity
        for _, child in ipairs(baseParts) do
            local name = getEffectiveName(child)
            local level = getBoneLevel(name)
            
            if level <= 4 then
                local isFront = nil
                -- Only hardcode unambiguous extreme ends. Let middle segments (leg/thigh) fall back to physical 3D position!
                if string.find(name, "shoulder") or (string.find(name, "paw") and not string.find(name, "paw2")) then
                    isFront = true
                end
                if string.find(name, "hind") or string.find(name, "paw2") then
                    isFront = false
                end
                
                if isFront == nil then
                    if fCount > 0 and bCount > 0 then
                        isFront = (child.Position - avgFront).Magnitude < (child.Position - avgBack).Magnitude
                    else
                        local relPos = dogVisualRoot.CFrame:Inverse() * child.CFrame.Position
                        isFront = relPos.Z < 0
                    end
                end
                
                local isLeft = string.find(name, "left") ~= nil
                local isRight = string.find(name, "right") ~= nil
                
                if not isLeft and not isRight then
                    if lCount > 0 and rCount > 0 then
                        isLeft = (child.Position - avgLeft).Magnitude < (child.Position - avgRight).Magnitude
                        isRight = not isLeft
                    else
                        local relPos = dogVisualRoot.CFrame:Inverse() * child.CFrame.Position
                        if relPos.X < -0.1 then isLeft = true
                        elseif relPos.X > 0.1 then isRight = true 
                        else isLeft = true end
                    end
                end
                
                local qName = (isFront and "Front" or "Back") .. (isLeft and "Left" or "Right")
                table.insert(quadrants[qName], child)
            end
        end
        
        local riggedParts = {}
        
        -- Build hierarchical limbs using proximity search (Torso -> Level 1 -> Level 2 -> Level 3 -> Claws)
        for qName, parts in pairs(quadrants) do
            for _, child in ipairs(parts) do
                local level = getBoneLevel(getEffectiveName(child))
                local parentPart = dogVisualRoot
                
                if level == 2 then
                    -- Find closest Level 1 (Shoulder)
                    local closest = nil; local minDst = math.huge
                    for _, cand in ipairs(parts) do
                        if getBoneLevel(getEffectiveName(cand)) == 1 then
                            local dst = (child.Position - cand.Position).Magnitude
                            if dst < minDst then minDst = dst; closest = cand end
                        end
                    end
                    if closest then 
                        parentPart = closest 
                    else
                        -- If there is NO Level 1 in this quadrant, this Level 2 MUST act as Level 1 to swing from torso!
                        level = 1
                    end
                    
                elseif level == 3 then
                    -- Find closest Level 2 (Leg)
                    local closest = nil; local minDst = math.huge
                    for _, cand in ipairs(parts) do
                        if getBoneLevel(getEffectiveName(cand)) == 2 then
                            local dst = (child.Position - cand.Position).Magnitude
                            if dst < minDst then minDst = dst; closest = cand end
                        end
                    end
                    if closest then 
                        parentPart = closest 
                    else
                        -- Fallback to Level 1
                        for _, cand in ipairs(parts) do
                            if getBoneLevel(getEffectiveName(cand)) == 1 then
                                local dst = (child.Position - cand.Position).Magnitude
                                if dst < minDst then minDst = dst; closest = cand end
                            end
                        end
                        if closest then 
                            parentPart = closest 
                        else
                            -- No Level 1 or 2! This paw is the entire leg!
                            level = 1
                        end
                    end
                    
                elseif level == 4 then
                    -- Find closest Level 3 (Paw)
                    local closest = nil; local minDst = math.huge
                    for _, cand in ipairs(parts) do
                        if getBoneLevel(getEffectiveName(cand)) == 3 then
                            local dst = (child.Position - cand.Position).Magnitude
                            if dst < minDst then minDst = dst; closest = cand end
                        end
                    end
                    if closest then parentPart = closest end
                end
                
                local motor = Instance.new("Motor6D")
                motor.Name = child.Name .. "_Motor"
                motor.Part0 = parentPart
                motor.Part1 = child
                
                local pivotY = child.Size.Y / 2
                local pivotOffset = CFrame.new(0, pivotY, 0)
                
                motor.C0 = parentPart.CFrame:Inverse() * (child.CFrame * pivotOffset)
                motor.C1 = pivotOffset
                motor.Parent = parentPart
                
                motor:SetAttribute("BoneLevel", level)
                motor:SetAttribute("Quadrant", qName)
                riggedParts[child] = true
            end
        end
        
        -- Rig any remaining parts that were missed (fallback)
        for _, child in ipairs(baseParts) do
            if not riggedParts[child] then
                local name = getEffectiveName(child)
                local parentPart = dogVisualRoot
                
                -- Explicitly exempt torso-bound parts. Any other unclassified part attaches to the physically closest bone!
                if not (string.find(name, "head") or string.find(name, "ear") or string.find(name, "tail") or string.find(name, "snout") or string.find(name, "nose") or string.find(name, "eye") or string.find(name, "body") or string.find(name, "neck") or string.find(name, "forehead")) then
                    local minDst = math.huge
                    for b, _ in pairs(riggedParts) do
                        local dst = (child.Position - b.Position).Magnitude
                        if dst < minDst then
                            minDst = dst
                            parentPart = b
                        end
                    end
                end
                
                local motor = Instance.new("Motor6D")
                motor.Name = child.Name .. "_Motor"
                motor.Part0 = parentPart
                motor.Part1 = child
                
                local pivotY = child.Size.Y / 2
                if string.find(name, "ear") then
                    pivotY = -child.Size.Y / 2
                elseif string.find(name, "tail") then
                    pivotY = -child.Size.Z / 2
                elseif string.find(name, "head") or string.find(name, "snout") then
                    pivotY = -child.Size.Y / 2
                end
                
                local pivotOffset = CFrame.new(0, pivotY, 0)
                motor.C0 = parentPart.CFrame:Inverse() * (child.CFrame * pivotOffset)
                motor.C1 = pivotOffset
                motor.Parent = parentPart
                
                riggedParts[child] = true
            end
        end
        
        -- Attach the visual root to the actual physical HumanoidRootPart using a Motor6D
        local rootMotor = nil
        if dogVisualRoot then
            rootMotor = Instance.new("Motor6D")
            rootMotor.Name = "VisualRootMotor"
            rootMotor.Part0 = rootPart
            rootMotor.Part1 = dogVisualRoot
            -- Offset C0 by yOffset so the pivot aligns exactly with the custom offset
            rootMotor.C0 = CFrame.new(0, yOffset, 0)
            local customPivot = customDog:GetPivot()
            rootMotor.C1 = dogVisualRoot.CFrame:ToObjectSpace(customPivot)
            rootMotor.Parent = rootPart
        end
        
        customDog.Parent = dogModel
        
        -- Animation loop moved to DogAnimator.client.lua
        
        -- Separation Steering (Avoid Trees and other Dogs)
        task.spawn(function()
            local RunService = game:GetService("RunService")
            while dogModel and dogModel.Parent and rootPart and rootPart.Parent do
                local separationVector = Vector3.new()
                
                -- Avoid other dogs using cached array
                for _, otherDog in ipairs(dogs) do
                    if otherDog ~= dogModel and otherDog.Parent then
                        local otherRoot = otherDog:FindFirstChild("HumanoidRootPart")
                        if otherRoot then
                            local dist = (rootPart.Position - otherRoot.Position).Magnitude
                            if dist < 6 and dist > 0.1 then
                                separationVector = separationVector + (rootPart.Position - otherRoot.Position).Unit * (6 - dist)
                            end
                        end
                    end
                end
                
                -- Avoid cached static obstacles (Trees, Shops, Walls, FireTrees, LavaObby)
                -- We only check objects within a rough distance first to save math!
                local flatRoot = Vector3.new(rootPart.Position.X, 0, rootPart.Position.Z)
                for _, obj in ipairs(cachedObstacles) do
                    local pivot = obj:GetPivot()
                    local flatObj = Vector3.new(pivot.Position.X, 0, pivot.Position.Z)
                    
                    local avoidDist = 5
                    local roughCheck = 10
                    local pushStrength = 1
                    
                    if obj.Name == "Shop" then 
                        avoidDist = 8 
                    elseif string.find(obj.Name, "Wall") then 
                        avoidDist = 3 
                    elseif obj.Name == "FireTree" then
                        avoidDist = 8
                        pushStrength = 5 -- Extreme push so they don't touch it at all
                    elseif obj.Name == "LavaObby" or obj.Name == "JustLava" or obj.Name == "SpikeObby" or obj.Name == "SpikeTile" then
                        local size = Vector3.new(10, 10, 10)
                        if obj:IsA("Model") then
                            local _, s = obj:GetBoundingBox()
                            size = s
                        elseif obj:IsA("BasePart") then
                            size = obj.Size
                        end
                        avoidDist = math.max(size.X, size.Z) / 2 + 10
                        roughCheck = avoidDist + 8
                        pushStrength = 50 -- Extreme push so they stay away
                    end
                    
                    -- Quick rough magnitude check (cheaper than precise magnitude)
                    if math.abs(flatRoot.X - flatObj.X) < roughCheck and math.abs(flatRoot.Z - flatObj.Z) < roughCheck then
                        local dist = (flatRoot - flatObj).Magnitude
                        
                        if dist < avoidDist and dist > 0.1 then
                            separationVector = separationVector + (flatRoot - flatObj).Unit * (avoidDist - dist) * pushStrength
                        end
                    end
                end
                
                if separationVector.Magnitude > 0.01 then
                    separationVector = Vector3.new(separationVector.X, 0, separationVector.Z)
                    local moveDir = separationVector * 0.15
                    
                    -- Raycast to make sure we don't push the dog into a wall
                    local pushRay = RaycastParams.new()
                    pushRay.FilterDescendantsInstances = {dogModel}
                    pushRay.FilterType = Enum.RaycastFilterType.Exclude
                    
                    -- Only apply separation if the path is clear
                    local hit = workspace:Raycast(rootPart.Position, moveDir.Unit * (moveDir.Magnitude + 2), pushRay)
                    if not hit then
                        rootPart.CFrame = rootPart.CFrame + moveDir
                    end
                end
                
                RunService.Heartbeat:Wait()
            end
        end)
    end
    
    -- Disable CastShadow on all dog parts for rendering performance
    for _, part in ipairs(dogModel:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CastShadow = false
        end
    end
    
    dogModel.Parent = workspace
    return dogModel
end

local function isMaleAvatar(character)
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return true end
    local desc = humanoid:GetAppliedDescription()
    if not desc then return true end
    
    local femaleTorsos = {
        [86499666] = true, -- Woman Torso (R15)
        [48474356] = true, -- ROBLOX Girl Torso (R6)
        [146522365] = true, -- Lindsey Torso
        [146524317] = true, -- Cindy Torso
        [86499905] = true, -- Summer Torso
    }
    if femaleTorsos[desc.Torso] then return false end
    
    return true
end

local function isPlayerSafe(character)
    local humanoid = character:FindFirstChild("Humanoid")
    if humanoid and humanoid:GetState() == Enum.HumanoidStateType.Climbing then
        return true
    end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return true end
    
    -- Check if they are touching any climbable Truss or TrussPart
    local isTouchingClimbable = false
    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    overlapParams.FilterDescendantsInstances = {character}
    
    local hrpOverlaps = workspace:GetPartsInPart(hrp, overlapParams)
    for _, part in ipairs(hrpOverlaps) do
        if part:IsA("TrussPart") or part.Name == "Truss" then
            isTouchingClimbable = true
            break
        end
    end
    
    if not isTouchingClimbable then
        for _, limb in ipairs(character:GetChildren()) do
            if limb:IsA("BasePart") and limb.Name ~= "HumanoidRootPart" then
                local limbOverlaps = workspace:GetPartsInPart(limb, overlapParams)
                for _, part in ipairs(limbOverlaps) do
                    if part:IsA("TrussPart") or part.Name == "Truss" then
                        isTouchingClimbable = true
                        break
                    end
                end
            end
            if isTouchingClimbable then break end
        end
    end
    
    if isTouchingClimbable then
        return true
    end
    
    -- Also keep the height check just in case they are standing on the platform at the top
    -- Trees are tall, so being above ~12 studs is enough to be safe
    if hrp.Position.Y > (Constants.WallHeight * 0.3) then
        return true
    end
    
    -- Check if they are in the Safe Zone
    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Include
    overlapParams.FilterDescendantsInstances = cachedSafeZoneParts
    
    local partsInBox = workspace:GetPartBoundsInBox(hrp.CFrame, Vector3.new(4, 10, 4), overlapParams)
    if #partsInBox > 0 then
        return true
    end
    
    -- Check if they are near a Hazard (Lava, Spikes) so the dog stays away
    local mazeElements = workspace:FindFirstChild("MazeElements")
    if mazeElements then
        local hazardOverlap = OverlapParams.new()
        hazardOverlap.FilterType = Enum.RaycastFilterType.Include
        local hazards = {}
        for _, child in ipairs(mazeElements:GetChildren()) do
            if child.Name == "LavaObby" or child.Name == "JustLava" or child.Name == "SpikeObby" or child.Name == "SpikeTile" then
                table.insert(hazards, child)
            end
        end
        if #hazards > 0 then
            hazardOverlap.FilterDescendantsInstances = hazards
            local nearHazards = workspace:GetPartBoundsInBox(hrp.CFrame, Vector3.new(15, 15, 15), hazardOverlap)
            if #nearHazards > 0 then
                return true -- Player is near a hazard, so they are "safe" from dogs (dogs avoid)
            end
        end
    end
    
    return false
end

local function getNearestVisiblePlayer(dogModel)
    local dogPosition = dogModel.PrimaryPart.Position
    local nearestDist = math.huge
    local nearestPlayer = nil
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {dogModel}
    raycastParams.CollisionGroup = "Dogs"
    
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") then
            if char.Humanoid.Health > 0 and not isPlayerSafe(char) and not char:GetAttribute("Immune") and not char:GetAttribute("Invisible") then
                local targetPos = char.HumanoidRootPart.Position
                local dist = (targetPos - dogPosition).Magnitude
                
                local maxRange = Constants.DogChasingRange
                if player:GetAttribute("IsSprinting") then
                    maxRange = maxRange * 1.3
                end
                
                if workspace:GetAttribute("TrollEffectActive") then
                    maxRange = maxRange * 10
                end
                
                if dist <= maxRange and dist < nearestDist then
                    local direction = (targetPos - dogPosition)
                    local result = workspace:Raycast(dogPosition, direction, raycastParams)
                    
                    local hasLineOfSight = not result or result.Instance:IsDescendantOf(char)
                    
                    if hasLineOfSight or workspace:GetAttribute("TrollEffectActive") then
                        nearestDist = dist
                        nearestPlayer = char
                    end
                end
            end
        end
    end
    
    return nearestPlayer
end

local function getNearestVisibleBone(dogPosition)
    local nearestDist = Constants.DogChasingRange
    local nearestBone = nil
    
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj.Name == "ThrownBone" and obj:IsA("BasePart") then
            local dist = (obj.Position - dogPosition).Magnitude
            if dist < nearestDist then
                nearestDist = dist
                nearestBone = obj
            end
        end
    end
    
    return nearestBone
end

local function setupDogAI(dogModel)
    local pathParams = {
        AgentRadius = 4.5,   -- Increased buffer keeps dogs from hugging corner walls
        AgentHeight = 4,
        AgentCanJump = false,
        WaypointSpacing = 2   -- Tighter spacing prevents corner-cutting
    }
    local path = PathfindingService:CreatePath(pathParams)
    local humanoid = dogModel:WaitForChild("Humanoid")
    local rootPart = dogModel:WaitForChild("HumanoidRootPart")
    dogModel:SetAttribute("PatrolCenter", rootPart.Position)
    
    local isChasing = false
    local chaseSound = nil
    local wanderRoutine = nil
    
    local isSearching = false
    local searchTimer = 0
    local lastSeenPosition = nil
    local searchWanderPoint = nil
    
    local footstepSound = SoundManager.playSound(Constants.Sounds.DogFootsteps, rootPart, true, 80)
    if footstepSound then
        footstepSound.Volume = 0
    end
    
    local function stopChasingSound()
        if chaseSound then
            SoundManager.stopSound(chaseSound)
            chaseSound = nil
        end
    end
    
    local function onDogTouched(hit)
        if hit.Parent:FindFirstChild("Humanoid") and Players:GetPlayerFromCharacter(hit.Parent) then
            local char = hit.Parent
            
            -- Ensure dog is not biting feet from way below (e.g. player in tree)
            local charHrp = char:FindFirstChild("HumanoidRootPart")
            if charHrp and (charHrp.Position.Y - rootPart.Position.Y) > 5 then
                return
            end
            
            if not isPlayerSafe(char) and not char:GetAttribute("Immune") and not char:GetAttribute("Invisible") then
                if char:GetAttribute("HasShield") then
                    -- Break shield — play sound on client only
                    playSoundRemote:FireClient(Players:GetPlayerFromCharacter(char), "ShieldBreak")
                    char:SetAttribute("HasShield", nil)
                    local ff = char:FindFirstChild("ShieldFF")
                    if ff then ff:Destroy() end
                    
                    local shieldTool = char:FindFirstChild("Shield")
                    if shieldTool and shieldTool:IsA("Tool") then
                        shieldTool:Destroy()
                    end
                    
                    -- Player immunity for 5 seconds
                    char:SetAttribute("Immune", true)
                    task.delay(5, function()
                        if char then char:SetAttribute("Immune", nil) end
                    end)
                else
                    -- Deal Damage Instead of Instant Death
                    local p = Players:GetPlayerFromCharacter(char)
                    if not p then return end
                    
                    local currentHP = p:GetAttribute("HP") or Constants.MaximumHP
                    
                    local damage = Constants.DogDamage
                    if workspace:GetAttribute("TrollEffectActive") then
                        damage = damage * 1.3
                    end
                    
                    local newHP = math.max(0, currentHP - damage)
                    p:SetAttribute("HP", newHP)
                    
                    if newHP > 0 then
                        -- Player survives, give short immunity
                        char:SetAttribute("Immune", true)
                        local ff = Instance.new("ForceField")
                        ff.Parent = char
                        
                        -- Play damage sounds
                        local damageSoundName = "Damage"
                        local pitchOverride = nil
                        if isMaleAvatar(char) then
                            pitchOverride = Constants.MaleDamageSoundPitch
                        end
                        playSoundRemote:FireClient(p, damageSoundName, pitchOverride)
                        playSoundRemote:FireClient(p, "PlayerDeathImpact")
                        
                        -- Flash red effect could go here in the future
                        task.delay(4, function()
                            if char then char:SetAttribute("Immune", nil) end
                            if ff then ff:Destroy() end
                        end)
                    else
                        -- Intercept Death
                        local hrp = char:FindFirstChild("HumanoidRootPart")
                        if hrp then hrp.Anchored = true end
                        char:SetAttribute("Immune", true) -- Prevent multiple death triggers
                        char:SetAttribute("Invisible", true) -- Dogs ignore them
                        
                        p:SetAttribute("GameLost", true)
                        
                        -- Make character invisible
                        for _, part in ipairs(char:GetDescendants()) do
                            if part:IsA("BasePart") or part:IsA("Decal") or part:IsA("Texture") then
                                part.Transparency = 1
                            end
                        end
                        
                        playSoundRemote:FireClient(p, "PlayerDeathImpact")
                        playSoundRemote:FireClient(p, "GameOver")
                        
                        playerCaughtRemote:FireClient(p)
                    end
                end
            end
        end
    end
    
    -- Connect touch event to ALL parts of the dog so the custom model's head/tail can kill the player
    for _, child in ipairs(dogModel:GetDescendants()) do
        if child:IsA("BasePart") then
            child.Touched:Connect(onDogTouched)
        end
    end
    
    local function stopWandering()
        if wanderRoutine then
            task.cancel(wanderRoutine)
            wanderRoutine = nil
        end
    end
    
    -- Cache raycast params once instead of recreating every call
    local wanderRayParams = RaycastParams.new()
    wanderRayParams.FilterType = Enum.RaycastFilterType.Exclude
    wanderRayParams.FilterDescendantsInstances = {dogModel}
    
    local function getValidWanderPoint()
        local patrolCenter = dogModel:GetAttribute("PatrolCenter") or rootPart.Position
        local patrolRadius = Constants.DogPatrolRadius or 75
        
        local mazeElements = workspace:FindFirstChild("MazeElements")
        local floor = mazeElements and mazeElements:FindFirstChild("Floor")
        if not floor then return patrolCenter + Vector3.new(math.random(-20, 20), 0, math.random(-20, 20)) end
        
        -- Pick points biased toward a moderate range from current position for natural roaming
        for i = 1, 20 do
            local angle = math.random() * math.pi * 2
            local distance = 10 + math.random() * (patrolRadius - 10)
            local testX = patrolCenter.X + math.cos(angle) * distance
            local testZ = patrolCenter.Z + math.sin(angle) * distance
            
            -- Ensure testX and testZ are inside the floor boundaries
            local halfX = floor.Size.X / 2
            local halfZ = floor.Size.Z / 2
            testX = math.clamp(testX, floor.Position.X - halfX + 5, floor.Position.X + halfX - 5)
            testZ = math.clamp(testZ, floor.Position.Z - halfZ + 5, floor.Position.Z + halfZ - 5)
            
            local testPos = Vector3.new(testX, 20, testZ)
            
            -- Prefer points 20-60 studs away for more natural patrol distances
            local flatDist = (Vector3.new(testPos.X, 0, testPos.Z) - Vector3.new(rootPart.Position.X, 0, rootPart.Position.Z)).Magnitude
            if flatDist < 20 or flatDist > 60 then continue end
            
            local hitInfo = workspace:Raycast(testPos, Vector3.new(0, -30, 0), wanderRayParams)
            
            if hitInfo and hitInfo.Instance == floor then
                -- Check for nearby walls, trees, and other dogs (Strictly 2 studs away)
                local isClear = true
                local overlapParams = OverlapParams.new()
                overlapParams.FilterType = Enum.RaycastFilterType.Exclude
                
                local floorsFolder = mazeElements and mazeElements:FindFirstChild("Floors")
                local filters = {dogModel, floor}
                if floorsFolder then
                    table.insert(filters, floorsFolder)
                end
                overlapParams.FilterDescendantsInstances = filters
                
                local partsInRadius = workspace:GetPartBoundsInRadius(hitInfo.Position + Vector3.new(0, 2, 0), 2, overlapParams)
                for _, part in ipairs(partsInRadius) do
                    local modelName = part.Parent and part.Parent.Name or ""
                    if part.Name == "Wall" or part.Name == "Tree" or part.Name == "FireTree" or modelName == "ChaserDog" or modelName == "Wall" or part.CanCollide then
                        isClear = false
                        break
                    end
                end
                
                if isClear then
                    return hitInfo.Position
                end
            end
        end
        
        -- Fallback: try any point on the floor within patrol radius
        for i = 1, 10 do
            local angle = math.random() * math.pi * 2
            local distance = math.random() * patrolRadius
            local testX = patrolCenter.X + math.cos(angle) * distance
            local testZ = patrolCenter.Z + math.sin(angle) * distance
            
            local halfX = floor.Size.X / 2
            local halfZ = floor.Size.Z / 2
            testX = math.clamp(testX, floor.Position.X - halfX + 5, floor.Position.X + halfX - 5)
            testZ = math.clamp(testZ, floor.Position.Z - halfZ + 5, floor.Position.Z + halfZ - 5)
            
            local testPos = Vector3.new(testX, 20, testZ)
            local hitInfo = workspace:Raycast(testPos, Vector3.new(0, -30, 0), wanderRayParams)
            if hitInfo and hitInfo.Instance == floor then
                return hitInfo.Position
            end
        end
        
        return patrolCenter
    end
    
    local function startWandering()
        if wanderRoutine then return end
        
        -- Smooth patrol: pre-compute next destination while walking to current one
        -- Dogs walk continuously without stopping between paths
        wanderRoutine = task.spawn(function()
            local nextWanderPoint = getValidWanderPoint()
            
            while true do
                local wanderPoint = nextWanderPoint
                
                -- Pre-compute the NEXT destination in parallel so there's no pause between paths
                task.spawn(function()
                    nextWanderPoint = getValidWanderPoint()
                end)
                
                -- Vary patrol speed slightly for natural look (90-110% of base)
                local patrolSpeed = Constants.DogSpeed * (0.9 + math.random() * 0.2)
                humanoid.WalkSpeed = patrolSpeed
                
                local success, errorMessage = pcall(function()
                    path:ComputeAsync(rootPart.Position, wanderPoint)
                end)
                
                if success and path.Status == Enum.PathStatus.Success then
                    local waypoints = path:GetWaypoints()
                    for i, waypoint in ipairs(waypoints) do
                        if i > 1 then
                            humanoid:MoveTo(waypoint.Position)
                            
                            -- Wait until we are close enough to the waypoint, then proceed immediately
                            -- This maintains momentum and prevents the stop-and-go "robot" movement
                            local t = 0
                            while t < 2 do
                                local flatDist = (Vector3.new(rootPart.Position.X, 0, rootPart.Position.Z) - Vector3.new(waypoint.Position.X, 0, waypoint.Position.Z)).Magnitude
                                if flatDist < 2.5 then
                                    break
                                end
                                task.wait(0.05)
                                t = t + 0.05
                            end
                            
                            -- If we timed out (took longer than 2 seconds for a single waypoint), we're probably stuck. Abort!
                            if t >= 2 then
                                break
                            end
                        end
                    end
                    -- No pause between paths! Immediately start walking to next point
                else
                    -- Path failed, short pause then try again
                    task.wait(0.3)
                    nextWanderPoint = getValidWanderPoint()
                end
            end
        end)
    end
    
    -- Simple AI Loop
    local isDistracted = false
    
    task.spawn(function()
        while true do
            task.wait(0.2)
            
            if not rootPart or not rootPart.Parent then break end
            
            if footstepSound then
                local speed = rootPart.AssemblyLinearVelocity.Magnitude
                if speed > 1 then
                    footstepSound.Volume = Constants.Sounds.DogFootsteps.Volume or 0.65
                    if isChasing then
                        footstepSound.PlaybackSpeed = Constants.DogFootstepChasePitch
                    else
                        footstepSound.PlaybackSpeed = Constants.DogFootstepWalkPitch
                    end
                else
                    footstepSound.Volume = 0
                end
            end
            
            if isDistracted then
                stopWandering()
                continue
            end
            
            -- Proximity bark (even if invisible)
            if not isChasing then
                for _, p in ipairs(Players:GetPlayers()) do
                    local char = p.Character
                    if char and char:FindFirstChild("HumanoidRootPart") then
                        local dist = (char.HumanoidRootPart.Position - rootPart.Position).Magnitude
                        if dist <= Constants.DogChasingRange then
                            local lastBark = dogModel:GetAttribute("LastBarkTime") or 0
                            if tick() - lastBark > 5 then
                                dogModel:SetAttribute("LastBarkTime", tick())
                                SoundManager.playSound(Constants.Sounds.DogBark, rootPart, false, 80)
                            end
                        end
                    end
                end
            end
            
            local targetBone = getNearestVisibleBone(rootPart.Position)
            if targetBone then
                stopWandering()
                isChasing = true
                humanoid.WalkSpeed = Constants.DogChaseSpeed
                humanoid:MoveTo(targetBone.Position)
                
                -- Check if dog reached the bone
                if (rootPart.Position - targetBone.Position).Magnitude < 4 then
                    targetBone:Destroy()
                    isDistracted = true
                    stopChasingSound()
                    isChasing = false
                    -- Play a sound or animation here if needed
                    task.delay(10, function()
                        isDistracted = false
                    end)
                end
                continue
            end
            
            local targetChar = getNearestVisiblePlayer(dogModel)
            
            if targetChar then
                isSearching = false
                searchTimer = 0
                
                stopWandering()
                isChasing = true
                local p = Players:GetPlayerFromCharacter(targetChar)
                if p then
                    local currentChasing = dogModel:GetAttribute("ChasingPlayer")
                    if currentChasing ~= p.Name then
                        -- Decrement old target if switching
                        if currentChasing then
                            local oldP = Players:FindFirstChild(currentChasing)
                            if oldP then
                                local oldCount = oldP:GetAttribute("DogChasingCount") or 0
                                if oldCount > 0 then
                                    oldCount = oldCount - 1
                                    oldP:SetAttribute("DogChasingCount", oldCount)
                                    if oldCount <= 0 then
                                        oldP:SetAttribute("DogChasing", false)
                                    end
                                end
                            end
                        end
                        
                        dogModel:SetAttribute("ChasingPlayer", p.Name)
                        local chaseCount = p:GetAttribute("DogChasingCount") or 0
                        p:SetAttribute("DogChasingCount", chaseCount + 1)
                        if chaseCount == 0 then
                            p:SetAttribute("DogChasing", true)
                        end
                    end
                end
                
                if not chaseSound then
                    chaseSound = SoundManager.playSound(Constants.Sounds.DogChasing, rootPart, true, 80)
                end
                
                local speed = Constants.DogChaseSpeed
                if workspace:GetAttribute("TrollEffectActive") then
                    speed = speed * 1.3
                end
                humanoid.WalkSpeed = speed
                
                -- Predictive Interception AI
                local targetHrp = targetChar.HumanoidRootPart
                local targetPos = targetHrp.Position
                local flatVel = Vector3.new(targetHrp.AssemblyLinearVelocity.X, 0, targetHrp.AssemblyLinearVelocity.Z)
                local predictedPos = targetPos
                
                if flatVel.Magnitude > 2 then
                    local dist = (targetPos - rootPart.Position).Magnitude
                    -- Predict position based on time to reach (capped to 1.5 seconds to prevent overshooting)
                    local timeToReach = math.min(dist / Constants.DogChaseSpeed, 1.5)
                    local rawPredictedPos = targetPos + (flatVel * timeToReach)
                    
                    -- Ensure we don't predict a target position inside a wall
                    local raycastParams = RaycastParams.new()
                    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
                    raycastParams.FilterDescendantsInstances = {targetChar, dogModel}
                    raycastParams.CollisionGroup = "Dogs"
                    
                    local rayResult = workspace:Raycast(targetPos, rawPredictedPos - targetPos, raycastParams)
                    if rayResult then
                        -- If predicting through a wall, intercept slightly in front of the wall
                        predictedPos = rayResult.Position - (rawPredictedPos - targetPos).Unit * 2
                    else
                        predictedPos = rawPredictedPos
                    end
                end
                
                lastSeenPosition = predictedPos
                humanoid:MoveTo(predictedPos)
            else
                if isChasing then
                    isChasing = false
                    isSearching = true
                    searchTimer = tick()
                    searchWanderPoint = nil
                    stopChasingSound()
                    
                    humanoid.WalkSpeed = Constants.DogSpeed * 1.2
                    if lastSeenPosition then
                        humanoid:MoveTo(lastSeenPosition)
                    end
                elseif isSearching then
                    local timeInSearch = tick() - searchTimer
                    local searchDelay = Constants.DogLostChaseSearchDuration or 4.0
                    
                    if timeInSearch < searchDelay then
                        local distToLastSeen = lastSeenPosition and (rootPart.Position - lastSeenPosition).Magnitude or 0
                        if distToLastSeen < 4 or not searchWanderPoint then
                            if not searchWanderPoint or (rootPart.Position - searchWanderPoint).Magnitude < 4 then
                                local rx = (math.random() - 0.5) * 16
                                local rz = (math.random() - 0.5) * 16
                                searchWanderPoint = (lastSeenPosition or rootPart.Position) + Vector3.new(rx, 0, rz)
                                humanoid:MoveTo(searchWanderPoint)
                            end
                        end
                    else
                        isSearching = false
                        stopChasingSound()
                        
                        local chasingPlayerName = dogModel:GetAttribute("ChasingPlayer")
                        if chasingPlayerName then
                            local p = Players:FindFirstChild(chasingPlayerName)
                            if p then
                                local chaseCount = p:GetAttribute("DogChasingCount") or 0
                                if chaseCount > 0 then
                                    chaseCount = chaseCount - 1
                                    p:SetAttribute("DogChasingCount", chaseCount)
                                    if chaseCount <= 0 then
                                        p:SetAttribute("DogChasing", false)
                                    end
                                end
                            end
                            dogModel:SetAttribute("ChasingPlayer", nil)
                        end
                        
                        humanoid.WalkSpeed = Constants.DogSpeed
                        startWandering()
                    end
                else
                    startWandering()
                end
            end
        end
    end)
end

local function initDogs()
    if not workspace:GetAttribute("MazeGenerated") then
        workspace:GetAttributeChangedSignal("MazeGenerated"):Wait()
    end
    task.wait(0.5) -- A short extra wait to ensure all spawn points have fully initialized in Workspace
    
    local spawnLocations = workspace:WaitForChild("SpawnLocations")
    
    local spawns = {}
    for _, child in ipairs(spawnLocations:GetChildren()) do
        if child.Name == "DogSpawn" then
            local isFarEnough = true
            if #cachedSafeZoneParts > 0 then
                for _, part in ipairs(cachedSafeZoneParts) do
                    if (child.Position - part.Position).Magnitude <= 20 then
                        isFarEnough = false
                        break
                    end
                end
            end
            
            if isFarEnough then
                table.insert(spawns, child)
            else
                child:Destroy() -- Too close to base, remove spawn point
            end
        end
    end
    
    -- Shuffle spawns to pick random locations
    for i = #spawns, 2, -1 do
        local j = math.random(i)
        spawns[i], spawns[j] = spawns[j], spawns[i]
    end
    
    print("Total spawns found:", #spawns); local dogsToSpawn = math.min(Constants.TotalDogs, #spawns)
    for i = 1, dogsToSpawn do
        local sp = spawns[i]
        task.spawn(function()
            local dogName = "Dog" .. ((i - 1) % 3 + 1)
            local d = createDogModel(sp.Position, dogName)
            table.insert(dogs, d)
            setupDogAI(d)
        end)
    end
    
    -- Cleanup all unused spawn points
    for _, sp in ipairs(spawns) do
        if sp.Parent then
            sp:Destroy()
        end
    end
end

initDogs()
