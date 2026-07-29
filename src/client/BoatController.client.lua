local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local player = Players.LocalPlayer
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")

local collectBoatRemote = remotesFolder:FindFirstChild("CollectBoatRemote")
if not collectBoatRemote then
    collectBoatRemote = Instance.new("RemoteEvent")
    collectBoatRemote.Name = "CollectBoatRemote"
    collectBoatRemote.Parent = remotesFolder
end

local toggleBoatRemote = remotesFolder:FindFirstChild("ToggleBoatRemote")
if not toggleBoatRemote then
    toggleBoatRemote = Instance.new("RemoteEvent")
    toggleBoatRemote.Name = "ToggleBoatRemote"
    toggleBoatRemote.Parent = remotesFolder
end

local collectedBoatThisSession = false
local isInBoat = false

local function setupBoatPrompt(item)
    if not item:GetAttribute("IsBoat") or not string.match(item.Name, "_Pickup$") then return end
    
    local primary = item:IsA("Model") and (item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart", true)) or item
    if not primary:IsA("BasePart") then return end
    
    if primary:FindFirstChild("CollectBoatPrompt") then return end
    
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "CollectBoatPrompt"
    prompt.ActionText = "Collect"
    prompt.ObjectText = "Boat"
    prompt.HoldDuration = 0.5
    prompt.RequiresLineOfSight = false
    prompt.MaxActivationDistance = 15
    prompt.Parent = primary
    
    prompt.Triggered:Connect(function(triggerPlayer)
        if triggerPlayer == player then
            if not collectedBoatThisSession then
                collectedBoatThisSession = true
                item:Destroy()
                collectBoatRemote:FireServer()
            end
        end
    end)
end

local function scanBoat()
    for _, item in ipairs(workspace:GetChildren()) do
        setupBoatPrompt(item)
    end
end

workspace.ChildAdded:Connect(setupBoatPrompt)
task.spawn(function()
    while true do
        scanBoat()
        task.wait(2)
    end
end)

-- Handle Proximity Prompts on WaterTiles
local ProximityPromptService = game:GetService("ProximityPromptService")
ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
    if who == player and prompt.Name == "EnterBoatPrompt" then
        if player:GetAttribute("HasBoat") and not player:GetAttribute("InBoat") then
            toggleBoatRemote:FireServer(true, prompt.Parent.Position) -- True means "Enter", pass barrier position
        end
    end
end)

-- Enable/Disable Prompts based on Having Boat
local function updatePrompts()
    local hasBoat = player:GetAttribute("HasBoat")
    local inBoat = player:GetAttribute("InBoat")
    
    local mazeElements = workspace:FindFirstChild("MazeElements")
    if not mazeElements then return end
    
    -- Use GetDescendants so barriers nested in any sub-folder are also found
    for _, obj in ipairs(mazeElements:GetDescendants()) do
        if obj:GetAttribute("IsWaterBarrier") then
            local prompt = obj:FindFirstChild("EnterBoatPrompt")
            if prompt then
                prompt.Enabled = hasBoat and not inBoat
            end
        end
    end
end

player:GetAttributeChangedSignal("HasBoat"):Connect(updatePrompts)
player:GetAttributeChangedSignal("InBoat"):Connect(updatePrompts)

-- Run once after maze finishes, and also watch for any barriers added after that
task.spawn(function()
    if not workspace:GetAttribute("MazeGenerated") then
        workspace:GetAttributeChangedSignal("MazeGenerated"):Wait()
    end
    updatePrompts()
    
    -- Also watch for new barriers added (e.g., if maze rebuilds)
    local mazeElements = workspace:WaitForChild("MazeElements", 30)
    if mazeElements then
        mazeElements.DescendantAdded:Connect(function(obj)
            if obj:GetAttribute("IsWaterBarrier") then
                local hasBoat = player:GetAttribute("HasBoat")
                local inBoat = player:GetAttribute("InBoat")
                local prompt = obj:FindFirstChild("EnterBoatPrompt")
                if prompt then
                    prompt.Enabled = hasBoat and not inBoat
                end
            end
        end)
    end
end)

-- Dismount Logic
local ACTION_DISMOUNT = "DismountBoatAction"

local function handleDismount(actionName, inputState, inputObject)
    if actionName == ACTION_DISMOUNT and inputState == Enum.UserInputState.Begin then
        if player:GetAttribute("InBoat") then
            toggleBoatRemote:FireServer(false) -- False means "Exit"
        end
    end
end

local function isNearFirmLand()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    local Maps = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Maps"))
    local layout = Maps[Constants.ActiveLevel]
    if not layout then return false end
    
    local cellSize = Constants.CellSize
    local mazeOffset = Constants.MazeOffset or Vector3.new(0, 0, 0)
    
    local cellX = math.floor((hrp.Position.X - mazeOffset.X + cellSize/2) / cellSize) + 1
    local cellZ = math.floor((hrp.Position.Z - mazeOffset.Z + cellSize/2) / cellSize) + 1
    
    local maxDist = cellSize * 2.5
    
    -- Check a 7x7 grid around the player's current cell
    for dz = -3, 3 do
        local z = cellZ + dz
        local row = layout[z]
        if row then
            for dx = -3, 3 do
                local x = cellX + dx
                local cellType = row[x]
                if cellType then
                    -- Walkable paths (non-wall, non-hazard, non-water)
                    local isWalkable = (cellType ~= 1 and cellType ~= 24 and cellType ~= 25 and cellType ~= 26 and cellType ~= 28)
                    if isWalkable then
                        local px = (x - 1) * cellSize + mazeOffset.X
                        local pz = (z - 1) * cellSize + mazeOffset.Z
                        local dist = (Vector3.new(px, 0, pz) - Vector3.new(hrp.Position.X, 0, hrp.Position.Z)).Magnitude
                        if dist <= maxDist then
                            return true
                        end
                    end
                end
            end
        end
    end
    
    return false
end

local function bindDismount()
    ContextActionService:BindAction(ACTION_DISMOUNT, handleDismount, true, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
    ContextActionService:SetTitle(ACTION_DISMOUNT, "Dismount")
    
    -- Create ScreenGui for dismount prompt
    local playerGui = player:FindFirstChild("PlayerGui")
    if playerGui and not playerGui:FindFirstChild("DismountPromptGui") then
        local sg = Instance.new("ScreenGui")
        sg.Name = "DismountPromptGui"
        sg.ResetOnSpawn = false
        
        local tl = Instance.new("TextLabel")
        tl.Size = UDim2.new(0, 300, 0, 50)
        tl.Position = UDim2.new(0.5, -150, 0.8, -50)
        tl.BackgroundTransparency = 0.5
        tl.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        tl.Text = "Press [E] or (X) to Dismount"
        tl.TextColor3 = Color3.fromRGB(255, 255, 255)
        tl.TextScaled = true
        tl.Font = Enum.Font.FredokaOne
        tl.Parent = sg
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = tl
        
        sg.Parent = playerGui
    end
    
    -- Position mobile touch button next to the jump button
    task.spawn(function()
        local playerGui = player:FindFirstChild("PlayerGui")
        local touchGui = playerGui and playerGui:WaitForChild("TouchGui", 2)
        local jumpButton = touchGui and touchGui:WaitForChild("TouchControlFrame", 2):WaitForChild("JumpButton", 2)
        
        local button = ContextActionService:GetButton(ACTION_DISMOUNT)
        if button then
            if jumpButton then
                button.Position = UDim2.new(
                    jumpButton.Position.X.Scale, 
                    jumpButton.Position.X.Offset - 110, 
                    jumpButton.Position.Y.Scale, 
                    jumpButton.Position.Y.Offset
                )
            else
                -- Fallback position on mobile if jump button isn't resolved
                button.Position = UDim2.new(1, -250, 1, -120)
            end
        end
    end)
end

local function unbindDismount()
    ContextActionService:UnbindAction(ACTION_DISMOUNT)
    
    local playerGui = player:FindFirstChild("PlayerGui")
    if playerGui then
        local dismountGui = playerGui:FindFirstChild("DismountPromptGui")
        if dismountGui then
            dismountGui:Destroy()
        end
    end
end

local loopThread = nil
local function startLandCheckLoop()
    if loopThread then return end
    
    loopThread = task.spawn(function()
        local nearLand = false
        while player:GetAttribute("InBoat") do
            local isNear = isNearFirmLand()
            if isNear ~= nearLand then
                nearLand = isNear
                if nearLand then
                    bindDismount()
                else
                    unbindDismount()
                end
            end
            task.wait(0.1)
        end
        loopThread = nil
    end)
end

player:GetAttributeChangedSignal("InBoat"):Connect(function()
    local char = player.Character
    local humanoid = char and char:FindFirstChild("Humanoid")
    
    if player:GetAttribute("InBoat") then
        startLandCheckLoop()
        
        -- Disable Jump
        ContextActionService:BindAction("DisableJumpInBoat", function() return Enum.ContextActionResult.Sink end, false, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
        if humanoid then
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
            humanoid.JumpPower = 0
        end
    else
        unbindDismount()
        
        -- Enable Jump
        ContextActionService:UnbindAction("DisableJumpInBoat")
        if humanoid then
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
            humanoid.JumpPower = 50 -- default
        end
    end
end)
