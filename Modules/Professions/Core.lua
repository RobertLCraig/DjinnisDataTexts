-- Djinni's Data Texts - Professions Framework: Core
-- Dynamic LDB broker creation, tooltip rendering, settings, KP engine.
-- Loads AFTER Data.lua and all Data_*.lua files.
local addonName, ns = ...
local DDT = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local Professions = {}
ns.Professions = Professions

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

local TOOLTIP_PADDING = ns.TOOLTIP_PADDING
local HEADER_HEIGHT   = 18
local ICON_SIZE       = 18
local SECTION_GAP     = 8

-- Last daily reset timestamp (server time)
local function GetLastDailyReset()
    return GetServerTime() + C_DateAndTime.GetSecondsUntilDailyReset() - 86400
end

-- DMF up check (first Sunday of month for ~7 days).
-- Calculated locally instead of querying calendar API because
-- C_Calendar requires the frame to be open and fires async events.
local function IsDarkmoonFaireUp()
    local dayOfWeek = tonumber(date("%w"))
    local dayOfMonth = tonumber(date("%e"))
    local firstSundayOfMonth = ((dayOfMonth - (dayOfWeek + 1)) % 7) + 1
    local daysSinceFirstSunday = dayOfMonth - firstSundayOfMonth
    return daysSinceFirstSunday >= 0 and daysSinceFirstSunday <= 6
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

-- LDB broker objects: { [profKey] = dataobj }
local brokers = {}

-- Per-profession runtime state: { [profKey] = { profIndex, profDef, profData, skillLevel, ... } }
local profState = {}

-- Tooltip frames: { [profKey] = frame }
local tooltipFrames = {}

-- Hide timers: { [profKey] = timer }
local hideTimers = {}

-- Row/header pools per profession: { [profKey] = { rows = {}, headers = {} } }
local pools = {}

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
    activeExpansion  = "midnight",
    tooltipScale     = 1.0,
    tooltipMaxHeight = 500,
    tooltipWidth     = 380,
    perProf          = {},   -- per-profession settings (lazily populated)
    chars            = {},   -- per-character per-profession state
}

local PROF_DEFAULTS = {
    labelTemplate    = "<name>: <kp_earned>/<kp_total> KP",
    showKPSources    = true,
    hideKnownKP      = true,
    showBuffs        = true,
    showActivities   = true,
    showTimers       = true,
    tooltipScale     = nil,   -- nil = inherit from module-level
    tooltipWidth     = nil,
    tooltipMaxHeight = nil,
    showHintBar      = true,
    clickActions = {
        leftClick       = "openprofessions",
        rightClick      = "none",
        middleClick     = "none",
        shiftLeftClick  = "shoppinglist",
        shiftRightClick = "none",
        ctrlLeftClick   = "opensettings",
        ctrlRightClick  = "none",
        altLeftClick    = "none",
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
-- DB Accessors
---------------------------------------------------------------------------

function Professions:GetDB()
    return ns.db and ns.db.professions or DEFAULTS
end

--- Get per-profession settings, lazily populating defaults.
--- Lazy init instead of pre-creating all 11 professions because most
--- characters only have 2 professions - no need to pollute saved vars.
function Professions:GetProfDB(profKey)
    local db = self:GetDB()
    if not db.perProf then db.perProf = {} end
    if not db.perProf[profKey] then
        db.perProf[profKey] = {}
    end
    -- Shallow-copy table defaults so each profession gets its own copy
    local pdb = db.perProf[profKey]
    for k, v in pairs(PROF_DEFAULTS) do
        if pdb[k] == nil then
            if type(v) == "table" then
                pdb[k] = {}
                for k2, v2 in pairs(v) do pdb[k][k2] = v2 end
            else
                pdb[k] = v
            end
        end
    end
    return pdb
end

--- Get or create per-character, per-profession, per-expansion data
function Professions:GetCharData(profKey, expansion)
    local db = self:GetDB()
    local charKey = self.charKey
    if not charKey then return nil end
    if not db.chars then db.chars = {} end
    if not db.chars[charKey] then db.chars[charKey] = {} end
    if not db.chars[charKey][profKey] then db.chars[charKey][profKey] = {} end
    if expansion then
        if not db.chars[charKey][profKey][expansion] then
            db.chars[charKey][profKey][expansion] = {}
        end
        return db.chars[charKey][profKey][expansion]
    end
    return db.chars[charKey][profKey]
end

--- Resolve effective tooltip setting (per-prof override → module-level fallback)
local function ResolveTooltipSetting(pdb, db, key)
    if pdb[key] ~= nil then return pdb[key] end
    return db[key]
end

---------------------------------------------------------------------------
-- Profession Detection
---------------------------------------------------------------------------

--- Detect and register the character's professions
function Professions:DetectProfessions()
    local prof1, prof2 = GetProfessions()
    local indices = {}
    if prof1 then indices[#indices + 1] = prof1 end
    if prof2 then indices[#indices + 1] = prof2 end

    local db = self:GetDB()
    local expansion = db.activeExpansion or "midnight"

    for _, profIndex in ipairs(indices) do
        local name, texture, skillLevel, maxSkillLevel, _, _, skillLineID, bonusSkill = GetProfessionInfo(profIndex)
        local profKey = ns.PROF_SKILL_TO_KEY[skillLineID]
        if profKey then
            local profDef = ns.PROF_DEFS[profKey]
            local expData = profDef.expansions[expansion]
            -- Detection via expansion-specific spell rather than skill line
            -- because skill line exists even if the player hasn't trained yet.
            local hasExpansion = expData and C_SpellBook and C_SpellBook.IsSpellKnown(expData.spellID)
            self:RegisterProfession(profKey, profDef, profIndex, texture, hasExpansion)
        end
    end
end

--- Register a profession: create LDB broker and runtime state
function Professions:RegisterProfession(profKey, profDef, profIndex, texture, hasExpansion)
    if brokers[profKey] then
        -- Already registered - just update state
        local state = profState[profKey]
        state.profIndex = profIndex
        state.hasExpansion = hasExpansion
        return
    end

    -- Initialize runtime state
    profState[profKey] = {
        profIndex    = profIndex,
        profKey      = profKey,
        profDef      = profDef,
        profData     = ns.ProfessionData[profKey],   -- may be nil if data file not loaded yet
        hasExpansion = hasExpansion,
        skillLevel   = 0,
        maxSkillLevel = 0,
        bonusSkill   = 0,
        concentration    = 0,
        maxConcentration = 0,
        weeklyKPEarned   = 0,
        weeklyKPTotal    = 0,
    }

    -- Initialize pools
    pools[profKey] = { rows = {}, headers = {}, separators = {} }

    -- Create LDB broker
    local icon = texture or profDef.fallbackIcon
    brokers[profKey] = LDB:NewDataObject("DDT-Prof-" .. profDef.name, {
        type  = "data source",
        text  = profDef.name,
        icon  = icon,
        label = "DDT - Prof - " .. profDef.name,
        OnEnter = function(anchor)
            Professions:ShowTooltip(profKey, anchor)
        end,
        OnLeave = function()
            Professions:StartHideTimer(profKey)
        end,
        OnClick = function(_, button)
            local pdb = Professions:GetProfDB(profKey)
            local action = DDT:ResolveClickAction(button, pdb.clickActions or {})
            Professions:ExecuteClickAction(profKey, action)
        end,
    })
end

---------------------------------------------------------------------------
-- Data Update
---------------------------------------------------------------------------

function Professions:UpdateData()
    for profKey, state in pairs(profState) do
        self:UpdateProfession(profKey)
    end
end

function Professions:UpdateProfession(profKey)
    local state = profState[profKey]
    if not state then return end

    -- Update skill level
    local name, texture, skillLevel, maxSkillLevel, _, _, _, bonusSkill = GetProfessionInfo(state.profIndex)
    state.skillLevel    = skillLevel or 0
    state.maxSkillLevel = maxSkillLevel or 0
    state.bonusSkill    = bonusSkill or 0

    -- Update concentration
    local db = self:GetDB()
    local expansion = db.activeExpansion or "midnight"
    local expData = state.profDef.expansions[expansion]
    if expData then
        local concCurrencyID = nil
        if C_TradeSkillUI and C_TradeSkillUI.GetConcentrationCurrencyID then
            concCurrencyID = C_TradeSkillUI.GetConcentrationCurrencyID(expData.skillLine)
        end
        if concCurrencyID and concCurrencyID ~= 0 then
            local currInfo = C_CurrencyInfo.GetCurrencyInfo(concCurrencyID)
            if currInfo then
                state.concentration    = currInfo.quantity or 0
                state.maxConcentration = currInfo.maxQuantity or 0
            end
        end
    end

    -- Calculate KP totals
    local kpEarned, kpTotal = self:CalcKPTotals(profKey, expansion)
    state.weeklyKPEarned = kpEarned
    state.weeklyKPTotal  = kpTotal

    -- Update label
    self:UpdateLabel(profKey)

    -- Refresh tooltip if visible
    local tf = tooltipFrames[profKey]
    if tf and tf:IsShown() then
        self:PopulateTooltip(profKey)
    end
end

--- Update the LDB text label for a profession
function Professions:UpdateLabel(profKey)
    local state = profState[profKey]
    local pdb = self:GetProfDB(profKey)
    local fmt = pdb.labelTemplate or PROF_DEFAULTS.labelTemplate

    local result = fmt
    result = ns.ExpandTag(result, "name", state.profDef.name)
    result = ns.ExpandTag(result, "skill", state.skillLevel)
    result = ns.ExpandTag(result, "maxskill", state.maxSkillLevel)
    result = ns.ExpandTag(result, "kp_earned", state.weeklyKPEarned)
    result = ns.ExpandTag(result, "kp_total", state.weeklyKPTotal)
    result = ns.ExpandTag(result, "concentration", state.concentration)

    -- Majestic Beast tags (Skinning)
    if state.profData and state.profData.activities and state.profData.activities.majesticBeasts then
        local mbData = state.profData.activities.majesticBeasts
        local charData = self:GetCharData(profKey, self:GetDB().activeExpansion or "midnight")
        local lureKills = charData and charData.activities and charData.activities.lureKills or {}
        local points = charData and charData.activities and charData.activities.talentPoints or 0
        local kills, total, nextBeast = 0, 0, ""
        local lastReset = GetLastDailyReset()
        for _, lure in ipairs(mbData.lures) do
            if points >= lure.requiredPoints then
                total = total + 1
                if lureKills[lure.name] and lureKills[lure.name] >= lastReset then
                    kills = kills + 1
                elseif nextBeast == "" then
                    nextBeast = lure.name
                end
            end
        end
        result = ns.ExpandTag(result, "mb_kills", kills)
        result = ns.ExpandTag(result, "mb_total", total)
        result = ns.ExpandTag(result, "mb_next", nextBeast)
    end

    local broker = brokers[profKey]
    if broker then
        broker.text = result
    end
end

---------------------------------------------------------------------------
-- KP Calculation
---------------------------------------------------------------------------

--- Calculate total KP earned and available for a profession+expansion
function Professions:CalcKPTotals(profKey, expansion)
    local profData = ns.ProfessionData[profKey]
    if not profData or not profData.kpSources then return 0, 0 end

    local charData = self:GetCharData(profKey, expansion)
    local kpCompleted = charData and charData.kpCompleted or {}
    local earned, total = 0, 0

    local kp = profData.kpSources

    -- Unique Treasures
    if kp.uniqueTreasures then
        for _, src in ipairs(kp.uniqueTreasures) do
            total = total + src.kp
            if C_QuestLog.IsQuestFlaggedCompleted(src.questID) then
                earned = earned + src.kp
            end
        end
    end

    -- Unique Books
    if kp.uniqueBooks then
        for _, src in ipairs(kp.uniqueBooks) do
            total = total + src.kp
            local qid = type(src.questID) == "table" and src.questID[1] or src.questID
            if qid and C_QuestLog.IsQuestFlaggedCompleted(qid) then
                earned = earned + src.kp
            end
        end
    end

    -- Weeklies
    if kp.weeklies then
        for _, w in ipairs(kp.weeklies) do
            if w.dmf and not IsDarkmoonFaireUp() then
                -- Skip DMF when not active
            elseif w.mode == "each" then
                -- Each quest ID counts separately
                for _, qid in ipairs(w.questIDs) do
                    total = total + w.kp
                    if C_QuestLog.IsQuestFlaggedCompleted(qid) then
                        earned = earned + w.kp
                    end
                end
            elseif w.mode == "rotation" then
                -- Any one of the quest IDs being complete counts
                total = total + w.kp
                for _, qid in ipairs(w.questIDs) do
                    if C_QuestLog.IsQuestFlaggedCompleted(qid) then
                        earned = earned + w.kp
                        break
                    end
                end
            else
                -- Single quest
                total = total + w.kp
                if w.questIDs and w.questIDs[1] and C_QuestLog.IsQuestFlaggedCompleted(w.questIDs[1]) then
                    earned = earned + w.kp
                end
            end
        end
    end

    -- Weekly item
    if kp.weeklyItem then
        local wi = kp.weeklyItem
        total = total + wi.kp
        if wi.questID and C_QuestLog.IsQuestFlaggedCompleted(wi.questID) then
            earned = earned + wi.kp
        end
    end

    return earned, total
end

---------------------------------------------------------------------------
-- Tooltip: Show / Hide / Timer
---------------------------------------------------------------------------

function Professions:ShowTooltip(profKey, anchor)
    if not tooltipFrames[profKey] then
        tooltipFrames[profKey] = self:CreateTooltipFrame(profKey)
    end

    self:CancelHideTimer(profKey)

    -- Update data before showing
    self:UpdateProfession(profKey)

    local pdb = self:GetProfDB(profKey)
    local db = self:GetDB()
    local scale = ResolveTooltipSetting(pdb, db, "tooltipScale") or 1.0

    ns.AnchorTooltip(tooltipFrames[profKey], anchor, pdb.tooltipGrowDirection)
    tooltipFrames[profKey]:SetScale(scale)

    self:PopulateTooltip(profKey)
    tooltipFrames[profKey]:Show()
end

-- Per-profession pin state. When pinned[profKey] is true, the auto-hide
-- timer is suppressed so users can leave the tooltip open while running
-- a delve / craft session and click rows freely.
local pinned = {}

function Professions:StartHideTimer(profKey)
    self:CancelHideTimer(profKey)
    if pinned[profKey] then return end
    hideTimers[profKey] = C_Timer.NewTimer(ns.HIDE_DELAY, function()
        if tooltipFrames[profKey] then tooltipFrames[profKey]:Hide() end
        hideTimers[profKey] = nil
    end)
end

function Professions:TogglePin(profKey)
    if pinned[profKey] then
        pinned[profKey] = nil
        self:StartHideTimer(profKey)
    else
        pinned[profKey] = true
        self:CancelHideTimer(profKey)
        if tooltipFrames[profKey] and not tooltipFrames[profKey]:IsShown() then
            tooltipFrames[profKey]:Show()
        end
    end
end

function Professions:CancelHideTimer(profKey)
    if hideTimers[profKey] then
        hideTimers[profKey]:Cancel()
        hideTimers[profKey] = nil
    end
end

---------------------------------------------------------------------------
-- Tooltip: Frame Creation
---------------------------------------------------------------------------

function Professions:CreateTooltipFrame(profKey)
    local f = ns.CreateTooltipFrame(nil, {
        CancelTooltipHideTimer = function() Professions:CancelHideTimer(profKey) end,
        StartTooltipHideTimer  = function() Professions:StartHideTimer(profKey) end,
        GetDB = function() return Professions:GetProfDB(profKey) end,
    })

    f.headerExtra = 0
    return f
end

---------------------------------------------------------------------------
-- Tooltip: Row/Header Pool Helpers
---------------------------------------------------------------------------

local function GetOrCreateRow(profKey, parent, index)
    local pool = pools[profKey]
    if pool.rows[index] then
        pool.rows[index]:Show()
        return pool.rows[index]
    end

    local row = CreateFrame("Button", nil, parent)
    row:SetSize(360, ns.ROW_HEIGHT)
    row:EnableMouse(true)
    row:RegisterForClicks("AnyUp")

    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, 0.1)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:Hide()

    row.text = ns.FontString(row, "DDTFontNormal")
    row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 4, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetJustifyV("TOP")
    row.text:SetWordWrap(true)

    row.status = ns.FontString(row, "DDTFontSmall")
    row.status:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    row.status:SetJustifyH("RIGHT")
    row.status:SetJustifyV("TOP")

    row:SetScript("OnEnter", function()
        Professions:CancelHideTimer(profKey)
    end)

    row:SetScript("OnLeave", function()
        Professions:StartHideTimer(profKey)
    end)

    pool.rows[index] = row
    return row
end

---------------------------------------------------------------------------
-- Secure lure button pool (SecureActionButtonTemplate for Use Lure)
---------------------------------------------------------------------------

local lureButtons = {}  -- { [profKey] = { [index] = Button } }

local function GetOrCreateLureButton(profKey, parent, index, lure)
    if not lureButtons[profKey] then lureButtons[profKey] = {} end
    if lureButtons[profKey][index] then
        lureButtons[profKey][index]:Show()
        return lureButtons[profKey][index]
    end

    local row = CreateFrame("Button", "DDTProfLure_" .. profKey .. "_" .. index, parent, "SecureActionButtonTemplate")
    row:SetSize(360, ns.ROW_HEIGHT)
    row:EnableMouse(true)
    row:RegisterForClicks("AnyUp", "AnyDown")

    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, 0.1)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:Hide()

    row.text = ns.FontString(row, "DDTFontNormal")
    row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 4, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetJustifyV("TOP")
    row.text:SetWordWrap(true)

    row.status = ns.FontString(row, "DDTFontSmall")
    row.status:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    row.status:SetJustifyH("RIGHT")
    row.status:SetJustifyV("TOP")

    row:SetScript("OnEnter", function()
        Professions:CancelHideTimer(profKey)
    end)
    row:SetScript("OnLeave", function()
        Professions:StartHideTimer(profKey)
    end)

    -- Secure item attribute: set item for lure usage.
    -- Start with "item:<id>" (works immediately) then upgrade to the item
    -- name once loaded, because some WoW builds resolve "item:" slowly.
    row:SetAttribute("type", "item")
    row:SetAttribute("item", "item:" .. lure.itemID)
    C_Item.RequestLoadItemDataByID(lure.itemID)
    local ticker
    ticker = C_Timer.NewTicker(1, function()
        local itemName = C_Item.GetItemNameByID(lure.itemID)
        if itemName and not InCombatLockdown() then
            row:SetAttribute("item", itemName)
            ticker:Cancel()
        end
    end, 10)

    -- PreClick: gate secure item use to only the "placelure" action.
    -- Without this, every click on the row would try to use the lure item.
    -- Setting type=nil in PreClick suppresses the secure action for that click.
    row:SetScript("PreClick", function(self, button)
        if InCombatLockdown() then return end
        local pdb = Professions:GetProfDB(profKey)
        local action = DDT:ResolveClickAction(button, pdb.rowClickActions or {})
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
        -- RegisterForClicks("AnyUp","AnyDown") causes PostClick to fire twice
        -- per physical click. Throttle within 100ms to deduplicate.
        local now = GetTime()
        if (now - (self._lastPostClick or 0)) < 0.1 then return end
        self._lastPostClick = now

        local pdb = Professions:GetProfDB(profKey)
        local action = DDT:ResolveClickAction(button, pdb.rowClickActions or {})
        if action and action ~= "placelure" and action ~= "none" then
            Professions:ExecuteRowClickAction(profKey, action, self._lureIndex)
        end
    end)

    lureButtons[profKey][index] = row
    return row
end

--- Execute a row-level click action on a beast lure row
function Professions:ExecuteRowClickAction(profKey, action, lureIndex)
    if not action or action == "none" then return end
    local profData = ns.ProfessionData[profKey]
    if not profData or not profData.activities or not profData.activities.majesticBeasts then return end
    local lure = profData.activities.majesticBeasts.lures[lureIndex]
    if not lure then return end

    if action == "waypoint" then
        if lure.waypoint then
            ns.SetWaypoint(lure.waypoint.map, lure.waypoint.x, lure.waypoint.y,
                "Waypoint: " .. lure.color .. lure.name .. "|r")
        end

    elseif action == "craftlure" then
        if lure.recipeID then
            C_TradeSkillUI.OpenRecipe(lure.recipeID)
        else
            DDT:Print("No recipe found for " .. lure.color .. lure.name .. "|r")
        end

    elseif action == "shopzone" then
        if Auctionator and Auctionator.API and Auctionator.API.v1 then
            local items = {}
            for _, reagent in ipairs(lure.reagents) do
                local name = C_Item.GetItemNameByID(reagent.itemID)
                if name then
                    local searchStr = Auctionator.API.v1.ConvertToSearchString("DDT", { searchString = name })
                    items[#items + 1] = searchStr
                end
            end
            if #items > 0 then
                pcall(Auctionator.API.v1.CreateShoppingList, "DDT", "DDT " .. lure.name .. " Reagents", items)
                DDT:Print("Shopping list: DDT " .. lure.name .. " Reagents")
            end
        else
            DDT:Print("Auctionator not installed.")
        end

    elseif action == "openmap" then
        if lure.waypoint then
            OpenWorldMap(lure.waypoint.map)
        end
    end
end

local function GetOrCreateHeader(profKey, parent, index)
    local pool = pools[profKey]
    if pool.headers[index] then
        pool.headers[index]:Show()
        return pool.headers[index]
    end

    local hdr = ns.FontString(parent, "DDTFontNormal")
    hdr:SetJustifyH("LEFT")
    hdr:SetJustifyV("TOP")
    hdr:SetHeight(HEADER_HEIGHT)

    pool.headers[index] = hdr
    return hdr
end

local function HideAllPooled(profKey)
    local pool = pools[profKey]
    if not pool then return end
    for _, row in pairs(pool.rows) do row:Hide() end
    for _, hdr in pairs(pool.headers) do hdr:Hide() end
    -- Also hide secure lure buttons
    if lureButtons[profKey] then
        for _, btn in pairs(lureButtons[profKey]) do btn:Hide() end
    end
end

---------------------------------------------------------------------------
-- Tooltip: Populate
---------------------------------------------------------------------------

function Professions:PopulateTooltip(profKey)
    local tf = tooltipFrames[profKey]
    if not tf then return end

    local state = profState[profKey]
    if not state then return end

    local pdb = self:GetProfDB(profKey)
    local db  = self:GetDB()
    local expansion = db.activeExpansion or "midnight"
    local tooltipWidth = ResolveTooltipSetting(pdb, db, "tooltipWidth") or 380
    local innerWidth = tooltipWidth - 2 * TOOLTIP_PADDING

    tf:SetWidth(tooltipWidth)
    tf.maxHeightOverride = ResolveTooltipSetting(pdb, db, "tooltipMaxHeight")

    -- Header
    tf.header:SetText(DDT:ColorText(state.profDef.name, 1, 0.82, 0))

    local sc = tf.scrollContent

    HideAllPooled(profKey)

    local yOffset = 0
    local rowIdx = 0
    local hdrIdx = 0
    local rowSpacing = 2

    -- ── Sub-header: Skill + Concentration ──
    rowIdx = rowIdx + 1
    local skillRow = GetOrCreateRow(profKey, sc, rowIdx)
    skillRow:ClearAllPoints()
    skillRow:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, yOffset)
    skillRow:SetWidth(innerWidth)
    skillRow.icon:Hide()
    skillRow.text:SetPoint("TOPLEFT", skillRow, "TOPLEFT", 0, 0)
    skillRow.text:SetWidth(innerWidth * 0.5)

    local skillText = "Skill: " .. state.skillLevel .. "/" .. state.maxSkillLevel
    if state.bonusSkill and state.bonusSkill > 0 then
        skillText = skillText .. " |cff00ff00(+" .. state.bonusSkill .. ")|r"
    end
    skillRow.text:SetText(skillText)
    skillRow.text:SetTextColor(0.9, 0.9, 0.9)

    if state.maxConcentration > 0 then
        local concPct = state.concentration / state.maxConcentration
        local cr, cg, cb = 0.6, 0.6, 0.6
        if concPct >= 0.8 then cr, cg, cb = 0.2, 1.0, 0.4
        elseif concPct >= 0.4 then cr, cg, cb = 1.0, 0.82, 0
        else cr, cg, cb = 1.0, 0.4, 0.2 end
        skillRow.status:SetText(DDT:ColorText("Conc: " .. state.concentration .. "/" .. state.maxConcentration, cr, cg, cb))
    else
        skillRow.status:SetText("")
    end
    skillRow.status:SetWidth(innerWidth * 0.5)

    skillRow:SetHeight(ns.ROW_HEIGHT)
    skillRow:SetScript("OnMouseUp", nil)
    yOffset = yOffset - ns.ROW_HEIGHT - SECTION_GAP

    -- ── KP Sources Section ──
    if pdb.showKPSources ~= false and state.profData and state.profData.kpSources then
        yOffset, rowIdx, hdrIdx = self:RenderKPSection(sc, yOffset, rowIdx, hdrIdx, profKey, expansion, innerWidth)
        yOffset = yOffset - SECTION_GAP
    end

    -- ── Activities Section ──
    if pdb.showActivities ~= false and state.profData and state.profData.activities then
        yOffset, rowIdx, hdrIdx = self:RenderActivities(sc, yOffset, rowIdx, hdrIdx, profKey, innerWidth)
        yOffset = yOffset - SECTION_GAP
    end

    -- ── Buffs Section ──
    if pdb.showBuffs ~= false then
        yOffset, rowIdx, hdrIdx = self:RenderBuffs(sc, yOffset, rowIdx, hdrIdx, profKey, innerWidth)
        yOffset = yOffset - SECTION_GAP
    end

    -- ── Timers Section ──
    if pdb.showTimers ~= false then
        yOffset, rowIdx, hdrIdx = self:RenderTimers(sc, yOffset, rowIdx, hdrIdx, profKey, innerWidth)
    end

    -- ── Hint bar ──
    local showHint = pdb.showHintBar ~= false
    if showHint then
        local hintText = DDT:BuildHintText(pdb.clickActions or {}, ns.PROF_CLICK_ACTIONS)
        -- Add row click hints if this profession has activities (beast rows)
        local profData = ns.ProfessionData[profKey]
        if profData and profData.activities and profData.activities.majesticBeasts then
            local rowHint = DDT:BuildHintText(pdb.rowClickActions or {}, ns.PROF_ROW_CLICK_ACTIONS)
            if rowHint and rowHint ~= "" then
                hintText = hintText .. "\nRow: " .. rowHint
            end
        end
        tf.hint:SetText(hintText)
        tf.hint:Show()
    else
        tf.hint:SetText("")
        tf.hint:Hide()
    end

    -- Finalize layout
    local contentH = math.max(math.abs(yOffset), ns.ROW_HEIGHT)
    local maxH = ResolveTooltipSetting(pdb, db, "tooltipMaxHeight")
    tf:FinalizeLayout(tooltipWidth, contentH, nil, maxH)
end

---------------------------------------------------------------------------
-- Tooltip: KP Section Renderer
---------------------------------------------------------------------------

function Professions:RenderKPSection(sc, yOffset, rowIdx, hdrIdx, profKey, expansion, innerWidth)
    local profData = ns.ProfessionData[profKey]
    if not profData or not profData.kpSources then return yOffset, rowIdx, hdrIdx end
    local kp = profData.kpSources

    -- Section header
    local totalEarned, totalAvail = self:CalcKPTotals(profKey, expansion)
    hdrIdx = hdrIdx + 1
    local hdr = GetOrCreateHeader(profKey, sc, hdrIdx)
    hdr:ClearAllPoints()
    hdr:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, yOffset)
    hdr:SetWidth(innerWidth)
    hdr:SetText(DDT:ColorText("Knowledge Points (" .. totalEarned .. "/" .. totalAvail .. " KP)", 1, 0.82, 0))
    yOffset = yOffset - HEADER_HEIGHT

    -- Unique Treasures
    if kp.uniqueTreasures and #kp.uniqueTreasures > 0 then
        yOffset, rowIdx, hdrIdx = self:RenderKPGroup(sc, yOffset, rowIdx, hdrIdx, profKey,
            "Unique Treasures", kp.uniqueTreasures, innerWidth)
    end

    -- Unique Books
    if kp.uniqueBooks and #kp.uniqueBooks > 0 then
        yOffset, rowIdx, hdrIdx = self:RenderKPGroup(sc, yOffset, rowIdx, hdrIdx, profKey,
            "Unique Books", kp.uniqueBooks, innerWidth)
    end

    -- Weeklies
    if kp.weeklies and #kp.weeklies > 0 then
        yOffset, rowIdx, hdrIdx = self:RenderWeeklies(sc, yOffset, rowIdx, hdrIdx, profKey,
            kp.weeklies, innerWidth)
    end

    -- Weekly item
    if kp.weeklyItem then
        local pdb = self:GetProfDB(profKey)
        local wi = kp.weeklyItem
        local done = C_QuestLog.IsQuestFlaggedCompleted(wi.questID)
        if done and pdb.hideKnownKP then
            -- Skip when done and hiding known
        else
        rowIdx = rowIdx + 1
        local row = GetOrCreateRow(profKey, sc, rowIdx)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", sc, "TOPLEFT", 8, yOffset)
        row:SetWidth(innerWidth - 8)
        row.icon:Hide()
        row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.text:SetWidth(innerWidth - 80)
        row.text:SetText((done and "|cff00ff00[x]|r " or "|cffff3333[ ]|r ") .. (wi.name or "Weekly Quest"))
        row.text:SetTextColor(done and 0.5 or 0.9, done and 0.5 or 0.9, done and 0.5 or 0.9)
        row.status:SetText(wi.kp .. " KP")
        row.status:SetTextColor(0.7, 0.7, 0.7)
        row.status:SetWidth(60)
        row:SetHeight(ns.ROW_HEIGHT)

        -- Waypoint click
        if wi.waypoint and not done then
            row:SetScript("OnMouseUp", function(_, button)
                if button == "LeftButton" then
                    ns.SetWaypoint(wi.waypoint.map, wi.waypoint.x, wi.waypoint.y)
                end
            end)
        else
            row:SetScript("OnMouseUp", nil)
        end

        yOffset = yOffset - ns.ROW_HEIGHT - 2

        end -- hideKnown else
    end

    return yOffset, rowIdx, hdrIdx
end

--- Render a group of KP sources (treasures or books)
function Professions:RenderKPGroup(sc, yOffset, rowIdx, hdrIdx, profKey, title, sources, innerWidth)
    local completedCount = 0
    for _, src in ipairs(sources) do
        local qid = type(src.questID) == "table" and src.questID[1] or src.questID
        if qid and C_QuestLog.IsQuestFlaggedCompleted(qid) then
            completedCount = completedCount + 1
        end
    end

    -- Sub-header
    hdrIdx = hdrIdx + 1
    local hdr = GetOrCreateHeader(profKey, sc, hdrIdx)
    hdr:ClearAllPoints()
    hdr:SetPoint("TOPLEFT", sc, "TOPLEFT", 4, yOffset)
    hdr:SetWidth(innerWidth - 4)
    local completionColor = completedCount == #sources and "|cff00ff00" or "|cffaaaaaa"
    hdr:SetText(completionColor .. title .. " (" .. completedCount .. "/" .. #sources .. ")|r")
    yOffset = yOffset - HEADER_HEIGHT

    local pdb = self:GetProfDB(profKey)
    local hideKnown = pdb.hideKnownKP

    for _, src in ipairs(sources) do
        local qid = type(src.questID) == "table" and src.questID[1] or src.questID
        local done = qid and C_QuestLog.IsQuestFlaggedCompleted(qid)

        if done and hideKnown then
            -- Skip completed items
        else

        rowIdx = rowIdx + 1
        local row = GetOrCreateRow(profKey, sc, rowIdx)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", sc, "TOPLEFT", 12, yOffset)
        row:SetWidth(innerWidth - 12)
        row.icon:Hide()
        row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.text:SetWidth(innerWidth - 80)

        local checkmark = done and "|cff00ff00[x]|r " or "|cffff3333[ ]|r "
        row.text:SetText(checkmark .. (src.name or "Unknown"))
        row.text:SetTextColor(done and 0.5 or 0.9, done and 0.5 or 0.9, done and 0.5 or 0.9)

        row.status:SetText(src.kp .. " KP")
        row.status:SetTextColor(0.7, 0.7, 0.7)
        row.status:SetWidth(60)
        row:SetHeight(ns.ROW_HEIGHT)

        -- Click to set waypoint (only if not done and has waypoint)
        if src.waypoint and not done then
            row:SetScript("OnMouseUp", function(_, button)
                if button == "LeftButton" then
                    ns.SetWaypoint(src.waypoint.map, src.waypoint.x, src.waypoint.y)
                end
            end)
        else
            row:SetScript("OnMouseUp", nil)
        end

        yOffset = yOffset - ns.ROW_HEIGHT - 2

        end -- hideKnown else
    end

    return yOffset, rowIdx, hdrIdx
end

--- Render weekly KP sources
function Professions:RenderWeeklies(sc, yOffset, rowIdx, hdrIdx, profKey, weeklies, innerWidth)
    -- Calculate weekly earned/total
    local weekEarned, weekTotal = 0, 0
    for _, w in ipairs(weeklies) do
        if w.dmf and not IsDarkmoonFaireUp() then
            -- Skip DMF when not active
        elseif w.mode == "each" then
            for _, qid in ipairs(w.questIDs) do
                weekTotal = weekTotal + w.kp
                if C_QuestLog.IsQuestFlaggedCompleted(qid) then
                    weekEarned = weekEarned + w.kp
                end
            end
        elseif w.mode == "rotation" then
            weekTotal = weekTotal + w.kp
            for _, qid in ipairs(w.questIDs) do
                if C_QuestLog.IsQuestFlaggedCompleted(qid) then
                    weekEarned = weekEarned + w.kp
                    break
                end
            end
        else
            weekTotal = weekTotal + w.kp
            if w.questIDs and w.questIDs[1] and C_QuestLog.IsQuestFlaggedCompleted(w.questIDs[1]) then
                weekEarned = weekEarned + w.kp
            end
        end
    end

    -- Sub-header
    hdrIdx = hdrIdx + 1
    local hdr = GetOrCreateHeader(profKey, sc, hdrIdx)
    hdr:ClearAllPoints()
    hdr:SetPoint("TOPLEFT", sc, "TOPLEFT", 4, yOffset)
    hdr:SetWidth(innerWidth - 4)
    local color = weekEarned == weekTotal and "|cff00ff00" or "|cffaaaaaa"
    hdr:SetText(color .. "Weekly Sources (" .. weekEarned .. "/" .. weekTotal .. " KP)|r")
    yOffset = yOffset - HEADER_HEIGHT

    for _, w in ipairs(weeklies) do
        if w.dmf and not IsDarkmoonFaireUp() then
            -- Skip DMF row when faire is not active
        else
            rowIdx = rowIdx + 1
            local row = GetOrCreateRow(profKey, sc, rowIdx)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", sc, "TOPLEFT", 12, yOffset)
            row:SetWidth(innerWidth - 12)
            row.icon:Hide()
            row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
            row.text:SetWidth(innerWidth - 120)

            local statusText, done
            if w.mode == "each" then
                local count = 0
                for _, qid in ipairs(w.questIDs) do
                    if C_QuestLog.IsQuestFlaggedCompleted(qid) then count = count + 1 end
                end
                done = count == #w.questIDs
                statusText = count .. "/" .. #w.questIDs
            elseif w.mode == "rotation" then
                done = false
                for _, qid in ipairs(w.questIDs) do
                    if C_QuestLog.IsQuestFlaggedCompleted(qid) then done = true; break end
                end
                statusText = done and "Done" or "Todo"
            else
                done = w.questIDs and w.questIDs[1] and C_QuestLog.IsQuestFlaggedCompleted(w.questIDs[1])
                statusText = done and "Done" or "Todo"
            end

            row.text:SetText(w.label or w.key)
            row.text:SetTextColor(done and 0.5 or 0.9, done and 0.5 or 0.9, done and 0.5 or 0.9)

            local statusColor = done and "|cff00ff00" or "|cffffcc00"
            row.status:SetText(statusColor .. statusText .. "|r  " .. w.kp .. " KP")
            row.status:SetWidth(100)
            row.status:SetTextColor(0.7, 0.7, 0.7)

            row:SetHeight(ns.ROW_HEIGHT)
            row:SetScript("OnMouseUp", nil)
            yOffset = yOffset - ns.ROW_HEIGHT - 2
        end
    end

    return yOffset, rowIdx, hdrIdx
end

---------------------------------------------------------------------------
-- Tooltip: Activities Section
---------------------------------------------------------------------------

--- Detect invested talent points in the "Tracker" spec tree for Skinning.
--- pcall wraps each C_ProfSpecs call because the API throws if the
--- profession window hasn't been opened yet in the current session.
local function DetectTrackerTalentPoints(skillLine)
    if not C_ProfSpecs then return 0 end
    local ok, configID = pcall(C_ProfSpecs.GetConfigIDForSkillLine, skillLine)
    if not ok or not configID or configID == 0 then return 0 end
    local ok2, tabIDs = pcall(C_ProfSpecs.GetSpecTabIDsForSkillLine, skillLine)
    if not ok2 or not tabIDs then return 0 end
    for _, tabID in ipairs(tabIDs) do
        local ok3, tabInfo = pcall(C_ProfSpecs.GetTabInfo, tabID)
        if ok3 and tabInfo and tabInfo.name and tabInfo.name:lower():find("tracker") then
            -- BFS traversal of the talent tree; C_ProfSpecs only exposes
            -- parent->child relationships, not a flat list of nodes.
            local todo = { tabInfo.rootNodeID }
            local total = 0
            while #todo > 0 do
                local nodeID = table.remove(todo)
                local children = C_ProfSpecs.GetChildrenForPath(nodeID)
                if children then
                    for _, childID in ipairs(children) do
                        todo[#todo + 1] = childID
                    end
                end
                local info = C_Traits.GetNodeInfo(configID, nodeID)
                if info and info.activeRank and info.activeRank > 0 then
                    total = total + info.activeRank
                end
            end
            return total
        end
    end
    return 0
end

--- Render activities for a profession (Majestic Beasts for Skinning, cooldowns for crafting, etc.)
function Professions:RenderActivities(sc, yOffset, rowIdx, hdrIdx, profKey, innerWidth)
    local profData = ns.ProfessionData[profKey]
    if not profData or not profData.activities then return yOffset, rowIdx, hdrIdx end

    local activities = profData.activities

    -- Buff Alerts (Enchanting Shatter Essence, etc.) - render first, most prominent
    if activities.buffAlerts then
        yOffset, rowIdx, hdrIdx = self:RenderBuffAlerts(sc, yOffset, rowIdx, hdrIdx, profKey, innerWidth, activities.buffAlerts)
    end

    -- Cooldowns (Alchemy transmutes, Tailoring bolts, etc.)
    if activities.cooldowns then
        yOffset, rowIdx, hdrIdx = self:RenderCooldowns(sc, yOffset, rowIdx, hdrIdx, profKey, innerWidth, activities.cooldowns)
    end

    -- Buff Trackers (Mining Wild Perception, etc.)
    if activities.buffTrackers then
        yOffset, rowIdx, hdrIdx = self:RenderBuffTrackers(sc, yOffset, rowIdx, hdrIdx, profKey, innerWidth, activities.buffTrackers)
    end

    -- Tracking Toggle (Skinning Find High-Value Beasts)
    if activities.trackingToggle then
        yOffset, rowIdx, hdrIdx = self:RenderTrackingToggle(sc, yOffset, rowIdx, hdrIdx, profKey, innerWidth, activities.trackingToggle)
    end

    -- Majestic Beasts (Skinning)
    if activities.majesticBeasts then
        yOffset, rowIdx, hdrIdx = self:RenderMajesticBeasts(sc, yOffset, rowIdx, hdrIdx, profKey, innerWidth, activities.majesticBeasts)
    end

    return yOffset, rowIdx, hdrIdx
end

---------------------------------------------------------------------------
-- Tooltip: Buff Alerts (e.g. Enchanting Shattered Essence)
---------------------------------------------------------------------------

function Professions:RenderBuffAlerts(sc, yOffset, rowIdx, hdrIdx, profKey, innerWidth, alerts)
    for _, alert in ipairs(alerts) do
        -- Prefer spellID-based lookup (locale-independent, unique).
        -- AuraUtil.FindAuraByName is a fallback since aura names are
        -- localized and non-unique (see AuraUtil.lua:75-79 warnings).
        local isActive
        if alert.spellID and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
            isActive = C_UnitAuras.GetPlayerAuraBySpellID(alert.spellID) ~= nil
        else
            isActive = alert.buffName and AuraUtil.FindAuraByName(alert.buffName, "player")
        end

        rowIdx = rowIdx + 1
        local row = GetOrCreateRow(profKey, sc, rowIdx)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, yOffset)
        row:SetWidth(innerWidth)

        -- Icon from spell
        local iconID = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(alert.spellID)
            or GetSpellTexture(alert.spellID)
        if iconID then
            row.icon:SetTexture(iconID)
            row.icon:SetDesaturated(not isActive)
            row.icon:Show()
            row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 4, 0)
        else
            row.icon:Hide()
            row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        end

        row.text:SetWidth(innerWidth - 80)

        if isActive then
            row.text:SetText("|cff00ff00" .. alert.activeText .. "|r")
            row.status:SetText("|cff00ff00Active|r")
        else
            row.text:SetText("|cffff3333" .. alert.alertText .. "|r")
            row.status:SetText("|cffff3333MISSING|r")
        end
        row.status:SetWidth(60)
        row:SetHeight(ns.ROW_HEIGHT)
        row:SetScript("OnClick", nil)

        yOffset = yOffset - ns.ROW_HEIGHT - 2

        -- Description sub-row
        if alert.description then
            rowIdx = rowIdx + 1
            local descRow = GetOrCreateRow(profKey, sc, rowIdx)
            descRow:ClearAllPoints()
            descRow:SetPoint("TOPLEFT", sc, "TOPLEFT", ICON_SIZE + 4, yOffset)
            descRow:SetWidth(innerWidth - ICON_SIZE - 4)
            descRow.icon:Hide()
            descRow.text:SetPoint("TOPLEFT", descRow, "TOPLEFT", 0, 0)
            descRow.text:SetWidth(innerWidth - ICON_SIZE - 4)
            descRow.text:SetText("|cff888888" .. alert.description .. "|r")
            descRow.status:SetText("")
            descRow:SetHeight(ns.ROW_HEIGHT)
            descRow:SetScript("OnClick", nil)
            yOffset = yOffset - ns.ROW_HEIGHT - 2
        end
    end

    return yOffset, rowIdx, hdrIdx
end

---------------------------------------------------------------------------
-- Tooltip: Cooldowns (e.g. Alchemy Transmutes, Tailoring Bolts)
---------------------------------------------------------------------------

function Professions:RenderCooldowns(sc, yOffset, rowIdx, hdrIdx, profKey, innerWidth, cooldowns)
    -- Section header
    hdrIdx = hdrIdx + 1
    local hdr = GetOrCreateHeader(profKey, sc, hdrIdx)
    hdr:ClearAllPoints()
    hdr:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, yOffset)
    hdr:SetWidth(innerWidth)
    hdr:SetText(DDT:ColorText("Cooldowns", 1, 0.82, 0))
    yOffset = yOffset - HEADER_HEIGHT

    local function FormatCooldown(sec)
        if not sec or sec <= 0 then return "|cff00ff00Ready|r" end
        local h = math.floor(sec / 3600)
        local m = math.floor((sec % 3600) / 60)
        if h > 0 then return h .. "h " .. m .. "m"
        else return m .. "m" end
    end

    for _, cd in ipairs(cooldowns) do
        -- Check if the player knows this spell
        local isKnown = C_SpellBook and C_SpellBook.IsSpellKnown(cd.spellID)
        if isKnown == nil then isKnown = IsSpellKnown and IsSpellKnown(cd.spellID) end
        if isKnown then
            rowIdx = rowIdx + 1
            local row = GetOrCreateRow(profKey, sc, rowIdx)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", sc, "TOPLEFT", 4, yOffset)
            row:SetWidth(innerWidth - 4)

            -- Spell icon
            local iconID = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(cd.spellID)
                or GetSpellTexture(cd.spellID)
            if iconID then
                row.icon:SetTexture(iconID)
                row.icon:Show()
                row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 4, 0)
            else
                row.icon:Hide()
                row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
            end

            row.text:SetWidth(innerWidth - 140)
            row.text:SetText(cd.name)

            -- C_TradeSkillUI.GetRecipeCooldown is the primary API for profession
            -- cooldowns (returns charges natively). CraftSim uses the same approach.
            -- C_Spell.GetSpellCooldown is less reliable for recipe-based cooldowns.
            local currentCooldown, isDayCooldown, currentCharges, maxCharges
            if C_TradeSkillUI and C_TradeSkillUI.GetRecipeCooldown then
                currentCooldown, isDayCooldown, currentCharges, maxCharges = C_TradeSkillUI.GetRecipeCooldown(cd.spellID)
            end
            currentCooldown = currentCooldown or 0

            local statusText
            if maxCharges and maxCharges > 0 then
                -- Charge-based cooldown (Tailoring bolts)
                local charges = tonumber(currentCharges) or 0
                if charges >= maxCharges then
                    statusText = "|cff00ff00" .. charges .. "/" .. maxCharges .. " Ready|r"
                    row.text:SetTextColor(0.9, 0.9, 0.9)
                else
                    statusText = "|cffffcc00" .. charges .. "/" .. maxCharges .. "|r " .. FormatCooldown(currentCooldown)
                    row.text:SetTextColor(0.7, 0.7, 0.7)
                end
            elseif currentCooldown > 0 then
                -- Standard day cooldown (Alchemy transmutes)
                statusText = "|cffff6600" .. FormatCooldown(currentCooldown) .. "|r"
                row.text:SetTextColor(0.7, 0.7, 0.7)
            else
                statusText = "|cff00ff00Ready|r"
                row.text:SetTextColor(0.9, 0.9, 0.9)
            end

            row.status:SetText(statusText)
            row.status:SetWidth(120)
            row:SetHeight(ns.ROW_HEIGHT)
            row:SetScript("OnClick", nil)

            yOffset = yOffset - ns.ROW_HEIGHT - 2
        end
    end

    return yOffset, rowIdx, hdrIdx
end

---------------------------------------------------------------------------
-- Tooltip: Buff Trackers (e.g. Mining Wild Perception)
---------------------------------------------------------------------------

function Professions:RenderBuffTrackers(sc, yOffset, rowIdx, hdrIdx, profKey, innerWidth, trackers)
    for _, tracker in ipairs(trackers) do
        local auraData
        if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
            auraData = C_UnitAuras.GetPlayerAuraBySpellID(tracker.spellID)
        end
        local isActive = auraData ~= nil

        -- Use AuraUtil as fallback
        if not auraData and tracker.buffName then
            isActive = AuraUtil.FindAuraByName(tracker.buffName, "player") ~= nil
        end

        rowIdx = rowIdx + 1
        local row = GetOrCreateRow(profKey, sc, rowIdx)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, yOffset)
        row:SetWidth(innerWidth)

        local iconID = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(tracker.spellID)
            or GetSpellTexture(tracker.spellID)
        if iconID then
            row.icon:SetTexture(iconID)
            row.icon:SetDesaturated(not isActive)
            row.icon:Show()
            row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 4, 0)
        else
            row.icon:Hide()
            row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        end

        row.text:SetWidth(innerWidth - 80)
        row.text:SetText(tracker.name)

        if isActive then
            -- Show remaining duration if available
            local remaining
            if auraData and auraData.expirationTime then
                remaining = auraData.expirationTime - GetTime()
            end
            if remaining and remaining > 0 then
                local m = math.floor(remaining / 60)
                local s = math.floor(remaining % 60)
                row.status:SetText("|cff00ff00" .. m .. "m " .. s .. "s|r")
            else
                row.status:SetText("|cff00ff00Active|r")
            end
            row.text:SetTextColor(0.2, 1, 0.4)
        else
            row.status:SetText("|cff666666Inactive|r")
            row.text:SetTextColor(0.5, 0.5, 0.5)
        end

        row.status:SetWidth(60)
        row:SetHeight(ns.ROW_HEIGHT)
        row:SetScript("OnClick", nil)

        yOffset = yOffset - ns.ROW_HEIGHT - 2
    end

    return yOffset, rowIdx, hdrIdx
end

---------------------------------------------------------------------------
-- Tooltip: Tracking Toggle (e.g. Skinning Find High-Value Beasts)
---------------------------------------------------------------------------

function Professions:RenderTrackingToggle(sc, yOffset, rowIdx, hdrIdx, profKey, innerWidth, toggle)
    -- No direct API to check if a specific tracking spell is active;
    -- must iterate all minimap tracking entries and match by spellID.
    local isTracking = false
    for i = 1, C_Minimap.GetNumTrackingTypes() do
        local info = C_Minimap.GetTrackingInfo(i)
        if info and info.spellID == toggle.spellID then
            isTracking = info.active or false
            break
        end
    end

    rowIdx = rowIdx + 1
    local row = GetOrCreateRow(profKey, sc, rowIdx)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, yOffset)
    row:SetWidth(innerWidth)

    local iconID = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(toggle.spellID)
        or GetSpellTexture(toggle.spellID)
    if iconID then
        row.icon:SetTexture(iconID)
        row.icon:SetDesaturated(not isTracking)
        row.icon:Show()
        row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 4, 0)
    else
        row.icon:Hide()
        row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    end

    row.text:SetWidth(innerWidth - 80)
    row.text:SetText(toggle.name)

    if isTracking then
        row.status:SetText("|cff00ff00ON|r")
        row.text:SetTextColor(0.2, 1, 0.4)
    else
        row.status:SetText("|cffff6600OFF|r")
        row.text:SetTextColor(0.7, 0.5, 0.2)
    end

    row.status:SetWidth(60)
    row:SetHeight(ns.ROW_HEIGHT)
    row:SetScript("OnClick", nil)

    yOffset = yOffset - ns.ROW_HEIGHT - 2

    return yOffset, rowIdx, hdrIdx
end

--- Render Majestic Beast lure rows with status, reagent counts, waypoint clicks
function Professions:RenderMajesticBeasts(sc, yOffset, rowIdx, hdrIdx, profKey, innerWidth, mbData)
    local charData = self:GetCharData(profKey, self:GetDB().activeExpansion or "midnight")
    if not charData then return yOffset, rowIdx, hdrIdx end

    -- Detect talent points
    local talentPoints = DetectTrackerTalentPoints(mbData.skillLine)
    if not charData.activities then charData.activities = {} end
    if talentPoints > 0 then
        charData.activities.talentPoints = talentPoints
    end
    local points = charData.activities.talentPoints or 0

    -- Count kills
    local lureKills = charData.activities.lureKills or {}
    local killCount = 0
    local totalLures = #mbData.lures
    for i, lure in ipairs(mbData.lures) do
        if points >= lure.requiredPoints then
            local killTS = lureKills[lure.name]
            if killTS and killTS >= GetLastDailyReset() then
                killCount = killCount + 1
            end
        end
    end

    -- Section header
    hdrIdx = hdrIdx + 1
    local hdr = GetOrCreateHeader(profKey, sc, hdrIdx)
    hdr:ClearAllPoints()
    hdr:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, yOffset)
    hdr:SetWidth(innerWidth)
    local visibleCount = 0
    for i, lure in ipairs(mbData.lures) do
        if points >= lure.requiredPoints then visibleCount = visibleCount + 1 end
    end
    local hdrColor = killCount == visibleCount and visibleCount > 0 and "|cff00ff00" or "|cffffcc00"
    hdr:SetText(DDT:ColorText("Majestic Beasts (" .. killCount .. "/" .. visibleCount .. ")", 1, 0.82, 0))
    yOffset = yOffset - HEADER_HEIGHT

    -- Render each lure row
    -- Layout: Name | Lures (count or missing reagents) | Killed/Available
    local STATUS_W = 60
    local LURE_W = 100

    for i, lure in ipairs(mbData.lures) do
        local canSee = points >= lure.requiredPoints
        if not canSee then
            -- Show locked row
            rowIdx = rowIdx + 1
            local row = GetOrCreateRow(profKey, sc, rowIdx)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", sc, "TOPLEFT", 4, yOffset)
            row:SetWidth(innerWidth - 4)

            row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            row.icon:SetDesaturated(true)
            row.icon:Show()
            row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 4, 0)
            row.text:SetWidth(innerWidth - STATUS_W - LURE_W)
            row.text:SetText("|cff666666" .. lure.name .. " (" .. lure.requiredPoints .. " pts)|r")
            row.text:SetTextColor(0.4, 0.4, 0.4)

            -- Hide middle column for locked rows
            if row.middle then row.middle:SetText(""); row.middle:Hide() end
            row.status:SetText("|cff666666Locked|r")
            row.status:SetWidth(STATUS_W)
            row:SetHeight(ns.ROW_HEIGHT)
            row:SetScript("OnMouseUp", nil)
            yOffset = yOffset - ns.ROW_HEIGHT - 2
        else
            local killTS = lureKills[lure.name]
            local killedToday = killTS and killTS >= GetLastDailyReset()

            rowIdx = rowIdx + 1
            local row = GetOrCreateRow(profKey, sc, rowIdx)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", sc, "TOPLEFT", 4, yOffset)
            row:SetWidth(innerWidth - 4)

            -- Lazily create the middle font string for lure info
            if not row.middle then
                row.middle = ns.FontString(row, "DDTFontSmall")
                row.middle:SetJustifyH("RIGHT")
                row.middle:SetJustifyV("TOP")
            end
            row.middle:SetPoint("TOPRIGHT", row.status, "TOPLEFT", -4, 0)
            row.middle:SetWidth(LURE_W)
            row.middle:Show()

            -- Lure icon
            local iconID = C_Item.GetItemIconByID(lure.itemID)
            if iconID then
                row.icon:SetTexture(iconID)
                row.icon:SetDesaturated(killedToday)
                row.icon:Show()
            else
                row.icon:Hide()
            end
            row.text:SetPoint("TOPLEFT", row.icon:IsShown() and row.icon or row, row.icon:IsShown() and "TOPRIGHT" or "TOPLEFT", row.icon:IsShown() and 4 or 0, 0)
            row.text:SetWidth(innerWidth - STATUS_W - LURE_W - ICON_SIZE - 12)

            -- Col 1: Name with lure color (grey out if killed today)
            local nameText = (killedToday and "|cff666666" or lure.color) .. lure.name .. "|r"
            row.text:SetText(nameText)
            row.text:SetTextColor(1, 1, 1)

            -- Col 2: Lure count in bags, or missing reagent info
            local lureCount = C_Item.GetItemCount(lure.itemID, true, false, true, true)
            if lureCount > 0 then
                row.middle:SetText("|cff00ff00" .. lureCount .. " lure" .. (lureCount > 1 and "s" or "") .. "|r")
            else
                -- Check if reagents are available to craft
                local hasReagents = true
                local missingParts = {}
                for _, reagent in ipairs(lure.reagents) do
                    local count = C_Item.GetItemCount(reagent.itemID, true, false, true, true)
                    if count < reagent.count then
                        hasReagents = false
                        missingParts[#missingParts + 1] = count .. "/" .. reagent.count
                    end
                end
                if hasReagents then
                    row.middle:SetText("|cff00ff00Craftable|r")
                else
                    row.middle:SetText("|cffff6600" .. table.concat(missingParts, ", ") .. "|r")
                end
            end

            -- Col 3: Kill status
            if killedToday then
                row.status:SetText("|cff00ff00Killed|r")
            else
                row.status:SetText("|cffffffffAvail.|r")
            end
            row.status:SetWidth(STATUS_W)
            row:SetHeight(ns.ROW_HEIGHT)

            -- Click handler for row actions (waypoint, craftlure, shopzone, openmap)
            local lureIndex = i
            row:SetScript("OnClick", function(self, button)
                local pdb = Professions:GetProfDB(profKey)
                local action = DDT:ResolveClickAction(button, pdb.rowClickActions or {})
                if action == "placelure" then
                    -- Secure item usage handled by overlay button
                    return
                end
                Professions:ExecuteRowClickAction(profKey, action, lureIndex)
            end)

            -- Secure lure overlay for placelure action
            if not InCombatLockdown() then
                local lureBtn = GetOrCreateLureButton(profKey, sc, i, lure)
                lureBtn:ClearAllPoints()
                lureBtn:SetAllPoints(row)
                lureBtn:SetFrameLevel(row:GetFrameLevel() + 1)
                -- Hide overlay visuals - only the highlight and click behavior remain
                lureBtn.icon:Hide()
                lureBtn.text:SetText("")
                lureBtn.status:SetText("")
                lureBtn._lureIndex = i
                lureBtn:Show()
            end

            yOffset = yOffset - ns.ROW_HEIGHT - 2
        end
    end

    return yOffset, rowIdx, hdrIdx
end

---------------------------------------------------------------------------
-- Tooltip: Buff Section
---------------------------------------------------------------------------

function Professions:RenderBuffs(sc, yOffset, rowIdx, hdrIdx, profKey, innerWidth)
    local category = ns.PROF_GATHERING[profKey] and "gathering" or "crafting"
    local buffs = ns.PROF_BUFFS[category]
    if not buffs or #buffs == 0 then return yOffset, rowIdx, hdrIdx end

    -- Also include profession-specific consumables from activity data
    local profData = ns.ProfessionData[profKey]
    local activityBuffs = profData and profData.activities
        and profData.activities.majesticBeasts
        and profData.activities.majesticBeasts.consumables

    -- Build combined list for shopping list action
    local allBuffs = {}
    local sharedSet = {}
    for _, b in ipairs(buffs) do
        allBuffs[#allBuffs + 1] = b
        sharedSet[b.itemID] = true
    end
    if activityBuffs then
        for _, b in ipairs(activityBuffs) do
            if not sharedSet[b.itemID] then
                allBuffs[#allBuffs + 1] = b
            end
        end
    end

    -- Section header (use a row for click support)
    rowIdx = rowIdx + 1
    local hdrRow = GetOrCreateRow(profKey, sc, rowIdx)
    hdrRow:ClearAllPoints()
    hdrRow:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, yOffset)
    hdrRow:SetWidth(innerWidth)
    hdrRow.icon:Hide()
    hdrRow.text:SetPoint("TOPLEFT", hdrRow, "TOPLEFT", 0, 0)
    hdrRow.text:SetWidth(innerWidth)
    hdrRow.text:SetText(DDT:ColorText("Consumable Buffs", 1, 0.82, 0))
    hdrRow.text:SetTextColor(1, 0.82, 0)
    hdrRow.status:SetText("|cff888888Shift+Click: Shop All|r")
    hdrRow.status:SetWidth(120)
    hdrRow:SetHeight(HEADER_HEIGHT)
    hdrRow:SetScript("OnClick", function(_, button)
        if IsShiftKeyDown() and button == "LeftButton" then
            if Auctionator and Auctionator.API and Auctionator.API.v1 then
                local items = {}
                for _, buff in ipairs(allBuffs) do
                    local name = C_Item.GetItemNameByID(buff.itemID)
                    if name then
                        items[#items + 1] = Auctionator.API.v1.ConvertToSearchString("DDT", { searchString = name })
                    end
                end
                if #items > 0 then
                    pcall(Auctionator.API.v1.CreateShoppingList, "DDT", "DDT Consumable Buffs", items)
                    DDT:Print("Shopping list created: DDT Consumable Buffs")
                end
            else
                DDT:Print("Auctionator not installed.")
            end
        end
    end)
    yOffset = yOffset - HEADER_HEIGHT

    local function RenderBuff(buff)
        rowIdx = rowIdx + 1
        local row = GetOrCreateRow(profKey, sc, rowIdx)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", sc, "TOPLEFT", 4, yOffset)
        row:SetWidth(innerWidth - 4)

        -- Icon
        local iconID = C_Item.GetItemIconByID(buff.itemID)
        if iconID then
            row.icon:SetTexture(iconID)
            row.icon:Show()
            row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 4, 0)
        else
            row.icon:Hide()
            row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        end

        row.text:SetWidth(innerWidth - 80)
        row.text:SetText(buff.name)
        row.text:SetTextColor(0.9, 0.9, 0.9)

        -- Check if buff is active or how many we have
        local isActive = buff.buffName and AuraUtil.FindAuraByName(buff.buffName, "player")
        if isActive then
            row.status:SetText("|cff00ff00Active|r")
        else
            local count = C_Item.GetItemCount(buff.itemID, true) or 0
            if count > 0 then
                row.status:SetText("|cffffcc00x" .. count .. "|r")
            else
                row.status:SetText("|cffff3333None|r")
            end
        end
        row.status:SetWidth(60)
        row:SetHeight(ns.ROW_HEIGHT)

        -- Shift+Click: search AH for this consumable
        local buffRef = buff
        row:SetScript("OnClick", function(_, button)
            if IsShiftKeyDown() and button == "LeftButton" then
                if Auctionator and Auctionator.API and Auctionator.API.v1 then
                    local name = C_Item.GetItemNameByID(buffRef.itemID)
                    if name then
                        pcall(Auctionator.API.v1.CreateShoppingList, "DDT", "DDT " .. name, {
                            Auctionator.API.v1.ConvertToSearchString("DDT", { searchString = name })
                        })
                    end
                else
                    DDT:Print("Auctionator not installed.")
                end
            end
        end)

        yOffset = yOffset - ns.ROW_HEIGHT - 2
    end

    for _, buff in ipairs(buffs) do
        RenderBuff(buff)
    end

    -- Render profession-specific consumables (that aren't already in the shared list)
    if activityBuffs then
        for _, buff in ipairs(activityBuffs) do
            if not sharedSet[buff.itemID] then
                RenderBuff(buff)
            end
        end
    end

    return yOffset, rowIdx, hdrIdx
end

---------------------------------------------------------------------------
-- Tooltip: Timer Section
---------------------------------------------------------------------------

function Professions:RenderTimers(sc, yOffset, rowIdx, hdrIdx, profKey, innerWidth)
    local dailySec = C_DateAndTime.GetSecondsUntilDailyReset()
    local weeklySec = C_DateAndTime.GetSecondsUntilWeeklyReset()

    local function FormatTime(sec)
        if not sec or sec <= 0 then return "|cff00ff00Ready|r" end
        local h = math.floor(sec / 3600)
        local m = math.floor((sec % 3600) / 60)
        if h > 24 then
            local d = math.floor(h / 24)
            h = h % 24
            return d .. "d " .. h .. "h"
        elseif h > 0 then
            return h .. "h " .. m .. "m"
        else
            return m .. "m"
        end
    end

    local function TimeColor(sec)
        if not sec or sec <= 0 then return 0.2, 1, 0.4 end
        if sec < 3600 then return 1, 0.82, 0 end
        return 0.7, 0.7, 0.7
    end

    for _, timerInfo in ipairs({
        { label = "Daily Reset",  sec = dailySec },
        { label = "Weekly Reset", sec = weeklySec },
    }) do
        rowIdx = rowIdx + 1
        local row = GetOrCreateRow(profKey, sc, rowIdx)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, yOffset)
        row:SetWidth(innerWidth)
        row.icon:Hide()
        row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.text:SetWidth(innerWidth * 0.6)
        row.text:SetText(timerInfo.label)
        row.text:SetTextColor(0.6, 0.6, 0.6)

        local r, g, b = TimeColor(timerInfo.sec)
        row.status:SetText(DDT:ColorText(FormatTime(timerInfo.sec), r, g, b))
        row.status:SetWidth(innerWidth * 0.4)
        row:SetHeight(ns.ROW_HEIGHT)
        row:SetScript("OnMouseUp", nil)

        yOffset = yOffset - ns.ROW_HEIGHT - 2
    end

    return yOffset, rowIdx, hdrIdx
end

---------------------------------------------------------------------------
-- Click Actions
---------------------------------------------------------------------------

function Professions:ExecuteClickAction(profKey, action)
    if not action or action == "none" then return end

    local state = profState[profKey]
    if not state then return end

    if action == "openprofessions" then
        -- Open the profession's trade skill window
        local expData = state.profDef.expansions[self:GetDB().activeExpansion or "midnight"]
        if expData and C_TradeSkillUI then
            C_TradeSkillUI.OpenTradeSkill(expData.skillLine)
        end
    elseif action == "waypointtrainer" then
        local expData = state.profDef.expansions[self:GetDB().activeExpansion or "midnight"]
        if expData and expData.trainer then
            local t = expData.trainer
            ns.SetWaypoint(t.map, t.x, t.y)
        end
    elseif action == "waypointbeast" then
        -- Waypoint the next un-killed beast
        local profData = ns.ProfessionData[profKey]
        if profData and profData.activities and profData.activities.majesticBeasts then
            local charData = self:GetCharData(profKey, self:GetDB().activeExpansion or "midnight")
            local lureKills = charData and charData.activities and charData.activities.lureKills or {}
            local points = charData and charData.activities and charData.activities.talentPoints or 0
            local lastReset = GetLastDailyReset()
            for _, lure in ipairs(profData.activities.majesticBeasts.lures) do
                if points >= lure.requiredPoints then
                    local killTS = lureKills[lure.name]
                    if not killTS or killTS < lastReset then
                        if lure.waypoint then
                            ns.SetWaypoint(lure.waypoint.map, lure.waypoint.x, lure.waypoint.y,
                                "Waypoint set: " .. lure.name)
                        end
                        return
                    end
                end
            end
            DDT:Print("All beasts killed today!")
        end
    elseif action == "openmap" then
        -- Open map to next un-killed beast
        local profData = ns.ProfessionData[profKey]
        if profData and profData.activities and profData.activities.majesticBeasts then
            local charData = self:GetCharData(profKey, self:GetDB().activeExpansion or "midnight")
            local lureKills = charData and charData.activities and charData.activities.lureKills or {}
            local points = charData and charData.activities and charData.activities.talentPoints or 0
            local lastReset = GetLastDailyReset()
            for _, lure in ipairs(profData.activities.majesticBeasts.lures) do
                if points >= lure.requiredPoints then
                    local killTS = lureKills[lure.name]
                    if not killTS or killTS < lastReset then
                        if lure.waypoint then
                            ns.SetWaypoint(lure.waypoint.map, lure.waypoint.x, lure.waypoint.y)
                            OpenWorldMap(lure.waypoint.map)
                        end
                        return
                    end
                end
            end
        end
    elseif action == "shoppinglist" then
        -- Create Auctionator shopping list for missing reagents
        if Auctionator and Auctionator.API and Auctionator.API.v1 then
            local profData = ns.ProfessionData[profKey]
            if profData and profData.activities and profData.activities.majesticBeasts then
                local items = {}
                for _, lure in ipairs(profData.activities.majesticBeasts.lures) do
                    for _, r in ipairs(lure.reagents) do
                        local count = C_Item.GetItemCount(r.itemID, true, false, true, true)
                        if count < r.count then
                            local name = C_Item.GetItemNameByID(r.itemID)
                            if name then
                                local searchStr = Auctionator.API.v1.ConvertToSearchString("DDT", { searchString = name })
                                items[searchStr] = true
                            end
                        end
                    end
                end
                local list = {}
                for s in pairs(items) do list[#list + 1] = s end
                if #list > 0 then
                    pcall(Auctionator.API.v1.CreateShoppingList, "DDT", "DDT Prof Reagents", list)
                    DDT:Print("Shopping list created: DDT Prof Reagents")
                else
                    DDT:Print("No missing reagents!")
                end
            end
        else
            DDT:Print("Auctionator not installed.")
        end
    elseif action == "bufflist" then
        -- Create Auctionator shopping list for profession buffs
        if Auctionator and Auctionator.API and Auctionator.API.v1 then
            local category = ns.PROF_GATHERING[profKey] and "gathering" or "crafting"
            local buffs = ns.PROF_BUFFS[category] or {}
            local items = {}
            for _, buff in ipairs(buffs) do
                local name = C_Item.GetItemNameByID(buff.itemID)
                if name then
                    local searchStr = Auctionator.API.v1.ConvertToSearchString("DDT", { searchString = name })
                    items[#items + 1] = searchStr
                end
            end
            if #items > 0 then
                pcall(Auctionator.API.v1.CreateShoppingList, "DDT", "DDT Prof Buffs", items)
                DDT:Print("Shopping list created: DDT Prof Buffs")
            end
        else
            DDT:Print("Auctionator not installed.")
        end
    elseif action == "buybuffs" then
        -- Create Auctionator shopping list for buffs the player is out of
        if Auctionator and Auctionator.API and Auctionator.API.v1 then
            local category = ns.PROF_GATHERING[profKey] and "gathering" or "crafting"
            local buffs = ns.PROF_BUFFS[category] or {}
            local items = {}
            for _, buff in ipairs(buffs) do
                local count = C_Item.GetItemCount(buff.itemID, true) or 0
                if count == 0 and not (buff.buffName and AuraUtil.FindAuraByName(buff.buffName, "player")) then
                    local name = C_Item.GetItemNameByID(buff.itemID)
                    if name then
                        local searchStr = Auctionator.API.v1.ConvertToSearchString("DDT", { searchString = name })
                        items[#items + 1] = searchStr
                    end
                end
            end
            if #items > 0 then
                pcall(Auctionator.API.v1.CreateShoppingList, "DDT", "DDT Restock Buffs", items)
                DDT:Print("Shopping list created: DDT Restock Buffs (" .. #items .. " missing)")
            else
                DDT:Print("All consumable buffs in stock!")
            end
        else
            DDT:Print("Auctionator not installed.")
        end
    elseif action == "pintooltip" then
        self:TogglePin(profKey)
    elseif action == "opensettings" then
        if DDT.settingsCategoryID then
            Settings.OpenToCategory(DDT.settingsCategoryID)
        end
    end
end

---------------------------------------------------------------------------
-- Event Handling
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

-- Build quest-to-lure lookup from all profession activity data
local questToLure = {}  -- { [questID] = { profKey, lureName } }
for profKey, profData in pairs(ns.ProfessionData) do
    if profData.activities and profData.activities.majesticBeasts then
        for _, lure in ipairs(profData.activities.majesticBeasts.lures) do
            questToLure[lure.questID] = { profKey = profKey, lureName = lure.name }
        end
    end
end

--- Sync lure kills from quest completion flags (called on login/reload)
function Professions:SyncLureKills(profKey)
    local profData = ns.ProfessionData[profKey]
    if not profData or not profData.activities or not profData.activities.majesticBeasts then return end

    local charData = self:GetCharData(profKey, self:GetDB().activeExpansion or "midnight")
    if not charData then return end
    if not charData.activities then charData.activities = {} end
    if not charData.activities.lureKills then charData.activities.lureKills = {} end

    for _, lure in ipairs(profData.activities.majesticBeasts.lures) do
        if C_QuestLog.IsQuestFlaggedCompleted(lure.questID) then
            local existing = charData.activities.lureKills[lure.name]
            if not existing or existing < GetLastDailyReset() then
                -- Quest flagged but no kill recorded today - record now
                charData.activities.lureKills[lure.name] = GetServerTime()
            end
        end
    end
end

---------------------------------------------------------------------------
-- Migration: MajesticBeast → Professions
---------------------------------------------------------------------------

function Professions:MigrateMajesticBeastData()
    local db = self:GetDB()
    if db._migratedFromMB then return end

    local mbDB = ns.db and ns.db.majesticbeast
    if not mbDB then return end

    -- Also check MajesticBeastTrackerDB (standalone addon shared data)
    local mbChars = (MajesticBeastTrackerDB and MajesticBeastTrackerDB.chars) or (mbDB and mbDB.chars)
    if not mbChars then
        db._migratedFromMB = true
        return
    end

    -- Migrate per-character lure kill data
    for charKey, mbChar in pairs(mbChars) do
        if mbChar.hasSkinning and mbChar.lures then
            if not db.chars then db.chars = {} end
            if not db.chars[charKey] then db.chars[charKey] = {} end
            if not db.chars[charKey].skinning then db.chars[charKey].skinning = {} end
            if not db.chars[charKey].skinning.midnight then db.chars[charKey].skinning.midnight = {} end
            local charData = db.chars[charKey].skinning.midnight
            if not charData.activities then charData.activities = {} end
            if not charData.activities.lureKills then charData.activities.lureKills = {} end

            -- Copy lure kill timestamps
            for lureName, timestamp in pairs(mbChar.lures) do
                if type(timestamp) == "number" and timestamp > 0 then
                    charData.activities.lureKills[lureName] = timestamp
                end
            end

            -- Copy talent points
            if mbChar.talentPoints and mbChar.talentPoints > 0 then
                charData.activities.talentPoints = mbChar.talentPoints
            end
        end
    end

    -- Migrate settings (tooltip scale, width, label template, click actions)
    local pdb = self:GetProfDB("skinning")
    if mbDB.tooltipScale then pdb.tooltipScale = mbDB.tooltipScale end
    if mbDB.tooltipWidth then pdb.tooltipWidth = mbDB.tooltipWidth end
    -- Set a profession-centric template instead of copying the old beast-only
    -- template, which lacked <name> and <kp_*> tags.
    pdb.labelTemplate = "<name>: <kp_earned>/<kp_total> KP  <mb_kills>/<mb_total> Beasts"
    if mbDB.clickActions then
        -- Map old MajesticBeast actions to new Professions equivalents
        local actionMap = {
            waypoint     = "waypointbeast",
            openmap      = "openmap",
            shoppinglist = "shoppinglist",
            bufflist     = "bufflist",
            opensettings = "opensettings",
            openmbt      = "openprofessions",  -- MBT window → profession window
            none         = "none",
        }
        for k, v in pairs(mbDB.clickActions) do
            pdb.clickActions[k] = actionMap[v] or v
        end
    end

    db._migratedFromMB = true
    DDT:Print("|cff33ff99Professions:|r Majestic Beast data migrated to Professions framework.")
end

--- Fix labels that are still beast-only from v1 migration
function Professions:FixMBLabelMigration()
    local db = self:GetDB()
    if db._mbLabelV2 then return end
    local pdb = db.perProf and db.perProf.skinning
    if pdb then
        -- Fix label if purely beast-centric
        if pdb.labelTemplate then
            local t = pdb.labelTemplate
            if t:find("<mb_") and not t:find("<name>") and not t:find("<kp_") then
                pdb.labelTemplate = "<name>: <kp_earned>/<kp_total> KP  <mb_kills>/<mb_total> Beasts"
            end
        end
        -- Fix click actions: map old MBT action names to new ones
        if pdb.clickActions then
            local actionMap = {
                waypoint = "waypointbeast", openmbt = "openprofessions",
            }
            for k, v in pairs(pdb.clickActions) do
                if actionMap[v] then pdb.clickActions[k] = actionMap[v] end
            end
        end
        -- Clear migrated tooltipMaxHeight so it inherits from module-level setting
        pdb.tooltipMaxHeight = nil
    end
    db._mbLabelV2 = true
end

function Professions:Init()
    self.charKey = UnitName("player") .. "-" .. GetRealmName()

    -- Run migrations
    self:MigrateMajesticBeastData()
    self:FixMBLabelMigration()
    -- Clear stale per-prof tooltipMaxHeight from MB migration (should inherit module-level)
    local mdb = self:GetDB()
    if not mdb._fixMaxHeight then
        local spdb = mdb.perProf and mdb.perProf.skinning
        if spdb then spdb.tooltipMaxHeight = nil end
        mdb._fixMaxHeight = true
    end

    eventFrame:SetScript("OnEvent", function(_, event, ...)
        Professions:OnEvent(event, ...)
    end)
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("SKILL_LINES_CHANGED")
    eventFrame:RegisterEvent("QUEST_TURNED_IN")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:RegisterEvent("UNIT_AURA")

    -- Two-pass detection: GetProfessions() and C_SpellBook.IsSpellKnown()
    -- return incomplete data at login. 2s covers most cases; 5s catches
    -- late-loading spell data (observed on slow connections).
    C_Timer.After(2, function()
        self:DetectProfessions()
        self:UpdateData()
        for profKey in pairs(profState) do
            self:SyncLureKills(profKey)
        end
    end)

    C_Timer.After(5, function()
        self:DetectProfessions()
        self:UpdateData()
        for profKey in pairs(profState) do
            self:SyncLureKills(profKey)
        end
    end)
end

function Professions:OnEvent(event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(3, function()
            self:DetectProfessions()
            self:UpdateData()
            for profKey in pairs(profState) do
                self:SyncLureKills(profKey)
            end
        end)
    elseif event == "SKILL_LINES_CHANGED" then
        self:DetectProfessions()
        self:UpdateData()
    elseif event == "QUEST_TURNED_IN" then
        local questID = ...
        -- Check if this is a lure kill
        local lureInfo = questToLure[questID]
        if lureInfo and profState[lureInfo.profKey] then
            local charData = self:GetCharData(lureInfo.profKey, self:GetDB().activeExpansion or "midnight")
            if charData then
                if not charData.activities then charData.activities = {} end
                if not charData.activities.lureKills then charData.activities.lureKills = {} end
                charData.activities.lureKills[lureInfo.lureName] = GetServerTime()
            end
        end
        -- A quest was completed - could be a KP source
        C_Timer.After(0.5, function()
            self:UpdateData()
            -- Refresh visible tooltips so kill status is reflected
            for pk in pairs(profState) do
                local tf = tooltipFrames[pk]
                if tf and tf:IsShown() then
                    self:PopulateTooltip(pk)
                end
            end
        end)
    elseif event == "BAG_UPDATE_DELAYED" then
        self:UpdateData()
    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" then
            -- Refresh buff status on visible tooltips
            for profKey in pairs(profState) do
                local tf = tooltipFrames[profKey]
                if tf and tf:IsShown() then
                    self:PopulateTooltip(profKey)
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Settings Panel
---------------------------------------------------------------------------

Professions.settingsLabel = "Professions"

function Professions:BuildSettingsPanel(panel)
    local W = ns.SettingsWidgets
    local r = panel.refreshCallbacks
    local db = function() return ns.db.professions end

    -- General settings
    local body = W.AddSection(panel, "General")
    local y = 0

    -- Expansion toggle
    local expansionValues = {}
    for key, exp in pairs(ns.PROF_EXPANSIONS) do
        expansionValues[key] = exp.label
    end
    y = W.AddDropdown(body, y, "Active Expansion", expansionValues,
        function() return db().activeExpansion end,
        function(v)
            db().activeExpansion = v
            self:DetectProfessions()
            self:UpdateData()
        end, r)

    -- Shared tooltip settings
    y = W.AddSliderPair(body, y,
        { label = "Default Scale", min = 0.5, max = 2.0, step = 0.05,
          get = function() return db().tooltipScale end,
          set = function(v) db().tooltipScale = v end },
        { label = "Default Width", min = 250, max = 600, step = 10,
          get = function() return db().tooltipWidth end,
          set = function(v) db().tooltipWidth = v end }, r)
    y = W.AddSlider(body, y, "Default Max Height", 200, 1000, 10,
        function() return db().tooltipMaxHeight end,
        function(v) db().tooltipMaxHeight = v end, r)
    W.EndSection(panel, y)

    -- Per-profession sections - built from PROF_DEFS (always available)
    -- Sort alphabetically by profession name
    local sortedProfs = {}
    for profKey, profDef in pairs(ns.PROF_DEFS) do
        table.insert(sortedProfs, { key = profKey, name = profDef.name })
    end
    table.sort(sortedProfs, function(a, b) return a.name < b.name end)

    for _, entry in ipairs(sortedProfs) do
        local profKey = entry.key
        local pdb = function() return self:GetProfDB(profKey) end
        local refresh = function() self:UpdateProfession(profKey) end

        local profBody = W.AddSection(panel, entry.name, true)  -- collapsed by default
        y = 0

        -- Label template
        local tags = "<name> <skill> <maxskill> <kp_earned> <kp_total> <concentration>"
        if profKey == "skinning" then
            tags = tags .. " <mb_kills> <mb_total> <mb_next>"
        end
        y = W.AddDescription(profBody, y, "Tags: " .. tags)
        y = W.AddEditBox(profBody, y, "Label Template",
            function() return pdb().labelTemplate end,
            function(v) pdb().labelTemplate = v; refresh() end, r)

        -- Tooltip overrides
        y = W.AddSliderPair(profBody, y,
            { label = "Scale", min = 0.5, max = 2.0, step = 0.05,
              get = function() return pdb().tooltipScale or db().tooltipScale end,
              set = function(v) pdb().tooltipScale = v end },
            { label = "Width", min = 250, max = 600, step = 10,
              get = function() return pdb().tooltipWidth or db().tooltipWidth end,
              set = function(v) pdb().tooltipWidth = v end }, r)

        -- Show/hide toggles
        y = W.AddCheckboxPair(profBody, y, "Show KP Sources",
            function() return pdb().showKPSources end,
            function(v) pdb().showKPSources = v end,
            "Show Buffs",
            function() return pdb().showBuffs end,
            function(v) pdb().showBuffs = v end, r)
        y = W.AddCheckboxPair(profBody, y, "Show Activities",
            function() return pdb().showActivities end,
            function(v) pdb().showActivities = v end,
            "Show Timers",
            function() return pdb().showTimers end,
            function(v) pdb().showTimers = v end, r)
        y = W.AddCheckboxPair(profBody, y, "Hide Known KP",
            function() return pdb().hideKnownKP end,
            function(v) pdb().hideKnownKP = v end,
            "Show Hint Bar",
            function() return pdb().showHintBar end,
            function(v) pdb().showHintBar = v end, r)
        W.EndSection(panel, y)

        -- Click actions as a sub-section
        local clickBody = W.AddSection(panel, entry.name .. " Click Actions", true)
        local cy = 0
        cy = W.AddDescription(clickBody, cy, "Configure what happens when you click the DataText.")
        local clickKeys = {
            { key = "leftClick",       label = "Left Click" },
            { key = "rightClick",      label = "Right Click" },
            { key = "middleClick",     label = "Middle Click" },
            { key = "shiftLeftClick",  label = "Shift + Left Click" },
            { key = "shiftRightClick", label = "Shift + Right Click" },
            { key = "ctrlLeftClick",   label = "Ctrl + Left Click" },
            { key = "ctrlRightClick",  label = "Ctrl + Right Click" },
            { key = "altLeftClick",    label = "Alt + Left Click" },
            { key = "altRightClick",   label = "Alt + Right Click" },
        }
        for _, ck in ipairs(clickKeys) do
            cy = W.AddDropdown(clickBody, cy, ck.label, ns.PROF_CLICK_ACTIONS,
                function() return pdb().clickActions[ck.key] end,
                function(v) pdb().clickActions[ck.key] = v end, r)
        end
        W.EndSection(panel, cy)

        -- Row click actions (for beast/activity rows)
        local rowBody = W.AddSection(panel, entry.name .. " Row Click Actions", true)
        local ry = 0
        ry = W.AddDescription(rowBody, ry, "Configure what happens when you click a beast or activity row in the tooltip.")
        for _, ck in ipairs(clickKeys) do
            ry = W.AddDropdown(rowBody, ry, ck.label, ns.PROF_ROW_CLICK_ACTIONS,
                function() return pdb().rowClickActions[ck.key] end,
                function(v) pdb().rowClickActions[ck.key] = v end, r)
        end
        W.EndSection(panel, ry)
    end
end

---------------------------------------------------------------------------
-- Module Registration
---------------------------------------------------------------------------

ns:RegisterModule("professions", Professions, DEFAULTS)
