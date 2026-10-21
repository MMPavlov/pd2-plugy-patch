<#
    Launch-PD2-PlugY.ps1

    Starts Project Diablo 2 through PlugY, avoiding
    "PlugY: Read process memory failed."

    On current Windows 11 builds, PlugY.exe fails with that error (almost always)
    when it is started by a 64-bit program - Explorer, a desktop shortcut, 64-bit
    PowerShell - and works when its parent is 32-bit. So this launcher re-runs
    itself under 32-bit PowerShell before starting PlugY, and as a safety net
    retries if PlugY still reports the error.

    USAGE
      Double-click Launch-PD2-PlugY.bat, or:
      .\Launch-PD2-PlugY.ps1 [-Path <PD2 folder>] [-MaxAttempts 10]
#>

[CmdletBinding()]
param([string]$Path, [int]$MaxAttempts = 10, [switch]$NoPause)

$ErrorActionPreference = "Stop"
$VERSION = "3.0.0"

# PlugY.exe must be started from a 32-bit parent (see header). If we're running as
# 64-bit PowerShell, hand over to the 32-bit one and pass the result straight back.
if ([Environment]::Is64BitProcess) {
    $ps32 = Join-Path $env:SystemRoot "SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $ps32) {
        $relaunch = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $PSCommandPath, "-MaxAttempts", $MaxAttempts)
        if ($Path)    { $relaunch += @("-Path", $Path) }
        if ($NoPause) { $relaunch += "-NoPause" }
        & $ps32 @relaunch
        exit $LASTEXITCODE
    }
}

if (-not $Path) { $Path = $PSScriptRoot }
if (-not $Path) { $Path = (Get-Location).Path }
$plugyExe = Join-Path $Path "PlugY.exe"

function Stop-Here([int]$code) {
    if (-not $NoPause) {
        Write-Host ""
        Write-Host "Press Enter to close..." -ForegroundColor DarkGray
        try { [void](Read-Host) } catch { Start-Sleep -Seconds 20 }
    }
    exit $code
}

Add-Type @"
using System; using System.Text; using System.Runtime.InteropServices; using System.Collections.Generic;
public static class Win {
  delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Auto)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Auto)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  // Returns the text of a visible message box owned by the given process, or null.
  public static string DialogText(int pid) {
    string found = null;
    EnumWindows((h, l) => {
      uint p; GetWindowThreadProcessId(h, out p);
      if (p != (uint)pid || !IsWindowVisible(h)) return true;
      var cls = new StringBuilder(64); GetClassName(h, cls, 64);
      if (cls.ToString() != "#32770") return true;
      var text = new StringBuilder();
      EnumChildWindows(h, (c, l2) => {
        var cc = new StringBuilder(64); GetClassName(c, cc, 64);
        if (cc.ToString() == "Static") { var t = new StringBuilder(512); GetWindowText(c, t, 512); if (t.Length > 0) text.Append(t.ToString()).Append(' '); }
        return true; }, IntPtr.Zero);
      found = text.ToString().Trim(); return false;
    }, IntPtr.Zero);
    return found;
  }
}
"@

function Get-StuckGames {
    # a Game.exe with no window is a leftover from a failed PlugY attempt
    Get-Process -Name "Game" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -eq [IntPtr]::Zero }
}
function Clear-Attempt {
    Get-Process -Name "PlugY" -ErrorAction SilentlyContinue | ForEach-Object { try { Stop-Process -Id $_.Id -Force -ErrorAction Stop } catch {} }
    Start-Sleep -Milliseconds 700
    Get-StuckGames | ForEach-Object { try { Stop-Process -Id $_.Id -Force -ErrorAction Stop } catch {} }
    Start-Sleep -Milliseconds 700
}

Write-Host ""
Write-Host "PD2 + PlugY launcher  v$VERSION" -ForegroundColor Cyan
Write-Host "------------------------------"

if (-not (Test-Path $plugyExe)) {
    Write-Host "  PlugY.exe not found in '$Path'." -ForegroundColor Red
    Write-Host "  Put this launcher in your Project Diablo 2 folder." -ForegroundColor Red
    Stop-Here 1
}
$running = Get-Process -Name "Game" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero }
if ($running) {
    Write-Host "  Diablo II is already running." -ForegroundColor Yellow
    Stop-Here 0
}
if ((Get-StuckGames) -or (Get-Process -Name "PlugY" -ErrorAction SilentlyContinue)) {
    Write-Host "  Cleaning up leftovers from an earlier failed launch..." -ForegroundColor DarkGray
    Clear-Attempt
}

for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    Write-Host ("  attempt {0}/{1}... " -f $attempt, $MaxAttempts) -NoNewline
    $p = Start-Process -FilePath $plugyExe -WorkingDirectory $Path -PassThru

    $result = $null; $msg = $null
    $deadline = (Get-Date).AddSeconds(60)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 500
        $p.Refresh()
        if ($p.HasExited) { $result = "exited"; break }
        $msg = [Win]::DialogText($p.Id)
        if ($msg) { $result = "dialog"; break }
    }

    if ($result -eq "exited") {
        # PlugY exits after injecting successfully; confirm the game window appears
        $ok = $false
        for ($i = 0; $i -lt 40; $i++) {
            if (Get-Process -Name "Game" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero }) { $ok = $true; break }
            Start-Sleep -Milliseconds 500
        }
        if ($ok) {
            Write-Host "started." -ForegroundColor Green
            if ($attempt -gt 1) { Write-Host ("  (PlugY needed {0} attempts)" -f $attempt) -ForegroundColor DarkGray }
            exit 0
        }
        Write-Host "PlugY closed but no game window appeared." -ForegroundColor Yellow
        Clear-Attempt
        continue
    }

    if ($result -eq "dialog" -and $msg -match "Read process memory failed") {
        Write-Host "PlugY: read process memory failed - retrying" -ForegroundColor DarkYellow
        Clear-Attempt
        continue
    }

    if ($result -eq "dialog") {
        # a different PlugY error - don't hide it, the user needs to read it
        Write-Host "PlugY reported an error:" -ForegroundColor Red
        Write-Host "    $msg" -ForegroundColor Red
        Write-Host "  (left on screen - this one isn't fixed by retrying)" -ForegroundColor Red
        Stop-Here 1
    }

    Write-Host "no response from PlugY after 60s" -ForegroundColor Yellow
    Clear-Attempt
}

Write-Host ""
Write-Host "  Gave up after $MaxAttempts attempts." -ForegroundColor Red
Write-Host "  Rebooting usually changes the memory layout enough for it to work." -ForegroundColor Red
Stop-Here 1
