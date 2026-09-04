-- Regression check for the 12.1 secret-name crash in the club list
-- (2026-09-04): sorting subscribed clubs threw "attempt to compare a secret
-- string value" and took the whole settings panel down with it.
--
-- This does NOT copy the comparator. It lifts the real block out of
-- Modules/Communities.lua between the [club-sort] markers and runs it, so
-- deleting or reverting the fix fails this check. There is no game here, so
-- a secret is modelled by the one behaviour that matters: it errors on any
-- comparison.
--
--   lua docs/build/check-club-sort.lua          (run from the addon root)

local SOURCE = ({ ... })[1] or "Modules/Communities.lua"

local f = assert(io.open(SOURCE, "r"), "run this from the addon root: " .. SOURCE)
local src = f:read("*a")
f:close()

local block = src:match("%-%- %[club%-sort%][^\n]*\n(.-)%-%- %[/club%-sort%]")
assert(block, "no [club-sort] block in " .. SOURCE .. " -- was the fix removed?")

local chunk = assert(load(block .. "\nreturn SortClubsByName", "club-sort"))
local SortClubsByName = assert(chunk(), "[club-sort] block defines no SortClubsByName")

local secretmt = {
    __lt = function() error("attempt to compare a secret string value", 2) end,
    __le = function() error("attempt to compare a secret string value", 2) end,
}
local function secret() return setmetatable({}, secretmt) end
local function self_(entry) return entry end

local function ids(list)
    local out = {}
    for i, c in ipairs(list) do out[i] = c.clubId end
    return table.concat(out, ",")
end

-- 1. Plain names still sort alphabetically. The fix must not cost the feature.
local plain = {
    { clubId = 3, name = "Zulan" },
    { clubId = 1, name = "Ashenvale" },
    { clubId = 2, name = "Moonglade" },
}
SortClubsByName(plain, self_)
assert(ids(plain) == "1,2,3", "plain names must sort alphabetically, got " .. ids(plain))

-- 2. All names secret: the original crash. Order falls back to clubId.
local allSecret = {
    { clubId = 209916972, name = secret() },
    { clubId = 149146102, name = secret() },
}
local ok, err = pcall(SortClubsByName, allSecret, self_)
assert(ok, "secret names must not throw -> " .. tostring(err))
assert(ids(allSecret) == "149146102,209916972", "secret names must fall back to clubId order")

-- 3. Mixed readable and secret. This is the trap a per-pair guard falls into:
--    two different orderings in one comparator is inconsistent, and table.sort
--    errors on that by itself.
local mixed = {
    { clubId = 30, name = secret() },
    { clubId = 10, name = "Ashenvale" },
    { clubId = 20, name = secret() },
    { clubId = 40, name = "Moonglade" },
}
local okMixed, errMixed = pcall(SortClubsByName, mixed, self_)
assert(okMixed, "a mix of secret and readable names must not throw -> " .. tostring(errMixed))
assert(ids(mixed) == "10,20,30,40", "mixed list must fall back to clubId order")

-- 4. A missing name is not a crash either.
local okNil = pcall(SortClubsByName, { { clubId = 1 }, { clubId = 2, name = "Ashenvale" } }, self_)
assert(okNil, "a nil club name must not throw")

-- 5. The wrapped shape used by the tooltip render path (entry.info).
local wrapped = {
    { info = { clubId = 2, name = secret() } },
    { info = { clubId = 1, name = secret() } },
}
local okWrapped = pcall(SortClubsByName, wrapped, function(entry) return entry.info end)
assert(okWrapped, "the entry.info shape must not throw")
assert(wrapped[1].info.clubId == 1, "wrapped list must fall back to clubId order")

print("club sort: all 5 checks passed")
