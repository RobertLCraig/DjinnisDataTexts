-- Djinni's Data Texts — Time / Date
-- Server time, local time, daily and weekly reset countdowns.
local addonName, ns = ...
local DDT = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local TimeDate = {}
ns.TimeDate = TimeDate

-- Tooltip
local tooltipFrame = nil
local hideTimer = nil

-- Layout
local TOOLTIP_WIDTH  = 260
local ROW_HEIGHT     = 20
local HEADER_HEIGHT  = 18
local PADDING        = 10
local HINT_HEIGHT    = 18

-- State
local displayHour = 0
local displayMin  = 0

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
    use24h        = true,
    showLocal     = false,   -- false = server time on LDB, true = local time
    showSeconds   = false,
    labelTemplate = "<time>",
    tooltipScale  = 1.0,
    tooltipWidth  = 260,
}

---------------------------------------------------------------------------
-- Time formatting
---------------------------------------------------------------------------

local function FormatTime(hour, minute, second, use24h, showSeconds)
    if use24h then
        if showSeconds and second then
            return string.format("%02d:%02d:%02d", hour, minute, second)
        end
        return string.format("%02d:%02d", hour, minute)
    else
        local ampm = hour >= 12 and "PM" or "AM"
        local h = hour % 12
        if h == 0 then h = 12 end
        if showSeconds and second then
            return string.format("%d:%02d:%02d %s", h, minute, second, ampm)
        end
        return string.format("%d:%02d %s", h, minute, ampm)
    end
end

local function FormatCountdown(seconds)
    if not seconds or seconds <= 0 then return "Now" end
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

local WEEKDAY_NAMES = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }
local MONTH_NAMES = { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" }

local function GetDateString()
    local d = C_DateAndTime.GetCurrentCalendarTime()
    if not d then return "" end
    local wday = WEEKDAY_NAMES[d.weekday] or ""
    local month = MONTH_NAMES[d.month] or ""
    return string.format("%s, %s %d, %d", wday, month, d.monthDay, d.year)
end

---------------------------------------------------------------------------
-- Label template expansion
---------------------------------------------------------------------------

local function ExpandLabel(template, db)
    local result = template
    local use24h = db.use24h ~= false
    local showSec = db.showSeconds

    local sHour, sMin = GetGameTime()
    local lTime = date("*t")

    if db.showLocal then
        result = result:gsub("<time>", FormatTime(lTime.hour, lTime.min, showSec and lTime.sec or nil, use24h, showSec))
    else
        result = result:gsub("<time>", FormatTime(sHour, sMin, nil, use24h, false))
    end
    result = result:gsub("<server>", FormatTime(sHour, sMin, nil, use24h, false))
    result = result:gsub("<local>", FormatTime(lTime.hour, lTime.min, lTime.sec, use24h, true))
    result = result:gsub("<date>", GetDateString())
    return result
end

---------------------------------------------------------------------------
-- LDB Data Object
---------------------------------------------------------------------------

local dataobj = LDB:NewDataObject("DDT-TimeDate", {
    type  = "data source",
    text  = "00:00",
    icon  = "Interface\\Icons\\INV_Misc_PocketWatch_01",
    label = "DDT - Time",
    OnEnter = function(self)
        TimeDate:ShowTooltip(self)
    end,
    OnLeave = function(self)
        TimeDate:StartHideTimer()
    end,
    OnClick = function(self, button)
        if button == "LeftButton" then
            ToggleCalendar()
        elseif button == "RightButton" then
            -- Toggle between server/local on the label
            if ns.db and ns.db.timedate then
                ns.db.timedate.showLocal = not ns.db.timedate.showLocal
            end
        end
    end,
})

TimeDate.dataobj = dataobj

---------------------------------------------------------------------------
-- Event handling and update
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local elapsed = 0

function TimeDate:Init()
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("CALENDAR_UPDATE_EVENT_LIST")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(3, function()
                if C_Calendar and C_Calendar.OpenCalendar then
                    C_Calendar.OpenCalendar()
                end
            end)
        end
        TimeDate:UpdateDisplay()
    end)

    -- Time display needs periodic updates (OnUpdate is appropriate here)
    eventFrame:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= 1 then
            elapsed = 0
            TimeDate:UpdateDisplay()
        end
    end)
end

function TimeDate:GetDB()
    return ns.db and ns.db.timedate or DEFAULTS
end

function TimeDate:UpdateDisplay()
    local db = self:GetDB()
    dataobj.text = ExpandLabel(db.labelTemplate, db)

    -- Refresh tooltip if visible
    if tooltipFrame and tooltipFrame:IsShown() then
        self:BuildTooltipContent()
    end
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------

local function CreateTooltipFrame()
    local f = CreateFrame("Frame", "DDTTimeDateTooltip", UIParent, "BackdropTemplate")
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
    f:SetScript("OnEnter", function() TimeDate:CancelHideTimer() end)
    f:SetScript("OnLeave", function() TimeDate:StartHideTimer() end)

    -- Reusable lines: { label = FontString, value = FontString }
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

function TimeDate:BuildTooltipContent()
    local f = tooltipFrame
    HideLines(f)

    local db = self:GetDB()
    local use24h = db.use24h ~= false

    f.title:SetText("Time & Date")

    local y = -PADDING - 20 - 6
    local lineIdx = 0

    -- Date
    lineIdx = lineIdx + 1
    local dateLine = GetLine(f, lineIdx)
    dateLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    dateLine.label:SetText("|cffffffffDate|r")
    dateLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    dateLine.value:SetText(GetDateString())
    dateLine.value:SetTextColor(0.9, 0.9, 0.9)
    y = y - ROW_HEIGHT

    -- Server time
    local sHour, sMin = GetGameTime()
    lineIdx = lineIdx + 1
    local serverLine = GetLine(f, lineIdx)
    serverLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    serverLine.label:SetText("|cffffffffServer Time|r")
    serverLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    serverLine.value:SetText(FormatTime(sHour, sMin, nil, use24h, false))
    serverLine.value:SetTextColor(0.4, 0.78, 1)
    y = y - ROW_HEIGHT

    -- Local time
    local lTime = date("*t")
    lineIdx = lineIdx + 1
    local localLine = GetLine(f, lineIdx)
    localLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    localLine.label:SetText("|cffffffffLocal Time|r")
    localLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    localLine.value:SetText(FormatTime(lTime.hour, lTime.min, lTime.sec, use24h, true))
    localLine.value:SetTextColor(0.4, 0.78, 1)
    y = y - ROW_HEIGHT

    -- Separator
    y = y - 4

    -- Daily reset
    local dailyReset = C_DateAndTime.GetSecondsUntilDailyReset and C_DateAndTime.GetSecondsUntilDailyReset() or 0
    lineIdx = lineIdx + 1
    local dailyLine = GetLine(f, lineIdx)
    dailyLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    dailyLine.label:SetText("|cffffffffDaily Reset|r")
    dailyLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    dailyLine.value:SetText(FormatCountdown(dailyReset))
    dailyLine.value:SetTextColor(0.0, 1.0, 0.0)
    y = y - ROW_HEIGHT

    -- Weekly reset
    local weeklyReset = C_DateAndTime.GetSecondsUntilWeeklyReset and C_DateAndTime.GetSecondsUntilWeeklyReset() or 0
    lineIdx = lineIdx + 1
    local weeklyLine = GetLine(f, lineIdx)
    weeklyLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    weeklyLine.label:SetText("|cffffffffWeekly Reset|r")
    weeklyLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    weeklyLine.value:SetText(FormatCountdown(weeklyReset))
    weeklyLine.value:SetTextColor(1.0, 0.82, 0.0)
    y = y - ROW_HEIGHT

    -- Calendar events / holidays
    if C_Calendar and C_Calendar.GetNumDayEvents then
        local calTime = C_DateAndTime.GetCurrentCalendarTime()
        if calTime then
            local numEvents = C_Calendar.GetNumDayEvents(0, calTime.monthDay)
            local events = {}
            for i = 1, numEvents do
                local event = C_Calendar.GetDayEvent(0, calTime.monthDay, i)
                if event and event.title then
                    local ct = event.calendarType
                    if ct == "HOLIDAY" or ct == "RAID_LOCKOUT" or ct == "RAID_RESET" then
                        table.insert(events, {
                            title = event.title,
                            calendarType = ct,
                        })
                    end
                end
            end

            if #events > 0 then
                y = y - 4

                lineIdx = lineIdx + 1
                local evHdr = GetLine(f, lineIdx)
                evHdr.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
                evHdr.label:SetText("|cffffd100Today's Events|r")
                evHdr.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
                evHdr.value:SetText("")
                y = y - HEADER_HEIGHT

                for _, ev in ipairs(events) do
                    lineIdx = lineIdx + 1
                    local evLine = GetLine(f, lineIdx)
                    evLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 6, y)
                    evLine.label:SetText(ev.title)
                    if ev.calendarType == "HOLIDAY" then
                        evLine.label:SetTextColor(0.0, 0.8, 0.0)
                    else
                        evLine.label:SetTextColor(0.7, 0.7, 0.7)
                    end
                    evLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
                    evLine.value:SetText("")
                    y = y - ROW_HEIGHT
                end
            end
        end
    end

    -- Hint
    f.hint:SetText("|cff888888LClick: Calendar  |  RClick: Toggle Server/Local|r")

    local ttWidth = db.tooltipWidth or TOOLTIP_WIDTH
    local totalHeight = math.abs(y) + PADDING + HINT_HEIGHT + 8
    f:SetSize(ttWidth, totalHeight)
end

function TimeDate:ShowTooltip(anchor)
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

function TimeDate:StartHideTimer()
    self:CancelHideTimer()
    hideTimer = C_Timer.NewTimer(ns.HIDE_DELAY, function()
        if tooltipFrame then tooltipFrame:Hide() end
        hideTimer = nil
    end)
end

function TimeDate:CancelHideTimer()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
end

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------

TimeDate.settingsLabel = "Time / Date"

function TimeDate:BuildSettingsPanel(panel)
    local W = ns.SettingsWidgets
    local c = panel.content
    local r = panel.refreshCallbacks
    local y = -10
    local db = function() return ns.db.timedate end

    y = W.AddHeader(c, y, "Label Template")
    y = W.AddDescription(c, y, "Tags: <time> <server> <local> <date>")
    y = W.AddEditBox(c, y, "Template",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateDisplay() end, r)

    y = W.AddHeader(c, y, "Display")
    y = W.AddCheckbox(c, y, "Use 24-hour format",
        function() return db().use24h end,
        function(v) db().use24h = v; self:UpdateDisplay() end, r)
    y = W.AddCheckbox(c, y, "Show seconds",
        function() return db().showSeconds end,
        function(v) db().showSeconds = v; self:UpdateDisplay() end, r)
    y = W.AddCheckbox(c, y, "Show local time on DataText (instead of server time)",
        function() return db().showLocal end,
        function(v) db().showLocal = v; self:UpdateDisplay() end, r)

    y = W.AddHeader(c, y, "Tooltip")
    y = W.AddSlider(c, y, "Scale", 0.5, 2.0, 0.05,
        function() return db().tooltipScale end,
        function(v) db().tooltipScale = v end, r)
    y = W.AddSlider(c, y, "Width", 200, 500, 10,
        function() return db().tooltipWidth end,
        function(v) db().tooltipWidth = v end, r)

    y = W.AddHeader(c, y, "Interactions")
    y = W.AddDescription(c, y,
        "Left-click: Open Calendar\n" ..
        "Right-click: Toggle server/local time on the DataText")

    c:SetHeight(math.abs(y) + 20)
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("timedate", TimeDate, DEFAULTS)
