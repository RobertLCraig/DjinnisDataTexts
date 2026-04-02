-- Djinni's Data Texts — Action Bar Profiles
-- Save and restore action bar layouts as named profiles, shared across
-- characters of the same class. MySlot interoperability.
local addonName, ns = ...
local DDT = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local ABP = {}
ns.ActionBarProfiles = ABP

-- State
ABP.profileList    = {}   -- sorted list for current class
ABP.currentClass   = ""
ABP.currentSpec    = ""
ABP.currentSpecID  = 0
ABP.pendingRestore = nil  -- deferred restore when leaving combat
ABP.demoMode       = false

-- Tooltip
local tooltipFrame = nil
local hideTimer    = nil
local rowPool      = {}
local headerPool   = {}
local separatorPool = {}

-- Layout constants
local TOOLTIP_WIDTH  = 320
local ROW_HEIGHT     = 20
local HEADER_HEIGHT  = 18
local PADDING        = 10
local ICON_SIZE      = 18

local MAX_ACTIONBAR_SLOT = 180
local MAX_PROFILES       = 1000

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local DEFAULTS = {
    labelTemplate    = "<profile>",
    tooltipScale     = 1.0,
    tooltipMaxHeight = 500,
    tooltipWidth     = 320,
    activeProfile    = {},   -- { [classToken] = "profileName" }
    profiles         = {},   -- { [classToken] = { [name] = profileData } }
    previousLayout   = {},   -- { [classToken] = profileData }
    autoLoadSpec     = {},   -- { [classToken .. "-" .. specID] = "profileName" }
    showMySlot       = true,
    clickActions = {
        leftClick       = "loadnext",
        rightClick      = "savecurrent",
        middleClick     = "none",
        shiftLeftClick  = "none",
        shiftRightClick = "none",
        ctrlLeftClick   = "none",
        ctrlRightClick  = "none",
        altLeftClick    = "opensettings",
        altRightClick   = "none",
    },
}

---------------------------------------------------------------------------
-- Action definitions
---------------------------------------------------------------------------

local CLICK_ACTIONS = {
    loadnext     = "Load Next Profile",
    loadprev     = "Load Previous Profile",
    savecurrent  = "Save to Current Profile",
    undorestore  = "Undo (Load Previous Layout)",
    opensettings = "Open DDT Settings",
    none         = "None",
}
ns.ABP_ACTION_VALUES = CLICK_ACTIONS

---------------------------------------------------------------------------
-- Djinni-style message
---------------------------------------------------------------------------

local function DjinniMsg(msg)
    DDT:Print("|cff33ff99Djinni:|r " .. msg)
end

---------------------------------------------------------------------------
-- Database helpers
---------------------------------------------------------------------------

function ABP:GetDB()
    return ns.db and ns.db.actionbarprofiles or DEFAULTS
end

local function GetClassToken()
    local _, classToken = UnitClass("player")
    return classToken or "UNKNOWN"
end

local function GetCharacterKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or ""
    return name .. " - " .. realm
end

local function GetClassProfiles(db)
    local cls = GetClassToken()
    if not db.profiles[cls] then db.profiles[cls] = {} end
    return db.profiles[cls]
end

---------------------------------------------------------------------------
-- Core: Read action bar slots
---------------------------------------------------------------------------

local function ReadActionBarSlots()
    local slots = {}
    for slotID = 1, MAX_ACTIONBAR_SLOT do
        if C_ActionBar.HasAction(slotID) then
            local actionType, id, subType = GetActionInfo(slotID)
            if actionType == "spell" then
                slots[slotID] = { type = "spell", id = id }
            elseif actionType == "macro" then
                local macroName = C_ActionBar.GetActionText(slotID)
                slots[slotID] = { type = "macro", name = macroName, index = id }
            elseif actionType == "item" then
                slots[slotID] = { type = "item", id = id }
            elseif actionType == "flyout" then
                slots[slotID] = { type = "flyout", id = id }
            elseif actionType == "summonpet" then
                slots[slotID] = { type = "summonpet", id = id }
            elseif actionType then
                slots[slotID] = { type = actionType, id = id, subType = subType }
            end
        end
    end
    return slots
end

---------------------------------------------------------------------------
-- Core: Find macro by name (with index hint)
---------------------------------------------------------------------------

local function FindMacro(savedName, savedIndex)
    if savedIndex then
        local name = GetMacroInfo(savedIndex)
        if name == savedName then return savedIndex end
    end
    local numAccount, numCharacter = GetNumMacros()
    for i = 1, numAccount + numCharacter do
        local name = GetMacroInfo(i)
        if name == savedName then return i end
    end
    return nil
end

---------------------------------------------------------------------------
-- Core: Find flyout in spellbook
---------------------------------------------------------------------------

local function FindFlyoutInSpellbook(targetFlyoutID)
    if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then return nil end
    for lineIdx = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local info = C_SpellBook.GetSpellBookSkillLineInfo(lineIdx)
        if info then
            for i = 1, info.numSpellBookItems do
                local slotIdx = info.itemIndexOffset + i
                local itemType, actionID = C_SpellBook.GetSpellBookItemType(slotIdx, Enum.SpellBookSpellBank.Player)
                if itemType == Enum.SpellBookItemType.Flyout and actionID == targetFlyoutID then
                    return slotIdx
                end
            end
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- Core: Place a single action into a slot
---------------------------------------------------------------------------

local function PlaceActionInSlot(slotID, slotData)
    local placed = false
    if slotData.type == "spell" then
        C_Spell.PickupSpell(slotData.id)
        if GetCursorInfo() then PlaceAction(slotID); placed = true end
    elseif slotData.type == "macro" then
        local idx = FindMacro(slotData.name, slotData.index)
        if idx then
            PickupMacro(idx)
            if GetCursorInfo() then PlaceAction(slotID); placed = true end
        end
    elseif slotData.type == "item" then
        C_Item.PickupItem(slotData.id)
        if GetCursorInfo() then PlaceAction(slotID); placed = true end
    elseif slotData.type == "flyout" then
        local sbSlot = FindFlyoutInSpellbook(slotData.id)
        if sbSlot then
            C_SpellBook.PickupSpellBookItem(sbSlot, Enum.SpellBookSpellBank.Player)
            if GetCursorInfo() then PlaceAction(slotID); placed = true end
        end
    elseif slotData.type == "summonpet" then
        C_PetJournal.PickupPet(slotData.id)
        if GetCursorInfo() then PlaceAction(slotID); placed = true end
    end
    ClearCursor()
    return placed
end

---------------------------------------------------------------------------
-- Core: Save Profile
---------------------------------------------------------------------------

local function SaveProfile(name)
    if InCombatLockdown() then
        DjinniMsg("Cannot save profiles in combat.")
        return false
    end
    if C_ActionBar.HasVehicleActionBar() or C_ActionBar.HasOverrideActionBar() then
        DjinniMsg("Warning: Vehicle/override bar is active. Profile may not save correctly.")
    end

    local db = ABP:GetDB()
    local cls = GetClassToken()
    local profiles = GetClassProfiles(db)

    -- Check limit for new profiles
    if not profiles[name] then
        local count = 0
        for _ in pairs(profiles) do count = count + 1 end
        if count >= MAX_PROFILES then
            DjinniMsg("Maximum profile limit (" .. MAX_PROFILES .. ") reached.")
            return false
        end
    end

    local specIdx = C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecialization() or 0
    local specID, specName = 0, ""
    if specIdx and specIdx > 0 then
        specID, specName = GetSpecializationInfo(specIdx)
    end

    profiles[name] = {
        slots     = ReadActionBarSlots(),
        slotCount = MAX_ACTIONBAR_SLOT,
        savedAt   = time(),
        savedBy   = GetCharacterKey(),
        specID    = specID or 0,
        specName  = specName or "",
    }

    db.activeProfile[cls] = name
    DjinniMsg("Saved profile: |cff00cc00" .. name .. "|r")
    ABP:UpdateData()
    return true
end

---------------------------------------------------------------------------
-- Core: Restore Profile
---------------------------------------------------------------------------

local function RestoreProfile(name, skipBackup)
    local db = ABP:GetDB()
    local cls = GetClassToken()
    local profiles = GetClassProfiles(db)
    local profile = profiles[name]
    if not profile then
        DjinniMsg("Profile not found: " .. name)
        return false
    end

    if InCombatLockdown() then
        ABP.pendingRestore = { name = name, skipBackup = skipBackup }
        DjinniMsg("In combat — profile will load when combat ends.")
        return false
    end

    -- Auto-backup current layout
    if not skipBackup then
        local specIdx = C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecialization() or 0
        local specID, specName = 0, ""
        if specIdx and specIdx > 0 then
            specID, specName = GetSpecializationInfo(specIdx)
        end
        db.previousLayout[cls] = {
            slots     = ReadActionBarSlots(),
            slotCount = MAX_ACTIONBAR_SLOT,
            savedAt   = time(),
            savedBy   = GetCharacterKey(),
            specID    = specID or 0,
            specName  = specName or "",
        }
    end

    -- Phase 1: Clear ALL slots
    for slotID = 1, MAX_ACTIONBAR_SLOT do
        if C_ActionBar.HasAction(slotID) then
            PickupAction(slotID)
            ClearCursor()
        end
    end

    -- Phase 2: Place saved actions
    local placed, failed = 0, 0
    for slotID, slotData in pairs(profile.slots) do
        if PlaceActionInSlot(slotID, slotData) then
            placed = placed + 1
        else
            failed = failed + 1
        end
    end

    db.activeProfile[cls] = name
    local msg = "Loaded profile: |cff00cc00" .. name .. "|r (" .. placed .. " placed"
    if failed > 0 then msg = msg .. ", " .. failed .. " skipped" end
    msg = msg .. ")"
    DjinniMsg(msg)

    ABP:UpdateData()
    return true
end

---------------------------------------------------------------------------
-- Core: Restore from raw profile data (for Previous Layout and MySlot)
---------------------------------------------------------------------------

local function RestoreFromData(profileData, label, skipBackup)
    if not profileData or not profileData.slots then
        DjinniMsg("No " .. (label or "layout") .. " data to restore.")
        return false
    end

    if InCombatLockdown() then
        DjinniMsg("In combat — cannot restore now.")
        return false
    end

    local db = ABP:GetDB()
    local cls = GetClassToken()

    -- Auto-backup
    if not skipBackup then
        local specIdx = C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecialization() or 0
        local specID, specName = 0, ""
        if specIdx and specIdx > 0 then
            specID, specName = GetSpecializationInfo(specIdx)
        end
        db.previousLayout[cls] = {
            slots     = ReadActionBarSlots(),
            slotCount = MAX_ACTIONBAR_SLOT,
            savedAt   = time(),
            savedBy   = GetCharacterKey(),
            specID    = specID or 0,
            specName  = specName or "",
        }
    end

    -- Clear ALL
    for slotID = 1, MAX_ACTIONBAR_SLOT do
        if C_ActionBar.HasAction(slotID) then
            PickupAction(slotID)
            ClearCursor()
        end
    end

    -- Place
    local placed, failed = 0, 0
    for slotID, slotData in pairs(profileData.slots) do
        if PlaceActionInSlot(slotID, slotData) then
            placed = placed + 1
        else
            failed = failed + 1
        end
    end

    local msg = "Restored " .. (label or "layout") .. " (" .. placed .. " placed"
    if failed > 0 then msg = msg .. ", " .. failed .. " skipped" end
    msg = msg .. ")"
    DjinniMsg(msg)

    ABP:UpdateData()
    return true
end

local function RestorePreviousLayout()
    local db = ABP:GetDB()
    local cls = GetClassToken()
    local prev = db.previousLayout[cls]
    if not prev then
        DjinniMsg("No previous layout stored.")
        return false
    end
    return RestoreFromData(prev, "Previous Layout", true)
end

---------------------------------------------------------------------------
-- Core: Delete / Rename
---------------------------------------------------------------------------

local function DeleteProfile(name)
    local db = ABP:GetDB()
    local cls = GetClassToken()
    local profiles = GetClassProfiles(db)
    if not profiles[name] then return false end
    profiles[name] = nil
    if db.activeProfile[cls] == name then
        db.activeProfile[cls] = nil
    end
    -- Clean auto-load refs
    for key, profName in pairs(db.autoLoadSpec) do
        if profName == name and key:find("^" .. cls) then
            db.autoLoadSpec[key] = nil
        end
    end
    DjinniMsg("Deleted profile: " .. name)
    ABP:UpdateData()
    return true
end

local function RenameProfile(oldName, newName)
    local db = ABP:GetDB()
    local cls = GetClassToken()
    local profiles = GetClassProfiles(db)
    if not profiles[oldName] then return false end
    if profiles[newName] then
        DjinniMsg("A profile named '" .. newName .. "' already exists.")
        return false
    end
    profiles[newName] = profiles[oldName]
    profiles[oldName] = nil
    if db.activeProfile[cls] == oldName then
        db.activeProfile[cls] = newName
    end
    for key, profName in pairs(db.autoLoadSpec) do
        if profName == oldName then
            db.autoLoadSpec[key] = newName
        end
    end
    DjinniMsg("Renamed profile: " .. oldName .. " → " .. newName)
    ABP:UpdateData()
    return true
end

local function GetSortedProfileList()
    local db = ABP:GetDB()
    local profiles = GetClassProfiles(db)
    local list = {}
    for name in pairs(profiles) do
        list[#list + 1] = name
    end
    table.sort(list)
    return list
end

---------------------------------------------------------------------------
-- MySlot compatibility: minimal protobuf decoder
---------------------------------------------------------------------------

-- Base64 decode (WoW-compatible, matches MySlot's charset)
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_LOOKUP = {}
for i = 1, #B64 do B64_LOOKUP[B64:byte(i)] = i - 1 end
B64_LOOKUP[string.byte("=")] = 0

local function Base64Decode(str)
    str = str:gsub("[^%w%+%/%=]", "")
    local bytes = {}
    for i = 1, #str, 4 do
        local b1 = B64_LOOKUP[str:byte(i)] or 0
        local b2 = B64_LOOKUP[str:byte(i + 1)] or 0
        local b3 = B64_LOOKUP[str:byte(i + 2)] or 0
        local b4 = B64_LOOKUP[str:byte(i + 3)] or 0
        local n = b1 * 262144 + b2 * 4096 + b3 * 64 + b4
        bytes[#bytes + 1] = bit.band(bit.rshift(n, 16), 255)
        if str:byte(i + 2) ~= string.byte("=") then
            bytes[#bytes + 1] = bit.band(bit.rshift(n, 8), 255)
        end
        if str:byte(i + 3) ~= string.byte("=") then
            bytes[#bytes + 1] = bit.band(n, 255)
        end
    end
    return bytes
end

local function Base64Encode(bytes)
    local result = {}
    for i = 1, #bytes, 3 do
        local b1 = bytes[i] or 0
        local b2 = bytes[i + 1] or 0
        local b3 = bytes[i + 2] or 0
        local n = b1 * 65536 + b2 * 256 + b3
        result[#result + 1] = B64:sub(bit.rshift(n, 18) + 1, bit.rshift(n, 18) + 1)
        result[#result + 1] = B64:sub(bit.band(bit.rshift(n, 12), 63) + 1, bit.band(bit.rshift(n, 12), 63) + 1)
        if i + 1 <= #bytes then
            result[#result + 1] = B64:sub(bit.band(bit.rshift(n, 6), 63) + 1, bit.band(bit.rshift(n, 6), 63) + 1)
        else
            result[#result + 1] = "="
        end
        if i + 2 <= #bytes then
            result[#result + 1] = B64:sub(bit.band(n, 63) + 1, bit.band(n, 63) + 1)
        else
            result[#result + 1] = "="
        end
    end
    return table.concat(result)
end

-- Minimal protobuf varint decoder
local function DecodeVarint(bytes, pos)
    local result = 0
    local shift = 0
    while pos <= #bytes do
        local b = bytes[pos]
        result = result + bit.band(b, 0x7F) * (2 ^ shift)
        pos = pos + 1
        if bit.band(b, 0x80) == 0 then
            return result, pos
        end
        shift = shift + 7
    end
    return result, pos
end

-- Decode a protobuf sub-message (Slot) from bytes
local function DecodeSlot(bytes, startPos, endPos)
    local slot = {}
    local pos = startPos
    while pos <= endPos do
        local tag, newPos = DecodeVarint(bytes, pos)
        pos = newPos
        local fieldNum = bit.rshift(tag, 3)
        local wireType = bit.band(tag, 7)

        if wireType == 0 then -- varint
            local val
            val, pos = DecodeVarint(bytes, pos)
            if fieldNum == 1 then slot.id = val
            elseif fieldNum == 2 then slot.slotType = val
            elseif fieldNum == 3 then slot.index = val
            end
        elseif wireType == 2 then -- length-delimited
            local len
            len, pos = DecodeVarint(bytes, pos)
            if fieldNum == 4 then -- strindex
                local chars = {}
                for i = pos, pos + len - 1 do
                    chars[#chars + 1] = string.char(bytes[i])
                end
                slot.strindex = table.concat(chars)
            end
            pos = pos + len
        else
            -- skip unknown wire types
            if wireType == 5 then pos = pos + 4
            elseif wireType == 1 then pos = pos + 8
            end
        end
    end
    return slot
end

-- Decode the Charactor message, extracting only slot field (field 1)
local function DecodeMySlotPayload(bytes)
    local slots = {}
    local pos = 1
    while pos <= #bytes do
        local tag, newPos = DecodeVarint(bytes, pos)
        pos = newPos
        local fieldNum = bit.rshift(tag, 3)
        local wireType = bit.band(tag, 7)

        if wireType == 0 then -- varint
            local _
            _, pos = DecodeVarint(bytes, pos)
        elseif wireType == 2 then -- length-delimited
            local len
            len, pos = DecodeVarint(bytes, pos)
            if fieldNum == 1 then -- repeated Slot slot = 1
                local slot = DecodeSlot(bytes, pos, pos + len - 1)
                if slot.id then
                    slots[#slots + 1] = slot
                end
            end
            pos = pos + len
        elseif wireType == 5 then pos = pos + 4
        elseif wireType == 1 then pos = pos + 8
        end
    end
    return slots
end

-- MySlot SlotType enum values
local MYSLOT_TYPE_SPELL       = 1
local MYSLOT_TYPE_ITEM        = 2
local MYSLOT_TYPE_MACRO       = 3
local MYSLOT_TYPE_FLYOUT      = 4
local MYSLOT_TYPE_EMPTY       = 5
local MYSLOT_TYPE_EQUIPSET    = 6
local MYSLOT_TYPE_SUMMONPET   = 7
local MYSLOT_TYPE_COMPANION   = 8
local MYSLOT_TYPE_SUMMONMOUNT = 9

-- Convert MySlot slot to DDT slot format
local function ConvertMySlotSlot(msSlot)
    local st = msSlot.slotType
    if st == MYSLOT_TYPE_SPELL or st == MYSLOT_TYPE_COMPANION then
        return { type = "spell", id = msSlot.index }
    elseif st == MYSLOT_TYPE_ITEM then
        return { type = "item", id = msSlot.index }
    elseif st == MYSLOT_TYPE_MACRO then
        -- Resolve macro name from index
        local macroName = nil
        if msSlot.index and msSlot.index > 0 then
            macroName = GetMacroInfo(msSlot.index)
        end
        return { type = "macro", name = macroName or ("Macro" .. msSlot.index), index = msSlot.index }
    elseif st == MYSLOT_TYPE_FLYOUT then
        return { type = "flyout", id = msSlot.index }
    elseif st == MYSLOT_TYPE_SUMMONPET then
        return { type = "summonpet", id = msSlot.strindex or msSlot.index }
    elseif st == MYSLOT_TYPE_SUMMONMOUNT then
        -- Convert mountID → spellID
        if C_MountJournal and C_MountJournal.GetMountInfoByID then
            local _, spellID = C_MountJournal.GetMountInfoByID(msSlot.index)
            if spellID then
                return { type = "spell", id = spellID }
            end
        end
        return nil
    elseif st == MYSLOT_TYPE_EMPTY then
        return nil
    end
    return nil
end

-- Decode a full MySlot export string into a DDT profile table
local function DecodeMySlotExport(text)
    -- Strip comments and whitespace
    text = text:gsub("(@[^\n]*\n*)", "")
    text = text:gsub("(#[^\n]*\n*)", "")
    text = text:gsub("\n", "")
    text = text:gsub("\r", "")

    local bytes = Base64Decode(text)
    if #bytes < 8 then return nil end

    -- Check header: ver=42, nonce=86,04,22
    if bytes[1] ~= 42 or bytes[2] ~= 86 or bytes[3] ~= 4 or bytes[4] ~= 22 then
        return nil
    end

    -- Skip CRC check (we don't have MySlot's crc32 lib)
    -- Extract payload after 8-byte header
    local payload = {}
    for i = 9, #bytes do
        payload[#payload + 1] = bytes[i]
    end

    local msSlots = DecodeMySlotPayload(payload)
    local slots = {}
    for _, msSlot in ipairs(msSlots) do
        local ddtSlot = ConvertMySlotSlot(msSlot)
        if ddtSlot and msSlot.id then
            slots[msSlot.id] = ddtSlot
        end
    end

    return {
        slots     = slots,
        slotCount = MAX_ACTIONBAR_SLOT,
        savedAt   = time(),
        savedBy   = "MySlot Import",
        specID    = 0,
        specName  = "",
    }
end

-- Get MySlot profiles from SavedVariables (if MySlot installed)
local function GetMySlotProfiles()
    if type(MyslotExports) ~= "table" then return {} end
    local exports = MyslotExports["exports"]
    if type(exports) ~= "table" then return {} end
    return exports
end

-- Restore a MySlot profile by decoding and restoring
local function RestoreMySlotProfile(index)
    local exports = GetMySlotProfiles()
    local entry = exports[index]
    if not entry or not entry.value then
        DjinniMsg("MySlot profile not found.")
        return false
    end

    local profile = DecodeMySlotExport(entry.value)
    if not profile then
        DjinniMsg("Failed to decode MySlot profile.")
        return false
    end

    return RestoreFromData(profile, "MySlot: " .. (entry.name or "Unknown"), false)
end

---------------------------------------------------------------------------
-- Export / Import: DDT Native Format
---------------------------------------------------------------------------

local DDT_EXPORT_VERSION = 1

local function EscapePipe(s)
    return s:gsub("|", "||")
end

local function UnescapePipe(s)
    return s:gsub("||", "|")
end

local function SerializeProfile(name, profile, classToken)
    -- Header: DDT-ABP|name|class|specName|timestamp|version
    -- Pipes in name/specName are escaped as ||
    local parts = { "DDT-ABP" }
    parts[#parts + 1] = EscapePipe(name)
    parts[#parts + 1] = classToken
    parts[#parts + 1] = EscapePipe(profile.specName or "")
    parts[#parts + 1] = tostring(profile.savedAt or 0)
    parts[#parts + 1] = tostring(DDT_EXPORT_VERSION)
    local header = table.concat(parts, "|")

    -- Slot data: slotID:type:id[:name]
    -- Macro name is always the last field so colons in it are safe
    local slotParts = {}
    for slotID, data in pairs(profile.slots) do
        local entry = slotID .. ":" .. data.type .. ":" .. tostring(data.id or 0)
        if data.name and data.name ~= "" then
            entry = entry .. ":" .. data.name
        end
        slotParts[#slotParts + 1] = entry
    end
    local body = table.concat(slotParts, "|")

    -- Encode body as base64
    local bodyBytes = {}
    for i = 1, #body do
        bodyBytes[i] = body:byte(i)
    end

    return "# " .. header .. "\n" .. Base64Encode(bodyBytes)
end

local function DeserializeProfile(text)
    -- Find header line
    local headerLine = text:match("# (DDT%-ABP|[^\n]+)")
    if not headerLine then return nil end

    -- Split header on single | (not ||). Use a simple approach: split all,
    -- then rejoin any adjacent empty entries caused by || escapes.
    local rawParts = {}
    for part in (headerLine .. "|"):gmatch("(.-)|") do
        rawParts[#rawParts + 1] = part
    end
    -- Rejoin || escapes: empty entry between two | means escaped pipe
    local parts = {}
    local i = 1
    while i <= #rawParts do
        if rawParts[i] == "" and i > 1 then
            -- || escape: append pipe to previous part
            parts[#parts] = (parts[#parts] or "") .. "|"
            i = i + 1
        else
            parts[#parts + 1] = rawParts[i]
            i = i + 1
        end
    end
    if parts[1] ~= "DDT-ABP" or #parts < 6 then return nil end

    local name = parts[2]
    local classToken = parts[3]
    local specName = parts[4]
    local savedAt = tonumber(parts[5]) or 0

    -- Extract base64 body (skip comment lines)
    local bodyB64 = text:gsub("(#[^\n]*\n?)", ""):gsub("%s+", "")
    if bodyB64 == "" then return nil end

    local bodyBytes = Base64Decode(bodyB64)
    local body = {}
    for _, b in ipairs(bodyBytes) do
        body[#body + 1] = string.char(b)
    end
    body = table.concat(body)

    -- Parse slot entries
    local slots = {}
    for entry in body:gmatch("[^|]+") do
        -- Split on first 3 colons only; remainder is macro name (may contain colons)
        local slotStr, slotType, rest = entry:match("^(%d+):(%a+):(.+)$")
        local slotID = tonumber(slotStr)
        if slotID and slotType then
            local slotData = { type = slotType }
            if slotType == "macro" then
                local idStr, macroName = rest:match("^(%d+):(.+)$")
                if idStr then
                    slotData.index = tonumber(idStr) or 0
                    slotData.name = macroName
                else
                    slotData.index = tonumber(rest) or 0
                    slotData.name = ""
                end
                slotData.id = slotData.index
            else
                slotData.id = tonumber(rest) or rest
            end
            slots[slotID] = slotData
        end
    end

    return {
        name = name,
        classToken = classToken,
        profile = {
            slots     = slots,
            slotCount = MAX_ACTIONBAR_SLOT,
            savedAt   = savedAt,
            savedBy   = "Imported",
            specID    = 0,
            specName  = specName,
        },
    }
end

---------------------------------------------------------------------------
-- Export / Import: Full Config
---------------------------------------------------------------------------

-- Simple recursive table serializer (no metatables, no cycles)
local function SerializeTable(tbl, depth)
    depth = depth or 0
    if depth > 20 then return "nil" end
    local parts = { "{" }
    for k, v in pairs(tbl) do
        local keyStr
        if type(k) == "number" then
            keyStr = "[" .. k .. "]"
        else
            keyStr = '["' .. tostring(k):gsub('"', '\\"') .. '"]'
        end

        local valStr
        if type(v) == "table" then
            valStr = SerializeTable(v, depth + 1)
        elseif type(v) == "string" then
            valStr = '"' .. v:gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
        elseif type(v) == "number" or type(v) == "boolean" then
            valStr = tostring(v)
        else
            valStr = "nil"
        end

        parts[#parts + 1] = keyStr .. "=" .. valStr .. ","
    end
    parts[#parts + 1] = "}"
    return table.concat(parts)
end

-- Simple table deserializer (load as Lua)
local function DeserializeTable(str)
    local fn, err = loadstring("return " .. str)
    if not fn then return nil end
    -- Sandbox: no access to globals
    setfenv(fn, {})
    local ok, result = pcall(fn)
    if ok and type(result) == "table" then
        return result
    end
    return nil
end

local function ExportFullConfig()
    local db = ABP:GetDB()
    local data = {
        profiles      = db.profiles,
        activeProfile = db.activeProfile,
        autoLoadSpec  = db.autoLoadSpec,
        previousLayout = db.previousLayout,
    }
    local serialized = SerializeTable(data)
    local bytes = {}
    for i = 1, #serialized do bytes[i] = serialized:byte(i) end
    return "# DDT-ABP-FULL|" .. DDT_EXPORT_VERSION .. "|" .. time() .. "\n" .. Base64Encode(bytes)
end

local function ImportFullConfig(text)
    local header = text:match("# (DDT%-ABP%-FULL|[^\n]+)")
    if not header then return false, "Not a DDT full config export." end

    local bodyB64 = text:gsub("(#[^\n]*\n?)", ""):gsub("%s+", "")
    if bodyB64 == "" then return false, "Empty export data." end

    local bodyBytes = Base64Decode(bodyB64)
    local body = {}
    for _, b in ipairs(bodyBytes) do body[#body + 1] = string.char(b) end
    body = table.concat(body)

    local imported = DeserializeTable(body)
    if not imported then return false, "Failed to decode config data." end

    local db = ABP:GetDB()
    local profileCount = 0
    local overwriteCount = 0

    -- Merge profiles
    if type(imported.profiles) == "table" then
        for cls, clsProfiles in pairs(imported.profiles) do
            if type(clsProfiles) == "table" then
                if not db.profiles[cls] then db.profiles[cls] = {} end
                for name, profile in pairs(clsProfiles) do
                    if db.profiles[cls][name] then
                        overwriteCount = overwriteCount + 1
                    end
                    db.profiles[cls][name] = profile
                    profileCount = profileCount + 1
                end
            end
        end
    end

    -- Merge auto-load spec mappings
    if type(imported.autoLoadSpec) == "table" then
        for key, val in pairs(imported.autoLoadSpec) do
            db.autoLoadSpec[key] = val
        end
    end

    -- Merge activeProfile
    if type(imported.activeProfile) == "table" then
        for cls, name in pairs(imported.activeProfile) do
            db.activeProfile[cls] = name
        end
    end

    -- Merge previousLayout
    if type(imported.previousLayout) == "table" then
        for cls, layout in pairs(imported.previousLayout) do
            db.previousLayout[cls] = layout
        end
    end

    local msg = "Imported " .. profileCount .. " profiles."
    if overwriteCount > 0 then
        msg = msg .. " (" .. overwriteCount .. " overwritten)"
    end
    DjinniMsg(msg)
    ABP:UpdateData()
    return true
end

-- Auto-detect import format and process
local function ImportString(text)
    if not text or text == "" then return false, "Empty import string." end

    -- Check for DDT full config
    if text:find("DDT%-ABP%-FULL") then
        return ImportFullConfig(text)
    end

    -- Check for DDT single profile
    if text:find("DDT%-ABP|") then
        local result = DeserializeProfile(text)
        if not result then return false, "Failed to decode DDT profile." end
        local db = ABP:GetDB()
        local cls = result.classToken or GetClassToken()
        if not db.profiles[cls] then db.profiles[cls] = {} end
        db.profiles[cls][result.name] = result.profile
        DjinniMsg("Imported profile: " .. result.name .. " (" .. cls .. ")")
        ABP:UpdateData()
        return true
    end

    -- Check for MySlot format (try base64 decode and check header)
    local cleaned = text:gsub("(@[^\n]*\n*)", ""):gsub("(#[^\n]*\n*)", ""):gsub("%s+", "")
    if cleaned ~= "" then
        local bytes = Base64Decode(cleaned)
        if #bytes >= 8 and bytes[1] == 42 and bytes[2] == 86 and bytes[3] == 4 and bytes[4] == 22 then
            local profile = DecodeMySlotExport(text)
            if profile then
                -- Prompt handled by caller — store with a generated name
                local name = "MySlot Import " .. date("%Y-%m-%d %H:%M")
                local db = ABP:GetDB()
                local cls = GetClassToken()
                if not db.profiles[cls] then db.profiles[cls] = {} end
                db.profiles[cls][name] = profile
                DjinniMsg("Imported MySlot profile as: " .. name)
                ABP:UpdateData()
                return true
            end
        end
    end

    return false, "Unrecognized import format."
end

---------------------------------------------------------------------------
-- Auto-load on spec change
---------------------------------------------------------------------------

local function CheckAutoLoadSpec()
    local db = ABP:GetDB()
    local cls = GetClassToken()
    local specIdx = C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecialization()
    if not specIdx or specIdx == 0 then return end
    local specID = GetSpecializationInfo(specIdx)
    if not specID then return end

    local key = cls .. "-" .. specID
    local profileName = db.autoLoadSpec[key]
    if not profileName then return end

    -- Guard: skip if already active
    if db.activeProfile[cls] == profileName then return end

    local profiles = GetClassProfiles(db)
    if profiles[profileName] then
        DjinniMsg("Auto-loading profile for spec: |cff00cc00" .. profileName .. "|r")
        RestoreProfile(profileName, false)
    end
end

---------------------------------------------------------------------------
-- Label expansion
---------------------------------------------------------------------------

local function ExpandLabel(template)
    local db = ABP:GetDB()
    local cls = GetClassToken()
    local E = ns.ExpandTag
    local result = template

    local activeName = db.activeProfile[cls] or "None"
    result = E(result, "profile", activeName)

    local profiles = GetClassProfiles(db)
    local count = 0
    for _ in pairs(profiles) do count = count + 1 end
    result = E(result, "count", count)

    local _, className = UnitClass("player")
    result = E(result, "class", className or "")

    result = E(result, "spec", ABP.currentSpec or "")

    return result
end

ABP.ExpandLabel = ExpandLabel

---------------------------------------------------------------------------
-- Click action executor
---------------------------------------------------------------------------

local function ExecuteAction(action)
    if not action or action == "none" then return end

    if action == "loadnext" or action == "loadprev" then
        local list = GetSortedProfileList()
        if #list == 0 then return end
        local db = ABP:GetDB()
        local cls = GetClassToken()
        local active = db.activeProfile[cls]
        local curIdx = 0
        for i, name in ipairs(list) do
            if name == active then curIdx = i; break end
        end
        local nextIdx
        if action == "loadnext" then
            nextIdx = (curIdx % #list) + 1
        else
            nextIdx = curIdx > 1 and (curIdx - 1) or #list
        end
        RestoreProfile(list[nextIdx], false)

    elseif action == "savecurrent" then
        local db = ABP:GetDB()
        local cls = GetClassToken()
        local active = db.activeProfile[cls]
        if active then
            SaveProfile(active)
        else
            DjinniMsg("No active profile. Save from tooltip or settings.")
        end

    elseif action == "undorestore" then
        RestorePreviousLayout()

    elseif action == "opensettings" then
        if DDT.settingsCategoryID then
            Settings.OpenToCategory(DDT.settingsCategoryID)
        end
    end
end

---------------------------------------------------------------------------
-- LDB Data Object
---------------------------------------------------------------------------

local dataobj = LDB:NewDataObject("DDT-ActionBarProfiles", {
    type  = "data source",
    text  = "Action Bar Profiles",
    icon  = "Interface\\Icons\\INV_Misc_Book_09",
    label = "DDT - Action Bar Profiles",
    OnEnter = function(self)
        ABP:ShowTooltip(self)
    end,
    OnLeave = function(self)
        ABP:StartHideTimer()
    end,
    OnClick = function(self, button)
        local db = ABP:GetDB()
        local action = DDT:ResolveClickAction(button, db.clickActions or {})
        ExecuteAction(action)
    end,
})

ABP.dataobj = dataobj

---------------------------------------------------------------------------
-- Event handling
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

function ABP:Init()
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            if ABP.pendingRestore then
                local pr = ABP.pendingRestore
                ABP.pendingRestore = nil
                RestoreProfile(pr.name, pr.skipBackup)
            end
            return
        end
        if event == "PLAYER_SPECIALIZATION_CHANGED" then
            ABP:UpdateData()
            CheckAutoLoadSpec()
            return
        end
        if event == "PLAYER_ENTERING_WORLD" then
            ABP:UpdateData()
            -- Check auto-load on login
            C_Timer.After(2, CheckAutoLoadSpec)
            return
        end
        ABP:UpdateData()
    end)

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    self:UpdateData()
end

---------------------------------------------------------------------------
-- Data collection
---------------------------------------------------------------------------

function ABP:UpdateData()
    local _, classToken = UnitClass("player")
    self.currentClass = classToken or "UNKNOWN"

    local specIdx = C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecialization()
    if specIdx and specIdx > 0 then
        local specID, specName = GetSpecializationInfo(specIdx)
        self.currentSpecID = specID or 0
        self.currentSpec = specName or ""
    else
        self.currentSpecID = 0
        self.currentSpec = ""
    end

    self.profileList = GetSortedProfileList()

    local db = self:GetDB()
    dataobj.text = ExpandLabel(db.labelTemplate)

    if tooltipFrame and tooltipFrame:IsShown() then
        self:BuildTooltipContent()
    end
end

---------------------------------------------------------------------------
-- Tooltip frame creation
---------------------------------------------------------------------------

local function CreateTooltipFrame()
    return ns.CreateTooltipFrame("DDTActionBarProfilesTooltip", ABP)
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

    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, 0.08)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.text = ns.FontString(row, "DDTFontNormal")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.text:SetJustifyH("LEFT")

    row.status = ns.FontString(row, "DDTFontNormal")
    row.status:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.status:SetJustifyH("RIGHT")

    row.activeBar = row:CreateTexture(nil, "BACKGROUND")
    row.activeBar:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.activeBar:SetSize(3, ROW_HEIGHT - 4)
    row.activeBar:SetColorTexture(0.2, 0.8, 0.2, 0.8)

    row:SetScript("OnEnter", function() ABP:CancelHideTimer() end)
    row:SetScript("OnLeave", function() ABP:StartHideTimer() end)

    rowPool[index] = row
    return row
end

local function GetHeader(parent, index)
    if headerPool[index] then
        headerPool[index]:Show()
        return headerPool[index]
    end
    local hdr = ns.FontString(parent, "DDTFontNormal")
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
-- Tooltip: Save EditBox (inline profile name entry)
---------------------------------------------------------------------------

local saveEditBox = nil

local function GetSaveEditBox(parent)
    if saveEditBox then
        saveEditBox:SetParent(parent)
        saveEditBox:Show()
        return saveEditBox
    end

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(24)

    local eb = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    eb:SetPoint("LEFT", frame, "LEFT", 8, 0)
    eb:SetPoint("RIGHT", frame, "RIGHT", -60, 0)
    eb:SetHeight(20)
    eb:SetAutoFocus(false)
    eb:SetFontObject("DDTFontNormal")

    local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btn:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
    btn:SetSize(52, 20)
    btn:SetText("Save")

    local function DoSave()
        local name = strtrim(eb:GetText())
        if name ~= "" then
            SaveProfile(name)
            eb:SetText("")
        end
    end

    btn:SetScript("OnClick", DoSave)
    eb:SetScript("OnEnterPressed", function(self)
        DoSave()
        self:ClearFocus()
    end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- Keep tooltip alive while interacting
    eb:SetScript("OnEditFocusGained", function() ABP:CancelHideTimer() end)

    saveEditBox = frame
    saveEditBox.editBox = eb
    return saveEditBox
end

---------------------------------------------------------------------------
-- Tooltip content building
---------------------------------------------------------------------------

function ABP:BuildTooltipContent()
    HideAllPooled()
    if saveEditBox then saveEditBox:Hide() end

    local f = tooltipFrame
    local c = f.content
    local db = self:GetDB()
    local cls = GetClassToken()
    f.header:SetText("Action Bar Profiles")

    local rowIndex = 0
    local headerIndex = 0
    local sepIndex = 0
    local y = 0

    -- ── Class Profiles ────────────────────────────────────────
    local profileList = self.profileList
    local activeName = db.activeProfile[cls]

    headerIndex = headerIndex + 1
    local profHdr = GetHeader(c, headerIndex)
    profHdr:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
    local _, className = UnitClass("player")
    profHdr:SetText((className or cls) .. " Profiles (" .. #profileList .. ")")
    y = y - HEADER_HEIGHT

    if #profileList == 0 then
        rowIndex = rowIndex + 1
        local row = GetRow(c, rowIndex)
        row:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
        row:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
        row.icon:Hide()
        row.text:SetText("  |cff888888No profiles saved|r")
        row.text:SetPoint("LEFT", row, "LEFT", ICON_SIZE + 10, 0)
        row.status:SetText("")
        row.activeBar:Hide()
        row:SetScript("OnClick", nil)
        y = y - ROW_HEIGHT
    else
        for _, name in ipairs(profileList) do
            rowIndex = rowIndex + 1
            local row = GetRow(c, rowIndex)
            row:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
            row:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)

            row.icon:Hide()
            row.text:SetText("  " .. name)
            row.text:SetPoint("LEFT", row, "LEFT", ICON_SIZE + 10, 0)

            local isActive = (name == activeName)
            if isActive then
                row.status:SetText("|cff00cc00Active|r")
                row.activeBar:Show()
                row.text:SetTextColor(1, 1, 1)
            else
                row.status:SetText("")
                row.activeBar:Hide()
                row.text:SetTextColor(0.7, 0.7, 0.7)
            end

            local profName = name
            row:SetScript("OnClick", function()
                RestoreProfile(profName, false)
            end)

            y = y - ROW_HEIGHT
        end
    end

    -- Previous Layout row
    local hasPrev = db.previousLayout[cls] ~= nil
    if hasPrev then
        rowIndex = rowIndex + 1
        local row = GetRow(c, rowIndex)
        row:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
        row:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)

        row.icon:Hide()
        row.text:SetText("  |cff888888[Previous Layout]|r")
        row.text:SetPoint("LEFT", row, "LEFT", ICON_SIZE + 10, 0)
        row.status:SetText("|cffaaaa00Undo|r")
        row.activeBar:Hide()
        row.text:SetTextColor(0.5, 0.5, 0.5)

        row:SetScript("OnClick", function()
            RestorePreviousLayout()
        end)
        y = y - ROW_HEIGHT
    end

    -- ── MySlot Profiles ───────────────────────────────────────
    if db.showMySlot then
        local msProfiles = GetMySlotProfiles()
        if #msProfiles > 0 then
            y = y - 4
            sepIndex = sepIndex + 1
            local sep = GetSeparator(c, sepIndex)
            sep:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
            sep:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
            y = y - 6

            headerIndex = headerIndex + 1
            local msHdr = GetHeader(c, headerIndex)
            msHdr:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
            msHdr:SetText("MySlot Profiles (" .. #msProfiles .. ")")
            y = y - HEADER_HEIGHT

            for i, entry in ipairs(msProfiles) do
                rowIndex = rowIndex + 1
                local row = GetRow(c, rowIndex)
                row:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
                row:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)

                row.icon:Hide()
                row.text:SetText("  " .. (entry.name or "Export " .. i))
                row.text:SetPoint("LEFT", row, "LEFT", ICON_SIZE + 10, 0)
                row.status:SetText("")
                row.activeBar:Hide()
                row.text:SetTextColor(0.6, 0.8, 1.0)

                local msIndex = i
                row:SetScript("OnClick", function()
                    RestoreMySlotProfile(msIndex)
                end)
                y = y - ROW_HEIGHT
            end
        end
    end

    -- ── Save row ──────────────────────────────────────────────
    y = y - 4
    sepIndex = sepIndex + 1
    local sep = GetSeparator(c, sepIndex)
    sep:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
    sep:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
    y = y - 6

    local saveRow = GetSaveEditBox(c)
    saveRow:SetPoint("TOPLEFT", c, "TOPLEFT", PADDING, y)
    saveRow:SetPoint("RIGHT", c, "RIGHT", -PADDING, 0)
    y = y - 28

    -- ── Hint bar ──────────────────────────────────────────────
    local hintText = DDT:BuildHintText(db.clickActions or {}, CLICK_ACTIONS)
    f.hint:SetText(hintText ~= "" and hintText or "|cff888888Click a profile to load|r")

    local ttWidth = db.tooltipWidth or TOOLTIP_WIDTH
    f:FinalizeLayout(ttWidth, math.abs(y))
end

---------------------------------------------------------------------------
-- Tooltip show/hide
---------------------------------------------------------------------------

function ABP:ShowTooltip(anchor)
    self:CancelHideTimer()

    if not tooltipFrame then
        tooltipFrame = CreateTooltipFrame()
    end

    local db = self:GetDB()
    ns.AnchorTooltip(tooltipFrame, anchor, db.tooltipGrowDirection)
    tooltipFrame:SetScale(db.tooltipScale or 1.0)

    self:UpdateData()
    self:BuildTooltipContent()

    tooltipFrame:Show()
end

function ABP:StartHideTimer()
    self:CancelHideTimer()
    hideTimer = C_Timer.NewTimer(ns.HIDE_DELAY, function()
        if tooltipFrame then tooltipFrame:Hide() end
        hideTimer = nil
    end)
end

function ABP:CancelHideTimer()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
end

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------

ABP.settingsLabel = "Action Bar Profiles"

function ABP:BuildSettingsPanel(panel)
    local W = ns.SettingsWidgets
    local r = panel.refreshCallbacks
    local db = function() return ns.db.actionbarprofiles end

    -- ── Label Template ────────────────────────────────────────
    W.AddLabelEditBox(panel, "profile count class spec",
        function() return db().labelTemplate end,
        function(v) db().labelTemplate = v; self:UpdateData() end, r, {
        { "Default",    "<profile>" },
        { "With Count", "<profile> (<count>)" },
        { "Class",      "<class>: <profile>" },
        { "Spec Bars",  "<spec> Bars" },
    })

    -- ── Tooltip ───────────────────────────────────────────────
    local body = W.AddSection(panel, "Tooltip", true)
    local y = 0
    y = W.AddSliderPair(body, y,
        { label = "Scale", min = 0.5, max = 2.0, step = 0.05,
          get = function() return db().tooltipScale end,
          set = function(v) db().tooltipScale = v end },
        { label = "Width", min = 200, max = 500, step = 10,
          get = function() return db().tooltipWidth end,
          set = function(v) db().tooltipWidth = v end }, r)
    y = W.AddSliderPair(body, y,
        { label = "Max Height", min = 100, max = 1000, step = 10,
          get = function() return db().tooltipMaxHeight end,
          set = function(v) db().tooltipMaxHeight = v end },
        nil, r)
    y = W.AddTooltipGrowDirection(body, y, db, r)
    y = W.AddTooltipCopyFrom(body, y, "actionbarprofiles", db, r)
    W.EndSection(panel, y)

    -- ── Profile Management ────────────────────────────────────
    local profBody = W.AddSection(panel, "Profile Management")
    y = 0

    -- Save current bars
    y = W.AddDescription(profBody, y, "Enter a name and click Save to snapshot your current action bars.")

    local saveFrame = CreateFrame("Frame", nil, profBody)
    saveFrame:SetPoint("TOPLEFT", profBody, "TOPLEFT", 18, y)
    saveFrame:SetSize(500, 30)

    local saveEB = CreateFrame("EditBox", nil, saveFrame, "InputBoxTemplate")
    saveEB:SetPoint("LEFT", saveFrame, "LEFT", 4, 0)
    saveEB:SetSize(300, 22)
    saveEB:SetAutoFocus(false)

    local saveBtn = CreateFrame("Button", nil, saveFrame, "UIPanelButtonTemplate")
    saveBtn:SetPoint("LEFT", saveEB, "RIGHT", 8, 0)
    saveBtn:SetSize(140, 22)
    saveBtn:SetText("Save Current Bars")

    local function DoSettingsSave()
        local name = strtrim(saveEB:GetText())
        if name == "" then return end
        -- Confirm overwrite if profile already exists
        local existing = GetClassProfiles(ABP:GetDB())
        if existing[name] then
            StaticPopupDialogs["DDT_ABP_OVERWRITE"] = {
                text = "Overwrite existing profile '|cff00cc00" .. name .. "|r'?",
                button1 = "Overwrite",
                button2 = "Cancel",
                OnAccept = function()
                    SaveProfile(name)
                    saveEB:SetText("")
                    ABP:RebuildProfileListUI(profBody)
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
            StaticPopup_Show("DDT_ABP_OVERWRITE")
        else
            SaveProfile(name)
            saveEB:SetText("")
            ABP:RebuildProfileListUI(profBody)
        end
    end

    saveBtn:SetScript("OnClick", DoSettingsSave)
    saveEB:SetScript("OnEnterPressed", function(self)
        DoSettingsSave()
        self:ClearFocus()
    end)
    saveEB:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    y = y - 36

    -- Profile list container
    local listContainer = CreateFrame("Frame", nil, profBody)
    listContainer:SetPoint("TOPLEFT", profBody, "TOPLEFT", 18, y)
    listContainer:SetPoint("RIGHT", profBody, "RIGHT", -18, 0)
    listContainer:SetHeight(1) -- will be resized

    profBody._listContainer = listContainer
    profBody._listY = y
    profBody._profileRows = {}

    self:RebuildProfileListUI(profBody)
    W.EndSection(panel, y - 10) -- approximate

    -- ── Auto-Load by Spec ─────────────────────────────────────
    local specBody = W.AddSection(panel, "Auto-Load on Spec Change", true)
    y = 0
    y = W.AddDescription(specBody, y, "Automatically load a profile when switching to a specialization. Applies to all characters of this class.")

    local cls = GetClassToken()
    local numSpecs = GetNumSpecializations and GetNumSpecializations() or 0
    for i = 1, numSpecs do
        local specID, specName = GetSpecializationInfo(i)
        if specID and specName then
            local specKey = cls .. "-" .. specID

            -- Manual dropdown since profile list is dynamic
            local specLabel = specBody:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            specLabel:SetPoint("TOPLEFT", specBody, "TOPLEFT", 18, y)
            specLabel:SetText(specName)

            local specDD = CreateFrame("DropdownButton", nil, specBody, "WowStyle1DropdownTemplate")
            specDD:SetPoint("TOPLEFT", specLabel, "BOTTOMLEFT", 0, -2)
            specDD:SetWidth(200)

            local capturedKey = specKey
            specDD:SetupMenu(function(_, rootDescription)
                rootDescription:CreateButton("(None)", function()
                    db().autoLoadSpec[capturedKey] = nil
                end):SetIsSelected(function() return not db().autoLoadSpec[capturedKey] end)

                local profiles = GetSortedProfileList()
                for _, pName in ipairs(profiles) do
                    local capturedName = pName
                    rootDescription:CreateButton(pName, function()
                        db().autoLoadSpec[capturedKey] = capturedName
                    end):SetIsSelected(function() return db().autoLoadSpec[capturedKey] == capturedName end)
                end
            end)

            if r then
                table.insert(r, function() specDD:GenerateMenu() end)
            end
            y = y - 54
        end
    end
    W.EndSection(panel, y)

    -- ── Import / Export ───────────────────────────────────────
    local ioBody = W.AddSection(panel, "Import / Export", true)
    y = 0

    -- Export buttons
    y = W.AddButton(ioBody, y, "Export Current Profile", function()
        local dbData = ABP:GetDB()
        local activeName = dbData.activeProfile[cls]
        if not activeName then
            DjinniMsg("No active profile to export.")
            return
        end
        local profiles = GetClassProfiles(dbData)
        local profile = profiles[activeName]
        if not profile then return end
        local exportStr = SerializeProfile(activeName, profile, cls)
        DDT:CopyToClipboard(exportStr, "Profile: " .. activeName)
    end)

    y = W.AddButton(ioBody, y, "Export All Profiles", function()
        local exportStr = ExportFullConfig()
        DDT:CopyToClipboard(exportStr, "Full Config Export")
    end)

    y = y - 8

    -- Import editbox
    y = W.AddDescription(ioBody, y, "Paste a DDT profile, full config, or MySlot export below:")

    local importEB = CreateFrame("EditBox", nil, ioBody, "InputBoxTemplate")
    importEB:SetPoint("TOPLEFT", ioBody, "TOPLEFT", 22, y)
    importEB:SetSize(400, 22)
    importEB:SetAutoFocus(false)
    y = y - 28

    local importBtn = CreateFrame("Button", nil, ioBody, "UIPanelButtonTemplate")
    importBtn:SetPoint("TOPLEFT", ioBody, "TOPLEFT", 22, y)
    importBtn:SetSize(120, 22)
    importBtn:SetText("Import")

    importBtn:SetScript("OnClick", function()
        local text = strtrim(importEB:GetText())
        local success, err = ImportString(text)
        if success then
            importEB:SetText("")
            DjinniMsg("Import successful.")
        else
            DjinniMsg("Import failed: " .. (err or "unknown error"))
        end
    end)
    importEB:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    y = y - 28

    -- MySlot toggle
    y = W.AddCheckbox(ioBody, y, "Show MySlot profiles in tooltip",
        function() return db().showMySlot end,
        function(v) db().showMySlot = v end, r)

    y = W.AddNote(ioBody, y, "Supports DDT profiles, full config bundles, and MySlot exports.")
    W.EndSection(panel, y)

    -- ── Click Actions ─────────────────────────────────────────
    ns.AddModuleClickActionsSection(panel, r, "actionbarprofiles", CLICK_ACTIONS)
end

---------------------------------------------------------------------------
-- Settings: Rebuild profile list dynamically
---------------------------------------------------------------------------

function ABP:RebuildProfileListUI(profBody)
    local container = profBody._listContainer
    if not container then return end

    -- Clear existing rows
    if profBody._profileRows then
        for _, row in ipairs(profBody._profileRows) do
            row:Hide()
            row:SetParent(nil)
        end
    end
    profBody._profileRows = {}

    local profiles = GetSortedProfileList()
    local db = self:GetDB()
    local cls = GetClassToken()
    local ry = 0

    for _, name in ipairs(profiles) do
        local profile = GetClassProfiles(db)[name]
        if profile then
            local row = CreateFrame("Frame", nil, container)
            row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, ry)
            row:SetPoint("RIGHT", container, "RIGHT", 0, 0)
            row:SetHeight(28)

            -- Name label
            local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            nameText:SetPoint("LEFT", row, "LEFT", 4, 0)
            nameText:SetText(name)
            if db.activeProfile[cls] == name then
                nameText:SetTextColor(0.2, 1.0, 0.2)
            end

            -- Meta (right side)
            local meta = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            meta:SetPoint("RIGHT", row, "RIGHT", -200, 0)
            local metaText = (profile.savedBy or "") .. " | " .. (profile.specName or "")
            if profile.savedAt then
                metaText = metaText .. " | " .. date("%Y-%m-%d", profile.savedAt)
            end
            meta:SetText("|cff888888" .. metaText .. "|r")

            -- Buttons
            local loadBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            loadBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            loadBtn:SetSize(50, 20)
            loadBtn:SetText("Load")
            local profName = name
            loadBtn:SetScript("OnClick", function()
                RestoreProfile(profName, false)
                ABP:RebuildProfileListUI(profBody)
            end)

            local delBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            delBtn:SetPoint("RIGHT", loadBtn, "LEFT", -4, 0)
            delBtn:SetSize(54, 20)
            delBtn:SetText("Delete")
            delBtn:SetScript("OnClick", function()
                StaticPopupDialogs["DDT_ABP_DELETE"] = {
                    text = "Delete profile '|cff00cc00" .. profName .. "|r'?\n\nThis cannot be undone.",
                    button1 = "Delete",
                    button2 = "Cancel",
                    OnAccept = function()
                        DeleteProfile(profName)
                        ABP:RebuildProfileListUI(profBody)
                    end,
                    timeout = 0,
                    whileDead = true,
                    hideOnEscape = true,
                    preferredIndex = 3,
                }
                StaticPopup_Show("DDT_ABP_DELETE")
            end)

            local renBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            renBtn:SetPoint("RIGHT", delBtn, "LEFT", -4, 0)
            renBtn:SetSize(62, 20)
            renBtn:SetText("Rename")
            renBtn:SetScript("OnClick", function()
                -- Use a StaticPopup for rename
                StaticPopupDialogs["DDT_ABP_RENAME"] = {
                    text = "Rename profile '" .. profName .. "' to:",
                    button1 = "Rename",
                    button2 = "Cancel",
                    hasEditBox = true,
                    OnShow = function(self) self.editBox:SetText(profName) end,
                    OnAccept = function(self)
                        local newName = strtrim(self.editBox:GetText())
                        if newName ~= "" and newName ~= profName then
                            RenameProfile(profName, newName)
                            ABP:RebuildProfileListUI(profBody)
                        end
                    end,
                    timeout = 0,
                    whileDead = true,
                    hideOnEscape = true,
                    preferredIndex = 3,
                }
                StaticPopup_Show("DDT_ABP_RENAME")
            end)

            profBody._profileRows[#profBody._profileRows + 1] = row
            ry = ry - 30
        end
    end

    container:SetHeight(math.max(math.abs(ry), 1))
end

---------------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------------

ns:RegisterModule("actionbarprofiles", ABP, DEFAULTS)
