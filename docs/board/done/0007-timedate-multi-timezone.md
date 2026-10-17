# TimeDate multi-timezone support

## What I need from you

**Four steps in the game, with BugSack or the error frame open.**

**Deployed 2026-09-29.** Merged to `master` (`b8d6197`) and in the game folder. Just `/reload`.

1. `/ddt`, then Time / Date, then open the **Extra Time Zones** section.
   Expect: four zones, the first three filled in as New York, London and Sydney, all unticked.
2. Tick **Show zone 1**, 2 and 3. Hover the Time / Date DataText.
   Expect: three new rows under Local Time. Between 4 and 25 October 2026 London is 1 hour
   ahead of UTC, New York 4 hours behind, Sydney 11 ahead (its summer time began 4 October).
   From 25 October London is UTC+0; from 1 November New York is UTC-5. Compare with any world clock.
3. On zone 4, leave the label blank, drag the offset to `5.50`, rule "None". Tick Show zone 4.
   Expect: a row labelled `UTC+5:30` showing India's time.
4. If any zone is already on tomorrow or still on yesterday compared with you, its time has a
   small grey `+1d` or `-1d` after it.

**Pass:** all four, the times match a world clock, no Lua error.

**Fail:** a wrong hour, or any error. Paste it into `## Comments` and move the card to `todo/`.

**Why it needs you:** the tooltip and the settings panel only exist in a game client. The
daylight saving maths itself is already proved offline (below), so a wrong hour in step 2 means
a wiring fault, not a rules fault.

## Why
The Time / Date tooltip shows server time and your own local time, and nothing else. If you
play with friends or a raid team in another region, you work out their clock in your head,
and twice a year you get it wrong because one of you has changed to summer time and the
other has not.

It was the only unchecked item in the old phase tracker
([docs/build/task.md](../../build/task.md)), "TimeDate Phase 3 (multi-timezone) - deferred".
The card was first written as "build or drop" on the belief that nobody had asked for it.
**That was wrong: Rob asked for it** (Decided, below).

The obstacle that kept it deferred: WoW's Lua has no time zone database, so a fixed UTC offset
is wrong for half of every year, and a hand-kept table of change dates goes stale.

## Not this card
- A full time zone database or any zone with rules other than the three below. A zone that
  does not observe summer time uses "none" with its fixed offset, which covers most of the
  world that is not US, EU or south-east Australia.
- A label tag (`<zone1>` etc.) for the DataText text itself. Tooltip rows only.
- Changing the existing server / local rows, resets or calendar events.

## Acceptance
<!-- AC:BEGIN -->
- [ ] #1 WHEN an extra zone is enabled, THE APP SHALL show one tooltip row for it, below Local
      Time, labelled with the user's label or, if blank, its UTC offset. proves: manual
- [x] #2 WHEN the zone uses the US rule, THE APP SHALL add the summer hour from the 2nd Sunday of
      March 02:00 standard to the 1st Sunday of November 02:00 daylight, local to that zone.
      proves: `docs/build/check-timezones.lua` (US cases)
- [x] #3 WHEN the zone uses the EU rule, THE APP SHALL add the summer hour from the last Sunday of
      March to the last Sunday of October, both 01:00 UTC. proves: `docs/build/check-timezones.lua` (UK and CET cases)
- [x] #4 WHEN the zone uses the south-east Australia rule, THE APP SHALL add the summer hour from
      the 1st Sunday of October 02:00 standard to the 1st Sunday of April 03:00 daylight,
      including across the new year. proves: `docs/build/check-timezones.lua` (Sydney and Adelaide cases)
- [x] #5 WHEN the zone uses no rule, THE APP SHALL apply its fixed offset, including half- and
      quarter-hour offsets. proves: `docs/build/check-timezones.lua` (fixed-offset cases)
- [ ] #6 WHEN the zone is on a different calendar day from the player, THE APP SHALL mark the row
      "+1d" or "-1d". proves: manual (the day arithmetic itself is in the check's calendar sweep)
- [ ] #7 THE APP SHALL let the user set, per zone, on/off, label, standard offset and rule in the
      existing Time / Date settings panel, for up to four zones. proves: manual
<!-- AC:END -->

## Tasks
- [x] Check the time APIs against `wow-ui-source`: `GetServerTime()` (`SystemTimeDocumentation.lua:30`,
      plain number, no secret flag) gives the UTC epoch; `date("*t")` gives the player's local date.
- [x] `[tz-maths]` block in `Modules/TimeDate.lua`: civil-date arithmetic, the three rules, zone time.
- [x] Defaults: four slots, New York / London / Sydney pre-filled and off.
- [x] Tooltip rows and the "Extra Time Zones" settings section.
- [x] `docs/build/check-timezones.lua`, 106 checks, run under Lua 5.1 and 5.4, seen red under five mutations.
- [x] `RELEASE_NOTES.md` entry under 0.9.16, Added.
- [ ] In-game check (see `## What I need from you` once the card reaches `human-review/`).

## Decided

**2026-09-29** **Decided:** Rob 2026-09-29: "I asked for this." So the premise of this card,
that nobody had asked, was wrong, and the answer is build, not drop. Per the coordinator
relaying Rob: option 2 (configurable extra zones as tooltip rows with user labels), but with
daylight saving computed from the rules (US, EU, south-east Australia, plus fixed no-DST
offsets) rather than a hand-kept table of dates, configurable in the existing options.

## Comments

**2026-09-29** The decision card this was, kept for the record now that it is a feature card.
Options as first written: (1) drop it, at no cost, reopen if asked; (2) build it, configurable
extra zones as tooltip rows, small to moderate, the real cost being hard-coded offsets that
break twice a year or a hand-maintained DST table; (3) a single user-set UTC offset with a
label, no DST, documented as such. The recommendation was option 1, because it had sat
deferred through nine phases "with no user asking for it". Rob's answer overturned that
premise, and computing DST from rules removes the maintenance cost option 2 was priced on.

**2026-09-29** Built (unattended, agent). The DST rules are the published ones and need no
upkeep unless a government changes them. The check lifts the real `[tz-maths]` block out of the
module, so it tests the shipped code, and uses standard Lua's `os.date("!*t")` as an independent
oracle for the calendar conversion from 1970 to 2100. `docs/` is in `pkgmeta.yaml`'s ignore list,
so the check never ships.

Assumed, and worth a look: the offset is set with the existing 0.25-hour slider, which shows
`5.50` rather than `+5:30`. The settings text explains it. A new widget was not worth it.

This adds a third unverified change to the held 0.9.16 release. If you would rather not ship it
untested, move its `RELEASE_NOTES.md` entry out before cutting the tag.

**2026-09-29** ADVERSARIAL REVIEW (unattended, agent). **Same session as the build**, so by the
review rule this pass cannot send it to `done/`. Verdict: #2 to #5 proved offline, #1, #6 and
#7 need a client; moved to `human-review/` for the four steps above.

Attacked, and held:
- **The check can fail.** Five mutations, each turning `docs/build/check-timezones.lua` red: US
  start on the 1st instead of 2nd Sunday (2 fail), EU end at 02:00 instead of 01:00 UTC (2),
  southern-hemisphere season test flipped to northern (4), a broken month shift in the calendar
  maths (101), and the US/AU end instant computed in standard rather than daylight time (3).
- **APIs.** `GetServerTime()` is documented (`SystemTimeDocumentation.lua:30`) as a plain number
  with no secret or restriction flag. `time()` is only a fallback and Blizzard itself calls it
  (`Blizzard_SharedXML/TimeUtil.lua:21`). `date("*t")` is already used by this module.
- **Saved data.** A new default table needs no schema migration (DATA-MODEL: adding a default
  needs none). `MergeDefaults` builds fresh tables, so slots never alias `DEFAULTS`. A label the
  user blanked stays blank, because the merge only fills nil. Reset to Defaults restores the
  three pre-filled zones, switched off. The settings helper recreates a missing slot rather
  than indexing nil.
- **Year edges.** The rule year is taken from the UTC date. Every transition is months away from
  1 January, so a zone already in the next year locally cannot pick the wrong year's rule.
- **Today's expected values in step 2** were worked from the rules, not from memory of the
  clocks: EU summer time ends 25 October 2026, US on 1 November, and south-east Australia's
  starts 4 October, so on 29 September London is UTC+1, New York UTC-4, Sydney UTC+10.

Weak, not fixed:
- `+1d` compares the zone's date (from the server clock) with your PC's date. A PC clock that is
  minutes out is only visible in the minutes either side of midnight. Not worth another source.

Security (code card): **weakest point** is the user's own label string, drawn into their own
tooltip; a stray `|` escape can only garble their own row. **Unchecked path:** none; the offset
comes from a bounded slider (-12 to 14) and the rule from a fixed list, and an unknown rule
falls back to a fixed offset (checked). **Leaks:** nothing; no network, no other character's
data, no chat output.

**2026-10-11** Clear-down (attended, agent). Fixed the look text in step 2: south-east Australian summer time began 4 October 2026, so Sydney is UTC+11 now, not UTC+10, and the London and New York changes on 25 October and 1 November are named. Unticked #1, #6 and #7: they say `proves: manual`, and the 2026-09-29 review said they need a client, so the ticks were wrong and would have hidden the look from the product list. #2 to #5 stay ticked (`docs/build/check-timezones.lua`, 106 passed today under Lua 5.1). Per the board README rule "A look waits on the product", moved to `ai-review/`: the only review so far was by the building session, which the review rule does not count.

### 2026-10-17 review (v20261017084104-dc76)

**suite**

No suite this job could find in WoWAddons:DjinnisDataTexts, so none ran. That is not a pass.

**acceptance: sound**

I checked each criterion against `Modules/TimeDate.lua`. Each one is in the code.

- **#1**: In `BuildTooltipContent`, the loop over `GetExtraZoneRows` puts the zone rows right after the Local Time row. The label is the user's label. If the label is blank, the row shows `TZ.FormatOffset` instead.
- **#2**: `TZ.RULES.us` starts at the 2nd Sunday of March, 02:00 standard time. It ends at the 1st Sunday of November, 02:00 daylight time, done as `std + HOUR`.
- **#3**: `TZ.RULES.eu` changes on the last Sunday of March and the last Sunday of October, both at 01:00 UTC.
- **#4**: `TZ.RULES.au` covers October to April. `TZ.IsSummer` handles the case where the start is later than the end, so summer time runs across the new year. The rule year comes from the UTC date. That is safe, because no change date is near 1 January.
- **#5**: When the rule is `none`, `TZ.RULES[rule]` is nil, so `TZ.IsSummer` returns false. `TZ.ZoneTime` rounds `offset*3600`, so offsets like 5.5 and 5.75 work.
- **#6**: `GetExtraZoneRows` works out `dayShift`. `BuildTooltipContent` then adds a grey `+Nd` or `-Nd`.
- **#7**: `BuildSettingsPanel` has a section called "Extra Time Zones". It has 4 slots, and each slot has a checkbox, a label, a slider from -12 to 14 in steps of 0.25, and a rule dropdown (`DST_RULES`). The `zone(i)` helper makes a slot again if it is missing.

I did not find a defect. Criteria #1, #6 and #7 still need a check in the game.

VERDICT: sound

**scope: sound**

No scope problem found. The card's commit (`2694bf8`) only adds code.

- It touches only these files: `Modules/TimeDate.lua`, `RELEASE_NOTES.md`, the card file and `docs/build/check-timezones.lua`.
- In `Modules/TimeDate.lua` it adds 197 lines and removes none. So the server row, the local row, the resets and the calendar events did not change.
- In `Modules/TimeDate.lua` there is no `<zone1>` tag in the label code. The new zones show only as tooltip rows, in `BuildTooltipContent` through `GetExtraZoneRows`.
- In `TZ.ZoneTime` there are only the three rules (US, EU, south-east Australia) plus "none". It does not add a full time zone database.
- Nothing is left half done. The defaults, the tooltip rows, the "Extra Time Zones" settings section and the check are all present. The in-game check is still open, but it is the owner's step (`proves: manual`).
- The big diff also has toggles, Achievements, QuestLog and other changes. Those belong to other cards and other commits. They are not this card's growth.

VERDICT: sound

**breakage: sound**

I checked the time zone code. I did not find a fault in it.

**What I checked:**
- **The daylight saving maths** in `TZ.RULES` and `TZ.IsSummer` (`Modules/TimeDate.lua`). The US and Australia end times are in summer time, which is right. The Australian season crosses the new year, and the "start later than end" branch handles that.
- **Half-hour offsets.** `TZ.ZoneTime` rounds the slider value to whole seconds. A slider value with a tiny rounding error, such as 5.4999, still gives 5:30.
- **The settings panel.** `BuildSettingsPanel` calls `AddCheckbox`, `AddEditBox`, `AddSlider` and `AddDropdown`. All four exist in `Settings.lua` and take the arguments the panel gives them.
- **Saved settings.** `MergeDefaults` (`Core.lua`) builds new tables for each zone slot. It only fills empty values, so a label you cleared stays clear. `ResetModuleDefaults` puts the three filled-in zones back, switched off.
- **The tooltip rows.** `GetExtraZoneRows` and the tooltip code that uses it (`BuildTooltipContent`) put each zone below Local Time. They add `+1d` or `-1d` when the zone is on another day. No other code calls these functions, so nothing else needed a change.

None of my checks failed. Criteria #1, #6 and #7 are still open, but only because they need a check in the game. That is not a fault.

VERDICT: sound

