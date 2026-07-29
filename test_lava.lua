local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lava = ReplicatedStorage.MazeElements.LavaObby
local bbox, size = lava:GetBoundingBox()
print("LavaObby Size:", size)
print("LavaObby BBox Pos:", bbox.Position)
print("LavaObby Pivot:", lava:GetPivot().Position)
if lava.PrimaryPart then print("PrimaryPart Pos:", lava.PrimaryPart.Position) end
