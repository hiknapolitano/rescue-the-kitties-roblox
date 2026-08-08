local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Cache for dog data
local activeDogs = {}

local function processDog(dogModel)
    if not dogModel:FindFirstChild("HumanoidRootPart") or not dogModel:FindFirstChild("Dog") then return end
    local rootPart = dogModel.HumanoidRootPart
    local customDog = dogModel.Dog
    
    local rootMotor = rootPart:FindFirstChild("VisualRootMotor")
    if not rootMotor then return end
    
    local originalRootC0 = rootMotor.C0
    local animParts = {}
    
    for _, m in ipairs(customDog:GetDescendants()) do
        if m:IsA("Motor6D") and m.Name ~= "VisualRootMotor" then
            local n = string.lower(m.Part1.Name)
            local isLeft = string.find(n, "left") ~= nil
            local isRight = string.find(n, "right") ~= nil
            
            if not isLeft and not isRight then
                if m.C0.X < -0.1 then isLeft = true
                elseif m.C0.X > 0.1 then isRight = true end
            end
            
            local boneLevel = m:GetAttribute("BoneLevel")
            local qName = m:GetAttribute("Quadrant")
            local isFront = m.C0.Z < 0
            
            if qName then
                isFront = string.find(qName, "Front") ~= nil
                isLeft = string.find(qName, "Left") ~= nil
            end
            
            table.insert(animParts, {
                motor = m,
                originalC0 = m.C0,
                isLeft = isLeft,
                isFront = isFront,
                boneLevel = boneLevel,
                isEar = string.find(n, "ear"),
                isTail = string.find(n, "tail"),
                isHead = string.find(n, "head") or string.find(n, "snout") or string.find(n, "nose")
            })
        end
    end
    
    activeDogs[dogModel] = {
        rootPart = rootPart,
        humanoid = dogModel:FindFirstChild("Humanoid"),
        rootMotor = rootMotor,
        originalRootC0 = originalRootC0,
        animParts = animParts,
        animTime = 0
    }
end

workspace.ChildAdded:Connect(function(child)
    if child.Name == "ChaserDog" then
        task.spawn(function()
            local rootPart = child:WaitForChild("HumanoidRootPart", 30)
            local dog = child:WaitForChild("Dog", 30)
            if rootPart and dog then
                rootPart:WaitForChild("VisualRootMotor", 15)
                task.wait(1) -- Give Motor6Ds more time to replicate over the real network
                processDog(child)
            end
        end)
    end
end)

workspace.ChildRemoved:Connect(function(child)
    if activeDogs[child] then
        activeDogs[child] = nil
    end
end)

-- Process existing dogs with the same wait logic as ChildAdded.
-- Dogs already in workspace when the client loads ALSO need time
-- for their Motor6Ds to replicate from the server -- don't skip the wait!
for _, child in ipairs(workspace:GetChildren()) do
    if child.Name == "ChaserDog" then
        task.spawn(function()
            local rootPart = child:WaitForChild("HumanoidRootPart", 30)
            local dog = child:WaitForChild("Dog", 30)
            if rootPart and dog then
                rootPart:WaitForChild("VisualRootMotor", 15)
                task.wait(1) -- Give Motor6Ds extra time on real network
                processDog(child)
            end
        end)
    end
end

local DOG_ANIM_RANGE_SQ = 100 * 100 -- 100 studs squared

-- Cache player references outside the loop
local localPlayer = Players.LocalPlayer
local cachedLocalChar = nil
local cachedLocalHrp = nil

local function refreshDogAnimCache()
    cachedLocalChar = localPlayer.Character
    cachedLocalHrp = cachedLocalChar and cachedLocalChar:FindFirstChild("HumanoidRootPart")
end

localPlayer.CharacterAdded:Connect(function(char)
    cachedLocalChar = char
    cachedLocalHrp = nil
    char:WaitForChild("HumanoidRootPart", 10)
    cachedLocalHrp = char:FindFirstChild("HumanoidRootPart")
end)
refreshDogAnimCache()

RunService.Heartbeat:Connect(function(deltaTime)
    local t = os.clock()
    
    local playerPos = cachedLocalHrp and cachedLocalHrp.Position
    
    for dogModel, data in pairs(activeDogs) do
        if not dogModel.Parent or not data.rootPart.Parent then
            activeDogs[dogModel] = nil
            continue
        end
        -- Keep animating dogs at any distance to prevent ugly static floating when far but visible
        
        local speed = data.rootPart.AssemblyLinearVelocity.Magnitude
        local isMoving = speed > 0.5 or (data.humanoid and data.humanoid.MoveDirection.Magnitude > 0)
        
        -- Animation speed perfectly matches the physical movement speed!
        local speedMult = isMoving and math.clamp(speed, 5, 30) or 0
        
        -- Accumulate time cleanly so changing speeds doesn't cause a violent time-jump!
        data.animTime = data.animTime + (deltaTime * (isMoving and speedMult or 5) * 0.7)
        local animTime = data.animTime
        
        -- Optimization: Pre-calculate expensive trig functions once per dog per frame
        local sinAnim = math.sin(animTime)
        local cosAnim = math.cos(animTime)
        local sinAnim2 = math.sin(animTime * 2)
        local sinIdle = math.sin(t * 2)
        local sinLook = math.sin(t)
        
        -- Body Bob/Sway
        if isMoving then
            local bob = math.abs(sinAnim) * 0.3
            local sway = cosAnim * 0.03
            data.rootMotor.C0 = data.originalRootC0 * CFrame.new(0, bob, 0) * CFrame.Angles(0, 0, sway)
        else
            -- Organic breathing bob + chest expand tilt (Y bob and Z pitch tilt)
            local breatheBob = math.sin(t * 2.5) * 0.05
            local breatheTilt = math.sin(t * 2.5) * 0.02
            data.rootMotor.C0 = data.originalRootC0 * CFrame.new(0, breatheBob, 0) * CFrame.Angles(breatheTilt, 0, 0)
        end
        
        -- Individual Parts
        for _, p in ipairs(data.animParts) do
            if p.boneLevel == 1 then -- Shoulder / Hind
                if isMoving then
                    -- math.sin(x + pi) is just -math.sin(x)!
                    local angle = (p.isLeft == p.isFront) and (sinAnim * 0.5) or (-sinAnim * 0.5)
                    p.motor.C0 = p.originalC0 * CFrame.Angles(angle, 0, 0)
                else
                    p.motor.C0 = p.motor.C0:Lerp(p.originalC0, 0.1)
                end
            elseif p.boneLevel == 2 then -- Leg / Thigh (Knee)
                if isMoving then
                    local offset = (p.isLeft == p.isFront) and 0 or math.pi
                    local bend = math.max(0, math.sin(animTime + offset - 1.0)) * 0.4
                    p.motor.C0 = p.originalC0 * CFrame.Angles(-bend, 0, 0)
                else
                    p.motor.C0 = p.motor.C0:Lerp(p.originalC0, 0.1)
                end
            elseif p.boneLevel == 3 then -- Paw (Ankle)
                if isMoving then
                    local offset = (p.isLeft == p.isFront) and 0 or math.pi
                    local angle = math.sin(animTime + offset - 1.5) * 0.2
                    p.motor.C0 = p.originalC0 * CFrame.Angles(-angle, 0, 0)
                else
                    p.motor.C0 = p.motor.C0:Lerp(p.originalC0, 0.1)
                end
            elseif p.isTail then
                local wagSpeed = isMoving and 15 or 5
                local wagAngle = math.sin(t * wagSpeed) * 0.4
                p.motor.C0 = p.originalC0 * CFrame.Angles(0, wagAngle, 0)
            elseif p.isEar then
                if isMoving then
                    local flop = math.abs(sinAnim2) * 0.3
                    local dir = p.isLeft and 1 or -1
                    p.motor.C0 = p.originalC0 * CFrame.Angles(0, 0, flop * dir)
                else
                    p.motor.C0 = p.motor.C0:Lerp(p.originalC0, 0.1)
                end
            elseif p.isHead then
                if isMoving then
                    p.motor.C0 = p.originalC0 * CFrame.Angles(sinAnim * 0.1, 0, 0)
                else
                    -- Breathing head tilt (X rotation) + horizontal look around (Y rotation)
                    local breatheHeadTilt = math.sin(t * 2.5) * 0.04
                    p.motor.C0 = p.motor.C0:Lerp(p.originalC0 * CFrame.Angles(breatheHeadTilt, sinLook * 0.15, 0), 0.1)
                end
            end
        end
    end
end)

