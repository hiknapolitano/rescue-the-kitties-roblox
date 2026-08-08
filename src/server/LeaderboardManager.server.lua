local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local WeeklyStore = DataStoreService:GetOrderedDataStore("WeeklyScore_v1")
local AllTimeStore = DataStoreService:GetOrderedDataStore("TotalWins_v1")
local PlayTimeStore = DataStoreService:GetOrderedDataStore("PlayTime_v1")

local function getLeaderboardBoard(name)
    for _, obj in ipairs(workspace:GetDescendants()) do
        if string.lower(obj.Name) == string.lower(name) and (obj:IsA("Model") or obj:IsA("BasePart")) then
            return obj
        end
    end
    return nil
end

local function setupBoardGUI(board)
    local existingGui = board:FindFirstChildWhichIsA("SurfaceGui", true)
    local targetFace = existingGui and existingGui.Face or Enum.NormalId.Front
    local mainPart = existingGui and existingGui.Parent or board
    
    if existingGui then
        local canvas = existingGui:FindFirstChild("Canvas")
        if canvas then
            local header = canvas:FindFirstChild("Header")
            local titleLabel = header and header:FindFirstChild("TitleLabel")
            local rowsContainer = canvas:FindFirstChild("RowsContainer")
            if titleLabel and rowsContainer then
                return {
                    TitleLabel = titleLabel,
                    RowsContainer = rowsContainer
                }
            end
        end
        existingGui:Destroy() -- Recreate if malformed
    end

    if mainPart:IsA("Model") then
        mainPart = mainPart.PrimaryPart
        if not mainPart then
            for _, child in ipairs(board:GetDescendants()) do
                if child:IsA("BasePart") and (child.Name == "Board" or child.Name == "Display" or child.Name == "Screen" or child.Name == "Main") then
                    mainPart = child
                    break
                end
            end
        end
        if not mainPart then
            mainPart = board:FindFirstChildWhichIsA("BasePart")
        end
        if not mainPart then
            mainPart = board:FindFirstChildWhichIsA("BasePart", true)
        end
    end
    if not mainPart or not mainPart:IsA("BasePart") then 
        warn("Leaderboard board " .. board.Name .. " has no physical part to host SurfaceGui")
        return nil 
    end

    local lbConfig = Constants.Leaderboard or {
        TitleTextSize = 32,
        RankTextSize = 24,
        NameTextSize = 22,
        ValueTextSize = 22,
        RowHeight = 35,
        RowPadding = 4
    }
    
    local headerHeight = lbConfig.TitleTextSize + 38
    local containerHeightOffset = -(headerHeight + 40)
    local containerPositionY = headerHeight + 20

    local gui = Instance.new("SurfaceGui")
    gui.Name = "LeaderboardGui"
    gui.Face = targetFace
    gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    gui.CanvasSize = Vector2.new(1200, 1600)
    gui.Parent = mainPart

    local canvas = Instance.new("Frame")
    canvas.Name = "Canvas"
    canvas.Size = UDim2.new(1, 0, 1, 0)
    canvas.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
    canvas.BorderSizePixel = 0
    canvas.Parent = gui

    local borderStroke = Instance.new("UIStroke")
    borderStroke.Color = Color3.fromRGB(60, 60, 75)
    borderStroke.Thickness = 4
    borderStroke.Parent = canvas

    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, headerHeight)
    header.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    header.BorderSizePixel = 0
    header.Parent = canvas

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(1, 0, 1, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    titleLabel.Font = Enum.Font.FredokaOne
    titleLabel.TextSize = lbConfig.TitleTextSize
    titleLabel.TextXAlignment = Enum.TextXAlignment.Center
    titleLabel.TextYAlignment = Enum.TextYAlignment.Center
    titleLabel.Parent = header

    local headerStroke = Instance.new("Frame")
    headerStroke.Size = UDim2.new(1, 0, 0, 3)
    headerStroke.Position = UDim2.new(0, 0, 1, -3)
    headerStroke.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
    headerStroke.BorderSizePixel = 0
    headerStroke.Parent = header

    local rowsContainer = Instance.new("Frame")
    rowsContainer.Name = "RowsContainer"
    rowsContainer.Size = UDim2.new(1, -40, 1, containerHeightOffset)
    rowsContainer.Position = UDim2.new(0, 20, 0, containerPositionY)
    rowsContainer.BackgroundTransparency = 1
    rowsContainer.Parent = canvas

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, lbConfig.RowPadding)
    listLayout.Parent = rowsContainer

    return {
        TitleLabel = titleLabel,
        RowsContainer = rowsContainer
    }
end

local function updateLeaderboardDisplay(boardName, dataStore, title, isTime)
    local board = getLeaderboardBoard(boardName)
    if not board then return end
    
    local references = setupBoardGUI(board)
    if not references then return end
    
    references.TitleLabel.Text = title
    
    -- Clear old rows
    for _, child in ipairs(references.RowsContainer:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    local success, pages = pcall(function()
        return dataStore:GetSortedAsync(false, 10)
    end)
    
    if not success or not pages then
        local errorLabel = Instance.new("TextLabel")
        errorLabel.Size = UDim2.new(1, 0, 1, 0)
        errorLabel.BackgroundTransparency = 1
        errorLabel.Text = "Failed to load data..."
        errorLabel.TextColor3 = Color3.fromRGB(231, 76, 60)
        errorLabel.Font = Enum.Font.FredokaOne
        errorLabel.TextSize = 24
        errorLabel.Parent = references.RowsContainer
        return
    end
    
    local data = pages:GetCurrentPage()
    
    for rank, entry in ipairs(data) do
        local name = "Unknown"
        pcall(function()
            name = Players:GetNameFromUserIdAsync(tonumber(entry.key) or entry.key)
        end)
        
        local val = entry.value
        local valueText = ""
        if isTime then
            local mins = math.floor(val / 60)
            local hrs = math.floor(mins / 60)
            mins = mins % 60
            valueText = hrs .. "h " .. mins .. "m"
        else
            valueText = val .. (title == "TOTAL WINS" and " Wins" or " ★")
        end
        
        local lbConfig = Constants.Leaderboard or {
            TitleTextSize = 32,
            RankTextSize = 24,
            NameTextSize = 22,
            ValueTextSize = 22,
            RowHeight = 35,
            RowPadding = 4
        }
        local rowHeight = lbConfig.RowHeight or 35
        
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, rowHeight)
        row.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
        row.BorderSizePixel = 0
        row.LayoutOrder = rank
        
        local rowCorner = Instance.new("UICorner")
        rowCorner.CornerRadius = UDim.new(0, 6)
        rowCorner.Parent = row
        
        -- Highlighting top 3
        if rank == 1 then
            row.BackgroundColor3 = Color3.fromRGB(50, 45, 30)
            local stroke = Instance.new("UIStroke")
            stroke.Color = Color3.fromRGB(255, 215, 0)
            stroke.Thickness = 1.5
            stroke.Parent = row
        elseif rank == 2 then
            row.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
            local stroke = Instance.new("UIStroke")
            stroke.Color = Color3.fromRGB(200, 200, 200)
            stroke.Thickness = 1.5
            stroke.Parent = row
        elseif rank == 3 then
            row.BackgroundColor3 = Color3.fromRGB(42, 35, 30)
            local stroke = Instance.new("UIStroke")
            stroke.Color = Color3.fromRGB(205, 127, 50)
            stroke.Thickness = 1.5
            stroke.Parent = row
        end
        
        -- Rank Label
        local rankLabel = Instance.new("TextLabel")
        rankLabel.Size = UDim2.new(0, 150, 1, 0)
        rankLabel.Position = UDim2.new(0, 20, 0, 0)
        rankLabel.BackgroundTransparency = 1
        
        local suffix = "th"
        if rank == 1 then suffix = "st"
        elseif rank == 2 then suffix = "nd"
        elseif rank == 3 then suffix = "rd"
        end
        rankLabel.Text = rank .. suffix
        
        if rank == 1 then
            rankLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
            rankLabel.Font = Enum.Font.FredokaOne
        elseif rank == 2 then
            rankLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            rankLabel.Font = Enum.Font.FredokaOne
        elseif rank == 3 then
            rankLabel.TextColor3 = Color3.fromRGB(205, 127, 50)
            rankLabel.Font = Enum.Font.FredokaOne
        else
            rankLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
            rankLabel.Font = Enum.Font.GothamBold
        end
        rankLabel.TextSize = lbConfig.RankTextSize
        rankLabel.TextXAlignment = Enum.TextXAlignment.Left
        rankLabel.Parent = row
        
        -- Get Avatar image for top 3
        local avatarImage = nil
        if rank <= 3 then
            pcall(function()
                local content, isReady = Players:GetUserThumbnailAsync(tonumber(entry.key) or entry.key, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
                avatarImage = content
            end)
        end
        
        local nameXPosition = 180
        if avatarImage then
            local avatarSize = rowHeight - 20
            local avatarImgLabel = Instance.new("ImageLabel")
            avatarImgLabel.Name = "AvatarImage"
            avatarImgLabel.Size = UDim2.new(0, avatarSize, 0, avatarSize)
            avatarImgLabel.Position = UDim2.new(0, 180, 0, 10)
            avatarImgLabel.Image = avatarImage
            avatarImgLabel.BackgroundTransparency = 1
            avatarImgLabel.BorderSizePixel = 0
            
            local imgCorner = Instance.new("UICorner")
            imgCorner.CornerRadius = UDim.new(0, 12)
            imgCorner.Parent = avatarImgLabel
            
            avatarImgLabel.Parent = row
            nameXPosition = 180 + avatarSize + 20
        end
        
        -- Name Label
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(0.5, -80, 1, 0)
        nameLabel.Position = UDim2.new(0, nameXPosition, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = name
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.Font = Enum.Font.GothamSemibold
        nameLabel.TextSize = lbConfig.NameTextSize
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = row
        
        -- Value Label
        local valueLabel = Instance.new("TextLabel")
        valueLabel.AnchorPoint = Vector2.new(1, 0)
        valueLabel.Size = UDim2.new(0.3, 0, 1, 0)
        valueLabel.Position = UDim2.new(1, -20, 0, 0)
        valueLabel.BackgroundTransparency = 1
        valueLabel.Text = valueText
        
        if rank == 1 then
            valueLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
        elseif rank == 2 then
            valueLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        elseif rank == 3 then
            valueLabel.TextColor3 = Color3.fromRGB(205, 127, 50)
        else
            valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
        
        valueLabel.Font = Enum.Font.FredokaOne
        valueLabel.TextSize = lbConfig.ValueTextSize
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right
        valueLabel.Parent = row
        
        row.Parent = references.RowsContainer
    end
    
    if #data == 0 then
        local emptyLabel = Instance.new("TextLabel")
        emptyLabel.Size = UDim2.new(1, 0, 1, 0)
        emptyLabel.BackgroundTransparency = 1
        emptyLabel.Text = "No scores yet!"
        emptyLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
        emptyLabel.Font = Enum.Font.FredokaOne
        emptyLabel.TextSize = 20
        emptyLabel.Parent = references.RowsContainer
    end
end

local function spawnLeaderboards()
    local baseFolder = workspace:FindFirstChild("Base")
    if not baseFolder then return end

    -- Only keep leaderboardAllTime (tracks amount of wins) centered on base wall
    local boards = {
        {Name = "leaderboardAllTime", Color = Color3.fromRGB(0, 150, 200)}
    }

    for _, b in ipairs(boards) do
        if not getLeaderboardBoard(b.Name) then
            local p = Instance.new("Part")
            p.Name = b.Name
            p.Size = Vector3.new(12, 10, 1)
            p.Position = Vector3.new(0, 6, 25) -- Centered nicely
            p.Anchored = true
            p.Color = b.Color
            p.Material = Enum.Material.SmoothPlastic
            p.Parent = baseFolder
        end
    end
end

local function refreshAllLeaderboards()
    spawnLeaderboards()
    updateLeaderboardDisplay("leaderboardAllTime", AllTimeStore, "TOTAL WINS", false)
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
