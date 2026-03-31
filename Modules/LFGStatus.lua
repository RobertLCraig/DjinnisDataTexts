-- Djinni's Data Texts — LFG Status
-- Tracks LFG queue status, premade group applications, and selected roles.
local addonName, ns = ...
local DDT = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local LFGStatus = {}
ns.LFGStatus = LFGStatus

-- Tooltip
local tooltipFrame = nil
local hideTimer = nil

-- Layout
local TOOLTIP_WIDTH  = 360
local ROW_HEIGHT     = 20
local HEADER_HEIGHT  = 18
local PADDING        = 10
local HINT_HEIGHT    = 18

-- State
local activeQueues = {}   -- { {category, categoryName, mode, instanceName, waitTime, queuedTime} }
local pendingApps  = {}   -- { {resultID, groupName, activityName, role, status, duration, numMembers} }
local activeEntry  = nil  -- { name, activityName, numApplicants } or nil
local roleString   = ""   -- "Tank/Healer" etc. (selected roles)
local assignedRole = nil  -- "TANK"/"HEALER"/"DAMAGER" when assigned via proposal or group

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
    labelTemplate  = "<status>",
    showQueues     = true,
    showApps       = true,
    showListed     = true,
    tooltipScale   = 1.0,
    tooltipWidth   = 360,
    clickActions   = {
        leftClick  = "groupfinder",
        rightClick = "opensettings",
    },
}

local CLICK_ACTIONS = {
    groupfinder  = "Group Finder",
    leavequeue   = "Leave All Queues",
    opensettings = "Open DDT Settings",
    none         = "None",
}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

local LFG_CATEGORIES = {
    { id = 1, name = "Dungeon Finder" },
    { id = 3, name = "Raid Finder" },
    { id = 4, name = "Scenarios" },
}

local ROLE_ICONS = {
    TANK    = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:0:19:22:41|t",
    HEALER  = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:20:39:1:20|t",
    DAMAGER = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:20:39:22:41|t",
}

local ROLE_LABELS = {
    TANK    = "Tank",
    HEALER  = "Healer",
    DAMAGER = "DPS",
}

local APP_STATUS_TEXT = {
    applied           = "Pending",
    invited           = "Invited!",
    failed            = "Failed",
    cancelled         = "Cancelled",
    declined          = "Declined",
    declined_full     = "Group Full",
    declined_delisted = "Delisted",
    timedout          = "Timed Out",
    inviteaccepted    = "Accepted",
    invitedeclined    = "Declined",
}

local APP_STATUS_COLOR = {
    applied           = { 1, 0.82, 0 },
    invited           = { 0, 1, 0 },
    failed            = { 0.5, 0.5, 0.5 },
    cancelled         = { 0.5, 0.5, 0.5 },
    declined          = { 1, 0.3, 0.3 },
    declined_full     = { 1, 0.3, 0.3 },
    declined_delisted = { 0.5, 0.5, 0.5 },
    timedout          = { 0.5, 0.5, 0.5 },
    inviteaccepted    = { 0, 1, 0 },
    invitedeclined    = { 1, 0.3, 0.3 },
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function FormatTime(seconds)
    if not seconds or seconds <= 0 then return "—" end
    seconds = math.floor(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then
        return string.format("%dh %dm", h, m)
    elseif m > 0 then
        return string.format("%dm %ds", m, s)
    else
        return string.format("%ds", s)
    end
end

local function GetRoleString()
    local _, tank, healer, damage = GetLFGRoles()
    local parts = {}
    if tank then table.insert(parts, "Tank") end
    if healer then table.insert(parts, "Healer") end
    if damage then table.insert(parts, "DPS") end
    if #parts == 0 then return "—" end
    return table.concat(parts, "/")
end

local function GetRoleIcon(role)
    if not role then return "" end
    local key = role:upper()
    return ROLE_ICONS[key] or ""
end

local function GetRoleLabel(role)
    if not role then return "—" end
    local key = role:upper()
    return ROLE_LABELS[key] or role
end

---------------------------------------------------------------------------
-- Data collection
---------------------------------------------------------------------------

local function CollectQueues()
    wipe(activeQueues)
    assignedRole = nil

    for _, cat in ipairs(LFG_CATEGORIES) do
        local mode = GetLFGMode(cat.id)
        if mode and mode ~= "none" and mode ~= "" then
            local hasData, _, _, _, _,
                  _, _, _, _, _,
                  instanceName, averageWait, _, _, _,
                  myWait, queuedTime = GetLFGQueueStats(cat.id)

            table.insert(activeQueues, {
                category     = cat.id,
                categoryName = cat.name,
                mode         = mode,
                instanceName = instanceName or cat.name,
                waitTime     = myWait or averageWait or 0,
                queuedTime   = queuedTime or 0,
                hasData      = hasData,
            })
        end
    end

    roleString = GetRoleString()

    -- Check for assigned role from an active proposal
    if GetLFGProposal then
        local proposalExists, _, _, _, _, _, role = GetLFGProposal()
        if proposalExists and role then
            assignedRole = role
        end
    end

    -- If in a group (post-accept), check group-assigned role
    if not assignedRole then
        local groupRole = UnitGroupRolesAssigned("player")
        if groupRole and groupRole ~= "NONE" and groupRole ~= "" then
            assignedRole = groupRole
        end
    end
end

local function CollectApplications()
    wipe(pendingApps)

    if not C_LFGList then return end

    local apps = C_LFGList.GetApplications()
    if not apps then return end

    for _, resultID in ipairs(apps) do
        local id, status, _, appDuration, role = C_LFGList.GetApplicationInfo(resultID)
        if id and status and status ~= "none" then
            local searchInfo = C_LFGList.GetSearchResultInfo(resultID)
            local activityName = ""
            if searchInfo and searchInfo.activityIDs then
                for _, actID in ipairs(searchInfo.activityIDs) do
                    local actInfo = C_LFGList.GetActivityInfoTable(actID)
                    if actInfo then
                        activityName = actInfo.shortName or actInfo.fullName or ""
                        break
                    end
                end
            end

            table.insert(pendingApps, {
                resultID     = resultID,
                groupName    = (searchInfo and searchInfo.name) or "Unknown",
                activityName = activityName,
                role         = role or "",
                status       = status,
                duration     = appDuration or 0,
                leaderName   = (searchInfo and searchInfo.leaderName) or "",
                numMembers   = (searchInfo and searchInfo.numMembers) or 0,
            })
        end
    end
end

local function CollectActiveEntry()
    activeEntry = nil

    if not C_LFGList or not C_LFGList.HasActiveEntryInfo then return end
    if not C_LFGList.HasActiveEntryInfo() then return end

    local entryInfo = C_LFGList.GetActiveEntryInfo()
    if not entryInfo then return end

    local activityName = ""
    if entryInfo.activityID then
        local actInfo = C_LFGList.GetActivityInfoTable(entryInfo.activityID)
        if actInfo then
            activityName = actInfo.shortName or actInfo.fullName or ""
        end
    end

    local numApplicants = 0
    if C_LFGList.GetNumApplicants then
        numApplicants = C_LFGList.GetNumApplicants() or 0
    end

    activeEntry = {
        name          = entryInfo.name or "Your Group",
        activityName  = activityName,
        numApplicants = numApplicants,
    }
end

---------------------------------------------------------------------------
-- Label template expansion
---------------------------------------------------------------------------

local function GetActiveAppCount()
    local count = 0
    for _, app in ipairs(pendingApps) do
        if app.status == "applied" or app.status == "invited" then
            count = count + 1
        end
    end
    return count
end

local function GetStatusText()
    local parts = {}
    if #activeQueues > 0 then
        if assignedRole then
            table.insert(parts, "Queued (" .. GetRoleLabel(assignedRole) .. ")")
        else
            table.insert(parts, "Queued")
        end
    end
    local appCount = GetActiveAppCount()
    if appCount > 0 then
        table.insert(parts, appCount .. " App" .. (appCount > 1 and "s" or ""))
    end
    if activeEntry then
        table.insert(parts, "Listed")
    end
    if #parts == 0 then return "Idle" end
    return table.concat(parts, " | ")
end

local function ExpandLabel(template, db)
    local result = template
    result = result:gsub("<status>", GetStatusText())
    result = result:gsub("<queues>", tostring(#activeQueues))
    result = result:gsub("<apps>", tostring(GetActiveAppCount()))
    result = result:gsub("<role>", roleString)
    result = result:gsub("<assigned>", assignedRole and GetRoleLabel(assignedRole) or "")
    -- Wait time for first queue
    local waitStr = "—"
    if #activeQueues > 0 and activeQueues[1].waitTime > 0 then
        waitStr = FormatTime(activeQueues[1].waitTime)
    end
    result = result:gsub("<wait>", waitStr)
    -- Elapsed time for first queue
    local elapsedStr = "—"
    if #activeQueues > 0 and activeQueues[1].queuedTime > 0 then
        elapsedStr = FormatTime(activeQueues[1].queuedTime)
    end
    result = result:gsub("<elapsed>", elapsedStr)
    return result
end

---------------------------------------------------------------------------
-- LDB Data Object
---------------------------------------------------------------------------

local dataobj = LDB:NewDataObject("DDT-LFGStatus", {
    type  = "data source",
    text  = "Idle",
    icon  = "Interface\\Icons\\INV_Misc_GroupLooking",
    label = "DDT - LFG Status",
    OnEnter = function(self)
        LFGStatus:ShowTooltip(self)
    end,
    OnLeave = function(self)
        LFGStatus:StartHideTimer()
    end,
    OnClick = function(self, button)
        local db = LFGStatus:GetDB()
        local action = DDT:ResolveClickAction(button, db.clickActions or {})
        if action == "groupfinder" then
            ToggleLFDParentFrame()
        elseif action == "leavequeue" then
            for _, q in ipairs(activeQueues) do
                LeaveLFG(q.category)
            end
            LFGStatus:UpdateData()
        elseif action == "opensettings" then
            if DDT.settingsCategoryID then
                Settings.OpenToCategory(DDT.settingsCategoryID)
            end
        end
    end,
})

LFGStatus.dataobj = dataobj

---------------------------------------------------------------------------
-- Event handling and update
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local elapsed = 0
local UPDATE_INTERVAL = 1

function LFGStatus:Init()
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("LFG_UPDATE")
    eventFrame:RegisterEvent("LFG_QUEUE_STATUS_UPDATE")
    eventFrame:RegisterEvent("LFG_PROPOSAL_UPDATE")
    eventFrame:RegisterEvent("LFG_PROPOSAL_SHOW")
    eventFrame:RegisterEvent("LFG_PROPOSAL_FAILED")
    eventFrame:RegisterEvent("LFG_ROLE_CHECK_UPDATE")
    eventFrame:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
    eventFrame:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
    eventFrame:RegisterEvent("LFG_LIST_APPLICANT_LIST_UPDATED")
    eventFrame:RegisterEvent("ROLE_CHANGED_INFORM")

    eventFrame:SetScript("OnEvent", function()
        LFGStatus:UpdateData()
    end)

    -- OnUpdate for live elapsed time when queued
    eventFrame:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= UPDATE_INTERVAL then
            elapsed = 0
            if #activeQueues > 0 or (tooltipFrame and tooltipFrame:IsShown()) then
                LFGStatus:UpdateData()
            end
        end
    end)
end

function LFGStatus:GetDB()
    return ns.db and ns.db.lfgstatus or DEFAULTS
end

function LFGStatus:UpdateData()
    CollectQueues()
    CollectApplications()
    CollectActiveEntry()

    local db = self:GetDB()
    dataobj.text = ExpandLabel(db.labelTemplate, db)

    -- Update icon based on state
    if #activeQueues > 0 then
        for _, q in ipairs(activeQueues) do
            if q.mode == "proposal" then
                dataobj.icon = "Interface\\Icons\\Spell_Nature_WispSplode"
                return
            end
        end
        dataobj.icon = "Interface\\Icons\\Spell_Nature_TimeStop"
    elseif GetActiveAppCount() > 0 then
        dataobj.icon = "Interface\\Icons\\INV_Scroll_11"
    elseif activeEntry then
        dataobj.icon = "Interface\\Icons\\INV_Misc_Note_01"
    else
        dataobj.icon = "Interface\\Icons\\INV_Misc_GroupLooking"
    end

    if tooltipFrame and tooltipFrame:IsShown() then
        self:BuildTooltipContent()
    end
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------

local function CreateTooltipFrame()
    local f = CreateFrame("Frame", "DDTLFGStatusTooltip", UIParent, "BackdropTemplate")
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
    f:SetScript("OnEnter", function() LFGStatus:CancelHideTimer() end)
    f:SetScript("OnLeave", function() LFGStatus:StartHideTimer() end)

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

function LFGStatus:BuildTooltipContent()
    local f = tooltipFrame
    HideLines(f)

    local db = self:GetDB()
    f.title:SetText("LFG Status")

    local y = -PADDING - 20 - 6
    local lineIdx = 0

    -----------------------------------------------------------------------
    -- Active Queues
    -----------------------------------------------------------------------
    if db.showQueues and #activeQueues > 0 then
        lineIdx = lineIdx + 1
        local hdr = GetLine(f, lineIdx)
        hdr.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        hdr.label:SetText("|cff66c7ffActive Queues|r")
        hdr.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        hdr.value:SetText("Queued as: " .. roleString)
        hdr.value:SetTextColor(0.8, 0.8, 0.8)
        y = y - ROW_HEIGHT

        -- Show assigned role prominently when known
        if assignedRole then
            lineIdx = lineIdx + 1
            local assignLine = GetLine(f, lineIdx)
            assignLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 8, y)
            local roleIcon = GetRoleIcon(assignedRole)
            local roleLabel = GetRoleLabel(assignedRole)
            assignLine.label:SetText(roleIcon .. " |cff00ff00Assigned as: " .. roleLabel .. "|r")
            assignLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
            assignLine.value:SetText("")
            y = y - ROW_HEIGHT
        end

        for _, q in ipairs(activeQueues) do
            -- Row 1: category + mode indicator
            lineIdx = lineIdx + 1
            local catLine = GetLine(f, lineIdx)
            catLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 8, y)

            local catText = q.categoryName
            if q.mode == "proposal" then
                catText = catText .. "  |cff00ff00READY!|r"
            elseif q.mode == "rolecheck" then
                catText = catText .. "  |cffffff00Role Check|r"
            elseif q.mode == "suspended" then
                catText = catText .. "  |cffff8800Suspended|r"
            end
            catLine.label:SetText(catText)
            catLine.label:SetTextColor(1, 0.82, 0)
            catLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
            catLine.value:SetText("")
            y = y - ROW_HEIGHT

            -- Row 2: instance name + wait/elapsed
            lineIdx = lineIdx + 1
            local instLine = GetLine(f, lineIdx)
            instLine.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 16, y)
            instLine.label:SetText(q.instanceName)
            instLine.label:SetTextColor(1, 1, 1)

            local timeParts = {}
            if q.queuedTime > 0 then
                table.insert(timeParts, FormatTime(q.queuedTime) .. " in queue")
            end
            if q.hasData and q.waitTime > 0 then
                table.insert(timeParts, "est. " .. FormatTime(q.waitTime))
            end
            instLine.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
            instLine.value:SetText(table.concat(timeParts, " / "))
            instLine.value:SetTextColor(0.7, 0.7, 0.7)
            y = y - ROW_HEIGHT
        end

        y = y - 4
    end

    -----------------------------------------------------------------------
    -- Premade Applications
    -----------------------------------------------------------------------
    if db.showApps and #pendingApps > 0 then
        lineIdx = lineIdx + 1
        local hdr = GetLine(f, lineIdx)
        hdr.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        hdr.label:SetText("|cff66c7ffPremade Applications|r")
        hdr.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        hdr.value:SetText("")
        y = y - ROW_HEIGHT

        for _, app in ipairs(pendingApps) do
            lineIdx = lineIdx + 1
            local line = GetLine(f, lineIdx)
            line.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 8, y)

            local roleIcon = GetRoleIcon(app.role)
            local roleLabel = GetRoleLabel(app.role)
            local groupText = roleIcon .. " " .. app.groupName
            if app.activityName ~= "" then
                groupText = groupText .. " |cff888888(" .. app.activityName .. ")|r"
            end
            line.label:SetText(groupText)
            line.label:SetTextColor(1, 1, 1)

            local statusLabel = APP_STATUS_TEXT[app.status] or app.status
            local statusColor = APP_STATUS_COLOR[app.status] or { 0.7, 0.7, 0.7 }
            local rightText = roleLabel .. " — " .. statusLabel
            line.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
            line.value:SetText(rightText)
            line.value:SetTextColor(unpack(statusColor))
            y = y - ROW_HEIGHT
        end

        y = y - 4
    end

    -----------------------------------------------------------------------
    -- Your Listed Group
    -----------------------------------------------------------------------
    if db.showListed and activeEntry then
        lineIdx = lineIdx + 1
        local hdr = GetLine(f, lineIdx)
        hdr.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        hdr.label:SetText("|cff66c7ffYour Listed Group|r")
        hdr.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        hdr.value:SetText("")
        y = y - ROW_HEIGHT

        lineIdx = lineIdx + 1
        local line = GetLine(f, lineIdx)
        line.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + 8, y)
        local entryText = activeEntry.name
        if activeEntry.activityName ~= "" then
            entryText = entryText .. " |cff888888(" .. activeEntry.activityName .. ")|r"
        end
        line.label:SetText(entryText)
        line.label:SetTextColor(1, 1, 1)
        line.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        local n = activeEntry.numApplicants
        line.value:SetText(n .. " applicant" .. (n ~= 1 and "s" or ""))
        line.value:SetTextColor(0.4, 0.78, 1)
        y = y - ROW_HEIGHT

        y = y - 4
    end

    -----------------------------------------------------------------------
    -- Empty state
    -----------------------------------------------------------------------
    if #activeQueues == 0 and #pendingApps == 0 and not activeEntry then
        lineIdx = lineIdx + 1
        local line = GetLine(f, lineIdx)
        line.label:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        line.label:SetText("|cff888888Not queued or applied to any groups.|r")
        line.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        line.value:SetText("")
        y = y - ROW_HEIGHT
    end

    -- Hint
    f.hint:SetText(DDT:BuildHintText(db.clickActions or {}, CLICK_ACTIONS))

    local ttWidth = db.tooltipWidth or TOOLTIP_WIDTH
    local totalHeight = math.abs(y) + PADDING + HINT_HEIGHT + 8
    f:SetSize(ttWidth, totalHeight)
end

function LFGStatus:ShowTooltip(anchor)
    self:CancelHideTimer()

    if not tooltipFrame then
        tooltipFrame = CreateTooltipFrame()
    end

    local db = self:GetDB()
    tooltipFrame:ClearAllPoints()
    tooltipFrame:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 4)
    tooltipFrame:SetScale(db.tooltipScale or 1.0)

    self:UpdateData()
    self:BuildTooltipContent()
    tooltipFrame:Show()
end

function LFGStatus:StartHideTimer()
    self:CancelHideTimer()
    hideTimer = C_Timer.NewTimer(ns.HIDE_DELAY, function()
        if tooltipFrame then tooltipFrame:Hide() end
        hideTimer = nil
    end)
end

function LFGStatus:CancelHideTimer()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
end

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------

LFGStatus.settingsLabel = "LFG Status"

function LFGStatus:BuildSettingsPanel(panel)
    local W = ns.SettingsWidgets
    local c = panel.content
    local r = panel.refreshCallbacks
    local y = -10
    local db = function() return ns.db.lfgstatus end

    y = W.AddHeader(c, y, "Label Template")
    y = W.AddLabelEditBox(c, y, "status queues apps role assigned wait elapsed",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateData() end, r, {
        { "Default",    "<status>" },
        { "With Role",  "<status> (<role>)" },
        { "Queue Time", "<status> - <elapsed>" },
        { "Compact",    "LFG: <queues>Q <apps>A" },
        { "Assigned",   "<status> <assigned>" },
    })

    y = W.AddHeader(c, y, "Display")
    y = W.AddCheckbox(c, y, "Show active queues (Dungeon/Raid Finder)",
        function() return db().showQueues end,
        function(v) db().showQueues = v end, r)
    y = W.AddCheckbox(c, y, "Show premade group applications",
        function() return db().showApps end,
        function(v) db().showApps = v end, r)
    y = W.AddCheckbox(c, y, "Show your listed group",
        function() return db().showListed end,
        function(v) db().showListed = v end, r)

    y = W.AddHeader(c, y, "Tooltip")
    y = W.AddSlider(c, y, "Scale", 0.5, 2.0, 0.05,
        function() return db().tooltipScale end,
        function(v) db().tooltipScale = v end, r)
    y = W.AddSlider(c, y, "Width", 200, 500, 10,
        function() return db().tooltipWidth end,
        function(v) db().tooltipWidth = v end, r)

    y = ns.AddModuleClickActionsSection(c, r, y, "lfgstatus", CLICK_ACTIONS)

    c:SetHeight(math.abs(y) + 20)
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("lfgstatus", LFGStatus, DEFAULTS)
