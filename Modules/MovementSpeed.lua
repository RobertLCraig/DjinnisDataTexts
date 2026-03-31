-- Djinni's Data Texts — Movement Speed
-- Current/base movement speed as percentage, swim/fly/glide detection,
-- speed-affecting buffs and consumables.
local addonName, ns = ...
local DDT = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local MoveSpeed = {}
ns.MoveSpeed = MoveSpeed

-- Tooltip
local tooltipFrame = nil
local hideTimer = nil

-- Layout
local TOOLTIP_WIDTH  = 320
local ROW_HEIGHT     = 20
local HEADER_HEIGHT  = 18
local PADDING        = 10
local HINT_HEIGHT    = 18

-- State
local BASE_SPEED = 7  -- yards/sec (Blizzard constant from PaperDollFrame)
local currentSpeed = 0    -- yd/s actual
local runSpeed = 0        -- yd/s max ground
local flightSpeed = 0     -- yd/s max flying
local swimSpeed = 0       -- yd/s max swimming
local currentPercent = 0
local runPercent = 0
local flyPercent = 0
local swimPercent = 0
local isFlying = false
local isSwimming = false
local isGliding = false
local glideSpeed = 0
local activeBuffs = {}  -- { { name, icon, speedEffect } }

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
    labelTemplate     = "<speed>%",
    updateInterval    = 0.2,   -- seconds (0.05 = high, 0.5 = low)
    showSpeedBuffs    = true,
    tooltipScale      = 1.0,
    tooltipWidth      = 320,
    clickActions      = {
        leftClick       = "character",
        rightClick      = "none",
        middleClick     = "none",
        shiftLeftClick  = "shopenchants",
        shiftRightClick = "none",
        ctrlLeftClick   = "none",
        ctrlRightClick  = "none",
        altLeftClick    = "opensettings",
        altRightClick   = "none",
    },
}

-- Click actions for MovementSpeed
local CLICK_ACTIONS = {
    character     = "Character Panel",
    shopenchants  = "Shop: Speed Enchants",
    shopfood      = "Shop: Speed Food",
    shoppotions   = "Shop: Speed Potions",
    shopgear      = "Shop: Speed Gear",
    opensettings  = "Open DDT Settings",
    none          = "None",
}

-- Auctionator shopping lists and TSM search strings for Midnight speed consumables
local SHOPPING_DATA = {
    shopenchants = {
        label = "Speed Enchants",
        auctionator = {
            "Enchant Boots - Defender's March",
            "Enchant Cloak - Graceful Avoidance",
        },
        tsm = "Enchant Boots - Defender's March/exact;Enchant Cloak - Graceful Avoidance/exact",
    },
    shopfood = {
        label = "Speed Food",
        auctionator = {
            "Feast of the Midnight Masquerade",
            "Hallowfall Chili",
            "Everything Stew",
            "Salty Dog",
        },
        tsm = "Feast of the Midnight Masquerade/exact;Hallowfall Chili/exact;Everything Stew/exact;Salty Dog/exact",
    },
    shoppotions = {
        label = "Speed Potions",
        auctionator = {
            "Potion of Shocking Disclosure",
            "Skystep Potion",
            "Goblin Glider Kit",
        },
        tsm = "Potion of Shocking Disclosure/exact;Skystep Potion/exact;Goblin Glider Kit/exact",
    },
    shopgear = {
        label = "Speed Gear",
        auctionator = {
            "Gunshoes",
        },
        tsm = "Gunshoes/exact",
    },
}

---------------------------------------------------------------------------
-- Known speed-affecting spells / items
---------------------------------------------------------------------------

-- { spellID, name (display fallback), category }
-- Categories: mount, enchant, consumable, class, passive, item
local SPEED_BUFF_SPELLS = {
    -- Consumables
    { id = 2379,   name = "Speed",                 cat = "consumable" },  -- Swiftness Potion
    { id = 53908,  name = "Speed",                 cat = "consumable" },  -- Potion of Speed
    { id = 188024, name = "Skystep Potion",        cat = "consumable" },
    { id = 371028, name = "Potion of Shocking Disclosure", cat = "consumable" },
    { id = 172347, name = "Goblin Glider",         cat = "consumable" },
    -- Enchants / Items
    { id = 425124, name = "Enchant Boots - Defender's March", cat = "enchant" },
    { id = 423336, name = "Enchant Cloak - Graceful Avoidance", cat = "enchant" },
    { id = 136,    name = "Mithril Spurs",         cat = "enchant" },
    { id = 246236, name = "Gunshoes",              cat = "item" },
    { id = 68645,  name = "Rocket Boots",          cat = "item" },
    -- Class abilities
    { id = 2983,   name = "Sprint",                cat = "class" },       -- Rogue
    { id = 116841, name = "Tiger's Lust",          cat = "class" },       -- Monk
    { id = 1850,   name = "Dash",                  cat = "class" },       -- Druid
    { id = 231390, name = "Trailblazer",           cat = "class" },       -- Hunter
    { id = 186257, name = "Aspect of the Cheetah", cat = "class" },       -- Hunter
    { id = 65081,  name = "Body and Soul",         cat = "class" },       -- Priest
    { id = 111400, name = "Burning Rush",          cat = "class" },       -- Warlock
    { id = 2825,   name = "Bloodlust",             cat = "class" },       -- Shaman
    { id = 32182,  name = "Heroism",               cat = "class" },       -- Shaman
    -- Food
    { id = 431361, name = "Well Fed",              cat = "food" },
    { id = 104284, name = "Well Fed",              cat = "food" },
    -- Passives / talents
    { id = 196055, name = "Blessing of the Wind",  cat = "passive" },
    { id = 118922, name = "Posthaste",             cat = "class" },       -- Hunter
}

local SPEED_SPELL_SET = {}
for _, entry in ipairs(SPEED_BUFF_SPELLS) do
    SPEED_SPELL_SET[entry.id] = entry
end

local CATEGORY_COLORS = {
    consumable = { 0.0, 0.8, 0.0 },
    enchant    = { 0.0, 0.8, 1.0 },
    item       = { 0.64, 0.21, 0.93 },
    class      = { 1.0, 0.82, 0.0 },
    food       = { 1.0, 0.5, 0.2 },
    passive    = { 0.5, 0.5, 0.5 },
    mount      = { 0.4, 0.78, 1.0 },
}

local CATEGORY_LABELS = {
    consumable = "Consumable",
    enchant    = "Enchant",
    item       = "Item",
    class      = "Class Ability",
    food       = "Food Buff",
    passive    = "Passive",
    mount      = "Mount",
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function FormatSpeed(percent)
    return string.format("%.0f%%", percent)
end

local function ScanSpeedBuffs()
    wipe(activeBuffs)
    for i = 1, 40 do
        local name, _, icon, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
        if not name then break end
        local entry = SPEED_SPELL_SET[spellId]
        if entry then
            table.insert(activeBuffs, {
                name = name,
                icon = icon,
                cat = entry.cat,
                spellId = spellId,
            })
        end
    end
end

---------------------------------------------------------------------------
-- Label template expansion
---------------------------------------------------------------------------

local function ExpandLabel(template)
    local result = template
    local E = ns.ExpandTag
    result = E(result, "speed", string.format("%.0f", currentPercent))
    result = E(result, "run", string.format("%.0f", runPercent))
    result = E(result, "fly", string.format("%.0f", flyPercent))
    result = E(result, "swim", string.format("%.0f", swimPercent))
    -- Movement mode indicator
    local mode = "Run"
    if isGliding then mode = "Glide"
    elseif isFlying then mode = "Fly"
    elseif isSwimming then mode = "Swim" end
    result = E(result, "mode", mode)
    return result
end

---------------------------------------------------------------------------
-- LDB Data Object
---------------------------------------------------------------------------

local dataobj = LDB:NewDataObject("DDT-MovementSpeed", {
    type  = "data source",
    text  = "0%",
    icon  = "Interface\\Icons\\Ability_Rogue_Sprint",
    label = "DDT - Speed",
    OnEnter = function(self)
        MoveSpeed:ShowTooltip(self)
    end,
    OnLeave = function(self)
        MoveSpeed:StartHideTimer()
    end,
    OnClick = function(self, button)
        local db = MoveSpeed:GetDB()
        local action = DDT:ResolveClickAction(button, db.clickActions or {})
        if action == "character" then
            ToggleCharacter("PaperDollFrame")
        elseif action == "opensettings" then
            if DDT.settingsCategoryID then
                Settings.OpenToCategory(DDT.settingsCategoryID)
            end
        elseif SHOPPING_DATA[action] then
            MoveSpeed:OpenShoppingSearch(action)
        end
    end,
})

MoveSpeed.dataobj = dataobj

---------------------------------------------------------------------------
-- Event handling and update
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local elapsed = 0

function MoveSpeed:Init()
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:SetScript("OnEvent", function(_, event, unit)
        if event == "UNIT_AURA" and unit ~= "player" then return end
        ScanSpeedBuffs()
        MoveSpeed:UpdateData()
    end)

    -- OnUpdate only polls speed values (cheap). Buff scanning is event-driven via UNIT_AURA.
    eventFrame:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        local db = MoveSpeed:GetDB()
        local interval = db.updateInterval or 0.2
        if elapsed >= interval then
            elapsed = 0
            MoveSpeed:UpdateSpeed()
        end
    end)
end

function MoveSpeed:GetDB()
    return ns.db and ns.db.movementspeed or DEFAULTS
end

---------------------------------------------------------------------------
-- Data collection
---------------------------------------------------------------------------

-- Lightweight speed-only poll for OnUpdate (no buff scan)
function MoveSpeed:UpdateSpeed()
    local prevPercent = currentPercent
    currentSpeed, runSpeed, flightSpeed, swimSpeed = GetUnitSpeed("player")

    isFlying = IsFlying() or false
    isSwimming = IsSwimming() or false
    isGliding = false
    glideSpeed = 0

    if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
        local gliding, _, fwdSpeed = C_PlayerInfo.GetGlidingInfo()
        if gliding then
            isGliding = true
            glideSpeed = fwdSpeed or 0
        end
    end

    runPercent = runSpeed / BASE_SPEED * 100
    flyPercent = flightSpeed / BASE_SPEED * 100
    swimPercent = swimSpeed / BASE_SPEED * 100

    if isGliding and glideSpeed > 0 then
        currentPercent = glideSpeed / BASE_SPEED * 100
    elseif currentSpeed > 0 then
        currentPercent = currentSpeed / BASE_SPEED * 100
    elseif isFlying then
        currentPercent = flyPercent
    elseif isSwimming then
        currentPercent = swimPercent
    else
        currentPercent = runPercent
    end

    -- Only update label/tooltip if speed actually changed
    if math.abs(currentPercent - prevPercent) < 0.5 then return end

    local db = self:GetDB()
    dataobj.text = ExpandLabel(db.labelTemplate)

    if tooltipFrame and tooltipFrame:IsShown() then
        self:BuildTooltipContent()
    end
end

function MoveSpeed:UpdateData()
    currentSpeed, runSpeed, flightSpeed, swimSpeed = GetUnitSpeed("player")

    isFlying = IsFlying() or false
    isSwimming = IsSwimming() or false
    isGliding = false
    glideSpeed = 0

    if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
        local gliding, _, fwdSpeed = C_PlayerInfo.GetGlidingInfo()
        if gliding then
            isGliding = true
            glideSpeed = fwdSpeed or 0
        end
    end

    -- Calculate percentages
    runPercent = runSpeed / BASE_SPEED * 100
    flyPercent = flightSpeed / BASE_SPEED * 100
    swimPercent = swimSpeed / BASE_SPEED * 100

    if isGliding and glideSpeed > 0 then
        currentPercent = glideSpeed / BASE_SPEED * 100
    elseif currentSpeed > 0 then
        currentPercent = currentSpeed / BASE_SPEED * 100
    elseif isFlying then
        currentPercent = flyPercent
    elseif isSwimming then
        currentPercent = swimPercent
    else
        currentPercent = runPercent
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
-- Shopping search (Auctionator / TSM)
---------------------------------------------------------------------------

function MoveSpeed:OpenShoppingSearch(actionKey)
    local data = SHOPPING_DATA[actionKey]
    if not data then return end

    -- Try Auctionator first
    if Auctionator and Auctionator.API and Auctionator.API.v1 then
        local listName = "DDT Speed: " .. data.label
        pcall(function()
            Auctionator.API.v1.CreateShoppingList("DjinnisDataTexts", listName, data.auctionator)
        end)
        DDT:Print("Created Auctionator list: " .. listName)
        return
    end

    -- Try TSM
    if TSM_API then
        -- Copy TSM search string to chat for manual paste
        if ChatFrameUtil then
            ChatFrameUtil.OpenChat(data.tsm)
            DDT:Print("TSM search string copied to chat input. Paste into TSM search.")
        end
        return
    end

    DDT:Print("No supported auction addon found (Auctionator or TSM required).")
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------

local function CreateTooltipFrame()
    local f = CreateFrame("Frame", "DDTMoveSpeedTooltip", UIParent, "BackdropTemplate")
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

    f.title = f:CreateFontString(nil, "OVERLAY", "DDTFontHeader")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, -PADDING)
    f.title:SetTextColor(1, 0.82, 0)

    f.titleSep = f:CreateTexture(nil, "ARTWORK")
    f.titleSep:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
    f.titleSep:SetPoint("RIGHT", f, "RIGHT", -PADDING, 0)
    f.titleSep:SetHeight(1)
    f.titleSep:SetColorTexture(0.5, 0.5, 0.5, 0.5)

    f.hint = f:CreateFontString(nil, "OVERLAY", "DDTFontSmall")
    f.hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PADDING, 8)
    f.hint:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PADDING, 8)
    f.hint:SetJustifyH("CENTER")
    f.hint:SetTextColor(0.53, 0.53, 0.53)

    f:EnableMouse(true)
    f:SetScript("OnEnter", function() MoveSpeed:CancelHideTimer() end)
    f:SetScript("OnLeave", function() MoveSpeed:StartHideTimer() end)

    f.lines = {}
    return f
end

local function GetLine(f, index)
    if f.lines[index] then
        f.lines[index].label:Show()
        f.lines[index].value:Show()
        return f.lines[index]
    end

    local label = f:CreateFontString(nil, "OVERLAY", "DDTFontNormal")
    label:SetJustifyH("LEFT")

    local value = f:CreateFontString(nil, "OVERLAY", "DDTFontNormal")
    value:SetJustifyH("RIGHT")

    f.lines[index] = { label = label, value = value }
    return f.lines[index]
end

local function HideLines(f)
    for _, line in pairs(f.lines) do
        line.label:Hide()
        line.value:Hide()
    end
end

function MoveSpeed:BuildTooltipContent()
    local f = tooltipFrame
    HideLines(f)

    local db = self:GetDB()

    f.title:SetText("Movement Speed")

    local y = -PADDING - 20 - 6
    local lineIdx = 0

    -- Current speed
    lineIdx = lineIdx + 1
    local curLine = GetLine(f, lineIdx)
    curLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    local modeText = "Current"
    if isGliding then modeText = "Current (Skyriding)"
    elseif isFlying then modeText = "Current (Flying)"
    elseif isSwimming then modeText = "Current (Swimming)" end
    curLine.label:SetText("|cffffffff" .. modeText .. "|r")
    curLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    curLine.value:SetText(string.format("%.0f%%  (%.1f yd/s)", currentPercent, currentSpeed))
    curLine.value:SetTextColor(0.4, 0.78, 1)
    y = y - ROW_HEIGHT

    y = y - 4

    -- Ground run speed
    lineIdx = lineIdx + 1
    local runLine = GetLine(f, lineIdx)
    runLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    runLine.label:SetText("|cffffffffGround|r")
    runLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    runLine.value:SetText(FormatSpeed(runPercent))
    runLine.value:SetTextColor(0.9, 0.9, 0.9)
    y = y - ROW_HEIGHT

    -- Flying speed
    if flyPercent > 0 then
        lineIdx = lineIdx + 1
        local flyLine = GetLine(f, lineIdx)
        flyLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        flyLine.label:SetText("|cffffffffFlying|r")
        flyLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        flyLine.value:SetText(FormatSpeed(flyPercent))
        flyLine.value:SetTextColor(0.9, 0.9, 0.9)
        y = y - ROW_HEIGHT
    end

    -- Swimming speed
    lineIdx = lineIdx + 1
    local swimLine = GetLine(f, lineIdx)
    swimLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
    swimLine.label:SetText("|cffffffffSwimming|r")
    swimLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
    swimLine.value:SetText(FormatSpeed(swimPercent))
    swimLine.value:SetTextColor(0.9, 0.9, 0.9)
    y = y - ROW_HEIGHT

    -- Gliding speed (if currently skyriding)
    if isGliding and glideSpeed > 0 then
        lineIdx = lineIdx + 1
        local glideLine = GetLine(f, lineIdx)
        glideLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        glideLine.label:SetText("|cffffffffSkyriding|r")
        glideLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        glideLine.value:SetText(string.format("%.0f%%  (%.1f yd/s)", glideSpeed / BASE_SPEED * 100, glideSpeed))
        glideLine.value:SetTextColor(0.0, 1.0, 0.5)
        y = y - ROW_HEIGHT
    end

    -- Active speed buffs
    if db.showSpeedBuffs then
        ScanSpeedBuffs()
        if #activeBuffs > 0 then
            y = y - 4

            lineIdx = lineIdx + 1
            local buffHdr = GetLine(f, lineIdx)
            buffHdr.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
            buffHdr.label:SetText("|cffffd100Active Speed Effects|r")
            buffHdr.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
            buffHdr.value:SetText("")
            y = y - HEADER_HEIGHT

            for _, buff in ipairs(activeBuffs) do
                lineIdx = lineIdx + 1
                local row = GetLine(f, lineIdx)
                row.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 6, y)

                local iconStr = ""
                if buff.icon then
                    iconStr = "|T" .. buff.icon .. ":14:14:0:0|t "
                end
                row.label:SetText(iconStr .. buff.name)
                local cc = CATEGORY_COLORS[buff.cat] or { 0.8, 0.8, 0.8 }
                row.label:SetTextColor(unpack(cc))

                row.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
                row.value:SetText(CATEGORY_LABELS[buff.cat] or "")
                row.value:SetTextColor(0.5, 0.5, 0.5)
                y = y - ROW_HEIGHT
            end
        else
            y = y - 4
            lineIdx = lineIdx + 1
            local noBuff = GetLine(f, lineIdx)
            noBuff.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
            noBuff.label:SetText("|cff888888No speed effects active|r")
            noBuff.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
            noBuff.value:SetText("")
            y = y - ROW_HEIGHT
        end

        -- Speed source reference
        y = y - 4
        lineIdx = lineIdx + 1
        local refHdr = GetLine(f, lineIdx)
        refHdr.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        refHdr.label:SetText("|cffffd100Common Speed Sources|r")
        refHdr.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        refHdr.value:SetText("")
        y = y - HEADER_HEIGHT

        local sources = {
            { "|cff00cc00Consumables|r", "Skystep Potion, Speed potions" },
            { "|cff00ccffEnchants|r",    "Defender's March (boots), Mithril Spurs" },
            { "|cffa335eeItems|r",       "Gunshoes, Rocket Boots, Nitro Boosts" },
            { "|cffff8033Food|r",        "Well Fed buffs (varies by recipe)" },
            { "|cffffd100Class|r",       "Sprint, Dash, Tiger's Lust, Burning Rush" },
        }
        for _, src in ipairs(sources) do
            lineIdx = lineIdx + 1
            local srcRow = GetLine(f, lineIdx)
            srcRow.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 6, y)
            srcRow.label:SetText(src[1])
            srcRow.label:SetTextColor(1, 1, 1)
            srcRow.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
            srcRow.value:SetText(src[2])
            srcRow.value:SetTextColor(0.6, 0.6, 0.6)
            y = y - ROW_HEIGHT
        end
    end

    -- Hint
    f.hint:SetText(DDT:BuildHintText(db.clickActions or {}, CLICK_ACTIONS))

    local ttWidth = db.tooltipWidth or TOOLTIP_WIDTH
    local totalHeight = math.abs(y) + PADDING + HINT_HEIGHT + 8
    f:SetSize(ttWidth, totalHeight)
end

function MoveSpeed:ShowTooltip(anchor)
    self:CancelHideTimer()

    if not tooltipFrame then
        tooltipFrame = CreateTooltipFrame()
    end

    local db = self:GetDB()
    tooltipFrame:ClearAllPoints()
    tooltipFrame:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 4)
    tooltipFrame:SetScale(db.tooltipScale or 1.0)

    ScanSpeedBuffs()
    self:BuildTooltipContent()
    tooltipFrame:Show()
end

function MoveSpeed:StartHideTimer()
    self:CancelHideTimer()
    hideTimer = C_Timer.NewTimer(ns.HIDE_DELAY, function()
        if tooltipFrame then tooltipFrame:Hide() end
        hideTimer = nil
    end)
end

function MoveSpeed:CancelHideTimer()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
end

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------

MoveSpeed.settingsLabel = "Movement Speed"

local UPDATE_INTERVAL_VALUES = {
    ["0.05"] = "Very High (0.05s) - Higher CPU",
    ["0.1"]  = "High (0.1s)",
    ["0.2"]  = "Medium (0.2s) - Default",
    ["0.5"]  = "Low (0.5s)",
    ["1"]    = "Very Low (1s) - Minimal CPU",
}

function MoveSpeed:BuildSettingsPanel(panel)
    local W = ns.SettingsWidgets
    local r = panel.refreshCallbacks
    local db = function() return ns.db.movementspeed end

    local body = W.AddSection(panel, "Label Template")
    local y = 0
    y = W.AddLabelEditBox(body, y, "speed run fly swim mode",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateData() end, r, {
        { "Default",    "<speed>%" },
        { "With Mode",  "<speed>% (<mode>)" },
        { "Labeled",    "Speed: <speed>%" },
        { "Run/Fly",    "R:<run>% F:<fly>%" },
    })
    W.EndSection(panel, y)

    body = W.AddSection(panel, "Performance")
    y = 0
    y = W.AddDropdown(body, y, "Update Frequency", UPDATE_INTERVAL_VALUES,
        function() return tostring(db().updateInterval) end,
        function(v) db().updateInterval = tonumber(v) end, r)
    y = W.AddDescription(body, y,
        "Controls how often speed is polled (OnUpdate interval).\n" ..
        "Higher frequency = smoother display but more CPU usage.\n" ..
        "Lower frequency = less CPU, slight display delay.")
    W.EndSection(panel, y)

    body = W.AddSection(panel, "Display")
    y = 0
    y = W.AddCheckbox(body, y, "Show speed buffs and sources in tooltip",
        function() return db().showSpeedBuffs end,
        function(v) db().showSpeedBuffs = v end, r)
    W.EndSection(panel, y)

    body = W.AddSection(panel, "Tooltip", true)
    y = 0
    y = W.AddSliderPair(body, y,
        { label = "Scale", min = 0.5, max = 2.0, step = 0.05,
          get = function() return db().tooltipScale end,
          set = function(v) db().tooltipScale = v end },
        { label = "Width", min = 250, max = 600, step = 10,
          get = function() return db().tooltipWidth end,
          set = function(v) db().tooltipWidth = v end }, r)
    W.EndSection(panel, y)

    ns.AddModuleClickActionsSection(panel, r, "movementspeed", CLICK_ACTIONS,
        "Shopping actions create an Auctionator shopping list\n" ..
        "or copy a TSM search string to the chat input.\n" ..
        "Requires Auctionator or TradeSkillMaster.")
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("movementspeed", MoveSpeed, DEFAULTS)
