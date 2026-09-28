# The settings panel dies sorting communities, because a club name is now a secret

## What I need from you

**Three steps in the client, with BugSack or the error frame open.**

**The second fix (below) is not deployed yet.** It is on branch `claude/0012`, not `master`,
because another session was committing to `master` at the time. First, in
`C:\Dev\WoWAddons\DjinnisDataTexts`: `git merge claude/0012`. Then from `C:\Dev\WoWAddons`:
`.\bin\deploy.ps1 -WhatIf -Only DjinnisDataTexts`, read the plan, run it without `-WhatIf`, and
`/reload`.

1. `/ddt`, then open the Communities settings panel.
   Expect: every settings panel builds, and the "Enabled Communities" list shows your clubs.
2. In that panel set the first grouping to **Community**. Hover the Communities DataText
   while at least one club member is online.
   Expect: one header per club with its members underneath, and no error.
3. Set the second grouping to something else (for example Zone) and hover again.
   Expect: sub-headers under each club header, and no error.

**Pass:** all three, and no Lua error at any point.

**Fail:** any "attempt to compare / concatenate / index a secret" error. Paste it into
`## Comments` and move the card to `todo/`.

**Why it needs you:** secret club names only come from a live client.

What you may see and is not a bug: if club names come back as secrets, the lists are ordered
by club id instead of alphabetically, and a club header shows its name without the member
count in brackets. `SetText` accepts a secret; comparing, joining or indexing one throws.

## Why

Rob hit this on 2026-09-04, twice in one login:

    Communities.lua:858: attempt to compare a secret string value
      (execution tainted by 'DjinnisDataTexts')
    in function 'sort' ... RebuildClubList ... BuildSettingsPanel ...
    SetupOptions ... Core.lua:1641

The whole options panel failed to build, because `SetupOptions` never returned.

`C_Club.GetSubscribedClubs()` now returns clubs whose `name` is a 12.1 secret
string. The error's own locals show it: both clubs had `name=<secret string>`,
while `clubId`, `clubType` and `memberCount` came back as ordinary numbers.

The guard above the sort was `type(clubInfo.name) == "string"`, and **that check
cannot see a secret**: `type()` still answers `"string"`. So every club passed
the filter and `table.sort` compared two secrets, which throws.

Four sorts had the same comparator, two of them in this addon and two in
`DjinnisGuildFriends`, so the fix went in at both. Only the settings one had
been reached in a game.

## Links

**Relates to**
- `djinnisguildfriends#0001` - the same club sort crash in the older addon this one replaced,
  fixed in step with the same helper; a regression there would look identical.

## What was done

One helper, `SortClubsByName(list, GetInfo)`, in `Modules/Communities.lua`,
used by both club sorts here. It probes each name once with a pcall, and if any
name is unreadable it orders the **whole** list by `clubId`.

Ordering the whole list matters. A comparator that guards each pair and falls
back per pair is inconsistent when some names are readable and some are not, and
`table.sort` errors on an inconsistent comparator by itself, trading one crash
for a rarer one.

## Not this card

- The member-name sorts in `ns.SORT_FUNCTIONS`. Member names come from
  `C_Club.GetMemberInfo` and can be secret too, but the ingest loop in
  `UpdateData()` is already inside a pcall, so a secret name never reaches those
  comparators. Worth a card if that pcall is ever removed.
- Item, currency and profession name sorts. Those names are not unit identity
  and are not secret.
- `SortGroupOrder`, which does string ops on `member.area`. Same pcall shields it.
- Anything outside the club list. This card is the reported crash and its exact
  siblings.

## Acceptance
<!-- AC:BEGIN -->
- [x] #1 WHEN a subscribed club has a secret name, THE APP SHALL order the club
      list without throwing.
- [x] #2 WHEN every club name is readable, THE APP SHALL still order the list
      alphabetically by name.
- [x] #3 IF some club names are readable and some are not, THEN THE APP SHALL
      order the whole list by `clubId` rather than mixing the two orderings.
- [x] #4 IF a club has no name at all, THE APP SHALL NOT throw.
- [ ] #5 WHEN the settings panel is opened in the client, THE APP SHALL build
      every panel, including Communities.
<!-- AC:END -->

## Tasks

- [x] Reproduce the throw outside the game, with a fake secret that errors on
      comparison
- [x] Replace both club sorts with the shared helper
- [x] Same fix in `DjinnisGuildFriends` (its own card, `djinnisguildfriends#0001`)
- [x] Regression check at `docs/build/check-club-sort.lua`, which lifts the real
      function out of the source between the `[club-sort]` markers, so reverting
      the fix fails it. Seen to fail against the old comparator first.
- [x] `loadfile` clean
- [x] `deploy.ps1 -Only DjinnisDataTexts`
- [ ] In-game `/reload` check (the ask above)
- [x] Adversarial and security pass (2026-09-29, below)

## Comments

**2026-09-04** Built. Not yet seen in a client, so acceptance #5 is unconfirmed.

The check is `lua docs/build/check-club-sort.lua` from the addon root; it takes
an optional path so it can be pointed at a doctored copy to prove it goes red.
It was run against the pre-fix comparator first and failed with the exact error
Rob saw. `pkgmeta.yaml` keeps `docs/` out of every build, so it cannot ship.

The deploy also carried an already-committed `Modules/ItemLevel.lua` that had
never reached the game folder. Unrelated to this card.

**2026-09-29** ADVERSARIAL REVIEW (unattended, agent). Verdict: #1 to #4 hold; a second crash
on the same secret name was found and fixed; moved to `human-review/` for the three steps above,
which settle #5.

Attacked, and held:
- **The regression check can fail.** `lua docs/build/check-club-sort.lua` passes (5 of 5).
  Pointed at a copy whose `[club-sort]` block holds the old comparator, it goes red with
  "attempt to compare a secret string value", the error Rob saw.
- **#3, mixed names.** Decided once for the whole list, then sorted, as the workspace
  2026-08-21 entry (extended 2026-09-04) requires. **#4:** a nil name fails the probe, so the
  list falls back to `clubId` order instead of throwing.
- **API.** `C_Club.GetSubscribedClubs` carries `SecretInChatMessagingLockdown`
  (`ClubDocumentation.lua:779`). `FontString:SetText` is `SecretArguments = "AllowedWhenTainted"`
  (`SimpleFontStringAPIDocumentation.lua:664`), so the card's "names are still shown" is right.

Broke, and fixed in place (`Modules/Communities.lua`):
- **The tooltip's "group by Community" path used the club name as a table key and joined it
  into strings**: `GetOrCreateGroupHeader(sc, clubName)` indexes `parent.groupHeaders[name]`,
  then `clubName .. " ("`, then `clubName .. "|" .. subName`. The sort fix stopped the crash one
  line earlier and left this one standing. Headers are now keyed `"club:" .. clubId`, and a
  secret name goes to `SetText` on its own, without the member count.
- **`member.clubName` carried the raw name**, and `BuildGroups` turns it into a group key in
  "community" grouping (second level, or any mode that groups by it). It now holds the name if
  readable, else `"Community <clubId>"`.
- One new local, `IsReadableName`, using the same comparison probe as `SortClubsByName`.
  `luac -p` clean, club-sort check still 5 of 5. Not covered by an offline check; steps 2 and 3
  above are the proof.
- Added `## Links` for `djinnisguildfriends#0001`, which the board's convention check flagged.
  Removed two em dashes.

Security (code card): **weakest point** is any string read from `C_Club` reaching `..`, `<` or a
table index. The club ingest and both club lists are now covered; member fields stay inside the
existing `pcall` in `UpdateData`. **Unchecked path:** the `type(clubInfo.name) == "string"`
filters at the ingest and settings list still let a secret through by design, and everything
after them now tolerates one. **Leaks:** nothing. A failure shows a club id rather than a name,
and no data leaves the client.

Not this card: `DjinnisGuildFriends/CommunitiesBroker.lua:485-498` has the identical header
path (name as key, name joined into strings). It is a dormant addon in its own repository with
its own card, `djinnisguildfriends#0001`; not touched here.

