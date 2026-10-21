# Changelog

The script prints its version at the top of the window when it runs.
If you're helping someone, ask which version they have first.

Versioning: **MAJOR** changes what gets written into the DLL, **MINOR** adds
features or usability changes, **PATCH** is fixes only.

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
