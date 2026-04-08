-- Djinni's Data Texts - Mail
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
local HEADER_HEIGHT  = 18
local PADDING        = 10

-- State
local hasNewMail = false
local mailCount = 0         -- total items in mailbox (only known when mailbox is open)
local mailItems = {}        -- { { sender, subject, money, daysLeft, wasRead, hasItem } }
local mailboxOpen = false

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
    labelTemplate  = "<status>",
    mailSortOrder  = "sender",  -- sender, subject, expiry, unread
    tooltipScale     = 1.0,
    tooltipMaxHeight = 400,
    tooltipWidth     = 300,
    clickActions   = {
        leftClick       = "character",
        rightClick      = "none",
        middleClick     = "none",
        shiftLeftClick  = "copysummary",
        shiftRightClick = "none",
        ctrlLeftClick   = "none",
        ctrlRightClick  = "none",
        altLeftClick    = "opensettings",
        altRightClick   = "none",
    },
}

local CLICK_ACTIONS = {
    character    = "Character Panel",
    copysummary  = "Copy Mail Summary",
    opensettings = "Open DDT Settings",
    none         = "None",
}

local MAIL_SORT_VALUES = {
    sender  = "Sender (A-Z)",
    subject = "Subject (A-Z)",
    expiry  = "Expiry (Soonest First)",
    unread  = "Unread First",
}

local function SortMailItems(items, order)
    if order == "sender" then
        table.sort(items, function(a, b) return a.sender < b.sender end)
    elseif order == "subject" then
        table.sort(items, function(a, b) return a.subject < b.subject end)
    elseif order == "expiry" then
        table.sort(items, function(a, b) return a.daysLeft < b.daysLeft end)
    elseif order == "unread" then
        table.sort(items, function(a, b)
            if a.wasRead ~= b.wasRead then return not a.wasRead end
            return a.sender < b.sender
        end)
    end
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function FormatMoney(copper)
    if not copper or copper <= 0 then return "" end
    return ns.FormatGold(copper)
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

    local E = ns.ExpandTag
    result = E(result, "status", status)
    result = E(result, "count", mailCount)
    result = E(result, "new", hasNewMail and "New" or "")
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
        local db = Mail:GetDB()
        local action = DDT:ResolveClickAction(button, db.clickActions or {})
        if action == "character" then
            ToggleCharacter("PaperDollFrame")
        elseif action == "copysummary" then
            local msg = mailCount > 0 and (mailCount .. " mail") or "No mail"
            ChatFrameUtil.OpenChat(msg)
        elseif action == "opensettings" then
            if DDT.settingsCategoryID then
                Settings.OpenToCategory(DDT.settingsCategoryID)
            end
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
    local f = ns.CreateTooltipFrame("DDTMailTooltip", Mail)
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

function Mail:BuildTooltipContent()
    local f = tooltipFrame
    local c = f.content
    HideLines(c)

    f.header:SetText("Mail")

    local y = 0
    local lineIdx = 0

    -- Status line
    lineIdx = lineIdx + 1
    local statusLine = GetLine(c, lineIdx)
    statusLine.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
    statusLine.label:SetText("|cffffffffStatus|r")
    statusLine.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
    if hasNewMail then
        statusLine.value:SetText("New mail waiting!")
        statusLine.value:SetTextColor(0.0, 1.0, 0.0)
    else
        statusLine.value:SetText("No new mail")
        statusLine.value:SetTextColor(0.5, 0.5, 0.5)
    end
    y = y - ns.ROW_HEIGHT

    -- Mail items (only available when mailbox has been opened)
    local db = self:GetDB()
    if #mailItems > 0 then
        SortMailItems(mailItems, db.mailSortOrder)
        y = y - 4

        lineIdx = lineIdx + 1
        local hdr = GetLine(c, lineIdx)
        hdr.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
        hdr.label:SetText("|cffffd100Mailbox (" .. mailCount .. " items)|r")
        hdr.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
        hdr.value:SetText("")
        y = y - HEADER_HEIGHT

        for i, item in ipairs(mailItems) do
            if i > 15 then
                lineIdx = lineIdx + 1
                local moreRow = GetLine(c, lineIdx)
                moreRow.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING + 6, y)
                moreRow.label:SetText("|cff888888... and " .. (#mailItems - 15) .. " more|r")
                moreRow.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
                moreRow.value:SetText("")
                y = y - ns.ROW_HEIGHT
                break
            end

            lineIdx = lineIdx + 1
            local row = GetLine(c, lineIdx)
            row.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING + 6, y)

            -- Subject or sender
            local displayText = item.subject ~= "" and item.subject or item.sender
            if not item.wasRead then
                displayText = "|cffffffff" .. displayText .. "|r"
            end
            row.label:SetText(displayText)
            row.label:SetTextColor(item.wasRead and 0.5 or 0.9, item.wasRead and 0.5 or 0.9, item.wasRead and 0.5 or 0.9)

            -- Right side: money, attachment indicator, or days left
            row.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
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

            y = y - ns.ROW_HEIGHT
        end
    elseif mailboxOpen then
        lineIdx = lineIdx + 1
        local emptyLine = GetLine(c, lineIdx)
        emptyLine.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
        emptyLine.label:SetText("|cff888888Mailbox is empty.|r")
        emptyLine.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
        emptyLine.value:SetText("")
        y = y - ns.ROW_HEIGHT
    else
        lineIdx = lineIdx + 1
        local notOpenLine = GetLine(c, lineIdx)
        notOpenLine.label:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
        notOpenLine.label:SetText("|cff888888Visit a mailbox to see details.|r")
        notOpenLine.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PADDING, y)
        notOpenLine.value:SetText("")
        y = y - ns.ROW_HEIGHT
    end

    -- Hint
    local hintText = DDT:BuildHintText(db.clickActions or {}, CLICK_ACTIONS)
    if hintText == "" then
        f.hint:SetText("|cff888888Visit a mailbox to see mail details|r")
    else
        f.hint:SetText(hintText)
    end

    local ttWidth = db.tooltipWidth or TOOLTIP_WIDTH
    f:FinalizeLayout(ttWidth, math.abs(y))
end

function Mail:ShowTooltip(anchor)
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
    local r = panel.refreshCallbacks
    local db = function() return ns.db.mail end

    W.AddLabelEditBox(panel, "status count new",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateData() end, r, {
        { "Default",  "<status>" },
        { "Count",    "Mail: <count>" },
        { "New Only", "<new> new" },
        { "Full",     "Mail: <count> (<new> new)" },
    })

    local body = W.AddSection(panel, "Sorting")
    local y = 0
    y = W.AddDropdown(body, y, "Mail Order", MAIL_SORT_VALUES,
        function() return db().mailSortOrder end,
        function(v) db().mailSortOrder = v end, r)
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
    y = W.AddNote(body, y, "Suggested: 350 x 350. Increase height for many mail items.")
    y = W.AddTooltipGrowDirection(body, y, db, r)
    y = W.AddTooltipCopyFrom(body, y, "mail", db, r)
    W.EndSection(panel, y)

    ns.AddModuleClickActionsSection(panel, r, "mail", CLICK_ACTIONS,
        "Mail details are populated when you visit a mailbox.\n" ..
        "The indicator shows whether you have new unread mail.")
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("mail", Mail, DEFAULTS)
