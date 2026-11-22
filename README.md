# PD2 + PlugY — get the item stat ranges back

Launch Project Diablo 2 through **PlugY** and picked-up items lose their augmented
description: no green `[min - max]` stat ranges, no `Max Sockets`, no `Base Speed`,
no upgrade recipe. This patch brings all of that back **and keeps PlugY's
multi-page / shared stash working**. From 6.0.0 PD2's own stash categories (Gems,
Runes, …) work again too.

> **Single player only.** This changes the game client. Don't use it on the PD2 online
> realm — restore the original first (see *Undo*).

> **Season 14 is supported from 4.0.0 on**, as well as the Season 13 rollback. Details
> and complete setups from scratch: [docs/seasons.md](docs/seasons.md).

**Version:** printed at the top of the patch window. See `CHANGELOG.md` for what
changed, and include the version when reporting a problem.

## Install

For a game that already has PD2 (either season) and PlugY:

1. **Close Diablo II.** Back up `Diablo II\Save` the first time.
2. Copy these files into your ProjectD2 folder — the one with `ProjectDiablo.dll`,
   `D2Client.dll` and `PlugY.exe` in it.
3. Double-click **`Run-Patch.bat`**. If the game is under `Program Files`, Windows asks
   for permission — click **Yes**. Read the window; you want:

   ```
   ============================================
    SUCCESS - patch applied and verified
   ============================================
   ```

4. **Play with `Launch-PD2-PlugY.bat`**, not `PlugY.exe` or the PD2 launcher. Point your
   desktop shortcut at it.
5. Hover a unique or rare: green `[min - max]` ranges, Max Sockets, the upgrade recipe.
   Open the stash: PlugY's page buttons are along the top.

`Param=` in `PlugY.ini` should include `-plugy`. From 6.1.0 the launcher adds it when
it's missing there, but `PlugY.exe` started any other way still needs it.

Starting from nothing (PD2, then the Season 13 rollback, then TDL's pack):
[docs/seasons.md](docs/seasons.md). Testing mode:
[docs/testing-mode.md](docs/testing-mode.md).

## After a PD2 update

The PD2 launcher puts the original `ProjectDiablo.dll` back, so the patch is gone and
the ranges disappear. **Double-click `Run-Patch.bat` again** — that's the whole fix.
You don't need a new version for a PD2 update: nothing is hardcoded, every address is
found by byte pattern (two Season 13 builds, six Season 14 builds and the Single Player
Plus 14.0.x DLLs so far). Running it twice is harmless.

A new season can change more than addresses — Season 14 needed 4.0.0. If the hooks this
patch relies on change, it stops with *this version of PD2 isn't supported yet* and
changes nothing.

With the **Single Player Plus mod**, the update also replaces the mod's files, and
characters holding the mod's items fail with *generic bad file*: put the mod back, then
run `Run-Patch.bat` and `Run-SPPlus-Patch.bat` —
[docs/single-player-plus.md](docs/single-player-plus.md).

## If something goes wrong

| what you see | do this |
|---|---|
| `PlugY: Read process memory failed.` | start with `Launch-PD2-PlugY.bat`, not `PlugY.exe` or a shortcut |
| box titled *PlugY*, `EXCEPTION_ACCESS_VIOLATION` | run `PD2-Diag.bat` and send the report; the patch isn't involved |
| `ALREADY PATCHED` but still no ranges | launch with `Launch-PD2-PlugY.bat`, and `Param=` needs `-plugy` |
| every stash page button goes to the next page | patch older than 4.0.0 — run the current `Run-Patch.bat` |
| `FAILED: signature ... not found` / *isn't supported yet* | PD2 changed; nothing was written, wait for a patch update |
| `>>> DIABLO II IS RUNNING <<<` | close `Game.exe` and run it again; nothing was changed |

Every other message, and the three known cosmetic quirks:
[docs/troubleshooting.md](docs/troubleshooting.md).

## Undo

Double-click **`Restore-Original.bat`**. It copies `ProjectDiablo.dll.stock-backup`
(made automatically when patching) back over `ProjectDiablo.dll`, after checking that
the DLL is patched and the backup is from the same PD2 build — so it never puts an old
season's DLL into an updated game.

## What's in the folder

| file | what it is |
|---|---|
| `Launch-PD2-PlugY.bat` | **double-click this to play** — starts PD2 through PlugY (use it instead of `PlugY.exe`) |
| `Launch-PD2-PlugY (testing).bat` | same, in **testing mode** (`-direct -txt`, loads the testing modpack) |
| `Launch-PD2-PlugY.ps1` | the launcher itself (the `.bat` files just run it) |
| `Run-Patch.bat` | **double-click this** to apply the patch |
| `Restore-Original.bat` | double-click to undo and put the original DLL back |
| `Patch-PD2-PlugY.ps1` | the actual patcher |
| `PD2-Diag.bat` / `PD2-Diag.ps1` | report on why the game won't start through PlugY; changes nothing |
| `Run-SPPlus-Patch.bat` / `Restore-SPPlus.bat` | *Single Player Plus mod only:* double-click to fix / undo its `(old)` runes and gems |
| `Patch-SPPlus.ps1` | that fix itself; separate from the PlugY patch |
| `docs/` | [seasons](docs/seasons.md), [testing mode](docs/testing-mode.md), [Single Player Plus](docs/single-player-plus.md), [troubleshooting](docs/troubleshooting.md), [how it works](docs/how-it-works.md) |
| `CHANGELOG.md` | what changed in each version (and `CHANGELOG-SPPlus.md` for the mod fix) |

## More

- **[How it works](docs/how-it-works.md)** — the hook table, the injected code, and the
  full signature list, for the curious.
- **[Troubleshooting](docs/troubleshooting.md)** — every message, and *Known quirks*.
- **[Seasons and complete setups](docs/seasons.md)** — Season 13 rollback included.
- **[CHANGELOG.md](CHANGELOG.md)** — release history.
