local p = Instance.new("Part")
local c = Instance.new("Part")
c.Parent = p
c.Position = Vector3.new(0, 10, 0)
local w = Instance.new("WeldConstraint")
w.Part0 = p
w.Part1 = c
w.Parent = p
p:PivotTo(CFrame.new(100, 0, 0))
print("Child pos after PivotTo:", c.Position)
p.CFrame = CFrame.new(200, 0, 0)
print("Child pos after CFrame:", c.Position)
