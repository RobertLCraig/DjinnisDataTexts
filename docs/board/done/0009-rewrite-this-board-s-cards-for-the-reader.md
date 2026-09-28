# Rewrite this board's cards for the reader

## Why
**A card on this board opens with the answer and never says what is wrong.** On 2026-08-18 Rob said
most of the cards he was handed made him work backwards: they lead with candidate solutions and
their costs, so he has to reverse-engineer the problem out of the proposals. He cannot tell whether
the options are the right ones, because he does not yet know what they are for.

**Two more faults, in his words.** Cards ask him to settle things an agent could have researched and
applied. And a bare card number dropped into a sentence tells him some other card matters and
nothing about why, so he opens it to find out.

**What it costs.** His attention is the only scarce thing here. Measured on 2026-08-20, 258 of 398
open cards across the estate fail at least one of these rules and 257 of those fail on the link rule
alone. A card that reads badly costs a round trip; one that should never have been surfaced costs
the whole reading for nothing. Enough of either and he stops opening the ones that mattered.

**How it came to be this way.** Every card here was written by an agent against a convention that,
until 2026-08-18, said nothing about stating the problem first, nothing about whether a question was
a person's to answer at all, and nothing about how to name another card. It gained all three rules
that day, and nothing was applied to the cards, so this board is measured against a standard none of
it was written to.

## Links

**Relates to**
- `progressboard#0065` - the estate-wide rewrite this card was seeded from; its pilot over
  ProgressBoard's own 40 cards is the worked example of a pass.
- `progressboard#0066` - the five checks the count below is measured with, and why each is
  structural rather than a judgement about prose.

## Not this card
**Changing the convention.** `docs/board/README.md` here is a COPY of a canonical file outside every
repository, so an edit to it is destroyed silently on the next distribution. This card applies the
convention and never changes it.

**Rewriting cards in `done/` or `discarded/`.** Those are a record of what happened. Rewriting a
record is falsifying it, and nobody reads them to decide anything.

**Deleting anything.** A badly written card still holds facts somebody measured. A rewrite keeps
everything the card knows and changes only how it is ordered and said. `## Direction` and
`## Decided` are append-only: do not edit them, on any card, for any reason.

**Any other board.** Each one carries its own copy of this card, worked in its own repository.

## Acceptance
<!-- AC:BEGIN -->
- [x] #1 WHEN a card in a non-terminal lane is rewritten, THE CARD SHALL state the problem in
      `## Why` before any solution appears anywhere in it. proves: none - about prose, and no check
      here reads prose
- [x] #2 WHEN a rewritten card is a decision, THE CARD SHALL say which of the four reasons makes it
      a person's to answer, or SHALL be converted to a feature card whose `## Plan` records the
      practice applied and its source. proves: none - the command that counts it is in another
      repository, named in `## Plan`
- [x] #3 WHEN a rewritten card names another card, THE CARD SHALL name it in a `## Links` section
      with the relationship type and one line of why, and SHALL NOT leave a bare card number in a
      sentence as the only mention of it. proves: none - as #2
- [x] #4 THE `Blocked by` LINES on every rewritten card SHALL match that card's `needs:` frontmatter
      exactly, in both directions. proves: none - as #2
- [x] #5 THE REWRITE SHALL preserve every measurement, date and decision the card already carried,
      and SHALL NOT edit `## Direction` or `## Decided`. proves: none - as #2
- [x] #6 WHEN this board's rewrite is finished, THE BOARD SHALL report zero open cards failing the
      checks. proves: none - as #2
<!-- AC:END -->

## Tasks
- [x] Read the count, and write it into `## Direction` before changing anything
- [x] Rewrite `human-review/` first, then `todo/`, `in-progress/` and `ai-review/`
- [x] For each decision card, apply the four-reason test and convert the ones that fail it
- [x] Read the count again and write into `## Direction` what changed, counted by rule

## Plan
**Where to stand.** This repository, on whatever branch the session was given. Nothing outside it is
edited and no card changes lane. **The one command, from this board's directory, in PowerShell:**

    php C:\Dev\ProgressBoard\artisan board:convention --path=$PWD

It prints one tab-separated line: board name, OPEN cards failing the checks, open cards, the next
free card number, and the directory read. The second number is this card's finish line and it must
reach 0. Run it before the first edit and after the last. `--path` matters: a build worktree is not
`C:\Dev\<board>`, and without it you measure a tree you are not editing.

**What the checks look for is in `docs/board/README.md` here**, three sections of it: "`## Why` is
the PROBLEM, and it comes before any answer", "Links: say what the relationship IS, never a bare
card number", and "Is this actually a person's to decide?". Read those three first. Every check is
structural - a missing `## Links` section, a `Blocked by` line that disagrees with `needs:`, a link
with nothing after the dash - so each flag names one thing to fix and none is an opinion.

**`human-review/` first, and that is not tidiness.** That lane is the only one a person reads. A
`todo/` card is read by an agent, a reader with different problems, so rewriting those first spends
the session on the half nobody is complaining about.

**Expect the four-reason test to shrink the queue rather than reformat it.** A decision whose answer
turns on established practice is not Rob's: research it, apply it, and rewrite the card as a feature
card whose `## Plan` says what was applied and where it came from. Count those separately from the
cards merely rewritten - that is the change that gives him evenings back.

**If the board is too big for one session, stop cleanly.** Tick nothing, write the count you reached
into `## Direction`, and leave the card where it is; the next session carries on from that entry. A
part-rewritten board is normal. A card ticked off a board that is not at 0 is not.

## Comments
<!-- The card's thread, appended by ProgressBoard. Append-only: entries are added, never edited or removed. An entry beginning **Decided:** is an answer, and that is what a decision card exits on. -->

**2026-08-29** The count before any edit, from
`php C:\Dev\ProgressBoard\artisan board:convention --path=$PWD` in the build worktree:

    DjinnisDataTexts	5	9	0012	C:\Users\r\AppData\Local\ProgressBoard\worktrees\WoWAddons\DjinnisDataTexts

**5 open cards of 9 fail the checks.** Which card fails which check is not printed by that command,
so it was read from the same code the count comes from, `Card::conventionFlags()`:

| Card | Lane | Flag |
|---|---|---|
| 0001 | `human-review/` | unexplained link: 0003 |
| 0010 | `human-review/` | outward effect, no `not_for_the_loop:`: browser |
| 0002 | `todo/` | unexplained link: 0001, 0003 |
| 0003 | `todo/` | `Blocked by` and `needs:` disagree: 0002 in `needs:`, not under `Blocked by` |
| 0004 | `todo/` | unexplained link: 0001; `Blocked by` and `needs:` disagree: 0002 |

Four of the nine already pass and are not touched: 0007, 0009, 0006 and 0008.

**2026-08-29** The board is at zero. Same command, after the last edit:

    DjinnisDataTexts	0	9	0012	C:\Users\r\AppData\Local\ProgressBoard\worktrees\WoWAddons\DjinnisDataTexts

**What changed, counted by rule.** Five cards were rewritten and six flags were cleared:

- **Unexplained link (3 cards, 4 flags).** 0001, 0002 and 0004 each named another card in a
  sentence and nowhere else. Each now carries a `## Links` section under `## Why`, one line per
  link saying what the other card is for. Nothing was deleted to clear these: the prose mention
  stays and the section explains it.
- **`Blocked by` and `needs:` disagree (2 cards, 2 flags).** 0003 and 0004 both carry
  `needs: 0002` in frontmatter and said "Blocked on 0002" in prose, which no view can render.
  Both now say it under `**Blocked by**` as well, with the reason on the line.
- **Outward effect with no `not_for_the_loop:` (1 card, 1 flag).** 0010's criterion #6 is a paste
  into raidbots.com in a browser. That is a real outward effect and not a false positive, so it
  got `not_for_the_loop:` and not `no_outward_effect:`. Nothing about the card's lane or its
  content changed; the key only tells the unattended loop to leave it alone, which is already
  true of it in practice.

**The four-reason test found nothing to convert.** Three decision cards were read against it,
0002, 0003 and 0004. All three turn on a cost or a risk Rob carries and none of them turns on
established practice an agent could have researched:

- 0002 commits him publicly, on a page anybody can read, to a scope and a rough timeframe. It
  already said so and needed no change.
- 0003 and 0004 are each a choice between a day of his time and several, plus the ongoing
  support of a much larger tooltip. Neither said so, so each now opens its `## Recommendation`
  with one line naming the reason. **Nothing was converted to a feature card and the queue did
  not shrink**, which is the outcome the card's `## Plan` said to expect the other way round.
  It is honest here: this is a nine-card board, not a forty-card one.

**Two things done differently from the card, both deliberate.**

The count was written to `## Comments` and not to `## Direction`. This card carries neither
`## Direction` nor `## Decided`, and the convention now puts one thread under `## Comments`;
opening a second heading would have split the log the convention just merged.

0001's `## Why` carried a paragraph pointing at `docs/build/PLAN-module-toggles.md`, which is a
solution sitting in the section reserved for the problem. It moved to a new `## Plan` on that
card, whole and unedited, with one line added saying where to stand. The problem paragraph above
it is untouched.

**No `## Direction` or `## Decided` block was edited on any card, and nothing was deleted.**
Every edit was an addition, apart from that one move. Cards in `done/` and `discarded/` were not
opened.

**There is no suite to run here and there never was.** This repository has no `vendor/`, no
`composer.json` and no PHP; `CLAUDE.md` says the verification is loading the addon in a game
client. Nothing in this card touches Lua, the `.toc` or either PowerShell script, so no addon
behaviour changed and there is nothing to check in a client. The check that matters is the
`board:convention` count above, and it is 0.

**2026-09-29** ADVERSARIAL REVIEW (unattended, agent). Verdict: pass, moved to `done/`. No code,
so no security pass and no in-game step.

Attacked, and held:
- **#5, nothing deleted.** Read every removed line in `6ed1cae` across all six cards it touched:
  the only deletions are the four-line `PLAN-module-toggles.md` paragraph on 0001, and it
  reappears whole under that card's new `## Plan`. No `## Direction` or `## Decided` block was
  touched; no card in `done/` or `discarded/` was opened.
- **#3 and #4.** Spot-read 0003 and 0004: each `Blocked by` line names `0002`, matching
  `needs: 0002`, with a reason after the dash.
- **#1 and #2.** 0003 and 0004 now open their recommendation by naming the cost Rob carries,
  one of the four permitted reasons. No decision card leads `## Why` with a solution.
- **#6.** Re-ran `board:convention --path=$PWD --cards` today. It reports **2 of 10** failing, and
  neither is this card's regression: `0012 unexplained link: djinnisguildfriends#0001` is on a
  card written on 2026-09-04, after this rewrite finished at 0; `0010 unexplained link: 0008`
  was introduced by commit `4d329e9` today, from a separate attended session still working
  that card. The 0012 flag is cleared in 0012's own review. The 0010 flag is left to the
  session holding 0010, to avoid two writers on one file: it needs "card 0008" in its opening
  paragraph explained under `## Links` (0008 is the Lair label check, the other in-game check
  holding 0.9.16).
