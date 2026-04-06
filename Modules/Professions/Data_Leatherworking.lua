-- Djinni's Data Texts — Professions: Leatherworking (Midnight)
local _, ns = ...
ns.ProfessionData = ns.ProfessionData or {}

ns.ProfessionData.leatherworking = {
    kpSources = {
        uniqueTreasures = {
            { questID = 89096, itemID = 238595, name = "Artisan's Considered Order", kp = 3,
              waypoint = { map = 2393, x = 0.4477, y = 0.5626 }, vignetteID = 6861 },
            { questID = 89089, itemID = 238588, name = "Amani Leatherworker's Tool", kp = 3,
              waypoint = { map = 2437, x = 0.3308, y = 0.7891 }, vignetteID = 6808 },
            { questID = 89091, itemID = 238590, name = "Prestigiously Racked Hide", kp = 3,
              waypoint = { map = 2437, x = 0.3075, y = 0.8398 }, vignetteID = 6806 },
            { questID = 89092, itemID = 238591, name = "Bundle of Tanner's Trinkets", kp = 3,
              waypoint = { map = 2536, x = 0.4530, y = 0.4559 }, vignetteID = 6805 },
            { questID = 89094, itemID = 238593, name = "Haranir Leatherworking Mallet", kp = 3,
              waypoint = { map = 2413, x = 0.5169, y = 0.5131 }, vignetteID = 6863 },
            { questID = 89095, itemID = 238594, name = "Haranir Leatherworking Knife", kp = 3,
              waypoint = { map = 2413, x = 0.3610, y = 0.2517 }, vignetteID = 6862 },
            { questID = 89090, itemID = 238589, name = "Ethereal Leatherworking Knife", kp = 3,
              waypoint = { map = 2405, x = 0.3471, y = 0.5692 }, vignetteID = 6807 },
            { questID = 89093, itemID = 238592, name = "Patterns: Beyond the Void", kp = 3,
              waypoint = { map = 2444, x = 0.5374, y = 0.5168 }, vignetteID = 6864 },
        },
        uniqueBooks = {
            { questID = 92371, itemID = 250922, name = "Whisper of the Loa: Leatherworking", kp = 10,
              waypoint = { map = 2437, x = 0.458, y = 0.658 },
              requires = { renown = { factionID = 2696, level = 6 },
                           currency = { { id = 3263, amount = 75 }, { id = 3316, amount = 750 } } } },
        },
        weeklies = {
            { key = "trainer",   label = "Trainer Quest",       questIDs = { 93695 },           kp = 2 },
            { key = "drop",      label = "Weekly Treasures",    questIDs = { 93540, 93541 },    kp = 2, mode = "each" },
            { key = "treatise",  label = "Treatise",            questIDs = { 95134 },            kp = 1 },
            { key = "dmf",       label = "Darkmoon Faire",      questIDs = { 29517 },            kp = 3, dmf = true },
        },
        weeklyItem = { questID = 93695, itemID = 263459, name = "Thalassian Leatherworker's Journal", kp = 2,
                       waypoint = { map = 2393, x = 0.4503, y = 0.5515 } },
        catchup = { currencyID = 3193 },
    },
    buffCategory = "crafting",
}
