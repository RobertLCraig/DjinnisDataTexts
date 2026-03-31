-- Djinni's Data Texts — Character Info
-- Character name, realm, class, race, level, item level, shard ID (best-effort).
local addonName, ns = ...
local DDT = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local CharInfo = {}
ns.CharInfo = CharInfo

-- Tooltip
local tooltipFrame = nil
local hideTimer = nil

-- Layout
local TOOLTIP_WIDTH  = 300
local ROW_HEIGHT     = 20
local HEADER_HEIGHT  = 18
local PADDING        = 10
local HINT_HEIGHT    = 18

-- State
local charName = ""
local charRealm = ""
local charFullName = ""
local charClass = ""
local charClassFile = ""
local charRace = ""
local charLevel = 0
local charIlvl = 0
local charGuild = ""
local charFaction = ""

-- Shard detection (best-effort via NPC GUID parsing)
local shardID = nil
local shardCache = 0  -- GetTime() of last shard update

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
    labelTemplate   = "<name> - <realm>",
    showShardID     = false,
    showGuild       = true,
    showItemLevel   = true,
    tooltipScale    = 1.0,
    tooltipWidth    = 300,
    clickActions    = {
        leftClick  = "character",
        rightClick = "copyname",
    },
}

local CLICK_ACTIONS = {
    character    = "Character Panel",
    copyname     = "Copy Name to Chat",
    opensettings = "Open DDT Settings",
    none         = "None",
}

---------------------------------------------------------------------------
-- Shard ID detection (best-effort)
---------------------------------------------------------------------------

local function ParseShardFromGUID(guid)
    if not guid then return nil end
    -- Creature GUIDs: Creature-0-XXXX-YYYY-ZZZZ-NNNNNNNNN-SSSSSSSSS
    -- The 5th field (ZZZZ) is zone_uid which varies by shard
    local guidType = strsplit("-", guid)
    if guidType ~= "Creature" and guidType ~= "Vehicle" then return nil end
    local _, _, serverID, instanceID, zoneUID = strsplit("-", guid)
    if zoneUID then
        return zoneUID
    end
    return nil
end

local function TryUpdateShard()
    local now = GetTime()
    if now - shardCache < 5 then return end -- 5s cache

    for _, unit in ipairs({"target", "mouseover", "nameplate1", "nameplate2"}) do
        local ok, guid = pcall(UnitGUID, unit)
        if ok and guid then
            local id = ParseShardFromGUID(guid)
            if id then
                shardID = id
                shardCache = now
                return
            end
        end
    end
end

---------------------------------------------------------------------------
-- Label template expansion
---------------------------------------------------------------------------

local function ExpandLabel(template)
    local result = template
    result = result:gsub("<name>", charName)
    result = result:gsub("<realm>", charRealm)
    result = result:gsub("<class>", charClass)
    result = result:gsub("<level>", tostring(charLevel))
    result = result:gsub("<ilvl>", string.format("%.1f", charIlvl))
    result = result:gsub("<race>", charRace)
    result = result:gsub("<shard>", shardID or "?")
    return result
end

---------------------------------------------------------------------------
-- LDB Data Object
---------------------------------------------------------------------------

local dataobj = LDB:NewDataObject("DDT-CharacterInfo", {
    type  = "data source",
    text  = "Character",
    icon  = "Interface\\Icons\\Achievement_Character_Human_Female",
    label = "DDT - Character",
    OnEnter = function(self)
        CharInfo:ShowTooltip(self)
    end,
    OnLeave = function(self)
        CharInfo:StartHideTimer()
    end,
    OnClick = function(self, button)
        local db = CharInfo:GetDB()
        local action = DDT:ResolveClickAction(button, db.clickActions or {})
        if action == "character" then
            ToggleCharacter("PaperDollFrame")
        elseif action == "copyname" then
            if charFullName ~= "" then
                ChatFrameUtil.OpenChat(charFullName)
            end
        elseif action == "opensettings" then
            if DDT.settingsCategoryID then
                Settings.OpenToCategory(DDT.settingsCategoryID)
            end
        end
    end,
})

CharInfo.dataobj = dataobj

---------------------------------------------------------------------------
-- Event handling
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

function CharInfo:Init()
    eventFrame:SetScript("OnEvent", function(_, event)
        CharInfo:UpdateData()
    end)

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
    eventFrame:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
    eventFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
    eventFrame:RegisterEvent("UNIT_TARGET")
    eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
end

function CharInfo:GetDB()
    return ns.db and ns.db.characterinfo or DEFAULTS
end

---------------------------------------------------------------------------
-- Data collection
---------------------------------------------------------------------------

function CharInfo:UpdateData()
    charName = UnitName("player") or "Unknown"
    charRealm = GetRealmName() or "Unknown"
    charFullName = charName .. "-" .. charRealm
    charClass, charClassFile = UnitClass("player")
    charRace = UnitRace("player") or ""
    charLevel = UnitLevel("player") or 0
    charFaction = UnitFactionGroup("player") or ""

    local _, equipped = GetAverageItemLevel()
    charIlvl = equipped or 0

    local guild = GetGuildInfo("player")
    charGuild = guild or ""

    -- Best-effort shard detection
    local db = self:GetDB()
    if db.showShardID then
        TryUpdateShard()
    end

    -- Update LDB text
    dataobj.text = ExpandLabel(db.labelTemplate)

    -- Update icon to class icon
    local coords = CLASS_ICON_TCOORDS[charClassFile]
    if coords then
        dataobj.icon = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
        dataobj.iconCoords = { coords[1], coords[2], coords[3], coords[4] }
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
    local f = CreateFrame("Frame", "DDTCharInfoTooltip", UIParent, "BackdropTemplate")
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
    f:SetScript("OnEnter", function() CharInfo:CancelHideTimer() end)
    f:SetScript("OnLeave", function() CharInfo:StartHideTimer() end)

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

function CharInfo:BuildTooltipContent()
    local f = tooltipFrame
    HideLines(f)

    local db = self:GetDB()

    -- Title: class-colored character name
    local r, g, b = DDT:GetClassColor(charClassFile)
    f.title:SetText(DDT:ColorText(charName, r, g, b))

    local y = -PADDING - 20 - 6
    local lineIdx = 0

    -- Realm
    lineIdx = lineIdx + 1
    local realmLine = GetLine(f, lineIdx)
    realmLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    realmLine.label:SetText("|cffffffffRealm|r")
    realmLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    realmLine.value:SetText(charRealm)
    realmLine.value:SetTextColor(0.9, 0.9, 0.9)
    y = y - ROW_HEIGHT

    -- Class
    lineIdx = lineIdx + 1
    local classLine = GetLine(f, lineIdx)
    classLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    classLine.label:SetText("|cffffffffClass|r")
    classLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    classLine.value:SetText(DDT:ColorText(charClass, r, g, b))
    classLine.value:SetTextColor(1, 1, 1)
    y = y - ROW_HEIGHT

    -- Race
    lineIdx = lineIdx + 1
    local raceLine = GetLine(f, lineIdx)
    raceLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    raceLine.label:SetText("|cffffffffRace|r")
    raceLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    raceLine.value:SetText(charRace)
    raceLine.value:SetTextColor(0.9, 0.9, 0.9)
    y = y - ROW_HEIGHT

    -- Level
    lineIdx = lineIdx + 1
    local lvlLine = GetLine(f, lineIdx)
    lvlLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    lvlLine.label:SetText("|cffffffffLevel|r")
    lvlLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    lvlLine.value:SetText(tostring(charLevel))
    lvlLine.value:SetTextColor(1, 0.82, 0)
    y = y - ROW_HEIGHT

    -- Item Level
    if db.showItemLevel then
        lineIdx = lineIdx + 1
        local ilvlLine = GetLine(f, lineIdx)
        ilvlLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        ilvlLine.label:SetText("|cffffffffItem Level|r")
        ilvlLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        ilvlLine.value:SetText(string.format("%.1f", charIlvl))
        local ilvlColor
        if charIlvl >= 600 then ilvlColor = {1, 0.5, 0}
        elseif charIlvl >= 500 then ilvlColor = {0.64, 0.21, 0.93}
        elseif charIlvl >= 400 then ilvlColor = {0, 0.44, 0.87}
        else ilvlColor = {0, 1, 0} end
        ilvlLine.value:SetTextColor(unpack(ilvlColor))
        y = y - ROW_HEIGHT
    end

    -- Faction
    lineIdx = lineIdx + 1
    local facLine = GetLine(f, lineIdx)
    facLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    facLine.label:SetText("|cffffffffFaction|r")
    facLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    facLine.value:SetText(charFaction)
    if charFaction == "Alliance" then
        facLine.value:SetTextColor(0.2, 0.4, 1.0)
    elseif charFaction == "Horde" then
        facLine.value:SetTextColor(1.0, 0.2, 0.2)
    else
        facLine.value:SetTextColor(0.9, 0.9, 0.9)
    end
    y = y - ROW_HEIGHT

    -- Guild
    if db.showGuild and charGuild ~= "" then
        lineIdx = lineIdx + 1
        local guildLine = GetLine(f, lineIdx)
        guildLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        guildLine.label:SetText("|cffffffffGuild|r")
        guildLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        guildLine.value:SetText(charGuild)
        guildLine.value:SetTextColor(0.0, 0.8, 0.0)
        y = y - ROW_HEIGHT
    end

    -- Shard ID (best-effort)
    if db.showShardID then
        TryUpdateShard()
        lineIdx = lineIdx + 1
        local shardLine = GetLine(f, lineIdx)
        shardLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        shardLine.label:SetText("|cffffffffShard ID|r")
        shardLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        if shardID then
            shardLine.value:SetText(shardID)
            shardLine.value:SetTextColor(0.4, 0.78, 1)
        else
            shardLine.value:SetText("Unknown (target an NPC)")
            shardLine.value:SetTextColor(0.5, 0.5, 0.5)
        end
        y = y - ROW_HEIGHT
    end

    -- Hint
    f.hint:SetText(DDT:BuildHintText(db.clickActions or {}, CLICK_ACTIONS))

    local ttWidth = db.tooltipWidth or TOOLTIP_WIDTH
    local totalHeight = math.abs(y) + PADDING + HINT_HEIGHT + 8
    f:SetSize(ttWidth, totalHeight)
end

function CharInfo:ShowTooltip(anchor)
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

function CharInfo:StartHideTimer()
    self:CancelHideTimer()
    hideTimer = C_Timer.NewTimer(ns.HIDE_DELAY, function()
        if tooltipFrame then tooltipFrame:Hide() end
        hideTimer = nil
    end)
end

function CharInfo:CancelHideTimer()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
end

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------

CharInfo.settingsLabel = "Character Info"

function CharInfo:BuildSettingsPanel(panel)
    local W = ns.SettingsWidgets
    local c = panel.content
    local r = panel.refreshCallbacks
    local y = -10
    local db = function() return ns.db.characterinfo end

    y = W.AddHeader(c, y, "Label Template")
    y = W.AddLabelEditBox(c, y, "name realm class level ilvl race shard",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateData() end, r)

    y = W.AddHeader(c, y, "Display")
    y = W.AddCheckbox(c, y, "Show item level",
        function() return db().showItemLevel end,
        function(v) db().showItemLevel = v end, r)
    y = W.AddCheckbox(c, y, "Show guild name",
        function() return db().showGuild end,
        function(v) db().showGuild = v end, r)
    y = W.AddCheckbox(c, y, "Show shard ID (best-effort)",
        function() return db().showShardID end,
        function(v) db().showShardID = v end, r)
    y = W.AddDescription(c, y,
        "Shard ID Detection (Limitations):\n" ..
        "Blizzard does not expose shard/server IDs to addons.\n" ..
        "DDT extracts an approximate shard identifier by parsing\n" ..
        "NPC GUIDs when you target or mouseover a creature.\n\n" ..
        "Caveats:\n" ..
        "  \226\128\162 Only updates when you target/mouseover an NPC\n" ..
        "  \226\128\162 Shows 'Unknown' in empty areas with no NPCs\n" ..
        "  \226\128\162 May be inaccurate during shard transitions\n" ..
        "  \226\128\162 Blizzard may change GUID format at any time")

    y = W.AddHeader(c, y, "Tooltip")
    y = W.AddSlider(c, y, "Scale", 0.5, 2.0, 0.05,
        function() return db().tooltipScale end,
        function(v) db().tooltipScale = v end, r)
    y = W.AddSlider(c, y, "Width", 200, 500, 10,
        function() return db().tooltipWidth end,
        function(v) db().tooltipWidth = v end, r)

    y = ns.AddModuleClickActionsSection(c, r, y, "characterinfo", CLICK_ACTIONS)

    c:SetHeight(math.abs(y) + 20)
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("characterinfo", CharInfo, DEFAULTS)
