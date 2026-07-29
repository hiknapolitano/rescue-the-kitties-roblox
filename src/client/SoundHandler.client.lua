-- SoundHandler.client.lua
-- Listens to PlaySoundClient remote events and plays sounds locally.
-- This ensures personal sounds (cat rescue, item use, damage, etc.)
-- are only heard by the intended player — not replicated to others.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local SoundManager = require(Shared:WaitForChild("SoundManager"))

local player = Players.LocalPlayer

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local playSoundRemote = remotesFolder:WaitForChild("PlaySoundClient", 10)
if not playSoundRemote then
    -- If it hasn't been created yet, wait longer
    playSoundRemote = remotesFolder:WaitForChild("PlaySoundClient")
end

playSoundRemote.OnClientEvent:Connect(function(soundName, pitchOverride)
    local soundConfig = Constants.Sounds[soundName]
    if not soundConfig then
        warn("[SoundHandler] Unknown sound name:", soundName)
        return
    end
    
    -- If a pitch override was provided, clone the config and apply it
    if pitchOverride then
        if type(soundConfig) == "table" then
            soundConfig = table.clone(soundConfig)
            soundConfig.PlaybackSpeed = pitchOverride
        end
    end
    
    -- Play on the local player's character HRP (or fallback to workspace)
    local char = player.Character
    local parent = char and char:FindFirstChild("HumanoidRootPart") or workspace
    SoundManager.playSound(soundConfig, parent)
end)
