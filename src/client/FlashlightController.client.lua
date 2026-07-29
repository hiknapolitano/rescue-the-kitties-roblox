-- FlashlightController.client.lua
-- Optimized: BindToRenderStep for zero-lag local player light,
-- throttled updates for other players, all lookups cached.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local SoundManager = require(Shared:WaitForChild("SoundManager"))

local player = Players.LocalPlayer

local wasFlashlightEquipped = false

-- On (re)spawn, sync the flag so we don't fire the "on" sound if flashlight is
-- already equipped (e.g. the server gives it immediately at spawn start).
local function syncFlashlightFlagForChar(char)
    wasFlashlightEquipped = char:FindFirstChild("Flashlight") ~= nil
end
if player.Character then syncFlashlightFlagForChar(player.Character) end
player.CharacterAdded:Connect(syncFlashlightFlagForChar)

-- Clean up old FlashlightHUD if it exists
local oldGui = player:WaitForChild("PlayerGui"):FindFirstChild("FlashlightHUD")
if oldGui then oldGui:Destroy() end

-- Cache of per-player light setups: { [Player] = { attach, light, hrp } }
local playerLightCache = {}

local function getOrCreateLight(pChar, pHrp)
    local pPlayer = Players:GetPlayerFromCharacter(pChar)
    if not pPlayer then return nil, nil end
    
    local cached = playerLightCache[pPlayer]
    if cached and cached.hrp == pHrp and cached.attach.Parent == pHrp then
        return cached.attach, cached.light
    end
    
    -- Create new attachment + light
    local attach = pHrp:FindFirstChild("LocalFlashlightAttachment")
    if not attach then
        attach = Instance.new("Attachment")
        attach.Name = "LocalFlashlightAttachment"
        attach.Position = Vector3.new(0, 0.5, -0.5)
        attach.Parent = pHrp
        
        local light = Instance.new("SpotLight")
        light.Name = "Light"
        light.Range = Constants.FlashlightNormal.Range
        light.Angle = 100
        light.Color = Color3.new(1, 1, 0.9)
        light.Shadows = false -- Shadows on spotlights are extremely expensive
        light.Enabled = false
        light.Parent = attach
    end
    
    local light = attach:FindFirstChild("Light")
    playerLightCache[pPlayer] = { attach = attach, light = light, hrp = pHrp }
    return attach, light
end

-- Clean up cache when players leave
Players.PlayerRemoving:Connect(function(p)
    playerLightCache[p] = nil
end)

-- Clean up old handle-based attachments once per character spawn, not per frame
local function cleanupOldHandleAttachments(char)
    local tool = char:FindFirstChild("Flashlight")
    if tool then
        local handle = tool:FindFirstChild("Handle")
        if handle then
            local oldAttach = handle:FindFirstChild("LightAttachment")
            if oldAttach then oldAttach:Destroy() end
        end
    end
end

player.CharacterAdded:Connect(function(char)
    task.defer(function()
        cleanupOldHandleAttachments(char)
    end)
end)
if player.Character then
    task.defer(function()
        cleanupOldHandleAttachments(player.Character)
    end)
end

-- Pre-cached values for local player fast-path
local cachedLocalChar = nil
local cachedLocalHrp = nil
local cachedLocalTool = nil
local cachedLocalUpgraded = nil

-- Refresh local player cache when character or tool changes
local localCharConn = nil
local localToolAddedConn = nil
local localToolRemovedConn = nil

local function refreshLocalCache()
    local char = player.Character
    cachedLocalChar = char
    cachedLocalHrp = char and char:FindFirstChild("HumanoidRootPart") or nil
    cachedLocalTool = char and char:FindFirstChild("Flashlight") or nil
    cachedLocalUpgraded = player:GetAttribute("HasUpgradedFlashlight") or false
end

local function hookLocalCharacter(char)
    -- Disconnect old connections
    if localToolAddedConn then localToolAddedConn:Disconnect() end
    if localToolRemovedConn then localToolRemovedConn:Disconnect() end
    
    localToolAddedConn = char.ChildAdded:Connect(function(child)
        if child.Name == "Flashlight" or child.Name == "HumanoidRootPart" then
            refreshLocalCache()
        end
    end)
    localToolRemovedConn = char.ChildRemoved:Connect(function(child)
        if child.Name == "Flashlight" or child.Name == "HumanoidRootPart" then
            refreshLocalCache()
        end
    end)
    
    refreshLocalCache()
end

player.CharacterAdded:Connect(hookLocalCharacter)
if player.Character then hookLocalCharacter(player.Character) end
player:GetAttributeChangedSignal("HasUpgradedFlashlight"):Connect(refreshLocalCache)

-- Frame counter for throttling remote player updates
local frameCounter = 0

-- Update function for the LOCAL player only (runs at highest priority, every frame)
local function updateLocalFlashlight()
    local hrp = cachedLocalHrp
    if not hrp then return end
    
    local pTool = cachedLocalTool
    local _, light = getOrCreateLight(cachedLocalChar, hrp)
    if not light then return end
    
    if pTool then
        if not wasFlashlightEquipped then
            wasFlashlightEquipped = true
            SoundManager.playSound(Constants.Sounds.FlashlightOn, hrp)
        end
        
        light.Enabled = true
        
        local targetBrightness = Constants.FlashlightNormal.Brightness
        local targetRange = Constants.FlashlightNormal.Range
        
        if cachedLocalUpgraded then
            targetBrightness = Constants.FlashlightUpgrade.Brightness
            targetRange = Constants.FlashlightUpgrade.Range
        end
        
        if light.Brightness ~= targetBrightness then
            light.Brightness = targetBrightness
        end
        if light.Range ~= targetRange then
            light.Range = targetRange
        end
    else
        if wasFlashlightEquipped then
            wasFlashlightEquipped = false
            SoundManager.playSound(Constants.Sounds.FlashlightOff, hrp)
        end
        light.Enabled = false
    end
end

-- Update function for OTHER players (throttled to every 3 frames)
local function updateRemoteFlashlights()
    for _, p in ipairs(Players:GetPlayers()) do
        if p == player then continue end
        
        local pChar = p.Character
        if not pChar then continue end
        
        local pHrp = pChar:FindFirstChild("HumanoidRootPart")
        if not pHrp then continue end
        
        local pTool = pChar:FindFirstChild("Flashlight")
        
        local _, light = getOrCreateLight(pChar, pHrp)
        if not light then continue end
        
        if pTool then
            light.Enabled = true
            
            local targetBrightness = Constants.FlashlightNormal.Brightness
            local targetRange = Constants.FlashlightNormal.Range
            
            if p:GetAttribute("HasUpgradedFlashlight") then
                targetBrightness = Constants.FlashlightUpgrade.Brightness
                targetRange = Constants.FlashlightUpgrade.Range
            end
            
            if light.Brightness ~= targetBrightness then
                light.Brightness = targetBrightness
            end
            if light.Range ~= targetRange then
                light.Range = targetRange
            end
        else
            light.Enabled = false
        end
    end
end

-- Bind local flashlight update at Camera+1 priority (runs before camera renders)
RunService:BindToRenderStep("LocalFlashlight", Enum.RenderPriority.Camera.Value + 1, function()
    updateLocalFlashlight()
    
    -- Throttle remote players to every 3 frames
    frameCounter = frameCounter + 1
    if frameCounter >= 3 then
        frameCounter = 0
        updateRemoteFlashlights()
    end
end)
