-- ItemAnimator.client.lua
-- Client-side item hover/spin animation with distance culling
-- Only animates items within ANIM_RANGE studs of the player

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- Cache player HRP reference (avoid FindFirstChild in loop)
local cachedHrp = nil
local function refreshItemAnimCache()
    local char = player.Character
    cachedHrp = char and char:FindFirstChild("HumanoidRootPart")
end
player.CharacterAdded:Connect(function(char)
    cachedHrp = nil
    char:WaitForChild("HumanoidRootPart", 10)
    cachedHrp = char:FindFirstChild("HumanoidRootPart")
end)
refreshItemAnimCache()

local ANIM_RANGE = 80 -- studs
local ANIM_RANGE_SQ = ANIM_RANGE * ANIM_RANGE -- pre-compute for faster distance checks

local trackedItems = {} -- {instance = {basePos, isCash}}
local trackedKeys = {}  -- {instance = {basePos}}

local function trackItem(obj)
    if string.match(obj.Name, "_Pickup$") then
        local basePos = obj:GetAttribute("BasePosition")
        if basePos then
            trackedItems[obj] = {
                basePos = basePos,
                isCash = (obj.Name == "Cash_Pickup")
            }
        end
    end
end

local function trackKey(obj)
    if obj:GetAttribute("IsKey") then
        local basePos = obj:GetAttribute("BasePosition")
        if basePos then
            trackedKeys[obj] = { basePos = basePos }
        end
    end
end

-- Initial scan
for _, child in ipairs(workspace:GetChildren()) do
    trackItem(child)
end

local keysFolder = workspace:FindFirstChild("Keys")
if keysFolder then
    for _, child in ipairs(keysFolder:GetChildren()) do
        trackKey(child)
    end
    keysFolder.ChildAdded:Connect(trackKey)
    keysFolder.ChildRemoved:Connect(function(child)
        trackedKeys[child] = nil
    end)
end

workspace.ChildAdded:Connect(trackItem)
workspace.ChildRemoved:Connect(function(child)
    trackedItems[child] = nil
end)

local timePassed = 0

RunService.Heartbeat:Connect(function(dt)
    timePassed = timePassed + dt
    
    if not cachedHrp then return end
    
    local playerPos = cachedHrp.Position
    
    -- Animate pickup items
    for obj, data in pairs(trackedItems) do
        if not obj.Parent then
            trackedItems[obj] = nil
            continue
        end
        
        local basePos = data.basePos
        -- Fast squared distance check (no square root)
        local dx = playerPos.X - basePos.X
        local dz = playerPos.Z - basePos.Z
        local distSq = dx * dx + dz * dz
        
        if distSq <= ANIM_RANGE_SQ then
            local hoverOffset = Vector3.new(0, math.sin(timePassed * 2) * 0.3, 0)
            local newCFrame
            
            if data.isCash then
                newCFrame = CFrame.new(basePos + hoverOffset) * CFrame.Angles(0, timePassed * 2, 0)
            else
                newCFrame = CFrame.new(basePos + hoverOffset) * CFrame.Angles(0, timePassed * 1.5, 0)
            end
            
            if obj:IsA("Model") then
                obj:PivotTo(newCFrame)
            elseif obj:IsA("BasePart") then
                obj.CFrame = newCFrame
            end
        end
    end
    
    -- Animate keys
    for obj, data in pairs(trackedKeys) do
        if not obj.Parent then
            trackedKeys[obj] = nil
            continue
        end
        
        local basePos = data.basePos
        local dx = playerPos.X - basePos.X
        local dz = playerPos.Z - basePos.Z
        local distSq = dx * dx + dz * dz
        
        if distSq <= ANIM_RANGE_SQ then
            local hoverOffset = Vector3.new(0, math.sin(timePassed * 2) * 0.3, 0)
            local newCFrame = CFrame.new(basePos + hoverOffset) * CFrame.Angles(0, timePassed * 1.5, 0)
            obj:PivotTo(newCFrame)
        end
    end
end)
