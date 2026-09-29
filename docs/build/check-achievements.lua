-- Regression check for card 0013's Achievements DataText: the label template
-- (<points>, <session>) and the criteria row formatting.
--
-- This does NOT copy the code. It lifts the real block out of
-- Modules/Achievements.lua between the [ach-helpers] markers, and the real
-- ns.ExpandTag out of Core.lua, and runs them, so breaking either fails here.
-- Nothing here touches the game API; the in-game half of the card is manual.
--
--   lua docs/build/check-achievements.lua          (run from the addon root)

local SOURCE = ({ ... })[1] or "Modules/Achievements.lua"

local function slurp(path)
    local f = assert(io.open(path, "r"), "run this from the addon root: " .. path)
    local s = f:read("*a"):gsub("\r", "")
    f:close()
    return s
end

local block = slurp(SOURCE):match("%-%- %[ach%-helpers%][^\n]*\n(.-)%-%- %[/ach%-helpers%]")
assert(block, "no [ach-helpers] block in " .. SOURCE .. " -- was it removed?")
local A = assert(assert((loadstring or load)(block .. "\nreturn AchHelpers", "ach-helpers"))(),
    "[ach-helpers] block defines no AchHelpers")

local expandSrc = slurp("Core.lua"):match("(function ns%.ExpandTag.-\nend)\n")
assert(expandSrc, "no ns.ExpandTag in Core.lua")
local ns = {}
assert((loadstring or load)("local ns = ...\n" .. expandSrc))(ns)
local E = ns.ExpandTag

local fails, passes = 0, 0
local function eq(got, want, msg)
    if got == want then passes = passes + 1
    else fails = fails + 1; print("FAIL " .. msg .. ": got " .. tostring(got) .. ", want " .. tostring(want)) end
end

-- #1 Label template: <points> is the total, <session> the gain since login.
eq(A.ExpandLabel("<points>", 12345, 12345, E), "12345", "<points> expands to the total")
eq(A.ExpandLabel("<points> (<session>)", 12360, 12345, E), "12360 (+15)", "<session> is points minus the login baseline")
eq(A.ExpandLabel("<session>", 12345, 12345, E), "+0", "nothing earned yet reads +0")
eq(A.ExpandLabel("<session>", 500, nil, E), "+0", "no baseline yet reads +0, not an error")
eq(A.ExpandLabel("Ach: <points>", nil, nil, E), "Ach: 0", "points not yet readable reads 0")
eq(A.ExpandLabel("<points> <other>", 10, 10, E), "10 <other>", "an unknown tag is left alone")

-- #3 Criteria rows. Flag 0x1 is EVALUATION_TREE_FLAG_PROGRESS_BAR (Constants.lua).
local r = A.CriteriaRow("Kill 10 boars", false, 3, 10, 1)
eq(r.text, "Kill 10 boars", "criteria text is carried through")
eq(r.value, "3 / 10", "a quantity criterion reads quantity / required")
eq(r.fraction, 0.3, "a quantity criterion carries its bar fill")
eq(r.done, false, "an unfinished quantity criterion is not done")

r = A.CriteriaRow("Kill 10 boars", true, 10, 10, 1)
eq(r.fraction, 1, "a finished quantity criterion fills the bar")
eq(r.done, true, "a finished quantity criterion is done")

r = A.CriteriaRow("Loot 5000 gold", false, 7000, 5000, 1)
eq(r.fraction, 1, "over-quantity clamps the bar to full")

r = A.CriteriaRow("Bar flag plus another", false, 2, 4, 3)
eq(r.value, "2 / 4", "the bar bit is found alongside other flag bits")
eq(r.fraction, 0.5, "the bar bit is found alongside other flag bits (fill)")

r = A.CriteriaRow("Visit Stormwind", false, 0, 1, 0)
eq(r.fraction, nil, "a criterion without the bar flag has no bar")
eq(r.value, "Not done", "a non-quantity criterion reads Not done")
eq(A.CriteriaRow("Visit Stormwind", true, 1, 1, 2).value, "Done", "a finished non-quantity criterion reads Done")

r = A.CriteriaRow("Odd", false, 0, 0, 1)
eq(r.fraction, nil, "a bar criterion needing 0 does not divide by zero")
eq(r.value, "Not done", "a bar criterion needing 0 falls back to done / not done")

r = A.CriteriaRow(nil, nil, nil, nil, nil)
eq(r.text, "", "a missing criteria string is empty, not nil")
eq(r.done, false, "a missing completed flag is not done")

print(("achievements: %d passed, %d failed"):format(passes, fails))
if fails > 0 then os.exit(1) end
