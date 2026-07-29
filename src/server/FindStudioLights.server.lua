-- Debug 0,0,0
task.wait(2)
print("=== SCANNING 0,0,0 ===")
local region = Region3.new(Vector3.new(-10, -10, -10), Vector3.new(10, 10, 10))
local parts = workspace:FindPartsInRegion3(region, nil, 1000)
for _, p in ipairs(parts) do
    print("At 0,0,0: ", p.Name, p.ClassName, "Color:", tostring(p.Color), "Material:", tostring(p.Material), "Parent:", p.Parent and p.Parent.Name or "nil", "Pos:", p.Position)
    if p:IsA("BasePart") and (p.Material == Enum.Material.Neon or p.Color == Color3.new(1,1,1)) then
        print("^^^ THIS MIGHT BE THE WHITE LIGHT ^^^")
        if p.Name == "Part" or p.Name == "WhiteLightTeleporter" then
            p:Destroy()
        end
    end
end
print("=== END SCAN ===")
