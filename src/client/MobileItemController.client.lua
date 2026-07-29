local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local currentAction = nil -- Can be "Use", "EquipFlashlight", "UnequipFlashlight", "None"

local function getEquippedTool()
    if player.Character then
        return player.Character:FindFirstChildOfClass("Tool")
    end
    return nil
end

local function hasFlashlightInBackpack()
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        return backpack:FindFirstChild("Flashlight") or backpack:FindFirstChild("flashlight")
    end
    return nil
end

local function handleUseItemAction(actionName, inputState, inputObject)
    if inputState == Enum.UserInputState.Begin then
        local tool = getEquippedTool()
        if currentAction == "EquipFlashlight" then
            local flashlight = hasFlashlightInBackpack()
            if flashlight and player.Character then
                local humanoid = player.Character:FindFirstChild("Humanoid")
                if humanoid then
                    humanoid:EquipTool(flashlight)
                end
            end
        elseif currentAction == "UnequipFlashlight" then
            if player.Character then
                local humanoid = player.Character:FindFirstChild("Humanoid")
                if humanoid then
                    humanoid:UnequipTools()
                end
            end
        elseif currentAction == "Use" then
            if tool then
                tool:Activate()
            end
        end
    elseif inputState == Enum.UserInputState.End then
        local tool = getEquippedTool()
        if currentAction == "Use" and tool then
            tool:Deactivate()
        end
    end
    return Enum.ContextActionResult.Pass
end

-- Use Item bound to ButtonB (Circle). R2 is now Sprint.
ContextActionService:BindAction("UseItem", handleUseItemAction, false, Enum.KeyCode.ButtonB)

-- Build a clean custom touch button for mobile
local useItemBtn = nil
local useItemGui = nil

if UserInputService.TouchEnabled then
    local playerGui = player:WaitForChild("PlayerGui")

    useItemGui = Instance.new("ScreenGui")
    useItemGui.Name = "UseItemButtonGui"
    useItemGui.ResetOnSpawn = false
    useItemGui.DisplayOrder = 5
    useItemGui.IgnoreGuiInset = true
    useItemGui.Parent = playerGui

    -- Pill-shaped button above the sprint and jump buttons
    -- Styled like the "Flashlight On" label seen in screenshot but much cleaner
    useItemBtn = Instance.new("ImageButton")
    useItemBtn.Name = "UseItemButton"
    useItemBtn.Size = UDim2.new(0, 160, 0, 55)
    useItemBtn.AnchorPoint = Vector2.new(1, 1)
    useItemBtn.Position = UDim2.new(1, -15, 1, -100)
    useItemBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    useItemBtn.BackgroundTransparency = 0.25
    useItemBtn.BorderSizePixel = 0
    useItemBtn.Image = "" -- No image texture, clean background
    useItemBtn.Visible = false
    useItemBtn.Parent = useItemGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 20)
    corner.Parent = useItemBtn

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Transparency = 0.7
    stroke.Thickness = 1.5
    stroke.Parent = useItemBtn

    -- Press whitening feedback
    local pressOverlay = Instance.new("Frame")
    pressOverlay.Size = UDim2.new(1, 0, 1, 0)
    pressOverlay.BackgroundColor3 = Color3.new(1, 1, 1)
    pressOverlay.BackgroundTransparency = 1
    pressOverlay.BorderSizePixel = 0
    pressOverlay.ZIndex = 2
    local overlayCorner = Instance.new("UICorner")
    overlayCorner.CornerRadius = UDim.new(0, 20)
    overlayCorner.Parent = pressOverlay
    pressOverlay.Parent = useItemBtn

    local label = Instance.new("TextLabel")
    label.Name = "ActionTitle"
    label.Size = UDim2.new(1, -16, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 17
    label.Text = ""
    label.AutoLocalize = true
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.Parent = useItemBtn

    -- Wire up touch events
    useItemBtn.MouseButton1Down:Connect(function()
        pressOverlay.BackgroundTransparency = 0.6
        handleUseItemAction("UseItem", Enum.UserInputState.Begin, nil)
    end)
    useItemBtn.MouseButton1Up:Connect(function()
        pressOverlay.BackgroundTransparency = 1
        handleUseItemAction("UseItem", Enum.UserInputState.End, nil)
    end)
    useItemBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            pressOverlay.BackgroundTransparency = 1
            handleUseItemAction("UseItem", Enum.UserInputState.End, nil)
        end
    end)
end

local isBound = false

local function updateButtonLogic()
    local tool = getEquippedTool()
    local flashlight = hasFlashlightInBackpack()
    
    local targetAction = "None"
    local btnText = ""
    
    if tool then
        if string.lower(tool.Name) == "shield" then
            targetAction = "None"
        elseif string.lower(tool.Name) == "flashlight" then
            targetAction = "UnequipFlashlight"
            btnText = "Flashlight Off"
        else
            targetAction = "Use"
            btnText = "Use " .. tool.Name
        end
    else
        if flashlight then
            targetAction = "EquipFlashlight"
            btnText = "Flashlight On"
        else
            targetAction = "None"
        end
    end
    
    currentAction = targetAction
    
    -- Show/hide and update the custom touch button
    if useItemBtn then
        if targetAction == "None" then
            useItemBtn.Visible = false
        else
            useItemBtn.Visible = true
            local lbl = useItemBtn:FindFirstChild("ActionTitle")
            if lbl then lbl.Text = btnText end
        end
    end
end

-- Hook into changes
local function setupCharacter(char)
    updateButtonLogic()
    char.ChildAdded:Connect(updateButtonLogic)
    char.ChildRemoved:Connect(updateButtonLogic)
end

if player.Character then
    setupCharacter(player.Character)
end
player.CharacterAdded:Connect(setupCharacter)

local backpack = player:WaitForChild("Backpack")
backpack.ChildAdded:Connect(updateButtonLogic)
backpack.ChildRemoved:Connect(updateButtonLogic)

updateButtonLogic()
