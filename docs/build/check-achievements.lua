-- Regression check for card 0013's Achievements DataText: label template
-- expansion, the points-this-session delta and criteria row formatting.
--
-- This does NOT copy the code. It lifts the real block out of
-- Modules/Achievements.lua between the [ach-helpers] markers, plus the real
-- ns.ExpandTag out of Core.lua, and runs them, so breaking or deleting either
-- fails this check.
--
--   lua docs/build/check-achievements.lua          (run from the addon root)

local function read(path)
    local f = assert(io.open(path, "r"), "run this from the addon root: " .. path)
    local s = f:read("*a"):gsub("\r", "")
    f:close()
    return s
end

local core = read("Core.lua")
local expandSrc = core:match("\n(function ns%.ExpandTag.-\nend)\n")
assert(expandSrc, "no ns.ExpandTag in Core.lua")
ns = {}
assert((loadstring or load)(expandSrc, "ExpandTag"))()

local src = read(({ ... })[1] or "Modules/Achievements.lua")
local block = src:match("%-%- %[ach%-helpers%][^\n]*\n(.-)%-%- %[/ach%-helpers%]")
assert(block, "no [ach-helpers] block in Modules/Achievements.lua -- was it removed?")
local H = assert(assert((loadstring or load)(block .. "\nreturn AchH", "ach-helpers"))(),
    "[ach-helpers] block defines no AchH")

local fails, passes = 0, 0
local function eq(got, want, msg)
    if got == want then passes = passes + 1
    else fails = fails + 1; print("FAIL " .. msg .. ": got " .. tostring(got) .. ", want " .. tostring(want)) end
end

-- 1. Label template: <points> and <session>.
eq(H.ExpandLabel("<points>", 12345, 0), "12345", "points alone")
eq(H.ExpandLabel("<points> <session>", 12345, 15), "12345 +15", "session gained shows +N")
eq(H.ExpandLabel("<points> <session>", 12345, 0), "12345", "no gain leaves no trailing +0 or space")
eq(H.ExpandLabel("Ach: <points>", 50, 5), "Ach: 50", "unknown tags untouched, <session> absent")

-- 2. Session delta. The baseline is the first non-zero read: the game can
--    answer 0 before achievement data has loaded, and that must not make the
--    whole total look earned this session.
local s = {}
eq(H.SessionDelta(s, 0), 0, "a zero read sets no baseline")
eq(H.SessionDelta(s, 12000), 0, "first real read is the baseline")
eq(H.SessionDelta(s, 12010), 10, "points earned since the baseline")
eq(H.SessionDelta(s, 12025), 25, "delta keeps counting from the same baseline")

-- 3. Criteria rows. Flag bit 1 is Blizzard's EVALUATION_TREE_FLAG_PROGRESS_BAR.
local r = H.CriterionRow("Kill boars", false, 3, 10, 1, "")
eq(r.value, "3 / 10", "quantity criterion shows quantity / required")
eq(r.progress, 0.3, "quantity criterion carries a bar fraction")
eq(r.done, false, "quantity criterion not done")
r = H.CriterionRow("Gold", false, 5, 10, 1, "5/10 gold")
eq(r.value, "5/10 gold", "the game's own quantity string wins when it gives one")
r = H.CriterionRow("Overshoot", true, 12, 10, 1, "")
eq(r.progress, 1, "bar clamps at full")
r = H.CriterionRow("Visit Stormwind", true, 0, 0, 0, "")
eq(r.value, "Done", "plain criterion done")
eq(r.progress, nil, "plain criterion has no bar")
r = H.CriterionRow("Visit Orgrimmar", false, 0, 0, 0, "")
eq(r.value, "Not done", "plain criterion not done")
r = H.CriterionRow("Odd", false, 0, 0, 1, "")
eq(r.progress, nil, "a bar flag with nothing required is not a bar")
eq(r.value, "Not done", "and reads as not done")

-- 4. A secret criteria string (12.1) is passed through, never concatenated.
local secret = setmetatable({}, { __concat = function() error("attempt to concatenate a secret string value") end })
local ok, err = pcall(H.CriterionRow, secret, false, 1, 2, 1, "")
eq(ok, true, "a secret criteria string must not throw (" .. tostring(err) .. ")")

print(("achievements: %d passed, %d failed"):format(passes, fails))
if fails > 0 then os.exit(1) end
