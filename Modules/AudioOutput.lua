-- Djinni's Data Texts - Audio Output Device
-- Switch between available audio output devices from a tooltip list.
local addonName, ns = ...
local DDT = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

local AudioOutput = {}
ns.AudioOutput = AudioOutput

local tooltipFrame = nil
local hideTimer    = nil

local TOOLTIP_WIDTH = 320
local PADDING       = 10
local ROW_HEIGHT    = ns.ROW_HEIGHT or 20

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
    labelTemplate    = "<device>",
    maxLabelLength   = 24,
    tooltipScale     = 1.0,
    tooltipWidth     = TOOLTIP_WIDTH,
    tooltipMaxHeight = 500,
    clickActions     = {
        leftClick       = "toggle",
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
    toggle       = "Open/Close Device List",
    cyclenext    = "Cycle to Next Device",
    cycleprev    = "Cycle to Previous Device",
    opensettings = "Open DDT Settings",
    none         = "None",
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

function AudioOutput:GetDB()
    return ns.db and ns.db.audiooutput or DEFAULTS
end

local function GetCurrentDeviceIndex()
    return tonumber(GetCVar("Sound_OutputDriverIndex")) or 0
end

local function GetDeviceCount()
    return Sound_GameSystem_GetNumOutputDrivers() or 0
end

local function GetDeviceName(index)
    local name = Sound_GameSystem_GetOutputDriverNameByIndex(index)
    return (name and name ~= "") and name or ("Device " .. index)
end

local function SwitchToDevice(index)
    SetCVar("Sound_OutputDriverIndex", index)
    Sound_GameSystem_RestartSoundSystem()
end

local function TruncateName(name, maxLen)
    if #name <= maxLen then return name end
    return name:sub(1, maxLen - 1) .. "…"
end

---------------------------------------------------------------------------
-- Label
---------------------------------------------------------------------------

local dataobj  -- forward ref

local function ExpandLabel(template)
    local E = ns.ExpandTag
    local db = AudioOutput:GetDB()
    local idx    = GetCurrentDeviceIndex()
    local name   = GetDeviceName(idx)
    local result = template
    result = E(result, "device", TruncateName(name, db.maxLabelLength or 24))
    result = E(result, "index",  tostring(idx + 1))   -- 1-based for display
    result = E(result, "count",  tostring(GetDeviceCount()))
    return result
end

function AudioOutput:UpdateLabel()
    if not dataobj then return end
    dataobj.text = ExpandLabel(self:GetDB().labelTemplate)
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------

local function BuildTooltipFrame()
    local f = ns.CreateTooltipFrame("DDTAudioOutputTooltip", AudioOutput)
    f.deviceRows = {}
    return f
end

function AudioOutput:PopulateTooltip()
    local f = tooltipFrame
    local c = f.content
    local db = self:GetDB()
    local ttWidth  = db.tooltipWidth or TOOLTIP_WIDTH
    local innerW   = ttWidth - 2 * PADDING
    local curIdx   = GetCurrentDeviceIndex()
    local count    = GetDeviceCount()

    -- Hide stale rows
    for _, row in ipairs(f.deviceRows) do
        row:Hide()
    end

    local y = 0
    for i = 0, count - 1 do
        local name      = GetDeviceName(i)
        local isCurrent = (i == curIdx)

        -- Reuse or create row button
        local row = f.deviceRows[i + 1]
        if not row then
            row = CreateFrame("Button", nil, c)
            row:SetHeight(ROW_HEIGHT)
            row:EnableMouse(true)
            row:RegisterForClicks("LeftButtonUp")

            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.08)

            local sel = row:CreateTexture(nil, "BACKGROUND")
            sel:SetAllPoints()
            sel:SetColorTexture(0.3, 0.65, 1, 0.12)
            row._selBg = sel

            row._text = ns.FontString(row, "DDTFontNormal")
            row._text:SetPoint("TOPLEFT", 4, 0)
            row._text:SetPoint("BOTTOMRIGHT", -4, 0)
            row._text:SetJustifyH("LEFT")
            row._text:SetJustifyV("MIDDLE")

            row:SetScript("OnEnter", function() AudioOutput:CancelHideTimer() end)
            row:SetScript("OnLeave", function() AudioOutput:StartHideTimer() end)

            f.deviceRows[i + 1] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y)
        row:SetWidth(innerW)
        row:Show()

        -- Current device: highlighted text + background tint
        row._selBg:SetShown(isCurrent)
        if isCurrent then
            row._text:SetText("|cff4da6ff" .. name .. "|r")
        else
            row._text:SetText("|cffcccccc" .. name .. "|r")
        end

        -- Capture index for click handler
        local capturedIdx = i
        row:SetScript("OnClick", function()
            SwitchToDevice(capturedIdx)
            AudioOutput:UpdateLabel()
            -- Re-sync label and tooltip after sound system restart completes
            C_Timer.After(0.5, function()
                AudioOutput:UpdateLabel()
                if tooltipFrame and tooltipFrame:IsShown() then
                    AudioOutput:PopulateTooltip()
                end
            end)
        end)

        y = y - ROW_HEIGHT - 1
    end

    if count == 0 then
        -- No devices found
        local row = f.deviceRows[1]
        if not row then
            row = CreateFrame("Frame", nil, c)
            row._text = ns.FontString(row, "DDTFontNormal")
            row._text:SetAllPoints()
            row._text:SetJustifyH("LEFT")
            row._text:SetJustifyV("MIDDLE")
            f.deviceRows[1] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y)
        row:SetWidth(innerW)
        row:SetHeight(ROW_HEIGHT)
        row._text:SetText("|cffaaaaaa(No audio devices found)|r")
        row:Show()
        y = y - ROW_HEIGHT
        count = 1
    end

    local contentH = math.abs(y)
    c:SetWidth(innerW)
    c:SetHeight(contentH)

    f.hint:SetText(DDT:BuildHintText(db.clickActions or {}, CLICK_ACTIONS))
    f:FinalizeLayout(ttWidth, contentH)
end

function AudioOutput:ShowTooltip(anchor)
    self:CancelHideTimer()
    if not tooltipFrame then
        tooltipFrame = BuildTooltipFrame()
    end

    local db = self:GetDB()
    ns.AnchorTooltip(tooltipFrame, anchor, db.tooltipGrowDirection)
    tooltipFrame:SetScale(db.tooltipScale or 1.0)
    tooltipFrame.header:SetText("Audio Output")

    self:PopulateTooltip()
    tooltipFrame:Show()
end

---------------------------------------------------------------------------
-- Scroll / cycle helpers
---------------------------------------------------------------------------

function AudioOutput:CycleDevice(direction)
    local count = GetDeviceCount()
    if count < 2 then return end
    local cur  = GetCurrentDeviceIndex()
    local next = (cur + direction) % count
    SwitchToDevice(next)
    self:UpdateLabel()
    C_Timer.After(0.5, function()
        AudioOutput:UpdateLabel()
        if tooltipFrame and tooltipFrame:IsShown() then
            AudioOutput:PopulateTooltip()
        end
    end)
end

---------------------------------------------------------------------------
-- Hide timer
---------------------------------------------------------------------------

function AudioOutput:StartHideTimer()
    self:CancelHideTimer()
    hideTimer = C_Timer.NewTimer(ns.HIDE_DELAY, function()
        if tooltipFrame then tooltipFrame:Hide() end
        hideTimer = nil
    end)
end

function AudioOutput:CancelHideTimer()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
end

---------------------------------------------------------------------------
-- LDB Data Object
---------------------------------------------------------------------------

dataobj = LDB:NewDataObject("DDT-AudioOutput", {
    type  = "data source",
    text  = "Audio: --",
    icon  = "Interface\\Icons\\inv_misc_enggizmos_29",
    label = "DDT - Audio Output",
    OnEnter = function(self)
        AudioOutput:ShowTooltip(self)
    end,
    OnLeave = function(self)
        AudioOutput:StartHideTimer()
    end,
    OnClick = function(self, button)
        local db = AudioOutput:GetDB()
        local action = DDT:ResolveClickAction(button, db.clickActions or {})
        if action == "toggle" then
            if tooltipFrame and tooltipFrame:IsShown() then
                tooltipFrame:Hide()
            else
                AudioOutput:ShowTooltip(self)
            end
        elseif action == "cyclenext" then
            AudioOutput:CycleDevice(1)
        elseif action == "cycleprev" then
            AudioOutput:CycleDevice(-1)
        elseif action == "pintooltip" then
            ns:TogglePinTooltip(AudioOutput, tooltipFrame)
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
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("CVAR_UPDATE")
eventFrame:SetScript("OnEvent", function(_, event, cvarName)
    if event == "PLAYER_ENTERING_WORLD" then
        AudioOutput:UpdateLabel()
    elseif event == "CVAR_UPDATE" and cvarName == "Sound_OutputDriverIndex" then
        AudioOutput:UpdateLabel()
    end
end)

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function AudioOutput:Init()
    self:UpdateLabel()
end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------

AudioOutput.settingsLabel = "Audio Output"

function AudioOutput:BuildSettingsPanel(panel)
    local W = ns.SettingsWidgets
    local r = panel.refreshCallbacks
    local db = function() return ns.db.audiooutput end

    W.AddLabelEditBox(panel, "device index count",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateLabel() end, r)

    local body = W.AddSection(panel, "Display")
    local y = 0

    y = W.AddSlider(body, y, "Label Max Length", 8, 40, 1,
        function() return db().maxLabelLength end,
        function(v) db().maxLabelLength = v; self:UpdateLabel() end, r)

    y = W.AddSliderPair(body, y,
        { label = "Scale", min = 0.5, max = 2.0, step = 0.05,
          get = function() return db().tooltipScale end,
          set = function(v) db().tooltipScale = v end },
        { label = "Width", min = 250, max = 500, step = 10,
          get = function() return db().tooltipWidth end,
          set = function(v) db().tooltipWidth = v end }, r)

    y = W.AddTooltipGrowDirection(body, y, db, r)
    W.EndSection(panel, y)

    ns.AddModuleClickActionsSection(panel, r, "audiooutput", CLICK_ACTIONS)
end

---------------------------------------------------------------------------
-- Registration
---------------------------------------------------------------------------

ns:RegisterModule("audiooutput", AudioOutput, DEFAULTS)
