local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local SoundManager = require(Shared:WaitForChild("SoundManager"))

-- Clean up existing
local oldScreen = playerGui:FindFirstChild("DeathScreen")
if oldScreen then oldScreen:Destroy() end

local deathScreen = Instance.new("ScreenGui")
deathScreen.Name = "DeathScreen"
deathScreen.ResetOnSpawn = false
deathScreen.DisplayOrder = 100 -- Ensure it's on top of HUD and Minimap
deathScreen.Parent = playerGui

local frame = Instance.new("Frame")
frame.Name = "Frame"
frame.Size = UDim2.new(1, 0, 1, 0)
frame.BackgroundColor3 = Color3.new(0, 0, 0)
frame.BackgroundTransparency = 0.2
frame.Visible = false
frame.Parent = deathScreen

-- Add a red vignette effect using UI gradient
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.new(0, 0, 0)),
    ColorSequenceKeypoint.new(0.5, Color3.new(0.2, 0, 0)),
    ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0))
})
gradient.Rotation = 90
gradient.Parent = frame

local centerPanel = Instance.new("Frame")
centerPanel.Size = UDim2.new(0, 450, 0, 300)
centerPanel.AnchorPoint = Vector2.new(0.5, 0.5)
centerPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
centerPanel.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
centerPanel.BackgroundTransparency = 0.1
local centerCorner = Instance.new("UICorner")
centerCorner.CornerRadius = UDim.new(0, 12)
centerCorner.Parent = centerPanel
local centerStroke = Instance.new("UIStroke")
centerStroke.Color = Color3.fromRGB(200, 0, 0)
centerStroke.Thickness = 3
centerStroke.Parent = centerPanel
centerPanel.Parent = frame

local message = Instance.new("TextLabel")
message.Name = "Message"
message.Size = UDim2.new(1, 0, 0, 80)
message.Position = UDim2.new(0, 0, 0, 10)
message.Text = "💀 YOU DIED!"
message.TextSize = 36
message.Font = Enum.Font.FredokaOne
message.AutoLocalize = true
message.TextColor3 = Color3.new(1, 0.2, 0.2)
message.BackgroundTransparency = 1
message.Parent = centerPanel

local reviveButton = Instance.new("TextButton")
reviveButton.Name = "ReviveButton"
reviveButton.Size = UDim2.new(0, 350, 0, 60)
reviveButton.AnchorPoint = Vector2.new(0.5, 0)
reviveButton.Position = UDim2.new(0.5, 0, 0, 110)
reviveButton.Text = "✨ Heal myself"
reviveButton.Font = Enum.Font.FredokaOne
reviveButton.TextSize = 26
reviveButton.AutoLocalize = true
reviveButton.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
reviveButton.TextColor3 = Color3.new(1, 1, 1)
local corner1 = Instance.new("UICorner")
corner1.CornerRadius = UDim.new(0, 8)
corner1.Parent = reviveButton
reviveButton.Parent = centerPanel

local tryAgainButton = Instance.new("TextButton")
tryAgainButton.Name = "TryAgainButton"
tryAgainButton.Size = UDim2.new(0, 350, 0, 60)
tryAgainButton.AnchorPoint = Vector2.new(0.5, 0)
tryAgainButton.Position = UDim2.new(0.5, 0, 0, 190)
tryAgainButton.Text = "💀 Try again"
tryAgainButton.Font = Enum.Font.FredokaOne
tryAgainButton.TextSize = 26
tryAgainButton.AutoLocalize = true
tryAgainButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
tryAgainButton.TextColor3 = Color3.new(1, 1, 1)
local corner2 = Instance.new("UICorner")
corner2.CornerRadius = UDim.new(0, 8)
corner2.Parent = tryAgainButton
tryAgainButton.Parent = centerPanel

-- Handle remotes
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local playerCaughtRemote = remotesFolder:WaitForChild("PlayerCaught")
local respawnPlayerRemote = remotesFolder:WaitForChild("RespawnPlayer")

local revivePlayerRemote = remotesFolder:FindFirstChild("RevivePlayer")
if not revivePlayerRemote then
    revivePlayerRemote = Instance.new("RemoteEvent")
    revivePlayerRemote.Name = "RevivePlayer"
    revivePlayerRemote.Parent = remotesFolder
end

playerCaughtRemote.OnClientEvent:Connect(function(deathReason)
    if deathReason == "Lava" or deathReason == "FireTree" then
        message.Text = "💀 YOU BURNED!"
        centerStroke.Color = Color3.fromRGB(255, 100, 0)
        message.TextColor3 = Color3.fromRGB(255, 150, 50)
    elseif deathReason == "Spikes" then
        message.Text = "💀 IMPALED!"
        centerStroke.Color = Color3.fromRGB(200, 0, 0)
        message.TextColor3 = Color3.new(1, 0.2, 0.2)
    elseif deathReason == "Dogs" then
        message.Text = "💀 YOU WERE CAUGHT!"
        centerStroke.Color = Color3.fromRGB(200, 0, 0)
        message.TextColor3 = Color3.new(1, 0.2, 0.2)
    else
        message.Text = "💀 YOU DIED!"
        centerStroke.Color = Color3.fromRGB(200, 0, 0)
        message.TextColor3 = Color3.new(1, 0.2, 0.2)
    end
    frame.Visible = true
    
    GuiService.AutoSelectGuiEnabled = true
    GuiService.SelectedObject = tryAgainButton
end)

tryAgainButton.MouseButton1Click:Connect(function()
    SoundManager.playClick(Constants.Sounds.ShopBuy)
    frame.Visible = false
    GuiService.SelectedObject = nil
    GuiService.AutoSelectGuiEnabled = false
    respawnPlayerRemote:FireServer()
end)

reviveButton.MouseButton1Click:Connect(function()
    SoundManager.playClick(Constants.Sounds.ShopBuy)
    if Constants.FreePurchaseWhitelist and table.find(Constants.FreePurchaseWhitelist, player.Name) then
        local freePurchaseRemote = remotesFolder:FindFirstChild("FreePurchaseRequested")
        if freePurchaseRemote then
            freePurchaseRemote:FireServer(Constants.ReviveProductId)
        end
    elseif Constants.ReviveProductId > 0 then
        MarketplaceService:PromptProductPurchase(player, Constants.ReviveProductId)
    else
        warn("ReviveProductId not set in Constants! Cannot prompt purchase.")
    end
end)

revivePlayerRemote.OnClientEvent:Connect(function()
    frame.Visible = false
    GuiService.SelectedObject = nil
    GuiService.AutoSelectGuiEnabled = false
    
    local char = player.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if (part:IsA("BasePart") or part:IsA("Decal")) and part.Name ~= "HumanoidRootPart" then
                part.Transparency = 0
            end
        end
    end
end)

player.CharacterAdded:Connect(function()
    frame.Visible = false
    GuiService.SelectedObject = nil
    GuiService.AutoSelectGuiEnabled = false
end)
