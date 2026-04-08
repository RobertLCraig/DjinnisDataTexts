-- Djinni's Data Texts — Professions: Alchemy (Midnight)
local _, ns = ...
ns.ProfessionData = ns.ProfessionData or {}

ns.ProfessionData.alchemy = {
    kpSources = {
        uniqueTreasures = {
            { questID = 89115, itemID = 238536, name = "Freshly Plucked Peacebloom", kp = 3,
              waypoint = { map = 2393, x = 0.4911, y = 0.7585 }, vignetteID = 6844 },
            { questID = 89117, itemID = 238538, name = "Pristine Potion", kp = 3,
              waypoint = { map = 2393, x = 0.4775, y = 0.5169 }, vignetteID = 6842 },
            { questID = 89111, itemID = 238532, name = "Vial of Eversong Oddities", kp = 3,
              waypoint = { map = 2393, x = 0.4507, y = 0.4476 }, vignetteID = 6848 },
            { questID = 89114, itemID = 238535, name = "Vial of Zul'Aman Oddities", kp = 3,
              waypoint = { map = 2437, x = 0.4040, y = 0.5118 }, vignetteID = 6845 },
            { questID = 89116, itemID = 238537, name = "Measured Ladle", kp = 3,
              waypoint = { map = 2536, x = 0.4910, y = 0.2314 }, vignetteID = 6843 },
            { questID = 89113, itemID = 238534, name = "Vial of Rootlands Oddities", kp = 3,
              waypoint = { map = 2413, x = 0.3477, y = 0.2469 }, vignetteID = 6846 },
            { questID = 89118, itemID = 238539, name = "Failed Experiment", kp = 3,
              waypoint = { map = 2405, x = 0.3279, y = 0.4330 }, vignetteID = 6841 },
            { questID = 89112, itemID = 238533, name = "Vial of Voidstorm Oddities", kp = 3,
              waypoint = { map = 2444, x = 0.4198, y = 0.4061 }, vignetteID = 6847 },
        },
        uniqueBooks = {
            { questID = 93794, itemID = 262645, name = "Beyond the Event Horizon: Alchemy", kp = 10,
              waypoint = { map = 2405, x = 0.5258, y = 0.7290 },
              requires = { renown = { factionID = 2699, level = 9 },
                           currency = { { id = 3256, amount = 75 }, { id = 3316, amount = 750 } } } },
        },
        weeklies = {
            { key = "trainer",   label = "Trainer Quest",       questIDs = { 93690 },                         kp = 1 },
            { key = "drop",      label = "Weekly Treasures",    questIDs = { 93528, 93529 },                  kp = 1, mode = "each" },
            { key = "treatise",  label = "Treatise",            questIDs = { 95127 },                         kp = 1 },
            { key = "dmf",       label = "Darkmoon Faire",      questIDs = { 29506 },                         kp = 3, dmf = true },
        },
        weeklyItem = { questID = 93690, itemID = 263454, name = "Thalassian Alchemist's Notebook", kp = 1,
                       waypoint = { map = 2393, x = 0.4503, y = 0.5515 } },
        catchup = { currencyID = 3189 },
    },

    activities = {
        cooldowns = {
            { spellID = 1230856, name = "Wondrous Synergist",             baseCooldown = 64800, shared = true },
            { spellID = 1230887, name = "Transmute: Mote of Wild Magic",  baseCooldown = 64800, shared = true },
            { spellID = 1230890, name = "Transmute: Mote of Light",       baseCooldown = 64800, shared = true },
            { spellID = 1230889, name = "Transmute: Mote of Primal Energy", baseCooldown = 64800, shared = true },
            { spellID = 1230888, name = "Transmute: Mote of Pure Void",   baseCooldown = 64800, shared = true },
        },
    },

    buffCategory = "crafting",
}
