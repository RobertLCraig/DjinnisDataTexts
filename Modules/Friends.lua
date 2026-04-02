-- Djinni's Data Texts — Friends
-- Friends list with online/BNet status, game info, and broadcast messages.
local addonName, ns = ...
local DDT = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local FriendsBroker = {}
ns.FriendsBroker = FriendsBroker

local DEFAULTS = {
    labelFormat = "Friends: <online>/<total>",
    sortBy = "name",
    sortAscending = true,
    classColorNames = true,
    showWoWFriends = true,
    showBNetFriends = true,
    showHintBar = true,
    tooltipScale = 1.0,
    tooltipWidth = 420,
    tooltipMaxHeight = 500,
    rowSpacing = 4,
    groupBy = "none",
    groupBy2 = "none",
    groupCollapsed = {},
    clickActions = {
        leftClick       = "openfriends",
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

FriendsBroker.friendsCache = {}
FriendsBroker.onlineCount = 0
FriendsBroker.totalCount = 0

-- Tooltip frame and row pool
local tooltipFrame = nil
local rowPool = {}
local ROW_HEIGHT      = ns.ROW_HEIGHT
local TOOLTIP_PADDING = ns.TOOLTIP_PADDING

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
        local db = ns.db and ns.db.friends or {}
        local action = DDT:ResolveClickAction(button, db.clickActions or {})
        if action == "openfriends" then
            ToggleFriendsFrame()
        elseif action == "openguild" then
            ToggleGuildFrame()
        elseif action == "opencommunities" then
            ToggleCommunitiesFrame()
        elseif action == "opensettings" then
            if DDT.settingsCategoryID then Settings.OpenToCategory(DDT.settingsCategoryID) end
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
                local localizedName = info.className or ""
                local classToken = localizedClassMap[localizedName]

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
    local className = gameInfo.className or ""
    local classToken = ResolveClassToken(nil, gameInfo.classID, className)

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

function FriendsBroker:GetDB()
    return ns.db and ns.db.friends or {}
end

---------------------------------------------------------------------------
-- Tooltip frame creation
---------------------------------------------------------------------------

local function CreateTooltipFrame()
    local f = ns.CreateTooltipFrame(nil, FriendsBroker)

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

    f.colZone = ns.FontString(f, "DDTFontNormal")
    f.colZone:SetPoint("LEFT", f.colLevel, "RIGHT", 4, 0)
    f.colZone:SetText("|cffaaaaaaZone|r")
    f.colZone:SetJustifyH("LEFT")

    f.colNote = ns.FontString(f, "DDTFontNormal")
    f.colNote:SetPoint("LEFT", f.colZone, "RIGHT", 4, 0)
    f.colNote:SetPoint("RIGHT", f, "RIGHT", -TOOLTIP_PADDING, 0)
    f.colNote:SetText("|cffaaaaaaNotes|r")
    f.colNote:SetJustifyH("LEFT")

    f.headerExtra = 18  -- extra space for column headers

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

    row.nameText = ns.FontString(row, "DDTFontNormal")
    row.nameText:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.nameText:SetWidth(130)
    row.nameText:SetJustifyH("LEFT")

    row.levelText = ns.FontString(row, "DDTFontNormal")
    row.levelText:SetPoint("LEFT", row.nameText, "RIGHT", 4, 0)
    row.levelText:SetWidth(30)
    row.levelText:SetJustifyH("CENTER")

    row.zoneText = ns.FontString(row, "DDTFontNormal")
    row.zoneText:SetPoint("LEFT", row.levelText, "RIGHT", 4, 0)
    row.zoneText:SetWidth(130)
    row.zoneText:SetJustifyH("LEFT")

    row.noteText = ns.FontString(row, "DDTFontSmall")
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

    ns.AnchorTooltip(tooltipFrame, anchor, ns.db.friends.tooltipGrowDirection)
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

    local contentH = math.max(math.abs(yOffset), ROW_HEIGHT)
    tooltipFrame:FinalizeLayout(tooltipWidth, contentH)
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

    local action = DDT:ResolveClickAction(button, ns.db.friends.rowClickActions or {})
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

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------

FriendsBroker.settingsLabel = "Friends"

function FriendsBroker:BuildSettingsPanel(panel)
    local W = ns.SettingsWidgets
    local r = panel.refreshCallbacks
    local db = function() return ns.db.friends end
    local refresh = function() self:UpdateData() end

    -- Label Template
    W.AddLabelEditBox(panel, "online total offline",
        function() return db().labelFormat end,
        function(v) db().labelFormat = v; refresh() end, r, {
        { "Default",  "Friends: <online>/<total>" },
        { "Short",    "F: <online>" },
        { "Detailed", "Friends: <online> on / <offline> off" },
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
    y = W.AddTooltipCopyFrom(body, y, "friends", db, r)
    W.EndSection(panel, y)

    -- Display
    body = W.AddSection(panel, "Display")
    y = 0
    y = W.AddCheckboxPair(body, y, "Show Character Friends",
        function() return db().showWoWFriends end,
        function(v) db().showWoWFriends = v; refresh() end,
        "Show Battle.net Friends",
        function() return db().showBNetFriends end,
        function(v) db().showBNetFriends = v; refresh() end, r)
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
    y = W.AddDropdown(body, y, "Group By", ns.FRIENDS_GROUP_VALUES,
        function() return db().groupBy end,
        function(v) db().groupBy = v; refresh() end, r)
    y = W.AddDropdown(body, y, "Then By", ns.FRIENDS_GROUP_VALUES,
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
    ns.AddModuleClickActionsSection(panel, r, "friends", ns.SOCIAL_LABEL_ACTION_VALUES)

    -- Row Click Actions (collapsed)
    ns.AddClickActionsSection(panel, r, "friends")

    -- Social Settings (collapsed)
    ns.AddSocialSettingsSection(panel, r)
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("friends", FriendsBroker, DEFAULTS)
