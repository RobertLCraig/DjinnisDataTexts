-- Djinni's Data Texts - Achievements
-- Achievement points, points earned this session, recently completed
-- achievements and tracked achievements with their criteria.
local addonName, ns = ...
local DDT = ns.addon

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local Achievements = {}
ns.Achievements = Achievements

-- Tooltip
local tooltipFrame = nil
local hideTimer = nil

-- Layout
local TOOLTIP_WIDTH  = 320
local HEADER_HEIGHT  = 18
local PADDING        = 10
local BAR_WIDTH      = 110

-- State
local points = 0
local session = { baseline = nil }

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
    labelTemplate    = "<points>",
    recentCount      = 5,
    tooltipScale     = 1.0,
    tooltipMaxHeight = 500,
    tooltipWidth     = 320,
    clickActions     = {
        leftClick       = "achievements",
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
    achievements = "Achievement Window",
    menu         = "Menu",
    opensettings = "Open DDT Settings",
    none         = "None",
}

---------------------------------------------------------------------------
-- Pure helpers. Lifted and run by docs/build/check-achievements.lua, so keep
-- everything between the markers free of WoW API calls.
---------------------------------------------------------------------------

-- [ach-helpers]
local AchH = {}

--- Points earned since login. The baseline is the first non-zero read, because
--- the game can answer 0 before achievement data has loaded.
function AchH.SessionDelta(state, current)
    if not state.baseline then
        if current > 0 then state.baseline = current end
        return 0
    end
    return current - state.baseline
end

--- <points> is the total; <session> is "+N", or nothing when N is 0.
function AchH.ExpandLabel(template, pts, gained)
    local result = ns.ExpandTag(template, "points", pts)
    result = ns.ExpandTag(result, "session", gained > 0 and ("+" .. gained) or "")
    return (result:gsub("^%s+", ""):gsub("%s+$", ""))
end

--- One tooltip row for a criterion. Flag bit 1 is Blizzard's
--- EVALUATION_TREE_FLAG_PROGRESS_BAR. `text` is never concatenated, since a
--- 12.1 string from the game may be a secret.
function AchH.CriterionRow(text, completed, quantity, required, flags, quantityString)
    local row = { label = text, done = completed and true or false }
    if (flags or 0) % 2 == 1 and (required or 0) > 0 then
        row.progress = math.min(1, (quantity or 0) / required)
        if quantityString and quantityString ~= "" then
            row.value = quantityString
        else
            row.value = (quantity or 0) .. " / " .. required
        end
    else
        row.value = completed and "Done" or "Not done"
    end
    return row
end
-- [/ach-helpers]

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
        root:CreateTitle("Achievements")
        root:CreateButton("Open achievement window", function() ToggleAchievementFrame() end)
        root:CreateButton("Open DDT settings", OpenSettings)
    end)
end

local dataobj = ns:NewBroker("achievements", "DDT-Achievements", {
    type  = "data source",
    text  = "0",
    icon  = "Interface\\Icons\\Achievement_Quests_Completed_08",
    label = "DDT - Achievements",
    OnEnter = function(self)
        Achievements:ShowTooltip(self)
    end,
    OnLeave = function()
        Achievements:StartHideTimer()
    end,
    OnClick = function(self, button)
        local db = Achievements:GetDB()
        local action = DDT:ResolveClickAction(button, db.clickActions or {})
        if action == "achievements" then
            ToggleAchievementFrame()
        elseif action == "menu" then
            OpenBrokerMenu(self)
        elseif action == "pintooltip" then
            ns:TogglePinTooltip(Achievements, tooltipFrame)
        elseif action == "opensettings" then
            OpenSettings()
        end
    end,
})

Achievements.dataobj = dataobj

---------------------------------------------------------------------------
-- Event handling
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

-- CRITERIA_UPDATE fires often; it only redoes the label, which is one call.
-- The criteria walk happens in BuildTooltipContent, i.e. only while hovered.
local EVENTS = {
    "PLAYER_ENTERING_WORLD",
    "ACHIEVEMENT_EARNED",
    "CRITERIA_UPDATE",
    "TRACKED_ACHIEVEMENT_LIST_CHANGED",
    "CONTENT_TRACKING_UPDATE",
}

function Achievements:Init()
    -- Handler first, then each event singly and confirmed: a refused
    -- RegisterEvent raises no Lua error (workspace decision, 2026-08-21).
    eventFrame:SetScript("OnEvent", function()
        Achievements:UpdateData()
    end)
    for _, event in ipairs(EVENTS) do
        eventFrame:RegisterEvent(event)
        if not eventFrame:IsEventRegistered(event) then
            DDT:Print("Achievements: the game refused " .. event .. "; that update will wait for the poll.")
        end
    end
end

function Achievements:GetDB()
    return ns.db and ns.db.achievements or DEFAULTS
end

---------------------------------------------------------------------------
-- Data collection
---------------------------------------------------------------------------

function Achievements:UpdateData()
    points = GetTotalAchievementPoints() or 0
    local gained = AchH.SessionDelta(session, points)

    local db = self:GetDB()
    dataobj.text = AchH.ExpandLabel(db.labelTemplate, points, gained)

    if tooltipFrame and tooltipFrame:IsShown() then
        self:BuildTooltipContent()
    end
end

---------------------------------------------------------------------------
-- Row actions
---------------------------------------------------------------------------

local function LinkInChat(id)
    local link = GetAchievementLink(id)
    if not link then return end
    if not ChatFrameUtil.InsertLink(link) then
        ChatFrameUtil.OpenChat(link)
    end
end

local function Untrack(id)
    C_ContentTracking.StopTracking(Enum.ContentTrackingType.Achievement, id,
        Enum.ContentTrackingStopType.Manual)
end

local function OpenRowMenu(row)
    local id, name, tracked = row.achID, row.achName, row.tracked
    MenuUtil.CreateContextMenu(row, function(_, root)
        if name then root:CreateTitle(name) end
        root:CreateButton("Open", function() ShowAchievementFrameForAchievement(id) end)
        if tracked then
            root:CreateButton("Untrack", function() Untrack(id) end)
        end
        root:CreateButton("Link in chat", function() LinkInChat(id) end)
    end)
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------

local function CreateTooltipFrame()
    local f = ns.CreateTooltipFrame("DDTAchievementsTooltip", Achievements)
    f.content.rows = {}
    return f
end

-- One pool of Button rows for every line. A row with achID set is clickable
-- and highlights; the rest are plain text.
local function GetRow(c, index)
    local row = c.rows[index]
    if not row then
        row = CreateFrame("Button", nil, c)
        row:SetHeight(ns.ROW_HEIGHT)
        row:RegisterForClicks("AnyUp")

        row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
        row.highlight:SetAllPoints()
        row.highlight:SetColorTexture(1, 1, 1, 0.1)

        row.barBg = row:CreateTexture(nil, "BACKGROUND")
        row.barBg:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.barBg:SetSize(BAR_WIDTH, ns.ROW_HEIGHT - 6)
        row.barBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)

        row.bar = row:CreateTexture(nil, "ARTWORK")
        row.bar:SetPoint("LEFT", row.barBg, "LEFT", 0, 0)
        row.bar:SetHeight(ns.ROW_HEIGHT - 6)
        row.bar:SetColorTexture(0.1, 0.6, 0.1, 0.9)

        row.label = ns.FontString(row, "DDTFontNormal")
        row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.label:SetPoint("RIGHT", row.barBg, "LEFT", -6, 0)
        row.label:SetJustifyH("LEFT")
        row.label:SetWordWrap(false)

        row.value = ns.FontString(row, "DDTFontNormal")
        row.value:SetPoint("CENTER", row.barBg, "CENTER", 0, 0)
        row.value:SetJustifyH("RIGHT")

        row:SetScript("OnEnter", function() Achievements:CancelHideTimer() end)
        row:SetScript("OnLeave", function() Achievements:StartHideTimer() end)
        row:SetScript("OnClick", function(self, button)
            if not self.achID then return end
            if button == "LeftButton" then
                ShowAchievementFrameForAchievement(self.achID)
            elseif button == "RightButton" then
                OpenRowMenu(self)
            end
        end)
        c.rows[index] = row
    end
    row.achID, row.achName, row.tracked = nil, nil, nil
    row.highlight:SetAlpha(0)
    row.barBg:Hide()
    row.bar:Hide()
    row.label:SetTextColor(1, 1, 1)
    row.value:SetTextColor(1, 1, 1)
    row.value:ClearAllPoints()
    row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row:Show()
    return row
end

function Achievements:BuildTooltipContent()
    local f = tooltipFrame
    local c = f.content
    for _, row in ipairs(c.rows) do row:Hide() end

    f.header:SetText("Achievements")

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

    -- Points
    local gained = AchH.SessionDelta(session, points)
    local pointsRow = Line(0, "Points", BreakUpLargeNumbers(points))
    pointsRow.label:SetTextColor(1, 0.82, 0)
    if gained > 0 then
        Line(6, "This session", "+" .. gained).value:SetTextColor(0, 1, 0)
    end

    -- Recently completed, newest first as the game returns them.
    Header("Recently completed")
    local recent = { GetLatestCompletedAchievements() }
    local shown = 0
    for _, id in ipairs(recent) do
        if shown >= (db.recentCount or 5) then break end
        local _, name, _, _, month, day, year = GetAchievementInfo(id)
        if name then
            shown = shown + 1
            local row = Line(6, name, FormatShortDate(day, month, year))
            row.value:SetTextColor(0.6, 0.6, 0.6)
            row.achID, row.achName = id, name
            row.highlight:SetAlpha(1)
        end
    end
    if shown == 0 then
        Line(6, "None yet.").label:SetTextColor(0.5, 0.5, 0.5)
    end

    -- Tracked, each with its criteria.
    Header("Tracked")
    local tracked = C_ContentTracking.GetTrackedIDs(Enum.ContentTrackingType.Achievement) or {}
    if #tracked == 0 then
        Line(6, "No achievements tracked.").label:SetTextColor(0.5, 0.5, 0.5)
    end
    for _, id in ipairs(tracked) do
        local _, name, pts = GetAchievementInfo(id)
        if name then
            local row = Line(6, name, pts and (pts .. " pts") or "")
            row.value:SetTextColor(0.6, 0.6, 0.6)
            row.achID, row.achName, row.tracked = id, name, true
            row.highlight:SetAlpha(1)

            for i = 1, GetAchievementNumCriteria(id) do
                local text, _, completed, quantity, required, _, flags, _, quantityString =
                    GetAchievementCriteriaInfo(id, i)
                local cr = AchH.CriterionRow(text, completed, quantity, required, flags, quantityString)
                local line = Line(18, cr.label, cr.value)
                if cr.done then
                    line.label:SetTextColor(0.1, 1, 0.1)
                else
                    line.label:SetTextColor(0.6, 0.6, 0.6)
                end
                if cr.progress then
                    line.barBg:Show()
                    line.bar:SetWidth(math.max(1, BAR_WIDTH * cr.progress))
                    line.bar:Show()
                    line.value:ClearAllPoints()
                    line.value:SetPoint("CENTER", line.barBg, "CENTER", 0, 0)
                elseif not cr.done then
                    line.value:SetTextColor(0.6, 0.6, 0.6)
                else
                    line.value:SetTextColor(0.1, 1, 0.1)
                end
            end
        end
    end

    f.hint:SetText(DDT:BuildHintText(db.clickActions or {}, CLICK_ACTIONS))
    f:FinalizeLayout(db.tooltipWidth or TOOLTIP_WIDTH, math.abs(y))
end

function Achievements:ShowTooltip(anchor)
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

function Achievements:StartHideTimer()
    self:CancelHideTimer()
    hideTimer = C_Timer.NewTimer(ns.HIDE_DELAY, function()
        hideTimer = nil
        -- A context menu closes when its owner row hides, so keep the tooltip
        -- up while one is open and look again once it has gone.
        if Menu.GetManager():GetOpenMenu() then
            Achievements:StartHideTimer()
            return
        end
        if tooltipFrame then tooltipFrame:Hide() end
    end)
end

function Achievements:CancelHideTimer()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
end

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------

Achievements.settingsLabel = "Achievements"

function Achievements:BuildSettingsPanel(panel)
    local W = ns.SettingsWidgets
    local r = panel.refreshCallbacks
    local db = function() return ns.db.achievements end

    W.AddLabelEditBox(panel, "points session",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateData() end, r, {
        { "Default",      "<points>" },
        { "With Session", "<points> <session>" },
        { "Labelled",     "Achievements: <points> <session>" },
    })

    local body = W.AddSection(panel, "Tooltip", true)
    local y = 0
    y = W.AddSliderPair(body, y,
        { label = "Scale", min = 0.5, max = 2.0, step = 0.05,
          get = function() return db().tooltipScale end,
          set = function(v) db().tooltipScale = v end },
        { label = "Width", min = 200, max = 2000, step = 10,
          get = function() return db().tooltipWidth end,
          set = function(v) db().tooltipWidth = v end }, r)
    y = W.AddSliderPair(body, y,
        { label = "Max Height", min = 100, max = 1000, step = 10,
          get = function() return db().tooltipMaxHeight end,
          set = function(v) db().tooltipMaxHeight = v end },
        { label = "Recent Achievements", min = 1, max = 10, step = 1,
          get = function() return db().recentCount end,
          set = function(v) db().recentCount = v end }, r)
    y = W.AddTooltipGrowDirection(body, y, db, r)
    y = W.AddTooltipCopyFrom(body, y, "achievements", db, r)
    W.EndSection(panel, y)

    ns.AddModuleClickActionsSection(panel, r, "achievements", CLICK_ACTIONS,
        "In the tooltip, left-click an achievement to open it and right-click\n" ..
        "it for a menu (open, untrack, link in chat).")
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("achievements", Achievements, DEFAULTS)
