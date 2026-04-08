-- Djinni's Data Texts — Professions: Enchanting (Midnight)
local _, ns = ...
ns.ProfessionData = ns.ProfessionData or {}

ns.ProfessionData.enchanting = {
    kpSources = {
        uniqueTreasures = {
            { questID = 89103, itemID = 238551, name = "Everblazing Sunmote", kp = 3,
              waypoint = { map = 2395, x = 0.6075, y = 0.5301 }, vignetteID = 6829 },
            { questID = 89107, itemID = 238555, name = "Sin'dorei Enchanting Rod", kp = 3,
              waypoint = { map = 2395, x = 0.6349, y = 0.3259 }, vignetteID = 6825 },
            { questID = 89101, itemID = 238549, name = "Enchanted Sunfire Silk", kp = 3,
              waypoint = { map = 2395, x = 0.4019, y = 0.6121 }, vignetteID = 6831 },
            { questID = 89106, itemID = 238554, name = "Loa-Blessed Dust", kp = 3,
              waypoint = { map = 2437, x = 0.4041, y = 0.5118 }, vignetteID = 6826 },
            { questID = 89100, itemID = 238548, name = "Enchanted Amani Mask", kp = 3,
              waypoint = { map = 2536, x = 0.4877, y = 0.2255 }, vignetteID = 6832 },
            { questID = 89104, itemID = 238552, name = "Entropic Shard", kp = 3,
              waypoint = { map = 2413, x = 0.3775, y = 0.6523 }, vignetteID = 6828 },
            { questID = 89105, itemID = 238553, name = "Primal Essence Orb", kp = 3,
              waypoint = { map = 2413, x = 0.6572, y = 0.5022 }, vignetteID = 6827 },
            { questID = 89102, itemID = 238550, name = "Pure Void Crystal", kp = 3,
              waypoint = { map = 2405, x = 0.3546, y = 0.5882 }, vignetteID = 6830 },
        },
        uniqueBooks = {
            { questID = 92374, itemID = 257600, name = "Skill Issue: Enchanting", kp = 10,
              waypoint = { map = 2395, x = 0.434, y = 0.474 },
              requires = { renown = { factionID = 2710, level = 6 },
                           currency = { { id = 3258, amount = 75 }, { id = 3316, amount = 750 } } } },
            { questID = 92186, itemID = 250445, name = "Echo of Abundance: Enchanting", kp = 10,
              waypoint = { map = 2437, x = 0.3156, y = 0.2626 },
              requires = { currency = { { id = 3377, amount = 1600 }, { id = 3258, amount = 75 } } } },
        },
        weeklies = {
            { key = "trainer",   label = "Trainer Quest",          questIDs = { 93699, 93698, 93697 },                     kp = 3, mode = "rotation" },
            { key = "drop",      label = "Swirling Arcane Essence", questIDs = { 95048, 95049, 95050, 95051, 95052 },       kp = 1, mode = "each" },
            { key = "bonusDrop", label = "Brimming Mana Shard",    questIDs = { 95053 },                                    kp = 4 },
            { key = "weekly1",   label = "Voidstorm Ashes",        questIDs = { 93532 },                                    kp = 2 },
            { key = "weekly2",   label = "Lost Thalassian Vellum", questIDs = { 93533 },                                    kp = 2 },
            { key = "treatise",  label = "Treatise",               questIDs = { 95129 },                                    kp = 1 },
            { key = "dmf",       label = "Darkmoon Faire",         questIDs = { 29510 },                                    kp = 3, dmf = true },
        },
        catchup = { currencyID = 3198 },
    },

    activities = {
        buffAlerts = {
            { spellID = 1235733, buffName = "Shattered Essence", castSpellID = 1235731,
              alertText = "NO SHATTER BUFF", activeText = "Shattered Essence Active",
              description = "+5 Resourcefulness, +5 Ingenuity, +5 Multicraft" },
        },
    },

    buffCategory = "crafting",
}
