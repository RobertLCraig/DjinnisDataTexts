-- Djinni's Data Texts — Professions Framework: Shared Data
-- Profession definitions, expansion constants, buff tables.
local _, ns = ...

---------------------------------------------------------------------------
-- Profession Data Registry
-- Each Data_*.lua file populates its entry here during file load.
-- Core.lua iterates this table during Init().
---------------------------------------------------------------------------

ns.ProfessionData = ns.ProfessionData or {}

---------------------------------------------------------------------------
-- Expansion definitions
---------------------------------------------------------------------------

ns.PROF_EXPANSIONS = {
    midnight = { id = "midnight", label = "Midnight", order = 1 },
    -- tww = { id = "tww", label = "The War Within", order = 2 },  -- future
}

---------------------------------------------------------------------------
-- Profession definitions
-- baseSkillLine: the root profession skill line (shared across expansions)
-- expansions.midnight: expansion-specific data (skill line, detection spell,
--     catch-up currency, trainer location)
---------------------------------------------------------------------------

ns.PROF_DEFS = {
    alchemy = {
        name = "Alchemy",
        baseSkillLine = 171,
        fallbackIcon = "Interface\\Icons\\Trade_Alchemy",
        expansions = {
            midnight = { skillLine = 2906, spellID = 471003, catchupCurrency = 3189,
                         trainer = { map = 2393, x = 0.4704, y = 0.5197 } },
        },
    },
    blacksmithing = {
        name = "Blacksmithing",
        baseSkillLine = 164,
        fallbackIcon = "Interface\\Icons\\Trade_BlackSmithing",
        expansions = {
            midnight = { skillLine = 2907, spellID = 471004, catchupCurrency = 3199,
                         trainer = { map = 2393, x = 0.4365, y = 0.5177 } },
        },
    },
    enchanting = {
        name = "Enchanting",
        baseSkillLine = 333,
        fallbackIcon = "Interface\\Icons\\Trade_Engraving",
        expansions = {
            midnight = { skillLine = 2909, spellID = 471006, catchupCurrency = 3198,
                         trainer = { map = 2393, x = 0.4800, y = 0.5385 } },
        },
    },
    engineering = {
        name = "Engineering",
        baseSkillLine = 202,
        fallbackIcon = "Interface\\Icons\\Trade_Engineering",
        expansions = {
            midnight = { skillLine = 2910, spellID = 471007, catchupCurrency = 3197,
                         trainer = { map = 2393, x = 0.4352, y = 0.5410 } },
        },
    },
    herbalism = {
        name = "Herbalism",
        baseSkillLine = 182,
        fallbackIcon = "Interface\\Icons\\Trade_Herbalism",
        expansions = {
            midnight = { skillLine = 2912, spellID = 471009, catchupCurrency = 3196,
                         trainer = { map = 2393, x = 0.4830, y = 0.5142 } },
        },
    },
    inscription = {
        name = "Inscription",
        baseSkillLine = 773,
        fallbackIcon = "Interface\\Icons\\INV_Inscription_Tradeskill01",
        expansions = {
            midnight = { skillLine = 2913, spellID = 471010, catchupCurrency = 3195,
                         trainer = { map = 2393, x = 0.4691, y = 0.5161 } },
        },
    },
    jewelcrafting = {
        name = "Jewelcrafting",
        baseSkillLine = 755,
        fallbackIcon = "Interface\\Icons\\INV_Misc_Gem_01",
        expansions = {
            midnight = { skillLine = 2914, spellID = 471011, catchupCurrency = 3194,
                         trainer = { map = 2393, x = 0.4818, y = 0.5509 } },
        },
    },
    leatherworking = {
        name = "Leatherworking",
        baseSkillLine = 165,
        fallbackIcon = "Interface\\Icons\\INV_Misc_ArmorKit_17",
        expansions = {
            midnight = { skillLine = 2915, spellID = 471012, catchupCurrency = 3193,
                         trainer = { map = 2393, x = 0.4314, y = 0.5576 } },
        },
    },
    mining = {
        name = "Mining",
        baseSkillLine = 186,
        fallbackIcon = "Interface\\Icons\\Trade_Mining",
        expansions = {
            midnight = { skillLine = 2916, spellID = 471013, catchupCurrency = 3192,
                         trainer = { map = 2393, x = 0.4259, y = 0.5286 } },
        },
    },
    skinning = {
        name = "Skinning",
        baseSkillLine = 393,
        fallbackIcon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
        expansions = {
            midnight = { skillLine = 2917, spellID = 471014, catchupCurrency = 3191,
                         trainer = { map = 2393, x = 0.4320, y = 0.5557 } },
        },
    },
    tailoring = {
        name = "Tailoring",
        baseSkillLine = 197,
        fallbackIcon = "Interface\\Icons\\Trade_Tailoring",
        expansions = {
            midnight = { skillLine = 2918, spellID = 471015, catchupCurrency = 3190,
                         trainer = { map = 2393, x = 0.4820, y = 0.5399 } },
        },
    },
}

-- Reverse lookup: baseSkillLine → profKey
ns.PROF_SKILL_TO_KEY = {}
for key, def in pairs(ns.PROF_DEFS) do
    ns.PROF_SKILL_TO_KEY[def.baseSkillLine] = key
end

---------------------------------------------------------------------------
-- Profession categories
---------------------------------------------------------------------------

ns.PROF_GATHERING = { herbalism = true, mining = true, skinning = true }
ns.PROF_CRAFTING  = {
    alchemy = true, blacksmithing = true, enchanting = true, engineering = true,
    inscription = true, jewelcrafting = true, leatherworking = true, tailoring = true,
}

---------------------------------------------------------------------------
-- Consumable buff definitions
-- Shared across professions of the same category.
---------------------------------------------------------------------------

ns.PROF_BUFFS = {
    gathering = {
        { itemID = 242299, name = "Sanguithorn Tea",              buffName = "Relaxed",                     stat = "Perception" },
        { itemID = 242298, name = "Argentleaf Tea",               buffName = "Relaxed",                     stat = "Finesse" },
        { itemID = 242301, name = "Azeroot Tea",                  buffName = "Relaxed",                     stat = "Deftness" },
        { itemID = 241317, name = "Haranir Phial of Perception",  buffName = "Haranir Phial of Perception", stat = "Perception" },
        { itemID = 241311, name = "Haranir Phial of Finesse",     buffName = "Haranir Phial of Finesse",    stat = "Finesse" },
        { itemID = 237373, name = "Refulgent Razorstone",         buffName = "Refulgent Razorstone",        stat = "Finesse" },
        { itemID = 124671, name = "Darkmoon Firewater",           buffName = "Darkmoon Firewater",          stat = "Deftness" },
    },
    crafting = {
        { itemID = 241313, name = "Haranir Phial of Ingenuity",              buffName = "Haranir Phial of Ingenuity",              stat = "Ingenuity" },
        { itemID = 241314, name = "Haranir Phial of Concentrated Ingenuity", buffName = "Haranir Phial of Concentrated Ingenuity", stat = "Ingenuity" },
    },
}

---------------------------------------------------------------------------
-- Click action definitions (shared base; professions can add extras)
---------------------------------------------------------------------------

ns.PROF_CLICK_ACTIONS = {
    openprofessions = "Open Profession Window",
    waypointtrainer = "Waypoint Trainer",
    waypointbeast   = "Waypoint Next Beast",
    openmap         = "Open Map to Beast",
    shoppinglist    = "Reagent Shopping List",
    bufflist        = "Buff Shopping List",
    opensettings    = "Open DDT Settings",
    none            = "None",
}

ns.PROF_ROW_CLICK_ACTIONS = {
    waypoint = "Set Waypoint",
    none     = "None",
}
