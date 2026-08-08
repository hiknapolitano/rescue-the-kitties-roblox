local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

-- 0: Path, 1: Wall, 2: Tree, 3: Cat Spawn, 4: Dog Spawn, 5: Exit Door, 6: Lobby/Spawn
local Maps = require(Shared:WaitForChild("Maps"))
local layout = Maps[Constants.ActiveLevel]

if not layout then
    warn("ActiveLevel " .. tostring(Constants.ActiveLevel) .. " not found in Maps. Defaulting to first map.")
    local firstKey = next(Maps)
    layout = Maps[firstKey]
end

print("Loaded map:", Constants.ActiveLevel)

local function applyWallTexture(part, name)
    local textureId = nil
    local studsScale = 4 -- fallback default
    if name == "Base" or name == "BaseNode" or name == "BaseEdge" then
        textureId = Constants.WallBaseTextureId
        studsScale = Constants.WallBaseTextureScale or 4
    elseif name == "Middle" or name == "MiddleNode" or name == "MiddleEdge" then
        textureId = Constants.WallMiddleTextureId
        studsScale = Constants.WallMiddleTextureScale or 5
    elseif name == "Top" or name == "TopNode" or name == "TopEdge" then
        textureId = Constants.WallTopTextureId
        studsScale = Constants.WallTopTextureScale or 4
    end
    
    if textureId and textureId ~= "" then
        local faces = {
            Enum.NormalId.Front, Enum.NormalId.Back,
            Enum.NormalId.Left, Enum.NormalId.Right,
            Enum.NormalId.Top
        }
        for _, face in ipairs(faces) do
            local texture = Instance.new("Texture")
            texture.Name = "HQWallTexture"
            texture.Texture = textureId
            texture.Face = face
            texture.StudsPerTileU = studsScale
            texture.StudsPerTileV = studsScale
            texture.Parent = part
        end
    end
end

local function makeLethal(model, deathReason, filterName)
    local partsToCheck = {model}
    for _, d in ipairs(model:GetDescendants()) do table.insert(partsToCheck, d) end
    
    for _, child in ipairs(partsToCheck) do
        if child:IsA("BasePart") and (not filterName or child.Name == filterName) then
            child.Touched:Connect(function(hit)
                local char = hit.Parent
                local hum = char and char:FindFirstChild("Humanoid")
                if hum and hum.Health > 0 then
                    local p = Players:GetPlayerFromCharacter(char)
                    if p and not char:GetAttribute("Immune") and not char:GetAttribute("Invisible") and not p:GetAttribute("GameLost") then
                        if char:GetAttribute("HasShield") then
                            char:SetAttribute("HasShield", nil)
                            local ff = char:FindFirstChild("ShieldFF")
                            if ff then ff:Destroy() end
                            
                            local shieldTool = char:FindFirstChild("Shield")
                            if shieldTool and shieldTool:IsA("Tool") then
                                shieldTool:Destroy()
                            end
                            
                            local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
                            local playSoundRemote = remotesFolder and remotesFolder:FindFirstChild("PlaySoundClient")
                            if playSoundRemote then
                                playSoundRemote:FireClient(p, "ShieldBreak")
                            end
                            
                            char:SetAttribute("Immune", true)
                            local newFf = Instance.new("ForceField")
                            newFf.Parent = char
                            
                            task.delay(4, function()
                                if char then char:SetAttribute("Immune", nil) end
                                if newFf then newFf:Destroy() end
                            end)
                            return
                        end
                        
                        local currentHP = p:GetAttribute("HP") or Constants.MaximumHP
                        local damage = (deathReason == "Spikes") and Constants.SpikeDamage or Constants.LavaDamage
                        local newHP = math.max(0, currentHP - damage)
                        p:SetAttribute("HP", newHP)
                        
                        if newHP > 0 then
                            -- Deal damage, give temporary immunity
                            char:SetAttribute("Immune", true)
                            local ff = Instance.new("ForceField")
                            ff.Parent = char
                            
                            -- Teleport back to nearest platform if hit by spikes
                            if deathReason == "Spikes" then
                                local hrp = char:FindFirstChild("HumanoidRootPart")
                                if hrp then
                                    local playerPos = hrp.Position
                                    local nearestPlat = nil
                                    local minDist = math.huge
                                    
                                    local mazeFolder = workspace:FindFirstChild("MazeElements")
                                    if mazeFolder then
                                        for _, obj in ipairs(mazeFolder:GetDescendants()) do
                                            if obj.Name == "ParkourPlatform" or obj.Name == "Platform" then
                                                local platPos = obj:GetPivot().Position
                                                local dist = (platPos - playerPos).Magnitude
                                                if dist < minDist then
                                                    minDist = dist
                                                    nearestPlat = obj
                                                end
                                            end
                                        end
                                    end
                                    
                                    if nearestPlat then
                                        char:PivotTo(nearestPlat:GetPivot() + Vector3.new(0, 3, 0))
                                    end
                                end
                            end
                            
                            -- Play damage sounds on client only
                            local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
                            local playSoundRemote = remotesFolder and remotesFolder:FindFirstChild("PlaySoundClient")
                            if playSoundRemote then
                                playSoundRemote:FireClient(p, "Damage")
                                playSoundRemote:FireClient(p, "PlayerDeathImpact")
                            end
                            
                            task.delay(4, function()
                                if char then char:SetAttribute("Immune", nil) end
                                if ff then ff:Destroy() end
                            end)
                        else
                            -- Death logic
                            local hrp = char:FindFirstChild("HumanoidRootPart")
                            if hrp then hrp.Anchored = true end
                            char:SetAttribute("Immune", true)
                            char:SetAttribute("Invisible", true)
                            p:SetAttribute("GameLost", true)
                            p:SetAttribute("DiedByLava", true) -- Reuse for safe revive behavior
                            
                            for _, part in ipairs(char:GetDescendants()) do
                                if part:IsA("BasePart") or part:IsA("Decal") or part:IsA("Texture") then
                                    part.Transparency = 1
                                end
                            end
                            
                            -- Play death sounds on client only
                            local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
                            local playSoundRemote = remotesFolder and remotesFolder:FindFirstChild("PlaySoundClient")
                            if playSoundRemote then
                                playSoundRemote:FireClient(p, "PlayerDeathImpact")
                                playSoundRemote:FireClient(p, "GameOver")
                            end
                            
                            local playerCaughtRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PlayerCaught")
                            playerCaughtRemote:FireClient(p, deathReason)
                        end
                    end
                end
            end)
        end
    end
end

local function buildMaze()
    local mazeFolder = Instance.new("Folder")
    mazeFolder.Name = "MazeElements"
    mazeFolder.Parent = workspace
    
    local function isInsideBase(instance)
        local current = instance.Parent
        while current and current ~= workspace do
            if current.Name == "Base" then
                return true
            end
            current = current.Parent
        end
        return false
    end

    -- Cleanup rogue/manually-placed lights from Studio that cause mystery white lights.
    -- Scan ALL workspace objects (including deeply nested) for Neon parts or WhiteLightTeleporter names.
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            if (obj.Name == "WhiteLightTeleporter" or obj.Material == Enum.Material.Neon) and not isInsideBase(obj) then
                -- Check it's not a player character, dog, cat, boat, etc.
                local safeNames = {"HumanoidRootPart", "Head", "UpperTorso", "LowerTorso", "LeftLowerArm", "RightLowerArm"}
                local isSafe = false
                for _, n in ipairs(safeNames) do
                    if obj.Name == n then isSafe = true break end
                end
                
                if not isSafe then
                    print("[MazeBuilder] Destroying rogue BasePart light:", obj.Name, "at", obj.Position, "parent:", obj.Parent and obj.Parent.Name or "nil")
                    obj:Destroy()
                end
            end
        elseif obj:IsA("Light") then
            -- Destroy stray Light objects (PointLight, SpotLight, SurfaceLight)
            local p = obj.Parent
            
            -- Only destroy if not in Base, and not in ReplicatedStorage or ServerStorage
            if not isInsideBase(obj) and obj:IsDescendantOf(workspace) then
                print("[MazeBuilder] Destroying rogue Light object:", obj.Name, "parent:", p and p.Name or "nil")
                obj:Destroy()
            end
        end
    end

    local spawnLocationsFolder = Instance.new("Folder")
    spawnLocationsFolder.Name = "SpawnLocations"
    spawnLocationsFolder.Parent = workspace
    
    local doorsFolder = workspace:FindFirstChild("Doors") or Instance.new("Folder")
    doorsFolder.Name = "Doors"
    doorsFolder.Parent = workspace
    
    local keysFolder = workspace:FindFirstChild("Keys") or Instance.new("Folder")
    keysFolder.Name = "Keys"
    keysFolder.Parent = workspace

    local cellSize = Constants.CellSize
    local wallHeight = Constants.WallHeight
    
    -- FORCEFUL 0,0,0 ANNIHILATION
    -- Since the mystery white light is exactly at 0,0,0, we will wipe that area completely clean before building the maze.
    local originRegion = Region3.new(Vector3.new(-5, -20, -5), Vector3.new(5, 20, 5))
    local originParts = workspace:FindPartsInRegion3(originRegion, nil, 1000)
    for _, p in ipairs(originParts) do
        if not p:IsDescendantOf(workspace:FindFirstChild("Base")) and p.Name ~= "SpawnLocation" and p.Name ~= "Baseplate" then
            print("[MazeBuilder] 💥 NUKING ROGUE OBJECT AT 0,0,0:", p.Name, p.ClassName)
            p:Destroy()
        end
    end
    
    local safeZone1Positions = {}

    local lavaMinX, lavaMaxX, lavaMinZ, lavaMaxZ
    local lavaParkour = workspace:FindFirstChild("lava parkour")
    if lavaParkour then
        for _, part in ipairs(lavaParkour:GetDescendants()) do
            if part:IsA("BasePart") then
                local pos = part.Position
                local size = part.Size
                local minX = pos.X - size.X/2
                local maxX = pos.X + size.X/2
                local minZ = pos.Z - size.Z/2
                local maxZ = pos.Z + size.Z/2
                
                if not lavaMinX or minX < lavaMinX then lavaMinX = minX end
                if not lavaMaxX or maxX > lavaMaxX then lavaMaxX = maxX end
                if not lavaMinZ or minZ < lavaMinZ then lavaMinZ = minZ end
                if not lavaMaxZ or maxZ > lavaMaxZ then lavaMaxZ = maxZ end
            end
        end
    end
    
    local validPaths = {}

    -- Floors Folder
    local floorsFolder = Instance.new("Folder")
    floorsFolder.Name = "Floors"
    floorsFolder.Parent = mazeFolder

    for z, row in ipairs(layout) do
        for x, cellType in ipairs(row) do
            local offset = Constants.MazeOffset or Vector3.new(0,0,0)
            local posX = (x - 1) * cellSize + offset.X
            local posZ = (z - 1) * cellSize + offset.Z
            
            local noiseScale = 0.08
            local noiseVal = math.noise(x * noiseScale, z * noiseScale, 123.45)
            local alpha = (math.clamp(noiseVal, -0.5, 0.5) + 0.5)
            
            local finalGroundColor
            if alpha < 0.333 then
                local subAlpha = alpha / 0.333
                finalGroundColor = Constants.GroundColorA:Lerp(Constants.GroundColorB, subAlpha)
            elseif alpha < 0.666 then
                local subAlpha = (alpha - 0.333) / 0.333
                finalGroundColor = Constants.GroundColorB:Lerp(Constants.GroundColorC, subAlpha)
            else
                local subAlpha = (alpha - 0.666) / 0.334
                finalGroundColor = Constants.GroundColorC:Lerp(Constants.GroundColorD, subAlpha)
            end
            
            -- Only spawn a floor tile for maze cells, NOT for Safe Zone 1, Lava Obbies, JustLava, WaterTile, or SpikeTile
            if cellType ~= 6 and cellType ~= 24 and cellType ~= 25 and cellType ~= 26 and cellType ~= 28 then
                local floorTile = Instance.new("Part")
                floorTile.Name = "FloorTile"
                floorTile.Anchored = true
                floorTile.Size = Vector3.new(cellSize, 10, cellSize)
                floorTile.Position = Vector3.new(posX, -4.5, posZ)
                floorTile.Color = finalGroundColor
                floorTile.Material = Constants.GroundMaterial
                floorTile.Parent = floorsFolder
                
                -- Apply custom ground texture if configured
                if Constants.GroundTextureId and Constants.GroundTextureId ~= "" then
                    local texture = Instance.new("Texture")
                    texture.Name = "HQFloorTexture"
                    texture.Texture = Constants.GroundTextureId
                    texture.Face = Enum.NormalId.Top
                    texture.StudsPerTileU = Constants.GroundTextureScale or 4
                    texture.StudsPerTileV = Constants.GroundTextureScale or 4
                    texture.Parent = floorTile
                end
            end

            if cellType == 1 then
                local wallModel = Instance.new("Model")
                wallModel.Name = "Wall"
                
                local currentWallHeight = wallHeight
                local biomeMidColor, biomeBaseColor, biomeTopColor
                local midMat = Constants.WallMiddleMaterial
                local baseMat = Constants.WallBaseMaterial
                local topMat = Constants.WallTopMaterial
                
                if alpha < 0.333 then
                    local subAlpha = alpha / 0.333
                    biomeMidColor = Constants.WallColorA:Lerp(Constants.WallColorB, subAlpha)
                elseif alpha < 0.666 then
                    local subAlpha = (alpha - 0.333) / 0.333
                    biomeMidColor = Constants.WallColorB:Lerp(Constants.WallColorC, subAlpha)
                else
                    local subAlpha = (alpha - 0.666) / 0.334
                    biomeMidColor = Constants.WallColorC:Lerp(Constants.WallColorD, subAlpha)
                end
                
                biomeBaseColor = Constants.WallBaseColor
                biomeTopColor = Constants.WallTopColor
                
                local groundY = 0.5
                local middleHeight = currentWallHeight - Constants.WallBaseHeight - Constants.WallTopHeight
                
                local function createCylinderNode(name, height, oversize, color, material, yOffset)
                    local w = cellSize + oversize
                    local cyl = Instance.new("Part")
                    cyl.Name = name .. "Node"
                    cyl.Anchored = true
                    cyl.CanCollide = false
                    local roundness = Constants.WallCornerRoundness or 1.0
                    cyl.Shape = (roundness >= 0.5) and Enum.PartType.Cylinder or Enum.PartType.Block
                    cyl.Size = Vector3.new(height, w, w)
                    cyl.CFrame = CFrame.new(posX, yOffset + height/2, posZ) * CFrame.Angles(0, 0, math.rad(90))
                    cyl.Color = color
                    cyl.Material = material
                    cyl.Parent = wallModel
                    applyWallTexture(cyl, name)
                end
                
                local function createEdgeBlock(name, height, oversize, color, material, yOffset, isRight)
                    local w = cellSize + oversize
                    local block = Instance.new("Part")
                    block.Name = name .. "Edge"
                    block.Anchored = true
                    block.CanCollide = false
                    if isRight then
                        block.Size = Vector3.new(cellSize, height, w)
                        block.Position = Vector3.new(posX + cellSize/2, yOffset + height/2, posZ)
                    else
                        block.Size = Vector3.new(w, height, cellSize)
                        block.Position = Vector3.new(posX, yOffset + height/2, posZ + cellSize/2)
                    end
                    block.Color = color
                    block.Material = material
                    block.Parent = wallModel
                    applyWallTexture(block, name)
                end
                
                -- 1. Create Node (Cylinder) at current cell
                createCylinderNode("Base", Constants.WallBaseHeight, Constants.WallBaseOversize, biomeBaseColor, baseMat, groundY)
                createCylinderNode("Middle", middleHeight, 0, biomeMidColor, midMat, groundY + Constants.WallBaseHeight)
                createCylinderNode("Top", Constants.WallTopHeight, Constants.WallTopOversize, biomeTopColor, topMat, groundY + Constants.WallBaseHeight + middleHeight)
                
                local cw = cellSize + Constants.WallBaseOversize
                local colliderCyl = Instance.new("Part")
                colliderCyl.Name = "ColliderNode"
                colliderCyl.Anchored = true
                local roundness = Constants.WallCornerRoundness or 1.0
                colliderCyl.Shape = (roundness >= 0.5) and Enum.PartType.Cylinder or Enum.PartType.Block
                colliderCyl.Size = Vector3.new(currentWallHeight, cw, cw)
                colliderCyl.CFrame = CFrame.new(posX, groundY + currentWallHeight/2, posZ) * CFrame.Angles(0, 0, math.rad(90))
                colliderCyl.Transparency = 1
                colliderCyl.CustomPhysicalProperties = PhysicalProperties.new(1, 0, 0, 100, 100)
                colliderCyl.Parent = wallModel
                
                local function isWallLike(cType)
                    if not cType then return false end
                    -- Only actual wall cells (type 1) get edge blocks.
                    -- Door cells (10,12,14,16,18,20) are NOT wall-like for this purpose:
                    -- treating doors as walls causes edge blocks to spawn inside the portal opening.
                    return cType == 1
                end
                
                local function isDoorCell(cType)
                    if not cType then return false end
                    return cType == 10 or cType == 12 or cType == 14 or cType == 16 or cType == 18 or cType == 20
                end
                
                local function createHalfEdge(dir, neighborCell)
                    if not isDoorCell(neighborCell) then return end
                    
                    local sizeX, sizeZ, posXOffset, posZOffset
                    local halfSize = cellSize / 2
                    
                    if dir == "Right" then
                        sizeX = halfSize
                        sizeZ = cellSize
                        posXOffset = cellSize / 4
                        posZOffset = 0
                    elseif dir == "Left" then
                        sizeX = halfSize
                        sizeZ = cellSize
                        posXOffset = -cellSize / 4
                        posZOffset = 0
                    elseif dir == "Down" then
                        sizeX = cellSize
                        sizeZ = halfSize
                        posXOffset = 0
                        posZOffset = cellSize / 4
                    elseif dir == "Up" then
                        sizeX = cellSize
                        sizeZ = halfSize
                        posXOffset = 0
                        posZOffset = -cellSize / 4
                    end
                    
                    local function createVisualBlock(name, height, oversize, color, material, yOffset)
                        local w = (dir == "Right" or dir == "Left") and (sizeZ + oversize) or sizeZ
                        local hW = (dir == "Down" or dir == "Up") and (sizeX + oversize) or sizeX
                        
                        local block = Instance.new("Part")
                        block.Name = name .. "Edge"
                        block.Anchored = true
                        block.CanCollide = false
                        block.Size = Vector3.new(hW, height, w)
                        block.Position = Vector3.new(posX + posXOffset, yOffset + height/2, posZ + posZOffset)
                        block.Color = color
                        block.Material = material
                        block.Parent = wallModel
                        applyWallTexture(block, name)
                    end
                    
                    createVisualBlock("Base", Constants.WallBaseHeight, Constants.WallBaseOversize, biomeBaseColor, baseMat, groundY)
                    createVisualBlock("Middle", middleHeight, 0, biomeMidColor, midMat, groundY + Constants.WallBaseHeight)
                    createVisualBlock("Top", Constants.WallTopHeight, Constants.WallTopOversize, biomeTopColor, topMat, groundY + Constants.WallBaseHeight + middleHeight)
                    
                    -- Collider Part
                    local colliderBlock = Instance.new("Part")
                    colliderBlock.Name = "ColliderEdge" .. dir .. "Half"
                    colliderBlock.Anchored = true
                    
                    local colW = (dir == "Right" or dir == "Left") and cw or cw
                    local colHW = (dir == "Down" or dir == "Up") and cw or cw
                    local cSizeX = (dir == "Right" or dir == "Left") and halfSize or colHW
                    local cSizeZ = (dir == "Down" or dir == "Up") and halfSize or colW
                    
                    colliderBlock.Size = Vector3.new(cSizeX, currentWallHeight, cSizeZ)
                    colliderBlock.Position = Vector3.new(posX + posXOffset, groundY + currentWallHeight/2, posZ + posZOffset)
                    colliderBlock.Transparency = 1
                    colliderBlock.CustomPhysicalProperties = PhysicalProperties.new(1, 0, 0, 100, 100)
                    colliderBlock.Parent = wallModel
                end
                
                -- 2. Create Right Edge if cell to the right is also a Wall
                if isWallLike(row[x+1]) then
                    createEdgeBlock("Base", Constants.WallBaseHeight, Constants.WallBaseOversize, biomeBaseColor, baseMat, groundY, true)
                    createEdgeBlock("Middle", middleHeight, 0, biomeMidColor, midMat, groundY + Constants.WallBaseHeight, true)
                    createEdgeBlock("Top", Constants.WallTopHeight, Constants.WallTopOversize, biomeTopColor, topMat, groundY + Constants.WallBaseHeight + middleHeight, true)
                    
                    local colliderBlock = Instance.new("Part")
                    colliderBlock.Name = "ColliderEdgeRight"
                    colliderBlock.Anchored = true
                    colliderBlock.Size = Vector3.new(cellSize, currentWallHeight, cw)
                    colliderBlock.Position = Vector3.new(posX + cellSize/2, groundY + currentWallHeight/2, posZ)
                    colliderBlock.Transparency = 1
                    colliderBlock.CustomPhysicalProperties = PhysicalProperties.new(1, 0, 0, 100, 100)
                    colliderBlock.Parent = wallModel
                end
                
                -- 3. Create Down Edge if cell below is also a Wall
                if layout[z+1] and isWallLike(layout[z+1][x]) then
                    createEdgeBlock("Base", Constants.WallBaseHeight, Constants.WallBaseOversize, biomeBaseColor, baseMat, groundY, false)
                    createEdgeBlock("Middle", middleHeight, 0, biomeMidColor, midMat, groundY + Constants.WallBaseHeight, false)
                    createEdgeBlock("Top", Constants.WallTopHeight, Constants.WallTopOversize, biomeTopColor, topMat, groundY + Constants.WallBaseHeight + middleHeight, false)
                    
                    local colliderBlock = Instance.new("Part")
                    colliderBlock.Name = "ColliderEdgeDown"
                    colliderBlock.Anchored = true
                    colliderBlock.Size = Vector3.new(cw, currentWallHeight, cellSize)
                    colliderBlock.Position = Vector3.new(posX, groundY + currentWallHeight/2, posZ + cellSize/2)
                    colliderBlock.Transparency = 1
                    colliderBlock.CustomPhysicalProperties = PhysicalProperties.new(1, 0, 0, 100, 100)
                    colliderBlock.Parent = wallModel
                end
                
                -- 4. Create half-length edges for door/portal neighbors (to prevent rounded corners without blocking openings)
                createHalfEdge("Right", row[x+1])
                createHalfEdge("Left", row[x-1])
                createHalfEdge("Down", layout[z+1] and layout[z+1][x])
                createHalfEdge("Up", layout[z-1] and layout[z-1][x])
                
                wallModel.PrimaryPart = colliderCyl
                wallModel.Parent = mazeFolder
                
            elseif cellType == 0 then
                local inLava = false
                if lavaMinX and posX >= lavaMinX and posX <= lavaMaxX and posZ >= lavaMinZ and posZ <= lavaMaxZ then
                    inLava = true
                end
                
                if not inLava then
                    table.insert(validPaths, Vector3.new(posX, 0.5, posZ))
                end
                
            elseif cellType == 21 then
                -- FireTree
                local treeTemplate = ReplicatedStorage:FindFirstChild("MazeElements") and ReplicatedStorage.MazeElements:FindFirstChild("FireTree")
                if treeTemplate then
                    local treeModel = treeTemplate:Clone()
                    treeModel.Name = "FireTree"
                    
                    local groundY = 0.5
                    
                    local randRotY = math.rad(math.random() * 360)
                    local offsetX = (math.random() - 0.5) * 6
                    local offsetZ = (math.random() - 0.5) * 6
                    
                    if treeModel:IsA("Model") then
                        local bboxCFrame, size = treeModel:GetBoundingBox()
                        local pivot = treeModel:GetPivot()
                        local pivotOffset = pivot.Position.Y - bboxCFrame.Position.Y
                        local targetY = groundY + (size.Y / 2) + pivotOffset - 3
                        
                        treeModel:PivotTo(CFrame.new(posX + offsetX, targetY, posZ + offsetZ) * CFrame.Angles(0, randRotY, 0))
                    elseif treeModel:IsA("BasePart") then
                        treeModel.CFrame = CFrame.new(posX + offsetX, groundY + treeModel.Size.Y / 2, posZ + offsetZ) * CFrame.Angles(0, randRotY, 0)
                        treeModel.Anchored = true
                    end
                    
                    makeLethal(treeModel, "FireTree", nil)
                    
                    local pfMod = Instance.new("PathfindingModifier")
                    pfMod.Label = "Hazard"
                    pfMod.PassThrough = false
                    pfMod.Parent = treeModel
                    
                    treeModel.Parent = mazeFolder
                end
                
            elseif cellType == 23 then
                -- Climbable Tree
                local treeTemplate = ReplicatedStorage:FindFirstChild("MazeElements") and ReplicatedStorage.MazeElements:FindFirstChild("Tree")
                if treeTemplate then
                    local treeModel = treeTemplate:Clone()
                    treeModel.Name = "Tree"
                    
                    local groundY = 0.5
                    if treeModel:IsA("Model") then
                        local bboxCFrame, size = treeModel:GetBoundingBox()
                        local pivot = treeModel:GetPivot()
                        local pivotOffset = pivot.Position.Y - bboxCFrame.Position.Y
                        local targetY = groundY + (size.Y / 2) + pivotOffset - 3
                        
                        treeModel:PivotTo(CFrame.new(posX, targetY, posZ))
                    elseif treeModel:IsA("BasePart") then
                        treeModel.CFrame = CFrame.new(posX, groundY + treeModel.Size.Y / 2, posZ)
                        treeModel.Anchored = true
                        treeModel.CollisionGroup = "Trees"
                    end
                    
                    treeModel.Parent = mazeFolder
                    
                    local tag = Instance.new("BoolValue")
                    tag.Name = Constants.TreeTag
                    tag.Parent = treeModel
                end
                
            elseif cellType == 3 then
                -- Cat Spawn
                local sp = Instance.new("Part")
                sp.Name = "CatSpawn"
                sp.Anchored = true
                sp.Transparency = 1
                sp.CanCollide = false
                sp.Size = Vector3.new(2, 2, 2)
                sp.Position = Vector3.new(posX, 2, posZ)
                sp.Parent = spawnLocationsFolder
            elseif cellType == 4 then
                -- Dog Spawn
                local sp = Instance.new("Part")
                sp.Name = "DogSpawn"
                sp.Anchored = true
                sp.Transparency = 1
                sp.CanCollide = false
                sp.Size = Vector3.new(2, 2, 2)
                sp.Position = Vector3.new(posX, 3, posZ)
                sp.Parent = spawnLocationsFolder
            elseif cellType == 5 then
                -- Do nothing, it's just a path. No more exit door!
            elseif cellType == 6 then
                -- Collect Safe Zone 1 positions to move the manual spawn there later
                table.insert(safeZone1Positions, Vector3.new(posX, 0.5, posZ))
            elseif cellType == 22 then
                -- Shop
                local shopTemplate = ReplicatedStorage:FindFirstChild("MazeElements") and ReplicatedStorage.MazeElements:FindFirstChild("Shop")
                if shopTemplate then
                    local shopModel = shopTemplate:Clone()
                    shopModel.Name = "Shop"
                    
                    local groundY = 0.5
                    local rotAngle = 0
                    if layout[z-1] and layout[z-1][x] == 0 then
                        rotAngle = math.rad(0)
                    elseif layout[z+1] and layout[z+1][x] == 0 then
                        rotAngle = math.rad(180)
                    elseif row[x-1] == 0 then
                        rotAngle = math.rad(90)
                    elseif row[x+1] == 0 then
                        rotAngle = math.rad(-90)
                    end
                    
                    local offset = CFrame.Angles(0, rotAngle, 0).LookVector * 1.5
                    local finalPosX = posX + offset.X
                    local finalPosZ = posZ + offset.Z
                    
                    if shopModel:IsA("Model") then
                        local bboxCFrame, size = shopModel:GetBoundingBox()
                        local pivotOffsetCFrame = bboxCFrame:Inverse() * shopModel:GetPivot()
                        
                        local newBboxCFrame = CFrame.new(finalPosX, groundY + size.Y / 2, finalPosZ) * CFrame.Angles(0, rotAngle, 0)
                        shopModel:PivotTo(newBboxCFrame * pivotOffsetCFrame)
                    elseif shopModel:IsA("BasePart") then
                        shopModel.CFrame = CFrame.new(finalPosX, groundY + shopModel.Size.Y / 2, finalPosZ) * CFrame.Angles(0, rotAngle, 0)
                        shopModel.Anchored = true
                    end
                    
                    shopModel.Parent = mazeFolder
                end
                
            elseif cellType == 24 then
                -- Lava Obby
                local lavaTemplate = ReplicatedStorage:FindFirstChild("MazeElements") and ReplicatedStorage.MazeElements:FindFirstChild("LavaObby")
                if lavaTemplate then
                    local lavaModel = lavaTemplate:Clone()
                    lavaModel.Name = "LavaObby"
                    
                    local randomRot = math.rad(math.random(0, 3) * 90)
                    local rotCFrame = CFrame.Angles(0, randomRot, 0)
                    
                    if lavaModel:IsA("Model") then
                        -- Trust the prefab's Y offset — the user controls lava depth via the prefab.
                        -- We only override X and Z to place it at the correct tile position.
                        local pivot = lavaModel:GetPivot()
                        lavaModel:PivotTo(CFrame.new(posX, pivot.Position.Y, posZ) * rotCFrame * pivot.Rotation)
                    elseif lavaModel:IsA("BasePart") then
                        -- Single part: keep its original Y, just move XZ
                        lavaModel.CFrame = CFrame.new(posX, lavaModel.CFrame.Position.Y, posZ) * rotCFrame * lavaModel.CFrame.Rotation
                        lavaModel.Anchored = true
                    end
                    
                    makeLethal(lavaModel, "Lava", "Lava")
                    
                    local pfMod = Instance.new("PathfindingModifier")
                    pfMod.Label = "Hazard"
                    pfMod.PassThrough = false
                    pfMod.Parent = lavaModel
                    
                    -- Smart tile border generation
                    local borderThickness = Constants.LavaBorderThickness or 1.5
                    local borderHeight = 1.0
                    local borderY = 0.5
                    local borderColor = Constants.LavaBorderColor or Color3.fromRGB(80, 80, 80)
                    local borderMat = Constants.LavaBorderMaterial or Enum.Material.Slate
                    
                    local function isLavaOrWall(cx, cz)
                        if not layout[cz] or not layout[cz][cx] then return true end
                        local c = layout[cz][cx]
                        return c == 1 or c == 25 or c == 24 or c == 26
                    end
                    
                    local function createBorderNode(offsetX, offsetZ)
                        local node = Instance.new("Part")
                        node.Name = "LavaBorderNode"
                        node.Shape = Enum.PartType.Cylinder
                        node.Size = Vector3.new(borderHeight, borderThickness, borderThickness)
                        node.CFrame = CFrame.new(posX + offsetX, borderY, posZ + offsetZ) * CFrame.Angles(0, 0, math.rad(90))
                        node.Color = borderColor
                        node.Material = borderMat
                        node.Anchored = true
                        node.Parent = lavaModel
                    end
                    
                    local function createBorderEdge(offsetX, offsetZ, sizeX, sizeZ)
                        local edge = Instance.new("Part")
                        edge.Name = "LavaBorderEdge"
                        edge.Size = Vector3.new(sizeX, borderHeight, sizeZ)
                        edge.Position = Vector3.new(posX + offsetX, borderY, posZ + offsetZ)
                        edge.Color = borderColor
                        edge.Material = borderMat
                        edge.Anchored = true
                        edge.Parent = lavaModel
                    end
                    
                    local t = borderThickness
                    local halfCell = cellSize / 2
                    
                    local topWall = isLavaOrWall(x, z-1)
                    local botWall = isLavaOrWall(x, z+1)
                    local leftWall = isLavaOrWall(x-1, z)
                    local rightWall = isLavaOrWall(x+1, z)
                    
                    local corners = {}
                    local function placeCorner(cx, cz)
                        local key = cx .. "_" .. cz
                        if not corners[key] then
                            corners[key] = true
                            createBorderNode(cx, cz)
                        end
                    end
                    
                    if not topWall then
                        createBorderEdge(0, -halfCell, cellSize, t)
                        placeCorner(-halfCell, -halfCell)
                        placeCorner(halfCell, -halfCell)
                    end
                    if not botWall then
                        createBorderEdge(0, halfCell, cellSize, t)
                        placeCorner(-halfCell, halfCell)
                        placeCorner(halfCell, halfCell)
                    end
                    if not leftWall then
                        createBorderEdge(-halfCell, 0, t, cellSize)
                        placeCorner(-halfCell, -halfCell)
                        placeCorner(-halfCell, halfCell)
                    end
                    if not rightWall then
                        createBorderEdge(halfCell, 0, t, cellSize)
                        placeCorner(halfCell, -halfCell)
                        placeCorner(halfCell, halfCell)
                    end
                    
                    lavaModel.Parent = mazeFolder
                end
                
            elseif cellType == 25 then
                -- JustLava
                local lavaTemplate = ReplicatedStorage:FindFirstChild("MazeElements") and ReplicatedStorage.MazeElements:FindFirstChild("JustLava")
                if lavaTemplate then
                    local lavaModel = lavaTemplate:Clone()
                    lavaModel.Name = "JustLava"
                    
                    if lavaModel:IsA("Model") then
                        local pivot = lavaModel:GetPivot()
                        -- Trust the prefab's Y — only override X and Z for tile placement.
                        lavaModel:PivotTo(CFrame.new(posX, pivot.Position.Y, posZ) * pivot.Rotation)
                    elseif lavaModel:IsA("BasePart") then
                        -- Keep original Y, just place at tile XZ
                        lavaModel.CFrame = CFrame.new(posX, lavaModel.CFrame.Position.Y, posZ) * lavaModel.CFrame.Rotation
                        lavaModel.Anchored = true
                    end
                    
                    makeLethal(lavaModel, "Lava", "Lava")
                    
                    local pfMod = Instance.new("PathfindingModifier")
                    pfMod.Label = "Hazard"
                    pfMod.PassThrough = false
                    pfMod.Parent = lavaModel
                    
                    -- Smart tile border generation
                    local borderThickness = Constants.LavaBorderThickness
                    local borderHeight = 1.0
                    local borderY = 0.5
                    local borderColor = Constants.LavaBorderColor
                    local borderMat = Constants.LavaBorderMaterial
                    
                    local function isLavaOrWall(cx, cz)
                        if not layout[cz] or not layout[cz][cx] then return true end
                        local c = layout[cz][cx]
                        return c == 1 or c == 25 or c == 24
                    end
                    
                    local function createBorderNode(offsetX, offsetZ)
                        local node = Instance.new("Part")
                        node.Name = "LavaBorderNode"
                        node.Shape = Enum.PartType.Cylinder
                        node.Size = Vector3.new(borderHeight, borderThickness, borderThickness)
                        node.CFrame = CFrame.new(posX + offsetX, borderY, posZ + offsetZ) * CFrame.Angles(0, 0, math.rad(90))
                        node.Color = borderColor
                        node.Material = borderMat
                        node.Anchored = true
                        node.Parent = lavaModel
                    end
                    
                    local function createBorderEdge(offsetX, offsetZ, sizeX, sizeZ)
                        local edge = Instance.new("Part")
                        edge.Name = "LavaBorderEdge"
                        edge.Size = Vector3.new(sizeX, borderHeight, sizeZ)
                        edge.Position = Vector3.new(posX + offsetX, borderY, posZ + offsetZ)
                        edge.Color = borderColor
                        edge.Material = borderMat
                        edge.Anchored = true
                        edge.Parent = lavaModel
                    end
                    
                    local t = borderThickness
                    local halfCell = cellSize / 2
                    
                    local topWall = isLavaOrWall(x, z-1)
                    local botWall = isLavaOrWall(x, z+1)
                    local leftWall = isLavaOrWall(x-1, z)
                    local rightWall = isLavaOrWall(x+1, z)
                    
                    local corners = {}
                    local function placeCorner(cx, cz)
                        local key = cx .. "_" .. cz
                        if not corners[key] then
                            corners[key] = true
                            createBorderNode(cx, cz)
                        end
                    end
                    
                    if not topWall then
                        createBorderEdge(0, -halfCell, cellSize, t)
                        placeCorner(-halfCell, -halfCell)
                        placeCorner(halfCell, -halfCell)
                    end
                    if not botWall then
                        createBorderEdge(0, halfCell, cellSize, t)
                        placeCorner(-halfCell, halfCell)
                        placeCorner(halfCell, halfCell)
                    end
                    if not leftWall then
                        createBorderEdge(-halfCell, 0, t, cellSize)
                        placeCorner(-halfCell, -halfCell)
                        placeCorner(-halfCell, halfCell)
                    end
                    if not rightWall then
                        createBorderEdge(halfCell, 0, t, cellSize)
                        placeCorner(halfCell, -halfCell)
                        placeCorner(halfCell, halfCell)
                    end
                    
                    lavaModel.Parent = mazeFolder
                end
                
            elseif cellType == 26 then
                -- WaterTile
                local waterTemplate = ReplicatedStorage:FindFirstChild("MazeElements") and ReplicatedStorage.MazeElements:FindFirstChild("WaterTile")
                if waterTemplate then
                    local waterModel = waterTemplate:Clone()
                    waterModel.Name = "WaterTile"
                    
                    if waterModel:IsA("Model") then
                        local bboxCFrame, size = waterModel:GetBoundingBox()
                        local pivot = waterModel:GetPivot()
                        local pivotOffset = pivot.Position.Y - bboxCFrame.Position.Y
                        local targetY = 0.5 - (size.Y/2) + pivotOffset
                        waterModel:PivotTo(CFrame.new(posX, targetY, posZ) * pivot.Rotation)
                    elseif waterModel:IsA("BasePart") then
                        local targetY = 0.5 - (waterModel.Size.Y / 2)
                        waterModel.CFrame = CFrame.new(posX, targetY, posZ) * waterModel.CFrame.Rotation
                        waterModel.Anchored = true
                    end
                    
                    -- Create InvisibleBarrier
                    local barrier = Instance.new("Part")
                    barrier.Name = "InvisibleBarrier"
                    barrier.Size = Vector3.new(cellSize, 20, cellSize)
                    barrier.Position = Vector3.new(posX, 10, posZ)
                    barrier.Anchored = true
                    barrier.Transparency = 1
                    barrier.CollisionGroup = "WaterBarrier"
                    barrier:SetAttribute("IsWaterBarrier", true)
                    
                    -- Pathfinding Modifier
                    local pfMod = Instance.new("PathfindingModifier")
                    pfMod.Label = "Hazard"
                    pfMod.PassThrough = false
                    pfMod.Parent = waterModel
                    
                    -- ProximityPrompt for entering boat
                    local prompt = Instance.new("ProximityPrompt")
                    prompt.ActionText = "Enter Boat"
                    prompt.ObjectText = "Water"
                    prompt.HoldDuration = 1
                    prompt.RequiresLineOfSight = false
                    prompt.MaxActivationDistance = 15
                    prompt.Name = "EnterBoatPrompt"
                    prompt.Enabled = false -- Starts disabled; client enables when player has boat
                    prompt.Parent = barrier
                    
                    waterModel:SetAttribute("IsWaterTile", true)
                    
                    -- Parent barrier to mazeFolder so it survives if the WaterTile script deletes the original part
                    barrier.Parent = mazeFolder
                    waterModel.Parent = mazeFolder
                end
                
            elseif cellType == 27 then
                -- Boat Item
                local boatTemplate = ReplicatedStorage:FindFirstChild("Objects") and ReplicatedStorage.Objects:FindFirstChild("Boat")
                if boatTemplate then
                    local clone = boatTemplate:Clone()
                    clone.Name = "Boat_Pickup"
                    if clone:IsA("Model") then
                        local cframe, size = clone:GetBoundingBox()
                        clone:PivotTo(CFrame.new(posX, 2 + size.Y/2, posZ))
                        clone:SetAttribute("BasePosition", Vector3.new(posX, 2 + size.Y/2, posZ))
                    elseif clone:IsA("BasePart") or clone:IsA("MeshPart") then
                        local size = clone.Size
                        clone.CFrame = CFrame.new(posX, 2 + size.Y/2, posZ)
                        clone:SetAttribute("BasePosition", Vector3.new(posX, 2 + size.Y/2, posZ))
                    end
                    
                    -- Disable collisions and seats
                    for _, p in ipairs(clone:GetDescendants()) do
                        if p:IsA("BasePart") then
                            p.Anchored = true
                            p.CanCollide = false
                        end
                        if p:IsA("Seat") or p:IsA("VehicleSeat") then
                            p.Disabled = true
                        end
                    end
                    if clone:IsA("BasePart") then
                        clone.Anchored = true
                        clone.CanCollide = false
                    end
                    if clone:IsA("Seat") or clone:IsA("VehicleSeat") then
                        clone.Disabled = true
                    end
                    
                    clone:SetAttribute("IsBoat", true)
                    
                    -- Delete embedded scripts to prevent logic conflicts
                    for _, s in ipairs(clone:GetDescendants()) do
                        if s:IsA("Script") or s:IsA("LocalScript") then
                            s:Destroy()
                        end
                    end
                    
                    clone.Parent = workspace
                end
                
            elseif cellType == 28 then
                -- SpikeTile
                local spikeTemplate = ReplicatedStorage:FindFirstChild("MazeElements") and ReplicatedStorage.MazeElements:FindFirstChild("SpikeTile")
                if spikeTemplate then
                    local spikeModel = spikeTemplate:Clone()
                    spikeModel.Name = "SpikeTile"
                    
                    local spikeY = Constants.Parkour and Constants.Parkour.SpikeYOffset or -5.0
                    
                    if spikeModel:IsA("Model") then
                        local pivot = spikeModel:GetPivot()
                        spikeModel:PivotTo(CFrame.new(posX, spikeY, posZ) * pivot.Rotation)
                    elseif spikeModel:IsA("BasePart") then
                        spikeModel.CFrame = CFrame.new(posX, spikeY + spikeModel.Size.Y / 2, posZ) * spikeModel.CFrame.Rotation
                        spikeModel.Anchored = true
                    end
                    
                    makeLethal(spikeModel, "Spikes")
                    
                    local pfMod = Instance.new("PathfindingModifier")
                    pfMod.Label = "Hazard"
                    pfMod.PassThrough = false
                    pfMod.Parent = spikeModel
                    
                    spikeModel.Parent = mazeFolder
                end
                
            elseif cellType == 8 then
                -- White Light Teleporter
                local lightPart = Instance.new("Part")
                lightPart.Name = "WhiteLightTeleporter"
                lightPart.Anchored = true
                lightPart.Size = Vector3.new(cellSize, wallHeight, cellSize)
                lightPart.Position = Vector3.new(posX, wallHeight / 2, posZ)
                lightPart.BrickColor = BrickColor.new("White")
                lightPart.Material = Enum.Material.Neon
                lightPart.CanCollide = false
                
                -- Add PointLight for dramatic effect
                local pointLight = Instance.new("PointLight")
                pointLight.Color = Color3.new(1, 1, 1)
                pointLight.Range = 20
                pointLight.Brightness = 5
                pointLight.Parent = lightPart
                
                lightPart.Parent = mazeFolder
            elseif cellType >= 10 and cellType <= 20 then
                -- Doors and Keys
                local nameMap = {
                    [10] = "BlueDoor", [11] = "BlueKey",
                    [12] = "YellowDoor", [13] = "YellowKey",
                    [14] = "RedDoor", [15] = "RedKey",
                    [16] = "PurpleDoor", [17] = "PurpleKey",
                    [18] = "GreenDoor", [19] = "GreenKey",
                    [20] = "FinalDoor"
                }
                
                local objName = nameMap[cellType]
                if objName then
                    local isDoor = string.find(objName, "Door")
                    local targetFolder = isDoor and doorsFolder or keysFolder
                    
                    local template = nil
                    if isDoor then
                        template = ReplicatedStorage:FindFirstChild("DoorsAndKeys") and ReplicatedStorage.DoorsAndKeys:FindFirstChild(objName)
                    end
                    
                    if template then
                        local clone = template:Clone()
                        clone.Name = objName
                        
                        -- Place it
                        local targetY = isDoor and 5 or 2
                        if clone:IsA("Model") then
                            local bbox, size = clone:GetBoundingBox()
                            local pivotOffset = clone:GetPivot().Position.Y - bbox.Position.Y
                            clone:PivotTo(CFrame.new(posX, targetY + size.Y/2 + pivotOffset, posZ))
                            for _, child in ipairs(clone:GetDescendants()) do
                                if child:IsA("BasePart") then child.Anchored = true end
                            end
                        elseif clone:IsA("BasePart") then
                            clone.CFrame = CFrame.new(posX, targetY + clone.Size.Y/2, posZ)
                            clone.Anchored = true
                        end
                        clone.Parent = targetFolder
                    else
                        -- Fallback blocks if missing
                        local colors = {
                            Blue = Color3.fromRGB(0, 86, 255),
                            Yellow = Color3.fromRGB(251, 255, 0),
                            Red = Color3.fromRGB(255, 0, 0),
                            Purple = Color3.fromRGB(161, 0, 255),
                            Green = Color3.fromRGB(0, 255, 7),
                            Final = Color3.fromRGB(142, 0, 88)
                        }
                        
                        local objColor = Color3.fromRGB(255, 255, 255)
                        for colorName, colorVal in pairs(colors) do
                            if string.find(objName, colorName) then
                                objColor = colorVal
                                break
                            end
                        end
                        
                        if isDoor then
                            local doorModel = Instance.new("Model")
                            doorModel.Name = objName
                            doorModel.Parent = doorsFolder
                            
                            local groundY = 0.5
                            local currentWallHeight = wallHeight
                            local middleHeight = currentWallHeight - Constants.WallBaseHeight - Constants.WallTopHeight
                            
                            local rotAngle = 0
                            if layout[z-1] and layout[z-1][x] == 0 then rotAngle = math.rad(0)
                            elseif layout[z+1] and layout[z+1][x] == 0 then rotAngle = math.rad(180)
                            elseif row[x-1] == 0 then rotAngle = math.rad(90)
                            elseif row[x+1] == 0 then rotAngle = math.rad(-90) end
                            
                            local carveParts = {}
                            local templateName = (objName == "FinalDoor") and "FinalPortal" or "ForestPortal"
                            local forestPortalTemplate = ReplicatedStorage:FindFirstChild("MazeElements") and ReplicatedStorage.MazeElements:FindFirstChild(templateName)
                            if forestPortalTemplate then
                                local portalInstance = forestPortalTemplate:Clone()
                                
                                if objName ~= "FinalDoor" then
                                    for _, part in ipairs(portalInstance:GetDescendants()) do
                                        if part:IsA("BasePart") then
                                            if part.Name == "PortalPartLight" or part.Name == "ColorfulLock" then
                                                part.Color = objColor
                                            elseif part.Name == "PortalPartDark" then
                                                local r = math.clamp(objColor.R * 0.4, 0, 1)
                                                local g = math.clamp(objColor.G * 0.4, 0, 1)
                                                local b = math.clamp(objColor.B * 0.4, 0, 1)
                                                part.Color = Color3.new(r, g, b)
                                            end
                                        end
                                    end
                                else
                                    -- Add BillboardGui for Cat Counter on FinalDoor.
                                    -- AlwaysOnTop=false so it is hidden by walls and distance naturally.
                                    -- Starts Enabled=false; client enables it once GreenKey is collected.
                                    local sg = Instance.new("BillboardGui")
                                    sg.Name = "CatCounterGui"
                                    sg.Size = UDim2.new(10, 0, 3, 0)
                                    sg.StudsOffset = Vector3.new(0, 8, 0)
                                    sg.AlwaysOnTop = false  -- hides behind walls naturally
                                    sg.MaxDistance = 60     -- only visible when close
                                    sg.Enabled = false      -- hidden until GreenKey is unlocked
                                    
                                    local tl = Instance.new("TextLabel")
                                    tl.Size = UDim2.new(1, 0, 1, 0)
                                    tl.BackgroundTransparency = 1
                                    tl.TextScaled = true
                                    tl.TextColor3 = Color3.fromRGB(255, 255, 255)
                                    tl.TextStrokeTransparency = 0
                                    tl.Text = "0/" .. Constants.TotalCats
                                    tl.Font = Enum.Font.FredokaOne
                                    tl.Parent = sg
                                    
                                    local root
                                    if portalInstance:IsA("BasePart") then
                                        root = portalInstance
                                    else
                                        root = portalInstance.PrimaryPart or portalInstance:FindFirstChildWhichIsA("BasePart", true)
                                    end
                                    
                                    if root then
                                        sg.Parent = root
                                    end
                                    
                                    for _, part in ipairs(portalInstance:GetDescendants()) do
                                        if part:IsA("SurfaceGui") or part:IsA("BillboardGui") then
                                            if part.Name ~= "CatCounterGui" then
                                                part:Destroy()
                                            end
                                        end
                                    end
                                end
                                
                                local bbox, size
                                if portalInstance:IsA("Model") then
                                    bbox, size = portalInstance:GetBoundingBox()
                                else
                                    bbox, size = portalInstance.CFrame, portalInstance.Size
                                end
                                local newBboxCFrame = CFrame.new(posX, groundY + size.Y/2, posZ) * CFrame.Angles(0, rotAngle, 0)
                                local pivotOffsetCFrame = bbox:Inverse() * portalInstance:GetPivot()
                                portalInstance:PivotTo(newBboxCFrame * pivotOffsetCFrame)
                                
                                -- Clone each portal arch part and BlockerPart as carve shapes.
                                -- These are the ACTUAL arch-shaped pieces that will be subtracted
                                -- from the wall blocks to create the arch-shaped doorway.
                                for _, part in ipairs(portalInstance:GetDescendants()) do
                                    if part:IsA("BasePart") and (part.Name == "PortalPartLight" or part.Name == "PortalPartDark" or part.Name == "BlockerPart") then
                                        local cp = part:Clone()
                                        local s = cp.Size
                                        -- Extend the carve part along its THINNEST local axis.
                                        -- The thin axis is the wall-depth direction (perpendicular to the portal face).
                                        -- Since cp inherits the portal's rotation via CFrame, local axes are correct.
                                        if s.X <= s.Y and s.X <= s.Z then
                                            cp.Size = Vector3.new(cellSize * 3, s.Y, s.Z)
                                        elseif s.Z <= s.X and s.Z <= s.Y then
                                            cp.Size = Vector3.new(s.X, s.Y, cellSize * 3)
                                        else
                                            cp.Size = Vector3.new(s.X, s.Y, cellSize * 3)
                                        end
                                        cp.Anchored = true
                                        cp.CanCollide = false
                                        cp.CFrame = part.CFrame
                                        table.insert(carveParts, cp)
                                    end
                                end
                                
                                portalInstance.Parent = doorModel
                            end
                            
                            local biomeMidColor
                            if alpha < 0.333 then
                                local subAlpha = alpha / 0.333
                                biomeMidColor = Constants.WallColorA:Lerp(Constants.WallColorB, subAlpha)
                            elseif alpha < 0.666 then
                                local subAlpha = (alpha - 0.333) / 0.333
                                biomeMidColor = Constants.WallColorB:Lerp(Constants.WallColorC, subAlpha)
                            else
                                local subAlpha = (alpha - 0.666) / 0.334
                                biomeMidColor = Constants.WallColorC:Lerp(Constants.WallColorD, subAlpha)
                            end
                            
                            local biomeBaseColor = Constants.WallBaseColor
                            local biomeTopColor = Constants.WallTopColor
                            
                            local function createDoorBlock(name, h, mat, yOffset, color, oversize)
                                local sizeX = cellSize
                                local sizeZ = cellSize
                                
                                if rotAngle == 0 or rotAngle == math.rad(180) then
                                    sizeX = cellSize * 2
                                    sizeZ = cellSize + oversize
                                else
                                    sizeX = cellSize + oversize
                                    sizeZ = cellSize * 2
                                end
                                
                                local block = Instance.new("Part")
                                block.Name = name
                                block.Size = Vector3.new(sizeX, h, sizeZ)
                                block.Position = Vector3.new(posX, yOffset + h/2, posZ)
                                block.Color = color
                                block.Material = mat
                                block.Anchored = true
                                
                                if #carveParts > 0 then
                                    -- SubtractAsync requires ALL parts (the block AND the carve parts)
                                    -- to be direct descendants of workspace. Parent block to workspace first.
                                    block.Parent = workspace
                                    
                                    local activeCarves = {}
                                    for _, cp in ipairs(carveParts) do
                                        local carve = cp:Clone()
                                        carve.Anchored = true
                                        carve.CanCollide = false
                                        carve.Transparency = 1
                                        carve.Parent = workspace
                                        table.insert(activeCarves, carve)
                                    end
                                    
                                    local success, result = pcall(function()
                                        return block:SubtractAsync(activeCarves)
                                    end)
                                    
                                    if success and result then
                                        result.Name = block.Name
                                        result.UsePartColor = true
                                        result.Color = block.Color
                                        result.Material = block.Material
                                        result.Anchored = true
                                        result.Parent = doorModel
                                        applyWallTexture(result, name)
                                        block:Destroy()
                                    else
                                        -- Subtraction failed: move the original block to doorModel
                                        warn("CSG Subtraction failed for door block " .. name .. ": " .. tostring(result))
                                        block.Parent = doorModel
                                        applyWallTexture(block, name)
                                    end
                                    
                                    for _, cp in ipairs(activeCarves) do
                                        cp:Destroy()
                                    end
                                else
                                    block.Parent = doorModel
                                    block.Color = objColor
                                    applyWallTexture(block, name)
                                end
                            end
                            
                            createDoorBlock("Base", Constants.WallBaseHeight, Constants.WallBaseMaterial, groundY, biomeBaseColor, Constants.WallBaseOversize)
                            createDoorBlock("Middle", middleHeight, Constants.WallMiddleMaterial, groundY + Constants.WallBaseHeight, biomeMidColor, 0)
                            createDoorBlock("Top", Constants.WallTopHeight, Constants.WallTopMaterial, groundY + Constants.WallBaseHeight + middleHeight, biomeTopColor, Constants.WallTopOversize)
                        else
                            local keyTemplate = ReplicatedStorage:FindFirstChild("Objects") and ReplicatedStorage.Objects:FindFirstChild("Key")
                            if keyTemplate then
                                local fb = keyTemplate:Clone()
                                fb.Name = objName .. "_Pickup"
                                if fb:IsA("Model") then
                                    local cframe, size = fb:GetBoundingBox()
                                    fb:PivotTo(CFrame.new(posX, size.Y/2 + 3.0, posZ))
                                    fb:SetAttribute("BasePosition", Vector3.new(posX, size.Y/2 + 3.0, posZ))
                                    fb:SetAttribute("IsKey", true)
                                    for _, p in ipairs(fb:GetDescendants()) do
                                        if p:IsA("BasePart") then 
                                            p.Color = objColor 
                                            p.Anchored = true
                                            p.CanCollide = false
                                        end
                                    end
                                elseif fb:IsA("BasePart") or fb:IsA("MeshPart") then
                                    local size = fb.Size
                                    fb.CFrame = CFrame.new(posX, size.Y/2 + 3.0, posZ)
                                    fb:SetAttribute("BasePosition", Vector3.new(posX, size.Y/2 + 3.0, posZ))
                                    fb:SetAttribute("IsKey", true)
                                    fb.Color = objColor
                                    fb.Anchored = true
                                    fb.CanCollide = false
                                    for _, p in ipairs(fb:GetDescendants()) do
                                        if p:IsA("BasePart") then
                                            p.Anchored = true
                                            p.CanCollide = false
                                        end
                                    end
                                end
                                fb.Parent = keysFolder
                            else
                                local fb = Instance.new("Part")
                                fb.Name = objName .. "_Pickup"
                                fb.Anchored = true
                                fb.CanCollide = false
                                fb.Size = Vector3.new(2,2,2)
                                fb.CFrame = CFrame.new(posX, fb.Size.Y/2 + 3.0, posZ)
                                fb:SetAttribute("BasePosition", Vector3.new(posX, fb.Size.Y/2 + 3.0, posZ))
                                fb:SetAttribute("IsKey", true)
                                fb.Color = objColor
                                fb.Parent = keysFolder
                            end
                        end
                    end
                end
            end
        end
    end
    
    if #safeZone1Positions > 0 then
        local sumX, sumZ = 0, 0
        for _, pos in ipairs(safeZone1Positions) do
            sumX = sumX + pos.X
            sumZ = sumZ + pos.Z
        end
        local avgX = sumX / #safeZone1Positions
        local avgZ = sumZ / #safeZone1Positions
        local centerPos = Vector3.new(avgX, 0.5, avgZ)
        
        local spawnLoc = workspace:FindFirstChild("SpawnLocation")
        if spawnLoc then
            -- Y=5 keeps the spawn safely above the maze floor (floor tiles are at Y=0.5)
            spawnLoc.Position = Vector3.new(avgX, 5, avgZ)
        end
    end
    
    -- Spawn custom MazeElements from ReplicatedStorage
    local elements = ReplicatedStorage:FindFirstChild("MazeElements")
    if elements and #validPaths > 0 then
        -- Shuffle validPaths
        for i = #validPaths, 2, -1 do
            local j = math.random(i)
            validPaths[i], validPaths[j] = validPaths[j], validPaths[i]
        end
        
        local occupiedPositions = {}
        
        local function spawnElement(template, count, isHazard, randomScale, pickRandomChild, minDistance)
            if not template then return end
            
            local spawnedCount = 0
            for i = #validPaths, 1, -1 do
                if spawnedCount >= count then break end
                
                local pos = validPaths[i]
                
                local tooClose = false
                if minDistance and minDistance > 0 then
                    for _, occupiedPos in ipairs(occupiedPositions) do
                        if (pos - occupiedPos).Magnitude < minDistance then
                            tooClose = true
                            break
                        end
                    end
                end
                
                if not tooClose then
                    table.remove(validPaths, i)
                    table.insert(occupiedPositions, pos)
                    spawnedCount = spawnedCount + 1
                    
                    local clone
                    if pickRandomChild then
                        local children = template:GetChildren()
                        if #children > 0 then
                            clone = children[math.random(1, #children)]:Clone()
                        else
                            clone = template:Clone()
                        end
                    else
                        clone = template:Clone()
                    end
                    
                    if not clone:IsA("Model") then
                        local newModel = Instance.new("Model")
                        if clone:IsA("BasePart") then
                            clone.Parent = newModel
                            newModel.PrimaryPart = clone
                        else
                            for _, c in ipairs(clone:GetChildren()) do
                                c.Parent = newModel
                            end
                            clone:Destroy()
                        end
                        clone = newModel
                    end
                    
                    if randomScale then
                        local scale = math.random(70, 140) / 100
                        clone:ScaleTo(scale)
                    end
                    
                    -- Apply position and rotation
                    local rot = CFrame.Angles(0, math.rad(math.random(0, 360)), 0)
                    local spawnPos = pos
                    
                    local bbox, size = clone:GetBoundingBox()
                    local pivotOffset = clone:GetPivot().Position.Y - bbox.Position.Y
                    local targetY = pos.Y + (size.Y / 2) + pivotOffset
                    
                    local originalRot = clone:GetPivot().Rotation
                    clone:PivotTo(CFrame.new(spawnPos.X, targetY, spawnPos.Z) * rot * originalRot)
                    
                    
                    if isHazard then
                        -- add touch event to kill
                        local function makeLethal(part)
                            part.Touched:Connect(function(hit)
                                local char = hit.Parent
                                local hum = char and char:FindFirstChild("Humanoid")
                                if hum and hum.Health > 0 then
                                    local Players = game:GetService("Players")
                                    local p = Players:GetPlayerFromCharacter(char)
                                    if p and not char:GetAttribute("Immune") and not char:GetAttribute("Invisible") then
                                        if char:GetAttribute("HasShield") then
                                            local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
                                            local playSoundRemote = remotesFolder and remotesFolder:FindFirstChild("PlaySoundClient")
                                            if playSoundRemote then
                                                playSoundRemote:FireClient(p, "ShieldBreak")
                                            end
                                            char:SetAttribute("HasShield", nil)
                                            local ff = char:FindFirstChild("ShieldFF")
                                            if ff then ff:Destroy() end
                                            
                                            local shieldTool = char:FindFirstChild("Shield")
                                            if shieldTool and shieldTool:IsA("Tool") then
                                                shieldTool:Destroy()
                                            end
                                            
                                            char:SetAttribute("Immune", true)
                                            task.delay(5, function()
                                                if char then char:SetAttribute("Immune", nil) end
                                            end)
                                        else
                                            local hrp = char:FindFirstChild("HumanoidRootPart")
                                            if hrp then hrp.Anchored = true end
                                            char:SetAttribute("Immune", true)
                                            char:SetAttribute("Invisible", true)
                                            p:SetAttribute("GameLost", true)
                                            
                                            for _, c in ipairs(char:GetDescendants()) do
                                                if c:IsA("BasePart") and c.Name ~= "HumanoidRootPart" then
                                                    c.Transparency = 1
                                                elseif c:IsA("Decal") then
                                                    c.Transparency = 1
                                                end
                                            end
                                        end
                                    end
                                end
                            end)
                        end
                        for _, part in ipairs(clone:GetDescendants()) do
                            if part:IsA("BasePart") then
                                makeLethal(part)
                            end
                        end
                        if clone:IsA("BasePart") then
                            makeLethal(clone)
                        end
                    end
                    
                    -- Ensure anchored
                    for _, part in ipairs(clone:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.Anchored = true
                        end
                    end
                    if clone:IsA("BasePart") then
                        clone.Anchored = true
                    end
                    
                    clone.Parent = mazeFolder
                end
            end
        end
        
        spawnElement(elements:FindFirstChild("Mushrooms"), Constants.AmountSpawnedMushrooms or 30, false, true, true, 15)
        spawnElement(elements:FindFirstChild("Plants"), Constants.AmountSpawnedPlants or 60, false, true, true, 10)
        
        -- Manual Dog Mapping overrides procedural generation
        if Maps["dogsMapping"] then
            local dMap = Maps["dogsMapping"]
            for z = 1, #dMap do
                if dMap[z] then
                    for x = 1, #dMap[z] do
                        local dType = dMap[z][x]
                        local offset = Constants.MazeOffset or Vector3.new(0, 0, 0)
                        local px = (x - 1) * cellSize + offset.X
                        local pz = (z - 1) * cellSize + offset.Z
                        if dType == 1 then
                            local sp = Instance.new("Part")
                            sp.Name = "DogSpawn"
                            sp.Anchored = true
                            sp.Transparency = 1
                            sp.CanCollide = false
                            sp.Size = Vector3.new(2, 2, 2)
                            sp.Position = Vector3.new(px, 3, pz)
                            sp.Parent = spawnLocationsFolder
                        elseif dType == 2 then
                            local barrier = Instance.new("Part")
                            barrier.Name = "DogBarrier"
                            barrier.Anchored = true
                            barrier.Transparency = 1
                            barrier.CanCollide = true
                            barrier.Size = Vector3.new(cellSize, 20, cellSize)
                            barrier.Position = Vector3.new(px, 10, pz)
                            barrier.CollisionGroup = "DogBarrier"
                            
                            local pfMod = Instance.new("PathfindingModifier")
                            pfMod.Label = "DogBarrier"
                            pfMod.PassThrough = false
                            pfMod.Parent = barrier
                            
                            barrier.Parent = mazeFolder
                        end
                    end
                end
            end
        else
            -- Spawn Dogs dynamically based on Constants.TotalDogs
            local totalDogs = Constants.TotalDogs or 6
            for i = 1, totalDogs do
                if #validPaths == 0 then break end
                local pos = validPaths[#validPaths]
                table.remove(validPaths, #validPaths)
                
                local sp = Instance.new("Part")
                sp.Name = "DogSpawn"
                sp.Anchored = true
                sp.Transparency = 1
                sp.CanCollide = false
                sp.Size = Vector3.new(2, 2, 2)
                sp.Position = Vector3.new(pos.X, 3, pos.Z)
                sp.Parent = spawnLocationsFolder
            end
        end
    end
    
    -- Manual Platform Mapping overrides procedural generation
    if Maps["platformMapping"] then
        local pMap = Maps["platformMapping"]
        for z = 1, #pMap do
            if pMap[z] then
                for x = 1, #pMap[z] do
                    -- Black pixels map to 1
                    if pMap[z][x] == 1 then
                        local offset = Constants.MazeOffset or Vector3.new(0, 0, 0)
                        local px = (x - 1) * cellSize + offset.X
                        local pz = (z - 1) * cellSize + offset.Z
                        
                        local scaleFactor = Constants.Parkour and Constants.Parkour.Scale or 0.425
                        -- The original Platform model has a diameter of 10 studs
                        local platformRadius = 5 * scaleFactor
                        
                        -- The max safe distance from the center of the cell to avoid hitting walls
                        local safeCellRadius = (cellSize / 2) - platformRadius
                        if safeCellRadius < 0 then safeCellRadius = 0 end
                        
                        -- Read XZVariation and strictly cap it to the safe radius!
                        local xzVar = Constants.Parkour and Constants.Parkour.XZVariation or 1.5
                        if xzVar > safeCellRadius then xzVar = safeCellRadius end
                        
                        -- Choose a random spot inside the strictly bounded radius
                        local rx = (math.random() - 0.5) * 2 * xzVar
                        local rz = (math.random() - 0.5) * 2 * xzVar
                        
                        local targetX = px + rx
                        local targetZ = pz + rz
                        
                        local baseHeight = Constants.Parkour and Constants.Parkour.BaseHeight or 5.0
                        local yVar = Constants.Parkour and Constants.Parkour.YVariation or 1.0
                        local randY = (math.random() - 0.5) * 2 * yVar
                        local targetY = baseHeight + randY
                        
                        local targetPos = Vector3.new(targetX, targetY, targetZ)
                        
                        local platformTemplate = ReplicatedStorage:FindFirstChild("MazeElements") and ReplicatedStorage.MazeElements:FindFirstChild("Platform")
                        if platformTemplate then
                            local platformModel = platformTemplate:Clone()
                            platformModel.Name = "ParkourPlatform"
                            
                            if platformModel:IsA("Model") then
                                local pivot = platformModel:GetPivot()
                                platformModel:PivotTo(CFrame.new(targetPos) * pivot.Rotation)
                                if platformModel.ScaleTo then
                                    platformModel:ScaleTo(scaleFactor)
                                end
                            elseif platformModel:IsA("BasePart") then
                                platformModel.CFrame = CFrame.new(targetPos) * platformModel.CFrame.Rotation
                                platformModel.Size = platformModel.Size * scaleFactor
                                platformModel.Anchored = true
                            end
                            
                            platformModel.Parent = mazeFolder
                        end
                    end
                end
            end
        end
    end
end

buildMaze()

-- Post-build optimization: Disable CastShadow on ALL maze geometry
-- and disable CanQuery on decorative parts (non-Collider) to exclude them from raycasts
local mazeFolder = workspace:FindFirstChild("MazeElements")
if mazeFolder then
    for _, obj in ipairs(mazeFolder:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.CastShadow = false
            -- Disable CanQuery on decorative parts that don't need to be hit by raycasts
            -- Keep CanQuery on Collider parts (ColliderNode, ColliderEdgeRight, ColliderEdgeDown)
            -- and on floor tiles, barriers, platforms, etc.
            local name = obj.Name
            if string.find(name, "Node") and not string.find(name, "Collider") then
                obj.CanQuery = false
            elseif string.find(name, "Edge") and not string.find(name, "Collider") then
                obj.CanQuery = false
            end
        end
    end
end

-- Also disable on the Base/SafeZone
local baseFolder = workspace:FindFirstChild("Base")
if baseFolder then
    for _, obj in ipairs(baseFolder:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.CastShadow = false
        end
    end
end

workspace:SetAttribute("MazeGenerated", true)

-- FINAL NUKE: The mysterious white light appears inside MazeElements at 0,0,0.
-- Let's scan MazeElements specifically at 0,0,0 and destroy it.
if mazeFolder then
    for _, obj in ipairs(mazeFolder:GetDescendants()) do
        if obj:IsA("BasePart") then
            local pos = obj.Position
            -- If it's very close to 0,0,0 and it's not a standard outer wall/floor
            if pos.Magnitude < 5 then
                if obj.Name ~= "FloorTile" and obj.Name ~= "FortressWall" and obj.Name ~= "ColliderNode" then
                    print("[MazeBuilder] 💥 FINAL NUKE DESTROYED ARTIFACT AT 0,0,0:", obj.Name, "ClassName:", obj.ClassName, "Material:", tostring(obj.Material), "Color:", tostring(obj.Color))
                    obj:Destroy()
                elseif obj.Material == Enum.Material.Neon then
                    print("[MazeBuilder] 💥 FINAL NUKE DESTROYED NEON WALL/FLOOR AT 0,0,0:", obj.Name)
                    obj:Destroy()
                end
            end
        elseif obj:IsA("Light") or obj:IsA("ParticleEmitter") or obj:IsA("Beam") then
            local p = obj.Parent
            if p and p:IsA("BasePart") and p.Position.Magnitude < 5 then
                print("[MazeBuilder] 💥 FINAL NUKE DESTROYED LIGHT/EFFECT AT 0,0,0:", obj.Name)
                obj:Destroy()
            end
        end
    end
end

-- Apply MazeOffset to the pre-placed Base model
local offset = Constants.MazeOffset or Vector3.new(0,0,0)
if offset.Magnitude > 0 then
    local base = workspace:FindFirstChild("Base")
    if base then
        if base:IsA("Model") then
            base:PivotTo(base:GetPivot() + offset)
        else
            for _, obj in ipairs(base:GetDescendants()) do
                if obj:IsA("BasePart") then
                    obj.CFrame = obj.CFrame + offset
                end
            end
        end
    end
    
    -- Also shift any players that have already spawned on the unshifted Base
    for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
        if player.Character and player.Character.PrimaryPart then
            player.Character:PivotTo(player.Character:GetPivot() + offset)
        end
    end
end
