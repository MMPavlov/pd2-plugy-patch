# Changelog

The script prints its version at the top of the window when it runs.
If you're helping someone, ask which version they have first.

Versioning: **MAJOR** changes what gets written into the DLL, **MINOR** adds
features or usability changes, **PATCH** is fixes only.

## 4.0.0 — 2026-10-27

Major version: what's written into `ProjectDiablo.dll` on Season 14 changed. Season 13
output is byte-identical to 3.1.0–3.2.1.

### Added
- **Season 14 support.** Stat ranges with PlugY's stash pages on Season 14. Tested in
  game on the Season 14 hotfix build: ranges show, pages go both ways, one tooltip.
  - Season 14's hook table has 65 entries. The first 14 are the same as Season 13's,
    then come 21 new hooks (PD2's rewrite of the party portraits), then the panel
    hook at entry 35. The patch moves the panel record up and ends the table there,
    so PD2 installs only hooks that were tested with PlugY.
  - **PD2's entry 13 is left out on Season 14.** It hooks the same D2Client call as
    PlugY (`0x4437C`, PlugY's `/players` default). On Season 13, D2Win loaded
    `ProjectDiablo.dll` itself; on Season 14 it doesn't, so PD2 now installs after
    PlugY and wins that call. Its Season 14 version wraps the UI draw with the new
    stash's logic, and with it every PlugY stash page button went to the next page.
  - **No more second tooltip on Season 14.** D2's own panel draw (which the patch
    runs so PlugY's pages appear) printed D2's plain tooltip next to PD2's augmented
    one; on Season 13 they line up, on Season 14 they don't. On Season 14 the panel
    code now moves D2's mouse position off-screen during that draw and puts it back
    before PD2's renderer. The mouse variables are read from the panel draw's own
    code, not hard-coded.
- Only the first 14 hooks of a known season are accepted. A build whose hooks differ
  gets *this version of PD2 isn't supported yet* and nothing is written.

### Fixed
- **PD2's module table is now found inside the hook installer.** On Season 14 the
  first match for its pattern in the file points somewhere else, so any 3.x patch on
  Season 14 read the wrong table and couldn't have worked.
- A Season 14 DLL patched by 3.x is upgraded automatically from the backup.
- The code-cave packer skips caves too small for the next instruction, and the cave
  size follows the longest instruction.

### Changed
- README: Season 14 setup now includes the patch; the "Which season?" table and
  troubleshooting are updated.
- Launcher reports 4.0.0 too (no functional change).

### Checked
- 55 offline checks across Season 13 (`579987ED`, `538A77B7`) and Season 14 (open
  beta, launch, hotfix): fresh patch, re-run, restore, upgrades from 2.2.0, 3.1.0 and
  the pre-release 4.0.0 builds, a simulated future season, and Restore refusing a
  backup from another season. An independent disassembler check confirms the hooks
  PD2 will install and the injected code on each build.
- The Season 13 rollback zip on the mirror was re-uploaded on 22 Oct: same game files,
  minus five settings files, so extracting it no longer resets your settings.

## 3.2.1 — 2026-10-24

Season 14 is live. Fixes for people whose game the PD2 launcher just updated.

### Fixed
- **An S14 DLL patched by an older version was reported as unpatched.** Versions
  before 3.2.0 didn't check the season, and the v3.1.0 README said to re-run
  `Run-Patch.bat` after every update, so some Season 14 DLLs got patched. Season 14
  has a second match for the `-plugy` gate pattern. Once the real gate was patched,
  3.2.0 found the other one and said *isn't supported yet ... Nothing was changed*
  (with "entry -1"), without mentioning the DLL was already patched. The gate is now
  the match whose table holds the panel hook entry. On such a DLL the patcher says
  *PATCHED BY AN OLDER VERSION - NOT SUPPORTED* and points to `Restore-Original.bat`.
- **The season check now runs before "already patched"**, so an old patch on an
  unsupported build is never reported as `ALREADY PATCHED`.
- **`Restore-Original.bat` could put a Season 13 DLL into a Season 14 game.** After
  an update, `ProjectDiablo.dll.stock-backup` is still the previous season's DLL, and
  the old restore copied it over blindly. It now restores only when the DLL is patched
  and the backup is from the same build. Otherwise it says *nothing to restore* or
  *from a different PD2 version*, and changes nothing.
- The *not supported* message no longer says "to keep using PlugY": PlugY doesn't
  need this patch, it's the stat ranges that do.

### Changed
- README: **Which season?** comparison, plus a Season 14 setup (PlugY without stat
  ranges, no testing modpack) next to the Season 13 rollback, and a section for
  people patched on Season 13 who've just been updated to Season 14.
- Launcher reports 3.2.1 too (no functional change).

### Checked
- Season 14 live (`ProjectDiablo.dll` 5,252,096 bytes) has the same hook table layout
  as the open beta: 65 entries, panel hook at 35. Refused, nothing written.
- `D2Client.dll` in Season 14 is byte-identical to Season 13's.
- Season 13: output byte-identical to 3.1.0 and 3.2.0 on both builds.

## 3.2.0 — 2026-10-21

Fixes found while checking a complete setup: PD2 rolled back to Season 13 with the
`s13p2m2` mirror, plus TDL's PlugY pack, plus this patch.

### Added
- **Asks for administrator rights when the game folder needs them** (e.g. under
  `Program Files`). `Run-Patch.bat` and `Restore-Original.bat` first check they can
  write to the folder. If they can't, they relaunch elevated: click *Yes* and the patch
  carries on in a new window. Click *No* and nothing is changed.
- **Stops on PD2 builds whose hook table is laid out differently from Season 13.**
  The Season 14 open beta still matches every signature, but adds 21 D2Client hooks
  ahead of the panel hook (entry 35 instead of 14). The patch switches off everything
  after the panel hook, so on Season 14 those new hooks would stay on alongside PlugY,
  untested. It now says *this version of PD2 isn't supported yet* and changes nothing.
- README: **Complete setup from scratch**: PD2, then the Season 13 rollback, then TDL's
  PlugY pack, then this patch, in that order, plus the two TDL tips that don't apply.

### Fixed
- **The window closed instantly on errors the scripts didn't expect**, such as
  *access denied* in a `Program Files` folder or the DLL being in use by another
  program. The raw PowerShell error flashed past unread. Both the patcher and the
  launcher now show `FAILED: <reason>` and wait for Enter.

### Checked
- The `s13p2m2` mirror's `ProjectDiablo.dll` is byte-identical to `538A77B7`, one of
  the two tested builds, and its `D2Client.dll` matches. Fresh patch, re-run, restore
  and upgrade from 2.2.0 all pass on it.
- TDL's zip doesn't overlap any file the mirror installs, and its `PlugY.ini` already
  has `Param=-3dfx -plugy`.
- No change to what's written into `ProjectDiablo.dll`. The output is byte-identical to
  3.1.0's on both Season 13 builds.

## 3.1.0 — 2026-10-21

Testing mode, for single-player packs such as
[TDLofCC/PD2-PlugY](https://github.com/TDLofCC/PD2-PlugY).

### Added
- **`Launch-PD2-PlugY (testing).bat`** — starts the game with `-direct -txt` so it
  loads the "testing" modpack's text files. Replaces the pack's `PlugY (testing)`
  shortcut, which runs `cmd /c start PlugY.exe -direct -txt` and so fails with
  *Read process memory failed* on current Windows 11 (`cmd.exe` is 64-bit).
- Launcher options **`-Testing`** and **`-GameArgs "<args>"`**, passed on to
  `PlugY.exe` and from there to the game; carried across the 32-bit hand-over.

### Fixed
- **README wrongly said shortcut arguments are ignored by `PlugY.exe`.** They aren't:
  it builds `Game.exe [-w] <its own arguments> <Param=>` (confirmed from its code).
- **README and patcher told everyone to use `Param=-plugy -3dfx -direct -txt`.**
  Only `-plugy` is needed. Forcing `-direct -txt` would make a testing pack's
  *normal* mode load the testing modpack.

### Checked
- TDL's `PlugY.dll` hooks the same D2Client offsets as the one this was developed
  with (including `0x99A56`, used by the stash-button fix). Static check only.
- No change to what's written into `ProjectDiablo.dll` (still the 3.0.0 code).

## 3.0.0 — 2026-10-21

Major version: the code written into `ProjectDiablo.dll` changed.

### Fixed
- **PlugY's stash page buttons are now visible.** They were hidden under PD2's
  top border because PD2's frame was drawn over them. The new panel code calls
  PlugY's button routine once more *after* PD2's renderer, only while the stash is
  open (checked via D2Client's UI state), so the buttons land on top. Tested:
  buttons visible and clickable, one click = one page, nothing drawn over the
  inventory or Horadric Cube, stat ranges unaffected.
- **Survives DLL relocation.** The old thunk used PD2's module table by absolute
  address, which would break if Windows loaded `ProjectDiablo.dll` elsewhere. The
  new code is position-independent (`call $+5 / pop`).

### Changed
- The injected code is now 57 bytes, packed into several small `int3` gaps and
  chained with jumps, instead of needing one 17-byte gap.
- **Automatic upgrade:** run on a DLL patched by 2.x, it re-patches from
  `ProjectDiablo.dll.stock-backup`, so updating is just running `Run-Patch.bat`.
- Signature search is much faster (`[Array]::IndexOf` anchoring).
- Launcher reports 3.0.0 too (no functional change).

## 2.2.0 — 2026-10-21

### Added
- **`Launch-PD2-PlugY.bat` / `.ps1`** — starts the game and fixes
  `PlugY: Read process memory failed.`, which suddenly stopped the game launching.
  `PlugY.exe` now fails almost every time it's started by a 64-bit program (Explorer,
  shortcuts, normal PowerShell) and works when started by a 32-bit one. The launcher
  runs through 32-bit PowerShell — and relaunches itself that way if started from
  64-bit — retries if PlugY still fails, cleans up the stuck `Game.exe` a failed
  attempt leaves behind, and shows any *other* PlugY error instead of hiding it.
  Measured: 12/12 launches failed from 64-bit parents, 5/5 worked from 32-bit.

### Changed
- README: launch with the launcher instead of `PlugY.exe`; new troubleshooting entry;
  hidden stash page buttons listed under known quirks.

### Investigated, not changed
- Moving PlugY's stash page buttons out from under PD2's top border via `PlugY.ini`
  doesn't work: PD2's frame paints the whole panel and the margin beside it.
  Fixing it needs PlugY's buttons drawn after PD2's frame, i.e. a DLL change.

## 2.1.0 — 2026-10-11

Usability fixes from the first round of friends trying it.

### Fixed
- **Window closed instantly** when run with right-click → *Run with PowerShell*,
  hiding every message. An error such as "Diablo II is running" flashed past unread,
  so it looked like nothing happened. The window now always waits for Enter.
- **False failure on re-run.** Running the script on an already-patched DLL
  reported `FAILED: signature 1 not found - PD2 changed too much` instead of
  `ALREADY PATCHED`. The gate signature required the unpatched bytes `75 ??` and
  never matched the patched `90 90`. Both are now recognised.
- **Output changed between runs.** On a re-run the code-cave search skipped the cave
  the thunk already occupied and reported a different address. Already-patched
  detection now happens first, before anything else is searched.

### Added
- `Run-Patch.bat` and `Restore-Original.bat` — double-click launchers that run with
  `-ExecutionPolicy Bypass`, so no PowerShell knowledge is needed.
- Verification after writing: the DLL is re-read and every change checked. If
  anything doesn't match, the backup is restored automatically.
- Version number shown in the banner.
- `-NoPause` switch for scripted/unattended runs.

### Changed
- "Diablo II is running" is now a large, unmissable message.
- README rewritten for the signature-based approach, with a troubleshooting section.

## 2.0.0 — 2026-08-06

### Changed
- **No longer locked to one PD2 build.** Every address is located by byte signature
  at run time instead of fixed offsets, so the patch survives PD2 updates. Re-run it
  after an update — no new version needed.
- The D2Client panel-draw address is decoded from `D2Client.dll` rather than assumed.
- Removed the SHA256 check that made 1.0.0 refuse any other build.

Tested on PD2 builds `579987ED…` (4,313,088 bytes) and `538A77B7…` (4,312,576 bytes).

## 1.0.0 — 2026-08-06

- First release. Restores BH item stat ranges under PlugY while keeping PlugY's stash,
  by installing PD2's hook table under `-plugy` and routing the panel hook through a
  thunk that runs both renderers.
- Hard-coded offsets, locked to `ProjectDiablo.dll` SHA256 `579987ED…`
  (Season 13 "Betrayal"). Refused to run on any other build, so it broke on the first
  PD2 update.
