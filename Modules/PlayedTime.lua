-- Djinni's Data Texts — Played Time
-- Session time, total /played, and level time tracking.
local addonName, ns = ...
local DDT = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local PlayedTime = {}
ns.PlayedTime = PlayedTime

-- Tooltip
local tooltipFrame = nil
local hideTimer = nil

-- Layout
local TOOLTIP_WIDTH  = 280
local ROW_HEIGHT     = 20
local HEADER_HEIGHT  = 18
local PADDING        = 10
local HINT_HEIGHT    = 18

-- State
local sessionStart = 0       -- GetTime() at login
local totalPlayed = 0        -- seconds, from TIME_PLAYED_MSG
local levelPlayed = 0        -- seconds, from TIME_PLAYED_MSG
local playedReceived = false -- has TIME_PLAYED_MSG fired?

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
    labelTemplate = "<session>",
    tooltipScale  = 1.0,
    tooltipWidth  = 280,
    clickActions  = {
        leftClick       = "refresh",
        rightClick      = "stopwatch",
        middleClick     = "none",
        shiftLeftClick  = "copytime",
        shiftRightClick = "none",
        ctrlLeftClick   = "none",
        ctrlRightClick  = "none",
        altLeftClick    = "opensettings",
        altRightClick   = "none",
    },
}

local CLICK_ACTIONS = {
    refresh      = "Refresh /played",
    stopwatch    = "Toggle Stopwatch",
    copytime     = "Copy Session Time",
    opensettings = "Open DDT Settings",
    none         = "None",
}

---------------------------------------------------------------------------
-- Time formatting
---------------------------------------------------------------------------

local function FormatDuration(seconds)
    if not seconds or seconds <= 0 then return "0m" end
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local mins = math.floor((seconds % 3600) / 60)

    if days > 0 then
        return string.format("%dd %dh %dm", days, hours, mins)
    elseif hours > 0 then
        return string.format("%dh %dm", hours, mins)
    else
        return string.format("%dm", mins)
    end
end

local function FormatDurationLong(seconds)
    if not seconds or seconds <= 0 then return "0 minutes" end
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local mins = math.floor((seconds % 3600) / 60)

    local parts = {}
    if days > 0 then table.insert(parts, days .. (days == 1 and " day" or " days")) end
    if hours > 0 then table.insert(parts, hours .. (hours == 1 and " hour" or " hours")) end
    if mins > 0 then table.insert(parts, mins .. (mins == 1 and " minute" or " minutes")) end
    return #parts > 0 and table.concat(parts, ", ") or "0 minutes"
end

local function GetSessionTime()
    return GetTime() - sessionStart
end

---------------------------------------------------------------------------
-- Label template expansion
---------------------------------------------------------------------------

local function ExpandLabel(template)
    local result = template
    local E = ns.ExpandTag
    result = E(result, "session", FormatDuration(GetSessionTime()))
    result = E(result, "total", playedReceived and FormatDuration(totalPlayed + GetSessionTime()) or "...")
    result = E(result, "level", playedReceived and FormatDuration(levelPlayed + GetSessionTime()) or "...")
    return result
end

---------------------------------------------------------------------------
-- LDB Data Object
---------------------------------------------------------------------------

local dataobj = LDB:NewDataObject("DDT-PlayedTime", {
    type  = "data source",
    text  = "0m",
    icon  = "Interface\\Icons\\Spell_Holy_BorrowedTime",
    label = "DDT - Played Time",
    OnEnter = function(self)
        PlayedTime:ShowTooltip(self)
    end,
    OnLeave = function(self)
        PlayedTime:StartHideTimer()
    end,
    OnClick = function(self, button)
        local db = PlayedTime:GetDB()
        local action = DDT:ResolveClickAction(button, db.clickActions or {})
        if action == "refresh" then
            RequestTimePlayed()
        elseif action == "stopwatch" then
            Stopwatch_Toggle()
        elseif action == "copytime" then
            ChatFrameUtil.OpenChat("Session: " .. FormatDuration(GetSessionTime()))
        elseif action == "opensettings" then
            if DDT.settingsCategoryID then
                Settings.OpenToCategory(DDT.settingsCategoryID)
            end
        end
    end,
})

PlayedTime.dataobj = dataobj

---------------------------------------------------------------------------
-- Event handling and update
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local elapsed = 0

function PlayedTime:Init()
    sessionStart = GetTime()

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("TIME_PLAYED_MSG")

    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            -- Request played time silently after a short delay
            C_Timer.After(5, function()
                RequestTimePlayed()
            end)
        elseif event == "TIME_PLAYED_MSG" then
            local total, level = ...
            totalPlayed = total or 0
            levelPlayed = level or 0
            playedReceived = true
            -- Reset session offset — totalPlayed now includes time up to this moment
            sessionStart = GetTime()
            PlayedTime:UpdateDisplay()
        end
    end)

    -- Update every second for session timer
    eventFrame:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= 1 then
            elapsed = 0
            PlayedTime:UpdateDisplay()
        end
    end)
end

function PlayedTime:GetDB()
    return ns.db and ns.db.playedtime or DEFAULTS
end

function PlayedTime:UpdateDisplay()
    local db = self:GetDB()
    dataobj.text = ExpandLabel(db.labelTemplate)

    -- Refresh tooltip if visible
    if tooltipFrame and tooltipFrame:IsShown() then
        self:BuildTooltipContent()
    end
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------

local function CreateTooltipFrame()
    local f = CreateFrame("Frame", "DDTPlayedTimeTooltip", UIParent, "BackdropTemplate")
    f:SetFrameStrata("TOOLTIP")
    f:SetClampedToScreen(true)
    f:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.92)
    f:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    f.title = f:CreateFontString(nil, "OVERLAY", "DDTFontHeader")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, -PADDING)
    f.title:SetTextColor(1, 0.82, 0)

    f.titleSep = f:CreateTexture(nil, "ARTWORK")
    f.titleSep:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
    f.titleSep:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)
    f.titleSep:SetHeight(1)
    f.titleSep:SetColorTexture(0.5, 0.5, 0.5, 0.5)

    f.hint = f:CreateFontString(nil, "OVERLAY", "DDTFontSmall")
    f.hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PADDING, 8)
    f.hint:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PADDING, 8)
    f.hint:SetJustifyH("CENTER")
    f.hint:SetTextColor(0.53, 0.53, 0.53)

    f:EnableMouse(true)
    f:SetScript("OnEnter", function() PlayedTime:CancelHideTimer() end)
    f:SetScript("OnLeave", function() PlayedTime:StartHideTimer() end)

    f.lines = {}
    return f
end

local function GetLine(f, index)
    if f.lines[index] then
        f.lines[index].label:Show()
        f.lines[index].value:Show()
        return f.lines[index]
    end

    local label = f:CreateFontString(nil, "OVERLAY", "DDTFontNormal")
    label:SetJustifyH("LEFT")

    local value = f:CreateFontString(nil, "OVERLAY", "DDTFontNormal")
    value:SetJustifyH("RIGHT")

    f.lines[index] = { label = label, value = value }
    return f.lines[index]
end

local function HideLines(f)
    for _, line in pairs(f.lines) do
        line.label:Hide()
        line.value:Hide()
    end
end

function PlayedTime:BuildTooltipContent()
    local f = tooltipFrame
    HideLines(f)

    f.title:SetText("Played Time")

    local y = -PADDING - 20 - 6
    local lineIdx = 0

    -- Session time
    lineIdx = lineIdx + 1
    local sessLine = GetLine(f, lineIdx)
    sessLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    sessLine.label:SetText("|cffffffffSession|r")
    sessLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    sessLine.value:SetText(FormatDurationLong(GetSessionTime()))
    sessLine.value:SetTextColor(0.0, 1.0, 0.0)
    y = y - ROW_HEIGHT

    -- Separator
    y = y - 4

    if playedReceived then
        -- Total played (including session time since last TIME_PLAYED_MSG)
        local adjustedTotal = totalPlayed + GetSessionTime()
        lineIdx = lineIdx + 1
        local totalLine = GetLine(f, lineIdx)
        totalLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        totalLine.label:SetText("|cffffffffTotal Played|r")
        totalLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        totalLine.value:SetText(FormatDurationLong(adjustedTotal))
        totalLine.value:SetTextColor(0.4, 0.78, 1)
        y = y - ROW_HEIGHT

        -- Level played
        local adjustedLevel = levelPlayed + GetSessionTime()
        lineIdx = lineIdx + 1
        local lvlLine = GetLine(f, lineIdx)
        lvlLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        lvlLine.label:SetText("|cffffffffThis Level|r")
        lvlLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        lvlLine.value:SetText(FormatDurationLong(adjustedLevel))
        lvlLine.value:SetTextColor(0.4, 0.78, 1)
        y = y - ROW_HEIGHT
    else
        lineIdx = lineIdx + 1
        local pendLine = GetLine(f, lineIdx)
        pendLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        pendLine.label:SetText("|cff888888Waiting for /played data...|r")
        pendLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        pendLine.value:SetText("")
        y = y - ROW_HEIGHT
    end

    -- Character info
    y = y - 4
    local playerName = UnitName("player") or ""
    local _, className = UnitClass("player")
    local level = UnitLevel("player") or 0

    lineIdx = lineIdx + 1
    local charLine = GetLine(f, lineIdx)
    charLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    charLine.label:SetText("|cffffffffCharacter|r")
    charLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    local nameStr = playerName
    if className then
        local cc = RAID_CLASS_COLORS[className]
        if cc then
            nameStr = cc:WrapTextInColorCode(playerName)
        end
    end
    charLine.value:SetText(nameStr .. " (Lv " .. level .. ")")
    charLine.value:SetTextColor(0.9, 0.9, 0.9)
    y = y - ROW_HEIGHT

    local db = self:GetDB()

    -- Hint
    f.hint:SetText(DDT:BuildHintText(db.clickActions or {}, CLICK_ACTIONS))

    local ttWidth = db.tooltipWidth or TOOLTIP_WIDTH
    local totalHeight = math.abs(y) + PADDING + HINT_HEIGHT + 8
    f:SetSize(ttWidth, totalHeight)
end

function PlayedTime:ShowTooltip(anchor)
    self:CancelHideTimer()

    if not tooltipFrame then
        tooltipFrame = CreateTooltipFrame()
    end

    local db = self:GetDB()
    tooltipFrame:ClearAllPoints()
    tooltipFrame:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 4)
    tooltipFrame:SetScale(db.tooltipScale or 1.0)

    self:BuildTooltipContent()
    tooltipFrame:Show()
end

function PlayedTime:StartHideTimer()
    self:CancelHideTimer()
    hideTimer = C_Timer.NewTimer(ns.HIDE_DELAY, function()
        if tooltipFrame then tooltipFrame:Hide() end
        hideTimer = nil
    end)
end

function PlayedTime:CancelHideTimer()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
end

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------

PlayedTime.settingsLabel = "Played Time"

function PlayedTime:BuildSettingsPanel(panel)
    local W = ns.SettingsWidgets
    local r = panel.refreshCallbacks
    local db = function() return ns.db.playedtime end

    local body = W.AddSection(panel, "Label Template")
    local y = 0
    y = W.AddLabelEditBox(body, y, "session total level",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateDisplay() end, r, {
        { "Default",   "<session>" },
        { "Labeled",   "Session: <session>" },
        { "Total",     "Played: <total>" },
        { "Both",      "<session> / <total>" },
        { "Level",     "Lv: <level>  Total: <total>" },
    })
    W.EndSection(panel, y)

    body = W.AddSection(panel, "Tooltip", true)
    y = 0
    y = W.AddSliderPair(body, y,
        { label = "Scale", min = 0.5, max = 2.0, step = 0.05,
          get = function() return db().tooltipScale end,
          set = function(v) db().tooltipScale = v end },
        { label = "Width", min = 200, max = 500, step = 10,
          get = function() return db().tooltipWidth end,
          set = function(v) db().tooltipWidth = v end }, r)
    W.EndSection(panel, y)

    ns.AddModuleClickActionsSection(panel, r, "playedtime", CLICK_ACTIONS)
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("playedtime", PlayedTime, DEFAULTS)
