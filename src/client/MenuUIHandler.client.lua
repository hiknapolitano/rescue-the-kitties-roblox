local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local mainHud = playerGui:WaitForChild("MainHUD")

-- Settings & Help Buttons Container (Top Right)
local topMenu = Instance.new("Frame")
topMenu.Name = "TopMenu"
topMenu.Size = UDim2.new(0, 120, 0, 50)
topMenu.AnchorPoint = Vector2.new(1, 0)
topMenu.Position = UDim2.new(1, -20, 0, 20)
topMenu.BackgroundTransparency = 1
topMenu.Parent = mainHud

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 10)
layout.Parent = topMenu

-- Helper to create rounded, glassmorphism buttons
local function createButton(text, parent)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 50, 0, 50)
    btn.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    btn.BackgroundTransparency = 0.3
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.FredokaOne
    btn.TextSize = 24
    btn.AutoLocalize = true
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0) -- Perfect circle
    corner.Parent = btn
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(200, 200, 220)
    stroke.Thickness = 2
    stroke.Transparency = 0.5
    stroke.Parent = btn
    
    btn.Parent = parent
    return btn
end

local helpBtn = createButton("?", topMenu)
local settingsBtn = createButton("⚙️", topMenu)

-- Helper to create Premium Popups
local function createPopup(titleText)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.new(0, 0, 0)
    frame.BackgroundTransparency = 0.6
    frame.Visible = false
    frame.Parent = mainHud
    
    local panel = Instance.new("Frame")
    -- Responsive sizing: max 600x500, but scales down on smaller screens
    panel.Size = UDim2.new(0.8, 0, 0.8, 0)
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.new(0.5, 0, 0.5, 0)
    panel.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    panel.BackgroundTransparency = 0.1 -- Glass effect
    
    local constraint = Instance.new("UISizeConstraint")
    constraint.MaxSize = Vector2.new(600, 500)
    constraint.Parent = panel
    
    local aspect = Instance.new("UIAspectRatioConstraint")
    aspect.AspectRatio = 1.2
    aspect.Parent = panel
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = panel
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(100, 100, 150)
    stroke.Thickness = 1
    stroke.Transparency = 0.3
    stroke.Parent = panel
    
    panel.Parent = frame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0.15, 0)
    title.BackgroundTransparency = 1
    title.Text = titleText
    title.TextColor3 = Color3.fromRGB(230, 230, 250)
    title.Font = Enum.Font.FredokaOne
    title.TextSize = 32
    title.AutoLocalize = true
    title.Parent = panel
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 40, 0, 40)
    closeBtn.AnchorPoint = Vector2.new(1, 0)
    closeBtn.Position = UDim2.new(1, -15, 0, 15)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.BackgroundTransparency = 0.2
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.Font = Enum.Font.FredokaOne
    closeBtn.TextSize = 24
    closeBtn.MouseButton1Click:Connect(function()
        frame.Visible = false
        GuiService.SelectedObject = nil
        GuiService.AutoSelectGuiEnabled = false
    end)
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0.5, 0)
    closeCorner.Parent = closeBtn
    closeBtn.Parent = panel
    
    local contentLayout = Instance.new("UIListLayout")
    contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    contentLayout.Padding = UDim.new(0, 15)
    contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    
    local content = Instance.new("ScrollingFrame")
    content.Size = UDim2.new(1, -40, 0.8, -10)
    content.Position = UDim2.new(0, 20, 0.15, 0)
    content.BackgroundTransparency = 1
    content.ScrollBarThickness = 4
    content.ScrollBarImageColor3 = Color3.fromRGB(150, 150, 200)
    contentLayout.Parent = content
    content.Parent = panel
    
    return frame, content, closeBtn
end

local settingsPopup, settingsContent, settingsCloseBtn = createPopup("Settings")
local helpPopup, helpContent, helpCloseBtn = createPopup("Help")

settingsBtn.MouseButton1Click:Connect(function()
    settingsPopup.Visible = true
    GuiService.AutoSelectGuiEnabled = true
    GuiService.SelectedObject = settingsCloseBtn
end)

helpBtn.MouseButton1Click:Connect(function()
    helpPopup.Visible = true
    GuiService.AutoSelectGuiEnabled = true
    GuiService.SelectedObject = helpCloseBtn
end)

-- Volume Slider
local function createSlider(text, attributeName, parent)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -40, 0, 60)
    frame.BackgroundTransparency = 1
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.4, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Font = Enum.Font.FredokaOne
    label.TextSize = 20
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.AutoLocalize = true
    label.Parent = frame
    
    local sliderBar = Instance.new("Frame")
    sliderBar.Size = UDim2.new(0.5, 0, 0, 10)
    sliderBar.AnchorPoint = Vector2.new(1, 0.5)
    sliderBar.Position = UDim2.new(1, -10, 0.5, 0)
    sliderBar.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(1, 0)
    barCorner.Parent = sliderBar
    sliderBar.Parent = frame
    
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill
    fill.Parent = sliderBar
    
    local knob = Instance.new("TextButton")
    knob.Size = UDim2.new(0, 24, 0, 24)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(0, 0, 0.5, 0)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.Text = ""
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(0.5, 0)
    knobCorner.Parent = knob
    knob.Parent = sliderBar
    
    local isDragging = false
    
    local function updateVisuals()
        local val = player:GetAttribute(attributeName) or 1
        fill.Size = UDim2.new(val, 0, 1, 0)
        knob.Position = UDim2.new(val, 0, 0.5, 0)
    end
    
    local function setPercent(input)
        local pos = input.Position.X
        local start = sliderBar.AbsolutePosition.X
        local size = sliderBar.AbsoluteSize.X
        local pct = math.clamp((pos - start) / size, 0, 1)
        player:SetAttribute(attributeName, pct)
        updateVisuals()
    end
    
    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            setPercent(input)
        end
    end)
    
    -- Also allow clicking on the bar
    sliderBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            setPercent(input)
            isDragging = true
        end
    end)
    
    updateVisuals()
    player:GetAttributeChangedSignal(attributeName):Connect(updateVisuals)
    
    frame.Parent = parent
end

createSlider("Music Volume", "MusicVolume", settingsContent)
createSlider("SFX Volume", "SFXVolume", settingsContent)

-- Quality / Performance Segmented Toggle
local function createSegmentToggle(parent)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -40, 0, 60)
    frame.BackgroundTransparency = 1
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.4, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "Graphics Mode"
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Font = Enum.Font.FredokaOne
    label.TextSize = 20
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.AutoLocalize = true
    label.Parent = frame
    
    local container = Instance.new("Frame")
    container.Size = UDim2.new(0.5, 0, 0, 40)
    container.AnchorPoint = Vector2.new(1, 0.5)
    container.Position = UDim2.new(1, -10, 0.5, 0)
    container.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = UDim.new(0.5, 0)
    cCorner.Parent = container
    container.Parent = frame
    
    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.new(0.5, 0, 1, 0)
    indicator.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
    local iCorner = Instance.new("UICorner")
    iCorner.CornerRadius = UDim.new(0.5, 0)
    iCorner.Parent = indicator
    indicator.Parent = container
    
    local qBtn = Instance.new("TextButton")
    qBtn.Size = UDim2.new(0.5, 0, 1, 0)
    qBtn.BackgroundTransparency = 1
    qBtn.Text = "Quality"
    qBtn.TextColor3 = Color3.fromRGB(30, 30, 40)
    qBtn.Font = Enum.Font.FredokaOne
    qBtn.TextSize = 16
    qBtn.Parent = container
    
    local pBtn = Instance.new("TextButton")
    pBtn.Size = UDim2.new(0.5, 0, 1, 0)
    pBtn.Position = UDim2.new(0.5, 0, 0, 0)
    pBtn.BackgroundTransparency = 1
    pBtn.Text = "Fast"
    pBtn.TextColor3 = Color3.new(1, 1, 1)
    pBtn.Font = Enum.Font.FredokaOne
    pBtn.TextSize = 16
    pBtn.Parent = container
    
    local function updateVisuals()
        local isPerf = player:GetAttribute("PerformanceMode")
        if isPerf then
            TweenService:Create(indicator, TweenInfo.new(0.2), {Position = UDim2.new(0.5, 0, 0, 0)}):Play()
            qBtn.TextColor3 = Color3.new(1, 1, 1)
            pBtn.TextColor3 = Color3.fromRGB(30, 30, 40)
        else
            TweenService:Create(indicator, TweenInfo.new(0.2), {Position = UDim2.new(0, 0, 0, 0)}):Play()
            qBtn.TextColor3 = Color3.fromRGB(30, 30, 40)
            pBtn.TextColor3 = Color3.new(1, 1, 1)
        end
    end
    
    qBtn.MouseButton1Click:Connect(function()
        player:SetAttribute("PerformanceMode", false)
        updateVisuals()
    end)
    
    pBtn.MouseButton1Click:Connect(function()
        player:SetAttribute("PerformanceMode", true)
        updateVisuals()
    end)
    
    updateVisuals()
    frame.Parent = parent
end

createSegmentToggle(settingsContent)

-- Gamepad Vibration On/Off Toggle (same style as graphics toggle)
local function createVibrationToggle(parent)
    player:SetAttribute("GamepadVibrationEnabled", true) -- Default on

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -40, 0, 60)
    frame.BackgroundTransparency = 1

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.4, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "Vibration"
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Font = Enum.Font.FredokaOne
    label.TextSize = 20
    label.Parent = frame

    local container = Instance.new("Frame")
    container.Size = UDim2.new(0.5, 0, 0, 40)
    container.AnchorPoint = Vector2.new(1, 0.5)
    container.Position = UDim2.new(1, -10, 0.5, 0)
    container.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = UDim.new(0.5, 0)
    cCorner.Parent = container
    container.Parent = frame

    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.new(0.5, 0, 1, 0)
    indicator.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
    local iCorner = Instance.new("UICorner")
    iCorner.CornerRadius = UDim.new(0.5, 0)
    iCorner.Parent = indicator
    indicator.Parent = container

    local onBtn = Instance.new("TextButton")
    onBtn.Size = UDim2.new(0.5, 0, 1, 0)
    onBtn.BackgroundTransparency = 1
    onBtn.Text = "On"
    onBtn.TextColor3 = Color3.fromRGB(30, 30, 40)
    onBtn.Font = Enum.Font.FredokaOne
    onBtn.TextSize = 16
    onBtn.Parent = container

    local offBtn = Instance.new("TextButton")
    offBtn.Size = UDim2.new(0.5, 0, 1, 0)
    offBtn.Position = UDim2.new(0.5, 0, 0, 0)
    offBtn.BackgroundTransparency = 1
    offBtn.Text = "Off"
    offBtn.TextColor3 = Color3.new(1, 1, 1)
    offBtn.Font = Enum.Font.FredokaOne
    offBtn.TextSize = 16
    offBtn.Parent = container

    local function updateVibVisuals()
        local isOn = player:GetAttribute("GamepadVibrationEnabled")
        if isOn then
            TweenService:Create(indicator, TweenInfo.new(0.2), {Position = UDim2.new(0, 0, 0, 0)}):Play()
            onBtn.TextColor3 = Color3.fromRGB(30, 30, 40)
            offBtn.TextColor3 = Color3.new(1, 1, 1)
        else
            TweenService:Create(indicator, TweenInfo.new(0.2), {Position = UDim2.new(0.5, 0, 0, 0)}):Play()
            onBtn.TextColor3 = Color3.new(1, 1, 1)
            offBtn.TextColor3 = Color3.fromRGB(30, 30, 40)
        end
    end

    onBtn.MouseButton1Click:Connect(function()
        player:SetAttribute("GamepadVibrationEnabled", true)
        updateVibVisuals()
    end)
    offBtn.MouseButton1Click:Connect(function()
        player:SetAttribute("GamepadVibrationEnabled", false)
        updateVibVisuals()
    end)

    updateVibVisuals()
    frame.Parent = parent
end

createVibrationToggle(settingsContent)

local credits = Instance.new("TextLabel")
credits.Size = UDim2.new(1, 0, 0, 40)
credits.BackgroundTransparency = 1
credits.Text = "This game was created by beabadoobeelson"
credits.TextColor3 = Color3.fromRGB(150, 150, 170)
credits.Font = Enum.Font.FredokaOne
credits.TextSize = 14
credits.TextWrapped = true
credits.Parent = settingsContent

-- Populating Help
local function createHelpText(text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Font = Enum.Font.FredokaOne
    label.TextSize = 16
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.RichText = true
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.Parent = helpContent
end

local function formatBtn(txt)
    return '<font color="#FFD700"><b>[' .. txt .. ']</b></font>'
end

createHelpText("<b><font size=\"20\">Objective:</font></b>\nRescue all 13 cats from the maze, find keys to open doors, and then the final door will open!")
createHelpText("\n<b><font size=\"20\">Hazards & HP:</font></b>\nSpikes, Lava, and Evil Dogs deal damage. Keep an eye on your HP bar (❤️)! If you drop to 0 HP, you will die.")
createHelpText("\n<b><font size=\"20\">Items & Coins:</font></b>\nCollect coins to buy useful items in the shop. Buy Bandages to restore your HP, or upgrades to gain advantages like seeing through walls and escaping dogs!")
createHelpText("\n<b><font size=\"20\">Stars:</font></b>\nThe faster you collect all cats and return to the Safe Zone, the more stars you earn.")

local controlsText = Instance.new("TextLabel")
controlsText.Size = UDim2.new(1, -20, 0, 0)
controlsText.BackgroundTransparency = 1
controlsText.Text = ""
controlsText.TextColor3 = Color3.fromRGB(220, 230, 255)
controlsText.Font = Enum.Font.FredokaOne
controlsText.TextSize = 16
controlsText.TextWrapped = true
controlsText.TextXAlignment = Enum.TextXAlignment.Left
controlsText.RichText = true
controlsText.AutomaticSize = Enum.AutomaticSize.Y
controlsText.Parent = helpContent

local function updateControlsText()
    local hasGamepad = UserInputService:GetGamepadConnected(Enum.UserInputType.Gamepad1)
    local hasTouch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

    local txt = "\n<b><font size=\"20\">Controls:</font></b>\n"
    if hasGamepad then
        txt = txt .. "• Move: " .. formatBtn("L-STICK") .. "\n"
        txt = txt .. "• Look: " .. formatBtn("R-STICK") .. "\n"
        txt = txt .. "• Sprint: " .. formatBtn("R2") .. " (Right Trigger)\n"
        txt = txt .. "• Use Item: " .. formatBtn("B / Circle") .. "\n"
        txt = txt .. "• Cycle Items: " .. formatBtn("L1") .. " / " .. formatBtn("R1") .. "\n"
        txt = txt .. "• Interact: " .. formatBtn("X / Square") .. "\n"
        txt = txt .. "• Settings: " .. formatBtn("START") .. "\n"
        txt = txt .. "• Map Zoom In: " .. formatBtn("DPad UP") .. "\n"
        txt = txt .. "• Map Zoom Out: " .. formatBtn("DPad DOWN")
    elseif hasTouch then
        txt = txt .. "• Move: " .. formatBtn("L-JOYSTICK") .. "\n"
        txt = txt .. "• Look: " .. formatBtn("Drag Screen") .. "\n"
        txt = txt .. "• Sprint: " .. formatBtn("Sprint Button") .. "\n"
        txt = txt .. "• Use Item: " .. formatBtn("Tap Item") .. "\n"
        txt = txt .. "• Interact: " .. formatBtn("Tap Prompt") .. "\n"
        txt = txt .. "• Map Zoom: " .. formatBtn("Tap +/-")
    else
        txt = txt .. "• Move: " .. formatBtn("W A S D") .. "\n"
        txt = txt .. "• Look: " .. formatBtn("Mouse") .. "\n"
        txt = txt .. "• Sprint: " .. formatBtn("SHIFT") .. "\n"
        txt = txt .. "• Use Item: " .. formatBtn("1-9") .. " or " .. formatBtn("Click") .. "\n"
        txt = txt .. "• Interact: " .. formatBtn("E") .. "\n"
        txt = txt .. "• Map Zoom: " .. formatBtn("Click +/-")
    end
    controlsText.Text = txt
end

updateControlsText()
UserInputService.GamepadConnected:Connect(updateControlsText)
UserInputService.GamepadDisconnected:Connect(updateControlsText)

-- Start / Options button opens Settings popup
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.ButtonStart then
        if settingsPopup.Visible then
            settingsPopup.Visible = false
            GuiService.SelectedObject = nil
            GuiService.AutoSelectGuiEnabled = false
        else
            settingsPopup.Visible = true
            GuiService.AutoSelectGuiEnabled = true
            GuiService.SelectedObject = settingsCloseBtn
        end
    end
end)
