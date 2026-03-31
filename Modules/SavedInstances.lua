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

-- M+ run history cache
local mythicPlusRuns = {}   -- { { name, level, completed } }  sorted by level desc
local mythicPlusCount = 0   -- total completed M+ runs this week
local vaultProgress = {}    -- { { progress, threshold, level } }  Great Vault tiers

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

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
    labelTemplate   = "<summary>",
    condensedRaids  = false,
    condensedMPlus  = false,
    raidSortOrder   = "diff_asc",   -- diff_asc, diff_desc, name, api
    mplusSortOrder  = "level_asc",  -- level_asc, level_desc, name, api
    tooltipScale    = 1.0,
    tooltipWidth    = 380,
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

-- Difficulty rank for sort ordering
local DIFFICULTY_RANK = {
    T   = 0,
    LFR = 1,
    N   = 2,
    H   = 3,
    M   = 4,
    ["M+"]  = 4,
    ["10N"] = 2, ["25N"] = 2,
    ["10H"] = 3, ["25H"] = 3,
    ["40"]  = 1,
}

-- Sort dropdown values
local RAID_SORT_VALUES = {
    diff_asc  = "Difficulty (LFR \226\134\146 Mythic)",
    diff_desc = "Difficulty (Mythic \226\134\146 LFR)",
    name      = "Name (A-Z)",
    api       = "As Received",
}
local MPLUS_SORT_VALUES = {
    level_asc  = "Level (Low \226\134\146 High)",
    level_desc = "Level (High \226\134\146 Low)",
    name       = "Name (A-Z)",
    api        = "As Received",
}

---------------------------------------------------------------------------
-- Sort helpers
---------------------------------------------------------------------------

local function SortRaidEntries(entries, order)
    if order == "diff_asc" then
        table.sort(entries, function(a, b)
            if a.name ~= b.name then return a.name < b.name end
            local ra, rb = DIFFICULTY_RANK[a.difficultyTag] or 0, DIFFICULTY_RANK[b.difficultyTag] or 0
            return ra < rb
        end)
    elseif order == "diff_desc" then
        table.sort(entries, function(a, b)
            if a.name ~= b.name then return a.name < b.name end
            local ra, rb = DIFFICULTY_RANK[a.difficultyTag] or 0, DIFFICULTY_RANK[b.difficultyTag] or 0
            return ra > rb
        end)
    elseif order == "name" then
        table.sort(entries, function(a, b)
            if a.name ~= b.name then return a.name < b.name end
            local ra, rb = DIFFICULTY_RANK[a.difficultyTag] or 0, DIFFICULTY_RANK[b.difficultyTag] or 0
            return ra < rb
        end)
    end
    -- "api" = no sort, keep original order
end

local function SortMPlusRuns(runs, order)
    if order == "level_desc" then
        table.sort(runs, function(a, b)
            if a.level ~= b.level then return a.level > b.level end
            return a.name < b.name
        end)
    elseif order == "level_asc" then
        table.sort(runs, function(a, b)
            if a.level ~= b.level then return a.level < b.level end
            return a.name < b.name
        end)
    elseif order == "name" then
        table.sort(runs, function(a, b)
            if a.name ~= b.name then return a.name < b.name end
            return a.level > b.level
        end)
    end
    -- "api" = no sort, keep original order
end

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
                if C_MythicPlus and C_MythicPlus.RequestMapInfo then
                    C_MythicPlus.RequestMapInfo()
                end
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
    eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    eventFrame:RegisterEvent("WEEKLY_REWARDS_UPDATE")
end

function SavedInst:GetDB()
    return ns.db and ns.db.savedinstances or DEFAULTS
end

---------------------------------------------------------------------------
-- Label template expansion
---------------------------------------------------------------------------

local function ExpandLabel(template)
    local total = raidCount + dungeonCount
    local parts = {}
    if raidCount > 0 then table.insert(parts, raidCount .. "R") end
    if dungeonCount > 0 then table.insert(parts, dungeonCount .. "D") end
    if mythicPlusCount > 0 then table.insert(parts, mythicPlusCount .. "M+") end
    local summary = #parts > 0 and ("Lockouts: " .. table.concat(parts, " ")) or "No Lockouts"

    local result = template
    result = result:gsub("<summary>", summary)
    result = result:gsub("<raids>", tostring(raidCount))
    result = result:gsub("<dungeons>", tostring(dungeonCount))
    result = result:gsub("<mplus>", tostring(mythicPlusCount))
    result = result:gsub("<total>", tostring(total))
    return result
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

            local apiIdx = #lockoutCache + 1
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
                apiOrder         = apiIdx,
            })

            if isRaid then
                raidCount = raidCount + 1
            else
                dungeonCount = dungeonCount + 1
            end
        end
    end

    -- M+ run history (weekly)
    wipe(mythicPlusRuns)
    mythicPlusCount = 0
    wipe(vaultProgress)

    if C_MythicPlus and C_MythicPlus.GetRunHistory then
        local runHistory = C_MythicPlus.GetRunHistory(false, true)
        if runHistory then
            for idx, run in ipairs(runHistory) do
                local dungeonName = C_ChallengeMode and C_ChallengeMode.GetMapUIInfo
                    and C_ChallengeMode.GetMapUIInfo(run.mapChallengeModeID) or "Unknown"
                table.insert(mythicPlusRuns, {
                    name      = dungeonName,
                    level     = run.level,
                    completed = run.completed,
                    apiOrder  = idx,
                })
                if run.completed then
                    mythicPlusCount = mythicPlusCount + 1
                end
            end
        end
    end

    -- Great Vault progress
    if C_WeeklyRewards and C_WeeklyRewards.GetActivities then
        local activities = C_WeeklyRewards.GetActivities(Enum.WeeklyRewardChestThresholdType.Activities)
        if activities then
            table.sort(activities, function(a, b) return a.index < b.index end)
            for _, info in ipairs(activities) do
                table.insert(vaultProgress, {
                    progress  = info.progress,
                    threshold = info.threshold,
                    level     = info.level,
                })
            end
        end
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

    -- Instance name (left side, ~35-40% of row)
    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.nameText:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.nameText:SetPoint("RIGHT", row, "CENTER", -35, 0)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWordWrap(false)

    -- Reset timer (far right, fixed width) — created first so others can anchor to it
    row.resetText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.resetText:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.resetText:SetJustifyH("RIGHT")
    row.resetText:SetWidth(56)

    -- Difficulty tag (right of name)
    row.diffText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.diffText:SetPoint("LEFT", row, "CENTER", -35, 0)
    row.diffText:SetJustifyH("CENTER")
    row.diffText:SetWidth(36)

    -- Progress (e.g. "4/8" or condensed "N 4/8  H 2/8") — fills space between diff and reset
    row.progressText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.progressText:SetPoint("LEFT", row.diffText, "RIGHT", 4, 0)
    row.progressText:SetPoint("RIGHT", row.resetText, "LEFT", -4, 0)
    row.progressText:SetJustifyH("LEFT")
    row.progressText:SetWordWrap(false)

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
    local db = self:GetDB()
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

        -- Separate raids and dungeons, then sort per user setting
        local raids, dungeons = {}, {}
        for _, entry in ipairs(lockoutCache) do
            if entry.isRaid then
                table.insert(raids, entry)
            else
                table.insert(dungeons, entry)
            end
        end
        SortRaidEntries(raids, db.raidSortOrder)
        SortRaidEntries(dungeons, db.raidSortOrder)

        -- Raids section
        if #raids > 0 then
            headerIndex = headerIndex + 1
            local raidHdr = GetHeader(f, headerIndex)
            raidHdr:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
            raidHdr:SetText("Raids")
            y = y - HEADER_HEIGHT

            if db.condensedRaids then
                -- Condensed: group by instance name (same layout as condensed M+)
                local raidGroups = {}
                local raidOrder = {}
                for _, entry in ipairs(raids) do
                    if not raidGroups[entry.name] then
                        raidGroups[entry.name] = {}
                        table.insert(raidOrder, entry.name)
                    end
                    table.insert(raidGroups[entry.name], entry)
                end

                for _, raidName in ipairs(raidOrder) do
                    local entries = raidGroups[raidName]
                    local diffParts = {}
                    for _, entry in ipairs(entries) do
                        local colors = DIFFICULTY_COLORS[entry.difficultyTag] or { 0.7, 0.7, 0.7 }
                        local hex = string.format("|cff%02x%02x%02x", colors[1] * 255, colors[2] * 255, colors[3] * 255)
                        local prog = ""
                        if entry.numEncounters > 0 then
                            prog = " " .. entry.encounterProgress .. "/" .. entry.numEncounters
                        end
                        table.insert(diffParts, hex .. entry.difficultyTag .. prog .. "|r")
                    end

                    rowIndex = rowIndex + 1
                    local row = GetRow(f, rowIndex)
                    row:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
                    row:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)
                    row:SetHeight(ROW_HEIGHT)

                    row.nameText:SetText(raidName)
                    row.nameText:SetTextColor(0.9, 0.9, 0.9)

                    row.diffText:SetText("x" .. #entries)
                    row.diffText:SetTextColor(0.7, 0.7, 0.7)

                    row.progressText:SetText(table.concat(diffParts, " "))
                    row.progressText:SetTextColor(1, 1, 1)
                    row.resetText:SetText("")
                    row.extendedBar:Hide()
                    row:SetScript("OnClick", nil)

                    y = y - ROW_HEIGHT
                end
            else
                -- Full view
                for _, entry in ipairs(raids) do
                    rowIndex = rowIndex + 1
                    rowIndex, y = AddInstanceRow(f, rowIndex, y, entry)
                    if entry.expanded and #entry.bosses > 0 then
                        for _, boss in ipairs(entry.bosses) do
                            rowIndex = rowIndex + 1
                            rowIndex, y = AddBossRow(f, rowIndex, y, boss)
                        end
                    end
                end
            end
        end

        -- Dungeons section
        if #dungeons > 0 then
            if #raids > 0 then
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

            for _, entry in ipairs(dungeons) do
                rowIndex = rowIndex + 1
                rowIndex, y = AddInstanceRow(f, rowIndex, y, entry)
                if entry.expanded and #entry.bosses > 0 then
                    for _, boss in ipairs(entry.bosses) do
                        rowIndex = rowIndex + 1
                        rowIndex, y = AddBossRow(f, rowIndex, y, boss)
                    end
                end
            end
        end
    end

    -- M+ runs this week
    if #mythicPlusRuns > 0 then
        y = y - 4
        sepIndex = sepIndex + 1
        local mpSep = GetSeparator(f, sepIndex)
        mpSep:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        mpSep:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)
        y = y - 6

        -- Vault progress summary
        local vaultText = ""
        if #vaultProgress > 0 then
            local vaultParts = {}
            for i, tier in ipairs(vaultProgress) do
                if tier.progress >= tier.threshold then
                    table.insert(vaultParts, "|cff00cc00" .. tier.progress .. "/" .. tier.threshold .. "|r")
                else
                    table.insert(vaultParts, tier.progress .. "/" .. tier.threshold)
                end
            end
            vaultText = "  |cff888888(Vault: " .. table.concat(vaultParts, " ") .. ")|r"
        end

        headerIndex = headerIndex + 1
        local mpHdr = GetHeader(f, headerIndex)
        mpHdr:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        mpHdr:SetText("Mythic+ This Week (" .. mythicPlusCount .. ")" .. vaultText)
        y = y - HEADER_HEIGHT

        SortMPlusRuns(mythicPlusRuns, db.mplusSortOrder)

        if db.condensedMPlus then
            -- Condensed view: group runs by dungeon
            local dungeonGroups = {}
            local dungeonOrder = {}
            for _, run in ipairs(mythicPlusRuns) do
                if not dungeonGroups[run.name] then
                    dungeonGroups[run.name] = {}
                    table.insert(dungeonOrder, run.name)
                end
                table.insert(dungeonGroups[run.name], run)
            end

            local lvlColor = DIFFICULTY_COLORS["M+"] or { 0.78, 0, 1 }
            for _, dungeonName in ipairs(dungeonOrder) do
                local runs = dungeonGroups[dungeonName]
                -- Build level list (already sorted desc from mythicPlusRuns)
                local levels = {}
                for _, run in ipairs(runs) do
                    local prefix = run.completed and "|cff00cc00" or "|cffcc0000"
                    table.insert(levels, prefix .. "+" .. run.level .. "|r")
                end

                rowIndex = rowIndex + 1
                local row = GetRow(f, rowIndex)
                row:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
                row:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)
                row:SetHeight(ROW_HEIGHT)

                row.nameText:SetText(dungeonName)
                row.nameText:SetTextColor(0.9, 0.9, 0.9)

                row.diffText:SetText("x" .. #runs)
                row.diffText:SetTextColor(lvlColor[1], lvlColor[2], lvlColor[3])

                row.progressText:SetText(table.concat(levels, " "))
                row.progressText:SetTextColor(1, 1, 1)
                row.resetText:SetText("")
                row.extendedBar:Hide()
                row:SetScript("OnClick", nil)

                y = y - ROW_HEIGHT
            end
        else
            -- Full view: one row per run
            for _, run in ipairs(mythicPlusRuns) do
                rowIndex = rowIndex + 1
                local row = GetRow(f, rowIndex)
                row:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
                row:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)
                row:SetHeight(ROW_HEIGHT)

                row.nameText:SetText(run.name)
                row.nameText:SetTextColor(0.9, 0.9, 0.9)

                local lvlColor = DIFFICULTY_COLORS["M+"] or { 0.78, 0, 1 }
                row.diffText:SetText("+" .. run.level)
                row.diffText:SetTextColor(lvlColor[1], lvlColor[2], lvlColor[3])

                if run.completed then
                    row.progressText:SetText("|cff00cc00Timed|r")
                else
                    row.progressText:SetText("|cffcc0000Over|r")
                end

                row.resetText:SetText("")
                row.extendedBar:Hide()
                row:SetScript("OnClick", nil)

                y = y - ROW_HEIGHT
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
    local ttWidth = db.tooltipWidth or TOOLTIP_WIDTH
    local totalHeight = math.abs(y) + PADDING + HINT_HEIGHT + 4
    f:SetSize(ttWidth, totalHeight)
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

    -- Anchor & scale
    local db = self:GetDB()
    tooltipFrame:ClearAllPoints()
    tooltipFrame:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 4)
    tooltipFrame:SetScale(db.tooltipScale or 1.0)

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
    local r = panel.refreshCallbacks
    local y = -10
    local db = function() return ns.db.savedinstances end
    local refreshTT = function()
        if tooltipFrame and tooltipFrame:IsShown() then self:BuildTooltipContent() end
    end

    y = W.AddHeader(c, y, "Label Template")
    y = W.AddDescription(c, y, "Tags: <summary> <raids> <dungeons> <mplus> <total>")
    y = W.AddEditBox(c, y, "Template",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateData() end, r)

    y = W.AddHeader(c, y, "Display")
    y = W.AddCheckbox(c, y, "Condensed raid view (group difficulties per instance)",
        function() return db().condensedRaids end,
        function(v) db().condensedRaids = v; refreshTT() end, r)
    y = W.AddCheckbox(c, y, "Condensed M+ view (group by dungeon)",
        function() return db().condensedMPlus end,
        function(v) db().condensedMPlus = v; refreshTT() end, r)

    y = W.AddHeader(c, y, "Sorting")
    y = W.AddDropdown(c, y, "Raid / Dungeon Order", RAID_SORT_VALUES,
        function() return db().raidSortOrder end,
        function(v) db().raidSortOrder = v; refreshTT() end, r)
    y = W.AddDropdown(c, y, "Mythic+ Order", MPLUS_SORT_VALUES,
        function() return db().mplusSortOrder end,
        function(v) db().mplusSortOrder = v; refreshTT() end, r)

    y = W.AddHeader(c, y, "Tooltip")
    y = W.AddSlider(c, y, "Scale", 0.5, 2.0, 0.05,
        function() return db().tooltipScale end,
        function(v) db().tooltipScale = v end, r)
    y = W.AddSlider(c, y, "Width", 300, 600, 10,
        function() return db().tooltipWidth end,
        function(v) db().tooltipWidth = v; refreshTT() end, r)

    y = W.AddHeader(c, y, "Interactions")
    y = W.AddDescription(c, y,
        "Left-click: Refresh lockout data\n" ..
        "Shift+Left-click: Open Raid Info\n" ..
        "Click a lockout row: Expand/collapse boss details")

    c:SetHeight(math.abs(y) + 20)
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("savedinstances", SavedInst, DEFAULTS)
