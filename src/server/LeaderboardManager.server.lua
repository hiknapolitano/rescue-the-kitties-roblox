local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local WeeklyStore = DataStoreService:GetOrderedDataStore("WeeklyScore_v1")
local AllTimeStore = DataStoreService:GetOrderedDataStore("TotalWins_v1")
local PlayTimeStore = DataStoreService:GetOrderedDataStore("PlayTime_v1")

local function getLeaderboardBoard(name)
    for _, obj in ipairs(workspace:GetDescendants()) do
        if string.lower(obj.Name) == string.lower(name) and (obj:IsA("Model") or obj:IsA("Part")) then
            return obj
        end
    end
    return nil
end

local function setupBoardGUI(board)
    -- Look for an existing SurfaceGui anywhere inside the board
    local gui = board:FindFirstChildWhichIsA("SurfaceGui", true)
    
    if gui then
        -- Find the TextLabel inside the GUI
        local label = gui:FindFirstChild("Display", true) or gui:FindFirstChildWhichIsA("TextLabel", true)
        if label then
            return label
        end
    end

    -- If no GUI or TextLabel was found, create one on the main part
    local mainPart = board
    if board:IsA("Model") then
        mainPart = board.PrimaryPart or board:FindFirstChildWhichIsA("BasePart")
    end
    
    if not mainPart then return nil end

    gui = Instance.new("SurfaceGui")
    gui.Name = "LeaderboardGui"
    gui.Face = Enum.NormalId.Front
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 50
    gui.Parent = mainPart
    
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    bg.Parent = gui
    
    local label = Instance.new("TextLabel")
    label.Name = "Display"
    label.Size = UDim2.new(1, -40, 1, -40)
    label.Position = UDim2.new(0, 20, 0, 20)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.TextSize = 100
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Parent = bg
    
    return label
end

local function updateLeaderboardDisplay(boardName, dataStore, title, isTime)
    local board = getLeaderboardBoard(boardName)
    if not board then return end
    
    local display = setupBoardGUI(board)
    if not display then return end
    
    local success, pages = pcall(function()
        return dataStore:GetSortedAsync(false, 10)
    end)
    
    if not success or not pages then
        display.Text = title .. "\n\nFailed to load data..."
        return
    end
    
    local data = pages:GetCurrentPage()
    local text = "<font color=\"#FFD700\">" .. title .. "</font>\n\n"
    display.RichText = true
    
    for rank, entry in ipairs(data) do
        local name = "Unknown"
        pcall(function()
            name = Players:GetNameFromUserIdAsync(entry.key)
        end)
        
        local val = entry.value
        if isTime then
            local mins = math.floor(val / 60)
            local hrs = math.floor(mins / 60)
            mins = mins % 60
            val = hrs .. "h " .. mins .. "m"
        else
            val = val .. " Wins"
        end
        
        text = text .. rank .. ". " .. name .. " - " .. val .. "\n"
    end
    
    if #data == 0 then
        text = text .. "No scores yet!"
    end
    
    display.Text = text
end

local function spawnLeaderboards()
    local baseFolder = workspace:FindFirstChild("Base")
    if not baseFolder then return end

    -- Position them along the wall in Safe Zone (around Z = 20)
    local boards = {
        {Name = "leaderboardWeekly", Color = Color3.fromRGB(200, 150, 0)},
        {Name = "leaderboardAllTime", Color = Color3.fromRGB(0, 150, 200)},
        {Name = "leaderboardPlayTime", Color = Color3.fromRGB(50, 200, 50)}
    }

    for i, b in ipairs(boards) do
        if not getLeaderboardBoard(b.Name) then
            local p = Instance.new("Part")
            p.Name = b.Name
            p.Size = Vector3.new(12, 10, 1)
            p.Position = Vector3.new((i - 2) * 15, 6, 25) -- Placed nicely spaced apart
            p.Anchored = true
            p.Color = b.Color
            p.Material = Enum.Material.SmoothPlastic
            p.Parent = baseFolder
        end
    end
end

local function refreshAllLeaderboards()
    spawnLeaderboards()
    updateLeaderboardDisplay("leaderboardWeekly", WeeklyStore, "WEEKLY BEST SCORES", false)
    updateLeaderboardDisplay("leaderboardAllTime", AllTimeStore, "TOTAL WINS", false)
    updateLeaderboardDisplay("leaderboardPlayTime", PlayTimeStore, "TOP PLAYTIME", true)
end

task.spawn(function()
    while true do
        refreshAllLeaderboards()
        task.wait(60)
    end
end)

local joinTimes = {}
Players.PlayerAdded:Connect(function(player)
    joinTimes[player.UserId] = os.time()
end)

Players.PlayerRemoving:Connect(function(player)
    local joinTime = joinTimes[player.UserId]
    if joinTime then
        local playedSeconds = os.time() - joinTime
        pcall(function()
            PlayTimeStore:UpdateAsync(player.UserId, function(oldValue)
                return (oldValue or 0) + playedSeconds
            end)
        end)
    end
    joinTimes[player.UserId] = nil
end)

local ServerStorage = game:GetService("ServerStorage")
local evt = ServerStorage:FindFirstChild("SaveWinScore")
if not evt then
    evt = Instance.new("BindableEvent")
    evt.Name = "SaveWinScore"
    evt.Parent = ServerStorage
end

evt.Event:Connect(function(player, score)
    pcall(function()
        AllTimeStore:IncrementAsync(player.UserId, 1)
        
        local currentWeekly = WeeklyStore:GetAsync(player.UserId)
        if not currentWeekly or score > currentWeekly then
            WeeklyStore:SetAsync(player.UserId, score)
        end
    end)
    -- Refresh immediately so they can see their score
    task.wait(2)
    refreshAllLeaderboards()
end)
