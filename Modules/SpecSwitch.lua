-- Djinni's Data Texts — Spec Switch
-- Talent specialization, loadout switching, and loot spec selection.
local addonName, ns = ...
local DDT = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local SpecSwitch = {}
ns.SpecSwitch = SpecSwitch

-- State (module fields — accessible by DemoMode)
SpecSwitch.specCache      = {}   -- { [index] = { id, name, icon, role } }
SpecSwitch.loadoutCache   = {}   -- { [specID] = { { configID, name } } }
SpecSwitch.currentSpecIndex = 0
SpecSwitch.currentSpecID    = 0
SpecSwitch.currentSpecName  = ""
SpecSwitch.currentSpecIcon  = nil
SpecSwitch.currentRole      = nil
SpecSwitch.lootSpecID       = 0  -- 0 = "Current Spec (Default)"
SpecSwitch.activeLoadoutID   = nil
SpecSwitch.activeLoadoutName = nil
SpecSwitch.lastConfigBySpec  = {}  -- { [specID] = configID } for all specs

-- Demo mode flag (set by DemoMode.lua)
SpecSwitch.demoMode = false

-- Tooltip
local tooltipFrame = nil
local hideTimer = nil
local rowPool = {}
local headerPool = {}
local separatorPool = {}

-- Layout constants
local TOOLTIP_WIDTH  = 280
local ROW_HEIGHT     = 22
local HEADER_HEIGHT  = 18
local PADDING        = 10
local ICON_SIZE      = 18
local HINT_HEIGHT    = 18

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
    labelTemplate = "<spec>",
    clickActions = {
        leftClick      = "opentalents",
        rightClick     = "none",
        shiftLeftClick = "nextspec",
        shiftRightClick = "none",
        ctrlLeftClick  = "none",
        ctrlRightClick = "none",
        altLeftClick   = "none",
        altRightClick  = "none",
    },
}

---------------------------------------------------------------------------
-- Action definitions
---------------------------------------------------------------------------

local SPEC_ACTION_VALUES = {
    opentalents  = "Open Talents",
    nextspec     = "Next Spec",
    nextloadout  = "Next Loadout",
    none         = "None",
}
ns.SPEC_ACTION_VALUES = SPEC_ACTION_VALUES

---------------------------------------------------------------------------
-- Click action resolver (supports shift / ctrl / alt modifiers)
---------------------------------------------------------------------------

local function ResolveSpecClick(button, clickActions)
    if IsAltKeyDown() then
        if button == "LeftButton" then return clickActions.altLeftClick end
        if button == "RightButton" then return clickActions.altRightClick end
    elseif IsControlKeyDown() then
        if button == "LeftButton" then return clickActions.ctrlLeftClick end
        if button == "RightButton" then return clickActions.ctrlRightClick end
    elseif IsShiftKeyDown() then
        if button == "LeftButton" then return clickActions.shiftLeftClick end
        if button == "RightButton" then return clickActions.shiftRightClick end
    else
        if button == "LeftButton" then return clickActions.leftClick end
        if button == "RightButton" then return clickActions.rightClick end
    end
end

---------------------------------------------------------------------------
-- Djinni-style combat message
---------------------------------------------------------------------------

local function DjinniMsg(msg)
    DDT:Print("|cff33ff99Djinni:|r " .. msg)
end

---------------------------------------------------------------------------
-- Spec switching helper
-- Uses C_SpecializationInfo.SetSpecialization (the working API in
-- Midnight) — matches ElvUI / EnhanceQoL implementations.
---------------------------------------------------------------------------

local function SwitchToSpec(specIndex)
    if InCombatLockdown() then
        DjinniMsg("Cannot change specialization in combat.")
        return
    end
    local spec = SpecSwitch.specCache[specIndex]
    if not spec then return end
    if specIndex == SpecSwitch.currentSpecIndex then return end

    C_SpecializationInfo.SetSpecialization(specIndex)
end

---------------------------------------------------------------------------
-- Action executor
---------------------------------------------------------------------------

local function ExecuteSpecAction(action)
    if not action or action == "none" then return end

    if action == "opentalents" then
        if InCombatLockdown() then
            DjinniMsg("Cannot open talents in combat.")
            return
        end
        if not PlayerSpellsFrame then
            PlayerSpellsFrame_LoadUI()
        end
        if PlayerSpellsFrame then
            if PlayerSpellsFrame:IsShown() then
                HideUIPanel(PlayerSpellsFrame)
            else
                ShowUIPanel(PlayerSpellsFrame)
            end
        end

    elseif action == "nextspec" then
        local numSpecs = #SpecSwitch.specCache
        if numSpecs == 0 then return end
        local nextIndex = (SpecSwitch.currentSpecIndex % numSpecs) + 1
        if SpecSwitch.demoMode then
            DemoSwitchSpec(nextIndex)
            return
        end
        SwitchToSpec(nextIndex)

    elseif action == "nextloadout" then
        local loadouts = SpecSwitch.currentSpecID > 0 and SpecSwitch.loadoutCache[SpecSwitch.currentSpecID]
        if not loadouts or #loadouts == 0 then return end
        -- Find current index and advance
        local curIdx = 0
        for i, lo in ipairs(loadouts) do
            if lo.configID == SpecSwitch.activeLoadoutID then
                curIdx = i
                break
            end
        end
        local nextIdx = (curIdx % #loadouts) + 1
        if SpecSwitch.demoMode then
            DemoSwitchLoadout(loadouts[nextIdx].configID)
            return
        end
        if InCombatLockdown() then
            DjinniMsg("Cannot change loadout in combat.")
            return
        end
        if C_ClassTalents.LoadConfig then
            C_ClassTalents.LoadConfig(loadouts[nextIdx].configID, true)
        end
    end
end

---------------------------------------------------------------------------
-- Label template expansion
---------------------------------------------------------------------------

local ROLE_ICONS = {
    TANK    = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:0:19:22:41|t",
    HEALER  = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:20:39:1:20|t",
    DAMAGER = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:20:39:22:41|t",
}

local function ExpandLabel(template)
    local result = template
    result = result:gsub("<spec>", SpecSwitch.currentSpecName or "")
    result = result:gsub("<loadout>", SpecSwitch.activeLoadoutName or "")

    -- Loot spec name
    local lootName = "Current Spec"
    if SpecSwitch.lootSpecID > 0 then
        for _, spec in ipairs(SpecSwitch.specCache) do
            if spec.id == SpecSwitch.lootSpecID then
                lootName = spec.name
                break
            end
        end
    end
    result = result:gsub("<lootspec>", lootName)
    result = result:gsub("<role>", ROLE_ICONS[SpecSwitch.currentRole] or "")
    return result
end

---------------------------------------------------------------------------
-- Demo mode simulation
---------------------------------------------------------------------------

local function DemoSwitchSpec(specIndex)
    local spec = SpecSwitch.specCache[specIndex]
    if not spec then return end
    SpecSwitch.currentSpecIndex = specIndex
    SpecSwitch.currentSpecID = spec.id
    SpecSwitch.currentSpecName = spec.name
    SpecSwitch.currentSpecIcon = spec.icon
    SpecSwitch.currentRole = spec.role
    -- Reset loadout to first available for the new spec
    local loadouts = SpecSwitch.loadoutCache[spec.id]
    if loadouts and #loadouts > 0 then
        SpecSwitch.activeLoadoutID = loadouts[1].configID
        SpecSwitch.activeLoadoutName = loadouts[1].name
    else
        SpecSwitch.activeLoadoutID = nil
        SpecSwitch.activeLoadoutName = nil
    end
    local db = SpecSwitch:GetDB()
    SpecSwitch.dataobj.text = ExpandLabel(db.labelTemplate)
    SpecSwitch.dataobj.icon = spec.icon
    DjinniMsg("(Demo) Switched to " .. spec.name)
    SpecSwitch:BuildTooltipContent()
end

local function DemoSwitchLoadout(configID)
    local loadouts = SpecSwitch.loadoutCache[SpecSwitch.currentSpecID]
    if not loadouts then return end
    for _, lo in ipairs(loadouts) do
        if lo.configID == configID then
            SpecSwitch.activeLoadoutID = configID
            SpecSwitch.activeLoadoutName = lo.name
            local db = SpecSwitch:GetDB()
            SpecSwitch.dataobj.text = ExpandLabel(db.labelTemplate)
            DjinniMsg("(Demo) Loaded " .. lo.name)
            SpecSwitch:BuildTooltipContent()
            return
        end
    end
end

local function DemoSetLootSpec(specID)
    SpecSwitch.lootSpecID = specID
    local name = "Current Spec"
    if specID > 0 then
        for _, spec in ipairs(SpecSwitch.specCache) do
            if spec.id == specID then name = spec.name; break end
        end
    end
    local db = SpecSwitch:GetDB()
    SpecSwitch.dataobj.text = ExpandLabel(db.labelTemplate)
    DjinniMsg("(Demo) Loot spec set to " .. name)
    SpecSwitch:BuildTooltipContent()
end

---------------------------------------------------------------------------
-- Hint bar builder
---------------------------------------------------------------------------

local function BuildSpecHintText(clickActions)
    local labels = {
        { key = "leftClick",       prefix = "LClick" },
        { key = "rightClick",      prefix = "RClick" },
        { key = "shiftLeftClick",  prefix = "Shift+L" },
        { key = "shiftRightClick", prefix = "Shift+R" },
        { key = "ctrlLeftClick",   prefix = "Ctrl+L" },
        { key = "ctrlRightClick",  prefix = "Ctrl+R" },
        { key = "altLeftClick",    prefix = "Alt+L" },
        { key = "altRightClick",   prefix = "Alt+R" },
    }
    local hints = {}
    for _, entry in ipairs(labels) do
        local action = clickActions[entry.key]
        if action and action ~= "none" then
            table.insert(hints, entry.prefix .. ": " .. (SPEC_ACTION_VALUES[action] or ""))
        end
    end
    if #hints == 0 then return "|cff888888Click a row to switch|r" end
    return "|cff888888" .. table.concat(hints, "  |  ") .. "|r"
end

---------------------------------------------------------------------------
-- LDB Data Object
---------------------------------------------------------------------------

local dataobj = LDB:NewDataObject("DDT-SpecSwitch", {
    type  = "data source",
    text  = "Specialization",
    icon  = "Interface\\Icons\\INV_Misc_QuestionMark",
    label = "Specialization",
    OnEnter = function(self)
        SpecSwitch:ShowTooltip(self)
    end,
    OnLeave = function(self)
        SpecSwitch:StartHideTimer()
    end,
    OnClick = function(self, button)
        local db = SpecSwitch:GetDB()
        local action = ResolveSpecClick(button, db.clickActions)
        ExecuteSpecAction(action)
    end,
})

SpecSwitch.dataobj = dataobj

---------------------------------------------------------------------------
-- Event handling
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

function SpecSwitch:Init()
    eventFrame:SetScript("OnEvent", function(_, event)
        SpecSwitch:UpdateData()
    end)
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
    eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    eventFrame:RegisterEvent("PLAYER_LOOT_SPEC_UPDATED")
    eventFrame:RegisterEvent("TRAIT_CONFIG_DELETED")
    eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
end

---------------------------------------------------------------------------
-- Data collection
---------------------------------------------------------------------------

function SpecSwitch:GetDB()
    return ns.db and ns.db.specswitch or DEFAULTS
end

function SpecSwitch:UpdateData()
    self.currentSpecIndex = GetSpecialization() or 0
    local numSpecs = GetNumSpecializations() or 0

    wipe(self.specCache)
    for i = 1, numSpecs do
        local id, name, _, icon, role = GetSpecializationInfo(i)
        if id then
            self.specCache[i] = { id = id, name = name, icon = icon, role = role }
        end
    end

    if self.currentSpecIndex > 0 and self.specCache[self.currentSpecIndex] then
        local spec = self.specCache[self.currentSpecIndex]
        self.currentSpecID = spec.id
        self.currentSpecName = spec.name
        self.currentSpecIcon = spec.icon
        self.currentRole = spec.role
    else
        self.currentSpecID = 0
        self.currentSpecName = "No Spec"
        self.currentSpecIcon = "Interface\\Icons\\INV_Misc_QuestionMark"
        self.currentRole = nil
    end

    -- Loot spec
    self.lootSpecID = GetLootSpecialization() or 0

    -- Loadouts (Mainline talent system)
    wipe(self.loadoutCache)
    self.activeLoadoutID = nil
    self.activeLoadoutName = nil

    if C_ClassTalents and PlayerUtil and PlayerUtil.CanUseClassTalents and PlayerUtil.CanUseClassTalents() then
        for i, spec in pairs(self.specCache) do
            local configIDs = C_ClassTalents.GetConfigIDsBySpecID(spec.id)
            if configIDs then
                self.loadoutCache[spec.id] = {}
                for _, configID in ipairs(configIDs) do
                    local configInfo = C_Traits and C_Traits.GetConfigInfo(configID)
                    if configInfo and configInfo.name then
                        table.insert(self.loadoutCache[spec.id], {
                            configID = configID,
                            name = configInfo.name,
                        })
                    end
                end
            end
        end
        -- Last-selected config for ALL specs (used for spec switching via LoadConfig)
        wipe(self.lastConfigBySpec)
        if C_ClassTalents.GetLastSelectedSavedConfigID then
            for _, spec in ipairs(self.specCache) do
                local lastConfig = C_ClassTalents.GetLastSelectedSavedConfigID(spec.id)
                if lastConfig then
                    self.lastConfigBySpec[spec.id] = lastConfig
                elseif self.loadoutCache[spec.id] and #self.loadoutCache[spec.id] > 0 then
                    -- Fallback: use first available loadout
                    self.lastConfigBySpec[spec.id] = self.loadoutCache[spec.id][1].configID
                end
            end
        end

        -- Active loadout for current spec
        if self.currentSpecID > 0 and C_ClassTalents.GetLastSelectedSavedConfigID then
            self.activeLoadoutID = self.lastConfigBySpec[self.currentSpecID]
            -- Resolve name
            if self.activeLoadoutID and self.loadoutCache[self.currentSpecID] then
                for _, lo in ipairs(self.loadoutCache[self.currentSpecID]) do
                    if lo.configID == self.activeLoadoutID then
                        self.activeLoadoutName = lo.name
                        break
                    end
                end
            end
        end
    end

    -- Update LDB text from label template
    local db = self:GetDB()
    dataobj.text = ExpandLabel(db.labelTemplate)
    dataobj.icon = self.currentSpecIcon

    -- Refresh tooltip if visible
    if tooltipFrame and tooltipFrame:IsShown() then
        self:BuildTooltipContent()
    end
end

---------------------------------------------------------------------------
-- Tooltip frame creation
---------------------------------------------------------------------------

local function CreateTooltipFrame()
    local f = CreateFrame("Frame", "DDTSpecSwitchTooltip", UIParent, "BackdropTemplate")
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

    -- Mouse interaction: keep tooltip visible when mousing over it
    f:EnableMouse(true)
    f:SetScript("OnEnter", function() SpecSwitch:CancelHideTimer() end)
    f:SetScript("OnLeave", function() SpecSwitch:StartHideTimer() end)

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
    row.highlight:SetColorTexture(1, 1, 1, 0.08)

    -- Icon
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Text
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.text:SetJustifyH("LEFT")

    -- Status text (right side)
    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.status:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.status:SetJustifyH("RIGHT")

    -- Active indicator
    row.activeBar = row:CreateTexture(nil, "BACKGROUND")
    row.activeBar:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.activeBar:SetSize(3, ROW_HEIGHT - 4)
    row.activeBar:SetColorTexture(0.2, 0.8, 0.2, 0.8)

    row:SetScript("OnEnter", function(self)
        SpecSwitch:CancelHideTimer()
    end)
    row:SetScript("OnLeave", function(self)
        SpecSwitch:StartHideTimer()
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

function SpecSwitch:BuildTooltipContent()
    HideAllPooled()

    local f = tooltipFrame
    local db = self:GetDB()
    f.title:SetText("Specialization")

    local rowIndex = 0
    local headerIndex = 0
    local sepIndex = 0
    local y = -PADDING - 20 - 6 -- below title + separator

    -- ── Specializations ──────────────────────────────────────
    headerIndex = headerIndex + 1
    local specHdr = GetHeader(f, headerIndex)
    specHdr:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    specHdr:SetText("Specializations")
    y = y - HEADER_HEIGHT

    for i, spec in ipairs(self.specCache) do
        rowIndex = rowIndex + 1
        local row = GetRow(f, rowIndex)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        row:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)

        row.icon:SetTexture(spec.icon)
        row.icon:Show()

        local roleIcon = ROLE_ICONS[spec.role] or ""
        local nameText = roleIcon .. " " .. spec.name
        row.text:SetText(nameText)
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)

        local isActive = (i == self.currentSpecIndex)
        if isActive then
            row.status:SetText("|cff00cc00Active|r")
            row.activeBar:Show()
            row.text:SetTextColor(1, 1, 1)
        else
            row.status:SetText("")
            row.activeBar:Hide()
            row.text:SetTextColor(0.7, 0.7, 0.7)
        end

        local specIndex = i
        row:SetScript("OnClick", function()
            if self.demoMode then
                DemoSwitchSpec(specIndex)
                return
            end
            SwitchToSpec(specIndex)
        end)

        y = y - ROW_HEIGHT
    end

    -- ── Talent Loadouts ──────────────────────────────────────
    local currentLoadouts = self.currentSpecID > 0 and self.loadoutCache[self.currentSpecID]
    if currentLoadouts and #currentLoadouts > 0 then
        y = y - 4

        sepIndex = sepIndex + 1
        local sep = GetSeparator(f, sepIndex)
        sep:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        sep:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)
        y = y - 6

        headerIndex = headerIndex + 1
        local loadHdr = GetHeader(f, headerIndex)
        loadHdr:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        loadHdr:SetText("Talent Loadouts")
        y = y - HEADER_HEIGHT

        -- Check starter build (skip in demo mode)
        local hasStarter = (not self.demoMode) and C_ClassTalents and C_ClassTalents.GetHasStarterBuild and C_ClassTalents.GetHasStarterBuild()
        local starterActive = hasStarter and C_ClassTalents.GetStarterBuildActive and C_ClassTalents.GetStarterBuildActive()

        if hasStarter then
            rowIndex = rowIndex + 1
            local row = GetRow(f, rowIndex)
            row:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
            row:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)

            row.icon:Hide()
            row.text:SetText("  Starter Build")
            row.text:SetPoint("LEFT", row, "LEFT", ICON_SIZE + 10, 0)

            if starterActive then
                row.status:SetText("|cff00cc00Active|r")
                row.activeBar:Show()
                row.text:SetTextColor(1, 1, 1)
            else
                row.status:SetText("")
                row.activeBar:Hide()
                row.text:SetTextColor(0.7, 0.7, 0.7)
            end

            row:SetScript("OnClick", nil) -- starter can't be loaded via API
            y = y - ROW_HEIGHT
        end

        for _, loadout in ipairs(currentLoadouts) do
            rowIndex = rowIndex + 1
            local row = GetRow(f, rowIndex)
            row:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
            row:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)

            row.icon:Hide()
            row.text:SetText("  " .. loadout.name)
            row.text:SetPoint("LEFT", row, "LEFT", ICON_SIZE + 10, 0)

            local isActive = (not starterActive) and (loadout.configID == self.activeLoadoutID)
            if isActive then
                row.status:SetText("|cff00cc00Active|r")
                row.activeBar:Show()
                row.text:SetTextColor(1, 1, 1)
            else
                row.status:SetText("")
                row.activeBar:Hide()
                row.text:SetTextColor(0.7, 0.7, 0.7)
            end

            local configID = loadout.configID
            row:SetScript("OnClick", function()
                if self.demoMode then
                    DemoSwitchLoadout(configID)
                    return
                end
                if InCombatLockdown() then
                    DjinniMsg("Cannot change loadout in combat.")
                    return
                end
                if C_ClassTalents.LoadConfig then
                    C_ClassTalents.LoadConfig(configID, true)
                end
            end)

            y = y - ROW_HEIGHT
        end
    end

    -- ── Loot Specialization ──────────────────────────────────
    y = y - 4

    sepIndex = sepIndex + 1
    local sep2 = GetSeparator(f, sepIndex)
    sep2:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    sep2:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)
    y = y - 6

    headerIndex = headerIndex + 1
    local lootHdr = GetHeader(f, headerIndex)
    lootHdr:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    lootHdr:SetText("Loot Specialization")
    y = y - HEADER_HEIGHT

    -- "Current Spec" option
    rowIndex = rowIndex + 1
    local defaultRow = GetRow(f, rowIndex)
    defaultRow:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    defaultRow:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)

    if self.currentSpecIcon then
        defaultRow.icon:SetTexture(self.currentSpecIcon)
        defaultRow.icon:Show()
    else
        defaultRow.icon:Hide()
    end
    defaultRow.text:SetText("Current Spec (Default)")
    defaultRow.text:SetPoint("LEFT", defaultRow.icon, "RIGHT", 6, 0)

    local isDefaultLoot = (self.lootSpecID == 0)
    if isDefaultLoot then
        defaultRow.status:SetText("|cff00cc00Active|r")
        defaultRow.activeBar:Show()
        defaultRow.text:SetTextColor(1, 1, 1)
    else
        defaultRow.status:SetText("")
        defaultRow.activeBar:Hide()
        defaultRow.text:SetTextColor(0.7, 0.7, 0.7)
    end
    defaultRow:SetScript("OnClick", function()
        if self.demoMode then
            DemoSetLootSpec(0)
            return
        end
        SetLootSpecialization(0)
    end)
    y = y - ROW_HEIGHT

    -- Per-spec loot options
    for i, spec in ipairs(self.specCache) do
        rowIndex = rowIndex + 1
        local row = GetRow(f, rowIndex)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        row:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)

        row.icon:SetTexture(spec.icon)
        row.icon:Show()
        row.text:SetText(spec.name)
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)

        local isLootActive = (self.lootSpecID == spec.id)
        if isLootActive then
            row.status:SetText("|cff00cc00Active|r")
            row.activeBar:Show()
            row.text:SetTextColor(1, 1, 1)
        else
            row.status:SetText("")
            row.activeBar:Hide()
            row.text:SetTextColor(0.7, 0.7, 0.7)
        end

        local specID = spec.id
        row:SetScript("OnClick", function()
            if self.demoMode then
                DemoSetLootSpec(specID)
                return
            end
            SetLootSpecialization(specID)
        end)
        y = y - ROW_HEIGHT
    end

    -- Hint bar
    f.hint:SetText(BuildSpecHintText(db.clickActions))

    -- Size the frame
    local totalHeight = math.abs(y) + PADDING + HINT_HEIGHT + 4
    f:SetSize(TOOLTIP_WIDTH, totalHeight)
end

---------------------------------------------------------------------------
-- Tooltip show/hide
---------------------------------------------------------------------------

function SpecSwitch:ShowTooltip(anchor)
    self:CancelHideTimer()

    if not tooltipFrame then
        tooltipFrame = CreateTooltipFrame()
    end

    -- Anchor
    tooltipFrame:ClearAllPoints()
    tooltipFrame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)

    -- Build content
    self:UpdateData()
    self:BuildTooltipContent()

    tooltipFrame:Show()
end

function SpecSwitch:StartHideTimer()
    self:CancelHideTimer()
    hideTimer = C_Timer.NewTimer(ns.HIDE_DELAY, function()
        if tooltipFrame then tooltipFrame:Hide() end
        hideTimer = nil
    end)
end

function SpecSwitch:CancelHideTimer()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
end

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------

local SPEC_CLICK_KEYS = {
    { key = "leftClick",       label = "Left Click" },
    { key = "rightClick",      label = "Right Click" },
    { key = "shiftLeftClick",  label = "Shift + Left Click" },
    { key = "shiftRightClick", label = "Shift + Right Click" },
    { key = "ctrlLeftClick",   label = "Ctrl + Left Click" },
    { key = "ctrlRightClick",  label = "Ctrl + Right Click" },
    { key = "altLeftClick",    label = "Alt + Left Click" },
    { key = "altRightClick",   label = "Alt + Right Click" },
}

SpecSwitch.settingsLabel = "Spec Switch"

function SpecSwitch:BuildSettingsPanel(panel)
    local W = ns.SettingsWidgets
    local c = panel.content
    local r = panel.refreshCallbacks
    local y = -10
    local db = function() return ns.db.specswitch end

    y = W.AddHeader(c, y, "Label Template")
    y = W.AddDescription(c, y, "Tags: <spec> <loadout> <lootspec> <role>")
    y = W.AddEditBox(c, y, "Template",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateData() end, r)

    y = W.AddHeader(c, y, "DataText Click Actions")
    y = W.AddDescription(c, y, "Configure what happens when you click the DataText label.")
    for _, entry in ipairs(SPEC_CLICK_KEYS) do
        y = W.AddDropdown(c, y, entry.label, SPEC_ACTION_VALUES,
            function() return db().clickActions[entry.key] end,
            function(v) db().clickActions[entry.key] = v end, r)
    end
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("specswitch", SpecSwitch, DEFAULTS)
