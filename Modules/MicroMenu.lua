-- Djinni's Data Texts — Micro Menu
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
local ROW_HEIGHT     = 20
local ICON_SIZE      = 16
local PADDING        = 10
local HINT_HEIGHT    = 18

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
    labelTemplate = "Menu",
    tooltipScale  = 1.0,
    tooltipWidth  = 220,
    clickActions  = {
        leftClick  = "gamemenu",
    },
}

local CLICK_ACTIONS = {
    gamemenu     = "Game Menu",
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
    local f = CreateFrame("Frame", "DDTMicroMenuTooltip", UIParent, "BackdropTemplate")
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
    f:SetScript("OnEnter", function() MicroMenu:CancelHideTimer() end)
    f:SetScript("OnLeave", function() MicroMenu:StartHideTimer() end)

    return f
end

local function GetRow(parent, index)
    if rowPool[index] then
        rowPool[index]:Show()
        return rowPool[index]
    end

    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)

    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, 0.08)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.text = row:CreateFontString(nil, "OVERLAY", "DDTFontNormal")
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
    local db = self:GetDB()

    f.title:SetText("Micro Menu")

    local y = -PADDING - 20 - 6
    local rowIndex = 0

    for _, entry in ipairs(MENU_ENTRIES) do
        rowIndex = rowIndex + 1
        local row = GetRow(f, rowIndex)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        row:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)

        row.icon:SetTexture(entry.icon)
        row.text:SetText(entry.label)
        row.text:SetTextColor(0.9, 0.9, 0.9)

        local action = entry.action
        row:SetScript("OnClick", function()
            if tooltipFrame then tooltipFrame:Hide() end
            action()
        end)

        y = y - ROW_HEIGHT
    end

    f.hint:SetText(DDT:BuildHintText(db.clickActions or {}, CLICK_ACTIONS))

    local ttWidth = db.tooltipWidth or TOOLTIP_WIDTH
    local totalHeight = math.abs(y) + PADDING + HINT_HEIGHT + 8
    f:SetSize(ttWidth, totalHeight)
end

function MicroMenu:ShowTooltip(anchor)
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
    local c = panel.content
    local r = panel.refreshCallbacks
    local y = -10
    local db = function() return ns.db.micromenu end

    y = W.AddHeader(c, y, "Label Template")
    y = W.AddDescription(c, y, "Static label — no dynamic tags for this module.")
    y = W.AddEditBox(c, y, "Template",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateDisplay() end, r)

    y = W.AddHeader(c, y, "Tooltip")
    y = W.AddSlider(c, y, "Scale", 0.5, 2.0, 0.05,
        function() return db().tooltipScale end,
        function(v) db().tooltipScale = v end, r)
    y = W.AddSlider(c, y, "Width", 150, 400, 10,
        function() return db().tooltipWidth end,
        function(v) db().tooltipWidth = v end, r)

    y = ns.AddModuleClickActionsSection(c, r, y, "micromenu", CLICK_ACTIONS)
    y = W.AddDescription(c, y,
        "Click any row in the tooltip to open the corresponding panel.")

    c:SetHeight(math.abs(y) + 20)
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("micromenu", MicroMenu, DEFAULTS)
