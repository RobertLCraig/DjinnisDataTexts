-- Djinni's Data Texts — Communities
-- WoW Communities roster with online members and stream notifications.
local addonName, ns = ...
local DDT = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local CommunitiesBroker = {}
ns.CommunitiesBroker = CommunitiesBroker

local DEFAULTS = {
    labelFormat = "Communities: <online>",
    sortBy = "name",
    sortAscending = true,
    classColorNames = true,
    showHintBar = true,
    tooltipScale = 1.0,
    tooltipWidth = 480,
    tooltipMaxHeight = 500,
    rowSpacing = 4,
    groupBy = "community",
    groupBy2 = "none",
    groupCollapsed = {},
    disabledClubs = {},
    clickActions = {
        leftClick       = "opencommunities",
        rightClick      = "none",
        middleClick     = "none",
        shiftLeftClick  = "none",
        shiftRightClick = "none",
        ctrlLeftClick   = "none",
        ctrlRightClick  = "none",
        altLeftClick    = "opensettings",
        altRightClick   = "none",
    },
    rowClickActions = {
        leftClick       = "whisper",
        rightClick      = "invite",
        middleClick     = "none",
        shiftLeftClick  = "copyname",
        shiftRightClick = "who",
        ctrlLeftClick   = "copyarmory",
        ctrlRightClick  = "none",
        altLeftClick    = "none",
        altRightClick   = "none",
    },
}

CommunitiesBroker.clubsCache = {}   -- { clubId = { info=ClubInfo, members={...} } }
CommunitiesBroker.onlineCount = 0
CommunitiesBroker.totalOnline = 0

local tooltipFrame = nil
local rowPool = {}
local TOOLTIP_PADDING = ns.TOOLTIP_PADDING

---------------------------------------------------------------------------
-- LDB Data Object
---------------------------------------------------------------------------

local dataobj = LDB:NewDataObject("DDT-Communities", {
    type  = "data source",
    text  = "Communities: 0",
    icon  = "Interface\\FriendsFrame\\UI-Toast-ChatInviteIcon",
    label = "DDT - Communities",
    OnEnter = function(self)
        CommunitiesBroker:ShowTooltip(self)
    end,
    OnLeave = function(self)
        CommunitiesBroker:StartTooltipHideTimer()
    end,
    OnClick = function(self, button)
        local db = ns.db and ns.db.communities or {}
        local action = DDT:ResolveClickAction(button, db.clickActions or {})
        if action == "opencommunities" then
            ToggleCommunitiesFrame()
        elseif action == "openfriends" then
            ToggleFriendsFrame()
        elseif action == "openguild" then
            ToggleGuildFrame()
        elseif action == "opensettings" then
            if DDT.settingsCategoryID then Settings.OpenToCategory(DDT.settingsCategoryID) end
        end
    end,
})

CommunitiesBroker.dataobj = dataobj

---------------------------------------------------------------------------
-- Event handling
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

function CommunitiesBroker:Init()
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            CommunitiesBroker:OnPlayerEnteringWorld()
        else
            CommunitiesBroker:OnClubUpdate(event, ...)
        end
    end)
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("CLUB_MEMBER_PRESENCE_UPDATED")
    eventFrame:RegisterEvent("CLUB_MEMBER_UPDATED")
    eventFrame:RegisterEvent("CLUB_ADDED")
    eventFrame:RegisterEvent("CLUB_REMOVED")
    eventFrame:RegisterEvent("CLUB_STREAMS_LOADED")
    eventFrame:RegisterEvent("CLUB_MEMBER_ROLE_UPDATED")
end

function CommunitiesBroker:OnPlayerEnteringWorld()
    C_Timer.After(5, function()
        self:UpdateData()
    end)
end

function CommunitiesBroker:OnClubUpdate()
    self:UpdateData()
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

--- Resolve classFile from a classID via C_CreatureInfo
local function ClassFileFromID(classID)
    if not classID or classID == 0 then return nil end
    local info = C_CreatureInfo and C_CreatureInfo.GetClassInfo(classID)
    return info and info.classFile or nil
end

--- Check if a club member is considered online
local function IsPresenceOnline(presence)
    return presence == Enum.ClubMemberPresence.Online
        or presence == Enum.ClubMemberPresence.OnlineMobile
        or presence == Enum.ClubMemberPresence.Away
        or presence == Enum.ClubMemberPresence.Busy
end

--- Club role constants (Owner=1, Leader=2, Moderator=3, Member=4)
local ROLE_OWNER     = Enum.ClubRoleIdentifier and Enum.ClubRoleIdentifier.Owner or 1
local ROLE_LEADER    = Enum.ClubRoleIdentifier and Enum.ClubRoleIdentifier.Leader or 2
local ROLE_MODERATOR = Enum.ClubRoleIdentifier and Enum.ClubRoleIdentifier.Moderator or 3

--- Color M+ scores by rating tier
local function GetScoreColor(score)
    if C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor then
        local color = C_ChallengeMode.GetDungeonScoreRarityColor(score)
        if color then return color.r, color.g, color.b end
    end
    if score >= 2500 then return 1.0, 0.50, 0.0  end
    if score >= 2000 then return 0.63, 0.21, 0.93 end
    if score >= 1500 then return 0.0, 0.44, 0.87  end
    if score >= 1000 then return 0.12, 0.75, 0.0  end
    if score >= 500  then return 1.0, 1.0, 1.0    end
    return 0.62, 0.62, 0.62
end

--- Check if a club should be shown (not disabled by user)
function CommunitiesBroker:IsClubEnabled(clubId)
    return not ns.db.communities.disabledClubs[clubId]
end

---------------------------------------------------------------------------
-- Data collection
---------------------------------------------------------------------------

function CommunitiesBroker:UpdateData()
    local db = ns.db.communities
    local clubs = C_Club.GetSubscribedClubs()
    if type(clubs) ~= "table" then clubs = {} end
    local totalOnline = 0
    local clubsData = {}

    for _, clubInfo in ipairs(clubs) do
        -- Only character and BNet communities (skip guild — handled by GuildBroker)
        -- Skip clubs whose data hasn't loaded yet — unloaded fields return a
        -- WoW "secret" protected value, which is truthy but not a string.
        if type(clubInfo.name) == "string"
           and (clubInfo.clubType == Enum.ClubType.Character or clubInfo.clubType == Enum.ClubType.BattleNet)
           and self:IsClubEnabled(clubInfo.clubId) then

            local memberIds = C_Club.GetClubMembers(clubInfo.clubId)
            local onlineMembers = {}

            for _, memberId in ipairs(memberIds or {}) do
                local mInfo = C_Club.GetMemberInfo(clubInfo.clubId, memberId)
                if type(mInfo) == "table" and IsPresenceOnline(mInfo.presence) then
                    local classFile = ClassFileFromID(mInfo.classID)
                    local memberName = mInfo.name or "Unknown"

                    -- Strip realm suffix for display
                    local displayName = memberName
                    local dash = memberName:find("-")
                    if dash then
                        displayName = memberName:sub(1, dash - 1)
                    end

                    table.insert(onlineMembers, {
                        name         = displayName,
                        fullName     = memberName,
                        level        = mInfo.level or 0,
                        classFile    = classFile,
                        area         = mInfo.zone or "",
                        notes        = mInfo.memberNote or "",
                        afk          = (mInfo.presence == Enum.ClubMemberPresence.Away),
                        dnd          = (mInfo.presence == Enum.ClubMemberPresence.Busy),
                        isMobile     = (mInfo.presence == Enum.ClubMemberPresence.OnlineMobile),
                        isRemoteChat = mInfo.isRemoteChat or false,
                        isSelf       = mInfo.isSelf,
                        clubId       = clubInfo.clubId,
                        clubName     = clubInfo.name or "Unknown",
                        clubType     = clubInfo.clubType,
                        role         = mInfo.role,
                        dungeonScore = mInfo.overallDungeonScore or 0,
                    })
                end
            end

            -- Sort members within each club
            self:SortMembers(onlineMembers)

            totalOnline = totalOnline + #onlineMembers
            clubsData[clubInfo.clubId] = {
                info = clubInfo,
                members = onlineMembers,
            }
        end
    end

    self.clubsCache = clubsData
    self.totalOnline = totalOnline

    dataobj.text = DDT:FormatLabel(db.labelFormat, totalOnline, totalOnline)

    if tooltipFrame and tooltipFrame:IsShown() then
        self:PopulateTooltip()
    end
end

---------------------------------------------------------------------------
-- Sorting
---------------------------------------------------------------------------

function CommunitiesBroker:SortMembers(members)
    DDT:SortList(members, ns.db.communities)
end

function CommunitiesBroker:GetDB()
    return ns.db and ns.db.communities or {}
end

---------------------------------------------------------------------------
-- Tooltip frame creation
---------------------------------------------------------------------------

local function CreateTooltipFrame()
    local f = ns.CreateTooltipFrame(nil, CommunitiesBroker)

    -- Column headers live on the outer frame (above scroll area)
    f.colName = ns.FontString(f, "DDTFontNormal")
    f.colName:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 0, -4)
    f.colName:SetText("|cffaaaaaaName|r")
    f.colName:SetJustifyH("LEFT")

    f.colLevel = ns.FontString(f, "DDTFontNormal")
    f.colLevel:SetPoint("LEFT", f.colName, "RIGHT", 4, 0)
    f.colLevel:SetText("|cffaaaaaaLvl|r")
    f.colLevel:SetWidth(30)
    f.colLevel:SetJustifyH("CENTER")

    f.colScore = ns.FontString(f, "DDTFontNormal")
    f.colScore:SetPoint("LEFT", f.colLevel, "RIGHT", 4, 0)
    f.colScore:SetText("|cffaaaaaaScore|r")
    f.colScore:SetWidth(45)
    f.colScore:SetJustifyH("CENTER")
    f.colScore:Hide()

    f.colZone = ns.FontString(f, "DDTFontNormal")
    f.colZone:SetPoint("LEFT", f.colScore, "RIGHT", 4, 0)
    f.colZone:SetText("|cffaaaaaaZone|r")
    f.colZone:SetJustifyH("LEFT")

    f.colNote = ns.FontString(f, "DDTFontNormal")
    f.colNote:SetPoint("LEFT", f.colZone, "RIGHT", 4, 0)
    f.colNote:SetPoint("RIGHT", f, "RIGHT", -TOOLTIP_PADDING, 0)
    f.colNote:SetText("|cffaaaaaaNotes|r")
    f.colNote:SetJustifyH("LEFT")

    f.headerExtra = 18  -- extra height for column header row

    return f
end



local function GetOrCreateRow(parent, index)
    if rowPool[index] then
        rowPool[index]:Show()
        return rowPool[index]
    end

    local row = CreateFrame("Button", nil, parent)
    row:SetSize(360, ns.ROW_HEIGHT)
    row:EnableMouse(true)
    row:RegisterForClicks("AnyUp")

    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, 0.1)

    row.nameText = ns.FontString(row, "DDTFontNormal")
    row.nameText:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.nameText:SetWidth(130)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetJustifyV("TOP")
    row.nameText:SetWordWrap(true)

    row.levelText = ns.FontString(row, "DDTFontNormal")
    row.levelText:SetPoint("TOPLEFT", row.nameText, "TOPRIGHT", 4, 0)
    row.levelText:SetWidth(30)
    row.levelText:SetJustifyH("CENTER")
    row.levelText:SetJustifyV("TOP")

    row.scoreText = ns.FontString(row, "DDTFontNormal")
    row.scoreText:SetPoint("TOPLEFT", row.levelText, "TOPRIGHT", 4, 0)
    row.scoreText:SetWidth(45)
    row.scoreText:SetJustifyH("CENTER")
    row.scoreText:SetJustifyV("TOP")

    row.zoneText = ns.FontString(row, "DDTFontNormal")
    row.zoneText:SetPoint("TOPLEFT", row.scoreText, "TOPRIGHT", 4, 0)
    row.zoneText:SetWidth(130)
    row.zoneText:SetJustifyH("LEFT")
    row.zoneText:SetJustifyV("TOP")
    row.zoneText:SetWordWrap(true)

    row.noteText = ns.FontString(row, "DDTFontSmall")
    row.noteText:SetPoint("TOPLEFT", row.zoneText, "TOPRIGHT", 4, 0)
    row.noteText:SetJustifyH("LEFT")
    row.noteText:SetJustifyV("TOP")
    row.noteText:SetWordWrap(true)

    row:SetScript("OnMouseUp", function(self, button)
        CommunitiesBroker:OnRowClick(self, button)
    end)

    row:SetScript("OnEnter", function(self)
        CommunitiesBroker:CancelTooltipHideTimer()
        if self.memberData and self.memberData.notes and self.memberData.notes ~= "" then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.memberData.notes, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)

    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
        CommunitiesBroker:StartTooltipHideTimer()
    end)

    rowPool[index] = row
    return row
end

---------------------------------------------------------------------------
-- Tooltip display
---------------------------------------------------------------------------

function CommunitiesBroker:ShowTooltip(anchor)
    if not tooltipFrame then
        tooltipFrame = CreateTooltipFrame()
    end

    self:CancelTooltipHideTimer()
    self:UpdateData()

    ns.AnchorTooltip(tooltipFrame, anchor, ns.db.communities.tooltipGrowDirection)
    tooltipFrame:SetScale(ns.db.communities.tooltipScale or 1.0)

    self:PopulateTooltip()
    tooltipFrame:Show()
end

function CommunitiesBroker:PopulateTooltip()
    if not tooltipFrame then return end

    local db = ns.db.communities
    local useClassColors = db.classColorNames

    local tooltipWidth = db.tooltipWidth or 480
    local innerWidth = tooltipWidth - 2 * TOOLTIP_PADDING
    local nameW = math.floor(innerWidth * 0.30)
    local levelW = 30

    -- Check if any member has M+ scores
    local hasScores = false
    for _, clubData in pairs(self.clubsCache) do
        for _, m in ipairs(clubData.members) do
            if m.dungeonScore and m.dungeonScore > 0 then
                hasScores = true
                break
            end
        end
        if hasScores then break end
    end

    local scoreW = hasScores and 45 or 0
    local zoneW = hasScores and math.floor(innerWidth * 0.24) or math.floor(innerWidth * 0.28)
    local gapTotal = hasScores and 16 or 12
    local noteW = math.max(50, innerWidth - nameW - levelW - scoreW - zoneW - gapTotal)

    if hasScores then
        tooltipFrame.colScore:SetWidth(scoreW)
        tooltipFrame.colScore:SetText("|cffaaaaaaScore|r")
        tooltipFrame.colScore:Show()
    else
        tooltipFrame.colScore:SetWidth(0)
        tooltipFrame.colScore:SetText("")
        tooltipFrame.colScore:Hide()
    end

    tooltipFrame:SetWidth(tooltipWidth)
    tooltipFrame.colName:SetWidth(nameW)
    tooltipFrame.colZone:SetWidth(zoneW)

    local sc = tooltipFrame.scrollContent

    -- Count enabled clubs
    local clubCount = 0
    for _ in pairs(self.clubsCache) do clubCount = clubCount + 1 end

    tooltipFrame.header:SetText(
        DDT:ColorText("Communities Online: ", 1, 0.82, 0) ..
        DDT:ColorText(tostring(self.totalOnline), 0, 1, 0)
    )

    local showHint = db.showHintBar ~= false
    if showHint then
        tooltipFrame.hint:SetText(DDT:BuildHintText(db.rowClickActions or {}))
        tooltipFrame.hint:Show()
    else
        tooltipFrame.hint:Hide()
    end

    for _, row in pairs(rowPool) do
        row:Hide()
    end
    if sc.groupHeaders then
        for _, hdr in pairs(sc.groupHeaders) do
            hdr:Hide()
        end
    end

    local rowSpacing = db.rowSpacing or 4
    local rowStep = ns.ROW_HEIGHT + rowSpacing
    local groupBy = db.groupBy or "community"
    local yOffset = 0
    local rowIdx = 0

    -- Sort clubs alphabetically by name
    local sortedClubs = {}
    for clubId, data in pairs(self.clubsCache) do
        table.insert(sortedClubs, data)
    end
    table.sort(sortedClubs, function(a, b)
        return (a.info.name or "") < (b.info.name or "")
    end)

    local function RenderMember(member)
        rowIdx = rowIdx + 1
        local row = GetOrCreateRow(sc, rowIdx)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, yOffset)

        row:SetWidth(innerWidth)
        row.nameText:SetWidth(nameW)
        row.scoreText:SetWidth(scoreW)
        row.zoneText:SetWidth(zoneW)
        row.noteText:SetWidth(noteW)

        row.memberData = member

        -- Status prefix
        local status = ""
        if member.isRemoteChat then
            status = "|cff82c5ff[App]|r "
        elseif member.afk then
            status = "|cffffcc00[AFK]|r "
        elseif member.dnd then
            status = "|cffff0000[DND]|r "
        end

        -- Community role badge
        local roleBadge = ""
        if member.role then
            if member.role == ROLE_OWNER then
                roleBadge = "|cffff8800[O]|r "
            elseif member.role == ROLE_LEADER then
                roleBadge = "|cff00ccff[L]|r "
            elseif member.role == ROLE_MODERATOR then
                roleBadge = "|cff00cc00[M]|r "
            end
        end

        local namePrefix = roleBadge .. status
        if useClassColors and member.classFile then
            row.nameText:SetText(namePrefix .. DDT:ClassColorText(member.name, member.classFile))
        else
            row.nameText:SetText(namePrefix .. member.name)
        end

        -- Level and zone (blank for app users not in WoW)
        if member.isRemoteChat then
            row.levelText:SetText("")
            row.zoneText:SetText(DDT:ColorText("Battle.net App", 0.51, 0.77, 1))
        else
            row.levelText:SetText(member.level > 0 and tostring(member.level) or "")
            row.zoneText:SetText(DDT:ColorText(member.area, 0.63, 0.82, 1))
        end

        -- M+ score
        if hasScores then
            local score = member.dungeonScore or 0
            if score > 0 and not member.isRemoteChat then
                local r, g, b = GetScoreColor(score)
                row.scoreText:SetText(DDT:ColorText(tostring(score), r, g, b))
            else
                row.scoreText:SetText("")
            end
        else
            row.scoreText:SetText("")
        end

        row.noteText:SetText(member.notes or "")

        -- Measure actual text height (accounts for word-wrap)
        local textH = math.max(row.nameText:GetStringHeight(), row.zoneText:GetStringHeight(), row.noteText:GetStringHeight(), ns.ROW_HEIGHT)
        row:SetHeight(textH)

        yOffset = yOffset - textH - rowSpacing
    end

    local hasAnyMembers = false

    local groupBy2 = db.groupBy2 or "none"

    if groupBy == "community" then
        for _, clubData in ipairs(sortedClubs) do
            local members = clubData.members
            if #members > 0 then
                hasAnyMembers = true
                yOffset = yOffset - 4
                local clubName = clubData.info.name or "Unknown"
                local hdr = self:GetOrCreateGroupHeader(sc, clubName)
                hdr:ClearAllPoints()
                hdr:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, yOffset)
                hdr:SetText(DDT:ColorText(clubName .. " (" .. #members .. ")", 0.4, 0.78, 1))
                hdr:Show()
                yOffset = yOffset - 16

                if groupBy2 ~= "none" and groupBy2 ~= "community" then
                    local subGroups, subOrder = self:BuildGroups(members, groupBy2)
                    for _, subName in ipairs(subOrder) do
                        local subMembers = subGroups[subName]
                        if subMembers and #subMembers > 0 then
                            yOffset = yOffset - 2
                            local subHdr = DDT:GetOrCreateGroupHeader(sc, clubName .. "|" .. subName)
                            subHdr:ClearAllPoints()
                            subHdr:SetPoint("TOPLEFT", sc, "TOPLEFT", 16, yOffset)
                            subHdr:SetText(DDT:ColorText(subName .. " (" .. #subMembers .. ")", 0.8, 0.8, 0.6))
                            subHdr:Show()
                            yOffset = yOffset - 14
                            for _, member in ipairs(subMembers) do
                                RenderMember(member)
                            end
                        end
                    end
                else
                    for _, member in ipairs(members) do
                        RenderMember(member)
                    end
                end
            end
        end
    else
        -- Flatten members from all clubs, re-sort, then group
        local allMembers = {}
        for _, clubData in ipairs(sortedClubs) do
            for _, m in ipairs(clubData.members) do
                table.insert(allMembers, m)
                hasAnyMembers = true
            end
        end
        self:SortMembers(allMembers)

        if groupBy == "none" then
            for _, member in ipairs(allMembers) do
                RenderMember(member)
            end
        else
            local groups, groupOrder = self:BuildGroups(allMembers, groupBy)
            for _, groupName in ipairs(groupOrder) do
                local groupMembers = groups[groupName]
                if groupMembers and #groupMembers > 0 then
                    yOffset = yOffset - 4
                    local hdr = self:GetOrCreateGroupHeader(sc, groupName)
                    hdr:ClearAllPoints()
                    hdr:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, yOffset)
                    hdr:SetText(DDT:ColorText(groupName .. " (" .. #groupMembers .. ")", 1, 0.82, 0))
                    hdr:Show()
                    yOffset = yOffset - 16
                    if not db.groupCollapsed[groupName] then
                        if groupBy2 ~= "none" and groupBy2 ~= groupBy then
                            local subGroups, subOrder = self:BuildGroups(groupMembers, groupBy2)
                            for _, subName in ipairs(subOrder) do
                                local subMembers = subGroups[subName]
                                if subMembers and #subMembers > 0 then
                                    yOffset = yOffset - 2
                                    local subHdr = DDT:GetOrCreateGroupHeader(sc, groupName .. "|" .. subName)
                                    subHdr:ClearAllPoints()
                                    subHdr:SetPoint("TOPLEFT", sc, "TOPLEFT", 16, yOffset)
                                    subHdr:SetText(DDT:ColorText(subName .. " (" .. #subMembers .. ")", 0.8, 0.8, 0.6))
                                    subHdr:Show()
                                    yOffset = yOffset - 14
                                    for _, member in ipairs(subMembers) do
                                        RenderMember(member)
                                    end
                                end
                            end
                        else
                            for _, member in ipairs(groupMembers) do
                                RenderMember(member)
                            end
                        end
                    end
                end
            end
        end
    end

    if not hasAnyMembers then
        rowIdx = rowIdx + 1
        local row = GetOrCreateRow(sc, rowIdx)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, yOffset)

        row:SetWidth(innerWidth)
        row.nameText:SetWidth(nameW)
        row.zoneText:SetWidth(zoneW)
        row.noteText:SetWidth(noteW)

        row.memberData = nil
        row.nameText:SetText("|cff888888No community members online|r")
        row.levelText:SetText("")
        row.scoreText:SetText("")
        row.scoreText:SetWidth(scoreW)
        row.zoneText:SetText("")
        row.noteText:SetText("")
        yOffset = yOffset - rowStep
    end

    -- Finalize scroll layout
    local contentH = math.max(math.abs(yOffset), ns.ROW_HEIGHT)
    tooltipFrame:FinalizeLayout(tooltipWidth, contentH)
end

---------------------------------------------------------------------------
-- Group headers (community names)
---------------------------------------------------------------------------

function CommunitiesBroker:GetOrCreateGroupHeader(parent, name)
    return DDT:GetOrCreateGroupHeader(parent, name)
end

function CommunitiesBroker:BuildGroups(members, groupBy)
    return DDT:BuildGroups(members, groupBy, function(member, mode)
        if mode == "community" then
            return { member.clubName or "Unknown" }
        end
    end)
end

---------------------------------------------------------------------------
-- Tooltip hide timer
---------------------------------------------------------------------------

CommunitiesBroker.hideTimer = nil

function CommunitiesBroker:StartTooltipHideTimer()
    self:CancelTooltipHideTimer()
    self.hideTimer = C_Timer.NewTimer(ns.HIDE_DELAY, function()
        if tooltipFrame then tooltipFrame:Hide() end
        self.hideTimer = nil
    end)
end

function CommunitiesBroker:CancelTooltipHideTimer()
    if self.hideTimer then
        self.hideTimer:Cancel()
        self.hideTimer = nil
    end
end

---------------------------------------------------------------------------
-- Click action handling
---------------------------------------------------------------------------

function CommunitiesBroker:OnRowClick(row, button)
    local member = row.memberData
    if not member then return end

    local action = DDT:ResolveClickAction(button, ns.db.communities.rowClickActions or {})
    if action and action ~= "none" then
        self:ExecuteAction(action, member)
    end
end

function CommunitiesBroker:ExecuteAction(action, member)
    self:CancelTooltipHideTimer()
    local realmName = member.fullName and member.fullName:match("%-(.+)$") or GetRealmName()
    DDT:ExecuteAction(action, member.name, realmName, member.fullName or member.name, nil, tooltipFrame)
end

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------

CommunitiesBroker.settingsLabel = "Communities"

function CommunitiesBroker:BuildSettingsPanel(panel)
    local W = ns.SettingsWidgets
    local r = panel.refreshCallbacks
    local db = function() return ns.db.communities end
    local refresh = function() self:UpdateData() end

    -- Label Template
    W.AddLabelEditBox(panel, "online",
        function() return db().labelFormat end,
        function(v) db().labelFormat = v; refresh() end, r, {
        { "Default",  "Communities: <online>" },
        { "Short",    "Comm: <online>" },
        { "Labeled",  "<online> online" },
    })

    -- Tooltip (collapsed)
    local body = W.AddSection(panel, "Tooltip", true)
    local y = 0
    y = W.AddSliderPair(body, y,
        { label = "Scale", min = 0.5, max = 2.0, step = 0.05,
          get = function() return db().tooltipScale end,
          set = function(v) db().tooltipScale = v end },
        { label = "Width", min = 300, max = 800, step = 10,
          get = function() return db().tooltipWidth end,
          set = function(v) db().tooltipWidth = v end }, r)
    y = W.AddSliderPair(body, y,
        { label = "Row Spacing", min = 0, max = 16, step = 1,
          get = function() return db().rowSpacing end,
          set = function(v) db().rowSpacing = v end },
        { label = "Max Height", min = 100, max = 1000, step = 10,
          get = function() return db().tooltipMaxHeight end,
          set = function(v) db().tooltipMaxHeight = v end }, r)
    y = W.AddTooltipGrowDirection(body, y, db, r)
    y = W.AddTooltipCopyFrom(body, y, "communities", db, r)
    W.EndSection(panel, y)

    -- Display
    body = W.AddSection(panel, "Display")
    y = 0
    y = W.AddCheckboxPair(body, y, "Class-Colored Names",
        function() return db().classColorNames end,
        function(v) db().classColorNames = v; refresh() end,
        "Show Hint Bar",
        function() return db().showHintBar end,
        function(v) db().showHintBar = v; refresh() end, r)
    W.EndSection(panel, y)

    -- Grouping & Sorting
    body = W.AddSection(panel, "Grouping & Sorting")
    y = 0
    y = W.AddDropdown(body, y, "Group By", ns.COMMUNITIES_GROUP_VALUES,
        function() return db().groupBy end,
        function(v) db().groupBy = v; refresh() end, r)
    y = W.AddDropdown(body, y, "Then By", ns.COMMUNITIES_GROUP_VALUES,
        function() return db().groupBy2 end,
        function(v) db().groupBy2 = v; refresh() end, r)
    y = W.AddDropdown(body, y, "Sort By", { name = "Name", class = "Class", level = "Level", zone = "Zone", status = "Status" },
        function() return db().sortBy end,
        function(v) db().sortBy = v; refresh() end, r)
    y = W.AddCheckbox(body, y, "Ascending Order",
        function() return db().sortAscending end,
        function(v) db().sortAscending = v; refresh() end, r)
    W.EndSection(panel, y)

    -- Label Click Actions (collapsed)
    ns.AddModuleClickActionsSection(panel, r, "communities", ns.SOCIAL_LABEL_ACTION_VALUES)

    -- Row Click Actions (collapsed)
    ns.AddClickActionsSection(panel, r, "communities")

    -- Social Settings (collapsed)
    ns.AddSocialSettingsSection(panel, r)

    -- Enabled Communities (dynamic section)
    body = W.AddSection(panel, "Enabled Communities")
    y = 0
    y = W.AddDescription(body, y, "Uncheck a community to hide it from the tooltip. New communities are shown by default.")

    local dynamicSection = panel.currentSection
    local dynamicStart = y
    local dynamicWidgets = {}

    local function RebuildClubList()
        for _, widget in ipairs(dynamicWidgets) do
            widget:Hide()
            widget:SetParent(nil)
        end
        wipe(dynamicWidgets)

        local dy = dynamicStart
        local clubs = C_Club.GetSubscribedClubs()
        if type(clubs) ~= "table" then clubs = {} end

        local communityClubs = {}
        for _, clubInfo in ipairs(clubs) do
            if type(clubInfo.name) == "string"
               and (clubInfo.clubType == Enum.ClubType.Character or clubInfo.clubType == Enum.ClubType.BattleNet) then
                table.insert(communityClubs, clubInfo)
            end
        end
        table.sort(communityClubs, function(a, b) return (a.name or "") < (b.name or "") end)

        if #communityClubs == 0 then
            local noClubs = body:CreateFontString(nil, "OVERLAY", "GameFontDisable")
            noClubs:SetPoint("TOPLEFT", body, "TOPLEFT", 18, dy)
            noClubs:SetText("No communities found.")
            table.insert(dynamicWidgets, noClubs)
            dy = dy - 20
        else
            for _, clubInfo in ipairs(communityClubs) do
                local cb = CreateFrame("CheckButton", nil, body, "UICheckButtonTemplate")
                cb:SetPoint("TOPLEFT", body, "TOPLEFT", 14, dy)

                local cbText = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                cbText:SetPoint("LEFT", cb, "RIGHT", 2, 0)
                cbText:SetText(clubInfo.name)

                local clubId = clubInfo.clubId
                cb:SetChecked(not ns.db.communities.disabledClubs[clubId])
                cb:SetScript("OnClick", function(self)
                    if self:GetChecked() then
                        ns.db.communities.disabledClubs[clubId] = nil
                    else
                        ns.db.communities.disabledClubs[clubId] = true
                    end
                    refresh()
                end)

                table.insert(dynamicWidgets, cb)
                table.insert(dynamicWidgets, cbText)
                dy = dy - 26
            end
        end

        dynamicSection.bodyHeight = math.abs(dy) + 8
        dynamicSection.body:SetHeight(dynamicSection.bodyHeight)
        dynamicSection:UpdateLayout()
    end

    RebuildClubList()
    panel.currentSection = nil  -- manual EndSection since height is dynamic

    panel:HookScript("OnShow", function()
        RebuildClubList()
    end)
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("communities", CommunitiesBroker, DEFAULTS)
