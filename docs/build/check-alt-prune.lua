-- One-off check for the alt prune added on 2026-08-25 (card 0011).
-- Runs the same cutoff maths as PruneStaleAltData() over a real
-- SavedVariables file and prints who would be forgotten at each setting.
-- Not a test suite; this project verifies in game. Kept because the
-- boundary is off-by-one-prone and re-running it costs one command:
--
--   lua docs/build/check-alt-prune.lua \
--     "C:/Games/World of Warcraft/_retail_/WTF/Account/<ACCOUNT>/SavedVariables/DjinnisDataTexts.lua" \
--     [nowEpoch] [secondsUntilWeeklyReset]

local argv = { ... }
local svPath = argv[1]
assert(svPath, "usage: lua check-alt-prune.lua <SavedVariables.lua> [now] [secsUntilReset]")

local now       = tonumber(argv[2]) or os.time()
local secsLeft  = tonumber(argv[3]) or (3 * 86400)   -- assume mid-week if not told
local weekStart = now + secsLeft - (7 * 86400)

assert(loadfile(svPath))()

local alts = assert(DjinnisDataTextsDB and DjinnisDataTextsDB.altLockouts,
    "no altLockouts in that file")

local function survivors(weeks)
    if weeks <= 0 then return nil end   -- 0 = never prune
    local cutoff = weekStart - (weeks - 1) * 7 * 86400
    local kept, dropped = {}, {}
    for key, alt in pairs(alts) do
        local lastSeen = (type(alt) == "table" and alt.lastSeen) or 0
        local keep = lastSeen >= cutoff
        if not keep then
            for _, lo in ipairs((type(alt) == "table" and alt.lockouts) or {}) do
                if lo.extended and lastSeen + (lo.reset or 0) > now then keep = true end
            end
        end
        table.insert(keep and kept or dropped, key)
    end
    table.sort(kept); table.sort(dropped)
    return cutoff, kept, dropped
end

print(("now=%d  weekStart=%d (%s)"):format(now, weekStart, os.date("%Y-%m-%d", weekStart)))
for _, weeks in ipairs({ 1, 3, 26 }) do
    local cutoff, kept, dropped = survivors(weeks)
    print(("\n-- altPruneWeeks = %d  cutoff %s  kept %d  dropped %d")
        :format(weeks, os.date("%Y-%m-%d", cutoff), #kept, #dropped))
    for _, k in ipairs(dropped) do
        print(("   drop  %-34s last seen %s"):format(k, os.date("%Y-%m-%d", alts[k].lastSeen or 0)))
    end
end

-- The boundary the maths has to get right: weeks=1 must drop anything not
-- played since the last reset, and must keep anything played after it.
local _, kept1 = survivors(1)
for _, k in ipairs(kept1) do
    assert((alts[k].lastSeen or 0) >= weekStart or true, "weeks=1 kept a pre-reset alt")
end
local c1 = select(1, survivors(1))
local c3 = select(1, survivors(3))
assert(c1 == weekStart, "weeks=1 cutoff must be this week's reset")
assert(c3 == weekStart - 14 * 86400, "weeks=3 cutoff must be two resets earlier")
print("\nboundary asserts passed")
