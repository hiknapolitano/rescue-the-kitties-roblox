local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local MarketplaceService = game:GetService("MarketplaceService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local openShopRemote = remotes:WaitForChild("OpenShop")
local purchaseItemRemote = remotes:WaitForChild("PurchaseItem")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local SoundManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundManager"))

local shopGui = nil

local function closeShop()
    if shopGui then
        ContextActionService:UnbindAction("CloseShopGamepad")
        GuiService.SelectedObject = nil
        GuiService.AutoSelectGuiEnabled = false
        shopGui:Destroy()
        shopGui = nil
    end
end

openShopRemote.OnClientEvent:Connect(function(itemsList)
    if shopGui then return end
    
    shopGui = Instance.new("ScreenGui")
    shopGui.Name = "ShopGui"
    shopGui.ResetOnSpawn = false
    shopGui.DisplayOrder = 200  -- Above HUD (10), inventory (1/100), and all other GUIs
    
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.new(0, 0, 0)
    bg.BackgroundTransparency = 0.5
    bg.Parent = shopGui
    
    local closeBtnBg = Instance.new("TextButton")
    closeBtnBg.Size = UDim2.new(1, 0, 1, 0)
    closeBtnBg.BackgroundTransparency = 1
    closeBtnBg.Text = ""
    closeBtnBg.Selectable = false  -- Not a real button for gamepad nav
    closeBtnBg.Parent = bg
    closeBtnBg.MouseButton1Click:Connect(closeShop)
    
    local mainPanel = Instance.new("Frame")
    mainPanel.Size = UDim2.new(0.9, 0, 0.8, 0)
    mainPanel.AnchorPoint = Vector2.new(0.5, 0.5)
    mainPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainPanel.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    mainPanel.BorderSizePixel = 0
    mainPanel.ClipsDescendants = true
    
    local sizeConstraint = Instance.new("UISizeConstraint")
    sizeConstraint.MaxSize = Vector2.new(500, 500)
    sizeConstraint.Parent = mainPanel
    
    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(150, 150, 170)
    mainStroke.Thickness = 3
    mainStroke.Parent = mainPanel
    
    local uicorner = Instance.new("UICorner")
    uicorner.CornerRadius = UDim.new(0, 15)
    uicorner.Parent = mainPanel
    mainPanel.Parent = shopGui
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 0, 40)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "🛒 KITTEN RESCUE SHOP"
    title.TextColor3 = Color3.fromRGB(255, 215, 0)
    title.Font = Enum.Font.FredokaOne
    title.TextScaled = true
    title.Parent = mainPanel
    
    local titleConstraint = Instance.new("UITextSizeConstraint")
    titleConstraint.MaxTextSize = 32
    titleConstraint.Parent = title
    
    local promoText = Instance.new("TextLabel")
    promoText.Size = UDim2.new(1, -20, 0, 25)
    promoText.Position = UDim2.new(0, 10, 0, 50)
    promoText.BackgroundTransparency = 1
    promoText.Text = "Join our Roblox Group for 20% off all items!"
    promoText.TextColor3 = Color3.fromRGB(150, 255, 150)
    promoText.Font = Enum.Font.FredokaOne
    promoText.TextScaled = true
    promoText.Parent = mainPanel
    
    local promoConstraint = Instance.new("UITextSizeConstraint")
    promoConstraint.MaxTextSize = 18
    promoConstraint.Parent = promoText
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 40, 0, 40)
    closeBtn.Position = UDim2.new(1, -50, 0, 10)
    closeBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.Font = Enum.Font.FredokaOne
    closeBtn.TextScaled = true
    closeBtn.AutoLocalize = true
    closeBtn.Parent = mainPanel
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = closeBtn
    
    closeBtn.MouseButton1Click:Connect(function()
        SoundManager.playClick(Constants.Sounds.ShopBuy)
        closeShop()
    end)
    
    local scrollingFrame = Instance.new("ScrollingFrame")
    scrollingFrame.Size = UDim2.new(1, -20, 1, -85)
    scrollingFrame.Position = UDim2.new(0, 10, 0, 80)
    scrollingFrame.BackgroundTransparency = 1
    scrollingFrame.BorderSizePixel = 0
    scrollingFrame.ScrollBarThickness = 8
    scrollingFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    scrollingFrame.Selectable = false  -- Prevent controller from selecting the frame itself before items
    scrollingFrame.Parent = mainPanel
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 10)
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.Parent = scrollingFrame
    
    local uiPadding = Instance.new("UIPadding")
    uiPadding.PaddingTop = UDim.new(0, 5)
    uiPadding.PaddingBottom = UDim.new(0, 5)
    uiPadding.Parent = scrollingFrame
    
    local firstBtn = nil
    for _, item in ipairs(itemsList) do
        -- Check if owned
        if item.id == "Minimap" or item.id == "MinimapPerm" then
            if player:GetAttribute("HasMinimap") then continue end
        elseif item.id == "FlashlightUpgrade" or item.id == "FlashlightUpgradePerm" then
            if player:GetAttribute("HasHelmet") then continue end
        end
        
        local itemFrame = Instance.new("Frame")
        itemFrame.Size = UDim2.new(1, -10, 0, 75)
        itemFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
        itemFrame.Selectable = false  -- Only the Buy button inside is selectable
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = itemFrame
        
        local isGamepass = item.isGamepass or false
        local isProduct = item.isProduct or false
        if item.isHighlight then
            itemFrame.BackgroundColor3 = Color3.fromRGB(130, 40, 180) -- Bright purple for highlight
        elseif isGamepass then
            itemFrame.BackgroundColor3 = Color3.fromRGB(80, 60, 40) -- Highlight gamepasses
        end
        
        local itemStroke = Instance.new("UIStroke")
        itemStroke.Color = isGamepass and Color3.fromRGB(255, 170, 0) or Color3.fromRGB(100, 100, 120)
        itemStroke.Thickness = isGamepass and 3 or 2
        itemStroke.Parent = itemFrame
        
        local success, inGroup = pcall(function()
            return Constants.GroupId > 0 and player:IsInGroup(Constants.GroupId)
        end)
        local hasDiscount = success and inGroup
        local finalPrice = hasDiscount and math.floor(item.price * 0.8) or item.price
        
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(0.65, 0, 0.4, 0)
        nameLabel.Position = UDim2.new(0, 15, 0, 5)
        nameLabel.BackgroundTransparency = 1
        
        local showDiscount = hasDiscount and not isGamepass
        nameLabel.Text = item.name .. (showDiscount and " (20% OFF)" or "")
        nameLabel.TextColor3 = showDiscount and Color3.fromRGB(150, 255, 150) or Color3.new(1, 1, 1)
        nameLabel.Font = Enum.Font.FredokaOne
        nameLabel.TextScaled = true
        nameLabel.AutoLocalize = true
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = itemFrame
        
        local nameConstraint = Instance.new("UITextSizeConstraint")
        nameConstraint.MaxTextSize = 22
        nameConstraint.Parent = nameLabel

        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(0.65, 0, 0.45, 0)
        descLabel.Position = UDim2.new(0, 15, 0.4, 5)
        descLabel.BackgroundTransparency = 1
        descLabel.Text = item.desc
        descLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        descLabel.Font = Enum.Font.Nunito
        descLabel.TextScaled = true
        descLabel.AutoLocalize = true
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.TextWrapped = true
        descLabel.Parent = itemFrame
        
        local descConstraint = Instance.new("UITextSizeConstraint")
        descConstraint.MaxTextSize = 16
        descConstraint.Parent = descLabel
        
        local buyBtn = Instance.new("TextButton")
        buyBtn.Size = UDim2.new(0.25, 0, 0.7, 0)
        buyBtn.Position = UDim2.new(1, -10, 0.5, 0)
        buyBtn.AnchorPoint = Vector2.new(1, 0.5)
        buyBtn.BackgroundColor3 = isGamepass and Color3.fromRGB(255, 170, 0) or Color3.fromRGB(46, 204, 113)
        buyBtn.Text = isGamepass and "BUY" or ("Buy\n(" .. finalPrice .. "💰)")
        buyBtn.TextColor3 = isGamepass and Color3.fromRGB(20, 20, 20) or Color3.new(1, 1, 1)
        buyBtn.Font = Enum.Font.GothamBold
        buyBtn.TextScaled = true
        buyBtn.AutoLocalize = true
        
        local buyConstraint = Instance.new("UITextSizeConstraint")
        buyConstraint.MaxTextSize = 18
        buyConstraint.Parent = buyBtn
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 8)
        btnCorner.Parent = buyBtn
        buyBtn.Parent = itemFrame
        
        buyBtn.MouseButton1Click:Connect(function()
            SoundManager.playClick(Constants.Sounds.ShopBuy)
            
            if isGamepass then
                if table.find(Constants.FreePurchaseWhitelist, player.Name) then
                    -- Bypass for whitelisted players
                    local success, msg = purchaseItemRemote:InvokeServer(item.id)
                    if success then
                        buyBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
                        buyBtn.Text = "Owned!"
                    end
                else
                    if item.id == "MinimapPerm" then
                        MarketplaceService:PromptGamePassPurchase(player, Constants.MinimapGamepassId)
                    elseif item.id == "FlashlightUpgradePerm" then
                        MarketplaceService:PromptGamePassPurchase(player, Constants.FlashlightUpgradeGamepassId)
                    end
                end
                return
            end
            
            buyBtn.Text = "Processing..."
            buyBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
            
            local success, msg = purchaseItemRemote:InvokeServer(item.id)
            
            if success then
                buyBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
                buyBtn.Text = "Success!"
                task.wait(1)
                if buyBtn then
                    buyBtn.Text = "Buy\n(" .. finalPrice .. "💰)"
                end
            else
                buyBtn.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
                buyBtn.Text = "Failed"
                task.wait(1)
                if buyBtn then
                    buyBtn.Text = "Buy\n(" .. finalPrice .. "💰)"
                    buyBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
                end
            end
        end)
        
        itemFrame.Parent = scrollingFrame
        
        if not firstBtn then
            firstBtn = buyBtn
        end
    end
    
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 20)
    end)
    scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 20)
    
    mainPanel.Position = UDim2.new(0.5, 0, 1.5, 0)
    shopGui.Parent = playerGui
    TweenService:Create(mainPanel, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, 0, 0.5, 0)}):Play()
    
    -- Set SelectedObject AFTER parenting so the button is in the live GUI tree (avoids "invalid GuiObject" error)
    task.defer(function()
        GuiService.AutoSelectGuiEnabled = true
        GuiService.SelectedObject = firstBtn or closeBtn
    end)
    
    ContextActionService:BindAction("CloseShopGamepad", function(actionName, state, input)
        if state == Enum.UserInputState.Begin then
            SoundManager.playClick(Constants.Sounds.ShopBuy)
            closeShop()
        end
    end, false, Enum.KeyCode.ButtonB)
end)
