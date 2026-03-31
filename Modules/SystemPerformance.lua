-- Djinni's Data Texts — System Performance
-- FPS, latency (home/world), memory usage, and top addon memory consumers.
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

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
    labelTemplate    = "<fps> fps  <latency>ms",
    showTopAddons    = true,
    numTopAddons     = 10,
    tooltipScale     = 1.0,
    tooltipWidth     = 320,
}

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

---------------------------------------------------------------------------
-- Label template expansion
---------------------------------------------------------------------------

local function ExpandLabel(template)
    local result = template
    result = result:gsub("<fps>", string.format("%.0f", fps))
    result = result:gsub("<latency>", tostring(latencyHome))
    result = result:gsub("<world>", tostring(latencyWorld))
    result = result:gsub("<memory>", FormatMemory(memoryTotal))
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
        if button == "LeftButton" then
            -- Garbage collect
            collectgarbage("collect")
            SysPerf:UpdateData()
        elseif button == "RightButton" then
            UpdateAddOnMemoryUsage()
            SysPerf:UpdateData()
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

    table.sort(addonMemory, function(a, b) return a.memory > b.memory end)

    -- Update LDB text
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

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, -PADDING)
    f.title:SetTextColor(1, 0.82, 0)

    f.titleSep = f:CreateTexture(nil, "ARTWORK")
    f.titleSep:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
    f.titleSep:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)
    f.titleSep:SetHeight(1)
    f.titleSep:SetColorTexture(0.5, 0.5, 0.5, 0.5)

    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
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

    local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetJustifyH("LEFT")

    local value = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
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

    -- Top addons
    if db.showTopAddons and #addonMemory > 0 then
        y = y - 4

        lineIdx = lineIdx + 1
        local hdr = GetLine(f, lineIdx)
        hdr.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        hdr.label:SetText("|cffffd100Top Addons|r")
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

    -- Hint
    f.hint:SetText("|cff888888LClick: Collect Garbage  |  RClick: Refresh Memory|r")

    local db = self:GetDB()
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
    y = W.AddDescription(c, y, "Tags: <fps> <latency> <world> <memory>")
    y = W.AddEditBox(c, y, "Template",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateData() end, r)

    y = W.AddHeader(c, y, "Tooltip")
    y = W.AddSlider(c, y, "Scale", 0.5, 2.0, 0.05,
        function() return db().tooltipScale end,
        function(v) db().tooltipScale = v end, r)
    y = W.AddSlider(c, y, "Width", 250, 600, 10,
        function() return db().tooltipWidth end,
        function(v) db().tooltipWidth = v end, r)
    y = W.AddCheckbox(c, y, "Show top addon memory usage",
        function() return db().showTopAddons end,
        function(v) db().showTopAddons = v end, r)
    y = W.AddSlider(c, y, "Number of addons to show", 5, 25, 1,
        function() return db().numTopAddons end,
        function(v) db().numTopAddons = v end, r)

    y = W.AddHeader(c, y, "Interactions")
    y = W.AddDescription(c, y,
        "Left-click: Garbage collect (free memory)\n" ..
        "Right-click: Refresh addon memory stats")

    c:SetHeight(math.abs(y) + 20)
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("systemperformance", SysPerf, DEFAULTS)
