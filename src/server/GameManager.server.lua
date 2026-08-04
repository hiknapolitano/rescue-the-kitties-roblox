local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

-- Setup Remotes
local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "Remotes"
remotesFolder.Parent = ReplicatedStorage

local playerCaughtRemote = Instance.new("RemoteEvent")
playerCaughtRemote.Name = "PlayerCaught"
playerCaughtRemote.Parent = remotesFolder

local respawnPlayerRemote = Instance.new("RemoteEvent")
respawnPlayerRemote.Name = "RespawnPlayer"
respawnPlayerRemote.Parent = remotesFolder

local showWinScreenRemote = Instance.new("RemoteEvent")
showWinScreenRemote.Name = "ShowWinScreen"
showWinScreenRemote.Parent = remotesFolder

local catCollectedClientRemote = Instance.new("RemoteEvent")
catCollectedClientRemote.Name = "CatCollectedClient"
catCollectedClientRemote.Parent = remotesFolder

local resetHudRemote = Instance.new("RemoteEvent")
resetHudRemote.Name = "ResetHUD"
resetHudRemote.Parent = remotesFolder

local openShopRemote = Instance.new("RemoteEvent")
openShopRemote.Name = "OpenShop"
openShopRemote.Parent = remotesFolder

local purchaseItemRemote = Instance.new("RemoteFunction")
purchaseItemRemote.Name = "PurchaseItem"
purchaseItemRemote.Parent = remotesFolder

local catCollectedEvent = Instance.new("BindableEvent")
catCollectedEvent.Name = "CatCollected"
catCollectedEvent.Parent = remotesFolder

local playSoundRemote = Instance.new("RemoteEvent")
playSoundRemote.Name = "PlaySoundClient"
playSoundRemote.Parent = remotesFolder

local catsCollected = 0

local function isCharacterInSafeZone(character)
    if not character then return false end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    local playerPos = Vector2.new(hrp.Position.X, hrp.Position.Z)
    
    -- Check distance to Base model pivot
    local baseModel = workspace:FindFirstChild("Base")
    if baseModel then
        local basePivot = baseModel:GetPivot()
        local centerPos = Vector2.new(basePivot.Position.X, basePivot.Position.Z)
        if (playerPos - centerPos).Magnitude < 45 then
            return true
        end
    end
    
    -- Check SafeZone2 if it exists
    local safeZone2 = workspace:FindFirstChild("SafeZone2")
    if safeZone2 and safeZone2:IsA("BasePart") then
        local sz2Pos = Vector2.new(safeZone2.Position.X, safeZone2.Position.Z)
        local sz2Radius = math.max(safeZone2.Size.X, safeZone2.Size.Z) / 2 + 5
        if (playerPos - sz2Pos).Magnitude < sz2Radius then
            return true
        end
    end
    
    return false
end

local function isCharacterInWhiteLight(character)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    local mazeElements = workspace:FindFirstChild("MazeElements")
    if not mazeElements then return false end
    
    local whiteLights = {}
    for _, child in ipairs(mazeElements:GetDescendants()) do
        if child.Name == "WhiteLightTeleporter" then
            table.insert(whiteLights, child)
        end
    end
    
    if #whiteLights == 0 then return false end
    
    local overlapParams = OverlapParams.new()
    overlapParams.FilterDescendantsInstances = whiteLights
    overlapParams.FilterType = Enum.RaycastFilterType.Include
    
    local partsInBox = workspace:GetPartBoundsInBox(hrp.CFrame, Vector3.new(4, 10, 4), overlapParams)
    return #partsInBox > 0
end

local function checkSafeZoneWin(character)
    local player = Players:GetPlayerFromCharacter(character)
    if not player or player:GetAttribute("GameWon") then return end
    
    local inWinZone = isCharacterInWhiteLight(character)
    
    if inWinZone then
        -- Ensure they have rescued all cats before letting them win
        local currentCats = player:GetAttribute("CatsRescued") or 0
        if currentCats < Constants.TotalCats then return end
        
        if player then
            player:SetAttribute("GameWon", true)
            playSoundRemote:FireClient(player, "GameWin")
            
            -- Dismount and clear boat if any
            local activeBoat = workspace:FindFirstChild(player.Name .. "_ActiveBoat")
            if activeBoat then
                activeBoat:Destroy()
            end
            player:SetAttribute("InBoat", false)
            local hum = character:FindFirstChild("Humanoid")
            if hum then
                hum.Sit = false
                hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
                hum.WalkSpeed = Constants.PlayerWalkSpeed or 22
            end
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CollisionGroup = "Default"
                end
            end
            
            local spawnLoc = workspace:FindFirstChild("SpawnLocation")
            if spawnLoc and character.PrimaryPart then
                character:PivotTo(spawnLoc.CFrame + Vector3.new(0, 5, 0))
            end
        end
        
        local player = Players:GetPlayerFromCharacter(character)
        
        local startTime = player and player:GetAttribute("StartTime")
        if not startTime then startTime = os.time() end
        local endTime = os.time()
        local totalSeconds = endTime - startTime
        
        local stars = 1
        if totalSeconds <= Constants.StarTime5 then stars = 5
        elseif totalSeconds <= Constants.StarTime4 then stars = 4
        elseif totalSeconds <= Constants.StarTime3 then stars = 3
        elseif totalSeconds <= Constants.StarTime2 then stars = 2
        end
        
        if player then
            local ServerStorage = game:GetService("ServerStorage")
            local saveWinEvent = ServerStorage:FindFirstChild("SaveWinScore")
            if saveWinEvent then
                saveWinEvent:Fire(player, stars)
            end
            
            -- Give reward: 20 coins for win + 10 coins per star
            local leaderstats = player:FindFirstChild("leaderstats")
            if leaderstats then
                local coins = leaderstats:FindFirstChild("Coins")
                if coins then
                    coins.Value = coins.Value + 20 + (stars * 10)
                end
            end
            
            showWinScreenRemote:FireClient(player, totalSeconds, stars)
        end
    end
end

catCollectedEvent.Event:Connect(function(player)
    local currentCats = player:GetAttribute("CatsRescued") or 0
    currentCats = currentCats + 1
    player:SetAttribute("CatsRescued", currentCats)
    
    playSoundRemote:FireClient(player, "CatRescueImpact")
    
    print(player.Name .. " collected a cat! Total: " .. currentCats .. "/" .. Constants.TotalCats)
    
    local catCollectedRemote = remotesFolder:FindFirstChild("CatCollectedClient")
    if catCollectedRemote then
        catCollectedRemote:FireClient(player, currentCats)
    end
    
    if currentCats >= Constants.TotalCats then
        print("All cats collected! Return to safe zone to win.")
        
        -- Start checking if player reaches safe zone
        task.spawn(function()
            while not player:GetAttribute("GameWon") do
                task.wait(0.5)
                local cats = player:GetAttribute("CatsRescued") or 0
                if cats < Constants.TotalCats then
                    break
                end
                if player.Character then
                    checkSafeZoneWin(player.Character)
                end
            end
        end)
    end
end)

local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

respawnPlayerRemote.OnServerEvent:Connect(function(player)
    player:SetAttribute("HP", Constants.MaximumHP)
    player:SetAttribute("GameLost", false)
    player:SetAttribute("GameWon", false)
    player:SetAttribute("DogChasing", false)
    player:SetAttribute("DogChasingCount", 0)
    
    -- Cash is persistent, so do not reset coins to 0 here.
    
    resetHudRemote:FireClient(player)
    
    player:LoadCharacter()
    
    -- Wait for the new character to fully load, then teleport to SpawnLocation
    -- (LoadCharacter is async; task.defer is too fast)
    task.spawn(function()
        local char = player.CharacterAdded:Wait()
        task.wait() -- one frame for physics to initialize
        local spawnLoc = workspace:FindFirstChild("SpawnLocation")
        if spawnLoc and char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = CFrame.new(spawnLoc.Position + Vector3.new(0, 3, 0))
            end
        end
    end)
end)

local resetProgressRemote = remotesFolder:FindFirstChild("ResetProgress") or Instance.new("RemoteEvent")
resetProgressRemote.Name = "ResetProgress"
resetProgressRemote.Parent = remotesFolder

resetProgressRemote.OnServerEvent:Connect(function(player)
    player:SetAttribute("GameWon", false)
    
    -- Also reset keys
    player:SetAttribute("HasBlueKey", false)
    player:SetAttribute("HasYellowKey", false)
    player:SetAttribute("HasRedKey", false)
    player:SetAttribute("HasPurpleKey", false)
    player:SetAttribute("HasGreenKey", false)
    
    local resetCatsEvent = remotesFolder:FindFirstChild("ResetCats")
    if resetCatsEvent then resetCatsEvent:Fire(player) end
    
    resetHudRemote:FireClient(player)
    
    local spRemote = remotesFolder:FindFirstChild("RespawnPlayer")
    if spRemote then
        spRemote:FireClient(player)
    end
    player:LoadCharacter()
end)

local collectKeyRemote = remotesFolder:FindFirstChild("CollectKeyRemote") or Instance.new("RemoteEvent")
collectKeyRemote.Name = "CollectKeyRemote"
collectKeyRemote.Parent = remotesFolder

collectKeyRemote.OnServerEvent:Connect(function(player, colorName)
    local attrName = "Has" .. colorName .. "Key"
    player:SetAttribute(attrName, true)
    
    playSoundRemote:FireClient(player, "ItemPickup")
end)

local resetWinStateRemote = remotesFolder:FindFirstChild("ResetWinStateRemote") or Instance.new("RemoteEvent")
resetWinStateRemote.Name = "ResetWinStateRemote"
resetWinStateRemote.Parent = remotesFolder

resetWinStateRemote.OnServerEvent:Connect(function(player)
    gameWon = false
    player:SetAttribute("GameWon", false)
    player:SetAttribute("CatsRescued", 0)
    
    -- Reset keys and statuses
    player:SetAttribute("HasBlueKey", nil)
    player:SetAttribute("HasYellowKey", nil)
    player:SetAttribute("HasRedKey", nil)
    player:SetAttribute("HasGreenKey", nil)
    player:SetAttribute("HasPurpleKey", nil)
    player:SetAttribute("HasCyanKey", nil)
    player:SetAttribute("HasOrangeKey", nil)
    player:SetAttribute("HasWhiteKey", nil)
    player:SetAttribute("HasBlackKey", nil)
    player:SetAttribute("HasRainbowKey", nil)
    
    -- Dismount and clear boat if any
    local activeBoat = workspace:FindFirstChild(player.Name .. "_ActiveBoat")
    if activeBoat then
        activeBoat:Destroy()
    end
    player:SetAttribute("InBoat", false)
    
    local character = player.Character
    if character then
        local hum = character:FindFirstChild("Humanoid")
        if hum then
            hum.Sit = false
            hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
            hum.WalkSpeed = Constants.PlayerWalkSpeed or 22
        end
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CollisionGroup = "Default"
            end
        end
    end
    
    local spawnLoc = workspace:FindFirstChild("SpawnLocation")
    if character and character.PrimaryPart and spawnLoc then
        character:PivotTo(CFrame.new(spawnLoc.Position + Vector3.new(0, 3, 0)))
    end
    
    local resetCatsEvent = remotesFolder:FindFirstChild("ResetCats")
    if resetCatsEvent then resetCatsEvent:Fire(player) end
    
    resetHudRemote:FireClient(player)
end)

local function createFlashlightTool(player, character)
    local tool = Instance.new("Tool")
    tool.Name = "Flashlight"
    tool.RequiresHandle = true
    
    local template = ReplicatedStorage:FindFirstChild("Objects") and (ReplicatedStorage.Objects:FindFirstChild("Flashlight") or ReplicatedStorage.Objects:FindFirstChild("flashlight"))
    
    local handle = nil
    if template then
        local model = template:Clone()
        if model:IsA("Model") then
            handle = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
            if handle then
                handle.Name = "Handle"
                for _, child in ipairs(model:GetDescendants()) do
                    if child:IsA("BasePart") and child ~= handle then
                        local weld = Instance.new("WeldConstraint")
                        weld.Part0 = handle
                        weld.Part1 = child
                        weld.Parent = handle
                        child.Anchored = false
                        child.CanCollide = false
                        child.Parent = tool
                    end
                end
                handle.Parent = tool
                model:Destroy()
            end
        elseif model:IsA("BasePart") then
            handle = model
            handle.Name = "Handle"
            handle.Parent = tool
        end
    end
    
    if not handle then
        handle = Instance.new("Part")
        handle.Name = "Handle"
        handle.Size = Vector3.new(0.5, 0.5, 2)
        handle.Parent = tool
    end
    
    handle.Anchored = false
    handle.CanCollide = false
    
    tool.Parent = player.Backpack
    
    -- Equip the flashlight automatically
    task.delay(0.5, function()
        if tool.Parent ~= nil and player.Character and player.Character:FindFirstChild("Humanoid") then
            pcall(function()
                player.Character.Humanoid:EquipTool(tool)
            end)
        end
    end)
end

Players.PlayerAdded:Connect(function(player)
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player
    
    local coins = Instance.new("IntValue")
    coins.Name = "Coins"
    if player.Name == "beabadoobeelson" then
        coins.Value = 999
    else
        coins.Value = 0
    end
    coins.Parent = leaderstats

    player.CharacterAdded:Connect(function(character)
        -- Safely teleport to spawn location to prevent falling into the void
        local spawnLoc = workspace:FindFirstChild("SpawnLocation")
        if spawnLoc then
            task.defer(function()
                local hrp = character:WaitForChild("HumanoidRootPart", 3)
                if hrp then
                    character:PivotTo(spawnLoc.CFrame + Vector3.new(0, 3, 0))
                end
            end)
        end
        
        -- Give them full HP when they spawn/respawn
        player:SetAttribute("HP", Constants.MaximumHP)
        player:SetAttribute("HasHelmet", nil)
        player:SetAttribute("HasMinimap", nil)
        
        -- Determine player gender on character spawn and store as attribute
        task.spawn(function()
            local humanoid = character:WaitForChild("Humanoid", 10)
            if humanoid then
                local success, desc = pcall(function()
                    return humanoid:GetAppliedDescription()
                end)
                local isMale = true
                if success and desc then
                    local femaleTorsos = {
                        [86499666] = true, -- Woman Torso (R15)
                        [48474356] = true, -- ROBLOX Girl Torso (R6)
                        [146522365] = true, -- Lindsey Torso
                        [146524317] = true, -- Cindy Torso
                        [86499905] = true, -- Summer Torso
                    }
                    if femaleTorsos[desc.Torso] then
                        isMale = false
                    end
                end
                player:SetAttribute("IsMale", isMale)
            end
        end)
        
        -- Start timer ONLY if it hasn't started yet (e.g. brand new game)
        if player:GetAttribute("StartTime") == nil then
            task.spawn(function()
                -- Wait for them to spawn and leave the safe zone
                while character.Parent and player:GetAttribute("StartTime") == nil do
                    task.wait(0.5)
                    if not isCharacterInSafeZone(character) then
                        player:SetAttribute("StartTime", os.time())
                    end
                end
            end)
        end
        
        createFlashlightTool(player, character)
        
        -- Check Gamepasses
        task.spawn(function()
            local successMinimap, ownsMinimap = pcall(function()
                return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Constants.MinimapGamepassId)
            end)
            if successMinimap and ownsMinimap then
                player:SetAttribute("HasMinimap", true)
            end
            
            local successFlashlight, ownsFlashlight = pcall(function()
                return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Constants.FlashlightUpgradeGamepassId)
            end)
            if successFlashlight and ownsFlashlight then
                -- Grant Flashlight Upgrade
                player:SetAttribute("HasHelmet", true)
                
                -- Remove old flashlight
                local backpack = player:FindFirstChild("Backpack")
                if backpack and backpack:FindFirstChild("Flashlight") then
                    backpack.Flashlight:Destroy()
                end
                if character:FindFirstChild("Flashlight") then
                    character.Flashlight:Destroy()
                end
                
                local template = ReplicatedStorage:FindFirstChild("Objects") and ReplicatedStorage.Objects:FindFirstChild("Helmet")
                local helmet
                if template then
                    helmet = template:Clone()
                    if helmet:IsA("Model") then
                        local primary = helmet.PrimaryPart or helmet:FindFirstChildWhichIsA("BasePart")
                        if primary then
                            for _, child in ipairs(helmet:GetDescendants()) do
                                if child:IsA("BasePart") then
                                    child.CanCollide = false
                                    child.Anchored = false
                                    if child ~= primary then
                                        local weld = Instance.new("WeldConstraint")
                                        weld.Part0 = primary
                                        weld.Part1 = child
                                        weld.Parent = primary
                                    end
                                end
                            end
                            local originalModel = helmet
                            helmet = primary
                            for _, child in ipairs(originalModel:GetChildren()) do
                                if child ~= helmet then
                                    child.Parent = helmet
                                end
                            end
                        end
                    end
                end
                
                if not helmet or not helmet:IsA("BasePart") then
                    helmet = Instance.new("Part")
                    helmet.Size = Vector3.new(1.2, 0.8, 1.2)
                    helmet.Color = Color3.fromRGB(255, 200, 50)
                    helmet.Material = Enum.Material.SmoothPlastic
                end
                
                helmet.Name = "FlashlightHelmet"
                helmet.CanCollide = false
                helmet.Anchored = false

                
                local head = character:FindFirstChild("Head")
                if head then
                    helmet.CFrame = head.CFrame * CFrame.new(0, 0.5, 0)
                    local weld = Instance.new("WeldConstraint")
                    weld.Part0 = head
                    weld.Part1 = helmet
                    weld.Parent = helmet
                    helmet.Parent = character
                end
            end
        end)
    end)
end)


