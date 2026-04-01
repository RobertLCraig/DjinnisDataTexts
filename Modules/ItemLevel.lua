-- Djinni's Data Texts — Item Level
-- Equipped item level, missing enchants/gems, SimC export, shopping lists.
local addonName, ns = ...
local DDT = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local ItemLevel = {}
ns.ItemLevel = ItemLevel

-- Tooltip
local tooltipFrame = nil
local hideTimer = nil
local linePool = {}

-- Layout
local TOOLTIP_WIDTH  = 360
local ROW_HEIGHT     = 20
local HEADER_HEIGHT  = 18
local PADDING        = 10
local HINT_HEIGHT    = 18

-- State
local equippedIlvl = 0
local overallIlvl  = 0
local slotData     = {}  -- { [slot] = { link, name, ilvl, quality, hasEnchant, missingGems, numSockets } }

-- Enchantable slots in current WoW (Midnight era)
-- Back (cloak), Chest, Wrist, Legs, Feet, Rings, Weapons
local ENCHANTABLE_SLOTS = {
    [INVSLOT_BACK]     = true,
    [INVSLOT_CHEST]    = true,
    [INVSLOT_WRIST]    = true,
    [INVSLOT_LEGS]     = true,
    [INVSLOT_FEET]     = true,
    [INVSLOT_FINGER1]  = true,
    [INVSLOT_FINGER2]  = true,
    [INVSLOT_MAINHAND] = true,
    [INVSLOT_OFFHAND]  = true,
}

-- Slot display names
local SLOT_NAMES = {
    [INVSLOT_HEAD]     = "Head",
    [INVSLOT_NECK]     = "Neck",
    [INVSLOT_SHOULDER] = "Shoulder",
    [INVSLOT_BODY]     = "Shirt",
    [INVSLOT_CHEST]    = "Chest",
    [INVSLOT_WAIST]    = "Waist",
    [INVSLOT_LEGS]     = "Legs",
    [INVSLOT_FEET]     = "Feet",
    [INVSLOT_WRIST]    = "Wrist",
    [INVSLOT_HAND]     = "Hands",
    [INVSLOT_FINGER1]  = "Ring 1",
    [INVSLOT_FINGER2]  = "Ring 2",
    [INVSLOT_TRINKET1] = "Trinket 1",
    [INVSLOT_TRINKET2] = "Trinket 2",
    [INVSLOT_BACK]     = "Back",
    [INVSLOT_MAINHAND] = "Main Hand",
    [INVSLOT_OFFHAND]  = "Off Hand",
    [INVSLOT_TABARD]   = "Tabard",
}

-- Slots to scan (skip shirt and tabard for missing enhancements)
local GEAR_SLOTS = {
    INVSLOT_HEAD, INVSLOT_NECK, INVSLOT_SHOULDER, INVSLOT_CHEST,
    INVSLOT_WAIST, INVSLOT_LEGS, INVSLOT_FEET, INVSLOT_WRIST,
    INVSLOT_HAND, INVSLOT_FINGER1, INVSLOT_FINGER2,
    INVSLOT_TRINKET1, INVSLOT_TRINKET2, INVSLOT_BACK,
    INVSLOT_MAINHAND, INVSLOT_OFFHAND,
}

-- Quality colors
local QUALITY_COLORS = {
    [0] = { 0.62, 0.62, 0.62 },  -- Poor
    [1] = { 1.00, 1.00, 1.00 },  -- Common
    [2] = { 0.12, 1.00, 0.00 },  -- Uncommon
    [3] = { 0.00, 0.44, 0.87 },  -- Rare
    [4] = { 0.64, 0.21, 0.93 },  -- Epic
    [5] = { 1.00, 0.50, 0.00 },  -- Legendary
    [6] = { 0.90, 0.80, 0.50 },  -- Artifact
    [7] = { 0.00, 0.80, 1.00 },  -- Heirloom
    [8] = { 0.00, 0.80, 1.00 },  -- WoW Token
}

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
    labelTemplate   = "<ilvl>",
    showSlotDetails = true,
    showMissingEnchants = true,
    showMissingGems = true,
    tooltipScale    = 1.0,
    tooltipWidth    = 360,
    clickActions    = {
        leftClick       = "character",
        rightClick      = "copysimcstring",
        middleClick     = "none",
        shiftLeftClick  = "copyilvl",
        shiftRightClick = "none",
        ctrlLeftClick   = "auctionatorsearch",
        ctrlRightClick  = "tsmsearch",
        altLeftClick    = "opensettings",
        altRightClick   = "none",
    },
}

local CLICK_ACTIONS = {
    character        = "Character Panel",
    copysimcstring   = "Copy SimC String",
    copyilvl         = "Copy iLvl to Chat",
    auctionatorsearch = "Auctionator: Missing Enhancements",
    tsmsearch        = "TSM: Missing Enhancements",
    ahsearch         = "AH Search: Gear Upgrades",
    opensettings     = "Open DDT Settings",
    none             = "None",
}

---------------------------------------------------------------------------
-- Enchant/gem detection from item links
---------------------------------------------------------------------------

-- Parse enchantID from an item link.
-- Format: |Hitem:itemID:enchantID:gem1:gem2:gem3:gem4:...
local function GetEnchantFromLink(itemLink)
    if not itemLink then return nil end
    local enchantID = itemLink:match("|Hitem:%d+:(%d+):")
    if enchantID then
        enchantID = tonumber(enchantID)
        if enchantID and enchantID > 0 then return enchantID end
    end
    return nil
end

-- Count empty gem sockets for an item
local function GetMissingGems(itemLink)
    if not itemLink then return 0, 0 end
    -- Try C_Item API first
    if C_Item and C_Item.GetItemNumSockets then
        local numSockets = C_Item.GetItemNumSockets(itemLink)
        if numSockets and numSockets > 0 then
            local filledCount = 0
            if C_Item.GetItemGem then
                for i = 1, numSockets do
                    local gemName = C_Item.GetItemGem(itemLink, i)
                    if gemName then filledCount = filledCount + 1 end
                end
            end
            return numSockets - filledCount, numSockets
        end
        return 0, numSockets or 0
    end
    return 0, 0
end

---------------------------------------------------------------------------
-- Data scanning
---------------------------------------------------------------------------

function ItemLevel:UpdateData()
    local avgIlvl, equippedAvg = GetAverageItemLevel()
    overallIlvl  = math.floor(avgIlvl or 0)
    equippedIlvl = math.floor(equippedAvg or 0)

    wipe(slotData)

    for _, slot in ipairs(GEAR_SLOTS) do
        local itemLink = GetInventoryItemLink("player", slot)
        if itemLink then
            local itemName, _, itemQuality, itemLevel = C_Item.GetItemInfo(itemLink)
            -- Use effective item level
            local effectiveIlvl = C_Item.GetDetailedItemLevelInfo(itemLink) or itemLevel or 0
            local hasEnchant = GetEnchantFromLink(itemLink) ~= nil
            local missingGems, numSockets = GetMissingGems(itemLink)

            slotData[slot] = {
                link       = itemLink,
                name       = itemName or "Loading...",
                ilvl       = effectiveIlvl,
                quality    = itemQuality or 1,
                hasEnchant = hasEnchant,
                missingGems = missingGems,
                numSockets = numSockets,
                canEnchant = ENCHANTABLE_SLOTS[slot] == true,
            }
        end
    end

    -- Update LDB text
    local db = self:GetDB()
    dataobj.text = self:ExpandLabel(db.labelTemplate)

    -- Refresh tooltip if visible
    if tooltipFrame and tooltipFrame:IsShown() then
        self:BuildTooltipContent()
    end
end

function ItemLevel:ExpandLabel(template)
    local result = template
    local E = ns.ExpandTag
    result = E(result, "ilvl", equippedIlvl)
    result = E(result, "overall", overallIlvl)

    -- Count missing enhancements
    local missingEnchants, missingGems = 0, 0
    for _, info in pairs(slotData) do
        if info.canEnchant and not info.hasEnchant then missingEnchants = missingEnchants + 1 end
        missingGems = missingGems + info.missingGems
    end
    result = E(result, "enchants", missingEnchants)
    result = E(result, "gems", missingGems)
    return result
end

---------------------------------------------------------------------------
-- LDB Data Object
---------------------------------------------------------------------------

local dataobj = LDB:NewDataObject("DDT-ItemLevel", {
    type  = "data source",
    text  = "iLvl: 0",
    icon  = "Interface\\Icons\\INV_Misc_Gear_01",
    label = "DDT - Item Level",
    OnEnter = function(self)
        ItemLevel:ShowTooltip(self)
    end,
    OnLeave = function(self)
        ItemLevel:StartHideTimer()
    end,
    OnClick = function(self, button)
        local db = ItemLevel:GetDB()
        local action = DDT:ResolveClickAction(button, db.clickActions or {})
        if action == "character" then
            ToggleCharacter("PaperDollFrame")
        elseif action == "copysimcstring" then
            ItemLevel:CopySimCString()
        elseif action == "copyilvl" then
            ChatFrameUtil.OpenChat(tostring(equippedIlvl))
        elseif action == "auctionatorsearch" then
            ItemLevel:CreateAuctionatorShoppingList()
        elseif action == "tsmsearch" then
            ItemLevel:CreateTSMShoppingList()
        elseif action == "ahsearch" then
            ItemLevel:SearchAHForUpgrades()
        elseif action == "opensettings" then
            if DDT.settingsCategoryID then
                Settings.OpenToCategory(DDT.settingsCategoryID)
            end
        end
    end,
})

ItemLevel.dataobj = dataobj

---------------------------------------------------------------------------
-- Event handling
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local pendingItemInfoUpdate = nil  -- debounce timer for GET_ITEM_INFO_RECEIVED

function ItemLevel:Init()
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(2, function() ItemLevel:UpdateData() end)
        elseif event == "GET_ITEM_INFO_RECEIVED" then
            -- Fires for ALL items in the game; debounce to avoid spamming UpdateData
            if not pendingItemInfoUpdate then
                pendingItemInfoUpdate = C_Timer.NewTimer(0.5, function()
                    pendingItemInfoUpdate = nil
                    ItemLevel:UpdateData()
                end)
            end
        else
            ItemLevel:UpdateData()
        end
    end)
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
end

function ItemLevel:GetDB()
    return ns.db and ns.db.itemlevel or DEFAULTS
end

---------------------------------------------------------------------------
-- SimulationCraft string generation
---------------------------------------------------------------------------

function ItemLevel:CopySimCString()
    -- Check if SimulationCraft addon is loaded and has its slash command
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("SimulationCraft") then
        -- Trigger SimC's own export
        SlashCmdList["SIMULATIONCRAFT"]("")
        return
    end

    -- Fallback: generate a basic /simc-style string ourselves
    local lines = {}
    local _, classFile = UnitClass("player")
    local _, raceName = UnitRace("player")
    local specID = GetSpecialization and GetSpecialization()
    local specName = specID and select(2, GetSpecializationInfo(specID)) or "Unknown"
    local level = UnitLevel("player")
    local realmName = GetRealmName():gsub("%s", "")

    table.insert(lines, string.format("%s=%s", (classFile or "unknown"):lower(), UnitName("player")))
    table.insert(lines, string.format("level=%d", level))
    table.insert(lines, string.format("race=%s", (raceName or "unknown"):lower():gsub(" ", "_")))
    table.insert(lines, string.format("spec=%s", (specName or "unknown"):lower():gsub(" ", "_")))
    table.insert(lines, string.format("server=%s", realmName))

    -- Gear
    local slotNames = {
        [INVSLOT_HEAD]     = "head",
        [INVSLOT_NECK]     = "neck",
        [INVSLOT_SHOULDER] = "shoulder",
        [INVSLOT_BACK]     = "back",
        [INVSLOT_CHEST]    = "chest",
        [INVSLOT_WRIST]    = "wrist",
        [INVSLOT_HAND]     = "hands",
        [INVSLOT_WAIST]    = "waist",
        [INVSLOT_LEGS]     = "legs",
        [INVSLOT_FEET]     = "feet",
        [INVSLOT_FINGER1]  = "finger1",
        [INVSLOT_FINGER2]  = "finger2",
        [INVSLOT_TRINKET1] = "trinket1",
        [INVSLOT_TRINKET2] = "trinket2",
        [INVSLOT_MAINHAND] = "main_hand",
        [INVSLOT_OFFHAND]  = "off_hand",
    }

    for _, slot in ipairs(GEAR_SLOTS) do
        local itemLink = GetInventoryItemLink("player", slot)
        if itemLink and slotNames[slot] then
            -- Extract the item string from the link
            local itemString = itemLink:match("|H(item:[^|]+)|h")
            if itemString then
                table.insert(lines, string.format("%s=%s", slotNames[slot], itemString))
            end
        end
    end

    -- Copy to clipboard via an edit box
    local text = table.concat(lines, "\n")
    DDT:CopyToClipboard(text, "SimC String")
end

---------------------------------------------------------------------------
-- Auctionator / TSM shopping lists
---------------------------------------------------------------------------

function ItemLevel:GetMissingEnhancementItems()
    local items = {}

    for _, slot in ipairs(GEAR_SLOTS) do
        local info = slotData[slot]
        if info then
            -- Missing enchant
            if info.canEnchant and not info.hasEnchant then
                table.insert(items, {
                    slot = SLOT_NAMES[slot] or "?",
                    type = "enchant",
                    itemLink = info.link,
                    itemName = info.name,
                })
            end
            -- Missing gems
            if info.missingGems > 0 then
                table.insert(items, {
                    slot = SLOT_NAMES[slot] or "?",
                    type = "gem",
                    count = info.missingGems,
                    itemLink = info.link,
                    itemName = info.name,
                })
            end
        end
    end

    return items
end

function ItemLevel:CreateAuctionatorShoppingList()
    -- Check if Auctionator is loaded
    if not (Auctionator and Auctionator.API and Auctionator.API.v1) then
        DDT:Print("Auctionator is not loaded.")
        return
    end

    local missing = self:GetMissingEnhancementItems()
    if #missing == 0 then
        DDT:Print("No missing enhancements found!")
        return
    end

    -- Build search terms for Auctionator
    local searchTerms = {}
    for _, item in ipairs(missing) do
        if item.type == "enchant" then
            table.insert(searchTerms, "Enchant " .. item.slot)
        elseif item.type == "gem" then
            table.insert(searchTerms, "Gem")
        end
    end

    -- Try to create/update shopping list
    local listName = "DDT - Missing Enhancements"
    local ok, err = pcall(function()
        Auctionator.API.v1.CreateShoppingList("DjinnisDataTexts", listName, searchTerms)
    end)

    if ok then
        DDT:Print("Auctionator shopping list '" .. listName .. "' created with " .. #searchTerms .. " items.")
    else
        DDT:Print("Failed to create Auctionator list: " .. tostring(err))
    end
end

function ItemLevel:CreateTSMShoppingList()
    local TSM_API = _G.TSM_API
    if not TSM_API then
        DDT:Print("TradeSkillMaster is not loaded.")
        return
    end

    local missing = self:GetMissingEnhancementItems()
    if #missing == 0 then
        DDT:Print("No missing enhancements found!")
        return
    end

    -- TSM doesn't have a direct shopping list creation API.
    -- Copy a search string to clipboard that the user can paste into TSM search.
    local searchParts = {}
    for _, item in ipairs(missing) do
        if item.type == "enchant" then
            table.insert(searchParts, "Enchant " .. item.slot)
        elseif item.type == "gem" then
            table.insert(searchParts, "Gem")
        end
    end

    local searchStr = table.concat(searchParts, "; ")
    DDT:CopyToClipboard(searchStr, "TSM Search")
end

function ItemLevel:SearchAHForUpgrades()
    -- Find the lowest ilvl equipped slot (excluding shirt/tabard)
    local lowestSlot, lowestIlvl = nil, 99999
    for _, slot in ipairs(GEAR_SLOTS) do
        local info = slotData[slot]
        if info and info.ilvl < lowestIlvl then
            lowestIlvl = info.ilvl
            lowestSlot = slot
        end
    end

    if not lowestSlot then
        DDT:Print("No gear found to search upgrades for.")
        return
    end

    -- Try to open the AH with a search if the player is at one
    if AuctionHouseFrame and AuctionHouseFrame:IsShown() then
        -- If AH is open, search for items in the weakest slot's equipment type
        local info = slotData[lowestSlot]
        if info and info.link then
            local _, _, _, _, _, itemType, itemSubType = C_Item.GetItemInfo(info.link)
            if itemSubType then
                -- Use AH search with the sub type
                if AuctionHouseFrame.SearchBar and AuctionHouseFrame.SearchBar.SearchBox then
                    AuctionHouseFrame.SearchBar.SearchBox:SetText(itemSubType)
                    AuctionHouseFrame.SearchBar.SearchButton:Click()
                end
            end
        end
    else
        -- AH not open: show the weakest slots so the user knows what to look for
        local weakSlots = {}
        -- Gather the 3 weakest slots
        local sorted = {}
        for _, slot in ipairs(GEAR_SLOTS) do
            local info = slotData[slot]
            if info then table.insert(sorted, { slot = slot, ilvl = info.ilvl, name = SLOT_NAMES[slot] or "?" }) end
        end
        table.sort(sorted, function(a, b) return a.ilvl < b.ilvl end)
        for i = 1, math.min(3, #sorted) do
            table.insert(weakSlots, string.format("%s (ilvl %d)", sorted[i].name, sorted[i].ilvl))
        end

        DDT:Print("Weakest slots: " .. table.concat(weakSlots, ", ") .. ". Visit the AH to search for upgrades.")
    end
end

---------------------------------------------------------------------------
-- Tooltip frame
---------------------------------------------------------------------------

local function CreateTooltipFrame()
    local f = CreateFrame("Frame", "DDTItemLevelTooltip", UIParent, "BackdropTemplate")
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

    -- Title
    f.title = f:CreateFontString(nil, "OVERLAY", "DDTFontHeader")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, -PADDING)
    f.title:SetTextColor(1, 0.82, 0)

    -- Title separator
    f.titleSep = f:CreateTexture(nil, "ARTWORK")
    f.titleSep:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
    f.titleSep:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)
    f.titleSep:SetHeight(1)
    f.titleSep:SetColorTexture(0.5, 0.5, 0.5, 0.5)

    -- Hint bar
    f.hint = f:CreateFontString(nil, "OVERLAY", "DDTFontSmall")
    f.hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PADDING, 8)
    f.hint:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PADDING, 8)
    f.hint:SetJustifyH("CENTER")
    f.hint:SetTextColor(0.53, 0.53, 0.53)

    -- Mouse interaction
    f:EnableMouse(true)
    f:SetScript("OnEnter", function() ItemLevel:CancelHideTimer() end)
    f:SetScript("OnLeave", function() ItemLevel:StartHideTimer() end)

    return f
end

---------------------------------------------------------------------------
-- Line pool
---------------------------------------------------------------------------

local function GetLine(parent, index)
    if linePool[index] then
        linePool[index].frame:Show()
        return linePool[index]
    end

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(ROW_HEIGHT)
    frame:EnableMouse(true)

    local highlight = frame:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.06)

    local label = frame:CreateFontString(nil, "OVERLAY", "DDTFontNormal")
    label:SetPoint("LEFT", frame, "LEFT", 6, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)

    local value = frame:CreateFontString(nil, "OVERLAY", "DDTFontNormal")
    value:SetPoint("RIGHT", frame, "RIGHT", -6, 0)
    value:SetJustifyH("RIGHT")

    -- Status indicators
    local status = frame:CreateFontString(nil, "OVERLAY", "DDTFontSmall")
    status:SetPoint("RIGHT", value, "LEFT", -8, 0)
    status:SetJustifyH("RIGHT")

    frame:SetScript("OnEnter", function(self)
        ItemLevel:CancelHideTimer()
    end)
    frame:SetScript("OnLeave", function(self)
        ItemLevel:StartHideTimer()
    end)

    local line = { frame = frame, label = label, value = value, status = status, highlight = highlight }
    linePool[index] = line
    return line
end

local function HideAllLines()
    for _, line in pairs(linePool) do line.frame:Hide() end
end

---------------------------------------------------------------------------
-- Tooltip content
---------------------------------------------------------------------------

function ItemLevel:BuildTooltipContent()
    HideAllLines()

    local f = tooltipFrame
    local db = self:GetDB()
    f.title:SetText("Item Level")

    local lineIdx = 0
    local y = -PADDING - 20 - 6

    -- Summary: Equipped iLvl
    lineIdx = lineIdx + 1
    local summaryLine = GetLine(f, lineIdx)
    summaryLine.frame:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    summaryLine.frame:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)
    summaryLine.label:SetText("|cffffffffEquipped Item Level|r")
    summaryLine.value:SetText("|cff00cc00" .. equippedIlvl .. "|r")
    summaryLine.status:SetText("")
    summaryLine.frame:SetScript("OnClick", nil)
    y = y - ROW_HEIGHT

    if overallIlvl ~= equippedIlvl then
        lineIdx = lineIdx + 1
        local overallLine = GetLine(f, lineIdx)
        overallLine.frame:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        overallLine.frame:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)
        overallLine.label:SetText("|cffffffffOverall Item Level|r")
        overallLine.value:SetText("|cff888888" .. overallIlvl .. "|r")
        overallLine.status:SetText("")
        overallLine.frame:SetScript("OnClick", nil)
        y = y - ROW_HEIGHT
    end

    -- Slot details
    if db.showSlotDetails ~= false then
        y = y - 4

        -- Count missing enhancements
        local missingEnchants = {}
        local missingGems = {}
        for _, slot in ipairs(GEAR_SLOTS) do
            local info = slotData[slot]
            if info then
                if info.canEnchant and not info.hasEnchant then
                    table.insert(missingEnchants, slot)
                end
                if info.missingGems > 0 then
                    table.insert(missingGems, slot)
                end
            end
        end

        -- Per-slot item level breakdown
        for _, slot in ipairs(GEAR_SLOTS) do
            local info = slotData[slot]
            if info then
                lineIdx = lineIdx + 1
                local line = GetLine(f, lineIdx)
                line.frame:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
                line.frame:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)

                local slotName = SLOT_NAMES[slot] or "?"
                local qc = QUALITY_COLORS[info.quality] or QUALITY_COLORS[1]

                line.label:SetText(string.format("|cff%02x%02x%02x%s|r", qc[1]*255, qc[2]*255, qc[3]*255, slotName))

                -- iLvl value
                line.value:SetText(tostring(info.ilvl))
                line.value:SetTextColor(0.9, 0.9, 0.9)

                -- Status: show warnings for missing enhancements
                local statusParts = {}
                if db.showMissingEnchants ~= false and info.canEnchant and not info.hasEnchant then
                    table.insert(statusParts, "|cffcc0000No Enchant|r")
                end
                if db.showMissingGems ~= false and info.missingGems > 0 then
                    table.insert(statusParts, "|cffcc0000" .. info.missingGems .. " Empty Socket" .. (info.missingGems > 1 and "s" or "") .. "|r")
                end
                line.status:SetText(table.concat(statusParts, " "))

                -- Hover to show item tooltip
                local capturedLink = info.link
                line.frame:SetScript("OnEnter", function(self)
                    ItemLevel:CancelHideTimer()
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink(capturedLink)
                    GameTooltip:Show()
                end)
                line.frame:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                    ItemLevel:StartHideTimer()
                end)

                y = y - ROW_HEIGHT
            end
        end

        -- Missing enhancements summary
        if db.showMissingEnchants ~= false and #missingEnchants > 0 then
            y = y - 4
            lineIdx = lineIdx + 1
            local enchLine = GetLine(f, lineIdx)
            enchLine.frame:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
            enchLine.frame:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)
            enchLine.label:SetText("|cffcc0000Missing Enchants: " .. #missingEnchants .. "|r")
            local slotList = {}
            for _, slot in ipairs(missingEnchants) do
                table.insert(slotList, SLOT_NAMES[slot] or "?")
            end
            enchLine.value:SetText("|cff888888" .. table.concat(slotList, ", ") .. "|r")
            enchLine.status:SetText("")
            enchLine.frame:SetScript("OnClick", nil)
            enchLine.frame:SetScript("OnEnter", function() ItemLevel:CancelHideTimer() end)
            enchLine.frame:SetScript("OnLeave", function() ItemLevel:StartHideTimer() end)
            y = y - ROW_HEIGHT
        end

        if db.showMissingGems ~= false and #missingGems > 0 then
            lineIdx = lineIdx + 1
            local gemLine = GetLine(f, lineIdx)
            gemLine.frame:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
            gemLine.frame:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)
            local totalMissing = 0
            for _, slot in ipairs(missingGems) do totalMissing = totalMissing + slotData[slot].missingGems end
            gemLine.label:SetText("|cffcc0000Missing Gems: " .. totalMissing .. "|r")
            local slotList = {}
            for _, slot in ipairs(missingGems) do
                table.insert(slotList, SLOT_NAMES[slot] or "?")
            end
            gemLine.value:SetText("|cff888888" .. table.concat(slotList, ", ") .. "|r")
            gemLine.status:SetText("")
            gemLine.frame:SetScript("OnClick", nil)
            gemLine.frame:SetScript("OnEnter", function() ItemLevel:CancelHideTimer() end)
            gemLine.frame:SetScript("OnLeave", function() ItemLevel:StartHideTimer() end)
            y = y - ROW_HEIGHT
        end
    end

    -- Hint bar
    local hintParts = DDT:BuildHintText(db.clickActions or {}, CLICK_ACTIONS)
    f.hint:SetText(hintParts)

    -- Size
    local ttWidth = db.tooltipWidth or TOOLTIP_WIDTH
    local totalHeight = math.abs(y) + PADDING + HINT_HEIGHT + 4
    f:SetSize(ttWidth, totalHeight)
end

---------------------------------------------------------------------------
-- Tooltip show/hide
---------------------------------------------------------------------------

function ItemLevel:ShowTooltip(anchor)
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

function ItemLevel:StartHideTimer()
    self:CancelHideTimer()
    hideTimer = C_Timer.NewTimer(ns.HIDE_DELAY, function()
        if tooltipFrame then tooltipFrame:Hide() end
        hideTimer = nil
    end)
end

function ItemLevel:CancelHideTimer()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
end

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------

ItemLevel.settingsLabel = "Item Level"

function ItemLevel:BuildSettingsPanel(panel)
    local W = ns.SettingsWidgets
    local r = panel.refreshCallbacks
    local db = function() return ns.db.itemlevel end
    local refreshTT = function()
        if tooltipFrame and tooltipFrame:IsShown() then self:BuildTooltipContent() end
    end

    local body = W.AddSection(panel, "Label Template")
    local y = 0
    y = W.AddLabelEditBox(body, y, "ilvl overall enchants gems",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateData() end, r, {
        { "Default",      "<ilvl>" },
        { "With Overall", "<ilvl> (<overall>)" },
        { "Warnings",     "<ilvl>  E:<enchants> G:<gems>" },
    })
    W.EndSection(panel, y)

    body = W.AddSection(panel, "Display")
    y = 0
    y = W.AddCheckbox(body, y, "Show per-slot item level breakdown",
        function() return db().showSlotDetails ~= false end,
        function(v) db().showSlotDetails = v; refreshTT() end, r)
    y = W.AddCheckboxPair(body, y,
        "Show missing enchants",
        function() return db().showMissingEnchants ~= false end,
        function(v) db().showMissingEnchants = v; refreshTT() end,
        "Show missing gems",
        function() return db().showMissingGems ~= false end,
        function(v) db().showMissingGems = v; refreshTT() end, r)
    W.EndSection(panel, y)

    body = W.AddSection(panel, "Integrations")
    y = 0
    y = W.AddDescription(body, y,
        "SimulationCraft: If the SimC addon is installed, Right-Click\n" ..
        "opens its export UI. Otherwise, a basic string is generated\n" ..
        "and copied to your clipboard.")
    y = W.AddDescription(body, y,
        "Auctionator / TSM: Ctrl-Click creates a shopping list or\n" ..
        "copies search terms for missing enhancements.")
    W.EndSection(panel, y)

    body = W.AddSection(panel, "Tooltip", true)
    y = 0
    y = W.AddSliderPair(body, y,
        { label = "Scale", min = 0.5, max = 2.0, step = 0.05,
          get = function() return db().tooltipScale end,
          set = function(v) db().tooltipScale = v end },
        { label = "Width", min = 300, max = 600, step = 10,
          get = function() return db().tooltipWidth end,
          set = function(v) db().tooltipWidth = v; refreshTT() end }, r)
    W.EndSection(panel, y)

    ns.AddModuleClickActionsSection(panel, r, "itemlevel", CLICK_ACTIONS,
        "Hover a slot row to see full item tooltip.")
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("itemlevel", ItemLevel, DEFAULTS)
