-- Djinni's Data Texts — Account Status
-- Warband bank and pet journal access indicators for multibox setups.
-- Shows at a glance which account/character has access to shared resources.
local addonName, ns = ...
local DDT = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local AcctStatus = {}
ns.AcctStatus = AcctStatus

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
local warbankEnabled = false   -- C_PlayerInfo.IsAccountBankEnabled()
local warbankLocked  = false   -- C_PlayerInfo.HasAccountInventoryLock() (true = this client has it)
local journalUnlocked = false  -- C_PetJournal.IsJournalUnlocked()
local findBattleEnabled = false

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
    labelTemplate    = "<warbank> | <journal>",
    tooltipScale     = 1.0,
    tooltipWidth     = 300,
    clickActions     = {
        leftClick       = "openwarbank",
        rightClick      = "openjournal",
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
    openwarbank  = "Open Warband Bank",
    openjournal  = "Open Pet Journal",
    opensettings = "Open DDT Settings",
    none         = "None",
}

---------------------------------------------------------------------------
-- Label template expansion
---------------------------------------------------------------------------

local function WarbankStatusText()
    if not warbankEnabled then
        return "WB: N/A"
    elseif warbankLocked then
        return "WB: OK"
    else
        return "WB: Locked"
    end
end

local function JournalStatusText()
    if journalUnlocked then
        return "Pets: OK"
    else
        return "Pets: Locked"
    end
end

local function ExpandLabel(template)
    local result = template
    local E = ns.ExpandTag
    result = E(result, "warbank", WarbankStatusText())
    result = E(result, "journal", JournalStatusText())
    result = E(result, "wbstatus", warbankEnabled and (warbankLocked and "Available" or "In Use") or "Disabled")
    result = E(result, "petstatus", journalUnlocked and "Unlocked" or "Locked")
    return result
end

---------------------------------------------------------------------------
-- LDB Data Object
---------------------------------------------------------------------------

local dataobj = LDB:NewDataObject("DDT-AccountStatus", {
    type  = "data source",
    text  = "Acct",
    icon  = "Interface\\Icons\\Achievement_GuildPerk_MobileBank",
    label = "DDT - Account Status",
    OnEnter = function(self)
        AcctStatus:ShowTooltip(self)
    end,
    OnLeave = function(self)
        AcctStatus:StartHideTimer()
    end,
    OnClick = function(self, button)
        local db = AcctStatus:GetDB()
        local action = DDT:ResolveClickAction(button, db.clickActions or {})
        if action == "openwarbank" then
            if BankFrame then
                ToggleAllBags()
            end
        elseif action == "openjournal" then
            ToggleCollectionsJournal(2)
        elseif action == "opensettings" then
            if DDT.settingsCategoryID then
                Settings.OpenToCategory(DDT.settingsCategoryID)
            end
        end
    end,
})

AcctStatus.dataobj = dataobj

---------------------------------------------------------------------------
-- Event handling
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

function AcctStatus:Init()
    eventFrame:SetScript("OnEvent", function(_, event)
        AcctStatus:UpdateData()
    end)

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    -- Warband events
    eventFrame:RegisterEvent("ACCOUNT_MONEY")
    -- Pet journal events
    eventFrame:RegisterEvent("PET_JOURNAL_LIST_UPDATE")
    eventFrame:RegisterEvent("COMPANION_UPDATE")

    -- Delay initial check to let APIs initialize
    C_Timer.After(3, function()
        AcctStatus:UpdateData()
    end)
end

function AcctStatus:GetDB()
    return ns.db and ns.db.accountstatus or DEFAULTS
end

---------------------------------------------------------------------------
-- Data collection
---------------------------------------------------------------------------

function AcctStatus:UpdateData()
    -- Warband bank status
    if C_PlayerInfo and C_PlayerInfo.IsAccountBankEnabled then
        warbankEnabled = C_PlayerInfo.IsAccountBankEnabled()
    end
    if C_PlayerInfo and C_PlayerInfo.HasAccountInventoryLock then
        warbankLocked = C_PlayerInfo.HasAccountInventoryLock()
    end

    -- Pet journal status
    if C_PetJournal then
        if C_PetJournal.IsJournalUnlocked then
            journalUnlocked = C_PetJournal.IsJournalUnlocked()
        end
        if C_PetJournal.IsFindBattleEnabled then
            findBattleEnabled = C_PetJournal.IsFindBattleEnabled()
        end
    end

    -- Update icon: green checkmark if all OK, red lock if anything restricted
    local allOK = warbankLocked and journalUnlocked
    if allOK then
        dataobj.icon = "Interface\\Icons\\Achievement_GuildPerk_MobileBank"
    else
        dataobj.icon = "Interface\\Icons\\INV_Misc_Key_04"
    end

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
    local f = CreateFrame("Frame", "DDTAccountStatusTooltip", UIParent, "BackdropTemplate")
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
    f:SetScript("OnEnter", function() AcctStatus:CancelHideTimer() end)
    f:SetScript("OnLeave", function() AcctStatus:StartHideTimer() end)

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

function AcctStatus:BuildTooltipContent()
    local f = tooltipFrame
    HideLines(f)

    local db = self:GetDB()

    f.title:SetText("Account Status")

    local y = -PADDING - 20 - 6
    local lineIdx = 0

    -- Character info
    lineIdx = lineIdx + 1
    local charLine = GetLine(f, lineIdx)
    charLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    charLine.label:SetText("|cffffffffCharacter|r")
    charLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    local charName = UnitName("player") or "Unknown"
    local _, classFile = UnitClass("player")
    if classFile then
        charLine.value:SetText(DDT:ClassColorText(charName, classFile))
    else
        charLine.value:SetText(charName)
    end
    charLine.value:SetTextColor(1, 1, 1)
    y = y - ROW_HEIGHT

    y = y - 4

    -- Warband Bank header
    lineIdx = lineIdx + 1
    local wbHdr = GetLine(f, lineIdx)
    wbHdr.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    wbHdr.label:SetText("|cffffd100Warband Bank|r")
    wbHdr.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    wbHdr.value:SetText("")
    y = y - HEADER_HEIGHT

    -- Warband: Feature enabled
    lineIdx = lineIdx + 1
    local wbEnabledLine = GetLine(f, lineIdx)
    wbEnabledLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 6, y)
    wbEnabledLine.label:SetText("Feature")
    wbEnabledLine.label:SetTextColor(0.8, 0.8, 0.8)
    wbEnabledLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    if warbankEnabled then
        wbEnabledLine.value:SetText("Enabled")
        wbEnabledLine.value:SetTextColor(0.0, 1.0, 0.0)
    else
        wbEnabledLine.value:SetText("Disabled / Unavailable")
        wbEnabledLine.value:SetTextColor(1.0, 0.2, 0.2)
    end
    y = y - ROW_HEIGHT

    -- Warband: Access lock
    lineIdx = lineIdx + 1
    local wbLockLine = GetLine(f, lineIdx)
    wbLockLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 6, y)
    wbLockLine.label:SetText("Access")
    wbLockLine.label:SetTextColor(0.8, 0.8, 0.8)
    wbLockLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    if not warbankEnabled then
        wbLockLine.value:SetText("N/A")
        wbLockLine.value:SetTextColor(0.5, 0.5, 0.5)
    elseif warbankLocked then
        wbLockLine.value:SetText("Available (this client)")
        wbLockLine.value:SetTextColor(0.0, 1.0, 0.0)
    else
        wbLockLine.value:SetText("Locked (another client)")
        wbLockLine.value:SetTextColor(1.0, 0.2, 0.2)
    end
    y = y - ROW_HEIGHT

    y = y - 4

    -- Pet Journal header
    lineIdx = lineIdx + 1
    local petHdr = GetLine(f, lineIdx)
    petHdr.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    petHdr.label:SetText("|cffffd100Pet Journal|r")
    petHdr.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    petHdr.value:SetText("")
    y = y - HEADER_HEIGHT

    -- Pet: Journal unlock
    lineIdx = lineIdx + 1
    local petUnlockLine = GetLine(f, lineIdx)
    petUnlockLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 6, y)
    petUnlockLine.label:SetText("Journal")
    petUnlockLine.label:SetTextColor(0.8, 0.8, 0.8)
    petUnlockLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    if journalUnlocked then
        petUnlockLine.value:SetText("Unlocked")
        petUnlockLine.value:SetTextColor(0.0, 1.0, 0.0)
    else
        petUnlockLine.value:SetText("Locked")
        petUnlockLine.value:SetTextColor(1.0, 0.2, 0.2)
    end
    y = y - ROW_HEIGHT

    -- Pet: Battle capability
    lineIdx = lineIdx + 1
    local petBattleLine = GetLine(f, lineIdx)
    petBattleLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 6, y)
    petBattleLine.label:SetText("Pet Battles")
    petBattleLine.label:SetTextColor(0.8, 0.8, 0.8)
    petBattleLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    if not journalUnlocked then
        petBattleLine.value:SetText("Unavailable")
        petBattleLine.value:SetTextColor(0.5, 0.5, 0.5)
    elseif findBattleEnabled then
        petBattleLine.value:SetText("Available")
        petBattleLine.value:SetTextColor(0.0, 1.0, 0.0)
    else
        petBattleLine.value:SetText("Disabled")
        petBattleLine.value:SetTextColor(1.0, 0.5, 0.0)
    end
    y = y - ROW_HEIGHT

    y = y - 4

    -- Summary
    lineIdx = lineIdx + 1
    local summaryLine = GetLine(f, lineIdx)
    summaryLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    local allOK = warbankLocked and journalUnlocked
    if allOK then
        summaryLine.label:SetText("|cff00ff00All resources available on this account.|r")
    else
        local issues = {}
        if not warbankLocked then
            table.insert(issues, "warband bank")
        end
        if not journalUnlocked then
            table.insert(issues, "pet journal")
        end
        summaryLine.label:SetText("|cffff3333Restricted: " .. table.concat(issues, ", ") .. "|r")
    end
    summaryLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    summaryLine.value:SetText("")
    y = y - ROW_HEIGHT

    -- Hint
    f.hint:SetText(DDT:BuildHintText(db.clickActions or {}, CLICK_ACTIONS))

    local ttWidth = db.tooltipWidth or TOOLTIP_WIDTH
    local totalHeight = math.abs(y) + PADDING + HINT_HEIGHT + 8
    f:SetSize(ttWidth, totalHeight)
end

function AcctStatus:ShowTooltip(anchor)
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

function AcctStatus:StartHideTimer()
    self:CancelHideTimer()
    hideTimer = C_Timer.NewTimer(ns.HIDE_DELAY, function()
        if tooltipFrame then tooltipFrame:Hide() end
        hideTimer = nil
    end)
end

function AcctStatus:CancelHideTimer()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
end

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------

AcctStatus.settingsLabel = "Account Status"

function AcctStatus:BuildSettingsPanel(panel)
    local W = ns.SettingsWidgets
    local c = panel.content
    local r = panel.refreshCallbacks
    local y = -10
    local db = function() return ns.db.accountstatus end

    y = W.AddHeader(c, y, "Label Template")
    y = W.AddLabelEditBox(c, y, "warbank journal wbstatus petstatus",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateData() end, r, {
        { "Default",  "<warbank>" },
        { "Status",   "<wbstatus>  <petstatus>" },
        { "Journal",  "Journal: <journal>" },
        { "Combined", "<warbank>  <journal>" },
    })

    y = W.AddHeader(c, y, "Tooltip")
    y = W.AddSlider(c, y, "Scale", 0.5, 2.0, 0.05,
        function() return db().tooltipScale end,
        function(v) db().tooltipScale = v end, r)
    y = W.AddSlider(c, y, "Width", 200, 500, 10,
        function() return db().tooltipWidth end,
        function(v) db().tooltipWidth = v end, r)

    y = ns.AddModuleClickActionsSection(c, r, y, "accountstatus", CLICK_ACTIONS)

    y = W.AddHeader(c, y, "About")
    y = W.AddDescription(c, y,
        "Designed for multibox setups where multiple\n" ..
        "accounts are logged in simultaneously.\n\n" ..
        "Warband Bank: Shows whether this client has\n" ..
        "the account inventory lock (only one client\n" ..
        "can access the warband bank at a time).\n\n" ..
        "Pet Journal: Shows whether the journal is\n" ..
        "unlocked on this account (restricted accounts\n" ..
        "cannot use pet battles, summoning, or caging).")

    c:SetHeight(math.abs(y) + 20)
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("accountstatus", AcctStatus, DEFAULTS)
