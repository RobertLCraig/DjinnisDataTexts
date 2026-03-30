local addonName, ns = ...
local DDT = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local GuildBroker = {}
ns.GuildBroker = GuildBroker

GuildBroker.guildCache = {}
GuildBroker.onlineCount = 0
GuildBroker.totalCount = 0
GuildBroker.guildName = ""

local tooltipFrame = nil
local rowPool = {}
local ROW_HEIGHT      = ns.ROW_HEIGHT
local TOOLTIP_PADDING = ns.TOOLTIP_PADDING
local HEADER_HEIGHT   = ns.HEADER_HEIGHT
local FIXED_TOP       = ns.FIXED_TOP
local FIXED_BOTTOM    = ns.FIXED_BOTTOM

local STATUS_STRINGS = {
    [0] = "",
    [1] = "|cffffcc00[AFK]|r ",
    [2] = "|cffff0000[DND]|r ",
}

local MOBILE_ICON = "|TInterface\\ChatFrame\\UI-ChatIcon-ArmoryChat:14|t "

---------------------------------------------------------------------------
-- LDB Data Object
---------------------------------------------------------------------------

local dataobj = LDB:NewDataObject("DDT-Guild", {
    type  = "data source",
    text  = "Guild: 0/0",
    icon  = "Interface\\GossipFrame\\TabardGossipIcon",
    label = "Guild",
    OnEnter = function(self)
        GuildBroker:ShowTooltip(self)
    end,
    OnLeave = function(self)
        GuildBroker:StartTooltipHideTimer()
    end,
    OnClick = function(self, button)
        if button == "LeftButton" and IsShiftKeyDown() then
            ToggleGuildFrame()
        end
    end,
})

GuildBroker.dataobj = dataobj

---------------------------------------------------------------------------
-- Event handling
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

function GuildBroker:Init()
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            GuildBroker:OnPlayerEnteringWorld()
        else
            GuildBroker:OnGuildUpdate()
        end
    end)
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
    eventFrame:RegisterEvent("GUILD_MOTD")
end

function GuildBroker:OnPlayerEnteringWorld()
    if IsInGuild() then
        C_GuildInfo.GuildRoster()
        C_Timer.After(3, function()
            self:UpdateData()
        end)
    end
end

function GuildBroker:OnGuildUpdate()
    self:UpdateData()
end

---------------------------------------------------------------------------
-- Data collection
---------------------------------------------------------------------------

function GuildBroker:UpdateData()
    if not IsInGuild() then
        self.guildCache = {}
        self.onlineCount = 0
        self.totalCount = 0
        self.guildName = ""
        dataobj.text = "No Guild"
        return
    end

    local db = ns.db.guild
    local members = {}

    local guildClubId = C_Club.GetGuildClubId()
    if not guildClubId then
        -- Guild club data not yet loaded; keep previous state
        return
    end

    -- Guild name from club info
    local clubInfo = C_Club.GetClubInfo(guildClubId)
    if type(clubInfo) == "table" and type(clubInfo.name) == "string" then
        self.guildName = clubInfo.name
    end

    -- Get all member IDs
    -- C_Club.GetClubMembers returns a Blizzard "secret table" — using # on it
    -- causes taint. Use clubInfo.memberCount for totalCount and iterate with
    -- ipairs (which handles secret tables without taint).
    local memberIds = C_Club.GetClubMembers(guildClubId)

    self.totalCount = (type(clubInfo) == "table" and clubInfo.memberCount) or 0

    local onlineCount = 0
    for _, memberId in ipairs(memberIds or {}) do
        local mInfo = C_Club.GetMemberInfo(guildClubId, memberId)
        if type(mInfo) == "table" and type(mInfo.name) == "string" then
            local presence = mInfo.presence or Enum.ClubMemberPresence.Offline
            local isOnline = (presence ~= Enum.ClubMemberPresence.Offline
                          and presence ~= Enum.ClubMemberPresence.Unknown)

            if isOnline then
                onlineCount = onlineCount + 1

                local classFile = ""
                if mInfo.classID then
                    local cInfo = C_CreatureInfo.GetClassInfo(mInfo.classID)
                    if cInfo then classFile = cInfo.classFile or "" end
                end

                local isMobile = (presence == Enum.ClubMemberPresence.OnlineMobile)
                local isAFK = (presence == Enum.ClubMemberPresence.Away)
                local isDND = (presence == Enum.ClubMemberPresence.Busy)
                local status = isAFK and 1 or isDND and 2 or 0

                local zone = ""
                if type(mInfo.zone) == "string" then
                    zone = mInfo.zone
                end
                if isMobile and mInfo.isRemoteChat then
                    zone = "Remote Chat"
                end

                table.insert(members, {
                    name      = mInfo.name,
                    level     = mInfo.level or 0,
                    classFile = classFile,
                    area      = zone,
                    rank      = mInfo.guildRank or "",
                    rankIndex = mInfo.guildRankOrder or 0,
                    connected = not isMobile,
                    isMobile  = isMobile,
                    status    = status,
                    afk       = isAFK,
                    dnd       = isDND,
                    notes     = mInfo.memberNote or "",
                    officerNote = mInfo.officerNote or "",
                    fullName  = mInfo.name,
                })
            end
        end
    end

    self.onlineCount = onlineCount

    self:SortMembers(members)
    self.guildCache = members

    dataobj.text = DDT:FormatLabel(db.labelFormat, self.onlineCount, self.totalCount, { guildname = self.guildName })

    if tooltipFrame and tooltipFrame:IsShown() then
        self:PopulateTooltip()
    end
end

---------------------------------------------------------------------------
-- Sorting
---------------------------------------------------------------------------

function GuildBroker:SortMembers(members)
    DDT:SortList(members, ns.db.guild)
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

    f.header = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.header:SetPoint("TOPLEFT", f, "TOPLEFT", TOOLTIP_PADDING, -TOOLTIP_PADDING)
    f.header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -TOOLTIP_PADDING, -TOOLTIP_PADDING)
    f.header:SetJustifyH("LEFT")
    f.header:SetHeight(HEADER_HEIGHT)

    f.motd = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.motd:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 0, -2)
    f.motd:SetPoint("TOPRIGHT", f.header, "BOTTOMRIGHT", 0, -2)
    f.motd:SetJustifyH("LEFT")
    f.motd:SetWordWrap(true)
    f.motd:SetMaxLines(2)

    f.colName = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.colName:SetText("|cffaaaaaaName|r")
    f.colName:SetJustifyH("LEFT")

    f.colLevel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.colLevel:SetText("|cffaaaaaaLvl|r")
    f.colLevel:SetWidth(30)
    f.colLevel:SetJustifyH("CENTER")

    f.colRank = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.colRank:SetText("|cffaaaaaaRank|r")
    f.colRank:SetJustifyH("LEFT")

    f.colZone = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.colZone:SetText("|cffaaaaaaZone|r")
    f.colZone:SetJustifyH("LEFT")

    f.colNote = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.colNote:SetPoint("RIGHT", f, "RIGHT", -TOOLTIP_PADDING, 0)
    f.colNote:SetText("|cffaaaaaaNotes|r")
    f.colNote:SetJustifyH("LEFT")

    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
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
        GuildBroker:CancelTooltipHideTimer()
    end)
    f:SetScript("OnLeave", function()
        GuildBroker:StartTooltipHideTimer()
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
    row:SetSize(400, ROW_HEIGHT)
    row:EnableMouse(true)
    row:RegisterForClicks("AnyUp")

    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, 0.1)

    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.nameText:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.nameText:SetWidth(130)
    row.nameText:SetJustifyH("LEFT")

    row.levelText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.levelText:SetPoint("LEFT", row.nameText, "RIGHT", 4, 0)
    row.levelText:SetWidth(30)
    row.levelText:SetJustifyH("CENTER")

    row.rankText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.rankText:SetPoint("LEFT", row.levelText, "RIGHT", 4, 0)
    row.rankText:SetWidth(70)
    row.rankText:SetJustifyH("LEFT")

    row.zoneText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.zoneText:SetPoint("LEFT", row.rankText, "RIGHT", 4, 0)
    row.zoneText:SetWidth(100)
    row.zoneText:SetJustifyH("LEFT")

    row.noteText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.noteText:SetPoint("LEFT", row.zoneText, "RIGHT", 4, 0)
    row.noteText:SetJustifyH("LEFT")
    row.noteText:SetWordWrap(false)

    row:SetScript("OnMouseUp", function(self, button)
        GuildBroker:OnRowClick(self, button)
    end)

    row:SetScript("OnEnter", function(self)
        GuildBroker:CancelTooltipHideTimer()
        if self.memberData then
            local hasNote = self.memberData.notes and self.memberData.notes ~= ""
            local hasONote = self.memberData.officerNote and self.memberData.officerNote ~= ""
            if hasNote or hasONote then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if hasNote then
                    GameTooltip:AddLine("Note: " .. self.memberData.notes, 1, 1, 1, true)
                end
                if hasONote then
                    GameTooltip:AddLine("Officer: " .. self.memberData.officerNote, 1, 0.5, 0, true)
                end
                GameTooltip:Show()
            end
        end
    end)

    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
        GuildBroker:StartTooltipHideTimer()
    end)

    rowPool[index] = row
    return row
end

---------------------------------------------------------------------------
-- Tooltip display
---------------------------------------------------------------------------

function GuildBroker:ShowTooltip(anchor)
    if not tooltipFrame then
        tooltipFrame = CreateTooltipFrame()
    end

    self:CancelTooltipHideTimer()

    if IsInGuild() then
        C_GuildInfo.GuildRoster()
    end
    self:UpdateData()

    tooltipFrame:ClearAllPoints()
    tooltipFrame:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 4)
    tooltipFrame:SetScale(ns.db.guild.tooltipScale or 1.0)

    self:PopulateTooltip()
    tooltipFrame:Show()
end

function GuildBroker:PopulateTooltip()
    if not tooltipFrame then return end

    local members = self.guildCache
    local db = ns.db.guild
    local useClassColors = db.classColorNames

    local tooltipWidth = db.tooltipWidth or 480
    local innerWidth = tooltipWidth - 2 * TOOLTIP_PADDING
    local nameW = math.floor(innerWidth * 0.25)
    local levelW = 30
    local rankW = math.floor(innerWidth * 0.15)
    local zoneW = math.floor(innerWidth * 0.22)
    local noteW = math.max(50, innerWidth - nameW - levelW - rankW - zoneW - 16)

    tooltipFrame:SetWidth(tooltipWidth)
    tooltipFrame.colName:SetWidth(nameW)
    tooltipFrame.colRank:SetWidth(rankW)
    tooltipFrame.colZone:SetWidth(zoneW)

    local sc = tooltipFrame.scrollContent

    tooltipFrame.header:SetText(
        DDT:ColorText(self.guildName .. "  ", 0.4, 0.78, 1) ..
        DDT:ColorText(tostring(self.onlineCount), 0, 1, 0) ..
        DDT:ColorText(" / " .. tostring(self.totalCount), 0.63, 0.63, 0.63)
    )

    local motd = C_GuildInfo.GetMOTD() or ""
    if motd ~= "" then
        tooltipFrame.motd:SetText("|cff888888MOTD: " .. motd .. "|r")
        tooltipFrame.motd:Show()
    else
        tooltipFrame.motd:SetText("")
        tooltipFrame.motd:Hide()
    end

    local motdHeight = 0
    if motd ~= "" then
        motdHeight = tooltipFrame.motd:GetStringHeight() + 4
    end

    -- fixedTop is dynamic based on MOTD presence
    local fixedTop = TOOLTIP_PADDING + HEADER_HEIGHT + motdHeight + 4 + 16

    local colY = -(TOOLTIP_PADDING + HEADER_HEIGHT + motdHeight + 4)
    tooltipFrame.colName:ClearAllPoints()
    tooltipFrame.colName:SetPoint("TOPLEFT", tooltipFrame, "TOPLEFT", TOOLTIP_PADDING, colY)
    tooltipFrame.colLevel:ClearAllPoints()
    tooltipFrame.colLevel:SetPoint("LEFT", tooltipFrame.colName, "RIGHT", 4, 0)
    tooltipFrame.colRank:ClearAllPoints()
    tooltipFrame.colRank:SetPoint("LEFT", tooltipFrame.colLevel, "RIGHT", 4, 0)
    tooltipFrame.colZone:ClearAllPoints()
    tooltipFrame.colZone:SetPoint("LEFT", tooltipFrame.colRank, "RIGHT", 4, 0)
    tooltipFrame.colNote:ClearAllPoints()
    tooltipFrame.colNote:SetPoint("LEFT", tooltipFrame.colZone, "RIGHT", 4, 0)

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
    local groupBy = db.groupBy or "none"
    local groups, groupOrder = self:BuildGroups(members, groupBy)

    local yOffset = 0
    local rowIdx = 0

    local function RenderMember(member)
        rowIdx = rowIdx + 1
        local row = GetOrCreateRow(sc, rowIdx)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, yOffset)

        row:SetWidth(innerWidth)
        row.nameText:SetWidth(nameW)
        row.rankText:SetWidth(rankW)
        row.zoneText:SetWidth(zoneW)
        row.noteText:SetWidth(noteW)

        row.memberData = member

        local status = STATUS_STRINGS[member.status] or ""
        if member.isMobile and not member.connected then
            status = MOBILE_ICON
        end

        local displayName = member.name
        local dashPos = displayName:find("-")
        if dashPos then
            displayName = displayName:sub(1, dashPos - 1)
        end

        if useClassColors and member.classFile then
            row.nameText:SetText(status .. DDT:ClassColorText(displayName, member.classFile))
        else
            row.nameText:SetText(status .. displayName)
        end

        row.levelText:SetText(member.level > 0 and tostring(member.level) or "")
        row.rankText:SetText(DDT:ColorText(member.rank, 0.7, 0.7, 0.7))
        row.zoneText:SetText(DDT:ColorText(member.area, 0.63, 0.82, 1))

        local noteDisplay = member.notes or ""
        if db.showOfficerNotes and member.officerNote and member.officerNote ~= "" then
            if noteDisplay ~= "" then
                noteDisplay = noteDisplay .. " |cffff8000[" .. member.officerNote .. "]|r"
            else
                noteDisplay = "|cffff8000" .. member.officerNote .. "|r"
            end
        end
        row.noteText:SetText(noteDisplay)

        yOffset = yOffset - rowStep
    end

    if groupBy == "none" then
        for _, member in ipairs(members) do
            RenderMember(member)
        end
    else
        local groupBy2 = db.groupBy2 or "none"
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

    if #members == 0 then
        rowIdx = rowIdx + 1
        local row = GetOrCreateRow(sc, rowIdx)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, yOffset)

        row:SetWidth(innerWidth)
        row.nameText:SetWidth(nameW)
        row.rankText:SetWidth(rankW)
        row.zoneText:SetWidth(zoneW)
        row.noteText:SetWidth(noteW)

        row.memberData = nil
        row.nameText:SetText("|cff888888No guild members online|r")
        row.levelText:SetText("")
        row.rankText:SetText("")
        row.zoneText:SetText("")
        row.noteText:SetText("")
        yOffset = yOffset - rowStep
    end

    -- Scroll geometry
    local fixedBottom = showHint and FIXED_BOTTOM or (TOOLTIP_PADDING + 4)
    local contentH = math.max(math.abs(yOffset), ROW_HEIGHT)
    local maxH = ns.db.guild.tooltipMaxHeight or 500
    local innerWidth = (ns.db.guild.tooltipWidth or 480) - 2 * TOOLTIP_PADDING
    local scrollAreaH = math.min(contentH, math.max(ROW_HEIGHT, maxH - fixedTop - fixedBottom))

    tooltipFrame.clipFrame:ClearAllPoints()
    tooltipFrame.clipFrame:SetPoint("TOPLEFT", tooltipFrame, "TOPLEFT", TOOLTIP_PADDING, -fixedTop)
    tooltipFrame.clipFrame:SetSize(innerWidth, scrollAreaH)
    tooltipFrame.scrollContent:SetSize(innerWidth, contentH)
    tooltipFrame.scrollOffset = 0
    tooltipFrame.scrollContent:ClearAllPoints()
    tooltipFrame.scrollContent:SetPoint("TOPLEFT", tooltipFrame.clipFrame, "TOPLEFT", 0, 0)
    tooltipFrame:SetHeight(fixedTop + scrollAreaH + fixedBottom)
    DDT:UpdateScrollbar(tooltipFrame)
end

---------------------------------------------------------------------------
-- Grouping
---------------------------------------------------------------------------

function GuildBroker:GetOrCreateGroupHeader(parent, name)
    return DDT:GetOrCreateGroupHeader(parent, name)
end

function GuildBroker:BuildGroups(members, groupBy)
    local groups, order = DDT:BuildGroups(members, groupBy, function(member, mode)
        if mode == "rank" then
            return { member.rank or "Unknown" }
        elseif mode == "level" then
            local lvl = member.level or 0
            local bracket
            if     lvl >= 90 then bracket = "90+"
            elseif lvl >= 80 then bracket = "80-89"
            elseif lvl >= 70 then bracket = "70-79"
            elseif lvl >= 60 then bracket = "60-69"
            elseif lvl >= 50 then bracket = "50-59"
            elseif lvl >= 40 then bracket = "40-49"
            elseif lvl >= 30 then bracket = "30-39"
            elseif lvl >= 20 then bracket = "20-29"
            elseif lvl >= 10 then bracket = "10-19"
            else                  bracket = "1-9"
            end
            return { bracket }
        end
    end)

    -- Broker-specific sort overrides for rank/level
    if groupBy == "rank" then
        table.sort(order, function(a, b)
            local ai = groups[a][1] and groups[a][1].rankIndex or 99
            local bi = groups[b][1] and groups[b][1].rankIndex or 99
            return ai < bi
        end)
    elseif groupBy == "level" then
        table.sort(order, function(a, b) return a > b end)
    end

    return groups, order
end

---------------------------------------------------------------------------
-- Tooltip hide timer
---------------------------------------------------------------------------

GuildBroker.hideTimer = nil

function GuildBroker:StartTooltipHideTimer()
    self:CancelTooltipHideTimer()
    self.hideTimer = C_Timer.NewTimer(ns.HIDE_DELAY, function()
        if tooltipFrame then tooltipFrame:Hide() end
        self.hideTimer = nil
    end)
end

function GuildBroker:CancelTooltipHideTimer()
    if self.hideTimer then
        self.hideTimer:Cancel()
        self.hideTimer = nil
    end
end

---------------------------------------------------------------------------
-- Click action handling
---------------------------------------------------------------------------

function GuildBroker:OnRowClick(row, button)
    local member = row.memberData
    if not member then return end

    local action = DDT:ResolveClickAction(button, ns.db.guild.clickActions)
    if action and action ~= "none" then
        self:ExecuteAction(action, member)
    end
end

function GuildBroker:ExecuteAction(action, member)
    self:CancelTooltipHideTimer()
    DDT:ExecuteAction(action, member.name, GetRealmName(), member.fullName or member.name, nil, tooltipFrame)
end
