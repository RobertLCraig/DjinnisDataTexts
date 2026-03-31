-- Djinni's Data Texts — Bag Value
-- Estimated total value of bag contents using TSM, with vendor price fallback.
local addonName, ns = ...
local DDT = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local BagVal = {}
ns.BagVal = BagVal

-- Tooltip
local tooltipFrame = nil
local hideTimer = nil

-- Layout
local TOOLTIP_WIDTH  = 340
local ROW_HEIGHT     = 20
local HEADER_HEIGHT  = 18
local PADDING        = 10
local HINT_HEIGHT    = 18

-- State
local totalValue = 0       -- copper
local vendorValue = 0      -- copper (vendor sell total)
local itemBreakdown = {}   -- { { name, icon, value, quantity, source } } sorted by value desc
local freeSlots = 0
local totalSlots = 0
local scanPending = false
local lastScanTime = 0

-- Bag constants
local NUM_BAG_SLOTS = 4    -- bags 0-4 (0 = backpack)
local REAGENT_BAG = 5      -- Enum.BagIndex.ReagentBag

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
    labelTemplate     = "<value>",
    tsmPriceSource    = "dbmarket",  -- TSM price source label
    showTopItems      = true,
    numTopItems       = 10,
    showFreeSlots     = true,
    itemSortOrder     = "value_desc",  -- value_desc, value_asc, name, quantity_desc
    tooltipScale      = 1.0,
    tooltipWidth      = 340,
    clickActions      = {
        leftClick       = "openbags",
        rightClick      = "rescan",
        middleClick     = "none",
        shiftLeftClick  = "sortbags",
        shiftRightClick = "none",
        ctrlLeftClick   = "none",
        ctrlRightClick  = "none",
        altLeftClick    = "opensettings",
        altRightClick   = "none",
    },
    rowClickActions   = {
        leftClick       = "linkitem",
        rightClick      = "none",
        middleClick     = "none",
        shiftLeftClick  = "none",
        shiftRightClick = "none",
        ctrlLeftClick   = "none",
        ctrlRightClick  = "none",
        altLeftClick    = "none",
        altRightClick   = "none",
    },
}

local CLICK_ACTIONS = {
    openbags     = "Open Bags",
    sortbags     = "Sort Bags",
    rescan       = "Rescan Bags",
    opensettings = "Open DDT Settings",
    none         = "None",
}

local ROW_CLICK_ACTIONS = {
    linkitem     = "Link Item to Chat",
    none         = "None",
}

local TSM_SOURCE_VALUES = {
    dbmarket            = "DBMarket (Realm Market Value)",
    dbminbuyout         = "DBMinBuyout (Lowest Auction)",
    dbhistorical        = "DBHistorical (Realm Historical)",
    dbrecent            = "DBRecent (Recent Market Value)",
    dbregionmarketavg   = "DBRegionMarketAvg (Region Average)",
    dbregionhistorical  = "DBRegionHistorical (Region Historical)",
    dbregionsaleavg     = "DBRegionSaleAvg (Region Sale Average)",
}

local ITEM_SORT_VALUES = {
    value_desc    = "Value (High > Low)",
    value_asc     = "Value (Low > High)",
    name          = "Name (A-Z)",
    quantity_desc = "Quantity (High > Low)",
}

local function SortItems(list, order)
    if order == "value_asc" then
        table.sort(list, function(a, b)
            if a.value ~= b.value then return a.value < b.value end
            return a.name < b.name
        end)
    elseif order == "name" then
        table.sort(list, function(a, b) return a.name < b.name end)
    elseif order == "quantity_desc" then
        table.sort(list, function(a, b)
            if a.quantity ~= b.quantity then return a.quantity > b.quantity end
            return a.name < b.name
        end)
    else -- value_desc (default)
        table.sort(list, function(a, b)
            if a.value ~= b.value then return a.value > b.value end
            return a.name < b.name
        end)
    end
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function FormatGoldShort(copper)
    return ns.FormatGoldShort(copper)
end

local function FormatGold(copper)
    return ns.FormatGold(copper, true)
end

---------------------------------------------------------------------------
-- TSM integration
---------------------------------------------------------------------------

local function GetTSMPrice(itemLink, source)
    if not TSM_API then return nil end
    local ok, itemString = pcall(TSM_API.ToItemString, itemLink)
    if not ok or not itemString then return nil end
    local ok2, value = pcall(TSM_API.GetCustomPriceValue, source, itemString)
    if not ok2 or not value then return nil end
    return value  -- copper
end

local function GetVendorPrice(itemLink)
    if not itemLink then return 0 end
    local _, _, _, _, _, _, _, _, _, _, sellPrice = C_Item.GetItemInfo(itemLink)
    return sellPrice or 0
end

---------------------------------------------------------------------------
-- Label template expansion
---------------------------------------------------------------------------

local function ExpandLabel(template)
    local result = template
    local E = ns.ExpandTag
    result = E(result, "value", FormatGoldShort(totalValue))
    result = E(result, "vendor", FormatGoldShort(vendorValue))
    result = E(result, "free", freeSlots)
    result = E(result, "total", totalSlots)
    result = E(result, "used", totalSlots - freeSlots)
    return result
end

---------------------------------------------------------------------------
-- LDB Data Object
---------------------------------------------------------------------------

local dataobj = LDB:NewDataObject("DDT-BagValue", {
    type  = "data source",
    text  = "Bags: 0g",
    icon  = "Interface\\Icons\\INV_Misc_Bag_07_Green",
    label = "DDT - Bag Value",
    OnEnter = function(self)
        BagVal:ShowTooltip(self)
    end,
    OnLeave = function(self)
        BagVal:StartHideTimer()
    end,
    OnClick = function(self, button)
        local db = BagVal:GetDB()
        local action = DDT:ResolveClickAction(button, db.clickActions or {})
        if action == "openbags" then
            ToggleAllBags()
        elseif action == "sortbags" then
            if C_Container and C_Container.SortBags then
                C_Container.SortBags()
            elseif SortBags then
                SortBags()
            end
        elseif action == "rescan" then
            BagVal:ScanBags()
        elseif action == "opensettings" then
            if DDT.settingsCategoryID then
                Settings.OpenToCategory(DDT.settingsCategoryID)
            end
        end
    end,
})

BagVal.dataobj = dataobj

---------------------------------------------------------------------------
-- Event handling
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local scanTimer = nil
local SCAN_DELAY = 0.5  -- debounce

function BagVal:Init()
    eventFrame:SetScript("OnEvent", function(_, event)
        -- Debounce bag updates
        if scanTimer then scanTimer:Cancel() end
        scanTimer = C_Timer.NewTimer(SCAN_DELAY, function()
            scanTimer = nil
            BagVal:ScanBags()
        end)
    end)

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("BAG_UPDATE")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
end

function BagVal:GetDB()
    return ns.db and ns.db.bagvalue or DEFAULTS
end

---------------------------------------------------------------------------
-- Bag scanning
---------------------------------------------------------------------------

function BagVal:ScanBags()
    local db = self:GetDB()
    local source = db.tsmPriceSource or "dbmarket"
    local hasTSM = TSM_API ~= nil

    totalValue = 0
    vendorValue = 0
    freeSlots = 0
    totalSlots = 0
    wipe(itemBreakdown)

    local itemAccum = {}  -- [itemID] = { name, icon, totalValue, totalVendor, quantity, source }

    -- Scan bags 0 through 4 + reagent bag
    for bag = 0, REAGENT_BAG do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots and numSlots > 0 then
            totalSlots = totalSlots + numSlots
            local bagFree = C_Container.GetContainerNumFreeSlots(bag)
            freeSlots = freeSlots + (bagFree or 0)

            for slot = 1, numSlots do
                local itemID = C_Container.GetContainerItemID(bag, slot)
                if itemID then
                    local itemLink = C_Container.GetContainerItemLink(bag, slot)
                    local containerInfo = C_Container.GetContainerItemInfo(bag, slot)
                    local stackCount = containerInfo and containerInfo.stackCount or 1

                    local unitPrice = 0
                    local priceSource = "vendor"

                    if hasTSM and itemLink then
                        local tsmPrice = GetTSMPrice(itemLink, source)
                        if tsmPrice and tsmPrice > 0 then
                            unitPrice = tsmPrice
                            priceSource = "TSM"
                        end
                    end

                    local vp = 0
                    if itemLink then
                        vp = GetVendorPrice(itemLink)
                    end

                    if unitPrice == 0 and vp > 0 then
                        unitPrice = vp
                        priceSource = "vendor"
                    end

                    local lineValue = unitPrice * stackCount
                    local lineVendor = vp * stackCount
                    totalValue = totalValue + lineValue
                    vendorValue = vendorValue + lineVendor

                    -- Accumulate by itemID
                    if lineValue > 0 then
                        if not itemAccum[itemID] then
                            local itemName = containerInfo and containerInfo.itemName
                            if not itemName and itemLink then
                                itemName = C_Item.GetItemInfo(itemLink)
                            end
                            local itemIcon = containerInfo and containerInfo.iconFileID
                            itemAccum[itemID] = {
                                itemID = itemID,
                                name = itemName or ("Item " .. itemID),
                                icon = itemIcon,
                                value = 0,
                                quantity = 0,
                                source = priceSource,
                            }
                        end
                        itemAccum[itemID].value = itemAccum[itemID].value + lineValue
                        itemAccum[itemID].quantity = itemAccum[itemID].quantity + stackCount
                    end
                end
            end
        end
    end

    -- Flatten to list
    for _, data in pairs(itemAccum) do
        table.insert(itemBreakdown, data)
    end

    lastScanTime = time()

    -- Update LDB text
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
    local f = CreateFrame("Frame", "DDTBagValueTooltip", UIParent, "BackdropTemplate")
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
    f:SetScript("OnEnter", function() BagVal:CancelHideTimer() end)
    f:SetScript("OnLeave", function() BagVal:StartHideTimer() end)

    f.lines = {}
    f.rowFrames = {}
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

local function GetRowFrame(f, index)
    if f.rowFrames[index] then
        f.rowFrames[index]:Show()
        return f.rowFrames[index]
    end
    local row = CreateFrame("Button", nil, f, "BackdropTemplate")
    row:SetHeight(ROW_HEIGHT)
    row:EnableMouse(true)
    row:RegisterForClicks("AnyUp")
    row:SetScript("OnEnter", function(self)
        BagVal:CancelHideTimer()
        if self.itemData then
            self:SetBackdrop({bgFile = "Interface\\ChatFrame\\ChatFrameBackground"})
            self:SetBackdropColor(0.3, 0.3, 0.3, 0.3)
        end
    end)
    row:SetScript("OnLeave", function(self)
        BagVal:StartHideTimer()
        self:SetBackdrop(nil)
    end)
    row:SetScript("OnClick", function(self, button)
        if not self.itemData then return end
        local db = BagVal:GetDB()
        local action = DDT:ResolveClickAction(button, db.rowClickActions or {})
        BagVal:ExecuteRowAction(action, self.itemData)
    end)
    f.rowFrames[index] = row
    return row
end

local function HideRowFrames(f)
    if not f.rowFrames then return end
    for _, row in pairs(f.rowFrames) do
        row:Hide()
        row.itemData = nil
    end
end

function BagVal:ExecuteRowAction(action, item)
    if not action or action == "none" or not item then return end
    if action == "linkitem" then
        if item.itemID then
            local _, link = C_Item.GetItemInfo(item.itemID)
            if link then
                ChatFrameUtil.OpenChat(link)
                return
            end
        end
        ChatFrameUtil.OpenChat(item.name)
    end
end

local function HideLines(f)
    for _, line in pairs(f.lines) do
        line.label:Hide()
        line.value:Hide()
    end
end

function BagVal:BuildTooltipContent()
    local f = tooltipFrame
    HideLines(f)
    HideRowFrames(f)

    local db = self:GetDB()
    local hasTSM = TSM_API ~= nil

    f.title:SetText("Bag Value")

    local y = -PADDING - 20 - 6
    local lineIdx = 0

    -- Total value
    lineIdx = lineIdx + 1
    local totalLine = GetLine(f, lineIdx)
    totalLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    totalLine.label:SetText("|cffffffffEstimated Value|r")
    totalLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    totalLine.value:SetText(FormatGold(totalValue))
    totalLine.value:SetTextColor(1, 1, 1)
    y = y - ROW_HEIGHT

    -- Vendor value
    lineIdx = lineIdx + 1
    local vendLine = GetLine(f, lineIdx)
    vendLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    vendLine.label:SetText("|cffffffffVendor Value|r")
    vendLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    vendLine.value:SetText(FormatGold(vendorValue))
    vendLine.value:SetTextColor(0.6, 0.6, 0.6)
    y = y - ROW_HEIGHT

    -- Price source
    lineIdx = lineIdx + 1
    local srcLine = GetLine(f, lineIdx)
    srcLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    srcLine.label:SetText("|cffffffffPrice Source|r")
    srcLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    if hasTSM then
        srcLine.value:SetText("TSM: " .. (db.tsmPriceSource or "dbmarket"))
        srcLine.value:SetTextColor(0.0, 0.8, 0.0)
    else
        srcLine.value:SetText("Vendor (TSM not loaded)")
        srcLine.value:SetTextColor(1.0, 0.5, 0.0)
    end
    y = y - ROW_HEIGHT

    -- Bag slots
    if db.showFreeSlots then
        lineIdx = lineIdx + 1
        local slotLine = GetLine(f, lineIdx)
        slotLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        slotLine.label:SetText("|cffffffffBag Space|r")
        slotLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        slotLine.value:SetText(string.format("%d / %d free", freeSlots, totalSlots))
        if freeSlots <= 5 then
            slotLine.value:SetTextColor(1.0, 0.2, 0.2)
        elseif freeSlots <= 15 then
            slotLine.value:SetTextColor(1.0, 0.82, 0.0)
        else
            slotLine.value:SetTextColor(0.0, 1.0, 0.0)
        end
        y = y - ROW_HEIGHT
    end

    -- Top items
    if db.showTopItems and #itemBreakdown > 0 then
        local sorted = {}
        for _, item in ipairs(itemBreakdown) do
            table.insert(sorted, item)
        end
        SortItems(sorted, db.itemSortOrder)

        y = y - 4

        lineIdx = lineIdx + 1
        local itemHdr = GetLine(f, lineIdx)
        itemHdr.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        itemHdr.label:SetText("|cffffd100Top Items|r")
        itemHdr.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        itemHdr.value:SetText("")
        y = y - HEADER_HEIGHT

        local count = math.min(db.numTopItems or 10, #sorted)
        for i = 1, count do
            local item = sorted[i]
            lineIdx = lineIdx + 1
            local row = GetLine(f, lineIdx)
            row.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 6, y)

            local iconStr = ""
            if item.icon then
                iconStr = "|T" .. item.icon .. ":14:14:0:0|t "
            end
            local qtyStr = item.quantity > 1 and (" x" .. item.quantity) or ""
            row.label:SetText(iconStr .. item.name .. qtyStr)
            row.label:SetTextColor(0.8, 0.8, 0.8)

            row.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
            row.value:SetText(FormatGoldShort(item.value))
            row.value:SetTextColor(0.9, 0.82, 0.0)

            -- Clickable row overlay
            local rf = GetRowFrame(f, i)
            rf.itemData = item
            rf:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
            rf:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
            y = y - ROW_HEIGHT
        end

        if #sorted > count then
            lineIdx = lineIdx + 1
            local moreRow = GetLine(f, lineIdx)
            moreRow.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 6, y)
            moreRow.label:SetText("|cff888888... and " .. (#sorted - count) .. " more items|r")
            moreRow.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
            moreRow.value:SetText("")
            y = y - ROW_HEIGHT
        end
    end

    -- Hint
    local dtHint = DDT:BuildHintText(db.clickActions or {}, CLICK_ACTIONS)
    local rowHint = DDT:BuildHintText(db.rowClickActions or {}, ROW_CLICK_ACTIONS)
    if rowHint ~= "" then
        rowHint = "|cff888888Row: " .. rowHint:gsub("|cff888888", ""):gsub("|r$", "") .. "|r"
    end
    local combined = dtHint
    if rowHint ~= "" then
        combined = combined ~= "" and (combined .. "\n" .. rowHint) or rowHint
    end
    f.hint:SetText(combined)

    local ttWidth = db.tooltipWidth or TOOLTIP_WIDTH
    local totalHeight = math.abs(y) + PADDING + HINT_HEIGHT + 8
    f:SetSize(ttWidth, totalHeight)
end

function BagVal:ShowTooltip(anchor)
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

function BagVal:StartHideTimer()
    self:CancelHideTimer()
    hideTimer = C_Timer.NewTimer(ns.HIDE_DELAY, function()
        if tooltipFrame then tooltipFrame:Hide() end
        hideTimer = nil
    end)
end

function BagVal:CancelHideTimer()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
end

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------

BagVal.settingsLabel = "Bag Value"

function BagVal:BuildSettingsPanel(panel)
    local W = ns.SettingsWidgets
    local r = panel.refreshCallbacks
    local db = function() return ns.db.bagvalue end

    local body = W.AddSection(panel, "Label Template")
    local y = 0
    y = W.AddLabelEditBox(body, y, "value vendor free total used",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:ScanBags() end, r, {
        { "Default",    "<value>" },
        { "With Slots", "<value>  <free>/<total> free" },
        { "Vendor",     "AH: <value>  Vendor: <vendor>" },
        { "Bags Only",  "<free>/<total> slots" },
    })
    W.EndSection(panel, y)

    body = W.AddSection(panel, "Price Source")
    y = 0
    y = W.AddDropdown(body, y, "TSM Price Source", TSM_SOURCE_VALUES,
        function() return db().tsmPriceSource end,
        function(v) db().tsmPriceSource = v; self:ScanBags() end, r)
    y = W.AddDescription(body, y,
        "Requires TradeSkillMaster (TSM) to be installed.\n" ..
        "Without TSM, vendor sell prices are used as fallback.\n\n" ..
        "Future support planned: Auctionator, Auctioneer, Oribos Exchange.")
    W.EndSection(panel, y)

    body = W.AddSection(panel, "Display")
    y = 0
    y = W.AddCheckboxPair(body, y, "Show free bag slots",
        function() return db().showFreeSlots end,
        function(v) db().showFreeSlots = v end,
        "Show top items by value",
        function() return db().showTopItems end,
        function(v) db().showTopItems = v end, r)
    y = W.AddSlider(body, y, "Number of items to show", 5, 25, 1,
        function() return db().numTopItems end,
        function(v) db().numTopItems = v end, r)
    y = W.AddDropdown(body, y, "Item Sort Order", ITEM_SORT_VALUES,
        function() return db().itemSortOrder end,
        function(v) db().itemSortOrder = v end, r)
    W.EndSection(panel, y)

    body = W.AddSection(panel, "Tooltip", true)
    y = 0
    y = W.AddSliderPair(body, y,
        { label = "Scale", min = 0.5, max = 2.0, step = 0.05,
          get = function() return db().tooltipScale end,
          set = function(v) db().tooltipScale = v end },
        { label = "Width", min = 250, max = 600, step = 10,
          get = function() return db().tooltipWidth end,
          set = function(v) db().tooltipWidth = v end }, r)
    W.EndSection(panel, y)

    ns.AddModuleClickActionsSection(panel, r, "bagvalue", CLICK_ACTIONS)
    ns.AddRowClickActionsSection(panel, r, "bagvalue", ROW_CLICK_ACTIONS)
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("bagvalue", BagVal, DEFAULTS)
