# Seasons and complete setups

Back to the [README](../README.md). For installing the patch into a game that already
has PD2 and PlugY, the README's four steps are all you need.

## Which season?

PD2 is on Season 14 now. [TDL's PlugY pack](https://github.com/TDLofCC/PD2-PlugY) and
its testing modpack were made for **Season 13**; this patch works on both.

| | Season 14 (current) | Season 13 (rollback) |
|---|---|---|
| PlugY's stash pages ([TDL's pack](https://github.com/TDLofCC/PD2-PlugY)) | yes | yes |
| green stat ranges with PlugY (this patch) | yes, from 4.0.0 | yes |
| TDL's testing modpack | **no**, its files are Season 13's | yes |
| `Launch-PD2-PlugY.bat` (fixes *Read process memory failed*) | yes | yes |
| PD2 launcher | use it as normal, then re-run `Run-Patch.bat` | **never open it** |

Season 14 was tested in game on one install with PlugY 14.03, first on the Season 14
hotfix build and then on the Single Player Plus mod's DLL (the launch build). Stat
ranges show, PlugY's stash pages go both ways, and only PD2's tooltip is drawn. PD2's
categories (Gems, Runes, …) work from 6.0.0. The cube on the stash page and the search
field are drawn too, but haven't been tested alongside PlugY.

From 5.0.0, PlugY's page buttons show only on PD2's **Stash** category (the first one
down the left of the stash). On Gems, Runes and the other categories they're hidden and
can't be clicked, so PlugY's pages no longer turn behind PD2's storage.

From 6.0.0, those categories are PD2's own again: you can put gems, runes and other
materials in, and take them out. With PlugY, PD2 normally switches its material storage
off. 6.0.0 turns it back on and gives those categories PD2's own stash clicks. On the
Stash category everything stays as before: PlugY's pages, PlugY's buttons.

| what | where it's kept with PlugY |
|---|---|
| items on the Stash category | PlugY's stash pages (`.d2x`, `_LOD_SharedStashSave.sss`) |
| gems, runes, … on the other categories | `Save\shared.stash` (hardcore: `hc_shared.stash`) |
| PD2's compendium (Uniques, Sets) | `Save\shared.compendium` (hardcore: `hc_shared.compendium`) |

PD2's own stash page tabs along the top of the stash (P, I–IX) are hidden under PlugY,
where PlugY's page buttons are; they didn't do anything with PlugY anyway.

PD2's own `pd2_shared.stash` and `pd2_shared.compendium` aren't touched under PlugY: they
also hold PD2's own shared stash pages, which PlugY replaces. So what you put in with
PlugY stays apart from what you put in when you play PD2 without PlugY.

Before 6.0.0, a click on a category with an item on the cursor went to the PlugY page
hidden behind it.

## Season 14: PlugY with stat ranges

1. **Diablo II: Lord of Destruction + Project Diablo 2**, updated to Season 14 by the
   PD2 launcher as usual. **Back up `Diablo II\Save`** first.
2. **PlugY.** From [TDLofCC/PD2-PlugY](https://github.com/TDLofCC/PD2-PlugY), download
   `PD2-PlugY-with-Extras.zip` (or `PD2-PlugY.zip` for PlugY on its own). Copy its
   `ProjectD2` and `Save` folders into your `Diablo II` folder, merging with what's there.
3. **This patch.** Download the zip from
   [Releases](https://github.com/MMPavlov/pd2-plugy-patch/releases), copy its files into
   `Diablo II\ProjectD2` and double-click **`Run-Patch.bat`** (details under
   *Install* in the [README](../README.md#install)).
4. **Play** with **`Launch-PD2-PlugY.bat`**. Point your desktop shortcut at it.
5. **Leave testing mode alone.** Don't use `Launch-PD2-PlugY (testing).bat` or TDL's
   *PlugY (testing)* shortcut, and keep `-direct -txt` out of `Param=` in `PlugY.ini`.
   Testing mode loads the text files in `ProjectD2\data\global\excel`, and TDL's are
   copies of Season 13's cube recipes and unique items, so the game would run on
   Season 13 data. Wait until TDL updates the pack.
6. **After every PD2 update, double-click `Run-Patch.bat` again** — the PD2 launcher
   puts the original `ProjectDiablo.dll` back.

## Season 13: PlugY with stat ranges (rollback)

Set the game up in this order. Later steps overwrite files from earlier ones, so the
order matters.

1. **Diablo II: Lord of Destruction + Project Diablo 2**, installed and working. On a
   fresh install, start it once through the PD2 launcher so it finishes setting up
   (step 2 rolls the season back afterwards). If you've played before, **back up
   `Diablo II\Save`** first.
2. **Roll back to Season 13.** From Khazra89's client mirror, release
   [`s13p2m2`](https://github.com/Khazra89/Unofficial-PD2-Client-Mirror-S12/releases/tag/s13p2m2),
   download **`ProjectD2-S13P2M2-FullPD2Update.zip`** (about 490 MB). Extract it
   **into your `Diablo II\ProjectD2` folder** and overwrite everything. The zip has no
   `ProjectD2` folder inside, so its files go straight into `ProjectD2`, next to `Game.exe`.
   You don't need the *JustTheLauncherUpdate* file.
3. **PlugY.** From [TDLofCC/PD2-PlugY](https://github.com/TDLofCC/PD2-PlugY), download
   `PD2-PlugY-with-Extras.zip` (or `PD2-PlugY.zip` for PlugY on its own). Copy its
   `ProjectD2` and `Save` folders into your `Diablo II` folder, merging with what's there.
   For the item pack and characters (in `Save\Library`), follow TDL's README. The item
   pack replaces your own shared stash, so back it up first.
4. **This patch.** Download the zip from
   [Releases](https://github.com/MMPavlov/pd2-plugy-patch/releases), copy its files into
   `Diablo II\ProjectD2` and double-click **`Run-Patch.bat`** (details under
   *Install* in the [README](../README.md#install)). It has to come after step 2, because
   step 2 replaces `ProjectDiablo.dll`.
5. **Play** with **`Launch-PD2-PlugY.bat`**, or **`Launch-PD2-PlugY (testing).bat`** for the
   testing modpack. Point your desktop shortcut at it.
6. **Don't open the PD2 launcher again.** It updates the game to the current season,
   which undoes steps 2 and 4. If that happens, redo steps 2 and 4.

Two tips in TDL's README don't apply to this setup:

- *Run PlugY.exe as administrator*: start the game with `Launch-PD2-PlugY.bat`
  instead. `PlugY.exe` started directly fails with *Read process memory failed* on
  current Windows 11 (see [troubleshooting.md](troubleshooting.md)).
- *Run the game once via the launcher* (when PlugY doesn't load): that updates you out
  of Season 13. Do it before step 2, never after.

Rolling back over a Season 14 folder is clean: Season 14 only adds shaders, scripts,
logs and a loot filter, none of which the Season 13 game loads.

## Patched on Season 13, now updated to Season 14

- **The update removed the patch.** The PD2 launcher replaced `ProjectDiablo.dll` with
  the Season 14 one. That's why the stat ranges are gone.
- **Get 4.0.0 or newer and run its `Run-Patch.bat`.** Older versions don't handle
  Season 14: before 3.2.0 they patched it wrongly, and 3.2.x refuse it. 4.0.0 also
  repairs a Season 14 DLL that an older version patched.
- **Your old `ProjectDiablo.dll.stock-backup` is the Season 13 DLL.** Don't copy it
  back by hand: a Season 13 DLL in a Season 14 game breaks it. `Run-Patch.bat`
  replaces it with the Season 14 original when it patches; to roll back later you use
  the mirror zip, not this file.
