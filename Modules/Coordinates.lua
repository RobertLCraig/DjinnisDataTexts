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
    coordDecimals  = 2,
    labelTemplate  = "<coords>",
    tooltipScale   = 1.0,
    tooltipWidth   = 280,
    clickActions   = {
        leftClick       = "worldmap",
        rightClick      = "copycoords",
        middleClick     = "none",
        shiftLeftClick  = "sharecoords",
        shiftRightClick = "waypoint",
        ctrlLeftClick   = "zonemap",
        ctrlRightClick  = "none",
        altLeftClick    = "opensettings",
        altRightClick   = "none",
    },
}

local CLICK_ACTIONS = {
    worldmap     = "World Map",
    zonemap      = "Zone Map",
    copycoords   = "Copy Coords to Chat",
    sharecoords  = "Share Coords in Group",
    pastecoords  = "Paste Coords (TomTom)",
    waypoint     = "Set/Clear Map Pin",
    opensettings = "Open DDT Settings",
    none         = "None",
}

---------------------------------------------------------------------------
-- Coordinate helpers
---------------------------------------------------------------------------

local function FormatCoords(x, y, decimals)
    if not x or not y then return "—, —" end
    local fmt = "%." .. (decimals or 2) .. "f"
    return string.format(fmt .. ", " .. fmt, x * 100, y * 100)
end

local prevX, prevY = -1, -1
local COORD_THRESHOLD = 0.0001  -- ~0.01% map movement

local function UpdatePosition()
    local mapID = C_Map.GetBestMapForUnit("player")
    currentMapID = mapID

    if mapID then
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        if pos then
            local newX, newY = pos:GetXY()
            -- Skip full update if position hasn't meaningfully changed
            if math.abs(newX - prevX) < COORD_THRESHOLD and math.abs(newY - prevY) < COORD_THRESHOLD then
                return false  -- no meaningful change
            end
            playerX, playerY = newX, newY
            prevX, prevY = newX, newY
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
    return true  -- data changed
end

---------------------------------------------------------------------------
-- Label template expansion
---------------------------------------------------------------------------

local function ExpandLabel(template, db)
    local result = template
    local E = ns.ExpandTag
    result = E(result, "coords", FormatCoords(playerX, playerY, db.coordDecimals))
    result = E(result, "zone", currentZone or "")
    result = E(result, "subzone", currentSubZone or "")
    result = E(result, "map", currentMapName or "")
    return result
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
        local db = Coordinates:GetDB()
        local action = DDT:ResolveClickAction(button, db.clickActions or {})
        if action == "worldmap" then
            ToggleWorldMap()
        elseif action == "zonemap" then
            -- Open the zone/flight map
            if ToggleBattlefieldMap then
                ToggleBattlefieldMap()
            elseif ToggleWorldMap then
                ToggleWorldMap()
            end
        elseif action == "copycoords" then
            local coordStr = FormatCoords(playerX, playerY, db.coordDecimals)
            local msg = currentZone
            if currentSubZone ~= "" and currentSubZone ~= currentZone then
                msg = msg .. " - " .. currentSubZone
            end
            msg = msg .. " (" .. coordStr .. ")"
            ChatFrameUtil.OpenChat(msg)
        elseif action == "sharecoords" then
            local coordStr = FormatCoords(playerX, playerY, db.coordDecimals)
            local msg = currentZone
            if currentSubZone ~= "" and currentSubZone ~= currentZone then
                msg = msg .. " - " .. currentSubZone
            end
            msg = msg .. " (" .. coordStr .. ")"
            local channel = IsInRaid() and "RAID" or IsInGroup() and "PARTY" or nil
            if channel then
                SendChatMessage(msg, channel)
            else
                ChatFrameUtil.OpenChat(msg)
            end
        elseif action == "pastecoords" then
            -- Build a /way command for TomTom or Blizzard waypoint
            local x = playerX and (playerX * 100) or 0
            local y = playerY and (playerY * 100) or 0
            local waypointStr = string.format("/way %.1f %.1f", x, y)
            ChatFrameUtil.OpenChat(waypointStr)
        elseif action == "waypoint" then
            if C_Map and C_Map.SetUserWaypoint and currentMapID and playerX and playerY then
                if C_Map.HasUserWaypoint and C_Map.HasUserWaypoint() then
                    C_Map.ClearUserWaypoint()
                    DDT:Print("Map pin cleared.")
                else
                    local point = UiMapPoint.CreateFromCoordinates(currentMapID, playerX, playerY)
                    C_Map.SetUserWaypoint(point)
                    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
                    DDT:Print("Map pin set at current location.")
                end
            end
        elseif action == "opensettings" then
            if DDT.settingsCategoryID then
                Settings.OpenToCategory(DDT.settingsCategoryID)
            end
        end
    end,
})

Coordinates.dataobj = dataobj

---------------------------------------------------------------------------
-- Event handling and update
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local elapsed = 0
local UPDATE_INTERVAL = 0.5

function Coordinates:Init()
    eventFrame:RegisterEvent("ZONE_CHANGED")
    eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("LOADING_SCREEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

    eventFrame:SetScript("OnEvent", function()
        Coordinates:UpdateDisplay()
    end)

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
    local changed = UpdatePosition()
    if not changed then return end

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
    f.hint:SetText(DDT:BuildHintText(db.clickActions or {}, CLICK_ACTIONS))

    local ttWidth = db.tooltipWidth or TOOLTIP_WIDTH
    local totalHeight = math.abs(y) + PADDING + HINT_HEIGHT + 8
    f:SetSize(ttWidth, totalHeight)
end

function Coordinates:ShowTooltip(anchor)
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

    y = W.AddHeader(c, y, "Label Template")
    y = W.AddLabelEditBox(c, y, "coords zone subzone map",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateDisplay() end, r, {
        { "Coords Only",  "<coords>" },
        { "Zone + Coords", "<zone> <coords>" },
        { "Full Location", "<zone> - <subzone> (<coords>)" },
        { "Map Name",      "<map>: <coords>" },
    })

    y = W.AddHeader(c, y, "Display")
    y = W.AddSlider(c, y, "Decimal places", 0, 4, 1,
        function() return db().coordDecimals end,
        function(v) db().coordDecimals = v; self:UpdateDisplay() end, r)

    y = W.AddHeader(c, y, "Tooltip")
    y = W.AddSlider(c, y, "Scale", 0.5, 2.0, 0.05,
        function() return db().tooltipScale end,
        function(v) db().tooltipScale = v end, r)
    y = W.AddSlider(c, y, "Width", 200, 500, 10,
        function() return db().tooltipWidth end,
        function(v) db().tooltipWidth = v end, r)

    y = ns.AddModuleClickActionsSection(c, r, y, "coordinates", CLICK_ACTIONS)

    c:SetHeight(math.abs(y) + 20)
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("coordinates", Coordinates, DEFAULTS)
