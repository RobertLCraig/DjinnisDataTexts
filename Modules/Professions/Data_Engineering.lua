-- Djinni's Data Texts - Professions: Engineering (Midnight)
local _, ns = ...
ns.ProfessionData = ns.ProfessionData or {}

ns.ProfessionData.engineering = {
    kpSources = {
        uniqueTreasures = {
            { questID = 89133, itemID = 238556, name = "One Engineer's Junk", kp = 3,
              waypoint = { map = 2393, x = 0.5132, y = 0.7445 }, vignetteID = 6824 },
            { questID = 89139, itemID = 238562, name = "What To Do When Nothing Works", kp = 3,
              waypoint = { map = 2393, x = 0.5120, y = 0.5726 }, vignetteID = 6818 },
            { questID = 89135, itemID = 238558, name = "Manual of Mistakes and Mishaps", kp = 3,
              waypoint = { map = 2395, x = 0.3957, y = 0.4580 }, vignetteID = 6822 },
            { questID = 89140, itemID = 238563, name = "Handy Wrench", kp = 3,
              waypoint = { map = 2437, x = 0.3420, y = 0.8780 }, vignetteID = 6817 },
            { questID = 89138, itemID = 238561, name = "Offline Helper Bot", kp = 3,
              waypoint = { map = 2536, x = 0.6514, y = 0.3475 }, vignetteID = 6819 },
            { questID = 89136, itemID = 238559, name = "Expeditious Pylon", kp = 3,
              waypoint = { map = 2413, x = 0.6799, y = 0.4980 }, vignetteID = 6821 },
            { questID = 89137, itemID = 238560, name = "Ethereal Stormwrench", kp = 3,
              waypoint = { map = 2444, x = 0.5413, y = 0.5100 }, vignetteID = 6820 },
            { questID = 89134, itemID = 238557, name = "Miniaturized Transport Skiff", kp = 3,
              waypoint = { map = 2444, x = 0.2893, y = 0.3899 }, vignetteID = 6823 },
        },
        uniqueBooks = {
            { questID = 93796, itemID = 262646, name = "Beyond the Event Horizon: Engineering", kp = 10,
              waypoint = { map = 2405, x = 0.5258, y = 0.7290 },
              requires = { renown = { factionID = 2699, level = 9 },
                           currency = { { id = 3259, amount = 75 }, { id = 3316, amount = 750 } } } },
        },
        weeklies = {
            { key = "trainer",   label = "Trainer Quest",       questIDs = { 93692 },           kp = 1 },
            { key = "drop",      label = "Weekly Treasures",    questIDs = { 93534, 93535 },    kp = 1, mode = "each" },
            { key = "treatise",  label = "Treatise",            questIDs = { 95138 },            kp = 1 },
            { key = "dmf",       label = "Darkmoon Faire",      questIDs = { 29511 },            kp = 3, dmf = true },
        },
        weeklyItem = { questID = 93692, itemID = 263456, name = "Thalassian Engineer's Notepad", kp = 1,
                       waypoint = { map = 2393, x = 0.4503, y = 0.5515 } },
        catchup = { currencyID = 3197 },
    },
    buffCategory = "crafting",
}
