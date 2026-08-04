-- CollectibleHighlightController.client.lua
-- Dynamic white outline highlight for cats and collectible items when within interaction range

local ProximityPromptService = game:GetService("ProximityPromptService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

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
