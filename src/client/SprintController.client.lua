local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local SoundManager = require(Shared:WaitForChild("SoundManager"))

local player = Players.LocalPlayer

local currentStamina = Constants.StaminaMax
local isExhausted = false
-- Mobile auto-sprint cooldown: once stamina hits 0, must recover to 50% before auto-sprinting again
local mobileSprintCooldown = false

local staminaSound = nil
local slimeSound = nil

local isMobile = UserInputService.TouchEnabled

-- Cached raycast params (reused every frame instead of recreating)
local sprintSlimeParams = nil
local cachedFilterChar = nil

-- ── PC / CONSOLE SPRINT BUTTON ──────────────────────────────────────────────
-- On mobile we skip the button and all manual sprint input entirely.
local isHoldingSprint = false  -- only ever set to true on PC/console

if not isMobile then
    local function handleSprintAction(actionName, inputState, inputObject)
        if inputState == Enum.UserInputState.Begin then
            isHoldingSprint = true
        elseif inputState == Enum.UserInputState.End then
            isHoldingSprint = false
        end
        -- Sink the input so R1 doesn't propagate to other actions
        return Enum.ContextActionResult.Sink
    end
    -- Sprint: LeftShift (keyboard) or R1 (gamepad).
    -- R2 is NOT used because Roblox maps R2 to tool activation (left-click) by default.
    ContextActionService:BindAction("Sprint", handleSprintAction, false,
        Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonR1)
end

-- Cache player references for sprint
local cachedSprintChar = nil
local cachedSprintHumanoid = nil

local function refreshSprintCache()
    cachedSprintChar = player.Character
    cachedSprintHumanoid = cachedSprintChar and cachedSprintChar:FindFirstChild("Humanoid")
end

player.CharacterAdded:Connect(function(char)
    -- Reset sprint state
    currentStamina = Constants.StaminaMax
    isExhausted = false
    isHoldingSprint = false
    mobileSprintCooldown = false
    if staminaSound then SoundManager.stopSound(staminaSound); staminaSound = nil end
    if slimeSound then SoundManager.stopSound(slimeSound); slimeSound = nil end
    
    -- Refresh cached references
    cachedSprintChar = char
    cachedSprintHumanoid = nil
    local hum = char:WaitForChild("Humanoid", 10)
    cachedSprintHumanoid = hum
    -- Reset filter when character changes
    cachedFilterChar = nil
end)
refreshSprintCache()

RunService.RenderStepped:Connect(function(dt)
    local char = cachedSprintChar
    local humanoid = cachedSprintHumanoid

    if not humanoid then return end

    local isMoving = humanoid.MoveDirection.Magnitude > 0

    -- ── Determine sprint intent ─────────────────────────────────────────────
    local wantToSprint
    if isMobile then
        -- Auto-sprint: only when a dog is actively chasing this player
        local beingChased = (player:GetAttribute("DogChasingCount") or 0) > 0

        -- Cooldown logic:
        --   • Once stamina hits 0 → mobileSprintCooldown = true (stop auto-sprint)
        --   • Stay in cooldown until stamina recovers to 50%
        --   • Only then allow auto-sprint again
        if isExhausted then
            mobileSprintCooldown = true
        end
        if mobileSprintCooldown and currentStamina >= (Constants.StaminaMax * 0.5) then
            mobileSprintCooldown = false
        end

        wantToSprint = beingChased and not mobileSprintCooldown
    else
        -- PC/console: player holds the sprint key / button
        wantToSprint = isHoldingSprint
    end

    local isSprinting = wantToSprint and isMoving and not isExhausted

    -- ── Slime detection ─────────────────────────────────────────────────────
    local inSlime = false
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if rootPart then
        -- Cache params and update filter only when character changes
        if not sprintSlimeParams then
            sprintSlimeParams = RaycastParams.new()
            sprintSlimeParams.FilterType = Enum.RaycastFilterType.Exclude
        end
        -- Only recreate the filter table when the character actually changes
        if cachedFilterChar ~= char then
            cachedFilterChar = char
            sprintSlimeParams.FilterDescendantsInstances = {char}
        end

        local hit = workspace:Raycast(rootPart.Position, Vector3.new(0, -4, 0), sprintSlimeParams)
        if hit then
            local inst = hit.Instance
            if inst.Name == "Slime" or (inst.Parent and inst.Parent.Name == "Slime")
            or inst.Name == "Mud"   or (inst.Parent and inst.Parent.Name == "Mud") then
                inSlime = true
            end
        end
    end

    if inSlime or player:GetAttribute("InBoat") then isSprinting = false end

    if inSlime and isMoving then
        if not slimeSound then
            slimeSound = SoundManager.playSound(Constants.Sounds.SlimeWalk, rootPart, true)
        end
    else
        if slimeSound then
            SoundManager.stopSound(slimeSound)
            slimeSound = nil
        end
    end

    -- ── Stamina ─────────────────────────────────────────────────────────────
    if isSprinting then
        if not staminaSound then
            staminaSound = SoundManager.playSound(Constants.Sounds.StaminaDrain, rootPart, true)
        end
        currentStamina = math.max(0, currentStamina - (Constants.StaminaDrainRate * dt))
        if currentStamina <= 0 then
            isExhausted = true
        end
    else
        if staminaSound then
            SoundManager.stopSound(staminaSound)
            staminaSound = nil
        end
        currentStamina = math.min(Constants.StaminaMax, currentStamina + (Constants.StaminaRecoverRate * dt))
        -- Exhaustion clears when stamina recovers to 25% (same threshold as before for PC)
        if isExhausted and currentStamina > (Constants.StaminaMax * 0.25) then
            isExhausted = false
        end
    end

    -- ── Speed ───────────────────────────────────────────────────────────────
    local speedBoostEnd = char:GetAttribute("SpeedBoostEnd") or 0
    local isBoosted = speedBoostEnd > workspace:GetServerTimeNow()
    local multiplier = isBoosted and 1.5 or 1.0

    local targetSpeed = (isSprinting and Constants.PlayerRunSpeed or Constants.PlayerWalkSpeed) * multiplier
    if inSlime then targetSpeed = Constants.PlayerWalkSpeed * 0.4 end

    humanoid.WalkSpeed = targetSpeed

    -- Footstep pitch shift
    if rootPart then
        local runningSound = rootPart:FindFirstChild("Running")
        if runningSound and runningSound:IsA("Sound") then
            local speed = rootPart.AssemblyLinearVelocity.Magnitude
            local speedRatio = math.max(0,
                (speed - Constants.PlayerWalkSpeed) / (Constants.PlayerRunSpeed - Constants.PlayerWalkSpeed))
            if inSlime then
                runningSound.PlaybackSpeed = Constants.FootstepBasePitch * 0.7
            else
                runningSound.PlaybackSpeed = Constants.FootstepBasePitch + (speedRatio * Constants.FootstepPitchShiftAmount)
            end
        end
    end

    -- ── Visual Boost Effect ─────────────────────────────────────────────────
    local camera = workspace.CurrentCamera
    local lighting = game:GetService("Lighting")

    local blur = lighting:FindFirstChild("SpeedBlur")
    if not blur then
        blur = Instance.new("BlurEffect")
        blur.Name = "SpeedBlur"
        blur.Parent = lighting
    end

    if camera then
        local targetFOV = isBoosted and 95 or 70
        camera.FieldOfView = camera.FieldOfView + (targetFOV - camera.FieldOfView) * 10 * dt
    end

    local targetBlur = isBoosted and 4 or 0
    blur.Size = blur.Size + (targetBlur - blur.Size) * 10 * dt

    -- Save attributes for HUD and DogAI
    player:SetAttribute("Stamina", currentStamina)
    player:SetAttribute("IsSprinting", isSprinting)
end)
