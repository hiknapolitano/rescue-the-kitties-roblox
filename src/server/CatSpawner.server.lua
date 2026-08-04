local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local SoundManager = require(Shared:WaitForChild("SoundManager")) -- Still needed for cat sobbing (3D ambient)
local Players = game:GetService("Players")

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local catCollectedEvent = remotesFolder:WaitForChild("CatCollected")

local hideCatRemote = remotesFolder:FindFirstChild("HideCatClient") or Instance.new("RemoteEvent")
hideCatRemote.Name = "HideCatClient"
hideCatRemote.Parent = remotesFolder

local resetLocalCats = remotesFolder:FindFirstChild("ResetLocalCats") or Instance.new("RemoteEvent")
resetLocalCats.Name = "ResetLocalCats"
resetLocalCats.Parent = remotesFolder

local activeCats = {}

-- Create or find the Cats folder so the minimap can track them
local catsFolder = workspace:FindFirstChild("Cats")
if not catsFolder then
    catsFolder = Instance.new("Folder")
    catsFolder.Name = "Cats"
    catsFolder.Parent = workspace
end

local function spawnCat(spawnPart, index)
    -- Ensure index wraps safely within CatsConfig bounds
    local configIndex = ((index - 1) % #Constants.CatsConfig) + 1
    local config = Constants.CatsConfig[configIndex]
    local catColor = config.color
    
    -- Face away from closest walls
    local wallDir = Vector3.zero
    for _, part in ipairs(workspace:GetPartBoundsInRadius(spawnPart.Position, 8)) do
        if part.Name:match("Wall") then
            local dir = (part.Position * Vector3.new(1,0,1)) - (spawnPart.Position * Vector3.new(1,0,1))
            if dir.Magnitude > 0 then
                wallDir = wallDir + dir.Unit
            end
        end
    end
    
    local cframe = CFrame.new(spawnPart.Position)
    if wallDir.Magnitude > 0.1 then
        local lookDir = -wallDir.Unit
        cframe = CFrame.lookAt(spawnPart.Position, spawnPart.Position + lookDir) * config.rotationOffset
    else
        cframe = CFrame.new(spawnPart.Position) * CFrame.Angles(0, math.rad(math.random(0, 360)), 0) * config.rotationOffset
    end
    
    local catRoot = Instance.new("Part")
    catRoot.Name = "Cat"
    catRoot.Shape = Enum.PartType.Block
    catRoot.Size = Vector3.new(2, 2, 2)
    catRoot.CFrame = cframe
    catRoot.Transparency = 1 -- Make placeholder invisible
    catRoot.Anchored = true
    catRoot.CanCollide = false
    
    -- Clone user's custom Cat model
    local template = ReplicatedStorage:FindFirstChild("Animals") and ReplicatedStorage.Animals:FindFirstChild("Cat")
    if template then
        local catModel = template:Clone()
        
        -- Position it perfectly at the root part, ignoring any collisions
        if catModel:IsA("Model") then
            catModel:PivotTo(catRoot.CFrame)
        else
            catModel.Position = catRoot.Position
        end
        
        -- Anchor all parts and apply color
        for _, child in ipairs(catModel:GetDescendants()) do
            if child:IsA("BasePart") then
                child.Anchored = true
                child.CanCollide = false
                child.CastShadow = false
                
                -- Color the part if it's not eyes or mouth
                local name = child.Name:lower()
                if not name:match("eye") and not name:match("mouth") then
                    child.Color = catColor
                end
            end
        end
        
        catModel.Parent = catRoot
    end
    
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Rescue"
    prompt.ObjectText = "Scared Kitty"
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.HoldDuration = Constants.CatHoldDuration
    prompt.RequiresLineOfSight = false
    
    prompt.Parent = catRoot
    
    prompt.Triggered:Connect(function(player)
        if catRoot:GetAttribute("CollectedBy_" .. player.UserId) then return end
        catRoot:SetAttribute("CollectedBy_" .. player.UserId, true)
        
        -- Play cat meow sound on client only (not audible to other players)
        local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
        local playSoundRemote = remotesFolder:FindFirstChild("PlaySoundClient")
        if playSoundRemote then
            local meowName = math.random() > 0.5 and "CatMeow" or "CatMeow2"
            playSoundRemote:FireClient(player, meowName)
            
            local currentCats = (player:GetAttribute("CatsRescued") or 0) + 1
            if currentCats == Constants.TotalCats then
                playSoundRemote:FireClient(player, "LastCat")
            end
        end
        
        catCollectedEvent:Fire(player)
        hideCatRemote:FireClient(player, catRoot)
    end)
    
    catRoot.Parent = catsFolder
    table.insert(activeCats, catRoot)
    
    if spawnPart and spawnPart.Parent then
        spawnPart:Destroy()
    end
end

local initialCatPositions = {}

local function initCats()
    local spawnLocations = workspace:WaitForChild("SpawnLocations")
    
    -- Wait for MazeBuilder to finish generating the maze
    if not workspace:GetAttribute("MazeGenerated") then
        workspace:GetAttributeChangedSignal("MazeGenerated"):Wait()
    end
    
    for _, child in ipairs(spawnLocations:GetChildren()) do
        if child.Name == "CatSpawn" then
            table.insert(initialCatPositions, child.Position)
            child:Destroy()
        end
    end
    
    for i, pos in ipairs(initialCatPositions) do
        local tempPart = Instance.new("Part")
        tempPart.Position = pos
        spawnCat(tempPart, i)
    end
end

initCats()

local resetCatsEvent = Instance.new("BindableEvent")
resetCatsEvent.Name = "ResetCats"
resetCatsEvent.Parent = remotesFolder

resetCatsEvent.Event:Connect(function(player)
    if not player then
        for _, cat in ipairs(activeCats) do
            if cat and cat.Parent then cat:Destroy() end
        end
        table.clear(activeCats)
        
        for i, pos in ipairs(initialCatPositions) do
            local tempPart = Instance.new("Part")
            tempPart.Position = pos
            spawnCat(tempPart, i)
        end
    else
        for _, cat in ipairs(activeCats) do
            if cat and cat.Parent then
                cat:SetAttribute("CollectedBy_" .. player.UserId, nil)
            end
        end
        resetLocalCats:FireClient(player)
    end
end)

-- Sobbing Proximity Loop
task.spawn(function()
    while true do
        task.wait(1)
        for i = #activeCats, 1, -1 do
            local cat = activeCats[i]
            if not cat or not cat.Parent then
                table.remove(activeCats, i)
                continue
            end
            
            local lastSob = cat:GetAttribute("LastSobTime") or 0
            if tick() - lastSob >= 5 then
                local playerNearby = false
                for _, player in ipairs(Players:GetPlayers()) do
                    if player.Character and player.Character.PrimaryPart then
                        if (player.Character.PrimaryPart.Position - cat.Position).Magnitude <= 40 then
                            if not cat:GetAttribute("CollectedBy_" .. player.UserId) then
                                playerNearby = true
                                break
                            end
                        end
                    end
                end
                
                if playerNearby then
                    cat:SetAttribute("LastSobTime", tick())
                    
                    local oldSound = cat:FindFirstChild("SobbingSound")
                    if oldSound then
                        SoundManager.stopSound(oldSound)
                    end
                    
                    local sobConfig = math.random() > 0.5 and Constants.Sounds.CatSobbing or Constants.Sounds.CatSobbing2
                    local newSound = SoundManager.playSound(sobConfig, cat, false, 40)
                    if newSound then
                        newSound.Name = "SobbingSound"
                    end
                end
            end
        end
    end
end)
