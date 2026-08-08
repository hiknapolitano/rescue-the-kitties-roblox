local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")

local collectBoatRemote = remotesFolder:FindFirstChild("CollectBoatRemote")
if not collectBoatRemote then
    collectBoatRemote = Instance.new("RemoteEvent")
    collectBoatRemote.Name = "CollectBoatRemote"
    collectBoatRemote.Parent = remotesFolder
end

local toggleBoatRemote = remotesFolder:FindFirstChild("ToggleBoatRemote")
if not toggleBoatRemote then
    toggleBoatRemote = Instance.new("RemoteEvent")
    toggleBoatRemote.Name = "ToggleBoatRemote"
    toggleBoatRemote.Parent = remotesFolder
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

collectBoatRemote.OnServerEvent:Connect(function(player)
    player:SetAttribute("HasBoat", true)
    
    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    local playSoundRemote = remotesFolder and remotesFolder:FindFirstChild("PlaySoundClient")
    if playSoundRemote then
        playSoundRemote:FireClient(player, "ItemPickup")
    end
end)

local function clearBoat(player)
    player:SetAttribute("InBoat", false)
    
    local boat = workspace:FindFirstChild(player.Name .. "_ActiveBoat")
    if boat then
        boat:Destroy()
    end
    
    if player.Character then
        local hum = player.Character:FindFirstChild("Humanoid")
        if hum then
            hum.Sit = false
            hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
            hum.WalkSpeed = 18 -- Reset WalkSpeed
        end
        for _, part in ipairs(player.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CollisionGroup = "Default"
            end
        end
    end
end

toggleBoatRemote.OnServerEvent:Connect(function(player, enter, targetPos)
    if enter then
        if not player:GetAttribute("HasBoat") then return end
        if workspace:FindFirstChild(player.Name .. "_ActiveBoat") then return end
        
        -- Enter Boat
        player:SetAttribute("InBoat", true)
        local character = player.Character
        if not character then return end
        
        local hrp = character:FindFirstChild("HumanoidRootPart")
        local hum = character:FindFirstChild("Humanoid")
        if not hrp or not hum then return end
        
        -- Disable Jump and Swimming
        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
        hum.WalkSpeed = 25 -- Faster in boat
        
        -- Change CollisionGroup so player can pass through WaterBarrier
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CollisionGroup = "PlayerInBoat"
            end
        end
        
        -- Create the functional vehicle boat
        local boatTemplate = ReplicatedStorage:FindFirstChild("Objects") and ReplicatedStorage.Objects:FindFirstChild("Boat")
        if boatTemplate then
            local activeBoat = boatTemplate:Clone()
            activeBoat.Name = player.Name .. "_ActiveBoat"
            
            -- Delete potentially broken internal scripts
            for _, s in ipairs(activeBoat:GetDescendants()) do
                if s:IsA("Script") or s:IsA("LocalScript") then
                    s:Destroy()
                end
            end
            
            -- Ensure everything is Anchored so it NEVER breaks or sinks
            for _, part in ipairs(activeBoat:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Anchored = true
                    part.CanCollide = false -- So it doesn't get stuck on walls
                end
            end
            if activeBoat:IsA("BasePart") then
                activeBoat.Anchored = true
                activeBoat.CanCollide = false
            end
            
            -- Determine exact water level
            local spawnX = typeof(targetPos) == "Vector3" and targetPos.X or hrp.Position.X + hrp.CFrame.LookVector.X * 5
            local spawnZ = typeof(targetPos) == "Vector3" and targetPos.Z or hrp.Position.Z + hrp.CFrame.LookVector.Z * 5
            local waterY = 0.5
            
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {character, activeBoat}
            raycastParams.FilterType = Enum.RaycastFilterType.Exclude
            
            local ray = workspace:Raycast(Vector3.new(spawnX, 10, spawnZ), Vector3.new(0, -20, 0), raycastParams)
            if ray and ray.Material == Enum.Material.Water then
                waterY = ray.Position.Y
            end
            
            activeBoat:PivotTo(CFrame.new(Vector3.new(spawnX, waterY + 0.5, spawnZ)))
            activeBoat.Parent = workspace
            
            -- Find the VehicleSeat
            local seat = activeBoat:FindFirstChildWhichIsA("VehicleSeat", true) or activeBoat:FindFirstChildWhichIsA("Seat", true)
            if seat then
                -- Teleport character and force sit
                hrp.CFrame = seat.CFrame * CFrame.new(0, 2, 0)
                task.wait(0.1) -- small delay to ensure physics updates before sitting
                seat:Sit(hum)
                
                -- Custom CFrame-based Boat Controller
                local boatSpeed = 20
                local turnSpeed = 2
                
                -- Cached overlap params (reused each frame, never recreated)
                local overlapParams = OverlapParams.new()
                overlapParams.FilterDescendantsInstances = {character, activeBoat}
                overlapParams.FilterType = Enum.RaycastFilterType.Exclude
                
                -- Use a small flat hitbox at water level to probe wall collisions.
                -- We don't use GetBoundingBox-based offset because it breaks after rotation.
                -- The hitbox is intentionally flat (Y=1) so it never catches floor tiles below the boat.
                local probeSize = Vector3.new(3, 1, 3)
                
                local function isPositionBlocked(testPos)
                    -- Test a flat box at the target XZ position at water height
                    local testCFrame = CFrame.new(testPos.X, 1, testPos.Z)
                    local parts = workspace:GetPartBoundsInBox(testCFrame, probeSize, overlapParams)
                    for _, part in ipairs(parts) do
                        local pName = part.Name
                        local isWall = (pName == "Wall") or (part.Parent and part.Parent.Name == "Wall")
                        -- Do NOT include FloorTile — the boat floats above floor tiles
                        if isWall or pName == "JustLava" or pName == "LavaObby" or pName == "Tree" then
                            return true
                        end
                    end
                    return false
                end
                
                -- Preload Maps once outside the loop
                local Maps = require(Shared:WaitForChild("Maps"))
                local mapLayout = Maps[Constants.ActiveLevel]
                local cellSize = Constants.CellSize
                local mazeOffset = Constants.MazeOffset or Vector3.new(0, 0, 0)
                
                local function isWaterCell(pos)
                    if not mapLayout then return true end -- if no layout, allow movement
                    local cellX = math.floor((pos.X - mazeOffset.X + cellSize/2) / cellSize) + 1
                    local cellZ = math.floor((pos.Z - mazeOffset.Z + cellSize/2) / cellSize) + 1
                    local row = mapLayout[cellZ]
                    -- Allow boat to drive on water (26) or white light teleporters (8)
                    return row and (row[cellX] == 26 or row[cellX] == 8)
                end
                
                local connection
                connection = game:GetService("RunService").Heartbeat:Connect(function(dt)
                    if not activeBoat or not activeBoat.Parent then
                        if connection then connection:Disconnect() end
                        return
                    end
                    
                    -- Guard: re-sit only if humanoid is alive and not seated
                    if hum and hum.Health > 0 and hum:GetState() ~= Enum.HumanoidStateType.Seated then
                        pcall(function() seat:Sit(hum) end)
                    end
                    
                    local throttle = 0
                    local steer = 0
                    if seat:IsA("VehicleSeat") then
                        throttle = seat.ThrottleFloat
                        steer = seat.SteerFloat
                    end
                    
                    if throttle ~= 0 or steer ~= 0 then
                        local currentPivot = activeBoat:GetPivot()
                        
                        -- Step 1: Always apply rotation (turning is never blocked)
                        local rotatedCFrame = currentPivot * CFrame.Angles(0, math.rad(-steer * turnSpeed * dt * 60), 0)
                        
                        -- Step 2: Compute desired forward position
                        local moveVector = rotatedCFrame.LookVector * (throttle * boatSpeed * dt)
                        local nextPos = rotatedCFrame.Position + moveVector
                        
                        -- Step 3: Check wall collision at future position
                        local wallBlocked = throttle ~= 0 and isPositionBlocked(nextPos)
                        
                        -- Step 4: Check map layout — boat must stay on water cells
                        local waterOK = throttle == 0 or isWaterCell(nextPos)
                        
                        -- Step 5: Move
                        if not wallBlocked and waterOK then
                            activeBoat:PivotTo(CFrame.new(nextPos.X, currentPivot.Position.Y, nextPos.Z) * rotatedCFrame.Rotation)
                        else
                            -- Blocked: apply rotation only so player can turn away
                            activeBoat:PivotTo(CFrame.new(currentPivot.Position) * rotatedCFrame.Rotation)
                        end
                    end
                end)
            end
        end
        
    else
        -- Exit Boat
        if not player:GetAttribute("InBoat") then return end
        
        local character = player.Character
        if not character then return end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        
        local targetPos = nil
        local Maps = require(Shared:WaitForChild("Maps"))
        local layout = Maps[Constants.ActiveLevel]
        
        if layout then
            local cellSize = Constants.CellSize
            local bestDist = math.huge
            
            for z, row in ipairs(layout) do
                for x, cellType in ipairs(row) do
                    -- Walkable paths are any cells that are NOT walls, hazards, water, or teleporters (8)
                    local isWalkable = (cellType ~= 1 and cellType ~= 8 and cellType ~= 24 and cellType ~= 25 and cellType ~= 26 and cellType ~= 28)
                    if isWalkable then
                        local mazeOffset = Constants.MazeOffset or Vector3.new(0, 0, 0)
                        local px = (x - 1) * cellSize + mazeOffset.X
                        local pz = (z - 1) * cellSize + mazeOffset.Z
                        
                        local testPos = Vector3.new(px, 0, pz)
                        local dist = (testPos - Vector3.new(hrp.Position.X, 0, hrp.Position.Z)).Magnitude
                        -- Must be reasonably close to land to exit
                        if dist < bestDist and dist <= (cellSize * 2.5) then
                            bestDist = dist
                            targetPos = Vector3.new(px, 4, pz) -- 4 is safely above ground
                        end
                    end
                end
            end
        end
        
        if targetPos then
            local hum = character:FindFirstChild("Humanoid")
            if hum then
                hum.Sit = false
            end
            hrp.CFrame = CFrame.new(targetPos) * CFrame.Angles(0, math.rad(hrp.Orientation.Y), 0)
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            
            task.wait(0.1) -- Wait for Roblox's internal unsit/exit physics to process
            
            if character.Parent and hrp.Parent then
                hrp.CFrame = CFrame.new(targetPos) * CFrame.Angles(0, math.rad(hrp.Orientation.Y), 0)
                hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                clearBoat(player)
            end
        else
            local remote = remotesFolder:FindFirstChild("SendNotification")
            if remote then
                remote:FireClient(player, "Could not find a safe place to land!")
            end
        end
    end
end)

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(char)
        -- Reset state on respawn
        player:SetAttribute("InBoat", false)
        local hum = char:WaitForChild("Humanoid", 5)
        if hum then
            hum.Died:Connect(function()
                clearBoat(player)
            end)
        end
    end)
end)
