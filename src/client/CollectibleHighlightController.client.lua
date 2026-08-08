-- CollectibleHighlightController.client.lua
-- Dynamic white outline highlight for cats and collectible items when within interaction range
-- Manages local-only cat rescuing heart particles without runtime instantiation overhead

local ProximityPromptService = game:GetService("ProximityPromptService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local objectsFolder = ReplicatedStorage:WaitForChild("Objects", 10)
local heartTrailTemplate = objectsFolder and objectsFolder:WaitForChild("HeartTrail", 10)

-- White selection outline highlights
local highlight = Instance.new("Highlight")
highlight.Name = "SelectionOutlineHighlight"
highlight.FillTransparency = 1 -- Only outline
highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
highlight.OutlineTransparency = 0
highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
highlight.Adornee = nil
highlight.Parent = playerGui

local currentTarget = nil

local function getHighlightTarget(parent)
    if parent then
        -- Handle nested models inside container parts (like Cats)
        local visualModel = parent:FindFirstChildWhichIsA("Model")
        if visualModel then
            return visualModel
        end
        
        if parent:IsA("BasePart") then
            local model = parent.Parent
            if model and model:IsA("Model") and model ~= workspace then
                return model
            end
        end
    end
    return parent
end

ProximityPromptService.PromptShown:Connect(function(prompt)
    if prompt.ActionText == "Rescue" or prompt.ActionText == "Pick Up" or prompt.ActionText == "Collect" then
        local target = getHighlightTarget(prompt.Parent)
        if target then
            currentTarget = target
            highlight.Adornee = target
        end
    end
end)

ProximityPromptService.PromptHidden:Connect(function(prompt)
    local target = getHighlightTarget(prompt.Parent)
    if target and currentTarget == target then
        currentTarget = nil
        highlight.Adornee = nil
    end
end)

-- Heart particles management (pre-cloned and welded to cats to prevent runtime lag)
local function setupHeartTrailForCat(cat)
    if not cat:IsA("BasePart") then return end
    if cat:FindFirstChild("CatHeartTrail") then return end -- Already setup
    if not heartTrailTemplate then return end
    
    local clone = heartTrailTemplate:Clone()
    clone.Name = "CatHeartTrail"
    
    local mainPart = clone:IsA("BasePart") and clone or (clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart", true))
    if not mainPart then return end
    
    -- Prevent collisions/physics issues
    for _, p in ipairs(clone:GetDescendants()) do
        if p:IsA("BasePart") then
            p.CanCollide = false
            p.Anchored = false
            p.Massless = true
        end
    end
    if clone:IsA("BasePart") then
        clone.CanCollide = false
        clone.Anchored = false
        clone.Massless = true
    end
    
    -- Position slightly above the cat
    if clone:IsA("Model") then
        clone:PivotTo(CFrame.new(cat.Position + Vector3.new(0, 2.5, 0)))
    else
        clone.Position = cat.Position + Vector3.new(0, 2.5, 0)
    end
    
    -- Weld to cat part
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = cat
    weld.Part1 = mainPart
    weld.Parent = mainPart
    
    -- Disable all emitters by default
    for _, emitter in ipairs(clone:GetDescendants()) do
        if emitter:IsA("ParticleEmitter") then
            emitter.Enabled = false
        end
    end
    
    clone.Parent = cat
end

-- Scan and setup cats on startup & child addition
task.spawn(function()
    local catsFolder = workspace:WaitForChild("Cats", 20)
    if catsFolder then
        for _, cat in ipairs(catsFolder:GetChildren()) do
            setupHeartTrailForCat(cat)
        end
        catsFolder.ChildAdded:Connect(setupHeartTrailForCat)
    end
end)

-- Toggle heart particles locally when rescuing begins and ends
ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, playerWhoTriggered)
    if prompt.ActionText == "Rescue" then
        local cat = prompt.Parent
        local trail = cat and cat:FindFirstChild("CatHeartTrail")
        if trail then
            for _, emitter in ipairs(trail:GetDescendants()) do
                if emitter:IsA("ParticleEmitter") then
                    emitter.Enabled = true
                end
            end
        end
    end
end)

local function stopHeartTrail(prompt)
    if prompt.ActionText == "Rescue" then
        local cat = prompt.Parent
        local trail = cat and cat:FindFirstChild("CatHeartTrail")
        if trail then
            for _, emitter in ipairs(trail:GetDescendants()) do
                if emitter:IsA("ParticleEmitter") then
                    emitter.Enabled = false
                end
            end
        end
    end
end

ProximityPromptService.PromptButtonHoldEnded:Connect(stopHeartTrail)
ProximityPromptService.PromptHidden:Connect(stopHeartTrail)
