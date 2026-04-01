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
    tooltipMaxHeight = 500,
    tooltipWidth     = 320,
    clickActions     = {
        leftClick       = "gc",
        rightClick      = "refresh",
        middleClick     = "none",
        shiftLeftClick  = "addonlist",
        shiftRightClick = "none",
        ctrlLeftClick   = "reloadui",
        ctrlRightClick  = "none",
        altLeftClick    = "opensettings",
        altRightClick   = "none",
    },
}

local CLICK_ACTIONS = {
    gc             = "Collect Garbage",
    refresh        = "Refresh Memory",
    addonlist      = "Addon List",
    gamemenu       = "Game Menu",
    reloadui       = "Reload UI",
    copymemory     = "Copy Memory Report",
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
    return ns.FormatMemory(kb)
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
    local E = ns.ExpandTag
    result = E(result, "fps", string.format("%.0f", fps))
    result = E(result, "latency", latencyHome)
    result = E(result, "world", latencyWorld)
    result = E(result, "memory", FormatMemory(memoryTotal))
    result = E(result, "cpu", profilerAvailable and FormatCPU(overallCPU.current) or "N/A")
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
        elseif action == "addonlist" then
            if AddonList then
                if AddonList:IsShown() then
                    AddonList:Hide()
                else
                    AddonList:Show()
                end
            end
        elseif action == "copymemory" then
            local msg = string.format("FPS: %.0f | Home: %dms | World: %dms | Memory: %s",
                fps, latencyHome, latencyWorld, FormatMemory(memoryTotal))
            ChatFrameUtil.OpenChat(msg)
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

    -- OnUpdate only refreshes fps/latency for the label (cheap).
    -- Full memory + CPU scan runs only when tooltip is shown.
    eventFrame:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= UPDATE_INTERVAL then
            elapsed = 0
            if tooltipFrame and tooltipFrame:IsShown() then
                SysPerf:UpdateData()
            else
                SysPerf:UpdateLabel()
            end
        end
    end)
end

function SysPerf:GetDB()
    return ns.db and ns.db.systemperformance or DEFAULTS
end

---------------------------------------------------------------------------
-- Data collection
---------------------------------------------------------------------------

-- Lightweight update: only fps/latency for the LDB label (runs every 1s)
function SysPerf:UpdateLabel()
    fps = GetFramerate()
    latencyHome, latencyWorld = select(3, GetNetStats())
    local db = self:GetDB()
    dataobj.text = ExpandLabel(db.labelTemplate)
end

-- Heavy update: memory + CPU scan (only when tooltip is visible or manually triggered)
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
    local f = ns.CreateTooltipFrame("DDTSystemPerfTooltip", SysPerf)
    f.content.lines = {}
    return f
end

local function GetLine(c, index)
    if c.lines[index] then
        c.lines[index].label:Show()
        c.lines[index].value:Show()
        return c.lines[index]
    end

    local label = c:CreateFontString(nil, "OVERLAY", "DDTFontNormal")
    label:SetJustifyH("LEFT")

    local value = c:CreateFontString(nil, "OVERLAY", "DDTFontNormal")
    value:SetJustifyH("RIGHT")

    c.lines[index] = { label = label, value = value }
    return c.lines[index]
end

local function HideLines(c)
    for _, line in pairs(c.lines) do
        line.label:Hide()
        line.value:Hide()
    end
end

function SysPerf:BuildTooltipContent()
    local f = tooltipFrame
    local c = f.content
    HideLines(c)

    local db = self:GetDB()

    f.header:SetText("System Performance")

    local y = 0
    local lineIdx = 0

    -- FPS
    lineIdx = lineIdx + 1
    local fpsLine = GetLine(c, lineIdx)
    fpsLine.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
    fpsLine.label:SetText("|cffffffffFramerate|r")
    fpsLine.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
    fpsLine.value:SetText(string.format("%.0f fps", fps))
    fpsLine.value:SetTextColor(FPSColor(fps))
    y = y - ROW_HEIGHT

    -- Home latency
    lineIdx = lineIdx + 1
    local homeLine = GetLine(c, lineIdx)
    homeLine.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
    homeLine.label:SetText("|cffffffffHome Latency|r")
    homeLine.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
    homeLine.value:SetText(latencyHome .. " ms")
    homeLine.value:SetTextColor(LatencyColor(latencyHome))
    y = y - ROW_HEIGHT

    -- World latency
    lineIdx = lineIdx + 1
    local worldLine = GetLine(c, lineIdx)
    worldLine.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
    worldLine.label:SetText("|cffffffffWorld Latency|r")
    worldLine.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
    worldLine.value:SetText(latencyWorld .. " ms")
    worldLine.value:SetTextColor(LatencyColor(latencyWorld))
    y = y - ROW_HEIGHT

    -- Separator
    y = y - 4

    -- Total memory
    lineIdx = lineIdx + 1
    local memLine = GetLine(c, lineIdx)
    memLine.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
    memLine.label:SetText("|cffffffffTotal Addon Memory|r")
    memLine.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
    memLine.value:SetText(FormatMemory(memoryTotal))
    memLine.value:SetTextColor(0.4, 0.78, 1)
    y = y - ROW_HEIGHT

    -- Top addons (memory)
    if db.showTopAddons and #addonMemory > 0 then
        SortAddonMemory(addonMemory, db.addonSortOrder)
        y = y - 4

        lineIdx = lineIdx + 1
        local hdr = GetLine(c, lineIdx)
        hdr.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
        hdr.label:SetText("|cffffd100Top Addons (Memory)|r")
        hdr.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
        hdr.value:SetText("")
        y = y - HEADER_HEIGHT

        local count = math.min(db.numTopAddons or NUM_TOP_ADDONS, #addonMemory)
        for i = 1, count do
            local addon = addonMemory[i]
            lineIdx = lineIdx + 1
            local row = GetLine(c, lineIdx)
            row.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING + 6, y)
            row.label:SetText(addon.name)
            row.label:SetTextColor(0.8, 0.8, 0.8)
            row.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
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
            local cpuHdr = GetLine(c, lineIdx)
            cpuHdr.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
            cpuHdr.label:SetText("|cffffd100CPU Profiling|r")
            cpuHdr.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
            cpuHdr.value:SetText("|cffff3333Not Available|r")
            y = y - ROW_HEIGHT

            lineIdx = lineIdx + 1
            local note = GetLine(c, lineIdx)
            note.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING + 6, y)
            note.label:SetText("|cff888888C_AddOnProfiler not enabled in this session.|r")
            note.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
            note.value:SetText("")
            y = y - ROW_HEIGHT
        else
            -- Overall CPU summary row
            lineIdx = lineIdx + 1
            local cpuHdr = GetLine(c, lineIdx)
            cpuHdr.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
            cpuHdr.label:SetText("|cffffd100CPU Usage (All Addons)|r")
            cpuHdr.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
            cpuHdr.value:SetText("")
            y = y - HEADER_HEIGHT

            -- Overall metrics: Current | Average | Encounter | Peak
            lineIdx = lineIdx + 1
            local curLine = GetLine(c, lineIdx)
            curLine.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING + 6, y)
            curLine.label:SetText("|cffffffffCurrent|r")
            curLine.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
            curLine.value:SetText(FormatCPU(overallCPU.current))
            curLine.value:SetTextColor(CPUColor(overallCPU.current))
            y = y - ROW_HEIGHT

            lineIdx = lineIdx + 1
            local avgLine = GetLine(c, lineIdx)
            avgLine.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING + 6, y)
            avgLine.label:SetText("|cffffffffAverage|r")
            avgLine.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
            avgLine.value:SetText(FormatCPU(overallCPU.average))
            avgLine.value:SetTextColor(CPUColor(overallCPU.average))
            y = y - ROW_HEIGHT

            lineIdx = lineIdx + 1
            local encLine = GetLine(c, lineIdx)
            encLine.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING + 6, y)
            encLine.label:SetText("|cffffffffEncounter|r")
            encLine.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
            local encText = overallCPU.encounter > 0 and FormatCPU(overallCPU.encounter) or "—"
            encLine.value:SetText(encText)
            if overallCPU.encounter > 0 then
                encLine.value:SetTextColor(CPUColor(overallCPU.encounter))
            else
                encLine.value:SetTextColor(0.5, 0.5, 0.5)
            end
            y = y - ROW_HEIGHT

            lineIdx = lineIdx + 1
            local pkLine = GetLine(c, lineIdx)
            pkLine.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING + 6, y)
            pkLine.label:SetText("|cffffffffPeak|r")
            pkLine.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
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
                local listHdr = GetLine(c, lineIdx)
                listHdr.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
                listHdr.label:SetText("|cffffd100Top Addons (CPU)|r")
                listHdr.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
                listHdr.value:SetText("|cff888888" .. metricLabel .. "|r")
                y = y - HEADER_HEIGHT

                local cpuCount = math.min(db.numTopCpuAddons or 10, #addonCPU)
                for i = 1, cpuCount do
                    local addon = addonCPU[i]
                    local val = addon[sortMetric] or 0
                    if val <= 0 then break end

                    lineIdx = lineIdx + 1
                    local row = GetLine(c, lineIdx)
                    row.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING + 6, y)
                    row.label:SetText(addon.name)
                    row.label:SetTextColor(0.8, 0.8, 0.8)
                    row.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
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
    f:FinalizeLayout(ttWidth, math.abs(y))
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
    local r = panel.refreshCallbacks
    local db = function() return ns.db.systemperformance end

    local body = W.AddSection(panel, "Label Template")
    local y = 0
    y = W.AddLabelEditBox(body, y, "fps latency world memory cpu",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateData() end, r, {
        { "Default",   "<fps> fps  <latency>ms" },
        { "Detailed",  "<fps> fps  H:<latency>  W:<world>ms" },
        { "Compact",   "<fps>/<latency>" },
        { "Full",      "<fps> fps  <latency>ms  <memory>" },
        { "CPU Focus", "<fps> fps  CPU: <cpu>" },
    })
    W.EndSection(panel, y)

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
        { label = "Max Height", min = 100, max = 1000, step = 10,
          get = function() return db().tooltipMaxHeight end,
          set = function(v) db().tooltipMaxHeight = v end },
        nil, r)
    y = W.AddNote(body, y, "Suggested: 350 x 400 for FPS, latency, and addon memory list.")
    W.EndSection(panel, y)

    body = W.AddSection(panel, "Addon Memory")
    y = 0
    y = W.AddCheckbox(body, y, "Show top addon memory usage",
        function() return db().showTopAddons end,
        function(v) db().showTopAddons = v end, r)
    y = W.AddSlider(body, y, "Number of addons to show", 5, 25, 1,
        function() return db().numTopAddons end,
        function(v) db().numTopAddons = v end, r)
    y = W.AddDropdown(body, y, "Sort Order", ADDON_SORT_VALUES,
        function() return db().addonSortOrder end,
        function(v) db().addonSortOrder = v end, r)
    W.EndSection(panel, y)

    body = W.AddSection(panel, "CPU Profiling")
    y = 0
    y = W.AddCheckbox(body, y, "Show CPU usage per addon",
        function() return db().showCpuUsage end,
        function(v) db().showCpuUsage = v end, r)
    y = W.AddDropdown(body, y, "Sort By", CPU_SORT_VALUES,
        function() return db().cpuSortMetric end,
        function(v) db().cpuSortMetric = v end, r)
    y = W.AddSlider(body, y, "Number of CPU addons to show", 5, 25, 1,
        function() return db().numTopCpuAddons end,
        function(v) db().numTopCpuAddons = v end, r)
    y = W.AddDescription(body, y,
        "Uses the C_AddOnProfiler API to display per-addon CPU\n" ..
        "usage as a percentage of total frame time.\n" ..
        "Shows Current, Average, Encounter, and Peak metrics\n" ..
        "similar to Simple Addon Manager's profiler view.")
    W.EndSection(panel, y)

    ns.AddModuleClickActionsSection(panel, r, "systemperformance", CLICK_ACTIONS)
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("systemperformance", SysPerf, DEFAULTS)
