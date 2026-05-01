-- Djinni's Data Texts - Majestic Beast Tracker
-- Skinning lure cooldowns, loot tracking, reagent management, weekly KP,
-- and AH integration for Midnight Majestic Beasts.
local addonName, ns = ...
local DDT = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local MajesticBeast = {}
ns.MajesticBeast = MajesticBeast

---------------------------------------------------------------------------
-- Constants / static data (mirrors MajesticBeastTracker/Core.lua)
---------------------------------------------------------------------------

local LURES = {
    { npcID = 245688, itemID = 238652, recipeID = 1225943, questID = 88545, name = "Eversong",    color = "|cff00ff96", colorRGB = {0, 1, 0.59},       requiredPoints = 1,  waypoint = { map = 2395, x = 0.4195, y = 0.8005 },
      reagents = { { itemID = 238371, count = 8 }, { itemID = 238366, count = 8 } } },
    { npcID = 245699, itemID = 238653, recipeID = 1225944, questID = 88526, name = "Zul'Aman",    color = "|cff00ccff", colorRGB = {0, 0.8, 1},        requiredPoints = 10, waypoint = { map = 2437, x = 0.4769, y = 0.5325 },
      reagents = { { itemID = 238382, count = 8 } } },
    { npcID = 245690, itemID = 238654, recipeID = 1225945, questID = 88531, name = "Harandar",    color = "|cffff9900", colorRGB = {1, 0.6, 0},        requiredPoints = 20, waypoint = { map = 2413, x = 0.6628, y = 0.4791 },
      reagents = { { itemID = 238375, count = 8 }, { itemID = 238374, count = 8 } } },
    { npcID = 247096, itemID = 238655, recipeID = 1225946, questID = 88532, name = "Voidstorm",   color = "|cffa335ee", colorRGB = {0.64, 0.21, 0.93}, requiredPoints = 30, waypoint = { map = 2405, x = 0.5460, y = 0.6580 },
      reagents = { { itemID = 238373, count = 4 } } },
    { npcID = 247101, itemID = 238656, recipeID = 1225948, questID = 88524, name = "Grand Beast", color = "|cffff3333", colorRGB = {1, 0.2, 0.2},      requiredPoints = 40, waypoint = { map = 2405, x = 0.4325, y = 0.8275 },
      reagents = { { itemID = 238380, count = 4 } } },
}

-- Skinning loot items per beast
local BEAST_LOOT = {
    ["Eversong"]    = { 238511, 238512, 238518, 238519, 238523, 238525, 238528, 238529 },
    ["Zul'Aman"]    = { 238513, 238514, 238520, 238521, 238528 },
    ["Harandar"]    = { 238513, 238514, 238520, 238521, 238530, 238522 },
    ["Voidstorm"]   = { 238511, 238512, 238518, 238519, 238528, 238529, 238525, 238523 },
    ["Grand Beast"] = { 238513, 238514, 238520, 238521, 238528, 238529, 238530, 238522 },
}

-- All tracked loot item IDs (set) - built at load time for O(1) lookups
-- in BAG_UPDATE_DELAYED (fires frequently, must be fast).
local TRACKED_LOOT = {}
for _, items in pairs(BEAST_LOOT) do
    for _, id in ipairs(items) do TRACKED_LOOT[id] = true end
end

-- Lure reagent items (set) - for reagent count tracking in bag scans
local LURE_REAGENTS = {}
for _, lure in ipairs(LURES) do
    if lure.reagents then
        for _, r in ipairs(lure.reagents) do LURE_REAGENTS[r.itemID] = true end
    end
end

-- Quest ID -> lure index for QUEST_TURNED_IN kill detection.
-- Beast kills complete a hidden quest; matching questID to lure index
-- lets us detect which beast was killed without scanning combat log.
local questToIndex = {}
for i, lure in ipairs(LURES) do
    if lure.questID then questToIndex[lure.questID] = i end
end

-- Consumables (same as MBT UI.lua)
local CONSUMABLES = {
    { itemID = 242299, name = "Sanguithorn Tea",              buffName = "Relaxed" },
    { itemID = 241317, name = "Haranir Phial of Perception",  buffName = "Haranir Phial of Perception" },
    { itemID = 238367, name = "Root Crab",                    buffName = "Midnight Perception" },
}

-- Skinning weekly Knowledge Point sources
local SKINNING_WEEKLIES = {
    { key = "trainer",   label = "Trainer Quest",  questIDs = { 93710, 93711, 93712, 93713, 93714 }, kp = 3, mode = "rotation" },
    { key = "drop",      label = "Skinning Drop",  questIDs = { 88534, 88549, 88536, 88537, 88530 }, kp = 1, mode = "each" },
    { key = "bonusDrop", label = "Bonus Drop",     questIDs = { 88529 },                              kp = 3 },
    { key = "treatise",  label = "Treatise",        questIDs = { 95136 },                              kp = 1 },
    { key = "dmf",       label = "Darkmoon Faire",  questIDs = { 29519 },                              kp = 3, dmf = true },
}

-- All weekly quest IDs (set for fast QUEST_TURNED_IN check)
local weeklyQuestIDs = {}
for _, w in ipairs(SKINNING_WEEKLIES) do
    for _, qid in ipairs(w.questIDs) do weeklyQuestIDs[qid] = true end
end

local MIDNIGHT_SKINNING_SKILL_LINE = 2917
local MIDNIGHT_SKINNING_SPELL = 471014

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

MajesticBeast.charKey          = nil
MajesticBeast.killsDoneToday   = 0
MajesticBeast.killsTotal       = #LURES
MajesticBeast.nextBeastName    = nil
MajesticBeast.nextBeastIndex   = nil
MajesticBeast.hasSkinning      = false
MajesticBeast.talentPoints     = 0
MajesticBeast.weeklyKPEarned   = 0
MajesticBeast.weeklyKPTotal    = 0
MajesticBeast.killStatus       = {}   -- { [lureName] = true/false }

-- Loot tracking state
local pendingLootBeast    = nil
local pendingLootSnapshot = nil
local pendingLootTime     = 0
local preCombatSnapshot   = nil
local pendingLootAccum    = {}

-- Tooltip
local tooltipFrame = nil
local hideTimer    = nil
local rowPool      = {}
local headerPool   = {}
local separatorPool = {}

-- Layout
local HEADER_HEIGHT = 18
local PADDING       = 10
local ICON_SIZE     = 18
local HINT_HEIGHT   = 18

-- AH hook state
local ahHookInstalled = false

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
    labelTemplate    = "<kills>/<total> Beasts",
    tooltipScale     = 1.0,
    tooltipMaxHeight = 500,
    tooltipWidth     = 340,
    showReagents     = true,
    showLoot         = true,
    showWeeklyKP     = true,
    ahAutofillQuantity = true,
    chars            = {},   -- local per-char storage; MBT addon's DB used if installed
    -- TODO: consumableStock targets per item
    -- TODO: routeOrder customization
    -- TODO: routeSkip per-beast toggles
    clickActions = {
        leftClick       = "waypoint",
        rightClick      = "openmap",
        middleClick     = "none",
        shiftLeftClick  = "shoppinglist",
        shiftRightClick = "bufflist",
        ctrlLeftClick   = "openmbt",
        ctrlRightClick  = "none",
        altLeftClick    = "opensettings",
        altRightClick   = "none",
    },
    rowClickActions = {
        leftClick       = "waypoint",
        rightClick      = "placelure",
        middleClick     = "none",
        shiftLeftClick  = "craftlure",
        shiftRightClick = "shopzone",
        ctrlLeftClick   = "openmap",
        ctrlRightClick  = "none",
        altLeftClick    = "none",
        altRightClick   = "none",
    },
}

---------------------------------------------------------------------------
-- Click action definitions
---------------------------------------------------------------------------

local CLICK_ACTIONS = {
    waypoint     = "Waypoint Next Beast",
    openmap      = "Open Map to Beast",
    shoppinglist = "Reagent Shopping List",
    bufflist     = "Buff Shopping List (Tea/Phial/Crab)",
    openmbt      = "Open MBT Window",
    opensettings = "Open DDT Settings",
    none         = "None",
}

local ROW_CLICK_ACTIONS = {
    waypoint    = "Set Waypoint",
    shopzone    = "Shop Zone Reagents",
    craftlure   = "Open Lure Recipe",
    placelure   = "Use Lure",
    openmap     = "Open Map",
    none        = "None",
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function DjinniMsg(msg)
    DDT:Print("|cff33ff99Djinni:|r " .. msg)
end

local function GetCharKey()
    return UnitName("player") .. "-" .. GetRealmName()
end

local function GetClassColor(class)
    if class and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
    end
    return "|cffffffff"
end

local function GetLastDailyReset()
    return GetServerTime() + C_DateAndTime.GetSecondsUntilDailyReset() - 86400
end

local function IsLureReady(timestamp)
    if not timestamp then return false end
    return timestamp < GetLastDailyReset()
end

local function FormatTimeLeft(seconds)
    if seconds <= 0 then return "|cff00ff00READY|r" end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    if h > 0 then
        return string.format("|cffff3333%dh %dm|r", h, m)
    else
        return string.format("|cffff9900%dm|r", m)
    end
end

local function CanSeeLure(charData, lureIndex)
    if not charData.hasSkinning then return false end
    if not charData.talentPoints or charData.talentPoints <= 0 then return false end
    return charData.talentPoints >= LURES[lureIndex].requiredPoints
end

local function HasSkinning()
    local prof1, prof2 = GetProfessions()
    if not prof1 and not prof2 then return false end
    local hasBase = false
    if prof1 then
        local _, _, _, _, _, _, skillLineID = GetProfessionInfo(prof1)
        if skillLineID == 393 then hasBase = true end
    end
    if not hasBase and prof2 then
        local _, _, _, _, _, _, skillLineID = GetProfessionInfo(prof2)
        if skillLineID == 393 then hasBase = true end
    end
    if not hasBase then return false end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, MIDNIGHT_SKINNING_SPELL)
        if ok then return known end
    end
    return nil
end

-- DMF up check (first Sunday of month for 7 days)
local function IsDarkmoonFaireUp()
    local dayOfWeek = tonumber(date("%w"))
    local dayOfMonth = tonumber(date("%e"))
    local firstSundayOfMonth = ((dayOfMonth - (dayOfWeek + 1)) % 7) + 1
    local daysSinceFirstSunday = dayOfMonth - firstSundayOfMonth
    return daysSinceFirstSunday >= 0 and daysSinceFirstSunday <= 6
end

---------------------------------------------------------------------------
-- Data source: MBT SavedVariables preferred, fallback to own DDT DB
---------------------------------------------------------------------------

-- Use MBT's DB if available (shared data), otherwise use our own DB's chars table
local function GetCharsDB()
    if MajesticBeastTrackerDB then
        if not MajesticBeastTrackerDB.chars then MajesticBeastTrackerDB.chars = {} end
        return MajesticBeastTrackerDB.chars
    end
    -- Fallback: store in our own SavedVariables
    local db = ns.db and ns.db.majesticbeast
    if db then
        if not db.chars then db.chars = {} end
        return db.chars
    end
    return nil
end

local function GetOwnDB()
    return ns.db and ns.db.majesticbeast
end

-- Ensure charData exists in whichever DB we're using
local function EnsureCharData(key)
    local chars = GetCharsDB()
    if not chars then return nil end
    if not chars[key] then
        local _, class = UnitClass("player")
        chars[key] = {
            class = class,
            lures = {},
            hasSkinning = false,
            talentPoints = 0,
        }
    end
    return chars[key]
end

---------------------------------------------------------------------------
-- Talented Tracker detection
---------------------------------------------------------------------------

local function GetInvestedPointsForTree(configID, rootNodeID)
    local todo = { rootNodeID }
    local totalPoints = 0
    while #todo > 0 do
        local nodeID = table.remove(todo)
        local children = C_ProfSpecs.GetChildrenForPath(nodeID)
        if children then
            for _, childID in ipairs(children) do
                table.insert(todo, childID)
            end
        end
        local info = C_Traits.GetNodeInfo(configID, nodeID)
        if info and info.activeRank and info.activeRank > 0 then
            totalPoints = totalPoints + info.activeRank
        end
    end
    return totalPoints
end

local function DetectTalentedTrackerPoints()
    if not HasSkinning() then return 0 end
    if not C_ProfSpecs then return 0 end
    local ok, configID = pcall(C_ProfSpecs.GetConfigIDForSkillLine, MIDNIGHT_SKINNING_SKILL_LINE)
    if not ok or not configID or configID == 0 then return 0 end
    local ok2, tabIDs = pcall(C_ProfSpecs.GetSpecTabIDsForSkillLine, MIDNIGHT_SKINNING_SKILL_LINE)
    if not ok2 or not tabIDs then return 0 end
    for _, tabID in ipairs(tabIDs) do
        local ok3, tabInfo = pcall(C_ProfSpecs.GetTabInfo, tabID)
        if ok3 and tabInfo and tabInfo.name and tabInfo.name:lower():find("tracker") then
            return GetInvestedPointsForTree(configID, tabInfo.rootNodeID)
        end
    end
    return 0
end

local function DetectSkinningAndTalent(key)
    local charData = EnsureCharData(key)
    if not charData then return end
    local skinning = HasSkinning()
    if skinning == true then
        charData.hasSkinning = true
        local points = DetectTalentedTrackerPoints()
        if points > 0 then charData.talentPoints = points end
    elseif skinning == false then
        charData.hasSkinning = false
        charData.talentPoints = 0
    end
    -- nil = API not ready, keep existing
end

---------------------------------------------------------------------------
-- Kill detection via quest flags
---------------------------------------------------------------------------

local function SyncKillsFromQuests(charKey, skipSanityCheck)
    local chars = GetCharsDB()
    if not chars or not chars[charKey] then return false end
    local charData = chars[charKey]
    if not charData.lures then charData.lures = {} end
    local changed = false

    local flagged = {}
    local flagCount = 0
    for i, lure in ipairs(LURES) do
        if lure.questID and C_QuestLog.IsQuestFlaggedCompleted(lure.questID) then
            flagged[i] = true
            flagCount = flagCount + 1
        end
    end

    -- Sanity check: all flagged but no existing kills = likely no tracker spec
    if not skipSanityCheck and flagCount == #LURES then
        local hasAnyKill = false
        for _, lure in ipairs(LURES) do
            if charData.lures[lure.name] then hasAnyKill = true; break end
        end
        if not hasAnyKill then return false end
    end

    for i, lure in ipairs(LURES) do
        if flagged[i] then
            local existing = charData.lures[lure.name]
            if not existing or IsLureReady(existing) then
                charData.lures[lure.name] = GetServerTime()
                changed = true
            end
        end
    end
    return changed
end

---------------------------------------------------------------------------
-- Weekly KP tracking
---------------------------------------------------------------------------

local function RefreshWeeklies(charKey)
    local chars = GetCharsDB()
    if not chars or not chars[charKey] then return end
    local charData = chars[charKey]
    if not charData.hasSkinning then return end

    local weeklies = {}
    for _, w in ipairs(SKINNING_WEEKLIES) do
        if w.mode == "each" then
            local completed = 0
            for _, qid in ipairs(w.questIDs) do
                if C_QuestLog.IsQuestFlaggedCompleted(qid) then completed = completed + 1 end
            end
            weeklies[w.key] = completed
        elseif w.mode == "rotation" then
            local done = false
            for _, qid in ipairs(w.questIDs) do
                if C_QuestLog.IsQuestFlaggedCompleted(qid) then done = true; break end
            end
            weeklies[w.key] = done
        else
            weeklies[w.key] = C_QuestLog.IsQuestFlaggedCompleted(w.questIDs[1])
        end
    end
    charData.weeklies = weeklies
    charData.weeklyResetTime = GetServerTime() + C_DateAndTime.GetSecondsUntilWeeklyReset()
end

---------------------------------------------------------------------------
-- Loot tracking: bag snapshot & recording
---------------------------------------------------------------------------

local function SnapshotTrackedItems()
    local snap = {}
    for id in pairs(TRACKED_LOOT) do
        snap[id] = C_Item.GetItemCount(id, false, false, false, false) or 0
    end
    return snap
end

local function DiffSnapshots(before, after)
    local diffs = {}
    for id in pairs(TRACKED_LOOT) do
        local delta = (after[id] or 0) - (before[id] or 0)
        if delta > 0 then diffs[id] = delta end
    end
    return diffs
end

local function GetTSMPrice(itemID)
    if not TSM_API then return nil end
    local ok, price = pcall(TSM_API.GetCustomPriceValue, "DBMinBuyout", "i:" .. itemID)
    if ok and price and price > 0 then return price end
    return nil
end

local function RecordLoot(beastName, diffs)
    if not MajesticBeast.charKey then return end
    local hasAny = false
    for _ in pairs(diffs) do hasAny = true; break end
    if not hasAny then return end

    local chars = GetCharsDB()
    if not chars then return end
    local charData = chars[MajesticBeast.charKey]
    if not charData then return end

    if not charData.loot then
        charData.loot = { thisReset = {}, allTime = {}, resetTime = GetServerTime() }
    end

    -- Reset thisReset if daily reset passed
    if charData.loot.resetTime and charData.loot.resetTime < GetLastDailyReset() then
        charData.loot.thisReset = {}
        charData.loot.perBeastReset = {}
        charData.loot.resetTime = GetServerTime()
    end

    if not charData.loot.prices then charData.loot.prices = {} end
    if not charData.loot.perBeast then charData.loot.perBeast = {} end
    if not charData.loot.perBeast[beastName] then charData.loot.perBeast[beastName] = {} end
    if not charData.loot.perBeastReset then charData.loot.perBeastReset = {} end
    if not charData.loot.perBeastReset[beastName] then charData.loot.perBeastReset[beastName] = {} end

    for id, count in pairs(diffs) do
        charData.loot.thisReset[id] = (charData.loot.thisReset[id] or 0) + count
        charData.loot.allTime[id] = (charData.loot.allTime[id] or 0) + count
        charData.loot.perBeast[beastName][id] = (charData.loot.perBeast[beastName][id] or 0) + count
        charData.loot.perBeastReset[beastName][id] = (charData.loot.perBeastReset[beastName][id] or 0) + count
        if not charData.loot.prices[id] then
            charData.loot.prices[id] = GetTSMPrice(id)
        end
    end

    DjinniMsg("Loot tracked from " .. beastName)
end

local function AccumulatePendingLoot()
    if not pendingLootBeast or not pendingLootSnapshot then return end
    local afterSnap = SnapshotTrackedItems()
    local diffs = DiffSnapshots(pendingLootSnapshot, afterSnap)
    for id, count in pairs(diffs) do
        pendingLootAccum[id] = count
    end
end

local function FinalizePendingLoot()
    if not pendingLootBeast then return false end
    AccumulatePendingLoot()
    RecordLoot(pendingLootBeast, pendingLootAccum)
    pendingLootBeast = nil
    pendingLootSnapshot = nil
    pendingLootTime = 0
    pendingLootAccum = {}
    return true
end

---------------------------------------------------------------------------
-- Reagent calculations
---------------------------------------------------------------------------

local function GetMissingReagents()
    local chars = GetCharsDB()
    if not chars then return {} end
    local missing = {}
    for i, lure in ipairs(LURES) do
        if lure.reagents then
            local numLeft = 0
            for _, cData in pairs(chars) do
                if CanSeeLure(cData, i) then
                    local ts = cData.lures and cData.lures[lure.name]
                    if not ts or IsLureReady(ts) then
                        numLeft = numLeft + 1
                    end
                end
            end
            if numLeft > 0 then
                for _, reagent in ipairs(lure.reagents) do
                    local totalNeed = reagent.count * numLeft
                    local have = C_Item.GetItemCount(reagent.itemID, true, false, true, true) or 0
                    local need = math.max(totalNeed - have, 0)
                    if need > 0 then
                        missing[reagent.itemID] = (missing[reagent.itemID] or 0) + need
                    end
                end
            end
        end
    end
    return missing
end

---------------------------------------------------------------------------
-- AH integration
---------------------------------------------------------------------------

local function InstallAHHook()
    if ahHookInstalled then return end
    ahHookInstalled = true

    local hookFrame = CreateFrame("Frame")
    hookFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
    hookFrame:SetScript("OnEvent", function()
        local ahFrame = AuctionHouseFrame
        if not ahFrame or not ahFrame.CommoditiesBuyFrame then return end
        local buyDisplay = ahFrame.CommoditiesBuyFrame.BuyDisplay
        if not buyDisplay or buyDisplay._ddtMBHooked then return end
        buyDisplay._ddtMBHooked = true

        hooksecurefunc(buyDisplay, "SetItemIDAndPrice", function(self, itemID)
            if not itemID then return end
            local db = GetOwnDB()
            if not db or not db.ahAutofillQuantity then return end
            if db.showReagents == false then return end

            local missingReagents = GetMissingReagents()
            local needed = missingReagents[itemID]
            -- TODO: check consumable stock targets too
            if needed and needed > 0 then
                C_Timer.After(0.1, function()
                    if self:GetItemID() == itemID then
                        self:GetAuctionHouseFrame():TriggerEvent(
                            AuctionHouseFrameMixin.Event.CommoditiesQuantitySelectionChanged, needed)
                    end
                end)
            end
        end)
    end)
end

local function CreateAuctionatorShoppingList()
    local loaded = C_AddOns.IsAddOnLoaded("Auctionator")
    if not loaded then
        DjinniMsg("Auctionator is not loaded.")
        return false
    end

    local searchStrings = {}

    -- Missing lure reagents
    local missingReagents = GetMissingReagents()
    for itemID, count in pairs(missingReagents) do
        local itemName = C_Item.GetItemNameByID(itemID)
        if itemName and count > 0 then
            table.insert(searchStrings, Auctionator.API.v1.ConvertToSearchString(
                "DjinnisDataTexts",
                { searchString = itemName, isExact = true, categoryKey = "", tier = "", quantity = count }
            ))
        end
    end

    -- TODO: missing consumables with stock targets

    if #searchStrings > 0 then
        Auctionator.API.v1.CreateShoppingList("DjinnisDataTexts", "DDT Beast Reagents", searchStrings)
        DjinniMsg("Auctionator shopping list updated (" .. #searchStrings .. " items).")
        return true
    else
        DjinniMsg("All reagents are stocked!")
        return false
    end
end

local function CreateBuffShoppingList()
    local loaded = C_AddOns.IsAddOnLoaded("Auctionator")
    if not loaded then
        DjinniMsg("Auctionator is not loaded.")
        return false
    end

    local searchStrings = {}
    for _, cons in ipairs(CONSUMABLES) do
        local have = C_Item.GetItemCount(cons.itemID, true, false, true, true) or 0
        local itemName = C_Item.GetItemNameByID(cons.itemID) or cons.name
        if itemName then
            table.insert(searchStrings, Auctionator.API.v1.ConvertToSearchString(
                "DjinnisDataTexts",
                { searchString = itemName, isExact = true, categoryKey = "", tier = "", quantity = math.max(1 - have, 0) }
            ))
        end
    end

    if #searchStrings > 0 then
        Auctionator.API.v1.CreateShoppingList("DjinnisDataTexts", "DDT Beast Buffs", searchStrings)
        DjinniMsg("Buff shopping list updated (" .. #searchStrings .. " items: Tea, Phial, Root Crab).")
        return true
    end
    return false
end

local function CreateZoneShoppingList(lureIndex)
    local lure = LURES[lureIndex]
    if not lure or not lure.reagents then
        DjinniMsg("No reagents needed for " .. (lure and lure.name or "this beast"))
        return false
    end

    local loaded = C_AddOns.IsAddOnLoaded("Auctionator")
    if not loaded then
        DjinniMsg("Auctionator is not loaded.")
        return false
    end

    local searchStrings = {}
    for _, reagent in ipairs(lure.reagents) do
        local have = C_Item.GetItemCount(reagent.itemID, true, false, true, true) or 0
        local need = math.max(reagent.count - have, 0)
        local itemName = C_Item.GetItemNameByID(reagent.itemID)
        if itemName then
            table.insert(searchStrings, Auctionator.API.v1.ConvertToSearchString(
                "DjinnisDataTexts",
                { searchString = itemName, isExact = true, categoryKey = "", tier = "", quantity = need }
            ))
        end
    end

    if #searchStrings > 0 then
        Auctionator.API.v1.CreateShoppingList("DjinnisDataTexts", "DDT " .. lure.name .. " Reagents", searchStrings)
        DjinniMsg(lure.color .. lure.name .. "|r reagent shopping list updated.")
        return true
    else
        DjinniMsg(lure.color .. lure.name .. "|r reagents fully stocked!")
        return false
    end
end

local function ExecuteRowAction(action, lureIndex)
    if not action or action == "none" then return end
    local lure = LURES[lureIndex]
    if not lure then return end

    if action == "waypoint" then
        if lure.waypoint then
            ns.SetWaypoint(lure.waypoint.map, lure.waypoint.x, lure.waypoint.y,
                "Waypoint: " .. lure.color .. lure.name .. "|r")
        end

    elseif action == "shopzone" then
        CreateZoneShoppingList(lureIndex)

    elseif action == "craftlure" then
        if lure.recipeID then
            C_TradeSkillUI.OpenRecipe(lure.recipeID)
        else
            DjinniMsg("No recipe found for " .. lure.color .. lure.name .. "|r")
        end

    elseif action == "openmap" then
        if lure.waypoint then
            OpenWorldMap(lure.waypoint.map)
        end
    end
end

---------------------------------------------------------------------------
-- Loot summary helpers
---------------------------------------------------------------------------

local function GetGlobalLootToday()
    local chars = GetCharsDB()
    if not chars then return {} end
    local totals = {}
    for _, charData in pairs(chars) do
        local loot = charData.loot
        if loot then
            -- Auto-reset if daily reset passed
            if loot.resetTime and loot.resetTime < GetLastDailyReset() then
                loot.thisReset = {}
                loot.perBeastReset = {}
                loot.prices = {}
                loot.resetTime = GetServerTime()
            end
            for id, count in pairs(loot.thisReset or {}) do
                totals[id] = (totals[id] or 0) + count
            end
        end
    end
    return totals
end

local function GetGlobalLootAllTime()
    local chars = GetCharsDB()
    if not chars then return {} end
    local totals = {}
    for _, charData in pairs(chars) do
        if charData.loot then
            for id, count in pairs(charData.loot.allTime or {}) do
                totals[id] = (totals[id] or 0) + count
            end
        end
    end
    return totals
end

---------------------------------------------------------------------------
-- Label template expansion
---------------------------------------------------------------------------

local function ExpandLabel(template)
    local result = template
    local E = ns.ExpandTag
    result = E(result, "kills", tostring(MajesticBeast.killsDoneToday))
    result = E(result, "total", tostring(MajesticBeast.killsTotal))
    result = E(result, "next", MajesticBeast.nextBeastName or "Done")
    result = E(result, "kp", string.format("%d/%d", MajesticBeast.weeklyKPEarned, MajesticBeast.weeklyKPTotal))
    return result
end

MajesticBeast.ExpandLabel = ExpandLabel

---------------------------------------------------------------------------
-- LDB Data Object
---------------------------------------------------------------------------

local dataobj = LDB:NewDataObject("DDT-MajesticBeast", {
    type  = "data source",
    text  = "Beasts",
    icon  = "Interface\\Icons\\INV_10_Skinning_Consumable_Lure_Beast",
    label = "DDT - Majestic Beast",
    OnEnter = function(self)
        MajesticBeast:ShowTooltip(self)
    end,
    OnLeave = function(self)
        MajesticBeast:StartHideTimer()
    end,
    OnClick = function(self, button)
        local db = MajesticBeast:GetDB()
        local action = DDT:ResolveClickAction(button, db.clickActions or {})
        MajesticBeast:ExecuteAction(action)
    end,
})
MajesticBeast.dataobj = dataobj

---------------------------------------------------------------------------
-- Action executor
---------------------------------------------------------------------------

function MajesticBeast:ExecuteAction(action)
    if not action or action == "none" then return end

    if action == "waypoint" then
        if not self.nextBeastIndex then
            DjinniMsg("All beasts done for today!")
            return
        end
        local lure = LURES[self.nextBeastIndex]
        if lure and lure.waypoint then
            ns.SetWaypoint(lure.waypoint.map, lure.waypoint.x, lure.waypoint.y,
                "Waypoint: " .. lure.color .. lure.name .. "|r")
        end

    elseif action == "openmap" then
        if not self.nextBeastIndex then
            DjinniMsg("All beasts done for today!")
            return
        end
        local lure = LURES[self.nextBeastIndex]
        if lure and lure.waypoint then
            OpenWorldMap(lure.waypoint.map)
        end

    elseif action == "shoppinglist" then
        CreateAuctionatorShoppingList()

    elseif action == "bufflist" then
        CreateBuffShoppingList()

    elseif action == "openmbt" then
        -- Toggle MBT window if the addon is loaded
        if MajesticBeastTracker_Toggle then
            MajesticBeastTracker_Toggle()
        elseif SlashCmdList and SlashCmdList["MBT"] then
            SlashCmdList["MBT"]("")
        else
            DjinniMsg("MajesticBeastTracker addon is not loaded.")
        end

    elseif action == "opensettings" then
        if DDT.settingsCategoryID then
            Settings.OpenToCategory(DDT.settingsCategoryID)
        end
    end
end

---------------------------------------------------------------------------
-- Event handling
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

function MajesticBeast:Init()
    self.charKey = GetCharKey()

    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            self.charKey = GetCharKey()
            DetectSkinningAndTalent(self.charKey)
            SyncKillsFromQuests(self.charKey)
            RefreshWeeklies(self.charKey)
            self:UpdateData()
            -- Delayed re-check (APIs may not be ready immediately)
            C_Timer.After(5, function()
                DetectSkinningAndTalent(self.charKey)
                SyncKillsFromQuests(self.charKey)
                RefreshWeeklies(self.charKey)
                self:UpdateData()
            end)

        elseif event == "PLAYER_REGEN_DISABLED" then
            preCombatSnapshot = SnapshotTrackedItems()

        elseif event == "QUEST_TURNED_IN" then
            local questID = ...
            if questToIndex[questID] then
                local lureIdx = questToIndex[questID]
                local charData = EnsureCharData(self.charKey)
                if charData then
                    charData.lures[LURES[lureIdx].name] = GetServerTime()
                    local _, class = UnitClass("player")
                    charData.class = class
                    charData.hasSkinning = true
                    if LURES[lureIdx].requiredPoints > (charData.talentPoints or 0) then
                        charData.talentPoints = LURES[lureIdx].requiredPoints
                    end
                end
                -- Start loot tracking
                pendingLootBeast = LURES[lureIdx].name
                pendingLootSnapshot = preCombatSnapshot or SnapshotTrackedItems()
                preCombatSnapshot = nil
                pendingLootTime = GetTime()
                pendingLootAccum = {}
                -- Auto-finalize after 5s
                C_Timer.After(5, function()
                    if pendingLootBeast then
                        FinalizePendingLoot()
                        self:UpdateData()
                    end
                end)
                self:UpdateData()
            end
            if weeklyQuestIDs[questID] then
                C_Timer.After(1, function()
                    RefreshWeeklies(self.charKey)
                    self:UpdateData()
                end)
            end

        elseif event == "BAG_UPDATE_DELAYED" then
            SyncKillsFromQuests(self.charKey, true)
            if pendingLootBeast and (GetTime() - pendingLootTime) > 15 then
                FinalizePendingLoot()
            end
            self:UpdateData()

        elseif event == "LOOT_CLOSED" then
            SyncKillsFromQuests(self.charKey, true)
            if pendingLootBeast then
                C_Timer.After(0.5, function() AccumulatePendingLoot() end)
            end
            self:UpdateData()

        elseif event == "SKILL_LINES_CHANGED" then
            DetectSkinningAndTalent(self.charKey)
            self:UpdateData()
        end
    end)

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("QUEST_TURNED_IN")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:RegisterEvent("LOOT_CLOSED")
    eventFrame:RegisterEvent("SKILL_LINES_CHANGED")

    -- Install AH hook
    InstallAHHook()

    self:UpdateData()
end

---------------------------------------------------------------------------
-- Data collection
---------------------------------------------------------------------------

function MajesticBeast:GetDB()
    return ns.db and ns.db.majesticbeast or DEFAULTS
end

function MajesticBeast:UpdateData()
    local chars = GetCharsDB()
    local charData = chars and chars[self.charKey]

    -- Kill count for current character
    local killsDone = 0
    local killsPossible = 0
    local nextBeastIdx = nil

    if charData and charData.hasSkinning then
        self.hasSkinning = true
        self.talentPoints = charData.talentPoints or 0
        self.killStatus = {}

        for i, lure in ipairs(LURES) do
            if CanSeeLure(charData, i) then
                killsPossible = killsPossible + 1
                local ts = charData.lures and charData.lures[lure.name]
                if ts and not IsLureReady(ts) then
                    killsDone = killsDone + 1
                    self.killStatus[lure.name] = true
                else
                    self.killStatus[lure.name] = false
                    if not nextBeastIdx then
                        nextBeastIdx = i
                    end
                end
            end
        end
    else
        self.hasSkinning = false
        self.talentPoints = 0
        self.killStatus = {}
    end

    self.killsDoneToday = killsDone
    self.killsTotal = killsPossible > 0 and killsPossible or #LURES
    self.nextBeastIndex = nextBeastIdx
    self.nextBeastName = nextBeastIdx and LURES[nextBeastIdx].name or nil

    -- Weekly KP
    self.weeklyKPEarned = 0
    self.weeklyKPTotal = 0
    if charData and charData.hasSkinning and charData.weeklies then
        for _, w in ipairs(SKINNING_WEEKLIES) do
            if w.dmf and not IsDarkmoonFaireUp() then
                -- Skip DMF when not active
            else
                if w.mode == "each" then
                    local completed = charData.weeklies[w.key] or 0
                    self.weeklyKPEarned = self.weeklyKPEarned + (completed * w.kp)
                    self.weeklyKPTotal = self.weeklyKPTotal + (#w.questIDs * w.kp)
                elseif w.mode == "rotation" then
                    local done = charData.weeklies[w.key]
                    if done then self.weeklyKPEarned = self.weeklyKPEarned + w.kp end
                    self.weeklyKPTotal = self.weeklyKPTotal + w.kp
                else
                    local done = charData.weeklies[w.key]
                    if done then self.weeklyKPEarned = self.weeklyKPEarned + w.kp end
                    self.weeklyKPTotal = self.weeklyKPTotal + w.kp
                end
            end
        end
    end

    -- Update LDB
    local db = self:GetDB()
    dataobj.text = ExpandLabel(db.labelTemplate)

    -- Refresh tooltip if visible
    if tooltipFrame and tooltipFrame:IsShown() then
        self:BuildTooltipContent()
    end
end

---------------------------------------------------------------------------
-- Tooltip frame / pools
---------------------------------------------------------------------------

local function GetRow(parent, index)
    if rowPool[index] then
        rowPool[index]:Show()
        return rowPool[index]
    end
    local row = CreateFrame("Button", nil, parent)
    row:RegisterForClicks("AnyUp")
    row:SetHeight(ns.ROW_HEIGHT)
    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, 0.08)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.text = ns.FontString(row, "DDTFontNormal")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.text:SetJustifyH("LEFT")

    row.status = ns.FontString(row, "DDTFontNormal")
    row.status:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.status:SetJustifyH("RIGHT")

    row.activeBar = row:CreateTexture(nil, "BACKGROUND")
    row.activeBar:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.activeBar:SetSize(3, ns.ROW_HEIGHT - 4)
    row.activeBar:SetColorTexture(0.2, 0.8, 0.2, 0.8)

    row:SetScript("OnEnter", function() MajesticBeast:CancelHideTimer() end)
    row:SetScript("OnLeave", function() MajesticBeast:StartHideTimer() end)

    rowPool[index] = row
    return row
end

local function GetHeader(parent, index)
    if headerPool[index] then
        headerPool[index]:Show()
        return headerPool[index]
    end
    local hdr = ns.FontString(parent, "DDTFontNormal")
    hdr:SetJustifyH("LEFT")
    hdr:SetTextColor(1, 0.82, 0)
    headerPool[index] = hdr
    return hdr
end

local function GetSeparator(parent, index)
    if separatorPool[index] then
        separatorPool[index]:Show()
        return separatorPool[index]
    end
    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetColorTexture(0.3, 0.3, 0.3, 0.5)
    separatorPool[index] = sep
    return sep
end

-- Secure lure buttons (one per beast, created once)
local lureButtons = {}

local function GetLureButton(parent, index)
    if lureButtons[index] then
        lureButtons[index]:Show()
        return lureButtons[index]
    end

    local row = CreateFrame("Button", "DDTMBLure" .. index, parent, "SecureActionButtonTemplate")
    row:RegisterForClicks("AnyUp", "AnyDown")
    row:SetHeight(ns.ROW_HEIGHT)

    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, 0.08)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.text = ns.FontString(row, "DDTFontNormal")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.text:SetJustifyH("LEFT")

    row.status = ns.FontString(row, "DDTFontNormal")
    row.status:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.status:SetJustifyH("RIGHT")

    row.activeBar = row:CreateTexture(nil, "BACKGROUND")
    row.activeBar:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.activeBar:SetSize(3, ns.ROW_HEIGHT - 4)
    row.activeBar:SetColorTexture(0.2, 0.8, 0.2, 0.8)

    row:SetScript("OnEnter", function() MajesticBeast:CancelHideTimer() end)
    row:SetScript("OnLeave", function() MajesticBeast:StartHideTimer() end)

    -- Secure item attribute: set item name for lure usage
    local lure = LURES[index]
    if lure then
        row:SetAttribute("type", "item")
        -- Set itemID as initial fallback
        row:SetAttribute("item", "item:" .. lure.itemID)
        -- Load proper item name asynchronously (more reliable)
        C_Item.RequestLoadItemDataByID(lure.itemID)
        local ticker
        ticker = C_Timer.NewTicker(1, function()
            local itemName = C_Item.GetItemNameByID(lure.itemID)
            if itemName and not InCombatLockdown() then
                row:SetAttribute("item", itemName)
                ticker:Cancel()
            end
        end, 10)
    end

    -- PreClick: only allow secure item use when the resolved action is "placelure"
    row:SetScript("PreClick", function(self, button)
        if InCombatLockdown() then return end
        local db = MajesticBeast:GetDB()
        local action = DDT:ResolveClickAction(button, db.rowClickActions or {})
        if action ~= "placelure" then
            self:SetAttribute("type", nil)
        else
            self:SetAttribute("type", "item")
        end
    end)

    -- PostClick: restore attribute and handle non-item actions
    row:SetScript("PostClick", function(self, button)
        if not InCombatLockdown() then
            self:SetAttribute("type", "item")
        end
        -- Throttle AnyUp/AnyDown double-fire
        local now = GetTime()
        if (now - (self._lastPostClick or 0)) < 0.1 then return end
        self._lastPostClick = now

        local db = MajesticBeast:GetDB()
        local action = DDT:ResolveClickAction(button, db.rowClickActions or {})
        if action and action ~= "placelure" and action ~= "none" then
            ExecuteRowAction(action, self._lureIndex)
        end
    end)

    lureButtons[index] = row
    return row
end

-- Secure consumable buttons (one per consumable, created once)
local consButtons = {}

local function GetConsButton(parent, index)
    if consButtons[index] then
        consButtons[index]:Show()
        return consButtons[index]
    end

    local cons = CONSUMABLES[index]
    local row = CreateFrame("Button", "DDTMBCons" .. index, parent, "SecureActionButtonTemplate")
    row:RegisterForClicks("AnyUp", "AnyDown")
    row:SetHeight(ns.ROW_HEIGHT)

    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, 0.08)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.text = ns.FontString(row, "DDTFontNormal")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.text:SetJustifyH("LEFT")

    row.status = ns.FontString(row, "DDTFontNormal")
    row.status:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.status:SetJustifyH("RIGHT")

    row.activeBar = row:CreateTexture(nil, "BACKGROUND")
    row.activeBar:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.activeBar:SetSize(3, ns.ROW_HEIGHT - 4)
    row.activeBar:SetColorTexture(0.2, 0.8, 0.2, 0.8)

    row:SetScript("OnEnter", function() MajesticBeast:CancelHideTimer() end)
    row:SetScript("OnLeave", function() MajesticBeast:StartHideTimer() end)

    -- Secure item use setup
    if cons then
        row:SetAttribute("type", "item")
        row:SetAttribute("item", "item:" .. cons.itemID)
        C_Item.RequestLoadItemDataByID(cons.itemID)
        local ticker
        ticker = C_Timer.NewTicker(1, function()
            local itemName = C_Item.GetItemNameByID(cons.itemID)
            if itemName and not InCombatLockdown() then
                row:SetAttribute("item", itemName)
                ticker:Cancel()
            end
        end, 10)
    end

    -- PreClick: only allow item use on LeftButton without modifiers
    row:SetScript("PreClick", function(self, button)
        if InCombatLockdown() then return end
        if button == "LeftButton" and not IsShiftKeyDown() and not IsControlKeyDown() and not IsAltKeyDown() then
            self:SetAttribute("type", "item")
        else
            self:SetAttribute("type", nil)
        end
    end)

    -- PostClick: restore attribute, handle right-click AH search
    row:SetScript("PostClick", function(self, button)
        if not InCombatLockdown() then
            self:SetAttribute("type", "item")
        end
        -- Throttle AnyUp/AnyDown double-fire
        local now = GetTime()
        if (now - (self._lastPostClick or 0)) < 0.1 then return end
        self._lastPostClick = now

        if button == "RightButton" then
            local aLoaded = C_AddOns.IsAddOnLoaded("Auctionator")
            if aLoaded then
                local itemName = C_Item.GetItemNameByID(cons.itemID) or cons.name
                local searchStrings = { Auctionator.API.v1.ConvertToSearchString(
                    "DjinnisDataTexts",
                    { searchString = itemName, isExact = true, categoryKey = "", tier = "" }
                ) }
                Auctionator.API.v1.CreateShoppingList("DjinnisDataTexts", "DDT " .. cons.name, searchStrings)
                DjinniMsg("AH search: " .. cons.name)
            else
                DjinniMsg("Auctionator is not loaded.")
            end
        end
    end)

    consButtons[index] = row
    return row
end

local function HideAllPooled()
    for _, row in pairs(rowPool) do row:Hide() end
    for _, btn in pairs(lureButtons) do btn:Hide() end
    for _, btn in pairs(consButtons) do btn:Hide() end
    for _, hdr in pairs(headerPool) do hdr:Hide() end
    for _, sep in pairs(separatorPool) do sep:Hide() end
end

---------------------------------------------------------------------------
-- Tooltip content
---------------------------------------------------------------------------

function MajesticBeast:BuildTooltipContent()
    -- Tooltip parents secure lure / consumable buttons; SetPoint and
    -- SetSize calls below are protected in combat. UpdateData refreshes
    -- (BAG_UPDATE_DELAYED, LOOT_CLOSED, ...) can fire during combat with
    -- the tooltip still visible from before pull, so gate the rebuild.
    -- Content goes stale until combat ends, then the next refresh path
    -- repopulates.
    if InCombatLockdown() then return end

    HideAllPooled()

    local f = tooltipFrame
    local c = f.content
    local db = self:GetDB()
    f.header:SetText("Majestic Beast Tracker")

    local rowIndex = 0
    local headerIndex = 0
    local sepIndex = 0
    local y = 0
    local ttWidth = db.tooltipWidth or 340

    -- ── Beast Routes (per-zone clickable rows with multi-char status) ──
    local chars = GetCharsDB()
    do
        headerIndex = headerIndex + 1
        local routeHdr = GetHeader(c, headerIndex)
        routeHdr:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
        routeHdr:SetText("Beast Routes")
        y = y - HEADER_HEIGHT

        -- Gather sorted alt list for multi-char columns
        local sortedChars = {}
        if chars then
            for key, cData in pairs(chars) do
                if cData.hasSkinning then
                    table.insert(sortedChars, { key = key, data = cData })
                end
            end
            table.sort(sortedChars, function(a, b) return a.key < b.key end)
        end
        local multiChar = #sortedChars > 1

        -- Column header row showing character names (only if multiple chars)
        if multiChar then
            rowIndex = rowIndex + 1
            local hdrRow = GetRow(c, rowIndex)
            hdrRow:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
            hdrRow:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
            hdrRow.icon:Hide()
            hdrRow.activeBar:Hide()
            hdrRow:SetScript("OnClick", nil)
            hdrRow.text:SetText("")
            -- Build right-aligned character name headers
            local names = {}
            for _, entry in ipairs(sortedChars) do
                local charName = entry.key:match("^(.-)%-") or entry.key
                local cc = GetClassColor(entry.data.class)
                names[#names + 1] = cc .. charName:sub(1, 4) .. "|r"
            end
            hdrRow.status:SetText(table.concat(names, " "))
            y = y - ns.ROW_HEIGHT
        end

        local charData = chars and chars[self.charKey]
        for i, lure in ipairs(LURES) do
            local row = GetLureButton(c, i)
            row._lureIndex = i
            row:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
            row:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
            row.activeBar:Hide()

            -- Lure icon
            local iconID = C_Item.GetItemIconByID(lure.itemID)
            if iconID then
                row.icon:SetTexture(iconID)
                row.icon:Show()
                row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            else
                row.icon:Hide()
                row.text:SetPoint("LEFT", row, "LEFT", 4, 0)
            end

            -- Reagent summary for current character
            local currentKilled = false
            if charData and charData.hasSkinning and CanSeeLure(charData, i) then
                local ts = charData.lures and charData.lures[lure.name]
                currentKilled = ts and not IsLureReady(ts)
            end

            local reagentInfo = ""
            if lure.reagents and not currentKilled then
                local parts = {}
                for _, reagent in ipairs(lure.reagents) do
                    local have = C_Item.GetItemCount(reagent.itemID, true, false, true, true) or 0
                    if have >= reagent.count then
                        parts[#parts + 1] = "|cff00ff00" .. have .. "/" .. reagent.count .. "|r"
                    else
                        parts[#parts + 1] = "|cffff9900" .. have .. "/" .. reagent.count .. "|r"
                    end
                end
                reagentInfo = " " .. table.concat(parts, " ")
            end

            row.text:SetText(lure.color .. lure.name .. "|r" .. reagentInfo)

            -- Status: multi-char icons or single-char text
            if multiChar then
                local icons = {}
                for _, entry in ipairs(sortedChars) do
                    local cData = entry.data
                    if CanSeeLure(cData, i) then
                        local ts = cData.lures and cData.lures[lure.name]
                        if ts and not IsLureReady(ts) then
                            icons[#icons + 1] = "|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t"
                        else
                            icons[#icons + 1] = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:0|t"
                        end
                    else
                        icons[#icons + 1] = "|cff555555-|r"
                    end
                end
                row.status:SetText(table.concat(icons, "  "))
            else
                local statusText
                if not charData or not charData.hasSkinning then
                    statusText = "|cff555555-|r"
                elseif not CanSeeLure(charData, i) then
                    statusText = "|cff555555Locked|r"
                elseif currentKilled then
                    statusText = "|cff00ff00Done|r"
                else
                    statusText = "|cffff3333Ready|r"
                end
                row.status:SetText(statusText)
            end

            -- Highlight next beast
            if i == self.nextBeastIndex then
                row.activeBar:Show()
            end

            y = y - ns.ROW_HEIGHT
        end

        -- Consumable buffs row
        y = y - 2
        headerIndex = headerIndex + 1
        local buffHdr = GetHeader(c, headerIndex)
        buffHdr:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
        buffHdr:SetText("Consumable Buffs")
        y = y - HEADER_HEIGHT

        for ci, cons in ipairs(CONSUMABLES) do
            local row = GetConsButton(c, ci)
            row:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
            row:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
            row.activeBar:Hide()

            local iconID = C_Item.GetItemIconByID(cons.itemID)
            if iconID then
                row.icon:SetTexture(iconID)
                row.icon:Show()
                row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            else
                row.icon:Hide()
                row.text:SetPoint("LEFT", row, "LEFT", 4, 0)
            end

            local have = C_Item.GetItemCount(cons.itemID, true, false, true, true) or 0
            local hasBuff = AuraUtil.FindAuraByName(cons.buffName, "player")
            local buffStatus
            if hasBuff then
                buffStatus = "|cff00ff00Active|r"
            elseif have > 0 then
                buffStatus = "|cffffff00x" .. have .. "|r"
            else
                buffStatus = "|cffff3333None|r"
            end

            row.text:SetText(cons.name)
            row.text:SetTextColor(0.9, 0.9, 0.9)
            row.status:SetText(buffStatus)
            y = y - ns.ROW_HEIGHT
        end
    end

    -- ── Reagent Status ───────────────────────────────────────
    if db.showReagents ~= false then
        local missingReagents = GetMissingReagents()
        local hasAnyMissing = false
        for _ in pairs(missingReagents) do hasAnyMissing = true; break end

        if hasAnyMissing then
            y = y - 4
            sepIndex = sepIndex + 1
            local sep = GetSeparator(c, sepIndex)
            sep:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
            sep:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
            y = y - 6

            headerIndex = headerIndex + 1
            local reagHdr = GetHeader(c, headerIndex)
            reagHdr:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
            reagHdr:SetText("Missing Reagents")
            y = y - HEADER_HEIGHT

            for itemID, count in pairs(missingReagents) do
                local itemName = C_Item.GetItemNameByID(itemID) or ("Item " .. itemID)
                rowIndex = rowIndex + 1
                local row = GetRow(c, rowIndex)
                row:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
                row:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
                row.activeBar:Hide()
                row:SetScript("OnClick", nil)

                local iconID = C_Item.GetItemIconByID(itemID)
                if iconID then
                    row.icon:SetTexture(iconID)
                    row.icon:Show()
                    row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
                else
                    row.icon:Hide()
                    row.text:SetPoint("LEFT", row, "LEFT", 4, 0)
                end

                row.text:SetText(itemName)
                row.text:SetTextColor(0.9, 0.9, 0.9)
                row.status:SetText("|cffff9900Need " .. count .. "|r")
                y = y - ns.ROW_HEIGHT
            end
        end
    end

    -- ── Loot Summary (today) ─────────────────────────────────
    if db.showLoot ~= false then
        local todayLoot = GetGlobalLootToday()
        local hasLoot = false
        for _ in pairs(todayLoot) do hasLoot = true; break end

        if hasLoot then
            y = y - 4
            sepIndex = sepIndex + 1
            local sep = GetSeparator(c, sepIndex)
            sep:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
            sep:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
            y = y - 6

            headerIndex = headerIndex + 1
            local lootHdr = GetHeader(c, headerIndex)
            lootHdr:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
            lootHdr:SetText("Loot Today")
            y = y - HEADER_HEIGHT

            -- Collect and sort by item name
            local lootLines = {}
            for id, count in pairs(todayLoot) do
                local itemName = C_Item.GetItemNameByID(id)
                if itemName then
                    table.insert(lootLines, { id = id, name = itemName, count = count })
                end
            end
            table.sort(lootLines, function(a, b) return a.name < b.name end)

            for _, entry in ipairs(lootLines) do
                rowIndex = rowIndex + 1
                local row = GetRow(c, rowIndex)
                row:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
                row:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
                row.activeBar:Hide()
                row:SetScript("OnClick", nil)

                local iconID = C_Item.GetItemIconByID(entry.id)
                if iconID then
                    row.icon:SetTexture(iconID)
                    row.icon:Show()
                    row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
                else
                    row.icon:Hide()
                    row.text:SetPoint("LEFT", row, "LEFT", 4, 0)
                end

                row.text:SetText(entry.name)
                row.text:SetTextColor(0.9, 0.9, 0.9)

                -- Show TSM value if available
                local priceStr = ""
                local price = GetTSMPrice(entry.id)
                if price and price > 0 then
                    priceStr = "  " .. ns.FormatGoldShort(price)
                end
                row.status:SetText("x" .. entry.count .. priceStr)
                y = y - ns.ROW_HEIGHT
            end
        end
    end

    -- ── Weekly Knowledge Points ──────────────────────────────
    if db.showWeeklyKP ~= false and self.hasSkinning then
        y = y - 4
        sepIndex = sepIndex + 1
        local sep = GetSeparator(c, sepIndex)
        sep:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
        sep:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
        y = y - 6

        headerIndex = headerIndex + 1
        local kpHdr = GetHeader(c, headerIndex)
        kpHdr:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
        kpHdr:SetText("Weekly Knowledge (" .. self.weeklyKPEarned .. "/" .. self.weeklyKPTotal .. " KP)")
        y = y - HEADER_HEIGHT

        local charData = chars and chars[self.charKey]
        if charData and charData.weeklies then
            for _, w in ipairs(SKINNING_WEEKLIES) do
                if w.dmf and not IsDarkmoonFaireUp() then
                    -- skip DMF when not up
                else
                    rowIndex = rowIndex + 1
                    local row = GetRow(c, rowIndex)
                    row:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
                    row:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
                    row.icon:Hide()
                    row.activeBar:Hide()
                    row:SetScript("OnClick", nil)
                    row.text:SetPoint("LEFT", row, "LEFT", 4, 0)
                    row.text:SetText("  " .. w.label .. " (" .. w.kp .. " KP)")

                    local val = charData.weeklies[w.key]
                    if w.mode == "each" then
                        local completed = val or 0
                        local total = #w.questIDs
                        if completed >= total then
                            row.status:SetText("|cff00ff00" .. completed .. "/" .. total .. "|r")
                            row.text:SetTextColor(0.5, 0.5, 0.5)
                        else
                            row.status:SetText("|cffff9900" .. completed .. "/" .. total .. "|r")
                            row.text:SetTextColor(0.9, 0.9, 0.9)
                        end
                    else
                        if val then
                            row.status:SetText("|cff00ff00Done|r")
                            row.text:SetTextColor(0.5, 0.5, 0.5)
                        else
                            row.status:SetText("|cffff3333Todo|r")
                            row.text:SetTextColor(0.9, 0.9, 0.9)
                        end
                    end
                    y = y - ns.ROW_HEIGHT
                end
            end
        end
    end

    -- ── Daily Reset Timer ────────────────────────────────────
    y = y - 4
    sepIndex = sepIndex + 1
    local sep3 = GetSeparator(c, sepIndex)
    sep3:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
    sep3:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
    y = y - 6

    rowIndex = rowIndex + 1
    local resetRow = GetRow(c, rowIndex)
    resetRow:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
    resetRow:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
    resetRow.icon:Hide()
    resetRow.activeBar:Hide()
    resetRow:SetScript("OnClick", nil)
    resetRow.text:SetPoint("LEFT", resetRow, "LEFT", 4, 0)
    resetRow.text:SetText("|cff888888Daily Reset|r")
    resetRow.text:SetTextColor(0.6, 0.6, 0.6)
    local secsUntilReset = C_DateAndTime.GetSecondsUntilDailyReset()
    resetRow.status:SetText(FormatTimeLeft(secsUntilReset))
    y = y - ns.ROW_HEIGHT

    -- Hint bar
    local hintText = DDT:BuildHintText(db.clickActions or {}, CLICK_ACTIONS)
    local rowHint = DDT:BuildHintText(db.rowClickActions or {}, ROW_CLICK_ACTIONS)
    if rowHint ~= "" then
        hintText = hintText .. "\n|cffaaaaaa" .. rowHint .. "|r"
    end
    f.hint:SetText(hintText ~= "" and hintText or "|cff888888Shift+Click: Shopping List|r")

    -- Finalize layout
    f:FinalizeLayout(ttWidth, math.abs(y))
end

---------------------------------------------------------------------------
-- Tooltip show/hide
---------------------------------------------------------------------------

function MajesticBeast:ShowTooltip(anchor)
    -- Once populated, the tooltip parents SecureActionButtonTemplate lure /
    -- consumable buttons; SetPoint/SetScale/SetWidth/Show on it are all
    -- protected in combat. Bail out entirely so we don't trip
    -- ADDON_ACTION_BLOCKED.
    if InCombatLockdown() then return end

    self:CancelHideTimer()
    if not tooltipFrame then
        tooltipFrame = ns.CreateTooltipFrame("DDTMajesticBeastTooltip", self)
    end
    local db = self:GetDB()
    ns.AnchorTooltip(tooltipFrame, anchor, db.tooltipGrowDirection)
    tooltipFrame:SetScale(db.tooltipScale or 1.0)
    self:UpdateData()
    self:BuildTooltipContent()
    tooltipFrame:Show()
end

function MajesticBeast:StartHideTimer()
    self:CancelHideTimer()
    hideTimer = C_Timer.NewTimer(ns.HIDE_DELAY, function()
        hideTimer = nil
        if not tooltipFrame then return end
        -- Tooltip parents SecureActionButtonTemplate lure/consumable buttons;
        -- hiding it in combat is protected. Reschedule until combat ends.
        if InCombatLockdown() then
            MajesticBeast:StartHideTimer()
            return
        end
        tooltipFrame:Hide()
    end)
end

function MajesticBeast:CancelHideTimer()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
end

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------

MajesticBeast.settingsLabel = "Majestic Beast"

function MajesticBeast:BuildSettingsPanel(panel)
    local W = ns.SettingsWidgets
    local r = panel.refreshCallbacks
    local db = function() return ns.db.majesticbeast end

    W.AddLabelEditBox(panel, "kills total next kp",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateData() end, r, {
        { "Default",    "<kills>/<total> Beasts" },
        { "Next Beast", "Next: <next>" },
        { "With KP",    "<kills>/<total> | KP <kp>" },
        { "Kills Only", "<kills> Killed" },
    })

    local body = W.AddSection(panel, "Tooltip", true)
    local y = 0
    y = W.AddSliderPair(body, y,
        { label = "Scale", min = 0.5, max = 2.0, step = 0.05,
          get = function() return db().tooltipScale end,
          set = function(v) db().tooltipScale = v end },
        { label = "Width", min = 200, max = 600, step = 10,
          get = function() return db().tooltipWidth end,
          set = function(v) db().tooltipWidth = v end }, r)
    y = W.AddSliderPair(body, y,
        { label = "Max Height", min = 100, max = 1000, step = 10,
          get = function() return db().tooltipMaxHeight end,
          set = function(v) db().tooltipMaxHeight = v end },
        nil, r)
    y = W.AddTooltipGrowDirection(body, y, db, r)
    y = W.AddTooltipCopyFrom(body, y, "majesticbeast", db, r)
    W.EndSection(panel, y)

    local body2 = W.AddSection(panel, "Display")
    y = 0
    y = W.AddCheckbox(body2, y, "Show Reagents",
        function() return db().showReagents end,
        function(v) db().showReagents = v end, r)
    y = W.AddCheckbox(body2, y, "Show Loot",
        function() return db().showLoot end,
        function(v) db().showLoot = v end, r)
    y = W.AddCheckbox(body2, y, "Show Weekly KP",
        function() return db().showWeeklyKP end,
        function(v) db().showWeeklyKP = v end, r)
    W.EndSection(panel, y)

    local body3 = W.AddSection(panel, "Auction House")
    y = 0
    y = W.AddCheckbox(body3, y, "Autofill AH Quantity",
        function() return db().ahAutofillQuantity end,
        function(v) db().ahAutofillQuantity = v end, r)
    -- TODO: consumable stock target sliders per item
    y = W.AddNote(body3, y, "Shift+Click: Create Auctionator shopping list")
    W.EndSection(panel, y)

    ns.AddModuleClickActionsSection(panel, r, "majesticbeast", CLICK_ACTIONS)
    ns.AddRowClickActionsSection(panel, r, "majesticbeast", ROW_CLICK_ACTIONS)
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("majesticbeast", MajesticBeast, DEFAULTS)

-- TODO: Warband bank deposit integration
-- TODO: Consumable stock tracking with per-item targets
-- TODO: Route order customization / per-beast skip toggles
-- TODO: Profession stats display (Skill/Perception/Finesse/Deftness)
-- TODO: Auto-waypoint to next beast after kill
