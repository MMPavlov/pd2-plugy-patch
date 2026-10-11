# Changelog

The script prints its version at the top of the window when it runs.
If you're helping someone, ask which version they have first.

Versioning: **MAJOR** changes what gets written into the DLL, **MINOR** adds
features or usability changes, **PATCH** is fixes only.

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
