local Constants = {
    ActiveLevel = "complexMap", -- Switch to "complexMap" to use the new map with keys and doors or oldLevel to use old one
    
    -- Maze Configuration
    CellSize = 10,
    WallHeight = 40,
    MazeOffset = Vector3.new(2000, 0, 2000), -- Offset the entire maze to avoid the 0,0,0 white light bug

    
    -- Wall Architecture Settings
    WallBaseHeight = 4,
    WallTopHeight = 4,
    WallBaseOversize = 2, -- Adds extra thickness to the base
    WallTopOversize = 2,  -- Adds extra thickness to the top
    WallCornerRoundness = 1, -- 1.0 for rounded corners (Cylinder), 0.0 for sharp square corners (Block)
    
    -- Custom Props Spawning Amounts
    AmountSpawnedPlants = 60,
    AmountSpawnedMushrooms = 0,
    AmountSpawnedDogHouses = 3,
    AmountSpawnedFireTrees = 8,
    
    WallBaseColor = Color3.fromRGB(50, 50, 50),
    WallBaseMaterial = Enum.Material.Cobblestone,
    WallMiddleColor = Color3.fromRGB(44, 101, 29),
    WallMiddleMaterial = Enum.Material.LeafyGrass,
    
    -- Dynamic Inner Wall Biome Colors
    WallColorA = Color3.fromRGB(15, 35, 15), -- Dark spooky forest
    WallColorB = Color3.fromRGB(45, 50, 25), -- Dead yellow-green
    WallColorC = Color3.fromRGB(35, 55, 20), -- Saturated Mossy Green
    WallColorD = Color3.fromRGB(40, 40, 40), -- Ashen/Charred Grey
    
    WallTopColor = Color3.fromRGB(50, 50, 50),
    WallTopMaterial = Enum.Material.Cobblestone,
    
    WallThickness = 2,
    
    -- Wall Texture Assets (PBR/HD Seamless Tiling)
    WallBaseTextureId = "rbxassetid://4954759675",   -- HD Seamless Tiling Rock/Stone
    WallMiddleTextureId = "rbxassetid://4954635422", -- HD Seamless Tiling Grass/Leaves
    WallTopTextureId = "rbxassetid://4954759675",    -- HD Seamless Tiling Rock/Stone
    
    -- Wall Texture Tiling Scale (smaller = more repeats, sharper detail, smaller tiles)
    WallBaseTextureScale = 3,   -- 4 studs per tile
    WallMiddleTextureScale = 1, -- 5 studs per tile
    WallTopTextureScale = 3,    -- 4 studs per tile
    
    -- Camera FOV Settings
    BaseFOV = 70,
    SprintFOV = 82,
    BoostFOV = 95,
    
    -- Screen Blur Settings (Sprinting & Boosting)
    SprintBlurSize = 1.5, -- Subtle blur size
    BoostBlurSize = 3.0,  -- Subtle boost blur size
    
    -- Damage/Pain Effects Settings
    DamageBlurScale = 1.2,
    DamageBlurMin = 5.0,
    DamageBlurMax = 20.0,
    DamageBlurDecay = 10.0, -- units decayed per second
    
    DamageShakeScale = 0.02, -- Way more subtle shake factor
    DamageShakeMin = 0.1,    -- Subtle minimum shake
    DamageShakeMax = 0.7,    -- Subtle maximum shake cap
    DamageShakeDecay = 3.0,  -- Faster settle decay
    
    -- Ground Configuration
    GroundColorA = Color3.fromRGB(44, 30, 20), -- Dark Mud
    GroundColorB = Color3.fromRGB(60, 45, 30), -- Lighter Mud
    GroundColorC = Color3.fromRGB(30, 45, 20), -- Mossy Mud
    GroundColorD = Color3.fromRGB(20, 20, 20), -- Ashy/Burnt Ground
    GroundMaterial = Enum.Material.Ground,
    GroundTextureId = "",                      -- Leave empty to use default Roblox Material, or set custom texture ID
    GroundTextureScale = 1,                    -- studs per tile
    
    LavaBorderThickness = 1.5,
    LavaBorderColor = Color3.fromRGB(40, 40, 45),
    LavaBorderMaterial = Enum.Material.Slate,
    
    -- Entities (These are defaults, they get overridden at the bottom based on ActiveLevel)
    TotalCats = 13,
    MaleDamageSoundPitch = 0.75,
    TotalDogs = 4,
    
    -- Item Spawning
    NormalItemSpawnInterval = 15,
    MaxNormalItems = 15,
    
    BandageHealAmount = 50,
    MaximumHP = 100,
    SpikeDamage = 34,
    DogDamage = 34,
    LavaDamage = 50,
    
    StarTime5 = 500,
    StarTime4 = 650,
    StarTime3 = 750,
    StarTime2 = 850,
    
    -- Game logic
    GroupId = 738544426, -- Replace with your actual Roblox Group ID for the discount
    CatHoldDuration = 5,
    MaxCatHeadRotation = 45, -- Degrees
    
    ShopOwnerUsernames = {
        "saahunicorn4",
        "heylaurinha67",
        "beabadoobeelson",
        "Marianinha2684",
        "tobiasbiou",
        "Deusa_x00",
        "AnaEscuraa97",
    },

    
    DogChasingRange = 80,
    DogSpeed = 12, -- Default walk speed
    DogChaseSpeed = 24, -- Faster when chasing
    
    DogFootstepWalkPitch = 1.25,
    DogFootstepChasePitch = 1.7,
    
    -- Player Mechanics
    PlayerWalkSpeed = 22,
    PlayerRunSpeed = 30,
    StaminaMax = 100,
    StaminaDrainRate = 10, -- 6.6 seconds to drain from 100 to 0
    StaminaRecoverRate = 10, -- ~6.6 seconds to recover from 0 to 100
    
    FootstepBasePitch = 1.55,
    FootstepPitchShiftAmount = 0.55, -- How much the pitch increases when running vs walking
    
    -- Mud Particle Effects
    MudParticleSize = 0.8,
    MudParticleColor = Color3.fromRGB(60, 50, 30),
    
    FlashlightNormal = { Brightness = 2.5, Range = 55.0 },
    FlashlightUpgrade = { Brightness = 4.0, Range = 90.0 },
    
    -- Lighting Settings
    Ambient = Color3.fromRGB(84, 84, 84),
    OutdoorAmbient = Color3.fromRGB(20, 20, 40),
    Brightness = 1.2,
    FogColor = Color3.fromRGB(2, 2, 5),
    FogStart = 50,
    FogEnd = 300,
    ClockTime = 0, -- 0 = Midnight
    GlobalShadows = false,
    
    -- Dog Red Light Settings
    DogLightColor = Color3.fromRGB(255, 0, 40),
    DogLightBrightness = 1.7,
    DogLightRange = 45,
    
    -- Monetization
    ReviveProductId = 3611065335, -- TODO: Replace with your actual Developer Product ID from the Roblox website
    MinimapGamepassId = 1928238733, -- TODO: Replace
    FlashlightUpgradeGamepassId = 1927212787, -- TODO: Replace
    TrollEveryoneProductId = 3611537595, -- TODO: Replace
    TrollEveryoneIconId = "rbxassetid://96039066184791", -- TODO: Replace with image ID
    FreePurchaseWhitelist = {"beabadoobeelson"},
    
    -- Troll Button UI Configs
    TrollButtonConfig = {
        BaseSize = 73,
        HoverSize = 85,
        BobSpeed = 6,
        BobAmount = 0.03,
        TextColor = Color3.fromRGB(235, 235, 20),
        TextSize = 13, -- Text size for the label below the icon
        TextSpacing = 3, -- Spacing between the icon and the text
    },
    
    -- Camera Zoom Limits
    CameraMaxZoomDistance = 30, -- Max distance player can zoom out camera (prevents seeing over maze walls)
    CameraMinZoomDistance = 5,
    
    -- Minimap Settings
    MinimapSize = 160, -- Diameter in pixels (20% smaller than default 200)
    MinimapViewRadius = 100, -- Range of X studs from player shown on minimap (Maximum Zoom In)
    MinimapMaxViewRadius = 250, -- Maximum range of X studs (Minimum Zoom Out)
    
    -- Minimap Colors
    MinimapColors = {
        Wall = Color3.fromRGB(10, 60, 10),
        Lava = Color3.fromRGB(255, 100, 0),
        Spike = Color3.fromRGB(200, 200, 200),
        Floor = Color3.fromRGB(120, 120, 120),
        Player = Color3.fromRGB(255, 255, 255),
        Cat = Color3.fromRGB(255, 55, 120),
        Circle = Color3.fromRGB(255, 255, 255), -- White minimap border/circle
        OtherPlayer = Color3.fromRGB(0, 120, 255) -- Other players color indicator
    },
    
    -- Cats Config
    CatsConfig = {
        { color = Color3.fromRGB(255, 255, 255), rotationOffset = CFrame.Angles(0, 0, 0) }, -- 1: White
        { color = Color3.fromRGB(80, 90, 130), rotationOffset = CFrame.Angles(0, 0, 0) },    -- 2: Black
        { color = Color3.fromRGB(180, 150, 150), rotationOffset = CFrame.Angles(0, 0, 0) }, -- 3: Gray
        { color = Color3.fromRGB(139, 69, 19), rotationOffset = CFrame.Angles(0, 0, 0) },   -- 4: Brown
        { color = Color3.fromRGB(200, 150, 50), rotationOffset = CFrame.Angles(0, 0, 0) },  -- 5: Mustard
        { color = Color3.fromRGB(240, 200, 150), rotationOffset = CFrame.Angles(0, 0, 0) }, -- 6: Sand
        { color = Color3.fromRGB(255, 140, 40), rotationOffset = CFrame.Angles(0, 0, 0) },   -- 7: Orange
        { color = Color3.fromRGB(255, 228, 196), rotationOffset = CFrame.Angles(0, 0, 0) }, -- 8: Cream
        { color = Color3.fromRGB(169, 169, 169), rotationOffset = CFrame.Angles(0, 0, 0) }, -- 9: Dark Gray
        { color = Color3.fromRGB(205, 133, 63), rotationOffset = CFrame.Angles(0, 0, 0) },  -- 10: Golden
        { color = Color3.fromRGB(105, 105, 105), rotationOffset = CFrame.Angles(0, 0, 0) }, -- 11: Dim Gray
        { color = Color3.fromRGB(210, 180, 140), rotationOffset = CFrame.Angles(0, 0, 0) }, -- 12: Tan
        { color = Color3.fromRGB(255, 240, 240), rotationOffset = CFrame.Angles(0, 0, 0) }, -- 13: Snow White
    },
    
    -- Tags and Names
    CatTag = "CatCollectible",
    DogTag = "ChaserDog",
    TreeTag = "ClimbableTree",
    
    -- Sounds Configs
    Sounds = {
        CatSobbing = { 
            SoundId = "rbxassetid://112821945927470", 
            Volume = 1, 
            FadeInDuration = 0, 
            FadeOutDuration = 0.5, 
            Looped = false, 
            PlaybackSpeed = 1, 
            PlaybackStart = 0 
        },
        CatSobbing2 = { 
            SoundId = "rbxassetid://87316925221500", 
            Volume = 1, 
            FadeInDuration = 0, 
            FadeOutDuration = 0.5, 
            Looped = false, 
            PlaybackSpeed = 1, 
            PlaybackStart = 0 
        },
        BackgroundMusic = { 
            SoundId = "rbxassetid://91516606716178", 
            Volume = 0.5, 
            FadeInDuration = 2, 
            FadeOutDuration = 2, 
            Looped = true, 
            PlaybackSpeed = 1, 
            PlaybackStart = 0 
        },
        DogBark = { 
            SoundId = "rbxassetid://122241919149088", 
            Volume = 1, 
            FadeInDuration = 0, 
            FadeOutDuration = 0, 
            Looped = false, 
            PlaybackSpeed = 1, 
            PlaybackStart = 0 
        },
        DogChasing = { 
            SoundId = "rbxassetid://94720247592994", 
            Volume = 1, 
            FadeInDuration = 0, 
            FadeOutDuration = 1.5, 
            Looped = true, 
            PlaybackSpeed = 1, 
            PlaybackStart = 0 
        },
        DogFootsteps = {
            SoundId = "rbxasset://sounds/action_footsteps_plastic.mp3", 
            Volume = 0.65, 
            FadeInDuration = 0.1, 
            FadeOutDuration = 0.1, 
            Looped = true, 
            PlaybackSpeed = 1, 
            PlaybackStart = 0
        },
        CatMeow = { 
            SoundId = "rbxassetid://114185930887084", 
            Volume = 0.4, 
            FadeInDuration = 0, 
            FadeOutDuration = 0, 
            Looped = false, 
            PlaybackSpeed = 1, 
            PlaybackStart = 0 
        },
        CatMeow2 = { 
            SoundId = "rbxassetid://114185930887084", 
            Volume = 0.4, 
            FadeInDuration = 0, 
            FadeOutDuration = 0, 
            Looped = false, 
            PlaybackSpeed = 0.8, 
            PlaybackStart = 0 
        },
        GameOver = { 
            SoundId = "rbxassetid://102973330291670", 
            Volume = 1, 
            FadeInDuration = 0, 
            FadeOutDuration = 0, 
            Looped = false, 
            PlaybackSpeed = 1, 
            PlaybackStart = 0 
        },
        ShopBuy = { 
            SoundId = "rbxassetid://110945530950546", 
            Volume = 1, 
            FadeInDuration = 0, 
            FadeOutDuration = 0, 
            Looped = false, 
            PlaybackSpeed = 1, 
            PlaybackStart = 0 
        },
        GameWin = { 
            SoundId = "rbxassetid://75023999600828", 
            Volume = 1, 
            FadeInDuration = 0, 
            FadeOutDuration = 0, 
            Looped = false, 
            PlaybackSpeed = 1, 
            PlaybackStart = 0 
        },
        BoneThrow = { 
            SoundId = "rbxassetid://105200330365760", 
            Volume = 1, 
            FadeInDuration = 0, 
            FadeOutDuration = 0, 
            Looped = false, 
            PlaybackSpeed = 1, 
            PlaybackStart = 0 
        },
        ShieldBreak = { 
            SoundId = "rbxassetid://95966123660528", 
            Volume = 1, 
            FadeInDuration = 0, 
            FadeOutDuration = 0, 
            Looped = false, 
            PlaybackSpeed = 1, 
            PlaybackStart = 0 
        },
        EnergyDrinkUse = { 
            SoundId = "rbxassetid://129244490780548", 
            Volume = 0.4, 
            FadeInDuration = 0, 
            FadeOutDuration = 0, 
            Looped = false, 
            PlaybackSpeed = 1.25, 
            PlaybackStart = 0 
        },
        ItemPickup = { 
            SoundId = "rbxassetid://110945530950546", -- Reusing ShopBuy sound with different pitch
            Volume = 1, 
            FadeInDuration = 0, 
            FadeOutDuration = 0, 
            Looped = false, 
            PlaybackSpeed = 1.5, 
            PlaybackStart = 0 
        },
        BandageUse = { 
            SoundId = "rbxassetid://129244490780548", -- Reusing EnergyDrinkUse sound with different pitch
            Volume = 1, 
            FadeInDuration = 0, 
            FadeOutDuration = 0, 
            Looped = false, 
            PlaybackSpeed = 0.8, 
            PlaybackStart = 0 
        },
        InvisibilityUse = { 
            SoundId = "rbxassetid://101435914094943", 
            Volume = 1, 
            FadeInDuration = 0, 
            FadeOutDuration = 0, 
            Looped = false, 
            PlaybackSpeed = 1, 
            PlaybackStart = 0 
        },
        StaminaDrain = { 
            SoundId = "rbxassetid://104660182564308", 
            Volume = 0.7, 
            FadeInDuration = 2.5, 
            FadeOutDuration = 1.0, 
            Looped = true, 
            PlaybackSpeed = 1, 
            PlaybackStart = 1 
        },
        SlimeWalk = { 
            SoundId = "rbxassetid://115834020194402", 
            Volume = 1, 
            FadeInDuration = 0.2, 
            FadeOutDuration = 0.5, 
            Looped = true, 
            PlaybackSpeed = 1, 
            PlaybackStart = 0 
        },
        LastCat = { 
            SoundId = "rbxassetid://120008829878857", 
            Volume = 1, 
            FadeInDuration = 0, 
            FadeOutDuration = 0, 
            Looped = false, 
            PlaybackSpeed = 1, 
            PlaybackStart = 0 
        },
        CatRescueImpact = { 
            SoundId = "rbxassetid://106930820450624", -- Happy pop/impact
            Volume = 1, 
            FadeInDuration = 0, 
            FadeOutDuration = 0, 
            Looped = false, 
            PlaybackSpeed = 1, 
            PlaybackStart = 0 
        },
        PlayerDeathImpact = { 
            SoundId = "rbxassetid://85365625996232", -- Heavy thud/impact
            Volume = 1, 
            FadeInDuration = 0, 
            FadeOutDuration = 0, 
            Looped = false, 
            PlaybackSpeed = 1, 
            PlaybackStart = 0 
        },
        Damage = { 
            SoundId = "rbxassetid://88918244316285", 
            Volume = 0, 
            FadeInDuration = 0, 
            FadeOutDuration = 0, 
            Looped = false, 
            PlaybackSpeed = 1, 
            PlaybackStart = 0 
        },
        FlashlightOn = { 
            SoundId = "rbxassetid://73154005500609", 
            Volume = 0.6, 
            FadeInDuration = 0, 
            FadeOutDuration = 0, 
            Looped = false, 
            PlaybackSpeed = 1.15, 
            PlaybackStart = 0 
        },
        FlashlightOff = { 
            SoundId = "rbxassetid://73154005500609", 
            Volume = 0.4, 
            FadeInDuration = 0, 
            FadeOutDuration = 0, 
            Looped = false, 
            PlaybackSpeed = 1.05, 
            PlaybackStart = 0 
        },
    },

    ShopPrices = {
        Potion = 5,
        EnergyDrink = 5,
        Shield = 5,
        Bone = 5,
        FlashlightUpgrade = 10,
        Minimap = 18,
        Bandage = 7
    },

    DogPatrolRadius = 75,
    DogLostChaseSearchDuration = 4.0,

    Leaderboard = {
        TitleTextSize = 80,
        RankTextSize = 72,
        NameTextSize = 68,
        ValueTextSize = 68,
        RowHeight = 120,
        RowPadding = 12
    },

    Parkour = {
        BaseHeight = 4.5,
        YVariation = 1,
        XZVariation = 2,
        Scale = 0.335,
        SpikeYOffset = -8.0
    },

    Images = {
        LoadingBackground = "rbxassetid://81241056693528", -- Replace with rescueTheKittiesHd.png asset ID!
    }
}

-- Apply Level Configs
if Constants.ActiveLevel == "oldLevel" then
    Constants.TotalCats = 7
    Constants.TotalDogs = 3
    Constants.UseKeys = false
    Constants.UseSafeZone2 = false
else
    Constants.TotalCats = 13
    Constants.TotalDogs = 4
    Constants.UseKeys = true
    Constants.UseSafeZone2 = true
end

return Constants
