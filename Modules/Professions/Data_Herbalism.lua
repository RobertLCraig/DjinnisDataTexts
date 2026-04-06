-- Djinni's Data Texts — Professions: Herbalism (Midnight)
local _, ns = ...
ns.ProfessionData = ns.ProfessionData or {}

ns.ProfessionData.herbalism = {
    kpSources = {
        uniqueTreasures = {
            { questID = 89160, itemID = 238470, name = "Simple Leaf Pruners", kp = 3,
              waypoint = { map = 2393, x = 0.4901, y = 0.7595 }, vignetteID = 6851 },
            { questID = 89158, itemID = 238472, name = "A Spade", kp = 3,
              waypoint = { map = 2395, x = 0.6426, y = 0.3046 }, vignetteID = 6853 },
            { questID = 89161, itemID = 238469, name = "Sweeping Harvester's Scythe", kp = 3,
              waypoint = { map = 2437, x = 0.4191, y = 0.4591 }, vignetteID = 6850 },
            { questID = 89157, itemID = 238473, name = "Harvester's Sickle", kp = 3,
              waypoint = { map = 2413, x = 0.7612, y = 0.5104 }, vignetteID = 6854 },
            { questID = 89162, itemID = 238468, name = "Bloomed Bud", kp = 3,
              waypoint = { map = 2413, x = 0.3832, y = 0.6704 }, vignetteID = 6849 },
            { questID = 89159, itemID = 238471, name = "Lightbloom Root", kp = 3,
              waypoint = { map = 2413, x = 0.3666, y = 0.2506 }, vignetteID = 6852 },
            { questID = 89155, itemID = 238475, name = "Planting Shovel", kp = 3,
              waypoint = { map = 2413, x = 0.5111, y = 0.5571 }, vignetteID = 6856 },
            { questID = 89156, itemID = 238474, name = "Peculiar Lotus", kp = 3,
              waypoint = { map = 2405, x = 0.3468, y = 0.5696 }, vignetteID = 6855 },
        },
        uniqueBooks = {
            { questID = 93411, itemID = 258410, name = "Traditions of the Haranir: Herbalism", kp = 10,
              waypoint = { map = 2413, x = 0.510, y = 0.508 },
              requires = { renown = { factionID = 2704, level = 6 },
                           currency = { { id = 3260, amount = 75 }, { id = 3316, amount = 750 } } } },
            { questID = 92174, itemID = 250443, name = "Echo of Abundance: Herbalism", kp = 10,
              waypoint = { map = 2437, x = 0.3156, y = 0.2626 },
              requires = { currency = { { id = 3377, amount = 1600 }, { id = 3260, amount = 75 } } } },
        },
        weeklies = {
            { key = "trainer",   label = "Trainer Quest",            questIDs = { 93700, 93701, 93702, 93703, 93704 }, kp = 3, mode = "rotation" },
            { key = "drop",      label = "Thalassian Phoenix Plume", questIDs = { 81425, 81426, 81427, 81428, 81429 }, kp = 1, mode = "each" },
            { key = "bonusDrop", label = "Thalassian Phoenix Tail",  questIDs = { 81430 },                              kp = 4 },
            { key = "treatise",  label = "Treatise",                 questIDs = { 95130 },                               kp = 1 },
            { key = "dmf",       label = "Darkmoon Faire",           questIDs = { 29514 },                               kp = 3, dmf = true },
        },
        catchup = { currencyID = 3196 },
    },
    buffCategory = "gathering",
}
