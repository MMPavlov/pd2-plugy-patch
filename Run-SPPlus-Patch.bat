@echo off
rem Double-click this file to fix the Single Player Plus mod's "(old)" runes and gems.
rem Keep it next to Patch-SPPlus.ps1 in your Project Diablo 2 folder. Close Diablo II first.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Patch-SPPlus.ps1" %*
