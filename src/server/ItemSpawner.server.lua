local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local itemsList = {
    "Cash", "Cash", "Cash", "Cash", "Cash",
    "Cash", "Cash", "Cash", "Cash", "Cash",
    "Cash", "Cash", "Cash", "Cash", "Cash",
    "Slime", "Slime", "Slime", "Slime", "Slime", 
    "Mud", "Mud", "Mud", "Mud", "Mud",
    "DogBone", "EnergyDrink", "Shield", "potion"
}

local activeSlimes = {}
local activeMuds = {}

local function createCashObject()
    local part = Instance.new("Part")
    part.Shape = Enum.PartType.Cylinder
    part.Size = Vector3.new(0.4, 2.0, 2.0) -- Thin cylinder (20% smaller)
    part.Color = Color3.fromRGB(255, 215, 0) -- Gold
    part.Material = Enum.Material.Metal
    
    for _, face in ipairs({Enum.NormalId.Right, Enum.NormalId.Left}) do
        local sg = Instance.new("SurfaceGui")
        sg.Face = face
        sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
        sg.PixelsPerStud = 50
        sg.Parent = part
        
        local text = Instance.new("TextLabel")
        text.Size = UDim2.new(1, 0, 1, 0)
        text.BackgroundTransparency = 1
        text.Text = "$"
        text.TextColor3 = Color3.fromRGB(200, 150, 0)
        text.TextScaled = true
        text.Font = Enum.Font.GothamBold
        text.Parent = sg
    end
    
    return part
end

local function createItem(itemName, position)
    local template = ReplicatedStorage:FindFirstChild("Objects") and ReplicatedStorage.Objects:FindFirstChild(itemName)
    local part
    
    if itemName == "Cash" then
        part = createCashObject()
    elseif template then
        part = template:Clone()
    end
    
    if part then
        local offset = Vector3.new(0, 1, 0)
        if itemName == "Shield" then
            offset = Vector3.new(0, 2.5, 0)
        elseif itemName == "Cash" then
            offset = Vector3.new(0, 1.5, 0)
        end
        local spawnCFrame = CFrame.new(position + offset)
        
        if part:IsA("Model") then
            part:PivotTo(spawnCFrame)
        else
            part.CFrame = spawnCFrame
        end
    else
        -- Generic fallback for any other missing items
        part = Instance.new("Part")
        part.Color = Color3.new(1, 1, 1)
        part.Material = Enum.Material.SmoothPlastic
        part.Shape = Enum.PartType.Block
        part.Size = Vector3.new(1, 1, 1)
        part.Position = position + Vector3.new(0, 4.5, 0)
        
        if itemName == "potion" then
            part.Color = Color3.new(0.5, 0, 0.8)
            part.Shape = Enum.PartType.Cylinder
            part.Size = Vector3.new(1, 1.5, 1)
            part.Position = position + Vector3.new(0, 0.75, 0)
        end
    end
    if part:IsA("BasePart") then
        part.Anchored = true
        part.CanCollide = false
        part.CastShadow = false
    else
        for _, child in ipairs(part:GetDescendants()) do
            if child:IsA("BasePart") then
                child.CanCollide = false
                child.Anchored = true
                child.CastShadow = false
            end
        end
    end
    
    part.Name = itemName .. "_Pickup"
    
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Pick Up"
    prompt.ObjectText = itemName
    prompt.HoldDuration = 0.5
    prompt.RequiresLineOfSight = false
    
    if part:IsA("Model") then
        if not part.PrimaryPart then
            local firstPart = part:FindFirstChildWhichIsA("BasePart", true)
            if firstPart then
                part.PrimaryPart = firstPart
            end
        end
        prompt.Parent = part.PrimaryPart or part
        
        local orientation, size = part:GetBoundingBox()
        local basePos = position + Vector3.new(0, (size.Y / 2) + 2, 0)
        part:SetAttribute("BasePosition", basePos)
        part:PivotTo(CFrame.new(basePos))
    else
        prompt.Parent = part
        local basePos = position + Vector3.new(0, (part.Size.Y / 2) + 2, 0)
        part:SetAttribute("BasePosition", basePos)
        part.CFrame = CFrame.new(basePos)
    end
    
    -- IMPORTANT: Parent to workspace LAST so the ItemAnimator client script gets the attributes!
    part.Parent = workspace
    
    prompt.Triggered:Connect(function(player)
        local count = 0
        if player:FindFirstChild("Backpack") then
            count = count + #player.Backpack:GetChildren()
        end
        if player.Character and player.Character:FindFirstChildOfClass("Tool") then
            count = count + 1
        end
        
        if count >= 9 and itemName ~= "Cash" then
            local notifyEvt = ReplicatedStorage:FindFirstChild("ShowNotification")
            if notifyEvt then
                notifyEvt:FireClient(player, "Inventory Full!")
            end
            return
        end

        local evt = ServerStorage:FindFirstChild("ItemPickedUp")
        if evt then
            evt:Fire(player, itemName)
            part:Destroy()
        end
    end)
end

local function spawnSlime(pos)
    local template = ReplicatedStorage:FindFirstChild("Objects") and (ReplicatedStorage.Objects:FindFirstChild("Slime") or ReplicatedStorage.Objects:FindFirstChild("slime"))
    local slime
    if template then
        slime = template:Clone()
    else
        slime = Instance.new("Part")
        slime.Name = "Slime"
        slime.Size = Vector3.new(10, 0.5, 10)
        slime.Color = Color3.fromRGB(50, 255, 50)
        slime.Material = Enum.Material.Mud
    end
    
    if slime:IsA("Model") then
        slime:PivotTo(CFrame.new(pos + Vector3.new(0, 0.25, 0)))
    else
        slime.Position = pos + Vector3.new(0, 0.25, 0)
    end
    
    for _, child in ipairs(slime:GetDescendants()) do
        if child:IsA("BasePart") then
            child.CanCollide = false
            child.Anchored = true
            child.CastShadow = false
        end
    end
    if slime:IsA("BasePart") then
        slime.CanCollide = false
        slime.Anchored = true
        slime.CastShadow = false
    end
    
    slime.Parent = workspace
    
    table.insert(activeSlimes, slime)
    if #activeSlimes > 20 then
        local oldest = table.remove(activeSlimes, 1)
        if oldest and oldest.Parent then
            oldest:Destroy()
        end
    end
end

local function spawnMud(pos)
    local template = ReplicatedStorage:FindFirstChild("Objects") and ReplicatedStorage.Objects:FindFirstChild("Mud")
    local mud
    if template then
        mud = template:Clone()
    else
        mud = Instance.new("Part")
        mud.Name = "Mud"
        mud.Size = Vector3.new(10, 0.5, 10)
        mud.Color = Color3.fromRGB(80, 50, 30)
        mud.Material = Enum.Material.Mud
    end
    
    if mud:IsA("Model") then
        mud:PivotTo(CFrame.new(pos + Vector3.new(0, 0.25, 0)))
    else
        mud.Position = pos + Vector3.new(0, 0.25, 0)
    end
    
    for _, child in ipairs(mud:GetDescendants()) do
        if child:IsA("BasePart") then
            child.CanCollide = false
            child.Anchored = true
            child.CastShadow = false
        end
    end
    if mud:IsA("BasePart") then
        mud.CanCollide = false
        mud.Anchored = true
        mud.CastShadow = false
    end
    
    mud.Parent = workspace
    
    table.insert(activeMuds, mud)
    if #activeMuds > 20 then
        local oldest = table.remove(activeMuds, 1)
        if oldest and oldest.Parent then
            oldest:Destroy()
        end
    end
end

-- Item hover/spin animation moved to client-side ItemAnimator.client.lua for performance

-- Cache spawn locations once for safe zone checks (avoid scanning all workspace descendants per call)
local cachedSpawnLocations = nil
local function isNearSafeZone(pos)
    if not cachedSpawnLocations then
        cachedSpawnLocations = {}
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("SpawnLocation") then
                table.insert(cachedSpawnLocations, obj)
            end
        end
    end
    
    for _, obj in ipairs(cachedSpawnLocations) do
        if obj.Parent then
            if (obj.Position - pos).Magnitude < 150 then
                return true
            end
        end
    end
    return false
end

local function getRandomPathPoint()
    local mazeElements = workspace:WaitForChild("MazeElements")
    local floorsFolder = mazeElements:WaitForChild("Floors")
    local floorTiles = floorsFolder:GetChildren()
    if #floorTiles == 0 then return nil end
    
    -- Build raycast params ONCE per call, not per attempt
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    local exclude = {}
    for _, child in ipairs(workspace:GetChildren()) do
        if string.match(child.Name, "_Pickup$") or child:FindFirstChild("Humanoid") then
            table.insert(exclude, child)
        end
    end
    raycastParams.FilterDescendantsInstances = exclude
    
    for i=1, 50 do
        local randomTile = floorTiles[math.random(1, #floorTiles)]
        local rx = (math.random() - 0.5) * randomTile.Size.X
        local rz = (math.random() - 0.5) * randomTile.Size.Z
        local testPos = randomTile.Position + Vector3.new(rx, 20, rz)
        
        local hitInfo = workspace:Raycast(testPos, Vector3.new(0, -30, 0), raycastParams)
        
        if hitInfo and hitInfo.Instance.Name == "FloorTile" then
            if not isNearSafeZone(hitInfo.Position) then
                -- Ensure there are no walls within 3 studs horizontally
                local isClear = true
                local directions = {
                    Vector3.new(3, 0, 0),
                    Vector3.new(-3, 0, 0),
                    Vector3.new(0, 0, 3),
                    Vector3.new(0, 0, -3)
                }
                
                for _, dir in ipairs(directions) do
                    local wallCheck = workspace:Raycast(hitInfo.Position + Vector3.new(0, 1, 0), dir, raycastParams)
                    if wallCheck then
                        isClear = false
                        break
                    end
                end
                
                if isClear then
                    return hitInfo.Position
                end
            end
        end
    end
    return nil
end

task.spawn(function()
    workspace:WaitForChild("MazeElements")
    
    if not ServerStorage:FindFirstChild("ItemPickedUp") then
        local evt = Instance.new("BindableEvent")
        evt.Name = "ItemPickedUp"
        evt.Parent = ServerStorage
    end
    
    -- Initial spawn
    task.wait(5)
    local initialSpawnCount = 15 + (#Players:GetPlayers() * 5)
    for i=1, initialSpawnCount do
        local pos = getRandomPathPoint()
        if pos then
            local itemName = itemsList[math.random(1, #itemsList)]
            if itemName == "Slime" then
                spawnSlime(pos)
            elseif itemName == "Mud" then
                spawnMud(pos)
            else
                createItem(itemName, pos)
            end
        end
    end
    
    while true do
        task.wait(Constants.NormalItemSpawnInterval)
        
        local currentItems = 0
        local currentSlimes = 0
        for _, child in ipairs(workspace:GetChildren()) do
            if string.match(child.Name, "_Pickup$") and child.Name ~= "Bandage_Pickup" and not child:GetAttribute("IsKey") then
                currentItems = currentItems + 1
            elseif child.Name == "Slime" then
                currentSlimes = currentSlimes + 1
            end
        end
        
        local pos = getRandomPathPoint()
        if pos then
            local itemName = itemsList[math.random(1, #itemsList)]
            if itemName == "Slime" then
                spawnSlime(pos)
            elseif itemName == "Mud" then
                spawnMud(pos)
            else
                local dynamicMaxItems = Constants.MaxNormalItems + (#Players:GetPlayers() * 8)
                if currentItems < dynamicMaxItems then
                    createItem(itemName, pos)
                end
            end
        end
    end
end)

-- Dedicated Bandage Spawner Loop
task.spawn(function()
    workspace:WaitForChild("MazeElements")
    
    -- Initial bandage spawn
    task.wait(6)
    local initialBandageSpawn = 1 + math.floor(#Players:GetPlayers() / 2)
    for i=1, initialBandageSpawn do
        local pos = getRandomPathPoint()
        if pos then
            createItem("Bandage", pos)
        end
    end
    
    while true do
        task.wait(120) -- Hardcoded 120 seconds interval
        
        local currentBandages = 0
        for _, child in ipairs(workspace:GetChildren()) do
            if child.Name == "Bandage_Pickup" then
                currentBandages = currentBandages + 1
            end
        end
        
        local dynamicMaxBandages = 9 + (#Players:GetPlayers() * 3)
        if currentBandages < dynamicMaxBandages then
            local pos = getRandomPathPoint()
            if pos then
                createItem("Bandage", pos)
            end
        end
    end
end)
