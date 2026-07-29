local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local player = Players.LocalPlayer

local function createDirtParticle(character)
    local rootPart = character:WaitForChild("HumanoidRootPart", 5)
    local humanoid = character:WaitForChild("Humanoid", 5)
    
    if not rootPart or not humanoid then return end
    
    local attachment = Instance.new("Attachment")
    -- Position it slightly below the root part to ensure it's not buried
    attachment.Position = Vector3.new(0, -2.5, 0) 
    attachment.Parent = rootPart
    
    local emitter = Instance.new("ParticleEmitter")
    emitter.Name = "DirtKickup"
    emitter.Enabled = false
    emitter.Color = ColorSequence.new(Constants.MudParticleColor) -- Muddy brown
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, Constants.MudParticleSize),
        NumberSequenceKeypoint.new(1, 0)
    })
    emitter.ZOffset = 1 -- Ensure it renders above the ground
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1)
    })
    emitter.Lifetime = NumberRange.new(0.3, 0.6)
    emitter.Rate = 40
    emitter.Speed = NumberRange.new(3, 7)
    emitter.Acceleration = Vector3.new(0, -10, 0)
    emitter.Drag = 2
    emitter.SpreadAngle = Vector2.new(45, 45)
    emitter.EmissionDirection = Enum.NormalId.Top
    emitter.Parent = attachment
    
    -- Loop to track movement and state
    local connection
    connection = RunService.Heartbeat:Connect(function()
        if not character.Parent or humanoid.Health <= 0 then
            connection:Disconnect()
            return
        end
        
        -- Are we moving?
        local isMoving = humanoid.MoveDirection.Magnitude > 0
        -- Are we on the ground? (not jumping or falling)
        local onGround = humanoid.FloorMaterial ~= Enum.Material.Air
        
        if isMoving and onGround then
            -- Increase rate if running fast
            local speed = humanoid.WalkSpeed
            if speed > 16 then
                emitter.Rate = 60
                emitter.Speed = NumberRange.new(5, 10)
            else
                emitter.Rate = 30
                emitter.Speed = NumberRange.new(3, 7)
            end
            
            local perfMode = player:GetAttribute("PerformanceMode")
            if perfMode == true then
                emitter.Enabled = false
            else
                emitter.Enabled = true
            end
        else
            emitter.Enabled = false
        end
    end)
end

if player.Character then
    createDirtParticle(player.Character)
end

player.CharacterAdded:Connect(createDirtParticle)
