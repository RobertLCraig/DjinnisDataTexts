-- ActiveActivity.lua
--
-- Aggregator module: provides a single LDB datatext that routes hover, click,
-- and label updates to whichever sub-tracker is currently engaged. Sub-trackers
-- (Delve, PreyTracker, future Dungeon/Mythic/Raid modules) register themselves
-- via ns:RegisterActivityTracker() during file load and continue to own their
-- own tooltip frames, data, and event handling. The aggregator only owns the
-- LDB broker and the dispatch logic.

local _, ns = ...
local LDB = LibStub("LibDataBroker-1.1")
local DDT = ns.DDT
local ActiveActivity = {}

local trackers     = {}   -- key -> tracker definition
local trackerOrder = {}   -- registration order, sorted by priority on register
local activeKey    = nil  -- key of the tracker that "owns" the current label/hover
local dataobj      = nil

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
    -- No labelTemplate here: each sub-tracker provides its already-formatted
    -- label text via GetLabelText(), so the aggregator just displays it
    -- verbatim. Per-tracker label customization lives in each tracker's own
    -- settings panel.
    -- No `enabled` table. Sub-tracker on/off used to live here, but it was read
    -- through a GetDB() that looked up the wrong saved key, so it never
    -- persisted and its setter wrote into this defaults table instead. Tracker
    -- enable now goes through ns:IsModuleEnabled/SetModuleEnabled, the same flag
    -- the Modules panel uses for everything else, which actually saves and also
    -- stops the tracker doing work rather than only hiding its output. Nothing
    -- to migrate: the old value could never reach the saved DB.
    clickActions  = {
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

local IDLE_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local IDLE_TEXT = "Idle"

---------------------------------------------------------------------------
-- Tracker registration API (called by sub-tracker files at load time)
---------------------------------------------------------------------------

--- Register an activity sub-tracker. Tracker fields:
---   key            string - unique key (e.g. "delve")
---   displayName    string - shown in settings
---   icon           string - texture path used as the LDB icon while active
---   priority       number - lower = higher priority when multiple are active
---   IsActive       function() -> bool
---   GetStatusText  function() -> string  (the status fragment shown in the label)
---   ShowTooltip    function(anchor)
---   HideTooltip    function()
---   HandleClick    function(button)
---   GetSettingsCategoryID function() -> id  (optional - for "open settings" routing)
function ns:RegisterActivityTracker(key, def)
    def.key = key
    def.priority = def.priority or 100
    trackers[key] = def
    -- Claim the backing module so the Modules panel leaves it out of its list
    -- and this panel becomes its only switch. Recorded here rather than on the
    -- module table because trackers register at file load, before the module
    -- registers itself further down the same file.
    if def.moduleKey then
        ns.subTrackerModules[def.moduleKey] = "ActiveActivity"
    end
    table.insert(trackerOrder, key)
    table.sort(trackerOrder, function(a, b)
        return (trackers[a].priority or 100) < (trackers[b].priority or 100)
    end)
    -- If the aggregator's already initialized, refresh immediately so the new
    -- tracker shows up without waiting for the next state change.
    if ActiveActivity._initialized then
        ActiveActivity:UpdateLabel()
    end
end

---------------------------------------------------------------------------
-- Active tracker resolution
---------------------------------------------------------------------------

-- The saved key is "ActiveActivity", matching ns:RegisterModule below. This
-- read said "activeactivity" until 0.9.14, which is not the key MergeDefaults
-- creates, so it always missed and fell through to DEFAULTS. That silently made
-- the idle click actions unconfigurable (saved correctly, read from defaults)
-- and the tracker toggles unsaveable. Keep the case in step with the
-- registration; this module is the only one registered CamelCase.
local function GetDB()
    return (ns.db and ns.db.ActiveActivity) or DEFAULTS
end

-- A tracker is on when its backing module is on. One flag, in ns.db.modules,
-- so the Modules panel and this panel cannot disagree about the same tracker.
local function IsTrackerEnabled(key)
    local t = trackers[key]
    if t and t.moduleKey then
        return ns:IsModuleEnabled(t.moduleKey)
    end
    return true
end

local function ResolveActiveTracker()
    for _, key in ipairs(trackerOrder) do
        local t = trackers[key]
        if IsTrackerEnabled(key) and t.IsActive and t.IsActive() then
            return key, t
        end
    end
    return nil, nil
end

---------------------------------------------------------------------------
-- Label
---------------------------------------------------------------------------

function ActiveActivity:UpdateLabel()
    if not dataobj then return end
    local key, tracker = ResolveActiveTracker()
    activeKey = key
    if tracker then
        local text = (tracker.GetLabelText and tracker.GetLabelText()) or tracker.displayName
        if text == nil or text == "" then text = tracker.displayName or IDLE_TEXT end
        dataobj.text = text
        dataobj.icon = tracker.icon or IDLE_ICON
    else
        dataobj.text = IDLE_TEXT
        dataobj.icon = IDLE_ICON
    end
end

--- Public notification: a sub-tracker calls this whenever its state changes
--- (active/inactive, progress, etc) so the aggregator can refresh.
function ns:NotifyActivityChange()
    if ActiveActivity._initialized then
        ActiveActivity:UpdateLabel()
    end
end

---------------------------------------------------------------------------
-- Hover / click dispatch
---------------------------------------------------------------------------

local function OnEnter(anchor)
    -- Re-resolve on hover so we always show the freshest active tracker.
    local key, tracker = ResolveActiveTracker()
    activeKey = key
    if tracker and tracker.ShowTooltip then
        tracker.ShowTooltip(anchor)
    end
end

local function OnLeave()
    if activeKey and trackers[activeKey] and trackers[activeKey].HideTooltip then
        trackers[activeKey].HideTooltip()
    end
end

local function OnClick(self, button)
    -- Active tracker (if any) gets first crack at the click. If no tracker is
    -- active, fall back to the aggregator's own click action map (so the user
    -- can still bind e.g. Alt+LClick = Open DDT Settings while idle).
    local key, tracker = ResolveActiveTracker()
    if tracker and tracker.HandleClick then
        tracker.HandleClick(button)
        return
    end
    local db = GetDB()
    local action = DDT:ResolveClickAction(button, db.clickActions or {})
    if not action or action == "none" then return end
    if action == "opensettings" then
        if DDT.settingsCategoryID then
            Settings.OpenToCategory(DDT.settingsCategoryID)
        end
    end
end

---------------------------------------------------------------------------
-- LDB data object
---------------------------------------------------------------------------

dataobj = ns:NewBroker("ActiveActivity", "DDT-ActiveActivity", {
    type    = "data source",
    text    = IDLE_TEXT,
    icon    = IDLE_ICON,
    label   = "DDT - Active Activity",
    OnEnter = function(self) OnEnter(self) end,
    OnLeave = function() OnLeave() end,
    OnClick = OnClick,
})
ActiveActivity.dataobj = dataobj

---------------------------------------------------------------------------
-- Init / Settings
---------------------------------------------------------------------------

function ActiveActivity:Init()
    self._initialized = true
    self:UpdateLabel()
end

function ActiveActivity:BuildSettingsPanel(panel)
    local W = ns.SettingsWidgets
    local r = panel.refreshCallbacks

    -- Enabled trackers
    local body = W.AddSection(panel, "Active Trackers")
    local y = 0
    y = W.AddDescription(body, y,
        "Toggle which activity types this datatext should follow. The first " ..
        "active tracker (by priority order) is shown. These are the whole " ..
        "on/off switch for each tracker, so turning one off also stops it " ..
        "scanning and polling rather than just hiding it here. That is why a " ..
        "change needs a UI reload, exactly like the Modules panel.")
    -- Column headings, matching the Modules panel so the rows read the same way.
    local hTracker = body:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hTracker:SetPoint("TOPLEFT", body, "TOPLEFT", 18, y)
    hTracker:SetText("Tracker")
    local hPoll = body:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hPoll:SetPoint("TOPLEFT", body, "TOPLEFT", 300, y)
    hPoll:SetText("Refresh interval")
    y = y - 18

    for _, key in ipairs(trackerOrder) do
        local t = trackers[key]
        if t.moduleKey and W.AddModuleRow then
            -- The same row the Modules panel builds, so a sub-tracker keeps its
            -- interval dropdown rather than being demoted to a bare checkbox.
            y = W.AddModuleRow(body, y, t.moduleKey, r)
        else
            -- A tracker with no backing module cannot be switched off, so show
            -- it rather than offering a control that would do nothing.
            y = W.AddNote(body, y, (t.displayName or key) .. " (always on)")
        end
    end

    -- Mirrors the Modules panel's note, since these checkboxes now set the same
    -- flag and are subject to the same reload.
    local pending = body:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pending:SetPoint("TOPLEFT", body, "TOPLEFT", 18, y - 4)
    pending:SetTextColor(1, 0.82, 0)
    table.insert(r, function()
        pending:SetText(ns:HasPendingModuleChanges()
            and "Changes pending - reload the UI to apply them."
            or "")
    end)
    y = y - 22

    W.EndSection(panel, y)

    -- Click actions (idle fallback only - active tracker handles its own clicks)
    ns.AddModuleClickActionsSection(panel, r, "ActiveActivity", CLICK_ACTIONS,
        "These click actions only fire when no tracked activity is currently " ..
        "active. While an activity is engaged, the active tracker's own click " ..
        "actions take over (configure them in their respective settings panels).")
end

-- The only module registered CamelCase, so its saved table is
-- DjinnisDataTextsDB.ActiveActivity. Renaming the key would orphan every
-- existing user's settings for this module, so it stays; GetDB() above matches
-- the case deliberately.
ActiveActivity.settingsLabel = "Active Activity"

ns:RegisterModule("ActiveActivity", ActiveActivity, DEFAULTS)
