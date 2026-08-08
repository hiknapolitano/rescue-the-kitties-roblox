local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local SoundManager = require(Shared:WaitForChild("SoundManager"))
local TranslationHelper = require(Shared:WaitForChild("TranslationHelper"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local showWinScreenRemote = remotes:WaitForChild("ShowWinScreen")
local respawnPlayerRemote = remotes:WaitForChild("RespawnPlayer")

local function formatTime(seconds)
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d", mins, secs)
end

showWinScreenRemote.OnClientEvent:Connect(function(totalSeconds, stars)
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "WinScreen"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    
    local background = Instance.new("Frame")
    background.Size = UDim2.new(1, 0, 1, 0)
    background.BackgroundColor3 = Color3.new(0, 0, 0)
    background.BackgroundTransparency = 1
    background.Parent = screenGui
    
    local mainPanel = Instance.new("Frame")
    mainPanel.Size = UDim2.new(0, 500, 0, 420)
    mainPanel.Position = UDim2.new(0.5, -250, 0.5, -100)
    mainPanel.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    mainPanel.BorderSizePixel = 0
    mainPanel.ClipsDescendants = false
    
    local uicorner = Instance.new("UICorner")
    uicorner.CornerRadius = UDim.new(0, 20)
    uicorner.Parent = mainPanel
    
    local panelStroke = Instance.new("UIStroke")
    panelStroke.Color = Color3.fromRGB(60, 60, 70)
    panelStroke.Thickness = 2
    panelStroke.Parent = mainPanel
    
    mainPanel.Parent = background
    
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 30)
    padding.PaddingBottom = UDim.new(0, 30)
    padding.Parent = mainPanel
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 15)
    listLayout.Parent = mainPanel
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 0, 50)
    title.BackgroundTransparency = 1
    title.Text = TranslationHelper.translate("YOU WON!")
    title.TextColor3 = Color3.fromRGB(255, 215, 0)
    title.Font = Enum.Font.FredokaOne
    title.TextSize = 48
    title.AutoLocalize = true
    title.LayoutOrder = 1
    title.Parent = mainPanel
    
    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -40, 0, 80)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = TranslationHelper.translate("You rescued all the kittens safely!")
    subtitle.TextColor3 = Color3.new(1, 1, 1)
    subtitle.Font = Enum.Font.Nunito
    subtitle.TextSize = 22
    subtitle.AutoLocalize = true
    subtitle.TextWrapped = true
    subtitle.LayoutOrder = 2
    subtitle.Parent = mainPanel
    
    local timeLabel = Instance.new("TextLabel")
    timeLabel.Size = UDim2.new(1, -40, 0, 40)
    timeLabel.BackgroundTransparency = 1
    timeLabel.Text = "⏱️ " .. TranslationHelper.translate("Time:") .. " " .. formatTime(totalSeconds)
    timeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    timeLabel.Font = Enum.Font.GothamBold
    timeLabel.TextSize = 24
    timeLabel.LayoutOrder = 3
    timeLabel.Parent = mainPanel
    
    local starsFrame = Instance.new("Frame")
    starsFrame.Size = UDim2.new(0, 300, 0, 60)
    starsFrame.BackgroundTransparency = 1
    starsFrame.LayoutOrder = 4
    starsFrame.Parent = mainPanel
    
    local starLayout = Instance.new("UIListLayout")
    starLayout.FillDirection = Enum.FillDirection.Horizontal
    starLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    starLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    starLayout.Padding = UDim.new(0, 10)
    starLayout.Parent = starsFrame
    
    for i=1, 5 do
        local star = Instance.new("TextLabel")
        star.Size = UDim2.new(0, 50, 0, 50)
        star.BackgroundTransparency = 1
        star.Text = "★"
        star.TextScaled = true
        if i <= stars then
            star.TextColor3 = Color3.fromRGB(255, 215, 0)
            star.TextTransparency = 0
            
            local glow = Instance.new("UIStroke")
            glow.Color = Color3.fromRGB(255, 215, 0)
            glow.Thickness = 1
            glow.Transparency = 0.5
            glow.Parent = star
        else
            star.TextColor3 = Color3.fromRGB(80, 80, 85)
            star.TextTransparency = 0.5
        end
        star.Parent = starsFrame
    end
    
    -- Spacer
    local spacer = Instance.new("Frame")
    spacer.Size = UDim2.new(1, 0, 0, 10)
    spacer.BackgroundTransparency = 1
    spacer.LayoutOrder = 5
    spacer.Parent = mainPanel
    
    local playButton = Instance.new("TextButton")
    playButton.Size = UDim2.new(0, 240, 0, 55)
    playButton.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
    playButton.Text = TranslationHelper.translate("OK")
    playButton.TextColor3 = Color3.new(1, 1, 1)
    playButton.Font = Enum.Font.FredokaOne
    playButton.TextSize = 24
    playButton.AutoLocalize = true
    playButton.LayoutOrder = 6
    playButton.Parent = mainPanel
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 12)
    btnCorner.Parent = playButton
    
    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = Color3.fromRGB(39, 174, 96)
    btnStroke.Thickness = 3
    btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    btnStroke.Parent = playButton
    
    screenGui.Parent = playerGui
    
    -- Animations
    TweenService:Create(background, TweenInfo.new(1), {BackgroundTransparency = 0.5}):Play()
    TweenService:Create(mainPanel, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, -250, 0.5, -200)}):Play()
    
    playButton.MouseButton1Click:Connect(function()
        SoundManager.playClick(Constants.Sounds.ShopBuy)
        GuiService.SelectedObject = nil
        GuiService.AutoSelectGuiEnabled = false
        screenGui:Destroy()
        
        local resetWinStateRemote = remotes:FindFirstChild("ResetWinStateRemote")
        if not resetWinStateRemote then
            resetWinStateRemote = Instance.new("RemoteEvent")
            resetWinStateRemote.Name = "ResetWinStateRemote"
            resetWinStateRemote.Parent = remotes
        end
        resetWinStateRemote:FireServer()
    end)
    
    SoundManager.playSound(Constants.Sounds.GameWin, playerGui)
    
    GuiService.AutoSelectGuiEnabled = true
    GuiService.SelectedObject = playButton
end)

-- Update the Final Portal Cat Counter dynamically
local function findCatCounterGui()
    local doorsFolder = workspace:FindFirstChild("Doors")
    if not doorsFolder then return nil end
    local finalDoor = doorsFolder:FindFirstChild("FinalDoor")
    if not finalDoor then return nil end
    return finalDoor:FindFirstChild("CatCounterGui", true)
end

local function updateCatCounter()
    local rescued = player:GetAttribute("CatsRescued") or 0
    local total = Constants.TotalCats
    local text = rescued .. "/" .. total
    local hasGreenKey = player:GetAttribute("HasGreenKey")
    
    local gui = findCatCounterGui()
    if gui then
        -- Only show when green key has been collected (FinalDoor is accessible)
        gui.Enabled = hasGreenKey == true
        local tl = gui:FindFirstChildWhichIsA("TextLabel")
        if tl then tl.Text = text end
    end
end

player:GetAttributeChangedSignal("CatsRescued"):Connect(updateCatCounter)

-- Also show/hide when GreenKey is picked up
player:GetAttributeChangedSignal("HasGreenKey"):Connect(updateCatCounter)

-- Run once after maze is ready
task.spawn(function()
    if not workspace:GetAttribute("MazeGenerated") then
        workspace:GetAttributeChangedSignal("MazeGenerated"):Wait()
    end
    task.wait(1) -- allow Doors folder to populate
    updateCatCounter()
end)

workspace.DescendantAdded:Connect(function(desc)
    if desc:IsA("TextLabel") and desc.Parent and desc.Parent.Name == "CatCounterGui" then
        local rescued = player:GetAttribute("CatsRescued") or 0
        desc.Text = rescued .. "/" .. Constants.TotalCats
        -- Also set Enabled state on the gui itself
        local gui = desc.Parent
        gui.Enabled = player:GetAttribute("HasGreenKey") == true
    end
end)
