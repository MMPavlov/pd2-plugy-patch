# Single Player Plus mod: `(old)` runes and gems

Back to the [README](../README.md). This fix is separate from the PlugY patch: it works
with or without PlugY.

Season 14 merged PD2's stacked and unstacked runes and gems. `El Rune` (`r01`) is now
the stackable one, and the Season 13 stacks (`r01s`, `gpws`, …) are only kept as
`El Rune (old)`, `Perfect Diamond (old)`, … They don't stack with the new ones, don't
go into the stash's Runes / Gems tabs and can't be socketed.

The [Single Player Plus](https://github.com/Lukaszpg/PD2-Single-Player-Plus-mod) mod
(14.0.1 and 14.0.2) still uses the old ones in its `pd2data.mpq`
([its issue #46](https://github.com/Lukaszpg/PD2-Single-Player-Plus-mod/issues/46)):

- **monsters drop old runes**: its `Runes 1`–`17` treasure classes name `r01s`–`r33s`,
  where PD2's own Season 14 data names `r01`–`r33`;
- **the cube gives old items**: the rune downgrades (in 14.0.1 Gheed's gem boxes too);
- **the cube asks for old items**: the crafting infusions and the downgrades from Um up
  (in 14.0.1 the rainbow facets too). New runes and gems don't fit them.

14.0.2 fixed the gem boxes and the rainbow facets itself. The rest is as in 14.0.1.

It isn't caused by PlugY or by the PlugY patch: it happens without PlugY too.

**Fix: close the game, double-click `Run-SPPlus-Patch.bat`.** It rewrites those to the
Season 14 items in the mod's treasure classes and cube recipes, in both the `.txt`
files and the compiled `.bin` files the game loads. The drop rates are the mod's.
Nothing else in the mod changes. It backs `pd2data.mpq` up as `pd2data.mpq.stock-backup`
first. `Restore-SPPlus.bat` puts that back.

- **Old runes and gems you already have stay old.** They still work wherever the cube
  takes any rune of a kind, like the rune upgrades (3 El → Eld). The Eld to Pul
  downgrades exist in the mod twice, for new and old runes. The fix leaves the old-rune
  copy as it is, and it now gives new runes. So an old rune can still be turned into
  new ones there.
- **14.0.2's recipes for old perfect gems stay.** Its compiled `cubemain.bin` has 7
  recipes that turn 50 old perfect gems (or skulls) into 50 Season 14 ones. The fix
  leaves them as they are. They're only in the compiled table, not in the mod's
  `CubeMain.txt`, so testing mode doesn't have them.
- **Testing mode** (`-direct -txt`): the game writes compiled copies of the tables to
  `ProjectD2\data\global\excel` and from then on reads those instead of `pd2data.mpq`.
  The fix patches the copies of `treasureclassex.bin` and `cubemain.bin` there too, if
  they're the mod's originals, and keeps the originals as `….stock-backup`. A copy that's
  some other version is left as is, with a warning: move it out of that folder to use
  the fix. After updating the mod, move all the `.bin` files out of that folder (the
  `….stock-backup` files can stay): they were compiled from the previous version's data,
  and the game rebuilds them the next time you enter a game.
- **After updating the mod**, run `Run-SPPlus-Patch.bat` again. On data that doesn't
  need it (PD2's own, or a mod version that fixed this) it says *nothing to fix* and
  changes nothing.
- Which items are old is read from the mod's data (PD2 names them `… (old)`). Every
  compiled record is checked against its `.txt` row first. If something doesn't
  match, it stops and changes nothing. A compiled table may have records after the
  last `.txt` row (14.0.2's `cubemain.bin` has 10); those are fixed in the compiled
  table only. The changed files are written uncompressed at
  the end of the archive, the way Blizzard stores half of `d2data.mpq`, and then the
  whole archive is read back and checked.
