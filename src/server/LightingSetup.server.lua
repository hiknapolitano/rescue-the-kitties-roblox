local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

Lighting.Ambient = Constants.Ambient
Lighting.OutdoorAmbient = Constants.OutdoorAmbient
Lighting.Brightness = Constants.Brightness
Lighting.ClockTime = Constants.ClockTime
Lighting.GlobalShadows = Constants.GlobalShadows

Lighting.FogColor = Constants.FogColor
Lighting.FogStart = Constants.FogStart
Lighting.FogEnd = Constants.FogEnd

print("Lighting overrides applied - Spooky Night Mode Active")

local PhysicsService = game:GetService("PhysicsService")

-- Create Collision Groups
pcall(function()
    PhysicsService:RegisterCollisionGroup("Dogs")
    PhysicsService:RegisterCollisionGroup("Trees")
    PhysicsService:RegisterCollisionGroup("Trusses")
    PhysicsService:RegisterCollisionGroup("WaterBarrier")
    PhysicsService:RegisterCollisionGroup("PlayerInBoat")
    
    -- Dogs do not collide with Trusses to prevent accidental climbing
    PhysicsService:CollisionGroupSetCollidable("Dogs", "Trusses", false)
    
    -- PlayerInBoat does NOT collide with WaterBarrier so they can pass through WaterTiles
    PhysicsService:CollisionGroupSetCollidable("PlayerInBoat", "WaterBarrier", false)
    
    PhysicsService:RegisterCollisionGroup("DogBarrier")
    PhysicsService:CollisionGroupSetCollidable("DogBarrier", "Default", false)
    PhysicsService:CollisionGroupSetCollidable("DogBarrier", "Dogs", true)
    PhysicsService:CollisionGroupSetCollidable("DogBarrier", "PlayerInBoat", false)
end)

-- Assign all TrussParts to the Trusses collision group
task.spawn(function()
    -- Wait a bit for the map to load
    task.wait(2)
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("TrussPart") then
            obj.CollisionGroup = "Trusses"
        end
    end
    
    workspace.DescendantAdded:Connect(function(obj)
        if obj:IsA("TrussPart") then
            obj.CollisionGroup = "Trusses"
        end
    end)
end)
