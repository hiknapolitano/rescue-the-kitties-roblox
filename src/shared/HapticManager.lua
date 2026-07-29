local HapticService = game:GetService("HapticService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local HapticManager = {}

local activeVibrations = {}

local startupTime = tick()
local lastVibrateTime = 0

-- Safely vibrate the gamepad
function HapticManager.vibrate(intensity, duration, motorType)
    -- Prevent vibrations right when the game loads or player spawns
    if tick() - startupTime < 5 then return end

    -- Debounce to prevent flooding the Bluetooth buffer which causes crashes
    if tick() - lastVibrateTime < 0.1 then return end
    lastVibrateTime = tick()

    -- Respect the in-game vibration toggle set by the player
    local Players = game:GetService("Players")
    local localPlayer = Players.LocalPlayer
    if localPlayer and localPlayer:GetAttribute("GamepadVibrationEnabled") == false then return end

    motorType = motorType or Enum.VibrationMotor.Small
    intensity = intensity or 0.5
    duration = duration or 0.2

    -- Only client can use HapticService
    if not RunService:IsClient() then return end

    local gamepad = Enum.UserInputType.Gamepad1
    
    local hasGamepad = UserInputService:GetGamepadConnected(gamepad)
    if not hasGamepad then return end
    
    local supportsHaptics = false
    pcall(function()
        supportsHaptics = HapticService:IsMotorSupported(gamepad, motorType)
    end)

    if supportsHaptics then
        -- Apply vibration
        pcall(function()
            HapticService:SetMotor(gamepad, motorType, intensity)
        end)
        
        -- Cancel previous reset task for this motor if it exists
        if activeVibrations[motorType] then
            task.cancel(activeVibrations[motorType])
        end
        
        -- Schedule stopping the vibration
        activeVibrations[motorType] = task.delay(duration, function()
            pcall(function()
                HapticService:SetMotor(gamepad, motorType, 0)
            end)
            activeVibrations[motorType] = nil
        end)
    end
end

-- Preset: Light tap (for collecting items, navigating)
function HapticManager.lightTap()
    HapticManager.vibrate(0.3, 0.1, Enum.VibrationMotor.Small)
end

-- Preset: Medium pulse (for using items, rescuing cats)
function HapticManager.mediumPulse()
    HapticManager.vibrate(0.6, 0.2, Enum.VibrationMotor.Small)
end

-- Preset: Heavy rumble (for taking damage)
function HapticManager.heavyRumble()
    HapticManager.vibrate(0.8, 0.3, Enum.VibrationMotor.Large)
    HapticManager.vibrate(1.0, 0.3, Enum.VibrationMotor.Small)
end

return HapticManager
