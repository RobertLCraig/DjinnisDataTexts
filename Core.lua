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
    global = {
        tooltipFont = "Fonts\\FRIZQT__.TTF",
        tooltipFontSize = 12,
        customUrl1 = "",
        customUrl2 = "",
        tagSeparator = "#",
        noteShowInAllGroups = true,
        numberFormat = "us_short",
        numberSep = ",",
        numberDec = ".",
        numberAbbr = true,
        goldColorize = true,
        goldShowSilver = true,
        goldShowCopper = true,
    },
}

-- Available click actions (shared by social modules — used for tooltip row clicks)
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
    opensettings     = "Open DDT Settings",
    none             = "None",
}

-- Label click actions for social module DataText buttons (no player context)
ns.SOCIAL_LABEL_ACTION_VALUES = {
    openfriends     = "Open Friends List",
    openguild       = "Open Guild Roster",
    opencommunities = "Open Communities",
    opensettings    = "Open DDT Settings",
    none            = "None",
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

-- Font object lookup by template name
local DDT_FONT_OBJECTS = {
    DDTFontHeader = DDTFontHeader,
    DDTFontNormal = DDTFontNormal,
    DDTFontSmall  = DDTFontSmall,
}

-- Registry of all DDT FontStrings for live font updates (weak values so GC works)
local fontStringRegistry = setmetatable({}, { __mode = "v" })
local fontStringCount = 0

--- Create a FontString that tracks DDT font object changes.
--- Drop-in replacement for parent:CreateFontString(nil, "OVERLAY", "DDTFontXxx").
--- @param parent Frame
--- @param fontTemplate string  "DDTFontHeader", "DDTFontNormal", or "DDTFontSmall"
--- @return FontString
function ns.FontString(parent, fontTemplate)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    -- Apply font directly rather than via SetFontObject so live updates work.
    -- SetFontObject blocks subsequent SetFont calls, preventing size changes.
    local fontObj = DDT_FONT_OBJECTS[fontTemplate]
    if fontObj then
        local path, sz, flags = fontObj:GetFont()
        if path then
            fs:SetFont(path, sz, flags or "")
        else
            fs:SetFontObject(fontTemplate)
        end
    end
    fontStringCount = fontStringCount + 1
    fontStringRegistry[fontStringCount] = fs
    fs._ddtFontTemplate = fontTemplate
    return fs
end

function ns:UpdateFonts()
    local db = self.db and self.db.global or {}
    local fontPath = db.tooltipFont or "Fonts\\FRIZQT__.TTF"
    local fontSize = db.tooltipFontSize or 12

    -- Update the CreateFont objects (for newly created FontStrings)
    DDTFontHeader:SetFont(fontPath, fontSize + 4, "")
    DDTFontNormal:SetFont(fontPath, fontSize, "")
    DDTFontSmall:SetFont(fontPath, fontSize - 2, "")

    -- Update dynamic row height for tooltip layouts
    ns.ROW_HEIGHT = math.max(16, fontSize + 8)

    -- Update all registered FontStrings directly (font object propagation
    -- is unreliable for addon-bundled fonts and size-only changes).
    local sizeMap = {
        DDTFontHeader = fontSize + 4,
        DDTFontNormal = fontSize,
        DDTFontSmall  = fontSize - 2,
    }
    for i, fs in pairs(fontStringRegistry) do
        if fs and fs.GetObjectType and fs._ddtFontTemplate then
            local sz = sizeMap[fs._ddtFontTemplate] or fontSize
            fs:SetFont(fontPath, sz, "")
        else
            fontStringRegistry[i] = nil
        end
    end
end

---------------------------------------------------------------------------
-- Shared tooltip constants
---------------------------------------------------------------------------

ns.ROW_HEIGHT      = 20
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
-- Number formatting (global)
---------------------------------------------------------------------------

-- Presets: { thousandsSep, decimalSep, abbreviate }
local FORMAT_PRESETS = {
    us_short   = { sep = ",", dec = ".", abbr = true },   -- 1.2K  12.3M
    us_full    = { sep = ",", dec = ".", abbr = false },   -- 1,234  12,345,678
    eu_short   = { sep = ".", dec = ",", abbr = true },   -- 1,2K  12,3M
    eu_full    = { sep = ".", dec = ",", abbr = false },   -- 1.234  12.345.678
    fr_short   = { sep = " ", dec = ",", abbr = true },   -- 1,2K  12,3M
    fr_full    = { sep = " ", dec = ",", abbr = false },   -- 1 234  12 345 678
    plain      = { sep = "",  dec = ".", abbr = false },   -- 1234  12345678
    custom     = { sep = ",", dec = ".", abbr = true },    -- user-defined
}
ns.FORMAT_PRESETS = FORMAT_PRESETS

-- Preset display names for settings dropdown
ns.FORMAT_PRESET_LABELS = {
    us_short   = "US/UK - Short (1.2K, 3.4M)",
    us_full    = "US/UK - Full (1,234,567)",
    eu_short   = "EU - Short (1,2K, 3,4M)",
    eu_full    = "EU - Full (1.234.567)",
    fr_short   = "FR/SI - Short (1,2K)",
    fr_full    = "FR/SI - Full (1 234 567)",
    plain      = "No Separators (1234567)",
    custom     = "Custom",
}

--- Get the active format settings
local function GetFormatSettings()
    local db = ns.db and ns.db.global or {}
    local preset = db.numberFormat or "us_short"
    if preset == "custom" then
        return {
            sep  = db.numberSep or ",",
            dec  = db.numberDec or ".",
            abbr = db.numberAbbr ~= false,
        }
    end
    return FORMAT_PRESETS[preset] or FORMAT_PRESETS.us_short
end

--- Insert thousands separators into an integer string
local function InsertSeparators(intStr, sep)
    if sep == "" or #intStr <= 3 then return intStr end
    local result = ""
    local count = 0
    for i = #intStr, 1, -1 do
        if count > 0 and count % 3 == 0 then
            result = sep .. result
        end
        result = intStr:sub(i, i) .. result
        count = count + 1
    end
    return result
end

--- Format a number for display, respecting global format settings.
--- @param n number       The number to format
--- @param decimals number|nil  Decimal places (default 0 for integers, 1 for abbreviated)
--- @param forceAbbr boolean|nil  Override abbreviation setting (true=always abbreviate)
--- @return string
function ns.FormatNumber(n, decimals, forceAbbr)
    if not n then return "0" end
    local fmt = GetFormatSettings()
    local abbr = forceAbbr or fmt.abbr
    local negative = n < 0
    if negative then n = -n end

    local result
    if abbr then
        if n >= 1000000000 then
            result = string.format("%." .. (decimals or 1) .. "f", n / 1000000000)
            if fmt.dec ~= "." then result = result:gsub("%.", fmt.dec) end
            result = result .. "B"
        elseif n >= 1000000 then
            result = string.format("%." .. (decimals or 1) .. "f", n / 1000000)
            if fmt.dec ~= "." then result = result:gsub("%.", fmt.dec) end
            result = result .. "M"
        elseif n >= 10000 then
            result = string.format("%." .. (decimals or 1) .. "f", n / 1000)
            if fmt.dec ~= "." then result = result:gsub("%.", fmt.dec) end
            result = result .. "K"
        else
            local dec = decimals or 0
            if dec > 0 then
                result = string.format("%." .. dec .. "f", n)
                if fmt.dec ~= "." then result = result:gsub("%.", fmt.dec) end
            else
                result = InsertSeparators(tostring(math.floor(n + 0.5)), fmt.sep)
            end
        end
    else
        local dec = decimals or 0
        if dec > 0 then
            local intPart = math.floor(n)
            local fracPart = string.format("%." .. dec .. "f", n - intPart):sub(2)  -- ".xx"
            if fmt.dec ~= "." then fracPart = fracPart:gsub("%.", fmt.dec) end
            result = InsertSeparators(tostring(intPart), fmt.sep) .. fracPart
        else
            result = InsertSeparators(tostring(math.floor(n + 0.5)), fmt.sep)
        end
    end

    if negative then result = "-" .. result end
    return result
end

--- Format gold/silver/copper, respecting global format settings.
--- @param copper number  Amount in copper
--- @param colorize boolean|nil  Add WoW color codes (for tooltips). Uses global goldColorize when nil.
--- @return string
--- @param opts table|nil  Optional: { showSilver = bool, showCopper = bool }. Uses global settings when nil.
function ns.FormatGold(copper, colorize, opts)
    if not copper then return "0g" end
    local negative = copper < 0
    if negative then copper = -copper end

    local gold   = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop    = copper % 100

    local fmt        = GetFormatSettings()
    local gdb        = ns.db and ns.db.global or {}
    -- Use opts overrides if provided, otherwise fall back to global settings
    local showSilver, showCopper
    if opts then
        showSilver = opts.showSilver ~= false
        showCopper = opts.showCopper ~= false
    else
        showSilver = gdb.goldShowSilver ~= false
        showCopper = gdb.goldShowCopper ~= false
    end
    -- Colorize: explicit param wins, then global setting
    if colorize == nil then colorize = gdb.goldColorize ~= false end
    local str

    if fmt.abbr then
        -- Abbreviated gold
        if gold >= 1000000 then
            local val = string.format("%.1f", gold / 1000000)
            if fmt.dec ~= "." then val = val:gsub("%.", fmt.dec) end
            str = val .. "M g"
        elseif gold >= 10000 then
            local val = string.format("%.1f", gold / 1000)
            if fmt.dec ~= "." then val = val:gsub("%.", fmt.dec) end
            str = val .. "K g"
        elseif colorize then
            local goldStr = gold >= 1 and InsertSeparators(tostring(gold), fmt.sep) or "0"
            str = string.format("|cffe6cc80%s|r|cffe6cc80g|r", goldStr)
            if showSilver then str = str .. string.format(" |cffc0c0c0%d|r|cffc0c0c0s|r", silver) end
            if showCopper then str = str .. string.format(" |cffcc7722%d|r|cffcc7722c|r", cop) end
        else
            local goldStr = InsertSeparators(tostring(gold), fmt.sep)
            str = goldStr .. "g"
            if showSilver then str = str .. string.format(" %ds", silver) end
            if showCopper then str = str .. string.format(" %dc", cop) end
        end
    else
        -- Full number gold
        local goldStr = InsertSeparators(tostring(gold), fmt.sep)
        if colorize then
            str = string.format("|cffe6cc80%s|r|cffe6cc80g|r", goldStr)
            if showSilver then str = str .. string.format(" |cffc0c0c0%d|r|cffc0c0c0s|r", silver) end
            if showCopper then str = str .. string.format(" |cffcc7722%d|r|cffcc7722c|r", cop) end
        else
            str = goldStr .. "g"
            if showSilver then str = str .. string.format(" %ds", silver) end
            if showCopper then str = str .. string.format(" %dc", cop) end
        end
    end

    if negative then str = "-" .. str end
    return str
end

--- Short gold format for labels, respecting global silver/copper/colorize settings.
--- @param copper number  Amount in copper
--- @return string
function ns.FormatGoldShort(copper)
    if not copper then return "0g" end
    local negative = copper < 0
    if negative then copper = -copper end

    local gold   = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop    = copper % 100
    local fmt    = GetFormatSettings()
    local gdb    = ns.db and ns.db.global or {}
    local showSilver = gdb.goldShowSilver ~= false
    local showCopper = gdb.goldShowCopper ~= false
    local colorize   = gdb.goldColorize ~= false
    local str

    if fmt.abbr then
        if gold >= 1000000 then
            local val = string.format("%.1f", gold / 1000000)
            if fmt.dec ~= "." then val = val:gsub("%.", fmt.dec) end
            str = colorize and string.format("|cffe6cc80%sM g|r", val) or (val .. "M g")
        elseif gold >= 10000 then
            local val = string.format("%.1f", gold / 1000)
            if fmt.dec ~= "." then val = val:gsub("%.", fmt.dec) end
            str = colorize and string.format("|cffe6cc80%sK g|r", val) or (val .. "K g")
        elseif gold >= 1 then
            local goldStr = InsertSeparators(tostring(gold), fmt.sep)
            if colorize then
                str = string.format("|cffe6cc80%s|r|cffe6cc80g|r", goldStr)
                if showSilver then str = str .. string.format(" |cffc0c0c0%d|r|cffc0c0c0s|r", silver) end
                if showCopper then str = str .. string.format(" |cffcc7722%d|r|cffcc7722c|r", cop) end
            else
                str = goldStr .. "g"
                if showSilver then str = str .. " " .. silver .. "s" end
                if showCopper then str = str .. " " .. cop .. "c" end
            end
        else
            -- Less than 1g: show silver or copper regardless of settings
            if silver > 0 then
                str = colorize and string.format("|cffc0c0c0%d|r|cffc0c0c0s|r", silver) or (silver .. "s")
                if showCopper then
                    str = str .. (colorize and string.format(" |cffcc7722%d|r|cffcc7722c|r", cop) or (" " .. cop .. "c"))
                end
            else
                str = colorize and string.format("|cffcc7722%d|r|cffcc7722c|r", cop) or (cop .. "c")
            end
        end
    else
        local goldStr = InsertSeparators(tostring(gold), fmt.sep)
        if colorize then
            str = string.format("|cffe6cc80%s|r|cffe6cc80g|r", goldStr)
            if showSilver then str = str .. string.format(" |cffc0c0c0%d|r|cffc0c0c0s|r", silver) end
            if showCopper then str = str .. string.format(" |cffcc7722%d|r|cffcc7722c|r", cop) end
        else
            str = goldStr .. "g"
            if showSilver then str = str .. " " .. silver .. "s" end
            if showCopper then str = str .. " " .. cop .. "c" end
        end
    end

    if negative then str = "-" .. str end
    return str
end

--- Format memory (KB) for display
function ns.FormatMemory(kb)
    if not kb then return "0 KB" end
    local fmt = GetFormatSettings()
    if kb >= 1024 then
        local val = string.format("%.1f", kb / 1024)
        if fmt.dec ~= "." then val = val:gsub("%.", fmt.dec) end
        return val .. " MB"
    end
    return string.format("%.0f KB", kb)
end

--- Format currency quantity with optional max
function ns.FormatQuantity(quantity, maxQuantity)
    local str = ns.FormatNumber(quantity)
    if maxQuantity and maxQuantity > 0 then
        return str .. " / " .. ns.FormatNumber(maxQuantity)
    end
    return str
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

--- Safely replace a <tag> placeholder without interpreting % in value.
--- @param str string   The template string
--- @param tag string   The tag name (without angle brackets)
--- @param value any     The replacement value (tostring'd automatically)
--- @return string
function ns.ExpandTag(str, tag, value)
    local s = tostring(value)
    return (str:gsub("<" .. tag .. ">", function() return s end))
end

--- Replace <token> placeholders in a format string
function DDT:FormatLabel(fmt, online, total, extra)
    local offline = total - online
    local result = fmt
    result = ns.ExpandTag(result, "online", online)
    result = ns.ExpandTag(result, "total", total)
    result = ns.ExpandTag(result, "offline", offline)
    if extra then
        for k, v in pairs(extra) do
            result = ns.ExpandTag(result, k, v)
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

--- Build the hint bar text showing all configured click actions.
--- @param clickActions table  Map of click slots to action keys
--- @param actionLabels table|nil  Optional display-name map (defaults to ns.ACTION_VALUES)
function DDT:BuildHintText(clickActions, actionLabels)
    actionLabels = actionLabels or ns.ACTION_VALUES
    local labels = {
        { key = "leftClick",       prefix = "LClick" },
        { key = "rightClick",      prefix = "RClick" },
        { key = "middleClick",     prefix = "MClick" },
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
            table.insert(hints, entry.prefix .. ": " .. (actionLabels[action] or action))
        end
    end
    if #hints == 0 then return "" end
    return "|cff888888" .. table.concat(hints, "  |  ") .. "|r"
end

--- Update vertical scrollbar thumb/track visibility and position
function DDT:UpdateScrollbar(f)
    if not f or not f.scrollTrack then return end
    local contentH = (f.scrollContent or f.content):GetHeight()
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

--- Update horizontal scrollbar thumb/track visibility and position
function DDT:UpdateHScrollbar(f)
    if not f or not f.hScrollTrack then return end
    local contentW = (f.scrollContent or f.content):GetWidth()
    local clipW = f.clipFrame:GetWidth()
    if contentW > clipW + 1 then
        f.hScrollTrack:Show()
        f.hScrollThumb:Show()
        local ratio = clipW / contentW
        local thumbW = math.max(20, clipW * ratio)
        f.hScrollThumb:SetWidth(thumbW)
        local scrollRange = contentW - clipW
        local scrollPos = (scrollRange > 0) and (f.hScrollOffset / scrollRange) or 0
        local thumbTravel = clipW - thumbW
        f.hScrollThumb:ClearAllPoints()
        f.hScrollThumb:SetPoint("TOPLEFT", f.hScrollTrack, "TOPLEFT", scrollPos * thumbTravel, 0)
    else
        f.hScrollTrack:Hide()
        f.hScrollThumb:Hide()
    end
end

---------------------------------------------------------------------------
-- Scrollable tooltip factory
---------------------------------------------------------------------------

local FACTORY_PADDING     = 10
local FACTORY_HEADER_H    = 20
local FACTORY_SEP_GAP     = 3   -- gap below header before separator
local FACTORY_CONTENT_GAP = 6   -- gap below separator before content
local FACTORY_HINT_H      = 28  -- hint bar height reservation (minimum, grows with wrap)
local FACTORY_HINT_H_NONE = 8   -- bottom padding when no hint

--- Anchor a tooltip frame relative to a DataText anchor.
--- @param tooltip Frame  The tooltip frame to position
--- @param anchor Frame   The DataText button/frame that triggered the tooltip
--- @param direction string|nil  "auto" (default), "up", or "down"
function ns.AnchorTooltip(tooltip, anchor, direction)
    direction = direction or "auto"
    local gap = 4
    tooltip:ClearAllPoints()

    local growDown
    if direction == "down" then
        growDown = true
    elseif direction == "up" then
        growDown = false
    else
        -- auto: detect from screen position
        local _, anchorY = anchor:GetCenter()
        local screenH = UIParent:GetHeight()
        growDown = anchorY and screenH and anchorY > screenH / 2
    end

    if growDown then
        tooltip:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -gap)
    else
        tooltip:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, gap)
    end
end

--- Create a scrollable tooltip frame with standard DDT styling.
--- All content should be placed on f.content (the scroll child).
--- After populating, call f:FinalizeLayout(width, contentHeight [, contentWidth]).
--- @param globalName string|nil  Frame global name (nil = anonymous)
--- @param moduleRef table  Module with CancelHideTimer/StartHideTimer (or *TooltipHideTimer variants)
--- @return Frame
function ns.CreateTooltipFrame(globalName, moduleRef)
    local f = CreateFrame("Frame", globalName, UIParent, "BackdropTemplate")
    f:SetFrameStrata("TOOLTIP")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetSize(400, 100)

    f:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.92)
    f:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Header (title)
    f.header = ns.FontString(f, "DDTFontHeader")
    f.header:SetPoint("TOPLEFT", f, "TOPLEFT", FACTORY_PADDING, -FACTORY_PADDING)
    f.header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -FACTORY_PADDING, -FACTORY_PADDING)
    f.header:SetJustifyH("LEFT")
    f.header:SetTextColor(1, 0.82, 0)
    f.header:SetHeight(FACTORY_HEADER_H)
    f.title = f.header  -- alias for Pattern B compat

    -- Title separator
    f.titleSep = f:CreateTexture(nil, "ARTWORK")
    f.titleSep:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 0, -FACTORY_SEP_GAP)
    f.titleSep:SetPoint("RIGHT", f, "RIGHT", -FACTORY_PADDING, 0)
    f.titleSep:SetHeight(1)
    f.titleSep:SetColorTexture(0.5, 0.5, 0.5, 0.5)

    -- Hint bar separator line (repositioned in FinalizeLayout)
    f.hintSep = f:CreateTexture(nil, "ARTWORK")
    f.hintSep:SetPoint("LEFT", f, "LEFT", FACTORY_PADDING, 0)
    f.hintSep:SetPoint("RIGHT", f, "RIGHT", -FACTORY_PADDING, 0)
    f.hintSep:SetHeight(1)
    f.hintSep:SetColorTexture(0.3, 0.3, 0.3, 0.5)
    f.hintSep:Hide()

    -- Hint bar (anchored to bottom of outer frame)
    f.hint = ns.FontString(f, "DDTFontSmall")
    f.hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", FACTORY_PADDING, 10)
    f.hint:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -FACTORY_PADDING, 10)
    f.hint:SetJustifyH("CENTER")
    f.hint:SetTextColor(0.53, 0.53, 0.53)

    -- Clip frame (clips children for scrolling)
    f.clipFrame = CreateFrame("Frame", nil, f)
    f.clipFrame:SetClipsChildren(true)

    -- Scroll content (child of clipFrame — all module content goes here)
    f.content = CreateFrame("Frame", nil, f.clipFrame)
    f.scrollContent = f.content  -- alias for DDT:UpdateScrollbar compat

    f.scrollOffset  = 0
    f.hScrollOffset = 0

    -- Vertical scrollbar track + thumb
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

    -- Horizontal scrollbar track + thumb
    f.hScrollTrack = f:CreateTexture(nil, "ARTWORK")
    f.hScrollTrack:SetPoint("TOPLEFT", f.clipFrame, "BOTTOMLEFT", 0, -2)
    f.hScrollTrack:SetPoint("TOPRIGHT", f.clipFrame, "BOTTOMRIGHT", 0, -2)
    f.hScrollTrack:SetHeight(4)
    f.hScrollTrack:SetColorTexture(1, 1, 1, 0.08)
    f.hScrollTrack:Hide()

    f.hScrollThumb = f:CreateTexture(nil, "OVERLAY")
    f.hScrollThumb:SetHeight(4)
    f.hScrollThumb:SetColorTexture(0.8, 0.8, 0.8, 0.4)
    f.hScrollThumb:Hide()

    -- Extra top offset for modules with column headers (set before FinalizeLayout)
    f.headerExtra = 0

    -- Mouse wheel: vertical default, Shift+wheel = horizontal
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(self, delta)
        if IsShiftKeyDown() then
            local contentW = self.content:GetWidth() or 0
            local clipW    = self.clipFrame:GetWidth() or 0
            local maxScroll = math.max(0, contentW - clipW)
            self.hScrollOffset = math.max(0, math.min(maxScroll, self.hScrollOffset - delta * 30))
        else
            local contentH = self.content:GetHeight() or 0
            local clipH    = self.clipFrame:GetHeight() or 0
            local maxScroll = math.max(0, contentH - clipH)
            self.scrollOffset = math.max(0, math.min(maxScroll, self.scrollOffset - delta * 20))
        end
        self.content:ClearAllPoints()
        self.content:SetPoint("TOPLEFT", self.clipFrame, "TOPLEFT",
            -self.hScrollOffset, self.scrollOffset)
        DDT:UpdateScrollbar(self)
        DDT:UpdateHScrollbar(self)
    end)

    -- OnEnter / OnLeave — probe for both naming conventions
    f:SetScript("OnEnter", function()
        if moduleRef.CancelTooltipHideTimer then
            moduleRef:CancelTooltipHideTimer()
        elseif moduleRef.CancelHideTimer then
            moduleRef:CancelHideTimer()
        end
    end)
    f:SetScript("OnLeave", function()
        if moduleRef.StartTooltipHideTimer then
            moduleRef:StartTooltipHideTimer()
        elseif moduleRef.StartHideTimer then
            moduleRef:StartHideTimer()
        end
    end)

    --- Finalize tooltip layout after content is populated.
    --- Sets clip frame size, outer frame size, and updates scrollbars.
    --- @param width number  Desired tooltip width
    --- @param contentHeight number  Total content height (positive)
    --- @param contentWidth number|nil  Total content width (nil = use inner width)
    function f:FinalizeLayout(width, contentHeight, contentWidth)
        local padding = FACTORY_PADDING
        local innerWidth = width - 2 * padding

        contentHeight = math.max(1, contentHeight)
        contentWidth  = contentWidth or innerWidth

        local fixedTop = padding + FACTORY_HEADER_H + FACTORY_SEP_GAP + 1 + FACTORY_CONTENT_GAP
                         + self.headerExtra
        local hintText = self.hint:GetText()
        local hasHint  = hintText and hintText ~= ""
        local hintH
        if hasHint then
            -- Measure actual wrapped height by pre-sizing the hint to the tooltip's inner width
            self.hint:SetWidth(innerWidth)
            hintH = math.max(FACTORY_HINT_H, math.ceil(self.hint:GetStringHeight()) + 14)
            self.hint:SetWidth(0)  -- clear; anchors will control it once frame is sized
        else
            hintH = FACTORY_HINT_H_NONE
        end

        -- Determine max scroll area height
        local db = moduleRef.GetDB and moduleRef:GetDB() or {}
        local maxH = db.tooltipMaxHeight or math.floor(UIParent:GetHeight() * 0.7)
        local scrollAreaH = math.min(contentHeight,
            math.max(20, maxH - fixedTop - hintH))

        -- Position clip frame
        self.clipFrame:ClearAllPoints()
        self.clipFrame:SetPoint("TOPLEFT", self, "TOPLEFT", padding, -fixedTop)
        self.clipFrame:SetSize(innerWidth, scrollAreaH)

        -- Set content size
        self.content:SetSize(contentWidth, contentHeight)

        -- Reset scroll position
        self.scrollOffset  = 0
        self.hScrollOffset = 0
        self.content:ClearAllPoints()
        self.content:SetPoint("TOPLEFT", self.clipFrame, "TOPLEFT", 0, 0)

        -- Set outer frame size
        self:SetSize(width, fixedTop + scrollAreaH + hintH)

        -- Position hint separator at top of hint zone
        if hasHint then
            self.hintSep:ClearAllPoints()
            self.hintSep:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", padding, hintH - 1)
            self.hintSep:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -padding, hintH - 1)
            self.hintSep:Show()
        else
            self.hintSep:Hide()
        end

        -- Update scrollbar visibility
        DDT:UpdateScrollbar(self)
        DDT:UpdateHScrollbar(self)
    end

    f:Hide()
    return f
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

    local hdr = ns.FontString(parent, "DDTFontNormal")
    hdr:SetJustifyH("LEFT")
    hdr:SetHeight(14)
    hdr:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    parent.groupHeaders[name] = hdr
    return hdr
end

--- Resolve a click action from a button+modifier combo
function DDT:ResolveClickAction(button, clickActions)
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
        if button == "MiddleButton" then return clickActions.middleClick end
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
    elseif action == "opensettings" then
        if DDT.settingsCategoryID then
            Settings.OpenToCategory(DDT.settingsCategoryID)
        end
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
    local result = template
    result = ns.ExpandTag(result, "name", charName:lower())
    result = ns.ExpandTag(result, "realm", slug)
    result = ns.ExpandTag(result, "region", region)
    return result
end

--- Copy a URL: uses CopyToClipboard if available, otherwise inserts into chat input
function ns.CopyURL(url)
    if CopyToClipboard then
        CopyToClipboard(url)
        ns.addon:Print("Copied: " .. url)
    else
        ChatFrameUtil.OpenChat(url)
    end
end

--- Copy text to clipboard with an optional popup for multi-line text.
--- @param text string  Text to copy
--- @param label string|nil  Label shown in print message
function DDT:CopyToClipboard(text, label)
    do
        -- CopyToClipboard() is hardware-protected; addons cannot call it.
        -- Show a popup with selectable text instead.
        if not DDTCopyFrame then
            local f = CreateFrame("Frame", "DDTCopyFrame", UIParent, "BackdropTemplate")
            f:SetSize(500, 300)
            f:SetPoint("CENTER")
            f:SetFrameStrata("DIALOG")
            f:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 },
            })
            f:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
            f:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
            f:EnableMouse(true)
            f:SetMovable(true)
            f:RegisterForDrag("LeftButton")
            f:SetScript("OnDragStart", f.StartMoving)
            f:SetScript("OnDragStop", f.StopMovingOrSizing)

            local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            title:SetPoint("TOP", 0, -10)
            title:SetText("DDT — Copy Text")
            f.titleText = title

            local scroll = CreateFrame("ScrollFrame", "DDTCopyScroll", f, "UIPanelScrollFrameTemplate")
            scroll:SetPoint("TOPLEFT", 12, -34)
            scroll:SetPoint("BOTTOMRIGHT", -30, 36)

            local edit = CreateFrame("EditBox", "DDTCopyEditBox", scroll)
            edit:SetMultiLine(true)
            edit:SetAutoFocus(true)
            edit:SetFontObject("GameFontHighlight")
            edit:SetWidth(440)
            edit:SetScript("OnEscapePressed", function() f:Hide() end)
            scroll:SetScrollChild(edit)
            f.editBox = edit

            local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
            close:SetPoint("TOPRIGHT", -2, -2)

            local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
            hint:SetPoint("BOTTOM", 0, 12)
            hint:SetText("Ctrl+A to select all, Ctrl+C to copy, Escape to close")
        end

        DDTCopyFrame.titleText:SetText("DDT — " .. (label or "Copy Text"))
        DDTCopyFrame.editBox:SetText(text)
        DDTCopyFrame:Show()
        DDTCopyFrame.editBox:HighlightText()
        DDTCopyFrame.editBox:SetFocus()
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

    -- Refresh all modules: initial update once data is available,
    -- then periodically so labels stay current without requiring mouseover.
    local function RefreshAllModules()
        for _, mod in pairs(ns.modules) do
            if mod.UpdateData then
                pcall(mod.UpdateData, mod)
            end
        end
    end

    -- Initial refresh shortly after login/reload (data APIs need a frame)
    C_Timer.After(1, RefreshAllModules)

    -- Periodic refresh every 180 seconds
    C_Timer.NewTicker(180, RefreshAllModules)
end)
