-- Djinni's Data Texts
-- LDB data brokers for a unified suite of DataTexts with rich tooltips.
-- Uses: LibDataBroker-1.1
local addonName, ns = ...

---------------------------------------------------------------------------
-- Addon namespace
---------------------------------------------------------------------------

local DDT = {}
ns.addon = DDT
ns.addonName = addonName

-- Saved variables reference (populated in ADDON_LOADED)
ns.db = nil

-- Module registry — modules call ns:RegisterModule() during load
ns.modules = {}

-- Default settings (flat structure, no profiles)
-- Each module merges its own defaults into this table via RegisterModule().
ns.defaults = {
    friends = {
        labelFormat = "Friends: <online>/<total>",
        sortBy = "name",
        sortAscending = true,
        showBNetFriends = true,
        showWoWFriends = true,
        classColorNames = true,
        showHintBar = true,
        tooltipScale = 1.0,
        tooltipWidth = 420,
        tooltipMaxHeight = 400,
        rowSpacing = 4,
        groupBy = "none",
        groupBy2 = "none",
        groupCollapsed = {},
        clickActions = {
            leftClick = "whisper",
            rightClick = "invite",
            shiftLeftClick = "copyname",
            shiftRightClick = "who",
            middleClick = "openfriends",
        },
    },
    guild = {
        labelFormat = "Guild: <online>/<total>",
        sortBy = "name",
        sortAscending = true,
        classColorNames = true,
        showOfficerNotes = false,
        showHintBar = true,
        tooltipScale = 1.0,
        tooltipWidth = 480,
        tooltipMaxHeight = 500,
        rowSpacing = 4,
        groupBy = "none",
        groupBy2 = "none",
        groupCollapsed = {},
        clickActions = {
            leftClick = "whisper",
            rightClick = "invite",
            shiftLeftClick = "copyname",
            shiftRightClick = "who",
            middleClick = "openguild",
        },
    },
    global = {
        tooltipFont = "Fonts\\FRIZQT__.TTF",
        tooltipFontSize = 12,
        customUrl1 = "",
        customUrl2 = "",
        tagSeparator = "#",
        noteShowInAllGroups = true,
    },
    communities = {
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
            leftClick = "whisper",
            rightClick = "invite",
            shiftLeftClick = "copyname",
            shiftRightClick = "who",
            middleClick = "opencommunities",
        },
    },
}

-- Available click actions (shared by social modules)
ns.ACTION_VALUES = {
    whisper          = "Whisper",
    invite           = "Invite to Group",
    who              = "/who Lookup",
    copyname         = "Copy Name to Chat",
    copyarmory       = "Copy Armory Link",
    copyraiderio     = "Copy Raider.IO Link",
    copywarcraftlogs = "Copy WarcraftLogs Link",
    copyurl1         = "Copy Custom URL 1",
    copyurl2         = "Copy Custom URL 2",
    openfriends      = "Open Friends List",
    openguild        = "Open Guild Roster",
    opencommunities  = "Open Communities",
    none             = "None",
}

-- Grouping modes (shared by social modules)
ns.FRIENDS_GROUP_VALUES = {
    none = "No Grouping",
    type = "BNet / In-Game Friends",
    zone = "Same Zone",
    note = "Friend Note (#tags)",
}

ns.GUILD_GROUP_VALUES = {
    none  = "No Grouping",
    rank  = "Guild Rank",
    level = "Level Bracket",
    zone  = "Same Zone",
    note  = "Member Note (#tags)",
}

ns.COMMUNITIES_GROUP_VALUES = {
    community = "Community",
    none      = "No Grouping",
    zone      = "Same Zone",
    note      = "Member Note (#tags)",
}

---------------------------------------------------------------------------
-- DDT tooltip font objects
---------------------------------------------------------------------------

local DDTFontHeader = CreateFont("DDTFontHeader")
DDTFontHeader:SetFont("Fonts\\FRIZQT__.TTF", 16, "")

local DDTFontNormal = CreateFont("DDTFontNormal")
DDTFontNormal:SetFont("Fonts\\FRIZQT__.TTF", 12, "")

local DDTFontSmall = CreateFont("DDTFontSmall")
DDTFontSmall:SetFont("Fonts\\FRIZQT__.TTF", 10, "")

function ns:UpdateFonts()
    local db = self.db and self.db.global or {}
    local fontPath = db.tooltipFont or "Fonts\\FRIZQT__.TTF"
    local fontSize = db.tooltipFontSize or 12

    DDTFontHeader:SetFont(fontPath, fontSize + 4, "")
    DDTFontNormal:SetFont(fontPath, fontSize, "")
    DDTFontSmall:SetFont(fontPath, fontSize - 2, "")
end

---------------------------------------------------------------------------
-- Shared tooltip constants
---------------------------------------------------------------------------

ns.ROW_HEIGHT      = 16
ns.TOOLTIP_PADDING = 10
ns.HEADER_HEIGHT   = 24
ns.FIXED_TOP       = ns.TOOLTIP_PADDING + ns.HEADER_HEIGHT + 20   -- header + column headers row
ns.FIXED_BOTTOM    = ns.TOOLTIP_PADDING * 2 + 18                  -- hint bar + padding
ns.HIDE_DELAY      = 0.15

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

--- Register a module with DDT.
--- @param key string  Short identifier (e.g. "guild", "specswitch")
--- @param mod table   Module table with :Init(), optional :BuildSettingsPanel()
--- @param defaults table|nil  Module-specific defaults to merge into ns.defaults
function ns:RegisterModule(key, mod, defaults)
    self.modules[key] = mod
    if defaults then
        self.defaults[key] = defaults
    end
end

---------------------------------------------------------------------------
-- Shared sort functions
---------------------------------------------------------------------------

ns.SORT_FUNCTIONS = {
    name = function(a, b) return a.name < b.name end,
    class = function(a, b)
        local ac = a.classFile or ""
        local bc = b.classFile or ""
        if ac == bc then return a.name < b.name end
        return ac < bc
    end,
    level = function(a, b)
        if a.level == b.level then return a.name < b.name end
        return a.level < b.level
    end,
    zone = function(a, b)
        if a.area == b.area then return a.name < b.name end
        return a.area < b.area
    end,
    rank = function(a, b)
        if a.rankIndex == b.rankIndex then return a.name < b.name end
        return a.rankIndex < b.rankIndex
    end,
    status = function(a, b)
        local sa = a.afk and 2 or a.dnd and 3 or 1
        local sb = b.afk and 2 or b.dnd and 3 or 1
        if sa == sb then return a.name < b.name end
        return sa < sb
    end,
}

--- Sort a list using the db settings for a given section
function DDT:SortList(list, db, extraSortFuncs)
    local funcs = extraSortFuncs or ns.SORT_FUNCTIONS
    local sortFunc = funcs[db.sortBy] or ns.SORT_FUNCTIONS[db.sortBy] or ns.SORT_FUNCTIONS.name
    local ascending = db.sortAscending ~= false
    if ascending then
        table.sort(list, sortFunc)
    else
        table.sort(list, function(a, b) return sortFunc(b, a) end)
    end
end

---------------------------------------------------------------------------
-- Saved variables helpers
---------------------------------------------------------------------------

--- Deep-merge defaults into saved vars (only fills missing keys)
local function MergeDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then
                target[k] = {}
            end
            MergeDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
end

---------------------------------------------------------------------------
-- Migration: DjinnisGuildFriends → DjinnisDataTexts
---------------------------------------------------------------------------

--- Migrate settings from DjinnisGuildFriendsDB if present
local function MigrateFromDGF()
    if not DjinnisGuildFriendsDB then return false end
    if DjinnisDataTextsDB._migratedFromDGF then return false end

    local src = DjinnisGuildFriendsDB
    local dst = DjinnisDataTextsDB

    -- Copy section-by-section (friends, guild, communities, global)
    for _, key in ipairs({ "friends", "guild", "communities", "global" }) do
        if type(src[key]) == "table" then
            if type(dst[key]) ~= "table" then
                dst[key] = {}
            end
            -- Deep copy source values into destination
            for k, v in pairs(src[key]) do
                if type(v) == "table" then
                    dst[key][k] = {}
                    for k2, v2 in pairs(v) do
                        dst[key][k][k2] = v2
                    end
                else
                    dst[key][k] = v
                end
            end
        end
    end

    dst._migratedFromDGF = true
    return true
end

---------------------------------------------------------------------------
-- DjinnisGuildFriends coexistence check
---------------------------------------------------------------------------

--- If DjinnisGuildFriends is still loaded, tell the user it's superseded
local function CheckDGFCoexistence()
    if not C_AddOns then return end
    local loaded = C_AddOns.IsAddOnLoaded("DjinnisGuildFriends")
    if loaded then
        C_Timer.After(5, function()
            DDT:Print("DjinnisGuildFriends is still installed. Its Guild, Friends, and Communities brokers are now provided by Djinni's Data Texts. You can safely disable DjinnisGuildFriends.")
        end)
    end
end

---------------------------------------------------------------------------
-- Utility functions
---------------------------------------------------------------------------

--- Parse tags from a note string using the configured separator (default "#")
function DDT:ParseNoteGroups(note)
    if not note or note == "" then return {} end
    local sep = (ns.db and ns.db.global and ns.db.global.tagSeparator) or "#"
    local groups = {}
    local start = note:find(sep, 1, true)
    if not start then return groups end
    local pos = start
    while pos do
        pos = pos + #sep
        local nextSep = note:find(sep, pos, true)
        local chunk = note:sub(pos, nextSep and (nextSep - 1) or #note)
        local trimmed = chunk:match("^%s*(.-)%s*$")
        if trimmed and trimmed ~= "" then
            table.insert(groups, trimmed)
        end
        pos = nextSep
    end
    return groups
end

--- Replace <token> placeholders in a format string
function DDT:FormatLabel(fmt, online, total, extra)
    local offline = total - online
    local result = fmt
    result = result:gsub("<online>", tostring(online))
    result = result:gsub("<total>", tostring(total))
    result = result:gsub("<offline>", tostring(offline))
    if extra then
        for k, v in pairs(extra) do
            result = result:gsub("<" .. k .. ">", tostring(v))
        end
    end
    return result
end

--- Get class color as r, g, b (0-1) with fallback
function DDT:GetClassColor(classFile)
    if classFile and RAID_CLASS_COLORS[classFile] then
        local c = RAID_CLASS_COLORS[classFile]
        return c.r, c.g, c.b
    end
    return 0.63, 0.63, 0.63
end

--- Wrap text in a color escape sequence
function DDT:ColorText(text, r, g, b)
    return ("|cff%02x%02x%02x%s|r"):format(r * 255, g * 255, b * 255, text)
end

--- Color text by class file token
function DDT:ClassColorText(text, classFile)
    local r, g, b = self:GetClassColor(classFile)
    return self:ColorText(text, r, g, b)
end

--- Copy shared display settings between modules
function DDT:CopyDisplaySettings(fromKey, toKey)
    local from = ns.db[fromKey]
    local to = ns.db[toKey]
    if not from or not to then return end
    to.tooltipScale = from.tooltipScale
    to.tooltipWidth = from.tooltipWidth
    to.tooltipMaxHeight = from.tooltipMaxHeight
    to.rowSpacing = from.rowSpacing
    to.classColorNames = from.classColorNames
    to.sortAscending = from.sortAscending
end

--- Build the hint bar text showing all configured click actions
function DDT:BuildHintText(clickActions)
    local labels = {
        { key = "leftClick",       prefix = "LClick" },
        { key = "rightClick",      prefix = "RClick" },
        { key = "shiftLeftClick",  prefix = "Shift+L" },
        { key = "shiftRightClick", prefix = "Shift+R" },
        { key = "middleClick",     prefix = "MClick" },
    }
    local hints = {}
    for _, entry in ipairs(labels) do
        local action = clickActions[entry.key]
        if action and action ~= "none" then
            table.insert(hints, entry.prefix .. ": " .. (ns.ACTION_VALUES[action] or ""))
        end
    end
    if #hints == 0 then return "" end
    return "|cff888888" .. table.concat(hints, "  |  ") .. "|r"
end

--- Update scrollbar thumb/track visibility and position for a scrollable tooltip
function DDT:UpdateScrollbar(f)
    if not f or not f.scrollTrack then return end
    local contentH = f.scrollContent:GetHeight()
    local clipH = f.clipFrame:GetHeight()
    if contentH > clipH + 1 then
        f.scrollTrack:Show()
        f.scrollThumb:Show()
        local ratio = clipH / contentH
        local thumbH = math.max(20, clipH * ratio)
        f.scrollThumb:SetHeight(thumbH)
        local scrollRange = contentH - clipH
        local scrollPos = (scrollRange > 0) and (f.scrollOffset / scrollRange) or 0
        local thumbTravel = clipH - thumbH
        f.scrollThumb:ClearAllPoints()
        f.scrollThumb:SetPoint("TOPRIGHT", f.scrollTrack, "TOPRIGHT", 0, -(scrollPos * thumbTravel))
    else
        f.scrollTrack:Hide()
        f.scrollThumb:Hide()
    end
end

--- Print a message to chat
function DDT:Print(msg)
    print("|cff33ff99" .. addonName .. "|r: " .. msg)
end

---------------------------------------------------------------------------
-- Shared tooltip helpers
---------------------------------------------------------------------------

--- Create or return a cached group header FontString
function DDT:GetOrCreateGroupHeader(parent, name)
    if not parent.groupHeaders then parent.groupHeaders = {} end
    if parent.groupHeaders[name] then return parent.groupHeaders[name] end

    local hdr = parent:CreateFontString(nil, "OVERLAY", "DDTFontNormal")
    hdr:SetJustifyH("LEFT")
    hdr:SetHeight(14)
    hdr:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    parent.groupHeaders[name] = hdr
    return hdr
end

--- Resolve a click action from a button+modifier combo
function DDT:ResolveClickAction(button, clickActions)
    if button == "LeftButton" and IsShiftKeyDown() then
        return clickActions.shiftLeftClick
    elseif button == "RightButton" and IsShiftKeyDown() then
        return clickActions.shiftRightClick
    elseif button == "LeftButton" then
        return clickActions.leftClick
    elseif button == "RightButton" then
        return clickActions.rightClick
    elseif button == "MiddleButton" then
        return clickActions.middleClick
    end
end

---------------------------------------------------------------------------
-- Shared grouping helpers
---------------------------------------------------------------------------

-- Zone grouping: assigns members to "Same Zone: ..." or their zone name
local function GroupByZone(member, playerZone)
    if member.area == playerZone and playerZone ~= "" then
        return { "Same Zone: " .. playerZone }
    end
    return { member.area ~= "" and member.area or "Unknown" }
end

-- Note grouping: parses tags from notes field
local function GroupByNote(member)
    local tags = DDT:ParseNoteGroups(member.notes)
    if #tags > 0 then
        local showAll = not ns.db or not ns.db.global or ns.db.global.noteShowInAllGroups ~= false
        if showAll then return tags end
        return { tags[1] }
    end
    return { "Ungrouped" }
end

--- Shared group-order sort -- handles zone and note modes
function DDT:SortGroupOrder(order, groupBy, groups)
    if groupBy == "zone" then
        table.sort(order, function(a, b)
            local aLocal = a:find("^Same Zone")
            local bLocal = b:find("^Same Zone")
            if aLocal and not bLocal then return true end
            if bLocal and not aLocal then return false end
            return a < b
        end)
    elseif groupBy == "note" then
        table.sort(order, function(a, b)
            if a == "Ungrouped" then return false end
            if b == "Ungrouped" then return true end
            return a < b
        end)
    else
        table.sort(order)
    end
end

--- Assign members to groups and build ordering.
function DDT:BuildGroups(members, groupBy, extraHandler)
    if groupBy == "none" then return {}, {} end

    local groups   = {}
    local groupSet = {}
    local playerZone = GetRealZoneText() or ""

    for _, member in ipairs(members) do
        local groupNames

        if extraHandler then
            groupNames = extraHandler(member, groupBy, playerZone)
        end

        if not groupNames then
            if groupBy == "zone" then
                groupNames = GroupByZone(member, playerZone)
            elseif groupBy == "note" then
                groupNames = GroupByNote(member)
            else
                groupNames = { "Other" }
            end
        end

        for _, gn in ipairs(groupNames) do
            if not groups[gn] then
                groups[gn] = {}
                groupSet[gn] = true
            end
            table.insert(groups[gn], member)
        end
    end

    local order = {}
    for name in pairs(groupSet) do
        table.insert(order, name)
    end

    self:SortGroupOrder(order, groupBy, groups)
    return groups, order
end

---------------------------------------------------------------------------
-- Shared click-action execution
---------------------------------------------------------------------------

--- Execute a common click action. Returns true if handled.
function DDT:ExecuteAction(action, charName, realmName, fullName, bnet, tooltipFrame)
    if action == "whisper" then
        if tooltipFrame then tooltipFrame:Hide() end
        if bnet and bnet.accountName then
            local tellName = bnet.accountName
            if tellName == "" then
                tellName = bnet.battleTag and bnet.battleTag:match("^([^#]+)") or charName
            end
            if ChatFrameUtil and ChatFrameUtil.SendBNetTell then
                ChatFrameUtil.SendBNetTell(tellName)
            else
                ChatFrameUtil.OpenChat("/w " .. tellName .. " ")
            end
        elseif fullName and fullName ~= "" then
            if ChatFrameUtil and ChatFrameUtil.SendTell then
                ChatFrameUtil.SendTell(fullName)
            else
                ChatFrameUtil.OpenChat("/w " .. fullName .. " ")
            end
        end
        return true

    elseif action == "invite" then
        if bnet and bnet.gameAccountID then
            BNInviteFriend(bnet.gameAccountID)
        elseif fullName and fullName ~= "" then
            C_PartyInfo.InviteUnit(fullName)
        end

    elseif action == "who" then
        local query = fullName or ""
        if bnet and realmName and realmName ~= "" and charName then
            query = charName .. "-" .. realmName
        end
        if query ~= "" then C_FriendList.SendWho(query) end

    elseif action == "copyname" then
        local copyName = fullName or charName or ""
        if copyName ~= "" then
            ChatFrameUtil.OpenChat(copyName)
        end

    elseif action == "copyarmory" or action == "copyraiderio" or action == "copywarcraftlogs" then
        if charName and charName ~= "" and realmName and realmName ~= "" then
            local urlType = (action == "copyarmory") and "armory" or (action == "copyraiderio") and "raiderio" or "warcraftlogs"
            ns.CopyURL(ns.GetCharacterURL(charName, realmName, urlType))
        end

    elseif action == "copyurl1" or action == "copyurl2" then
        if charName and charName ~= "" and realmName and realmName ~= "" then
            local template = (action == "copyurl1") and ns.db.global.customUrl1 or ns.db.global.customUrl2
            local url = ns.GetCustomURL(template, charName, realmName)
            if url then ns.CopyURL(url) end
        end

    elseif action == "openfriends" then
        ToggleFriendsFrame()
    elseif action == "openguild" then
        ToggleGuildFrame()
    elseif action == "opencommunities" then
        ToggleCommunitiesFrame()
    end

    if tooltipFrame then tooltipFrame:Hide() end
end

---------------------------------------------------------------------------
-- URL helpers
---------------------------------------------------------------------------

local ARMORY_LOCALE = { us="en-us", eu="en-gb", kr="ko-kr", tw="zh-tw", cn="zh-cn" }

--- Convert a realm name to a URL-safe slug (lowercase, no apostrophes, spaces to hyphens)
local function RealmSlug(realmName)
    return (realmName:lower():gsub("'", ""):gsub("%s+", "-"))
end

--- Build an Armory, Raider.IO, or WarcraftLogs URL for a character
function ns.GetCharacterURL(charName, realmName, urlType)
    local region = (GetCurrentRegionName and GetCurrentRegionName() or "US"):lower()
    local slug   = RealmSlug(realmName)
    local name   = charName:lower()
    if urlType == "armory" then
        local locale = ARMORY_LOCALE[region] or "en-us"
        return ("https://worldofwarcraft.blizzard.com/%s/character/%s/%s/%s"):format(locale, region, slug, name)
    elseif urlType == "warcraftlogs" then
        return ("https://www.warcraftlogs.com/character/%s/%s/%s"):format(region, slug, name)
    else -- raiderio
        return ("https://raider.io/characters/%s/%s/%s"):format(region, slug, name)
    end
end

--- Expand a custom URL template: replaces <name>, <realm>, <region>
function ns.GetCustomURL(template, charName, realmName)
    if not template or template == "" then return nil end
    local region = (GetCurrentRegionName and GetCurrentRegionName() or "US"):lower()
    local slug   = RealmSlug(realmName)
    return (template:gsub("<name>", charName:lower()):gsub("<realm>", slug):gsub("<region>", region))
end

--- Copy a URL: uses C_Clipboard if available, otherwise inserts into chat input
function ns.CopyURL(url)
    if C_Clipboard and C_Clipboard.SetText then
        C_Clipboard.SetText(url)
        ns.addon:Print("Copied: " .. url)
    else
        ChatFrameUtil.OpenChat(url)
    end
end

---------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(_, _, loadedAddon)
    if loadedAddon ~= addonName then return end
    initFrame:UnregisterEvent("ADDON_LOADED")

    -- Load or create saved variables
    if not DjinnisDataTextsDB then
        DjinnisDataTextsDB = {}
    end

    -- Migrate from DjinnisGuildFriends if present
    local migrated = MigrateFromDGF()

    -- Merge defaults into saved vars
    MergeDefaults(DjinnisDataTextsDB, ns.defaults)
    ns.db = DjinnisDataTextsDB

    -- Apply font settings
    ns:UpdateFonts()

    if migrated then
        DDT:Print("Settings migrated from Djinni's Guild & Friends.")
    end

    -- Setup settings UI (Settings.lua)
    DDT:SetupOptions()

    -- Slash commands
    SLASH_DDT1 = "/ddt"
    SLASH_DDT2 = "/djdata"
    SlashCmdList["DDT"] = function(input)
        if input and input:match("%S") then
            DDT:Print("Unknown command: " .. input)
        else
            Settings.OpenToCategory(DDT.settingsCategoryID)
        end
    end

    -- Initialize all registered modules
    for key, mod in pairs(ns.modules) do
        if mod.Init then
            mod:Init()
        end
    end

    -- Check for DjinnisGuildFriends coexistence
    CheckDGFCoexistence()
end)
