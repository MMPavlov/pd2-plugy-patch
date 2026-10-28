<#
    Patch-PD2-PlugY.ps1   v6.0.0   (version-independent)

    Restores Project Diablo 2's augmented item descriptions (green [min - max]
    stat ranges, Max Sockets, Base Speed, upgrade recipe) when launching through
    PlugY, while keeping PlugY's multi-page / shared stash working - and draws
    PlugY's stash page buttons on top of PD2's panel frame so they're visible.
    On Season 14 the buttons only show and click on PD2's "Stash" category, not
    on Gems, Runes and the other categories down the left of the stash. Those
    get PD2's own stash clicks and its material storage back (PD2 turns that off
    with PlugY), so gems, runes, ... can be put in. Under PlugY it's saved in
    Save\shared.stash, apart from PD2's own pd2_shared.stash. PD2's own stash
    page tabs (P, I-IX) are hidden under PlugY; its page buttons are there.

    Nothing is hardcoded to a particular ProjectDiablo.dll build. Every address is
    located by byte signature at run time, so this keeps working across PD2 updates.
    If PD2 ever restructures the code so a signature no longer matches, the script
    stops and tells you which one - it never writes a partial patch. It installs
    only PD2 hooks tested alongside PlugY (Seasons 13 and 14 so far), and stops if
    a build's first hooks aren't those.

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

$VERSION = "6.0.0"   # bump on every change - see CHANGELOG.md

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

# Anything unexpected: show the message and keep the window open, instead of
# PowerShell printing it and the window closing before it can be read.
trap {
    Write-Host ""
    Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Stop-Here 1
}

if (-not $Path) { $Path = $PSScriptRoot }
if (-not $Path) { $Path = (Get-Location).Path }
$Path = (Resolve-Path -LiteralPath $Path).ProviderPath.TrimEnd('\')

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

# A game folder under Program Files can only be changed with administrator rights.
# Check before touching anything; if they're missing, ask Windows for them and
# carry on in the elevated window.
function Test-Writable {
    try {
        $probe = Join-Path $Path ("pd2-plugy-patch-{0}.tmp" -f [guid]::NewGuid().ToString("N").Substring(0, 8))
        [IO.File]::WriteAllBytes($probe, [byte[]]@())
        Remove-Item -LiteralPath $probe -Force
        [IO.File]::Open($dll, 'Open', 'ReadWrite', 'Read').Close()
        return $true
    } catch [UnauthorizedAccessException] { return $false }
}
if (-not (Test-Writable)) {
    $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
                 [Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($admin) {
        Fail ("Windows won't let this change ProjectDiablo.dll, even as administrator.`n" +
              "          Check the file isn't read-only, and that antivirus isn't blocking it.")
    }
    Write-Host ""
    Write-Host "  This folder needs administrator rights (it's probably under Program Files)." -ForegroundColor Yellow
    Write-Host "  Windows will ask for permission - click Yes. The patch continues in a new window." -ForegroundColor Yellow
    $elevated = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Path `"$Path`""
    if ($Restore) { $elevated += " -Restore" }
    if ($NoPause) { $elevated += " -NoPause" }
    try { $p = Start-Process powershell.exe -Verb RunAs -ArgumentList $elevated -Wait -PassThru }
    catch { Fail "administrator rights weren't granted, so the patch can't change the game folder." }
    exit $p.ExitCode
}

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
# fixed byte and lets [Array]::IndexOf do the scanning. Returns the first match
# at or after $from.
function FindSig([byte[]]$a, [int[]]$sig, [int]$from = 0) {
    $anchor = -1
    for ($k = 0; $k -lt $sig.Count; $k++) { if ($sig[$k] -gt 0) { $anchor = $k; break } }
    $av = [byte]$sig[$anchor]
    $last = $a.Length - $sig.Count
    $i = [Array]::IndexOf($a, $av, $from + $anchor)
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
# -Soft: return $null instead of stopping when something isn't found.
$panelSig = @(0x00,0x00,0x00,0x00, 0x18,0x3B,0x0C,0x00, -1,-1,-1,0x10, 0x01,0x00,0x00,0x00)
function Find-Targets([byte[]]$a, [string]$label, $pe, [switch]$Soft) {
    # 2. the panel hook entry: { module=0, RVA=0x000C3B18, handler, flag=1 }
    $entry = FindSig $a $panelSig
    if ($entry -lt 0) { if ($Soft) { return $null }; Fail "signature 2 (the D2Client panel hook entry) not found in $label." }

    # 1. the -plugy gate:  cmp byte [flag],0 / jne short / mov ecx,<table> / call <installer>
    #    unpatched it reads "75 xx"; once patched "90 90". Season 14 has a second
    #    match elsewhere, so take the one whose table holds the panel hook entry.
    $gate = -1; $tableOff = -1
    foreach ($jcc in @(@(0x75, -1), @(0x90, 0x90))) {
        $sig = @(0x80,0x3D,-1,-1,-1,-1,0x00) + $jcc + @(0xB9,-1,-1,-1,-1, 0xE8)
        $at = FindSig $a $sig
        while ($at -ge 0) {
            $to = RvaToOff $pe ([int64](U32 $a ($at + 10)) - $pe.ImageBase)
            if ($to -ge 0 -and $entry -ge $to -and ($entry - $to) % 20 -eq 0 -and ($entry - $to) / 20 -lt 256) { $gate = $at; $tableOff = $to; break }
            $at = FindSig $a $sig ($at + 1)
        }
        if ($gate -ge 0) { break }
    }
    if ($gate -lt 0) { if ($Soft) { return $null }; Fail "signature 1 (the -plugy gate) not found in $label - PD2 changed too much, the patch needs re-deriving." }
    $jne = $gate + 7

    # 3. PD2's module base table:  mov eax,[<table> + eax*8]  (slot 0 = D2Client), read
    #    inside the hook installer the gate calls. Season 14 has other matches earlier
    #    in the file that point somewhere else.
    $instOff = RvaToOff $pe ((OffToVa $pe ($gate + 14)) + 5 + [BitConverter]::ToInt32($a, $gate + 15) - $pe.ImageBase)
    $mt = if ($instOff -ge 0) { FindSig $a @(0x8B,0x04,0xC5,-1,-1,-1,0x10) $instOff } else { -1 }
    if ($mt -lt 0 -or $mt -gt $instOff + 0x100) { if ($Soft) { return $null }; Fail "signature 3 (module base table) not found in the hook installer of $label." }

    # PD2's own panel record. Once patched on Season 14 the first panel record is the
    # one this script moved up; PD2's original stays further down, unused.
    $last = $entry
    $at = FindSig $a $panelSig ($entry + 1)
    while ($at -ge 0 -and $at -lt $tableOff + 256 * 20) {
        if (($at - $tableOff) % 20 -eq 0) { $last = $at }
        $at = FindSig $a $panelSig ($at + 1)
    }

    [PSCustomObject]@{
        Gate       = $gate
        Jne        = $jne
        Patched    = ($a[$jne] -eq 0x90 -and $a[$jne + 1] -eq 0x90)
        TableOff   = $tableOff
        Entry      = $entry
        PanelIndex = ($entry - $tableOff) / 20
        PD2PanelIndex = ($last - $tableOff) / 20
        Handler    = [int64](U32 $a ($entry + 8))
        ModTbl     = [int64](U32 $a ($mt + 3))
    }
}

# signature of the start of the code this version writes:
#   push esi / call $+5 / pop eax
$V3_HEAD = [byte[]](0x56, 0xE8, 0x00, 0x00, 0x00, 0x00, 0x58)

# Which PD2 hooks this installs. Season 13: PD2's first 14 hook-table entries, then
# the panel hook as entry 14, then the end of the table - the set tested with PlugY.
# Season 14 has the same first 14, then 21 new ones (a rewrite of the party portraits
# down the left of the screen), then the panel hook at entry 35. There the panel record
# is moved up and the table ends after it - and entry 13 is left out too: it hooks the
# same D2Client call as PlugY (0x4437C, PlugY's /players default), and on Season 14
# PD2 installs after PlugY and wraps that call with its new stash, which turned every
# stash page button into "next page".
$TESTED_HOOKS = @(        # { module, offset, relative, size } of entries 0-13
    @(3,0x02E47F,1,0), @(3,0x053BA4,1,0), @(3,0x0543B3,1,0), @(3,0x02D568,1,0), @(3,0x0543E7,1,0),
    @(3,0x02D8E1,1,0), @(3,0x02DD0B,1,0), @(3,0x02DEA8,1,0), @(0,0x043979,1,0), @(0,0x0AD484,1,0),
    @(0,0x04449F,1,0), @(7,0x0066C0,0,1), @(7,0x006917,0,1), @(0,0x04437C,1,0))
$S13_PANEL = $TESTED_HOOKS.Count                     # where Season 13 has the panel hook
function Get-Season14([byte[]]$a, $tt) { $tt.PD2PanelIndex -gt $S13_PANEL }
# number of PD2's leading hooks kept = the slot the panel record goes in
function Get-Keep([byte[]]$a, $tt) { if (Get-Season14 $a $tt) { $S13_PANEL - 1 } else { $S13_PANEL } }
# Does the panel code at $va hide D2's mouse position from D2's own panel draw (what
# this version writes on Season 14)? Its 4th instruction, after push esi / call+pop /
# mov esi, is then "push dword [esi+MouseX]" (FF B6); link jumps between caves followed.
function Test-HidesMouse([byte[]]$a, $pe, [int64]$va) {
    $o = RvaToOff $pe ($va - $pe.ImageBase)
    foreach ($len in 1, 6, 6, 0) {
        if ($o -lt 0) { return $false }
        if ($a[$o] -eq 0xE9) { $o = RvaToOff $pe ((OffToVa $pe $o) + 5 + [BitConverter]::ToInt32($a, $o + 1) - $pe.ImageBase) }
        if ($o -lt 0) { return $false }
        $o += $len
    }
    $a[$o] -eq 0xFF -and $a[$o + 1] -eq 0xB6
}
# Season 14: D2Client's stash mouse-down handler calls a hit test here, right before
# the call PlugY takes over to check its stash page buttons. This version hooks it, in
# the hook-table slot after the panel record, so PlugY's buttons can't be clicked on
# PD2's other stash categories (Gems, Runes, ...).
$CLICK_CALL = 0x9B887
# ...and D2Client's stash draw calls its item draw here, right before the call PlugY
# takes over to draw the buttons. Hooked in the slot after that, so PlugY doesn't draw
# them under PD2's frame on the other categories either (they show above its top edge).
$DRAW_CALL = 0x99A4A
# is hook-table slot (kept hooks + $n) the gate record for the D2Client call at $call?
function Test-Gate([byte[]]$a, $tt, [int]$n, [int64]$call) {
    $r = $tt.TableOff + ((Get-Keep $a $tt) + $n) * 20
    (U32 $a $r) -eq 0 -and (U32 $a ($r + 4)) -eq ($call + 1) -and (U32 $a ($r + 12)) -eq 1
}
# Season 14: PD2 has its own handlers for the stash's left click, right click, left
# release, mouse move, Esc and Space - the categories need them (putting gems, runes,
# ... in happens there). It puts them in D2Client's stash message table (rows of
# {type, message, handler}) with records further down its hook table. They replace the
# D2 handlers PlugY hooks into, so this version puts a switch in each row instead, in
# the slots after the gates: D2's handler on the Stash category, PD2's on the others.
$STASH_MSGS = 0xDBDB8; $STASH_ROWS = 8
# PD2's records for that table (file offsets): after its panel record, up to its table's end
function Get-StashHandlers([byte[]]$a, $tt) {
    $found = @()
    for ($i = $tt.PD2PanelIndex + 1; $i -lt 256; $i++) {
        $r = $tt.TableOff + $i * 20
        if ((U32 $a $r) -eq 0x1B) { break }
        $off = [int64](U32 $a ($r + 4))
        if ((U32 $a $r) -eq 0 -and (U32 $a ($r + 12)) -eq 0 -and (U32 $a ($r + 16)) -eq 0 -and
            $off -ge $STASH_MSGS -and $off -lt $STASH_MSGS + $STASH_ROWS * 12 -and ($off - $STASH_MSGS) % 12 -eq 8) { $found += $r }
    }
    $found      # callers wrap it in @()
}
# are they switched: one record per PD2 record, same row but not PD2's handler, then the end?
function Test-Handlers([byte[]]$a, $tt) {
    $hs = @(Get-StashHandlers $a $tt)
    if ($hs.Count -eq 0) { return $false }
    $r = $tt.TableOff + ((Get-Keep $a $tt) + 3) * 20
    foreach ($h in $hs) {
        if ((U32 $a $r) -ne 0 -or (U32 $a ($r + 4)) -ne (U32 $a ($h + 4)) -or (U32 $a ($r + 8)) -eq (U32 $a ($h + 8)) -or
            (U32 $a ($r + 12)) -ne 0 -or (U32 $a ($r + 16)) -ne 0) { return $false }
        $r += 20
    }
    (U32 $a $r) -eq 0x1B
}
$MSG_NAMES = @{ "0-200" = "mouse move"; "0-201" = "left click"; "0-202" = "left release"; "0-204" = "right click"; "3-1B" = "Esc"; "3-20" = "Space" }

# Season 14: with PlugY (the flag the gate tests), PD2 turns its material storage off - the
# Gems, Runes, ... categories - and doesn't load or save the file it's kept in,
# pd2_shared.stash, which also holds PD2's own shared stash pages. This version turns the
# material checks back on, and points PD2's shared-stash and compendium files 4 characters
# into their names under PlugY (Save\shared.stash, shared.compendium, hc_...), so PD2's
# own files and the items in them are never touched. PD2's checks around its own stash
# pages stay as they are: PlugY's pages are the Stash category's.
# The checks: cmp byte [flag],0|al|dl|bl / jne (once, mov [ebp-18h],eax in between), in
# .text order; on every Season 14 build the same 18, of these forms. On the ones marked
# "-" PD2 handles its own stash pages (switching them, putting items on them, ...).
$PLUGY_FORMS = "c c b b c C c c d c c c c c c c a a"
$PLUGY_KEEP  = @(2, 7, 10, 11)
function Get-PlugyChecks([byte[]]$a, $p, $tt) {
    $flag = [BitConverter]::GetBytes([uint32](U32 $a ($tt.Gate + 2)))
    $text = $p.Sections | Where-Object { $_.Name -eq ".text" }
    $sites = @(); $at = FindSig $a ([int[]]$flag) $text.RawPtr
    while ($at -ge 0 -and $at -lt $text.RawPtr + $text.RawSize) {
        $s = $at - 2; $form = $null
        if ($a[$s] -eq 0x80 -and $a[$s + 1] -eq 0x3D -and $a[$at + 4] -eq 0 -and $s -ne $tt.Gate) { $form = "c"; $j = $s + 7 }
        elseif ($a[$s] -eq 0x38 -and $a[$s + 1] -in 0x05, 0x15, 0x1D) { $form = @{ 0x05 = "a"; 0x15 = "d"; 0x1D = "b" }[[int]$a[$s + 1]]; $j = $s + 6 }
        if ($form) {
            if ($a[$j] -eq 0x89 -and $a[$j + 1] -eq 0x45) { $j += 3; $form = $form.ToUpper() }
            $len = if ($a[$j] -eq 0x75 -or ($a[$j] -eq 0x90 -and $a[$j + 1] -eq 0x90 -and $a[$j + 2] -ne 0x90)) { 2 }
                   elseif (($a[$j] -eq 0x0F -and $a[$j + 1] -eq 0x85) -or ($a[$j] -eq 0x90 -and $a[$j + 5] -eq 0x90)) { 6 } else { 0 }
            $sites += [PSCustomObject]@{ Cmp = $s; Form = $form; Jne = $j; Len = $len; Off = ($a[$j] -eq 0x90) }
        }
        $at = FindSig $a ([int[]]$flag) ($at + 1)
    }
    $sites
}
# PD2's two file names this redirects, and the calls that build their path in the save
# folder (path builder: ecx = out, edx = folder, one argument = the name). Found from the
# mov reg,<name> that each loads the name with: the first call after it into .text (an
# E8 byte inside another instruction, like shr al,2 = C0 E8 02, points somewhere else).
$PD2_FILES = "pd2_shared.stash", "pd2_hc_shared.stash", "pd2_shared.compendium", "pd2_hc_shared.compendium"
function Get-FileCalls([byte[]]$a, $p) {
    $text = $p.Sections | Where-Object { $_.Name -eq ".text" }
    $lo = [int64]$p.ImageBase + $text.VAddr; $hi = $lo + [Math]::Min($text.VSize, $text.RawSize)
    $calls = @{}
    foreach ($n in $PD2_FILES) {
        $nb = [int[]][Text.Encoding]::ASCII.GetBytes($n + [char]0)
        $no = FindSig $a $nb
        if ($no -lt 0) { return $null }
        $vb = [int[]][BitConverter]::GetBytes([uint32](OffToVa $p $no))
        $at = FindSig $a $vb $text.RawPtr
        while ($at -ge 0 -and $at -lt $text.RawPtr + $text.RawSize) {
            if ($a[$at - 1] -ge 0xB8 -and $a[$at - 1] -le 0xBF) {
                for ($k = $at + 4; $k -lt $at + 0x40; $k++) {
                    if ($a[$k] -ne 0xE8) { continue }
                    $to = (OffToVa $p $k) + 5 + [BitConverter]::ToInt32($a, $k + 1)
                    if ($to -ge $lo -and $to -lt $hi) { $calls[$k] = $to; break }
                }
            }
            $at = FindSig $a $vb ($at + 1)
        }
    }
    $calls
}
# the checks kept as they are, recognised by what follows them: PD2's stash page switch
# (cmp eax,0Ah ... mov byte [ebp-4],55h, its page packet), then two kinds of calls
function Test-KeptChecks([byte[]]$a, $cs) {
    $f = @($PLUGY_KEEP | ForEach-Object { $cs[$_].Jne + $cs[$_].Len })
    $c1 = FindSig $a @(0x83,0xF8,0x0A) $f[0]; $c2 = FindSig $a @(0xC6,0x45,0xFC,0x55) $f[0]
    $c1 -ge 0 -and $c1 -lt $f[0] + 0x40 -and $c2 -ge 0 -and $c2 -lt $f[0] + 0x50 -and
    $a[$f[1]] -eq 0x8B -and $a[$f[1] + 1] -eq 0xD6 -and $a[$f[1] + 2] -eq 0x8B -and $a[$f[1] + 3] -eq 0xCB -and $a[$f[1] + 4] -eq 0xE8 -and
    $a[$f[2]] -eq 0x8B -and $a[$f[2] + 1] -eq 0xCE -and $a[$f[2] + 2] -eq 0xE8 -and
    $a[$f[3]] -eq 0x8B -and $a[$f[3] + 1] -eq 0xCE -and $a[$f[3] + 2] -eq 0xE8 -and ($cs[11].Cmp - $cs[10].Cmp) -lt 0x100
}
# do the last three checks guard PD2's saving and loading of those files: calls, right
# after, to at least two functions that each build one of their paths?
function Test-FileChecks([byte[]]$a, $p, $cs, $fc) {
    $siteVas = @($fc.Keys | ForEach-Object { OffToVa $p $_ })
    foreach ($i in 15, 16, 17) {
        $f = $cs[$i].Jne + $cs[$i].Len; $n = 0
        for ($k = $f; $k -lt $f + 0x90; $k++) {
            if ($a[$k] -ne 0xE8) { continue }
            $to = (OffToVa $p $k) + 5 + [BitConverter]::ToInt32($a, $k + 1)
            if (@($siteVas | Where-Object { $_ -ge $to -and $_ -lt $to + 0x400 }).Count -gt 0) { $n++ }
        }
        if ($n -lt 2) { return $false }
    }
    $true
}
# Season 14: PD2's stash page tabs (P, I-IX) along the top of the stash. Its panel draw
# skips them on the categories; this version skips them under PlugY too, whose page
# buttons are there instead. The draw, around the image it loads for them:
#   cmp dword [esp+20h],0 / mov [esp+10h],edi / jne X / cmp dword [esp+24h],0 / jne X /
#   mov eax,[image] / test eax,eax / jnz / push eax / push <"...\stashtabs">
# Its second cmp becomes a call to the tabs check (5 bytes either way).
$TABS_SIG = @(0x83,0x7C,0x24,0x20,0x00, 0x89,0x7C,0x24,0x10, 0x0F,0x85,-1,-1,-1,-1, -2,-2,-2,-2,-2, 0x0F,0x85,-1,-1,-1,-1,
              0xA1,-1,-1,-1,-1, 0x85,0xC0, 0x75,-1, 0x50, 0x68,-1,-1,-1,-1)
$TABS_CMP = @(0x83,0x7C,0x24,0x24,0x00)
function Find-TabsDraw([byte[]]$a, $p) {
    foreach ($second in @($TABS_CMP, @(0xE8,-1,-1,-1,-1))) {
        $sig = [int[]]($TABS_SIG | ForEach-Object { $_ }); for ($i = 0; $i -lt 5; $i++) { $sig[15 + $i] = $second[$i] }
        $at = FindSig $a $sig
        if ($at -ge 0) {
            $no = RvaToOff $p ([int64](U32 $a ($at + 37)) - $p.ImageBase)
            $name = if ($no -ge 0) { [Text.Encoding]::ASCII.GetString($a, $no, 30) } else { "" }
            $same = ([BitConverter]::ToInt32($a, $at + 11) + 15) -eq ([BitConverter]::ToInt32($a, $at + 22) + 26)
            if ($name -like "*\stashtabs*" -and $same -and (FindSig $a $sig ($at + 1)) -lt 0) {
                return [PSCustomObject]@{ Site = $at + 15; Patched = ($a[$at + 15] -eq 0xE8) }
            }
        }
    }
    $null
}
# are PD2's material checks on and its files redirected (by this code: call $+5 / pop eax)?
function Test-Materials([byte[]]$a, $p, $tt) {
    $cs = @(Get-PlugyChecks $a $p $tt)
    if ($cs.Count -ne 18) { return $false }
    for ($i = 0; $i -lt $cs.Count; $i++) { if ($cs[$i].Off -ne ($i -notin $PLUGY_KEEP)) { return $false } }
    $fc = Get-FileCalls $a $p
    if (-not $fc -or $fc.Count -eq 0) { return $false }
    $to = @($fc.Values | Sort-Object -Unique)
    if ($to.Count -ne 1) { return $false }
    $o = RvaToOff $p ($to[0] - $p.ImageBase)
    $o -ge 0 -and $a[$o] -eq 0xE8 -and (U32 $a ($o + 1)) -eq 0 -and $a[$o + 5] -eq 0x58
}
function Test-HookSet([byte[]]$a, $tt) {
    if ($tt.PD2PanelIndex -lt $S13_PANEL) { return $false }
    for ($i = 0; $i -lt $S13_PANEL; $i++) {
        $r = $tt.TableOff + $i * 20; $h = $TESTED_HOOKS[$i]
        # on a patched Season 14 DLL the last slot holds the moved panel record
        if ($i -eq $S13_PANEL - 1 -and $tt.Patched -and $tt.PanelIndex -eq $i) { continue }
        if ((U32 $a $r) -ne $h[0] -or (U32 $a ($r + 4)) -ne $h[1] -or (U32 $a ($r + 12)) -ne $h[2] -or (U32 $a ($r + 16)) -ne $h[3]) { return $false }
    }
    $true
}

# ------------------------------------------------------------- restore ----

if ($Restore) {
    if (-not (Test-Path $backup)) { Fail "no backup found at ProjectDiablo.dll.stock-backup" }
    # Only put the backup back over a patched copy of the same DLL. After a PD2 update
    # the backup is the previous version's DLL, and copying it in would break the game.
    $cur = [System.IO.File]::ReadAllBytes($dll)
    $ct  = Find-Targets $cur "ProjectDiablo.dll" (Get-PE $cur "ProjectDiablo.dll") -Soft
    if (-not $ct -or -not $ct.Patched) {
        Ok "ProjectDiablo.dll isn't patched - nothing to restore."
        Info "(A PD2 update replaces it with an unpatched one, so this is normal after an update.)"
        Stop-Here 0
    }
    $old = [System.IO.File]::ReadAllBytes($backup)
    $ot  = Find-Targets $old "ProjectDiablo.dll.stock-backup" (Get-PE $old "ProjectDiablo.dll.stock-backup") -Soft
    if (-not $ot -or $ot.Patched -or $old.Length -ne $cur.Length -or $ot.Gate -ne $ct.Gate -or $ot.TableOff -ne $ct.TableOff) {
        Fail ("ProjectDiablo.dll.stock-backup is from a different PD2 version than ProjectDiablo.dll,`n" +
              "          so putting it back would break the game. Get the original DLL back with the`n" +
              "          PD2 launcher instead (on the Season 13 rollback: extract the S13 zip again).")
    }
    Copy-Item $backup $dll -Force
    Ok "restored the original ProjectDiablo.dll"
    Stop-Here 0
}
if (-not (Test-Path $d2c)) { Fail "D2Client.dll not found - needed to locate the panel-draw function." }

# --------------------------------------------------------- ProjectDiablo ----

$b  = [System.IO.File]::ReadAllBytes($dll)
$pe = Get-PE $b "ProjectDiablo.dll"
Info ("file:   {0:N0} bytes, ImageBase 0x{1:X8}" -f $b.Length, $pe.ImageBase)

Write-Host ""
Write-Host "Locating (by signature, not fixed offsets)..." -ForegroundColor Cyan
Info "this takes a few seconds"

$t = Find-Targets $b "ProjectDiablo.dll" $pe
Ok ("-plugy gate       0x{0:X6}" -f $t.Gate)

# Checked before "already patched", so a patch on a build this doesn't know is never
# reported as fine.
if (-not (Test-HookSet $b $t)) {
    $why = "          Its first $S13_PANEL hooks aren't the ones this patch works with on Seasons 13 and 14."
    if ($t.Patched) {
        Write-Host ""
        Write-Host "  ==================================================" -ForegroundColor Yellow
        Write-Host "   PATCHED, BUT THIS PD2 VERSION ISN'T SUPPORTED" -ForegroundColor Yellow
        Write-Host "  ==================================================" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  ProjectDiablo.dll was patched by another version of this script."
        Write-Host $why
        Write-Host ""
        Write-Host "  To undo it, double-click Restore-Original.bat." -ForegroundColor Yellow
        Stop-Here 1
    }
    Fail ("this version of PD2 isn't supported yet.`n$why`n" +
          "          The patch needs updating for it. For stat ranges with PlugY meanwhile,`n" +
          "          roll back to Season 13 (see README).")
}

$upgrading = $false
if ($t.Patched) {
    $ho = RvaToOff $pe ($t.Handler - $pe.ImageBase)
    $isV3 = ($ho -ge 0)
    if ($isV3) { for ($i = 0; $i -lt $V3_HEAD.Length; $i++) { if ($b[$ho + $i] -ne $V3_HEAD[$i]) { $isV3 = $false; break } } }
    # current: this code in the panel slot for this season; on Season 14 only, hiding
    # the mouse from D2's panel draw, gating the stash clicks and PlugY's own button
    # draw, and switching the stash handlers. Versions before 4.0.0 left the Season 14
    # panel hook at entry 35 (and 3.x read the wrong module table there), 4.0.0 had no
    # gates, 5.0.0 no handler switches, the first 6.0.0 test build left PD2's material
    # storage off - upgrade those.
    $s14 = Get-Season14 $b $t
    if ($isV3 -and $t.PanelIndex -eq (Get-Keep $b $t) -and (Test-HidesMouse $b $pe $t.Handler) -eq $s14 -and
        (Test-Gate $b $t 1 $CLICK_CALL) -eq $s14 -and (Test-Gate $b $t 2 $DRAW_CALL) -eq $s14 -and
        (Test-Handlers $b $t) -eq $s14 -and (Test-Materials $b $pe $t) -eq $s14 -and
        [bool]((Find-TabsDraw $b $pe) | Where-Object { $_.Patched }) -eq $s14) {
        Write-Host ""
        Write-Host "  ============================================" -ForegroundColor Green
        Write-Host "   ALREADY PATCHED - nothing to do" -ForegroundColor Green
        Write-Host "  ============================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "  If you still don't see stat ranges, make sure you start the game with" -ForegroundColor DarkGray
        Write-Host "  Launch-PD2-PlugY.bat and that PlugY.ini Param= includes -plugy" -ForegroundColor DarkGray
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
    $bt  = Find-Targets $bb "ProjectDiablo.dll.stock-backup" $bpe
    if ($bt.Patched -or $bb.Length -ne $b.Length -or $bt.TableOff -ne $t.TableOff -or $bt.Gate -ne $t.Gate) {
        Fail ("ProjectDiablo.dll.stock-backup doesn't match this DLL's build.`n" +
              "          Get the original DLL back (PD2 launcher > verify/repair files), then run this again.")
    }
    Ok "starting from ProjectDiablo.dll.stock-backup (original of this build)"
    $b = $bb; $pe = $bpe; $t = $bt
    $upgrading = $true
}
if ($b[$t.Jne] -ne 0x75) { Fail ("unexpected byte 0x{0:X2} at the gate." -f $b[$t.Jne]) }

$origHandler = $t.Handler
Ok ("panel hook entry  0x{0:X6}  handler 0x{1:X8}  (entry {2})" -f $t.Entry, $origHandler, $t.PanelIndex)
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

# 7. Season 14 only: D2's mouse position, read by the panel draw right at its start
#    (mov eax,[MouseX] / mov ecx,[MouseY]). Hidden from that draw so it doesn't print
#    D2's plain tooltip next to PD2's - on Season 14 the two no longer line up.
$hideMouse = Get-Season14 $b $t
if ($hideMouse) {
    $mo = RvaToOff $dpe ($panelRva + 0xF)
    if ($mo -lt 0 -or $dc[$mo] -ne 0xA1 -or $dc[$mo + 5] -ne 0x8B -or $dc[$mo + 6] -ne 0x0D) {
        Fail "D2Client's panel draw doesn't read the mouse position where expected - D2Client.dll isn't the 1.13c build PlugY expects."
    }
    $mouseX = [int64](U32 $dc ($mo + 1)) - $dpe.ImageBase
    $mouseY = [int64](U32 $dc ($mo + 7)) - $dpe.ImageBase
    Ok ("mouse position    D2Client+0x{0:X} / +0x{1:X}" -f $mouseX, $mouseY)
}

# 8. Season 14 only: PD2's own "stash open on the Stash category" check
#      push 19h / call GetUIState / test eax,eax / setne cl / call IsStashTab / ...
#    IsStashTab is "cmp dword [tab],9 / setbe al / ret": PD2's stash tabs 0-9 are its
#    pages, 10 and up the categories down the left (Uniques, Sets, Gems, Runes, ...).
#    PlugY's stash page buttons are drawn and clicked only while it's true.
$gateStash = Get-Season14 $b $t
if ($gateStash) {
    $cat = FindSig $b @(0x6A,0x19, 0xE8,-1,-1,-1,-1, 0x85,0xC0, 0x0F,0x95,0xC1, 0xE8,-1,-1,-1,-1,
                        0x84,0xC0, 0x74,-1, 0x84,0xC9, 0x74,-1, 0xB0,0x01, 0xC3)
    $isStashVa = if ($cat -ge 0) { (OffToVa $pe ($cat + 12)) + 5 + [BitConverter]::ToInt32($b, $cat + 13) } else { -1 }
    $io = if ($isStashVa -ge 0) { RvaToOff $pe ($isStashVa - $pe.ImageBase) } else { -1 }
    if ($io -lt 0 -or $b[$io] -ne 0x83 -or $b[$io + 1] -ne 0x3D -or $b[$io + 6] -ne 0x09 -or
        $b[$io + 7] -ne 0x0F -or $b[$io + 8] -ne 0x96 -or $b[$io + 9] -ne 0xC0 -or $b[$io + 10] -ne 0xC3) {
        Fail "signature 5 (PD2's stash category check) not found in ProjectDiablo.dll."
    }
    Ok ("stash category    0x{0:X8} (PD2's Stash-tab check)" -f $isStashVa)

    # 9. ...and the stash's mouse-down handler in D2Client, around PlugY's button check:
    #      mov eax,ebx / call <hit test> / test eax,eax / je +13h / ...
    #      mov edi,ebx / call <hit test PlugY takes over> / test eax,eax
    $BTN_DOWN_CALL = 0x9B8A5
    $co = RvaToOff $dpe ($CLICK_CALL - 2); $bo = RvaToOff $dpe ($BTN_DOWN_CALL - 2)
    if ($co -lt 0 -or $bo -lt 0 -or $dc[$co] -ne 0x8B -or $dc[$co + 1] -ne 0xC3 -or $dc[$co + 7] -ne 0x85 -or
        $dc[$co + 8] -ne 0xC0 -or $dc[$co + 9] -ne 0x74 -or $dc[$co + 10] -ne ($BTN_DOWN_CALL - 2 - ($CLICK_CALL + 9)) -or
        $dc[$bo] -ne 0x8B -or $dc[$bo + 1] -ne 0xFB -or $dc[$bo + 7] -ne 0x85 -or $dc[$bo + 8] -ne 0xC0) {
        Fail "D2Client's stash click handler isn't as expected - D2Client.dll isn't the 1.13c build PlugY expects."
    }
    $clickHit = DcCallTarget $CLICK_CALL "stash click"
    $btnHit   = DcCallTarget $BTN_DOWN_CALL "stash button click"
    Ok ("stash click call  0x{0:X} (PlugY's button check at 0x{1:X})" -f $CLICK_CALL, $BTN_DOWN_CALL)

    # 10. ...and the stash draw, around the call PlugY takes over to draw its buttons:
    #      push eax / mov byte [flag],4 / call <item draw> / mov [flag],bl / call <buttons>
    $do = RvaToOff $dpe ($DRAW_CALL - 8)
    if ($do -lt 0 -or $dc[$do] -ne 0x50 -or $dc[$do + 1] -ne 0xC6 -or $dc[$do + 2] -ne 0x05 -or $dc[$do + 7] -ne 0x04 -or
        $dc[$do + 13] -ne 0x88 -or $dc[$do + 14] -ne 0x1D -or (U32 $dc ($do + 15)) -ne (U32 $dc ($do + 3)) -or
        $DRAW_CALL + 11 -ne $BTN_CALL) {
        Fail "D2Client's stash draw isn't as expected - D2Client.dll isn't the 1.13c build PlugY expects."
    }
    $itemDraw = DcCallTarget $DRAW_CALL "stash item draw"
    $drawFlag = [int64](U32 $dc ($do + 3)) - $dpe.ImageBase
    Ok ("stash draw call   0x{0:X} (PlugY's buttons at 0x{1:X})" -f $DRAW_CALL, $BTN_CALL)

    # 11. ...and PD2's own stash handlers, each with the D2 handler of its row in D2Client's
    #     stash message table
    $handlers = @()
    foreach ($h in @(Get-StashHandlers $b $t)) {
        $ro  = RvaToOff $dpe ([int64](U32 $b ($h + 4)) - 8)
        $d2h = if ($ro -ge 0) { [int64](U32 $dc ($ro + 8)) - $dpe.ImageBase } else { -1 }
        $pdh = [int64](U32 $b ($h + 8))
        if ($ro -lt 0 -or (RvaToOff $dpe $d2h) -lt 0 -or (RvaToOff $pe ($pdh - $pe.ImageBase)) -lt 0) {
            Fail "PD2's stash handlers don't fit D2Client's stash message table - D2Client.dll isn't the 1.13c build PlugY expects."
        }
        $handlers += [PSCustomObject]@{ Rec = $h; Name = $MSG_NAMES[("{0:X}-{1:X}" -f (U32 $dc $ro), (U32 $dc ($ro + 4)))]; D2 = $d2h; PD2 = $pdh; Label = "" }
    }
    if (-not ($handlers | Where-Object { $_.Name -eq "left click" })) { Fail "signature 6 (PD2's stash left-click handler) not found in ProjectDiablo.dll." }
    Ok ("stash handlers    {0} of PD2's in D2Client+0x{1:X}: {2}" -f $handlers.Count, $STASH_MSGS,
        (($handlers | ForEach-Object { if ($_.Name) { $_.Name } else { "?" } }) -join ", "))

    # their records go in the slots after the panel record, which must hold pointers
    # (relative-call hooks) in PD2's table, so Windows relocates the new ones with the DLL
    foreach ($n in 1..(2 + $handlers.Count)) {
        $gs = $t.TableOff + ((Get-Keep $b $t) + $n) * 20
        if ((RvaToOff $pe ([int64](U32 $b ($gs + 8)) - $pe.ImageBase)) -lt 0 -or (U32 $b ($gs + 12)) -ne 1 -or (U32 $b ($gs + 16)) -ne 0) {
            Fail "hook-table entry $((Get-Keep $b $t) + $n) isn't a call hook in this build - the stash gates can't go there."
        }
    }

    # 12. ...PD2's checks for PlugY around its material storage and its own stash pages,
    # 13. ...and the calls building the paths of its shared-stash and compendium files
    $plugyChecks = @(Get-PlugyChecks $b $pe $t)
    $fileCalls = Get-FileCalls $b $pe
    $pathBuild = @(if ($fileCalls -and $fileCalls.Count -ge 4) { $fileCalls.Values | Sort-Object -Unique })
    if ((($plugyChecks | ForEach-Object { $_.Form }) -join " ") -ne $PLUGY_FORMS -or
        @($plugyChecks | Where-Object { $_.Len -eq 0 -or $_.Off }).Count -gt 0 -or -not (Test-KeptChecks $b $plugyChecks)) {
        Fail "signature 7 (PD2's checks for PlugY around its material storage) not found as expected in ProjectDiablo.dll."
    }
    if ($pathBuild.Count -ne 1 -or -not (Test-FileChecks $b $pe $plugyChecks $fileCalls)) {
        Fail "signature 8 (where PD2 saves its material storage) not found as expected in ProjectDiablo.dll."
    }
    $pathBuild = $pathBuild[0]
    $flagVa = [int64](U32 $b ($t.Gate + 2))
    Ok ("PlugY checks      {0} of PD2's: {1} for its material storage, {2} for its own stash pages" -f
        $plugyChecks.Count, ($plugyChecks.Count - $PLUGY_KEEP.Count), $PLUGY_KEEP.Count)
    Ok ("material files    {0} calls build their path (0x{1:X8})" -f $fileCalls.Count, $pathBuild)

    # 14. ...and where PD2's panel draw decides whether to draw its stash page tabs
    $tabs = Find-TabsDraw $b $pe
    if (-not $tabs -or $tabs.Patched) { Fail "signature 9 (PD2's stash page tabs) not found in ProjectDiablo.dll." }
    Ok ("stash page tabs   0x{0:X8} (PD2's P, I-IX along the top of the stash)" -f (OffToVa $pe $tabs.Site))
}

# ------------------------------------------------------------- the code ----
#
# The panel hook entry is redirected here. Runs, in order:
#   1. D2Client's own panel draw     -> PlugY's stash pages render (it patches inside it)
#   2. PD2's renderer                -> BH stat-range augmentation, PD2's frame
#   3. if the stash is open: PlugY's stash-button routine again, so the buttons
#      land on top of PD2's frame
# On Season 14, step 1 runs with D2's mouse position moved off-screen (and put back
# right after), so D2 draws no tooltip of its own; PD2's renderer draws the real one.
# Step 3 also needs PD2's Stash category, and a second routine (the click gate) takes
# the hit-test call before PlugY's button check in D2's stash mouse-down handler: on
# the other categories it makes that call itself and carries on after PlugY's check,
# exactly as D2 would without PlugY. Clicks on items and the inventory still work.
# A third (the draw gate) does the same for the item-draw call before PlugY's button
# draw in step 1, so on those categories PlugY draws nothing under PD2's frame either.
# Then the handler switches: D2 calls one instead of each D2 stash handler PD2 replaces
# (left click, right click, ...); it runs D2's on the Stash category, PD2's otherwise.
# Then the file switch, which gives PD2's material files their PlugY names, and last
# the tabs check, which hides PD2's stash page tabs under PlugY.
# Position-independent: PD2's module table is addressed relative to this code
# (call $+5 / pop), D2Client through its runtime base, so it survives relocation.

function LE([int64]$v) { [BitConverter]::GetBytes([uint32]$v) }
$prog = @(
    @{ B = @(0x56) }                                                    # push esi
    @{ B = @(0xE8,0,0,0,0, 0x58); Pic = $true }                         # call $+5 / pop eax
    @{ B = @(0x8B,0xB0,0,0,0,0); PicDisp = $true }                      # mov esi,[eax + (modtbl - here)]
)
if ($hideMouse) {
    $prog += @(
        @{ B = @(0xFF,0xB6) + (LE $mouseX) }                            # push dword [esi + MouseX]
        @{ B = @(0xFF,0xB6) + (LE $mouseY) }                            # push dword [esi + MouseY]
        @{ B = @(0xC7,0x86) + (LE $mouseX) + (LE 0x7FFF) }              # mov dword [esi + MouseX], 7FFFh
        @{ B = @(0xC7,0x86) + (LE $mouseY) + (LE 0x7FFF) }              # mov dword [esi + MouseY], 7FFFh
    )
}
$prog += @(
    @{ B = @(0x8D,0x86) + [BitConverter]::GetBytes([uint32]$panelRva) } # lea eax,[esi + panelRva]
    @{ B = @(0xFF,0xD0) }                                               # call eax
)
if ($hideMouse) {
    $prog += @(
        @{ B = @(0x8F,0x86) + (LE $mouseY) }                            # pop dword [esi + MouseY]
        @{ B = @(0x8F,0x86) + (LE $mouseX) }                            # pop dword [esi + MouseX]
    )
}
$prog += @(
    @{ B = @(0xE8,0,0,0,0); To = $origHandler }                         # call PD2 renderer
    @{ B = @(0x83,0xBE) + [BitConverter]::GetBytes([uint32]$uiStashRva) + @(0x00) }  # cmp dword [esi+stash],0
)
if ($gateStash) {
    $prog += @(
        @{ B = @(0x0F,0x84,0,0,0,0); ToLabel = "done" }                 # jz done
        @{ B = @(0xE8,0,0,0,0); To = $isStashVa }                       # call PD2's IsStashTab
        @{ B = @(0x84,0xC0) }                                           # test al,al
    )
}
$prog += @(
    @{ B = @(0x0F,0x85,0,0,0,0); ToLabel = "buttons" }                  # jnz buttons
    @{ B = @(0x5E); Label = "done" }                                    # pop esi
    @{ B = @(0xC3); End = $true }                                       # ret
    @{ B = @(0x8B,0x86) + [BitConverter]::GetBytes([uint32]($BTN_CALL + 1)); Label = "buttons" }   # mov eax,[esi + call operand]
    @{ B = @(0x8D,0x84,0x06) + [BitConverter]::GetBytes([uint32]($BTN_CALL + 5)) }               # lea eax,[esi + eax + next]
    @{ B = @(0x5E) }                                                    # pop esi
    @{ B = @(0xFF,0xE0); End = $true }                                  # jmp eax (PlugY's routine)
)
# The click gate, called instead of D2's hit test (eax = y, esi = x, ebx = y). Its
# return address is the "test eax,eax" after that call; on a category other than
# Stash it returns past PlugY's call instead, with what D2's own target returns.
if ($gateStash) {
    $prog += @(
        @{ B = @(0xE8,0,0,0,0, 0x59); Pic = $true; Label = "click" }    # call $+5 / pop ecx
        @{ B = @(0x8B,0x89,0,0,0,0); PicDisp = $true }                  # mov ecx,[ecx + (modtbl - here)]
        @{ B = @(0x81,0xC1) + (LE $clickHit) }                          # add ecx, <D2's hit test>
        @{ B = @(0xFF,0xD1) }                                           # call ecx
        @{ B = @(0x85,0xC0) }                                           # test eax,eax
        @{ B = @(0x0F,0x85,0,0,0,0); ToLabel = "clickret" }             # jnz clickret (D2 takes the click)
        @{ B = @(0xE8,0,0,0,0); To = $isStashVa }                       # call PD2's IsStashTab
        @{ B = @(0x84,0xC0) }                                           # test al,al
        @{ B = @(0x0F,0x84,0,0,0,0); ToLabel = "noplugy" }              # jz noplugy
        @{ B = @(0x33,0xC0) }                                           # xor eax,eax (on to PlugY's check)
        @{ B = @(0xC3); End = $true; Label = "clickret" }               # ret
        @{ B = @(0x8B,0xFB); Label = "noplugy" }                        # mov edi,ebx (as D2 does next)
        @{ B = @(0xE8,0,0,0,0, 0x59); Pic = $true }                     # call $+5 / pop ecx
        @{ B = @(0x8B,0x89,0,0,0,0); PicDisp = $true }                  # mov ecx,[ecx + (modtbl - here)]
        @{ B = @(0x81,0xC1) + (LE $btnHit) }                            # add ecx, <D2's target of PlugY's call>
        @{ B = @(0xFF,0xD1) }                                           # call ecx
        @{ B = @(0x83,0x04,0x24, ($BTN_DOWN_CALL - $CLICK_CALL)) }      # add dword [esp], <past PlugY's call>
        @{ B = @(0xC3); End = $true }                                   # ret
    )
}
# The draw gate, called instead of D2's stash item draw (one argument, which it pops;
# bl = the flag byte D2 puts back next). On the Stash category it just jumps there.
# Otherwise it calls it, does what D2 does next except PlugY's call - puts the flag
# back and calls D2's own target of that call - and returns past PlugY's call.
if ($gateStash) {
    $prog += @(
        @{ B = @(0xE8,0,0,0,0, 0x59); Pic = $true; Label = "draw" }     # call $+5 / pop ecx
        @{ B = @(0x8B,0x89,0,0,0,0); PicDisp = $true }                  # mov ecx,[ecx + (modtbl - here)]
        @{ B = @(0x50) }                                                # push eax
        @{ B = @(0xE8,0,0,0,0); To = $isStashVa }                       # call PD2's IsStashTab
        @{ B = @(0x84,0xC0) }                                           # test al,al
        @{ B = @(0x58) }                                                # pop eax
        @{ B = @(0x0F,0x84,0,0,0,0); ToLabel = "nobuttons" }            # jz nobuttons
        @{ B = @(0x81,0xC1) + (LE $itemDraw) }                          # add ecx, <D2's item draw>
        @{ B = @(0xFF,0xE1); End = $true }                              # jmp ecx (then on to PlugY's call, as before)
        @{ B = @(0x51); Label = "nobuttons" }                           # push ecx (D2Client base)
        @{ B = @(0xFF,0x74,0x24,0x08) }                                 # push dword [esp+8] (the argument again)
        @{ B = @(0x8D,0x91) + (LE $itemDraw) }                          # lea edx,[ecx + <D2's item draw>]
        @{ B = @(0xFF,0xD2) }                                           # call edx
        @{ B = @(0x59) }                                                # pop ecx
        @{ B = @(0x88,0x99) + (LE $drawFlag) }                          # mov [ecx + flag],bl (as D2 does next)
        @{ B = @(0x81,0xC1) + (LE $btnTarget) }                         # add ecx, <D2's target of PlugY's call>
        @{ B = @(0xFF,0xD1) }                                           # call ecx
        @{ B = @(0x83,0x04,0x24, ($BTN_CALL + 5 - ($DRAW_CALL + 5))) }  # add dword [esp], <past PlugY's call>
        @{ B = @(0xC2,0x04,0x00); End = $true }                         # ret 4
    )
}
# The handler switches, called by D2 in place of a stash handler, with the message as the
# one argument (on the stack, left as it is). Rows whose handlers are the same share one.
if ($gateStash) {
    $switches = @{}
    foreach ($h in $handlers) {
        $key = "{0:X}-{1:X}" -f $h.D2, $h.PD2
        if (-not $switches.ContainsKey($key)) {
            $n = $switches.Count; $switches[$key] = "msg$n"
            $prog += @(
                @{ B = @(0xE8,0,0,0,0); To = $isStashVa; Label = "msg$n" }          # call PD2's IsStashTab
                @{ B = @(0x84,0xC0) }                                               # test al,al
                @{ B = @(0x0F,0x84,0,0,0,0); ToLabel = "pd2msg$n" }                 # jz pd2msg
                @{ B = @(0xB8) + (LE $h.D2) }                                       # mov eax, <D2's handler>
                @{ B = @(0xE9,0,0,0,0); ToLabel = "d2msg"; End = $true }            # jmp d2msg
                @{ B = @(0xE9,0,0,0,0); To = $h.PD2; Label = "pd2msg$n"; End = $true }   # jmp <PD2's handler>
            )
        }
        $h.Label = $switches[$key]
    }
    $prog += @(
        @{ B = @(0xE8,0,0,0,0, 0x59); Pic = $true; Label = "d2msg" }    # call $+5 / pop ecx
        @{ B = @(0x8B,0x89,0,0,0,0); PicDisp = $true }                  # mov ecx,[ecx + (modtbl - here)]
        @{ B = @(0x03,0xC1) }                                           # add eax,ecx
        @{ B = @(0xFF,0xE0); End = $true }                              # jmp eax (D2's handler)
    )
}
# The file switch, called instead of PD2's path builder where it builds the path of its
# shared-stash and compendium files (the name is its one argument on the stack): under
# PlugY it moves the name 4 characters on, past "pd2_", then goes on to the path builder.
if ($gateStash) {
    $prog += @(
        @{ B = @(0xE8,0,0,0,0, 0x58); Pic = $true; Label = "files" }    # call $+5 / pop eax
        @{ B = @(0x80,0xB8,0,0,0,0, 0x00); PicDisp = $true; PicAddr = $flagVa }   # cmp byte [eax + (PlugY flag - here)],0
        @{ B = @(0x0F,0x84,0,0,0,0); ToLabel = "path" }                 # jz path
        @{ B = @(0x83,0x44,0x24,0x04,0x04) }                            # add dword [esp+4],4 (the name, past "pd2_")
        @{ B = @(0xE9,0,0,0,0); To = $pathBuild; Label = "path"; End = $true }   # jmp <PD2's path builder>
    )
}
# The tabs check, called in place of the panel draw's "cmp dword [esp+24h],0", whose jne
# then skips the tabs on nonzero: so set, or under PlugY. Leaves eax as it was; ret and
# pop keep the flags.
if ($gateStash) {
    $prog += @(
        @{ B = @(0x83,0x7C,0x24,0x28,0x00); Label = "tabs" }            # cmp dword [esp+28h],0 (its [esp+24h])
        @{ B = @(0x0F,0x85,0,0,0,0); ToLabel = "tabsret" }              # jnz tabsret (skipped, as before)
        @{ B = @(0x50) }                                                # push eax
        @{ B = @(0xE8,0,0,0,0, 0x58); Pic = $true }                     # call $+5 / pop eax
        @{ B = @(0x80,0xB8,0,0,0,0, 0x00); PicDisp = $true; PicAddr = $flagVa }   # cmp byte [eax + (PlugY flag - here)],0
        @{ B = @(0x58) }                                                # pop eax
        @{ B = @(0xC3); End = $true; Label = "tabsret" }                # ret
    )
}

# code caves: runs of int3 padding inside the mapped part of .text
$text = $pe.Sections | Where-Object { $_.Name -eq ".text" }
if (-not $text) { Fail "no .text section in ProjectDiablo.dll." }
$MIN_CAVE = ($prog | ForEach-Object { $_.B.Count } | Measure-Object -Maximum).Maximum + 5   # longest instruction + link jump
$caves = New-Object System.Collections.ArrayList
$run = 0; $start = -1
$endRaw = $text.RawPtr + [Math]::Min($text.RawSize, $text.VSize)
for ($i = $text.RawPtr; $i -lt $endRaw; $i++) {
    if ($b[$i] -eq 0xCC) { if ($run -eq 0) { $start = $i }; $run++ }
    else {
        if ($run -ge $MIN_CAVE) { [void]$caves.Add(@{ Off = $start; Len = $run }); if ($caves.Count -ge 128) { break } }
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
    while ($need -gt $left) {
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
    if ($ins.PicDisp) {                                                             # the module table, or PicAddr
        $pa = if ($ins.PicAddr) { $ins.PicAddr } else { $t.ModTbl }
        [Array]::Copy([BitConverter]::GetBytes([int32]($pa - $picBase)), 0, $bytes, 2, 4)
    }
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
# the panel hook record {module, offset, handler, relative, size} with our code as
# handler, right after the kept hooks: entry 14 on Season 13 (where it already is),
# entry 13 on Season 14 (moved up from 35, in place of entry 13)
$keep = Get-Keep $b $t
$panelSlot = $t.TableOff + $keep * 20
$rec = [byte[]]$b[$t.Entry..($t.Entry + 19)]
[Array]::Copy([BitConverter]::GetBytes([uint32]$codeVa), 0, $rec, 8, 4)
Emit $panelSlot $rec
if ($t.PanelIndex -ne $keep) {
    Ok ("panel hook moved from entry {0} to {1} (entry 13 and the {2} new hooks stay off)" -f $t.PanelIndex, $keep, ($t.PanelIndex - $S13_PANEL))
}
Ok ("panel handler 0x{0:X8} -> 0x{1:X8}" -f $origHandler, $codeVa)
$endSlot = $panelSlot + 20
if ($gateStash) {
    # the two gates as more records, in slots that held pointers too (so they're relocated)
    foreach ($g in @(@("click", $CLICK_CALL, "stash clicks    "), @("draw", $DRAW_CALL, "stash buttons   "))) {
        $gva = VaOf $labels[$g[0]]
        Emit $endSlot ([byte[]]((LE 0) + (LE ($g[1] + 1)) + (LE $gva) + (LE 1) + (LE 0)))
        Ok ("{0}  D2Client+0x{1:X} -> 0x{2:X8} (PlugY's buttons on the Stash category only)" -f $g[2], $g[1], $gva)
        $endSlot += 20
    }
    # PD2's stash handler records, each with its switch as the handler
    foreach ($h in $handlers) {
        $rec = [byte[]]$b[$h.Rec..($h.Rec + 19)]
        [Array]::Copy((LE (VaOf $labels[$h.Label])), 0, $rec, 8, 4)
        Emit $endSlot $rec
        $endSlot += 20
    }
    Ok ("stash handlers    {0} switched -> 0x{1:X8}.. (PD2's on the categories, D2's and PlugY's on Stash)" -f $handlers.Count, (VaOf $labels["msg0"]))
    # PD2's material storage on under PlugY: its checks' jumps become nops...
    for ($i = 0; $i -lt $plugyChecks.Count; $i++) {
        if ($i -notin $PLUGY_KEEP) { Emit $plugyChecks[$i].Jne ([byte[]](@(0x90) * $plugyChecks[$i].Len)) }
    }
    Ok ("PlugY checks      {0} jumps -> nops (PD2's material storage on under PlugY; its stash pages stay PlugY's)" -f
        ($plugyChecks.Count - $PLUGY_KEEP.Count))
    # ...and its files get their PlugY names, through the file switch
    $fva = VaOf $labels["files"]
    foreach ($k in $fileCalls.Keys) { Emit ($k + 1) (Rel32 ((VaOf $k) + 5) $fva) }
    Ok ("material files    {0} calls -> 0x{1:X8} (under PlugY: Save\shared.stash, shared.compendium, hc_...)" -f $fileCalls.Count, $fva)
    # ...and PD2's stash page tabs are hidden under PlugY, through the tabs check
    $tva = VaOf $labels["tabs"]
    Emit $tabs.Site ([byte[]](@(0xE8) + (Rel32 ((VaOf $tabs.Site) + 5) $tva)))
    Ok ("stash page tabs   0x{0:X8} -> 0x{1:X8} (PD2's P, I-IX hidden under PlugY)" -f (VaOf $tabs.Site), $tva)
}
Emit $endSlot ([BitConverter]::GetBytes([uint32]0x1B))
if ($keep -eq $S13_PANEL) { Ok ("hook table ends after entry {0} - the {1} hooks tested on Season 13" -f $keep, ($keep + 1)) }
else { Ok ("hook table ends after entry {0} - Season 13's hooks minus the call PlugY hooks (0x4437C), then the stash gates and switches" -f (($endSlot - $t.TableOff) / 20 - 1)) }

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
Write-Host "  PlugY.ini Param= must include  -plugy   (testing mode: Launch-PD2-PlugY (testing).bat)"
Write-Host ""
Write-Host "  Hover an item - you should see green [min - max] ranges, Max Sockets"
Write-Host "  and the upgrade recipe. PlugY's stash page buttons now draw on top."
if ($gateStash) {
    Write-Host "  (Only on PD2's Stash category - not on Gems, Runes and the others,"
    Write-Host "  which are PD2's own again: put gems, runes, ... in there. With PlugY,"
    Write-Host "  PD2 keeps them in Save\shared.stash, not in its pd2_shared.stash.)"
}
Write-Host ""
Write-Host "  Re-run this after every PD2 update (the launcher restores the DLL)."
Write-Host ""
Write-Host "  SINGLE PLAYER ONLY - do not use on the PD2 online realm." -ForegroundColor Yellow
Stop-Here 0
