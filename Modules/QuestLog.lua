-- Djinni's Data Texts - Quest Log
-- Quests held out of the cap, how many are ready to hand in, and the whole
-- log grouped by its own headers or by zone, with track, open and abandon.
local addonName, ns = ...
local DDT = ns.addon

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local QuestLog = {}
ns.QuestLog = QuestLog

-- Tooltip
local tooltipFrame = nil
local hideTimer = nil

-- Layout
local TOOLTIP_WIDTH  = 340
local HEADER_HEIGHT  = 18
local PADDING        = 10

-- Quest events arrive in bursts (QUEST_LOG_UPDATE fires several times for one
-- accept), so they rebuild at most once per this many seconds.
local THROTTLE = 0.5

-- State, refreshed by UpdateData
local counts = { quests = 0, ready = 0, daily = 0, weekly = 0 }
local numQuests, maxQuests = 0, 0

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
    labelTemplate    = "<count>/<max>",
    groupBy          = "header",
    tooltipScale     = 1.0,
    tooltipMaxHeight = 500,
    tooltipWidth     = 340,
    clickActions     = {
        leftClick       = "questlog",
        rightClick      = "menu",
        middleClick     = "none",
        shiftLeftClick  = "none",
        shiftRightClick = "none",
        ctrlLeftClick   = "none",
        ctrlRightClick  = "none",
        altLeftClick    = "opensettings",
        altRightClick   = "none",
    },
}

local CLICK_ACTIONS = {
    questlog     = "Quest Log",
    menu         = "Menu",
    opensettings = "Open DDT Settings",
    none         = "None",
}

local GROUP_VALUES = {
    header = "Quest Log Headers",
    zone   = "Zone",
}

---------------------------------------------------------------------------
-- Pure helpers. Lifted and run by docs/build/check-questlog.lua, so keep
-- everything between the markers free of WoW API calls.
--
-- An entry is { isHeader, title, questID, mapID, ready, failed, frequency,
-- isHidden, isTask }, built from C_QuestLog.GetInfo in log order. Titles and
-- objective texts are game strings and may be 12.1 secrets, so they are only
-- ever passed through: never concatenated, compared or used as a key.
---------------------------------------------------------------------------

-- [ql-helpers]
local QLH = {}

-- Enum.QuestFrequency: Daily = 1, Weekly = 2.
local FREQ_DAILY, FREQ_WEEKLY = 1, 2

local function Listed(e)
    return not e.isHeader and not e.isHidden and not e.isTask
end

--- <count> and <max> are quests held out of the cap; <ready> is how many can
--- be handed in.
function QLH.ExpandLabel(template, count, max, ready)
    local result = ns.ExpandTag(template, "count", count)
    result = ns.ExpandTag(result, "max", max)
    result = ns.ExpandTag(result, "ready", ready)
    return (result:gsub("^%s+", ""):gsub("%s+$", ""))
end

--- Groups in log order. "header" follows the log's own zone and campaign
--- headers; "zone" groups by map ID in order of first appearance, with
--- quests that have no map last. Empty groups are dropped.
function QLH.Group(entries, mode)
    local groups = {}
    if mode == "zone" then
        local byMap, other = {}, nil
        for _, e in ipairs(entries) do
            if Listed(e) then
                local g
                if e.mapID then
                    g = byMap[e.mapID]
                    if not g then
                        g = { mapID = e.mapID, quests = {} }
                        byMap[e.mapID] = g
                        groups[#groups + 1] = g
                    end
                else
                    other = other or { quests = {} }
                    g = other
                end
                g.quests[#g.quests + 1] = e
            end
        end
        if other then groups[#groups + 1] = other end
        return groups
    end

    local current = nil
    for _, e in ipairs(entries) do
        if e.isHeader then
            current = { title = e.title, quests = {} }
            groups[#groups + 1] = current
        elseif Listed(e) then
            if not current then
                current = { quests = {} }
                groups[#groups + 1] = current
            end
            current.quests[#current.quests + 1] = e
        end
    end
    local kept = {}
    for _, g in ipairs(groups) do
        if #g.quests > 0 then kept[#kept + 1] = g end
    end
    return kept
end

function QLH.Counts(entries)
    local c = { quests = 0, ready = 0, daily = 0, weekly = 0 }
    for _, e in ipairs(entries) do
        if Listed(e) then
            c.quests = c.quests + 1
            if e.ready then c.ready = c.ready + 1 end
            if e.frequency == FREQ_DAILY then c.daily = c.daily + 1 end
            if e.frequency == FREQ_WEEKLY then c.weekly = c.weekly + 1 end
        end
    end
    return c
end

--- One progress line for a quest: a short value for the right-hand column
--- and, while in progress, the first unfinished objective's own text.
function QLH.Progress(objectives, ready, failed)
    if failed then return { state = "failed", value = "Failed" } end
    if ready then return { state = "ready", value = "Ready" } end
    local total, done, detail = 0, 0, nil
    for _, o in ipairs(objectives or {}) do
        total = total + 1
        if o.finished then
            done = done + 1
        elseif detail == nil then
            detail = o.text
        end
    end
    return {
        state  = "active",
        value  = total > 0 and (done .. "/" .. total) or "",
        detail = detail,
    }
end

--- Returns poke(). The first poke in a window schedules one run at its end;
--- the rest of the burst is absorbed. `after` is C_Timer.After.
function QLH.NewThrottle(window, after, run)
    local pending = false
    return function()
        if pending then return false end
        pending = true
        after(window, function()
            pending = false
            run()
        end)
        return true
    end
end
-- [/ql-helpers]

---------------------------------------------------------------------------
-- Reading the log
---------------------------------------------------------------------------

local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

--- Walks the log. `full` adds what only the tooltip needs: objectives and
--- the zone each quest is on.
local function ReadLog(full)
    local entries = {}
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info then
            local id = Plain(info.questID)
            local e = {
                isHeader  = info.isHeader,
                title     = info.title,
                questID   = id,
                frequency = info.frequency,
                isHidden  = info.isHidden,
                isTask    = info.isTask,
            }
            if not info.isHeader then
                if not id then
                    e.isHidden = true
                else
                    e.ready  = C_QuestLog.ReadyForTurnIn(id) or false
                    e.failed = C_QuestLog.IsFailed(id)
                    if full then
                        e.objectives = C_QuestLog.GetQuestObjectives(id)
                        local mapID = GetQuestUiMapID and Plain(GetQuestUiMapID(id))
                        e.mapID = (mapID and mapID > 0) and mapID or nil
                        e.tracked = C_QuestLog.GetQuestWatchType(id) ~= nil
                    end
                end
            end
            entries[#entries + 1] = e
        end
    end
    return entries
end

---------------------------------------------------------------------------
-- LDB Data Object
---------------------------------------------------------------------------

local function OpenSettings()
    if DDT.settingsCategoryID then
        Settings.OpenToCategory(DDT.settingsCategoryID)
    end
end

local function OpenBrokerMenu(owner)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle("Quest Log")
        root:CreateButton("Open quest log", function() ToggleQuestLog() end)
        root:CreateButton("Open DDT settings", OpenSettings)
    end)
end

local dataobj = ns:NewBroker("questlog", "DDT-QuestLog", {
    type  = "data source",
    text  = "0/0",
    icon  = "Interface\\Icons\\INV_Misc_Book_08",
    label = "DDT - Quest Log",
    OnEnter = function(self)
        QuestLog:ShowTooltip(self)
    end,
    OnLeave = function()
        QuestLog:StartHideTimer()
    end,
    OnClick = function(self, button)
        local db = QuestLog:GetDB()
        local action = DDT:ResolveClickAction(button, db.clickActions or {})
        if action == "questlog" then
            ToggleQuestLog()
        elseif action == "menu" then
            OpenBrokerMenu(self)
        elseif action == "pintooltip" then
            ns:TogglePinTooltip(QuestLog, tooltipFrame)
        elseif action == "opensettings" then
            OpenSettings()
        end
    end,
})

QuestLog.dataobj = dataobj

---------------------------------------------------------------------------
-- Event handling
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

local EVENTS = {
    "PLAYER_ENTERING_WORLD",
    "QUEST_LOG_UPDATE",
    "QUEST_ACCEPTED",
    "QUEST_REMOVED",
    "QUEST_TURNED_IN",
    "QUEST_WATCH_LIST_CHANGED",
}

local poke = QLH.NewThrottle(THROTTLE, C_Timer.After, function()
    QuestLog:UpdateData()
end)

function QuestLog:Init()
    -- Handler first, then each event singly and confirmed: a refused
    -- RegisterEvent raises no Lua error (workspace decision, 2026-08-21).
    eventFrame:SetScript("OnEvent", function() poke() end)
    for _, event in ipairs(EVENTS) do
        eventFrame:RegisterEvent(event)
        if not eventFrame:IsEventRegistered(event) then
            DDT:Print("Quest Log: the game refused " .. event .. "; that update will wait for the poll.")
        end
    end
end

function QuestLog:GetDB()
    return ns.db and ns.db.questlog or DEFAULTS
end

---------------------------------------------------------------------------
-- Data collection
---------------------------------------------------------------------------

function QuestLog:UpdateData()
    local _, n = C_QuestLog.GetNumQuestLogEntries()
    numQuests = n or 0
    maxQuests = C_QuestLog.GetMaxNumQuestsCanAccept() or 0
    counts = QLH.Counts(ReadLog(false))

    local db = self:GetDB()
    dataobj.text = QLH.ExpandLabel(db.labelTemplate, numQuests, maxQuests, counts.ready)

    if tooltipFrame and tooltipFrame:IsShown() then
        self:BuildTooltipContent()
    end
end

---------------------------------------------------------------------------
-- Row actions
---------------------------------------------------------------------------

local function OpenQuest(id)
    QuestMapFrame_OpenToQuestDetails(id)
end

local function ToggleTrack(id, tracked)
    if tracked then
        C_QuestLog.RemoveQuestWatch(id)
    else
        C_QuestLog.AddQuestWatch(id)
    end
end

-- Blizzard's own abandon: it selects the quest and shows the ABANDON_QUEST
-- (or ABANDON_QUEST_WITH_ITEMS) confirmation, and only that dialog's accept
-- button abandons. Never C_QuestLog.AbandonQuest from here.
local function Abandon(id)
    if QuestMapQuestOptions_AbandonQuest then
        QuestMapQuestOptions_AbandonQuest(id)
    end
end

local function OpenRowMenu(row)
    local id, title, tracked = row.questID, row.questTitle, row.tracked
    MenuUtil.CreateContextMenu(row, function(_, root)
        if title then root:CreateTitle(title) end
        root:CreateButton(tracked and "Untrack" or "Track", function() ToggleTrack(id, tracked) end)
        root:CreateButton("Open", function() OpenQuest(id) end)
        if C_QuestLog.CanAbandonQuest(id) and QuestMapQuestOptions_AbandonQuest then
            root:CreateButton("Abandon...", function() Abandon(id) end)
        end
    end)
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------

local function CreateTooltipFrame()
    local f = ns.CreateTooltipFrame("DDTQuestLogTooltip", QuestLog)
    f.content.rows = {}
    return f
end

-- One pool of Button rows for every line. A row with questID set is
-- clickable and highlights; the rest are plain text.
local function GetRow(c, index)
    local row = c.rows[index]
    if not row then
        row = CreateFrame("Button", nil, c)
        row:SetHeight(ns.ROW_HEIGHT)
        row:RegisterForClicks("AnyUp")

        row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
        row.highlight:SetAllPoints()
        row.highlight:SetColorTexture(1, 1, 1, 0.1)

        row.value = ns.FontString(row, "DDTFontNormal")
        row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.value:SetJustifyH("RIGHT")

        row.label = ns.FontString(row, "DDTFontNormal")
        row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.label:SetPoint("RIGHT", row.value, "LEFT", -6, 0)
        row.label:SetJustifyH("LEFT")
        row.label:SetWordWrap(false)

        row:SetScript("OnEnter", function() QuestLog:CancelHideTimer() end)
        row:SetScript("OnLeave", function() QuestLog:StartHideTimer() end)
        row:SetScript("OnClick", function(self, button)
            if not self.questID then return end
            if button == "LeftButton" then
                OpenQuest(self.questID)
            elseif button == "RightButton" then
                OpenRowMenu(self)
            end
        end)
        c.rows[index] = row
    end
    row.questID, row.questTitle, row.tracked = nil, nil, nil
    row.highlight:SetAlpha(0)
    row.label:SetTextColor(1, 1, 1)
    row.value:SetTextColor(1, 1, 1)
    row:Show()
    return row
end

local STATE_COLOURS = {
    ready  = { 0.1, 1, 0.1 },
    failed = { 1, 0.2, 0.2 },
    active = { 0.6, 0.6, 0.6 },
}

local function ZoneName(mapID)
    local info = mapID and C_Map.GetMapInfo(mapID)
    return info and info.name or nil
end

function QuestLog:BuildTooltipContent()
    local f = tooltipFrame
    local c = f.content
    for _, row in ipairs(c.rows) do row:Hide() end

    f.header:SetText("Quest Log")

    local db = self:GetDB()
    local y, n = 0, 0

    local function Line(indent, label, value, height)
        n = n + 1
        local row = GetRow(c, n)
        row:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING + indent, y)
        row:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
        row.label:SetText(label)
        row.value:SetText(value or "")
        y = y - (height or ns.ROW_HEIGHT)
        return row
    end

    local function Header(text)
        y = y - 4
        local row = Line(0, text, nil, HEADER_HEIGHT)
        row.label:SetTextColor(1, 0.82, 0)
    end

    local function Grey(row) row.label:SetTextColor(0.5, 0.5, 0.5) end

    -- The full walk happens here only, so only while the tooltip is shown.
    local entries = ReadLog(true)
    local c2 = QLH.Counts(entries)

    local quests = Line(0, "Quests", numQuests .. " / " .. maxQuests)
    quests.label:SetTextColor(1, 0.82, 0)
    local ready = Line(6, "Ready to hand in", tostring(c2.ready))
    if c2.ready > 0 then ready.value:SetTextColor(0.1, 1, 0.1) end
    Line(6, "Daily", tostring(c2.daily))
    Line(6, "Weekly", tostring(c2.weekly))

    local groups = QLH.Group(entries, db.groupBy)
    if #groups == 0 then
        y = y - 4
        Grey(Line(6, "No quests."))
    end
    for _, g in ipairs(groups) do
        if db.groupBy == "zone" then
            Header(ZoneName(g.mapID) or "Other")
        else
            Header(g.title or "Other")
        end
        for _, e in ipairs(g.quests) do
            local p = QLH.Progress(e.objectives, e.ready, e.failed)
            local row = Line(6, e.title, p.value)
            local col = STATE_COLOURS[p.state]
            row.value:SetTextColor(col[1], col[2], col[3])
            if p.state == "ready" then
                row.label:SetTextColor(0.1, 1, 0.1)
            elseif e.tracked then
                row.label:SetTextColor(1, 1, 1)
            else
                row.label:SetTextColor(0.85, 0.85, 0.85)
            end
            row.questID, row.questTitle, row.tracked = e.questID, e.title, e.tracked
            row.highlight:SetAlpha(1)
            if p.detail then
                Grey(Line(18, p.detail))
            end
        end
    end

    f.hint:SetText(DDT:BuildHintText(db.clickActions or {}, CLICK_ACTIONS))
    f:FinalizeLayout(db.tooltipWidth or TOOLTIP_WIDTH, math.abs(y))
end

function QuestLog:ShowTooltip(anchor)
    self:CancelHideTimer()

    if not tooltipFrame then
        tooltipFrame = CreateTooltipFrame()
    end

    local db = self:GetDB()
    ns.AnchorTooltip(tooltipFrame, anchor, db.tooltipGrowDirection)
    tooltipFrame:SetScale(db.tooltipScale or 1.0)

    self:BuildTooltipContent()
    tooltipFrame:Show()
end

function QuestLog:StartHideTimer()
    self:CancelHideTimer()
    hideTimer = C_Timer.NewTimer(ns.HIDE_DELAY, function()
        hideTimer = nil
        -- A context menu closes when its owner row hides, so keep the tooltip
        -- up while one is open and look again once it has gone.
        if Menu.GetManager():GetOpenMenu() then
            QuestLog:StartHideTimer()
            return
        end
        if tooltipFrame then tooltipFrame:Hide() end
    end)
end

function QuestLog:CancelHideTimer()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
end

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------

QuestLog.settingsLabel = "Quest Log"

function QuestLog:BuildSettingsPanel(panel)
    local W = ns.SettingsWidgets
    local r = panel.refreshCallbacks
    local db = function() return ns.db.questlog end

    W.AddLabelEditBox(panel, "count max ready",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateData() end, r, {
        { "Default",    "<count>/<max>" },
        { "With Ready", "<count>/<max> (<ready> ready)" },
        { "Labelled",   "Quests: <count>/<max>" },
    })

    local body = W.AddSection(panel, "Display")
    local y = 0
    y = W.AddDropdown(body, y, "Group By", GROUP_VALUES,
        function() return db().groupBy end,
        function(v) db().groupBy = v end, r)
    W.EndSection(panel, y)

    body = W.AddSection(panel, "Tooltip", true)
    y = 0
    y = W.AddSliderPair(body, y,
        { label = "Scale", min = 0.5, max = 2.0, step = 0.05,
          get = function() return db().tooltipScale end,
          set = function(v) db().tooltipScale = v end },
        { label = "Width", min = 200, max = 2000, step = 10,
          get = function() return db().tooltipWidth end,
          set = function(v) db().tooltipWidth = v end }, r)
    y = W.AddSlider(body, y, "Max Height", 100, 1000, 10,
        function() return db().tooltipMaxHeight end,
        function(v) db().tooltipMaxHeight = v end, r)
    y = W.AddTooltipGrowDirection(body, y, db, r)
    y = W.AddTooltipCopyFrom(body, y, "questlog", db, r)
    W.EndSection(panel, y)

    ns.AddModuleClickActionsSection(panel, r, "questlog", CLICK_ACTIONS,
        "In the tooltip, left-click a quest to open it in the quest log and\n" ..
        "right-click it for a menu (track or untrack, open, abandon).")
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("questlog", QuestLog, DEFAULTS)
