-- Djinni's Data Texts - Saved Instances
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

-- Delve run history cache (uses Great Vault "World" threshold type)
local delveRuns = {}        -- { { tier, count } }  sorted by tier desc
local delveCount = 0        -- total delve completions this week
local delveVaultProgress = {} -- { { progress, threshold, level } }  Great Vault World tiers

-- Delve self-tracking: captures individual completions with instance names
-- Stored in DjinnisDataTextsDB.delveHistory[charKey] = { weekStart = N, runs = { { name, tier, timestamp }, ... } }
local delveTrackedRuns = {}     -- { { name, tier, timestamp } }  individual completions this week
local preDelveVaultSnapshot = nil   -- snapshot of vault data taken on zone-in, used to determine tier on completion
local isInDelve = false         -- true when inside a delve instance

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
    showDelves      = true,
    condensedDelves = false,
    delveSortOrder  = "tier_desc",  -- tier_desc, tier_asc, count_desc, count_asc
    raidSortOrder   = "diff_asc",   -- diff_asc, diff_desc, name, api
    mplusSortOrder  = "level_asc",  -- level_asc, level_desc, name, api
    tooltipScale     = 1.0,
    tooltipMaxHeight = 600,
    tooltipWidth     = 380,
    -- Alt lockout display
    showAlts        = true,
    altColumns      = false,        -- show alt progress as columns next to current char
    altNameLength   = 0,            -- 0 = full name; >0 = truncate column headers to N chars
    altHoverAnchor  = "ANCHOR_BOTTOM",  -- GameTooltip anchor direction
    altHoverRealm   = true,
    altHoverClass   = true,
    altHoverSpec    = true,
    altHoverRole    = true,
    altFilter       = "all",        -- all, maxlevel, hasraids, mplus30/60/90/180, manual
    altManualList   = {},           -- { ["Name - Realm"] = true } - used when altFilter == "manual"
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
local DELVE_SORT_VALUES = {
    tier_desc  = "Tier (High > Low)",
    tier_asc   = "Tier (Low > High)",
    count_desc = "Count (High > Low)",
    count_asc  = "Count (Low > High)",
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

local function SortDelveRuns(runs, order)
    if order == "tier_desc" then
        table.sort(runs, function(a, b) return a.tier > b.tier end)
    elseif order == "tier_asc" then
        table.sort(runs, function(a, b) return a.tier < b.tier end)
    elseif order == "count_desc" then
        table.sort(runs, function(a, b)
            if a.count ~= b.count then return a.count > b.count end
            return a.tier > b.tier
        end)
    elseif order == "count_asc" then
        table.sort(runs, function(a, b)
            if a.count ~= b.count then return a.count < b.count end
            return a.tier > b.tier
        end)
    end
end

---------------------------------------------------------------------------
-- Delve self-tracking helpers
---------------------------------------------------------------------------

-- Get the weekly reset timestamp (start of current week)
local function GetCurrentWeekStart()
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local secsLeft = C_DateAndTime.GetSecondsUntilWeeklyReset()
        -- Weekly reset is 7 days from now minus remaining seconds
        return time() + secsLeft - (7 * 86400)
    end
    return 0
end

-- Load tracked delve runs from SavedVariables for this character
local function LoadDelveHistory()
    wipe(delveTrackedRuns)
    if not ns.db then return end
    if not ns.db.delveHistory then ns.db.delveHistory = {} end

    local playerKey = UnitName("player") .. " - " .. GetRealmName()
    local charData = ns.db.delveHistory[playerKey]
    if not charData then return end

    -- Check weekly reset - clear stale data
    local weekStart = GetCurrentWeekStart()
    if (charData.weekStart or 0) < weekStart then
        charData.runs = {}
        charData.weekStart = weekStart
        return
    end

    for _, run in ipairs(charData.runs or {}) do
        table.insert(delveTrackedRuns, { name = run.name, tier = run.tier, timestamp = run.timestamp })
    end
end

-- Save tracked delve runs to SavedVariables
local function SaveDelveHistory()
    if not ns.db then return end
    if not ns.db.delveHistory then ns.db.delveHistory = {} end

    local playerKey = UnitName("player") .. " - " .. GetRealmName()
    local runs = {}
    for _, run in ipairs(delveTrackedRuns) do
        table.insert(runs, { name = run.name, tier = run.tier, timestamp = run.timestamp })
    end
    ns.db.delveHistory[playerKey] = {
        weekStart = GetCurrentWeekStart(),
        runs = runs,
    }
end

-- Take a snapshot of the vault's World progress before a delve starts
local function SnapshotVaultProgress()
    if not (C_WeeklyRewards and C_WeeklyRewards.GetSortedProgressForActivity) then return nil end
    local sorted = C_WeeklyRewards.GetSortedProgressForActivity(Enum.WeeklyRewardChestThresholdType.World, true)
    if not sorted then return nil end
    local snap = {}
    for _, entry in ipairs(sorted) do
        snap[entry.difficulty] = (snap[entry.difficulty] or 0) + entry.numPoints
    end
    return snap
end

-- Determine the tier of the delve just completed by diffing vault snapshots
local function DetermineCompletedTier(priorSnap)
    if not (C_WeeklyRewards and C_WeeklyRewards.GetSortedProgressForActivity) then return nil end
    local sorted = C_WeeklyRewards.GetSortedProgressForActivity(Enum.WeeklyRewardChestThresholdType.World, true)
    if not sorted then return nil end

    local currentSnap = {}
    for _, entry in ipairs(sorted) do
        currentSnap[entry.difficulty] = (currentSnap[entry.difficulty] or 0) + entry.numPoints
    end

    if not priorSnap then return nil end
    -- Find the tier where count increased
    for tier, count in pairs(currentSnap) do
        local priorCount = priorSnap[tier] or 0
        if count > priorCount then
            return tier
        end
    end
    return nil
end

-- Check if we're currently in a delve instance
local function CheckIsInDelve()
    if C_DelvesUI and C_DelvesUI.HasActiveDelve then
        local _, _, _, mapID = UnitPosition("player")
        if mapID then
            return C_DelvesUI.HasActiveDelve(mapID)
        end
    end
    -- Fallback: check C_PartyInfo
    if C_PartyInfo and C_PartyInfo.IsDelveInProgress then
        return C_PartyInfo.IsDelveInProgress()
    end
    return false
end

-- Called when SCENARIO_COMPLETED fires while in a delve
local function OnDelveCompleted()
    local instanceName = GetInstanceInfo()
    local tier = DetermineCompletedTier(preDelveVaultSnapshot)

    -- If vault diff didn't work, try to estimate from the instance difficulty name
    if not tier then
        local _, _, difficultyID, difficultyName = GetInstanceInfo()
        -- Blizzard source: difficulties above 1 are guaranteed to be Delves
        -- difficultyName often contains the tier, e.g. "Level 8"
        local levelMatch = difficultyName and difficultyName:match("(%d+)")
        if levelMatch then
            tier = tonumber(levelMatch)
        end
    end

    tier = tier or 0

    table.insert(delveTrackedRuns, {
        name = instanceName or "Unknown Delve",
        tier = tier,
        timestamp = time(),
    })
    SaveDelveHistory()

    -- Refresh data so tooltip updates
    SavedInst:UpdateData()
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
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            -- Delay initial request to avoid login congestion
            C_Timer.After(3, function()
                RequestRaidInfo()
                if C_MythicPlus and C_MythicPlus.RequestMapInfo then
                    C_MythicPlus.RequestMapInfo()
                end
                LoadDelveHistory()
                SavedInst:UpdateData()
                -- Also check delve state on login/reload
                isInDelve = CheckIsInDelve()
                if isInDelve then
                    preDelveVaultSnapshot = SnapshotVaultProgress()
                end
            end)
        elseif event == "ZONE_CHANGED_NEW_AREA" then
            -- Track delve zone-in: snapshot vault data for tier detection
            C_Timer.After(1, function()
                local wasInDelve = isInDelve
                isInDelve = CheckIsInDelve()
                if isInDelve and not wasInDelve then
                    preDelveVaultSnapshot = SnapshotVaultProgress()
                elseif not isInDelve then
                    preDelveVaultSnapshot = nil
                end
            end)
            SavedInst:UpdateData()
        elseif event == "SCENARIO_COMPLETED" then
            -- If we just completed a scenario while in a delve, record it
            if isInDelve or CheckIsInDelve() then
                -- Slight delay to let vault data update
                C_Timer.After(2, function()
                    OnDelveCompleted()
                    isInDelve = false
                    preDelveVaultSnapshot = nil
                end)
            end
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
    eventFrame:RegisterEvent("SCENARIO_COMPLETED")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
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

    -- Lightweight lockout summary (no boss data - kept small for SavedVariables)
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

    -- Delve run summary
    local dvRuns = {}
    for _, run in ipairs(delveRuns) do
        table.insert(dvRuns, { tier = run.tier, count = run.count })
    end

    -- Current spec and role
    local specName, specRole
    local specID = GetSpecialization and GetSpecialization()
    if specID then
        _, specName, _, _, specRole = GetSpecializationInfo(specID)
    end

    ns.db.altLockouts[key] = {
        name                 = playerName,
        realm                = playerRealm,
        class                = select(2, UnitClass("player")):upper(),
        level                = UnitLevel("player"),
        specName             = specName or "",
        role                 = specRole or "",   -- TANK, HEALER, DAMAGER
        lastSeen             = now,
        lockouts             = lockouts,
        hasRaids             = raidCount > 0,
        mythicPlusRuns       = mpRuns,
        mythicPlusCount      = mythicPlusCount,
        delveRuns            = dvRuns,
        delveCount           = delveCount,
        delveTrackedRuns     = CopyTable(delveTrackedRuns),
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
    if delveCount > 0 then table.insert(parts, delveCount .. "Dv") end
    local summary = #parts > 0 and ("Lockouts: " .. table.concat(parts, " ")) or "No Lockouts"

    local result = template
    local E = ns.ExpandTag
    result = E(result, "summary", summary)
    result = E(result, "raids", raidCount)
    result = E(result, "dungeons", dungeonCount)
    result = E(result, "mplus", mythicPlusCount)
    result = E(result, "delves", delveCount)
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

    -- Great Vault progress (M+/Dungeons)
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

    -- Delve / World activity progress (Great Vault "World" threshold type)
    wipe(delveRuns)
    delveCount = 0
    wipe(delveVaultProgress)

    if C_WeeklyRewards and C_WeeklyRewards.GetActivities then
        -- Vault tier progress (progress/threshold per slot)
        local worldActivities = C_WeeklyRewards.GetActivities(Enum.WeeklyRewardChestThresholdType.World)
        if worldActivities then
            table.sort(worldActivities, function(a, b) return a.index < b.index end)
            for _, info in ipairs(worldActivities) do
                table.insert(delveVaultProgress, {
                    progress  = info.progress,
                    threshold = info.threshold,
                    level     = info.level,
                })
            end
        end

        -- Per-tier breakdown: difficulty = delve tier, numPoints = completions
        if C_WeeklyRewards.GetSortedProgressForActivity then
            local sorted = C_WeeklyRewards.GetSortedProgressForActivity(Enum.WeeklyRewardChestThresholdType.World, true)
            if sorted then
                for _, entry in ipairs(sorted) do
                    table.insert(delveRuns, {
                        tier  = entry.difficulty,
                        count = entry.numPoints,
                    })
                    delveCount = delveCount + entry.numPoints
                end
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
    local f = ns.CreateTooltipFrame("DDTSavedInstancesTooltip", SavedInst)
    f.content.lines = {}
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
    row:SetHeight(ns.ROW_HEIGHT)

    -- Highlight
    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, 0.06)

    -- Instance name (left side, ~35-40% of row)
    row.nameText = ns.FontString(row, "DDTFontNormal")
    row.nameText:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.nameText:SetPoint("RIGHT", row, "CENTER", -35, 0)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWordWrap(false)

    -- Reset timer (far right, fixed width) - created first so others can anchor to it
    row.resetText = ns.FontString(row, "DDTFontNormal")
    row.resetText:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.resetText:SetJustifyH("RIGHT")
    row.resetText:SetWidth(56)

    -- Difficulty tag (right of name)
    row.diffText = ns.FontString(row, "DDTFontNormal")
    row.diffText:SetPoint("LEFT", row, "CENTER", -35, 0)
    row.diffText:SetJustifyH("CENTER")
    row.diffText:SetWidth(36)

    -- Progress (e.g. "4/8" or condensed "N 4/8  H 2/8") - fills space between diff and reset
    row.progressText = ns.FontString(row, "DDTFontNormal")
    row.progressText:SetPoint("LEFT", row.diffText, "RIGHT", 4, 0)
    row.progressText:SetPoint("RIGHT", row.resetText, "LEFT", -4, 0)
    row.progressText:SetJustifyH("LEFT")
    row.progressText:SetWordWrap(false)

    -- Extended indicator (left bar)
    row.extendedBar = row:CreateTexture(nil, "BACKGROUND")
    row.extendedBar:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.extendedBar:SetSize(3, ns.ROW_HEIGHT - 4)
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

    local hdr = ns.FontString(parent, "DDTFontNormal")
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
local function RenderAltLockoutRow(c, rowIndex, y, lo, elapsed)
    local lrow = GetRow(c, rowIndex)
    lrow:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING + 12, y)
    lrow:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
    lrow:SetHeight(ns.ROW_HEIGHT)
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

    return rowIndex, y - ns.ROW_HEIGHT
end

---------------------------------------------------------------------------
-- Alt column display (side-by-side in main tooltip)
---------------------------------------------------------------------------

local ALT_COL_WIDTH = 44
local activeAltCols = {}  -- { { key, name, class }, ... } - rebuilt each tooltip render
local altLockoutMap = {}  -- altLockoutMap[altKey]["InstanceName|DiffTag"] = { progress, total }
local altMPlusMap   = {}  -- altMPlusMap[altKey]["DungeonName"] = highestLevel
local altDelveMap   = {}  -- altDelveMap[altKey] = { delveCount, bestTier }

-- Populate alt column state. Same filter logic as BuildAltSection.
local function BuildAltColumnData(db, currentKey)
    wipe(activeAltCols)
    wipe(altLockoutMap)
    wipe(altMPlusMap)
    wipe(altDelveMap)

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
            local hasDelves   = (altData.delveCount or 0) > 0
            if hasLockouts or hasMPlus or hasDelves then
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

        -- Delve summary for alt columns
        local altDelveCount = altData.delveCount or 0
        local altBestTier = 0
        if altData.delveRuns then
            for _, run in ipairs(altData.delveRuns) do
                if run.tier > altBestTier then altBestTier = run.tier end
            end
        end
        altDelveMap[alt.key] = { count = altDelveCount, bestTier = altBestTier }
    end
end

-- Ensure a row has the right number of alt-column FontStrings + a "you" column, positioned and visible.
local function EnsureAltColumns(row, count)
    if not row.altTexts then row.altTexts = {} end

    -- "You" (current character) column - same style as alt columns
    if not row.youText then
        local yt = ns.FontString(row, "DDTFontSmall")
        yt:SetJustifyH("CENTER")
        yt:SetWidth(ALT_COL_WIDTH)
        row.youText = yt
    end
    row.youText:Show()

    for i = 1, count do
        if not row.altTexts[i] then
            local at = ns.FontString(row, "DDTFontSmall")
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
        -- Chain right-to-left: altTexts[n] → resetText, ..., altTexts[1], youText
        row.altTexts[count]:SetPoint("RIGHT", row.resetText, "LEFT", -2, 0)
        for i = count - 1, 1, -1 do
            row.altTexts[i]:SetPoint("RIGHT", row.altTexts[i + 1], "LEFT", -2, 0)
        end
        row.youText:SetPoint("RIGHT", row.altTexts[1], "LEFT", -2, 0)
    else
        -- No alts, but still show "you" column
        row.youText:SetPoint("RIGHT", row.resetText, "LEFT", -2, 0)
    end
    -- Re-anchor progressText to end at the "you" column
    row.progressText:SetPoint("RIGHT", row.youText, "LEFT", -4, 0)
end

-- Set alt column data for an instance row (full view: show progress/total per alt).
local function SetAltColumnsForInstance(row, instanceName, diffTag, entry)
    local count = #activeAltCols
    EnsureAltColumns(row, count)

    -- "You" column: current character's progress for this lockout
    if entry and not entry.isGhost then
        row.youText:SetText(entry.encounterProgress .. "/" .. entry.numEncounters)
        local ratio = entry.numEncounters > 0 and (entry.encounterProgress / entry.numEncounters) or 0
        if ratio >= 1 then
            row.youText:SetTextColor(0.0, 1.0, 0.0)
        elseif ratio > 0 then
            row.youText:SetTextColor(1.0, 0.82, 0.0)
        else
            row.youText:SetTextColor(0.5, 0.5, 0.5)
        end
    else
        row.youText:SetText("-")
        row.youText:SetTextColor(0.3, 0.3, 0.3)
    end

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
local function SetAltColumnsForCondensedRaid(row, instanceName, youDiffCount)
    local count = #activeAltCols
    EnsureAltColumns(row, count)

    -- "You" column: number of different difficulties the current char has for this instance
    if youDiffCount and youDiffCount > 0 then
        row.youText:SetText("x" .. youDiffCount)
        row.youText:SetTextColor(0.7, 0.7, 0.7)
    else
        row.youText:SetText("-")
        row.youText:SetTextColor(0.3, 0.3, 0.3)
    end

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
local function SetAltColumnsForMPlus(row, dungeonName, youHighest)
    local count = #activeAltCols
    EnsureAltColumns(row, count)

    -- "You" column: current character's highest key for this dungeon
    if youHighest then
        row.youText:SetText("+" .. youHighest)
        local lvlColor = DIFFICULTY_COLORS["M+"] or { 0.78, 0, 1 }
        row.youText:SetTextColor(lvlColor[1], lvlColor[2], lvlColor[3])
    else
        row.youText:SetText("-")
        row.youText:SetTextColor(0.3, 0.3, 0.3)
    end

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
    if row.youText then row.youText:Hide() end
    if row.altTexts then
        for _, at in ipairs(row.altTexts) do at:Hide() end
    end
    row.progressText:SetPoint("RIGHT", row.resetText, "LEFT", -4, 0)
end

---------------------------------------------------------------------------
-- Column header hover overlays & column highlights
---------------------------------------------------------------------------

local colHdrOverlayPool = {}
local colHighlightPool = {}   -- vertical highlight strips per column

local function GetColHdrOverlay(parent, index)
    if colHdrOverlayPool[index] then
        colHdrOverlayPool[index]:Show()
        return colHdrOverlayPool[index]
    end
    local ov = CreateFrame("Frame", nil, parent)
    ov:EnableMouse(true)
    colHdrOverlayPool[index] = ov
    return ov
end

local function GetColHighlight(parent, index)
    if colHighlightPool[index] then
        colHighlightPool[index]:Hide()
        return colHighlightPool[index]
    end
    local hl = parent:CreateTexture(nil, "BACKGROUND", nil, 1)
    hl:SetColorTexture(1, 1, 1, 0.06)
    hl:Hide()
    colHighlightPool[index] = hl
    return hl
end

local function HideColHighlights()
    for _, hl in pairs(colHighlightPool) do hl:Hide() end
end

local function HideColHdrOverlays()
    for _, ov in pairs(colHdrOverlayPool) do ov:Hide() end
    HideColHighlights()
end

local ROLE_LABELS = { TANK = "Tank", HEALER = "Healer", DAMAGER = "DPS" }

function SavedInst:ShowCharTooltip(anchor, charInfo)
    local db = self:GetDB()
    GameTooltip:SetOwner(anchor, db.altHoverAnchor or "ANCHOR_BOTTOM")
    GameTooltip:AddLine(charInfo.name, 1, 0.82, 0)

    if db.altHoverRealm and charInfo.realm and charInfo.realm ~= "" then
        GameTooltip:AddLine("Realm: " .. charInfo.realm, 0.7, 0.7, 0.7)
    end
    if db.altHoverClass and charInfo.class and charInfo.class ~= "" then
        local cc = RAID_CLASS_COLORS[charInfo.class]
        local className = charInfo.class:sub(1, 1) .. charInfo.class:sub(2):lower():gsub("_(%l)", function(c) return " " .. c:upper() end)
        if cc then
            GameTooltip:AddLine("Class: " .. className, cc.r, cc.g, cc.b)
        else
            GameTooltip:AddLine("Class: " .. className, 0.7, 0.7, 0.7)
        end
    end
    if db.altHoverSpec and charInfo.specName and charInfo.specName ~= "" then
        GameTooltip:AddLine("Spec: " .. charInfo.specName, 0.7, 0.7, 0.7)
    end
    if db.altHoverRole and charInfo.role and charInfo.role ~= "" then
        GameTooltip:AddLine("Role: " .. (ROLE_LABELS[charInfo.role] or charInfo.role), 0.7, 0.7, 0.7)
    end

    GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Tooltip content building
---------------------------------------------------------------------------

local function AddInstanceRow(c, rowIndex, y, entry)
    local row = GetRow(c, rowIndex)
    row:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
    row:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
    row:SetHeight(ns.ROW_HEIGHT)
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
    if entry.isGhost then
        row.progressText:SetText("|cff555555-|r")
        row.resetText:SetText("")
        row.extendedBar:Hide()
        row.nameText:SetTextColor(0.5, 0.5, 0.5)
        row:SetScript("OnClick", nil)
    else
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
    end

    return rowIndex, y - ns.ROW_HEIGHT
end

local function AddBossRow(c, rowIndex, y, boss)
    local row = GetRow(c, rowIndex)
    row:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING + 16, y)
    row:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
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
    HideColHdrOverlays()

    local f = tooltipFrame
    local c = f.content
    local db = self:GetDB()
    f.header:SetText("Saved Instances")

    -- Build alt column lookup for side-by-side display
    local playerKey = UnitName("player") .. " - " .. GetRealmName()
    BuildAltColumnData(db, playerKey)
    local numAltCols = #activeAltCols

    local rowIndex = 0
    local headerIndex = 0
    local sepIndex = 0
    local y = 0

    -- Check if any alt has lockouts or M+ data (for alt-column mode)
    local anyAltHasData = false
    if numAltCols > 0 then
        for _, alt in ipairs(activeAltCols) do
            local altMap = altLockoutMap[alt.key]
            if altMap and next(altMap) then anyAltHasData = true; break end
            local mpMap = altMPlusMap[alt.key]
            if mpMap and next(mpMap) then anyAltHasData = true; break end
        end
    end

    if #lockoutCache == 0 and #mythicPlusRuns == 0 and not anyAltHasData then
        -- No lockouts message
        headerIndex = headerIndex + 1
        local noData = GetHeader(c, headerIndex)
        noData:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
        noData:SetText("|cff888888No active lockouts.|r")
        noData:SetTextColor(0.53, 0.53, 0.53)
        y = y - HEADER_HEIGHT
    else
        -- Column headers
        headerIndex = headerIndex + 1
        local colHdr = GetHeader(c, headerIndex)
        colHdr:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING + 6, y)
        colHdr:SetText("|cff888888Instance|r")
        colHdr:SetTextColor(0.53, 0.53, 0.53)

        -- Character column headers: current character + alts (when alt columns active)
        if numAltCols > 0 then
            local nameLen = db.altNameLength or 0
            local ovIdx = 0
            local hlIdx = 0

            -- Current character header (positioned just left of alt columns)
            headerIndex = headerIndex + 1
            local youHdr = GetHeader(c, headerIndex)
            youHdr:ClearAllPoints()
            local youRightOff = -(PADDING + 6 + 56 + 2 + numAltCols * (ALT_COL_WIDTH + 2))
            youHdr:SetPoint("TOPRIGHT", c, "TOPRIGHT", youRightOff, y)
            youHdr:SetWidth(ALT_COL_WIDTH)
            youHdr:SetJustifyH("CENTER")
            local youName = UnitName("player")
            local youClass = select(2, UnitClass("player")):upper()
            local youDisplay = youName
            if nameLen > 0 then youDisplay = youDisplay:sub(1, nameLen) end
            youHdr:SetText(DDT:ClassColorText(youDisplay, youClass))

            -- Column highlight for "you"
            hlIdx = hlIdx + 1
            local youHL = GetColHighlight(c, hlIdx)
            youHL:ClearAllPoints()
            youHL:SetPoint("TOPRIGHT", c, "TOPRIGHT", youRightOff, y)
            youHL:SetWidth(ALT_COL_WIDTH)
            youHL:SetPoint("BOTTOM", c, "BOTTOM", 0, 0)

            -- Hover overlay for current character
            ovIdx = ovIdx + 1
            local youOv = GetColHdrOverlay(c, ovIdx)
            youOv:ClearAllPoints()
            youOv:SetPoint("TOPRIGHT", c, "TOPRIGHT", youRightOff, y)
            youOv:SetSize(ALT_COL_WIDTH, HEADER_HEIGHT)
            local capturedYouHL = youHL
            youOv:SetScript("OnEnter", function(self)
                SavedInst:CancelHideTimer()
                capturedYouHL:Show()
                local specID = GetSpecialization and GetSpecialization()
                local specName, specRole
                if specID then _, specName, _, _, specRole = GetSpecializationInfo(specID) end
                SavedInst:ShowCharTooltip(self, {
                    name = youName, realm = GetRealmName(), class = youClass,
                    specName = specName or "", role = specRole or "",
                })
            end)
            youOv:SetScript("OnLeave", function()
                capturedYouHL:Hide()
                GameTooltip:Hide()
                SavedInst:StartHideTimer()
            end)

            -- Alt column headers
            for i, alt in ipairs(activeAltCols) do
                headerIndex = headerIndex + 1
                local altNameHdr = GetHeader(c, headerIndex)
                altNameHdr:ClearAllPoints()
                local rightOff = -(PADDING + 6 + 56 + 2 + (numAltCols - i) * (ALT_COL_WIDTH + 2))
                altNameHdr:SetPoint("TOPRIGHT", c, "TOPRIGHT", rightOff, y)
                altNameHdr:SetWidth(ALT_COL_WIDTH)
                altNameHdr:SetJustifyH("CENTER")
                local displayName = alt.name
                if nameLen > 0 then displayName = displayName:sub(1, nameLen) end
                altNameHdr:SetText(DDT:ClassColorText(displayName, alt.class:upper()))

                -- Column highlight for this alt
                hlIdx = hlIdx + 1
                local altHL = GetColHighlight(c, hlIdx)
                altHL:ClearAllPoints()
                altHL:SetPoint("TOPRIGHT", c, "TOPRIGHT", rightOff, y)
                altHL:SetWidth(ALT_COL_WIDTH)
                altHL:SetPoint("BOTTOM", c, "BOTTOM", 0, 0)

                -- Hover overlay for this alt
                ovIdx = ovIdx + 1
                local altOv = GetColHdrOverlay(c, ovIdx)
                altOv:ClearAllPoints()
                altOv:SetPoint("TOPRIGHT", c, "TOPRIGHT", rightOff, y)
                altOv:SetSize(ALT_COL_WIDTH, HEADER_HEIGHT)
                local capturedAlt = alt
                local capturedAltHL = altHL
                altOv:SetScript("OnEnter", function(self)
                    SavedInst:CancelHideTimer()
                    capturedAltHL:Show()
                    local altData = ns.db.altLockouts and ns.db.altLockouts[capturedAlt.key] or {}
                    SavedInst:ShowCharTooltip(self, {
                        name = altData.name or capturedAlt.name,
                        realm = altData.realm or "",
                        class = altData.class or capturedAlt.class,
                        specName = altData.specName or "",
                        role = altData.role or "",
                    })
                end)
                altOv:SetScript("OnLeave", function()
                    capturedAltHL:Hide()
                    GameTooltip:Hide()
                    SavedInst:StartHideTimer()
                end)
            end
        end

        y = y - (HEADER_HEIGHT - 4)

        -- Separate raids and dungeons, then sort per user setting
        local raids, dungeons = {}, {}
        local currentInstanceKeys = {}  -- track what current char already has
        for _, entry in ipairs(lockoutCache) do
            currentInstanceKeys[entry.name .. "|" .. entry.difficultyTag] = true
            if entry.isRaid then
                table.insert(raids, entry)
            else
                table.insert(dungeons, entry)
            end
        end

        -- Inject alt-only lockouts as synthetic entries (ghost rows)
        if numAltCols > 0 then
            local altOnlyKeys = {}  -- deduplicate across alts
            for _, alt in ipairs(activeAltCols) do
                local altData = ns.db.altLockouts and ns.db.altLockouts[alt.key]
                if altData and altData.lockouts then
                    for _, lo in ipairs(altData.lockouts) do
                        local mapKey = lo.name .. "|" .. lo.difficultyTag
                        if not currentInstanceKeys[mapKey] and not altOnlyKeys[mapKey] then
                            altOnlyKeys[mapKey] = true
                            local ghost = {
                                name = lo.name,
                                difficultyTag = lo.difficultyTag,
                                encounterProgress = 0,
                                numEncounters = lo.total or 0,
                                reset = 0,
                                isRaid = lo.isRaid,
                                extended = false,
                                bosses = {},
                                isGhost = true,  -- flag: current char has no lockout here
                            }
                            if lo.isRaid then
                                table.insert(raids, ghost)
                            else
                                table.insert(dungeons, ghost)
                            end
                        end
                    end
                end
            end
        end

        SortRaidEntries(raids, db.raidSortOrder)
        SortRaidEntries(dungeons, db.raidSortOrder)

        -- Raids section
        if #raids > 0 then
            headerIndex = headerIndex + 1
            local raidHdr = GetHeader(c, headerIndex)
            raidHdr:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
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
                    local youCount = 0
                    for _, entry in ipairs(entries) do
                        if not entry.isGhost then
                            youCount = youCount + 1
                            local colors = DIFFICULTY_COLORS[entry.difficultyTag] or { 0.7, 0.7, 0.7 }
                            local hex = string.format("|cff%02x%02x%02x", colors[1] * 255, colors[2] * 255, colors[3] * 255)
                            local prog = ""
                            if entry.numEncounters > 0 then
                                prog = " " .. entry.encounterProgress .. "/" .. entry.numEncounters
                            end
                            table.insert(diffParts, hex .. entry.difficultyTag .. prog .. "|r")
                        end
                    end

                    rowIndex = rowIndex + 1
                    local row = GetRow(c, rowIndex)
                    row:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
                    row:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
                    row:SetHeight(ns.ROW_HEIGHT)

                    row.nameText:SetText(raidName)
                    row.nameText:SetTextColor(0.9, 0.9, 0.9)

                    if youCount > 0 then
                        row.diffText:SetText("x" .. youCount)
                        row.diffText:SetTextColor(0.7, 0.7, 0.7)
                        row.progressText:SetText(table.concat(diffParts, " "))
                        row.progressText:SetTextColor(1, 1, 1)
                    else
                        row.diffText:SetText("")
                        row.progressText:SetText("|cff555555(alt only)|r")
                    end
                    row.resetText:SetText("")
                    row.extendedBar:Hide()
                    row:SetScript("OnClick", nil)
                    if numAltCols > 0 then SetAltColumnsForCondensedRaid(row, raidName, youCount) end

                    y = y - ns.ROW_HEIGHT
                end
            else
                -- Full view
                for _, entry in ipairs(raids) do
                    rowIndex = rowIndex + 1
                    rowIndex, y = AddInstanceRow(c, rowIndex, y, entry)
                    if numAltCols > 0 then SetAltColumnsForInstance(rowPool[rowIndex], entry.name, entry.difficultyTag, entry) end
                    if entry.expanded and #entry.bosses > 0 then
                        for _, boss in ipairs(entry.bosses) do
                            rowIndex = rowIndex + 1
                            rowIndex, y = AddBossRow(c, rowIndex, y, boss)
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
                local sep = GetSeparator(c, sepIndex)
                sep:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
                sep:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
                y = y - 6
            end
            headerIndex = headerIndex + 1
            local dungHdr = GetHeader(c, headerIndex)
            dungHdr:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
            dungHdr:SetText("Dungeons")
            y = y - HEADER_HEIGHT

            for _, entry in ipairs(dungeons) do
                rowIndex = rowIndex + 1
                rowIndex, y = AddInstanceRow(c, rowIndex, y, entry)
                if numAltCols > 0 then SetAltColumnsForInstance(rowPool[rowIndex], entry.name, entry.difficultyTag, entry) end
                if entry.expanded and #entry.bosses > 0 then
                    for _, boss in ipairs(entry.bosses) do
                        rowIndex = rowIndex + 1
                        rowIndex, y = AddBossRow(c, rowIndex, y, boss)
                        if numAltCols > 0 then ClearAltColumns(rowPool[rowIndex]) end
                    end
                end
            end
        end
    end

    -- Check if any alt has M+ runs
    local anyAltHasMPlus = false
    if numAltCols > 0 then
        for _, alt in ipairs(activeAltCols) do
            if altMPlusMap[alt.key] and next(altMPlusMap[alt.key]) then
                anyAltHasMPlus = true; break
            end
        end
    end

    -- M+ runs this week
    if #mythicPlusRuns > 0 or anyAltHasMPlus then
        y = y - 4
        sepIndex = sepIndex + 1
        local mpSep = GetSeparator(c, sepIndex)
        mpSep:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
        mpSep:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
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
        local mpHdr = GetHeader(c, headerIndex)
        mpHdr:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
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
                local row = GetRow(c, rowIndex)
                row:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
                row:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
                row:SetHeight(ns.ROW_HEIGHT)

                row.nameText:SetText(dungeonName)
                row.nameText:SetTextColor(0.9, 0.9, 0.9)

                row.diffText:SetText("x" .. #runs)
                row.diffText:SetTextColor(lvlColor[1], lvlColor[2], lvlColor[3])

                row.progressText:SetText(table.concat(levels, " "))
                row.progressText:SetTextColor(1, 1, 1)
                row.resetText:SetText("")
                row.extendedBar:Hide()
                row:SetScript("OnClick", nil)
                -- Highest key for this dungeon (runs are sorted desc)
                if numAltCols > 0 then SetAltColumnsForMPlus(row, dungeonName, runs[1].level) end

                y = y - ns.ROW_HEIGHT
            end
        else
            -- Full view: one row per run
            for _, run in ipairs(mythicPlusRuns) do
                rowIndex = rowIndex + 1
                local row = GetRow(c, rowIndex)
                row:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
                row:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
                row:SetHeight(ns.ROW_HEIGHT)

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
                if numAltCols > 0 then SetAltColumnsForMPlus(row, run.name, run.level) end

                y = y - ns.ROW_HEIGHT
            end
        end

        -- Inject alt-only M+ dungeon rows (dungeons no current char run exists for)
        if numAltCols > 0 then
            local currentDungeons = {}
            for _, run in ipairs(mythicPlusRuns) do
                currentDungeons[run.name] = true
            end
            -- Collect unique alt-only dungeon names
            local altOnlyDungeons = {}
            local altOnlyOrder = {}
            for _, alt in ipairs(activeAltCols) do
                for dungeonName in pairs(altMPlusMap[alt.key] or {}) do
                    if not currentDungeons[dungeonName] and not altOnlyDungeons[dungeonName] then
                        altOnlyDungeons[dungeonName] = true
                        table.insert(altOnlyOrder, dungeonName)
                    end
                end
            end
            table.sort(altOnlyOrder)
            for _, dungeonName in ipairs(altOnlyOrder) do
                rowIndex = rowIndex + 1
                local row = GetRow(c, rowIndex)
                row:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
                row:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
                row:SetHeight(ns.ROW_HEIGHT)

                row.nameText:SetText(dungeonName)
                row.nameText:SetTextColor(0.5, 0.5, 0.5)
                row.diffText:SetText("")
                row.progressText:SetText("|cff555555-|r")
                row.resetText:SetText("")
                row.extendedBar:Hide()
                row:SetScript("OnClick", nil)
                if numAltCols > 0 then SetAltColumnsForMPlus(row, dungeonName, nil) end

                y = y - ns.ROW_HEIGHT
            end
        end
    end

    -- Delves this week
    local hasDelveData = #delveRuns > 0 or #delveTrackedRuns > 0
    if hasDelveData and db.showDelves ~= false then
        y = y - 4
        sepIndex = sepIndex + 1
        local dvSep = GetSeparator(c, sepIndex)
        dvSep:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
        dvSep:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
        y = y - 6

        -- Vault progress summary
        local dvVaultText = ""
        if #delveVaultProgress > 0 then
            local dvVaultParts = {}
            for i, tier in ipairs(delveVaultProgress) do
                if tier.progress >= tier.threshold then
                    table.insert(dvVaultParts, "|cff00cc00" .. tier.progress .. "/" .. tier.threshold .. "|r")
                else
                    table.insert(dvVaultParts, tier.progress .. "/" .. tier.threshold)
                end
            end
            dvVaultText = "  |cff888888(Vault: " .. table.concat(dvVaultParts, " ") .. ")|r"
        end

        headerIndex = headerIndex + 1
        local dvHdr = GetHeader(c, headerIndex)
        dvHdr:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
        dvHdr:SetText("Delves This Week (" .. delveCount .. ")" .. dvVaultText)
        y = y - HEADER_HEIGHT

        local dvColor = { 0.0, 0.76, 0.36 }  -- Emerald green for delves
        local hasTrackedNames = #delveTrackedRuns > 0

        if db.condensedDelves then
            if hasTrackedNames then
                -- Condensed with tracked names: group by delve name
                local delveGroups = {}
                local delveOrder = {}
                for _, run in ipairs(delveTrackedRuns) do
                    if not delveGroups[run.name] then
                        delveGroups[run.name] = {}
                        table.insert(delveOrder, run.name)
                    end
                    table.insert(delveGroups[run.name], run)
                end

                for _, delveName in ipairs(delveOrder) do
                    local runs = delveGroups[delveName]
                    local tierParts = {}
                    for _, run in ipairs(runs) do
                        table.insert(tierParts, string.format("|cff%02x%02x%02x%s|r",
                            dvColor[1] * 255, dvColor[2] * 255, dvColor[3] * 255,
                            "T" .. run.tier))
                    end

                    rowIndex = rowIndex + 1
                    local row = GetRow(c, rowIndex)
                    row:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
                    row:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
                    row:SetHeight(ns.ROW_HEIGHT)

                    row.nameText:SetText(delveName)
                    row.nameText:SetTextColor(0.9, 0.9, 0.9)

                    row.diffText:SetText("x" .. #runs)
                    row.diffText:SetTextColor(dvColor[1], dvColor[2], dvColor[3])

                    row.progressText:SetText(table.concat(tierParts, " "))
                    row.progressText:SetTextColor(1, 1, 1)
                    row.resetText:SetText("")
                    row.extendedBar:Hide()
                    row:SetScript("OnClick", nil)

                    y = y - ns.ROW_HEIGHT
                end
            else
                -- Condensed without tracked names: single row with tier breakdown
                SortDelveRuns(delveRuns, db.delveSortOrder)
                local tierParts = {}
                for _, run in ipairs(delveRuns) do
                    for j = 1, run.count do
                        table.insert(tierParts, string.format("|cff%02x%02x%02x%s|r",
                            dvColor[1] * 255, dvColor[2] * 255, dvColor[3] * 255,
                            "T" .. run.tier))
                    end
                end

                rowIndex = rowIndex + 1
                local row = GetRow(c, rowIndex)
                row:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
                row:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
                row:SetHeight(ns.ROW_HEIGHT)

                row.nameText:SetText("All Delves")
                row.nameText:SetTextColor(0.9, 0.9, 0.9)

                row.diffText:SetText("x" .. delveCount)
                row.diffText:SetTextColor(dvColor[1], dvColor[2], dvColor[3])

                row.progressText:SetText(table.concat(tierParts, " "))
                row.progressText:SetTextColor(1, 1, 1)
                row.resetText:SetText("")
                row.extendedBar:Hide()
                row:SetScript("OnClick", nil)

                y = y - ns.ROW_HEIGHT
            end
        else
            if hasTrackedNames then
                -- Full view with tracked names: one row per individual completion
                -- Sort by the configured order
                local sortedTracked = {}
                for _, run in ipairs(delveTrackedRuns) do
                    table.insert(sortedTracked, run)
                end
                local order = db.delveSortOrder
                if order == "tier_desc" then
                    table.sort(sortedTracked, function(a, b)
                        if a.tier ~= b.tier then return a.tier > b.tier end
                        return a.name < b.name
                    end)
                elseif order == "tier_asc" then
                    table.sort(sortedTracked, function(a, b)
                        if a.tier ~= b.tier then return a.tier < b.tier end
                        return a.name < b.name
                    end)
                elseif order == "count_desc" or order == "count_asc" then
                    -- For individual runs, sort by name then tier
                    table.sort(sortedTracked, function(a, b)
                        if a.name ~= b.name then return a.name < b.name end
                        return a.tier > b.tier
                    end)
                end

                for _, run in ipairs(sortedTracked) do
                    rowIndex = rowIndex + 1
                    local row = GetRow(c, rowIndex)
                    row:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
                    row:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
                    row:SetHeight(ns.ROW_HEIGHT)

                    row.nameText:SetText(run.name)
                    row.nameText:SetTextColor(0.9, 0.9, 0.9)

                    row.diffText:SetText("T" .. run.tier)
                    row.diffText:SetTextColor(dvColor[1], dvColor[2], dvColor[3])

                    row.progressText:SetText("|cff00cc00Completed|r")
                    row.progressText:SetTextColor(1, 1, 1)

                    row.resetText:SetText("")
                    row.extendedBar:Hide()
                    row:SetScript("OnClick", nil)

                    y = y - ns.ROW_HEIGHT
                end
            else
                -- Full view without tracked names: one row per tier (aggregate)
                SortDelveRuns(delveRuns, db.delveSortOrder)
                for _, run in ipairs(delveRuns) do
                    rowIndex = rowIndex + 1
                    local row = GetRow(c, rowIndex)
                    row:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
                    row:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
                    row:SetHeight(ns.ROW_HEIGHT)

                    row.nameText:SetText("Delve")
                    row.nameText:SetTextColor(0.9, 0.9, 0.9)

                    row.diffText:SetText("T" .. run.tier)
                    row.diffText:SetTextColor(dvColor[1], dvColor[2], dvColor[3])

                    row.progressText:SetText("x" .. run.count .. " completed")
                    row.progressText:SetTextColor(0.9, 0.9, 0.9)

                    row.resetText:SetText("")
                    row.extendedBar:Hide()
                    row:SetScript("OnClick", nil)

                    y = y - ns.ROW_HEIGHT
                end
            end
        end
    end

    -- Alt lockouts section (expandable per-alt detail - hidden when column view is active)
    if not db.altColumns then
        local altSection = self:BuildAltSection(c, y, rowIndex, headerIndex, sepIndex)
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

    -- Size (expand width for character columns: current + alts)
    local ttWidth = db.tooltipWidth or TOOLTIP_WIDTH
    if numAltCols > 0 then
        ttWidth = ttWidth + (numAltCols + 1) * (ALT_COL_WIDTH + 2) -- +1 for current char column
    end
    f:FinalizeLayout(ttWidth, math.abs(y))
end

---------------------------------------------------------------------------
-- Alt lockout section (reads DDT's own DjinnisDataTextsDB.altLockouts)
---------------------------------------------------------------------------

function SavedInst:BuildAltSection(c, y, rowIndex, headerIndex, sepIndex)
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
            local hasDelves   = (altData.delveCount or 0) > 0
            if hasLockouts or hasMPlus or hasDelves then
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
    local sep = GetSeparator(c, sepIndex)
    sep:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
    sep:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
    y = y - 6

    headerIndex = headerIndex + 1
    local altHdr = GetHeader(c, headerIndex)
    altHdr:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
    altHdr:SetText("Alt Lockouts")
    altHdr:SetTextColor(1, 0.82, 0)
    y = y - HEADER_HEIGHT

    for _, alt in ipairs(alts) do
        local altData  = alt.data
        local lockouts = altData.lockouts or {}
        local mpRuns   = altData.mythicPlusRuns or {}
        local elapsed  = now - (altData.lastSeen or now)

        -- Build summary badge: "2R 1D 3M+ 5Dv"
        local rCt, dCt, mCt, dvCt = 0, 0, altData.mythicPlusCount or 0, altData.delveCount or 0
        for _, lo in ipairs(lockouts) do
            if lo.isRaid then rCt = rCt + 1 else dCt = dCt + 1 end
        end
        local summaryParts = {}
        if rCt > 0 then table.insert(summaryParts, rCt .. "R") end
        if dCt > 0 then table.insert(summaryParts, dCt .. "D") end
        if mCt > 0 then table.insert(summaryParts, mCt .. "M+") end
        if dvCt > 0 then table.insert(summaryParts, dvCt .. "Dv") end
        local summary = #summaryParts > 0 and table.concat(summaryParts, " ") or "No lockouts"

        local isExpanded = expandedAlts[alt.key]
        local arrow = isExpanded and "|cffaaaaaa▼|r " or "|cffaaaaaa▶|r "

        -- Alt summary row (click to expand)
        rowIndex = rowIndex + 1
        local row = GetRow(c, rowIndex)
        row:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
        row:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
        row:SetHeight(ns.ROW_HEIGHT)
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

        y = y - ns.ROW_HEIGHT

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
                rowIndex, y = RenderAltLockoutRow(c, rowIndex, y, lo, elapsed)
            end
            for _, lo in ipairs(altDungs) do
                rowIndex = rowIndex + 1
                rowIndex, y = RenderAltLockoutRow(c, rowIndex, y, lo, elapsed)
            end

            -- M+ runs
            if #mpRuns > 0 then
                local sortedRuns = {}
                for _, r in ipairs(mpRuns) do table.insert(sortedRuns, r) end
                SortMPlusRuns(sortedRuns, db.mplusSortOrder)

                local lvlColor = DIFFICULTY_COLORS["M+"] or { 0.78, 0, 1 }
                for _, run in ipairs(sortedRuns) do
                    rowIndex = rowIndex + 1
                    local lrow = GetRow(c, rowIndex)
                    lrow:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING + 12, y)
                    lrow:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
                    lrow:SetHeight(ns.ROW_HEIGHT)
                    lrow.isBossRow = false

                    lrow.nameText:SetText(run.name)
                    lrow.nameText:SetTextColor(0.8, 0.8, 0.8)
                    lrow.diffText:SetText("+" .. run.level)
                    lrow.diffText:SetTextColor(lvlColor[1], lvlColor[2], lvlColor[3])
                    lrow.progressText:SetText(run.completed and "|cff00cc00Timed|r" or "|cffcc0000Over|r")
                    lrow.resetText:SetText("")
                    lrow.extendedBar:Hide()
                    lrow:SetScript("OnClick", nil)

                    y = y - ns.ROW_HEIGHT
                end
            end

            -- Delve runs
            local altDvRuns = altData.delveRuns or {}
            if #altDvRuns > 0 then
                local dvColor = { 0.0, 0.76, 0.36 }
                -- Show tracked names if available, otherwise aggregate
                local altTracked = altData.delveTrackedRuns
                if altTracked and #altTracked > 0 then
                    for _, run in ipairs(altTracked) do
                        rowIndex = rowIndex + 1
                        local lrow = GetRow(c, rowIndex)
                        lrow:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING + 12, y)
                        lrow:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
                        lrow:SetHeight(ns.ROW_HEIGHT)
                        lrow.isBossRow = false

                        lrow.nameText:SetText(run.name)
                        lrow.nameText:SetTextColor(0.8, 0.8, 0.8)
                        lrow.diffText:SetText("T" .. run.tier)
                        lrow.diffText:SetTextColor(dvColor[1], dvColor[2], dvColor[3])
                        lrow.progressText:SetText("|cff00cc00Completed|r")
                        lrow.resetText:SetText("")
                        lrow.extendedBar:Hide()
                        lrow:SetScript("OnClick", nil)

                        y = y - ns.ROW_HEIGHT
                    end
                else
                    for _, run in ipairs(altDvRuns) do
                        rowIndex = rowIndex + 1
                        local lrow = GetRow(c, rowIndex)
                        lrow:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING + 12, y)
                        lrow:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
                        lrow:SetHeight(ns.ROW_HEIGHT)
                        lrow.isBossRow = false

                        lrow.nameText:SetText("Delve")
                        lrow.nameText:SetTextColor(0.8, 0.8, 0.8)
                        lrow.diffText:SetText("T" .. run.tier)
                        lrow.diffText:SetTextColor(dvColor[1], dvColor[2], dvColor[3])
                        lrow.progressText:SetText("x" .. run.count)
                        lrow.progressText:SetTextColor(0.7, 0.7, 0.7)
                        lrow.resetText:SetText("")
                        lrow.extendedBar:Hide()
                        lrow:SetScript("OnClick", nil)

                        y = y - ns.ROW_HEIGHT
                    end
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
    ns.AnchorTooltip(tooltipFrame, anchor, db.tooltipGrowDirection)
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
    local r = panel.refreshCallbacks
    local db = function() return ns.db.savedinstances end
    local refreshTT = function()
        if tooltipFrame and tooltipFrame:IsShown() then self:BuildTooltipContent() end
    end

    W.AddLabelEditBox(panel, "summary raids dungeons mplus delves total",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateData() end, r, {
        { "Default",    "<summary>" },
        { "Split",      "R:<raids> D:<dungeons>" },
        { "M+ Focus",   "M+: <mplus>  Saved: <total>" },
        { "Delves",     "M+: <mplus>  Dv: <delves>" },
        { "Full",       "R: <raids>  M+: <mplus>  Dv: <delves>" },
        { "Count",      "<total> lockouts" },
    })

    local body = W.AddSection(panel, "Display")
    local y = 0
    y = W.AddCheckbox(body, y, "Condensed raid view (group difficulties per instance)",
        function() return db().condensedRaids end,
        function(v) db().condensedRaids = v; refreshTT() end, r)
    y = W.AddCheckbox(body, y, "Condensed M+ view (group by dungeon)",
        function() return db().condensedMPlus end,
        function(v) db().condensedMPlus = v; refreshTT() end, r)
    y = W.AddCheckboxPair(body, y,
        "Show Delves",
        function() return db().showDelves end,
        function(v) db().showDelves = v; refreshTT() end,
        "Condensed Delves",
        function() return db().condensedDelves end,
        function(v) db().condensedDelves = v; refreshTT() end, r)
    W.EndSection(panel, y)

    body = W.AddSection(panel, "Sorting")
    y = 0
    y = W.AddDropdown(body, y, "Raid / Dungeon Order", RAID_SORT_VALUES,
        function() return db().raidSortOrder end,
        function(v) db().raidSortOrder = v; refreshTT() end, r)
    y = W.AddDropdown(body, y, "Mythic+ Order", MPLUS_SORT_VALUES,
        function() return db().mplusSortOrder end,
        function(v) db().mplusSortOrder = v; refreshTT() end, r)
    y = W.AddDropdown(body, y, "Delve Order", DELVE_SORT_VALUES,
        function() return db().delveSortOrder end,
        function(v) db().delveSortOrder = v; refreshTT() end, r)
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
    y = W.AddSliderPair(body, y,
        { label = "Max Height", min = 100, max = 1000, step = 10,
          get = function() return db().tooltipMaxHeight end,
          set = function(v) db().tooltipMaxHeight = v end },
        nil, r)
    y = W.AddNote(body, y, "Suggested: 400 x 600. Increase for many lockouts and alt data.")
    y = W.AddTooltipGrowDirection(body, y, db, r)
    y = W.AddTooltipCopyFrom(body, y, "savedinstances", db, r)
    W.EndSection(panel, y)

    -- Alt Lockouts (before click actions so it's easier to find)
    body = W.AddSection(panel, "Alt Lockouts")
    y = 0
    y = W.AddCheckbox(body, y, "Show alt lockout section in tooltip",
        function() return db().showAlts end,
        function(v) db().showAlts = v; refreshTT() end, r)
    y = W.AddCheckbox(body, y, "Show alt progress columns alongside current character",
        function() return db().altColumns end,
        function(v) db().altColumns = v; refreshTT() end, r)
    y = W.AddDescription(body, y,
        "|cff888888When column view is active, the expandable alt section is hidden.|r")
    y = W.AddSlider(body, y, "Column name length (0 = full name)", 0, 12, 1,
        function() return db().altNameLength end,
        function(v) db().altNameLength = v; refreshTT() end, r)

    local HOVER_ANCHOR_VALUES = {
        ANCHOR_TOP         = "Above",
        ANCHOR_BOTTOM      = "Below",
        ANCHOR_LEFT        = "Left",
        ANCHOR_RIGHT       = "Right",
        ANCHOR_TOPRIGHT    = "Top-Right",
        ANCHOR_TOPLEFT     = "Top-Left",
        ANCHOR_BOTTOMRIGHT = "Bottom-Right",
        ANCHOR_BOTTOMLEFT  = "Bottom-Left",
    }
    y = W.AddDescription(body, y, "Column header hover details:")
    y = W.AddDropdown(body, y, "Hover tooltip direction", HOVER_ANCHOR_VALUES,
        function() return db().altHoverAnchor end,
        function(v) db().altHoverAnchor = v end, r)
    y = W.AddCheckboxPair(body, y, "Show realm",
        function() return db().altHoverRealm end,
        function(v) db().altHoverRealm = v end,
        "Show class",
        function() return db().altHoverClass end,
        function(v) db().altHoverClass = v end, r)
    y = W.AddCheckboxPair(body, y, "Show specialization",
        function() return db().altHoverSpec end,
        function(v) db().altHoverSpec = v end,
        "Show role",
        function() return db().altHoverRole end,
        function(v) db().altHoverRole = v end, r)

    y = W.AddDropdown(body, y, "Show alts matching", ALT_FILTER_VALUES,
        function() return db().altFilter end,
        function(v) db().altFilter = v; refreshTT() end, r)

    -- Manual alt selection: always shown so users can pre-configure before switching to manual
    y = W.AddDescription(body, y, "Manual selection (used when filter = \"Manual selection\"):")

    local dynamicSection = panel.currentSection
    local dynamicStart = y
    local dynamicWidgets = {}

    local function RebuildAltList()
        for _, widget in ipairs(dynamicWidgets) do
            widget:Hide()
            widget:SetParent(nil)
        end
        wipe(dynamicWidgets)

        local dy = dynamicStart
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
                local noAlts = body:CreateFontString(nil, "OVERLAY", "GameFontDisable")
                noAlts:SetPoint("TOPLEFT", body, "TOPLEFT", 18, dy)
                noAlts:SetText("No alts recorded yet. Log in to each alt to populate.")
                table.insert(dynamicWidgets, noAlts)
                dy = dy - 20
            else
                for _, alt in ipairs(knownAlts) do
                    local cb = CreateFrame("CheckButton", nil, body, "UICheckButtonTemplate")
                    cb:SetPoint("TOPLEFT", body, "TOPLEFT", 14, dy)

                    local cbText = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                    cbText:SetPoint("LEFT", cb, "RIGHT", 2, 0)
                    local label = DDT:ClassColorText(alt.data.name or alt.key, (alt.data.class or ""):upper())
                                  .. " |cff888888(Lv " .. (alt.data.level or "?") .. ")|r"
                    cbText:SetText(label)

                    local capturedKey = alt.key
                    cb:SetChecked(db().altManualList[capturedKey] == true)
                    cb:SetScript("OnClick", function(self)
                        db().altManualList[capturedKey] = self:GetChecked() or nil
                        refreshTT()
                    end)

                    table.insert(dynamicWidgets, cb)
                    table.insert(dynamicWidgets, cbText)
                    dy = dy - 26
                end
            end
        else
            local noAlts = body:CreateFontString(nil, "OVERLAY", "GameFontDisable")
            noAlts:SetPoint("TOPLEFT", body, "TOPLEFT", 18, dy)
            noAlts:SetText("No alts recorded yet. Log in to each alt to populate.")
            table.insert(dynamicWidgets, noAlts)
            dy = dy - 20
        end

        -- Update section height dynamically
        dynamicSection.bodyHeight = math.abs(dy) + 8
        dynamicSection.body:SetHeight(dynamicSection.bodyHeight)
        dynamicSection:UpdateLayout()
    end

    RebuildAltList()
    panel.currentSection = nil  -- manual EndSection since height is dynamic

    panel:HookScript("OnShow", function()
        RebuildAltList()
    end)

    ns.AddModuleClickActionsSection(panel, r, "savedinstances", CLICK_ACTIONS,
        "Click a lockout row: Expand/collapse boss details")
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("savedinstances", SavedInst, DEFAULTS)
