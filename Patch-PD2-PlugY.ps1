<#
    Patch-PD2-PlugY.ps1   v3.0.0   (version-independent)

    Restores Project Diablo 2's augmented item descriptions (green [min - max]
    stat ranges, Max Sockets, Base Speed, upgrade recipe) when launching through
    PlugY, while keeping PlugY's multi-page / shared stash working - and draws
    PlugY's stash page buttons on top of PD2's panel frame so they're visible.

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

$VERSION = "3.0.0"   # bump on every change - see CHANGELOG.md

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

# ------------------------------------------------------------- helpers ----

function U16([byte[]]$a, [int]$o) { [BitConverter]::ToUInt16($a, $o) }
function U32([byte[]]$a, [int]$o) { [BitConverter]::ToUInt32($a, $o) }

function Get-PE([byte[]]$a, [string]$what) {
    $pe = U32 $a 0x3C
    if ($pe -le 0 -or $pe -ge $a.Length - 4 -or (U32 $a $pe) -ne 0x00004550) { Fail "$what is not a valid PE file." }
    $coff = $pe + 4
    $n = U16 $a ($coff + 2); $optSz = U16 $a ($coff + 16); $opt = $coff + 20
    $tab = $opt + $optSz
    $secs = @()
    for ($i = 0; $i -lt $n; $i++) {
        $s = $tab + $i * 40
        $secs += [PSCustomObject]@{
            Name    = [System.Text.Encoding]::ASCII.GetString($a, $s, 8).Trim([char]0)
            VSize   = (U32 $a ($s + 8));  VAddr  = (U32 $a ($s + 12))
            RawSize = (U32 $a ($s + 16)); RawPtr = (U32 $a ($s + 20))
        }
    }
    [PSCustomObject]@{ ImageBase = (U32 $a ($opt + 28)); Sections = $secs }
}
function OffToVa($pe, [int]$o) {
    foreach ($s in $pe.Sections) {
        if ($o -ge $s.RawPtr -and $o -lt ($s.RawPtr + $s.RawSize)) { return [int64]$pe.ImageBase + $s.VAddr + ($o - $s.RawPtr) }
    }
    return -1
}
function RvaToOff($pe, [int64]$r) {
    foreach ($s in $pe.Sections) {
        if ($r -ge $s.VAddr -and $r -lt ($s.VAddr + [Math]::Min($s.VSize, $s.RawSize))) { return [int]($r - $s.VAddr + $s.RawPtr) }
    }
    return -1
}

# masked signature search; -1 = wildcard byte. Anchors on the first non-zero
# fixed byte and lets [Array]::IndexOf do the scanning.
function FindSig([byte[]]$a, [int[]]$sig) {
    $anchor = -1
    for ($k = 0; $k -lt $sig.Count; $k++) { if ($sig[$k] -gt 0) { $anchor = $k; break } }
    $av = [byte]$sig[$anchor]
    $last = $a.Length - $sig.Count
    $i = [Array]::IndexOf($a, $av, $anchor)
    while ($i -ge 0) {
        $s = $i - $anchor
        if ($s -gt $last) { break }
        $hit = $true
        for ($j = 0; $j -lt $sig.Count; $j++) {
            if ($sig[$j] -ge 0 -and $a[$s + $j] -ne $sig[$j]) { $hit = $false; break }
        }
        if ($hit) { return $s }
        $i = [Array]::IndexOf($a, $av, $i + 1)
    }
    return -1
}

# Locates everything that gets patched in a ProjectDiablo.dll image.
function Find-Targets([byte[]]$a, [string]$label) {
    # 1. the -plugy gate:  cmp byte [flag],0 / jne short / mov ecx,<table> / call <installer>
    #    unpatched it reads "75 xx"; once patched "90 90"
    $gate = FindSig $a @(0x80,0x3D,-1,-1,-1,-1,0x00, 0x75,-1, 0xB9,-1,-1,-1,-1, 0xE8)
    if ($gate -lt 0) { $gate = FindSig $a @(0x80,0x3D,-1,-1,-1,-1,0x00, 0x90,0x90, 0xB9,-1,-1,-1,-1, 0xE8) }
    if ($gate -lt 0) { Fail "signature 1 (the -plugy gate) not found in $label - PD2 changed too much, the patch needs re-deriving." }
    $jne = $gate + 7

    # 2. the panel hook entry: { module=0, RVA=0x000C3B18, handler, flag=1 }
    $entry = FindSig $a @(0x00,0x00,0x00,0x00, 0x18,0x3B,0x0C,0x00, -1,-1,-1,0x10, 0x01,0x00,0x00,0x00)
    if ($entry -lt 0) { Fail "signature 2 (the D2Client panel hook entry) not found in $label." }

    # 3. PD2's module base table:  mov eax,[<table> + eax*8]  (slot 0 = D2Client)
    $mt = FindSig $a @(0x8B,0x04,0xC5,-1,-1,-1,0x10)
    if ($mt -lt 0) { Fail "signature 3 (module base table) not found in $label." }

    [PSCustomObject]@{
        Gate    = $gate
        Jne     = $jne
        Patched = ($a[$jne] -eq 0x90 -and $a[$jne + 1] -eq 0x90)
        Entry   = $entry
        Handler = [int64](U32 $a ($entry + 8))
        ModTbl  = [int64](U32 $a ($mt + 3))
    }
}

# signature of the start of the code this version writes:
#   push esi / call $+5 / pop eax
$V3_HEAD = [byte[]](0x56, 0xE8, 0x00, 0x00, 0x00, 0x00, 0x58)

# --------------------------------------------------------- ProjectDiablo ----

$b  = [System.IO.File]::ReadAllBytes($dll)
$pe = Get-PE $b "ProjectDiablo.dll"
Info ("file:   {0:N0} bytes, ImageBase 0x{1:X8}" -f $b.Length, $pe.ImageBase)

Write-Host ""
Write-Host "Locating (by signature, not fixed offsets)..." -ForegroundColor Cyan
Info "this takes a few seconds"

$t = Find-Targets $b "ProjectDiablo.dll"
Ok ("-plugy gate       0x{0:X6}" -f $t.Gate)

$upgrading = $false
if ($t.Patched) {
    $ho = RvaToOff $pe ($t.Handler - $pe.ImageBase)
    $isV3 = ($ho -ge 0)
    if ($isV3) { for ($i = 0; $i -lt $V3_HEAD.Length; $i++) { if ($b[$ho + $i] -ne $V3_HEAD[$i]) { $isV3 = $false; break } } }
    if ($isV3) {
        Write-Host ""
        Write-Host "  ============================================" -ForegroundColor Green
        Write-Host "   ALREADY PATCHED (v3) - nothing to do" -ForegroundColor Green
        Write-Host "  ============================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "  If you still don't see stat ranges, make sure you start the game with" -ForegroundColor DarkGray
        Write-Host "  Launch-PD2-PlugY.bat and PlugY.ini has  Param=-plugy -3dfx -direct -txt" -ForegroundColor DarkGray
        Write-Host "  (Use -Restore / Restore-Original.bat to undo.)" -ForegroundColor DarkGray
        Stop-Here 0
    }

    # Patched by an older version of this script. Upgrade starting from the
    # original DLL, which the older version saved as the backup.
    Write-Host ""
    Write-Host "  This DLL was patched by an older version of this script - upgrading." -ForegroundColor Yellow
    if (-not (Test-Path $backup)) {
        Fail ("no ProjectDiablo.dll.stock-backup to upgrade from.`n" +
              "          Get the original DLL back (PD2 launcher > verify/repair files), then run this again.")
    }
    $bb  = [System.IO.File]::ReadAllBytes($backup)
    $bpe = Get-PE $bb "ProjectDiablo.dll.stock-backup"
    $bt  = Find-Targets $bb "ProjectDiablo.dll.stock-backup"
    if ($bt.Patched -or $bb.Length -ne $b.Length -or $bt.Entry -ne $t.Entry -or $bt.Gate -ne $t.Gate) {
        Fail ("ProjectDiablo.dll.stock-backup doesn't match this DLL's build.`n" +
              "          Get the original DLL back (PD2 launcher > verify/repair files), then run this again.")
    }
    Ok "starting from ProjectDiablo.dll.stock-backup (original of this build)"
    $b = $bb; $pe = $bpe; $t = $bt
    $upgrading = $true
}
if ($b[$t.Jne] -ne 0x75) { Fail ("unexpected byte 0x{0:X2} at the gate." -f $b[$t.Jne]) }

$origHandler = $t.Handler
Ok ("panel hook entry  0x{0:X6}  handler 0x{1:X8}" -f $t.Entry, $origHandler)
Ok ("module base table 0x{0:X8}" -f $t.ModTbl)

# ------------------------------------------------------------- D2Client ----

$dc  = [System.IO.File]::ReadAllBytes($d2c)
$dpe = Get-PE $dc "D2Client.dll"
function DcCallTarget([int64]$callRva, [string]$what) {
    $o = RvaToOff $dpe $callRva
    if ($o -lt 0 -or $dc[$o] -ne 0xE8) { Fail ("expected a call ($what) at D2Client RVA 0x{0:X} - D2Client.dll isn't the 1.13c build PlugY expects." -f $callRva) }
    return [int64]($callRva + 5 + [BitConverter]::ToInt32($dc, $o + 1))
}

# 4. the inventory/stash panel draw - the call PD2's panel hook replaces
$panelRva = DcCallTarget 0xC3B17 "panel draw"
Ok ("panel draw RVA    0x{0:X}" -f $panelRva)

# 5. the call inside that panel draw that PlugY hooks to draw its stash page buttons
$BTN_CALL = 0x99A55
$btnTarget = DcCallTarget $BTN_CALL "stash buttons"
if ($btnTarget -ne 0xBEAF0) { Fail ("D2Client stash-button call goes to 0x{0:X}, expected 0xBEAF0 - D2Client.dll isn't the 1.13c build PlugY expects." -f $btnTarget) }
Ok ("stash button call 0x{0:X}" -f $BTN_CALL)

# 6. the UI-state array (GetUIState: cmp eax,26h ... mov eax,[eax*4 + array] / ret)
$ui = FindSig $dc @(0x83,0xF8,0x26, 0x72,-1, 0x68,-1,-1,-1,-1, 0xE8,-1,-1,-1,-1, 0x50, 0x68,-1,-1,-1,-1,
                    0xE8,-1,-1,-1,-1, 0x83,0xC4,0x0C, 0x6A,0xFF, 0xE8,-1,-1,-1,-1, 0x8B,0x04,0x85,-1,-1,-1,-1, 0xC3)
if ($ui -lt 0) { Fail "signature 4 (D2Client GetUIState) not found." }
$UI_STASH = 0x19                                         # D2 1.13c UI index of the stash panel
$uiStashRva = ([int64](U32 $dc ($ui + 39)) - $dpe.ImageBase) + $UI_STASH * 4
Ok ("stash-open flag   D2Client+0x{0:X}" -f $uiStashRva)

# ------------------------------------------------------------- the code ----
#
# The panel hook entry is redirected here. Runs, in order:
#   1. D2Client's own panel draw     -> PlugY's stash pages render (it patches inside it)
#   2. PD2's renderer                -> BH stat-range augmentation, PD2's frame
#   3. if the stash is open: PlugY's stash-button routine again, so the buttons
#      land on top of PD2's frame
# Position-independent: PD2's module table is addressed relative to this code
# (call $+5 / pop), D2Client through its runtime base, so it survives relocation.

$prog = @(
    @{ B = @(0x56) }                                                    # push esi
    @{ B = @(0xE8,0,0,0,0, 0x58); Pic = $true }                         # call $+5 / pop eax
    @{ B = @(0x8B,0xB0,0,0,0,0); PicDisp = $true }                      # mov esi,[eax + (modtbl - here)]
    @{ B = @(0x8D,0x86) + [BitConverter]::GetBytes([uint32]$panelRva) } # lea eax,[esi + panelRva]
    @{ B = @(0xFF,0xD0) }                                               # call eax
    @{ B = @(0xE8,0,0,0,0); To = $origHandler }                         # call PD2 renderer
    @{ B = @(0x83,0xBE) + [BitConverter]::GetBytes([uint32]$uiStashRva) + @(0x00) }  # cmp dword [esi+stash],0
    @{ B = @(0x0F,0x85,0,0,0,0); ToLabel = "buttons" }                  # jnz buttons
    @{ B = @(0x5E) }                                                    # pop esi
    @{ B = @(0xC3); End = $true }                                       # ret
    @{ B = @(0x8B,0x86) + [BitConverter]::GetBytes([uint32]($BTN_CALL + 1)); Label = "buttons" }   # mov eax,[esi + call operand]
    @{ B = @(0x8D,0x84,0x06) + [BitConverter]::GetBytes([uint32]($BTN_CALL + 5)) }               # lea eax,[esi + eax + next]
    @{ B = @(0x5E) }                                                    # pop esi
    @{ B = @(0xFF,0xE0); End = $true }                                  # jmp eax (PlugY's routine)
)

# code caves: runs of int3 padding inside the mapped part of .text
$text = $pe.Sections | Where-Object { $_.Name -eq ".text" }
if (-not $text) { Fail "no .text section in ProjectDiablo.dll." }
$MIN_CAVE = 12          # longest instruction (7) + link jump (5)
$caves = New-Object System.Collections.ArrayList
$run = 0; $start = -1
$endRaw = $text.RawPtr + [Math]::Min($text.RawSize, $text.VSize)
for ($i = $text.RawPtr; $i -lt $endRaw; $i++) {
    if ($b[$i] -eq 0xCC) { if ($run -eq 0) { $start = $i }; $run++ }
    else {
        if ($run -ge $MIN_CAVE) { [void]$caves.Add(@{ Off = $start; Len = $run }); if ($caves.Count -ge 10) { break } }
        $run = 0
    }
}

# pack the instructions into caves, linking caves with jmp rel32 where needed
$placed = @()            # per instruction: file offset
$links  = @()            # @{ Off = file offset of the link jmp; To = file offset of next cave }
$ci = 0
if ($caves.Count -eq 0) { Fail "no code caves found in .text." }
$pos = $caves[0].Off; $left = $caves[0].Len
$prevEnd = $true
for ($k = 0; $k -lt $prog.Count; $k++) {
    $ins = $prog[$k]
    $need = $ins.B.Count + $(if ($ins.End) { 0 } else { 5 })
    if ($need -gt $left) {
        $ci++
        if ($ci -ge $caves.Count) { Fail "not enough code-cave space in .text." }
        if (-not $prevEnd) { $links += @{ Off = $pos; To = $caves[$ci].Off } }
        $pos = $caves[$ci].Off; $left = $caves[$ci].Len
    }
    $placed += $pos
    $pos += $ins.B.Count; $left -= $ins.B.Count
    $prevEnd = [bool]$ins.End
}
$usedCaves = $ci + 1

# resolve and emit
$labels = @{}
for ($k = 0; $k -lt $prog.Count; $k++) { if ($prog[$k].Label) { $labels[$prog[$k].Label] = $placed[$k] } }
function VaOf([int]$off) { OffToVa $pe $off }

$planned = @{}           # file offset -> byte, for verification
function Emit([int]$off, [byte[]]$bytes) {
    for ($i = 0; $i -lt $bytes.Length; $i++) { $b[$off + $i] = $bytes[$i]; $planned[$off + $i] = $bytes[$i] }
}
function Rel32([int64]$nextIp, [int64]$to) { [BitConverter]::GetBytes([int32]($to - $nextIp)) }

$picBase = 0
for ($k = 0; $k -lt $prog.Count; $k++) {
    $ins = $prog[$k]; $off = $placed[$k]; $va = VaOf $off
    $bytes = [byte[]]$ins.B
    $len = $bytes.Length
    if ($ins.Pic)     { $picBase = $va + 5 }                                         # eax after pop
    if ($ins.PicDisp) { [Array]::Copy([BitConverter]::GetBytes([int32]($t.ModTbl - $picBase)), 0, $bytes, 2, 4) }
    if ($ins.To)      { [Array]::Copy((Rel32 ($va + $len) $ins.To), 0, $bytes, $len - 4, 4) }
    if ($ins.ToLabel) { [Array]::Copy((Rel32 ($va + $len) (VaOf $labels[$ins.ToLabel])), 0, $bytes, $len - 4, 4) }
    Emit $off $bytes
}
foreach ($l in $links) { Emit $l.Off ([byte[]](@(0xE9) + (Rel32 ((VaOf $l.Off) + 5) (VaOf $l.To)))) }

$codeVa = VaOf $placed[0]
Ok ("code: {0} bytes in {1} cave(s), starting 0x{2:X8}" -f ($prog | ForEach-Object { $_.B.Count } | Measure-Object -Sum).Sum, $usedCaves, $codeVa)

# ------------------------------------------------------------------ patch ----

Write-Host ""
Write-Host "Patching..." -ForegroundColor Cyan

if ($upgrading) { Info "keeping existing ProjectDiablo.dll.stock-backup (it's the original)" }
else { Copy-Item $dll $backup -Force; Ok "backed up original -> ProjectDiablo.dll.stock-backup" }

Emit $t.Jne ([byte[]](0x90, 0x90))
Ok "gate jne -> nop nop (hook table now installs under -plugy)"
Emit ($t.Entry + 8) ([BitConverter]::GetBytes([uint32]$codeVa))
Ok ("panel handler 0x{0:X8} -> 0x{1:X8}" -f $origHandler, $codeVa)
Emit ($t.Entry + 20) ([BitConverter]::GetBytes([uint32]0x1B))
Ok "hook table terminated after the panel entry"

[System.IO.File]::WriteAllBytes($dll, $b)

# ----------------------------------------------------------- verify on disk ----

$v = [System.IO.File]::ReadAllBytes($dll)
$bad = 0
foreach ($k in $planned.Keys) { if ($v[$k] -ne $planned[$k]) { $bad++ } }
# re-decode the branches from what's actually on disk
function DiskRel([int]$off, [int]$len) { (VaOf $off) + $len + [BitConverter]::ToInt32($v, $off + $len - 4) }
for ($k = 0; $k -lt $prog.Count; $k++) {
    $len = $prog[$k].B.Count
    if ($prog[$k].To      -and (DiskRel $placed[$k] $len) -ne $prog[$k].To)                          { $bad++ }
    if ($prog[$k].ToLabel -and (DiskRel $placed[$k] $len) -ne (VaOf $labels[$prog[$k].ToLabel]))    { $bad++ }
}
foreach ($l in $links) { if ((DiskRel $l.Off 5) -ne (VaOf $l.To)) { $bad++ } }
if ($bad -gt 0) {
    if (Test-Path $backup) { Copy-Item $backup $dll -Force }
    Fail "verification failed after writing ($bad problems) - original restored."
}

Write-Host ""
Write-Host "  ============================================" -ForegroundColor Green
Write-Host "   SUCCESS - patch applied and verified" -ForegroundColor Green
Write-Host "  ============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Start the game with Launch-PD2-PlugY.bat (not PlugY.exe directly)." -ForegroundColor Cyan
Write-Host "  PlugY.ini must contain:  Param=-plugy -3dfx -direct -txt"
Write-Host ""
Write-Host "  Hover an item - you should see green [min - max] ranges, Max Sockets"
Write-Host "  and the upgrade recipe. PlugY's stash page buttons now draw on top."
Write-Host ""
Write-Host "  Re-run this after every PD2 update (the launcher restores the DLL)."
Write-Host ""
Write-Host "  SINGLE PLAYER ONLY - do not use on the PD2 online realm." -ForegroundColor Yellow
Stop-Here 0
