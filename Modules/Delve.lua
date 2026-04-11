-- Djinni's Data Texts - Delve Tracker
-- Tracks the in-delve Bountiful objectives (Sanctified Banner, Empowered packs, etc.)
-- via the ScenarioHeaderDelves UI widget. Schema-free: enumerates whatever the
-- widget reports rather than hardcoding spell IDs, so it survives season changes.
local addonName, ns = ...
local DDT = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local Delve = {}
ns.Delve = Delve

-- State
local inDelve         = false
local delveTierText   = nil    -- e.g. "Tier 8"
local delveHeaderText = nil    -- e.g. "Collegiate Calamity"
local delveSpells     = {}     -- list of { spellID, name, earned, glow, progressStr, progLabel, hasProgress }
local rewardState     = nil    -- Enum.UIWidgetRewardShownState value
local rewardTooltip   = nil
local cachedWidgetID  = nil
local hasBountiful    = false  -- Bountiful spell present in widget = delve has Banner objective
local hasBanner       = false  -- Sanctified Touch aura present = banner collected

-- Map pin overlay state (used by RefreshMapPins)
local mapPins      = {}        -- list of pin frames currently parented to the world map canvas
local delveMapID   = nil       -- uiMapID captured the moment we detect inDelve

-- Companion XP state
local companionInfo  = nil     -- { name, level, currentXP, maxXP, rankName, isMaxLevel }
local xpTrack = {
    lastLevel     = nil,
    lastCurrent   = nil,
    lastMax       = nil,
    sessionGained = 0,
    delveGained   = 0,
    wasInDelve    = false,
}

-- Scenario criteria (current stage objectives, e.g. "Reveal Twilight Blade 12%/17%")
local scenarioCriteria = {}    -- list of { description, completed, quantity, totalQuantity, quantityString }

-- Spell IDs we know about
-- Banner-click buffs: applied to the player when the Sanctified Banner is clicked.
-- Different delve variants/tiers may use different buff spell IDs, so we check
-- a list. Latch hasBanner for the lifetime of the current delve once any are seen
-- (reset on transitioning into a new delve via xpTrack.wasInDelve).
--   1272756 - Ward of Light          (Tier 11 "The Gulf of Memory", stage 2 banner)
--   1273058 - Holy Reinforcements    (Tier 11 "The Gulf of Memory", stage 3 banner)
--   1271918 - Sanctified Touch       (observed in an earlier session - kept for fallback)
-- Both Ward of Light and Holy Reinforcements were observed to persist for several
-- minutes after the click (long enough to last most of a delve), but we still latch
-- hasBanner for safety so the indicator stays accurate even if the buff fades early.
local BANNER_BUFF_SPELL_IDS = {
    1272756,  -- Ward of Light
    1273058,  -- Holy Reinforcements
    1271918,  -- Sanctified Touch
}

-- Known Sanctified Banner spawn locations per delve, keyed by widget headerText.
-- Coordinates are normalized 0-1 (divide by 100 from /way values).
-- Source: wowhead.com/spell=1269416 community comments (TheranusKJ et al, patch 12.0.1).
-- Each delve may have multiple spawn variants; only one is active per run, so we
-- list all known spawns and let the player check whichever is closest.
local BANNER_LOCATIONS = {
    ["Collegiate Calamity"] = {
        { x = 0.8136, y = 0.3986 },
        { x = 0.4660, y = 0.8429, note = "Invasive Glow variant" },
    },
    ["Darkway"] = {
        { x = 0.4961, y = 0.3752 },
        { x = 0.5366, y = 0.4989 },
    },
    ["Grudge Pit"] = {
        { x = 0.5522, y = 0.6439 },
    },
    ["Parhelion Plaza"] = {
        { x = 0.2413, y = 0.8814 },
        { x = 0.6470, y = 0.6350 },
        { x = 0.2303, y = 0.1509 },
    },
    ["Twilight Crypts"] = {
        { x = 0.4491, y = 0.5472 },
    },
    ["Atal'Aman"] = {
        { x = 0.4057, y = 0.5784 },
        { x = 0.5738, y = 0.8309 },
    },
    ["Shadowguard Point"] = {
        { x = 0.4947, y = 0.5511 },
    },
    ["The Gulf of Memory"] = {
        { x = 0.5651, y = 0.4652 },
    },
    ["The Shadow Enclave"] = {
        { x = 0.4600, y = 0.2200 },
    },
}
local BOUNTIFUL_SPELL_ID        = 462940   -- "Bountiful" widget spell - presence indicates Banner exists

local tooltipFrame = nil
local hideTimer    = nil
local rowPool      = {}

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
    -- <name> falls back to "Not in Delve" when idle, so a single template works in both states.
    labelTemplate    = "Delve: <progress>",
    tooltipScale     = 1.0,
    tooltipMaxHeight = 500,
    tooltipWidth     = 360,
    mapPinScale      = 3.0,
    mapPinIcon       = "banner",
    hideWhenIdle     = false,  -- if true, dataobj text becomes empty when not in a delve
    clickActions = {
        leftClick       = "none",
        rightClick      = "none",
        middleClick     = "none",
        shiftLeftClick  = "none",
        shiftRightClick = "none",
        ctrlLeftClick   = "none",
        ctrlRightClick  = "none",
        altLeftClick    = "opensettings",
        altRightClick   = "none",
    },
}

local CLICK_ACTIONS = {
    opensettings = "Open DDT Settings",
    none         = "None",
}

-- Map pin icon presets. Each entry is { kind = "spell"|"atlas"|"texture", id = ... }.
-- "banner" uses the Sanctified Banner spell icon (1269416) for thematic match.
local MAP_PIN_ICONS = {
    banner    = { label = "Sanctified Banner", kind = "spell",   id = 1269416 },
    waypoint  = { label = "Waypoint Pin",      kind = "atlas",   id = "Waypoint-MapPin-Untracked" },
    flag      = { label = "Horde Flag",        kind = "atlas",   id = "poi-horde" },
    star      = { label = "Gold Star",         kind = "atlas",   id = "VignetteLoot" },
    skull     = { label = "Skull",             kind = "atlas",   id = "Vignette-MapIcon-Boss-Horde" },
    treasure  = { label = "Treasure Chest",    kind = "atlas",   id = "VignetteLootElite" },
    quest     = { label = "Quest Marker",      kind = "atlas",   id = "QuestNormal" },
}

local function ApplyPinIcon(pin)
    local key = (Delve:GetDB().mapPinIcon) or "banner"
    local def = MAP_PIN_ICONS[key] or MAP_PIN_ICONS.banner
    if def.kind == "spell" then
        local tex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(def.id)
        pin.ring:SetAtlas(nil)
        pin.ring:SetTexture(tex or 134400)
        pin.ring:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    elseif def.kind == "atlas" then
        pin.ring:SetTexture(nil)
        pin.ring:SetTexCoord(0, 1, 0, 1)
        pin.ring:SetAtlas(def.id, false)
    else
        pin.ring:SetTexture(def.id)
        pin.ring:SetTexCoord(0, 1, 0, 1)
    end
end

---------------------------------------------------------------------------
-- Widget scanning
---------------------------------------------------------------------------

--- Strip WoW color/escape codes from a tooltip string for clean display.
local function StripCodes(str)
    if not str then return "" end
    str = str:gsub("|c%x%x%x%x%x%x%x%x", "")
    str = str:gsub("|r", "")
    str = str:gsub("|H.-|h", "")
    str = str:gsub("|h", "")
    str = str:gsub("|T.-|t", "")
    return str
end

--- Resolve a spell name from spellID, falling back to widget tooltip's first line.
local function GetSpellLabel(spellID, tooltip)
    if spellID and spellID > 0 and C_Spell and C_Spell.GetSpellName then
        local name = C_Spell.GetSpellName(spellID)
        if name and name ~= "" then return name end
    end
    if tooltip and tooltip ~= "" then
        local clean = StripCodes(tooltip)
        local firstLine = clean:match("^([^\n]+)")
        if firstLine then return firstLine end
    end
    return spellID and ("Spell " .. spellID) or "Unknown"
end

--- Find the active delve scenario header widget by scanning known widget set IDs.
--- Caches the widget ID for fast subsequent lookups; cleared when widget vanishes.
local function FindDelveWidget()
    if cachedWidgetID then
        local info = C_UIWidgetManager.GetScenarioHeaderDelvesWidgetVisualizationInfo(cachedWidgetID)
        if info and info.shownState ~= Enum.WidgetShownState.Hidden then
            return info
        end
        cachedWidgetID = nil
    end

    -- Scan widget sets that scenario headers can appear in.
    -- Preferred source: the active scenario step exposes its widgetSetID directly,
    -- which is more reliable than the standard hooks (and works after /reload).
    local setIDs = {}
    if C_ScenarioInfo and C_ScenarioInfo.GetScenarioStepInfo then
        local stepInfo = C_ScenarioInfo.GetScenarioStepInfo()
        if stepInfo and stepInfo.widgetSetID then
            setIDs[#setIDs + 1] = stepInfo.widgetSetID
        end
    end
    local fn
    fn = C_UIWidgetManager.GetTopCenterWidgetSetID
    if fn then setIDs[#setIDs + 1] = fn() end
    fn = C_UIWidgetManager.GetObjectiveTrackerWidgetSetID
    if fn then setIDs[#setIDs + 1] = fn() end
    fn = C_UIWidgetManager.GetBelowMinimapWidgetSetID
    if fn then setIDs[#setIDs + 1] = fn() end

    for _, setID in ipairs(setIDs) do
        if setID then
            local widgets = C_UIWidgetManager.GetAllWidgetsBySetID(setID)
            if widgets then
                for _, w in ipairs(widgets) do
                    if w.widgetType == Enum.UIWidgetVisualizationType.ScenarioHeaderDelves then
                        local info = C_UIWidgetManager.GetScenarioHeaderDelvesWidgetVisualizationInfo(w.widgetID)
                        if info and info.shownState ~= Enum.WidgetShownState.Hidden then
                            cachedWidgetID = w.widgetID
                            return info
                        end
                    end
                end
            end
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- Data collection
---------------------------------------------------------------------------

--- Scan the active scenario step for criteria (sub-objectives like the Sanctified Banner).
function Delve:UpdateScenarioCriteria()
    scenarioCriteria = {}
    if not (C_ScenarioInfo and C_ScenarioInfo.GetScenarioStepInfo and C_ScenarioInfo.GetCriteriaInfo) then
        return
    end
    local stepInfo = C_ScenarioInfo.GetScenarioStepInfo()
    if not stepInfo or not stepInfo.numCriteria or stepInfo.numCriteria == 0 then return end

    for i = 1, stepInfo.numCriteria do
        local crit = C_ScenarioInfo.GetCriteriaInfo(i)
        if type(crit) == "table" and crit.description and crit.description ~= "" then
            scenarioCriteria[#scenarioCriteria + 1] = {
                description    = crit.description,
                completed      = crit.completed and true or false,
                quantity       = crit.quantity or 0,
                totalQuantity  = crit.totalQuantity or 0,
                quantityString = crit.quantityString or "",
                isFormatted    = crit.isFormatted and true or false,
            }
        end
    end
end

function Delve:UpdateData()
    -- Remember previous delve state so we can detect transitions (for latches like hasBanner).
    local prevInDelve = inDelve

    -- Reset state
    inDelve         = false
    delveTierText   = nil
    delveHeaderText = nil
    delveSpells     = {}
    rewardState     = nil
    rewardTooltip   = nil
    scenarioCriteria = {}

    -- C_DelvesUI.HasActiveDelve gives a quick gate, but the widget is the source of truth
    -- since the widget only appears when the scenario header is active.
    local info = FindDelveWidget()
    if not info then
        -- Even without the widget, scenario criteria may still be available
        -- (useful when widgets haven't been delivered yet after /reload).
        self:UpdateScenarioCriteria()
        if #scenarioCriteria > 0 then
            inDelve = true
        end
        if not inDelve and prevInDelve then
            -- Left the delve: clear the banner latch so the next delve starts clean.
            hasBanner  = false
            delveMapID = nil
            self:RefreshMapPins()
        end
        self:UpdateCompanionData()
        self:UpdateLabel()
        return
    end

    inDelve         = true
    delveTierText   = info.tierText
    delveHeaderText = info.headerText
    hasBountiful    = false

    -- Entering a new delve: clear the banner latch and capture the delve map ID.
    if not prevInDelve then
        hasBanner = false
        if C_Map and C_Map.GetBestMapForUnit then
            delveMapID = C_Map.GetBestMapForUnit("player")
        end
    end

    if type(info.spells) == "table" then
        for _, sp in ipairs(info.spells) do
            local cleanTip = StripCodes(sp.tooltip or "")
            local name = GetSpellLabel(sp.spellID, cleanTip)

            -- Bountiful spell presence means the delve has the Sanctified Banner objective
            if sp.spellID == BOUNTIFUL_SPELL_ID then
                hasBountiful = true
            end

            -- The widget tooltip is empty in practice; per-sub-item progress lives in
            -- C_Spell.GetSpellDescription as dynamic text like "Enemy groups remaining: 0 / 4".
            -- We parse the LAST "Label: X / Y" match (most up-to-date state).
            local progLabel, progCur, progMax, progStr, hasProgress
            if C_Spell and C_Spell.GetSpellDescription and sp.spellID then
                local desc = C_Spell.GetSpellDescription(sp.spellID)
                if desc and desc ~= "" then
                    -- Find the last occurrence of "Some label: N / M" in the description
                    for label, a, b in desc:gmatch("([^\n:]+):%s*(%d+)%s*/%s*(%d+)") do
                        progLabel = label:gsub("^%s+", ""):gsub("%s+$", "")
                        progCur   = tonumber(a)
                        progMax   = tonumber(b)
                    end
                    if progCur and progMax then
                        -- "remaining" semantics: lower is better; invert for display
                        if progLabel and progLabel:lower():find("remaining") then
                            progCur = progMax - progCur
                        end
                        progStr = progCur .. "/" .. progMax
                        hasProgress = true
                    end
                end
            end

            delveSpells[#delveSpells + 1] = {
                spellID     = sp.spellID,
                name        = name,
                text        = sp.text,
                earned      = sp.showAsEarned and true or false,
                glow        = (sp.showGlowState == Enum.WidgetShowGlowState.ShowGlow),
                progLabel   = progLabel,
                progStr     = progStr,
                progCur     = progCur,
                progMax     = progMax,
                hasProgress = hasProgress,
            }
        end
    end

    -- Sanctified Banner state: detected via any of the known banner-click player
    -- auras (see BANNER_BUFF_SPELL_IDS). These buffs have a finite duration, so
    -- we latch hasBanner = true for the rest of the delve once any is seen. The
    -- latch is reset on delve transitions in UpdateData.
    local aurasSecret = C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret()
    if not aurasSecret and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        for _, sid in ipairs(BANNER_BUFF_SPELL_IDS) do
            if C_UnitAuras.GetPlayerAuraBySpellID(sid) then
                hasBanner = true
                break
            end
        end
    end

    if type(info.rewardInfo) == "table" then
        rewardState   = info.rewardInfo.shownState
        rewardTooltip = StripCodes(
            (rewardState == Enum.UIWidgetRewardShownState.ShownEarned)
                and info.rewardInfo.earnedTooltip
                or info.rewardInfo.unearnedTooltip)
    end

    self:UpdateScenarioCriteria()
    self:UpdateCompanionData()
    self:UpdateLabel()
    self:RefreshMapPins()
end

--- Try several paths to obtain a usable companion factionID.
-- Per Blizzard_DelvesCompanionConfiguration.lua, GetPlayerCompanionID() only
-- returns a value once the config UI has been shown this session ("Nuke the
-- companion ID on closure"). Outside of that flow we have to fall back.
local function ResolveCompanionFactionID()
    if not (C_DelvesUI and C_DelvesUI.GetFactionForCompanion) then return nil end

    -- Path A: explicit ID from GetPlayerCompanionID (works only after UI open).
    if GetPlayerCompanionID then
        local ok, id = pcall(GetPlayerCompanionID)
        if ok and id then
            local ok2, factionID = pcall(C_DelvesUI.GetFactionForCompanion, id)
            if ok2 and factionID and factionID > 0 then return factionID end
        end
    end

    -- Path B: pass nil. The companionID arg is documented Nilable=true and
    -- defaults to "active mirror data companion" per the Blizzard docs.
    local ok, factionID = pcall(C_DelvesUI.GetFactionForCompanion, nil)
    if ok and factionID and factionID > 0 then return factionID end

    -- Path C: GetCompanionInfoForActivePlayer returns a playerCompanionInfoID
    -- that may also be acceptable.
    if C_DelvesUI.GetCompanionInfoForActivePlayer then
        local ok2, pcInfoID = pcall(C_DelvesUI.GetCompanionInfoForActivePlayer)
        if ok2 and pcInfoID then
            local ok3, factionID2 = pcall(C_DelvesUI.GetFactionForCompanion, pcInfoID)
            if ok3 and factionID2 and factionID2 > 0 then return factionID2 end
        end
    end

    return nil
end

--- Read companion (Brann) level + XP toward next rank.
-- Mirrors Blizzard_DelvesCompanionConfiguration.lua: companion progression is
-- modeled as a friendship faction. We use C_GossipInfo.GetFriendshipReputation
-- because it returns the current/threshold/nextThreshold values directly.
function Delve:UpdateCompanionData()
    companionInfo = nil

    local factionID = ResolveCompanionFactionID()
    if not factionID then return end

    local rankInfo = C_GossipInfo.GetFriendshipReputationRanks(factionID)
    local repInfo  = C_GossipInfo.GetFriendshipReputation(factionID)
    if type(repInfo) ~= "table" then return end

    local current, max, isMax
    if repInfo.nextThreshold then
        current = (repInfo.standing or 0) - (repInfo.reactionThreshold or 0)
        max     = (repInfo.nextThreshold or 0) - (repInfo.reactionThreshold or 0)
        isMax   = false
    else
        current = 1
        max     = 1
        isMax   = true
    end

    local name = repInfo.name or ""
    if C_Reputation and C_Reputation.GetFactionDataByID then
        local fdata = C_Reputation.GetFactionDataByID(factionID)
        if type(fdata) == "table" and fdata.name then name = fdata.name end
    end

    local level   = rankInfo and rankInfo.currentLevel or 0
    local maxRank = rankInfo and rankInfo.maxLevel or 0

    -- Reset delve XP counter when we transition into a new delve
    if inDelve and not xpTrack.wasInDelve then
        xpTrack.delveGained = 0
    end
    xpTrack.wasInDelve = inDelve

    -- Compute XP delta vs last snapshot. Same level -> simple subtraction;
    -- level up -> remainder of old rank + new current. We don't know intermediate
    -- rank thresholds, so multi-level jumps in a single tick are undercounted
    -- (rare in practice since UPDATE_FACTION fires per gain).
    if not isMax and xpTrack.lastLevel and xpTrack.lastCurrent and xpTrack.lastMax then
        local delta = 0
        if level == xpTrack.lastLevel then
            delta = current - xpTrack.lastCurrent
        elseif level > xpTrack.lastLevel then
            delta = (xpTrack.lastMax - xpTrack.lastCurrent) + current
        end
        if delta > 0 then
            xpTrack.sessionGained = xpTrack.sessionGained + delta
            if inDelve then
                xpTrack.delveGained = xpTrack.delveGained + delta
            end
        end
    end
    xpTrack.lastLevel   = level
    xpTrack.lastCurrent = current
    xpTrack.lastMax     = max

    companionInfo = {
        name       = name,
        level      = level,
        maxRank    = maxRank,
        currentXP  = current,
        maxXP      = math.max(1, max),
        rankName   = repInfo.reaction or "",
        isMaxLevel = isMax,
    }
end

function Delve:UpdateLabel()
    local db = self:GetDB()
    local template = db.labelTemplate or "<progress>"
    local E = ns.ExpandTag

    local nameStr, tierStr, progStr, statusStr

    if inDelve then
        nameStr = delveHeaderText or "Delve"
        tierStr = delveTierText or ""

        -- Count widget spells (skipping the Bountiful umbrella, which we represent
        -- via the synthetic Sanctified Banner row). Fall back to scenario criteria
        -- when no widget spells are available.
        local total, earned = 0, 0
        if #delveSpells > 0 then
            for _, s in ipairs(delveSpells) do
                if s.spellID ~= BOUNTIFUL_SPELL_ID then
                    total = total + 1
                    if s.earned or (s.hasProgress and s.progCur >= s.progMax) then
                        earned = earned + 1
                    end
                end
            end
            if hasBountiful then
                total = total + 1
                if hasBanner then earned = earned + 1 end
            end
        elseif #scenarioCriteria > 0 then
            total = #scenarioCriteria
            for _, c in ipairs(scenarioCriteria) do
                if c.completed then earned = earned + 1 end
            end
        end

        local rewardDone = (rewardState == Enum.UIWidgetRewardShownState.ShownEarned)
        local rewardChar = (rewardState == Enum.UIWidgetRewardShownState.ShownEarned) and "+"
                       or  (rewardState == Enum.UIWidgetRewardShownState.ShownUnearned) and "-"
                       or  nil

        if total > 0 then
            progStr = earned .. "/" .. total
            if rewardChar then progStr = progStr .. " [" .. rewardChar .. "]" end
        elseif rewardChar then
            progStr = "[" .. rewardChar .. "]"
        else
            progStr = "active"
        end

        statusStr = nameStr
        if tierStr ~= "" then statusStr = statusStr .. " (" .. tierStr .. ")" end
        statusStr = statusStr .. " " .. progStr

        -- Color: green if everything done, yellow if partial, white if nothing tracked
        if total > 0 and earned == total and (rewardState == nil or rewardDone) then
            statusStr = "|cff66ff66" .. statusStr .. "|r"
        elseif total > 0 then
            statusStr = "|cffffcc33" .. statusStr .. "|r"
        end
    else
        nameStr   = "Not in Delve"
        tierStr   = ""
        progStr   = "-"
        statusStr = db.hideWhenIdle and "" or "Not in Delve"
    end

    local result = template
    result = E(result, "status",   statusStr)
    result = E(result, "name",     nameStr)
    result = E(result, "tier",     tierStr)
    result = E(result, "progress", progStr)
    result = E(result, "prog",     progStr)

    -- If the user picked hideWhenIdle, blank the whole thing when not in a delve
    if not inDelve and db.hideWhenIdle then
        result = ""
    end

    self.dataobj.text = result

    -- Push the new label up to the ActiveActivity aggregator (no-op if the
    -- aggregator hasn't initialized yet).
    if ns.NotifyActivityChange then ns:NotifyActivityChange() end
end

function Delve:GetDB()
    return ns.db and ns.db.delve or DEFAULTS
end

---------------------------------------------------------------------------
-- Click action executor
---------------------------------------------------------------------------

local function ExecuteAction(action)
    if action == "opensettings" then
        Settings.OpenToCategory(DDT.settingsCategoryID)
    elseif action == "pintooltip" then
        ns:TogglePinTooltip(Delve, tooltipFrame)
    end
end

---------------------------------------------------------------------------
-- ActiveActivity tracker registration
--
-- This module no longer creates its own LDB DataBroker. Instead it registers
-- as a sub-tracker with the unified ActiveActivity datatext, which routes
-- hover/click/label calls to whichever activity is currently engaged.
--
-- A stub `dataobj` is kept so legacy code paths inside this file (notably
-- UpdateLabel which writes self.dataobj.text) continue to work without
-- error. The aggregator pulls the status text via GetStatusText() instead.
---------------------------------------------------------------------------

local dataobj = { text = "Delve", icon = "Interface\\Icons\\achievement_delves_01" }
Delve.dataobj = dataobj

-- Public accessor used by ActiveActivity to determine if this tracker owns
-- the current label / hover.
function Delve:IsActive()
    return inDelve
end

-- Returns the fully-formatted label text (the tracker's own labelTemplate
-- already applied). The aggregator displays this verbatim. Reads from the
-- cached dataobj.text rather than re-running UpdateLabel to avoid recursion
-- (UpdateLabel itself notifies the aggregator).
function Delve:GetLabelText()
    return self.dataobj.text or ""
end

local function HandleClick(button)
    Delve:CancelHideTimer()
    local db = Delve:GetDB()
    local action = DDT:ResolveClickAction(button, db.clickActions)
    -- Only auto-hide the tooltip for non-pin actions; pinning needs to keep it visible.
    if action ~= "pintooltip" and tooltipFrame then tooltipFrame:Hide() end
    if action and action ~= "none" then
        ExecuteAction(action)
    end
end

if ns.RegisterActivityTracker then
    ns:RegisterActivityTracker("delve", {
        displayName = "Delve",
        icon        = "Interface\\Icons\\achievement_delves_01",
        priority    = 10,
        IsActive    = function() return Delve:IsActive() end,
        GetLabelText = function() return Delve:GetLabelText() end,
        ShowTooltip = function(anchor)
            Delve:CancelHideTimer()
            Delve:ShowTooltip(anchor)
        end,
        HideTooltip = function()
            Delve:StartHideTimer()
        end,
        HandleClick = HandleClick,
    })
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------

local TOOLTIP_PADDING = ns.TOOLTIP_PADDING

--- Set a player waypoint at the given normalized (0-1) coordinates on the
-- player's current map. Used by the banner-location click handlers.
-- Delve maps generally do NOT allow user waypoints (CanSetUserWaypointOnMap
-- returns false), so we fall back to opening the world map - the map pin
-- overlay we register elsewhere will already mark the spots.
local function SetWaypointHere(x, y)
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not mapID then return end

    local canSet = C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(mapID)
    if canSet then
        local point = UiMapPoint.CreateFromCoordinates(mapID, x, y)
        C_Map.SetUserWaypoint(point)
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end
    else
        -- Echo coordinates to chat so the player can read them off, and open
        -- the map (our pin overlay highlights the spawn).
        print(string.format("|cff7fb8ff[DDT-Delve]|r Banner location: |cffffffff/way %.2f, %.2f|r",
            x * 100, y * 100))
        if not WorldMapFrame:IsShown() then
            ToggleWorldMap()
        end
    end
end

local function GetOrCreateRow(parent, index)
    if rowPool[index] then
        rowPool[index]:Show()
        return rowPool[index]
    end

    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ns.ROW_HEIGHT)

    -- Hover highlight (only visible when row is clickable)
    row.highlight = row:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetAllPoints(row)
    row.highlight:SetColorTexture(1, 1, 1, 0.08)
    row.highlight:Hide()

    row.left = ns.FontString(row, "DDTFontNormal")
    row.left:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.left:SetJustifyH("LEFT")
    row.left:SetJustifyV("TOP")

    row.right = ns.FontString(row, "DDTFontSmall")
    row.right:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    row.right:SetJustifyH("RIGHT")
    row.right:SetJustifyV("TOP")

    rowPool[index] = row
    return row
end

local function CreateTooltipFrame()
    local f = ns.CreateTooltipFrame(nil, Delve)
    local c = f.scrollContent

    -- Companion XP bar (textures live on the scroll content so they scroll with rows).
    -- Mirrors Experience module styling: dark BG track, purple fill.
    c.xpBarBG = c:CreateTexture(nil, "ARTWORK")
    c.xpBarBG:SetColorTexture(0.15, 0.15, 0.15, 0.85)
    c.xpBarBG:SetHeight(8)
    c.xpBarBG:Hide()

    c.xpBar = c:CreateTexture(nil, "ARTWORK", nil, 1)
    c.xpBar:SetColorTexture(0.58, 0.0, 0.82, 0.9)
    c.xpBar:SetHeight(8)
    c.xpBar:Hide()

    return f
end

function Delve:PopulateTooltip()
    if not tooltipFrame then return end

    local db = self:GetDB()
    local sc = tooltipFrame.scrollContent
    local tooltipWidth = db.tooltipWidth or 360
    local innerWidth = tooltipWidth - 2 * TOOLTIP_PADDING

    local rightW = 70
    local leftW  = innerWidth - rightW - 4

    for _, row in pairs(rowPool) do row:Hide() end

    tooltipFrame.header:SetText(DDT:ColorText("Delve Tracker", 1, 0.82, 0))

    local rowIdx = 0
    local yOffset = 0

    local function AddRow(leftText, rightText, leftColor, rightColor, onClick)
        rowIdx = rowIdx + 1
        local row = GetOrCreateRow(sc, rowIdx)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, yOffset)

        row.left:SetWidth(leftW)
        row.left:SetWordWrap(true)
        row.left:SetText(leftText or "")
        if leftColor then row.left:SetTextColor(unpack(leftColor)) else row.left:SetTextColor(1, 1, 1) end

        row.right:SetWidth(rightW)
        row.right:SetText(rightText or "")
        if rightColor then row.right:SetTextColor(unpack(rightColor)) else row.right:SetTextColor(0.7, 0.7, 0.7) end

        -- Configure clickability. Pooled rows may have stale handlers, so we
        -- always reset both states explicitly.
        if onClick then
            row:EnableMouse(true)
            row:SetScript("OnMouseUp", function(_, btn) if btn == "LeftButton" then onClick() end end)
            -- Cancel/restart the hide timer in addition to the highlight, otherwise
            -- the parent tooltip's OnLeave fires when the mouse crosses onto this
            -- mouse-enabled child, and the tooltip vanishes mid-click.
            row:SetScript("OnEnter", function(self)
                self.highlight:Show()
                Delve:CancelHideTimer()
            end)
            row:SetScript("OnLeave", function(self)
                self.highlight:Hide()
                Delve:StartHideTimer()
            end)
        else
            row:EnableMouse(false)
            row:SetScript("OnMouseUp", nil)
            row:SetScript("OnEnter", nil)
            row:SetScript("OnLeave", nil)
            row.highlight:Hide()
        end

        local textH = math.max(row.left:GetStringHeight(), ns.ROW_HEIGHT)
        row:SetSize(innerWidth, textH)
        yOffset = yOffset - textH - 2
    end

    -- Always hide bar by default; re-shown below if companion data present
    sc.xpBarBG:Hide()
    sc.xpBar:Hide()

    if not inDelve then
        AddRow("Not currently in a delve.", nil, { 0.6, 0.6, 0.6 })
        AddRow("Enter a Bountiful Delve to see objective progress.", nil, { 0.5, 0.5, 0.5 })
    else
        -- Header: delve name + tier
        local title = delveHeaderText or "Delve"
        if delveTierText and delveTierText ~= "" then
            title = title .. "  |cffaaaaaa(" .. delveTierText .. ")|r"
        end
        AddRow(title, nil, { 1, 0.82, 0 })

        -- Objectives section: widget spells with parsed progress (Revelations, Nemesis
        -- Strongbox, etc.) plus the synthetic Sanctified Banner row when Bountiful is active.
        if #delveSpells > 0 or hasBountiful then
            yOffset = yOffset - 2
            AddRow("|cffaaaaaaObjectives|r", nil, { 0.67, 0.67, 0.67 })

            for _, sp in ipairs(delveSpells) do
                -- Skip the Bountiful umbrella spell -- we render its sub-objectives explicitly.
                if sp.spellID ~= BOUNTIFUL_SPELL_ID then
                    local done = sp.earned or (sp.hasProgress and sp.progCur >= sp.progMax)
                    local mark, color
                    if done then
                        mark  = "|cff66ff66[+]|r"
                        color = { 0.5, 0.9, 0.5 }
                    else
                        mark  = "|cffff6666[ ]|r"
                        color = sp.glow and { 1, 0.9, 0.4 } or { 0.85, 0.85, 0.85 }
                    end
                    local right = sp.progStr or (sp.text and sp.text ~= "" and sp.text or nil)
                    AddRow(mark .. " " .. (sp.name or "Unknown"), right, color, { 0.7, 0.7, 0.7 })
                end
            end

            -- Sanctified Banner: only when the delve has a Bountiful objective.
            if hasBountiful then
                local mark, color
                if hasBanner then
                    mark  = "|cff66ff66[+]|r"
                    color = { 0.5, 0.9, 0.5 }
                else
                    mark  = "|cffff6666[ ]|r"
                    color = { 1, 0.9, 0.4 }
                end
                AddRow(mark .. " Sanctified Banner",
                    hasBanner and "Collected" or "Available",
                    color,
                    hasBanner and { 0.4, 1, 0.4 } or { 1, 0.85, 0.4 })

                -- Known spawn locations for this delve. Only show when not yet
                -- collected -- once the banner is in hand, locations are noise.
                if not hasBanner and delveHeaderText then
                    local locs = BANNER_LOCATIONS[delveHeaderText]
                    if locs then
                        for _, loc in ipairs(locs) do
                            local label = string.format("    |cff7fb8ff/way %.2f, %.2f|r",
                                loc.x * 100, loc.y * 100)
                            if loc.note then
                                label = label .. "  |cff888888(" .. loc.note .. ")|r"
                            end
                            local lx, ly = loc.x, loc.y
                            AddRow(label, "show map", { 0.85, 0.85, 0.85 }, { 0.5, 0.7, 1 },
                                function() SetWaypointHere(lx, ly) end)
                        end
                    end
                end
            end
        end

        -- Scenario criteria fallback (only when widget spells are unavailable)
        if #delveSpells == 0 and #scenarioCriteria > 0 then
            for _, c in ipairs(scenarioCriteria) do
                local mark, color
                if c.completed then
                    mark  = "|cff66ff66[+]|r"
                    color = { 0.5, 0.9, 0.5 }
                else
                    mark  = "|cffff6666[ ]|r"
                    color = { 0.85, 0.85, 0.85 }
                end
                local right
                if c.quantityString and c.quantityString ~= "" then
                    right = c.quantityString
                elseif c.totalQuantity and c.totalQuantity > 1 then
                    right = c.quantity .. "/" .. c.totalQuantity
                end
                AddRow(mark .. " " .. c.description, right, color, { 0.7, 0.7, 0.7 })
            end
        end

        if #delveSpells == 0 and #scenarioCriteria == 0 and not hasBountiful then
            AddRow("  No tracked objectives", nil, { 0.5, 0.5, 0.5 })
        end

        -- Reward (treasure cache state)
        if rewardState ~= nil and rewardState ~= Enum.UIWidgetRewardShownState.Hidden then
            yOffset = yOffset - 4
            local earned = (rewardState == Enum.UIWidgetRewardShownState.ShownEarned)
            local mark   = earned and "|cff66ff66[+]|r" or "|cffff6666[ ]|r"
            local color  = earned and { 0.5, 0.9, 0.5 } or { 0.85, 0.85, 0.85 }
            local status = earned and "Earned" or "Unearned"
            AddRow(mark .. " Treasure Reward", status, color,
                earned and { 0.4, 1, 0.4 } or { 1, 0.5, 0.5 })

            if rewardTooltip and rewardTooltip ~= "" then
                local firstLine = rewardTooltip:match("^([^\n]+)")
                if firstLine then
                    AddRow("  |cff888888" .. firstLine .. "|r", nil, { 0.6, 0.6, 0.6 })
                end
            end
        end
    end

    -- Companion XP bar (always shown when companion data available)
    if companionInfo then
        yOffset = yOffset - 6

        local fmt = ns.FormatNumber or tostring
        local pct = (companionInfo.currentXP / companionInfo.maxXP) * 100
        local levelStr = "Lv " .. companionInfo.level
        if companionInfo.maxRank and companionInfo.maxRank > 0 then
            levelStr = levelStr .. " / " .. companionInfo.maxRank
        end
        AddRow("|cffffd100" .. (companionInfo.name or "Companion") .. "|r  |cffaaaaaa" .. levelStr .. "|r",
               nil, { 1, 0.82, 0 })

        -- XP value on its own full-width line so big numbers don't get squashed
        local valueText
        if companionInfo.isMaxLevel then
            valueText = "Max Rank"
        else
            valueText = string.format("%s / %s  (%.1f%%)",
                fmt(companionInfo.currentXP), fmt(companionInfo.maxXP), pct)
        end
        AddRow("|cffffffffExperience:|r  |cffd9b3ff" .. valueText .. "|r", nil, { 1, 1, 1 })

        -- Graphical bar
        local barY = yOffset - 2
        sc.xpBarBG:ClearAllPoints()
        sc.xpBarBG:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, barY)
        sc.xpBarBG:SetWidth(innerWidth)
        sc.xpBarBG:Show()

        local fillFrac = math.min(1, math.max(0, companionInfo.currentXP / companionInfo.maxXP))
        sc.xpBar:ClearAllPoints()
        sc.xpBar:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, barY)
        sc.xpBar:SetWidth(math.max(1, innerWidth * fillFrac))
        sc.xpBar:Show()

        yOffset = barY - 12

        -- Session / delve / max-level summary lines
        if not companionInfo.isMaxLevel then
            AddRow(string.format("|cffaaaaaaThis Delve:|r    |cffffffff+%s|r", fmt(xpTrack.delveGained)),
                nil, { 0.85, 0.85, 0.85 })
            AddRow(string.format("|cffaaaaaaThis Session:|r  |cffffffff+%s|r", fmt(xpTrack.sessionGained)),
                nil, { 0.85, 0.85, 0.85 })

            -- Remaining to max rank: rank delta + current rank progress.
            -- Without per-rank thresholds we can't sum exact XP, so we show
            -- "N ranks + remaining in current".
            if companionInfo.maxRank and companionInfo.maxRank > 0 then
                local ranksLeft = companionInfo.maxRank - companionInfo.level
                local currRem   = companionInfo.maxXP - companionInfo.currentXP
                local remStr
                if ranksLeft > 0 then
                    remStr = string.format("%d ranks + %s XP", ranksLeft, fmt(currRem))
                else
                    remStr = string.format("%s XP", fmt(currRem))
                end
                AddRow("|cffaaaaaaTo Max Rank:|r   |cffffd9a8" .. remStr .. "|r",
                    nil, { 0.85, 0.85, 0.85 })
            end
        end
    end

    -- Hint bar
    tooltipFrame.hint:SetText(DDT:BuildHintText(db.clickActions or {}, CLICK_ACTIONS))

    local contentH = math.max(math.abs(yOffset), ns.ROW_HEIGHT)
    tooltipFrame:FinalizeLayout(tooltipWidth, contentH)
end

function Delve:ShowTooltip(anchor)
    if not tooltipFrame then
        tooltipFrame = CreateTooltipFrame()
    end

    self:CancelHideTimer()

    local db = self:GetDB()
    ns.AnchorTooltip(tooltipFrame, anchor, db.tooltipGrowDirection)
    tooltipFrame:SetScale(db.tooltipScale or 1.0)

    self:UpdateData()
    self:PopulateTooltip()
    tooltipFrame:Show()
end

function Delve:StartHideTimer()
    self:CancelHideTimer()
    hideTimer = C_Timer.NewTimer(ns.HIDE_DELAY, function()
        if tooltipFrame then tooltipFrame:Hide() end
        hideTimer = nil
    end)
end

function Delve:CancelHideTimer()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
end

---------------------------------------------------------------------------
-- World map pin overlay
---------------------------------------------------------------------------
-- Delve maps don't allow user waypoints (CanSetUserWaypointOnMap == false), so
-- we mark Sanctified Banner spawn locations directly on the world map by
-- attaching custom Frame "pins" to WorldMapFrame.ScrollContainer.Child. The
-- canvas handles scaling/panning automatically as long as pins are parented
-- to it and positioned via SetPoint relative to TOPLEFT.

local function CreateMapPin()
    local canvas = WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
    if not canvas then return nil end

    local pin = CreateFrame("Frame", nil, canvas)
    local scale = (Delve:GetDB().mapPinScale) or 3.0
    pin:SetSize(20 * scale, 20 * scale)
    pin:SetFrameStrata("HIGH")

    pin.ring = pin:CreateTexture(nil, "OVERLAY")
    pin.ring:SetAllPoints(pin)
    ApplyPinIcon(pin)

    pin:EnableMouse(true)
    pin:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Sanctified Banner spawn", 1, 0.82, 0)
        if self.coordText then
            GameTooltip:AddLine(self.coordText, 0.7, 0.85, 1)
        end
        if self.note then
            GameTooltip:AddLine(self.note, 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return pin
end

function Delve:RefreshMapPins()
    -- Hide existing pins
    for _, pin in ipairs(mapPins) do pin:Hide() end

    if not WorldMapFrame or not WorldMapFrame.ScrollContainer then return end
    local canvas = WorldMapFrame.ScrollContainer.Child
    if not canvas then return end

    -- Only show pins when the user is currently viewing the delve's map and
    -- the banner is still uncollected.
    if not inDelve or hasBanner or not delveHeaderText then return end
    local viewedMap = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
    if not viewedMap or (delveMapID and viewedMap ~= delveMapID) then return end

    local locs = BANNER_LOCATIONS[delveHeaderText]
    if not locs then return end

    local cw, ch = canvas:GetSize()
    if not cw or cw == 0 then return end

    for i, loc in ipairs(locs) do
        local pin = mapPins[i]
        if not pin then
            pin = CreateMapPin()
            if not pin then return end
            mapPins[i] = pin
        end
        local scale = (self:GetDB().mapPinScale) or 3.0
        pin:SetSize(20 * scale, 20 * scale)
        ApplyPinIcon(pin)
        pin:ClearAllPoints()
        pin:SetPoint("CENTER", canvas, "TOPLEFT", loc.x * cw, -loc.y * ch)
        pin.coordText = string.format("/way %.2f, %.2f", loc.x * 100, loc.y * 100)
        pin.note = loc.note
        pin:Show()
    end
end

--- Hook the world map so we re-place pins when it opens or changes maps.
local mapHooksInstalled = false
local function InstallMapHooks()
    if mapHooksInstalled or not WorldMapFrame then return end
    mapHooksInstalled = true
    WorldMapFrame:HookScript("OnShow", function() Delve:RefreshMapPins() end)
    -- Re-place pins when the user navigates between maps within the world map
    if WorldMapFrame.OnMapChanged then
        hooksecurefunc(WorldMapFrame, "OnMapChanged", function() Delve:RefreshMapPins() end)
    end
end

---------------------------------------------------------------------------
-- Event handling
---------------------------------------------------------------------------

function Delve:Init()
    InstallMapHooks()
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UPDATE_UI_WIDGET")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    -- ACTIVE_DELVE_DATA_UPDATE fires whenever delve scenario state changes (banner clicked,
    -- empowered pack killed, etc.). This is the primary refresh signal.
    eventFrame:RegisterEvent("ACTIVE_DELVE_DATA_UPDATE")
    eventFrame:RegisterEvent("DELVE_ASSIST_ACTION")
    eventFrame:RegisterEvent("SCENARIO_UPDATE")
    eventFrame:RegisterEvent("SCENARIO_CRITERIA_UPDATE")
    eventFrame:RegisterEvent("SCENARIO_BONUS_OBJECTIVE_COMPLETE")
    eventFrame:RegisterEvent("SCENARIO_BONUS_VISIBILITY_UPDATE")
    -- Companion XP is modeled as a friendship faction, so reputation updates
    -- are how we learn about Brann gaining experience.
    eventFrame:RegisterEvent("UPDATE_FACTION")
    -- Sanctified Banner state lives in a player aura, so watch aura changes.
    eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "UPDATE_UI_WIDGET" then
            local widgetInfo = ...
            -- Only refresh on widget updates that are actually our widget type, to avoid
            -- thrashing UpdateData on every nameplate / objective tracker tick.
            if widgetInfo and widgetInfo.widgetType == Enum.UIWidgetVisualizationType.ScenarioHeaderDelves then
                cachedWidgetID = widgetInfo.widgetID
                self:UpdateData()
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
            self:UpdateData()
            -- After /reload inside a delve, widget + scenario data is not yet pushed
            -- to the client when this event fires. Schedule a few retries so we catch
            -- the data once it arrives, instead of showing an empty tooltip.
            C_Timer.After(0.5, function() self:UpdateData() end)
            C_Timer.After(1.5, function() self:UpdateData() end)
            C_Timer.After(4.0, function() self:UpdateData() end)
        else
            self:UpdateData()
        end
    end)

    -- Diagnostic dump: /ddtdelve prints widget + scenario data to chat so we can
    -- see exactly what the server is reporting (helps diagnose missing sub-objectives).
    SLASH_DDTDELVE1 = "/ddtdelve"
    SlashCmdList["DDTDELVE"] = function()
        Delve:DiagnosticDump()
    end
end

function Delve:DiagnosticDump()
    local function p(...) print("|cff55bbff[DDT-Delve]|r", ...) end

    p("===== Delve Diagnostic =====")

    -- Scenario info
    local stepInfo
    if C_ScenarioInfo and C_ScenarioInfo.GetScenarioInfo then
        local sInfo = C_ScenarioInfo.GetScenarioInfo()
        if sInfo then
            p(string.format("Scenario: %s (id=%s, stage %s/%s, type=%s)",
                tostring(sInfo.name), tostring(sInfo.scenarioID),
                tostring(sInfo.currentStage), tostring(sInfo.numStages), tostring(sInfo.type)))
        else
            p("No active scenario.")
        end
    end

    -- Delve eligibility
    if C_DelvesUI then
        if C_DelvesUI.HasActiveDelve then
            local ok, has = pcall(C_DelvesUI.HasActiveDelve, nil)
            p("HasActiveDelve(nil): " .. tostring(ok and has))
        end
        if C_DelvesUI.IsEligibleForActiveDelveRewards then
            local ok, e = pcall(C_DelvesUI.IsEligibleForActiveDelveRewards, "player")
            p("IsEligibleForActiveDelveRewards: " .. tostring(ok and e))
        end
    end

    -- Step + criteria
    if C_ScenarioInfo and C_ScenarioInfo.GetScenarioStepInfo then
        stepInfo = C_ScenarioInfo.GetScenarioStepInfo()
        if stepInfo then
            p(string.format("Step: %s (stepID=%s, numCriteria=%s, widgetSetID=%s, isBonus=%s)",
                tostring(stepInfo.title), tostring(stepInfo.stepID),
                tostring(stepInfo.numCriteria), tostring(stepInfo.widgetSetID),
                tostring(stepInfo.isBonusStep)))
            for i = 1, (stepInfo.numCriteria or 0) do
                local c = C_ScenarioInfo.GetCriteriaInfo(i)
                if c then
                    p(string.format("  crit[%d] %s | done=%s | %s/%s | qStr=%q",
                        i, tostring(c.description), tostring(c.completed),
                        tostring(c.quantity), tostring(c.totalQuantity),
                        tostring(c.quantityString)))
                end
            end
        end
    end

    -- Walk EVERY widget in the scenario step's widget set (not just ScenarioHeaderDelves).
    -- The Sanctified Banner state may live in a sibling widget.
    if stepInfo and stepInfo.widgetSetID then
        local widgets = C_UIWidgetManager.GetAllWidgetsBySetID(stepInfo.widgetSetID)
        if widgets then
            p(string.format("Widget set %d: %d widgets", stepInfo.widgetSetID, #widgets))
            for _, w in ipairs(widgets) do
                p(string.format("  widget id=%s type=%s", tostring(w.widgetID), tostring(w.widgetType)))
            end
        end
    end

    -- ScenarioHeaderDelves widget (the one we currently use)
    local info = FindDelveWidget()
    if info then
        p(string.format("Header: tier=%q name=%q  spells=%d  reward=%s",
            tostring(info.tierText), tostring(info.headerText),
            info.spells and #info.spells or 0,
            info.rewardInfo and tostring(info.rewardInfo.shownState) or "nil"))

        for i, sp in ipairs(info.spells or {}) do
            local tipLen = sp.tooltip and #sp.tooltip or 0
            p(string.format("  spell[%d] id=%s earned=%s glow=%s text=%q tipLen=%d",
                i, tostring(sp.spellID), tostring(sp.showAsEarned),
                tostring(sp.showGlowState), tostring(sp.text), tipLen))

            -- Resolve spell name
            if C_Spell and C_Spell.GetSpellName then
                local nm = C_Spell.GetSpellName(sp.spellID)
                if nm then p("    name= " .. tostring(nm)) end
            end

            -- Spell description (often dynamic, may include collection state)
            if C_Spell and C_Spell.GetSpellDescription then
                local desc = C_Spell.GetSpellDescription(sp.spellID)
                if desc and desc ~= "" then
                    for line in desc:gmatch("([^\n]+)") do
                        if line ~= "" then p("    desc> " .. line) end
                    end
                end
            end

            -- Full spell tooltip via TooltipInfo (this is the rendered tooltip)
            if C_TooltipInfo and C_TooltipInfo.GetSpellByID then
                local td = C_TooltipInfo.GetSpellByID(sp.spellID)
                if td and td.lines then
                    for j, line in ipairs(td.lines) do
                        local lt = line.leftText
                        if lt and lt ~= "" then
                            p(string.format("    tip[%d]> %s", j, lt))
                        end
                    end
                end
            end
        end
    else
        p("No ScenarioHeaderDelves widget found.")
    end

    -- ALL player auras (helpful) so we can identify which aura corresponds to
    -- the Sanctified Banner click on different delve tiers / banner variants.
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        p("--- Player HELPFUL auras ---")
        for i = 1, 80 do
            local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
            if not aura then break end
            p(string.format("  [%d] %s  id=%s  stacks=%s  src=%s",
                i, tostring(aura.name), tostring(aura.spellId),
                tostring(aura.applications), tostring(aura.sourceUnit)))
        end
    end

    -- Probe known/likely Sanctified Banner spell IDs explicitly
    if not (C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret())
       and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local probes = { 1271918, 462940, 1278223, 1270179, 1277243 }
        for _, sid in ipairs(probes) do
            local a = C_UnitAuras.GetPlayerAuraBySpellID(sid)
            p(string.format("Probe aura spellID=%d  -> %s",
                sid, a and "PRESENT" or "absent"))
        end
    end

    -- Companion lookup (every path)
    if GetPlayerCompanionID then
        local ok, id = pcall(GetPlayerCompanionID)
        p("GetPlayerCompanionID: " .. tostring(ok and id))
    end
    if C_DelvesUI and C_DelvesUI.GetCompanionInfoForActivePlayer then
        local ok, id = pcall(C_DelvesUI.GetCompanionInfoForActivePlayer)
        p("GetCompanionInfoForActivePlayer: " .. tostring(ok and id))
    end
    if C_DelvesUI and C_DelvesUI.GetFactionForCompanion then
        local ok, fid = pcall(C_DelvesUI.GetFactionForCompanion, nil)
        p("GetFactionForCompanion(nil): " .. tostring(ok and fid))
    end
    if companionInfo then
        p(string.format("Resolved Companion: %s Lv%s  %s/%s",
            tostring(companionInfo.name), tostring(companionInfo.level),
            tostring(companionInfo.currentXP), tostring(companionInfo.maxXP)))
    else
        p("Resolved Companion: <none>")
    end

    p("===== End =====")
end

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------

Delve.settingsLabel = "Delve"

function Delve:BuildSettingsPanel(panel)
    local W = ns.SettingsWidgets
    local r = panel.refreshCallbacks
    local db = function() return ns.db.delve end

    W.AddLabelEditBox(panel, "status name tier progress prog",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateLabel() end, r, {
        { "Default",     "Delve: <progress>" },
        { "Status",      "<status>" },
        { "Name + Prog", "<name> <progress>" },
        { "Tier + Prog", "<tier> <progress>" },
        { "Compact",     "<prog>" },
    })

    -- Display
    local body = W.AddSection(panel, "Display")
    local y = 0
    y = W.AddCheckbox(body, y, "Hide datatext when not in a delve",
        function() return db().hideWhenIdle end,
        function(v) db().hideWhenIdle = v; self:UpdateLabel() end, r)
    y = W.AddSlider(body, y, "Map Pin Scale", 0.5, 10.0, 0.1,
        function() return db().mapPinScale end,
        function(v) db().mapPinScale = v; Delve:RefreshMapPins() end, r)
    do
        local iconValues = {}
        for key, def in pairs(MAP_PIN_ICONS) do iconValues[key] = def.label end
        y = W.AddDropdown(body, y, "Map Pin Icon", iconValues,
            function() return db().mapPinIcon end,
            function(v) db().mapPinIcon = v; Delve:RefreshMapPins() end)
    end
    W.EndSection(panel, y)

    -- Tooltip
    body = W.AddSection(panel, "Tooltip", true)
    y = 0
    y = W.AddSliderPair(body, y,
        { label = "Scale", min = 0.5, max = 2.0, step = 0.05,
          get = function() return db().tooltipScale end,
          set = function(v) db().tooltipScale = v end },
        { label = "Width", min = 250, max = 600, step = 10,
          get = function() return db().tooltipWidth end,
          set = function(v) db().tooltipWidth = v end }, r)
    y = W.AddSliderPair(body, y,
        { label = "Max Height", min = 100, max = 800, step = 10,
          get = function() return db().tooltipMaxHeight end,
          set = function(v) db().tooltipMaxHeight = v end },
        nil, r)
    y = W.AddTooltipGrowDirection(body, y, db, r)
    y = W.AddTooltipCopyFrom(body, y, "delve", db, r)
    W.EndSection(panel, y)

    -- Click Actions
    ns.AddModuleClickActionsSection(panel, r, "delve", CLICK_ACTIONS)
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("delve", Delve, DEFAULTS)
