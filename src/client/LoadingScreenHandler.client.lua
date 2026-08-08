local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local TranslationHelper = require(Shared:WaitForChild("TranslationHelper"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Force landscape mode on mobile/tablets immediately on startup
playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor

-- Build the loading screen FIRST before anything else
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LoadingScreen"
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 9999 -- Ensure it's on top of everything
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local bg = Instance.new("Frame")
bg.Size = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3 = Color3.new(0, 0, 0)
bg.Parent = screenGui

local imageLabel = Instance.new("ImageLabel")
imageLabel.Size = UDim2.new(1, 0, 1, 0)
imageLabel.BackgroundTransparency = 1
imageLabel.Image = Constants.Images.LoadingBackground or ""
imageLabel.ScaleType = Enum.ScaleType.Crop
imageLabel.ImageTransparency = 1
imageLabel.Parent = bg

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.new(0, 0, 0)),
    ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
    ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0))
})
gradient.Rotation = 90
gradient.Parent = imageLabel

local loadingText = Instance.new("TextLabel")
loadingText.Size = UDim2.new(1, 0, 0, 50)
loadingText.Position = UDim2.new(0, 0, 1, -100)
loadingText.BackgroundTransparency = 1
loadingText.Text = TranslationHelper.translate("Loading Game...")
loadingText.TextColor3 = Color3.new(1, 1, 1)
loadingText.TextStrokeTransparency = 0.5
loadingText.Font = Enum.Font.FredokaOne
loadingText.AutoLocalize = true
loadingText.TextSize = 24
loadingText.Parent = bg

-- Fade in image
TweenService:Create(imageLabel, TweenInfo.new(1), {ImageTransparency = 0}):Play()

-- Now that screenGui exists, hide ALL native CoreGui elements (backpack, chat, etc.)
-- Retry until StarterGui is ready (it may not be immediately after LocalScript runs)
task.spawn(function()
    local hidden = false
    while not hidden and screenGui.Parent do
        hidden = pcall(function()
            StarterGui:SetCore("TopbarEnabled", false)
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
        end)
        if not hidden then task.wait(0.1) end
    end
end)

task.spawn(function()
    -- Wait for the server to finish generating the maze before proceeding
    if not workspace:GetAttribute("MazeGenerated") then
        workspace:GetAttributeChangedSignal("MazeGenerated"):Wait()
    end

    local SoundService = game:GetService("SoundService")
    local soundCache = SoundService:FindFirstChild("SoundCache")
    if not soundCache then
        soundCache = Instance.new("Folder")
        soundCache.Name = "SoundCache"
        soundCache.Parent = SoundService
    end

    local assetsToPreload = {
        workspace,
        ReplicatedStorage
    }
    
    -- Dynamically extract and instantiate all sounds from Constants
    for soundName, soundConfig in pairs(Constants.Sounds) do
        local soundId = nil
        if type(soundConfig) == "table" then
            soundId = soundConfig.SoundId
        elseif type(soundConfig) == "string" then
            soundId = soundConfig
        end
        
        if soundId and soundId ~= "" and soundId ~= "rbxassetid://0" then
            local soundInstance = soundCache:FindFirstChild(soundName)
            if not soundInstance then
                soundInstance = Instance.new("Sound")
                soundInstance.Name = soundName
                soundInstance.SoundId = soundId
                if type(soundConfig) == "table" then
                    soundInstance.Volume = soundConfig.Volume or 1
                    soundInstance.PlaybackSpeed = soundConfig.PlaybackSpeed or 1
                    soundInstance.Looped = soundConfig.Looped or false
                end
                soundInstance.Parent = soundCache
            end

            table.insert(assetsToPreload, soundInstance)
        end
    end
    
    -- Dynamically extract and instantiate all images from Constants
    for _, imageId in pairs(Constants.Images) do
        if type(imageId) == "string" and imageId ~= "" then
            local tempDecal = Instance.new("Decal")
            tempDecal.Texture = imageId
            table.insert(assetsToPreload, tempDecal)
        end
    end
    
    -- Animate dots
    local dots = 0
    local dotAnim = task.spawn(function()
        while true do
            task.wait(0.5)
            dots = (dots + 1) % 4
            loadingText.Text = TranslationHelper.translate("Loading Game") .. string.rep(".", dots)
        end
    end)
    
    -- Actually wait for the game to load
    local success, errorMessage = pcall(function()
        ContentProvider:PreloadAsync(assetsToPreload)
    end)
    
    if not success then
        warn("Failed to preload assets: " .. tostring(errorMessage))
    end
    
    -- Force-bake lighting by sweeping the camera across the maze
    -- This causes Roblox's lighting engine to calculate voxels for the playable area
    loadingText.Text = TranslationHelper.translate("Baking Lighting...")
    
    local camera = workspace.CurrentCamera
    if camera then
        local mazeElements = workspace:FindFirstChild("MazeElements")
        local floorsFolder = mazeElements and mazeElements:FindFirstChild("Floors")
        
        if floorsFolder then
            -- Find map bounds
            local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
            for _, tile in ipairs(floorsFolder:GetChildren()) do
                if tile:IsA("BasePart") then
                    minX = math.min(minX, tile.Position.X)
                    maxX = math.max(maxX, tile.Position.X)
                    minZ = math.min(minZ, tile.Position.Z)
                    maxZ = math.max(maxZ, tile.Position.Z)
                end
            end
            
            if minX ~= math.huge then
                local centerX = (minX + maxX) / 2
                local centerZ = (minZ + maxZ) / 2
                local extent = math.max(maxX - minX, maxZ - minZ)
                
                -- Sweep camera to 4 corners + center to force lighting bake
                -- We also target the Base floor center directly first, so base lights are fully compiled/ready when spawning.
                local baseLoc = workspace:FindFirstChild("SpawnLocation")
                local basePos = baseLoc and (baseLoc.Position + (Constants.MazeOffset or Vector3.new(0, 0, 0))) or (Constants.MazeOffset or Vector3.new(2000, 0, 2000))
                
                local sweepPositions = {
                    Vector3.new(basePos.X, 35, basePos.Z), -- Look directly down at Base center
                    Vector3.new(centerX, 80, centerZ),
                    Vector3.new(minX, 80, minZ),
                    Vector3.new(maxX, 80, minZ),
                    Vector3.new(minX, 80, maxZ),
                    Vector3.new(maxX, 80, maxZ),
                }
                
                local originalCFrame = camera.CFrame
                camera.CameraType = Enum.CameraType.Scriptable
                
                for _, pos in ipairs(sweepPositions) do
                    camera.CFrame = CFrame.lookAt(pos, Vector3.new(centerX, 0, centerZ))
                    task.wait(0.5) -- Give engine time to process each view
                end
                
                -- Return camera to original
                camera.CFrame = originalCFrame
                camera.CameraType = Enum.CameraType.Custom
            end
        end
    end
    
    -- Final lighting bake settle time
    loadingText.Text = TranslationHelper.translate("Finalizing...")
    task.wait(6)
    
    task.cancel(dotAnim)
    loadingText.Text = TranslationHelper.translate("Welcome!")
    
    task.wait(1)
    
    -- Fade out
    local fadeOutBg = TweenService:Create(bg, TweenInfo.new(1), {BackgroundTransparency = 1})
    local fadeOutImg = TweenService:Create(imageLabel, TweenInfo.new(1), {ImageTransparency = 1})
    local fadeOutTxt = TweenService:Create(loadingText, TweenInfo.new(1), {TextTransparency = 1, TextStrokeTransparency = 1})
    
    fadeOutBg:Play()
    fadeOutImg:Play()
    fadeOutTxt:Play()
    
    fadeOutBg.Completed:Wait()
    
    pcall(function()
        StarterGui:SetCore("TopbarEnabled", true)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
    end)
    
    screenGui:Destroy()
end)
