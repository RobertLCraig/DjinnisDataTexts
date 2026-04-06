-- Djinni's Data Texts — Professions: Skinning (Midnight)
-- Includes Majestic Beast activity data (migrated from MajesticBeast.lua).
local _, ns = ...
ns.ProfessionData = ns.ProfessionData or {}

ns.ProfessionData.skinning = {
    kpSources = {
        uniqueTreasures = {
            { questID = 89171, itemID = 238633, name = "Sin'dorei Tanning Oil", kp = 3,
              waypoint = { map = 2393, x = 0.4313, y = 0.5562 }, vignetteID = 6787 },
            { questID = 89173, itemID = 238635, name = "Thalassian Skinning Knife", kp = 3,
              waypoint = { map = 2395, x = 0.4840, y = 0.7625 }, vignetteID = 6785 },
            { questID = 89170, itemID = 238632, name = "Amani Tanning Oil", kp = 3,
              waypoint = { map = 2437, x = 0.4039, y = 0.3601 }, vignetteID = 6788 },
            { questID = 89172, itemID = 238634, name = "Amani Skinning Knife", kp = 3,
              waypoint = { map = 2437, x = 0.3307, y = 0.7907 }, vignetteID = 6786 },
            { questID = 89167, itemID = 238629, name = "Cadre Skinning Knife", kp = 3,
              waypoint = { map = 2536, x = 0.4491, y = 0.4519 }, vignetteID = 6791 },
            { questID = 89166, itemID = 238628, name = "Lightbloom Afflicted Hide", kp = 3,
              waypoint = { map = 2413, x = 0.7609, y = 0.5108 }, vignetteID = 6792 },
            { questID = 89168, itemID = 238630, name = "Primal Hide", kp = 3,
              waypoint = { map = 2413, x = 0.6952, y = 0.4917 }, vignetteID = 6790 },
            { questID = 89169, itemID = 238631, name = "Voidstorm Leather Sample", kp = 3,
              waypoint = { map = 2444, x = 0.4550, y = 0.4240 }, vignetteID = 6789 },
        },
        uniqueBooks = {
            { questID = 92373, itemID = 250923, name = "Whisper of the Loa: Skinning", kp = 10,
              waypoint = { map = 2437, x = 0.458, y = 0.658 },
              requires = { renown = { factionID = 2696, level = 6 },
                           currency = { { id = 3265, amount = 75 }, { id = 3316, amount = 750 } } } },
            { questID = 92188, itemID = 250360, name = "Echo of Abundance: Skinning", kp = 10,
              waypoint = { map = 2437, x = 0.3156, y = 0.2626 },
              requires = { currency = { { id = 3377, amount = 1600 }, { id = 3265, amount = 75 } } } },
        },
        weeklies = {
            { key = "trainer",   label = "Trainer Quest",           questIDs = { 93710, 93711, 93712, 93713, 93714 }, kp = 3, mode = "rotation" },
            { key = "drop",      label = "Fine Void-Tempered Hide", questIDs = { 88534, 88549, 88536, 88537, 88530 }, kp = 1, mode = "each" },
            { key = "bonusDrop", label = "Mana-Infused Bone",       questIDs = { 88529 },                              kp = 3 },
            { key = "treatise",  label = "Treatise",                questIDs = { 95136 },                               kp = 1 },
            { key = "dmf",       label = "Darkmoon Faire",          questIDs = { 29519 },                               kp = 3, dmf = true },
        },
        catchup = { currencyID = 3191 },
    },

    ---------------------------------------------------------------------------
    -- Majestic Beast activity data
    ---------------------------------------------------------------------------
    activities = {
        majesticBeasts = {
            lures = {
                { name = "Eversong",    npcID = 245688, itemID = 238652, recipeID = 1225943, questID = 88545, requiredPoints = 1,
                  color = "|cff00ff96", colorRGB = { 0, 1, 0.59 },
                  waypoint = { map = 2395, x = 0.4195, y = 0.8005 },
                  reagents = { { itemID = 238371, count = 8 }, { itemID = 238366, count = 8 } } },
                { name = "Zul'Aman",    npcID = 245699, itemID = 238653, recipeID = 1225944, questID = 88526, requiredPoints = 10,
                  color = "|cff00ccff", colorRGB = { 0, 0.8, 1 },
                  waypoint = { map = 2437, x = 0.4769, y = 0.5325 },
                  reagents = { { itemID = 238382, count = 8 } } },
                { name = "Harandar",    npcID = 245690, itemID = 238654, recipeID = 1225945, questID = 88531, requiredPoints = 20,
                  color = "|cffff9900", colorRGB = { 1, 0.6, 0 },
                  waypoint = { map = 2413, x = 0.6628, y = 0.4791 },
                  reagents = { { itemID = 238375, count = 8 }, { itemID = 238374, count = 8 } } },
                { name = "Voidstorm",   npcID = 247096, itemID = 238655, recipeID = 1225946, questID = 88532, requiredPoints = 30,
                  color = "|cffa335ee", colorRGB = { 0.64, 0.21, 0.93 },
                  waypoint = { map = 2405, x = 0.5460, y = 0.6580 },
                  reagents = { { itemID = 238373, count = 4 } } },
                { name = "Grand Beast", npcID = 247101, itemID = 238656, recipeID = 1225948, questID = 88524, requiredPoints = 40,
                  color = "|cffff3333", colorRGB = { 1, 0.2, 0.2 },
                  waypoint = { map = 2405, x = 0.4325, y = 0.8275 },
                  reagents = { { itemID = 238380, count = 4 } } },
            },
            beastLoot = {
                Eversong    = { 238511, 238512, 238518, 238519, 238523, 238525, 238528, 238529 },
                ["Zul'Aman"]  = { 238513, 238514, 238520, 238521, 238528 },
                Harandar    = { 238513, 238514, 238520, 238521, 238530, 238522 },
                Voidstorm   = { 238511, 238512, 238518, 238519, 238528, 238529, 238525, 238523 },
                ["Grand Beast"] = { 238513, 238514, 238520, 238521, 238528, 238529, 238530, 238522 },
            },
            consumables = {
                { itemID = 242299, name = "Sanguithorn Tea",             buffName = "Relaxed" },
                { itemID = 241317, name = "Haranir Phial of Perception", buffName = "Haranir Phial of Perception" },
                { itemID = 238367, name = "Root Crab",                   buffName = "Midnight Perception" },
            },
            skillLine = 2917,
            spellID   = 471014,
        },
    },

    buffCategory = "gathering",
}
