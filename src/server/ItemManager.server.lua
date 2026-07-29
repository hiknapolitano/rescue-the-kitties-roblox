local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local itemsList = {"DogBone", "EnergyDrink", "Shield", "Cash", "potion"}

-- Get PlaySoundClient remote for client-only sounds
local playSoundRemote = nil
task.spawn(function()
    local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
    playSoundRemote = remotesFolder:WaitForChild("PlaySoundClient")
end)

-- Sanitize free models to remove hidden virus scripts like 'TypeConfig'
local objectsFolder = ReplicatedStorage:FindFirstChild("Objects")
if objectsFolder then
    for _, obj in ipairs(objectsFolder:GetDescendants()) do
        if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
            obj:Destroy()
        end
    end
end

if not ReplicatedStorage:FindFirstChild("ShowNotification") then
    local notifyEvt = Instance.new("RemoteEvent")
    notifyEvt.Name = "ShowNotification"
    notifyEvt.Parent = ReplicatedStorage
end

local function createToolFromTemplate(itemName)
    local tool = Instance.new("Tool")
    tool.Name = itemName
    tool.RequiresHandle = true
    
    local template = ReplicatedStorage:FindFirstChild("Objects") and ReplicatedStorage.Objects:FindFirstChild(itemName)
    local handle
    
    if template then
        local clone = template:Clone()
        if clone:IsA("Model") then
            -- We need a single BasePart named "Handle"
            handle = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
            if handle then
                handle.Name = "Handle"
                for _, child in ipairs(clone:GetDescendants()) do
                    if child:IsA("BasePart") and child ~= handle then
                        local weld = Instance.new("WeldConstraint")
                        weld.Part0 = handle
                        weld.Part1 = child
                        weld.Parent = handle
                        child.Anchored = false
                        child.CanCollide = false
                    end
                end
                handle.Anchored = false
                handle.CanCollide = false
                
                -- Reparent children to the new handle
                for _, child in ipairs(clone:GetChildren()) do
                    if child ~= handle then
                        child.Parent = handle
                    end
                end
                handle.Parent = tool
            else
                clone:Destroy()
            end
        else
            handle = clone
            handle.Name = "Handle"
            handle.Anchored = false
            handle.CanCollide = false
            handle.Parent = tool
        end
    end
    
    -- Fallback if no template or handle found
    if not handle then
        handle = Instance.new("Part")
        handle.Name = "Handle"
        handle.Size = Vector3.new(1, 1, 1)
        handle.Parent = tool
    end
    
    return tool
end

local function createBoneTool()
    -- Look for DogBone template if available, else Bone
    local tool = createToolFromTemplate("DogBone")
    if not tool:FindFirstChild("Handle") or tool.Handle.ClassName == "Part" and tool.Handle.Size == Vector3.new(1,1,1) then
        tool = createToolFromTemplate("Bone")
    end
    
    local equipTime = 0
    tool.Equipped:Connect(function()
        equipTime = tick()
    end)
    
    tool.Activated:Connect(function()
        if tick() - equipTime < 0.2 then return end
        
        local char = tool.Parent
        if char and char:FindFirstChild("Humanoid") then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local thrownBone = tool.Handle:Clone()
                thrownBone.Name = "ThrownBone"
                thrownBone.CFrame = hrp.CFrame * CFrame.new(0, 1, -2)
                thrownBone.CanCollide = true
                for _, child in ipairs(thrownBone:GetDescendants()) do
                    if child:IsA("BasePart") then
                        child.CanCollide = true
                    end
                end
                
                thrownBone.Parent = workspace
                thrownBone.AssemblyLinearVelocity = hrp.CFrame.LookVector * 50 + Vector3.new(0, 20, 0)
                
                local p = game:GetService("Players"):GetPlayerFromCharacter(char)
                if p and playSoundRemote then
                    playSoundRemote:FireClient(p, "BoneThrow")
                end
                
                -- DogAI will look for ThrownBone
                Debris:AddItem(thrownBone, 15) 
                
                tool:Destroy()
            end
        end
    end)
    return tool
end

local function createEnergyDrinkTool()
    local tool = createToolFromTemplate("EnergyDrink")
    
    local equipTime = 0
    tool.Equipped:Connect(function()
        equipTime = tick()
    end)
    
    tool.Activated:Connect(function()
        if tick() - equipTime < 0.2 then return end
        
        local char = tool.Parent
        local humanoid = char and char:FindFirstChild("Humanoid")
        if humanoid then
            local p = Players:GetPlayerFromCharacter(char)
            if p and playSoundRemote then
                playSoundRemote:FireClient(p, "EnergyDrinkUse")
            end
            local currentBoostEnd = char:GetAttribute("SpeedBoostEnd") or 0
            if currentBoostEnd > workspace:GetServerTimeNow() then
                -- Already boosted, add 10 more seconds
                char:SetAttribute("SpeedBoostEnd", currentBoostEnd + 10)
            else
                -- New boost
                char:SetAttribute("SpeedBoostEnd", workspace:GetServerTimeNow() + 10)
            end
            tool:Destroy()
        end
    end)
    return tool
end

local function createInvisibilityPotionTool()
    local tool = createToolFromTemplate("potion")
    tool.RequiresHandle = false
    
    tool.Activated:Connect(function()
        local char = tool.Parent
        local humanoid = char and char:FindFirstChild("Humanoid")
        if humanoid then
            if char:GetAttribute("PotionActive") then
                -- Already have a potion active, do not stack effects
                tool:Destroy()
                return
            end
            
            
            tool:Destroy()
            
            local p = Players:GetPlayerFromCharacter(char)
            if p and playSoundRemote then
                playSoundRemote:FireClient(p, "EnergyDrinkUse")
                playSoundRemote:FireClient(p, "InvisibilityUse")
            end
            
            char:SetAttribute("PotionActive", true)
            char:SetAttribute("Invisible", true)
            
            local originalTransparencies = {}
            local originalEnabled = {}
            
            local function makePartInvisible(part)
                local isFlashlight = false
                local pTool = part:FindFirstAncestorWhichIsA("Tool")
                if pTool and pTool.Name == "Flashlight" then isFlashlight = true end
                
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Name ~= "FlashlightHelmet" and not isFlashlight then
                    if originalTransparencies[part] == nil then
                        originalTransparencies[part] = part.Transparency
                    end
                    part.Transparency = 1
                elseif part:IsA("Decal") or part:IsA("Texture") then
                    if originalTransparencies[part] == nil then
                        originalTransparencies[part] = part.Transparency
                    end
                    part.Transparency = 1
                elseif part:IsA("ParticleEmitter") or part:IsA("Trail") or part:IsA("Beam") then
                    if originalEnabled[part] == nil then
                        originalEnabled[part] = part.Enabled
                    end
                    part.Enabled = false
                elseif part:IsA("ForceField") then
                    if originalEnabled[part] == nil then
                        originalEnabled[part] = part.Visible
                    end
                    part.Visible = false
                end
            end
            
            for _, part in ipairs(char:GetDescendants()) do
                makePartInvisible(part)
            end
            
            local descendantAddedConn
            descendantAddedConn = char.DescendantAdded:Connect(function(descendant)
                if char:GetAttribute("Invisible") then
                    makePartInvisible(descendant)
                end
            end)
            
            local diedConn
            diedConn = humanoid.Died:Connect(function()
                if descendantAddedConn then descendantAddedConn:Disconnect() end
                if diedConn then diedConn:Disconnect() end
                char:SetAttribute("PotionActive", nil)
                char:SetAttribute("Invisible", nil)
            end)
            
            task.delay(10, function()
                if char then
                    char:SetAttribute("PotionActive", nil)
                    char:SetAttribute("Invisible", nil)
                    if descendantAddedConn then descendantAddedConn:Disconnect() end
                    
                    for part, trans in pairs(originalTransparencies) do
                        if part and part.Parent then
                            part.Transparency = trans
                        end
                    end
                    for effect, enabled in pairs(originalEnabled) do
                        if effect and effect.Parent then
                            if effect:IsA("ForceField") then
                                effect.Visible = enabled
                            else
                                effect.Enabled = enabled
                            end
                        end
                    end
                    if diedConn then diedConn:Disconnect() end
                end
            end)
        end
    end)
    return tool
end

local function createShieldTool()
    local tool = createToolFromTemplate("Shield")
    tool.GripPos = Vector3.new(0, 0, 0.3) -- Offset to prevent hand clipping
    
    local currentTargetChar = nil
    local charFF = nil
    
    tool.Equipped:Connect(function()
        currentTargetChar = tool.Parent
        if currentTargetChar then
            local humanoid = currentTargetChar:FindFirstChild("Humanoid")
            if humanoid and not currentTargetChar:GetAttribute("HasShield") then
                currentTargetChar:SetAttribute("HasShield", true)
                charFF = Instance.new("ForceField")
                charFF.Name = "ShieldFF"
                charFF.Parent = currentTargetChar
            end
        end
    end)
    
    tool.Unequipped:Connect(function()
        if currentTargetChar then
            currentTargetChar:SetAttribute("HasShield", nil)
            if charFF then
                charFF:Destroy()
                charFF = nil
            end
            local oldFF = currentTargetChar:FindFirstChild("ShieldFF")
            if oldFF then oldFF:Destroy() end
            currentTargetChar = nil
        end
    end)
    
    tool.Activated:Connect(function()
        -- Shield is passive when equipped, no activation needed
    end)
    
    return tool
end

local function createBandageTool()
    local tool = createToolFromTemplate("Bandage")
    
    local equipTime = 0
    tool.Equipped:Connect(function()
        equipTime = tick()
    end)
    
    tool.Activated:Connect(function()
        if tick() - equipTime < 0.2 then return end
        local char = tool.Parent
        local player = game:GetService("Players"):GetPlayerFromCharacter(char)
        if player then
            if playSoundRemote then
                playSoundRemote:FireClient(player, "ItemPickup")
            end
            
            local currentHP = player:GetAttribute("HP") or Constants.MaximumHP
            local newHP = math.min(Constants.MaximumHP, currentHP + Constants.BandageHealAmount)
            player:SetAttribute("HP", newHP)
            
            tool:Destroy()
        end
    end)
    return tool
end

task.spawn(function()
    -- Wait for event to be created by ItemSpawner
    local evt = ServerStorage:WaitForChild("ItemPickedUp", 10)
    if not evt then
        evt = Instance.new("BindableEvent")
        evt.Name = "ItemPickedUp"
        evt.Parent = ServerStorage
    end
    
    evt.Event:Connect(function(player, itemName)
        if player.Character and player.Character.PrimaryPart then
            if playSoundRemote then
                playSoundRemote:FireClient(player, "ItemPickup")
            end
        end
        
        if itemName == "Bone" or itemName == "DogBone" then
            local tool = createBoneTool()
            tool.Parent = player.Backpack
        elseif itemName == "EnergyDrink" then
            local tool = createEnergyDrinkTool()
            tool.Parent = player.Backpack
        elseif itemName == "Shield" then
            local tool = createShieldTool()
            tool.Parent = player.Backpack
        elseif itemName == "InvisibilityPotion" or itemName == "potion" then
            local tool = createInvisibilityPotionTool()
            tool.Parent = player.Backpack
        elseif itemName == "Cash" then
            local leaderstats = player:FindFirstChild("leaderstats")
            if leaderstats then
                local coins = leaderstats:FindFirstChild("Coins")
                if coins then
                    coins.Value = coins.Value + 1
                end
            end
        elseif itemName == "Bandage" then
            local tool = createBandageTool()
            tool.Parent = player.Backpack
        end
    end)
end)
