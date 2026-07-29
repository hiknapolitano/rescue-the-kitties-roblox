local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

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
            -- Let's check if there is firm ground nearby to jump off onto.
            -- A simple raycast forward to see if we can land.
            toggleBoatRemote:FireServer(false) -- False means "Exit"
        end
    end
end

player:GetAttributeChangedSignal("InBoat"):Connect(function()
    local char = player.Character
    local humanoid = char and char:FindFirstChild("Humanoid")
    
    if player:GetAttribute("InBoat") then
        -- Bind dismount
        ContextActionService:BindAction(ACTION_DISMOUNT, handleDismount, true, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
        ContextActionService:SetTitle(ACTION_DISMOUNT, "Dismount Boat")
        
        -- Disable Jump
        ContextActionService:BindAction("DisableJumpInBoat", function() return Enum.ContextActionResult.Sink end, false, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
        if humanoid then
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
            humanoid.JumpPower = 0
        end
    else
        -- Unbind dismount
        ContextActionService:UnbindAction(ACTION_DISMOUNT)
        
        -- Enable Jump
        ContextActionService:UnbindAction("DisableJumpInBoat")
        if humanoid then
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
            humanoid.JumpPower = 50 -- default
        end
    end
end)
