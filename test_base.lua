local function printBase()
    local base = game.Workspace:FindFirstChild("Base")
    if base then
        print("Base found:", base.ClassName, base.Size)
    else
        print("Base not found")
    end
end
