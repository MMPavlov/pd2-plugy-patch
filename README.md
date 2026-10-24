# PD2 + PlugY — get the item stat ranges back

Launch Project Diablo 2 through **PlugY** and picked-up items lose their augmented
description: no green `[min - max]` stat ranges, no `Max Sockets`, no `Base Speed`,
no upgrade recipe. This patch brings all of that back **and keeps PlugY's
multi-page / shared stash working**.

> ⚠ **Single player only.** This modifies the game client. Do not use it on the
> PD2 online realm — restore the original first (see below).

> **Season 14 is live, and this patch works on Season 13 only.** On Season 14,
> `Run-Patch.bat` says *this version of PD2 isn't supported yet* and changes nothing.
> For stat ranges with PlugY, roll back to Season 13. See *Which season?* below.

**Version:** printed at the top of the patch window when it runs. See
`CHANGELOG.md` for what changed between versions, and include the version number
when reporting a problem.

## What's in the folder

| file | what it is |
|---|---|
| `Launch-PD2-PlugY.bat` | **double-click this to play** — starts PD2 through PlugY (use it instead of `PlugY.exe`) |
| `Launch-PD2-PlugY (testing).bat` | same, in **testing mode** (`-direct -txt`, loads the testing modpack) |
| `Launch-PD2-PlugY.ps1` | the launcher itself (the `.bat` files just run it) |
| `Run-Patch.bat` | **double-click this** to apply the patch |
| `Restore-Original.bat` | double-click to undo and put the original DLL back |
| `Patch-PD2-PlugY.ps1` | the actual patcher (the `.bat` files just run it) |
| `CHANGELOG.md` | what changed in each version |

## Which season?

PD2 is on Season 14 now. [TDL's PlugY pack](https://github.com/TDLofCC/PD2-PlugY), its
testing modpack and this patch were all made for **Season 13**.

| | Season 14 (current) | Season 13 (rollback) |
|---|---|---|
| PlugY's stash pages ([TDL's pack](https://github.com/TDLofCC/PD2-PlugY)) | yes¹ | yes |
| green stat ranges with PlugY (this patch) | **not yet** | yes |
| TDL's testing modpack | **no**, its files are Season 13's | yes |
| `Launch-PD2-PlugY.bat` (fixes *Read process memory failed*) | yes | yes |
| PD2 launcher | use it as normal | **never open it** |

¹ Season 14 still has PD2's PlugY compatibility mode, and `D2Client.dll` (the file
PlugY changes) is byte-identical to Season 13's, so PlugY should run as before, just
without stat ranges. Not play-tested here on Season 14.

### Season 14: PlugY without stat ranges

1. **Diablo II: Lord of Destruction + Project Diablo 2**, updated to Season 14 by the
   PD2 launcher as usual. **Back up `Diablo II\Save`** first.
2. **PlugY.** From [TDLofCC/PD2-PlugY](https://github.com/TDLofCC/PD2-PlugY), download
   `PD2-PlugY-with-Extras.zip` (or `PD2-PlugY.zip` for PlugY on its own). Copy its
   `ProjectD2` and `Save` folders into your `Diablo II` folder, merging with what's there.
3. **The launcher from this repo.** Download the zip from
   [Releases](https://github.com/MMPavlov/pd2-plugy-patch/releases), copy its files into
   `Diablo II\ProjectD2`, and play with **`Launch-PD2-PlugY.bat`**. You don't need
   `Run-Patch.bat`: on Season 14 it only says it isn't supported yet.
4. **Leave testing mode alone.** Don't use `Launch-PD2-PlugY (testing).bat` or TDL's
   *PlugY (testing)* shortcut, and keep `-direct -txt` out of `Param=` in `PlugY.ini`.
   Testing mode loads the text files in `ProjectD2\data\global\excel`, and TDL's are
   copies of Season 13's cube recipes and unique items, so the game would run on
   Season 13 data. Wait until TDL updates the pack.

### Season 13: PlugY with stat ranges (rollback)

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
   `Diablo II\ProjectD2` and double-click **`Run-Patch.bat`** (details under *Install*
   below). It has to come after step 2, because step 2 replaces `ProjectDiablo.dll`.
5. **Play** with **`Launch-PD2-PlugY.bat`**, or **`Launch-PD2-PlugY (testing).bat`** for the
   testing modpack. Point your desktop shortcut at it.
6. **Don't open the PD2 launcher again.** It updates the game to the current season,
   which undoes steps 2 and 4. If that happens, redo steps 2 and 4.

Two tips in TDL's README don't apply to this setup:

- *Run PlugY.exe as administrator*: start the game with `Launch-PD2-PlugY.bat`
  instead. `PlugY.exe` started directly fails with *Read process memory failed* on
  current Windows 11 (see *Troubleshooting*).
- *Run the game once via the launcher* (when PlugY doesn't load): that updates you out
  of Season 13. Do it before step 2, never after.

Rolling back over a Season 14 folder is clean: Season 14 only adds shaders, scripts,
logs and a loot filter, none of which the Season 13 game loads.

### Patched on Season 13, now updated to Season 14

- **The update removed the patch.** The PD2 launcher replaced `ProjectDiablo.dll` with
  the Season 14 one. That's why the stat ranges are gone.
- **Your `ProjectDiablo.dll.stock-backup` is still the Season 13 DLL.** Don't copy it
  back by hand: a Season 13 DLL in a Season 14 game breaks it. From 3.2.1 on,
  `Restore-Original.bat` checks for this and refuses.
- **Replace the old patch files in your folder with 3.2.1 or newer.** Versions before
  3.2.0 don't check the season: their `Run-Patch.bat` patches Season 14 untested and
  overwrites your Season 13 backup.
- **If you ran an old `Run-Patch.bat` after the update**, run the new one:
  it says *PATCHED BY AN OLDER VERSION - NOT SUPPORTED*. Then double-click
  `Restore-Original.bat` to undo it.
- **To get the stat ranges back**, roll back: steps 2 and 4 of the Season 13 setup.
  Back up `Diablo II\Save` first, because characters you played on Season 14 may not
  load on Season 13.

## Install

For a game that already has PD2 (on **Season 13**) and PlugY:

1. **Close Diablo II completely.**
2. Copy all the files into your Project Diablo 2 folder — the one that has
   `ProjectDiablo.dll`, `D2Client.dll` and `PlugY.exe` in it.
3. Double-click **`Run-Patch.bat`**. If your game is under `Program Files`, Windows asks
   whether to allow changes. Click **Yes** and the patch carries on in a new window.
4. Read the window. You want to see:

   ```
   ============================================
    SUCCESS - patch applied and verified
   ============================================
   ```

   The window stays open until you press Enter.
5. Open `PlugY.ini` and check the `[LAUNCHING]` section. `Param=` must include
   **`-plugy`** (what else is on that line is up to your setup), for example:

   ```
   Param=-3dfx -plugy
   Library=PlugY.dll
   ```

   Only add `-direct -txt` there if you *always* want the game to load modded text
   files. For switching between normal and testing mode, see below.

6. Start the game with **`Launch-PD2-PlugY.bat`** rather than `PlugY.exe` directly —
   see *Read process memory failed* below. You can point your desktop shortcut at it.

## Testing mode (modpacks)

Single-player packs such as [TDLofCC/PD2-PlugY](https://github.com/TDLofCC/PD2-PlugY)
include a **"testing" modpack** — modded text files in `ProjectD2\data\global\excel`
that add cube recipes for rerolling, duplicating, socketing and so on. The game only
loads them when started with `-direct -txt`, which is what the pack's
**`PlugY (testing)`** shortcut does (`cmd /c start PlugY.exe -direct -txt`).

That shortcut goes through `cmd.exe`, which is 64-bit, so on current Windows 11 it
fails with *Read process memory failed* like any other shortcut. Use these instead:

| to play | double-click |
|---|---|
| normally | `Launch-PD2-PlugY.bat` |
| with the testing modpack | **`Launch-PD2-PlugY (testing).bat`** |

The testing launcher adds `-direct -txt` and then works exactly like the normal one.
The stat-ranges patch works the same in both modes. **TDL's testing modpack is made for
Season 13**, so only use testing mode on the Season 13 rollback. For other
combinations, the launcher passes anything you give it on to the game:

```
Launch-PD2-PlugY.bat -GameArgs "-direct -txt -ns"
```

**Check it worked:** hover a unique or rare. You should see the green ranges,
e.g. `+297% Enhanced Damage [200 - 300]`, plus Max Sockets and the upgrade recipe.
Open the stash and PlugY's page arrows should be along the top.

## After a PD2 update

The PD2 launcher **puts the original `ProjectDiablo.dll` back** whenever it updates,
which silently removes the patch — the stat ranges just disappear again.

**Within a season: double-click `Run-Patch.bat` again.** That's it.

You don't need a new version of the patch for each PD2 update. It doesn't use fixed
addresses — it finds the code to change by searching for byte patterns, so it adapts
to new builds automatically. (Tested on both Season 13 builds, `579987ED` and
`538A77B7`; the `s13p2m2` mirror installs `538A77B7`.) Running it on an already-patched
DLL is harmless; it just says `ALREADY PATCHED`.

**A new season** can change more than addresses. Season 14 rearranges the hook table
this patch edits, so on Season 14 the patch stops with *this version of PD2 isn't
supported yet* and changes nothing. See *Patched on Season 13, now updated to Season 14*.

**On the Season 13 rollback** there shouldn't be any updates: don't open the PD2
launcher. If it updated you anyway, redo the rollback (Season 13 setup, step 2), then
run `Run-Patch.bat`.

## Troubleshooting

**`PlugY: Read process memory failed.` — the game won't start**
Start it with `Launch-PD2-PlugY.bat` instead of `PlugY.exe` or a shortcut to it.

On current Windows 11 builds, `PlugY.exe` fails with this error almost every time
it is started by a 64-bit program — and Explorer, desktop shortcuts and normal
PowerShell are all 64-bit. Started from a 32-bit program it works. The launcher
runs through 32-bit PowerShell, retries automatically if PlugY still fails, and
cleans up the stuck `Game.exe` a failed attempt leaves behind. It isn't caused by
the stat-ranges patch: it happens before PlugY even loads its DLL.

(Measured on one machine: 12 of 12 launches from 64-bit parents failed, 5 of 5 from
a 32-bit parent worked. It started between 17 Sep and 21 Oct 2026.)

**The window flashed open and closed / "it went so fast it didn't do anything"**
Use `Run-Patch.bat` instead of right-click → *Run with PowerShell*. Older versions
of this script closed the window instantly, hiding any error. This version always
waits for Enter.

**`>>> DIABLO II IS RUNNING <<<`**
Close the game fully (check Task Manager for `Game.exe`) and run it again. Windows
locks the DLL while the game is open. Nothing was changed.

**`ALREADY PATCHED` but still no stat ranges**
The DLL is fine — the problem is how the game is launched:
- launch through **`Launch-PD2-PlugY.bat`** (or `PlugY.exe`), not the PD2 launcher or `Game.exe`
- `Param=` in `PlugY.ini` must include `-plugy`

> How `PlugY.exe` builds the game's command line:
> `Game.exe [-w] <arguments given to PlugY.exe> <Param= from PlugY.ini>`.
> So shortcut arguments *are* passed on — they're added in front of `Param=`.
> (`-w` is added when PlugY.ini enables windowed mode.)

**`FAILED: signature ... not found`**
PD2 changed its code enough that the patterns no longer match. Nothing was written,
your DLL is untouched. The patch needs updating for that build.

**`FAILED: this version of PD2 isn't supported yet`**
Your game is on Season 14. The patterns still match, but PD2 now installs 21 extra
hooks ahead of the one this patch redirects, and that combination hasn't been tested
with PlugY. Nothing was changed. PlugY should still run, just without stat ranges. For stat
ranges, roll back to Season 13 (Season 13 setup, step 2) and run `Run-Patch.bat` again.

**`PATCHED BY AN OLDER VERSION - NOT SUPPORTED`**
A version of this script before 3.2.0 patched your Season 14 DLL; those versions didn't
check the season. It's untested, so undo it with `Restore-Original.bat`.

**`ProjectDiablo.dll isn't patched - nothing to restore`** (from `Restore-Original.bat`)
Normal after a PD2 update: the update already put an unpatched DLL in place. Nothing
was changed.

**`FAILED: ProjectDiablo.dll.stock-backup is from a different PD2 version`**
The backup was made on another season or build (e.g. Season 13, and the game is now
Season 14), so `Restore-Original.bat` won't copy it over. Get the original DLL back
with the PD2 launcher, or on the Season 13 rollback, extract the S13 zip again.

**Windows asks "Do you want to allow this app to make changes to your device?"**
That's `Run-Patch.bat` asking for administrator rights, because your game folder needs
them (usually because it's under `Program Files`). Click **Yes**. If you click **No**,
nothing is changed.

## Known quirks

- **Tooltips draw twice.** You'll see a faint second copy behind the augmented
  tooltip, most noticeable on rings. Cosmetic — everything is readable and correct.
- **Occasional hang on the loading screen.** If it happens, end `Game.exe` in Task
  Manager and relaunch. Save often.
- **Stash page names overlap.** PlugY's red `Shared Page N` and PD2's
  `Personal Bank` are printed in the same spot at the bottom of the stash.

All three come from the same cause: PD2 and PlugY each want to draw the
inventory/stash panel, so the patch runs both renderers — PlugY's first, PD2's on top.

*Fixed in 3.0.0:* PlugY's stash page buttons used to be hidden under PD2's top
border. They're now redrawn on top of PD2's frame whenever the stash is open.

## Undo

Double-click **`Restore-Original.bat`** — it copies `ProjectDiablo.dll.stock-backup`
(made automatically when patching) back over `ProjectDiablo.dll`. It first checks that
the DLL is patched and that the backup is from the same PD2 build, so it never puts an
old season's DLL into an updated game.

---

## How it works (for the curious)

`ProjectDiablo.dll` checks the command line for `-plugy` (stored as UTF-16, so a
plain-text search of the file won't find it). When present, PD2 enters a
compatibility mode and **skips installing its runtime hook table** (35 entries in Season 13) —
and one of those hooks is what feeds item descriptions through BH's augmentation.
(Season 14's table has 65 entries, with the panel hook moved to entry 35. That's why
Season 14 isn't supported yet.)

The awkward part is hook **entry 14**: it replaces D2Client's inventory/stash panel
draw (`D2Client+0x99440`), which is the exact function PlugY patches *inside* to add
its stash pages. Both mods want the same function.

The patch:

1. **Gate** — `jne` → `nop nop`, so the hook table installs even under `-plugy`.
2. **New panel code** — 57 bytes, packed into unused `int3` padding in `.text`
   (spread over several small gaps and chained with jumps):
   ```asm
   push esi
   call $+5 / pop eax          ; where am I? (position-independent)
   mov  esi, [eax + d]         ; PD2's module table, slot 0 = D2Client base
   lea  eax, [esi + 0x99440]   ; D2Client's panel draw (PlugY's stash pages live here)
   call eax                    ;   1. run it
   call <PD2 renderer>         ;   2. PD2's renderer (BH augmentation, PD2's frame)
   cmp  dword [esi + uiState+0x19*4], 0   ; stash open?
   jnz  buttons
   pop  esi / ret
   buttons:                    ;   3. PlugY's stash-button routine again, on top
   mov  eax, [esi + 0x99A56]   ;      (the call PlugY redirected - read at run time)
   lea  eax, [esi + eax + 0x99A5A]
   pop  esi / jmp eax
   ```
   Nothing in it is an absolute address, so it still works if Windows loads
   ProjectDiablo.dll or D2Client.dll somewhere other than their usual address.
3. **Redirect** — entry 14 now points at that code instead of PD2's renderer.
4. **Terminate** — the table stops after entry 14; later hooks assume PD2 owns
   the panel and would conflict.

Everything is located by signature at run time:

| what | how it's found |
|---|---|
| `-plugy` gate | `80 3D ?? ?? ?? ?? 00  75 ??  B9 ?? ?? ?? ??  E8`, the match whose table holds the panel hook entry (Season 14 has two matches) |
| hook table address | read from the `B9` operand above |
| panel hook entry | 20-byte record `{0, 0x000C3B18, handler, 1}` |
| module base table | `8B 04 C5 ?? ?? ?? 10` in the hook installer |
| panel-draw target | decoded from the `call` at `D2Client.dll` RVA `0xC3B17` |
| stash-button call | `call` at `D2Client.dll` RVA `0x99A55` (the one PlugY hooks), checked |
| stash-open flag | D2Client's `GetUIState` (`83 F8 26 … 8B 04 85 ???????? C3`), UI index `0x19` |
| code caves | runs of ≥12 `0xCC` bytes in the mapped part of `.text` |

Running it on a DLL patched by an older version upgrades it automatically, starting
from `ProjectDiablo.dll.stock-backup`.

Before writing anything the script checks every site; after writing it re-reads the
file and verifies each change, restoring the backup automatically if anything is off.
No patched `PlugY.dll` is needed — stock PlugY 14.03 works.
