@echo off
rem Double-click this to undo Patch-SPPlus.ps1 and restore the mod's original pd2data.mpq.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Patch-SPPlus.ps1" -Restore
