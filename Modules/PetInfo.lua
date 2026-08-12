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
local TOOLTIP_WIDTH  = 340
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
    tooltipWidth     = 340,
    clickActions    = {
        leftClick       = "openjournal",
        rightClick      = "randomsummon",
        middleClick     = "none",
        shiftLeftClick  = "none",
        shiftRightClick = "none",
        ctrlLeftClick   = "none",
        ctrlRightClick  = "none",
        altLeftClick    = "opensettings",
        altRightClick   = "none",
    },
}

-- Pet action spell/item IDs
local REVIVE_BATTLE_PETS_SPELL = 125439
local PET_BANDAGE_ITEM         = 86143
local SAFARI_HAT_ITEM          = 92738
local SAFARI_HAT_BUFF          = 158486  -- aura granted while the Safari Hat is worn
local LESSER_PET_TREAT_ITEM    = 98112
local PET_TREAT_ITEM           = 98114

-- Broker-click actions. Revive / bandage / Safari Hat / pet treats are NOT
-- here: those are protected spell-cast / item-use actions that can't run from
-- an LDB broker's insecure OnClick, so they live as secure buttons in the
-- tooltip instead (see ACTION_BUTTONS below).
local CLICK_ACTIONS = {
    openjournal   = "Open Pet Journal",
    randomsummon  = "Summon Random Pet",
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
        status = numPetsOwned .. " Battle Pets"
    else
        status = "Battle Pets Locked"
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

local dataobj = ns:NewBroker("petinfo", "DDT-PetInfo", {
    type  = "data source",
    text  = "Battle Pets",
    icon  = "Interface\\Icons\\INV_Pet_Achievement",
    label = "DDT - Battle Pets",
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
    -- Migrate away from the old protected click actions (revive / bandage /
    -- safarihat / pettreat), which are now secure tooltip buttons. Any saved
    -- binding still pointing at them is cleared so the slot isn't a dead click.
    local pdb = self:GetDB()
    if pdb and pdb.clickActions then
        local removed = { revive = true, bandage = true, safarihat = true, pettreat = true, randomteam = true }
        for slot, act in pairs(pdb.clickActions) do
            if removed[act] then pdb.clickActions[slot] = "none" end
        end
    end

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

        -- Collection stats. GetNumPets returns (numPets, numOwned): total first,
        -- owned second -- reversing them made "Collected" read as >100%.
        if C_PetJournal.GetNumPets then
            numPetsTotal, numPetsOwned = C_PetJournal.GetNumPets()
            numPetsTotal = numPetsTotal or 0
            numPetsOwned = numPetsOwned or 0
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

            -- GetPetInfoByIndex is indexed over all displayed species (1..numPets);
            -- the petID guard below skips uncollected ones.
            for i = 1, numPetsTotal do
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

---------------------------------------------------------------------------
-- Secure pet action buttons (revive / consumables)
--
-- Reviving battle pets and using pet items are PROTECTED actions: they cannot
-- be performed from an LDB broker's insecure OnClick. They are exposed instead
-- as SecureActionButtonTemplate rows inside the tooltip -- the same approach the
-- profession lure buttons use (Modules/Professions/Core.lua). Secure attributes
-- are only written out of combat (BuildTooltipContent bails in combat), and
-- because the tooltip then parents secure frames, showing/resizing it is
-- protected in combat too (handled in ShowTooltip / StartHideTimer).
---------------------------------------------------------------------------

-- Action panel definitions. Three kinds:
--   "func"  -> a normal button running def.onClick. Open journal / summon /
--              load team are NOT protected, so a plain button is fine.
--   "spell" -> a SecureActionButtonTemplate that casts def.spellID (revive).
--   "item"  -> a SecureActionButtonTemplate that uses the first of def.items
--              found in bags (bandage / Safari Hat / treats).
local ACTION_BUTTONS = {
    { key = "openjournal", kind = "func", icon = "Interface\\Icons\\INV_Pet_Achievement",
      label = "Open Pet Journal", onClick = function() ToggleCollectionsJournal(2) end },
    { key = "summon", kind = "func", icon = "Interface\\Icons\\Tracking_WildPet",
      label = "Summon Random Pet", onClick = function()
          if C_PetJournal and C_PetJournal.SummonRandomPet then C_PetJournal.SummonRandomPet(false) end
      end },
    { key = "revive",  kind = "spell", spellID = REVIVE_BATTLE_PETS_SPELL,                label = "Revive Battle Pets" },
    { key = "bandage", kind = "item",  items = { PET_BANDAGE_ITEM },                      label = "Use Pet Bandage"    },
    { key = "safari",  kind = "toy",   toyID = SAFARI_HAT_ITEM,                           label = "Equip Safari Hat"   },
    { key = "treat",   kind = "item",  items = { PET_TREAT_ITEM, LESSER_PET_TREAT_ITEM }, label = "Use Pet Treat"      },
}

local function HideActionButtons(f)
    if not f.actionButtons then return end
    for _, btn in pairs(f.actionButtons) do btn:Hide() end
end

local function GetOrCreateActionButton(f, def)
    f.actionButtons = f.actionButtons or {}
    if f.actionButtons[def.key] then return f.actionButtons[def.key] end

    -- Protected actions (spell/item) need a secure button; the rest are normal.
    local template = (def.kind == "func") and nil or "SecureActionButtonTemplate"
    local btn = CreateFrame("Button", "DDTPetAction_" .. def.key, f.content, template)
    btn:SetHeight(ns.ROW_HEIGHT)
    -- Non-secure "func" buttons run a plain OnClick, so fire once on "AnyUp".
    -- Secure action buttons MUST register both edges. Blizzard's
    -- SecureActionButton_OnClick gates on the ActionButtonUseKeyDown CVar and
    -- only performs the action on the matching edge -- down if the player casts
    -- on key-down, up otherwise. An AnyUp-only secure button therefore does
    -- nothing at all for anyone with "cast on key down" enabled. Registering
    -- both edges lets exactly one satisfy the gate, so the action fires once
    -- (the clickAction test makes double-firing impossible).
    if def.kind == "func" then
        btn:RegisterForClicks("AnyUp")
    else
        btn:RegisterForClicks("AnyUp", "AnyDown")
    end
    btn:EnableMouse(true)

    -- Faint background so each row clearly reads as a clickable button.
    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetColorTexture(1, 1, 1, 0.04)

    btn.hl = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.hl:SetAllPoints()
    btn.hl:SetColorTexture(1, 1, 1, 0.12)

    local iconSize = ns.ROW_HEIGHT - 4
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("LEFT", btn, "LEFT", 2, 0)
    btn.icon:SetSize(iconSize, iconSize)

    btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints(btn.icon)
    btn.cooldown:SetDrawEdge(false)

    btn.text = ns.FontString(btn, "DDTFontNormal")
    btn.text:SetPoint("LEFT", btn.icon, "RIGHT", 6, 0)
    btn.text:SetJustifyH("LEFT")

    btn.status = ns.FontString(btn, "DDTFontNormal")
    btn.status:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
    btn.status:SetJustifyH("RIGHT")

    -- Moving the mouse onto a child fires the tooltip frame's OnLeave, so each
    -- button must keep the hide timer at bay (same as the lure rows).
    btn:SetScript("OnEnter", function() PetInfo:CancelHideTimer() end)
    btn:SetScript("OnLeave", function() PetInfo:StartHideTimer() end)

    -- Non-protected actions run their handler directly; secure actions are
    -- driven by the type/spell/item attributes set in ConfigureActionButton.
    if def.kind == "func" and def.onClick then
        btn:SetScript("OnClick", def.onClick)
    end

    f.actionButtons[def.key] = btn
    return btn
end

-- Set attributes + visuals for an action button. MUST run out of combat
-- (secure attribute writes are protected).
local function ConfigureActionButton(btn, def)
    if def.kind == "func" then
        btn.icon:SetTexture(def.icon)
        btn.icon:SetDesaturated(false)
        btn.cooldown:Clear()
        btn.text:SetText(def.label)
        btn.status:SetText("")
        return
    end

    if def.kind == "toy" then
        -- The Safari Hat can be either a learned TOY or an equippable ITEM in
        -- bags depending on the character, so try both: prefer the toy (UseToy
        -- via type="toy"), else use/equip the bag item, else show why it can't.
        btn.icon:SetTexture(C_Item.GetItemIconByID(def.toyID))
        btn.cooldown:Clear()
        btn.text:SetText(def.label)
        -- If the Safari Hat buff is already active it's on -- surface that and
        -- desaturate so it's obviously a no-op, regardless of toy/bag ownership.
        local aurasSecret = C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret()
        local hatActive = (not aurasSecret) and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
            and C_UnitAuras.GetPlayerAuraBySpellID(SAFARI_HAT_BUFF) ~= nil
        if hatActive then
            -- Still allow a click to re-apply/refresh via the toy or bag item.
            if PlayerHasToy and PlayerHasToy(def.toyID) then
                btn:SetAttribute("type", "toy")
                btn:SetAttribute("toy", def.toyID)
            elseif (C_Item.GetItemCount(def.toyID) or 0) > 0 then
                btn:SetAttribute("type", "item")
                btn:SetAttribute("item", "item:" .. def.toyID)
            else
                btn:SetAttribute("type", "toy")
                btn:SetAttribute("toy", def.toyID)
            end
            btn.icon:SetDesaturated(true)
            btn.status:SetText("|cff00ff00Equipped|r")
            return
        end
        if PlayerHasToy and PlayerHasToy(def.toyID) then
            btn:SetAttribute("type", "toy")
            btn:SetAttribute("toy", def.toyID)
            btn.icon:SetDesaturated(false)
            btn.status:SetText("|cff00ff00Owned|r")
        elseif (C_Item.GetItemCount(def.toyID) or 0) > 0 then
            btn:SetAttribute("type", "item")
            btn:SetAttribute("item", "item:" .. def.toyID)
            btn.icon:SetDesaturated(false)
            btn.status:SetText("|cffffffffIn Bags|r")
        else
            btn:SetAttribute("type", "toy")
            btn:SetAttribute("toy", def.toyID)
            btn.icon:SetDesaturated(true)
            if C_Item.IsEquippedItem and C_Item.IsEquippedItem(def.toyID) then
                btn.status:SetText("|cff888888Equipped|r")
            else
                btn.status:SetText("|cff888888not owned|r")
            end
        end
        return
    end

    if def.kind == "spell" then
        btn:SetAttribute("type", "spell")
        btn:SetAttribute("spell", C_Spell.GetSpellName(def.spellID) or def.spellID)
        btn.icon:SetTexture(C_Spell.GetSpellTexture(def.spellID))
        btn.text:SetText(def.label)

        local cdSecret = C_Secrets and C_Secrets.ShouldCooldownsBeSecret and C_Secrets.ShouldCooldownsBeSecret()
        local cd = (not cdSecret) and C_Spell.GetSpellCooldown(def.spellID) or nil
        -- C_Spell.GetSpellCooldown returns a SpellCooldownInfo table, not a number.
        local onCd = cd and cd.duration and cd.duration > 0 and cd.startTime and cd.startTime > 0
        if onCd then
            btn.cooldown:SetCooldown(cd.startTime, cd.duration)
            btn.icon:SetDesaturated(true)
            btn.status:SetText("|cff888888Cooldown|r")
        else
            btn.cooldown:Clear()
            btn.icon:SetDesaturated(false)
            btn.status:SetText("|cff00ff00Ready|r")
        end
    else
        local chosenID, count = def.items[1], 0
        for _, id in ipairs(def.items) do
            local c = C_Item.GetItemCount(id) or 0
            if c > 0 then chosenID, count = id, c; break end
        end
        btn:SetAttribute("type", "item")
        btn:SetAttribute("item", "item:" .. chosenID)
        btn.icon:SetTexture(C_Item.GetItemIconByID(chosenID))
        btn.cooldown:Clear()
        btn.text:SetText(def.label)
        if count > 0 then
            btn.icon:SetDesaturated(false)
            btn.status:SetText("|cffffffffx" .. count .. "|r")
        else
            btn.icon:SetDesaturated(true)
            btn.status:SetText("|cff888888none|r")
        end
    end
end

function PetInfo:BuildTooltipContent()
    -- The tooltip parents secure action buttons; rebuilding its layout (and the
    -- SetAttribute calls below) is protected in combat. Bail and leave the last
    -- out-of-combat content in place.
    if InCombatLockdown() then return end

    local f = tooltipFrame
    local c = f.content
    HideLines(c)
    HideActionButtons(f)

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

    -- Pet actions (secure buttons: revive + consumables)
    if journalUnlocked then
        y = y - 6

        lineIdx = lineIdx + 1
        local actHdr = GetLine(c, lineIdx)
        actHdr.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
        actHdr.label:SetText("|cffffd100Actions|r")
        actHdr.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
        actHdr.value:SetText("")
        y = y - HEADER_HEIGHT

        for _, def in ipairs(ACTION_BUTTONS) do
            local btn = GetOrCreateActionButton(f, def)
            ConfigureActionButton(btn, def)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
            btn:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
            btn:Show()
            y = y - ns.ROW_HEIGHT
        end
    end

    -- Hint
    f.hint:SetText(DDT:BuildHintText(db.clickActions or {}, CLICK_ACTIONS))

    local ttWidth = db.tooltipWidth or TOOLTIP_WIDTH
    f:FinalizeLayout(ttWidth, math.abs(y))
end

function PetInfo:ShowTooltip(anchor)
    -- The tooltip parents SecureActionButtonTemplate action buttons, so showing
    -- and resizing it are protected in combat. Bail entirely while in combat --
    -- reviving/feeding pets is a non-combat activity anyway.
    if InCombatLockdown() then return end

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
        hideTimer = nil
        if not tooltipFrame then return end
        -- Hiding a frame that parents secure buttons is protected in combat;
        -- reschedule so it closes once combat ends.
        if InCombatLockdown() then
            PetInfo:StartHideTimer()
            return
        end
        tooltipFrame:Hide()
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

PetInfo.settingsLabel = "Battle Pets"

function PetInfo:BuildSettingsPanel(panel)
    local W = ns.SettingsWidgets
    local r = panel.refreshCallbacks
    local db = function() return ns.db.petinfo end

    W.AddLabelEditBox(panel, "status owned total maxlevel rare favorites journal battles",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateData() end, r, {
        { "Default",     "<status>" },
        { "Collection",  "Battle Pets: <owned>/<total>" },
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
        { label = "Width", min = 200, max = 2000, step = 10,
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
        "The tooltip is a control panel (out of combat): open\n" ..
        "the journal, summon a random pet, revive, bandage,\n" ..
        "equip a Safari Hat, or use pet treats. The datatext\n" ..
        "itself also opens the journal / summons on click.")
    W.EndSection(panel, y)
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("petinfo", PetInfo, DEFAULTS)
