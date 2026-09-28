# Write docs/PRD.md and docs/DATA-MODEL.md

## What I need from you

**One answer: what will Data Texts deliberately never do?**

The product document (`docs/PRD.md`) has a "Non-goals" section, the list a future session is not
allowed to argue with. Nobody has ever written one for this addon, so it is marked as a gap.
Everything else on this card is done and checked.

**Pass:** you post one `**Decided:**` line below, either accepting the list as it stands or
editing it. An agent then copies it into the PRD and closes the card.

**Fail:** the list says something you would not stand behind. Strike that line and say why.

**Why it needs you:** a non-goal is a statement of intent, and intent is not in the code. The
five below are only what the repository already shows you have refused or cannot do.

**Recommended answer, ready to paste into `## Comments`:**

> **2026-MM-DD** **Decided:** Non-goals are: (1) no "only refresh what is on screen", because
> LDB cannot tell us; (2) no live module toggling, a reload is fine; (3) no settings profiles,
> one account-wide setup; (4) no module that duplicates a good dedicated addon I already use
> (durability is covered by EnhanceQoL); (5) nothing in the download the addon does not need to
> run; (6) no dependency on any one display addon's API.

Number 6 is the only one not already written down as a refusal. It restates PRD goal 2 as a
boundary, and you can drop it.

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
- [x] #1 WHEN docs/PRD.md exists, THE APP SHALL state the purpose, the goals, the success
      criteria, the scope and the non-goals, with the non-goals section either filled from
      Rob's answer or marked as a loud gap rather than invented.
- [x] #2 WHEN docs/DATA-MODEL.md exists, THE APP SHALL document the `DjinnisDataTextsDB`
      shape: the `global` table, the per-module tables and how their keys map to module
      registration keys, the `_migratedFromDGF` and `_schemaVersion` metadata keys, and the
      defaults-merge and schema-migration mechanism in Core.lua.
- [x] #3 WHEN DATA-MODEL.md documents module keys, THE APP SHALL record that
      `ActiveActivity` is registered with a CamelCase key while every other module uses
      lowercase, and flag it as a divergence rather than describing it as the convention.
- [x] #4 WHEN both docs exist, THE APP SHALL update docs/HANDOVER.md to link them and cut
      its own inline goal and data-shape text down to a one-line summary each.
- [x] #5 WHEN the docs are written, THE APP SHALL leave every relative link resolving to a
      file that exists.
<!-- AC:END -->

## Tasks
- [ ] Draft PRD.md from README, CURSEFORGE and task.md. Ask Rob for the non-goals.
      *(PRD drafted; the ask is still unmade, this session had no one to ask.)*
- [x] Draft DATA-MODEL.md from Core.lua: `ns.defaults`, `MergeDefaults`, `RegisterModule`,
      `RunSchemaMigrations` and `SCHEMA_VERSION`.
- [x] Trim the handover's Goal and Canonical data shape sections to one-line summaries plus
      links, per the single-source-of-truth rule.
- [x] Re-run the link check across all markdown.

## Comments

**2026-08-29** Wrote `docs/PRD.md` and `docs/DATA-MODEL.md`, and cut the handover's Goal and
Canonical data shape sections down to a summary plus a link each. All five acceptance criteria
are ticked. The card is not finished in the sense that matters, though: **the PRD's non-goals
section is an explicit `UNKNOWN — confirm with Rob` and still needs an answer.** Criterion #1
allowed either a filled section or a loud gap, and this is the loud gap. It is the one thing in
the card that could not be derived from the repository, and the reviewer's job is to get that
answer rather than to accept the marker.

What the PRD is, and what it is not. Purpose, goals, success criteria, scope, requirements and
constraints are reconstructed from `README.md`, `CURSEFORGE.md`, `docs/build/task.md` and the
code, and the document says so at the top rather than presenting itself as a spec Rob wrote.
Under Non-goals I listed the five things the repository does evidence (the "only refresh what
is displayed" impossibility, reload-gated toggles, no profiles, the deprioritised durability
DataText, and "nothing ships that the addon does not need to run"), clearly labelled as
evidence rather than as a stated non-goal list. Cards 0003 and 0004 are named as open scope
questions, not as non-goals, because that is what they are.

Three things the PRD asks that nobody has answered anywhere in the repository, listed under
Open questions: what would take the alpha modules (Volume Control, Audio Output, Professions)
out of alpha, whether they are meant to leave alpha at all, and what "1.0" would mean for an
addon that has shipped at 0.9.x for its whole life.

DATA-MODEL.md covers the whole saved shape, not just what the handover carried. Beyond the
`global` table, the per-module tables and the two metadata keys, it documents three things the
handover did not mention: `DjinnisDataTextsDB.modules` (the enable flag and poll interval,
outside the per-module tables so no reset can reach them), the character-keyed data tables
`altLockouts` and `delveHistory` with their field lists, and the underscore convention inside a
module table (`currency._altGold`, `currency._postedAuctions`) which is cached data rather than
settings. It also gives the full module key map, twenty-seven registrations with source file,
saved table and broker name, taken from the code rather than from a list.

`ActiveActivity`'s CamelCase key is written up as divergence #1, with the live bug it caused,
why renaming it needs a migration step, and the whole-codebase check for a fourth CamelCase
module. Per the card I documented it and changed no code.

Two more divergences fell out of reading the code that nothing had recorded before. **Two
character-key formats coexist**: `SavedInstances` writes `"Name - Realm"` with spaces for both
`altLockouts` and `delveHistory`, while `Currency._altGold` and `Professions.chars` write
`"Name-Realm"` without them. Nothing joins across the two today, so nothing is broken, but
anything that later wants to match a character across those tables has to normalise first, and
neither format can be split on the dash because realm names contain spaces. **`altLockouts` and
`delveHistory` are top-level tables no module declares**: created on demand by
`Modules/SavedInstances.lua`, never touched by the defaults merge, and not cleared by that
module's Reset to Defaults. Both are recorded as observations. Neither is a card and I opened
none, since the card said document, do not fix.

Assumed, and worth a reviewer's eye: I treated the handover's Decisions locked entries as
grounded fact rather than re-deriving each from git history, and I took the module category
groupings in the PRD's Scope table from `README.md` rather than from the `.toc` phase comments,
which disagree with each other on where a few modules sit. Neither affects the data shape.

Link check: 76 relative links across every markdown file, 2 broken, both pre-existing and both
in `docs/board/README.md`, which the handover says is owned by the `/handover` skill and must
never be edited locally. One is `../../DEPLOY.md` (no such file in this repo), the other is the
`../attachments/NNNN-YYYY-MM-DD-N.png` filename pattern in a template example, which is a
placeholder and not a real link. Every link in the two new docs and in the edited handover
resolves. I ran the check with a throwaway Python script and deleted it rather than leaving a
tool the repo would then have to exclude from its builds.

No test suite ran. `.\vendor\bin\pest.bat` and `.\vendor\bin\pint.bat` do not exist here and
there is no `vendor/` at all: this is a pure-Lua WoW addon with no PHP, no build step and no
test suite, which `CLAUDE.md` states outright. Nothing in this card touches Lua, so there is
nothing to check in a game client either. The verification for this card is a person reading
the two documents.

**2026-09-29** ADVERSARIAL REVIEW (unattended, agent). Verdict: all five criteria met, moved to
`human-review/` for the one question only you can answer (above). No code, so no security pass
and no in-game step.

Attacked, and held:
- **#2 and #3, DATA-MODEL against the code.** Every `ns:RegisterModule("...")` call in the tree
  (27, including the retired `majesticbeast`) matches the key map row for row, and
  `ActiveActivity` is the only CamelCase key; `GetDB()` in `Modules/ActiveActivity.lua:105` reads
  `ns.db.ActiveActivity`, as the divergence says. `ns.defaults.global` matches the table field for
  field. `SCHEMA_VERSION = 2`, `DEFAULT_POLL = 180`, `MergeDefaults` fills only nil keys, and
  `ResetModuleDefaults` wipes every key before re-merging, so the claim that it clears
  `currency._altGold` is true. The init order (DGF migration, then schema migrations, then merge)
  is as written. Both character-key formats confirmed: `" - "` at `SavedInstances.lua:307, 541`,
  `"-"` at `Currency.lua:195` and `Professions/Core.lua:2120`. The `altLockouts` field list
  matches `SaveCurrentCharData` exactly.
- **#4.** The handover's Goal and data-shape sections are one line and a link each.
- **#5.** Re-ran a link check over every markdown file. Nothing broken in the new docs or the
  handover. The only misses are the two in `docs/board/README.md` the builder already named
  (skill-owned, not ours to edit) and five `%20`-encoded image links in `README.md` that a naive
  checker flags but which resolve.

Broke, and fixed in place:
- **16 em dashes** across the two new docs, against this repo's `CLAUDE.md` rule "No em dashes".
  Replaced with colons or commas; no meaning changed.
- **The PRD's Constraints line said "both" 12.1 traps.** The workspace log has had a third since
  2026-09-08 (ask `C_Secrets.Should*BeSecret` first, then test with `issecretvalue`), and the
  0012 fix showed `type()` cannot see a secret. The line now names all three.

Not a defect, noted: `Core.lua` line anchors in DATA-MODEL (`#L1591` etc.) will drift with any
edit to `Core.lua`; they are within two lines today.
