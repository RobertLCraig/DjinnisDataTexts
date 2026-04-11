-- Djinni's Data Texts - Prey Tracker
-- Tracks active prey hunt, zone, progress, weekly completions, and currency.
-- Zone mapping sourced from Wowhead NPC spawn data (configurable in settings).
local addonName, ns = ...
local DDT = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local PreyTracker = {}
ns.PreyTracker = PreyTracker

-- State
local activeQuestID    = nil
local activePreyName   = nil
local activeDifficulty = nil
local activeMapID      = nil
local activeZoneName   = nil
local progressState    = nil

local weeklyCompleted  = {}   -- { { questID, name, difficulty, zone } }
local weeklyDoneCount  = 0

local tooltipFrame = nil
local hideTimer    = nil
local rowPool      = {}

---------------------------------------------------------------------------
-- Prey data - quest IDs, target names, and zone mapping
-- Zones sourced from Wowhead NPC spawn data (March 2026).
-- Users can override zones in settings if data changes.
---------------------------------------------------------------------------

local REMNANT_OF_ANGUISH = 3392

--- { [preyName] = { zone, normal, hard, nightmare } }
local PREY_DATA = {
    ["Magister Sunbreaker"]         = { zone = "Harandar",       normal = 91095, hard = 91210, nightmare = 91211 },
    ["Magistrix Emberlash"]         = { zone = "Zul'Aman",       normal = 91096, hard = 91212, nightmare = 91213 },
    ["Senior Tinker Ozwold"]        = { zone = "Harandar",       normal = 91097, hard = 91214, nightmare = 91215 },
    ["L-N-0R the Recycler"]         = { zone = "Harandar",       normal = 91098, hard = 91216, nightmare = 91217 },
    ["Mordril Shadowfell"]          = { zone = "Zul'Aman",       normal = 91099, hard = 91218, nightmare = 91219 },
    ["Deliah Gloomsong"]            = { zone = "Zul'Aman",       normal = 91100, hard = 91220, nightmare = 91221 },
    ["Phaseblade Talasha"]          = { zone = "Voidstorm",      normal = 91101, hard = 91222, nightmare = 91223 },
    ["Nexus-Edge Hadim"]            = { zone = "Zul'Aman",       normal = 91102, hard = 91224, nightmare = 91225 },
    ["Jo'zolo the Breaker"]         = { zone = "Zul'Aman",       normal = 91103, hard = 91226, nightmare = 91227 },
    ["Zadu, Fist of Nalorakk"]      = { zone = "Voidstorm",      normal = 91104, hard = 91228, nightmare = 91229 },
    ["The Talon of Jan'alai"]       = { zone = "Eversong Woods",  normal = 91105, hard = 91230, nightmare = 91231 },
    ["The Wing of Akil'zon"]        = { zone = "Eversong Woods",  normal = 91106, hard = 91232, nightmare = 91233 },
    ["Ranger Swiftglade"]           = { zone = "Harandar",       normal = 91107, hard = 91234, nightmare = 91235 },
    ["Lieutenant Blazewing"]        = { zone = "Harandar",       normal = 91108, hard = 91236, nightmare = 91237 },
    ["Petyoll the Razorleaf"]       = { zone = "Voidstorm",      normal = 91109, hard = 91238, nightmare = 91239 },
    ["Lamyne of the Undercroft"]    = { zone = "Voidstorm",      normal = 91110, hard = 91240, nightmare = 91241 },
    ["High Vindicator Vureem"]      = { zone = "Eversong Woods",  normal = 91111, hard = 91242, nightmare = 91256 },
    ["Crusader Luxia Maxwell"]      = { zone = "Eversong Woods",  normal = 91112, hard = 91243, nightmare = 91257 },
    ["Praetor Singularis"]          = { zone = "Eversong Woods",  normal = 91113, hard = 91244, nightmare = 91258 },
    ["Consul Nebulor"]              = { zone = "Harandar",       normal = 91114, hard = 91245, nightmare = 91259 },
    ["Executor Kaenius"]            = { zone = "Zul'Aman",       normal = 91115, hard = 91246, nightmare = 91260 },
    ["Imperator Enigmalia"]         = { zone = "Harandar",       normal = 91116, hard = 91247, nightmare = 91261 },
    ["Knight-Errant Bloodshatter"]  = { zone = "Eversong Woods",  normal = 91117, hard = 91248, nightmare = 91262 },
    ["Vylenna the Defector"]        = { zone = "Harandar",       normal = 91118, hard = 91249, nightmare = 91263 },
    ["Lost Theldrin"]               = { zone = "Eversong Woods",  normal = 91119, hard = 91250, nightmare = 91264 },
    ["Neydra the Starving"]         = { zone = "Zul'Aman",       normal = 91120, hard = 91251, nightmare = 91265 },
    ["Thornspeaker Edgath"]         = { zone = "Voidstorm",      normal = 91121, hard = 91252, nightmare = 91266 },
    ["Thorn-Witch Liset"]           = { zone = "Voidstorm",      normal = 91122, hard = 91253, nightmare = 91267 },
    ["Grothoz, the Burning Shadow"] = { zone = "Voidstorm",      normal = 91123, hard = 91254, nightmare = 91268 },
    ["Dengzag, the Darkened Blaze"] = { zone = "Eversong Woods",  normal = 91124, hard = 91255, nightmare = 91269 },
}

-- Special quests (achievements, intro, etc.) - tracked for weekly but no zone mapping
local SPECIAL_QUEST_IDS = {
    91207,  -- Apex Predator
    91458,  -- Endurance Hunter
    91523, 91590, 91591, 91592,  -- Concealed Threat variants
    91594, 91595, 91596,         -- Endurance Hunter variants
    91601, 91602, 91604,         -- Apex Predator variants
    92177,  -- One Hero's Prey
    92926,  -- Astalor's Initiative
    93043,  -- When Predator Becomes Prey
    95114,  -- A Crimson Summons
}

-- Reverse lookup: questID → { name, difficulty, zone }
local questLookup = {}

do
    for name, data in pairs(PREY_DATA) do
        local zone = data.zone
        if data.normal    then questLookup[data.normal]    = { name = name, difficulty = "Normal",    zone = zone } end
        if data.hard      then questLookup[data.hard]      = { name = name, difficulty = "Hard",      zone = zone } end
        if data.nightmare then questLookup[data.nightmare] = { name = name, difficulty = "Nightmare", zone = zone } end
    end
    for _, qID in ipairs(SPECIAL_QUEST_IDS) do
        if not questLookup[qID] then
            questLookup[qID] = { name = nil, difficulty = nil, zone = nil, special = true }
        end
    end
end

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
    labelTemplate    = "Prey: <zone> (<progress>)",
    tooltipScale     = 1.0,
    tooltipMaxHeight = 500,
    tooltipWidth     = 340,
    showWeekly       = true,
    showCurrency     = true,
    zoneOverrides    = {},
    clickActions = {
        leftClick       = "openmap",
        rightClick      = "setwaypoint",
        middleClick     = "none",
        shiftLeftClick  = "none",
        shiftRightClick = "none",
        ctrlLeftClick   = "none",
        ctrlRightClick  = "none",
        altLeftClick    = "opensettings",
        altRightClick   = "none",
    },
}

---------------------------------------------------------------------------
-- Click actions
---------------------------------------------------------------------------

local CLICK_ACTIONS = {
    openmap      = "Open Prey Zone on Map",
    setwaypoint  = "Set Waypoint to Prey",
    opensettings = "Open DDT Settings",
    none         = "None",
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local PROGRESS_LABELS = {
    [0] = "Cold",
    [1] = "Warm",
    [2] = "Hot",
    [3] = "Final",
}

local PROGRESS_COLORS = {
    [0] = { 0.6, 0.6, 0.6 },
    [1] = { 1.0, 0.8, 0.2 },
    [2] = { 1.0, 0.5, 0.1 },
    [3] = { 0.2, 1.0, 0.4 },
}

-- Hex equivalents for progress bar fill colors
local PROGRESS_HEX = {
    [0] = "ff999999",
    [1] = "ffffcc33",
    [2] = "ffff8019",
    [3] = "ff33ff66",
}

local BAR_SEGMENTS   = 20
local BAR_FILL_CHAR  = "||"  -- || renders as literal "|" in WoW (single | is escape prefix)
local BAR_EMPTY_CHAR = "\194\183"  -- UTF-8 middle dot (U+00B7); thin glyph to keep bar compact
local BAR_EMPTY_HEX  = "ff444444"

-- Progress state → how many segments to fill (out of BAR_SEGMENTS)
local PROGRESS_FILL = {
    [0] = 5,    -- Cold:  25%
    [1] = 10,   -- Warm:  50%
    [2] = 15,   -- Hot:   75%
    [3] = 20,   -- Final: 100%
}

--- Build an ASCII progress bar string for the given state
local function BuildProgressBar(state)
    if not state then return "" end
    local filled = PROGRESS_FILL[state] or 0
    local empty  = BAR_SEGMENTS - filled
    local hex    = PROGRESS_HEX[state] or PROGRESS_HEX[0]
    local label  = PROGRESS_LABELS[state] or ""

    return "|c" .. BAR_EMPTY_HEX .. "[|r"
        .. "|c" .. hex .. string.rep(BAR_FILL_CHAR, filled) .. "|r"
        .. "|c" .. BAR_EMPTY_HEX .. string.rep(BAR_EMPTY_CHAR, empty) .. "]|r"
        .. "  " .. "|c" .. hex .. label .. "|r"
end

local DIFFICULTY_COLORS = {
    Normal    = { 0.7, 0.7, 0.7 },
    Hard      = { 1.0, 0.6, 0.2 },
    Nightmare = { 0.8, 0.3, 0.9 },
}

--- Get zone for a prey name, checking user overrides first.
local function GetPreyZone(preyName)
    if not preyName then return nil end
    local db = ns.db and ns.db.preytracker
    if db and db.zoneOverrides and db.zoneOverrides[preyName] then
        return db.zoneOverrides[preyName]
    end
    local data = PREY_DATA[preyName]
    return data and data.zone or nil
end

--- Parse quest title: "Prey: Name (Difficulty)" → name, difficulty
local function ParseQuestTitle(title)
    if not title then return nil, nil end
    local name, diff = title:match("^Prey:%s*(.-)%s*%((%w+)%)%s*$")
    if name and diff then return name, diff end
    name = title:match("^Prey:%s*(.+)%s*$")
    return name, nil
end

--- Get zone name from a mapID
local function GetZoneName(mapID)
    if not mapID then return nil end
    local info = C_Map.GetMapInfo(mapID)
    return info and info.name or nil
end

--- Scan UI widget sets for prey hunt progress state
local preyWidgetID = nil
local function ScanPreyProgressState()
    if preyWidgetID then
        local info = C_UIWidgetManager.GetPreyHuntProgressWidgetVisualizationInfo(preyWidgetID)
        if info and info.shownState ~= Enum.WidgetShownState.Hidden then
            return info.progressState
        end
        preyWidgetID = nil
    end

    local setIDs = {}
    local fn
    fn = C_UIWidgetManager.GetTopCenterWidgetSetID
    if fn then setIDs[#setIDs + 1] = fn() end
    fn = C_UIWidgetManager.GetBelowMinimapWidgetSetID
    if fn then setIDs[#setIDs + 1] = fn() end
    fn = C_UIWidgetManager.GetObjectiveTrackerWidgetSetID
    if fn then setIDs[#setIDs + 1] = fn() end

    for _, setID in ipairs(setIDs) do
        local widgets = C_UIWidgetManager.GetAllWidgetsBySetID(setID)
        if widgets then
            for _, w in ipairs(widgets) do
                if w.widgetType == Enum.UIWidgetVisualizationType.PreyHuntProgress then
                    preyWidgetID = w.widgetID
                    local info = C_UIWidgetManager.GetPreyHuntProgressWidgetVisualizationInfo(w.widgetID)
                    if info and info.shownState ~= Enum.WidgetShownState.Hidden then
                        return info.progressState
                    end
                end
            end
        end
    end
    return nil
end

--- Scan all known prey quest IDs for weekly completion.
local function ScanWeeklyCompletions()
    weeklyCompleted = {}
    weeklyDoneCount = 0

    for qID, info in pairs(questLookup) do
        if C_QuestLog.IsQuestFlaggedCompleted(qID) then
            local name = info.name
            if not name then
                name = C_QuestLog.GetTitleForQuestID(qID)
                if name then name = ParseQuestTitle(name) or name end
            end
            table.insert(weeklyCompleted, {
                questID    = qID,
                name       = name or ("Quest " .. qID),
                difficulty = info.difficulty or "Special",
                zone       = info.zone or GetPreyZone(name),
            })
            weeklyDoneCount = weeklyDoneCount + 1
        end
    end

    table.sort(weeklyCompleted, function(a, b)
        local za = a.zone or ""
        local zb = b.zone or ""
        if za ~= zb then return za < zb end
        local na = a.name or ""
        local nb = b.name or ""
        if na ~= nb then return na < nb end
        return (a.difficulty or "") < (b.difficulty or "")
    end)
end

---------------------------------------------------------------------------
-- Data collection
---------------------------------------------------------------------------

function PreyTracker:UpdateData()
    local db = self:GetDB()

    -- Active prey quest
    activeQuestID    = C_QuestLog.GetActivePreyQuest()
    activePreyName   = nil
    activeDifficulty = nil
    activeMapID      = nil
    activeZoneName   = nil
    progressState    = nil

    if activeQuestID then
        local title = C_QuestLog.GetTitleForQuestID(activeQuestID) or "Prey Hunt"
        activePreyName, activeDifficulty = ParseQuestTitle(title)
        if not activePreyName then activePreyName = title end

        -- Zone: try API first, then fallback to mapping table
        local ignoreWaypoints = true
        if GetQuestUiMapID then
            activeMapID = GetQuestUiMapID(activeQuestID, ignoreWaypoints)
        end
        if not activeMapID then
            activeMapID = C_TaskQuest.GetQuestZoneID(activeQuestID)
        end
        activeZoneName = GetZoneName(activeMapID) or GetPreyZone(activePreyName)

        if not activeZoneName then
            local info = questLookup[activeQuestID]
            if info then activeZoneName = info.zone end
        end

        progressState = ScanPreyProgressState()
    end

    -- Weekly completions
    if db.showWeekly then
        ScanWeeklyCompletions()
    end

    self:UpdateLabel()
end

function PreyTracker:UpdateLabel()
    local db = self:GetDB()
    local template = db.labelTemplate or "<status>"
    local E = ns.ExpandTag

    local statusStr
    if activeQuestID then
        local prog = progressState and PROGRESS_LABELS[progressState] or "Active"
        statusStr = activePreyName or "Prey Hunt"
        if activeZoneName then statusStr = statusStr .. " - " .. activeZoneName end
        if activeDifficulty then statusStr = statusStr .. " (" .. prog .. ")" end
    else
        statusStr = weeklyDoneCount > 0 and (weeklyDoneCount .. " prey done") or "No Prey"
    end

    local zoneStr  = activeZoneName or (activeQuestID and "Tracking..." or "-")
    local progStr  = (progressState and BuildProgressBar(progressState)) or (activeQuestID and "Active" or "-")
    local diffStr  = activeDifficulty or "-"
    local preyStr  = activePreyName or "-"
    local doneStr  = tostring(weeklyDoneCount)

    local currStr = "-"
    local currInfo = C_CurrencyInfo.GetCurrencyInfo(REMNANT_OF_ANGUISH)
    if currInfo then currStr = tostring(currInfo.quantity) end

    local result = template
    result = E(result, "status",     statusStr)
    result = E(result, "zone",       zoneStr)
    result = E(result, "progress",   progStr)
    result = E(result, "difficulty", diffStr)
    result = E(result, "diff",       diffStr)
    result = E(result, "prey",       preyStr)
    result = E(result, "weekly",     doneStr)
    result = E(result, "currency",   currStr)

    self.dataobj.text = result

    -- Push the new label up to the ActiveActivity aggregator (no-op if it
    -- hasn't initialized yet).
    if ns.NotifyActivityChange then ns:NotifyActivityChange() end
end

function PreyTracker:GetDB()
    return ns.db and ns.db.preytracker or DEFAULTS
end

---------------------------------------------------------------------------
-- Click action executor
---------------------------------------------------------------------------

local function ExecuteAction(action)
    if action == "openmap" then
        if activeMapID then
            OpenWorldMap(activeMapID)
            if activeQuestID then
                EventRegistry:TriggerEvent("MapCanvas.PingQuestID", activeQuestID)
            end
        end
    elseif action == "setwaypoint" then
        if activeQuestID then
            local mapID = activeMapID or C_Map.GetBestMapForUnit("player")
            local x, y = C_QuestLog.GetNextWaypoint(activeQuestID)
            if not x or not y then
                x, y = C_TaskQuest.GetQuestLocation(activeQuestID, mapID)
            end
            if x and y and mapID then
                ns.SetWaypoint(mapID, x, y, "Waypoint set for " .. (activePreyName or "prey target"))
            else
                DDT:DjinniMsg("No waypoint data available for active prey")
            end
        else
            DDT:DjinniMsg("No active prey hunt")
        end
    elseif action == "pintooltip" then
        ns:TogglePinTooltip(PreyTracker, tooltipFrame)
    elseif action == "opensettings" then
        Settings.OpenToCategory(DDT.settingsCategoryID)
    end
end

---------------------------------------------------------------------------
-- ActiveActivity tracker registration
--
-- This module no longer creates its own LDB DataBroker. Instead it registers
-- with the unified ActiveActivity datatext, which routes hover/click/label
-- to whichever activity is currently engaged. A stub `dataobj` is kept so
-- legacy code paths in this file (UpdateLabel writes self.dataobj.text)
-- continue to work without crashing.
---------------------------------------------------------------------------

local dataobj = { text = "Prey", icon = "Interface\\Icons\\worldquest-prey-crystal" }
PreyTracker.dataobj = dataobj

function PreyTracker:IsActive()
    return activeQuestID ~= nil
end

function PreyTracker:GetLabelText()
    return self.dataobj.text or ""
end

local function HandleClick(button)
    PreyTracker:CancelHideTimer()
    local db = PreyTracker:GetDB()
    local action = DDT:ResolveClickAction(button, db.clickActions)
    -- Pinning needs to keep the tooltip visible; only auto-hide for non-pin actions.
    if action ~= "pintooltip" and tooltipFrame then tooltipFrame:Hide() end
    if action and action ~= "none" then
        ExecuteAction(action)
    end
end

if ns.RegisterActivityTracker then
    ns:RegisterActivityTracker("prey", {
        displayName = "Prey Hunt",
        icon        = "Interface\\Icons\\worldquest-prey-crystal",
        priority    = 20,
        IsActive    = function() return PreyTracker:IsActive() end,
        GetLabelText = function() return PreyTracker:GetLabelText() end,
        ShowTooltip = function(anchor)
            PreyTracker:CancelHideTimer()
            PreyTracker:ShowTooltip(anchor)
        end,
        HideTooltip = function()
            PreyTracker:StartHideTimer()
        end,
        HandleClick = HandleClick,
    })
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------

local TOOLTIP_PADDING = ns.TOOLTIP_PADDING

local function GetOrCreateRow(parent, index)
    if rowPool[index] then
        rowPool[index]:Show()
        return rowPool[index]
    end

    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ns.ROW_HEIGHT)

    row.left = ns.FontString(row, "DDTFontNormal")
    row.left:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.left:SetJustifyH("LEFT")
    row.left:SetJustifyV("TOP")

    row.mid = ns.FontString(row, "DDTFontSmall")
    row.mid:SetJustifyH("LEFT")
    row.mid:SetJustifyV("TOP")

    row.right = ns.FontString(row, "DDTFontSmall")
    row.right:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    row.right:SetJustifyH("RIGHT")
    row.right:SetJustifyV("TOP")

    rowPool[index] = row
    return row
end

local function CreateTooltipFrame()
    return ns.CreateTooltipFrame(nil, PreyTracker)
end

function PreyTracker:PopulateTooltip()
    if not tooltipFrame then return end

    local db = self:GetDB()
    local sc = tooltipFrame.scrollContent
    local tooltipWidth = db.tooltipWidth or 340
    local innerWidth = tooltipWidth - 2 * TOOLTIP_PADDING

    local nameW = math.floor(innerWidth * 0.42)
    local zoneW = math.floor(innerWidth * 0.32)
    local diffW = math.max(50, innerWidth - nameW - zoneW - 8)

    for _, row in pairs(rowPool) do row:Hide() end

    tooltipFrame.header:SetText(DDT:ColorText("Prey Tracker", 1, 0.82, 0))

    local rowIdx = 0
    local yOffset = 0
    local rowStep = ns.ROW_HEIGHT + 2

    local function AddRow(leftText, midText, rightText, leftColor, midColor, rightColor)
        rowIdx = rowIdx + 1
        local row = GetOrCreateRow(sc, rowIdx)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, yOffset)

        row.left:SetWidth(nameW)
        row.left:SetWordWrap(true)
        row.left:SetText(leftText or "")
        if leftColor then row.left:SetTextColor(unpack(leftColor)) else row.left:SetTextColor(1, 1, 1) end

        row.mid:ClearAllPoints()
        row.mid:SetPoint("TOPLEFT", row.left, "TOPRIGHT", 4, 0)
        row.mid:SetWidth(zoneW)
        row.mid:SetText(midText or "")
        if midColor then row.mid:SetTextColor(unpack(midColor)) else row.mid:SetTextColor(0.63, 0.82, 1) end

        row.right:SetWidth(diffW)
        row.right:SetText(rightText or "")
        if rightColor then row.right:SetTextColor(unpack(rightColor)) else row.right:SetTextColor(0.7, 0.7, 0.7) end

        -- Measure actual text height (accounts for word-wrap)
        local textH = math.max(row.left:GetStringHeight(), ns.ROW_HEIGHT)
        row:SetSize(innerWidth, textH)

        yOffset = yOffset - textH - 2
    end

    -- Active hunt
    if activeQuestID then
        local diffColor = activeDifficulty and DIFFICULTY_COLORS[activeDifficulty] or { 0.7, 0.7, 0.7 }

        AddRow(activePreyName or "Prey Hunt", activeZoneName or "Unknown", activeDifficulty or "",
            { 1, 0.82, 0 }, { 0.63, 0.82, 1 }, diffColor)

        -- Progress bar row (spans full width)
        rowIdx = rowIdx + 1
        local barRow = GetOrCreateRow(sc, rowIdx)
        barRow:ClearAllPoints()
        barRow:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, yOffset)
        barRow.left:SetWidth(innerWidth)
        barRow.left:SetText(BuildProgressBar(progressState))
        barRow.left:SetTextColor(1, 1, 1)
        barRow.mid:SetText("")
        barRow.right:SetText("")
        barRow:SetSize(innerWidth, ns.ROW_HEIGHT)
        yOffset = yOffset - ns.ROW_HEIGHT - 2
    else
        AddRow("No active prey hunt", nil, nil, { 0.5, 0.5, 0.5 })
    end

    -- Weekly completions
    if db.showWeekly then
        yOffset = yOffset - 4

        AddRow("Weekly Completions", nil, tostring(weeklyDoneCount),
            { 0.8, 0.8, 0.4 }, nil, { 0, 1, 0 })

        if weeklyDoneCount == 0 then
            AddRow("  No completions yet", nil, nil, { 0.5, 0.5, 0.5 })
        else
            AddRow("|cffaaaaaaTarget|r", "|cffaaaaaaZone|r", "|cffaaaaaaDiff|r")
            local hdrRow = rowPool[rowIdx]
            hdrRow.left:SetTextColor(0.67, 0.67, 0.67)
            hdrRow.mid:SetTextColor(0.67, 0.67, 0.67)
            hdrRow.right:SetTextColor(0.67, 0.67, 0.67)

            for _, entry in ipairs(weeklyCompleted) do
                local diffColor = DIFFICULTY_COLORS[entry.difficulty] or { 0.7, 0.7, 0.7 }
                AddRow(
                    "|cff66c955[+]|r " .. (entry.name or "Unknown"),
                    entry.zone or "",
                    entry.difficulty or "",
                    { 0.4, 0.7, 0.4 }, { 0.63, 0.82, 1 }, diffColor)
            end
        end
    end

    -- Currency
    if db.showCurrency then
        local currInfo = C_CurrencyInfo.GetCurrencyInfo(REMNANT_OF_ANGUISH)
        if currInfo then
            yOffset = yOffset - 4
            AddRow(
                (currInfo.iconFileID and ("|T" .. currInfo.iconFileID .. ":14|t ") or "") .. (currInfo.name or "Remnant of Anguish"),
                nil, tostring(currInfo.quantity),
                { 0.8, 0.6, 1 }, nil, { 1, 1, 1 })
        end
    end

    -- Hint bar
    tooltipFrame.hint:SetText(DDT:BuildHintText(db.clickActions or {}, CLICK_ACTIONS))

    local contentH = math.max(math.abs(yOffset), ns.ROW_HEIGHT)
    tooltipFrame:FinalizeLayout(tooltipWidth, contentH)
end

function PreyTracker:ShowTooltip(anchor)
    if not tooltipFrame then
        tooltipFrame = CreateTooltipFrame()
    end

    self:CancelHideTimer()

    local db = self:GetDB()
    ns.AnchorTooltip(tooltipFrame, anchor, db.tooltipGrowDirection)
    tooltipFrame:SetScale(db.tooltipScale or 1.0)

    self:UpdateData()
    self:PopulateTooltip()
    tooltipFrame:Show()
end

function PreyTracker:StartHideTimer()
    self:CancelHideTimer()
    hideTimer = C_Timer.NewTimer(ns.HIDE_DELAY, function()
        if tooltipFrame then tooltipFrame:Hide() end
        hideTimer = nil
    end)
end

function PreyTracker:CancelHideTimer()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
end

---------------------------------------------------------------------------
-- Event handling
---------------------------------------------------------------------------

function PreyTracker:Init()
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
    eventFrame:RegisterEvent("QUEST_ACCEPTED")
    eventFrame:RegisterEvent("QUEST_REMOVED")
    eventFrame:RegisterEvent("QUEST_TURNED_IN")
    eventFrame:RegisterEvent("UPDATE_UI_WIDGET")
    eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            self:UpdateData()
        elseif event == "UPDATE_UI_WIDGET" then
            local widgetInfo = ...
            if widgetInfo and widgetInfo.widgetType == Enum.UIWidgetVisualizationType.PreyHuntProgress then
                preyWidgetID = widgetInfo.widgetID
                self:UpdateData()
            end
        elseif event == "CURRENCY_DISPLAY_UPDATE" then
            self:UpdateLabel()
        elseif event == "QUEST_LOG_UPDATE" then
            local newActiveID = C_QuestLog.GetActivePreyQuest()
            if newActiveID ~= activeQuestID then
                self:UpdateData()
            end
        elseif event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED" or event == "QUEST_TURNED_IN" then
            self:UpdateData()
        end
    end)
end

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------

PreyTracker.settingsLabel = "Prey Tracker"

function PreyTracker:BuildSettingsPanel(panel)
    local W = ns.SettingsWidgets
    local r = panel.refreshCallbacks
    local db = function() return ns.db.preytracker end

    W.AddLabelEditBox(panel, "status zone progress difficulty diff prey weekly currency",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateData() end, r, {
        { "Default",       "Prey: <zone> (<progress>)" },
        { "Status",        "<status>" },
        { "Target",        "<prey> (<diff>)" },
        { "Zone + Diff",   "<zone> - <diff>" },
        { "Weekly",        "<weekly> prey done" },
        { "Currency",      "Anguish: <currency>" },
        { "Full",          "<prey> <zone> <progress> | <weekly>" },
    })

    -- Display
    local body = W.AddSection(panel, "Display")
    local y = 0
    y = W.AddCheckbox(body, y, "Show weekly prey completions in tooltip",
        function() return db().showWeekly end,
        function(v) db().showWeekly = v; self:UpdateData() end, r)
    y = W.AddCheckbox(body, y, "Show Remnant of Anguish currency",
        function() return db().showCurrency end,
        function(v) db().showCurrency = v; self:UpdateData() end, r)
    W.EndSection(panel, y)

    -- Tooltip
    body = W.AddSection(panel, "Tooltip", true)
    y = 0
    y = W.AddSliderPair(body, y,
        { label = "Scale", min = 0.5, max = 2.0, step = 0.05,
          get = function() return db().tooltipScale end,
          set = function(v) db().tooltipScale = v end },
        { label = "Width", min = 250, max = 600, step = 10,
          get = function() return db().tooltipWidth end,
          set = function(v) db().tooltipWidth = v end }, r)
    y = W.AddSliderPair(body, y,
        { label = "Max Height", min = 100, max = 800, step = 10,
          get = function() return db().tooltipMaxHeight end,
          set = function(v) db().tooltipMaxHeight = v end },
        nil, r)
    y = W.AddTooltipGrowDirection(body, y, db, r)
    y = W.AddTooltipCopyFrom(body, y, "preytracker", db, r)
    W.EndSection(panel, y)

    -- Click Actions
    ns.AddModuleClickActionsSection(panel, r, "preytracker", CLICK_ACTIONS)

    -- Zone Mapping
    body = W.AddSection(panel, "Prey Zone Mapping", true)
    y = 0
    y = W.AddDescription(body, y, "Default zones sourced from Wowhead. Click a prey name to copy its Wowhead URL.")

    local sortedNames = {}
    for name in pairs(PREY_DATA) do
        sortedNames[#sortedNames + 1] = name
    end
    table.sort(sortedNames)

    for _, preyName in ipairs(sortedNames) do
        local pName = preyName
        local data = PREY_DATA[pName]

        -- Clickable prey name label (copies Wowhead quest URL)
        local link = CreateFrame("Button", nil, body)
        link:SetPoint("TOPLEFT", body, "TOPLEFT", 14, y)
        link:SetSize(200, 20)

        local linkText = link:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        linkText:SetPoint("LEFT")
        linkText:SetJustifyH("LEFT")
        linkText:SetText("|cff55bbff" .. pName .. "|r")

        link:SetScript("OnEnter", function(self)
            linkText:SetText("|cff88ddff" .. pName .. "|r")
        end)
        link:SetScript("OnLeave", function(self)
            linkText:SetText("|cff55bbff" .. pName .. "|r")
        end)
        link:SetScript("OnClick", function()
            local questID = data.normal
            if questID then
                ns.CopyURL("https://www.wowhead.com/quest=" .. questID)
            end
        end)

        -- Zone dropdown on the right
        local dropdown = CreateFrame("DropdownButton", nil, body, "WowStyle1DropdownTemplate")
        dropdown:SetPoint("LEFT", link, "RIGHT", 8, 0)
        dropdown:SetWidth(160)

        dropdown:SetupMenu(function(_, rootDescription)
            for _, zone in ipairs({"Eversong Woods", "Harandar", "Voidstorm", "Zul'Aman"}) do
                rootDescription:CreateButton(zone, function()
                    if zone == data.zone then
                        db().zoneOverrides[pName] = nil
                    else
                        db().zoneOverrides[pName] = zone
                    end
                end):SetIsSelected(function()
                    return (db().zoneOverrides[pName] or data.zone) == zone
                end)
            end
        end)

        if r then
            table.insert(r, function() dropdown:GenerateMenu() end)
        end

        y = y - 28
    end
    W.EndSection(panel, y)
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("preytracker", PreyTracker, DEFAULTS)
