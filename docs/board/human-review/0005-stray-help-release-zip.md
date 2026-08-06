# A release zip is committed under a directory named `--help`

## What I need from you
Say yes or no to removing it from git tracking. To confirm what it is:

1. Run `git ls-files -- '--help'`. Expect exactly one path:
   `--help/DjinnisDataTexts-v0.9.11.zip`. Anything else listed means this card is wrong
   about the scope and should not be acted on.
2. Run `git log --oneline --follow -- '--help/DjinnisDataTexts-v0.9.11.zip'` to see which
   release commit dragged it in. Expect a single commit around v0.9.11 (2026-05-04).
3. Confirm you have the v0.9.11 zip elsewhere, or do not need it. It is reproducible from
   the tag, and `releases/` is gitignored, so the copy in `--help/` is the only tracked one.

A yes means `git rm -r -- '--help'` plus a commit; history keeps the blob either way, so
nothing is destroyed. An agent should not do this unasked: it deletes tracked files, and the
directory name is odd enough that guessing at intent would be wrong.

## Why
`--help/DjinnisDataTexts-v0.9.11.zip` is tracked in the repo: 793KB of build artefact in a
directory named for a command-line flag, almost certainly from `release.ps1` being invoked
with `--help` where a path argument was expected, so the output directory was created
literally. It is excluded from the addon package either way, so it ships to nobody; the cost
is repo weight and a confusing directory at the root that every future session has to work
out and ignore.

Worth a second look while you are here: `release.ps1` created a directory from what was
meant to be a help flag rather than refusing. If that is easy to guard, it stops this
recurring.

## Options
1. **Remove it.** `git rm -r -- '--help'`, commit. Cost: one commit. The blob stays in
   history so the repo does not actually shrink on disk, but the working tree and every
   future checkout are clean.
2. **Leave it.** Cost: nothing today. It stays a small permanent confusion, and it will be
   rediscovered and re-raised by some future session.
3. **Remove it and guard `release.ps1`.** As option 1, plus validating the output-directory
   argument so an unparsed flag cannot become a directory. Cost: option 1 plus a small
   script change that needs testing on a dry run.

## Recommendation
Option 1 now, option 3 if the `release.ps1` guard turns out to be a couple of lines. Do not
leave it: it is the kind of thing that costs a minute to fix and gets re-investigated from
scratch every few months.

## Decided
