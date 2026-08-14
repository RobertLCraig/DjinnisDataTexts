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

  Do NOT write a version heading inside a comment like this one. release.ps1
  extracts the version by regex BEFORE it strips comments, so the first match in
  the file wins even when commented out, and the release is named from whatever
  that captures. A draft of this file did exactly that and resolved the version to
  a single backtick.

  Write entries as user-facing prose under ### Added / ### Fixed / ### Changed:
  what changed, and enough of why that someone reading the addon page understands
  it. Comments are stripped from the published notes.
-->

## Version: 0.9.14

### Fixed

- **The Modules panel's text overlapped itself and the buttons.** The panel measured each paragraph's height before it had been given a width, so a wrapped paragraph was measured as a single line and everything below it was placed about 45 pixels too high. The two descriptions collided and the Reload UI / Enable All / Disable All row landed on top of them. Descriptions are now measured against a known width, which affects every settings panel, not just this one.
- **Active Activity read its saved settings from the wrong key.** It looked up `activeactivity` where its settings are actually stored under `ActiveActivity`, so the lookup always missed and silently fell back to the built-in defaults. Two things were broken by this and both now work: its idle click actions were saved but never read, so configuring them did nothing; and its tracker on/off checkboxes could not persist, forgetting themselves on every reload while writing into the defaults table in memory.
- **Active Activity was the only module showing its internal name.** It now reads "Active Activity" in the settings list instead of `ActiveActivity`.

### Changed

- **Delve and Prey Tracker have one switch each instead of two.** They have no DataText of their own; they feed Active Activity, which owns the broker and shows whichever activity you are currently in. They were nevertheless listed in the Modules panel as though disabling them would remove a DataText, while Active Activity's own panel carried a second, separate switch for each. The two could disagree, and the worst case was a tracker that kept scanning, kept registering events and kept polling every three minutes while Active Activity discarded everything it produced. Their controls now live only in Active Activity's panel, complete with the refresh-interval dropdown, and that switch is the real one: turning a tracker off stops its work rather than only hiding its output.
- **The Modules panel says what it actually does.** It described every row as one DataText. Professions is one row that adds one DataText per profession you have learned, which the description now says.
