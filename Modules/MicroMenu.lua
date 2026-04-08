-- Djinni's Data Texts - Micro Menu
-- Quick-access buttons for game panels (character, spellbook, talents, etc.).
local addonName, ns = ...
local DDT = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local MicroMenu = {}
ns.MicroMenu = MicroMenu

-- Tooltip
local tooltipFrame = nil
local hideTimer = nil
local rowPool = {}

-- Layout
local TOOLTIP_WIDTH  = 220
local ICON_SIZE      = 16
local PADDING        = 10
local HINT_HEIGHT    = 18

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
    labelTemplate = "Menu",
    tooltipScale     = 1.0,
    tooltipMaxHeight = 400,
    tooltipWidth     = 220,
    clickActions  = {
        leftClick       = "gamemenu",
        rightClick      = "reloadui",
        middleClick     = "none",
        shiftLeftClick  = "none",
        shiftRightClick = "none",
        ctrlLeftClick   = "none",
        ctrlRightClick  = "none",
        altLeftClick    = "opensettings",
        altRightClick   = "none",
    },
}

local CLICK_ACTIONS = {
    gamemenu     = "Game Menu",
    reloadui     = "Reload UI",
    addonlist    = "Addon List",
    opensettings = "Open DDT Settings",
    none         = "None",
}

---------------------------------------------------------------------------
-- Menu entries
-- Each: { label, icon, action, condition(optional) }
---------------------------------------------------------------------------

local MENU_ENTRIES = {
    { label = "Character",         icon = "Interface\\Icons\\INV_Chest_Cloth_21",             action = function() ToggleCharacter("PaperDollFrame") end },
    { label = "Spellbook",         icon = "Interface\\Icons\\INV_Misc_Book_09",               action = function()
        if PlayerSpellsFrame then
            if PlayerSpellsFrame:IsShown() then HideUIPanel(PlayerSpellsFrame) else ShowUIPanel(PlayerSpellsFrame) end
        elseif ToggleSpellBook then
            ToggleSpellBook(BOOKTYPE_SPELL)
        end
    end },
    { label = "Talents",           icon = "Interface\\Icons\\Ability_Marksmanship",           action = function()
        if not PlayerSpellsFrame then PlayerSpellsFrame_LoadUI() end
        if PlayerSpellsFrame then
            if PlayerSpellsFrame:IsShown() then HideUIPanel(PlayerSpellsFrame) else ShowUIPanel(PlayerSpellsFrame) end
        end
    end },
    { label = "Achievements",      icon = "Interface\\Icons\\Achievement_General",            action = function() ToggleAchievementFrame() end },
    { label = "Quest Log",         icon = "Interface\\Icons\\INV_Misc_Book_08",               action = function() ToggleQuestLog() end },
    { label = "Guild & Communities", icon = "Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend", action = function() ToggleGuildFrame() end },
    { label = "Group Finder",      icon = "Interface\\Icons\\INV_Misc_GroupLooking",          action = function() ToggleLFDParentFrame() end },
    { label = "Collections",       icon = "Interface\\Icons\\MountJournalPortrait",           action = function() ToggleCollectionsJournal() end },
    { label = "Adventure Guide",   icon = "Interface\\Icons\\INV_Misc_Book_11",               action = function() ToggleEncounterJournal() end },
    { label = "Map & Quest Log",   icon = "Interface\\Icons\\INV_Misc_Map_01",                action = function() ToggleWorldMap() end },
    { label = "Calendar",          icon = "Interface\\Icons\\Ability_Mage_TimeWarp",          action = function() ToggleCalendar() end },
    { label = "Game Menu",         icon = "Interface\\Icons\\INV_Misc_Gear_01",               action = function()
        if GameMenuFrame and GameMenuFrame:IsShown() then
            HideUIPanel(GameMenuFrame)
        else
            ShowUIPanel(GameMenuFrame)
        end
    end },
}

---------------------------------------------------------------------------
-- Label template expansion
---------------------------------------------------------------------------

local function ExpandLabel(template)
    return template
end

---------------------------------------------------------------------------
-- LDB Data Object
---------------------------------------------------------------------------

local dataobj = LDB:NewDataObject("DDT-MicroMenu", {
    type  = "data source",
    text  = "Menu",
    icon  = "Interface\\Icons\\INV_Misc_Gear_01",
    label = "DDT - Micro Menu",
    OnEnter = function(self)
        MicroMenu:ShowTooltip(self)
    end,
    OnLeave = function(self)
        MicroMenu:StartHideTimer()
    end,
    OnClick = function(self, button)
        local db = MicroMenu:GetDB()
        local action = DDT:ResolveClickAction(button, db.clickActions or {})
        if action == "gamemenu" then
            if GameMenuFrame and GameMenuFrame:IsShown() then
                HideUIPanel(GameMenuFrame)
            else
                ShowUIPanel(GameMenuFrame)
            end
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
        elseif action == "opensettings" then
            if DDT.settingsCategoryID then
                Settings.OpenToCategory(DDT.settingsCategoryID)
            end
        end
    end,
})

MicroMenu.dataobj = dataobj

---------------------------------------------------------------------------
-- Event handling
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

function MicroMenu:Init()
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", function()
        MicroMenu:UpdateDisplay()
    end)
end

function MicroMenu:GetDB()
    return ns.db and ns.db.micromenu or DEFAULTS
end

function MicroMenu:UpdateDisplay()
    local db = self:GetDB()
    dataobj.text = ExpandLabel(db.labelTemplate)
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------

local function CreateTooltipFrame()
    local f = ns.CreateTooltipFrame("DDTMicroMenuTooltip", MicroMenu)
    return f
end

local function GetRow(parent, index)
    if rowPool[index] then
        rowPool[index]:Show()
        return rowPool[index]
    end

    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ns.ROW_HEIGHT)

    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, 0.08)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.text = ns.FontString(row, "DDTFontNormal")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.text:SetJustifyH("LEFT")

    row:SetScript("OnEnter", function()
        MicroMenu:CancelHideTimer()
    end)
    row:SetScript("OnLeave", function()
        MicroMenu:StartHideTimer()
    end)

    rowPool[index] = row
    return row
end

local function HideAllRows()
    for _, row in pairs(rowPool) do row:Hide() end
end

function MicroMenu:BuildTooltipContent()
    HideAllRows()

    local f = tooltipFrame
    local c = f.content
    local db = self:GetDB()

    f.header:SetText("Micro Menu")

    local y = 0
    local rowIndex = 0

    for _, entry in ipairs(MENU_ENTRIES) do
        rowIndex = rowIndex + 1
        local row = GetRow(c, rowIndex)
        row:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
        row:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)

        row.icon:SetTexture(entry.icon)
        row.text:SetText(entry.label)
        row.text:SetTextColor(0.9, 0.9, 0.9)

        local action = entry.action
        row:SetScript("OnClick", function()
            if tooltipFrame then tooltipFrame:Hide() end
            action()
        end)

        y = y - ns.ROW_HEIGHT
    end

    f.hint:SetText(DDT:BuildHintText(db.clickActions or {}, CLICK_ACTIONS))

    local ttWidth = db.tooltipWidth or TOOLTIP_WIDTH
    f:FinalizeLayout(ttWidth, math.abs(y))
end

function MicroMenu:ShowTooltip(anchor)
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

function MicroMenu:StartHideTimer()
    self:CancelHideTimer()
    hideTimer = C_Timer.NewTimer(ns.HIDE_DELAY, function()
        if tooltipFrame then tooltipFrame:Hide() end
        hideTimer = nil
    end)
end

function MicroMenu:CancelHideTimer()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
end

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------

MicroMenu.settingsLabel = "Micro Menu"

function MicroMenu:BuildSettingsPanel(panel)
    local W = ns.SettingsWidgets
    local r = panel.refreshCallbacks
    local db = function() return ns.db.micromenu end

    local body = W.AddSection(panel, "Label Template")
    local y = 0
    y = W.AddDescription(body, y, "Static label - no dynamic tags for this module.")
    y = W.AddEditBox(body, y, "Template",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateDisplay() end, r)
    W.EndSection(panel, y)

    body = W.AddSection(panel, "Tooltip", true)
    y = 0
    y = W.AddSliderPair(body, y,
        { label = "Scale", min = 0.5, max = 2.0, step = 0.05,
          get = function() return db().tooltipScale end,
          set = function(v) db().tooltipScale = v end },
        { label = "Width", min = 150, max = 400, step = 10,
          get = function() return db().tooltipWidth end,
          set = function(v) db().tooltipWidth = v end }, r)
    y = W.AddSliderPair(body, y,
        { label = "Max Height", min = 100, max = 1000, step = 10,
          get = function() return db().tooltipMaxHeight end,
          set = function(v) db().tooltipMaxHeight = v end },
        nil, r)
    y = W.AddNote(body, y, "Suggested: 200 x 350 for the full menu grid.")
    y = W.AddTooltipGrowDirection(body, y, db, r)
    y = W.AddTooltipCopyFrom(body, y, "micromenu", db, r)
    W.EndSection(panel, y)

    ns.AddModuleClickActionsSection(panel, r, "micromenu", CLICK_ACTIONS,
        "Click any row in the tooltip to open the corresponding panel.")
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("micromenu", MicroMenu, DEFAULTS)
