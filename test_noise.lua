local x = 1
local z = 1
local noiseScale = 0.08
local noiseVal = math.noise(x * noiseScale, z * noiseScale, 123.45)
local alpha = (math.clamp(noiseVal, -0.5, 0.5) + 0.5)
print("noiseVal:", noiseVal)
print("alpha:", alpha)
