-- Djinni's Data Texts — Professions: Tailoring (Midnight)
local _, ns = ...
ns.ProfessionData = ns.ProfessionData or {}

ns.ProfessionData.tailoring = {
    kpSources = {
        uniqueTreasures = {
            { questID = 89079, itemID = 238613, name = "A Really Nice Curtain", kp = 3,
              waypoint = { map = 2393, x = 0.3575, y = 0.6124 }, vignetteID = 6799 },
            { questID = 89084, itemID = 238618, name = "Particularly Enchanting Tablecloth", kp = 3,
              waypoint = { map = 2393, x = 0.3179, y = 0.6828 }, vignetteID = 6794 },
            { questID = 89080, itemID = 238614, name = "Sin'dorei Outfitter's Ruler", kp = 3,
              waypoint = { map = 2395, x = 0.4635, y = 0.3486 }, vignetteID = 6798 },
            { questID = 89085, itemID = 238619, name = "Artisan's Cover Comb", kp = 3,
              waypoint = { map = 2437, x = 0.4053, y = 0.4937 }, vignetteID = 6793 },
            { questID = 89078, itemID = 238612, name = "A Child's Stuffy", kp = 3,
              waypoint = { map = 2413, x = 0.7057, y = 0.5090 }, vignetteID = 6800 },
            { questID = 89081, itemID = 238615, name = "Wooden Weaving Sword", kp = 3,
              waypoint = { map = 2413, x = 0.6976, y = 0.5105 }, vignetteID = 6797 },
            { questID = 89082, itemID = 238616, name = "Book of Sin'dorei Stitches", kp = 3,
              waypoint = { map = 2444, x = 0.6201, y = 0.8351 }, vignetteID = 6796 },
            { questID = 89083, itemID = 238617, name = "Satin Throw Pillow", kp = 3,
              waypoint = { map = 2444, x = 0.6139, y = 0.8513 }, vignetteID = 6795 },
        },
        uniqueBooks = {
            { questID = 93201, itemID = 257601, name = "Skill Issue: Tailoring", kp = 10,
              waypoint = { map = 2395, x = 0.434, y = 0.474 },
              requires = { renown = { factionID = 2710, level = 6 },
                           currency = { { id = 3266, amount = 75 }, { id = 3316, amount = 750 } } } },
        },
        weeklies = {
            { key = "trainer",   label = "Trainer Quest",       questIDs = { 93696 },           kp = 2 },
            { key = "drop",      label = "Weekly Treasures",    questIDs = { 93542, 93543 },    kp = 2, mode = "each" },
            { key = "treatise",  label = "Treatise",            questIDs = { 95137 },            kp = 1 },
            { key = "dmf",       label = "Darkmoon Faire",      questIDs = { 29520 },            kp = 3, dmf = true },
        },
        weeklyItem = { questID = 93696, itemID = 263460, name = "Thalassian Tailor's Notebook", kp = 2,
                       waypoint = { map = 2393, x = 0.4503, y = 0.5515 } },
        catchup = { currencyID = 3190 },
    },

    activities = {
        cooldowns = {
            { spellID = 1227926, name = "Arcanoweave Bolt", baseCooldown = 60480, maxCharges = 10 },
            { spellID = 1228060, name = "Sunfire Silk Bolt", baseCooldown = 60480, maxCharges = 10 },
        },
    },

    buffCategory = "crafting",
}
