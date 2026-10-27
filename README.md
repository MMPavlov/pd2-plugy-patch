# PD2 + PlugY — get the item stat ranges back

Launch Project Diablo 2 through **PlugY** and picked-up items lose their augmented
description: no green `[min - max]` stat ranges, no `Max Sockets`, no `Base Speed`,
no upgrade recipe. This patch brings all of that back **and keeps PlugY's
multi-page / shared stash working**.

> ⚠ **Single player only.** This modifies the game client. Do not use it on the
> PD2 online realm — restore the original first (see below).

> **Season 14 is supported from 4.0.0 on**, as well as the Season 13 rollback.
> See *Which season?* below.

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

PD2 is on Season 14 now. [TDL's PlugY pack](https://github.com/TDLofCC/PD2-PlugY) and
its testing modpack were made for **Season 13**; this patch works on both.

| | Season 14 (current) | Season 13 (rollback) |
|---|---|---|
| PlugY's stash pages ([TDL's pack](https://github.com/TDLofCC/PD2-PlugY)) | yes | yes |
| green stat ranges with PlugY (this patch) | yes, from 4.0.0 | yes |
| TDL's testing modpack | **no**, its files are Season 13's | yes |
| `Launch-PD2-PlugY.bat` (fixes *Read process memory failed*) | yes | yes |
| PD2 launcher | use it as normal, then re-run `Run-Patch.bat` | **never open it** |

Season 14 was tested in game on one install (the Season 14 hotfix build, PlugY 14.03):
stat ranges show, PlugY's stash pages go both ways, and only PD2's tooltip is drawn.
PD2's own new Season 14 stash (its tabs, the cube on the stash page, search) is drawn
too, but hasn't been tested alongside PlugY — use PlugY's page buttons.

From 5.0.0, PlugY's page buttons show only on PD2's **Stash** category (the first one
down the left of the stash). On Gems, Runes and the other categories they're hidden and
can't be clicked, so PlugY's pages no longer turn behind PD2's storage.

### Season 14: PlugY with stat ranges

1. **Diablo II: Lord of Destruction + Project Diablo 2**, updated to Season 14 by the
   PD2 launcher as usual. **Back up `Diablo II\Save`** first.
2. **PlugY.** From [TDLofCC/PD2-PlugY](https://github.com/TDLofCC/PD2-PlugY), download
   `PD2-PlugY-with-Extras.zip` (or `PD2-PlugY.zip` for PlugY on its own). Copy its
   `ProjectD2` and `Save` folders into your `Diablo II` folder, merging with what's there.
3. **This patch.** Download the zip from
   [Releases](https://github.com/MMPavlov/pd2-plugy-patch/releases), copy its files into
   `Diablo II\ProjectD2` and double-click **`Run-Patch.bat`** (details under *Install*
   below).
4. **Play** with **`Launch-PD2-PlugY.bat`**. Point your desktop shortcut at it.
5. **Leave testing mode alone.** Don't use `Launch-PD2-PlugY (testing).bat` or TDL's
   *PlugY (testing)* shortcut, and keep `-direct -txt` out of `Param=` in `PlugY.ini`.
   Testing mode loads the text files in `ProjectD2\data\global\excel`, and TDL's are
   copies of Season 13's cube recipes and unique items, so the game would run on
   Season 13 data. Wait until TDL updates the pack.
6. **After every PD2 update, double-click `Run-Patch.bat` again** — the PD2 launcher
   puts the original `ProjectDiablo.dll` back.

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
- **Get 4.0.0 or newer and run its `Run-Patch.bat`.** Older versions don't handle
  Season 14: before 3.2.0 they patched it wrongly, and 3.2.x refuse it. 4.0.0 also
  repairs a Season 14 DLL that an older version patched.
- **Your old `ProjectDiablo.dll.stock-backup` is the Season 13 DLL.** Don't copy it
  back by hand: a Season 13 DLL in a Season 14 game breaks it. `Run-Patch.bat`
  replaces it with the Season 14 original when it patches; to roll back later you use
  the mirror zip, not this file.

## Install

For a game that already has PD2 (Season 13 or 14) and PlugY:

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

**Fix: double-click `Run-Patch.bat` again.** That's it.

You don't need a new version of the patch for each PD2 update. It doesn't use fixed
addresses — it finds the code to change by searching for byte patterns, so it adapts
to new builds automatically. (Tested on both Season 13 builds, `579987ED` and
`538A77B7` — the `s13p2m2` mirror installs `538A77B7` — and on three Season 14 builds:
open beta, launch and the first hotfix.) Running it on an already-patched DLL is
harmless; it just says `ALREADY PATCHED`.

**A new season** can change more than addresses: Season 14 needed 4.0.0. If a future
season changes the PD2 hooks this patch relies on, it stops with *this version of PD2
isn't supported yet* and changes nothing.

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

**Every stash page button goes to the next page** (Season 14)
That's what versions before 4.0.0 do on Season 14. Run `Run-Patch.bat` from 4.0.0 or
newer; it upgrades the DLL.

**`FAILED: signature ... not found`**
PD2 changed its code enough that the patterns no longer match. Nothing was written,
your DLL is untouched. The patch needs updating for that build.

**`FAILED: this version of PD2 isn't supported yet`**
The game is on a PD2 build whose first hooks differ from the ones this patch works
with on Seasons 13 and 14 — most likely a new season. Nothing was changed. PlugY should
still run, just without stat ranges. The patch needs updating for that build; until
then, for stat ranges with PlugY, roll back to Season 13.

**`PATCHED, BUT THIS PD2 VERSION ISN'T SUPPORTED`**
Another version of this script patched a PD2 build this one doesn't know. Undo it with
`Restore-Original.bat`.

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

- **Tooltips draw twice on Season 13.** You'll see a faint second copy behind the
  augmented tooltip, most noticeable on rings. Cosmetic — everything is readable and
  correct. On Season 14 the patch hides D2's own copy, so you only see PD2's.
- **Occasional hang on the loading screen.** If it happens, end `Game.exe` in Task
  Manager and relaunch. Save often.
- **Stash page names overlap.** PlugY's red `Shared Page N` is printed where PD2 has
  its own text: `Personal Bank` on Season 13, the search field on Season 14.

All three come from the same cause: PD2 and PlugY each want to draw the
inventory/stash panel, so the patch runs both renderers — PlugY's first, PD2's on top.

*Fixed in 3.0.0:* PlugY's stash page buttons used to be hidden under PD2's top
border. They're now redrawn on top of PD2's frame whenever the stash is open (on
Season 14, from 5.0.0, only on PD2's Stash category).

## Undo

Double-click **`Restore-Original.bat`** — it copies `ProjectDiablo.dll.stock-backup`
(made automatically when patching) back over `ProjectDiablo.dll`. It first checks that
the DLL is patched and that the backup is from the same PD2 build, so it never puts an
old season's DLL into an updated game.

---

## How it works (for the curious)

`ProjectDiablo.dll` checks the command line for `-plugy` (stored as UTF-16, so a
plain-text search of the file won't find it). When present, PD2 enters a
compatibility mode and **skips installing its runtime hook table** — and one of those
hooks is what feeds item descriptions through BH's augmentation.

The awkward part is the **panel hook**: it replaces D2Client's inventory/stash panel
draw (`D2Client+0x99440`), which is the exact function PlugY patches *inside* to add
its stash pages. Both mods want the same function.

The patch:

1. **Gate** — `jne` → `nop nop`, so the hook table installs even under `-plugy`.
2. **New panel code** — packed into unused `int3` padding in `.text` (spread over
   several small gaps and chained with jumps):
   ```asm
   push esi
   call $+5 / pop eax          ; where am I? (position-independent)
   mov  esi, [eax + d]         ; PD2's module table, slot 0 = D2Client base
   ; Season 14 only: hide the mouse from D2's own panel draw, so it doesn't print
   ; its plain tooltip next to PD2's
   push [esi + MouseX] / push [esi + MouseY]
   mov  [esi + MouseX], 7FFFh / mov [esi + MouseY], 7FFFh
   lea  eax, [esi + 0x99440]   ; D2Client's panel draw (PlugY's stash pages live here)
   call eax                    ;   1. run it
   pop  [esi + MouseY] / pop [esi + MouseX]    ; (Season 14 only)
   call <PD2 renderer>         ;   2. PD2's renderer (BH augmentation, PD2's frame)
   cmp  dword [esi + uiState+0x19*4], 0   ; stash open?
   jz   done                   ; Season 14 only: ...and on PD2's Stash category?
   call <PD2 IsStashTab>       ;   (PD2's "cmp dword [tab], 9 / setbe al / ret")
   test al, al                 ;
   jnz  buttons
   done: pop esi / ret
   buttons:                    ;   3. PlugY's stash-button routine again, on top
   mov  eax, [esi + 0x99A56]   ;      (the call PlugY redirected - read at run time)
   lea  eax, [esi + eax + 0x99A5A]
   pop  esi / jmp eax
   ```
   On Season 14 a second routine, the **click gate**, takes over the hit test that
   D2Client's stash mouse-down handler calls just before PlugY's button check:
   ```asm
   ; D2Client+0x9B885:  mov eax,ebx / call <hit test>   <- now calls the gate
   ;                    test eax,eax / je ... / mov edi,ebx / call <PlugY's check> / test eax,eax
   call <D2's hit test>        ; as before (D2Client base via the module table)
   test eax, eax / jnz ret     ; D2 takes this click itself
   call <PD2 IsStashTab> / test al, al / jz noplugy
   xor  eax, eax / ret         ; Stash category: on to PlugY's check, as before
   noplugy:
   mov  edi, ebx               ; what D2 does next...
   call <D2's own target of the call PlugY took over>
   add  dword [esp], 1Eh / ret ; ...and carry on after that call, skipping PlugY's check
   ```
   A third, the **draw gate**, does the same for PlugY's own button draw inside step 1
   (drawn under PD2's frame, its top still showed above it on the categories). It
   takes over D2's item-draw call that comes just before the call PlugY took over:
   ```asm
   ; D2Client+0x99A42:  push eax / mov byte [flag],4 / call <item draw>   <- now calls the gate
   ;                    mov [flag],bl / call <PlugY's buttons> / ...
   call <PD2 IsStashTab> / test al, al / jz nobuttons   ; (eax kept around it)
   jmp  <D2's item draw>       ; Stash category: as before, then PlugY's buttons
   nobuttons:
   call <D2's item draw>       ; with the same argument
   mov  [flag], bl             ; what D2 does next...
   call <D2's own target of the call PlugY took over>
   add  dword [esp], 0Bh / ret 4   ; ...and carry on after that call, skipping PlugY's
   ```
   Nothing in any of them is an absolute address, so they still work if Windows loads
   ProjectDiablo.dll or D2Client.dll somewhere other than their usual address.
3. **Redirect and cut the table** — only hooks tested alongside PlugY stay:
   - **Season 13** (35 entries): entries 0–13 stay, entry 14 (the panel hook) now
     points at the code above, and the table ends after it. Later hooks assume PD2
     owns the panel and would conflict.
   - **Season 14** (65 entries): entries 0–13 are the same as Season 13's, then 21 new
     hooks (PD2's rewrite of the party portraits), then the panel hook at entry 35.
     The panel record is moved up to entry 13, the click and draw gates go in entries
     14 and 15 (relative-call records on `D2Client+0x9B888` and `+0x99A4B`, like PD2's
     own), and the table ends after them. Entry 13 is left out because PlugY hooks
     the same call (`D2Client+0x4437C`): on Season 14 PD2 installs after PlugY, and its
     Season 14 version of that hook made every stash page button go to the next page.

Everything is located by signature at run time:

| what | how it's found |
|---|---|
| `-plugy` gate | `80 3D ?? ?? ?? ?? 00  75 ??  B9 ?? ?? ?? ??  E8`, the match whose table holds the panel hook entry (Season 14 has two matches) |
| hook table address | read from the `B9` operand above |
| panel hook entry | 20-byte record `{0, 0x000C3B18, handler, 1}`; on Season 14 the last one in the table is PD2's original |
| first 14 hooks | checked against Season 13's list — anything else is refused |
| module base table | `8B 04 C5 ?? ?? ?? 10` inside the hook installer the gate calls (Season 14 has other matches earlier in the file) |
| panel-draw target | decoded from the `call` at `D2Client.dll` RVA `0xC3B17` |
| stash-button call | `call` at `D2Client.dll` RVA `0x99A55` (the one PlugY hooks), checked |
| stash-open flag | D2Client's `GetUIState` (`83 F8 26 … 8B 04 85 ???????? C3`), UI index `0x19` |
| mouse position | the `mov eax,[MouseX]` / `mov ecx,[MouseY]` at the start of the panel draw (Season 14) |
| Stash-category check | PD2's `push 19h / call GetUIState / … / call IsStashTab / …`, its callee checked to be `cmp dword [tab], 9 / setbe al / ret` (Season 14) |
| stash click site | `mov eax,ebx / call` at `D2Client.dll` RVA `0x9B885`, then `je` to `mov edi,ebx / call` at `0x9B8A3` (PlugY's mouse-down check), checked (Season 14) |
| stash draw site | `push eax / mov byte [flag],4 / call / mov [flag],bl` at `D2Client.dll` RVA `0x99A42`, right before the stash-button call, checked (Season 14) |
| code caves | runs of `0xCC` at least as long as the longest instruction + a 5-byte jump, in the mapped part of `.text` |

Running it on a DLL patched by an older version upgrades it automatically, starting
from `ProjectDiablo.dll.stock-backup`.

Before writing anything the script checks every site; after writing it re-reads the
file and verifies each change, restoring the backup automatically if anything is off.
No patched `PlugY.dll` is needed — stock PlugY 14.03 works.
