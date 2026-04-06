-- Djinni's Data Texts — Professions: Jewelcrafting (Midnight)
local _, ns = ...
ns.ProfessionData = ns.ProfessionData or {}

ns.ProfessionData.jewelcrafting = {
    kpSources = {
        uniqueTreasures = {
            { questID = 89122, itemID = 238580, name = "Sin'dorei Masterwork Chisel", kp = 3,
              waypoint = { map = 2393, x = 0.5064, y = 0.5651 }, vignetteID = 6868 },
            { questID = 89124, itemID = 238582, name = "Dual-Function Magnifiers", kp = 3,
              waypoint = { map = 2393, x = 0.2862, y = 0.4638 }, vignetteID = 6866 },
            { questID = 89127, itemID = 238585, name = "Vintage Soul Gem", kp = 3,
              waypoint = { map = 2393, x = 0.5544, y = 0.4782 }, vignetteID = 6811 },
            { questID = 89125, itemID = 238583, name = "Poorly Rounded Vial", kp = 3,
              waypoint = { map = 2395, x = 0.5662, y = 0.4088 }, vignetteID = 6865 },
            { questID = 89129, itemID = 238587, name = "Sin'dorei Gem Faceters", kp = 3,
              waypoint = { map = 2395, x = 0.3964, y = 0.3882 }, vignetteID = 6809 },
            { questID = 89123, itemID = 238581, name = "Speculative Voidstorm Crystal", kp = 3,
              waypoint = { map = 2444, x = 0.3047, y = 0.6902 }, vignetteID = 6867 },
            { questID = 89126, itemID = 238584, name = "Shattered Glass", kp = 3,
              waypoint = { map = 2444, x = 0.6274, y = 0.5343 }, vignetteID = 6812 },
            { questID = 89128, itemID = 238586, name = "Ethereal Gem Pliers", kp = 3,
              waypoint = { map = 2444, x = 0.5420, y = 0.5104 }, vignetteID = 6810 },
        },
        uniqueBooks = {
            { questID = 93222, itemID = 257599, name = "Skill Issue: Jewelcrafting", kp = 10,
              waypoint = { map = 2395, x = 0.434, y = 0.474 },
              requires = { renown = { factionID = 2710, level = 6 },
                           currency = { { id = 3262, amount = 75 }, { id = 3316, amount = 750 } } } },
        },
        weeklies = {
            { key = "trainer",   label = "Trainer Quest",       questIDs = { 93694 },           kp = 3 },
            { key = "drop",      label = "Weekly Treasures",    questIDs = { 93539, 93538 },    kp = 2, mode = "each" },
            { key = "treatise",  label = "Treatise",            questIDs = { 95133 },            kp = 1 },
            { key = "dmf",       label = "Darkmoon Faire",      questIDs = { 29516 },            kp = 3, dmf = true },
        },
        weeklyItem = { questID = 93694, itemID = 263458, name = "Thalassian Jewelcrafter's Notebook", kp = 3,
                       waypoint = { map = 2393, x = 0.4503, y = 0.5515 } },
        catchup = { currencyID = 3194 },
    },
    buffCategory = "crafting",
}
