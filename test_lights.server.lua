for _, desc in ipairs(workspace:GetDescendants()) do
    if desc:IsA("Light") then
        local pos = "Unknown"
        if desc.Parent and desc.Parent:IsA("BasePart") then
            pos = tostring(desc.Parent.Position)
        end
        print("Found Light:", desc.Name, desc.ClassName, "in", desc.Parent.Name, "at", pos)
    end
end
