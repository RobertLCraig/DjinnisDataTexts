-- Djinni's Data Texts — Currency / Gold
-- Character gold, alt gold totals, session tracking, tracked currencies,
-- expansion-grouped currency list, and WoW Token price.
local addonName, ns = ...
local DDT = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local Currency = {}
ns.Currency = Currency

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
local currentGold = 0       -- copper
local sessionStart = 0      -- copper at login
local sessionChange = 0     -- copper gained/lost this session
local tokenPrice = nil      -- copper or nil
local currencyList = {}     -- { { name, quantity, iconFileID, maxQuantity, isHeader, currencyID, ... } }
local warbankGold = 0       -- copper (warband bank)
local warbankEnabled = nil  -- bool or nil
local warbankLock = nil     -- bool or nil (true = this client has access)
local postedAuctionCount = 0
local postedAuctionValue = 0   -- copper
local atAuctionHouse = false

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
    labelTemplate      = "<gold>",
    showTokenPrice     = true,
    showSessionChange  = true,
    showAltGold        = true,
    showWarbankGold    = true,
    showPostedAuctions = true,
    showCurrencies     = true,
    maxCurrencies      = 15,
    currencySortOrder  = "list",  -- list, name, quantity_desc, quantity_asc
    tooltipScale       = 1.0,
    tooltipWidth       = 340,
    clickActions       = {
        leftClick       = "currency",
        rightClick      = "refresh",
        middleClick     = "none",
        shiftLeftClick  = "copygold",
        shiftRightClick = "none",
        ctrlLeftClick   = "trackcurrency",
        ctrlRightClick  = "none",
        altLeftClick    = "opensettings",
        altRightClick   = "none",
    },
    rowClickActions    = {
        leftClick       = "linkcurrency",
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
    currency       = "Currency Tab",
    trackcurrency  = "Track Currencies (Backpack)",
    copygold       = "Copy Gold to Chat",
    refresh        = "Refresh Data",
    opensettings   = "Open DDT Settings",
    none           = "None",
}

local ROW_CLICK_ACTIONS = {
    linkcurrency = "Link to Chat",
    opencurrency = "Open Currency Tab",
    none         = "None",
}

local CURRENCY_SORT_VALUES = {
    list          = "Currency Tab Order",
    name          = "Name (A-Z)",
    quantity_desc = "Quantity (High > Low)",
    quantity_asc  = "Quantity (Low > High)",
}

local function SortCurrencies(list, order)
    if order == "name" then
        table.sort(list, function(a, b) return a.name < b.name end)
    elseif order == "quantity_desc" then
        table.sort(list, function(a, b)
            if a.quantity ~= b.quantity then return a.quantity > b.quantity end
            return a.name < b.name
        end)
    elseif order == "quantity_asc" then
        table.sort(list, function(a, b)
            if a.quantity ~= b.quantity then return a.quantity < b.quantity end
            return a.name < b.name
        end)
    end
    -- "list" = no sort, preserve API order
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function FormatGold(copper, colorize)
    return ns.FormatGold(copper, colorize)
end

local function FormatGoldShort(copper)
    return ns.FormatGoldShort(copper)
end

local function FormatQuantity(quantity, maxQuantity)
    return ns.FormatQuantity(quantity, maxQuantity)
end

---------------------------------------------------------------------------
-- Label template expansion
---------------------------------------------------------------------------

local function ExpandLabel(template)
    local result = template
    local E = ns.ExpandTag
    result = E(result, "gold", FormatGoldShort(currentGold))
    result = E(result, "session", FormatGoldShort(sessionChange))
    result = E(result, "token", tokenPrice and FormatGoldShort(tokenPrice) or "N/A")
    result = E(result, "warbank", FormatGoldShort(warbankGold))
    result = E(result, "auctions", postedAuctionCount)
    return result
end

---------------------------------------------------------------------------
-- LDB Data Object
---------------------------------------------------------------------------

local dataobj = LDB:NewDataObject("DDT-Currency", {
    type  = "data source",
    text  = "0g",
    icon  = "Interface\\Icons\\INV_Misc_Coin_01",
    label = "DDT - Currency",
    OnEnter = function(self)
        Currency:ShowTooltip(self)
    end,
    OnLeave = function(self)
        Currency:StartHideTimer()
    end,
    OnClick = function(self, button)
        local db = Currency:GetDB()
        local action = DDT:ResolveClickAction(button, db.clickActions or {})
        if action == "currency" then
            ToggleCharacter("TokenFrame")
        elseif action == "trackcurrency" then
            ToggleAllBags()
        elseif action == "copygold" then
            local FormatGoldShort = ns.FormatGoldShort
            ChatFrameUtil.OpenChat(FormatGoldShort(currentGold))
        elseif action == "refresh" then
            Currency:UpdateData()
        elseif action == "opensettings" then
            if DDT.settingsCategoryID then
                Settings.OpenToCategory(DDT.settingsCategoryID)
            end
        end
    end,
})

Currency.dataobj = dataobj

---------------------------------------------------------------------------
-- Alt gold tracking (persisted in SavedVariables)
---------------------------------------------------------------------------

local function GetCharKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "Unknown"
    return name .. "-" .. realm
end

local function SaveCharGold()
    if not ns.db then return end
    if not ns.db.currency then return end
    if not ns.db.currency._altGold then
        ns.db.currency._altGold = {}
    end
    local key = GetCharKey()
    local _, className = UnitClass("player")
    ns.db.currency._altGold[key] = {
        gold = currentGold,
        class = className,
        lastSeen = time(),
    }
end

local function GetAltGold()
    if not ns.db or not ns.db.currency or not ns.db.currency._altGold then
        return {}
    end
    local currentKey = GetCharKey()
    local alts = {}
    for key, data in pairs(ns.db.currency._altGold) do
        if key ~= currentKey then
            local name = key:match("^(.+)-")
            table.insert(alts, {
                name = name or key,
                fullName = key,
                gold = data.gold or 0,
                class = data.class,
            })
        end
    end
    table.sort(alts, function(a, b)
        if a.gold ~= b.gold then return a.gold > b.gold end
        return a.name < b.name
    end)
    return alts
end

---------------------------------------------------------------------------
-- Currency scanning
---------------------------------------------------------------------------

local function ScanCurrencies()
    wipe(currencyList)
    local size = C_CurrencyInfo.GetCurrencyListSize()
    local currentHeader = nil

    for i = 1, size do
        local info = C_CurrencyInfo.GetCurrencyListInfo(i)
        if info then
            if info.isHeader then
                currentHeader = info.name
            elseif info.name and info.discovered and info.quantity > 0 then
                table.insert(currencyList, {
                    name = info.name,
                    quantity = info.quantity,
                    maxQuantity = info.maxQuantity or 0,
                    iconFileID = info.iconFileID,
                    currencyID = info.currencyID,
                    header = currentHeader,
                    quality = info.quality,
                })
            end
        end
    end
end

---------------------------------------------------------------------------
-- Event handling
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

function Currency:Init()
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            currentGold = GetMoney()
            sessionStart = currentGold
            sessionChange = 0
            SaveCharGold()
            Currency:UpdateWarbankInfo()
            self:UpdateData()

            -- Request WoW Token price
            if C_WowTokenPublic and C_WowTokenPublic.UpdateMarketPrice then
                C_WowTokenPublic.UpdateMarketPrice()
            end
        elseif event == "PLAYER_MONEY" then
            currentGold = GetMoney()
            sessionChange = currentGold - sessionStart
            SaveCharGold()
            self:UpdateData()
        elseif event == "ACCOUNT_MONEY" then
            Currency:UpdateWarbankInfo()
            self:UpdateData()
        elseif event == "TOKEN_MARKET_PRICE_UPDATED" then
            if C_WowTokenPublic and C_WowTokenPublic.GetCurrentMarketPrice then
                tokenPrice = C_WowTokenPublic.GetCurrentMarketPrice() or nil
            end
            self:UpdateData()
        elseif event == "CURRENCY_DISPLAY_UPDATE" then
            ScanCurrencies()
            self:UpdateData()
        elseif event == "AUCTION_HOUSE_SHOW" then
            atAuctionHouse = true
            Currency:QueryOwnedAuctions()
        elseif event == "AUCTION_HOUSE_CLOSED" then
            atAuctionHouse = false
        elseif event == "OWNED_AUCTIONS_UPDATED" then
            Currency:ScanOwnedAuctions()
            self:UpdateData()
        end
    end)

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_MONEY")
    eventFrame:RegisterEvent("ACCOUNT_MONEY")
    eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
    eventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
    eventFrame:RegisterEvent("OWNED_AUCTIONS_UPDATED")

    if C_WowTokenPublic then
        eventFrame:RegisterEvent("TOKEN_MARKET_PRICE_UPDATED")
    end

    -- Hook auction posting to track immediately
    if C_AuctionHouse then
        if C_AuctionHouse.PostCommodity then
            hooksecurefunc(C_AuctionHouse, "PostCommodity", function()
                postedAuctionCount = postedAuctionCount + 1
            end)
        end
        if C_AuctionHouse.PostItem then
            hooksecurefunc(C_AuctionHouse, "PostItem", function()
                postedAuctionCount = postedAuctionCount + 1
            end)
        end
    end

    -- Load cached auction data
    if ns.db and ns.db.currency and ns.db.currency._postedAuctions then
        local cached = ns.db.currency._postedAuctions
        postedAuctionCount = cached.count or 0
        postedAuctionValue = cached.value or 0
    end

    -- Poll token price every 60s
    if C_WowTokenPublic and C_WowTokenPublic.UpdateMarketPrice then
        C_Timer.NewTicker(60, function()
            C_WowTokenPublic.UpdateMarketPrice()
        end)
    end
end

function Currency:GetDB()
    return ns.db and ns.db.currency or DEFAULTS
end

---------------------------------------------------------------------------
-- Warband bank
---------------------------------------------------------------------------

function Currency:UpdateWarbankInfo()
    -- Feature enabled?
    if C_PlayerInfo and C_PlayerInfo.IsAccountBankEnabled then
        warbankEnabled = C_PlayerInfo.IsAccountBankEnabled()
    end
    -- Lock status (true = this client has access)
    if C_PlayerInfo and C_PlayerInfo.HasAccountInventoryLock then
        warbankLock = C_PlayerInfo.HasAccountInventoryLock()
    end
    -- Gold (works anytime)
    if C_Bank and C_Bank.FetchDepositedMoney and Enum and Enum.BankType then
        local ok, gold = pcall(C_Bank.FetchDepositedMoney, Enum.BankType.Account)
        if ok and gold then
            warbankGold = gold
        end
    end
end

---------------------------------------------------------------------------
-- Posted auctions
---------------------------------------------------------------------------

function Currency:QueryOwnedAuctions()
    if C_AuctionHouse and C_AuctionHouse.QueryOwnedAuctions then
        C_AuctionHouse.QueryOwnedAuctions({})
    end
end

function Currency:ScanOwnedAuctions()
    if not C_AuctionHouse then return end
    postedAuctionCount = 0
    postedAuctionValue = 0

    local auctions = C_AuctionHouse.GetOwnedAuctions and C_AuctionHouse.GetOwnedAuctions()
    if auctions then
        for _, auction in ipairs(auctions) do
            if auction.status == Enum.AuctionStatus.Active then
                postedAuctionCount = postedAuctionCount + 1
                local value = auction.buyoutAmount or auction.bidAmount or 0
                if auction.quantity and auction.quantity > 0 and auction.itemKey and auction.itemKey.isCommodity then
                    -- Commodity: buyout is per-unit
                    value = value * auction.quantity
                end
                postedAuctionValue = postedAuctionValue + value
            end
        end
    end

    -- Cache to SavedVariables
    if ns.db and ns.db.currency then
        ns.db.currency._postedAuctions = {
            count = postedAuctionCount,
            value = postedAuctionValue,
            lastScan = time(),
        }
    end
end

---------------------------------------------------------------------------
-- Data update
---------------------------------------------------------------------------

function Currency:UpdateData()
    currentGold = GetMoney()

    -- Scan currencies if not yet done
    if #currencyList == 0 then
        ScanCurrencies()
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
    local f = CreateFrame("Frame", "DDTCurrencyTooltip", UIParent, "BackdropTemplate")
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
    f:SetScript("OnEnter", function() Currency:CancelHideTimer() end)
    f:SetScript("OnLeave", function() Currency:StartHideTimer() end)

    f.lines = {}
    f.rowFrames = {}
    return f
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
        Currency:CancelHideTimer()
        if self.currencyData then
            self:SetBackdrop({bgFile = "Interface\\ChatFrame\\ChatFrameBackground"})
            self:SetBackdropColor(0.3, 0.3, 0.3, 0.3)
        end
    end)
    row:SetScript("OnLeave", function(self)
        Currency:StartHideTimer()
        self:SetBackdrop(nil)
    end)
    row:SetScript("OnClick", function(self, button)
        if not self.currencyData then return end
        local db = Currency:GetDB()
        local action = DDT:ResolveClickAction(button, db.rowClickActions or {})
        Currency:ExecuteRowAction(action, self.currencyData)
    end)
    f.rowFrames[index] = row
    return row
end

local function HideRowFrames(f)
    if not f.rowFrames then return end
    for _, row in pairs(f.rowFrames) do
        row:Hide()
        row.currencyData = nil
    end
end

function Currency:ExecuteRowAction(action, cur)
    if not action or action == "none" or not cur then return end
    if action == "linkcurrency" then
        if cur.currencyID then
            local link = C_CurrencyInfo.GetCurrencyLink(cur.currencyID)
            if link then
                ChatFrameUtil.OpenChat(link)
            else
                ChatFrameUtil.OpenChat(cur.name)
            end
        end
    elseif action == "opencurrency" then
        ToggleCharacter("TokenFrame")
    end
end

local function GetLine(f, index)
    if f.lines[index] then
        f.lines[index].label:Show()
        f.lines[index].value:Show()
        if f.lines[index].icon then f.lines[index].icon:Show() end
        return f.lines[index]
    end

    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(14, 14)

    local label = f:CreateFontString(nil, "OVERLAY", "DDTFontNormal")
    label:SetJustifyH("LEFT")

    local value = f:CreateFontString(nil, "OVERLAY", "DDTFontNormal")
    value:SetJustifyH("RIGHT")

    f.lines[index] = { label = label, value = value, icon = icon }
    return f.lines[index]
end

local function HideLines(f)
    for _, line in pairs(f.lines) do
        line.label:Hide()
        line.value:Hide()
        if line.icon then line.icon:Hide() end
    end
end

function Currency:BuildTooltipContent()
    local f = tooltipFrame
    HideLines(f)
    HideRowFrames(f)

    local db = self:GetDB()

    f.title:SetText("Currency")

    local y = -PADDING - 20 - 6
    local lineIdx = 0

    -- Current character gold
    lineIdx = lineIdx + 1
    local goldLine = GetLine(f, lineIdx)
    goldLine.icon:Hide()
    goldLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    goldLine.label:SetText("|cffffffffGold|r")
    goldLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    goldLine.value:SetText(FormatGold(currentGold, true))
    goldLine.value:SetTextColor(1, 1, 1)
    y = y - ROW_HEIGHT

    -- Session change
    if db.showSessionChange then
        lineIdx = lineIdx + 1
        local sessLine = GetLine(f, lineIdx)
        sessLine.icon:Hide()
        sessLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        sessLine.label:SetText("|cffffffffSession|r")
        sessLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        sessLine.value:SetText(FormatGold(sessionChange))
        if sessionChange > 0 then
            sessLine.value:SetTextColor(0.0, 1.0, 0.0)
        elseif sessionChange < 0 then
            sessLine.value:SetTextColor(1.0, 0.2, 0.2)
        else
            sessLine.value:SetTextColor(0.5, 0.5, 0.5)
        end
        y = y - ROW_HEIGHT
    end

    -- WoW Token price
    if db.showTokenPrice then
        lineIdx = lineIdx + 1
        local tokLine = GetLine(f, lineIdx)
        tokLine.icon:Hide()
        tokLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        tokLine.label:SetText("|cffffffffWoW Token|r")
        tokLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        if tokenPrice and tokenPrice > 0 then
            tokLine.value:SetText(FormatGold(tokenPrice))
            tokLine.value:SetTextColor(0.0, 0.8, 1.0)
        else
            tokLine.value:SetText("Unavailable")
            tokLine.value:SetTextColor(0.5, 0.5, 0.5)
        end
        y = y - ROW_HEIGHT
    end

    -- Alt gold
    if db.showAltGold then
        local alts = GetAltGold()
        if #alts > 0 then
            y = y - 4

            lineIdx = lineIdx + 1
            local altHdr = GetLine(f, lineIdx)
            altHdr.icon:Hide()
            altHdr.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
            altHdr.label:SetText("|cffffd100Alt Characters|r")
            altHdr.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
            altHdr.value:SetText("")
            y = y - HEADER_HEIGHT

            local totalAltGold = 0
            for _, alt in ipairs(alts) do
                lineIdx = lineIdx + 1
                local row = GetLine(f, lineIdx)
                row.icon:Hide()
                row.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 6, y)

                local nameText = alt.name
                if alt.class then
                    local r, g, b = DDT:GetClassColor(alt.class)
                    nameText = DDT:ColorText(alt.name, r, g, b)
                end
                row.label:SetText(nameText)
                row.label:SetTextColor(0.9, 0.9, 0.9)
                row.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
                row.value:SetText(FormatGoldShort(alt.gold))
                row.value:SetTextColor(0.9, 0.82, 0.0)
                totalAltGold = totalAltGold + alt.gold
                y = y - ROW_HEIGHT
            end

            -- Total line
            lineIdx = lineIdx + 1
            local totalLine = GetLine(f, lineIdx)
            totalLine.icon:Hide()
            totalLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 6, y)
            totalLine.label:SetText("|cffffffffTotal (all chars)|r")
            totalLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
            totalLine.value:SetText(FormatGoldShort(currentGold + totalAltGold))
            totalLine.value:SetTextColor(1.0, 0.82, 0.0)
            y = y - ROW_HEIGHT
        end
    end

    -- Warband bank
    if db.showWarbankGold then
        y = y - 4

        lineIdx = lineIdx + 1
        local wbHdr = GetLine(f, lineIdx)
        wbHdr.icon:Hide()
        wbHdr.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        wbHdr.label:SetText("|cffffd100Warband Bank|r")
        wbHdr.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        wbHdr.value:SetText("")
        y = y - HEADER_HEIGHT

        -- Warband gold
        lineIdx = lineIdx + 1
        local wbGoldLine = GetLine(f, lineIdx)
        wbGoldLine.icon:Hide()
        wbGoldLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 6, y)
        wbGoldLine.label:SetText("|cffffffffGold|r")
        wbGoldLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        wbGoldLine.value:SetText(FormatGoldShort(warbankGold))
        wbGoldLine.value:SetTextColor(0.9, 0.82, 0.0)
        y = y - ROW_HEIGHT

        -- Access status
        lineIdx = lineIdx + 1
        local wbAccLine = GetLine(f, lineIdx)
        wbAccLine.icon:Hide()
        wbAccLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 6, y)
        wbAccLine.label:SetText("|cffffffffAccess|r")
        wbAccLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        if warbankEnabled == false then
            wbAccLine.value:SetText("Not Available")
            wbAccLine.value:SetTextColor(0.5, 0.5, 0.5)
        elseif warbankLock == true then
            wbAccLine.value:SetText("Available")
            wbAccLine.value:SetTextColor(0.0, 1.0, 0.0)
        elseif warbankLock == false then
            wbAccLine.value:SetText("Locked (another session)")
            wbAccLine.value:SetTextColor(1.0, 0.2, 0.2)
        else
            wbAccLine.value:SetText("Unknown")
            wbAccLine.value:SetTextColor(0.5, 0.5, 0.5)
        end
        y = y - ROW_HEIGHT
    end

    -- Posted auctions
    if db.showPostedAuctions and postedAuctionCount > 0 then
        y = y - 4

        lineIdx = lineIdx + 1
        local ahHdr = GetLine(f, lineIdx)
        ahHdr.icon:Hide()
        ahHdr.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        ahHdr.label:SetText("|cffffd100Posted Auctions|r")
        ahHdr.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        ahHdr.value:SetText("")
        y = y - HEADER_HEIGHT

        lineIdx = lineIdx + 1
        local ahCountLine = GetLine(f, lineIdx)
        ahCountLine.icon:Hide()
        ahCountLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 6, y)
        ahCountLine.label:SetText("|cffffffffListings|r")
        ahCountLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        ahCountLine.value:SetText(tostring(postedAuctionCount))
        ahCountLine.value:SetTextColor(0.9, 0.9, 0.9)
        y = y - ROW_HEIGHT

        if postedAuctionValue > 0 then
            lineIdx = lineIdx + 1
            local ahValLine = GetLine(f, lineIdx)
            ahValLine.icon:Hide()
            ahValLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 6, y)
            ahValLine.label:SetText("|cffffffffTotal Value|r")
            ahValLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
            ahValLine.value:SetText(FormatGoldShort(postedAuctionValue))
            ahValLine.value:SetTextColor(0.9, 0.82, 0.0)
            y = y - ROW_HEIGHT
        end

        -- Staleness indicator
        local cached = ns.db and ns.db.currency and ns.db.currency._postedAuctions
        if cached and cached.lastScan then
            local age = time() - cached.lastScan
            local ageText
            if age < 60 then ageText = "just now"
            elseif age < 3600 then ageText = math.floor(age / 60) .. "m ago"
            else ageText = math.floor(age / 3600) .. "h ago" end

            lineIdx = lineIdx + 1
            local ageLine = GetLine(f, lineIdx)
            ageLine.icon:Hide()
            ageLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 6, y)
            ageLine.label:SetText("|cff888888Last scanned: " .. ageText .. "|r")
            ageLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
            ageLine.value:SetText("")
            y = y - ROW_HEIGHT
        end
    end

    -- Tracked currencies
    if db.showCurrencies and #currencyList > 0 then
        local sorted = {}
        for _, c in ipairs(currencyList) do
            table.insert(sorted, c)
        end
        SortCurrencies(sorted, db.currencySortOrder)

        y = y - 4

        lineIdx = lineIdx + 1
        local curHdr = GetLine(f, lineIdx)
        curHdr.icon:Hide()
        curHdr.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        curHdr.label:SetText("|cffffd100Currencies|r")
        curHdr.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        curHdr.value:SetText("")
        y = y - HEADER_HEIGHT

        local count = math.min(db.maxCurrencies or 15, #sorted)
        local lastHeader = nil
        local shown = 0

        for _, cur in ipairs(sorted) do
            if shown >= count then break end

            -- Show expansion/category sub-header if grouping by list order
            if db.currencySortOrder == "list" and cur.header and cur.header ~= lastHeader then
                lastHeader = cur.header
                lineIdx = lineIdx + 1
                local subHdr = GetLine(f, lineIdx)
                subHdr.icon:Hide()
                subHdr.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 4, y)
                subHdr.label:SetText("|cff888888" .. cur.header .. "|r")
                subHdr.label:SetTextColor(0.53, 0.53, 0.53)
                subHdr.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
                subHdr.value:SetText("")
                y = y - HEADER_HEIGHT
            end

            shown = shown + 1
            lineIdx = lineIdx + 1
            local row = GetLine(f, lineIdx)

            -- Currency icon
            if cur.iconFileID then
                row.icon:SetTexture(cur.iconFileID)
                row.icon:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 6, y - 3)
                row.icon:Show()
            else
                row.icon:Hide()
            end

            local labelX = PADDING + 6 + (cur.iconFileID and 18 or 0)
            row.label:SetPoint("TOPLEFT", f, "TOPLEFT", labelX, y)
            row.label:SetText(cur.name)

            -- Color by quality
            local qr, qg, qb = 0.8, 0.8, 0.8
            if cur.quality and cur.quality > 0 then
                local color = ITEM_QUALITY_COLORS[cur.quality]
                if color then qr, qg, qb = color.r, color.g, color.b end
            end
            row.label:SetTextColor(qr, qg, qb)

            row.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
            row.value:SetText(FormatQuantity(cur.quantity, cur.maxQuantity))
            row.value:SetTextColor(0.9, 0.9, 0.9)

            -- Clickable row overlay
            local rf = GetRowFrame(f, shown)
            rf.currencyData = cur
            rf:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
            rf:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
            y = y - ROW_HEIGHT
        end

        if #sorted > count then
            lineIdx = lineIdx + 1
            local moreRow = GetLine(f, lineIdx)
            moreRow.icon:Hide()
            moreRow.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 6, y)
            moreRow.label:SetText("|cff888888... and " .. (#sorted - count) .. " more|r")
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

function Currency:ShowTooltip(anchor)
    self:CancelHideTimer()

    if not tooltipFrame then
        tooltipFrame = CreateTooltipFrame()
    end

    local db = self:GetDB()
    tooltipFrame:ClearAllPoints()
    tooltipFrame:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 4)
    tooltipFrame:SetScale(db.tooltipScale or 1.0)

    ScanCurrencies()
    self:UpdateWarbankInfo()
    self:BuildTooltipContent()
    tooltipFrame:Show()
end

function Currency:StartHideTimer()
    self:CancelHideTimer()
    hideTimer = C_Timer.NewTimer(ns.HIDE_DELAY, function()
        if tooltipFrame then tooltipFrame:Hide() end
        hideTimer = nil
    end)
end

function Currency:CancelHideTimer()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
end

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------

Currency.settingsLabel = "Currency"

function Currency:BuildSettingsPanel(panel)
    local W = ns.SettingsWidgets
    local r = panel.refreshCallbacks
    local db = function() return ns.db.currency end

    local body = W.AddSection(panel, "Label Template")
    local y = 0
    y = W.AddLabelEditBox(body, y, "gold session token warbank auctions",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateData() end, r, {
        { "Default",    "<gold>" },
        { "Session",    "<gold> (<session>)" },
        { "With Token", "<gold>  Token: <token>" },
        { "Warband",    "<gold>  WB: <warbank>" },
        { "Full",       "<gold> (<session>)  <auctions> auctions" },
    })
    W.EndSection(panel, y)

    body = W.AddSection(panel, "Gold")
    y = 0
    y = W.AddCheckbox(body, y, "Show session gold change",
        function() return db().showSessionChange end,
        function(v) db().showSessionChange = v end, r)
    y = W.AddCheckbox(body, y, "Show alt character gold",
        function() return db().showAltGold end,
        function(v) db().showAltGold = v end, r)
    y = W.AddCheckbox(body, y, "Show WoW Token price",
        function() return db().showTokenPrice end,
        function(v) db().showTokenPrice = v end, r)
    W.EndSection(panel, y)

    body = W.AddSection(panel, "Warband Bank")
    y = 0
    y = W.AddCheckbox(body, y, "Show warband bank gold and access status",
        function() return db().showWarbankGold end,
        function(v) db().showWarbankGold = v end, r)
    y = W.AddDescription(body, y,
        "Shows warband bank gold (available anytime) and\n" ..
        "access lock status for multi-account setups.\n" ..
        "'Locked' means another WoW client on the same\n" ..
        "Battle.net account currently has exclusive access.")
    W.EndSection(panel, y)

    body = W.AddSection(panel, "Auctions")
    y = 0
    y = W.AddCheckbox(body, y, "Show posted auction count and value",
        function() return db().showPostedAuctions end,
        function(v) db().showPostedAuctions = v end, r)
    y = W.AddDescription(body, y,
        "Auction data is scanned when you visit the AH.\n" ..
        "Cached data is shown when away from the AH\n" ..
        "with a 'last scanned' indicator.")
    W.EndSection(panel, y)

    body = W.AddSection(panel, "Currencies")
    y = 0
    y = W.AddCheckbox(body, y, "Show tracked currencies",
        function() return db().showCurrencies end,
        function(v) db().showCurrencies = v end, r)
    y = W.AddSlider(body, y, "Max currencies to show", 5, 30, 1,
        function() return db().maxCurrencies end,
        function(v) db().maxCurrencies = v end, r)
    y = W.AddDropdown(body, y, "Sort Order", CURRENCY_SORT_VALUES,
        function() return db().currencySortOrder end,
        function(v) db().currencySortOrder = v end, r)
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

    ns.AddModuleClickActionsSection(panel, r, "currency", CLICK_ACTIONS,
        "Alt gold is tracked per-character across sessions.")
    ns.AddRowClickActionsSection(panel, r, "currency", ROW_CLICK_ACTIONS)
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("currency", Currency, DEFAULTS)
