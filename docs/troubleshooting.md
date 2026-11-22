# Troubleshooting

Back to the [README](../README.md).

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

If the launcher still gives up, run `PD2-Diag.bat` (see the next entry). It shows where
`D2gfx.dll` loaded and what took its usual place.

**`EXCEPTION_ACCESS_VIOLATION` in a box titled *PlugY* — the game won't start**
The box comes from `PlugY.exe`, before PlugY is in the game. `PlugY.exe` starts
`Game.exe` under its control, waits for the game's `D2gfx.dll` and checks that it's the
1.13c file it knows. Then it loads PlugY and lets go. The box means that check didn't
pass: either `D2gfx.dll` is a different file, or something (security software, for
example) kept `PlugY.exe` from reading the game's memory. So the game ran on without
PlugY, still under `PlugY.exe`'s control, and crashed. Neither the patch nor the launcher
causes it, and neither `PlugY.log` nor D2's own log records it.

To find out which it is, close the game and double-click **`PD2-Diag.bat`**. It writes
`PD2-diag.txt` and opens it; send that to whoever is helping you. The report starts the
game three times the way `PlugY.exe` does and says what happened to `D2gfx.dll`, and
lists the game's files against PD2's own file list. Apart from writing the report, it
changes nothing.

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
- the game needs `-plugy`: `Launch-PD2-PlugY.bat` (6.1.0 or newer) adds it, otherwise
  `Param=` in `PlugY.ini` must include it

> How `PlugY.exe` builds the game's command line:
> `Game.exe [-w] <arguments given to PlugY.exe> <Param= from PlugY.ini>`.
> So shortcut arguments *are* passed on — they're added in front of `Param=`.
> (`-w` is added when PlugY.ini enables windowed mode.)

**Every stash page button goes to the next page** (Season 14)
That's what versions before 4.0.0 do on Season 14. Run `Run-Patch.bat` from 4.0.0 or
newer; it upgrades the DLL.

**PD2's stash page tabs (P, I–IX) show behind PlugY's page buttons** (Season 14)
From 6.0.0 the patch hides them under PlugY. If you still see them, either:
- the DLL was patched by an older version: run `Run-Patch.bat` from the current
  release. It says *patched by an older version of this script - upgrading* and fixes it.
- the game was started without `-plugy`, so PD2 doesn't know PlugY is there. That also
  sends gems and runes into PD2's own `pd2_shared.stash` instead of `Save\shared.stash`.
  Start the game with `Launch-PD2-PlugY.bat` (6.1.0 or newer adds `-plugy` itself), or add
  `-plugy` to `Param=` in `PlugY.ini`.

**`Unable to enter game, generic bad file`** (Single Player Plus mod, after a PD2 update)
The PD2 launcher's update replaced the mod's `ProjectDiablo.dll`, `BH.dll` and
`pd2data.mpq` with PD2's own. Plain PD2 doesn't have the mod's own items (Orb of
Extraction; Exalted, Mythic and Divine Orbs; Eternal Coin; Charsi's and Gheed's Curious
Boxes; Uncut Pristine Jewel). So it can't load a character who holds one in their
inventory or stash. If one is on a PlugY shared stash page, no character loads, because
they all load that page. The game's log (`ProjectD2\D2yymmdd.txt`, e.g. `D2261104.txt`)
says `Error Loading:<character>`. The saves themselves are fine:
1. Close the game and the PD2 launcher.
2. Put the mod's three files back, from
   [its release](https://github.com/Lukaszpg/PD2-Single-Player-Plus-mod/releases) or with
   its own launcher.
3. Run `Run-Patch.bat`, then `Run-SPPlus-Patch.bat`.
4. **Testing mode** only: if you tried to enter a game in between, the game recompiled the
   `.bin` files in `ProjectD2\data\global\excel` from PD2's data. Move those `.bin` files
   out of that folder (the `….stock-backup` files can stay), and it rebuilds them from
   the mod's data the next time you enter a game.

**Testing mode: a Season 14 runeword is missing, e.g. Jealousy**
The item shows without its runeword in testing mode, and with it in normal mode. In
testing mode the game takes its tables from `ProjectD2\data\global\excel` first: the
`.txt` files there replace the game's own, and the compiled `.bin` files there are used
instead of the game's data. If those came from older data, anything newer is missing.
Jealousy is an example: in Season 13's runeword table it's an unfinished placeholder,
and Season 14 made it a javelin runeword. TDL's testing modpack, and any `.bin` files the
game compiled while you played testing mode on Season 13 or an older version of a mod,
are older data. Until that folder is cleaned up, don't play a Season 14 character in
testing mode.
1. Close the game and back up `Diablo II\Save`.
2. Move the `.bin` files out of `ProjectD2\data\global\excel`, and any `.txt` files you
   didn't put there for the current season (the `….stock-backup` files can stay).
3. Start in testing mode. The game rebuilds the `.bin` files from the current data the
   next time you enter a game.

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

*Fixed in 6.0.0* (Season 14): you couldn't put gems, runes or other materials into
PD2's stash categories, and they were always empty. With PlugY, PD2 switches its
material storage off, and the patch had left PD2's own stash clicks out (they replace
the D2 ones PlugY's page buttons hook into). Now the categories have both, and keep
their contents in `Save\shared.stash`.
