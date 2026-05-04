-- Djinni's Data Texts - Volume Control
-- Interactive tooltip with per-stream volume sliders and mute toggles.
local addonName, ns = ...
local DDT = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

local VolumeControl = {}
ns.VolumeControl = VolumeControl

local tooltipFrame = nil
local hideTimer    = nil
local updating     = false   -- guard OnValueChanged re-entrance

local TOOLTIP_WIDTH = 300
local PADDING       = 10
local ROW_HEIGHT    = 26
local CB_W          = 18
local LABEL_W       = 64
local VALUE_W       = 36
-- Slider fills remaining inner width: 300 - 2*10 - 18 - 4 - 64 - 4 - 36 - 4 = 150
local SLIDER_W      = 150

local STREAMS = {
    { key = "master",   label = "Master",   cvar = "Sound_MasterVolume",   enableCvar = "Sound_EnableAllSound" },
    { key = "music",    label = "Music",    cvar = "Sound_MusicVolume",    enableCvar = "Sound_EnableMusic"    },
    { key = "sfx",      label = "Effects",  cvar = "Sound_SFXVolume",      enableCvar = "Sound_EnableSFX"      },
    { key = "ambience", label = "Ambience", cvar = "Sound_AmbienceVolume", enableCvar = "Sound_EnableAmbience" },
    { key = "dialog",   label = "Dialog",   cvar = "Sound_DialogVolume",   enableCvar = "Sound_EnableDialog"   },
}

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
    labelTemplate    = "Vol: <master>%",
    increment        = 5,
    invertScroll     = false,
    tooltipScale     = 1.0,
    tooltipWidth     = TOOLTIP_WIDTH,
    tooltipMaxHeight = 500,
    clickActions     = {
        leftClick       = "togglemute",
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
    togglemute   = "Toggle Master Mute",
    opensettings = "Open DDT Settings",
    none         = "None",
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

function VolumeControl:GetDB()
    return ns.db and ns.db.volumecontrol or DEFAULTS
end

local function ScrollDelta(delta)
    local db = VolumeControl:GetDB()
    local dir = db.invertScroll and -1 or 1
    local step = IsShiftKeyDown() and 1 or (db.increment or 5)
    return delta * step * dir
end

local function GetVolPct(cvar)
    return math.floor((tonumber(GetCVar(cvar)) or 1) * 100 + 0.5)
end

local function SetVolPct(cvar, pct)
    SetCVar(cvar, string.format("%.4f", math.max(0, math.min(1, pct / 100))))
end

local function IsEnabled(cvar)
    return GetCVar(cvar) ~= "0"
end

---------------------------------------------------------------------------
-- Label
---------------------------------------------------------------------------

local dataobj  -- forward ref

local function ExpandLabel(template)
    local E = ns.ExpandTag
    local result = template
    local masterMuted = not IsEnabled("Sound_EnableAllSound")
    result = E(result, "muted",    masterMuted and "MUTED" or "")
    result = E(result, "master",   tostring(GetVolPct("Sound_MasterVolume")))
    result = E(result, "music",    tostring(GetVolPct("Sound_MusicVolume")))
    result = E(result, "sfx",      tostring(GetVolPct("Sound_SFXVolume")))
    result = E(result, "ambience", tostring(GetVolPct("Sound_AmbienceVolume")))
    result = E(result, "dialog",   tostring(GetVolPct("Sound_DialogVolume")))
    return result
end

function VolumeControl:UpdateLabel()
    if not dataobj then return end
    dataobj.text = ExpandLabel(self:GetDB().labelTemplate)
end

---------------------------------------------------------------------------
-- Tooltip widget builders
---------------------------------------------------------------------------

local function MakeStreamSlider(parent, stream)
    local slider = CreateFrame("Slider", nil, parent)
    slider:SetSize(SLIDER_W, 18)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(0, 100)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)

    -- Track
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT", 8, 0)
    track:SetPoint("RIGHT", -8, 0)
    track:SetHeight(4)
    track:SetColorTexture(0.2, 0.2, 0.2, 1)
    slider._track = track

    -- Fill
    local fill = slider:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("LEFT", track, "LEFT", 0, 0)
    fill:SetHeight(4)
    fill:SetColorTexture(0.3, 0.65, 1, 0.9)
    slider._fill = fill

    -- Thumb
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    local thumb = slider:GetThumbTexture()
    if thumb then thumb:SetSize(10, 18) end

    slider:EnableMouseWheel(true)
    slider:SetScript("OnMouseWheel", function(self, delta)
        SetVolPct(stream.cvar, math.max(0, math.min(100, GetVolPct(stream.cvar) + ScrollDelta(delta))))
        VolumeControl:RefreshTooltip()
        VolumeControl:UpdateLabel()
    end)

    slider:SetScript("OnValueChanged", function(self, value)
        if updating then return end
        -- Apply to game
        updating = true
        SetVolPct(stream.cvar, math.floor(value + 0.5))
        updating = false
        -- Update fill
        local trackW = (track:GetWidth() or 0)
        if trackW > 0 then
            fill:SetWidth(math.max(0, (value / 100) * trackW))
        end
        -- Update companion value text
        if self._valueText then
            self._valueText:SetText(math.floor(value + 0.5) .. "%")
        end
        VolumeControl:UpdateLabel()
    end)

    slider:SetScript("OnEnter", function() VolumeControl:CancelHideTimer() end)
    slider:SetScript("OnLeave", function() VolumeControl:StartHideTimer() end)

    return slider
end

local function MakeStreamCheckButton(parent, stream)
    local cb = CreateFrame("CheckButton", nil, parent)
    cb:SetSize(CB_W, CB_W)
    cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")

    cb:SetScript("OnClick", function(self)
        SetCVar(stream.enableCvar, self:GetChecked() and "1" or "0")
        VolumeControl:RefreshTooltip()
        VolumeControl:UpdateLabel()
    end)
    cb:SetScript("OnEnter", function() VolumeControl:CancelHideTimer() end)
    cb:SetScript("OnLeave", function() VolumeControl:StartHideTimer() end)
    return cb
end

---------------------------------------------------------------------------
-- Tooltip frame creation
---------------------------------------------------------------------------

local function BuildTooltipFrame()
    local f = ns.CreateTooltipFrame("DDTVolumeControlTooltip", VolumeControl)
    local c = f.content
    f.streamRows = {}

    local y = 0
    for i, stream in ipairs(STREAMS) do
        local row = { stream = stream }

        -- Checkbox (enable/disable stream)
        row.cb = MakeStreamCheckButton(c, stream)
        row.cb:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y - math.floor((ROW_HEIGHT - CB_W) / 2))

        -- Stream label
        row.label = ns.FontString(c, "DDTFontNormal")
        row.label:SetPoint("TOPLEFT", c, "TOPLEFT", CB_W + 4, y)
        row.label:SetSize(LABEL_W, ROW_HEIGHT)
        row.label:SetJustifyH("LEFT")
        row.label:SetJustifyV("MIDDLE")
        row.label:SetText(stream.label)

        -- Value text (right-aligned, rightmost column)
        row.value = ns.FontString(c, "DDTFontSmall")
        row.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, y)
        row.value:SetSize(VALUE_W, ROW_HEIGHT)
        row.value:SetJustifyH("RIGHT")
        row.value:SetJustifyV("MIDDLE")

        -- Slider
        row.slider = MakeStreamSlider(c, stream)
        row.slider:SetPoint("TOPLEFT", c, "TOPLEFT",
            CB_W + 4 + LABEL_W + 4,
            y - math.floor((ROW_HEIGHT - 18) / 2))
        row.slider._valueText = row.value

        f.streamRows[i] = row
        y = y - ROW_HEIGHT - 2
    end

    -- Outer-frame mouse wheel adjusts master volume
    f:SetScript("OnMouseWheel", function(self, delta)
        SetVolPct("Sound_MasterVolume", math.max(0, math.min(100, GetVolPct("Sound_MasterVolume") + ScrollDelta(delta))))
        VolumeControl:RefreshTooltip()
        VolumeControl:UpdateLabel()
    end)

    return f
end

---------------------------------------------------------------------------
-- Tooltip population
---------------------------------------------------------------------------

function VolumeControl:RefreshTooltip()
    if not tooltipFrame or not tooltipFrame:IsShown() then return end
    local masterMuted = not IsEnabled("Sound_EnableAllSound")

    for _, row in ipairs(tooltipFrame.streamRows) do
        local stream = row.stream
        local vol     = GetVolPct(stream.cvar)
        local enabled = IsEnabled(stream.enableCvar)
        local muted   = masterMuted or not enabled

        -- Checkbox reflects enable state
        row.cb:SetChecked(enabled)

        -- Dim label and value when muted
        local dim = muted and 0.45 or 1.0
        row.label:SetTextColor(dim, dim, dim)
        row.value:SetTextColor(dim, dim, dim)
        row.value:SetText(vol .. "%")

        -- Update slider without triggering OnValueChanged side-effects
        updating = true
        row.slider:SetValue(vol)
        local trackW = row.slider._track:GetWidth() or 0
        if trackW > 0 then
            row.slider._fill:SetWidth(math.max(0, (vol / 100) * trackW))
        end
        updating = false
    end
end

function VolumeControl:ShowTooltip(anchor)
    self:CancelHideTimer()
    if not tooltipFrame then
        tooltipFrame = BuildTooltipFrame()
    end

    local db = self:GetDB()
    ns.AnchorTooltip(tooltipFrame, anchor, db.tooltipGrowDirection)
    tooltipFrame:SetScale(db.tooltipScale or 1.0)
    tooltipFrame.header:SetText("Volume")

    local ttWidth   = db.tooltipWidth or TOOLTIP_WIDTH
    local innerW    = ttWidth - 2 * PADDING
    local contentH  = #STREAMS * (ROW_HEIGHT + 2)

    -- Size content frame so right-anchored value text has a reference
    tooltipFrame.content:SetWidth(innerW)
    tooltipFrame.content:SetHeight(contentH)

    self:RefreshTooltip()

    tooltipFrame.hint:SetText(DDT:BuildHintText(db.clickActions or {}, CLICK_ACTIONS))
    tooltipFrame:FinalizeLayout(ttWidth, contentH)
    tooltipFrame:Show()
end

---------------------------------------------------------------------------
-- Hide timer
---------------------------------------------------------------------------

function VolumeControl:StartHideTimer()
    self:CancelHideTimer()
    hideTimer = C_Timer.NewTimer(ns.HIDE_DELAY, function()
        if tooltipFrame then tooltipFrame:Hide() end
        hideTimer = nil
    end)
end

function VolumeControl:CancelHideTimer()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
end

---------------------------------------------------------------------------
-- LDB Data Object
---------------------------------------------------------------------------

dataobj = LDB:NewDataObject("DDT-VolumeControl", {
    type  = "data source",
    text  = "Vol: --",
    icon  = "Interface\\Icons\\inv_misc_bell_01",
    label = "DDT - Volume",
    OnEnter = function(self)
        -- OnMouseWheel is not a standard LDB callback so display addons (e.g.
        -- ElvUI) never wire it up. Hook the actual display frame directly on
        -- first hover so scroll works regardless of which display is in use.
        if not self._ddt_vol_scroll then
            self:EnableMouseWheel(true)
            self:HookScript("OnMouseWheel", function(_, delta)
                SetVolPct("Sound_MasterVolume", math.max(0, math.min(100, GetVolPct("Sound_MasterVolume") + ScrollDelta(delta))))
                VolumeControl:RefreshTooltip()
                VolumeControl:UpdateLabel()
            end)
            self._ddt_vol_scroll = true
        end
        VolumeControl:ShowTooltip(self)
    end,
    OnLeave = function(self)
        VolumeControl:StartHideTimer()
    end,
    OnClick = function(self, button)  -- scroll is hooked in OnEnter above
        local db = VolumeControl:GetDB()
        local action = DDT:ResolveClickAction(button, db.clickActions or {})
        if action == "togglemute" then
            SetCVar("Sound_EnableAllSound", IsEnabled("Sound_EnableAllSound") and "0" or "1")
            VolumeControl:RefreshTooltip()
            VolumeControl:UpdateLabel()
        elseif action == "pintooltip" then
            ns:TogglePinTooltip(VolumeControl, tooltipFrame)
        elseif action == "opensettings" then
            if DDT.settingsCategoryID then
                Settings.OpenToCategory(DDT.settingsCategoryID)
            end
        end
    end,
})

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("CVAR_UPDATE")
eventFrame:SetScript("OnEvent", function(_, event, cvarName)
    if event == "PLAYER_LOGIN" then
        VolumeControl:UpdateLabel()
    elseif event == "CVAR_UPDATE" and cvarName and cvarName:find("^Sound_") then
        VolumeControl:UpdateLabel()
        VolumeControl:RefreshTooltip()
    end
end)

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function VolumeControl:Init()
    self:UpdateLabel()
end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------

VolumeControl.settingsLabel = "Volume Control"

function VolumeControl:BuildSettingsPanel(panel)
    local W = ns.SettingsWidgets
    local r = panel.refreshCallbacks
    local db = function() return ns.db.volumecontrol end

    W.AddLabelEditBox(panel, "master music sfx ambience dialog muted",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateLabel() end, r)

    local body = W.AddSection(panel, "Tooltip")
    local y = 0

    y = W.AddSlider(body, y, "Scroll Increment (%)", 1, 20, 1,
        function() return db().increment end,
        function(v) db().increment = v end, r)

    y = W.AddCheckbox(body, y, "Invert Scroll (scroll up = volume down)",
        function() return db().invertScroll end,
        function(v) db().invertScroll = v end, r)

    y = W.AddSliderPair(body, y,
        { label = "Scale", min = 0.5, max = 2.0, step = 0.05,
          get = function() return db().tooltipScale end,
          set = function(v) db().tooltipScale = v end },
        { label = "Width", min = 250, max = 2000, step = 10,
          get = function() return db().tooltipWidth end,
          set = function(v) db().tooltipWidth = v end }, r)

    y = W.AddTooltipGrowDirection(body, y, db, r)
    W.EndSection(panel, y)

    ns.AddModuleClickActionsSection(panel, r, "volumecontrol", CLICK_ACTIONS)
end

---------------------------------------------------------------------------
-- Registration
---------------------------------------------------------------------------

ns:RegisterModule("volumecontrol", VolumeControl, DEFAULTS)
