# Changelog — Single Player Plus fix (`Patch-SPPlus.ps1`)

The script prints its version at the top of the window when it runs. It's versioned
apart from the PlugY patch (`CHANGELOG.md`).

Versioning: **MAJOR** changes what gets written into `pd2data.mpq`, **MINOR** adds
features or usability changes, **PATCH** is fixes only.

## 1.0.1 — 2026-10-29

### Fixed
- **Testing mode still dropped `(old)` runes** (seen on the Countess). With
  `-direct -txt` the game writes compiled copies of its tables to
  `data\global\excel` and reads those instead of `pd2data.mpq`, so 1.0.0's fix didn't
  reach it. Loose copies of `treasureclassex.bin` and `cubemain.bin` (or their `.txt`)
  that are the mod's originals now get the same fix, backed up as `….stock-backup`.
  `-Restore` puts them back. Any other version is left as is, with a warning. On a
  `pd2data.mpq` that 1.0.0 already patched, running this patches just the loose copies.

## 1.0.0 — 2026-10-29

First version, for the [Single Player Plus](https://github.com/Lukaszpg/PD2-Single-Player-Plus-mod)
mod 14.0.1 on Season 14 ([its issue #46](https://github.com/Lukaszpg/PD2-Single-Player-Plus-mod/issues/46)).

### Fixed
- **Monsters dropped `(old)` runes.** Season 14 made `r01`–`r33` the stackable runes and
  kept the Season 13 stacks `r01s`–`r33s` only as `El Rune (old)` … `Zod Rune (old)`.
  The mod's `Runes 1`–`17` and `Runes 12`–`17 equiv` treasure classes still named the
  old ones (44 slots). They now name the Season 14 runes, with the mod's drop rates.
- **The cube gave `(old)` runes and gems**: the 52 rune downgrade recipes and the 7
  Gheed's gem boxes (59 results). They now give the Season 14 items.
- **The cube asked for `(old)` runes and gems**: the 70 crafting infusions, the 12
  downgrades from Um up and the 4 rainbow facets (156 ingredients). They now take the
  Season 14 items. The 20 downgrades (Eld … Pul) that the mod has for both new and old
  runes keep their old-rune copy, which now gives new runes.

### How
- Which items are old comes from the mod's data: a misc item whose code is a Season 14
  item's code + `s` and whose name (in `patchstring.tbl`) ends in `(old)`. 47 in 14.0.1:
  33 runes, 12 flawless / perfect gems, 2 skulls.
- `TreasureClassEx` and `CubeMain` are changed in both the `.txt` and the compiled
  `.bin`. Before anything is changed, every `.bin` record is checked against its `.txt`
  row (item names; cube inputs and outputs by item index).
- The 4 files are written uncompressed after the original archive, followed by the
  hash table (unchanged) and a new block table. All files in the rebuilt archive are
  read back and compared before it's saved. The original is kept as
  `pd2data.mpq.stock-backup`. `-Restore` only puts it back if patching it again gives
  exactly what's in `pd2data.mpq`.
