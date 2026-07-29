local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local function createFireflies()
    local container = Instance.new("Part")
    container.Name = "FireflyContainer"
    container.Size = Vector3.new(300, 20, 300)
    container.Position = Vector3.new(0, 10, 0)
    container.Anchored = true
    container.CanCollide = false
    container.Transparency = 1
    container.Parent = workspace
    
    local emitter = Instance.new("ParticleEmitter")
    emitter.Name = "Fireflies"
    emitter.Color = ColorSequence.new(Color3.fromRGB(200, 255, 100))
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.4),
        NumberSequenceKeypoint.new(0.5, 0.8),
        NumberSequenceKeypoint.new(1, 0.2)
    })
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0.2),
        NumberSequenceKeypoint.new(1, 1)
    })
    emitter.Lifetime = NumberRange.new(2, 5)
    emitter.Rate = 25
    emitter.Speed = NumberRange.new(1, 3)
    emitter.Acceleration = Vector3.new(0, 0.5, 0)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.EmissionDirection = Enum.NormalId.Top
    emitter.Parent = container
    
    return emitter
end

local fireflies = createFireflies()

-- Sync with Performance Mode
local function updatePerformance()
    local perfMode = player:GetAttribute("PerformanceMode")
    if perfMode == true then
        fireflies.Enabled = false
    else
        fireflies.Enabled = true
    end
end

updatePerformance()
player:GetAttributeChangedSignal("PerformanceMode"):Connect(updatePerformance)
