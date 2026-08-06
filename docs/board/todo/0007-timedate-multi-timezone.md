# TimeDate multi-timezone support: build or drop

## Why
The only unchecked item in the old phase tracker
([docs/build/task.md](../../build/task.md)), recorded as "TimeDate Phase 3
(multi-timezone) - deferred" and untouched since. It is carried onto the board so the
deferral is a visible decision rather than a stale checkbox nobody revisits.

Nobody has asked for it since. TimeDate already shows server and local time, reset
countdowns and calendar events.

## Options
1. **Drop it.** Move this card to `discarded/` with the reason. Cost: none. If a user asks,
   it can be reopened with a real request attached.
2. **Build it.** Configurable extra timezones as tooltip rows, for players raiding with
   people in other regions. Cost: small to moderate, but WoW's Lua has no timezone database,
   so it means either hard-coded UTC offsets that break twice a year on daylight saving, or
   a hand-maintained DST table. That maintenance burden is the real cost, not the feature.
3. **Build a narrow version.** A single user-set UTC offset with a custom label, no DST
   handling, documented as such. Cost: small. Covers the raid-in-another-region case
   without a timezone database.

## Recommendation
Option 1. It has sat deferred through nine phases with no user asking for it, and option 2's
DST maintenance is a recurring cost on a feature with no demonstrated demand. Option 3 is
the fallback if somebody does ask.

## Decided
