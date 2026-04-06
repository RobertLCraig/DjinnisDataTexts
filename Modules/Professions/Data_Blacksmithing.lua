-- Djinni's Data Texts — Professions: Blacksmithing (Midnight)
local _, ns = ...
ns.ProfessionData = ns.ProfessionData or {}

ns.ProfessionData.blacksmithing = {
    kpSources = {
        uniqueTreasures = {
            { questID = 89177, itemID = 238540, name = "Deconstructed Forge Techniques", kp = 3,
              waypoint = { map = 2393, x = 0.2697, y = 0.6029 }, vignetteID = 6840 },
            { questID = 89180, itemID = 238543, name = "Metalworking Cheat Sheet", kp = 3,
              waypoint = { map = 2395, x = 0.5683, y = 0.4077 }, vignetteID = 6837 },
            { questID = 89183, itemID = 238546, name = "Sin'dorei Master's Forgemace", kp = 3,
              waypoint = { map = 2393, x = 0.4916, y = 0.6135 }, vignetteID = 6834 },
            { questID = 89184, itemID = 238547, name = "Silvermoon Blacksmith's Hammer", kp = 3,
              waypoint = { map = 2393, x = 0.4853, y = 0.7438 }, vignetteID = 6833 },
            { questID = 89178, itemID = 238541, name = "Silvermoon Smithing Kit", kp = 3,
              waypoint = { map = 2395, x = 0.4837, y = 0.7583 }, vignetteID = 6839 },
            { questID = 89179, itemID = 238542, name = "Carefully Racked Spear", kp = 3,
              waypoint = { map = 2536, x = 0.3312, y = 0.6579 }, vignetteID = 6838 },
            { questID = 89182, itemID = 238545, name = "Rutaani Floratender's Sword", kp = 3,
              waypoint = { map = 2413, x = 0.6634, y = 0.5084 }, vignetteID = 6835 },
            { questID = 89181, itemID = 238544, name = "Voidstorm Defense Spear", kp = 3,
              waypoint = { map = 2444, x = 0.3051, y = 0.6900 }, vignetteID = 6836 },
        },
        uniqueBooks = {
            { questID = 93795, itemID = 262644, name = "Beyond the Event Horizon: Blacksmithing", kp = 10,
              waypoint = { map = 2405, x = 0.5258, y = 0.7290 },
              requires = { renown = { factionID = 2699, level = 9 },
                           currency = { { id = 3257, amount = 75 }, { id = 3316, amount = 750 } } } },
        },
        weeklies = {
            { key = "trainer",   label = "Trainer Quest",           questIDs = { 93691 },           kp = 2 },
            { key = "drop",      label = "Weekly Treasures",        questIDs = { 93530, 93531 },    kp = 2, mode = "each" },
            { key = "treatise",  label = "Treatise",                questIDs = { 95128 },            kp = 1 },
            { key = "dmf",       label = "Darkmoon Faire",          questIDs = { 29508 },            kp = 3, dmf = true },
        },
        weeklyItem = { questID = 93691, itemID = 263455, name = "Thalassian Blacksmith's Journal", kp = 2,
                       waypoint = { map = 2393, x = 0.4503, y = 0.5515 } },
        catchup = { currencyID = 3199 },
    },
    buffCategory = "crafting",
}
