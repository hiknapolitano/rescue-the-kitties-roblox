local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local player = Players.LocalPlayer

-- Clean up any existing billboard
local existingUI = player:WaitForChild("PlayerGui"):FindFirstChild("StaminaBillboard")
if existingUI then
    existingUI:Destroy()
end

-- Create BillboardGui above player
local billboard = Instance.new("BillboardGui")
billboard.Name = "StaminaBillboard"
billboard.Size = UDim2.new(0, 50, 0, 8) -- Made it pretty small
billboard.StudsOffset = Vector3.new(0, 2.2, 0) -- Just above head
billboard.AlwaysOnTop = true
billboard.MaxDistance = 50
billboard.ResetOnSpawn = false

-- Background bar
local bgFrame = Instance.new("Frame")
bgFrame.Size = UDim2.new(1, 0, 1, 0)
bgFrame.BackgroundColor3 = Color3.new(0, 0, 0)
bgFrame.BackgroundTransparency = 0.5
bgFrame.BorderSizePixel = 0
local cornerBg = Instance.new("UICorner")
cornerBg.CornerRadius = UDim.new(1, 0)
cornerBg.Parent = bgFrame
bgFrame.Parent = billboard

-- Fill bar
local fillFrame = Instance.new("Frame")
fillFrame.Size = UDim2.new(1, 0, 1, 0)
fillFrame.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
fillFrame.BorderSizePixel = 0
local cornerFill = Instance.new("UICorner")
cornerFill.CornerRadius = UDim.new(1, 0)
cornerFill.Parent = fillFrame
fillFrame.Parent = bgFrame

billboard.Parent = player:WaitForChild("PlayerGui")
billboard.Enabled = false -- Start hidden

-- Cache head reference to avoid FindFirstChild every frame
local cachedHead = nil

local function refreshStaminaCache()
    local char = player.Character
    if char then
        cachedHead = char:FindFirstChild("Head")
        if cachedHead then
            billboard.Adornee = cachedHead
        end
    end
end

player.CharacterAdded:Connect(function(char)
    cachedHead = nil
    billboard.Adornee = nil
    -- Wait for head to load
    local head = char:WaitForChild("Head", 10)
    if head then
        cachedHead = head
        billboard.Adornee = head
    end
end)
refreshStaminaCache()

-- Update stamina bar reactively via attribute change signal (not 60fps polling)
local function updateStaminaBar()
    local stamina = player:GetAttribute("Stamina") or Constants.StaminaMax
    local pct = math.clamp(stamina / Constants.StaminaMax, 0, 1)
    
    -- Hide if full, show if not
    billboard.Enabled = (pct < 0.99)
    
    fillFrame.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
    fillFrame.Size = UDim2.new(pct, 0, 1, 0)
end

player:GetAttributeChangedSignal("Stamina"):Connect(updateStaminaBar)
