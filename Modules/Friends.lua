local addonName, ns = ...
local DDT = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local FriendsBroker = {}
ns.FriendsBroker = FriendsBroker

FriendsBroker.friendsCache = {}
FriendsBroker.onlineCount = 0
FriendsBroker.totalCount = 0

-- Tooltip frame and row pool
local tooltipFrame = nil
local rowPool = {}
local ROW_HEIGHT      = ns.ROW_HEIGHT
local TOOLTIP_PADDING = ns.TOOLTIP_PADDING
local HEADER_HEIGHT   = ns.HEADER_HEIGHT
local FIXED_TOP       = ns.FIXED_TOP
local FIXED_BOTTOM    = ns.FIXED_BOTTOM

local STATUS_STRINGS = {
    afk = "|cffffcc00[AFK]|r ",
    dnd = "|cffff0000[DND]|r ",
}

local BNET_CLIENT_WOW = "WoW"

-- Build localized class name -> token lookup table
local localizedClassMap = {}
if LOCALIZED_CLASS_NAMES_MALE then
    for token, name in pairs(LOCALIZED_CLASS_NAMES_MALE) do
        if type(name) == "string" and name ~= "" then
            localizedClassMap[name] = token
        end
    end
end
if LOCALIZED_CLASS_NAMES_FEMALE then
    for token, name in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
        if type(name) == "string" and name ~= "" and not localizedClassMap[name] then
            localizedClassMap[name] = token
        end
    end
end

--- Resolve a class token from whatever fields are available
local function ResolveClassToken(classToken, classID, localizedName)
    if type(classToken) == "string" and classToken ~= "" then
        local token = classToken:upper()
        if RAID_CLASS_COLORS[token] then return token end
        if localizedClassMap[classToken] then return localizedClassMap[classToken] end
    end
    if classID and C_CreatureInfo and C_CreatureInfo.GetClassInfo then
        local info = C_CreatureInfo.GetClassInfo(classID)
        if info and info.classFile and RAID_CLASS_COLORS[info.classFile] then
            return info.classFile
        end
    end
    if type(localizedName) == "string" and localizedName ~= "" then
        local token = localizedClassMap[localizedName]
        if token then return token end
    end
    return nil
end

---------------------------------------------------------------------------
-- LDB Data Object
---------------------------------------------------------------------------

local dataobj = LDB:NewDataObject("DDT-Friends", {
    type  = "data source",
    text  = "Friends: 0/0",
    icon  = "Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon",
    label = "DDT - Friends",
    OnEnter = function(self)
        FriendsBroker:ShowTooltip(self)
    end,
    OnLeave = function(self)
        FriendsBroker:StartTooltipHideTimer()
    end,
    OnClick = function(self, button)
        if button == "LeftButton" and IsShiftKeyDown() then
            ToggleFriendsFrame()
        end
    end,
})

FriendsBroker.dataobj = dataobj

---------------------------------------------------------------------------
-- Event handling
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

function FriendsBroker:Init()
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            FriendsBroker:OnPlayerEnteringWorld()
        else
            FriendsBroker:OnFriendsUpdate()
        end
    end)
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("FRIENDLIST_UPDATE")
    eventFrame:RegisterEvent("BN_FRIEND_INFO_CHANGED")
    eventFrame:RegisterEvent("BN_FRIEND_LIST_SIZE_CHANGED")
    eventFrame:RegisterEvent("BN_CONNECTED")
    eventFrame:RegisterEvent("BN_DISCONNECTED")
end

function FriendsBroker:OnPlayerEnteringWorld()
    C_FriendList.ShowFriends()
    C_Timer.After(2, function()
        self:UpdateData()
    end)
end

function FriendsBroker:OnFriendsUpdate()
    self:UpdateData()
end

---------------------------------------------------------------------------
-- Data collection
---------------------------------------------------------------------------

function FriendsBroker:UpdateData()
    local db = ns.db.friends
    local friends = {}

    -- WoW Character Friends
    if db.showWoWFriends then
        local numFriends = C_FriendList.GetNumFriends()
        for i = 1, numFriends do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if info then
                local rawToken = info.classTag or info.classFileName or info.classFile or info.classToken
                local localizedName = info.className or info.classLocalized or info.class or ""
                local classToken = ResolveClassToken(rawToken, info.classID, localizedName)

                table.insert(friends, {
                    name      = info.name or "Unknown",
                    level     = info.level or 0,
                    classFile = classToken,
                    area      = info.area or "",
                    connected = info.connected,
                    afk       = info.afk,
                    dnd       = info.dnd,
                    notes     = info.notes or "",
                    isBNet    = false,
                    fullName  = info.name,
                })
            end
        end
    end

    -- Battle.net Friends
    if db.showBNetFriends then
        local numBNet = BNGetNumFriends()
        for i = 1, numBNet do
            local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
            if accountInfo then
                local gameInfo = accountInfo.gameAccountInfo
                local isWoW = gameInfo and gameInfo.clientProgram == BNET_CLIENT_WOW
                local isOnline = gameInfo and gameInfo.isOnline

                if isWoW and isOnline then
                    local numGameAccounts = C_BattleNet.GetFriendNumGameAccounts(i)
                    if numGameAccounts and numGameAccounts > 1 then
                        for j = 1, numGameAccounts do
                            local gameAccountInfo = C_BattleNet.GetFriendGameAccountInfo(i, j)
                            if gameAccountInfo and gameAccountInfo.clientProgram == BNET_CLIENT_WOW and gameAccountInfo.isOnline then
                                table.insert(friends, self:BuildBNetEntry(accountInfo, gameAccountInfo))
                            end
                        end
                    else
                        table.insert(friends, self:BuildBNetEntry(accountInfo, gameInfo))
                    end
                end
            end
        end
    end

    self:SortFriends(friends)
    self.friendsCache = friends

    local wowOnline = C_FriendList.GetNumOnlineFriends() or 0
    local wowTotal = C_FriendList.GetNumFriends() or 0
    local bnTotal = BNGetNumFriends()  -- first return = total BNet friends
    local bnOnlineInCache = 0
    for _, f in ipairs(friends) do
        if f.isBNet then bnOnlineInCache = bnOnlineInCache + 1 end
    end
    self.onlineCount = wowOnline + bnOnlineInCache
    self.totalCount = wowTotal + (bnTotal or 0)

    dataobj.text = DDT:FormatLabel(db.labelFormat, self.onlineCount, self.totalCount)

    if tooltipFrame and tooltipFrame:IsShown() then
        self:PopulateTooltip()
    end
end

function FriendsBroker:BuildBNetEntry(accountInfo, gameInfo)
    local rawToken = gameInfo.classTag or gameInfo.classFile or gameInfo.classToken
    local className = gameInfo.className or gameInfo.classLocalized or gameInfo.class or ""
    local classToken = ResolveClassToken(rawToken, gameInfo.classID, className)

    local charName = gameInfo.characterName or ""
    local realmName = gameInfo.realmDisplayName or gameInfo.realmName or ""
    local fullName = ""
    if charName ~= "" and realmName ~= "" then
        fullName = charName .. "-" .. realmName
    elseif charName ~= "" then
        fullName = charName
    end

    return {
        name          = charName ~= "" and charName or accountInfo.accountName or "Unknown",
        level         = gameInfo.characterLevel or 0,
        classFile     = classToken,
        area          = gameInfo.areaName or "",
        connected     = true,
        afk           = accountInfo.isAFK or (gameInfo.isGameAFK == true) or false,
        dnd           = accountInfo.isDND or (gameInfo.isGameBusy == true) or false,
        notes         = accountInfo.note or "",
        isBNet        = true,
        accountName   = accountInfo.accountName,
        gameAccountID = gameInfo.gameAccountID,
        realmName     = realmName,
        fullName      = fullName,
        battleTag     = accountInfo.battleTag or "",
    }
end

---------------------------------------------------------------------------
-- Sorting
---------------------------------------------------------------------------

function FriendsBroker:SortFriends(friends)
    DDT:SortList(friends, ns.db.friends)
end

---------------------------------------------------------------------------
-- Tooltip frame creation
---------------------------------------------------------------------------

local function CreateTooltipFrame()
    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetFrameStrata("TOOLTIP")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetSize(400, 100)

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
        FriendsBroker:CancelTooltipHideTimer()
    end)
    f:SetScript("OnLeave", function()
        FriendsBroker:StartTooltipHideTimer()
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
        FriendsBroker:OnRowClick(self, button)
    end)

    row:SetScript("OnEnter", function(self)
        FriendsBroker:CancelTooltipHideTimer()
        if self.friendData and self.friendData.notes and self.friendData.notes ~= "" then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.friendData.notes, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)

    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
        FriendsBroker:StartTooltipHideTimer()
    end)

    rowPool[index] = row
    return row
end

---------------------------------------------------------------------------
-- Tooltip display
---------------------------------------------------------------------------

function FriendsBroker:ShowTooltip(anchor)
    if not tooltipFrame then
        tooltipFrame = CreateTooltipFrame()
    end

    self:CancelTooltipHideTimer()
    self:UpdateData()

    tooltipFrame:ClearAllPoints()
    tooltipFrame:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 4)
    tooltipFrame:SetScale(ns.db.friends.tooltipScale or 1.0)

    self:PopulateTooltip()
    tooltipFrame:Show()
end

function FriendsBroker:PopulateTooltip()
    if not tooltipFrame then return end

    local db = ns.db.friends
    local useClassColors = db.classColorNames

    local tooltipWidth = db.tooltipWidth or 420
    local innerWidth = tooltipWidth - 2 * TOOLTIP_PADDING
    local nameW = math.floor(innerWidth * 0.30)
    local levelW = 30
    local zoneW = math.floor(innerWidth * 0.28)
    local noteW = math.max(50, innerWidth - nameW - levelW - zoneW - 12)

    tooltipFrame:SetWidth(tooltipWidth)
    tooltipFrame.colName:SetWidth(nameW)
    tooltipFrame.colZone:SetWidth(zoneW)

    local sc = tooltipFrame.scrollContent

    tooltipFrame.header:SetText(
        DDT:ColorText("Friends Online: ", 1, 0.82, 0) ..
        DDT:ColorText(tostring(self.onlineCount), 0, 1, 0) ..
        DDT:ColorText(" / " .. tostring(self.totalCount), 0.63, 0.63, 0.63)
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

    local onlineFriends = {}
    for _, f in ipairs(self.friendsCache) do
        if f.connected then
            table.insert(onlineFriends, f)
        end
    end

    local rowSpacing = db.rowSpacing or 4
    local rowStep = ROW_HEIGHT + rowSpacing
    local groupBy = db.groupBy or "none"
    local groups, groupOrder = self:BuildGroups(onlineFriends, groupBy)

    local yOffset = 0
    local rowIdx = 0

    local function RenderFriend(friend)
        rowIdx = rowIdx + 1
        local row = GetOrCreateRow(sc, rowIdx)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, yOffset)

        row:SetWidth(innerWidth)
        row.nameText:SetWidth(nameW)
        row.zoneText:SetWidth(zoneW)
        row.noteText:SetWidth(noteW)

        row.friendData = friend

        local status = ""
        if friend.afk then
            status = STATUS_STRINGS.afk
        elseif friend.dnd then
            status = STATUS_STRINGS.dnd
        end

        local displayName = friend.name
        if friend.isBNet and friend.accountName then
            displayName = displayName .. " |cff82c5ff(" .. friend.accountName .. ")|r"
        end

        if useClassColors and friend.classFile then
            row.nameText:SetText(status .. DDT:ClassColorText(displayName, friend.classFile))
        else
            row.nameText:SetText(status .. displayName)
        end

        row.levelText:SetText(friend.level > 0 and tostring(friend.level) or "")
        row.zoneText:SetText(DDT:ColorText(friend.area, 0.63, 0.82, 1))
        row.noteText:SetText(friend.notes or "")

        yOffset = yOffset - rowStep
    end

    if groupBy == "none" then
        for _, friend in ipairs(onlineFriends) do
            RenderFriend(friend)
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
                                for _, friend in ipairs(subMembers) do
                                    RenderFriend(friend)
                                end
                            end
                        end
                    else
                        for _, friend in ipairs(groupMembers) do
                            RenderFriend(friend)
                        end
                    end
                end
            end
        end
    end

    if #onlineFriends == 0 then
        rowIdx = rowIdx + 1
        local row = GetOrCreateRow(sc, rowIdx)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, yOffset)

        row:SetWidth(innerWidth)
        row.nameText:SetWidth(nameW)
        row.zoneText:SetWidth(zoneW)
        row.noteText:SetWidth(noteW)

        row.friendData = nil
        row.nameText:SetText("|cff888888No friends online|r")
        row.levelText:SetText("")
        row.zoneText:SetText("")
        row.noteText:SetText("")
        yOffset = yOffset - rowStep
    end

    -- Scroll geometry
    local fixedBottom = showHint and FIXED_BOTTOM or (TOOLTIP_PADDING + 4)
    local contentH = math.max(math.abs(yOffset), ROW_HEIGHT)
    local maxH = ns.db.friends.tooltipMaxHeight or 400
    local innerWidth = (ns.db.friends.tooltipWidth or 420) - 2 * TOOLTIP_PADDING
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
-- Grouping
---------------------------------------------------------------------------

function FriendsBroker:GetOrCreateGroupHeader(parent, name)
    return DDT:GetOrCreateGroupHeader(parent, name)
end

function FriendsBroker:BuildGroups(friends, groupBy)
    return DDT:BuildGroups(friends, groupBy, function(member, mode)
        if mode == "type" then
            return { member.isBNet and "Battle.net Friends" or "Character Friends" }
        end
    end)
end

---------------------------------------------------------------------------
-- Tooltip hide timer
---------------------------------------------------------------------------

FriendsBroker.hideTimer = nil

function FriendsBroker:StartTooltipHideTimer()
    self:CancelTooltipHideTimer()
    self.hideTimer = C_Timer.NewTimer(ns.HIDE_DELAY, function()
        if tooltipFrame then tooltipFrame:Hide() end
        self.hideTimer = nil
    end)
end

function FriendsBroker:CancelTooltipHideTimer()
    if self.hideTimer then
        self.hideTimer:Cancel()
        self.hideTimer = nil
    end
end

---------------------------------------------------------------------------
-- Click action handling
---------------------------------------------------------------------------

function FriendsBroker:OnRowClick(row, button)
    local friend = row.friendData
    if not friend then return end

    local action = DDT:ResolveClickAction(button, ns.db.friends.clickActions)
    if action and action ~= "none" then
        self:ExecuteAction(action, friend)
    end
end

function FriendsBroker:ExecuteAction(action, friend)
    self:CancelTooltipHideTimer()

    local charName  = friend.name
    local realmName = friend.realmName
    if (not realmName or realmName == "") and not friend.isBNet then
        realmName = GetRealmName()
    end

    -- For copyname, build the display name with realm
    local fullName = friend.fullName or friend.name
    if action == "copyname" then
        if not friend.isBNet and friend.fullName and friend.fullName ~= "" then
            fullName = friend.fullName
        elseif (friend.realmName or "") ~= "" then
            fullName = charName .. "-" .. friend.realmName
        end
    end

    local bnet = friend.isBNet and {
        accountName   = friend.accountName,
        battleTag     = friend.battleTag,
        gameAccountID = friend.gameAccountID,
    } or nil

    DDT:ExecuteAction(action, charName, realmName, fullName, bnet, tooltipFrame)
end
