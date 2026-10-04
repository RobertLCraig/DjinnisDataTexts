-- Regression check for card 0014's Quest Log DataText: label template
-- expansion, grouping and ordering of a fixture log, quest counts, the
-- one-line progress per quest, and the event throttle.
--
-- This does NOT copy the code. It lifts the real block out of
-- Modules/QuestLog.lua between the [ql-helpers] markers, plus the real
-- ns.ExpandTag out of Core.lua, and runs them, so breaking or deleting either
-- fails this check.
--
--   lua docs/build/check-questlog.lua          (run from the addon root)

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

local src = read(({ ... })[1] or "Modules/QuestLog.lua")
local block = src:match("%-%- %[ql%-helpers%][^\n]*\n(.-)%-%- %[/ql%-helpers%]")
assert(block, "no [ql-helpers] block in Modules/QuestLog.lua -- was it removed?")
local H = assert(assert((loadstring or load)(block .. "\nreturn QLH", "ql-helpers"))(),
    "[ql-helpers] block defines no QLH")

local fails, passes = 0, 0
local function eq(got, want, msg)
    if got == want then passes = passes + 1
    else fails = fails + 1; print("FAIL " .. msg .. ": got " .. tostring(got) .. ", want " .. tostring(want)) end
end

-- 1. Label template: <count>, <max>, <ready>.
eq(H.ExpandLabel("<count>/<max>", 12, 35, 0), "12/35", "count of max")
eq(H.ExpandLabel("<count>/<max> <ready>", 12, 35, 3), "12/35 3", "ready tag")
eq(H.ExpandLabel("  Quests: <count>  ", 4, 35, 0), "Quests: 4", "trimmed")

-- 2. A fixture log, in the order the game returns it. A secret-like title is a
--    table that throws on concatenation or comparison, to prove titles are
--    only ever passed through.
local secret = setmetatable({}, {
    __concat = function() error("attempt to concatenate a secret string value") end,
    __lt     = function() error("attempt to compare a secret string value") end,
    __le     = function() error("attempt to compare a secret string value") end,
})
local log = {
    { isHeader = true,  title = "Campaign" },
    { questID = 1, title = secret, mapID = 10, ready = true,  frequency = 0 },
    { questID = 2, title = "B",    mapID = 20, ready = false, frequency = 1 },
    { isHeader = true,  title = "Zone A" },
    { questID = 3, title = "C",    mapID = 10, ready = false, frequency = 2 },
    { questID = 4, title = "Hidden", mapID = 10, isHidden = true },
    { questID = 5, title = "Bonus",  mapID = 10, isTask = true },
    { isHeader = true,  title = "Other header" },
    { questID = 6, title = "D",    mapID = nil, ready = false, frequency = 1 },
}

local ok, groups = pcall(H.Group, log, "header")
eq(ok, true, "grouping by header must not throw on a secret title (" .. tostring(groups) .. ")")
if ok then
    eq(#groups, 3, "header mode: one group per header")
    eq(groups[1].title, "Campaign", "first group is the first header")
    eq(#groups[1].quests, 2, "first group holds its two quests")
    eq(groups[1].quests[1].questID, 1, "log order kept inside a group")
    eq(groups[2].title, "Zone A", "second group")
    eq(#groups[2].quests, 1, "hidden and task quests are not listed")
    eq(groups[3].quests[1].questID, 6, "quest 6 under its header")
end

-- A header with nothing under it is dropped, and a quest before any header
-- gets a group of its own.
local log2 = {
    { questID = 9, title = "Before any header", mapID = 30 },
    { isHeader = true, title = "H1" },
    { isHeader = true, title = "H2" },
    { questID = 7, title = "E", mapID = 30 },
}
groups = H.Group(log2, "header")
eq(#groups, 2, "a quest before any header gets its own group, an empty header is dropped")
eq(groups[1].title, nil, "the leading group has no title")
eq(groups[2].title, "H2", "the header that holds a quest is kept")

groups = H.Group(log, "zone")
eq(#groups, 3, "zone mode: map 10, map 20 and Other")
eq(groups[1].mapID, 10, "zones in order of first appearance")
eq(#groups[1].quests, 2, "quests 1 and 3 share map 10")
eq(groups[1].quests[2].questID, 3, "log order kept across headers")
eq(groups[2].mapID, 20, "second zone")
eq(groups[3].mapID, nil, "a quest with no map goes in the trailing Other group")
eq(groups[3].quests[1].questID, 6, "quest 6 in Other")

-- 3. Counts: hidden and task quests are not counted.
local c = H.Counts(log)
eq(c.quests, 4, "four listed quests")
eq(c.ready, 1, "one ready to hand in")
eq(c.daily, 2, "two dailies (frequency 1)")
eq(c.weekly, 1, "one weekly (frequency 2)")

-- 4. One progress line per quest.
local p = H.Progress({}, true, false)
eq(p.state, "ready", "ready quest")
eq(p.value, "Ready", "ready says so")
p = H.Progress({ { text = "x", finished = true } }, false, true)
eq(p.state, "failed", "failed wins over objectives")
eq(p.value, "Failed", "failed says so")
local objText = secret
p = H.Progress({
    { text = "Kill boars", finished = true },
    { text = objText,      finished = false },
    { text = "Third",      finished = false },
}, false, false)
eq(p.state, "active", "in progress")
eq(p.value, "1/3", "finished objectives out of all")
eq(p.detail, objText, "detail is the first unfinished objective, passed through untouched")
p = H.Progress({}, false, false)
eq(p.value, "", "no objectives, no count")
eq(p.detail, nil, "and no detail")
p = H.Progress(nil, false, false)
eq(p.value, "", "nil objectives tolerated")

-- 5. Throttle: a burst of events schedules one rebuild per window.
local pending, runs = {}, 0
local fakeAfter = function(_, fn) pending[#pending + 1] = fn end
local poke = H.NewThrottle(0.5, fakeAfter, function() runs = runs + 1 end)
eq(poke(), true, "first event schedules")
eq(poke(), false, "second event in the window is absorbed")
eq(poke(), false, "and the third")
eq(#pending, 1, "one timer for the burst")
eq(runs, 0, "nothing runs before the window ends")
pending[1]()
eq(runs, 1, "one rebuild for the burst")
eq(poke(), true, "the next event after the window schedules again")
eq(#pending, 2, "a second timer")

print(("questlog: %d passed, %d failed"):format(passes, fails))
if fails > 0 then os.exit(1) end
