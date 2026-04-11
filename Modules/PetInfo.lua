-- Djinni's Data Texts - Pet Info
-- Pet journal unlock status, battle capability, collection stats.
local addonName, ns = ...
local DDT = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local PetInfo = {}
ns.PetInfo = PetInfo

-- Tooltip
local tooltipFrame = nil
local hideTimer = nil

-- Layout
local TOOLTIP_WIDTH  = 300
local HEADER_HEIGHT  = 18
local PADDING        = 10
local HINT_HEIGHT    = 18

-- State
local journalUnlocked = false
local findBattleEnabled = false
local numPetsOwned = 0
local numPetsTotal = 0
local numMaxLevel = 0
local numRareQuality = 0
local favoriteCount = 0

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
    labelTemplate   = "<status>",
    showCollection  = true,
    tooltipScale     = 1.0,
    tooltipMaxHeight = 400,
    tooltipWidth     = 300,
    clickActions    = {
        leftClick       = "openjournal",
        rightClick      = "randomsummon",
        middleClick     = "none",
        shiftLeftClick  = "revive",
        shiftRightClick = "none",
        ctrlLeftClick   = "randomteam",
        ctrlRightClick  = "none",
        altLeftClick    = "opensettings",
        altRightClick   = "none",
    },
}

-- Pet action spell/item IDs
local REVIVE_BATTLE_PETS_SPELL = 125439
local PET_BANDAGE_ITEM         = 86143
local SAFARI_HAT_ITEM          = 92738
local LESSER_PET_TREAT_ITEM    = 98112
local PET_TREAT_ITEM           = 98114

local CLICK_ACTIONS = {
    openjournal   = "Open Pet Journal",
    randomsummon  = "Summon Random Pet",
    revive        = "Revive Battle Pets",
    bandage       = "Use Pet Bandage",
    safarihat     = "Equip Safari Hat",
    pettreat      = "Use Pet Treat",
    randomteam    = "Load Random Pet Team",
    opensettings  = "Open DDT Settings",
    none          = "None",
}

---------------------------------------------------------------------------
-- Label template expansion
---------------------------------------------------------------------------

local function ExpandLabel(template)
    local result = template
    local E = ns.ExpandTag
    local status
    if journalUnlocked then
        status = numPetsOwned .. " Pets"
    else
        status = "Pets Locked"
    end
    result = E(result, "status", status)
    result = E(result, "owned", numPetsOwned)
    result = E(result, "total", numPetsTotal)
    result = E(result, "maxlevel", numMaxLevel)
    result = E(result, "rare", numRareQuality)
    result = E(result, "favorites", favoriteCount)
    result = E(result, "journal", journalUnlocked and "Unlocked" or "Locked")
    result = E(result, "battles", findBattleEnabled and "Ready" or "Disabled")
    return result
end

---------------------------------------------------------------------------
-- LDB Data Object
---------------------------------------------------------------------------

local dataobj = LDB:NewDataObject("DDT-PetInfo", {
    type  = "data source",
    text  = "Pets",
    icon  = "Interface\\Icons\\INV_Pet_Achievement",
    label = "DDT - Pets",
    OnEnter = function(self)
        PetInfo:ShowTooltip(self)
    end,
    OnLeave = function(self)
        PetInfo:StartHideTimer()
    end,
    OnClick = function(self, button)
        local db = PetInfo:GetDB()
        local action = DDT:ResolveClickAction(button, db.clickActions or {})
        if action == "openjournal" then
            ToggleCollectionsJournal(2) -- 2 = Pet Journal tab
        elseif action == "randomsummon" then
            if C_PetJournal and C_PetJournal.SummonRandomPet then
                C_PetJournal.SummonRandomPet(false) -- false = not favorite-only
            end
        elseif action == "revive" then
            local cdSecret = C_Secrets and C_Secrets.ShouldCooldownsBeSecret and C_Secrets.ShouldCooldownsBeSecret()
            local start = not cdSecret and C_Spell.GetSpellCooldown(REVIVE_BATTLE_PETS_SPELL)
            if not start or start == 0 then
                C_Spell.CastSpellByID(REVIVE_BATTLE_PETS_SPELL)
            else
                DDT:Print("Revive Battle Pets is on cooldown.")
            end
        elseif action == "bandage" then
            local count = C_Item.GetItemCount(PET_BANDAGE_ITEM)
            if count > 0 then
                C_Item.UseItemByID(PET_BANDAGE_ITEM)
            else
                DDT:Print("No Pet Bandages in bags.")
            end
        elseif action == "safarihat" then
            local count = C_Item.GetItemCount(SAFARI_HAT_ITEM)
            if count > 0 then
                C_Item.UseItemByID(SAFARI_HAT_ITEM)
            else
                DDT:Print("Safari Hat not found in bags.")
            end
        elseif action == "pettreat" then
            -- Try pet treat first, then lesser
            local count = C_Item.GetItemCount(PET_TREAT_ITEM)
            if count > 0 then
                C_Item.UseItemByID(PET_TREAT_ITEM)
            else
                count = C_Item.GetItemCount(LESSER_PET_TREAT_ITEM)
                if count > 0 then
                    C_Item.UseItemByID(LESSER_PET_TREAT_ITEM)
                else
                    DDT:Print("No Pet Treats in bags.")
                end
            end
        elseif action == "randomteam" then
            if C_PetJournal and C_PetJournal.GetNumPetLoadouts then
                local numTeams = C_PetJournal.GetNumPetLoadouts()
                if numTeams and numTeams > 0 then
                    local team = math.random(1, numTeams)
                    C_PetJournal.LoadPetLoadout(team)
                    DDT:Print("Loaded pet team " .. team .. ".")
                end
            end
        elseif action == "pintooltip" then
            ns:TogglePinTooltip(PetInfo, tooltipFrame)
        elseif action == "opensettings" then
            if DDT.settingsCategoryID then
                Settings.OpenToCategory(DDT.settingsCategoryID)
            end
        end
    end,
})

PetInfo.dataobj = dataobj

---------------------------------------------------------------------------
-- Event handling
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

function PetInfo:Init()
    eventFrame:SetScript("OnEvent", function(_, event)
        PetInfo:UpdateData()
    end)

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PET_JOURNAL_LIST_UPDATE")
    eventFrame:RegisterEvent("COMPANION_UPDATE")
    eventFrame:RegisterEvent("PET_JOURNAL_PET_DELETED")
    eventFrame:RegisterEvent("NEW_PET_ADDED")

    -- Delay initial scan to let pet data load
    C_Timer.After(3, function()
        PetInfo:UpdateData()
    end)
end

function PetInfo:GetDB()
    return ns.db and ns.db.petinfo or DEFAULTS
end

---------------------------------------------------------------------------
-- Data collection
---------------------------------------------------------------------------

function PetInfo:UpdateData()
    -- Journal unlock / battle capability
    if C_PetJournal then
        if C_PetJournal.IsJournalUnlocked then
            journalUnlocked = C_PetJournal.IsJournalUnlocked()
        end
        if C_PetJournal.IsFindBattleEnabled then
            findBattleEnabled = C_PetJournal.IsFindBattleEnabled()
        end

        -- Collection stats
        if C_PetJournal.GetNumPets then
            numPetsOwned, numPetsTotal = C_PetJournal.GetNumPets()
            numPetsOwned = numPetsOwned or 0
            numPetsTotal = numPetsTotal or 0
        end

        -- Count max-level and rare pets
        numMaxLevel = 0
        numRareQuality = 0
        favoriteCount = 0

        if C_PetJournal.GetNumPetsInJournal then
            -- Filter might affect counts, so use collection total
        end

        -- Scan owned pets for stats
        if C_PetJournal.GetPetInfoByIndex then
            -- Save/restore filters to avoid interfering with journal UI
            local ownedOnly = C_PetJournal.IsFilterChecked(LE_PET_JOURNAL_FILTER_COLLECTED)
            local notOwned = C_PetJournal.IsFilterChecked(LE_PET_JOURNAL_FILTER_NOT_COLLECTED)

            -- Count via pet stats for owned pets
            for i = 1, numPetsOwned do
                local petID, _, _, _, level, favorite, _, _, _, _, _, _, _, _, _, _, _ = C_PetJournal.GetPetInfoByIndex(i)
                if petID then
                    if level and level >= 25 then
                        numMaxLevel = numMaxLevel + 1
                    end
                    if favorite then
                        favoriteCount = favoriteCount + 1
                    end
                    local _, _, _, _, quality = C_PetJournal.GetPetStats(petID)
                    if quality and quality >= 4 then -- 4 = Rare
                        numRareQuality = numRareQuality + 1
                    end
                end
            end
        end
    end

    -- Update icon based on status
    if journalUnlocked then
        dataobj.icon = "Interface\\Icons\\INV_Pet_Achievement"
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
    local f = ns.CreateTooltipFrame("DDTPetInfoTooltip", PetInfo)
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

function PetInfo:BuildTooltipContent()
    local f = tooltipFrame
    local c = f.content
    HideLines(c)

    local db = self:GetDB()

    f.header:SetText("Battle Pets")

    local y = 0
    local lineIdx = 0

    -- Journal status
    lineIdx = lineIdx + 1
    local statusLine = GetLine(c, lineIdx)
    statusLine.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
    statusLine.label:SetText("|cffffffffPet Journal|r")
    statusLine.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
    if journalUnlocked then
        statusLine.value:SetText("Unlocked")
        statusLine.value:SetTextColor(0.0, 1.0, 0.0)
    else
        statusLine.value:SetText("Locked")
        statusLine.value:SetTextColor(1.0, 0.2, 0.2)
    end
    y = y - ns.ROW_HEIGHT

    -- Battle capability
    lineIdx = lineIdx + 1
    local battleLine = GetLine(c, lineIdx)
    battleLine.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
    battleLine.label:SetText("|cffffffffPet Battles|r")
    battleLine.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
    if not journalUnlocked then
        battleLine.value:SetText("Unavailable (journal locked)")
        battleLine.value:SetTextColor(1.0, 0.2, 0.2)
    elseif findBattleEnabled then
        battleLine.value:SetText("Available")
        battleLine.value:SetTextColor(0.0, 1.0, 0.0)
    else
        battleLine.value:SetText("Disabled")
        battleLine.value:SetTextColor(1.0, 0.5, 0.0)
    end
    y = y - ns.ROW_HEIGHT

    -- Find Battle queue
    lineIdx = lineIdx + 1
    local queueLine = GetLine(c, lineIdx)
    queueLine.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
    queueLine.label:SetText("|cffffffffFind Battle|r")
    queueLine.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
    local canQueue = journalUnlocked and findBattleEnabled
    if C_LobbyMatchmakerInfo and C_LobbyMatchmakerInfo.IsInQueue and C_LobbyMatchmakerInfo.IsInQueue() then
        queueLine.value:SetText("In Queue")
        queueLine.value:SetTextColor(1.0, 0.82, 0.0)
    elseif canQueue then
        queueLine.value:SetText("Ready")
        queueLine.value:SetTextColor(0.0, 1.0, 0.0)
    else
        queueLine.value:SetText("Unavailable")
        queueLine.value:SetTextColor(0.5, 0.5, 0.5)
    end
    y = y - ns.ROW_HEIGHT

    -- Collection stats
    if db.showCollection and journalUnlocked then
        y = y - 4

        lineIdx = lineIdx + 1
        local colHdr = GetLine(c, lineIdx)
        colHdr.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
        colHdr.label:SetText("|cffffd100Collection|r")
        colHdr.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
        colHdr.value:SetText("")
        y = y - HEADER_HEIGHT

        -- Collected count
        lineIdx = lineIdx + 1
        local collLine = GetLine(c, lineIdx)
        collLine.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING + 6, y)
        collLine.label:SetText("Collected")
        collLine.label:SetTextColor(0.8, 0.8, 0.8)
        collLine.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
        local pct = numPetsTotal > 0 and math.floor(numPetsOwned / numPetsTotal * 100) or 0
        collLine.value:SetText(string.format("%d / %d  (%d%%)", numPetsOwned, numPetsTotal, pct))
        collLine.value:SetTextColor(0.4, 0.78, 1)
        y = y - ns.ROW_HEIGHT

        -- Max level
        lineIdx = lineIdx + 1
        local maxLine = GetLine(c, lineIdx)
        maxLine.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING + 6, y)
        maxLine.label:SetText("Level 25")
        maxLine.label:SetTextColor(0.8, 0.8, 0.8)
        maxLine.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
        maxLine.value:SetText(tostring(numMaxLevel))
        maxLine.value:SetTextColor(1.0, 0.82, 0.0)
        y = y - ns.ROW_HEIGHT

        -- Rare quality
        lineIdx = lineIdx + 1
        local rareLine = GetLine(c, lineIdx)
        rareLine.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING + 6, y)
        rareLine.label:SetText("Rare Quality")
        rareLine.label:SetTextColor(0.8, 0.8, 0.8)
        rareLine.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
        rareLine.value:SetText(tostring(numRareQuality))
        rareLine.value:SetTextColor(0.0, 0.44, 0.87)
        y = y - ns.ROW_HEIGHT

        -- Favorites
        lineIdx = lineIdx + 1
        local favLine = GetLine(c, lineIdx)
        favLine.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING + 6, y)
        favLine.label:SetText("Favorites")
        favLine.label:SetTextColor(0.8, 0.8, 0.8)
        favLine.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
        favLine.value:SetText(tostring(favoriteCount))
        favLine.value:SetTextColor(0.9, 0.9, 0.9)
        y = y - ns.ROW_HEIGHT
    elseif not journalUnlocked then
        y = y - 4

        lineIdx = lineIdx + 1
        local lockInfo = GetLine(c, lineIdx)
        lockInfo.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
        lockInfo.label:SetText("|cff888888Pet Journal is locked on this account.|r")
        lockInfo.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
        lockInfo.value:SetText("")
        y = y - ns.ROW_HEIGHT

        lineIdx = lineIdx + 1
        local lockInfo2 = GetLine(c, lineIdx)
        lockInfo2.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
        lockInfo2.label:SetText("|cff888888Pet battles, summoning, and caging|r")
        lockInfo2.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
        lockInfo2.value:SetText("")
        y = y - ns.ROW_HEIGHT

        lineIdx = lineIdx + 1
        local lockInfo3 = GetLine(c, lineIdx)
        lockInfo3.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
        lockInfo3.label:SetText("|cff888888are unavailable.|r")
        lockInfo3.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
        lockInfo3.value:SetText("")
        y = y - ns.ROW_HEIGHT
    end

    -- Hint
    f.hint:SetText(DDT:BuildHintText(db.clickActions or {}, CLICK_ACTIONS))

    local ttWidth = db.tooltipWidth or TOOLTIP_WIDTH
    f:FinalizeLayout(ttWidth, math.abs(y))
end

function PetInfo:ShowTooltip(anchor)
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

function PetInfo:StartHideTimer()
    self:CancelHideTimer()
    hideTimer = C_Timer.NewTimer(ns.HIDE_DELAY, function()
        if tooltipFrame then tooltipFrame:Hide() end
        hideTimer = nil
    end)
end

function PetInfo:CancelHideTimer()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
end

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------

PetInfo.settingsLabel = "Pet Info"

function PetInfo:BuildSettingsPanel(panel)
    local W = ns.SettingsWidgets
    local r = panel.refreshCallbacks
    local db = function() return ns.db.petinfo end

    W.AddLabelEditBox(panel, "status owned total maxlevel rare favorites journal battles",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateData() end, r, {
        { "Default",     "<status>" },
        { "Collection",  "Pets: <owned>/<total>" },
        { "Max Level",   "<owned> pets (<maxlevel> max)" },
        { "Favorites",   "<favorites> favorites" },
    })

    local body = W.AddSection(panel, "Display")
    local y = 0
    y = W.AddCheckbox(body, y, "Show collection statistics",
        function() return db().showCollection end,
        function(v) db().showCollection = v end, r)
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
    y = W.AddNote(body, y, "Suggested: 300 x 300 for pet stats and actions.")
    y = W.AddTooltipGrowDirection(body, y, db, r)
    y = W.AddTooltipCopyFrom(body, y, "petinfo", db, r)
    W.EndSection(panel, y)

    ns.AddModuleClickActionsSection(panel, r, "petinfo", CLICK_ACTIONS)

    body = W.AddSection(panel, "About", true)
    y = 0
    y = W.AddDescription(body, y,
        "Shows whether this account can use pet battles.\n" ..
        "A locked journal means pet battles, summoning,\n" ..
        "caging, and renaming are all unavailable.\n\n" ..
        "Click actions support: revive pets, use bandage,\n" ..
        "equip Safari Hat, use pet treats, summon a random\n" ..
        "pet, or load a random pet team.")
    W.EndSection(panel, y)
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("petinfo", PetInfo, DEFAULTS)
