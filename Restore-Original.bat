@echo off
rem Double-click this to undo the patch and restore the original ProjectDiablo.dll.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Patch-PD2-PlugY.ps1" -Restore
