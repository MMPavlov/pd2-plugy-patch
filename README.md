# PD2 + PlugY — get the item stat ranges back

Launch Project Diablo 2 through **PlugY** and picked-up items lose their augmented
description: no green `[min - max]` stat ranges, no `Max Sockets`, no `Base Speed`,
no upgrade recipe. This patch brings all of that back **and keeps PlugY's
multi-page / shared stash working**.

> ⚠ **Single player only.** This modifies the game client. Do not use it on the
> PD2 online realm — restore the original first (see below).

**Version:** printed at the top of the patch window when it runs. See
`CHANGELOG.md` for what changed between versions, and include the version number
when reporting a problem.

## What's in the folder

| file | what it is |
|---|---|
| `Launch-PD2-PlugY.bat` | **double-click this to play** — starts PD2 through PlugY (use it instead of `PlugY.exe`) |
| `Launch-PD2-PlugY.ps1` | the launcher itself (the `.bat` just runs it) |
| `Run-Patch.bat` | **double-click this** to apply the patch |
| `Restore-Original.bat` | double-click to undo and put the original DLL back |
| `Patch-PD2-PlugY.ps1` | the actual patcher (the `.bat` files just run it) |
| `CHANGELOG.md` | what changed in each version |

## Install

1. **Close Diablo II completely.**
2. Copy all the files into your Project Diablo 2 folder — the one that has
   `ProjectDiablo.dll`, `D2Client.dll` and `PlugY.exe` in it.
3. Double-click **`Run-Patch.bat`**.
4. Read the window. You want to see:

   ```
   ============================================
    SUCCESS - patch applied and verified
   ============================================
   ```

   The window stays open until you press Enter.
5. Open `PlugY.ini` and make sure it has:

   ```
   Param=-plugy -3dfx -direct -txt
   Library=PlugY.dll
   ```

6. Start the game with **`Launch-PD2-PlugY.bat`** rather than `PlugY.exe` directly —
   see *Read process memory failed* below. You can point your desktop shortcut at it.

**Check it worked:** hover a unique or rare. You should see the green ranges,
e.g. `+297% Enhanced Damage [200 - 300]`, plus Max Sockets and the upgrade recipe.
Open the stash and PlugY's page arrows should be along the top.

## After every PD2 update

The PD2 launcher **puts the original `ProjectDiablo.dll` back** whenever it updates,
which silently removes the patch — the stat ranges just disappear again.

**Fix: double-click `Run-Patch.bat` again.** That's it.

You don't need a new version of the patch for each PD2 update. It doesn't use fixed
addresses — it finds the code to change by searching for byte patterns, so it adapts
to new builds automatically. (Tested on two different PD2 builds.) Running it on an
already-patched DLL is harmless; it just says `ALREADY PATCHED`.

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
- `PlugY.ini` must contain `Param=-plugy -3dfx -direct -txt`

> `Param=` in `PlugY.ini` is what actually sets the game's command line.
> Editing your desktop shortcut's arguments does nothing — PlugY.exe ignores them.

**`FAILED: signature ... not found`**
PD2 changed its code enough that the patterns no longer match. Nothing was written,
your DLL is untouched. The patch needs updating for that build.

## Known quirks

- **Tooltips draw twice.** You'll see a faint second copy behind the augmented
  tooltip, most noticeable on rings. Cosmetic — everything is readable and correct.
- **Occasional hang on the loading screen.** If it happens, end `Game.exe` in Task
  Manager and relaunch. Save often.
- **PlugY's stash page buttons are partly hidden** under PD2's top border. They still
  work if you click them. Moving them via the `PosX…`/`PosY…` settings in `PlugY.ini`
  doesn't help: PD2's frame covers the whole panel *and* the margin beside it, and
  only its text fields are see-through.

All three come from the same cause: PD2 and PlugY each want to draw the
inventory/stash panel, so the patch runs both renderers — PlugY's first, PD2's on top.

## Undo

Double-click **`Restore-Original.bat`** — it copies `ProjectDiablo.dll.stock-backup`
(made automatically when patching) back over `ProjectDiablo.dll`.

---

## How it works (for the curious)

`ProjectDiablo.dll` checks the command line for `-plugy` (stored as UTF-16, so a
plain-text search of the file won't find it). When present, PD2 enters a
compatibility mode and **skips installing its 35-entry runtime hook table** —
and one of those hooks is what feeds item descriptions through BH's augmentation.

The awkward part is hook **entry 14**: it replaces D2Client's inventory/stash panel
draw (`D2Client+0x99440`), which is the exact function PlugY patches *inside* to add
its stash pages. Both mods want the same function.

The patch, 23 bytes total:

1. **Gate** — `jne` → `nop nop`, so the hook table installs even under `-plugy`.
2. **Thunk** — 17 bytes written into unused `int3` padding:
   ```asm
   mov  eax, [moduleTable]   ; PD2's table, slot 0 = D2Client base
   add  eax, 0x99440         ; D2Client's panel draw (PlugY's stash pages live here)
   call eax                  ; run it
   jmp  <PD2 renderer>       ; then PD2's renderer (BH augmentation)
   ```
3. **Redirect** — entry 14 now points at the thunk instead of PD2's renderer.
4. **Terminate** — the table stops after entry 14; later hooks assume PD2 owns
   the panel and would conflict.

Everything is located by signature at run time:

| what | how it's found |
|---|---|
| `-plugy` gate | `80 3D ?? ?? ?? ?? 00  75 ??  B9 ?? ?? ?? ??  E8` |
| hook table address | read from the `B9` operand above |
| panel hook entry | 20-byte record `{0, 0x000C3B18, handler, 1}` |
| module base table | `8B 04 C5 ?? ?? ?? 10` in the hook installer |
| panel-draw target | decoded from the `call` at `D2Client.dll` RVA `0xC3B17` |
| code cave | first run of ≥17 `0xCC` bytes in `.text` |

Before writing anything the script checks every site; after writing it re-reads the
file and verifies each change, restoring the backup automatically if anything is off.
No patched `PlugY.dll` is needed — stock PlugY 14.03 works.
