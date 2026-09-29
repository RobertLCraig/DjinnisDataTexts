# Release Notes

<!--
  This file is the PENDING release, not a record of the last one. The version
  heading below names the next tag; everything under it is copied verbatim into
  CHANGELOG.md when release.ps1 runs, and release.ps1 also rewrites the .toc to
  match this version.

  AFTER EVERY RELEASE: clear the body and bump the heading, as it stands now.
  Leaving the shipped notes here is not harmless. 0.9.12's notes sat in this file
  through the whole 0.9.13 cycle, and on 2026-08-14 a release run took the stale
  0.9.12 from here, rewrote a 0.9.13 .toc backwards, and published 0.9.13's code
  to GitHub and CurseForge labelled v0.9.12. Superseded by v0.9.13 the same day.

  The habit that avoids a repeat: clear this file in the same sitting as the
  release, not "next time". Shipped notes live in CHANGELOG.md, which is where
  release.ps1 has already put them, so there is nothing to preserve here.

  Do NOT write a version heading inside a comment like this one. release.ps1
  extracts the version by regex BEFORE it strips comments, so the first match in
  the file wins even when commented out, and the release is named from whatever
  that captures. A draft of this file did exactly that and resolved the version to
  a single backtick.

  Write entries as user-facing prose under ### Added / ### Fixed / ### Changed:
  what changed, and enough of why that someone reading the addon page understands
  it. Comments are stripped from the published notes.
-->

## Version: 0.9.16

### Fixed

- **Saved Instances no longer remembers characters forever.** Every character you had ever
  logged in kept its own tooltip column, carrying whatever keys and lockouts it had when you
  last played it, however long ago. One of them was on a Mythic Dungeon International
  tournament realm that Blizzard has since taken down, so it could never be cleared by
  playing it again. Characters you have not played for a while are now forgotten.
- **The Item Level module's SimC export now hands off to the Simulationcraft addon.** It was
  looking for that addon's `/simc` command under a name nothing registers, so the handoff
  missed on every machine, even where Simulationcraft was installed and working, and you
  always got Data Texts' own simpler export instead.
- **And that own export is now in a format Raidbots accepts**, for anyone who does not have
  the Simulationcraft addon. It used to paste each item as a raw link and carried no talents
  at all, so the sites either refused it or imported a character with no talents, which is
  worse than an error. It now writes the same keyed gear lines the real addon writes, with
  enchants, gems, bonus ids and crafted stats, plus your talent loadout, region, realm, role
  and professions.

### Added

- **An Achievements DataText.** The label shows your achievement points, and a `<session>`
  tag adds how many you have earned since logging in. The tooltip lists your most recently
  completed achievements with their dates (five by default, up to ten) and every achievement
  you are tracking, each with its criteria: a progress bar for counted ones, done or not done
  for the rest. Left-click the DataText for the achievement window; left-click a row to open
  that achievement. Right-click either for a menu, which on a row offers open, untrack and
  link in chat.
- **A "Forget an alt after this many weeks" slider**, under Saved Instances, Alt Lockouts.
  It counts weekly resets and defaults to 3. Set it to 0 to keep every character forever,
  which is the old behaviour. A character still holding an extended raid lockout is kept
  whatever you set, because that lockout is genuinely still yours.
- **Extra time zones on the Time / Date tooltip.** Up to four more clocks, each with your own
  label, for keeping track of friends or a raid team in another region. Set the zone's
  standard offset from UTC and pick a daylight saving rule (United States and Canada, Europe
  and the UK, south-east Australia, or none), and the summer hour switches on and off on the
  right dates by itself. A small "+1d" shows when that zone is already on tomorrow. Turn them
  on under Time / Date, Extra Time Zones; New York, London and Sydney are filled in ready.

### Changed

- **The Delve tracker now recognises Lairs.** Patch 12.1.0 added Lairs, and the game
  reports every Lair as an active delve, so the tracker labelled them "Delve". The label
  and the tooltip header now read "Lair" when you are in one.
- The Delve tracker's label template gains a `<kind>` tag, which resolves to "Lair" or
  "Delve". The default template is now `<kind>: <progress>`. If you were still on the old
  default it is updated for you on first load; a template you typed yourself is untouched.
