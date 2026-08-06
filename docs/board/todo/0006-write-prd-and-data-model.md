# Write docs/PRD.md and docs/DATA-MODEL.md

## Why
The project doc set has no PRD, no DATA-MODEL and no DECISIONS log. The handover currently
carries an interim goal and success criteria inline, which is explicitly a gap rather than
the intended home for them, and the canonical data shape is summarised in the handover
rather than owned by a doc.

Most of the raw material already exists and does not need inventing: `README.md` and
`CURSEFORGE.md` carry the purpose, the module list and the feature set;
[docs/build/task.md](../../build/task.md) carries nine phases of history and the scope that
was actually built; `Core.lua` carries the real saved-variables shape and its schema
migration mechanism.

The one thing that cannot be lifted from existing files is the non-goals section, which is
the part of a PRD that does the most work. That needs Rob.

## Not this card
- `DECISIONS.md`. Retrofitting a decision log from git history is a separate job and a
  larger one; open a card for it if it is wanted.
- Rewriting `README.md` or `CURSEFORGE.md`. They are the user-facing docs and stay as they
  are; the PRD links to them rather than restating them.
- Any change to the code, including the `ActiveActivity` key inconsistency noted in the
  handover. Document it, do not fix it here.

## Acceptance
<!-- AC:BEGIN -->
- [ ] #1 WHEN docs/PRD.md exists, THE APP SHALL state the purpose, the goals, the success
      criteria, the scope and the non-goals, with the non-goals section either filled from
      Rob's answer or marked as a loud gap rather than invented.
- [ ] #2 WHEN docs/DATA-MODEL.md exists, THE APP SHALL document the `DjinnisDataTextsDB`
      shape: the `global` table, the per-module tables and how their keys map to module
      registration keys, the `_migratedFromDGF` and `_schemaVersion` metadata keys, and the
      defaults-merge and schema-migration mechanism in Core.lua.
- [ ] #3 WHEN DATA-MODEL.md documents module keys, THE APP SHALL record that
      `ActiveActivity` is registered with a CamelCase key while every other module uses
      lowercase, and flag it as a divergence rather than describing it as the convention.
- [ ] #4 WHEN both docs exist, THE APP SHALL update docs/HANDOVER.md to link them and cut
      its own inline goal and data-shape text down to a one-line summary each.
- [ ] #5 WHEN the docs are written, THE APP SHALL leave every relative link resolving to a
      file that exists.
<!-- AC:END -->

## Tasks
- [ ] Draft PRD.md from README, CURSEFORGE and task.md. Ask Rob for the non-goals.
- [ ] Draft DATA-MODEL.md from Core.lua: `ns.defaults`, `MergeDefaults`, `RegisterModule`,
      `RunSchemaMigrations` and `SCHEMA_VERSION`.
- [ ] Trim the handover's Goal and Canonical data shape sections to one-line summaries plus
      links, per the single-source-of-truth rule.
- [ ] Re-run the link check across all markdown.
