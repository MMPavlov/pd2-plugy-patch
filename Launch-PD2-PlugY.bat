@echo off
rem Double-click to start PD2 through PlugY. Keep it in your PD2 folder.
rem PlugY.exe must be started from a 32-bit process on current Windows 11, otherwise
rem it fails with "Read process memory failed" - so this uses 32-bit PowerShell.
set "PS32=%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS32%" set "PS32=powershell.exe"
"%PS32%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Launch-PD2-PlugY.ps1" %*
