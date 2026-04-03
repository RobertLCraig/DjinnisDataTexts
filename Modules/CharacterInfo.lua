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
    tooltipScale     = 1.0,
    tooltipMaxHeight = 400,
    tooltipWidth     = 300,
    clickActions    = {
        leftClick       = "character",
        rightClick      = "copyname",
        middleClick     = "none",
        shiftLeftClick  = "achievements",
        shiftRightClick = "none",
        ctrlLeftClick   = "spellbook",
        ctrlRightClick  = "none",
        altLeftClick    = "opensettings",
        altRightClick   = "none",
    },
}

local CLICK_ACTIONS = {
    character    = "Character Panel",
    achievements = "Achievements",
    spellbook    = "Spellbook",
    collections  = "Collections",
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
    local E = ns.ExpandTag
    result = E(result, "name", charName)
    result = E(result, "realm", charRealm)
    result = E(result, "class", charClass)
    result = E(result, "level", charLevel)
    result = E(result, "ilvl", string.format("%.1f", charIlvl))
    result = E(result, "race", charRace)
    result = E(result, "shard", shardID or "?")
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
        elseif action == "achievements" then
            ToggleAchievementFrame()
        elseif action == "spellbook" then
            ToggleSpellBook(BOOKTYPE_SPELL)
        elseif action == "collections" then
            ToggleCollectionsJournal()
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
    local f = ns.CreateTooltipFrame("DDTCharInfoTooltip", CharInfo)
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

function CharInfo:BuildTooltipContent()
    local f = tooltipFrame
    local c = f.content
    HideLines(c)

    local db = self:GetDB()

    -- Title: class-colored character name
    local r, g, b = DDT:GetClassColor(charClassFile)
    f.header:SetText(DDT:ColorText(charName, r, g, b))

    local y = 0
    local lineIdx = 0

    -- Realm
    lineIdx = lineIdx + 1
    local realmLine = GetLine(c, lineIdx)
    realmLine.label:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y)
    realmLine.label:SetText("|cffffffffRealm|r")
    realmLine.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, y)
    realmLine.value:SetText(charRealm)
    realmLine.value:SetTextColor(0.9, 0.9, 0.9)
    y = y - ns.ROW_HEIGHT

    -- Class
    lineIdx = lineIdx + 1
    local classLine = GetLine(c, lineIdx)
    classLine.label:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y)
    classLine.label:SetText("|cffffffffClass|r")
    classLine.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, y)
    classLine.value:SetText(DDT:ColorText(charClass, r, g, b))
    classLine.value:SetTextColor(1, 1, 1)
    y = y - ns.ROW_HEIGHT

    -- Race
    lineIdx = lineIdx + 1
    local raceLine = GetLine(c, lineIdx)
    raceLine.label:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y)
    raceLine.label:SetText("|cffffffffRace|r")
    raceLine.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, y)
    raceLine.value:SetText(charRace)
    raceLine.value:SetTextColor(0.9, 0.9, 0.9)
    y = y - ns.ROW_HEIGHT

    -- Level
    lineIdx = lineIdx + 1
    local lvlLine = GetLine(c, lineIdx)
    lvlLine.label:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y)
    lvlLine.label:SetText("|cffffffffLevel|r")
    lvlLine.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, y)
    lvlLine.value:SetText(tostring(charLevel))
    lvlLine.value:SetTextColor(1, 0.82, 0)
    y = y - ns.ROW_HEIGHT

    -- Item Level
    if db.showItemLevel then
        lineIdx = lineIdx + 1
        local ilvlLine = GetLine(c, lineIdx)
        ilvlLine.label:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y)
        ilvlLine.label:SetText("|cffffffffItem Level|r")
        ilvlLine.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, y)
        ilvlLine.value:SetText(string.format("%.1f", charIlvl))
        local ilvlColor
        if charIlvl >= 600 then ilvlColor = {1, 0.5, 0}
        elseif charIlvl >= 500 then ilvlColor = {0.64, 0.21, 0.93}
        elseif charIlvl >= 400 then ilvlColor = {0, 0.44, 0.87}
        else ilvlColor = {0, 1, 0} end
        ilvlLine.value:SetTextColor(unpack(ilvlColor))
        y = y - ns.ROW_HEIGHT
    end

    -- Faction
    lineIdx = lineIdx + 1
    local facLine = GetLine(c, lineIdx)
    facLine.label:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y)
    facLine.label:SetText("|cffffffffFaction|r")
    facLine.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, y)
    facLine.value:SetText(charFaction)
    if charFaction == "Alliance" then
        facLine.value:SetTextColor(0.2, 0.4, 1.0)
    elseif charFaction == "Horde" then
        facLine.value:SetTextColor(1.0, 0.2, 0.2)
    else
        facLine.value:SetTextColor(0.9, 0.9, 0.9)
    end
    y = y - ns.ROW_HEIGHT

    -- Guild
    if db.showGuild and charGuild ~= "" then
        lineIdx = lineIdx + 1
        local guildLine = GetLine(c, lineIdx)
        guildLine.label:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y)
        guildLine.label:SetText("|cffffffffGuild|r")
        guildLine.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, y)
        guildLine.value:SetText(charGuild)
        guildLine.value:SetTextColor(0.0, 0.8, 0.0)
        y = y - ns.ROW_HEIGHT
    end

    -- Shard ID (best-effort)
    if db.showShardID then
        TryUpdateShard()
        lineIdx = lineIdx + 1
        local shardLine = GetLine(c, lineIdx)
        shardLine.label:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y)
        shardLine.label:SetText("|cffffffffShard ID|r")
        shardLine.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, y)
        if shardID then
            shardLine.value:SetText(shardID)
            shardLine.value:SetTextColor(0.4, 0.78, 1)
        else
            shardLine.value:SetText("Unknown (target an NPC)")
            shardLine.value:SetTextColor(0.5, 0.5, 0.5)
        end
        y = y - ns.ROW_HEIGHT
    end

    -- Hint
    f.hint:SetText(DDT:BuildHintText(db.clickActions or {}, CLICK_ACTIONS))

    local ttWidth = db.tooltipWidth or TOOLTIP_WIDTH
    f:FinalizeLayout(ttWidth, math.abs(y))
end

function CharInfo:ShowTooltip(anchor)
    self:CancelHideTimer()

    if not tooltipFrame then
        tooltipFrame = CreateTooltipFrame()
    end

    local db = self:GetDB()
    ns.AnchorTooltip(tooltipFrame, anchor, db.tooltipGrowDirection)
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
    local r = panel.refreshCallbacks
    local db = function() return ns.db.characterinfo end

    W.AddLabelEditBox(panel, "name realm class level ilvl race shard",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateData() end, r, {
        { "Default",    "<name>" },
        { "With iLvl",  "<name>  iLvl: <ilvl>" },
        { "Class Info", "<name> (<class> <level>)" },
        { "Realm",      "<name> - <realm>" },
        { "Full",       "<name> <level> <class> (<ilvl>)" },
    })

    local body = W.AddSection(panel, "Display")
    local y = 0
    y = W.AddCheckbox(body, y, "Show item level",
        function() return db().showItemLevel end,
        function(v) db().showItemLevel = v end, r)
    y = W.AddCheckbox(body, y, "Show guild name",
        function() return db().showGuild end,
        function(v) db().showGuild = v end, r)
    y = W.AddCheckbox(body, y, "Show shard ID (best-effort)",
        function() return db().showShardID end,
        function(v) db().showShardID = v end, r)
    y = W.AddDescription(body, y,
        "Shard ID Detection (Limitations):\n" ..
        "Blizzard does not expose shard/server IDs to addons.\n" ..
        "DDT extracts an approximate shard identifier by parsing\n" ..
        "NPC GUIDs when you target or mouseover a creature.\n\n" ..
        "Caveats:\n" ..
        "  \226\128\162 Only updates when you target/mouseover an NPC\n" ..
        "  \226\128\162 Shows 'Unknown' in empty areas with no NPCs\n" ..
        "  \226\128\162 May be inaccurate during shard transitions\n" ..
        "  \226\128\162 Blizzard may change GUID format at any time")
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
    y = W.AddSliderPair(body, y,
        { label = "Max Height", min = 100, max = 1000, step = 10,
          get = function() return db().tooltipMaxHeight end,
          set = function(v) db().tooltipMaxHeight = v end },
        nil, r)
    y = W.AddNote(body, y, "Suggested: 300 x 250 for standard character info.")
    y = W.AddTooltipGrowDirection(body, y, db, r)
    y = W.AddTooltipCopyFrom(body, y, "characterinfo", db, r)
    W.EndSection(panel, y)

    ns.AddModuleClickActionsSection(panel, r, "characterinfo", CLICK_ACTIONS)
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("characterinfo", CharInfo, DEFAULTS)
