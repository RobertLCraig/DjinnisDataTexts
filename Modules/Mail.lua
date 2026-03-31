-- Djinni's Data Texts — Mail
-- Unread mail count, mailbox status, and recent mail items.
local addonName, ns = ...
local DDT = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local Mail = {}
ns.Mail = Mail

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
local hasNewMail = false
local mailCount = 0         -- total items in mailbox (only known when mailbox is open)
local mailItems = {}        -- { { sender, subject, money, daysLeft, wasRead, hasItem } }
local mailboxOpen = false

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
    labelTemplate = "<status>",
    tooltipScale  = 1.0,
    tooltipWidth  = 300,
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function FormatMoney(copper)
    if not copper or copper <= 0 then return "" end
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop = copper % 100

    if gold > 0 then
        return string.format("%dg %ds %dc", gold, silver, cop)
    elseif silver > 0 then
        return string.format("%ds %dc", silver, cop)
    else
        return string.format("%dc", cop)
    end
end

---------------------------------------------------------------------------
-- Label template expansion
---------------------------------------------------------------------------

local function ExpandLabel(template)
    local result = template

    local status
    if hasNewMail then
        if mailCount > 0 then
            status = mailCount .. " Mail"
        else
            status = "New Mail"
        end
    else
        status = "No Mail"
    end

    result = result:gsub("<status>", status)
    result = result:gsub("<count>", tostring(mailCount))
    result = result:gsub("<new>", hasNewMail and "New" or "")
    return result
end

---------------------------------------------------------------------------
-- LDB Data Object
---------------------------------------------------------------------------

local dataobj = LDB:NewDataObject("DDT-Mail", {
    type  = "data source",
    text  = "No Mail",
    icon  = "Interface\\Icons\\INV_Letter_15",
    label = "DDT - Mail",
    OnEnter = function(self)
        Mail:ShowTooltip(self)
    end,
    OnLeave = function(self)
        Mail:StartHideTimer()
    end,
    OnClick = function(self, button)
        if button == "LeftButton" then
            ToggleCharacter("PaperDollFrame")
        end
    end,
})

Mail.dataobj = dataobj

---------------------------------------------------------------------------
-- Event handling
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

function Mail:Init()
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "UPDATE_PENDING_MAIL" or event == "PLAYER_ENTERING_WORLD" then
            Mail:UpdateData()
        elseif event == "MAIL_INBOX_UPDATE" then
            Mail:ScanMailbox()
        elseif event == "MAIL_SHOW" then
            mailboxOpen = true
            Mail:ScanMailbox()
        elseif event == "MAIL_CLOSED" then
            mailboxOpen = false
            Mail:UpdateData()
        end
    end)

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UPDATE_PENDING_MAIL")
    eventFrame:RegisterEvent("MAIL_INBOX_UPDATE")
    eventFrame:RegisterEvent("MAIL_SHOW")
    eventFrame:RegisterEvent("MAIL_CLOSED")
end

function Mail:GetDB()
    return ns.db and ns.db.mail or DEFAULTS
end

---------------------------------------------------------------------------
-- Data collection
---------------------------------------------------------------------------

function Mail:UpdateData()
    hasNewMail = HasNewMail() or false

    -- Update icon based on mail status
    if hasNewMail then
        dataobj.icon = "Interface\\Icons\\INV_Letter_15"
    else
        dataobj.icon = "Interface\\Icons\\INV_Letter_04"
    end

    -- Update LDB text
    local db = self:GetDB()
    dataobj.text = ExpandLabel(db.labelTemplate)

    -- Refresh tooltip if visible
    if tooltipFrame and tooltipFrame:IsShown() then
        self:BuildTooltipContent()
    end
end

function Mail:ScanMailbox()
    wipe(mailItems)
    mailCount = GetInboxNumItems() or 0

    for i = 1, mailCount do
        local _, _, sender, subject, money, _, daysLeft, hasItem, wasRead = GetInboxHeaderInfo(i)
        table.insert(mailItems, {
            sender  = sender or "Unknown",
            subject = subject or "",
            money   = money or 0,
            daysLeft = daysLeft or 0,
            wasRead = wasRead or false,
            hasItem = hasItem or false,
        })
    end

    self:UpdateData()
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------

local function CreateTooltipFrame()
    local f = CreateFrame("Frame", "DDTMailTooltip", UIParent, "BackdropTemplate")
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

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, -PADDING)
    f.title:SetTextColor(1, 0.82, 0)

    f.titleSep = f:CreateTexture(nil, "ARTWORK")
    f.titleSep:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
    f.titleSep:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)
    f.titleSep:SetHeight(1)
    f.titleSep:SetColorTexture(0.5, 0.5, 0.5, 0.5)

    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PADDING, 8)
    f.hint:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PADDING, 8)
    f.hint:SetJustifyH("CENTER")
    f.hint:SetTextColor(0.53, 0.53, 0.53)

    f:EnableMouse(true)
    f:SetScript("OnEnter", function() Mail:CancelHideTimer() end)
    f:SetScript("OnLeave", function() Mail:StartHideTimer() end)

    f.lines = {}
    return f
end

local function GetLine(f, index)
    if f.lines[index] then
        f.lines[index].label:Show()
        f.lines[index].value:Show()
        return f.lines[index]
    end

    local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetJustifyH("LEFT")

    local value = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
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

function Mail:BuildTooltipContent()
    local f = tooltipFrame
    HideLines(f)

    f.title:SetText("Mail")

    local y = -PADDING - 20 - 6
    local lineIdx = 0

    -- Status line
    lineIdx = lineIdx + 1
    local statusLine = GetLine(f, lineIdx)
    statusLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    statusLine.label:SetText("|cffffffffStatus|r")
    statusLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    if hasNewMail then
        statusLine.value:SetText("New mail waiting!")
        statusLine.value:SetTextColor(0.0, 1.0, 0.0)
    else
        statusLine.value:SetText("No new mail")
        statusLine.value:SetTextColor(0.5, 0.5, 0.5)
    end
    y = y - ROW_HEIGHT

    -- Mail items (only available when mailbox has been opened)
    if #mailItems > 0 then
        y = y - 4

        lineIdx = lineIdx + 1
        local hdr = GetLine(f, lineIdx)
        hdr.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        hdr.label:SetText("|cffffd100Mailbox (" .. mailCount .. " items)|r")
        hdr.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        hdr.value:SetText("")
        y = y - HEADER_HEIGHT

        for i, item in ipairs(mailItems) do
            if i > 15 then
                lineIdx = lineIdx + 1
                local moreRow = GetLine(f, lineIdx)
                moreRow.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 6, y)
                moreRow.label:SetText("|cff888888... and " .. (#mailItems - 15) .. " more|r")
                moreRow.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
                moreRow.value:SetText("")
                y = y - ROW_HEIGHT
                break
            end

            lineIdx = lineIdx + 1
            local row = GetLine(f, lineIdx)
            row.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 6, y)

            -- Subject or sender
            local displayText = item.subject ~= "" and item.subject or item.sender
            if not item.wasRead then
                displayText = "|cffffffff" .. displayText .. "|r"
            end
            row.label:SetText(displayText)
            row.label:SetTextColor(item.wasRead and 0.5 or 0.9, item.wasRead and 0.5 or 0.9, item.wasRead and 0.5 or 0.9)

            -- Right side: money, attachment indicator, or days left
            row.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
            if item.money > 0 then
                row.value:SetText(FormatMoney(item.money))
                row.value:SetTextColor(1.0, 0.82, 0.0)
            elseif item.hasItem then
                row.value:SetText("|cff00cc00[Item]|r")
                row.value:SetTextColor(0.0, 0.8, 0.0)
            else
                local daysText = string.format("%.0fd", item.daysLeft)
                row.value:SetText(daysText)
                if item.daysLeft <= 1 then
                    row.value:SetTextColor(1.0, 0.2, 0.2)
                elseif item.daysLeft <= 3 then
                    row.value:SetTextColor(1.0, 0.82, 0.0)
                else
                    row.value:SetTextColor(0.5, 0.5, 0.5)
                end
            end

            y = y - ROW_HEIGHT
        end
    elseif mailboxOpen then
        lineIdx = lineIdx + 1
        local emptyLine = GetLine(f, lineIdx)
        emptyLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        emptyLine.label:SetText("|cff888888Mailbox is empty.|r")
        emptyLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        emptyLine.value:SetText("")
        y = y - ROW_HEIGHT
    else
        lineIdx = lineIdx + 1
        local notOpenLine = GetLine(f, lineIdx)
        notOpenLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        notOpenLine.label:SetText("|cff888888Visit a mailbox to see details.|r")
        notOpenLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        notOpenLine.value:SetText("")
        y = y - ROW_HEIGHT
    end

    -- Hint
    f.hint:SetText("|cff888888Visit a mailbox to see mail details|r")

    local db = self:GetDB()
    local ttWidth = db.tooltipWidth or TOOLTIP_WIDTH
    local totalHeight = math.abs(y) + PADDING + HINT_HEIGHT + 8
    f:SetSize(ttWidth, totalHeight)
end

function Mail:ShowTooltip(anchor)
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

function Mail:StartHideTimer()
    self:CancelHideTimer()
    hideTimer = C_Timer.NewTimer(ns.HIDE_DELAY, function()
        if tooltipFrame then tooltipFrame:Hide() end
        hideTimer = nil
    end)
end

function Mail:CancelHideTimer()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
end

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------

Mail.settingsLabel = "Mail"

function Mail:BuildSettingsPanel(panel)
    local W = ns.SettingsWidgets
    local c = panel.content
    local r = panel.refreshCallbacks
    local y = -10
    local db = function() return ns.db.mail end

    y = W.AddHeader(c, y, "Label Template")
    y = W.AddDescription(c, y, "Tags: <status> <count> <new>")
    y = W.AddEditBox(c, y, "Template",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateData() end, r)

    y = W.AddHeader(c, y, "Tooltip")
    y = W.AddSlider(c, y, "Scale", 0.5, 2.0, 0.05,
        function() return db().tooltipScale end,
        function(v) db().tooltipScale = v end, r)
    y = W.AddSlider(c, y, "Width", 200, 500, 10,
        function() return db().tooltipWidth end,
        function(v) db().tooltipWidth = v end, r)

    y = W.AddHeader(c, y, "Interactions")
    y = W.AddDescription(c, y,
        "Mail details are populated when you visit a mailbox.\n" ..
        "The indicator shows whether you have new unread mail.")

    c:SetHeight(math.abs(y) + 20)
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("mail", Mail, DEFAULTS)
