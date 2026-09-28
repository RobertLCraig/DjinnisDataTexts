-- Djinni's Data Texts - Time / Date
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
local HEADER_HEIGHT  = 18
local PADDING        = 10

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
    use24h          = true,
    showLocal       = false,   -- false = server time on LDB, true = local time
    showSeconds     = false,
    dateTimeFormat  = "%A, %B %d, %Y",
    labelTemplate   = "<time>",
    tooltipScale     = 1.0,
    tooltipMaxHeight = 400,
    tooltipWidth     = 260,
    -- Extra tooltip rows for other time zones (card 0007). offset is the zone's
    -- STANDARD offset from UTC in hours; dst names a rule in TZ.RULES or "none".
    -- Pre-filled but off, so turning one on is a single tick.
    extraZones = {
        { enabled = false, label = "New York", offset = -5, dst = "us" },
        { enabled = false, label = "London",   offset = 0,  dst = "eu" },
        { enabled = false, label = "Sydney",   offset = 10, dst = "au" },
        { enabled = false, label = "",         offset = 0,  dst = "none" },
    },
    clickActions    = {
        leftClick       = "calendar",
        rightClick      = "toggletime",
        middleClick     = "none",
        shiftLeftClick  = "stopwatch",
        shiftRightClick = "copytime",
        ctrlLeftClick   = "none",
        ctrlRightClick  = "none",
        altLeftClick    = "opensettings",
        altRightClick   = "none",
    },
}

local CLICK_ACTIONS = {
    calendar     = "Calendar",
    toggletime   = "Toggle Server/Local",
    stopwatch    = "Toggle Stopwatch",
    copytime     = "Copy Time to Chat",
    opensettings = "Open DDT Settings",
    none         = "None",
}

---------------------------------------------------------------------------
-- Date/time format presets
---------------------------------------------------------------------------

local FORMAT_PRESETS = {
    ["%A, %B %d, %Y"]       = "Tuesday, March 31, 2026",
    ["%Y-%m-%d"]             = "2026-03-31",
    ["%d/%m/%Y"]             = "31/03/2026",
    ["%m/%d/%Y"]             = "03/31/2026",
    ["%d %B %Y"]             = "31 March 2026",
    ["%B %d, %Y"]            = "March 31, 2026",
    ["%a, %d %b %Y"]         = "Tue, 31 Mar 2026",
    ["%d-%b-%Y"]             = "31-Mar-2026",
    ["%Y/%m/%d"]             = "2026/03/31",
    ["%A, %d %B %Y"]         = "Tuesday, 31 March 2026",
}

local FORMAT_CHEATSHEET =
    "Strftime Tokens:\n" ..
    "  %Y = Year (2026)          %y = Year short (26)\n" ..
    "  %m = Month 01-12          %B = Month name (March)\n" ..
    "  %b = Month abbr (Mar)     %d = Day 01-31\n" ..
    "  %A = Weekday (Tuesday)    %a = Weekday abbr (Tue)\n" ..
    "  %H = Hour 00-23           %I = Hour 01-12\n" ..
    "  %M = Minute 00-59         %S = Second 00-59\n" ..
    "  %p = AM/PM                %X = Time (locale)\n" ..
    "  %x = Date (locale)        %c = Date+Time (locale)"

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

local function GetDateString(fmt)
    return date(fmt or "%A, %B %d, %Y")
end

---------------------------------------------------------------------------
-- Extra time zones (card 0007)
---------------------------------------------------------------------------
-- WoW's Lua has no time zone database, so daylight saving is computed from the
-- published rules rather than a hand-kept table of dates. Pure arithmetic on a
-- UTC epoch: no os.time (which reads a table as *local* time) and no date("!").

-- [tz-maths] extracted verbatim by docs/build/check-timezones.lua
local TZ = {}
local HOUR, DAY = 3600, 86400

--- Days since 1970-01-01 for a Gregorian date (Howard Hinnant, days_from_civil).
function TZ.DaysFromCivil(y, m, d)
    if m <= 2 then y = y - 1 end
    local era = math.floor(y / 400)
    local yoe = y - era * 400
    local mp  = (m + 9) % 12                       -- March = 0
    local doy = math.floor((153 * mp + 2) / 5) + d - 1
    local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
    return era * 146097 + doe - 719468
end

--- Inverse of DaysFromCivil: y, m, d.
function TZ.CivilFromDays(z)
    z = z + 719468
    local era = math.floor(z / 146097)
    local doe = z - era * 146097
    local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524)
                           - math.floor(doe / 146096)) / 365)
    local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
    local mp  = math.floor((5 * doy + 2) / 153)
    local d   = doy - math.floor((153 * mp + 2) / 5) + 1
    local m   = mp < 10 and mp + 3 or mp - 9
    local y   = yoe + era * 400
    if m <= 2 then y = y + 1 end
    return y, m, d
end

--- 0 = Sunday. 1970-01-01 was a Thursday.
function TZ.Weekday(days) return (days + 4) % 7 end

--- Day number of the nth Sunday of a month (n >= 1), or the last one when n == -1.
function TZ.NthSunday(y, m, n)
    if n == -1 then
        local ny, nm = y, m + 1
        if nm == 13 then ny, nm = y + 1, 1 end
        local last = TZ.DaysFromCivil(ny, nm, 1) - 1
        return last - TZ.Weekday(last)
    end
    local first = TZ.DaysFromCivil(y, m, 1)
    return first + (7 - TZ.Weekday(first)) % 7 + (n - 1) * 7
end

--- Summer time rules. Each returns the UTC instants [start, finish) for calendar
--- year y, given the zone's standard offset in seconds. A start later than the
--- finish means a southern-hemisphere season that spans the new year.
TZ.RULES = {
    -- US / Canada: 2nd Sunday of March 02:00 standard -> 1st Sunday of November 02:00 daylight
    us = function(y, std)
        return TZ.NthSunday(y, 3, 2) * DAY + 2 * HOUR - std,
               TZ.NthSunday(y, 11, 1) * DAY + 2 * HOUR - (std + HOUR)
    end,
    -- EU / UK: last Sunday of March 01:00 UTC -> last Sunday of October 01:00 UTC
    eu = function(y, std)
        return TZ.NthSunday(y, 3, -1) * DAY + 1 * HOUR,
               TZ.NthSunday(y, 10, -1) * DAY + 1 * HOUR
    end,
    -- Australia south-east: 1st Sunday of October 02:00 standard -> 1st Sunday of April 03:00 daylight
    au = function(y, std)
        return TZ.NthSunday(y, 10, 1) * DAY + 2 * HOUR - std,
               TZ.NthSunday(y, 4, 1) * DAY + 3 * HOUR - (std + HOUR)
    end,
}

function TZ.IsSummer(utc, std, rule)
    local f = TZ.RULES[rule]
    if not f then return false end
    local y = TZ.CivilFromDays(math.floor(utc / DAY))
    local s, e = f(y, std)
    if s < e then return utc >= s and utc < e end
    return utc >= s or utc < e
end

--- Wall-clock time in a zone: days-since-epoch, hour, minute, isSummer.
--- offsetHours is the zone's STANDARD offset from UTC, e.g. -5 or 5.5.
function TZ.ZoneTime(utc, offsetHours, rule)
    local std = math.floor((tonumber(offsetHours) or 0) * HOUR + 0.5)
    local summer = TZ.IsSummer(utc, std, rule)
    local t = utc + std + (summer and HOUR or 0)
    local days = math.floor(t / DAY)
    local secs = t - days * DAY
    return days, math.floor(secs / HOUR), math.floor((secs % HOUR) / 60), summer
end

--- "UTC+5:30", "UTC-5", "UTC".
function TZ.FormatOffset(offsetHours)
    local mins = math.floor(math.abs(tonumber(offsetHours) or 0) * 60 + 0.5)
    if mins == 0 then return "UTC" end
    local sign = (tonumber(offsetHours) or 0) < 0 and "-" or "+"
    local h, m = math.floor(mins / 60), mins % 60
    if m == 0 then return "UTC" .. sign .. h end
    return string.format("UTC%s%d:%02d", sign, h, m)
end
-- [/tz-maths]

local MAX_EXTRA_ZONES = 4

local DST_RULES = {
    none = "None (fixed offset)",
    us   = "United States / Canada",
    eu   = "Europe / UK",
    au   = "Australia (south-east)",
}

--- The enabled extra zones as display rows: { label, time, dayShift }.
--- dayShift is the zone's calendar day minus the player's local calendar day.
local function GetExtraZoneRows(db, use24h)
    local rows = {}
    local zones = db.extraZones
    if type(zones) ~= "table" then return rows end
    local utc = (GetServerTime and GetServerTime()) or time()
    local lt = date("*t")
    local localDays = TZ.DaysFromCivil(lt.year, lt.month, lt.day)
    for i = 1, MAX_EXTRA_ZONES do
        local z = zones[i]
        if type(z) == "table" and z.enabled then
            local days, hour, minute = TZ.ZoneTime(utc, z.offset, z.dst)
            local label = (type(z.label) == "string" and z.label ~= "") and z.label
                          or TZ.FormatOffset(z.offset)
            table.insert(rows, {
                label    = label,
                time     = FormatTime(hour, minute, nil, use24h, false),
                dayShift = days - localDays,
            })
        end
    end
    return rows
end

---------------------------------------------------------------------------
-- Label template expansion
---------------------------------------------------------------------------

local function ExpandLabel(template, db)
    local result = template
    local use24h = db.use24h ~= false
    local showSec = db.showSeconds
    local E = ns.ExpandTag

    local sHour, sMin = GetGameTime()
    local lTime = date("*t")

    if db.showLocal then
        result = E(result, "time", FormatTime(lTime.hour, lTime.min, showSec and lTime.sec or nil, use24h, showSec))
    else
        result = E(result, "time", FormatTime(sHour, sMin, nil, use24h, false))
    end
    result = E(result, "server", FormatTime(sHour, sMin, nil, use24h, false))
    result = E(result, "local", FormatTime(lTime.hour, lTime.min, lTime.sec, use24h, true))
    result = E(result, "date", GetDateString(db.dateTimeFormat))
    return result
end

---------------------------------------------------------------------------
-- LDB Data Object
---------------------------------------------------------------------------

local dataobj = ns:NewBroker("timedate", "DDT-TimeDate", {
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
        local db = TimeDate:GetDB()
        local action = DDT:ResolveClickAction(button, db.clickActions or {})
        if action == "calendar" then
            ToggleCalendar()
        elseif action == "toggletime" then
            if ns.db and ns.db.timedate then
                ns.db.timedate.showLocal = not ns.db.timedate.showLocal
            end
        elseif action == "stopwatch" then
            Stopwatch_Toggle()
        elseif action == "copytime" then
            local use24h = db.use24h ~= false
            local sHour, sMin = GetGameTime()
            local lTime = date("*t")
            local msg = "Server: " .. FormatTime(sHour, sMin, nil, use24h, false)
                .. " | Local: " .. FormatTime(lTime.hour, lTime.min, lTime.sec, use24h, true)
            ChatFrameUtil.OpenChat(msg)
        elseif action == "pintooltip" then
            ns:TogglePinTooltip(TimeDate, tooltipFrame)
        elseif action == "opensettings" then
            if DDT.settingsCategoryID then
                Settings.OpenToCategory(DDT.settingsCategoryID)
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
    local f = ns.CreateTooltipFrame("DDTTimeDateTooltip", TimeDate)
    f.content.lines = {}
    return f
end

local function GetLine(f, index)
    if f.lines[index] then
        f.lines[index].label:Show()
        f.lines[index].value:Show()
        return f.lines[index]
    end

    local label = ns.FontString(f, "DDTFontNormal")
    label:SetJustifyH("LEFT")

    local value = ns.FontString(f, "DDTFontNormal")
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
    local c = f.content
    HideLines(c)

    local db = self:GetDB()
    local use24h = db.use24h ~= false

    f.header:SetText("Time & Date")

    local y = 0
    local lineIdx = 0

    -- Date
    lineIdx = lineIdx + 1
    local dateLine = GetLine(c, lineIdx)
    dateLine.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
    dateLine.label:SetText("|cffffffffDate|r")
    dateLine.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
    dateLine.value:SetText(GetDateString(db.dateTimeFormat))
    dateLine.value:SetTextColor(0.9, 0.9, 0.9)
    y = y - ns.ROW_HEIGHT

    -- Server time
    local sHour, sMin = GetGameTime()
    lineIdx = lineIdx + 1
    local serverLine = GetLine(c, lineIdx)
    serverLine.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
    serverLine.label:SetText("|cffffffffServer Time|r")
    serverLine.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
    serverLine.value:SetText(FormatTime(sHour, sMin, nil, use24h, false))
    serverLine.value:SetTextColor(0.4, 0.78, 1)
    y = y - ns.ROW_HEIGHT

    -- Local time
    local lTime = date("*t")
    lineIdx = lineIdx + 1
    local localLine = GetLine(c, lineIdx)
    localLine.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
    localLine.label:SetText("|cffffffffLocal Time|r")
    localLine.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
    localLine.value:SetText(FormatTime(lTime.hour, lTime.min, lTime.sec, use24h, true))
    localLine.value:SetTextColor(0.4, 0.78, 1)
    y = y - ns.ROW_HEIGHT

    -- Extra time zones (card 0007), one row each, in slot order
    for _, zr in ipairs(GetExtraZoneRows(db, use24h)) do
        lineIdx = lineIdx + 1
        local zl = GetLine(c, lineIdx)
        zl.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
        zl.label:SetText("|cffffffff" .. zr.label .. "|r")
        zl.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
        local shift = ""
        if zr.dayShift > 0 then
            shift = "  |cff888888+" .. zr.dayShift .. "d|r"
        elseif zr.dayShift < 0 then
            shift = "  |cff888888" .. zr.dayShift .. "d|r"
        end
        zl.value:SetText(zr.time .. shift)
        zl.value:SetTextColor(0.4, 0.78, 1)
        y = y - ns.ROW_HEIGHT
    end

    -- Separator
    y = y - 4

    -- Daily reset
    local dailyReset = C_DateAndTime.GetSecondsUntilDailyReset and C_DateAndTime.GetSecondsUntilDailyReset() or 0
    lineIdx = lineIdx + 1
    local dailyLine = GetLine(c, lineIdx)
    dailyLine.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
    dailyLine.label:SetText("|cffffffffDaily Reset|r")
    dailyLine.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
    dailyLine.value:SetText(FormatCountdown(dailyReset))
    dailyLine.value:SetTextColor(0.0, 1.0, 0.0)
    y = y - ns.ROW_HEIGHT

    -- Weekly reset
    local weeklyReset = C_DateAndTime.GetSecondsUntilWeeklyReset and C_DateAndTime.GetSecondsUntilWeeklyReset() or 0
    lineIdx = lineIdx + 1
    local weeklyLine = GetLine(c, lineIdx)
    weeklyLine.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
    weeklyLine.label:SetText("|cffffffffWeekly Reset|r")
    weeklyLine.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
    weeklyLine.value:SetText(FormatCountdown(weeklyReset))
    weeklyLine.value:SetTextColor(1.0, 0.82, 0.0)
    y = y - ns.ROW_HEIGHT

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
                local evHdr = GetLine(c, lineIdx)
                evHdr.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
                evHdr.label:SetText("|cffffd100Today's Events|r")
                evHdr.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
                evHdr.value:SetText("")
                y = y - HEADER_HEIGHT

                for _, ev in ipairs(events) do
                    lineIdx = lineIdx + 1
                    local evLine = GetLine(c, lineIdx)
                    evLine.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING + 6, y)
                    evLine.label:SetText(ev.title)
                    if ev.calendarType == "HOLIDAY" then
                        evLine.label:SetTextColor(0.0, 0.8, 0.0)
                    else
                        evLine.label:SetTextColor(0.7, 0.7, 0.7)
                    end
                    evLine.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
                    evLine.value:SetText("")
                    y = y - ns.ROW_HEIGHT
                end
            end
        end
    end

    -- Hint
    f.hint:SetText(DDT:BuildHintText(db.clickActions or {}, CLICK_ACTIONS))

    local ttWidth = db.tooltipWidth or TOOLTIP_WIDTH
    f:FinalizeLayout(ttWidth, math.abs(y))
end

function TimeDate:ShowTooltip(anchor)
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
    local r = panel.refreshCallbacks
    local db = function() return ns.db.timedate end

    W.AddLabelEditBox(panel, "time server local date",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateDisplay() end, r, {
        { "Default",    "<time>" },
        { "With Date",  "<time>  <date>" },
        { "Both Times", "S: <server>  L: <local>" },
        { "Date Only",  "<date>" },
    })

    local body = W.AddSection(panel, "Display")
    local y = 0
    y = W.AddCheckbox(body, y, "Use 24-hour format",
        function() return db().use24h end,
        function(v) db().use24h = v; self:UpdateDisplay() end, r)
    y = W.AddCheckbox(body, y, "Show seconds",
        function() return db().showSeconds end,
        function(v) db().showSeconds = v; self:UpdateDisplay() end, r)
    y = W.AddCheckbox(body, y, "Show local time on DataText (instead of server time)",
        function() return db().showLocal end,
        function(v) db().showLocal = v; self:UpdateDisplay() end, r)
    W.EndSection(panel, y)

    -- Extra time zones (card 0007)
    body = W.AddSection(panel, "Extra Time Zones")
    y = 0
    y = W.AddDescription(body, y,
        "Up to " .. MAX_EXTRA_ZONES .. " more clocks as tooltip rows. Set each zone's standard " ..
        "(winter) offset from UTC in hours, so 5.5 means +5:30 and -5 is New York. Pick a " ..
        "daylight saving rule and the summer hour is added on the right dates by itself. " ..
        "A small +1d or -1d means that zone is already on another calendar day from you.")
    local function zone(i)
        local zones = db().extraZones
        if type(zones) ~= "table" then zones = {}; db().extraZones = zones end
        if type(zones[i]) ~= "table" then zones[i] = { enabled = false, label = "", offset = 0, dst = "none" } end
        return zones[i]
    end
    for i = 1, MAX_EXTRA_ZONES do
        y = W.AddCheckbox(body, y, "Show zone " .. i,
            function() return zone(i).enabled end,
            function(v) zone(i).enabled = v; self:UpdateDisplay() end, r)
        y = W.AddEditBox(body, y, "Zone " .. i .. " label (blank shows the UTC offset)",
            function() return zone(i).label or "" end,
            function(v) zone(i).label = v; self:UpdateDisplay() end, r)
        y = W.AddSlider(body, y, "Zone " .. i .. " standard offset from UTC (hours)", -12, 14, 0.25,
            function() return zone(i).offset or 0 end,
            function(v) zone(i).offset = v; self:UpdateDisplay() end, r)
        y = W.AddDropdown(body, y, "Zone " .. i .. " daylight saving", DST_RULES,
            function() return zone(i).dst or "none" end,
            function(v) zone(i).dst = v; self:UpdateDisplay() end, r)
        y = y - 8
    end
    W.EndSection(panel, y)

    body = W.AddSection(panel, "Date Format")
    y = 0

    -- Live preview
    y = y - 4
    local previewText = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    previewText:SetPoint("TOPLEFT", body, "TOPLEFT", 18, y)
    previewText:SetText("Preview: |cff4bc8ff" .. date(db().dateTimeFormat) .. "|r")
    y = y - 20

    local function RefreshPreview()
        previewText:SetText("Preview: |cff4bc8ff" .. date(db().dateTimeFormat) .. "|r")
    end

    -- Preset dropdown
    y = W.AddDropdown(body, y, "Preset", FORMAT_PRESETS,
        function() return db().dateTimeFormat end,
        function(v)
            db().dateTimeFormat = v
            self:UpdateDisplay()
            RefreshPreview()
        end, r)

    -- Custom format editbox
    y = W.AddEditBox(body, y, "Custom Format String",
        function() return db().dateTimeFormat end,
        function(v)
            db().dateTimeFormat = v
            self:UpdateDisplay()
            RefreshPreview()
        end, r)

    -- Cheatsheet
    y = W.AddDescription(body, y, FORMAT_CHEATSHEET)
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
    y = W.AddSliderPair(body, y,
        { label = "Max Height", min = 100, max = 1000, step = 10,
          get = function() return db().tooltipMaxHeight end,
          set = function(v) db().tooltipMaxHeight = v end },
        nil, r)
    y = W.AddNote(body, y, "Suggested: 350 x 350 for time, resets, and calendar events.")
    y = W.AddTooltipGrowDirection(body, y, db, r)
    y = W.AddTooltipCopyFrom(body, y, "timedate", db, r)
    W.EndSection(panel, y)

    ns.AddModuleClickActionsSection(panel, r, "timedate", CLICK_ACTIONS)
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("timedate", TimeDate, DEFAULTS)
