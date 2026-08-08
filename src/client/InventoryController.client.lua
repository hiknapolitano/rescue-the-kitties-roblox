local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HapticManager = require(Shared:WaitForChild("HapticManager"))
local TranslationHelper = require(Shared:WaitForChild("TranslationHelper"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MAX_SLOTS = 9
local currentItems = {} -- Array of Tool objects

-- Create Custom UI
local inventoryGui = Instance.new("ScreenGui")
inventoryGui.Name = "CustomInventoryUI"
inventoryGui.ResetOnSpawn = false
inventoryGui.DisplayOrder = 1
inventoryGui.IgnoreGuiInset = false
inventoryGui.Parent = playerGui

local container = Instance.new("Frame")
container.Name = "InventoryContainer"
container.AnchorPoint = Vector2.new(0.5, 1)
container.Position = UDim2.new(0.5, 0, 1, -15) -- Move to bottom of screen
container.Size = UDim2.new(1, -20, 0, 50)
container.BackgroundTransparency = 1
container.Parent = inventoryGui

local uilist = Instance.new("UIListLayout")
uilist.FillDirection = Enum.FillDirection.Horizontal
uilist.HorizontalAlignment = Enum.HorizontalAlignment.Center
uilist.VerticalAlignment = Enum.VerticalAlignment.Bottom
uilist.Padding = UDim.new(0, 5)
uilist.Parent = container

local slots = {}

for i = 1, MAX_SLOTS do
    local slot = Instance.new("TextButton")
    slot.Name = "Slot" .. i
    slot.Size = UDim2.new(0, 50, 0, 50)
    slot.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    slot.BackgroundTransparency = 0.3
    slot.BorderSizePixel = 0
    slot.AutoButtonColor = false
    slot.Text = ""
    slot.Parent = container
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = slot
    
    local numberLabel = Instance.new("TextLabel")
    numberLabel.Name = "Number"
    numberLabel.Size = UDim2.new(0, 15, 0, 15)
    numberLabel.Position = UDim2.new(0, 2, 0, 2)
    numberLabel.BackgroundTransparency = 1
    numberLabel.Text = tostring(i)
    numberLabel.TextColor3 = Color3.new(1, 1, 1)
    numberLabel.Font = Enum.Font.FredokaOne
    numberLabel.TextSize = 12
    numberLabel.Parent = slot
    
    local viewport = Instance.new("ViewportFrame")
    viewport.Name = "Viewport"
    viewport.Size = UDim2.new(1, -4, 1, -15)
    viewport.Position = UDim2.new(0, 2, 0, 15)
    viewport.BackgroundTransparency = 1
    viewport.Ambient = Color3.fromRGB(200, 200, 200)
    viewport.LightColor = Color3.fromRGB(255, 255, 255)
    viewport.LightDirection = Vector3.new(-1, -1, -1)
    viewport.Parent = slot
    
    local highlight = Instance.new("UIStroke")
    highlight.Color = Color3.fromRGB(255, 255, 255)
    highlight.Thickness = 2
    highlight.Transparency = 1
    highlight.Parent = slot
    
    slots[i] = {
        Button = slot,
        Viewport = viewport,
        Highlight = highlight,
        Tool = nil
    }
end

-- Refresh UI based on current backpack and character
local function getInventoryTools()
    local tools = {}
    if player.Character then
        local equipped = player.Character:FindFirstChildOfClass("Tool")
        if equipped then table.insert(tools, equipped) end
    end
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                table.insert(tools, tool)
            end
        end
    end
    return tools
end

local function updateInventoryUI()
    local activeTools = getInventoryTools()

    -- Build a compact ordered list: preserve existing slot order for tools that remain,
    -- then append any brand-new tools to the end. This ensures that when item 2 of 3 is
    -- consumed, item 3 immediately becomes item 2 — both visually and for keyboard/gamepad.
    local newItems = {}
    
    -- First pass: keep existing tools that are still in the inventory, in their current order
    for i = 1, MAX_SLOTS do
        local slotTool = currentItems[i]
        if slotTool then
            for _, t in ipairs(activeTools) do
                if t == slotTool then
                    table.insert(newItems, slotTool)
                    break
                end
            end
        end
    end
    
    -- Second pass: add any new tools not already in the list
    for _, t in ipairs(activeTools) do
        local found = false
        for _, existing in ipairs(newItems) do
            if existing == t then found = true; break end
        end
        if not found then
            table.insert(newItems, t)
        end
    end
    
    -- Apply compacted list
    for i = 1, MAX_SLOTS do
        currentItems[i] = newItems[i] or nil
    end
    
    -- Clamp gamepad index to valid range
    local count = #newItems
    if count == 0 then
        gamepadSelectedIndex = 1
    else
        gamepadSelectedIndex = math.min(gamepadSelectedIndex, count)
    end
    
    -- 3. Render slots
    for i = 1, MAX_SLOTS do
        local slotData = slots[i]
        local tool = currentItems[i]
        
        if tool then
            slotData.Button.Visible = true
            
            -- Update slot number label (reflects compacted position, not original index)
            local numLabel = slotData.Button:FindFirstChild("Number")
            if numLabel then numLabel.Text = tostring(i) end
            
            -- Only rebuild the 3D model if it's a NEW tool in this slot
            if slotData.Tool ~= tool then
                slotData.Tool = tool
                
                -- Clean old viewport contents
                for _, child in ipairs(slotData.Viewport:GetChildren()) do
                    child:Destroy()
                end
                
                task.spawn(function()
                    local handle = tool:FindFirstChild("Handle")
                    if not handle then
                        task.wait(0.5) -- Wait for the model to stream in/load
                        if tool.Parent then
                            handle = tool:FindFirstChild("Handle")
                        end
                    end
                    
                    if slotData.Tool ~= tool then return end -- Check if slot changed while waiting
                    
                    if tool.Name == "Flashlight" or tool.Name == "DogBone" then
                        local emojiLabel = Instance.new("TextLabel")
                        emojiLabel.Size = UDim2.new(1, 0, 1, 0)
                        emojiLabel.BackgroundTransparency = 1
                        emojiLabel.Text = tool.Name == "Flashlight" and "🔦" or "🦴"
                        emojiLabel.TextScaled = true
                        emojiLabel.Parent = slotData.Viewport
                    elseif handle and handle:IsA("BasePart") then
                        -- Wrap in a model so we can safely rotate all children (like the potion's glass bottle)
                        local cloneModel = Instance.new("Model")
                        local cloneHandle = handle:Clone()
                        cloneHandle.Parent = cloneModel
                        cloneModel.PrimaryPart = cloneHandle
                        
                        local angles = CFrame.Angles(0, math.rad(45), math.rad(15))
                        if tool.Name == "Shield" then
                            angles = CFrame.Angles(0, 0, 0) -- Display shield frontally
                        end
                        
                        cloneModel:PivotTo(CFrame.new(Vector3.zero) * angles)
                        cloneModel.Parent = slotData.Viewport
                        
                        local cam = Instance.new("Camera")
                        local _, size = cloneModel:GetBoundingBox()
                        local maxDim = math.max(size.X, size.Y, size.Z)
                        
                        -- Calculate exact distance needed to fit the object perfectly in view
                        local fovRadius = math.rad(cam.FieldOfView / 2)
                        local distance = (maxDim / 2) / math.tan(fovRadius)
                        
                        local distanceMod = 1.25
                        cam.CFrame = CFrame.lookAt(Vector3.new(0, 0, distance * distanceMod), Vector3.zero)
                        slotData.Viewport.CurrentCamera = cam
                        cam.Parent = slotData.Viewport
                    else
                        if tool.TextureId and tool.TextureId ~= "" then
                            local icon = Instance.new("ImageLabel")
                            icon.Size = UDim2.new(1, 0, 1, 0)
                            icon.BackgroundTransparency = 1
                            icon.Image = tool.TextureId
                            icon.Parent = slotData.Viewport
                        else
                            -- Fallback to text if no handle
                            local fallback = Instance.new("TextLabel")
                            fallback.Size = UDim2.new(1, 0, 1, 0)
                            fallback.BackgroundTransparency = 1
                            fallback.Text = TranslationHelper.translate(tool.Name)
                            fallback.TextColor3 = Color3.fromRGB(255, 255, 255)
                            fallback.Font = Enum.Font.FredokaOne
                            fallback.TextScaled = true
                            fallback.AutoLocalize = true
                            fallback.Parent = slotData.Viewport
                        end
                    end
                end)
            end

            slotData.Button.BackgroundTransparency = 0.1
            
            if tool.Parent == player.Character then
                -- Equipped
                slotData.Highlight.Transparency = 0
                slotData.Button.BackgroundColor3 = Color3.fromRGB(70, 130, 180) -- Blue tint
            else
                -- Not equipped
                slotData.Highlight.Transparency = 1
                slotData.Button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            end
        else
            -- Hide slot entirely if empty
            slotData.Tool = nil
            slotData.Button.Visible = false
        end
    end
end

local toolConnections = {}

-- Hook up backpack/character events
local function hookCharacter(char)
    char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            if not toolConnections[child] then
                toolConnections[child] = child.Activated:Connect(function()
                    pcall(function() HapticManager.mediumPulse() end)
                end)
            end
            updateInventoryUI()
        end
    end)
    char.ChildRemoved:Connect(function(child)
        if child:IsA("Tool") then
            if toolConnections[child] then
                toolConnections[child]:Disconnect()
                toolConnections[child] = nil
            end
            updateInventoryUI()
        end
    end)
    
    -- Check existing children
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") and not toolConnections[child] then
            toolConnections[child] = child.Activated:Connect(function()
                pcall(function() HapticManager.mediumPulse() end)
            end)
        end
    end
    
    updateInventoryUI()
end

if player.Character then hookCharacter(player.Character) end
player.CharacterAdded:Connect(hookCharacter)

local backpackConnAdded
local backpackConnRemoved

local function hookBackpack(bp)
    if backpackConnAdded then backpackConnAdded:Disconnect() end
    if backpackConnRemoved then backpackConnRemoved:Disconnect() end
    
    backpackConnAdded = bp.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            updateInventoryUI()
            pcall(function() HapticManager.lightTap() end)
        end
    end)
    backpackConnRemoved = bp.ChildRemoved:Connect(function(child)
        if child:IsA("Tool") then updateInventoryUI() end
    end)
    updateInventoryUI()
end

if player:FindFirstChild("Backpack") then
    hookBackpack(player.Backpack)
end

player.ChildAdded:Connect(function(child)
    if child.Name == "Backpack" then
        hookBackpack(child)
    end
end)

-- Equip logic
local function toggleEquip(slotIndex)
    local tool = currentItems[slotIndex]
    if not tool then return end
    
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    if tool.Parent == char then
        -- Unequip
        humanoid:UnequipTools()
    else
        -- Equip
        humanoid:EquipTool(tool)
    end
end

-- Slot clicking
for i = 1, MAX_SLOTS do
    slots[i].Button.MouseButton1Click:Connect(function()
        toggleEquip(i)
    end)
end

-- Keyboard binding (1-9)
local keyWords = {"One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine"}
for i = 1, 9 do
    local key = Enum.KeyCode[keyWords[i]]
    ContextActionService:BindAction("EquipSlot" .. i, function(actionName, state, input)
        if state == Enum.UserInputState.Begin then
            toggleEquip(i)
        end
    end, false, key)
end

local gamepadSelectedIndex = 1

local function updateGamepadSelection()
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    local tool = currentItems[gamepadSelectedIndex]
    if tool then
        humanoid:EquipTool(tool)
    else
        humanoid:UnequipTools()
    end
end

ContextActionService:BindAction("GamepadInventoryCycleLeft", function(actionName, state, input)
    if state == Enum.UserInputState.Begin then
        gamepadSelectedIndex = gamepadSelectedIndex - 1
        if gamepadSelectedIndex < 1 then gamepadSelectedIndex = math.max(1, #currentItems) end
        updateGamepadSelection()
        pcall(function() HapticManager.lightTap() end)
    end
    return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.ButtonL1)

ContextActionService:BindAction("GamepadInventoryCycleRight", function(actionName, state, input)
    if state == Enum.UserInputState.Begin then
        gamepadSelectedIndex = gamepadSelectedIndex + 1
        if gamepadSelectedIndex > #currentItems then gamepadSelectedIndex = 1 end
        updateGamepadSelection()
        pcall(function() HapticManager.lightTap() end)
    end
    return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.ButtonR1)

-- Popup notification for "Inventory Full"
local notifyGui = Instance.new("ScreenGui")
notifyGui.Name = "NotificationUI"
notifyGui.ResetOnSpawn = false
notifyGui.DisplayOrder = 100
notifyGui.Parent = playerGui

local notifyText = Instance.new("TextLabel")
notifyText.Size = UDim2.new(0, 300, 0, 50)
notifyText.AnchorPoint = Vector2.new(0.5, 0.5)
notifyText.Position = UDim2.new(0.5, 0, 0.4, 0)
notifyText.BackgroundTransparency = 1
notifyText.Text = ""
notifyText.TextColor3 = Color3.fromRGB(255, 50, 50)
notifyText.TextStrokeTransparency = 0
notifyText.TextStrokeColor3 = Color3.new(0, 0, 0)
notifyText.Font = Enum.Font.FredokaOne
notifyText.TextSize = 36
notifyText.AutoLocalize = true
notifyText.TextTransparency = 1
notifyText.Parent = notifyGui

local notifyEvt = ReplicatedStorage:WaitForChild("ShowNotification", 5)
if notifyEvt then
    notifyEvt.OnClientEvent:Connect(function(msg)
        notifyText.Text = TranslationHelper.translate(msg)
        notifyText.TextTransparency = 0
        notifyText.TextStrokeTransparency = 0
        notifyText.Position = UDim2.new(0.5, 0, 0.45, 0)
        
        local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        TweenService:Create(notifyText, tweenInfo, {Position = UDim2.new(0.5, 0, 0.4, 0)}):Play()
        
        task.delay(1.5, function()
            local fadeInfo = TweenInfo.new(0.5)
            TweenService:Create(notifyText, fadeInfo, {
                TextTransparency = 1,
                TextStrokeTransparency = 1,
                Position = UDim2.new(0.5, 0, 0.35, 0)
            }):Play()
        end)
    end)
end
