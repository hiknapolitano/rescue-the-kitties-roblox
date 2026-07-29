local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")

local revivePlayerRemote = remotesFolder:FindFirstChild("RevivePlayer")
if not revivePlayerRemote then
    revivePlayerRemote = Instance.new("RemoteEvent")
    revivePlayerRemote.Name = "RevivePlayer"
    revivePlayerRemote.Parent = remotesFolder
end

local trollRemote = remotesFolder:FindFirstChild("TrollEffectStarted")
if not trollRemote then
    trollRemote = Instance.new("RemoteEvent")
    trollRemote.Name = "TrollEffectStarted"
    trollRemote.Parent = remotesFolder
end

local function findNearestSafePos(position)
    local Maps = require(Shared:WaitForChild("Maps"))
    local layout = Maps[Constants.ActiveLevel]
    if not layout then return nil end
    
    local cellSize = Constants.CellSize
    local bestPos = nil
    local bestDist = math.huge
    
    for z, row in ipairs(layout) do
        for x, cellType in ipairs(row) do
            if cellType == 0 then
                local mazeOffset = Constants.MazeOffset or Vector3.new(0, 0, 0)
                local px = (x - 1) * cellSize + mazeOffset.X
                local pz = (z - 1) * cellSize + mazeOffset.Z
                
                local testPos = Vector3.new(px, 0, pz)
                local dist = (testPos - Vector3.new(position.X, 0, position.Z)).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    bestPos = Vector3.new(px, 5.5, pz) -- 5.5 is safely above the 0.5 ground level
                end
            end
        end
    end
    
    return bestPos
end

local function grantRevive(player)
    local char = player.Character
    if char then
        -- Clear flags
        player:SetAttribute("DiedByLava", nil)
        
        -- Unfreeze HRP
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.Anchored = false end
        
        -- ALWAYS teleport to nearest safe floor tile regardless of how they died
        if hrp then
            local nearestPos = findNearestSafePos(hrp.Position)
            if nearestPos then
                char:PivotTo(CFrame.new(nearestPos))
            end
        end
        
        -- Make visible to dogs
        char:SetAttribute("Invisible", nil)
        player:SetAttribute("HP", Constants.MaximumHP)
        player:SetAttribute("GameLost", false)
        player:SetAttribute("DogChasing", false)
        player:SetAttribute("DogChasingCount", 0)
        
        -- Restore transparency
        for _, part in ipairs(char:GetDescendants()) do
            if (part:IsA("BasePart") or part:IsA("Decal") or part:IsA("Texture")) and part.Name ~= "HumanoidRootPart" then
                part.Transparency = 0
            end
        end
        
        -- 5 second invulnerability window
        task.delay(5, function()
            if char then char:SetAttribute("Immune", nil) end
        end)
        
        -- Tell client to hide death screen
        revivePlayerRemote:FireClient(player)
        
        local ff = Instance.new("ForceField")
        ff.Parent = char
        task.delay(5, function()
            if ff then ff:Destroy() end
        end)
    end
end

local function grantTrollEffect(player)
    -- Global state
    workspace:SetAttribute("TrollEffectActive", true)
    
    -- Buyer Invulnerability + ForceField
    if player.Character then
        player.Character:SetAttribute("Immune", true)
        player.Character:SetAttribute("IsTrollInvulnerable", true)
        player.Character:SetAttribute("Invisible", true) -- Invisible to dogs
        
        local ff = Instance.new("ForceField")
        ff.Parent = player.Character
        
        task.delay(30, function()
            if ff then ff:Destroy() end
            if player.Character then
                player.Character:SetAttribute("Immune", nil)
                player.Character:SetAttribute("IsTrollInvulnerable", nil)
                player.Character:SetAttribute("Invisible", nil)
            end
        end)
    end
    
    task.delay(30, function()
        workspace:SetAttribute("TrollEffectActive", false)
    end)
    
    -- Tell clients (for UI announcement)
    local trollRemoteEvent = remotesFolder:FindFirstChild("TrollEffectStarted")
    if trollRemoteEvent then
        trollRemoteEvent:FireAllClients(player.Name, 30)
    end
end

local freePurchaseRemote = remotesFolder:FindFirstChild("FreePurchaseRequested")
if not freePurchaseRemote then
    freePurchaseRemote = Instance.new("RemoteEvent")
    freePurchaseRemote.Name = "FreePurchaseRequested"
    freePurchaseRemote.Parent = remotesFolder
end

freePurchaseRemote.OnServerEvent:Connect(function(player, productId)
    if Constants.FreePurchaseWhitelist and table.find(Constants.FreePurchaseWhitelist, player.Name) then
        if productId == Constants.ReviveProductId then
            grantRevive(player)
        elseif productId == Constants.TrollEveryoneProductId then
            grantTrollEffect(player)
        end
    end
end)

MarketplaceService.ProcessReceipt = function(receiptInfo)
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then
        -- Player might have left the game
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    
    if receiptInfo.ProductId == Constants.ReviveProductId then
        grantRevive(player)
        return Enum.ProductPurchaseDecision.PurchaseGranted
    elseif receiptInfo.ProductId == Constants.TrollEveryoneProductId then
        grantTrollEffect(player)
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end
    
    return Enum.ProductPurchaseDecision.NotProcessedYet
end
