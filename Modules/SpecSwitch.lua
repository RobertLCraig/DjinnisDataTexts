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

-- State
local specCache = {}        -- { [index] = { id, name, icon, role } }
local loadoutCache = {}     -- { [specID] = { { configID, name } } }
local currentSpecIndex = 0
local currentSpecID = 0
local currentSpecName = ""
local currentSpecIcon = nil
local lootSpecID = 0        -- 0 = "Current Spec (Default)"
local activeLoadoutID = nil

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
        if button == "LeftButton" then
            if InCombatLockdown() then
                DDT:Print("Cannot open talents in combat.")
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
        end
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

function SpecSwitch:UpdateData()
    currentSpecIndex = GetSpecialization() or 0
    local numSpecs = GetNumSpecializations() or 0

    wipe(specCache)
    for i = 1, numSpecs do
        local id, name, _, icon, role = GetSpecializationInfo(i)
        if id then
            specCache[i] = { id = id, name = name, icon = icon, role = role }
        end
    end

    if currentSpecIndex > 0 and specCache[currentSpecIndex] then
        local spec = specCache[currentSpecIndex]
        currentSpecID = spec.id
        currentSpecName = spec.name
        currentSpecIcon = spec.icon
        dataobj.text = currentSpecName
        dataobj.icon = currentSpecIcon
    else
        currentSpecID = 0
        currentSpecName = "No Spec"
        currentSpecIcon = "Interface\\Icons\\INV_Misc_QuestionMark"
        dataobj.text = currentSpecName
        dataobj.icon = currentSpecIcon
    end

    -- Loot spec
    lootSpecID = GetLootSpecialization() or 0

    -- Loadouts (Mainline talent system)
    wipe(loadoutCache)
    if C_ClassTalents and PlayerUtil and PlayerUtil.CanUseClassTalents and PlayerUtil.CanUseClassTalents() then
        for i, spec in pairs(specCache) do
            local configIDs = C_ClassTalents.GetConfigIDsBySpecID(spec.id)
            if configIDs then
                loadoutCache[spec.id] = {}
                for _, configID in ipairs(configIDs) do
                    local configInfo = C_Traits and C_Traits.GetConfigInfo(configID)
                    if configInfo and configInfo.name then
                        table.insert(loadoutCache[spec.id], {
                            configID = configID,
                            name = configInfo.name,
                        })
                    end
                end
            end
        end
        -- Active loadout for current spec
        if currentSpecID > 0 and C_ClassTalents.GetLastSelectedSavedConfigID then
            activeLoadoutID = C_ClassTalents.GetLastSelectedSavedConfigID(currentSpecID)
        else
            activeLoadoutID = nil
        end
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
-- Role icons
---------------------------------------------------------------------------

local ROLE_ICONS = {
    TANK    = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:0:19:22:41|t",
    HEALER  = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:20:39:1:20|t",
    DAMAGER = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:20:39:22:41|t",
}

---------------------------------------------------------------------------
-- Tooltip content building
---------------------------------------------------------------------------

function SpecSwitch:BuildTooltipContent()
    HideAllPooled()

    local f = tooltipFrame
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

    for i, spec in ipairs(specCache) do
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

        local isActive = (i == currentSpecIndex)
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
            if InCombatLockdown() then
                DDT:Print("Cannot switch specs in combat.")
                return
            end
            if specIndex ~= currentSpecIndex then
                SetSpecialization(specIndex)
            end
        end)

        y = y - ROW_HEIGHT
    end

    -- ── Talent Loadouts ──────────────────────────────────────
    local currentLoadouts = currentSpecID > 0 and loadoutCache[currentSpecID]
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

        -- Check starter build
        local hasStarter = C_ClassTalents and C_ClassTalents.GetHasStarterBuild and C_ClassTalents.GetHasStarterBuild()
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

            local isActive = (not starterActive) and (loadout.configID == activeLoadoutID)
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
                if InCombatLockdown() then
                    DDT:Print("Cannot switch loadouts in combat.")
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

    if currentSpecIcon then
        defaultRow.icon:SetTexture(currentSpecIcon)
        defaultRow.icon:Show()
    else
        defaultRow.icon:Hide()
    end
    defaultRow.text:SetText("Current Spec (Default)")
    defaultRow.text:SetPoint("LEFT", defaultRow.icon, "RIGHT", 6, 0)

    local isDefaultLoot = (lootSpecID == 0)
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
        SetLootSpecialization(0)
    end)
    y = y - ROW_HEIGHT

    -- Per-spec loot options
    for i, spec in ipairs(specCache) do
        rowIndex = rowIndex + 1
        local row = GetRow(f, rowIndex)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        row:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)

        row.icon:SetTexture(spec.icon)
        row.icon:Show()
        row.text:SetText(spec.name)
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)

        local isLootActive = (lootSpecID == spec.id)
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
            SetLootSpecialization(specID)
        end)
        y = y - ROW_HEIGHT
    end

    -- Hint bar
    f.hint:SetText("|cff888888LClick: Open Talents|r")

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
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("specswitch", SpecSwitch)
