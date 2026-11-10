# Changelog — Single Player Plus fix (`Patch-SPPlus.ps1`)

The script prints its version at the top of the window when it runs. It's versioned
apart from the PlugY patch (`CHANGELOG.md`).

Versioning: **MAJOR** changes what gets written into `pd2data.mpq`, **MINOR** adds
features or usability changes, **PATCH** is fixes only.

## 1.1.0 — 2026-11-10

For the mod's 14.0.2. On 14.0.1 it writes the same bytes as 1.0.1, so a `pd2data.mpq`
that 1.0.1 patched shows `ALREADY PATCHED`.

### Fixed
- **Mod 14.0.2: `FAILED: CubeMain.txt has 2981 rows but cubemain.bin 2991 - they don't
  match.`** 14.0.2's compiled `cubemain.bin` has 10 records after the last row of its
  `CubeMain.txt`: 7 recipes that turn 50 old perfect gems (or skulls) into 50 Season 14
  ones, 2 empty records, and one that turns a key into 50 each of the old Perfect
  Emeralds, Diamonds and Sapphires (it looks like a test recipe). 1.0.1 wanted one
  record per row. A compiled table may now have records after the text's last row. The
  rows that exist are checked against their records as before, and the extra records get
  the fix in the compiled table only. A text with more rows than its table still stops.

14.0.2 still needs the fix. Monsters drop `(old)` runes (the same 44 treasure-class
slots), the 52 rune downgrades give them, and the 70 crafting infusions and the 12
downgrades from Um up ask for them: 55 results and 152 ingredients with the key recipe.
The mod fixed Gheed's gem boxes and the rainbow facets itself in 14.0.2.

### Changed
- **Recipes that turn an old item into its Season 14 item are left as they are**:
  14.0.2's seven for the perfect gems and skulls. Swapping their ingredient would have
  left "50 Perfect Amethysts into 50 Perfect Amethysts". The rule: one of the recipe's
  results is the Season 14 item of one of its old ingredients.
- The key recipe's results become Season 14 gems, like every other result.
- **Testing mode with 14.0.2.** The game compiles `data\global\excel\cubemain.bin` from
  `CubeMain.txt`, so its copy has 2981 recipes and can't equal the mod's 2991. 1.0.1
  would have called it a different version and left it. Where the mod's table has more
  records than its text, a loose copy is now checked against the text instead. A copy
  compiled from the mod's text gets the fix (backed up as `….stock-backup`); a copy
  compiled from the patched text is reported as already fixed. `-Restore` puts a loose
  copy back when it's the fix of its backup. Where table and text have the same number
  of records (14.0.1, and 14.0.2's treasure classes), it works as in 1.0.1: only exact
  copies of the mod's table are patched.
- In testing mode the 10 extra recipes don't exist: the game builds its recipes from the
  text, which doesn't have them.

### Checked
- 78 offline scenario checks on 14.0.1, 14.0.2, PD2's own Season 14 (Patch #2
  maint2) and Season 13 data: fresh patch, re-run, restore, the `.bat` files, an update
  from a patched 14.0.1 to 14.0.2, loose testing-mode copies in each state, and made-up
  archives that must be refused (text longer than its table, text that names a
  different old rune than the table) or must work (a treasure table longer than its
  text, a text with all 2991 recipes).
- An independent Python check of the patched 14.0.1 and 14.0.2 archives: every other
  file unchanged, no old result left, old ingredients only in the 20 twin and 7
  conversion recipes, and the rune treasure classes name the same items as PD2's own
  Season 14 data.
- The tables the game itself compiled from the patched 14.0.1 text (testing mode,
  7 Nov) are byte-identical to the ones this writes into the archive.
- Installed on a 14.0.2 game folder, next to the PlugY patch 6.0.1 on the mod's DLL:
  the independent check passes on the installed archive, and a second run says
  `ALREADY PATCHED`.
- Not tried in game on 14.0.2.

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
