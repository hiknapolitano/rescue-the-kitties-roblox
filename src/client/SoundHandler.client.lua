-- SoundHandler.client.lua
-- Listens to PlaySoundClient remote events and plays sounds locally.
-- This ensures personal sounds (cat rescue, item use, damage, etc.)
-- are only heard by the intended player — not replicated to others.
-- It also tracks all active sounds in the game (both client-side, server-replicated, 
-- looped, and non-looped) and scales their volumes dynamically based on the local player's volume sliders.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local SoundManager = require(Shared:WaitForChild("SoundManager"))

local player = Players.LocalPlayer

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local playSoundRemote = remotesFolder:WaitForChild("PlaySoundClient", 10)
if not playSoundRemote then
    playSoundRemote = remotesFolder:WaitForChild("PlaySoundClient")
end

playSoundRemote.OnClientEvent:Connect(function(soundName, pitchOverride)
    local soundConfig = Constants.Sounds[soundName]
    if not soundConfig then
        warn("[SoundHandler] Unknown sound name:", soundName)
        return
    end
    
    -- Dynamically apply gender-specific voice pitch for standard "Damage" sound if not explicitly overridden
    if soundName == "Damage" and not pitchOverride then
        local isMale = player:GetAttribute("IsMale")
        if isMale == nil then isMale = true end -- default to male pitch fallback
        if isMale then
            pitchOverride = Constants.MaleDamageSoundPitch or 0.75
        end
    end
    
    if pitchOverride then
        if type(soundConfig) == "table" then
            soundConfig = table.clone(soundConfig)
            soundConfig.PlaybackSpeed = pitchOverride
        end
    end
    
    local char = player.Character
    local parent = char and char:FindFirstChild("HumanoidRootPart") or workspace
    SoundManager.playSound(soundConfig, parent)
end)

-- Active Sound Volume Tracking System
local activeSounds = setmetatable({}, {__mode = "k"})
local lastClientVolume = setmetatable({}, {__mode = "k"})
local lastClientOriginalVolume = setmetatable({}, {__mode = "k"})
local isUpdatingVolume = {}

local function updateSoundVolume(sound)
    if isUpdatingVolume[sound] then return end
    isUpdatingVolume[sound] = true
    
    local originalVolume = sound:GetAttribute("OriginalVolume")
    if not originalVolume then
        originalVolume = sound.Volume
        lastClientOriginalVolume[sound] = originalVolume
        sound:SetAttribute("OriginalVolume", originalVolume)
    end
    
    local volumeMultiplier = player:GetAttribute("SFXVolume") or 1
    
    local targetVolume = originalVolume * volumeMultiplier
    lastClientVolume[sound] = targetVolume
    sound.Volume = targetVolume
    isUpdatingVolume[sound] = nil
end

local function registerSound(sound)
    if not sound:IsA("Sound") then return end
    if activeSounds[sound] then return end
    
    local isMusic = sound:GetAttribute("IsMusic") or (sound.Name == "BackgroundMusic")
    if isMusic then
        -- Completely ignore music sounds; they are managed separately by HUDController / music manager
        return
    end
    
    activeSounds[sound] = true
    updateSoundVolume(sound)
    
    -- Listen for attribute changes or destruction
    local connection
    connection = sound:GetAttributeChangedSignal("OriginalVolume"):Connect(function()
        if not sound.Parent then
            connection:Disconnect()
            return
        end
        
        local current = sound:GetAttribute("OriginalVolume")
        if lastClientOriginalVolume[sound] == current then
            return
        end
        
        updateSoundVolume(sound)
    end)
    
    -- Listen for property changes (like server-side volume changes/tweens/footstep scaling)
    local volumePropConnection
    volumePropConnection = sound:GetPropertyChangedSignal("Volume"):Connect(function()
        if not sound.Parent then
            volumePropConnection:Disconnect()
            return
        end
        
        if lastClientVolume[sound] == sound.Volume then
            return
        end
        
        -- If the volume change was NOT initiated by the client's own scaling code,
        -- it must be a replicated change from the server. Update the base volume.
        local newOriginalVolume = sound.Volume
        lastClientOriginalVolume[sound] = newOriginalVolume
        sound:SetAttribute("OriginalVolume", newOriginalVolume)
        updateSoundVolume(sound)
    end)
    
    sound.Destroying:Connect(function()
        activeSounds[sound] = nil
        lastClientVolume[sound] = nil
        lastClientOriginalVolume[sound] = nil
        if connection then connection:Disconnect() end
        if volumePropConnection then volumePropConnection:Disconnect() end
    end)
end

-- Scan and listen for new sounds in Workspace, SoundService, and PlayerGui
local function setupSoundListeners()
    -- Scan existing
    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc:IsA("Sound") then
            registerSound(desc)
        end
    end
    for _, desc in ipairs(SoundService:GetDescendants()) do
        if desc:IsA("Sound") then
            registerSound(desc)
        end
    end
    local playerGui = player:WaitForChild("PlayerGui", 10)
    if playerGui then
        for _, desc in ipairs(playerGui:GetDescendants()) do
            if desc:IsA("Sound") then
                registerSound(desc)
            end
        end
    end
    
    -- Listen for new additions
    workspace.DescendantAdded:Connect(function(desc)
        if desc:IsA("Sound") then
            registerSound(desc)
        end
    end)
    
    SoundService.DescendantAdded:Connect(function(desc)
        if desc:IsA("Sound") then
            registerSound(desc)
        end
    end)
    
    if playerGui then
        playerGui.DescendantAdded:Connect(function(desc)
            if desc:IsA("Sound") then
                registerSound(desc)
            end
        end)
    end
end

setupSoundListeners()

-- Update all volumes when settings change
local function updateAllVolumes()
    for sound in pairs(activeSounds) do
        if sound.Parent then
            updateSoundVolume(sound)
        else
            activeSounds[sound] = nil
        end
    end
end

player:GetAttributeChangedSignal("SFXVolume"):Connect(updateAllVolumes)
player:GetAttributeChangedSignal("MusicVolume"):Connect(updateAllVolumes)
