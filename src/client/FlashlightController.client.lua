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

local function isGameLoading()
    return playerGui and playerGui:FindFirstChild("LoadingScreen") ~= nil
end

local function isCharacterInSafeZone(character)
    if not character then return false end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    local playerPos = Vector2.new(hrp.Position.X, hrp.Position.Z)
    
    -- Check distance to Base model pivot
    local baseModel = workspace:FindFirstChild("Base")
    if baseModel then
        local basePivot = baseModel:GetPivot()
        local centerPos = Vector2.new(basePivot.Position.X, basePivot.Position.Z)
        if (playerPos - centerPos).Magnitude < 45 then
            return true
        end
    end
    
    -- Check SafeZone2 if it exists
    local safeZone2 = workspace:FindFirstChild("SafeZone2")
    if safeZone2 and safeZone2:IsA("BasePart") then
        local sz2Pos = Vector2.new(safeZone2.Position.X, safeZone2.Position.Z)
        local sz2Radius = math.max(safeZone2.Size.X, safeZone2.Size.Z) / 2 + 5
        if (playerPos - sz2Pos).Magnitude < sz2Radius then
            return true
        end
    end
    
    return false
end

local isLightCurrentlyOn = false

-- On (re)spawn, sync the flag so we don't fire the "on" sound if flashlight is
-- already active (e.g. spawned in base where it is off).
local function syncFlashlightFlagForChar(char)
    task.defer(function()
        local hrp = char:WaitForChild("HumanoidRootPart", 5)
        if hrp then
            local inSafeZone = isCharacterInSafeZone(char) or isGameLoading()
            local holdingFlashlight = char:FindFirstChild("Flashlight") ~= nil
            local hasHelmet = player:GetAttribute("HasHelmet") or false
            isLightCurrentlyOn = (holdingFlashlight or hasHelmet) and not inSafeZone
            
            local _, light = getOrCreateLight(char, hrp)
            if light then
                light.Enabled = isLightCurrentlyOn
            end
        else
            isLightCurrentlyOn = false
        end
    end)
end

if player.Character then syncFlashlightFlagForChar(player.Character) end
player.CharacterAdded:Connect(syncFlashlightFlagForChar)

-- Clean up old FlashlightHUD if it exists
local oldGui = player:WaitForChild("PlayerGui"):FindFirstChild("FlashlightHUD")
if oldGui then oldGui:Destroy() end

-- Clean up cache when players leave
Players.PlayerRemoving:Connect(function(p)
    playerLightCache[p] = nil
end)

local function cleanupOldHandleAttachments(char)
    local tool = char:FindFirstChild("Flashlight")
    if tool then
        local handle = tool:FindFirstChild("Handle")
        if handle then
            local oldAttach = handle:FindFirstChild("LightAttachment")
            if oldAttach then oldAttach:Destroy() end
        end
    end
    
    local helmet = char:FindFirstChild("FlashlightHelmet")
    if helmet then
        for _, desc in ipairs(helmet:GetDescendants()) do
            if desc:IsA("SpotLight") then
                desc:Destroy()
            end
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
    cachedLocalUpgraded = player:GetAttribute("HasHelmet") or false
end

local function hookLocalCharacter(char)
    -- Disconnect old connections
    if localToolAddedConn then localToolAddedConn:Disconnect() end
    if localToolRemovedConn then localToolRemovedConn:Disconnect() end
    
    localToolAddedConn = char.ChildAdded:Connect(function(child)
        if child.Name == "Flashlight" or child.Name == "HumanoidRootPart" or child.Name == "FlashlightHelmet" then
            if child.Name == "FlashlightHelmet" then
                task.defer(function()
                    for _, desc in ipairs(child:GetDescendants()) do
                        if desc:IsA("SpotLight") then
                            desc:Destroy()
                        end
                    end
                end)
            end
            refreshLocalCache()
        end
    end)
    localToolRemovedConn = char.ChildRemoved:Connect(function(child)
        if child.Name == "Flashlight" or child.Name == "HumanoidRootPart" or child.Name == "FlashlightHelmet" then
            refreshLocalCache()
        end
    end)
    
    refreshLocalCache()
end

player.CharacterAdded:Connect(hookLocalCharacter)
if player.Character then hookLocalCharacter(player.Character) end
player:GetAttributeChangedSignal("HasHelmet"):Connect(refreshLocalCache)

-- Frame counter for throttling remote player updates
local frameCounter = 0

-- Update function for the LOCAL player only (runs at highest priority, every frame)
local function updateLocalFlashlight()
    local hrp = cachedLocalHrp
    if not hrp then return end
    
    local pTool = cachedLocalTool
    local _, light = getOrCreateLight(cachedLocalChar, hrp)
    if not light then return end
    
    local helmet = cachedLocalChar:FindFirstChild("FlashlightHelmet")
    if helmet then
        for _, desc in ipairs(helmet:GetDescendants()) do
            if desc:IsA("SpotLight") then
                desc:Destroy()
            end
        end
    end
    
    local inSafeZone = isCharacterInSafeZone(cachedLocalChar) or isGameLoading()
    local holdingFlashlight = (pTool ~= nil)
    local hasHelmet = cachedLocalUpgraded
    
    local shouldBeOn = (holdingFlashlight or hasHelmet) and not inSafeZone
    
    if shouldBeOn then
        if not isLightCurrentlyOn then
            isLightCurrentlyOn = true
            SoundManager.playSound(Constants.Sounds.FlashlightOn, hrp)
        end
        
        light.Enabled = true
        
        local targetBrightness = Constants.FlashlightNormal.Brightness
        local targetRange = Constants.FlashlightNormal.Range
        
        if hasHelmet then
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
        if isLightCurrentlyOn then
            isLightCurrentlyOn = false
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
        
        local pHelmet = pChar:FindFirstChild("FlashlightHelmet")
        if pHelmet then
            for _, desc in ipairs(pHelmet:GetDescendants()) do
                if desc:IsA("SpotLight") then
                    desc:Destroy()
                end
            end
        end
        
        local pTool = pChar:FindFirstChild("Flashlight")
        local pHasHelmet = p:GetAttribute("HasHelmet") or false
        local pInSafeZone = isCharacterInSafeZone(pChar)
        
        local pShouldBeOn = (pTool ~= nil or pHasHelmet) and not pInSafeZone
        
        local _, light = getOrCreateLight(pChar, pHrp)
        if not light then continue end
        
        if pShouldBeOn then
            light.Enabled = true
            
            local targetBrightness = Constants.FlashlightNormal.Brightness
            local targetRange = Constants.FlashlightNormal.Range
            
            if pHasHelmet then
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
