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
local lavaEmitters = {}

local function createLavaParticlesForPart(child)
    if child:FindFirstChild("LavaParticles") then return end
    
    local perfMode = player:GetAttribute("PerformanceMode")
    local enabled = not perfMode
    
    local emitter = Instance.new("ParticleEmitter")
    emitter.Name = "LavaParticles"
    emitter.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 180, 0)), -- Yellow-orange core
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 69, 0)), -- Bright orange
        ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 0, 0))    -- Dark red/smoke
    })
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(0.5, 0.45),
        NumberSequenceKeypoint.new(1, 0.1)
    })
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(0.8, 0.4),
        NumberSequenceKeypoint.new(1, 1)
    })
    emitter.Lifetime = NumberRange.new(1.0, 2.0)
    emitter.Rate = 4 -- Sparse and distinct bubble pops
    emitter.Speed = NumberRange.new(6.0, 12.0)
    emitter.Acceleration = Vector3.new(0, -12.0, 0) -- Gentle gravity pulls them back down
    emitter.SpreadAngle = Vector2.new(10, 10) -- Shoots mostly straight up and down
    emitter.EmissionDirection = Enum.NormalId.Top
    emitter.Enabled = enabled
    emitter.Parent = child
    
    table.insert(lavaEmitters, emitter)
end

local function isPartForJustLava(part)
    if not part:IsA("BasePart") then return false end
    if part.Name == "JustLava" then return true end
    
    local parent = part.Parent
    while parent and parent ~= workspace and parent.Name ~= "MazeElements" do
        if parent.Name == "JustLava" then
            return true
        end
        parent = parent.Parent
    end
    return false
end

local function setupLavaParticles()
    -- Clear old emitters
    for _, emitter in ipairs(lavaEmitters) do
        if emitter.Parent then
            emitter:Destroy()
        end
    end
    table.clear(lavaEmitters)
    
    local mazeElements = workspace:WaitForChild("MazeElements", 20)
    if not mazeElements then return end
    
    for _, child in ipairs(mazeElements:GetDescendants()) do
        if isPartForJustLava(child) then
            createLavaParticlesForPart(child)
        end
    end
end

-- Sync with Performance Mode
local function updatePerformance()
    local perfMode = player:GetAttribute("PerformanceMode")
    local enabled = not perfMode
    
    fireflies.Enabled = enabled
    
    local activeEmitters = {}
    for _, emitter in ipairs(lavaEmitters) do
        if emitter.Parent then
            emitter.Enabled = enabled
            table.insert(activeEmitters, emitter)
        end
    end
    lavaEmitters = activeEmitters
end

updatePerformance()
player:GetAttributeChangedSignal("PerformanceMode"):Connect(updatePerformance)

-- Re-setup particles when the maze is generated
local function onMazeGeneratedChanged()
    if workspace:GetAttribute("MazeGenerated") then
        task.spawn(setupLavaParticles)
    else
        for _, emitter in ipairs(lavaEmitters) do
            if emitter.Parent then
                emitter:Destroy()
            end
        end
        table.clear(lavaEmitters)
    end
end

if workspace:GetAttribute("MazeGenerated") then
    task.spawn(setupLavaParticles)
end
workspace:GetAttributeChangedSignal("MazeGenerated"):Connect(onMazeGeneratedChanged)

-- Handle streaming and dynamic replication
workspace.DescendantAdded:Connect(function(desc)
    if not workspace:GetAttribute("MazeGenerated") then return end
    if isPartForJustLava(desc) then
        local mazeElements = workspace:FindFirstChild("MazeElements")
        if mazeElements and desc:IsDescendantOf(mazeElements) then
            createLavaParticlesForPart(desc)
        end
    end
end)
