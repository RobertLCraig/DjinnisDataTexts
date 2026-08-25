# A character on a dead tournament realm has its own column in Saved Instances

## What I need from you

**One check, in game.**

1. `/reload`, then hover Saved Instances. Pass is all three of:
   - the last column, the second "Djinni", is gone
   - the characters you have played in the last three weeks are all still there
   - no Lua error

Already deployed to the game folder, so `/reload` is the whole job. Fail is a
character you played recently going missing, or the column still being there.
Say which in this card and I will revert; it is one commit.

Then check the new slider suits you: **Settings, Saved Instances, Alt Lockouts,
"Forget an alt after this many weeks"**. It is set to your 3. Set it to 0 to
keep every character forever, including the tournament-realm one.

Off the back of it, one thing worth knowing rather than deciding: the "show
alts active in the last 30 / 60 / 90 / 180 days" dropdown can now outlive its
own data. At 3 weeks nothing older than 21 days survives to be filtered, so the
90 and 180 day options do nothing. Not urgent, and not this card.

## Why

Rob reported a "phantom character" as the last column of the Saved Instances
tooltip on 2026-08-25, showing two Mythic+ keys from a season that has ended
(Maisara Caverns +12, Skyreach +12).

It is real and it is in the saved file. The entry is:

    ["Djinni - EU Mythic Dungeons"]

`EU Mythic Dungeons` is a genuine realm: one of the temporary tournament realms
Blizzard stands up for the Mythic Dungeon International and takes down again
afterwards (<https://raider.io/tournaments/mdi>). Rob played there on
2026-04-16, the addon recorded that character exactly as it should, and then the
realm went away. The character did not.

So nothing misread anything. The fault is that the addon has never deleted a
stored character, so a character on a realm that no longer exists is remembered
forever, and so is anybody else's stale week. The alt columns were showing last
week's keys as if they were this week's for every character not logged in
recently. Nobody decided that; the weekly-wipe code was written for the current
character only and the stored alts were never given the same treatment.

A temporary realm is just the loudest case of it, because there is no way to log
that character in again and clear it.

## Not this card

- Detecting tournament realms specifically. There is no API for it, and the
  prune clears them without needing to know what they are.
- Adding a manual "forget this character" button. The slider covers it.
- Fixing the "alts active in the last 30 / 60 / 90 / 180 days" dropdown, whose
  longer options can now outlast the prune window. Its own card if it matters.
- Wiping an alt's weekly numbers separately from forgetting the alt. That is a
  second rule for the tooltip to show "played, but nothing this week", and
  nobody has asked for it.
- Any other module. The bug is `Modules/SavedInstances.lua` alone.

## Acceptance
<!-- AC:BEGIN -->
- [ ] #1 WHEN the Saved Instances data refreshes, THE APP SHALL delete any stored
      character not seen within `altPruneWeeks` weekly resets.
- [ ] #2 IF `altPruneWeeks` is 0, THEN THE APP SHALL delete no stored character.
- [ ] #3 IF a stored character still holds an extended raid lockout that has not
      run out, THEN THE APP SHALL keep that character whatever the setting.
- [ ] #4 IF the weekly reset time cannot be read from the game, THEN THE APP
      SHALL delete nothing.
- [ ] #5 WHEN the settings panel is opened, THE APP SHALL offer `altPruneWeeks`
      as a 0 to 26 slider under Alt Lockouts, defaulting to 3.
- [ ] #6 WHEN the tooltip is shown after a reload at the default setting, THE APP
      SHALL NOT show a column for `Djinni - EU Mythic Dungeons`.
<!-- AC:END -->

## Tasks

- [x] Confirm the phantom in the live saved-variables file
- [x] Add `PruneStaleAltData()` to `Modules/SavedInstances.lua`
- [x] Call it from `SaveCurrentCharData()`, which runs on every data refresh
- [x] Add the `altPruneWeeks` default and its settings slider
- [x] `luac -p` clean
- [x] Check the cutoff maths against the real saved file, both boundaries
- [x] `deploy.ps1` to the game folder
- [ ] In-game `/reload` check (the ask above)
- [ ] Adversarial and security pass
- [ ] `RELEASE_NOTES.md` entry, since this ships with the unreleased 0.9.16

## Comments

**2026-08-25** Built. Not yet run in a game client, so nothing here is confirmed
behaviour. The adversarial pass is still owed and is deliberately held until ask
2 is answered, because the answer changes what the code does.

**2026-08-25** Rob identified `EU Mythic Dungeons` as an MDI tournament realm,
not a bad realm string. The `## Why` section above was rewritten; commit
`520cde5` still carries the wrong explanation in its message and is superseded
by this card. The fix itself is unchanged and is now better supported: a
character on a realm that has been taken down can never log in again, so a rule
that waits for it to log in and refresh itself would never fire.

**2026-08-25** Rob asked for the prune window to be a setting and said he would
want 3 weeks, so `altPruneWeeks` is now a 0 to 26 slider defaulting to 3. The
old behaviour is the same code at 1.

Checked against Rob's real saved file with
`lua docs/build/check-alt-prune.lua <SavedVariables.lua> 1787660908 86400`,
which runs the same cutoff maths outside the game. Twenty stored characters. At
1 week it drops 13, at 3 weeks it drops 12, and at 26 weeks it drops none. The
one that survives the difference is `Treecat - Aggra (Português)`, last played
2026-08-10, which is the behaviour the setting exists for. The phantom is
dropped at both. Boundary asserts pass: 1 week resolves to this week's reset and
3 weeks to two resets before it.

That script is a one-off check, not a test suite, and `pkgmeta.yaml` keeps
`docs/` out of every build so it cannot ship.
