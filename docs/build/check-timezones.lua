-- Regression check for card 0007's extra time zones: the calendar maths and the
-- three daylight saving rules in Modules/TimeDate.lua.
--
-- This does NOT copy the code. It lifts the real block out of the module between
-- the [tz-maths] markers and runs it, so breaking or deleting the maths fails
-- this check. Standard Lua's os.date("!*t") is the independent oracle for the
-- calendar conversion; the DST transitions are checked against published dates.
--
--   lua docs/build/check-timezones.lua          (run from the addon root)

local SOURCE = ({ ... })[1] or "Modules/TimeDate.lua"

local f = assert(io.open(SOURCE, "r"), "run this from the addon root: " .. SOURCE)
local src = f:read("*a"):gsub("\r", "")
f:close()

local block = src:match("%-%- %[tz%-maths%][^\n]*\n(.-)%-%- %[/tz%-maths%]")
assert(block, "no [tz-maths] block in " .. SOURCE .. " -- was it removed?")
local chunk = assert((loadstring or load)(block .. "\nreturn TZ", "tz-maths"))
local TZ = assert(chunk(), "[tz-maths] block defines no TZ")

local fails, passes = 0, 0
local function check(cond, msg)
    if cond then passes = passes + 1 else fails = fails + 1; print("FAIL " .. msg) end
end

local DAY = 86400
local function utcAt(y, m, d, hh, mm, ss)
    return TZ.DaysFromCivil(y, m, d) * DAY + (hh or 0) * 3600 + (mm or 0) * 60 + (ss or 0)
end

-- 1. Calendar conversion agrees with os.date("!*t") across 1970-2100, every 3 days + drift.
check(TZ.DaysFromCivil(1970, 1, 1) == 0, "1970-01-01 is day 0")
check(TZ.DaysFromCivil(2000, 3, 1) == 11017, "2000-03-01 is day 11017")
for t = 0, 4102444800, 3 * DAY + 3607 do
    local o = os.date("!*t", t)
    local days = math.floor(t / DAY)
    local y, m, d = TZ.CivilFromDays(days)
    if not (y == o.year and m == o.month and d == o.day) then
        check(false, "CivilFromDays(" .. days .. ") = " .. y .. "-" .. m .. "-" .. d)
        break
    end
    if TZ.DaysFromCivil(o.year, o.month, o.day) ~= days then
        check(false, "DaysFromCivil round trip at " .. t)
        break
    end
    if TZ.Weekday(days) ~= o.wday - 1 then
        check(false, "Weekday at " .. t)
        break
    end
end
check(true, "calendar sweep")

-- 2. Transition instants, one second either side, against published dates.
--    zone: offset, rule; then UTC instant -> expected local hour:minute.
local function hm(utc, off, rule)
    local days, h, m = TZ.ZoneTime(utc, off, rule)
    local y, mo, d = TZ.CivilFromDays(days)
    return string.format("%04d-%02d-%02d %02d:%02d", y, mo, d, h, m)
end
local cases = {
    -- US Eastern 2026: starts Sun 8 Mar 02:00 EST (07:00 UTC), ends Sun 1 Nov 02:00 EDT (06:00 UTC)
    { -5, "us", utcAt(2026, 3, 8, 6, 59, 59),  "2026-03-08 01:59" },
    { -5, "us", utcAt(2026, 3, 8, 7, 0, 0),    "2026-03-08 03:00" },
    { -5, "us", utcAt(2026, 11, 1, 5, 59, 59), "2026-11-01 01:59" },
    { -5, "us", utcAt(2026, 11, 1, 6, 0, 0),   "2026-11-01 01:00" },
    -- US Pacific 2025: starts Sun 9 Mar, ends Sun 2 Nov
    { -8, "us", utcAt(2025, 3, 9, 9, 59, 59),  "2025-03-09 01:59" },
    { -8, "us", utcAt(2025, 3, 9, 10, 0, 0),   "2025-03-09 03:00" },
    { -8, "us", utcAt(2025, 11, 2, 9, 0, 0),   "2025-11-02 01:00" },
    -- UK 2026: starts Sun 29 Mar 01:00 UTC, ends Sun 25 Oct 01:00 UTC
    { 0, "eu", utcAt(2026, 3, 29, 0, 59, 59),  "2026-03-29 00:59" },
    { 0, "eu", utcAt(2026, 3, 29, 1, 0, 0),    "2026-03-29 02:00" },
    { 0, "eu", utcAt(2026, 10, 25, 0, 59, 59), "2026-10-25 01:59" },
    { 0, "eu", utcAt(2026, 10, 25, 1, 0, 0),   "2026-10-25 01:00" },
    -- Central Europe 2025: starts Sun 30 Mar 02:00 CET, ends Sun 26 Oct 03:00 CEST
    { 1, "eu", utcAt(2025, 3, 30, 0, 59, 59),  "2025-03-30 01:59" },
    { 1, "eu", utcAt(2025, 3, 30, 1, 0, 0),    "2025-03-30 03:00" },
    { 1, "eu", utcAt(2025, 10, 26, 1, 0, 0),   "2025-10-26 02:00" },
    -- Sydney 2026: ends Sun 5 Apr 03:00 AEDT (Sat 16:00 UTC), starts Sun 4 Oct 02:00 AEST (Sat 16:00 UTC)
    { 10, "au", utcAt(2026, 4, 4, 15, 59, 59), "2026-04-05 02:59" },
    { 10, "au", utcAt(2026, 4, 4, 16, 0, 0),   "2026-04-05 02:00" },
    { 10, "au", utcAt(2026, 10, 3, 15, 59, 59), "2026-10-04 01:59" },
    { 10, "au", utcAt(2026, 10, 3, 16, 0, 0),  "2026-10-04 03:00" },
    -- Sydney across the new year, mid-summer
    { 10, "au", utcAt(2026, 12, 31, 13, 0, 0), "2027-01-01 00:00" },
    -- Adelaide (+9:30) shares the south-east rule
    { 9.5, "au", utcAt(2026, 1, 15, 0, 0, 0),  "2026-01-15 10:30" },
    -- Fixed offsets, no DST
    { 5.5, "none", utcAt(2026, 6, 1, 0, 0, 0), "2026-06-01 05:30" },
    { 5.75, "none", utcAt(2026, 6, 1, 0, 0, 0), "2026-06-01 05:45" },
    { -10, "none", utcAt(2026, 1, 1, 5, 0, 0), "2025-12-31 19:00" },
    { 14, "none", utcAt(2026, 1, 1, 12, 0, 0), "2026-01-02 02:00" },
    -- An unknown rule falls back to fixed
    { 3, "nonsense", utcAt(2026, 7, 1, 0, 0, 0), "2026-07-01 03:00" },
    -- A nil offset reads as UTC
    { nil, "none", utcAt(2026, 7, 1, 0, 0, 0), "2026-07-01 00:00" },
}
for i, c in ipairs(cases) do
    local got = hm(c[3], c[1], c[2])
    check(got == c[4], "case " .. i .. " (" .. tostring(c[1]) .. ", " .. c[2] .. "): want " .. c[4] .. ", got " .. got)
end

-- 3. Transition dates for a decade, checked as Sundays in the right month.
for y = 2024, 2035 do
    for _, spec in ipairs({ { 3, 2 }, { 11, 1 }, { 3, -1 }, { 10, -1 }, { 10, 1 }, { 4, 1 } }) do
        local day = TZ.NthSunday(y, spec[1], spec[2])
        local yy, mm, dd = TZ.CivilFromDays(day)
        local ok = TZ.Weekday(day) == 0 and yy == y and mm == spec[1]
        if spec[2] == -1 then ok = ok and dd > 21 else ok = ok and dd > (spec[2] - 1) * 7 and dd <= spec[2] * 7 end
        check(ok, "NthSunday(" .. y .. ", " .. spec[1] .. ", " .. spec[2] .. ") = " .. yy .. "-" .. mm .. "-" .. dd)
    end
end

-- 4. Offset labels.
check(TZ.FormatOffset(0) == "UTC", "FormatOffset 0")
check(TZ.FormatOffset(-5) == "UTC-5", "FormatOffset -5")
check(TZ.FormatOffset(5.5) == "UTC+5:30", "FormatOffset 5.5")
check(TZ.FormatOffset(-3.5) == "UTC-3:30", "FormatOffset -3.5")
check(TZ.FormatOffset(5.75) == "UTC+5:45", "FormatOffset 5.75")

print(string.format("time zones: %d passed, %d failed", passes, fails))
os.exit(fails == 0 and 0 or 1)
