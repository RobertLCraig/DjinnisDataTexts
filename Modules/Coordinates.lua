-- Djinni's Data Texts — Coordinates
-- Shows player map coordinates and zone information.
local addonName, ns = ...
local DDT = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local Coordinates = {}
ns.Coordinates = Coordinates

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
local playerX, playerY = 0, 0
local currentZone    = ""
local currentSubZone = ""
local currentMapName = ""
local currentMapID   = nil

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
    coordDecimals = 2,
    showZoneInLDB = false,  -- show zone name alongside coords on LDB text
}

---------------------------------------------------------------------------
-- Coordinate helpers
---------------------------------------------------------------------------

local function FormatCoords(x, y, decimals)
    if not x or not y then return "—, —" end
    local fmt = "%." .. (decimals or 2) .. "f"
    return string.format(fmt .. ", " .. fmt, x * 100, y * 100)
end

local function UpdatePosition()
    local mapID = C_Map.GetBestMapForUnit("player")
    currentMapID = mapID

    if mapID then
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        if pos then
            playerX, playerY = pos:GetXY()
        else
            playerX, playerY = 0, 0
        end

        local mapInfo = C_Map.GetMapInfo(mapID)
        currentMapName = mapInfo and mapInfo.name or ""
    else
        playerX, playerY = 0, 0
        currentMapName = ""
    end

    currentZone    = GetZoneText() or ""
    currentSubZone = GetSubZoneText() or ""
end

---------------------------------------------------------------------------
-- LDB Data Object
---------------------------------------------------------------------------

local dataobj = LDB:NewDataObject("DDT-Coordinates", {
    type  = "data source",
    text  = "0, 0",
    icon  = "Interface\\Icons\\INV_Misc_Map_01",
    label = "DDT - Coordinates",
    OnEnter = function(self)
        Coordinates:ShowTooltip(self)
    end,
    OnLeave = function(self)
        Coordinates:StartHideTimer()
    end,
    OnClick = function(self, button)
        if button == "LeftButton" then
            ToggleWorldMap()
        elseif button == "RightButton" then
            -- Copy coords to chat
            local db = Coordinates:GetDB()
            local coordStr = FormatCoords(playerX, playerY, db.coordDecimals)
            local msg = currentZone
            if currentSubZone ~= "" and currentSubZone ~= currentZone then
                msg = msg .. " - " .. currentSubZone
            end
            msg = msg .. " (" .. coordStr .. ")"
            ChatFrameUtil.OpenChat(msg)
        end
    end,
})

Coordinates.dataobj = dataobj

---------------------------------------------------------------------------
-- Event handling and update
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local elapsed = 0
local UPDATE_INTERVAL = 0.1

function Coordinates:Init()
    eventFrame:RegisterEvent("ZONE_CHANGED")
    eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("LOADING_SCREEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

    eventFrame:SetScript("OnEvent", function()
        Coordinates:UpdateDisplay()
    end)

    -- Coordinates need frequent OnUpdate for smooth display
    eventFrame:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= UPDATE_INTERVAL then
            elapsed = 0
            Coordinates:UpdateDisplay()
        end
    end)
end

function Coordinates:GetDB()
    return ns.db and ns.db.coordinates or DEFAULTS
end

function Coordinates:UpdateDisplay()
    UpdatePosition()

    local db = self:GetDB()
    local coordStr = FormatCoords(playerX, playerY, db.coordDecimals)

    if db.showZoneInLDB and currentZone ~= "" then
        dataobj.text = currentZone .. "  " .. coordStr
    else
        dataobj.text = coordStr
    end

    -- Refresh tooltip if visible
    if tooltipFrame and tooltipFrame:IsShown() then
        self:BuildTooltipContent()
    end
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------

local function CreateTooltipFrame()
    local f = CreateFrame("Frame", "DDTCoordinatesTooltip", UIParent, "BackdropTemplate")
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
    f:SetScript("OnEnter", function() Coordinates:CancelHideTimer() end)
    f:SetScript("OnLeave", function() Coordinates:StartHideTimer() end)

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

function Coordinates:BuildTooltipContent()
    local f = tooltipFrame
    HideLines(f)

    local db = self:GetDB()

    f.title:SetText("Coordinates")

    local y = -PADDING - 20 - 6
    local lineIdx = 0

    -- Zone
    if currentZone ~= "" then
        lineIdx = lineIdx + 1
        local zoneLine = GetLine(f, lineIdx)
        zoneLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        zoneLine.label:SetText("|cffffffffZone|r")
        zoneLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        zoneLine.value:SetText(currentZone)
        zoneLine.value:SetTextColor(0.4, 0.78, 1)
        y = y - ROW_HEIGHT
    end

    -- Subzone (if different from zone)
    if currentSubZone ~= "" and currentSubZone ~= currentZone then
        lineIdx = lineIdx + 1
        local subLine = GetLine(f, lineIdx)
        subLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        subLine.label:SetText("|cffffffffSubzone|r")
        subLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        subLine.value:SetText(currentSubZone)
        subLine.value:SetTextColor(0.4, 0.78, 1)
        y = y - ROW_HEIGHT
    end

    -- Map name (if different from zone)
    if currentMapName ~= "" and currentMapName ~= currentZone then
        lineIdx = lineIdx + 1
        local mapLine = GetLine(f, lineIdx)
        mapLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        mapLine.label:SetText("|cffffffffMap|r")
        mapLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        mapLine.value:SetText(currentMapName)
        mapLine.value:SetTextColor(0.9, 0.9, 0.9)
        y = y - ROW_HEIGHT
    end

    -- Separator
    y = y - 4

    -- Coordinates
    lineIdx = lineIdx + 1
    local coordLine = GetLine(f, lineIdx)
    coordLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    coordLine.label:SetText("|cffffffffCoordinates|r")
    coordLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    coordLine.value:SetText(FormatCoords(playerX, playerY, db.coordDecimals))
    coordLine.value:SetTextColor(0.0, 1.0, 0.0)
    y = y - ROW_HEIGHT

    -- Map ID (small reference)
    if currentMapID then
        lineIdx = lineIdx + 1
        local idLine = GetLine(f, lineIdx)
        idLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        idLine.label:SetText("|cffffffffMap ID|r")
        idLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        idLine.value:SetText(tostring(currentMapID))
        idLine.value:SetTextColor(0.6, 0.6, 0.6)
        y = y - ROW_HEIGHT
    end

    -- Hint
    f.hint:SetText("|cff888888LClick: World Map  |  RClick: Copy to Chat|r")

    local totalHeight = math.abs(y) + PADDING + HINT_HEIGHT + 8
    f:SetSize(TOOLTIP_WIDTH, totalHeight)
end

function Coordinates:ShowTooltip(anchor)
    self:CancelHideTimer()

    if not tooltipFrame then
        tooltipFrame = CreateTooltipFrame()
    end

    tooltipFrame:ClearAllPoints()
    tooltipFrame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)

    self:BuildTooltipContent()
    tooltipFrame:Show()
end

function Coordinates:StartHideTimer()
    self:CancelHideTimer()
    hideTimer = C_Timer.NewTimer(ns.HIDE_DELAY, function()
        if tooltipFrame then tooltipFrame:Hide() end
        hideTimer = nil
    end)
end

function Coordinates:CancelHideTimer()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
end

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------

Coordinates.settingsLabel = "Coordinates"

function Coordinates:BuildSettingsPanel(panel)
    local W = ns.SettingsWidgets
    local c = panel.content
    local r = panel.refreshCallbacks
    local y = -10
    local db = function() return ns.db.coordinates end

    y = W.AddHeader(c, y, "Display")
    y = W.AddSlider(c, y, "Decimal places", 0, 4, 1,
        function() return db().coordDecimals end,
        function(v) db().coordDecimals = v; self:UpdateDisplay() end, r)
    y = W.AddCheckbox(c, y, "Show zone name on DataText",
        function() return db().showZoneInLDB end,
        function(v) db().showZoneInLDB = v; self:UpdateDisplay() end, r)

    y = W.AddHeader(c, y, "Interactions")
    y = W.AddDescription(c, y,
        "Left-click: Open World Map\n" ..
        "Right-click: Copy coordinates and zone name to chat")

    c:SetHeight(math.abs(y) + 20)
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("coordinates", Coordinates, DEFAULTS)
