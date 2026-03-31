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

-- Alt lockout expanded state (per session)
local expandedAlts = {}

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
    -- Alt lockout display
    showAlts        = true,
    altColumns      = false,        -- show alt progress as columns next to current char
    altNameLength   = 0,            -- 0 = full name; >0 = truncate column headers to N chars
    altFilter       = "all",        -- all, maxlevel, hasraids, mplus30/60/90/180, manual
    altManualList   = {},           -- { ["Name - Realm"] = true } — used when altFilter == "manual"
    clickActions    = {
        leftClick       = "refresh",
        rightClick      = "greatvault",
        middleClick     = "none",
        shiftLeftClick  = "raidinfo",
        shiftRightClick = "none",
        ctrlLeftClick   = "groupfinder",
        ctrlRightClick  = "none",
        altLeftClick    = "opensettings",
        altRightClick   = "none",
    },
}

local CLICK_ACTIONS = {
    refresh      = "Refresh",
    greatvault   = "Great Vault",
    raidinfo     = "Raid Info",
    groupfinder  = "Group Finder",
    opensettings = "Open DDT Settings",
    none         = "None",
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

-- Alt filter dropdown values
local ALT_FILTER_VALUES = {
    all      = "All with lockouts",
    hasraids = "Has raid lockouts",
    maxlevel = "Max level only",
    mplus30  = "M+ active (30 days)",
    mplus60  = "M+ active (60 days)",
    mplus90  = "M+ active (90 days)",
    mplus180 = "M+ active (180 days)",
    manual   = "Manual selection",
}

-- Sort dropdown values
local RAID_SORT_VALUES = {
    diff_asc  = "Difficulty (LFR > Mythic)",
    diff_desc = "Difficulty (Mythic > LFR)",
    name      = "Name (A-Z)",
    api       = "As Received",
}
local MPLUS_SORT_VALUES = {
    level_asc  = "Level (Low > High)",
    level_desc = "Level (High > Low)",
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
        local db = SavedInst:GetDB()
        local action = DDT:ResolveClickAction(button, db.clickActions or {})
        if action == "refresh" then
            RequestRaidInfo()
        elseif action == "greatvault" then
            if not C_AddOns.IsAddOnLoaded("Blizzard_WeeklyRewards") then
                C_AddOns.LoadAddOn("Blizzard_WeeklyRewards")
            end
            if WeeklyRewardsFrame then
                if WeeklyRewardsFrame:IsShown() then
                    WeeklyRewardsFrame:Hide()
                else
                    WeeklyRewardsFrame:Show()
                end
            end
        elseif action == "raidinfo" then
            ToggleRaidFrame()
        elseif action == "groupfinder" then
            ToggleLFDParentFrame()
        elseif action == "opensettings" then
            if DDT.settingsCategoryID then
                Settings.OpenToCategory(DDT.settingsCategoryID)
            end
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
-- Alt lockout data: save current character to global SavedVariables
---------------------------------------------------------------------------

function SavedInst:SaveCurrentCharData()
    if not ns.db then return end
    if not ns.db.altLockouts then ns.db.altLockouts = {} end

    local playerName  = UnitName("player")
    local playerRealm = GetRealmName()
    local key         = playerName .. " - " .. playerRealm
    local now         = time()
    local existing    = ns.db.altLockouts[key] or {}

    -- Lightweight lockout summary (no boss data — kept small for SavedVariables)
    local lockouts = {}
    for _, entry in ipairs(lockoutCache) do
        table.insert(lockouts, {
            name         = entry.name,
            difficultyTag = entry.difficultyTag,
            progress     = entry.encounterProgress,
            total        = entry.numEncounters,
            reset        = entry.reset,
            isRaid       = entry.isRaid,
            extended     = entry.extended,
        })
    end

    -- M+ run summary
    local mpRuns = {}
    for _, run in ipairs(mythicPlusRuns) do
        table.insert(mpRuns, { name = run.name, level = run.level, completed = run.completed })
    end

    ns.db.altLockouts[key] = {
        name                 = playerName,
        realm                = playerRealm,
        class                = select(2, UnitClass("player")):upper(),
        level                = UnitLevel("player"),
        lastSeen             = now,
        lockouts             = lockouts,
        hasRaids             = raidCount > 0,
        mythicPlusRuns       = mpRuns,
        mythicPlusCount      = mythicPlusCount,
        -- Updated only when M+ runs exist; used for mplus30/60/90/180 filters
        mythicPlusLastActive = (mythicPlusCount > 0) and now or (existing.mythicPlusLastActive or 0),
    }
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
    local E = ns.ExpandTag
    result = E(result, "summary", summary)
    result = E(result, "raids", raidCount)
    result = E(result, "dungeons", dungeonCount)
    result = E(result, "mplus", mythicPlusCount)
    result = E(result, "total", total)
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

    -- Persist this character's data for display on other alts
    self:SaveCurrentCharData()

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
    row.nameText = row:CreateFontString(nil, "OVERLAY", "DDTFontNormal")
    row.nameText:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.nameText:SetPoint("RIGHT", row, "CENTER", -35, 0)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWordWrap(false)

    -- Reset timer (far right, fixed width) — created first so others can anchor to it
    row.resetText = row:CreateFontString(nil, "OVERLAY", "DDTFontNormal")
    row.resetText:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.resetText:SetJustifyH("RIGHT")
    row.resetText:SetWidth(56)

    -- Difficulty tag (right of name)
    row.diffText = row:CreateFontString(nil, "OVERLAY", "DDTFontNormal")
    row.diffText:SetPoint("LEFT", row, "CENTER", -35, 0)
    row.diffText:SetJustifyH("CENTER")
    row.diffText:SetWidth(36)

    -- Progress (e.g. "4/8" or condensed "N 4/8  H 2/8") — fills space between diff and reset
    row.progressText = row:CreateFontString(nil, "OVERLAY", "DDTFontNormal")
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

    local hdr = parent:CreateFontString(nil, "OVERLAY", "DDTFontNormal")
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

-- Renders one alt lockout row (indented, no boss-expand). Returns updated rowIndex, y.
local function RenderAltLockoutRow(f, rowIndex, y, lo, elapsed)
    local lrow = GetRow(f, rowIndex)
    lrow:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 12, y)
    lrow:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)
    lrow:SetHeight(ROW_HEIGHT)
    lrow.isBossRow = false

    lrow.nameText:SetText(lo.name)
    lrow.nameText:SetTextColor(0.8, 0.8, 0.8)

    local colors = DIFFICULTY_COLORS[lo.difficultyTag] or { 0.7, 0.7, 0.7 }
    lrow.diffText:SetText(lo.difficultyTag)
    lrow.diffText:SetTextColor(colors[1], colors[2], colors[3])

    if lo.total and lo.total > 0 then
        local ratio = lo.progress / lo.total
        lrow.progressText:SetText(lo.progress .. "/" .. lo.total)
        if ratio >= 1 then
            lrow.progressText:SetTextColor(0.0, 1.0, 0.0)
        elseif ratio > 0 then
            lrow.progressText:SetTextColor(1.0, 0.82, 0.0)
        else
            lrow.progressText:SetTextColor(0.5, 0.5, 0.5)
        end
    else
        lrow.progressText:SetText("")
    end

    -- Adjust reset time for elapsed since last seen
    local adjustedReset = math.max(0, (lo.reset or 0) - elapsed)
    if adjustedReset > 0 then
        lrow.resetText:SetText(FormatResetTime(adjustedReset))
        lrow.resetText:SetTextColor(0.6, 0.6, 0.6)
    else
        lrow.resetText:SetText("|cff888888Exp|r")
        lrow.resetText:SetTextColor(1, 1, 1)
    end

    if lo.extended then lrow.extendedBar:Show() else lrow.extendedBar:Hide() end
    lrow:SetScript("OnClick", nil)

    return rowIndex, y - ROW_HEIGHT
end

---------------------------------------------------------------------------
-- Alt column display (side-by-side in main tooltip)
---------------------------------------------------------------------------

local ALT_COL_WIDTH = 44
local activeAltCols = {}  -- { { key, name, class }, ... } — rebuilt each tooltip render
local altLockoutMap = {}  -- altLockoutMap[altKey]["InstanceName|DiffTag"] = { progress, total }
local altMPlusMap   = {}  -- altMPlusMap[altKey]["DungeonName"] = highestLevel

-- Populate alt column state. Same filter logic as BuildAltSection.
local function BuildAltColumnData(db, currentKey)
    wipe(activeAltCols)
    wipe(altLockoutMap)
    wipe(altMPlusMap)

    if not db.altColumns or not db.showAlts then return end
    if not ns.db or not ns.db.altLockouts then return end

    local now = time()
    local maxLevel = (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 90
    local filter = db.altFilter or "all"

    local alts = {}
    for key, altData in pairs(ns.db.altLockouts) do
        if key ~= currentKey and type(altData) == "table" then
            local hasLockouts = altData.lockouts and #altData.lockouts > 0
            local hasMPlus    = altData.mythicPlusRuns and #altData.mythicPlusRuns > 0
            if hasLockouts or hasMPlus then
                local pass = false
                if     filter == "all"      then pass = true
                elseif filter == "maxlevel" then pass = (altData.level or 0) >= maxLevel
                elseif filter == "hasraids" then pass = altData.hasRaids == true
                elseif filter == "mplus30"  then pass = (altData.mythicPlusLastActive or 0) > (now - 30  * 86400)
                elseif filter == "mplus60"  then pass = (altData.mythicPlusLastActive or 0) > (now - 60  * 86400)
                elseif filter == "mplus90"  then pass = (altData.mythicPlusLastActive or 0) > (now - 90  * 86400)
                elseif filter == "mplus180" then pass = (altData.mythicPlusLastActive or 0) > (now - 180 * 86400)
                elseif filter == "manual"   then pass = db.altManualList[key] == true
                end
                if pass then
                    table.insert(alts, { key = key, data = altData })
                end
            end
        end
    end

    if #alts == 0 then return end

    table.sort(alts, function(a, b)
        local la, lb = a.data.level or 0, b.data.level or 0
        if la ~= lb then return la > lb end
        return (a.data.name or a.key) < (b.data.name or b.key)
    end)

    -- Build lookup maps
    for _, alt in ipairs(alts) do
        local altData = alt.data
        table.insert(activeAltCols, { key = alt.key, name = altData.name or alt.key, class = altData.class or "" })

        altLockoutMap[alt.key] = {}
        if altData.lockouts then
            for _, lo in ipairs(altData.lockouts) do
                altLockoutMap[alt.key][lo.name .. "|" .. lo.difficultyTag] = { progress = lo.progress, total = lo.total }
            end
        end

        altMPlusMap[alt.key] = {}
        if altData.mythicPlusRuns then
            for _, run in ipairs(altData.mythicPlusRuns) do
                local existing = altMPlusMap[alt.key][run.name]
                if not existing or run.level > existing then
                    altMPlusMap[alt.key][run.name] = run.level
                end
            end
        end
    end
end

-- Ensure a row has the right number of alt-column FontStrings, positioned and visible.
local function EnsureAltColumns(row, count)
    if not row.altTexts then row.altTexts = {} end
    for i = 1, count do
        if not row.altTexts[i] then
            local at = row:CreateFontString(nil, "OVERLAY", "DDTFontSmall")
            at:SetJustifyH("CENTER")
            at:SetWidth(ALT_COL_WIDTH)
            row.altTexts[i] = at
        end
        row.altTexts[i]:Show()
    end
    for i = count + 1, #row.altTexts do
        row.altTexts[i]:Hide()
    end

    if count > 0 then
        -- Chain right-to-left: altTexts[n] → resetText, altTexts[n-1] → altTexts[n], ...
        row.altTexts[count]:SetPoint("RIGHT", row.resetText, "LEFT", -2, 0)
        for i = count - 1, 1, -1 do
            row.altTexts[i]:SetPoint("RIGHT", row.altTexts[i + 1], "LEFT", -2, 0)
        end
        -- Re-anchor progressText to end at first alt column
        row.progressText:SetPoint("RIGHT", row.altTexts[1], "LEFT", -4, 0)
    else
        row.progressText:SetPoint("RIGHT", row.resetText, "LEFT", -4, 0)
    end
end

-- Set alt column data for an instance row (full view: show progress/total per alt).
local function SetAltColumnsForInstance(row, instanceName, diffTag)
    local count = #activeAltCols
    EnsureAltColumns(row, count)
    for i, alt in ipairs(activeAltCols) do
        local data = altLockoutMap[alt.key] and altLockoutMap[alt.key][instanceName .. "|" .. diffTag]
        if data then
            row.altTexts[i]:SetText(data.progress .. "/" .. data.total)
            local ratio = data.total > 0 and (data.progress / data.total) or 0
            if ratio >= 1 then
                row.altTexts[i]:SetTextColor(0.0, 1.0, 0.0)
            elseif ratio > 0 then
                row.altTexts[i]:SetTextColor(1.0, 0.82, 0.0)
            else
                row.altTexts[i]:SetTextColor(0.5, 0.5, 0.5)
            end
        else
            row.altTexts[i]:SetText("-")
            row.altTexts[i]:SetTextColor(0.3, 0.3, 0.3)
        end
    end
end

-- Set alt column data for a condensed raid row (show count of lockouts for that instance).
local function SetAltColumnsForCondensedRaid(row, instanceName)
    local count = #activeAltCols
    EnsureAltColumns(row, count)
    for i, alt in ipairs(activeAltCols) do
        local lockCount = 0
        for mapKey, _ in pairs(altLockoutMap[alt.key] or {}) do
            local instName = mapKey:match("^(.+)|")
            if instName == instanceName then
                lockCount = lockCount + 1
            end
        end
        if lockCount > 0 then
            row.altTexts[i]:SetText("x" .. lockCount)
            row.altTexts[i]:SetTextColor(0.7, 0.7, 0.7)
        else
            row.altTexts[i]:SetText("-")
            row.altTexts[i]:SetTextColor(0.3, 0.3, 0.3)
        end
    end
end

-- Set alt column data for an M+ row (show highest key level for that dungeon).
local function SetAltColumnsForMPlus(row, dungeonName)
    local count = #activeAltCols
    EnsureAltColumns(row, count)
    for i, alt in ipairs(activeAltCols) do
        local level = altMPlusMap[alt.key] and altMPlusMap[alt.key][dungeonName]
        if level then
            row.altTexts[i]:SetText("+" .. level)
            local lvlColor = DIFFICULTY_COLORS["M+"] or { 0.78, 0, 1 }
            row.altTexts[i]:SetTextColor(lvlColor[1], lvlColor[2], lvlColor[3])
        else
            row.altTexts[i]:SetText("-")
            row.altTexts[i]:SetTextColor(0.3, 0.3, 0.3)
        end
    end
end

-- Clear alt columns on a row (e.g. boss sub-rows, headers).
local function ClearAltColumns(row)
    if row.altTexts then
        for _, at in ipairs(row.altTexts) do at:Hide() end
    end
    row.progressText:SetPoint("RIGHT", row.resetText, "LEFT", -4, 0)
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

    -- Build alt column lookup for side-by-side display
    local playerKey = UnitName("player") .. " - " .. GetRealmName()
    BuildAltColumnData(db, playerKey)
    local numAltCols = #activeAltCols

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

        -- Alt name column headers (aligned with data columns)
        if numAltCols > 0 then
            for i, alt in ipairs(activeAltCols) do
                headerIndex = headerIndex + 1
                local altNameHdr = GetHeader(f, headerIndex)
                altNameHdr:ClearAllPoints()
                local rightOff = -(PADDING + 56 + 2 + (numAltCols - i) * (ALT_COL_WIDTH + 2))
                altNameHdr:SetPoint("TOPRIGHT", f, "TOPRIGHT", rightOff, y)
                altNameHdr:SetWidth(ALT_COL_WIDTH)
                altNameHdr:SetJustifyH("CENTER")
                local displayName = alt.name
                local nameLen = db.altNameLength or 0
                if nameLen > 0 then displayName = displayName:sub(1, nameLen) end
                altNameHdr:SetText(DDT:ClassColorText(displayName, alt.class:upper()))
            end
        end

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
                    if numAltCols > 0 then SetAltColumnsForCondensedRaid(row, raidName) end

                    y = y - ROW_HEIGHT
                end
            else
                -- Full view
                for _, entry in ipairs(raids) do
                    rowIndex = rowIndex + 1
                    rowIndex, y = AddInstanceRow(f, rowIndex, y, entry)
                    if numAltCols > 0 then SetAltColumnsForInstance(rowPool[rowIndex], entry.name, entry.difficultyTag) end
                    if entry.expanded and #entry.bosses > 0 then
                        for _, boss in ipairs(entry.bosses) do
                            rowIndex = rowIndex + 1
                            rowIndex, y = AddBossRow(f, rowIndex, y, boss)
                            if numAltCols > 0 then ClearAltColumns(rowPool[rowIndex]) end
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
                if numAltCols > 0 then SetAltColumnsForInstance(rowPool[rowIndex], entry.name, entry.difficultyTag) end
                if entry.expanded and #entry.bosses > 0 then
                    for _, boss in ipairs(entry.bosses) do
                        rowIndex = rowIndex + 1
                        rowIndex, y = AddBossRow(f, rowIndex, y, boss)
                        if numAltCols > 0 then ClearAltColumns(rowPool[rowIndex]) end
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
                if numAltCols > 0 then SetAltColumnsForMPlus(row, dungeonName) end

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
                if numAltCols > 0 then SetAltColumnsForMPlus(row, run.name) end

                y = y - ROW_HEIGHT
            end
        end
    end

    -- Alt lockouts section (expandable per-alt detail — hidden when column view is active)
    if not db.altColumns then
        local altSection = self:BuildAltSection(f, y, rowIndex, headerIndex, sepIndex)
        if altSection then
            y = altSection.y
        end
    end

    -- Hint bar
    local hintParts = DDT:BuildHintText(db.clickActions or {}, CLICK_ACTIONS)
    if hintParts ~= "" then
        f.hint:SetText(hintParts .. "  |  |cff888888Row: Bosses|r")
    else
        f.hint:SetText("|cff888888Row: Bosses|r")
    end

    -- Size (expand width for alt columns)
    local ttWidth = db.tooltipWidth or TOOLTIP_WIDTH
    if numAltCols > 0 then
        ttWidth = ttWidth + numAltCols * (ALT_COL_WIDTH + 2)
    end
    local totalHeight = math.abs(y) + PADDING + HINT_HEIGHT + 4
    f:SetSize(ttWidth, totalHeight)
end

---------------------------------------------------------------------------
-- Alt lockout section (reads DDT's own DjinnisDataTextsDB.altLockouts)
---------------------------------------------------------------------------

function SavedInst:BuildAltSection(f, y, rowIndex, headerIndex, sepIndex)
    local db = self:GetDB()
    if not db.showAlts then return nil end
    if not ns.db or not ns.db.altLockouts then return nil end

    local playerName = UnitName("player")
    local playerRealm = GetRealmName()
    local currentKey = playerName .. " - " .. playerRealm
    local now = time()
    local maxLevel = (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 90
    local filter = db.altFilter or "all"

    -- Collect alts that pass the active filter and have any data
    local alts = {}
    for key, altData in pairs(ns.db.altLockouts) do
        if key ~= currentKey and type(altData) == "table" then
            local hasLockouts = altData.lockouts and #altData.lockouts > 0
            local hasMPlus    = altData.mythicPlusRuns and #altData.mythicPlusRuns > 0
            if hasLockouts or hasMPlus then
                local pass = false
                if     filter == "all"      then pass = true
                elseif filter == "maxlevel" then pass = (altData.level or 0) >= maxLevel
                elseif filter == "hasraids" then pass = altData.hasRaids == true
                elseif filter == "mplus30"  then pass = (altData.mythicPlusLastActive or 0) > (now - 30  * 86400)
                elseif filter == "mplus60"  then pass = (altData.mythicPlusLastActive or 0) > (now - 60  * 86400)
                elseif filter == "mplus90"  then pass = (altData.mythicPlusLastActive or 0) > (now - 90  * 86400)
                elseif filter == "mplus180" then pass = (altData.mythicPlusLastActive or 0) > (now - 180 * 86400)
                elseif filter == "manual"   then pass = db.altManualList[key] == true
                end
                if pass then
                    table.insert(alts, { key = key, data = altData })
                end
            end
        end
    end

    if #alts == 0 then return nil end

    -- Sort: highest level first, then alphabetical by name
    table.sort(alts, function(a, b)
        local la, lb = a.data.level or 0, b.data.level or 0
        if la ~= lb then return la > lb end
        return (a.data.name or a.key) < (b.data.name or b.key)
    end)

    -- Section separator + header
    y = y - 4
    sepIndex = sepIndex + 1
    local sep = GetSeparator(f, sepIndex)
    sep:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    sep:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)
    y = y - 6

    headerIndex = headerIndex + 1
    local altHdr = GetHeader(f, headerIndex)
    altHdr:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    altHdr:SetText("Alt Lockouts")
    altHdr:SetTextColor(1, 0.82, 0)
    y = y - HEADER_HEIGHT

    for _, alt in ipairs(alts) do
        local altData  = alt.data
        local lockouts = altData.lockouts or {}
        local mpRuns   = altData.mythicPlusRuns or {}
        local elapsed  = now - (altData.lastSeen or now)

        -- Build summary badge: "2R 1D 3M+"
        local rCt, dCt, mCt = 0, 0, altData.mythicPlusCount or 0
        for _, lo in ipairs(lockouts) do
            if lo.isRaid then rCt = rCt + 1 else dCt = dCt + 1 end
        end
        local summaryParts = {}
        if rCt > 0 then table.insert(summaryParts, rCt .. "R") end
        if dCt > 0 then table.insert(summaryParts, dCt .. "D") end
        if mCt > 0 then table.insert(summaryParts, mCt .. "M+") end
        local summary = #summaryParts > 0 and table.concat(summaryParts, " ") or "No lockouts"

        local isExpanded = expandedAlts[alt.key]
        local arrow = isExpanded and "|cffaaaaaa▼|r " or "|cffaaaaaa▶|r "

        -- Alt summary row (click to expand)
        rowIndex = rowIndex + 1
        local row = GetRow(f, rowIndex)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        row:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)
        row:SetHeight(ROW_HEIGHT)
        row.isBossRow = false

        row.nameText:SetText(arrow .. DDT:ClassColorText(altData.name or alt.key, (altData.class or ""):upper()))
        row.nameText:SetTextColor(1, 1, 1)
        row.diffText:SetText("")
        row.progressText:SetText(summary)
        row.progressText:SetTextColor(0.7, 0.7, 0.7)
        row.resetText:SetText("Lv " .. (altData.level or "?"))
        row.resetText:SetTextColor(0.5, 0.5, 0.5)
        row.extendedBar:Hide()

        local capturedKey = alt.key
        row:SetScript("OnClick", function()
            expandedAlts[capturedKey] = not expandedAlts[capturedKey]
            SavedInst:BuildTooltipContent()
        end)

        y = y - ROW_HEIGHT

        -- Expanded: show individual lockout rows
        if isExpanded then
            -- Split and sort raids/dungeons using main sort setting
            local altRaids, altDungs = {}, {}
            for _, lo in ipairs(lockouts) do
                if lo.isRaid then table.insert(altRaids, lo) else table.insert(altDungs, lo) end
            end
            SortRaidEntries(altRaids, db.raidSortOrder)
            SortRaidEntries(altDungs, db.raidSortOrder)

            for _, lo in ipairs(altRaids) do
                rowIndex = rowIndex + 1
                rowIndex, y = RenderAltLockoutRow(f, rowIndex, y, lo, elapsed)
            end
            for _, lo in ipairs(altDungs) do
                rowIndex = rowIndex + 1
                rowIndex, y = RenderAltLockoutRow(f, rowIndex, y, lo, elapsed)
            end

            -- M+ runs
            if #mpRuns > 0 then
                local sortedRuns = {}
                for _, r in ipairs(mpRuns) do table.insert(sortedRuns, r) end
                SortMPlusRuns(sortedRuns, db.mplusSortOrder)

                local lvlColor = DIFFICULTY_COLORS["M+"] or { 0.78, 0, 1 }
                for _, run in ipairs(sortedRuns) do
                    rowIndex = rowIndex + 1
                    local lrow = GetRow(f, rowIndex)
                    lrow:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 12, y)
                    lrow:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)
                    lrow:SetHeight(ROW_HEIGHT)
                    lrow.isBossRow = false

                    lrow.nameText:SetText(run.name)
                    lrow.nameText:SetTextColor(0.8, 0.8, 0.8)
                    lrow.diffText:SetText("+" .. run.level)
                    lrow.diffText:SetTextColor(lvlColor[1], lvlColor[2], lvlColor[3])
                    lrow.progressText:SetText(run.completed and "|cff00cc00Timed|r" or "|cffcc0000Over|r")
                    lrow.resetText:SetText("")
                    lrow.extendedBar:Hide()
                    lrow:SetScript("OnClick", nil)

                    y = y - ROW_HEIGHT
                end
            end
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
    y = W.AddLabelEditBox(c, y, "summary raids dungeons mplus total",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateData() end, r, {
        { "Default",    "<summary>" },
        { "Split",      "R:<raids> D:<dungeons>" },
        { "M+ Focus",   "M+: <mplus>  Saved: <total>" },
        { "Count",      "<total> lockouts" },
    })

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

    -- Alt Lockouts (before click actions so it's easier to find)
    y = W.AddHeader(c, y, "Alt Lockouts")
    y = W.AddCheckbox(c, y, "Show alt lockout section in tooltip",
        function() return db().showAlts end,
        function(v) db().showAlts = v; refreshTT() end, r)
    y = W.AddCheckbox(c, y, "Show alt progress columns alongside current character",
        function() return db().altColumns end,
        function(v) db().altColumns = v; refreshTT() end, r)
    y = W.AddDescription(c, y,
        "|cff888888When column view is active, the expandable alt section is hidden.|r")
    y = W.AddSlider(c, y, "Column name length (0 = full name)", 0, 12, 1,
        function() return db().altNameLength end,
        function(v) db().altNameLength = v; refreshTT() end, r)
    y = W.AddDropdown(c, y, "Show alts matching", ALT_FILTER_VALUES,
        function() return db().altFilter end,
        function(v) db().altFilter = v; refreshTT() end, r)

    -- Manual alt selection: always shown so users can pre-configure before switching to manual
    y = W.AddDescription(c, y, "Manual selection (used when filter = \"Manual selection\"):")

    local altDB = ns.db and ns.db.altLockouts
    local playerName  = UnitName("player")
    local playerRealm = GetRealmName()
    local currentKey  = playerName .. " - " .. playerRealm

    if altDB then
        local knownAlts = {}
        for key, altData in pairs(altDB) do
            if key ~= currentKey and type(altData) == "table" then
                table.insert(knownAlts, { key = key, data = altData })
            end
        end
        table.sort(knownAlts, function(a, b)
            local la, lb = a.data.level or 0, b.data.level or 0
            if la ~= lb then return la > lb end
            return (a.data.name or a.key) < (b.data.name or b.key)
        end)

        if #knownAlts == 0 then
            y = W.AddDescription(c, y, "|cff888888No alts recorded yet. Log in to each alt to populate.|r")
        else
            for _, alt in ipairs(knownAlts) do
                local label = DDT:ClassColorText(alt.data.name or alt.key, (alt.data.class or ""):upper())
                              .. " |cff888888(Lv " .. (alt.data.level or "?") .. ")|r"
                local capturedKey = alt.key
                y = W.AddCheckbox(c, y, label,
                    function() return db().altManualList[capturedKey] == true end,
                    function(v) db().altManualList[capturedKey] = v or nil; refreshTT() end, r)
            end
        end
    else
        y = W.AddDescription(c, y, "|cff888888No alts recorded yet. Log in to each alt to populate.|r")
    end

    y = ns.AddModuleClickActionsSection(c, r, y, "savedinstances", CLICK_ACTIONS)
    y = W.AddDescription(c, y,
        "Click a lockout row: Expand/collapse boss details")

    c:SetHeight(math.abs(y) + 20)
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("savedinstances", SavedInst, DEFAULTS)
