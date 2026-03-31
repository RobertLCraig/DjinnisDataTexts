-- Djinni's Data Texts — System Performance
-- FPS, latency (home/world), memory usage, and top addon memory/CPU consumers.
local addonName, ns = ...
local DDT = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local SysPerf = {}
ns.SysPerf = SysPerf

-- Tooltip
local tooltipFrame = nil
local hideTimer = nil

-- Layout
local TOOLTIP_WIDTH  = 320
local ROW_HEIGHT     = 20
local HEADER_HEIGHT  = 18
local PADDING        = 10
local HINT_HEIGHT    = 18

-- State
local fps = 0
local latencyHome = 0
local latencyWorld = 0
local memoryTotal = 0      -- KB, all addons
local addonMemory = {}     -- { { name, memory } } sorted desc
local NUM_TOP_ADDONS = 10

-- CPU profiler state (C_AddOnProfiler)
local profilerAvailable = false
local overallCPU = { current = 0, average = 0, encounter = 0, peak = 0 }
local addonCPU = {}        -- { { name, current, average, encounter, peak } }

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
    labelTemplate    = "<fps> fps  <latency>ms",
    showTopAddons    = true,
    numTopAddons     = 10,
    addonSortOrder   = "memory_desc",  -- memory_desc, memory_asc, name
    showCpuUsage     = true,
    cpuSortMetric    = "current",      -- current, average, peak, encounter
    numTopCpuAddons  = 10,
    tooltipScale     = 1.0,
    tooltipWidth     = 320,
    clickActions     = {
        leftClick       = "gc",
        rightClick      = "refresh",
    },
}

local CLICK_ACTIONS = {
    gc             = "Collect Garbage",
    refresh        = "Refresh Memory",
    gamemenu       = "Game Menu",
    reloadui       = "Reload UI",
    opensettings   = "Open DDT Settings",
    none           = "None",
}

local ADDON_SORT_VALUES = {
    memory_desc = "Memory (High > Low)",
    memory_asc  = "Memory (Low > High)",
    name        = "Name (A-Z)",
}

local CPU_SORT_VALUES = {
    current   = "Current CPU",
    average   = "Average CPU",
    peak      = "Peak CPU",
    encounter = "Encounter CPU",
}

local function SortAddonMemory(list, order)
    if order == "memory_asc" then
        table.sort(list, function(a, b)
            if a.memory ~= b.memory then return a.memory < b.memory end
            return a.name < b.name
        end)
    elseif order == "name" then
        table.sort(list, function(a, b)
            return a.name < b.name
        end)
    else -- memory_desc (default)
        table.sort(list, function(a, b)
            if a.memory ~= b.memory then return a.memory > b.memory end
            return a.name < b.name
        end)
    end
end

local function SortAddonCPU(list, metric)
    local key = metric or "current"
    table.sort(list, function(a, b)
        if a[key] ~= b[key] then return a[key] > b[key] end
        return a.name < b.name
    end)
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function FormatMemory(kb)
    if kb >= 1024 then
        return string.format("%.1f MB", kb / 1024)
    end
    return string.format("%.0f KB", kb)
end

local function LatencyColor(ms)
    if ms < 100 then return 0.0, 1.0, 0.0 end
    if ms < 250 then return 1.0, 0.82, 0.0 end
    return 1.0, 0.2, 0.2
end

local function FPSColor(val)
    if val >= 60 then return 0.0, 1.0, 0.0 end
    if val >= 30 then return 1.0, 0.82, 0.0 end
    return 1.0, 0.2, 0.2
end

local function CPUColor(pct)
    if pct > 50 then return 1.0, 0.2, 0.2 end
    if pct > 25 then return 1.0, 0.6, 0.2 end
    if pct > 10 then return 1.0, 0.82, 0.0 end
    return 1.0, 1.0, 1.0
end

local function FormatCPU(pct)
    if pct <= 0 then return "—" end
    return string.format("%.2f%%", pct)
end

---------------------------------------------------------------------------
-- CPU Profiler (C_AddOnProfiler)
---------------------------------------------------------------------------

local function IsProfilerEnabled()
    return C_AddOnProfiler and C_AddOnProfiler.IsEnabled()
end

--- Get overall CPU% for a metric (all addons combined / application total)
local function GetOverallPercent(metric)
    if not C_AddOnProfiler.GetApplicationMetric then return 0 end
    local app = C_AddOnProfiler.GetApplicationMetric(metric)
    if not app or app <= 0 then return 0 end
    local overall = C_AddOnProfiler.GetOverallMetric(metric)
    return (overall / app) * 100
end

--- Get per-addon CPU% for a metric, using pre-fetched overall/app values
local function GetAddonPercentFast(addonIndex, metric, appMetric, overallMetric)
    local addon = C_AddOnProfiler.GetAddOnMetric(addonIndex, metric)
    if addon <= 0 then return 0 end
    local relative = appMetric - overallMetric + addon
    if relative <= 0 then return 0 end
    return (addon / relative) * 100
end

-- Metric key to Enum mapping
local METRIC_ENUM_MAP -- populated on first use

local function CollectCPU()
    profilerAvailable = IsProfilerEnabled()
    wipe(addonCPU)

    if not profilerAvailable then
        overallCPU.current   = 0
        overallCPU.average   = 0
        overallCPU.encounter = 0
        overallCPU.peak      = 0
        return
    end

    local M = Enum.AddOnProfilerMetric
    if not METRIC_ENUM_MAP then
        METRIC_ENUM_MAP = {
            current   = M.RecentAverageTime,
            average   = M.SessionAverageTime,
            encounter = M.EncounterAverageTime,
            peak      = M.PeakTime,
        }
    end

    -- Fetch overall percentages (4 calls each = 8 API calls total)
    overallCPU.current   = GetOverallPercent(M.RecentAverageTime)
    overallCPU.average   = GetOverallPercent(M.SessionAverageTime)
    overallCPU.encounter = GetOverallPercent(M.EncounterAverageTime)
    overallCPU.peak      = GetOverallPercent(M.PeakTime)

    -- Only fetch the active sort metric for all addons (1 API call per addon)
    local db = ns.db and ns.db.systemperformance or DEFAULTS
    local sortKey = db.cpuSortMetric or "current"
    local sortEnum = METRIC_ENUM_MAP[sortKey] or M.RecentAverageTime

    -- Pre-fetch overall and app for the sort metric (avoid re-calling per addon)
    local sortOverall = C_AddOnProfiler.GetOverallMetric(sortEnum)
    local sortApp = C_AddOnProfiler.GetApplicationMetric
        and C_AddOnProfiler.GetApplicationMetric(sortEnum) or sortOverall

    local numAddons = C_AddOns.GetNumAddOns()
    for i = 1, numAddons do
        local val = GetAddonPercentFast(i, sortEnum, sortApp, sortOverall)
        if val > 0 then
            local name = C_AddOns.GetAddOnInfo(i)
            local entry = { name = name, index = i }
            entry[sortKey] = val
            table.insert(addonCPU, entry)
        end
    end

    -- Sort by the active metric, then fill remaining metrics for top N only
    SortAddonCPU(addonCPU, sortKey)
    local topN = math.min(db.numTopCpuAddons or 10, #addonCPU)
    for j = 1, topN do
        local entry = addonCPU[j]
        for key, enum in pairs(METRIC_ENUM_MAP) do
            if not entry[key] then
                local ov = C_AddOnProfiler.GetOverallMetric(enum)
                local ap = C_AddOnProfiler.GetApplicationMetric
                    and C_AddOnProfiler.GetApplicationMetric(enum) or ov
                entry[key] = GetAddonPercentFast(entry.index, enum, ap, ov)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Label template expansion
---------------------------------------------------------------------------

local function ExpandLabel(template)
    local result = template
    result = result:gsub("<fps>", string.format("%.0f", fps))
    result = result:gsub("<latency>", tostring(latencyHome))
    result = result:gsub("<world>", tostring(latencyWorld))
    result = result:gsub("<memory>", FormatMemory(memoryTotal))
    result = result:gsub("<cpu>", profilerAvailable and FormatCPU(overallCPU.current) or "N/A")
    return result
end

---------------------------------------------------------------------------
-- LDB Data Object
---------------------------------------------------------------------------

local dataobj = LDB:NewDataObject("DDT-SystemPerformance", {
    type  = "data source",
    text  = "0 fps  0ms",
    icon  = "Interface\\Icons\\INV_Gizmo_01",
    label = "DDT - System",
    OnEnter = function(self)
        SysPerf:ShowTooltip(self)
    end,
    OnLeave = function(self)
        SysPerf:StartHideTimer()
    end,
    OnClick = function(self, button)
        local db = SysPerf:GetDB()
        local action = DDT:ResolveClickAction(button, db.clickActions or {})
        if action == "gc" then
            collectgarbage("collect")
            SysPerf:UpdateData()
        elseif action == "refresh" then
            UpdateAddOnMemoryUsage()
            SysPerf:UpdateData()
        elseif action == "gamemenu" then
            ToggleGameMenuFrame()
        elseif action == "reloadui" then
            ReloadUI()
        elseif action == "opensettings" then
            if DDT.settingsCategoryID then
                Settings.OpenToCategory(DDT.settingsCategoryID)
            end
        end
    end,
})

SysPerf.dataobj = dataobj

---------------------------------------------------------------------------
-- Event handling and update
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local elapsed = 0
local UPDATE_INTERVAL = 1

function SysPerf:Init()
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", function()
        SysPerf:UpdateData()
    end)

    eventFrame:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= UPDATE_INTERVAL then
            elapsed = 0
            SysPerf:UpdateData()
        end
    end)
end

function SysPerf:GetDB()
    return ns.db and ns.db.systemperformance or DEFAULTS
end

---------------------------------------------------------------------------
-- Data collection
---------------------------------------------------------------------------

function SysPerf:UpdateData()
    fps = GetFramerate()
    latencyHome, latencyWorld = select(3, GetNetStats())

    local db = self:GetDB()

    -- Addon memory
    UpdateAddOnMemoryUsage()
    memoryTotal = 0
    wipe(addonMemory)

    local numAddons = C_AddOns.GetNumAddOns()
    for i = 1, numAddons do
        local mem = GetAddOnMemoryUsage(i)
        memoryTotal = memoryTotal + mem
        if mem > 0 then
            local name = C_AddOns.GetAddOnInfo(i)
            table.insert(addonMemory, { name = name, memory = mem })
        end
    end

    -- CPU profiling (C_AddOnProfiler)
    if db.showCpuUsage then
        CollectCPU()
    end

    -- Update LDB text
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
    local f = CreateFrame("Frame", "DDTSystemPerfTooltip", UIParent, "BackdropTemplate")
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
    f:SetScript("OnEnter", function() SysPerf:CancelHideTimer() end)
    f:SetScript("OnLeave", function() SysPerf:StartHideTimer() end)

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

function SysPerf:BuildTooltipContent()
    local f = tooltipFrame
    HideLines(f)

    local db = self:GetDB()

    f.title:SetText("System Performance")

    local y = -PADDING - 20 - 6
    local lineIdx = 0

    -- FPS
    lineIdx = lineIdx + 1
    local fpsLine = GetLine(f, lineIdx)
    fpsLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    fpsLine.label:SetText("|cffffffffFramerate|r")
    fpsLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    fpsLine.value:SetText(string.format("%.0f fps", fps))
    fpsLine.value:SetTextColor(FPSColor(fps))
    y = y - ROW_HEIGHT

    -- Home latency
    lineIdx = lineIdx + 1
    local homeLine = GetLine(f, lineIdx)
    homeLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    homeLine.label:SetText("|cffffffffHome Latency|r")
    homeLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    homeLine.value:SetText(latencyHome .. " ms")
    homeLine.value:SetTextColor(LatencyColor(latencyHome))
    y = y - ROW_HEIGHT

    -- World latency
    lineIdx = lineIdx + 1
    local worldLine = GetLine(f, lineIdx)
    worldLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    worldLine.label:SetText("|cffffffffWorld Latency|r")
    worldLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    worldLine.value:SetText(latencyWorld .. " ms")
    worldLine.value:SetTextColor(LatencyColor(latencyWorld))
    y = y - ROW_HEIGHT

    -- Separator
    y = y - 4

    -- Total memory
    lineIdx = lineIdx + 1
    local memLine = GetLine(f, lineIdx)
    memLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    memLine.label:SetText("|cffffffffTotal Addon Memory|r")
    memLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    memLine.value:SetText(FormatMemory(memoryTotal))
    memLine.value:SetTextColor(0.4, 0.78, 1)
    y = y - ROW_HEIGHT

    -- Top addons (memory)
    if db.showTopAddons and #addonMemory > 0 then
        SortAddonMemory(addonMemory, db.addonSortOrder)
        y = y - 4

        lineIdx = lineIdx + 1
        local hdr = GetLine(f, lineIdx)
        hdr.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        hdr.label:SetText("|cffffd100Top Addons (Memory)|r")
        hdr.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        hdr.value:SetText("")
        y = y - HEADER_HEIGHT

        local count = math.min(db.numTopAddons or NUM_TOP_ADDONS, #addonMemory)
        for i = 1, count do
            local addon = addonMemory[i]
            lineIdx = lineIdx + 1
            local row = GetLine(f, lineIdx)
            row.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 6, y)
            row.label:SetText(addon.name)
            row.label:SetTextColor(0.8, 0.8, 0.8)
            row.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
            row.value:SetText(FormatMemory(addon.memory))
            row.value:SetTextColor(0.6, 0.6, 0.6)
            y = y - ROW_HEIGHT
        end
    end

    -------------------------------------------------------------------
    -- CPU Profiler section
    -------------------------------------------------------------------
    if db.showCpuUsage then
        y = y - 4

        if not profilerAvailable then
            -- Profiler not available
            lineIdx = lineIdx + 1
            local cpuHdr = GetLine(f, lineIdx)
            cpuHdr.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
            cpuHdr.label:SetText("|cffffd100CPU Profiling|r")
            cpuHdr.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
            cpuHdr.value:SetText("|cffff3333Not Available|r")
            y = y - ROW_HEIGHT

            lineIdx = lineIdx + 1
            local note = GetLine(f, lineIdx)
            note.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 6, y)
            note.label:SetText("|cff888888C_AddOnProfiler not enabled in this session.|r")
            note.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
            note.value:SetText("")
            y = y - ROW_HEIGHT
        else
            -- Overall CPU summary row
            lineIdx = lineIdx + 1
            local cpuHdr = GetLine(f, lineIdx)
            cpuHdr.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
            cpuHdr.label:SetText("|cffffd100CPU Usage (All Addons)|r")
            cpuHdr.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
            cpuHdr.value:SetText("")
            y = y - HEADER_HEIGHT

            -- Overall metrics: Current | Average | Encounter | Peak
            lineIdx = lineIdx + 1
            local curLine = GetLine(f, lineIdx)
            curLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 6, y)
            curLine.label:SetText("|cffffffffCurrent|r")
            curLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
            curLine.value:SetText(FormatCPU(overallCPU.current))
            curLine.value:SetTextColor(CPUColor(overallCPU.current))
            y = y - ROW_HEIGHT

            lineIdx = lineIdx + 1
            local avgLine = GetLine(f, lineIdx)
            avgLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 6, y)
            avgLine.label:SetText("|cffffffffAverage|r")
            avgLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
            avgLine.value:SetText(FormatCPU(overallCPU.average))
            avgLine.value:SetTextColor(CPUColor(overallCPU.average))
            y = y - ROW_HEIGHT

            lineIdx = lineIdx + 1
            local encLine = GetLine(f, lineIdx)
            encLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 6, y)
            encLine.label:SetText("|cffffffffEncounter|r")
            encLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
            local encText = overallCPU.encounter > 0 and FormatCPU(overallCPU.encounter) or "—"
            encLine.value:SetText(encText)
            if overallCPU.encounter > 0 then
                encLine.value:SetTextColor(CPUColor(overallCPU.encounter))
            else
                encLine.value:SetTextColor(0.5, 0.5, 0.5)
            end
            y = y - ROW_HEIGHT

            lineIdx = lineIdx + 1
            local pkLine = GetLine(f, lineIdx)
            pkLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 6, y)
            pkLine.label:SetText("|cffffffffPeak|r")
            pkLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
            pkLine.value:SetText(FormatCPU(overallCPU.peak))
            pkLine.value:SetTextColor(CPUColor(overallCPU.peak))
            y = y - ROW_HEIGHT

            -- Per-addon CPU breakdown
            if #addonCPU > 0 then
                local sortMetric = db.cpuSortMetric or "current"
                SortAddonCPU(addonCPU, sortMetric)
                y = y - 4

                -- Column header
                local metricLabel = CPU_SORT_VALUES[sortMetric] or "Current CPU"
                lineIdx = lineIdx + 1
                local listHdr = GetLine(f, lineIdx)
                listHdr.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
                listHdr.label:SetText("|cffffd100Top Addons (CPU)|r")
                listHdr.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
                listHdr.value:SetText("|cff888888" .. metricLabel .. "|r")
                y = y - HEADER_HEIGHT

                local cpuCount = math.min(db.numTopCpuAddons or 10, #addonCPU)
                for i = 1, cpuCount do
                    local addon = addonCPU[i]
                    local val = addon[sortMetric] or 0
                    if val <= 0 then break end

                    lineIdx = lineIdx + 1
                    local row = GetLine(f, lineIdx)
                    row.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 6, y)
                    row.label:SetText(addon.name)
                    row.label:SetTextColor(0.8, 0.8, 0.8)
                    row.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
                    row.value:SetText(FormatCPU(val))
                    row.value:SetTextColor(CPUColor(val))
                    y = y - ROW_HEIGHT
                end
            end
        end
    end

    -- Hint
    f.hint:SetText(DDT:BuildHintText(db.clickActions or {}, CLICK_ACTIONS))

    local ttWidth = db.tooltipWidth or TOOLTIP_WIDTH
    local totalHeight = math.abs(y) + PADDING + HINT_HEIGHT + 8
    f:SetSize(ttWidth, totalHeight)
end

function SysPerf:ShowTooltip(anchor)
    self:CancelHideTimer()

    if not tooltipFrame then
        tooltipFrame = CreateTooltipFrame()
    end

    local db = self:GetDB()
    tooltipFrame:ClearAllPoints()
    tooltipFrame:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 4)
    tooltipFrame:SetScale(db.tooltipScale or 1.0)

    self:UpdateData()
    self:BuildTooltipContent()
    tooltipFrame:Show()
end

function SysPerf:StartHideTimer()
    self:CancelHideTimer()
    hideTimer = C_Timer.NewTimer(ns.HIDE_DELAY, function()
        if tooltipFrame then tooltipFrame:Hide() end
        hideTimer = nil
    end)
end

function SysPerf:CancelHideTimer()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
end

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------

SysPerf.settingsLabel = "System Performance"

function SysPerf:BuildSettingsPanel(panel)
    local W = ns.SettingsWidgets
    local c = panel.content
    local r = panel.refreshCallbacks
    local y = -10
    local db = function() return ns.db.systemperformance end

    y = W.AddHeader(c, y, "Label Template")
    y = W.AddLabelEditBox(c, y, "fps latency world memory cpu",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateData() end, r)

    y = W.AddHeader(c, y, "Tooltip")
    y = W.AddSlider(c, y, "Scale", 0.5, 2.0, 0.05,
        function() return db().tooltipScale end,
        function(v) db().tooltipScale = v end, r)
    y = W.AddSlider(c, y, "Width", 250, 600, 10,
        function() return db().tooltipWidth end,
        function(v) db().tooltipWidth = v end, r)

    y = W.AddHeader(c, y, "Addon Memory")
    y = W.AddCheckbox(c, y, "Show top addon memory usage",
        function() return db().showTopAddons end,
        function(v) db().showTopAddons = v end, r)
    y = W.AddSlider(c, y, "Number of addons to show", 5, 25, 1,
        function() return db().numTopAddons end,
        function(v) db().numTopAddons = v end, r)
    y = W.AddDropdown(c, y, "Sort Order", ADDON_SORT_VALUES,
        function() return db().addonSortOrder end,
        function(v) db().addonSortOrder = v end, r)

    y = W.AddHeader(c, y, "CPU Profiling")
    y = W.AddCheckbox(c, y, "Show CPU usage per addon",
        function() return db().showCpuUsage end,
        function(v) db().showCpuUsage = v end, r)
    y = W.AddDropdown(c, y, "Sort By", CPU_SORT_VALUES,
        function() return db().cpuSortMetric end,
        function(v) db().cpuSortMetric = v end, r)
    y = W.AddSlider(c, y, "Number of CPU addons to show", 5, 25, 1,
        function() return db().numTopCpuAddons end,
        function(v) db().numTopCpuAddons = v end, r)
    y = W.AddDescription(c, y,
        "Uses the C_AddOnProfiler API to display per-addon CPU\n" ..
        "usage as a percentage of total frame time.\n" ..
        "Shows Current, Average, Encounter, and Peak metrics\n" ..
        "similar to Simple Addon Manager's profiler view.")

    y = ns.AddModuleClickActionsSection(c, r, y, "systemperformance", CLICK_ACTIONS)

    c:SetHeight(math.abs(y) + 20)
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("systemperformance", SysPerf, DEFAULTS)
