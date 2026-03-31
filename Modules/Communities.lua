local addonName, ns = ...
local DDT = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local CommunitiesBroker = {}
ns.CommunitiesBroker = CommunitiesBroker

CommunitiesBroker.clubsCache = {}   -- { clubId = { info=ClubInfo, members={...} } }
CommunitiesBroker.onlineCount = 0
CommunitiesBroker.totalOnline = 0

local tooltipFrame = nil
local rowPool = {}
local ROW_HEIGHT      = ns.ROW_HEIGHT
local TOOLTIP_PADDING = ns.TOOLTIP_PADDING
local HEADER_HEIGHT   = ns.HEADER_HEIGHT
local FIXED_TOP       = ns.FIXED_TOP
local FIXED_BOTTOM    = ns.FIXED_BOTTOM

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
        if button == "LeftButton" and IsShiftKeyDown() then
            ToggleCommunitiesFrame()
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
                        name        = displayName,
                        fullName    = memberName,
                        level       = mInfo.level or 0,
                        classFile   = classFile,
                        area        = mInfo.zone or "",
                        notes       = mInfo.memberNote or "",
                        afk         = (mInfo.presence == Enum.ClubMemberPresence.Away),
                        dnd         = (mInfo.presence == Enum.ClubMemberPresence.Busy),
                        isMobile    = (mInfo.presence == Enum.ClubMemberPresence.OnlineMobile),
                        isSelf      = mInfo.isSelf,
                        clubId      = clubInfo.clubId,
                        clubName    = clubInfo.name or "Unknown",
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

---------------------------------------------------------------------------
-- Tooltip frame creation
---------------------------------------------------------------------------

local function CreateTooltipFrame()
    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetFrameStrata("TOOLTIP")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetSize(420, 100)

    f:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true,
        tileSize = 16,
        edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.92)
    f:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)

    f.header = f:CreateFontString(nil, "OVERLAY", "DDTFontHeader")
    f.header:SetPoint("TOPLEFT", f, "TOPLEFT", TOOLTIP_PADDING, -TOOLTIP_PADDING)
    f.header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -TOOLTIP_PADDING, -TOOLTIP_PADDING)
    f.header:SetJustifyH("LEFT")
    f.header:SetHeight(HEADER_HEIGHT)

    -- Column headers
    f.colName = f:CreateFontString(nil, "OVERLAY", "DDTFontNormal")
    f.colName:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 0, -4)
    f.colName:SetText("|cffaaaaaaName|r")
    f.colName:SetJustifyH("LEFT")

    f.colLevel = f:CreateFontString(nil, "OVERLAY", "DDTFontNormal")
    f.colLevel:SetPoint("LEFT", f.colName, "RIGHT", 4, 0)
    f.colLevel:SetText("|cffaaaaaaLvl|r")
    f.colLevel:SetWidth(30)
    f.colLevel:SetJustifyH("CENTER")

    f.colZone = f:CreateFontString(nil, "OVERLAY", "DDTFontNormal")
    f.colZone:SetPoint("LEFT", f.colLevel, "RIGHT", 4, 0)
    f.colZone:SetText("|cffaaaaaaZone|r")
    f.colZone:SetJustifyH("LEFT")

    f.colNote = f:CreateFontString(nil, "OVERLAY", "DDTFontNormal")
    f.colNote:SetPoint("LEFT", f.colZone, "RIGHT", 4, 0)
    f.colNote:SetPoint("RIGHT", f, "RIGHT", -TOOLTIP_PADDING, 0)
    f.colNote:SetText("|cffaaaaaaNotes|r")
    f.colNote:SetJustifyH("LEFT")

    f.hint = f:CreateFontString(nil, "OVERLAY", "DDTFontSmall")
    f.hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", TOOLTIP_PADDING, TOOLTIP_PADDING)
    f.hint:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -TOOLTIP_PADDING, TOOLTIP_PADDING)
    f.hint:SetJustifyH("LEFT")

    -- Scrollable content area (clip frame + content frame)
    f.clipFrame = CreateFrame("Frame", nil, f)
    f.clipFrame:SetClipsChildren(true)
    f.scrollContent = CreateFrame("Frame", nil, f.clipFrame)
    f.scrollOffset = 0

    -- Scrollbar track and thumb
    f.scrollTrack = f:CreateTexture(nil, "ARTWORK")
    f.scrollTrack:SetPoint("TOPLEFT", f.clipFrame, "TOPRIGHT", 2, 0)
    f.scrollTrack:SetPoint("BOTTOMLEFT", f.clipFrame, "BOTTOMRIGHT", 2, 0)
    f.scrollTrack:SetWidth(4)
    f.scrollTrack:SetColorTexture(1, 1, 1, 0.08)
    f.scrollTrack:Hide()

    f.scrollThumb = f:CreateTexture(nil, "OVERLAY")
    f.scrollThumb:SetWidth(4)
    f.scrollThumb:SetColorTexture(0.8, 0.8, 0.8, 0.4)
    f.scrollThumb:Hide()

    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(self, delta)
        local contentH = self.scrollContent:GetHeight() or 0
        local clipH = self.clipFrame:GetHeight() or 0
        local maxScroll = math.max(0, contentH - clipH)
        self.scrollOffset = math.max(0, math.min(maxScroll, self.scrollOffset - delta * (ROW_HEIGHT + 4)))
        self.scrollContent:ClearAllPoints()
        self.scrollContent:SetPoint("TOPLEFT", self.clipFrame, "TOPLEFT", 0, self.scrollOffset)
        DDT:UpdateScrollbar(self)
    end)

    f:SetScript("OnEnter", function()
        CommunitiesBroker:CancelTooltipHideTimer()
    end)
    f:SetScript("OnLeave", function()
        CommunitiesBroker:StartTooltipHideTimer()
    end)

    f:Hide()
    return f
end



local function GetOrCreateRow(parent, index)
    if rowPool[index] then
        rowPool[index]:Show()
        return rowPool[index]
    end

    local row = CreateFrame("Button", nil, parent)
    row:SetSize(360, ROW_HEIGHT)
    row:EnableMouse(true)
    row:RegisterForClicks("AnyUp")

    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, 0.1)

    row.nameText = row:CreateFontString(nil, "OVERLAY", "DDTFontNormal")
    row.nameText:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.nameText:SetWidth(130)
    row.nameText:SetJustifyH("LEFT")

    row.levelText = row:CreateFontString(nil, "OVERLAY", "DDTFontNormal")
    row.levelText:SetPoint("LEFT", row.nameText, "RIGHT", 4, 0)
    row.levelText:SetWidth(30)
    row.levelText:SetJustifyH("CENTER")

    row.zoneText = row:CreateFontString(nil, "OVERLAY", "DDTFontNormal")
    row.zoneText:SetPoint("LEFT", row.levelText, "RIGHT", 4, 0)
    row.zoneText:SetWidth(130)
    row.zoneText:SetJustifyH("LEFT")

    row.noteText = row:CreateFontString(nil, "OVERLAY", "DDTFontSmall")
    row.noteText:SetPoint("LEFT", row.zoneText, "RIGHT", 4, 0)
    row.noteText:SetJustifyH("LEFT")
    row.noteText:SetWordWrap(false)

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

    tooltipFrame:ClearAllPoints()
    tooltipFrame:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 4)
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
    local zoneW = math.floor(innerWidth * 0.28)
    local noteW = math.max(50, innerWidth - nameW - levelW - zoneW - 12)

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
        tooltipFrame.hint:SetText(DDT:BuildHintText(db.clickActions))
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
    local rowStep = ROW_HEIGHT + rowSpacing
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
        row.zoneText:SetWidth(zoneW)
        row.noteText:SetWidth(noteW)

        row.memberData = member

        local status = ""
        if member.afk then
            status = "|cffffcc00[AFK]|r "
        elseif member.dnd then
            status = "|cffff0000[DND]|r "
        end

        if useClassColors and member.classFile then
            row.nameText:SetText(status .. DDT:ClassColorText(member.name, member.classFile))
        else
            row.nameText:SetText(status .. member.name)
        end

        row.levelText:SetText(member.level > 0 and tostring(member.level) or "")
        row.zoneText:SetText(DDT:ColorText(member.area, 0.63, 0.82, 1))
        row.noteText:SetText(member.notes or "")

        yOffset = yOffset - rowStep
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
        row.zoneText:SetText("")
        row.noteText:SetText("")
        yOffset = yOffset - rowStep
    end

    -- Scroll geometry
    local fixedBottom = showHint and FIXED_BOTTOM or (TOOLTIP_PADDING + 4)
    local contentH = math.max(math.abs(yOffset), ROW_HEIGHT)
    local maxH = ns.db.communities.tooltipMaxHeight or 500
    local innerWidth = (ns.db.communities.tooltipWidth or 480) - 2 * TOOLTIP_PADDING
    local scrollAreaH = math.min(contentH, math.max(ROW_HEIGHT, maxH - FIXED_TOP - fixedBottom))

    tooltipFrame.clipFrame:ClearAllPoints()
    tooltipFrame.clipFrame:SetPoint("TOPLEFT", tooltipFrame, "TOPLEFT", TOOLTIP_PADDING, -FIXED_TOP)
    tooltipFrame.clipFrame:SetSize(innerWidth, scrollAreaH)
    tooltipFrame.scrollContent:SetSize(innerWidth, contentH)
    tooltipFrame.scrollOffset = 0
    tooltipFrame.scrollContent:ClearAllPoints()
    tooltipFrame.scrollContent:SetPoint("TOPLEFT", tooltipFrame.clipFrame, "TOPLEFT", 0, 0)
    tooltipFrame:SetHeight(FIXED_TOP + scrollAreaH + fixedBottom)
    DDT:UpdateScrollbar(tooltipFrame)
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

    local action = DDT:ResolveClickAction(button, ns.db.communities.clickActions)
    if action and action ~= "none" then
        self:ExecuteAction(action, member)
    end
end

function CommunitiesBroker:ExecuteAction(action, member)
    self:CancelTooltipHideTimer()
    local realmName = member.fullName and member.fullName:match("%-(.+)$") or GetRealmName()
    DDT:ExecuteAction(action, member.name, realmName, member.fullName or member.name, nil, tooltipFrame)
end
