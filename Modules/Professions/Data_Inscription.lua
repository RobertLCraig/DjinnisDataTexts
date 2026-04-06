-- Djinni's Data Texts — Professions: Inscription (Midnight)
local _, ns = ...
ns.ProfessionData = ns.ProfessionData or {}

ns.ProfessionData.inscription = {
    kpSources = {
        uniqueTreasures = {
            { questID = 89073, itemID = 238578, name = "Songwriter's Pen", kp = 3,
              waypoint = { map = 2393, x = 0.4759, y = 0.5041 }, vignetteID = 6870 },
            { questID = 89074, itemID = 238579, name = "Songwriter's Quill", kp = 3,
              waypoint = { map = 2395, x = 0.4035, y = 0.6124 }, vignetteID = 6869 },
            { questID = 89069, itemID = 238574, name = "Spare Ink", kp = 3,
              waypoint = { map = 2395, x = 0.4831, y = 0.7554 }, vignetteID = 6814 },
            { questID = 89072, itemID = 238577, name = "Half-Baked Techniques", kp = 3,
              waypoint = { map = 2395, x = 0.3930, y = 0.4543 }, vignetteID = 6871 },
            { questID = 89068, itemID = 238573, name = "Leather-Bound Techniques", kp = 3,
              waypoint = { map = 2437, x = 0.4048, y = 0.4935 }, vignetteID = 6815 },
            { questID = 89070, itemID = 238575, name = "Intrepid Explorer's Marker", kp = 3,
              waypoint = { map = 2413, x = 0.5243, y = 0.5261 }, vignetteID = 6813 },
            { questID = 89071, itemID = 238576, name = "Leftover Sanguithorn Pigment", kp = 3,
              waypoint = { map = 2413, x = 0.5275, y = 0.4998 }, vignetteID = 6872 },
            { questID = 89067, itemID = 238572, name = "Void-Touched Quill", kp = 3,
              waypoint = { map = 2444, x = 0.6069, y = 0.8426 }, vignetteID = 6816 },
        },
        uniqueBooks = {
            { questID = 93412, itemID = 258411, name = "Traditions of the Haranir: Inscription", kp = 10,
              waypoint = { map = 2413, x = 0.510, y = 0.508 },
              requires = { renown = { factionID = 2704, level = 6 },
                           currency = { { id = 3261, amount = 75 }, { id = 3316, amount = 750 } } } },
        },
        weeklies = {
            { key = "trainer",   label = "Trainer Quest",       questIDs = { 93693 },           kp = 4 },
            { key = "drop",      label = "Weekly Treasures",    questIDs = { 93536, 93537 },    kp = 2, mode = "each" },
            { key = "treatise",  label = "Treatise",            questIDs = { 95131 },            kp = 1 },
            { key = "dmf",       label = "Darkmoon Faire",      questIDs = { 29515 },            kp = 3, dmf = true },
        },
        weeklyItem = { questID = 93693, itemID = 263457, name = "Thalassian Scribe's Journal", kp = 4,
                       waypoint = { map = 2393, x = 0.4503, y = 0.5515 } },
        catchup = { currencyID = 3195 },
    },
    buffCategory = "crafting",
}
