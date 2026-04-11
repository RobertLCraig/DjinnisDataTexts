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
    enabled       = { delve = true, prey = true },
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

local function GetDB()
    return ns.db and ns.db.activeactivity or DEFAULTS
end

local function IsTrackerEnabled(key)
    local db = GetDB()
    if not db.enabled then return true end
    return db.enabled[key] ~= false
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

dataobj = LDB:NewDataObject("DDT-ActiveActivity", {
    type    = "data source",
    text    = IDLE_TEXT,
    icon    = IDLE_ICON,
    label   = "DDT - Active Activity",
    OnEnter = function(self) OnEnter(self) end,
    OnLeave = function() OnLeave() end,
    OnClick = OnClick,
})
if not dataobj then
    dataobj = LDB:GetDataObjectByName("DDT-ActiveActivity")
end
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
        "active tracker (by priority order) is shown.")
    for _, key in ipairs(trackerOrder) do
        local t = trackers[key]
        local label = t.displayName or key
        y = W.AddCheckbox(body, y, label,
            function() return IsTrackerEnabled(key) end,
            function(v)
                local db = GetDB()
                db.enabled = db.enabled or {}
                db.enabled[key] = v
                self:UpdateLabel()
            end, r)
    end
    W.EndSection(panel, y)

    -- Click actions (idle fallback only - active tracker handles its own clicks)
    ns.AddModuleClickActionsSection(panel, r, "activeactivity", CLICK_ACTIONS,
        "These click actions only fire when no tracked activity is currently " ..
        "active. While an activity is engaged, the active tracker's own click " ..
        "actions take over (configure them in their respective settings panels).")
end

ns:RegisterModule("activeactivity", ActiveActivity, DEFAULTS)
