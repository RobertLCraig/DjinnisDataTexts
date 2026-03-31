-- Djinni's Data Texts — Experience
-- XP progress, rested XP, and reputation tracking.
local addonName, ns = ...
local DDT = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local Experience = {}
ns.Experience = Experience

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
local currentXP = 0
local maxXP = 1
local restedXP = 0
local playerLevel = 0
local maxLevel = 0
local isMaxLevel = false
local watchedFaction = nil   -- { name, standing, barMin, barMax, barValue, factionID }
local STANDING_LABELS = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
local STANDING_COLORS = {
    { 0.80, 0.13, 0.13 }, -- Hated
    { 0.80, 0.13, 0.13 }, -- Hostile
    { 0.75, 0.27, 0.00 }, -- Unfriendly
    { 0.90, 0.70, 0.00 }, -- Neutral
    { 0.00, 0.60, 0.00 }, -- Friendly
    { 0.00, 0.60, 0.00 }, -- Honored
    { 0.00, 0.60, 0.00 }, -- Revered
    { 0.00, 0.60, 0.00 }, -- Exalted
}

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
    labelTemplate = "<xp>",
    tooltipScale  = 1.0,
    tooltipWidth  = 300,
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function FormatNumber(n)
    if n >= 1000000 then
        return string.format("%.1fM", n / 1000000)
    elseif n >= 1000 then
        return string.format("%.1fK", n / 1000)
    end
    return tostring(n)
end

local function GetXPPercent()
    if maxXP <= 0 then return 0 end
    return math.floor((currentXP / maxXP) * 1000) / 10 -- one decimal
end

local function GetRestedPercent()
    if maxXP <= 0 then return 0 end
    return math.floor((restedXP / maxXP) * 1000) / 10
end

---------------------------------------------------------------------------
-- Label template expansion
---------------------------------------------------------------------------

local function ExpandLabel(template)
    local result = template

    if isMaxLevel then
        -- At max level, show rep if watched, otherwise "Max Level"
        result = result:gsub("<xp>", watchedFaction and watchedFaction.name or "Max Level")
        result = result:gsub("<percent>", watchedFaction and
            string.format("%.1f%%", watchedFaction.barMax > 0 and
                ((watchedFaction.barValue - watchedFaction.barMin) / (watchedFaction.barMax - watchedFaction.barMin) * 100) or 0)
            or "")
        result = result:gsub("<level>", tostring(playerLevel))
        result = result:gsub("<remaining>", "")
        result = result:gsub("<rested>", "")
    else
        result = result:gsub("<xp>", string.format("%.1f%%", GetXPPercent()))
        result = result:gsub("<percent>", string.format("%.1f%%", GetXPPercent()))
        result = result:gsub("<level>", tostring(playerLevel))
        result = result:gsub("<remaining>", FormatNumber(maxXP - currentXP))
        result = result:gsub("<rested>", restedXP > 0 and string.format("+%.0f%%", GetRestedPercent()) or "")
    end
    return result
end

---------------------------------------------------------------------------
-- LDB Data Object
---------------------------------------------------------------------------

local dataobj = LDB:NewDataObject("DDT-Experience", {
    type  = "data source",
    text  = "XP",
    icon  = "Interface\\Icons\\XP_Icon",
    label = "DDT - Experience",
    OnEnter = function(self)
        Experience:ShowTooltip(self)
    end,
    OnLeave = function(self)
        Experience:StartHideTimer()
    end,
    OnClick = function(self, button)
        if button == "LeftButton" then
            ToggleCharacter("PaperDollFrame")
        end
    end,
})

Experience.dataobj = dataobj

---------------------------------------------------------------------------
-- Event handling
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

function Experience:Init()
    eventFrame:SetScript("OnEvent", function(_, event)
        Experience:UpdateData()
    end)
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_XP_UPDATE")
    eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
    eventFrame:RegisterEvent("UPDATE_EXHAUSTION")
    eventFrame:RegisterEvent("UPDATE_FACTION")
end

function Experience:GetDB()
    return ns.db and ns.db.experience or DEFAULTS
end

---------------------------------------------------------------------------
-- Data collection
---------------------------------------------------------------------------

function Experience:UpdateData()
    playerLevel = UnitLevel("player") or 0
    maxLevel = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or 80

    if playerLevel >= maxLevel then
        isMaxLevel = true
        currentXP = 0
        maxXP = 1
        restedXP = 0
    else
        isMaxLevel = false
        currentXP = UnitXP("player") or 0
        maxXP = UnitXPMax("player") or 1
        restedXP = GetXPExhaustion() or 0
    end

    -- Watched faction
    watchedFaction = nil
    if C_Reputation and C_Reputation.GetWatchedFactionData then
        local data = C_Reputation.GetWatchedFactionData()
        if data then
            watchedFaction = {
                name     = data.name or "",
                standing = data.reaction or 0,
                barMin   = data.currentReactionThreshold or 0,
                barMax   = data.nextReactionThreshold or 1,
                barValue = data.currentStanding or 0,
                factionID = data.factionID,
            }
        end
    end

    -- Update LDB
    local db = self:GetDB()
    dataobj.text = ExpandLabel(db.labelTemplate)

    if tooltipFrame and tooltipFrame:IsShown() then
        self:BuildTooltipContent()
    end
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------

local function CreateTooltipFrame()
    local f = CreateFrame("Frame", "DDTExperienceTooltip", UIParent, "BackdropTemplate")
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
    f:SetScript("OnEnter", function() Experience:CancelHideTimer() end)
    f:SetScript("OnLeave", function() Experience:StartHideTimer() end)

    f.lines = {}

    -- XP bar background
    f.xpBarBG = f:CreateTexture(nil, "ARTWORK")
    f.xpBarBG:SetColorTexture(0.15, 0.15, 0.15, 0.8)
    f.xpBarBG:SetHeight(8)

    -- XP bar fill
    f.xpBar = f:CreateTexture(nil, "ARTWORK", nil, 1)
    f.xpBar:SetColorTexture(0.58, 0.0, 0.82, 0.9)  -- purple
    f.xpBar:SetHeight(8)

    -- Rested bar fill
    f.restedBar = f:CreateTexture(nil, "ARTWORK", nil, 1)
    f.restedBar:SetColorTexture(0.0, 0.39, 0.88, 0.5)  -- blue overlay
    f.restedBar:SetHeight(8)

    -- Rep bar background
    f.repBarBG = f:CreateTexture(nil, "ARTWORK")
    f.repBarBG:SetColorTexture(0.15, 0.15, 0.15, 0.8)
    f.repBarBG:SetHeight(8)

    -- Rep bar fill
    f.repBar = f:CreateTexture(nil, "ARTWORK", nil, 1)
    f.repBar:SetColorTexture(0.0, 0.6, 0.0, 0.9)
    f.repBar:SetHeight(8)

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

function Experience:BuildTooltipContent()
    local f = tooltipFrame
    HideLines(f)

    local db = self:GetDB()
    local ttWidth = db.tooltipWidth or TOOLTIP_WIDTH
    local barWidth = ttWidth - (PADDING * 2)

    f.title:SetText("Experience")

    local y = -PADDING - 20 - 6
    local lineIdx = 0

    -- Level
    lineIdx = lineIdx + 1
    local lvlLine = GetLine(f, lineIdx)
    lvlLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    lvlLine.label:SetText("|cffffffffLevel|r")
    lvlLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    if isMaxLevel then
        lvlLine.value:SetText(playerLevel .. " (Max)")
        lvlLine.value:SetTextColor(1.0, 0.82, 0.0)
    else
        lvlLine.value:SetText(playerLevel .. " / " .. maxLevel)
        lvlLine.value:SetTextColor(0.4, 0.78, 1)
    end
    y = y - ROW_HEIGHT

    if not isMaxLevel then
        -- XP
        lineIdx = lineIdx + 1
        local xpLine = GetLine(f, lineIdx)
        xpLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        xpLine.label:SetText("|cffffffffExperience|r")
        xpLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        xpLine.value:SetText(string.format("%s / %s (%.1f%%)", FormatNumber(currentXP), FormatNumber(maxXP), GetXPPercent()))
        xpLine.value:SetTextColor(0.58, 0.0, 0.82)
        y = y - ROW_HEIGHT

        -- XP bar
        y = y - 2
        f.xpBarBG:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        f.xpBarBG:SetWidth(barWidth)
        f.xpBarBG:Show()

        local xpFill = maxXP > 0 and (currentXP / maxXP) or 0
        f.xpBar:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        f.xpBar:SetWidth(math.max(1, barWidth * xpFill))
        f.xpBar:Show()

        -- Rested overlay
        if restedXP > 0 then
            local restedFill = math.min(1, (currentXP + restedXP) / maxXP)
            f.restedBar:SetPoint("TOPLEFT", f.xpBar, "TOPRIGHT", 0, 0)
            f.restedBar:SetWidth(math.max(1, barWidth * (restedFill - xpFill)))
            f.restedBar:Show()
        else
            f.restedBar:Hide()
        end

        y = y - 12

        -- Remaining
        lineIdx = lineIdx + 1
        local remLine = GetLine(f, lineIdx)
        remLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        remLine.label:SetText("|cffffffffRemaining|r")
        remLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        remLine.value:SetText(FormatNumber(maxXP - currentXP))
        remLine.value:SetTextColor(0.7, 0.7, 0.7)
        y = y - ROW_HEIGHT

        -- Rested XP
        if restedXP > 0 then
            lineIdx = lineIdx + 1
            local restLine = GetLine(f, lineIdx)
            restLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
            restLine.label:SetText("|cffffffffRested|r")
            restLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
            restLine.value:SetText(string.format("%s (%.0f%%)", FormatNumber(restedXP), GetRestedPercent()))
            restLine.value:SetTextColor(0.0, 0.39, 0.88)
            y = y - ROW_HEIGHT
        end
    else
        f.xpBarBG:Hide()
        f.xpBar:Hide()
        f.restedBar:Hide()
    end

    -- Watched reputation
    if watchedFaction then
        y = y - 4

        lineIdx = lineIdx + 1
        local repHdr = GetLine(f, lineIdx)
        repHdr.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        repHdr.label:SetText("|cffffd100Watched Reputation|r")
        repHdr.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        repHdr.value:SetText("")
        y = y - HEADER_HEIGHT

        -- Faction name + standing
        lineIdx = lineIdx + 1
        local fLine = GetLine(f, lineIdx)
        fLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        fLine.label:SetText(watchedFaction.name)
        fLine.label:SetTextColor(0.9, 0.9, 0.9)
        fLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        local standingLabel = STANDING_LABELS[watchedFaction.standing] or "Unknown"
        local sc = STANDING_COLORS[watchedFaction.standing] or { 0.7, 0.7, 0.7 }
        fLine.value:SetText(standingLabel)
        fLine.value:SetTextColor(sc[1], sc[2], sc[3])
        y = y - ROW_HEIGHT

        -- Rep progress
        local repRange = watchedFaction.barMax - watchedFaction.barMin
        local repCurrent = watchedFaction.barValue - watchedFaction.barMin
        local repPct = repRange > 0 and (repCurrent / repRange * 100) or 0

        lineIdx = lineIdx + 1
        local rpLine = GetLine(f, lineIdx)
        rpLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        rpLine.label:SetText("|cffffffffProgress|r")
        rpLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        rpLine.value:SetText(string.format("%s / %s (%.1f%%)", FormatNumber(repCurrent), FormatNumber(repRange), repPct))
        rpLine.value:SetTextColor(sc[1], sc[2], sc[3])
        y = y - ROW_HEIGHT

        -- Rep bar
        y = y - 2
        f.repBarBG:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        f.repBarBG:SetWidth(barWidth)
        f.repBarBG:Show()

        local repFill = repRange > 0 and (repCurrent / repRange) or 0
        f.repBar:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        f.repBar:SetWidth(math.max(1, barWidth * repFill))
        f.repBar:SetColorTexture(sc[1], sc[2], sc[3], 0.9)
        f.repBar:Show()

        y = y - 12
    else
        f.repBarBG:Hide()
        f.repBar:Hide()
    end

    f.hint:SetText("|cff888888LClick: Character Panel|r")

    local totalHeight = math.abs(y) + PADDING + HINT_HEIGHT + 8
    f:SetSize(ttWidth, totalHeight)
end

function Experience:ShowTooltip(anchor)
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

function Experience:StartHideTimer()
    self:CancelHideTimer()
    hideTimer = C_Timer.NewTimer(ns.HIDE_DELAY, function()
        if tooltipFrame then tooltipFrame:Hide() end
        hideTimer = nil
    end)
end

function Experience:CancelHideTimer()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
end

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------

Experience.settingsLabel = "Experience"

function Experience:BuildSettingsPanel(panel)
    local W = ns.SettingsWidgets
    local c = panel.content
    local r = panel.refreshCallbacks
    local y = -10
    local db = function() return ns.db.experience end

    y = W.AddHeader(c, y, "Label Template")
    y = W.AddDescription(c, y, "Tags: <xp> <percent> <level> <remaining> <rested>")
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
        "Left-click: Open Character Panel\n\n" ..
        "At max level, the DataText shows watched reputation if set.")

    c:SetHeight(math.abs(y) + 20)
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("experience", Experience, DEFAULTS)
