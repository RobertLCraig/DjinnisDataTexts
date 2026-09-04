# The settings panel dies sorting communities, because a club name is now a secret

## What I need from you

**One check in the client.** Open the Communities settings panel (the "Enabled
Communities" list) and hover the Communities broker. Neither should throw, and
the club list should still be there. Deployed to the game folder on 2026-09-04,
so `/reload` is enough.

If the club names come back as secrets, the list is ordered by club id instead
of alphabetically. That is the fallback working, not a second bug. Names are
still shown: `SetText` accepts a secret, only comparing one throws.

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
cannot see a secret** — `type()` still answers `"string"`. So every club passed
the filter and `table.sort` compared two secrets, which throws.

Four sorts had the same comparator, two of them in this addon and two in
`DjinnisGuildFriends`, so the fix went in at both. Only the settings one had
been reached in a game.

## What was done

One helper, `SortClubsByName(list, GetInfo)`, in `Modules/Communities.lua`,
used by both club sorts here. It probes each name once with a pcall, and if any
name is unreadable it orders the **whole** list by `clubId`.

Ordering the whole list matters. A comparator that guards each pair and falls
back per pair is inconsistent when some names are readable and some are not, and
`table.sort` errors on an inconsistent comparator by itself — trading one crash
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
- [ ] Adversarial and security pass

## Comments

**2026-09-04** Built. Not yet seen in a client, so acceptance #5 is unconfirmed.

The check is `lua docs/build/check-club-sort.lua` from the addon root; it takes
an optional path so it can be pointed at a doctored copy to prove it goes red.
It was run against the pre-fix comparator first and failed with the exact error
Rob saw. `pkgmeta.yaml` keeps `docs/` out of every build, so it cannot ship.

The deploy also carried an already-committed `Modules/ItemLevel.lua` that had
never reached the game folder. Unrelated to this card.
