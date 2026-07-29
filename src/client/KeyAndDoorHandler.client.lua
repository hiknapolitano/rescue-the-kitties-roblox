local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local HapticManager = require(Shared:WaitForChild("HapticManager"))

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local collectKeyRemote = remotesFolder:WaitForChild("CollectKeyRemote")

local mazeElements = workspace:WaitForChild("MazeElements", 120)
local keysFolder = workspace:WaitForChild("Keys", 120)
local doorsFolder = workspace:WaitForChild("Doors", 120)

local colorNames = {"Blue", "Yellow", "Red", "Purple", "Green"}
local collectedKeys = {}

-- Handle local key collection via ProximityPrompt
local function setupKeyPrompt(key)
    if not key:GetAttribute("IsKey") or not string.match(key.Name, "_Pickup$") then return end
    
    local primary = key:IsA("Model") and (key.PrimaryPart or key:FindFirstChildWhichIsA("BasePart", true)) or key
    if not primary:IsA("BasePart") then return end
    
    if primary:FindFirstChild("CollectKeyPrompt") then return end
    
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "CollectKeyPrompt"
    prompt.ActionText = "Collect"
    
    local colorName = nil
    for _, c in ipairs(colorNames) do
        if string.find(key.Name, c) then
            colorName = c
            break
        end
    end
    
    prompt.ObjectText = colorName and (colorName .. " Key") or "Key"
    prompt.HoldDuration = 0.5
    prompt.RequiresLineOfSight = false
    prompt.MaxActivationDistance = 10
    prompt.Parent = primary
    
    prompt.Triggered:Connect(function(triggerPlayer)
        if triggerPlayer == player then
            if not collectedKeys[key.Name] then
                if colorName and not player:GetAttribute("Has" .. colorName .. "Key") then
                    if key:IsA("BasePart") then
                        key.Transparency = 1
                    else
                        for _, part in ipairs(key:GetDescendants()) do
                            if part:IsA("BasePart") then
                                part.Transparency = 1
                            end
                        end
                    end
                    prompt.Enabled = false
                    collectKeyRemote:FireServer(colorName)
                    pcall(function() HapticManager.mediumPulse() end)
                end
            end
        end
    end)
end

local function scanKeys()
    if keysFolder then
        for _, key in ipairs(keysFolder:GetChildren()) do
            setupKeyPrompt(key)
        end
    end
end

if keysFolder then
    keysFolder.ChildAdded:Connect(setupKeyPrompt)
end
task.spawn(function()
    while true do
        scanKeys()
        task.wait(2)
    end
end)

-- Handle door unlocking (local visibility and collision)
local function updateDoors()
    if not doorsFolder then return end
    
    for _, door in ipairs(doorsFolder:GetChildren()) do
        local colorName
        for _, c in ipairs(colorNames) do
            if string.find(door.Name, c) then
                colorName = c
                break
            end
        end
        
        local isFinal = string.find(door.Name, "Final")
        local shouldBeOpen = false
        
        if colorName then
            shouldBeOpen = player:GetAttribute("Has" .. colorName .. "Key") == true
        elseif isFinal then
            local catsRescued = player:GetAttribute("CatsRescued") or 0
            local Shared = ReplicatedStorage:WaitForChild("Shared")
            local Constants = require(Shared:WaitForChild("Constants"))
            shouldBeOpen = catsRescued >= Constants.TotalCats
        end
        
        if shouldBeOpen then
            local blocker = door:FindFirstChild("BlockerPart", true)
            if blocker then
                blocker:Destroy()
            end
            local locker = door:FindFirstChild("Locker", true)
            if locker then
                locker:Destroy()
            end
        end
    end
    
    if player:GetAttribute("HasGreenKey") == true then
        local finalDoor = doorsFolder:FindFirstChild("FinalDoor")
        if finalDoor then
            for _, desc in ipairs(finalDoor:GetDescendants()) do
                if desc:IsA("BillboardGui") and desc.Name == "CatCounterGui" then
                    desc.Enabled = true
                end
            end
        end
    end
end

-- Update whenever a key attribute or cats rescued changes
for _, c in ipairs(colorNames) do
    player:GetAttributeChangedSignal("Has" .. c .. "Key"):Connect(updateDoors)
end
player:GetAttributeChangedSignal("CatsRescued"):Connect(updateDoors)

-- Also hide keys locally if we spawn in and already have them (from previous death)
local function hideOwnedKeys()
    if not keysFolder then return end
    for _, key in ipairs(keysFolder:GetChildren()) do
        local colorName
        for _, c in ipairs(colorNames) do
            if string.find(key.Name, c) then
                colorName = c
                break
            end
        end
        
        if colorName and player:GetAttribute("Has" .. colorName .. "Key") then
            if key:IsA("BasePart") then
                key.Transparency = 1
            else
                for _, part in ipairs(key:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Transparency = 1
                    end
                end
            end
        end
    end
end

local function hookTrophy()
    local mazeElements = workspace:WaitForChild("MazeElements", 120)
    if mazeElements then
        local trophy = mazeElements:WaitForChild("ResetTrophy", 120)
        if trophy and trophy:FindFirstChild("ClickDetector") then
            local resetProgressRemote = remotesFolder:WaitForChild("ResetProgress", 10)
            if resetProgressRemote then
                trophy.ClickDetector.MouseClick:Connect(function()
                    resetProgressRemote:FireServer()
                end)
            end
        end
    end
end

-- Initial calls
task.spawn(function()
    task.wait(2) -- Wait for map to build
    updateDoors()
    hideOwnedKeys()
    hookTrophy()
end)
