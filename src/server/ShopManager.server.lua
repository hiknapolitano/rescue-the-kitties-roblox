local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local SoundManager = require(Shared:WaitForChild("SoundManager"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local openShopRemote = remotes:WaitForChild("OpenShop")
local purchaseItemRemote = remotes:WaitForChild("PurchaseItem")

local AvatarCache = ServerStorage:FindFirstChild("ShopAvatars")
if not AvatarCache then
    AvatarCache = Instance.new("Folder")
    AvatarCache.Name = "ShopAvatars"
    AvatarCache.Parent = ServerStorage
end

local avatarsLoaded = false

task.spawn(function()
    local usernames = Constants.ShopOwnerUsernames or {"Roblox"}
    for _, username in ipairs(usernames) do
        pcall(function()
            local userId = Players:GetUserIdFromNameAsync(username)
            if not userId then return end
            
            local model = nil
            local fSuccess, fModel = pcall(function()
                return Players:CreateHumanoidModelFromUserId(userId)
            end)
            if fSuccess and fModel then
                model = fModel
            end
            
            if model then
                model.Name = username
                for _, p in ipairs(model:GetDescendants()) do
                    if p:IsA("BasePart") then
                        p.Anchored = false -- Keep unanchored to preserve joint positioning
                        p.CanCollide = false
                    end
                end
                model.Parent = AvatarCache
            end
        end)
        task.wait(0.1)
    end
    
    avatarsLoaded = true
end)

local ShopItems = {
    { id = "MinimapPerm", name = "PERMANENT Minimap", price = 0, isGamepass = true, desc = "See the maze and remaining cats FOREVER! (Robux)" },
    { id = "FlashlightUpgradePerm", name = "PERMANENT Flashlight Upgrade", price = 0, isGamepass = true, desc = "A miner's helmet with an infinite light FOREVER! (Robux)" },
    { id = "Potion", name = "Invisibility Potion", price = Constants.ShopPrices.Potion or 5, desc = "Become invisible to dogs for 10 seconds." },
    { id = "EnergyDrink", name = "Energy Drink", price = Constants.ShopPrices.EnergyDrink or 5, desc = "Run faster for 10 seconds." },
    { id = "Shield", name = "Shield", price = Constants.ShopPrices.Shield or 5, desc = "Survive one dog attack." },
    { id = "Bone", name = "Bone", price = Constants.ShopPrices.Bone or 5, desc = "Throw to distract the closest dog." },
    { id = "FlashlightUpgrade", name = "Flashlight Upgrade", price = Constants.ShopPrices.FlashlightUpgrade or 10, desc = "A miner's helmet with an infinite light. Replaces your handheld flashlight." },
    { id = "Minimap", name = "Minimap", price = Constants.ShopPrices.Minimap or 18, desc = "See the maze and remaining cats." },
    { id = "Bandage", name = "Bandage", price = Constants.ShopPrices.Bandage or 7, desc = "Heal yourself from hazard damage." }
}

-- Setup Shop Stand Prompt & Assign Unique Avatars
task.spawn(function()
    local mazeElements = workspace:WaitForChild("MazeElements")
    while not workspace:GetAttribute("MazeGenerated") do
        task.wait(0.5)
    end
    
    -- Collect all shop stands in maze
    local shopStands = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "Shop" and (obj:IsA("Model") or obj:IsA("BasePart")) then
            table.insert(shopStands, obj)
        end
    end
    
    -- Setup prompts
    for _, obj in ipairs(shopStands) do
        local primary = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)) or obj
        if primary and not primary:FindFirstChild("ShopPrompt") then
            local prompt = Instance.new("ProximityPrompt")
            prompt.Name = "ShopPrompt"
            prompt.ActionText = "Open Shop"
            prompt.ObjectText = "Shop Stand"
            prompt.HoldDuration = 1
            prompt.RequiresLineOfSight = false
            prompt.MaxActivationDistance = 15
            prompt.Parent = primary
            
            prompt.Triggered:Connect(function(player)
                local filteredItems = {}
                for _, item in ipairs(ShopItems) do
                    if item.id == "Minimap" and player:GetAttribute("HasMinimap") then
                        continue
                    elseif item.id == "FlashlightUpgrade" and player:GetAttribute("HasHelmet") then
                        continue
                    end
                    table.insert(filteredItems, item)
                end
                openShopRemote:FireClient(player, filteredItems)
            end)
            
            -- Disable CastShadow on shop model
            for _, part in ipairs(obj:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CastShadow = false
                end
            end
        end
    end
    
    -- Wait for avatars to finish loading
    local timeout = 0
    while not avatarsLoaded and #AvatarCache:GetChildren() < #shopStands and timeout < 10 do
        task.wait(0.5)
        timeout = timeout + 0.5
    end
    
    local availableAvatars = AvatarCache:GetChildren()
    if #availableAvatars > 0 then
        -- Fisher-Yates Shuffle available avatars so shop distribution is randomized
        for i = #availableAvatars, 2, -1 do
            local j = math.random(i)
            availableAvatars[i], availableAvatars[j] = availableAvatars[j], availableAvatars[i]
        end
        
        -- Assign unique avatar to each shop stand
        for idx, obj in ipairs(shopStands) do
            local r6 = obj:FindFirstChild("R6") or obj:FindFirstChild("Dummy")
            if not r6 then
                for _, child in ipairs(obj:GetChildren()) do
                    if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
                        r6 = child
                        break
                    end
                end
            end
            
            if r6 then
                local avatarTemplate = availableAvatars[((idx - 1) % #availableAvatars) + 1]
                if avatarTemplate then
                    local customAvatar = avatarTemplate:Clone()
                    customAvatar.Name = "Vendor"
                    
                    -- Get the R6 HumanoidRootPart position to place the avatar correctly
                    local r6HRP = r6:FindFirstChild("HumanoidRootPart")
                    local r6Pivot = r6:GetPivot()
                    
                    -- Reset Motor6D transforms to prevent detached heads/limbs when anchoring
                    for _, m in ipairs(customAvatar:GetDescendants()) do
                        if m:IsA("Motor6D") then
                            m.Transform = CFrame.new()
                        end
                    end
                    
                    -- Anchor only HumanoidRootPart to let joints position the limbs/head correctly
                    for _, part in ipairs(customAvatar:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                            if part.Name == "HumanoidRootPart" then
                                part.Anchored = true
                            else
                                part.Anchored = false
                            end
                        end
                    end
                    
                    local humanoid = customAvatar:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        humanoid.PlatformStand = true
                        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
                    end
                    
                    -- Place avatar so its HumanoidRootPart matches the dummy's
                    local avatarHRP = customAvatar:FindFirstChild("HumanoidRootPart")
                    if avatarHRP then
                        -- Compute offset from avatar model pivot to HRP
                        local avatarPivot = customAvatar:GetPivot()
                        local hrpOffset = avatarPivot:Inverse() * avatarHRP.CFrame
                        -- Target: place HRP where R6's HRP is (or model pivot if no HRP)
                        local targetHRPCFrame = r6HRP and r6HRP.CFrame or r6Pivot
                        customAvatar:PivotTo(targetHRPCFrame * hrpOffset:Inverse())
                    else
                        customAvatar:PivotTo(r6Pivot)
                    end
                    
                    customAvatar.Parent = obj
                    r6:Destroy()
                    
                    -- Add "Vendor" nametag BillboardGui above head
                    -- AlwaysOnTop=false so walls/distance naturally hide it
                    local headPart = customAvatar:FindFirstChild("Head")
                    if headPart then
                        local bb = Instance.new("BillboardGui")
                        bb.Name = "VendorNameGui"
                        bb.Size = UDim2.new(0, 120, 0, 30)
                        bb.StudsOffset = Vector3.new(0, 2, 0)
                        bb.AlwaysOnTop = false
                        bb.MaxDistance = 25
                        bb.Parent = headPart
                        
                        local label = Instance.new("TextLabel")
                        label.Size = UDim2.new(1, 0, 1, 0)
                        label.BackgroundTransparency = 1
                        label.Text = "🛒 Vendor"
                        label.TextColor3 = Color3.fromRGB(255, 220, 50)
                        label.TextStrokeTransparency = 0
                        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                        label.TextScaled = true
                        label.Font = Enum.Font.FredokaOne
                        label.Parent = bb
                    end
                end
            end
        end
    end
end)

local function giveItem(player, itemId)
    local isTool = (itemId == "Potion" or itemId == "EnergyDrink" or itemId == "Shield" or itemId == "Bone")
    
    if isTool then
        local count = 0
        if player:FindFirstChild("Backpack") then
            count = count + #player.Backpack:GetChildren()
        end
        if player.Character and player.Character:FindFirstChildOfClass("Tool") then
            count = count + 1
        end
        
        if count >= 9 then
            local notifyEvt = game:GetService("ReplicatedStorage"):FindFirstChild("ShowNotification")
            if notifyEvt then
                notifyEvt:FireClient(player, "Inventory Full!")
            end
            return false
        end
    end

    if itemId == "Potion" then
        local evt = ServerStorage:FindFirstChild("ItemPickedUp")
        if evt then evt:Fire(player, "potion") end
        return true
    elseif itemId == "EnergyDrink" then
        local evt = ServerStorage:FindFirstChild("ItemPickedUp")
        if evt then evt:Fire(player, "EnergyDrink") end
        return true
    elseif itemId == "Shield" then
        local evt = ServerStorage:FindFirstChild("ItemPickedUp")
        if evt then evt:Fire(player, "Shield") end
        return true
    elseif itemId == "Bone" then
        local evt = ServerStorage:FindFirstChild("ItemPickedUp")
        if evt then evt:Fire(player, "Bone") end
        return true
    elseif itemId == "FlashlightUpgrade" or itemId == "FlashlightUpgradePerm" then
        if player.Character and not player.Character:FindFirstChild("FlashlightHelmet") then
            player:SetAttribute("HasHelmet", true)
            
            -- Remove old flashlight
            if player.Backpack:FindFirstChild("Flashlight") then
                player.Backpack.Flashlight:Destroy()
            end
            if player.Character:FindFirstChild("Flashlight") then
                player.Character.Flashlight:Destroy()
            end
            
            local template = game:GetService("ReplicatedStorage"):FindFirstChild("Objects") and game:GetService("ReplicatedStorage").Objects:FindFirstChild("Helmet")
            local helmet
            
            if template then
                helmet = template:Clone()
                if helmet:IsA("Model") then
                    -- If it's a model, make sure we manipulate its primary part
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
            

            
            local head = player.Character:FindFirstChild("Head")
            if head then
                helmet.CFrame = head.CFrame * CFrame.new(0, 0.5, 0)
                local weld = Instance.new("WeldConstraint")
                weld.Part0 = head
                weld.Part1 = helmet
                weld.Parent = helmet
                helmet.Parent = player.Character
                return true
            end
        end
        return false -- already has helmet
    elseif itemId == "Minimap" or itemId == "MinimapPerm" then
        if not player:GetAttribute("HasMinimap") then
            player:SetAttribute("HasMinimap", true)
            return true
        end
        return false
    elseif itemId == "Bandage" then
        local evt = ServerStorage:FindFirstChild("ItemPickedUp")
        if evt then evt:Fire(player, "Bandage") end
        return true
    end
    return false
end

purchaseItemRemote.OnServerInvoke = function(player, itemId)
    local item = nil
    for _, it in ipairs(ShopItems) do
        if it.id == itemId then
            item = it
            break
        end
    end
    
    if not item then return false, "Item not found" end
    
    -- Handle whitelist gamepass bypassing
    if item.isGamepass and table.find(Constants.FreePurchaseWhitelist, player.Name) then
        local success = giveItem(player, itemId)
        return success, "Gamepass Whitelisted"
    end
    
    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then return false, "No leaderstats" end
    
    local coins = leaderstats:FindFirstChild("Coins")
    if not coins then return false, "No coins" end
    
    local success, inGroup = pcall(function()
        return Constants.GroupId > 0 and player:IsInGroup(Constants.GroupId)
    end)
    local hasDiscount = success and inGroup
    local finalPrice = hasDiscount and math.floor(item.price * 0.8) or item.price
    
    if coins.Value < finalPrice then
        return false, "Not enough coins!"
    end
    
    local given = giveItem(player, itemId)
    if given then
        coins.Value = coins.Value - finalPrice
        local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
        local playSoundRemote = remotesFolder and remotesFolder:FindFirstChild("PlaySoundClient")
        if playSoundRemote then
            playSoundRemote:FireClient(player, "ShopBuy")
        end
        return true, "Purchased " .. item.name .. "!"
    else
        return false, "Could not purchase right now (already have it?)"
    end
end
