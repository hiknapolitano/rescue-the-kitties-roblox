local TweenService = game:GetService("TweenService")
local SoundManager = {}

function SoundManager.playSound(soundConfig, parent, overrideLoop, maxDistance)
    if not soundConfig then return nil end
    
    local soundId, volume, fadeIn, fadeOut, looped, pitch, playbackStart
    
    if type(soundConfig) == "table" then
        soundId = soundConfig.SoundId
        volume = soundConfig.Volume or 1
        fadeIn = soundConfig.FadeInDuration or 0
        fadeOut = soundConfig.FadeOutDuration or 0
        looped = overrideLoop ~= nil and overrideLoop or (soundConfig.Looped or false)
        pitch = soundConfig.PlaybackSpeed or 1
        playbackStart = soundConfig.PlaybackStart or 0
    else
        soundId = soundConfig
        volume = 1
        fadeIn = 0
        fadeOut = 0
        looped = overrideLoop or false
        pitch = 1
        playbackStart = 0
    end

    local isMusic = false
    pcall(function()
        local Shared = ReplicatedStorage:FindFirstChild("Shared")
        local Constants = Shared and require(Shared:FindFirstChild("Constants"))
        if Constants and Constants.Sounds and Constants.Sounds.BackgroundMusic then
            if soundId == Constants.Sounds.BackgroundMusic.SoundId then
                isMusic = true
            end
        end
    end)
    
    local baseVolume = volume
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    if player then
        local volMultiplier = 1
        if isMusic then
            volMultiplier = player:GetAttribute("MusicVolume") or 1
        else
            volMultiplier = player:GetAttribute("SFXVolume") or 1
        end
        volume = volume * volMultiplier
    end

    if soundId == "rbxassetid://0" or soundId == "" or not soundId then return nil end
    
    local sound = nil
    local SoundService = game:GetService("SoundService")
    local soundCache = SoundService:FindFirstChild("SoundCache")
    if soundCache then
        for _, child in ipairs(soundCache:GetChildren()) do
            if child:IsA("Sound") and child.SoundId == soundId then
                sound = child:Clone()
                break
            end
        end
    end
    
    if not sound then
        sound = Instance.new("Sound")
        sound.SoundId = soundId
    end
    
    sound.Parent = parent or workspace
    sound.Looped = looped
    sound.PlaybackSpeed = pitch
    
    if maxDistance then
        sound.RollOffMaxDistance = maxDistance
        sound.RollOffMinDistance = 10
        sound.RollOffMode = Enum.RollOffMode.Linear
    end
    
    sound.TimePosition = playbackStart
    if looped and playbackStart > 0 then
        sound.DidLoop:Connect(function()
            sound.TimePosition = playbackStart
        end)
    end
    
    sound:SetAttribute("OriginalVolume", baseVolume)
    sound:SetAttribute("IsMusic", isMusic)
    sound:SetAttribute("FadeOutDuration", fadeOut)
    
    if fadeIn > 0 then
        sound.Volume = 0
        sound:Play()
        local tweenInfo = TweenInfo.new(fadeIn, Enum.EasingStyle.Linear)
        local tween = TweenService:Create(sound, tweenInfo, {Volume = volume})
        tween:Play()
    else
        sound.Volume = volume
        sound:Play()
    end
    
    if not looped then
        sound.Ended:Connect(function()
            sound:Destroy()
        end)
    end
    
    return sound
end

function SoundManager.stopSound(soundInstance)
    if not soundInstance or not soundInstance:IsA("Sound") then return end
    
    local fadeOut = soundInstance:GetAttribute("FadeOutDuration") or 0
    if fadeOut > 0 then
        local tweenInfo = TweenInfo.new(fadeOut, Enum.EasingStyle.Linear)
        local tween = TweenService:Create(soundInstance, tweenInfo, {Volume = 0})
        tween:Play()
        tween.Completed:Connect(function()
            soundInstance:Stop()
            soundInstance:Destroy()
        end)
    else
        soundInstance:Stop()
        soundInstance:Destroy()
    end
end

function SoundManager.playClick(soundConfig, parent)
    -- Helper for UI clicks (doesn't need 3D sound)
    return SoundManager.playSound(soundConfig, parent or game:GetService("SoundService"), false, nil)
end

return SoundManager
