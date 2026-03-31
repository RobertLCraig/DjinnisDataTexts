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

-- XP/hr tracking
local sessionStartTime = 0
local sessionStartXP = 0
local xpPerHour = 0
local totalXPGained = 0

-- Quest XP
local questXPTotal = 0
local questXPCount = 0

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
    labelTemplate = "<xp>",
    barWidth      = 20,
    tooltipScale  = 1.0,
    tooltipWidth  = 300,
    clickActions  = {
        leftClick       = "character",
        rightClick      = "none",
        middleClick     = "none",
        shiftLeftClick  = "achievements",
        shiftRightClick = "none",
        ctrlLeftClick   = "none",
        ctrlRightClick  = "none",
        altLeftClick    = "opensettings",
        altRightClick   = "none",
    },
}

local CLICK_ACTIONS = {
    character    = "Character Panel",
    achievements = "Achievements",
    opensettings = "Open DDT Settings",
    none         = "None",
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function FormatNumber(n)
    return ns.FormatNumber(n)
end

local function GetXPPercent()
    if maxXP <= 0 then return 0 end
    return math.floor((currentXP / maxXP) * 1000) / 10 -- one decimal
end

local function GetRestedPercent()
    if maxXP <= 0 then return 0 end
    return math.floor((restedXP / maxXP) * 1000) / 10
end

local function CalcXPPerHour()
    local elapsed = GetTime() - sessionStartTime
    if elapsed < 1 then return 0 end
    return totalXPGained / (elapsed / 3600)
end

local function ScanQuestXP()
    questXPTotal = 0
    questXPCount = 0
    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, numEntries do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHidden and not info.isHeader then
            if C_QuestLog.ReadyForTurnIn(info.questID) then
                local xp = GetQuestLogRewardXP(info.questID)
                if xp and xp > 0 then
                    questXPTotal = questXPTotal + xp
                    questXPCount = questXPCount + 1
                end
            end
        end
    end
end

local function FormatDuration(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    if h > 0 then
        return string.format("%dh %dm", h, m)
    end
    return string.format("%dm", m)
end

---------------------------------------------------------------------------
-- ASCII progress bar
---------------------------------------------------------------------------

local CHAR_FILLED = "#"
local CHAR_EMPTY  = "-"

local function BuildBar(percent, restedPct, width)
    width = width or 20
    local filled = math.floor(percent / 100 * width + 0.5)
    filled = math.min(filled, width)

    -- Rested portion overlaps the filled section (shown in blue after XP)
    local restedChars = 0
    if restedPct and restedPct > 0 then
        restedChars = math.floor(restedPct / 100 * width + 0.5)
        restedChars = math.min(restedChars, width - filled)
    end

    local empty = width - filled - restedChars

    local bar = ""
    -- XP filled (purple)
    if filled > 0 then
        bar = bar .. "|cff8800ff" .. string.rep(CHAR_FILLED, filled) .. "|r"
    end
    -- Rested overlay (blue)
    if restedChars > 0 then
        bar = bar .. "|cff4488ff" .. string.rep(CHAR_FILLED, restedChars) .. "|r"
    end
    -- Empty (dark gray)
    if empty > 0 then
        bar = bar .. "|cff333333" .. string.rep(CHAR_EMPTY, empty) .. "|r"
    end

    return "[" .. bar .. "]"
end

local function BuildRepBar(percent, width)
    width = width or 20
    local filled = math.floor(percent / 100 * width + 0.5)
    filled = math.min(filled, width)
    local empty = width - filled

    local bar = ""
    if filled > 0 then
        bar = bar .. "|cff00cc00" .. string.rep(CHAR_FILLED, filled) .. "|r"
    end
    if empty > 0 then
        bar = bar .. "|cff333333" .. string.rep(CHAR_EMPTY, empty) .. "|r"
    end
    return "[" .. bar .. "]"
end

---------------------------------------------------------------------------
-- Label template expansion
---------------------------------------------------------------------------

local function ExpandLabel(template)
    local result = template
    local db = ns.db and ns.db.experience or DEFAULTS
    local barW = db.barWidth or 20
    local E = ns.ExpandTag

    if isMaxLevel then
        local repPct = 0
        if watchedFaction and watchedFaction.barMax > 0 then
            repPct = (watchedFaction.barValue - watchedFaction.barMin) / (watchedFaction.barMax - watchedFaction.barMin) * 100
        end
        result = E(result, "xp", watchedFaction and watchedFaction.name or "Max Level")
        result = E(result, "percent", watchedFaction and string.format("%.1f%%", repPct) or "")
        result = E(result, "bar", watchedFaction and BuildRepBar(repPct, barW) or "")
        result = E(result, "level", playerLevel)
        result = E(result, "remaining", "")
        result = E(result, "rested", "")
        result = E(result, "xphr", "")
        result = E(result, "questxp", "")
    else
        local pct = GetXPPercent()
        local restPct = GetRestedPercent()
        result = E(result, "xp", string.format("%.1f%%", pct))
        result = E(result, "percent", string.format("%.1f%%", pct))
        result = E(result, "bar", BuildBar(pct, restPct, barW))
        result = E(result, "level", playerLevel)
        result = E(result, "remaining", FormatNumber(maxXP - currentXP))
        result = E(result, "rested", restedXP > 0 and string.format("+%.0f%%", restPct) or "")
        result = E(result, "xphr", xpPerHour > 0 and FormatNumber(math.floor(xpPerHour)) .. "/hr" or "")
        result = E(result, "questxp", questXPTotal > 0 and FormatNumber(questXPTotal) or "")
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
        local db = Experience:GetDB()
        local action = DDT:ResolveClickAction(button, db.clickActions or {})
        if action == "character" then
            ToggleCharacter("PaperDollFrame")
        elseif action == "achievements" then
            ToggleAchievementFrame()
        elseif action == "opensettings" then
            if DDT.settingsCategoryID then
                Settings.OpenToCategory(DDT.settingsCategoryID)
            end
        end
    end,
})

Experience.dataobj = dataobj

---------------------------------------------------------------------------
-- Event handling
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

local questXPDirty = true  -- flag to re-scan quest XP only when needed

function Experience:Init()
    sessionStartTime = GetTime()
    sessionStartXP = UnitXP("player") or 0

    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_XP_UPDATE" then
            local newXP = UnitXP("player") or 0
            if newXP > currentXP then
                totalXPGained = totalXPGained + (newXP - currentXP)
            end
        elseif event == "QUEST_LOG_UPDATE" or event == "QUEST_TURNED_IN" or event == "PLAYER_ENTERING_WORLD" then
            questXPDirty = true
        end
        Experience:UpdateData()
    end)
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_XP_UPDATE")
    eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
    eventFrame:RegisterEvent("UPDATE_EXHAUSTION")
    eventFrame:RegisterEvent("UPDATE_FACTION")
    eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
    eventFrame:RegisterEvent("QUEST_TURNED_IN")
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
        xpPerHour = 0
    else
        isMaxLevel = false
        currentXP = UnitXP("player") or 0
        maxXP = UnitXPMax("player") or 1
        restedXP = GetXPExhaustion() or 0
        xpPerHour = CalcXPPerHour()
        if questXPDirty then
            ScanQuestXP()
            questXPDirty = false
        end
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
            restLine.label:SetText("|cffffffffRested XP|r")
            restLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
            restLine.value:SetText(string.format("%s (%.0f%%)", FormatNumber(restedXP), GetRestedPercent()))
            restLine.value:SetTextColor(0.0, 0.39, 0.88)
            y = y - ROW_HEIGHT
        end

        -- XP per hour
        lineIdx = lineIdx + 1
        local xphrLine = GetLine(f, lineIdx)
        xphrLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        xphrLine.label:SetText("|cffffffffXP / Hour|r")
        xphrLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        if xpPerHour > 0 then
            xphrLine.value:SetText(FormatNumber(math.floor(xpPerHour)))
            xphrLine.value:SetTextColor(0.0, 1.0, 0.0)
        else
            xphrLine.value:SetText("--")
            xphrLine.value:SetTextColor(0.5, 0.5, 0.5)
        end
        y = y - ROW_HEIGHT

        -- Time to level (at current XP/hr rate)
        if xpPerHour > 0 then
            local remaining = maxXP - currentXP
            local secondsToLevel = remaining / xpPerHour * 3600
            lineIdx = lineIdx + 1
            local ttlLine = GetLine(f, lineIdx)
            ttlLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
            ttlLine.label:SetText("|cffffffffTime to Level|r")
            ttlLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
            ttlLine.value:SetText(FormatDuration(secondsToLevel))
            ttlLine.value:SetTextColor(0.7, 0.7, 0.7)
            y = y - ROW_HEIGHT
        end

        -- Quest XP (ready to turn in)
        if questXPTotal > 0 then
            lineIdx = lineIdx + 1
            local qLine = GetLine(f, lineIdx)
            qLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
            qLine.label:SetText(string.format("|cffffffffQuest XP|r  |cff888888(%d quest%s)|r", questXPCount, questXPCount == 1 and "" or "s"))
            qLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
            qLine.value:SetText(string.format("%s (%.1f%%)", FormatNumber(questXPTotal), maxXP > 0 and (questXPTotal / maxXP * 100) or 0))
            qLine.value:SetTextColor(1.0, 0.82, 0.0)
            y = y - ROW_HEIGHT
        end

        -- Session stats
        if totalXPGained > 0 then
            y = y - 4
            lineIdx = lineIdx + 1
            local sessLine = GetLine(f, lineIdx)
            sessLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
            sessLine.label:SetText("|cffffd100Session|r")
            sessLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
            sessLine.value:SetText(string.format("%s XP in %s", FormatNumber(totalXPGained), FormatDuration(GetTime() - sessionStartTime)))
            sessLine.value:SetTextColor(0.7, 0.7, 0.7)
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

    f.hint:SetText(DDT:BuildHintText(db.clickActions or {}, CLICK_ACTIONS))

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
    y = W.AddLabelEditBox(c, y, "xp percent bar level remaining rested xphr questxp",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateData() end, r, {
        { "Default",     "<xp>" },
        { "With Bar",    "<bar> <percent>" },
        { "Detailed",    "Lv<level> <percent> <rested>" },
        { "XP/Hour",     "<percent> - <xphr>" },
        { "Bar + Level", "Lv<level> <bar>" },
    })

    y = W.AddHeader(c, y, "Progress Bar")
    y = W.AddSlider(c, y, "Bar width (characters)", 10, 40, 1,
        function() return db().barWidth end,
        function(v) db().barWidth = v; self:UpdateData() end, r)
    y = W.AddDescription(c, y,
        "The <bar> tag renders an ASCII progress bar in the label.\n" ..
        "Purple = XP, Blue = Rested, Green = Reputation (at max level).")

    y = W.AddHeader(c, y, "Tooltip")
    y = W.AddSlider(c, y, "Scale", 0.5, 2.0, 0.05,
        function() return db().tooltipScale end,
        function(v) db().tooltipScale = v end, r)
    y = W.AddSlider(c, y, "Width", 200, 500, 10,
        function() return db().tooltipWidth end,
        function(v) db().tooltipWidth = v end, r)

    y = ns.AddModuleClickActionsSection(c, r, y, "experience", CLICK_ACTIONS)
    y = W.AddDescription(c, y,
        "XP/Hour tracks experience gained since login.\n" ..
        "Quest XP shows total XP from quests ready to turn in.\n" ..
        "At max level, the DataText shows watched reputation if set.")

    c:SetHeight(math.abs(y) + 20)
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("experience", Experience, DEFAULTS)
