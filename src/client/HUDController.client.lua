local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local SoundManager = require(Shared:WaitForChild("SoundManager"))
local Maps = require(Shared:WaitForChild("Maps"))
local HapticManager = require(Shared:WaitForChild("HapticManager"))
local TranslationHelper = require(Shared:WaitForChild("TranslationHelper"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Clean up existing HUD
local oldHud = playerGui:FindFirstChild("MainHUD")
if oldHud then oldHud:Destroy() end

local TweenService = game:GetService("TweenService")
local bgmInstance = SoundManager.playSound(Constants.Sounds.BackgroundMusic, playerGui, true)
if bgmInstance then
    bgmInstance.Name = "BackgroundMusic"
end
local bgmMuted = false

player:SetAttribute("MusicVolume", 1)
player:SetAttribute("SFXVolume", 1)
player:SetAttribute("PerformanceMode", false)

player:GetAttributeChangedSignal("MusicVolume"):Connect(function()
    if bgmInstance then
        local vol = player:GetAttribute("MusicVolume")
        local baseVol = Constants.Sounds.BackgroundMusic.Volume or 1
        bgmInstance.Volume = baseVol * vol
    end
end)

player:GetAttributeChangedSignal("SFXVolume"):Connect(function()
    -- Just store the new volume. SoundManager will apply it to new sounds.
    -- Existing short sounds will finish naturally at their original volume.
    -- This avoids the extremely expensive workspace:GetDescendants() scan.
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MainHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 10

-- Troll Everyone Button
local tCfg = Constants.TrollButtonConfig or {
    BaseSize = 78,
    HoverSize = 95,
    BobSpeed = 4,
    BobAmount = 0.05,
    TextColor = Color3.fromRGB(255, 255, 255),
    TextSize = 14
}

local trollButton = Instance.new("ImageButton")
trollButton.Name = "TrollButton"
trollButton.Size = UDim2.new(0, tCfg.BaseSize, 0, tCfg.BaseSize)
trollButton.AnchorPoint = Vector2.new(1, 0)
trollButton.Position = UDim2.new(1, -20, 0, 100)
trollButton.Image = Constants.TrollEveryoneIconId
trollButton.BackgroundTransparency = 0
trollButton.BackgroundColor3 = Color3.fromRGB(130, 40, 180)
local trollCorner = Instance.new("UICorner")
trollCorner.CornerRadius = UDim.new(0, 15)
trollCorner.Parent = trollButton
local trollBtnStroke = Instance.new("UIStroke")
trollBtnStroke.Color = Color3.fromRGB(255, 170, 0)
trollBtnStroke.Thickness = 3
trollBtnStroke.Parent = trollButton
trollButton.Parent = screenGui

local trollText = Instance.new("TextLabel")
trollText.Size = UDim2.new(1.5, 0, 0, 40)
trollText.Position = UDim2.new(1, 0, 1, tCfg.TextSpacing or 5)
trollText.AnchorPoint = Vector2.new(1, 0)
trollText.BackgroundTransparency = 1
trollText.Text = TranslationHelper.translate("TROLL everyone!")
trollText.TextColor3 = tCfg.TextColor
trollText.Font = Enum.Font.FredokaOne
trollText.TextSize = tCfg.TextSize
trollText.TextWrapped = true
trollText.TextXAlignment = Enum.TextXAlignment.Right
local textStroke = Instance.new("UIStroke")
textStroke.Color = Color3.new(0, 0, 0)
textStroke.Thickness = 2
textStroke.Parent = trollText
trollText.Parent = trollButton

local trollHovered = false
trollButton.MouseEnter:Connect(function()
    trollHovered = true
    TweenService:Create(trollButton, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, tCfg.HoverSize, 0, tCfg.HoverSize),
        BackgroundColor3 = Color3.fromRGB(160, 50, 220)
    }):Play()
end)

trollButton.MouseLeave:Connect(function()
    trollHovered = false
    TweenService:Create(trollButton, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, tCfg.BaseSize, 0, tCfg.BaseSize),
        BackgroundColor3 = Color3.fromRGB(130, 40, 180)
    }):Play()
end)

-- Bobbing animation: bobs for 10s, static for 20s, repeat
local BOB_DURATION = 10 -- seconds of bobbing
local STATIC_DURATION = 20 -- seconds of staying still
local BOB_CYCLE_TOTAL = BOB_DURATION + STATIC_DURATION
local trollBobTime = 0

RunService.Heartbeat:Connect(function(dt)
    trollBobTime = trollBobTime + dt
    local cycleTime = trollBobTime % BOB_CYCLE_TOTAL
    
    if not trollHovered and cycleTime < BOB_DURATION then
        local scale = 1 + math.sin(trollBobTime * tCfg.BobSpeed) * tCfg.BobAmount
        trollButton.Size = UDim2.new(0, tCfg.BaseSize * scale, 0, tCfg.BaseSize * scale)
    elseif not trollHovered then
        -- Static period: ensure base size
        trollButton.Size = UDim2.new(0, tCfg.BaseSize, 0, tCfg.BaseSize)
    end
end)

local MarketplaceService = game:GetService("MarketplaceService")
trollButton.MouseButton1Click:Connect(function()
    SoundManager.playSound(Constants.Sounds.ShopBuy, nil)
    if Constants.FreePurchaseWhitelist and table.find(Constants.FreePurchaseWhitelist, player.Name) then
        local remotes = ReplicatedStorage:WaitForChild("Remotes")
        local freePurchaseRemote = remotes:WaitForChild("FreePurchaseRequested")
        freePurchaseRemote:FireServer(Constants.TrollEveryoneProductId)
    else
        MarketplaceService:PromptProductPurchase(player, Constants.TrollEveryoneProductId)
    end
end)

-- Stats Panel (Bottom Left)
local statsPanel = Instance.new("Frame")
statsPanel.Name = "StatsPanel"
statsPanel.Size = UDim2.new(0, 300, 0, 100)
statsPanel.AnchorPoint = Vector2.new(0, 1)
statsPanel.Position = UDim2.new(0, 20, 1, -20)
statsPanel.BackgroundTransparency = 1
statsPanel.Parent = screenGui

local layoutStats = Instance.new("UIListLayout")
layoutStats.SortOrder = Enum.SortOrder.LayoutOrder
layoutStats.Padding = UDim.new(0, 10)
layoutStats.VerticalAlignment = Enum.VerticalAlignment.Bottom
layoutStats.Parent = statsPanel

local layoutTop = Instance.new("UIListLayout")
layoutTop.SortOrder = Enum.SortOrder.LayoutOrder
layoutTop.Padding = UDim.new(0, 10)
layoutTop.Parent = statsPanel

-- Timer Label
local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "TimerLabel"
timerLabel.Size = UDim2.new(1, 0, 0, 40)
timerLabel.BackgroundTransparency = 1
timerLabel.Text = "⏱️ 00:00"
timerLabel.TextColor3 = Color3.new(1, 1, 1)
timerLabel.TextSize = 24
timerLabel.Font = Enum.Font.FredokaOne
timerLabel.AutoLocalize = true
timerLabel.TextXAlignment = Enum.TextXAlignment.Left
local stroke2 = Instance.new("UIStroke")
stroke2.Thickness = 2
stroke2.Parent = timerLabel
timerLabel.Parent = statsPanel

-- Coins Label
local coinsLabel = Instance.new("TextLabel")
coinsLabel.Name = "CoinsLabel"
coinsLabel.Size = UDim2.new(1, 0, 0, 40)
coinsLabel.BackgroundTransparency = 1
coinsLabel.Text = "💰 0"
coinsLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
coinsLabel.TextSize = 24
coinsLabel.Font = Enum.Font.FredokaOne
coinsLabel.AutoLocalize = true
coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
local stroke3 = Instance.new("UIStroke")
stroke3.Thickness = 2
stroke3.Parent = coinsLabel
coinsLabel.Parent = statsPanel

-- Bottom Right Panel for Cats, Boat, Keys
local bottomRightPanel = Instance.new("Frame")
bottomRightPanel.Name = "BottomRightPanel"
bottomRightPanel.Size = UDim2.new(0, 300, 0, 150)
bottomRightPanel.AnchorPoint = Vector2.new(1, 1)
local isMobile = UserInputService.TouchEnabled
bottomRightPanel.Position = UDim2.new(1, -20, 1, isMobile and -140 or -20)
bottomRightPanel.BackgroundTransparency = 1
bottomRightPanel.Parent = screenGui

local layoutBottomRight = Instance.new("UIListLayout")
layoutBottomRight.SortOrder = Enum.SortOrder.LayoutOrder
layoutBottomRight.Padding = UDim.new(0, 10)
layoutBottomRight.VerticalAlignment = Enum.VerticalAlignment.Bottom
layoutBottomRight.HorizontalAlignment = Enum.HorizontalAlignment.Right
layoutBottomRight.Parent = bottomRightPanel

-- Cats Label
local catsLabel = Instance.new("TextLabel")
catsLabel.Name = "CatsLabel"
catsLabel.Size = UDim2.new(1, 0, 0, 40)
catsLabel.BackgroundTransparency = 1
catsLabel.Text = "🐱 0 / " .. Constants.TotalCats
catsLabel.TextColor3 = Color3.new(1, 1, 1)
catsLabel.TextSize = 28
catsLabel.Font = Enum.Font.FredokaOne
catsLabel.AutoLocalize = true
catsLabel.TextXAlignment = Enum.TextXAlignment.Right
local stroke1 = Instance.new("UIStroke")
stroke1.Thickness = 2
stroke1.Parent = catsLabel
catsLabel.Parent = bottomRightPanel

-- Bottom Right Panel
local bottomPanel = Instance.new("Frame")
bottomPanel.Name = "BottomPanel"
bottomPanel.Size = UDim2.new(0, 250, 0, 120)
bottomPanel.AnchorPoint = Vector2.new(1, 1)
bottomPanel.Position = UDim2.new(1, -20, 1, -20)
bottomPanel.BackgroundTransparency = 1
bottomPanel.Parent = screenGui

local layoutBottom = Instance.new("UIListLayout")
layoutBottom.SortOrder = Enum.SortOrder.LayoutOrder
layoutBottom.Padding = UDim.new(0, 15)
layoutBottom.VerticalAlignment = Enum.VerticalAlignment.Bottom
layoutBottom.Parent = bottomPanel

-- Helper for Bars
local function createBar(name, iconText, color)
    local container = Instance.new("Frame")
    container.Name = name .. "Container"
    container.Size = UDim2.new(1, 0, 0, 20)
    container.BackgroundTransparency = 1
    
    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(0, 35, 1, 0)
    icon.BackgroundTransparency = 1
    icon.Text = iconText
    icon.TextSize = 22
    icon.TextXAlignment = Enum.TextXAlignment.Left
    icon.Parent = container
    
    local barBg = Instance.new("Frame")
    barBg.Name = "BarBg"
    barBg.Size = UDim2.new(0, 100, 0, 8)
    barBg.Position = UDim2.new(0, 35, 0.5, -4)
    barBg.BackgroundColor3 = Color3.new(0, 0, 0)
    barBg.BackgroundTransparency = 0.5
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = barBg
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.new(1, 1, 1)
    stroke.Thickness = 1
    stroke.Parent = barBg
    
    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = color
    
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 8)
    fillCorner.Parent = fill
    fill.Parent = barBg
    barBg.Parent = container
    return container
end

local hpContainer = createBar("HP", "❤️", Color3.fromRGB(46, 204, 113))
hpContainer.Parent = statsPanel

screenGui.Parent = playerGui

-- Manage Timer and Cats updates
local startTime = nil
local gameActive = true

local function isCharacterInSafeZone(character)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local baseModel = workspace:FindFirstChild("Base")
    if not baseModel then return false end
    
    local overlapParams = OverlapParams.new()
    overlapParams.FilterDescendantsInstances = {baseModel}
    overlapParams.FilterType = Enum.RaycastFilterType.Include
    
    local partsInBox = workspace:GetPartBoundsInBox(hrp.CFrame, Vector3.new(4, 10, 4), overlapParams)
    return #partsInBox > 0
end

-- Coins: update via .Changed event instead of polling every frame
task.spawn(function()
    local ls = player:WaitForChild("leaderstats", 10)
    if ls then
        local coins = ls:WaitForChild("Coins", 10)
        if coins then
            local lastCoins = coins.Value
            coinsLabel.Text = "💰 " .. math.floor(coins.Value)
            coins.Changed:Connect(function()
                local newVal = math.floor(coins.Value)
                coinsLabel.Text = "💰 " .. newVal
                -- Haptic tap when coins increase (picked up coin/cash)
                if coins.Value > lastCoins then
                    pcall(function() HapticManager.lightTap() end)
                end
                lastCoins = coins.Value
            end)
        end
    end
end)

-- HP: update via attribute changed signal
local lastHP = Constants.MaximumHP
player:GetAttributeChangedSignal("HP"):Connect(function()
    local hpValue = player:GetAttribute("HP")
    if hpValue then
        if hpValue < lastHP then
            pcall(function() HapticManager.heavyRumble() end)
        end
        lastHP = hpValue
        hpContainer.Visible = true
        local flashBg = hpContainer:FindFirstChild("BarBg")
        if flashBg then
            local fill = flashBg:FindFirstChild("Fill")
            if fill then
                local pct = math.clamp(hpValue / Constants.MaximumHP, 0, 1)
                fill.Size = UDim2.new(pct, 0, 1, 0)
                if pct > 0.5 then
                    fill.BackgroundColor3 = Color3.fromRGB(46, 204, 113) -- Green
                elseif pct > 0.2 then
                    fill.BackgroundColor3 = Color3.fromRGB(241, 196, 15) -- Yellow
                else
                    fill.BackgroundColor3 = Color3.fromRGB(231, 76, 60) -- Red
                end
            end
        end
    end
end)

-- Background Music Ducking: driven by attribute signals, not polling
local function updateMusicDucking()
    local cats = player:GetAttribute("CatsRescued") or 0
    local allCatsCollected = (cats >= Constants.TotalCats)
    local shouldMute = player:GetAttribute("DogChasing") or player:GetAttribute("GameLost") or player:GetAttribute("GameWon") or allCatsCollected
    if shouldMute and not bgmMuted then
        bgmMuted = true
        if bgmInstance then
            TweenService:Create(bgmInstance, TweenInfo.new(1, Enum.EasingStyle.Linear), {Volume = 0}):Play()
        end
    elseif not shouldMute and bgmMuted then
        bgmMuted = false
        if bgmInstance then
            local userVol = player:GetAttribute("MusicVolume") or 1
            local targetVol = (Constants.Sounds.BackgroundMusic.Volume or 1) * userVol
            TweenService:Create(bgmInstance, TweenInfo.new(1, Enum.EasingStyle.Linear), {Volume = targetVol}):Play()
        end
    end
end

player:GetAttributeChangedSignal("DogChasing"):Connect(updateMusicDucking)
player:GetAttributeChangedSignal("GameLost"):Connect(updateMusicDucking)
player:GetAttributeChangedSignal("GameWon"):Connect(updateMusicDucking)
player:GetAttributeChangedSignal("CatsRescued"):Connect(updateMusicDucking)

-- Controller rumble while being chased: pulse every 0.3s as long as DogChasing is true
local chaseRumbleTask = nil
local function updateChaseRumble()
    local isChased = player:GetAttribute("DogChasing")
    if isChased then
        if not chaseRumbleTask then
            chaseRumbleTask = task.spawn(function()
                while player:GetAttribute("DogChasing") do
                    pcall(function() HapticManager.vibrate(0.5, 0.25, Enum.VibrationMotor.Large) end)
                    task.wait(0.3)
                end
                chaseRumbleTask = nil
            end)
        end
    else
        -- Let the loop exit naturally on next iteration
        chaseRumbleTask = nil
    end
end
player:GetAttributeChangedSignal("DogChasing"):Connect(updateChaseRumble)

-- Timer + Minimap: throttled to once per second
-- Minimap wall dots are cached since they never move
local cachedWallDots = {} -- {Frame instances}
local cachedMapBounds = nil
local dynamicDotsMap = {} -- Map of Workspace Object -> Minimap Frame
local minimapWallsBuilt = false

-- 1Hz Loop for Game Timer
task.spawn(function()
    while true do
        task.wait(1)
        
        if not gameActive then continue end
        
        -- Timer update (once per second is sufficient)
        local startTime = player:GetAttribute("StartTime")
        if startTime == nil then
            timerLabel.Text = "⏱️ 00:00"
        else
            local elapsed = os.time() - startTime
            local minutes = math.floor(elapsed / 60)
            local seconds = elapsed % 60
            timerLabel.Text = string.format("⏱️ %02d:%02d", minutes, seconds)
        end
    end
end)

-- Limit camera zoom distance so players cannot zoom out over walls
player.CameraMaxZoomDistance = Constants.CameraMaxZoomDistance or 30
player.CameraMinZoomDistance = Constants.CameraMinZoomDistance or 5

-- Cache player HRP for minimap (avoid FindFirstChild in render loop)
local cachedHudHrp = nil
local function refreshHudHrpCache()
    local char = player.Character
    cachedHudHrp = char and char:FindFirstChild("HumanoidRootPart")
end
player.CharacterAdded:Connect(function(char)
    cachedHudHrp = nil
    char:WaitForChild("HumanoidRootPart", 10)
    cachedHudHrp = char:FindFirstChild("HumanoidRootPart")
end)
refreshHudHrpCache()

-- Cache workspace folder references for minimap (they don't change)
local cachedCatsFolder = workspace:FindFirstChild("Cats")
local cachedKeysFolder = workspace:FindFirstChild("Keys")
local cachedDoorsFolder = workspace:FindFirstChild("Doors")
-- Refresh folder refs after maze generation if they didn't exist yet
task.spawn(function()
    if not workspace:GetAttribute("MazeGenerated") then
        workspace:GetAttributeChangedSignal("MazeGenerated"):Wait()
    end
    cachedCatsFolder = workspace:FindFirstChild("Cats")
    cachedKeysFolder = workspace:FindFirstChild("Keys")
    cachedDoorsFolder = workspace:FindFirstChild("Doors")
end)

-- Minimap: throttled to ~20fps (every 3rd frame)
local currentMinimapViewRadius = Constants.MinimapViewRadius or 100
local minimapFrameCounter = 0
local MINIMAP_FRAME_SKIP = 2 -- Run every 3rd frame

RunService.RenderStepped:Connect(function()
    if not gameActive then return end
    
    -- Throttle minimap to ~20fps
    minimapFrameCounter = minimapFrameCounter + 1
    if minimapFrameCounter <= MINIMAP_FRAME_SKIP then return end
    minimapFrameCounter = 0
    
    if player:GetAttribute("HasMinimap") then
        local mmSize = Constants.MinimapSize or 160
        local viewRadius = currentMinimapViewRadius

        if not screenGui:FindFirstChild("MinimapFrame") then
            -- Outer container frame
            local mmFrame = Instance.new("Frame")
            mmFrame.Name = "MinimapFrame"
            mmFrame.Size = UDim2.new(0, mmSize, 0, mmSize)
            mmFrame.Position = UDim2.new(0, 20, 0, 80)
            mmFrame.BackgroundTransparency = 1

            -- CanvasGroup handles ONLY stencil masking (NO UIStroke directly on CanvasGroup!)
            -- We use CanvasGroup so that on high graphics, it handles sub-pixel masking perfectly.
            local maskGroup = Instance.new("CanvasGroup")
            maskGroup.Name = "MaskGroup"
            maskGroup.Size = UDim2.new(1, 0, 1, 0)
            maskGroup.BackgroundColor3 = Constants.MinimapColors and Constants.MinimapColors.Floor or Color3.fromRGB(60, 60, 65)
            maskGroup.BackgroundTransparency = 0 
            maskGroup.GroupTransparency = 0.02 -- MUST be > 0 to force Roblox to render as a clipped texture!
            maskGroup.ClipsDescendants = true
            maskGroup.Parent = mmFrame

            local uic = Instance.new("UICorner")
            uic.CornerRadius = UDim.new(0.5, 0)
            uic.Parent = maskGroup

            -- Border stroke overlay (on top of mask so it doesn't distort GPU stencil clipping)
            local borderOverlay = Instance.new("Frame")
            borderOverlay.Name = "BorderOverlay"
            borderOverlay.Size = UDim2.new(1, 0, 1, 0)
            borderOverlay.BackgroundTransparency = 1
            borderOverlay.ZIndex = 15

            local bUic = Instance.new("UICorner")
            bUic.CornerRadius = UDim.new(0.5, 0)
            bUic.Parent = borderOverlay

            local mapStroke = Instance.new("UIStroke")
            mapStroke.Color = Constants.MinimapColors and Constants.MinimapColors.Circle or Color3.fromRGB(255, 255, 255)
            mapStroke.Thickness = 2.5
            mapStroke.Parent = borderOverlay
            borderOverlay.Parent = mmFrame

            -- Smooth Radial Vignette Overlay (Hides popping pixels with a smooth fade to black)
            local vignetteContainer = Instance.new("Frame")
            vignetteContainer.Name = "VignetteContainer"
            vignetteContainer.Size = UDim2.new(1, 0, 1, 0)
            vignetteContainer.BackgroundTransparency = 1
            vignetteContainer.ZIndex = 14
            vignetteContainer.Parent = mmFrame

            local maxVigThick = 26 -- Pixels of gradient bleed
            local steps = 12
            for i = 1, steps do
                local t = math.floor(maxVigThick * (i / steps))
                if t > 0 then
                    local stepVig = Instance.new("Frame")
                    stepVig.Size = UDim2.new(1, -t * 2, 1, -t * 2)
                    stepVig.AnchorPoint = Vector2.new(0.5, 0.5)
                    stepVig.Position = UDim2.new(0.5, 0, 0.5, 0)
                    stepVig.BackgroundTransparency = 1
                    stepVig.Parent = vignetteContainer

                    local c = Instance.new("UICorner")
                    c.CornerRadius = UDim.new(0.5, 0)
                    c.Parent = stepVig

                    local s = Instance.new("UIStroke")
                    s.Color = Color3.new(0, 0, 0) -- Pitch black at the edges
                    s.Thickness = t
                    s.Transparency = 0.8 -- Light transparency, stacking 12 times makes the outer edge solid black
                    s.Parent = stepVig
                end
            end

            -- Rotating Canvas Container inside the MaskGroup
            local canvasFrame = Instance.new("Frame")
            canvasFrame.Name = "CanvasFrame"
            canvasFrame.Size = UDim2.new(2, 0, 2, 0)
            canvasFrame.AnchorPoint = Vector2.new(0.5, 0.5)
            canvasFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
            canvasFrame.BackgroundTransparency = 1
            canvasFrame.ClipsDescendants = false
            canvasFrame.Parent = maskGroup

            -- Fixed Player Cursor in Center of Mask
            local pDot = Instance.new("Frame")
            pDot.Name = "PlayerDot"
            pDot.Size = UDim2.new(0, 10, 0, 10)
            pDot.AnchorPoint = Vector2.new(0.5, 0.5)
            pDot.Position = UDim2.new(0.5, 0, 0.5, 0)
            pDot.BackgroundColor3 = Constants.MinimapColors.Player or Color3.fromRGB(0, 255, 0)
            pDot.ZIndex = 20
            local pCorner = Instance.new("UICorner")
            pCorner.CornerRadius = UDim.new(1, 0)
            pCorner.Parent = pDot
            local pStroke = Instance.new("UIStroke")
            pStroke.Color = Color3.new(1, 1, 1)
            pStroke.Thickness = 1.5
            pStroke.Parent = pDot
            pDot.Parent = mmFrame

            local zoomContainer = Instance.new("Frame")
            zoomContainer.Name = "ZoomContainer"
            zoomContainer.Size = UDim2.new(1, 0, 0, 30)
            zoomContainer.Position = UDim2.new(0, 0, 1, 5)
            zoomContainer.BackgroundTransparency = 1
            zoomContainer.Parent = mmFrame

            local layout = Instance.new("UIListLayout")
            layout.FillDirection = Enum.FillDirection.Horizontal
            layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
            layout.SortOrder = Enum.SortOrder.LayoutOrder
            layout.Padding = UDim.new(0, 15)
            layout.Parent = zoomContainer

            local function createZoomBtn(txt, order)
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(0, 30, 0, 30)
                btn.BackgroundTransparency = 1
                btn.Text = txt
                btn.LayoutOrder = order
                btn.TextColor3 = Color3.fromRGB(200, 200, 220)
                btn.Font = Enum.Font.FredokaOne
                btn.TextSize = 24
                btn.Parent = zoomContainer
                return btn
            end

            local btnOut = createZoomBtn("-", 1) -- Zoom out (increase radius)
            local btnIn = createZoomBtn("+", 2)  -- Zoom in (decrease radius)
            
            local function updateZoomButtons()
                local minZoom = Constants.MinimapViewRadius or 100
                local maxZoom = Constants.MinimapMaxViewRadius or 250

                if currentMinimapViewRadius <= minZoom then
                    btnIn.TextColor3 = Color3.fromRGB(100, 100, 110)
                else
                    btnIn.TextColor3 = Color3.fromRGB(200, 200, 220)
                end

                if currentMinimapViewRadius >= maxZoom then
                    btnOut.TextColor3 = Color3.fromRGB(100, 100, 110)
                else
                    btnOut.TextColor3 = Color3.fromRGB(200, 200, 220)
                end
            end
            
            local function setZoomRadius(newRad)
                local minZoom = Constants.MinimapViewRadius or 100
                local maxZoom = Constants.MinimapMaxViewRadius or 250
                currentMinimapViewRadius = math.clamp(newRad, minZoom, maxZoom)
                updateZoomButtons()
            end
            
            btnIn.MouseButton1Click:Connect(function() setZoomRadius(currentMinimapViewRadius - 20) end)
            btnOut.MouseButton1Click:Connect(function() setZoomRadius(currentMinimapViewRadius + 20) end)

            ContextActionService:BindAction("MinimapZoomIn", function(_, state)
                if state == Enum.UserInputState.Begin then
                    setZoomRadius(currentMinimapViewRadius - 20)
                end
            end, false, Enum.KeyCode.DPadUp)
            
            ContextActionService:BindAction("MinimapZoomOut", function(_, state)
                if state == Enum.UserInputState.Begin then
                    setZoomRadius(currentMinimapViewRadius + 20)
                end
            end, false, Enum.KeyCode.DPadDown)
            
            updateZoomButtons()

            mmFrame.Parent = screenGui
        end
        
        screenGui.MinimapFrame.Visible = true
        local mmFrame = screenGui.MinimapFrame
        local maskGroup = mmFrame:FindFirstChild("MaskGroup")
        local canvasFrame = maskGroup and maskGroup:FindFirstChild("CanvasFrame")

        if cachedHudHrp and canvasFrame then
            local hrp = cachedHudHrp
            local playerPos = hrp.Position
            local scale = (mmSize / 2) / viewRadius


            local cosT = 1
            local sinT = 0
            local camYaw = 0
            local camera = workspace.CurrentCamera
            if camera then
                local lookVector = camera.CFrame.LookVector
                camYaw = math.atan2(-lookVector.X, -lookVector.Z)
                cosT = math.cos(camYaw)
                sinT = math.sin(camYaw)
            end
            
            local rotationDeg = math.deg(camYaw)
            
            -- Rotate the entire CanvasFrame so Roblox applies high-quality bilinear anti-aliasing
            -- to the whole minimap, keeping walls perfectly smooth with no gaps.
            canvasFrame.Rotation = 0

            local function addMapElement(pos, color, size, isWall, customSize, isKey, isDoor, isCat)
                local dot
                if isKey then
                    dot = Instance.new("TextLabel")
                    dot.Size = UDim2.new(0, size, 0, size)
                    dot.AnchorPoint = Vector2.new(0.5, 0.5)
                    dot.BackgroundTransparency = 1
                    dot.Text = "⭐"
                    dot.TextColor3 = color
                    dot.TextScaled = true
                    dot.Font = Enum.Font.FredokaOne
                elseif isCat then
                    dot = Instance.new("TextLabel")
                    dot.Size = UDim2.new(0, size, 0, size)
                    dot.AnchorPoint = Vector2.new(0.5, 0.5)
                    dot.BackgroundTransparency = 1
                    dot.Text = "🐱"
                    dot.TextColor3 = color
                    dot.TextScaled = true
                    dot.Font = Enum.Font.FredokaOne
                elseif isDoor then
                    dot = Instance.new("Frame")
                    dot.Size = UDim2.new(0, 5, 0, 5)
                    dot.AnchorPoint = Vector2.new(0.5, 0.5)
                    dot.BackgroundColor3 = color
                    dot.BorderSizePixel = 0
                elseif isWall then
                    dot = Instance.new("Frame")
                    local sw = customSize.X * scale
                    local sh = customSize.Z * scale
                    dot.Size = UDim2.new(0, sw, 0, sh)
                    dot.AnchorPoint = Vector2.new(0.5, 0.5)
                    dot.BackgroundColor3 = color
                    dot.BackgroundTransparency = 0
                    dot.BorderSizePixel = 0
                else
                    dot = Instance.new("Frame")
                    dot.Size = UDim2.new(0, size, 0, size)
                    dot.AnchorPoint = Vector2.new(0.5, 0.5)
                    dot.BackgroundColor3 = color
                    local c = Instance.new("UICorner")
                    c.CornerRadius = UDim.new(1, 0)
                    c.Parent = dot
                end
                dot.Parent = canvasFrame
                return { pos = pos, instance = dot }
            end

            -- Build static elements ONCE
            if not minimapWallsBuilt then
                minimapWallsBuilt = true

                local layout = Maps[Constants.ActiveLevel]
                if layout then
                    for z, row in ipairs(layout) do
                        for x, cellType in ipairs(row) do
                            local offset = Constants.MazeOffset or Vector3.new(0,0,0)
                            local px = (x - 1) * Constants.CellSize + offset.X
                            local pz = (z - 1) * Constants.CellSize + offset.Z
                            local pos = Vector3.new(px, 0, pz)
                            local size = Vector3.new(Constants.CellSize, Constants.CellSize, Constants.CellSize)
                            
                            if cellType == 1 then
                                local el = addMapElement(pos, Constants.MinimapColors.Wall or Color3.fromRGB(20, 20, 20), 0, true, size)
                                table.insert(cachedWallDots, el)
                            elseif cellType == 24 or cellType == 25 then
                                local el = addMapElement(pos, Constants.MinimapColors.Lava or Color3.fromRGB(255, 100, 50), 0, true, size)
                                table.insert(cachedWallDots, el)
                            elseif cellType == 28 then
                                local el = addMapElement(pos, Constants.MinimapColors.Spike or Color3.fromRGB(220, 220, 220), 0, true, size)
                                table.insert(cachedWallDots, el)
                            end
                        end
                    end
                end

                -- Shops, Doors, Keys
                local mazeElementsFolder = workspace:FindFirstChild("MazeElements")
                if mazeElementsFolder then
                    for _, obj in ipairs(mazeElementsFolder:GetChildren()) do
                        if obj.Name == "Shop" and obj:IsA("Model") then
                            local primary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
                            if primary then
                                local el = addMapElement(primary.Position, Color3.fromRGB(180, 50, 200), 10)
                                table.insert(cachedWallDots, el)
                            end
                        end
                    end
                end

                -- Cats, Keys, and Doors are now drawn dynamically in the RenderStepped loop so they update when picked up!
            end

            -- Update static dot positions using camera-relative 2D rotation matrix
            -- MATHEMATICAL CLIPPING: Hide any dot that gets too close to the boundary,
            -- ensuring that square pixels never bleed out even if CanvasGroup UICorner fails on low graphics!
            local cutoffRadius = viewRadius - (Constants.CellSize * 0.9)
            local maxRadSq = cutoffRadius * cutoffRadius
            
            for _, dotData in ipairs(cachedWallDots) do
                local dx = dotData.pos.X - playerPos.X
                local dz = dotData.pos.Z - playerPos.Z
                
                -- Math culling effectively creates a perfect circular mask for small 1x1 cells!
                if (dx * dx + dz * dz) <= maxRadSq then
                    local rx = dx * cosT - dz * sinT
                    local rz = dx * sinT + dz * cosT
                    
                    dotData.instance.Visible = true
                    dotData.instance.Position = UDim2.new(0.5, rx * scale, 0.5, rz * scale)
                    dotData.instance.Rotation = rotationDeg
                    
                    -- Dynamically scale wall sizes to prevent thinning/gaps when zoomed
                    local cellSize = Constants.CellSize
                    dotData.instance.Size = UDim2.new(0, cellSize * scale, 0, cellSize * scale)
                else
                    dotData.instance.Visible = false
                end
            end

            -- We will track which objects are visible this frame to cleanup old dots
            local currentObjects = {}

            -- Draw other players on the minimap
            for _, otherPlayer in ipairs(Players:GetPlayers()) do
                if otherPlayer ~= player and otherPlayer.Character then
                    local primary = otherPlayer.Character.PrimaryPart or otherPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if primary then
                        local dx = primary.Position.X - playerPos.X
                        local dz = primary.Position.Z - playerPos.Z
                        
                        local distSq = dx * dx + dz * dz
                        if distSq > maxRadSq then
                            local dist = math.sqrt(distSq)
                            local maxRad = math.sqrt(maxRadSq)
                            dx = dx * (maxRad / dist)
                            dz = dz * (maxRad / dist)
                        end
                        
                        local rx = dx * cosT - dz * sinT
                        local rz = dx * sinT + dz * cosT
                        
                        local pDot = dynamicDotsMap[otherPlayer]
                        if not pDot then
                            pDot = Instance.new("Frame")
                            pDot.Size = UDim2.new(0, 8, 0, 8)
                            pDot.AnchorPoint = Vector2.new(0.5, 0.5)
                            pDot.BackgroundColor3 = Constants.MinimapColors and Constants.MinimapColors.OtherPlayer or Color3.fromRGB(0, 120, 255)
                            pDot.BorderSizePixel = 1
                            pDot.BorderColor3 = Color3.new(0, 0, 0)
                            
                            local corner = Instance.new("UICorner")
                            corner.CornerRadius = UDim.new(1, 0)
                            corner.Parent = pDot
                            
                            pDot.ZIndex = 11
                            pDot.Parent = canvasFrame
                            dynamicDotsMap[otherPlayer] = pDot
                        end
                        
                        pDot.Position = UDim2.new(0.5, rx * scale, 0.5, rz * scale)
                        pDot.Rotation = 0
                        currentObjects[otherPlayer] = true
                    end
                end
            end

            -- Draw Cats on minimap
            if cachedCatsFolder then
                local collectedKey = "CollectedBy_" .. player.UserId
                for _, cat in ipairs(cachedCatsFolder:GetChildren()) do
                    if cat.Name == "Cat" then
                        -- Skip if already collected by local player
                        local catId = cat:GetAttribute("CatId")
                        if catId and player:GetAttribute("CollectedCat_" .. tostring(catId)) then continue end
                        local primary = cat:IsA("BasePart") and cat or nil
                        if not primary then
                            primary = cat:FindFirstChildWhichIsA("BasePart", true)
                        end
                        if primary then
                            local dx = primary.Position.X - playerPos.X
                            local dz = primary.Position.Z - playerPos.Z
                            
                            local distSq = dx * dx + dz * dz
                            if distSq > maxRadSq then
                                local dist = math.sqrt(distSq)
                                local maxRad = math.sqrt(maxRadSq)
                                dx = dx * (maxRad / dist)
                                dz = dz * (maxRad / dist)
                            end
                            
                            local rx = dx * cosT - dz * sinT
                            local rz = dx * sinT + dz * cosT
                            
                            local cDot = dynamicDotsMap[cat]
                            if not cDot then
                                cDot = Instance.new("Frame")
                                cDot.Size = UDim2.new(0, 8, 0, 8)
                                cDot.AnchorPoint = Vector2.new(0.5, 0.5)
                                cDot.BackgroundColor3 = Color3.fromRGB(255, 165, 0) -- Orange for cats
                                cDot.BorderSizePixel = 1
                                cDot.BorderColor3 = Color3.new(0, 0, 0)
                                local corner = Instance.new("UICorner")
                                corner.CornerRadius = UDim.new(1, 0)
                                corner.Parent = cDot
                                cDot.ZIndex = 10
                                cDot.Parent = canvasFrame
                                dynamicDotsMap[cat] = cDot
                            end
                            
                            cDot.Position = UDim2.new(0.5, rx * scale, 0.5, rz * scale)
                            cDot.Rotation = 0
                            currentObjects[cat] = true
                        end
                    end
                end
            end
            
            -- Draw Keys on minimap
            if cachedKeysFolder then
                local collectedKey = "CollectedBy_" .. player.UserId
                for _, key in ipairs(cachedKeysFolder:GetChildren()) do
                    -- Skip if already collected by local player
                    local colorNames = {"Blue", "Yellow", "Red", "Purple", "Green"}
                    local colorName
                    for _, c in ipairs(colorNames) do
                        if string.find(key.Name, c) then
                            colorName = c
                            break
                        end
                    end
                    if colorName and player:GetAttribute("Has" .. colorName .. "Key") then continue end
                    local primary = key:IsA("BasePart") and key or nil
                    if not primary then
                        primary = key:FindFirstChildWhichIsA("BasePart", true)
                    end
                    if primary then
                        local dx = primary.Position.X - playerPos.X
                        local dz = primary.Position.Z - playerPos.Z
                        
                        local distSq = dx * dx + dz * dz
                        if distSq > maxRadSq then
                            local dist = math.sqrt(distSq)
                            local maxRad = math.sqrt(maxRadSq)
                            dx = dx * (maxRad / dist)
                            dz = dz * (maxRad / dist)
                        end
                        
                        local rx = dx * cosT - dz * sinT
                        local rz = dx * sinT + dz * cosT
                        
                        local cDot = dynamicDotsMap[key]
                        if not cDot then
                            cDot = Instance.new("Frame")
                            cDot.Size = UDim2.new(0, 6, 0, 6)
                            cDot.AnchorPoint = Vector2.new(0.5, 0.5)
                            cDot.BackgroundColor3 = primary.Color
                            cDot.BorderSizePixel = 1
                            cDot.BorderColor3 = Color3.new(0, 0, 0)
                            local corner = Instance.new("UICorner")
                            corner.CornerRadius = UDim.new(1, 0)
                            corner.Parent = cDot
                            cDot.ZIndex = 10
                            cDot.Parent = canvasFrame
                            dynamicDotsMap[key] = cDot
                        end
                        
                        cDot.Position = UDim2.new(0.5, rx * scale, 0.5, rz * scale)
                        cDot.Rotation = 0
                        currentObjects[key] = true
                    end
                end
            end
            
            if cachedDoorsFolder then
                for _, obj in ipairs(cachedDoorsFolder:GetChildren()) do
                    if string.find(obj.Name, "Door") then
                        local primary = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)) or obj
                        if primary and primary:IsA("BasePart") then
                            local dx = primary.Position.X - playerPos.X
                            local dz = primary.Position.Z - playerPos.Z
                            
                            local distSq = dx * dx + dz * dz
                            if distSq > maxRadSq then
                                local dist = math.sqrt(distSq)
                                local maxRad = math.sqrt(maxRadSq)
                                dx = dx * (maxRad / dist)
                                dz = dz * (maxRad / dist)
                            end
                            
                            local rx = dx * cosT - dz * sinT
                            local rz = dx * sinT + dz * cosT
                            
                            local isFinal = string.find(obj.Name, "Final")
                            local cDot = dynamicDotsMap[obj]
                            if not cDot then
                                cDot = Instance.new("Frame")
                                cDot.Size = UDim2.new(0, 8, 0, 8)
                                cDot.AnchorPoint = Vector2.new(0.5, 0.5)
                                cDot.BorderSizePixel = 1
                                cDot.BorderColor3 = Color3.new(0, 0, 0)
                                
                                local corner = Instance.new("UICorner")
                                corner.CornerRadius = UDim.new(1, 0)
                                corner.Parent = cDot
                                
                                cDot.ZIndex = 9
                                cDot.Parent = canvasFrame
                                dynamicDotsMap[obj] = cDot
                            end
                            
                            -- Determine if this door/portal is unlocked
                            local colorName = nil
                            local colorNamesList = {"Blue", "Yellow", "Red", "Purple", "Green"}
                            for _, c in ipairs(colorNamesList) do
                                if string.find(obj.Name, c) then
                                    colorName = c
                                    break
                                end
                            end
                            
                            local isUnlocked = false
                            if colorName then
                                isUnlocked = player:GetAttribute("Has" .. colorName .. "Key") == true
                            elseif isFinal then
                                local catsRescued = player:GetAttribute("CatsRescued") or 0
                                isUnlocked = catsRescued >= Constants.TotalCats
                            end
                            
                            local baseColor = isFinal and Color3.fromRGB(142, 0, 88) or (primary and primary.Color or Color3.fromRGB(200, 200, 200))
                            cDot.BackgroundColor3 = baseColor
                            
                            cDot.Position = UDim2.new(0.5, rx * scale, 0.5, rz * scale)
                            cDot.Rotation = 0
                            currentObjects[obj] = true
                        end
                    end
                end
            end
            
            -- Cleanup any dots for objects that are no longer visible or no longer exist
            for obj, dot in pairs(dynamicDotsMap) do
                if not currentObjects[obj] then
                    dot:Destroy()
                    dynamicDotsMap[obj] = nil
                end
            end
        end
    else
        if screenGui:FindFirstChild("MinimapFrame") then
            screenGui.MinimapFrame.Visible = false
        end
    end
end)

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")

local winPromptLabel = Instance.new("TextLabel")
winPromptLabel.Name = "WinPrompt"
winPromptLabel.Size = UDim2.new(0, 500, 0, 50)
winPromptLabel.AnchorPoint = Vector2.new(0.5, 0)
winPromptLabel.Position = UDim2.new(0.5, 0, 0, 100)
winPromptLabel.Text = "🎉 " .. TranslationHelper.translate("Now find the maze exit and bring all") .. " " .. Constants.TotalCats .. " " .. TranslationHelper.translate("cats to safety!") .. " 🎉"
winPromptLabel.TextSize = 24
winPromptLabel.Font = Enum.Font.GothamBold
winPromptLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
winPromptLabel.BackgroundTransparency = 1
winPromptLabel.AutoLocalize = true
winPromptLabel.Visible = false
local winStroke = Instance.new("UIStroke")
winStroke.Thickness = 2
winStroke.Parent = winPromptLabel
winPromptLabel.Parent = screenGui

local catCollectedRemote = remotesFolder:WaitForChild("CatCollectedClient", 5)

local hiddenCats = {}

local popupLabel = Instance.new("TextLabel")
popupLabel.Name = "PopupLabel"
popupLabel.Size = UDim2.new(0, 400, 0, 50)
popupLabel.AnchorPoint = Vector2.new(0.5, 0.5)
popupLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
popupLabel.BackgroundTransparency = 1
popupLabel.Text = ""
popupLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
popupLabel.Font = Enum.Font.FredokaOne
popupLabel.TextSize = 36
popupLabel.AutoLocalize = true
popupLabel.TextTransparency = 1
popupLabel.Visible = false

local popupStroke = Instance.new("UIStroke")
popupStroke.Thickness = 3
popupStroke.Color = Color3.new(0, 0, 0)
popupStroke.Transparency = 1
popupStroke.Parent = popupLabel
popupLabel.Parent = screenGui

local playerInfoRemote = remotesFolder:WaitForChild("UpdatePlayerInfo", 5)
if catCollectedRemote then
    catCollectedRemote.OnClientEvent:Connect(function(cats)
        catsLabel.Text = "🐱 " .. cats .. " / " .. Constants.TotalCats
        pcall(function() HapticManager.mediumPulse() end)
        
        popupLabel.Text = TranslationHelper.translate("Kitties rescued:") .. " " .. cats .. "/" .. Constants.TotalCats
        popupLabel.Visible = true
        popupLabel.TextTransparency = 0
        popupStroke.Transparency = 0
        
        local tweenInfo = TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local tween1 = TweenService:Create(popupLabel, tweenInfo, {TextTransparency = 1})
        local tween2 = TweenService:Create(popupStroke, tweenInfo, {Transparency = 1})
        tween1:Play()
        tween2:Play()
        tween1.Completed:Connect(function()
            if popupLabel.TextTransparency == 1 then
                popupLabel.Visible = false
            end
        end)
        
        if cats >= Constants.TotalCats then
            winPromptLabel.Visible = true
        end
    end)
end

local resetHudRemote = remotesFolder:WaitForChild("ResetHUD", 5)
if resetHudRemote then
    resetHudRemote.OnClientEvent:Connect(function()
        local cats = player:GetAttribute("CatsRescued") or 0
        catsLabel.Text = "🐱 " .. tostring(cats) .. " / " .. Constants.TotalCats
        winPromptLabel.Visible = false
    end)
end

local showWinScreenRemote = remotesFolder:WaitForChild("ShowWinScreen", 5)
if showWinScreenRemote then
    showWinScreenRemote.OnClientEvent:Connect(function()
        winPromptLabel.Visible = false
    end)
end

local hideCatRemote = remotesFolder:WaitForChild("HideCatClient", 5)
if hideCatRemote then
    hideCatRemote.OnClientEvent:Connect(function(cat)
        if cat and cat.Parent then
            table.insert(hiddenCats, cat)
            cat.Parent = nil
        end
    end)
end

local resetLocalCatsRemote = remotesFolder:WaitForChild("ResetLocalCats", 5)
if resetLocalCatsRemote then
    resetLocalCatsRemote.OnClientEvent:Connect(function()
        local catsFolder = workspace:FindFirstChild("Cats") or workspace
        for _, cat in ipairs(hiddenCats) do
            if cat then
                cat.Parent = catsFolder
            end
        end
        table.clear(hiddenCats)
    end)
end

-- HUD Keys Container
local keysContainer = Instance.new("Frame")
keysContainer.Name = "HUDKeysContainer"
keysContainer.Size = UDim2.new(0, 250, 0, 50)
keysContainer.BackgroundTransparency = 1
keysContainer.Parent = bottomRightPanel

local kcLayout = Instance.new("UIListLayout")
kcLayout.FillDirection = Enum.FillDirection.Horizontal
kcLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
kcLayout.SortOrder = Enum.SortOrder.LayoutOrder
kcLayout.Padding = UDim.new(0, -12)
kcLayout.Parent = keysContainer


local function updateKeychainUI()
    for _, child in ipairs(keysContainer:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") or child:IsA("ViewportFrame") then child:Destroy() end
    end
    
    local keyColors = {
        Blue = Color3.fromRGB(0, 86, 255),
        Yellow = Color3.fromRGB(251, 255, 0),
        Red = Color3.fromRGB(255, 0, 0),
        Purple = Color3.fromRGB(161, 0, 255),
        Green = Color3.fromRGB(0, 255, 7)
    }
    
    local count = 0
    local keyTemplate = ReplicatedStorage:FindFirstChild("Objects") and ReplicatedStorage.Objects:FindFirstChild("Key")
    
    for name, col in pairs(keyColors) do
        if player:GetAttribute("Has" .. name .. "Key") then
            count = count + 1
            if keyTemplate then
                local vpf = Instance.new("ViewportFrame")
                vpf.Size = UDim2.new(0, 50, 0, 50)
                vpf.BackgroundTransparency = 1
                
                local camera = Instance.new("Camera")
                vpf.CurrentCamera = camera
                camera.Parent = vpf
                
                local keyClone = keyTemplate:Clone()
                local radius = 2
                
                if keyClone:IsA("Model") then
                    for _, p in ipairs(keyClone:GetDescendants()) do
                        if p:IsA("BasePart") then p.Color = col end
                    end
                    local cframe, size = keyClone:GetBoundingBox()
                    radius = size.Magnitude / 2
                    keyClone:PivotTo(CFrame.new(0,0,0))
                elseif keyClone:IsA("BasePart") then
                    keyClone.Color = col
                    radius = keyClone.Size.Magnitude / 2
                    keyClone.CFrame = CFrame.new(0,0,0)
                end
                
                local camOffset = Vector3.new(radius * 1.5, radius * 1.5, radius * 2)
                camera.CFrame = CFrame.lookAt(camOffset, Vector3.new(0,0,0))
                
                keyClone.Parent = vpf
                vpf.Parent = keysContainer
            else
                local kf = Instance.new("Frame")
                kf.Size = UDim2.new(0, 42, 0, 42)
                kf.BackgroundColor3 = col
                local kc = Instance.new("UICorner")
                kc.CornerRadius = UDim.new(1, 0)
                kc.Parent = kf
                kf.Parent = keysContainer
            end
        end
    end
    
end


local keys = {"Blue", "Yellow", "Red", "Purple", "Green"}
for _, k in ipairs(keys) do
    player:GetAttributeChangedSignal("Has" .. k .. "Key"):Connect(function()
        updateKeychainUI()
    end)
end

-- Boat Icon
local boatIconFrame = Instance.new("Frame")
boatIconFrame.Name = "BoatIconFrame"
boatIconFrame.Size = UDim2.new(0, 95, 0, 95)
boatIconFrame.BackgroundTransparency = 1
boatIconFrame.Visible = false

local boatVpf = Instance.new("ViewportFrame")
boatVpf.Size = UDim2.new(1, 0, 1, 0)
boatVpf.BackgroundTransparency = 1
boatVpf.Parent = boatIconFrame

local camera = Instance.new("Camera")
boatVpf.CurrentCamera = camera
camera.Parent = boatVpf

local boatTemplate = ReplicatedStorage:FindFirstChild("Objects") and ReplicatedStorage.Objects:FindFirstChild("Boat")
if boatTemplate then
    local boatClone = boatTemplate:Clone()
    
    local radius = 3
    if boatClone:IsA("Model") then
        local cframe, size = boatClone:GetBoundingBox()
        radius = size.Magnitude / 2
        boatClone:PivotTo(CFrame.new(0,0,0))
    elseif boatClone:IsA("BasePart") then
        radius = boatClone.Size.Magnitude / 2
        boatClone.CFrame = CFrame.new(0,0,0)
    end
    
    local camOffset = Vector3.new(radius * 1.5, radius * 1.2, radius * 1.5)
    camera.CFrame = CFrame.lookAt(camOffset, Vector3.new(0,0,0))
    
    boatClone.Parent = boatVpf
end

boatIconFrame.Parent = bottomRightPanel

player:GetAttributeChangedSignal("HasBoat"):Connect(function()
    boatIconFrame.Visible = player:GetAttribute("HasBoat") == true
end)

-- Troll Mode Announcement
local trollRemote = remotesFolder:WaitForChild("TrollEffectStarted")
local trollLabel = Instance.new("TextLabel")
trollLabel.Name = "TrollLabel"
trollLabel.Size = UDim2.new(1, -40, 0, 60)
trollLabel.Position = UDim2.new(0, 20, 0, 120)
trollLabel.BackgroundTransparency = 1
trollLabel.Text = ""
trollLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
trollLabel.TextSize = 40
trollLabel.Font = Enum.Font.FredokaOne
trollLabel.Visible = false
trollLabel.TextScaled = true
trollLabel.TextWrapped = true
local trollStroke = Instance.new("UIStroke")
trollStroke.Thickness = 3
trollStroke.Parent = trollLabel
trollLabel.Parent = screenGui

local trollConstraint = Instance.new("UITextSizeConstraint")
trollConstraint.MaxTextSize = 35
trollConstraint.Parent = trollLabel

local trollThread = nil
trollRemote.OnClientEvent:Connect(function(buyerName, duration)
    if trollThread then task.cancel(trollThread) end
    
    trollButton.Visible = false
    trollLabel.Visible = true
    -- Play a warning sound
    SoundManager.playSound(Constants.Sounds.ShieldBreak, player.Character and player.Character.PrimaryPart)
    
    trollThread = task.spawn(function()
        local endTime = tick() + duration
        while tick() < endTime do
            local remaining = math.ceil(endTime - tick())
            trollLabel.Text = "🚨 " .. buyerName .. " " .. TranslationHelper.translate("IS TROLLING EVERYONE!") .. " (" .. remaining .. "s) 🚨"
            task.wait(0.5)
        end
        trollLabel.Visible = false
        trollButton.Visible = true
    end)
end)

-- Developer Testing Button (Whitelisted)
local function isWhitelisted(name)
    if name == "beabadoobeelson" then return true end
    if Constants.ShopOwnerUsernames then
        for _, u in ipairs(Constants.ShopOwnerUsernames) do
            if u == name then
                return true
            end
        end
    end
    return false
end

if isWhitelisted(player.Name) then
    local devButton = Instance.new("TextButton")
    devButton.Name = "DevUnlockButton"
    devButton.Size = UDim2.new(0, 160, 0, 45)
    devButton.Position = UDim2.new(1, -20, 0, 220)
    devButton.AnchorPoint = Vector2.new(1, 0)
    devButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
    devButton.TextColor3 = Color3.new(1, 1, 1)
    devButton.Text = "Unlock & Rescue All"
    devButton.Font = Enum.Font.FredokaOne
    devButton.TextSize = 13
    devButton.TextWrapped = true
    
    local devCorner = Instance.new("UICorner")
    devCorner.CornerRadius = UDim.new(0, 10)
    devCorner.Parent = devButton
    
    local devStroke = Instance.new("UIStroke")
    devStroke.Color = Color3.fromRGB(255, 255, 255)
    devStroke.Thickness = 2
    devStroke.Parent = devButton
    
    devButton.Parent = screenGui
    
    devButton.MouseButton1Click:Connect(function()
        local remotes = ReplicatedStorage:WaitForChild("Remotes")
        local devUnlockAllCatsRemote = remotes:WaitForChild("DevUnlockAllCatsRemote", 5)
        if devUnlockAllCatsRemote then
            devUnlockAllCatsRemote:FireServer()
        end
    end)
end

-- Dynamically translate ProximityPrompts and Vendor Name
task.spawn(function()
    -- Vendor
    local shopArea = workspace:WaitForChild("ShopArea", 10)
    if shopArea then
        local vendor = shopArea:WaitForChild("Vendor", 10)
        if vendor then
            local vendorNameGui = vendor:WaitForChild("VendorNameGui", 10)
            if vendorNameGui then
                local label = vendorNameGui:WaitForChild("NameLabel", 10)
                if label then
                    label.Text = "🛒 " .. TranslationHelper.translate("Vendor")
                end
            end
        end
    end
end)

local ProximityPromptService = game:GetService("ProximityPromptService")
ProximityPromptService.PromptShown:Connect(function(prompt)
    if not prompt:GetAttribute("Translated") then
        if prompt.ActionText and prompt.ActionText ~= "" then
            prompt.ActionText = TranslationHelper.translate(prompt.ActionText)
        end
        if prompt.ObjectText and prompt.ObjectText ~= "" then
            prompt.ObjectText = TranslationHelper.translate(prompt.ObjectText)
        end
        prompt:SetAttribute("Translated", true)
    end
end)
