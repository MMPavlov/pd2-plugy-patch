@echo off
rem Double-click this file for a report on why PlugY won't start (PD2-diag.txt).
rem Keep it next to PD2-Diag.ps1 in your Project Diablo 2 folder. Close Diablo II first.
rem It changes nothing; it starts the game briefly and closes it again.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0PD2-Diag.ps1" %*
echo.
pause
