# A character on a dead tournament realm has its own column in Saved Instances

## What I need from you

**One check and one choice.**

1. Run `/reload` in game, hover Saved Instances, and confirm the fourth column
   (the second "Djinni") is gone.
2. Old alts now disappear from the tooltip **and** from the alt tick-list in
   settings once a week goes by without playing them. Keep that, or keep the
   name and drop only the data? I would keep it as built.

---

**On 1.** The addon has already been deployed to the game folder, so `/reload`
is all it takes. Pass is the column gone and no Lua error. Fail is the column
still there, or an alt you played this week going missing: say which in this
card and I will revert, it is one commit.

**On 2.** The tooltip can show a column per character. The addon remembers each
one in its saved settings file. The rule I added is "forget any character not
played since the weekly reset", because that character's keys and raid lockouts
have already reset in game, so showing them is a lie either way.

The cost of that rule: the "show alts active in the last 30 / 60 / 90 / 180
days" dropdown now has nothing left to filter, because nothing older than a week
survives. Those settings become dead options. The other version keeps the name
and level and wipes only the weekly numbers, which keeps the dropdown alive but
leaves every character you have ever logged in sitting in the settings list
forever.

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
  weekly rule already clears them without needing to know what they are.
- Adding a manual "forget this character" button. The weekly rule removes the
  need unless choice 2 above goes the other way.
- The alt filter dropdown itself. If choice 2 lands on "keep it as built", those
  four options are dead and want their own card.
- Any other module. The bug is `Modules/SavedInstances.lua` alone.

## Acceptance
<!-- AC:BEGIN -->
- [ ] #1 WHEN the Saved Instances data refreshes, THE APP SHALL delete any stored
      character whose `lastSeen` predates the current weekly reset.
- [ ] #2 IF a stored character still holds an extended raid lockout that has not
      run out, THEN THE APP SHALL keep that character.
- [ ] #3 IF the weekly reset time cannot be read from the game, THEN THE APP
      SHALL delete nothing.
- [ ] #4 WHEN the tooltip is shown after a reload, THE APP SHALL NOT show a
      column for `Djinni - EU Mythic Dungeons`.
<!-- AC:END -->

## Tasks

- [x] Confirm the phantom in the live saved-variables file
- [x] Add `PruneStaleAltData()` to `Modules/SavedInstances.lua`
- [x] Call it from `SaveCurrentCharData()`, which runs on every data refresh
- [x] `luac -p` clean
- [x] `deploy.ps1` to the game folder
- [ ] In-game `/reload` check (ask 1 above)
- [ ] Adversarial and security pass, once ask 2 is answered
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
