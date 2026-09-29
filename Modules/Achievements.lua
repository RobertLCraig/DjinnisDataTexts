-- Djinni's Data Texts - Achievements
-- Achievement points, points earned this session, recently completed
-- achievements and the criteria of tracked ones.
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
local TOOLTIP_WIDTH = 320
local HEADER_HEIGHT = 18
local PADDING       = 10
local INDENT        = 14
local BAR_WIDTH     = 90

-- State
local totalPoints = nil     -- last readable total
local loginPoints = nil     -- baseline for <session>, first non-zero read

---------------------------------------------------------------------------
-- Pure helpers. Lifted and run outside the game by
-- docs/build/check-achievements.lua, so keep them free of WoW globals.
---------------------------------------------------------------------------

-- [ach-helpers] pure; run by docs/build/check-achievements.lua
local AchHelpers = {}

-- Points earned since the login baseline, always signed: "+0", "+15".
function AchHelpers.SessionText(points, baseline)
    return "+" .. math.max(0, (points or 0) - (baseline or points or 0))
end

-- expand is ns.ExpandTag, passed in so this block needs nothing from ns.
function AchHelpers.ExpandLabel(template, points, baseline, expand)
    local result = expand(template, "points", points or 0)
    return expand(result, "session", AchHelpers.SessionText(points, baseline))
end

-- One criteria row. Criteria flagged 0x1 (EVALUATION_TREE_FLAG_PROGRESS_BAR)
-- get a bar fill and "quantity / required"; the rest read Done or Not done.
function AchHelpers.CriteriaRow(text, completed, quantity, reqQuantity, flags)
    local row = { text = text or "", done = completed and true or false }
    if (flags or 0) % 2 == 1 and (reqQuantity or 0) > 0 then
        row.fraction = math.min(1, (quantity or 0) / reqQuantity)
        row.value = (quantity or 0) .. " / " .. reqQuantity
    else
        row.value = row.done and "Done" or "Not done"
    end
    return row
end
-- [/ach-helpers]

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
        leftClick       = "openachievements",
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
    openachievements = "Open Achievements",
    menu             = "Open Menu",
    opensettings     = "Open DDT Settings",
    none             = "None",
}

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------

local function OpenSettings()
    if DDT.settingsCategoryID then
        Settings.OpenToCategory(DDT.settingsCategoryID)
    end
end

local function OpenAt(id)
    ShowAchievementFrameForAchievement(id)
end

local function Untrack(id)
    C_ContentTracking.StopTracking(Enum.ContentTrackingType.Achievement, id,
        Enum.ContentTrackingStopType.Manual)
end

local function LinkInChat(id)
    local link = GetAchievementLink(id)
    if link and not ChatFrameUtil.InsertLink(link) then
        ChatFrameUtil.OpenChat(link)
    end
end

-- Right-click on the DataText. Opens a menu and does nothing else.
local function ShowBrokerMenu(owner)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle("Achievements")
        root:CreateButton("Open Achievements", function() ToggleAchievementFrame() end)
        root:CreateButton("Open DDT Settings", OpenSettings)
    end)
end

-- Right-click on a tooltip row. Untrack is offered only for tracked rows.
local function ShowRowMenu(row)
    local id, name, tracked = row.achievementID, row.achievementName, row.tracked
    MenuUtil.CreateContextMenu(row, function(_, root)
        root:CreateTitle(name or "Achievement")
        root:CreateButton("Open", function() OpenAt(id) end)
        if tracked then
            root:CreateButton("Untrack", function() Untrack(id) end)
        end
        root:CreateButton("Link in Chat", function() LinkInChat(id) end)
    end)
end

---------------------------------------------------------------------------
-- LDB Data Object
---------------------------------------------------------------------------

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
        if action == "openachievements" then
            ToggleAchievementFrame()
        elseif action == "menu" then
            ShowBrokerMenu(self)
        elseif action == "pintooltip" then
            ns:TogglePinTooltip(Achievements, tooltipFrame)
        elseif action == "opensettings" then
            OpenSettings()
        end
    end,
})

Achievements.dataobj = dataobj

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

local EVENTS = {
    "PLAYER_ENTERING_WORLD",
    "ACHIEVEMENT_EARNED",
    "CRITERIA_UPDATE",
    "TRACKED_ACHIEVEMENT_LIST_CHANGED",
    "CONTENT_TRACKING_UPDATE",
}

function Achievements:Init()
    -- Handler first, then one event at a time, each confirmed: a refused
    -- event raises no Lua error (workspace decision 2026-08-21).
    eventFrame:SetScript("OnEvent", function()
        Achievements:UpdateData()
    end)
    for _, event in ipairs(EVENTS) do
        eventFrame:RegisterEvent(event)
        if not eventFrame:IsEventRegistered(event) then
            DDT:Print("Achievements: the game refused " .. event .. "; that update will be missed.")
        end
    end
end

function Achievements:GetDB()
    return ns.db and ns.db.achievements or DEFAULTS
end

---------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------

function Achievements:UpdateData()
    local points = GetTotalAchievementPoints()
    -- Hold the last value rather than do arithmetic on a secret.
    if points and not (issecretvalue and issecretvalue(points)) then
        totalPoints = points
        -- ponytail: the baseline waits for a non-zero read because the total can
        -- read 0 before the game has loaded it; a zero-point account shows +0
        -- until its first achievement.
        if not loginPoints and points > 0 then loginPoints = points end
    end

    local db = self:GetDB()
    dataobj.text = AchHelpers.ExpandLabel(db.labelTemplate, totalPoints, loginPoints, ns.ExpandTag)

    if tooltipFrame and tooltipFrame:IsShown() then
        self:BuildTooltipContent()
    end
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------

local function CreateTooltipFrame()
    local f = ns.CreateTooltipFrame("DDTAchievementsTooltip", Achievements)
    f.content.rows = {}
    return f
end

local function GetRow(c, index)
    local row = c.rows[index]
    if not row then
        row = CreateFrame("Button", nil, c, "BackdropTemplate")
        row:SetHeight(ns.ROW_HEIGHT)
        row:RegisterForClicks("AnyUp")

        row.label = ns.FontString(row, "DDTFontNormal")
        row.label:SetJustifyH("LEFT")
        row.label:SetWordWrap(false)

        row.barBg = row:CreateTexture(nil, "BACKGROUND")
        row.barBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
        row.barBg:SetSize(BAR_WIDTH, ns.ROW_HEIGHT - 6)
        row.barBg:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.barFill = row:CreateTexture(nil, "ARTWORK")
        row.barFill:SetColorTexture(0.1, 0.55, 0.1, 0.9)
        row.barFill:SetHeight(ns.ROW_HEIGHT - 6)
        row.barFill:SetPoint("LEFT", row.barBg, "LEFT", 0, 0)

        row.value = ns.FontString(row, "DDTFontNormal")
        row.value:SetJustifyH("RIGHT")
        row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.label:SetPoint("RIGHT", row.value, "LEFT", -6, 0)

        row:SetScript("OnEnter", function(self)
            Achievements:CancelHideTimer()
            if self.achievementID then
                self:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground" })
                self:SetBackdropColor(0.3, 0.3, 0.3, 0.3)
            end
        end)
        row:SetScript("OnLeave", function(self)
            Achievements:StartHideTimer()
            self:SetBackdrop(nil)
        end)
        row:SetScript("OnClick", function(self, button)
            if not self.achievementID then return end
            if button == "LeftButton" then
                OpenAt(self.achievementID)
            elseif button == "RightButton" then
                ShowRowMenu(self)
            end
        end)
        c.rows[index] = row
    end
    row:Show()
    row.achievementID, row.achievementName, row.tracked = nil, nil, nil
    row.barBg:Hide()
    row.barFill:Hide()
    row.value:ClearAllPoints()
    row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.label:SetPoint("RIGHT", row.value, "LEFT", -6, 0)
    row.label:SetTextColor(1, 1, 1)
    row.value:SetTextColor(1, 1, 1)
    return row
end

function Achievements:BuildTooltipContent()
    local f = tooltipFrame
    local c = f.content
    for _, row in pairs(c.rows) do row:Hide() end

    local db = self:GetDB()
    local width = db.tooltipWidth or TOOLTIP_WIDTH
    local y, n = 0, 0

    local function Row(indent, height)
        n = n + 1
        local row = GetRow(c, n)
        row:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING + indent, y)
        row:SetPoint("RIGHT", c, "LEFT", width - PADDING, 0)
        y = y - (height or ns.ROW_HEIGHT)
        return row
    end

    local function Header(text)
        y = y - 4
        local row = Row(0, HEADER_HEIGHT)
        row.label:SetText("|cffffd100" .. text .. "|r")
        row.value:SetText("")
    end

    local function Grey(text)
        local row = Row(INDENT)
        row.label:SetText("|cff888888" .. text .. "|r")
        row.value:SetText("")
    end

    f.header:SetText("Achievements: " .. (totalPoints or 0) .. "  |cff00ff00"
        .. AchHelpers.SessionText(totalPoints, loginPoints) .. "|r")

    -- Recently completed, newest first as the game returns them.
    Header("Recently Completed")
    local recent = { GetLatestCompletedAchievements() }
    local shown = 0
    for i = 1, math.min(#recent, db.recentCount or 5) do
        local id, name, _, _, month, day, year = GetAchievementInfo(recent[i])
        if id then
            local row = Row(INDENT)
            row.achievementID, row.achievementName = id, name
            row.label:SetText(name)
            row.value:SetText(month and FormatShortDate(day, month, year) or "")
            row.value:SetTextColor(0.7, 0.7, 0.7)
            shown = shown + 1
        end
    end
    if shown == 0 then Grey("Nothing completed yet.") end

    -- Tracked, with criteria. This walk is why it runs on hover only.
    Header("Tracked")
    local tracked = C_ContentTracking.GetTrackedIDs(Enum.ContentTrackingType.Achievement) or {}
    if #tracked == 0 then
        Grey("No achievements tracked.")
    end
    for _, trackedID in ipairs(tracked) do
        local id, name, _, completed = GetAchievementInfo(trackedID)
        if id then
            local row = Row(INDENT)
            row.achievementID, row.achievementName, row.tracked = id, name, true
            row.label:SetText(name)
            row.value:SetText(completed and "Done" or "")
            row.value:SetTextColor(0.1, 1, 0.1)

            for i = 1, GetAchievementNumCriteria(id) or 0 do
                local text, _, done, quantity, reqQuantity, _, flags = GetAchievementCriteriaInfo(id, i)
                local cr = AchHelpers.CriteriaRow(text, done, quantity, reqQuantity, flags)
                local crow = Row(INDENT * 2)
                crow.achievementID, crow.achievementName, crow.tracked = id, name, true
                crow.label:SetText(cr.text)
                crow.value:SetText(cr.value)
                if cr.fraction then
                    crow.barBg:Show()
                    crow.barFill:SetWidth(math.max(1, BAR_WIDTH * cr.fraction))
                    crow.barFill:Show()
                    crow.value:ClearAllPoints()
                    crow.value:SetPoint("CENTER", crow.barBg, "CENTER", 0, 0)
                    crow.label:SetPoint("RIGHT", crow.barBg, "LEFT", -6, 0)
                end
                if cr.done then
                    crow.label:SetTextColor(0.5, 0.5, 0.5)
                    crow.value:SetTextColor(0.1, 1, 0.1)
                elseif not cr.fraction then
                    crow.value:SetTextColor(0.6, 0.6, 0.6)
                end
            end
        end
    end

    local hint = DDT:BuildHintText(db.clickActions or {}, CLICK_ACTIONS)
    local rowHint = "|cff888888Row: LClick open, RClick menu|r"
    f.hint:SetText(hint == "" and rowHint or (hint .. "  |  " .. rowHint))

    f:FinalizeLayout(width, math.abs(y))
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
        if tooltipFrame then tooltipFrame:Hide() end
        hideTimer = nil
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
        { "Default",       "<points>" },
        { "With Session",  "<points> (<session>)" },
        { "Labelled",      "Achievements: <points>" },
    })

    local body = W.AddSection(panel, "Tooltip", true)
    local y = 0
    -- ponytail: capped at 5 on the belief that GetLatestCompletedAchievements
    -- returns five; the repository does not confirm the count. Widen if it does more.
    y = W.AddSlider(body, y, "Recent Achievements", 1, 5, 1,
        function() return db().recentCount end,
        function(v) db().recentCount = v end, r)
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
        nil, r)
    y = W.AddTooltipGrowDirection(body, y, db, r)
    y = W.AddTooltipCopyFrom(body, y, "achievements", db, r)
    W.EndSection(panel, y)

    ns.AddModuleClickActionsSection(panel, r, "achievements", CLICK_ACTIONS,
        "Tooltip rows: left-click opens the achievement, right-click opens a menu\n" ..
        "(open, untrack, link in chat).")
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("achievements", Achievements, DEFAULTS)
