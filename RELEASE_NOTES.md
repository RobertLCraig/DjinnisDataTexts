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
  always got Data Texts' own simpler export instead. That fallback export is still not in a
  format Raidbots accepts; fixing it is a separate job and is not done yet.

### Added

- **A "Forget an alt after this many weeks" slider**, under Saved Instances, Alt Lockouts.
  It counts weekly resets and defaults to 3. Set it to 0 to keep every character forever,
  which is the old behaviour. A character still holding an extended raid lockout is kept
  whatever you set, because that lockout is genuinely still yours.

### Changed

- **The Delve tracker now recognises Lairs.** Patch 12.1.0 added Lairs, and the game
  reports every Lair as an active delve, so the tracker labelled them "Delve". The label
  and the tooltip header now read "Lair" when you are in one.
- The Delve tracker's label template gains a `<kind>` tag, which resolves to "Lair" or
  "Delve". The default template is now `<kind>: <progress>`. If you were still on the old
  default it is updated for you on first load; a template you typed yourself is untouched.
