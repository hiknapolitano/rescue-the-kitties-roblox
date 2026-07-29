local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local player = Players.LocalPlayer
local animatedCats = {}

-- Save the original CFrames of a cat model's children relative to its root
local function setupCatAnimation(catRoot)
    -- Verify it's a cat
    if catRoot.Name ~= "Cat" then return end
    
    local rootPart = nil
    if catRoot:IsA("BasePart") then
        rootPart = catRoot
    elseif catRoot:IsA("Model") then
        rootPart = catRoot.PrimaryPart or catRoot:FindFirstChild("HumanoidRootPart") or catRoot:FindFirstChildWhichIsA("BasePart")
    end
    if not rootPart then return end
    
    -- The actual visual model is parented inside the root part and is also named "Cat" (or we just search descendants)
    local visualModel = catRoot:FindFirstChild("Cat") or catRoot
    
    local catBodyModel = visualModel:FindFirstChild("Cat's body")
    local catFaceModel = visualModel:FindFirstChild("Cat's face")
    local catTailModel = visualModel:FindFirstChild("Tail")
    
    if not catBodyModel then return end
    
    local data = {
        model = catRoot,
        rootPart = rootPart,
        visualModel = visualModel,
        parts = {},
        partInfo = {}, -- Cached classification: { isLeg, isHead, isTail }
        timeOffset = math.random() * 10, -- Randomize breathing phase
        currentHeadCFrame = CFrame.new(), -- Start at identity offset
        headPivot = Vector3.new(0, 1.5, -1), -- Default pivot if no head is found
        tailModel = catTailModel, -- Cache tail reference
    }
    
    -- Helper to classify a part as head/face at setup time
    local function classifyAsHead(child)
        local name = child.Name:lower()
        if string.find(name, "head") or string.find(name, "face") or string.find(name, "snout") or string.find(name, "ear") or string.find(name, "eye") or string.find(name, "whisker") or string.find(name, "nose") or string.find(name, "mouth") then
            return true
        end
        -- Check all ancestors up to the visual model for "face" or "head"
        local p = child.Parent
        while p and p ~= visualModel and p ~= catRoot and p ~= workspace do
            local pName = p.Name:lower()
            if string.find(pName, "face") or string.find(pName, "head") then
                return true
            end
            p = p.Parent
        end
        return false
    end
    
    -- Function to recursively store original CFrames and classify parts
    local function storeOriginals(model)
        for _, child in ipairs(model:GetDescendants()) do
            if child:IsA("BasePart") then
                -- Store the CFrame offset relative to the Cat root part
                local localCFrame = rootPart.CFrame:ToObjectSpace(child.CFrame)
                data.parts[child] = localCFrame
                
                local name = child.Name:lower()
                
                if name == "head" then
                    data.headPivot = localCFrame.Position
                end
                
                -- Cache part classification at setup time (not per frame!)
                data.partInfo[child] = {
                    isLeg = string.find(name, "leg") ~= nil,
                    isHead = classifyAsHead(child),
                    isTail = catTailModel and child:IsDescendantOf(catTailModel),
                }
                
                -- Destroy any joints/welds to prevent CFrame assignment conflicts
                for _, joint in ipairs(child:GetJoints()) do
                    joint:Destroy()
                end
                for _, obj in ipairs(child:GetChildren()) do
                    if obj:IsA("WeldConstraint") or obj:IsA("Weld") or obj:IsA("Motor6D") or obj:IsA("JointInstance") then
                        obj:Destroy()
                    end
                end
            end
        end
    end
    
    storeOriginals(visualModel)
    
    animatedCats[catRoot] = data
end

local function cleanupCatAnimation(catRoot)
    animatedCats[catRoot] = nil
end

-- Scan existing and new cats
workspace.DescendantAdded:Connect(function(descendant)
    if descendant.Name == "Cat" then
        -- Wait a tiny bit to ensure children (like Cat's body) are loaded before caching
        task.delay(0.1, function()
            if descendant.Parent then
                setupCatAnimation(descendant)
            end
        end)
    end
end)

workspace.DescendantRemoving:Connect(function(descendant)
    if animatedCats[descendant] then
        cleanupCatAnimation(descendant)
    end
end)

-- Initial scan
for _, descendant in ipairs(workspace:GetDescendants()) do
    if descendant.Name == "Cat" then
        setupCatAnimation(descendant)
    end
end

-- Animation Loop (with distance culling and frame throttling)
local CAT_ANIM_RANGE_SQ = 120 * 120 -- 120 studs squared
local catAnimFrameCounter = 0
local CAT_ANIM_FRAME_SKIP = 2 -- Run every 3rd frame (~20fps at 60Hz)

RunService.Heartbeat:Connect(function(dt)
    if player:GetAttribute("PerformanceMode") == true then return end
    
    -- Throttle to ~20fps: skip 2 out of every 3 frames
    catAnimFrameCounter = catAnimFrameCounter + 1
    if catAnimFrameCounter <= CAT_ANIM_FRAME_SKIP then return end
    catAnimFrameCounter = 0
    
    -- Multiply dt by skip+1 to maintain correct animation speed
    local effectiveDt = dt * (CAT_ANIM_FRAME_SKIP + 1)
    
    local t = tick()
    
    local char = player.Character
    local playerHrp = char and char:FindFirstChild("HumanoidRootPart")
    local playerPos = playerHrp and playerHrp.Position
    
    for catModel, data in pairs(animatedCats) do
        if not catModel.Parent or not data.rootPart.Parent then
            animatedCats[catModel] = nil
            continue
        end
        
        -- Distance culling: skip animation for far cats
        if playerPos then
            local dx = playerPos.X - data.rootPart.Position.X
            local dz = playerPos.Z - data.rootPart.Position.Z
            if (dx * dx + dz * dz) > CAT_ANIM_RANGE_SQ then
                continue
            end
        end
        
        local rootCFrame = data.rootPart.CFrame
        local localTime = t + data.timeOffset
        
        -- Calculate Breathing (Slow sine wave)
        local breathSin = math.sin(localTime * 3)
        local breathOffset = Vector3.new(0, breathSin * 0.05, 0)
        
        -- Calculate Shaking (Fast, tiny sine wave for fear)
        local shakeSinX = math.sin(localTime * 25) * 0.02
        local shakeSinZ = math.cos(localTime * 23) * 0.02
        local shakeOffset = Vector3.new(shakeSinX, 0, shakeSinZ)
        
        -- Calculate Tail Wag (Slight rotation)
        local tailAngle = math.sin(localTime * 1.5) * 0.1
        
        -- Idle Head Wandering (smooth random-looking movement)
        local idleYaw = math.sin(localTime * 0.6) * math.cos(localTime * 0.35) * 0.5
        local idlePitch = math.sin(localTime * 0.4) * 0.15
        local targetHeadCFrame = CFrame.Angles(idlePitch, idleYaw, 0)
        
        -- Player Tracking (Overrides idle look if player is close)
        if playerPos then
            local dist = (playerPos - rootCFrame.Position).Magnitude
            if dist < 25 then
                local lookAtGlobal = CFrame.lookAt(rootCFrame.Position, playerPos)
                local relativeLook = rootCFrame:ToObjectSpace(lookAtGlobal)
                local rx, ry, rz = relativeLook:ToOrientation()
                local maxRad = math.rad(Constants.MaxCatHeadRotation)
                ry = math.clamp(ry, -maxRad, maxRad)
                rx = math.clamp(rx, -maxRad/2, maxRad/2)
                targetHeadCFrame = CFrame.Angles(rx, ry, 0)
            end
        end
        
        -- Smoothly lerp head tracking (scale by effective dt)
        data.currentHeadCFrame = data.currentHeadCFrame:Lerp(targetHeadCFrame, effectiveDt * 5)
        
        for part, localOriginalCFrame in pairs(data.parts) do
            if not part.Parent then continue end
            
            local info = data.partInfo[part]
            if not info then continue end
            
            -- Keep legs firmly planted (no Y breath, no shaking)
            if info.isLeg then
                part.CFrame = rootCFrame * localOriginalCFrame
            else
                -- Everything else breathes and shakes
                local targetLocalCFrame = localOriginalCFrame + breathOffset + shakeOffset
                
                -- Extra tail wagging (uses cached isTail)
                if info.isTail then
                    targetLocalCFrame = targetLocalCFrame * CFrame.Angles(0, tailAngle, 0)
                end
                
                if info.isHead then
                    local offsetFromPivot = targetLocalCFrame.Position - data.headPivot
                    local breathRot = CFrame.Angles(breathSin * 0.05, 0, 0)
                    local combinedRot = data.currentHeadCFrame * breathRot
                    local rotatedPos = data.headPivot + (combinedRot * offsetFromPivot)
                    local rot = targetLocalCFrame.Rotation
                    targetLocalCFrame = CFrame.new(rotatedPos) * combinedRot * rot
                end
                
                part.CFrame = rootCFrame * targetLocalCFrame
            end
        end
    end
end)
