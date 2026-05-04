# Release Notes

## Version: 0.9.12

### Fixed

- **LFG Status tooltip row overlap.** Instance name and wait/elapsed time were on the same row; at any tooltip width the two strings could collide. They now render on separate rows, with the timing row only appearing when time data is available.
- **LFG Status elapsed time wildly wrong.** `GetLFGQueueStats` returns `queuedTime` as a `GetTime()` timestamp, not a duration. The tooltip row and the `<elapsed>` label tag were displaying the raw timestamp (tens of thousands of seconds) instead of computing `GetTime() - queuedTime`. Both sites now match Blizzard's own `QueueStatusFrame` implementation.

### Changed

- **LFG Status default tooltip width** reduced from 360 to 340.
- **Tooltip width slider maximum** raised from 500-800 (varied per module) to 2000 across all modules.
- **Experience default tooltip width** raised from 300 to 340 to prevent the XP progress row (`12,345,678 / 23,456,789 (52.6%)`) from overlapping the label.

### Added

- **Reset to Defaults** - every module settings panel now has a collapsed "Reset to Defaults" section at the bottom. Clicking the button wipes the module's saved settings and re-applies its registered defaults, then refreshes all settings widgets live. The General panel has an equivalent button covering number formatting, gold display, and font settings.
