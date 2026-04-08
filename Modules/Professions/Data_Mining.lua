-- Djinni's Data Texts - Professions: Mining (Midnight)
local _, ns = ...
ns.ProfessionData = ns.ProfessionData or {}

ns.ProfessionData.mining = {
    kpSources = {
        uniqueTreasures = {
            { questID = 89147, itemID = 238599, name = "Solid Ore Punchers", kp = 3,
              waypoint = { map = 2395, x = 0.3798, y = 0.4537 }, vignetteID = 6857 },
            { questID = 89145, itemID = 238597, name = "Spelunker's Lucky Charm", kp = 3,
              waypoint = { map = 2437, x = 0.4200, y = 0.4653 }, vignetteID = 6859 },
            { questID = 89149, itemID = 238601, name = "Amani Expert's Chisel", kp = 3,
              waypoint = { map = 2536, x = 0.3329, y = 0.6589 }, vignetteID = 6803 },
            { questID = 89151, itemID = 238603, name = "Spare Expedition Torch", kp = 3,
              waypoint = { map = 2413, x = 0.3884, y = 0.6586 }, vignetteID = 6801 },
            { questID = 89150, itemID = 238602, name = "Star Metal Deposit", kp = 3,
              waypoint = { map = 2444, x = 0.3427, y = 0.7609 }, vignetteID = 6802 },
            { questID = 89144, itemID = 238596, name = "Miner's Guide to Voidstorm", kp = 3,
              waypoint = { map = 2444, x = 0.3047, y = 0.6907 }, vignetteID = 6860 },
            { questID = 89146, itemID = 238598, name = "Lost Voidstorm Satchel", kp = 3,
              waypoint = { map = 2444, x = 0.5424, y = 0.5160 }, vignetteID = 6858 },
            { questID = 89148, itemID = 238600, name = "Glimmering Void Pearl", kp = 3,
              waypoint = { map = 2444, x = 0.2875, y = 0.3857 }, vignetteID = 6804 },
        },
        uniqueBooks = {
            { questID = 92372, itemID = 250924, name = "Whisper of the Loa: Mining", kp = 10,
              waypoint = { map = 2437, x = 0.458, y = 0.658 },
              requires = { renown = { factionID = 2696, level = 6 },
                           currency = { { id = 3264, amount = 75 }, { id = 3316, amount = 750 } } } },
            { questID = 92187, itemID = 250444, name = "Echo of Abundance: Mining", kp = 10,
              waypoint = { map = 2437, x = 0.3156, y = 0.2626 },
              requires = { currency = { { id = 3377, amount = 1600 }, { id = 3264, amount = 75 } } } },
        },
        weeklies = {
            { key = "trainer",   label = "Trainer Quest",            questIDs = { 93705, 93706, 93707, 93708, 93709 }, kp = 3, mode = "rotation" },
            { key = "drop",      label = "Igneous Rock Specimen",    questIDs = { 88673, 88674, 88675, 88676, 88677 }, kp = 1, mode = "each" },
            { key = "bonusDrop", label = "Septarian Nodule",         questIDs = { 88678 },                              kp = 3 },
            { key = "treatise",  label = "Treatise",                 questIDs = { 95135 },                               kp = 1 },
            { key = "dmf",       label = "Darkmoon Faire",           questIDs = { 29518 },                               kp = 3, dmf = true },
        },
        catchup = { currencyID = 3192 },
    },

    activities = {
        buffTrackers = {
            { spellID = 1225704, buffName = "Wild Perception",
              description = "+150 Midnight Mining Perception (5 min)",
              source = "Avatar of Nalorakk (Wild Overload)" },
        },
    },

    buffCategory = "gathering",
}
