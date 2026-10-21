<#
    Patch-PD2-PlugY.ps1   v2.2.0   (version-independent)

    Restores Project Diablo 2's augmented item descriptions (green [min - max]
    stat ranges, Max Sockets, Base Speed, upgrade recipe) when launching through
    PlugY, while keeping PlugY's multi-page / shared stash working.

    Nothing is hardcoded to a particular ProjectDiablo.dll build. Every address is
    located by byte signature at run time, so this keeps working across PD2 updates.
    If PD2 ever restructures the code so a signature no longer matches, the script
    stops and tells you which one - it never writes a partial patch.

    SINGLE PLAYER ONLY. Do not use on the PD2 online realm.

    EASIEST WAY TO RUN IT
      Double-click Run-Patch.bat (next to this file).

    OR, from a PowerShell window:
      .\Patch-PD2-PlugY.ps1              # patch (re-run after every PD2 update)
      .\Patch-PD2-PlugY.ps1 -Restore     # undo
      .\Patch-PD2-PlugY.ps1 -Path "D:\PD2"
#>

[CmdletBinding()]
param([string]$Path, [switch]$Restore, [switch]$NoPause)

$ErrorActionPreference = "Stop"

$VERSION = "2.2.0"   # bump on every change - see CHANGELOG.md

# Keep the window open at the end so the result can actually be read.
# (Right-click > "Run with PowerShell" otherwise closes it instantly.)
function Stop-Here([int]$code) {
    if (-not $NoPause) {
        Write-Host ""
        Write-Host "Press Enter to close..." -ForegroundColor DarkGray
        try { [void](Read-Host) } catch { Start-Sleep -Seconds 20 }
    }
    exit $code
}
function Fail($m) {
    Write-Host ""
    Write-Host "  FAILED: $m" -ForegroundColor Red
    Write-Host "  Nothing was changed." -ForegroundColor Red
    Stop-Here 1
}
function Ok($m)   { Write-Host "  [ok] $m" -ForegroundColor Green }
function Info($m) { Write-Host "  $m" -ForegroundColor DarkGray }

if (-not $Path) { $Path = $PSScriptRoot }
if (-not $Path) { $Path = (Get-Location).Path }

$dll    = Join-Path $Path "ProjectDiablo.dll"
$d2c    = Join-Path $Path "D2Client.dll"
$backup = Join-Path $Path "ProjectDiablo.dll.stock-backup"

Write-Host ""
Write-Host "PD2 + PlugY stat-ranges patch  v$VERSION" -ForegroundColor Cyan
Write-Host "------------------------------------------------"
Info "folder: $Path"

if (-not (Test-Path $dll)) {
    Fail ("ProjectDiablo.dll not found in this folder.`n" +
          "          Put this script in your Project Diablo 2 folder (the one with`n" +
          "          ProjectDiablo.dll and PlugY.exe), or run it with -Path <folder>.")
}
if (Get-Process -Name "Game" -ErrorAction SilentlyContinue) {
    Write-Host ""
    Write-Host "  >>> DIABLO II IS RUNNING <<<" -ForegroundColor Yellow
    Write-Host "  Close the game completely, then run this again." -ForegroundColor Yellow
    Write-Host "  (Windows locks ProjectDiablo.dll while the game is open.)" -ForegroundColor Yellow
    Write-Host "  Nothing was changed." -ForegroundColor Yellow
    Stop-Here 1
}

if ($Restore) {
    if (-not (Test-Path $backup)) { Fail "no backup found at ProjectDiablo.dll.stock-backup" }
    Copy-Item $backup $dll -Force
    Ok "restored the original ProjectDiablo.dll"
    Stop-Here 0
}
if (-not (Test-Path $d2c)) { Fail "D2Client.dll not found - needed to locate the panel-draw function." }

# ------------------------------------------------------------------- PE ----

$b = [System.IO.File]::ReadAllBytes($dll)
function U16([int]$o) { [BitConverter]::ToUInt16($b, $o) }
function U32([int]$o) { [BitConverter]::ToUInt32($b, $o) }

$peOff = U32 0x3C
if ((U32 $peOff) -ne 0x00004550) { Fail "ProjectDiablo.dll is not a valid PE file." }
$coff = $peOff + 4
$nSec = U16 ($coff + 2); $optSz = U16 ($coff + 16); $opt = $coff + 20
$imageBase = U32 ($opt + 28)
$secTab = $opt + $optSz

$secs = @()
for ($i = 0; $i -lt $nSec; $i++) {
    $s = $secTab + ($i * 40)
    $secs += [PSCustomObject]@{
        Name   = [System.Text.Encoding]::ASCII.GetString($b, $s, 8).Trim([char]0)
        VAddr  = (U32 ($s + 12)); RawPtr = (U32 ($s + 20)); RawSize = (U32 ($s + 16))
    }
}
function OffToVa([int]$o) {
    foreach ($s in $secs) {
        if ($o -ge $s.RawPtr -and $o -lt ($s.RawPtr + $s.RawSize)) {
            return [uint32]($imageBase + $s.VAddr + ($o - $s.RawPtr))
        }
    }
    return 0
}
$text = $secs | Where-Object { $_.Name -eq ".text" }
if (-not $text) { Fail "no .text section in ProjectDiablo.dll." }

Info ("file:   {0:N0} bytes, ImageBase 0x{1:X8}" -f $b.Length, $imageBase)

# masked signature search; -1 = wildcard byte
function FindSig([int[]]$sig) {
    $last = $b.Length - $sig.Count
    for ($i = 0; $i -le $last; $i++) {
        $hit = $true
        for ($j = 0; $j -lt $sig.Count; $j++) {
            if ($sig[$j] -ge 0 -and $b[$i + $j] -ne $sig[$j]) { $hit = $false; break }
        }
        if ($hit) { return $i }
    }
    return -1
}

Write-Host ""
Write-Host "Locating (by signature, not fixed offsets)..." -ForegroundColor Cyan
Info "this takes a few seconds"

# 1. the -plugy gate:  cmp byte [flag],0 / jne short / mov ecx,<table> / call <installer>
#    unpatched it reads "75 xx"; once patched it reads "90 90" - accept either
$gate = FindSig @(0x80,0x3D,-1,-1,-1,-1,0x00, 0x75,-1, 0xB9,-1,-1,-1,-1, 0xE8)
if ($gate -lt 0) { $gate = FindSig @(0x80,0x3D,-1,-1,-1,-1,0x00, 0x90,0x90, 0xB9,-1,-1,-1,-1, 0xE8) }
if ($gate -lt 0) { Fail "signature 1 (the -plugy gate) not found - PD2 changed too much, the patch needs re-deriving." }
$gateJne   = $gate + 7
$hookTblVa = [BitConverter]::ToUInt32($b, $gate + 10)
Ok ("-plugy gate       0x{0:X6}" -f $gate)

if ($b[$gateJne] -eq 0x90 -and $b[$gateJne + 1] -eq 0x90) {
    Write-Host ""
    Write-Host "  ============================================" -ForegroundColor Green
    Write-Host "   ALREADY PATCHED - nothing to do" -ForegroundColor Green
    Write-Host "  ============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  If you still don't see stat ranges, check PlugY.ini has" -ForegroundColor DarkGray
    Write-Host "  Param=-plugy -3dfx -direct -txt  and that you launched via PlugY.exe." -ForegroundColor DarkGray
    Write-Host "  (Use -Restore / Restore-Original.bat to undo.)" -ForegroundColor DarkGray
    Stop-Here 0
}
Ok ("hook table        0x{0:X8}" -f $hookTblVa)

# 2. the panel hook entry: { module=0, RVA=0x000C3B18, handler, flag=1 }
$entry = FindSig @(0x00,0x00,0x00,0x00, 0x18,0x3B,0x0C,0x00, -1,-1,-1,0x10, 0x01,0x00,0x00,0x00)
if ($entry -lt 0) { Fail "signature 2 (the D2Client panel hook entry) not found." }
$origHandler = [BitConverter]::ToUInt32($b, $entry + 8)
$nextEntry   = $entry + 20
Ok ("panel hook entry  0x{0:X6}  handler 0x{1:X8}" -f $entry, $origHandler)

# 3. PD2's module base table:  mov eax,[<table> + eax*8]
$mt = FindSig @(0x8B,0x04,0xC5,-1,-1,-1,0x10)
if ($mt -lt 0) { Fail "signature 3 (module base table) not found." }
$modTblVa = [BitConverter]::ToUInt32($b, $mt + 3)
Ok ("module base table 0x{0:X8}" -f $modTblVa)

# 4. panel-draw RVA, decoded out of D2Client.dll
$dc = [System.IO.File]::ReadAllBytes($d2c)
$callOp = 0x000C3B18 - 1
if ($dc.Length -le ($callOp + 5)) { Fail "D2Client.dll is smaller than expected." }
if ($dc[$callOp] -ne 0xE8) { Fail ("expected a call at D2Client RVA 0x{0:X}, found 0x{1:X2}." -f $callOp, $dc[$callOp]) }
$panelRva = $callOp + 5 + [BitConverter]::ToInt32($dc, $callOp + 1)
Ok ("panel draw RVA    0x{0:X}" -f $panelRva)

# 5. a code cave (run of int3 padding)
$THUNK_LEN = 17
$caveOff = -1; $run = 0; $start = -1
for ($i = $text.RawPtr; $i -lt ($text.RawPtr + $text.RawSize); $i++) {
    if ($b[$i] -eq 0xCC) {
        if ($run -eq 0) { $start = $i }
        $run++
        if ($run -ge $THUNK_LEN) { $caveOff = $start; break }
    } else { $run = 0 }
}
if ($caveOff -lt 0) { Fail "no $THUNK_LEN-byte code cave found in .text." }
$caveVa = OffToVa $caveOff
Ok ("code cave         0x{0:X6}  VA 0x{1:X8}" -f $caveOff, $caveVa)

if ($b[$gateJne] -ne 0x75) { Fail ("unexpected byte 0x{0:X2} at the gate." -f $b[$gateJne]) }

# ------------------------------------------------------------------ patch ----

Write-Host ""
Write-Host "Patching..." -ForegroundColor Cyan

Copy-Item $dll $backup -Force
Ok "backed up original -> ProjectDiablo.dll.stock-backup"

# thunk: run D2Client's original panel draw (PlugY's stash patches live inside it),
#        then tail-call PD2's renderer (BH augmentation)
$rel = [int]($origHandler - ($caveVa + $THUNK_LEN))
$thunk = New-Object System.Collections.ArrayList
[void]$thunk.Add(0xA1)                                               # mov eax,[modTbl]
[void]$thunk.AddRange([BitConverter]::GetBytes([uint32]$modTblVa))
[void]$thunk.Add(0x05)                                               # add eax,panelRva
[void]$thunk.AddRange([BitConverter]::GetBytes([uint32]$panelRva))
[void]$thunk.AddRange(@(0xFF, 0xD0))                                 # call eax
[void]$thunk.Add(0xE9)                                               # jmp origHandler
[void]$thunk.AddRange([BitConverter]::GetBytes([int32]$rel))
if ($thunk.Count -ne $THUNK_LEN) { Fail "internal error: thunk is $($thunk.Count) bytes." }

for ($i = 0; $i -lt $THUNK_LEN; $i++) { $b[$caveOff + $i] = $thunk[$i] }
Ok ("thunk written: " + (($thunk | ForEach-Object { "{0:X2}" -f $_ }) -join ' '))

$b[$gateJne] = 0x90; $b[$gateJne + 1] = 0x90
Ok "gate jne -> nop nop (hook table now installs under -plugy)"

[Array]::Copy([BitConverter]::GetBytes([uint32]$caveVa), 0, $b, $entry + 8, 4)
Ok ("panel handler 0x{0:X8} -> 0x{1:X8}" -f $origHandler, $caveVa)

[Array]::Copy([BitConverter]::GetBytes([uint32]0x1B), 0, $b, $nextEntry, 4)
Ok "hook table terminated after the panel entry"

[System.IO.File]::WriteAllBytes($dll, $b)

# ----------------------------------------------------------- verify on disk ----

$v = [System.IO.File]::ReadAllBytes($dll)
$bad = @()
if ($v[$gateJne] -ne 0x90 -or $v[$gateJne + 1] -ne 0x90)    { $bad += "gate" }
if ([BitConverter]::ToUInt32($v, $entry + 8) -ne $caveVa)    { $bad += "handler" }
if ([BitConverter]::ToUInt32($v, $nextEntry) -ne 0x1B)       { $bad += "terminator" }
for ($i = 0; $i -lt $THUNK_LEN; $i++) { if ($v[$caveOff + $i] -ne $thunk[$i]) { $bad += "thunk"; break } }
if ($bad.Count -gt 0) {
    Copy-Item $backup $dll -Force
    Fail ("verification failed after writing (" + ($bad -join ', ') + ") - original restored.")
}

Write-Host ""
Write-Host "  ============================================" -ForegroundColor Green
Write-Host "   SUCCESS - patch applied and verified" -ForegroundColor Green
Write-Host "  ============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Now check PlugY.ini contains:" -ForegroundColor Cyan
Write-Host "      Param=-plugy -3dfx -direct -txt"
Write-Host "      Library=PlugY.dll"
Write-Host ""
Write-Host "  Then launch with PlugY.exe. Hover an item - you should see green"
Write-Host "  [min - max] ranges, Max Sockets and the upgrade recipe."
Write-Host ""
Write-Host "  Re-run this after every PD2 update (the launcher restores the DLL)."
Write-Host ""
Write-Host "  SINGLE PLAYER ONLY - do not use on the PD2 online realm." -ForegroundColor Yellow
Stop-Here 0
