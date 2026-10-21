@echo off
rem Double-click to start PD2 through PlugY in TESTING mode (-direct -txt), so the
rem game loads the modded text files in ProjectD2\data\global\excel (e.g. the
rem "testing" modpack). Replaces the pack's "PlugY (testing)" shortcut, which fails
rem with "Read process memory failed" on current Windows 11. Keep it in your PD2 folder.
set "PS32=%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS32%" set "PS32=powershell.exe"
"%PS32%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Launch-PD2-PlugY.ps1" -Testing %*
