-- Djinni's Data Texts — Saved Instances
-- Raid and dungeon lockout summary with boss kill status and reset timers.
local addonName, ns = ...
local DDT = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local SavedInst = {}
ns.SavedInst = SavedInst

-- Lockout data cache
local lockoutCache = {}     -- { { name, id, reset, difficulty, locked, extended, isRaid, maxPlayers, difficultyName, numEncounters, encounterProgress, bosses = {} } }
local raidCount = 0
local dungeonCount = 0

-- Tooltip
local tooltipFrame = nil
local hideTimer = nil
local rowPool = {}
local headerPool = {}
local separatorPool = {}

-- Layout constants
local TOOLTIP_WIDTH   = 380
local ROW_HEIGHT      = 20
local BOSS_ROW_HEIGHT = 16
local HEADER_HEIGHT   = 18
local PADDING         = 10
local HINT_HEIGHT     = 18

-- Difficulty display tags
local DIFFICULTY_TAGS = {
    [1]  = "N",    -- Normal Dungeon
    [2]  = "H",    -- Heroic Dungeon
    [3]  = "10N",  -- 10-player Normal (legacy)
    [4]  = "25N",  -- 25-player Normal (legacy)
    [5]  = "10H",  -- 10-player Heroic (legacy)
    [6]  = "25H",  -- 25-player Heroic (legacy)
    [7]  = "LFR",  -- Legacy LFR
    [8]  = "M+",   -- Mythic+
    [9]  = "40",   -- 40-player (legacy)
    [14] = "N",    -- Normal Raid
    [15] = "H",    -- Heroic Raid
    [16] = "M",    -- Mythic Raid
    [17] = "LFR",  -- LFR
    [23] = "M",    -- Mythic Dungeon
    [33] = "T",    -- Timewalking
    [39] = "H",    -- Heroic Scenario
    [147] = "N",   -- War of the Thorns Normal
    [149] = "H",   -- War of the Thorns Heroic
}

-- Difficulty colors
local DIFFICULTY_COLORS = {
    N   = { 0.12, 1.00, 0.00 },     -- Green
    H   = { 0.00, 0.44, 0.87 },     -- Blue
    M   = { 0.78, 0.00, 1.00 },     -- Purple
    LFR = { 0.00, 0.80, 0.60 },     -- Teal
    T   = { 0.00, 0.80, 0.80 },     -- Cyan
}
DIFFICULTY_COLORS["M+"]  = DIFFICULTY_COLORS.M
DIFFICULTY_COLORS["10N"] = DIFFICULTY_COLORS.N
DIFFICULTY_COLORS["25N"] = DIFFICULTY_COLORS.N
DIFFICULTY_COLORS["10H"] = DIFFICULTY_COLORS.H
DIFFICULTY_COLORS["25H"] = DIFFICULTY_COLORS.H
DIFFICULTY_COLORS["40"]  = DIFFICULTY_COLORS.N

---------------------------------------------------------------------------
-- LDB Data Object
---------------------------------------------------------------------------

local dataobj = LDB:NewDataObject("DDT-SavedInstances", {
    type  = "data source",
    text  = "Lockouts: 0",
    icon  = "Interface\\Icons\\INV_Misc_Key_04",
    label = "DDT - Saved Instances",
    OnEnter = function(self)
        SavedInst:ShowTooltip(self)
    end,
    OnLeave = function(self)
        SavedInst:StartHideTimer()
    end,
    OnClick = function(self, button)
        if button == "LeftButton" and IsShiftKeyDown() then
            ToggleRaidFrame()
        elseif button == "LeftButton" then
            -- Request fresh data
            RequestRaidInfo()
        end
    end,
})

SavedInst.dataobj = dataobj

---------------------------------------------------------------------------
-- Event handling
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

function SavedInst:Init()
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            -- Delay initial request to avoid login congestion
            C_Timer.After(3, function()
                RequestRaidInfo()
            end)
        else
            SavedInst:UpdateData()
        end
    end)
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UPDATE_INSTANCE_INFO")
    eventFrame:RegisterEvent("BOSS_KILL")
    eventFrame:RegisterEvent("INSTANCE_LOCK_START")
    eventFrame:RegisterEvent("INSTANCE_LOCK_STOP")
end

---------------------------------------------------------------------------
-- Time formatting
---------------------------------------------------------------------------

local function FormatResetTime(seconds)
    if seconds <= 0 then return "|cff888888Expired|r" end
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local mins = math.floor((seconds % 3600) / 60)

    if days > 0 then
        return string.format("%dd %dh", days, hours)
    elseif hours > 0 then
        return string.format("%dh %dm", hours, mins)
    else
        return string.format("%dm", mins)
    end
end

---------------------------------------------------------------------------
-- Data collection
---------------------------------------------------------------------------

function SavedInst:UpdateData()
    wipe(lockoutCache)
    raidCount = 0
    dungeonCount = 0

    local numSaved = GetNumSavedInstances() or 0

    for i = 1, numSaved do
        local name, id, reset, difficulty, locked, extended, _, isRaid, maxPlayers, difficultyName, numEncounters, encounterProgress = GetSavedInstanceInfo(i)

        if locked or extended then
            local tag = DIFFICULTY_TAGS[difficulty] or difficultyName or "?"

            -- Collect boss info
            local bosses = {}
            local encCount = numEncounters or 0
            for j = 1, encCount do
                local bossName, _, isKilled = GetSavedInstanceEncounterInfo(i, j)
                if bossName then
                    table.insert(bosses, {
                        name = bossName,
                        killed = isKilled,
                    })
                end
            end

            table.insert(lockoutCache, {
                name             = name or "Unknown",
                id               = id,
                reset            = reset or 0,
                difficulty       = difficulty,
                difficultyTag    = tag,
                difficultyName   = difficultyName or tag,
                locked           = locked,
                extended         = extended,
                isRaid           = isRaid,
                maxPlayers       = maxPlayers or 0,
                numEncounters    = numEncounters or 0,
                encounterProgress = encounterProgress or 0,
                bosses           = bosses,
                expanded         = false,
            })

            if isRaid then
                raidCount = raidCount + 1
            else
                dungeonCount = dungeonCount + 1
            end
        end
    end

    -- Sort: raids first, then alphabetical within each group
    table.sort(lockoutCache, function(a, b)
        if a.isRaid ~= b.isRaid then return a.isRaid end
        if a.name == b.name then
            return (a.difficultyTag or "") < (b.difficultyTag or "")
        end
        return a.name < b.name
    end)

    -- Update LDB text
    local total = raidCount + dungeonCount
    if total == 0 then
        dataobj.text = "No Lockouts"
    else
        local parts = {}
        if raidCount > 0 then table.insert(parts, raidCount .. "R") end
        if dungeonCount > 0 then table.insert(parts, dungeonCount .. "D") end
        dataobj.text = "Lockouts: " .. table.concat(parts, " ")
    end

    -- Refresh tooltip if visible
    if tooltipFrame and tooltipFrame:IsShown() then
        self:BuildTooltipContent()
    end
end

---------------------------------------------------------------------------
-- Tooltip frame creation
---------------------------------------------------------------------------

local function CreateTooltipFrame()
    local f = CreateFrame("Frame", "DDTSavedInstancesTooltip", UIParent, "BackdropTemplate")
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
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, -PADDING)
    f.title:SetTextColor(1, 0.82, 0)

    -- Title separator
    f.titleSep = f:CreateTexture(nil, "ARTWORK")
    f.titleSep:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
    f.titleSep:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)
    f.titleSep:SetHeight(1)
    f.titleSep:SetColorTexture(0.5, 0.5, 0.5, 0.5)

    -- Hint bar
    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PADDING, 8)
    f.hint:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PADDING, 8)
    f.hint:SetJustifyH("CENTER")
    f.hint:SetTextColor(0.53, 0.53, 0.53)

    -- Mouse interaction
    f:EnableMouse(true)
    f:SetScript("OnEnter", function() SavedInst:CancelHideTimer() end)
    f:SetScript("OnLeave", function() SavedInst:StartHideTimer() end)

    return f
end

---------------------------------------------------------------------------
-- Row management
---------------------------------------------------------------------------

local function GetRow(parent, index)
    if rowPool[index] then
        rowPool[index]:Show()
        return rowPool[index]
    end

    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)

    -- Highlight
    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, 0.06)

    -- Instance name (left)
    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.nameText:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.nameText:SetJustifyH("LEFT")

    -- Difficulty tag
    row.diffText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.diffText:SetJustifyH("CENTER")
    row.diffText:SetWidth(36)

    -- Progress (e.g. "4/8")
    row.progressText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.progressText:SetJustifyH("CENTER")
    row.progressText:SetWidth(40)

    -- Reset timer (right)
    row.resetText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.resetText:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.resetText:SetJustifyH("RIGHT")

    -- Layout: name ... diff ... progress ... reset
    row.diffText:SetPoint("RIGHT", row.progressText, "LEFT", -4, 0)
    row.progressText:SetPoint("RIGHT", row.resetText, "LEFT", -8, 0)

    -- Extended indicator (left bar)
    row.extendedBar = row:CreateTexture(nil, "BACKGROUND")
    row.extendedBar:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.extendedBar:SetSize(3, ROW_HEIGHT - 4)
    row.extendedBar:SetColorTexture(0.3, 1, 0.3, 0.8)

    -- Boss sub-row support
    row.isBossRow = false

    row:SetScript("OnEnter", function(self)
        SavedInst:CancelHideTimer()
    end)
    row:SetScript("OnLeave", function(self)
        SavedInst:StartHideTimer()
    end)

    rowPool[index] = row
    return row
end

local function GetHeader(parent, index)
    if headerPool[index] then
        headerPool[index]:Show()
        return headerPool[index]
    end

    local hdr = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hdr:SetJustifyH("LEFT")
    hdr:SetTextColor(1, 0.82, 0)

    headerPool[index] = hdr
    return hdr
end

local function GetSeparator(parent, index)
    if separatorPool[index] then
        separatorPool[index]:Show()
        return separatorPool[index]
    end

    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetColorTexture(0.3, 0.3, 0.3, 0.5)

    separatorPool[index] = sep
    return sep
end

local function HideAllPooled()
    for _, row in pairs(rowPool) do row:Hide() end
    for _, hdr in pairs(headerPool) do hdr:Hide() end
    for _, sep in pairs(separatorPool) do sep:Hide() end
end

---------------------------------------------------------------------------
-- Tooltip content building
---------------------------------------------------------------------------

local function AddInstanceRow(f, rowIndex, y, entry)
    local row = GetRow(f, rowIndex)
    row:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    row:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)
    row:SetHeight(ROW_HEIGHT)
    row.isBossRow = false

    -- Name
    row.nameText:SetText(entry.name)
    row.nameText:SetTextColor(0.9, 0.9, 0.9)

    -- Difficulty tag with color
    local tag = entry.difficultyTag
    local colors = DIFFICULTY_COLORS[tag] or { 0.7, 0.7, 0.7 }
    row.diffText:SetText(tag)
    row.diffText:SetTextColor(colors[1], colors[2], colors[3])

    -- Progress
    local prog = entry.encounterProgress
    local total = entry.numEncounters
    if total > 0 then
        local ratio = prog / total
        local pr, pg, pb
        if ratio >= 1 then
            pr, pg, pb = 0.0, 1.0, 0.0     -- All cleared: green
        elseif ratio > 0 then
            pr, pg, pb = 1.0, 0.82, 0.0    -- Partial: gold
        else
            pr, pg, pb = 0.5, 0.5, 0.5     -- None: gray
        end
        row.progressText:SetText(string.format("%d/%d", prog, total))
        row.progressText:SetTextColor(pr, pg, pb)
    else
        row.progressText:SetText("")
    end

    -- Reset timer
    row.resetText:SetText(FormatResetTime(entry.reset))
    row.resetText:SetTextColor(0.7, 0.7, 0.7)

    -- Extended indicator
    if entry.extended then
        row.extendedBar:Show()
    else
        row.extendedBar:Hide()
    end

    -- Click to expand/collapse boss list
    row:SetScript("OnClick", function()
        entry.expanded = not entry.expanded
        SavedInst:BuildTooltipContent()
    end)

    return rowIndex, y - ROW_HEIGHT
end

local function AddBossRow(f, rowIndex, y, boss)
    local row = GetRow(f, rowIndex)
    row:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 16, y)
    row:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)
    row:SetHeight(BOSS_ROW_HEIGHT)
    row.isBossRow = true

    row.nameText:SetText("  " .. boss.name)

    if boss.killed then
        row.nameText:SetTextColor(0.5, 0.5, 0.5)
        row.diffText:SetText("|cffcc0000Dead|r")
    else
        row.nameText:SetTextColor(0.3, 1.0, 0.3)
        row.diffText:SetText("|cff00cc00Alive|r")
    end
    row.diffText:SetWidth(40)

    row.progressText:SetText("")
    row.resetText:SetText("")
    row.extendedBar:Hide()
    row.highlight:SetColorTexture(1, 1, 1, 0.03)
    row:SetScript("OnClick", nil)

    return rowIndex, y - BOSS_ROW_HEIGHT
end

function SavedInst:BuildTooltipContent()
    HideAllPooled()

    local f = tooltipFrame
    f.title:SetText("Saved Instances")

    local rowIndex = 0
    local headerIndex = 0
    local sepIndex = 0
    local y = -PADDING - 20 - 6 -- below title + separator

    if #lockoutCache == 0 then
        -- No lockouts message
        headerIndex = headerIndex + 1
        local noData = GetHeader(f, headerIndex)
        noData:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        noData:SetText("|cff888888No active lockouts.|r")
        noData:SetTextColor(0.53, 0.53, 0.53)
        y = y - HEADER_HEIGHT
    else
        -- Column headers
        headerIndex = headerIndex + 1
        local colHdr = GetHeader(f, headerIndex)
        colHdr:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 6, y)
        colHdr:SetText("|cff888888Instance|r")
        colHdr:SetTextColor(0.53, 0.53, 0.53)
        y = y - (HEADER_HEIGHT - 4)

        local showingRaids = false
        local showingDungeons = false

        for _, entry in ipairs(lockoutCache) do
            -- Section header for Raids / Dungeons
            if entry.isRaid and not showingRaids then
                showingRaids = true
                headerIndex = headerIndex + 1
                local raidHdr = GetHeader(f, headerIndex)
                raidHdr:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
                raidHdr:SetText("Raids")
                y = y - HEADER_HEIGHT
            elseif not entry.isRaid and not showingDungeons then
                showingDungeons = true
                if showingRaids then
                    y = y - 4
                    sepIndex = sepIndex + 1
                    local sep = GetSeparator(f, sepIndex)
                    sep:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
                    sep:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)
                    y = y - 6
                end
                headerIndex = headerIndex + 1
                local dungHdr = GetHeader(f, headerIndex)
                dungHdr:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
                dungHdr:SetText("Dungeons")
                y = y - HEADER_HEIGHT
            end

            -- Instance row
            rowIndex = rowIndex + 1
            rowIndex, y = AddInstanceRow(f, rowIndex, y, entry)

            -- Expanded boss list
            if entry.expanded and #entry.bosses > 0 then
                for _, boss in ipairs(entry.bosses) do
                    rowIndex = rowIndex + 1
                    rowIndex, y = AddBossRow(f, rowIndex, y, boss)
                end
            end
        end
    end

    -- Alt lockouts from SavedInstances addon (if available)
    local altSection = self:BuildAltSection(f, y, rowIndex, headerIndex, sepIndex)
    if altSection then
        y = altSection.y
    end

    -- Hint bar
    f.hint:SetText("|cff888888LClick: Refresh  |  Shift+LClick: Raid Info  |  Click Row: Bosses|r")

    -- Size
    local totalHeight = math.abs(y) + PADDING + HINT_HEIGHT + 4
    f:SetSize(TOOLTIP_WIDTH, totalHeight)
end

---------------------------------------------------------------------------
-- Alt lockout integration (reads SavedInstances addon DB if present)
---------------------------------------------------------------------------

function SavedInst:BuildAltSection(f, y, rowIndex, headerIndex, sepIndex)
    -- Check for SavedInstances addon data
    if not SavedInstancesDB or type(SavedInstancesDB) ~= "table" then return nil end
    local toons = SavedInstancesDB.Toons
    if not toons or type(toons) ~= "table" then return nil end

    local playerName = UnitName("player")
    local playerRealm = GetRealmName()
    local playerKey = playerName .. " - " .. playerRealm

    -- Collect alts with lockouts
    local alts = {}
    for toonKey, toonData in pairs(toons) do
        if toonKey ~= playerKey and type(toonData) == "table" then
            local hasLockouts = false
            for key, val in pairs(toonData) do
                -- Instance data is stored with string keys that aren't standard fields
                if type(val) == "table" and key ~= "currency" and key ~= "Quests"
                   and key ~= "MythicKey" and key ~= "BonusRoll" and key ~= "Calling"
                   and key ~= "Warfront" and key ~= "Emissary" and key ~= "WorldBoss" then
                    -- Check if this is an instance entry with lockout data
                    for diffKey, diffData in pairs(val) do
                        if type(diffData) == "table" and diffData.ID and diffData.Locked then
                            hasLockouts = true
                            break
                        end
                    end
                end
                if hasLockouts then break end
            end

            if hasLockouts and toonData.Class then
                table.insert(alts, {
                    key = toonKey,
                    name = toonKey:match("^(.+) %-") or toonKey,
                    class = toonData.Class,
                    level = toonData.Level or 0,
                })
            end
        end
    end

    if #alts == 0 then return nil end

    -- Sort: max level first, then alphabetical
    table.sort(alts, function(a, b)
        if a.level ~= b.level then return a.level > b.level end
        return a.name < b.name
    end)

    -- Section header
    y = y - 4
    sepIndex = sepIndex + 1
    local sep = separatorPool[sepIndex]
    if not sep then
        sep = f:CreateTexture(nil, "ARTWORK")
        sep:SetHeight(1)
        sep:SetColorTexture(0.3, 0.3, 0.3, 0.5)
        separatorPool[sepIndex] = sep
    end
    sep:Show()
    sep:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    sep:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)
    y = y - 6

    headerIndex = headerIndex + 1
    local altHdr = headerPool[headerIndex]
    if not altHdr then
        altHdr = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        altHdr:SetJustifyH("LEFT")
        headerPool[headerIndex] = altHdr
    end
    altHdr:Show()
    altHdr:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    altHdr:SetText("Alt Lockouts (SavedInstances)")
    altHdr:SetTextColor(1, 0.82, 0)
    y = y - HEADER_HEIGHT

    -- Show summary per alt
    for _, alt in ipairs(alts) do
        local toonData = toons[alt.key]
        local lockCount = 0

        for key, val in pairs(toonData) do
            if type(val) == "table" and key ~= "currency" and key ~= "Quests"
               and key ~= "MythicKey" and key ~= "BonusRoll" and key ~= "Calling"
               and key ~= "Warfront" and key ~= "Emissary" and key ~= "WorldBoss" then
                for _, diffData in pairs(val) do
                    if type(diffData) == "table" and diffData.Locked then
                        lockCount = lockCount + 1
                    end
                end
            end
        end

        if lockCount > 0 then
            rowIndex = rowIndex + 1
            local row = GetRow(f, rowIndex)
            row:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
            row:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)
            row:SetHeight(ROW_HEIGHT)

            local nameColor = DDT:ClassColorText(alt.name, alt.class:upper())
            row.nameText:SetText(nameColor)
            row.diffText:SetText("")
            row.progressText:SetText(string.format("%d saved", lockCount))
            row.progressText:SetTextColor(0.7, 0.7, 0.7)
            row.resetText:SetText("Lv " .. alt.level)
            row.resetText:SetTextColor(0.5, 0.5, 0.5)
            row.extendedBar:Hide()
            row:SetScript("OnClick", nil)

            y = y - ROW_HEIGHT
        end
    end

    return { y = y }
end

---------------------------------------------------------------------------
-- Tooltip show/hide
---------------------------------------------------------------------------

function SavedInst:ShowTooltip(anchor)
    self:CancelHideTimer()

    if not tooltipFrame then
        tooltipFrame = CreateTooltipFrame()
    end

    -- Anchor
    tooltipFrame:ClearAllPoints()
    tooltipFrame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)

    -- Ensure data is fresh
    self:UpdateData()
    self:BuildTooltipContent()

    tooltipFrame:Show()
end

function SavedInst:StartHideTimer()
    self:CancelHideTimer()
    hideTimer = C_Timer.NewTimer(ns.HIDE_DELAY, function()
        if tooltipFrame then tooltipFrame:Hide() end
        hideTimer = nil
    end)
end

function SavedInst:CancelHideTimer()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
end

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------

SavedInst.settingsLabel = "Saved Instances"

function SavedInst:BuildSettingsPanel(panel)
    local W = ns.SettingsWidgets
    local c = panel.content
    local y = -10

    y = W.AddHeader(c, y, "Saved Instances")
    y = W.AddDescription(c, y,
        "Shows your current raid and dungeon lockouts.\n\n" ..
        "Click a lockout row in the tooltip to expand/collapse boss kill details.\n\n" ..
        "If the SavedInstances addon is installed, alt lockouts will also be shown.")

    c:SetHeight(math.abs(y) + 20)
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("savedinstances", SavedInst)
