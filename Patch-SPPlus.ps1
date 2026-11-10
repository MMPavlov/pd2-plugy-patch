<#
    Patch-SPPlus.ps1   v1.1.0   (version-independent)

    Fixes the "(old)" runes and gems of the PD2 Single Player Plus mod on Season 14.

    Season 14 merged PD2's stacked and unstacked runes and gems: El Rune (r01) is now
    the stackable one, and the Season 13 stacks (r01s, gpws, ...) are kept only as
    "El Rune (old)", "Perfect Diamond (old)", ... - they don't stack with the new ones,
    don't go into the stash's Runes / Gems tabs and don't socket. The Single Player
    Plus mod's pd2data.mpq (v14.0.1, v14.0.2) still drops and makes those old items:
      - monsters drop old runes (its Runes 1-17 treasure classes),
      - the rune downgrade recipes give old runes (in 14.0.1 the gem boxes give old
        gems too),
      - the crafting infusions and the higher rune downgrades ask for old runes and
        gems (in 14.0.1 the rainbow facets too), so new ones don't work in them.
    This rewrites those to the Season 14 items, in the mod's TreasureClassEx and
    CubeMain (both the .txt and the compiled .bin the game loads). Testing mode
    (-direct -txt) writes compiled copies to data\global\excel and reads those
    instead; copies that are the mod's original get the same fix. Recipes that ask
    for old items and already have a Season 14 twin are left as they are, so old
    runes you already have can still go down into new ones there. So are recipes
    that turn an old item into its Season 14 item (14.0.2 has them for the old
    perfect gems). Nothing else in the mod changes.

    Which items are "old" is read from the mod's own data (PD2's names that end in
    "(old)"), and every compiled record is checked against its .txt row first. If
    anything doesn't match, it stops and changes nothing. A compiled table may have
    records after the last .txt row (14.0.2's cubemain.bin has 10 recipes that its
    CubeMain.txt doesn't); those get the fix in the compiled table only.

    SINGLE PLAYER ONLY. Not related to PlugY - works with or without it.

    EASIEST WAY TO RUN IT
      Double-click Run-SPPlus-Patch.bat (next to this file).

    OR, from a PowerShell window:
      .\Patch-SPPlus.ps1              # patch (re-run after every mod update)
      .\Patch-SPPlus.ps1 -Restore     # undo
      .\Patch-SPPlus.ps1 -Path "D:\PD2"
#>

[CmdletBinding()]
param([string]$Path, [switch]$Restore, [switch]$NoPause)

$ErrorActionPreference = "Stop"

$VERSION = "1.1.0"   # bump on every change - see CHANGELOG-SPPlus.md

# Keep the window open at the end so the result can actually be read.
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

trap {
    Write-Host ""
    Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Stop-Here 1
}

if (-not $Path) { $Path = $PSScriptRoot }
if (-not $Path) { $Path = (Get-Location).Path }
$Path = (Resolve-Path -LiteralPath $Path).ProviderPath.TrimEnd('\')

$mpq    = Join-Path $Path "pd2data.mpq"
$backup = Join-Path $Path "pd2data.mpq.stock-backup"

Write-Host ""
Write-Host "PD2 Single Player Plus fix  v$VERSION" -ForegroundColor Cyan
Write-Host "------------------------------------------------"
Info "folder: $Path"

if (-not (Test-Path $mpq)) {
    Fail ("pd2data.mpq not found in this folder.`n" +
          "          Put this script in your Project Diablo 2 folder (the one with`n" +
          "          pd2data.mpq and ProjectDiablo.dll), or run it with -Path <folder>.")
}
if (Get-Process -Name "Game" -ErrorAction SilentlyContinue) {
    Write-Host ""
    Write-Host "  >>> DIABLO II IS RUNNING <<<" -ForegroundColor Yellow
    Write-Host "  Close the game completely, then run this again." -ForegroundColor Yellow
    Write-Host "  (Windows locks pd2data.mpq while the game is open.)" -ForegroundColor Yellow
    Write-Host "  Nothing was changed." -ForegroundColor Yellow
    Stop-Here 1
}

# A game folder under Program Files can only be changed with administrator rights.
function Test-Writable {
    try {
        $probe = Join-Path $Path ("pd2-spplus-patch-{0}.tmp" -f [guid]::NewGuid().ToString("N").Substring(0, 8))
        [IO.File]::WriteAllBytes($probe, [byte[]]@())
        Remove-Item -LiteralPath $probe -Force
        [IO.File]::Open($mpq, 'Open', 'ReadWrite', 'Read').Close()
        return $true
    } catch [UnauthorizedAccessException] { return $false }
}
if (-not (Test-Writable)) {
    $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
                 [Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($admin) {
        Fail ("Windows won't let this change pd2data.mpq, even as administrator.`n" +
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

# ------------------------------------------------------------- MPQ reader ----
# pd2data.mpq is a classic (version 0) MPQ archive: encrypted hash and block tables,
# files split in sectors compressed with PKWARE "implode" (or zlib). This reads it,
# and writes changed files back uncompressed at the end of a copy of the archive.

if (-not ('SpPlus.Mpq' -as [type])) {
Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Text;

namespace SpPlus {
public class Mpq {
    static readonly uint[] CT = BuildCryptTable();
    static uint[] BuildCryptTable() {
        uint[] t = new uint[0x500]; uint seed = 0x00100001;
        unchecked {
            for (int i = 0; i < 0x100; i++) {
                for (int k = 0, j = i; k < 5; k++, j += 0x100) {
                    seed = (seed * 125 + 3) % 0x2AAAAB; uint a = (seed & 0xFFFF) << 16;
                    seed = (seed * 125 + 3) % 0x2AAAAB; uint b = seed & 0xFFFF;
                    t[j] = a | b;
                }
            }
        }
        return t;
    }
    public static uint Hash(string s, int type) {
        uint s1 = 0x7FED7FED, s2 = 0xEEEEEEEE;
        unchecked {
            foreach (char ch in s.Replace('/', '\\')) {
                uint c = (uint)(byte)ch;
                if (c >= 'a' && c <= 'z') c -= 0x20;
                s1 = CT[(type << 8) + (int)c] ^ (s1 + s2);
                s2 = c + s1 + s2 + (s2 << 5) + 3;
            }
        }
        return s1;
    }
    static void Crypt(byte[] d, int off, int len, uint key, bool encrypt) {
        uint s2 = 0xEEEEEEEE;
        unchecked {
            for (int i = off; i + 4 <= off + len; i += 4) {
                s2 += CT[0x400 + (key & 0xFF)];
                uint raw = BitConverter.ToUInt32(d, i), v = raw ^ (key + s2);
                Put32(d, i, v);
                uint plain = encrypt ? raw : v;
                key = ((~key << 0x15) + 0x11111111) | (key >> 0x0B);
                s2 = plain + s2 + (s2 << 5) + 3;
            }
        }
    }
    static void Put32(byte[] d, int o, uint v) { d[o] = (byte)v; d[o+1] = (byte)(v >> 8); d[o+2] = (byte)(v >> 16); d[o+3] = (byte)(v >> 24); }
    static uint U32(byte[] d, int o) { return BitConverter.ToUInt32(d, o); }
    static byte[] Slice(byte[] d, long o, long n) {
        if (o < 0 || n < 0 || o + n > d.Length) throw new Exception("the archive is cut short or damaged");
        byte[] r = new byte[n]; Array.Copy(d, o, r, 0, n); return r;
    }

    public readonly byte[] Data;
    public readonly int ArchiveSize, HashPos, BlockPos, HashCount, BlockCount, SectorSize;
    readonly uint[] hashes, blocks;    // decrypted: 4 words per entry
    readonly byte[] hashRaw;           // the hash table as stored

    public Mpq(byte[] data) {
        Data = data;
        if (data.Length < 0x20 || U32(data, 0) != 0x1A51504D) throw new Exception("pd2data.mpq isn't an MPQ archive");
        ArchiveSize = (int)U32(data, 8);
        int version = BitConverter.ToUInt16(data, 12);
        SectorSize = 512 << BitConverter.ToUInt16(data, 14);
        HashPos = (int)U32(data, 16); BlockPos = (int)U32(data, 20);
        HashCount = (int)U32(data, 24); BlockCount = (int)U32(data, 28);
        if (version != 0) throw new Exception("pd2data.mpq is MPQ format version " + version + ", only version 0 is supported");
        if (ArchiveSize > data.Length) throw new Exception("pd2data.mpq is cut short");
        hashRaw = Slice(data, HashPos, (long)HashCount * 16);
        byte[] h = (byte[])hashRaw.Clone(); Crypt(h, 0, h.Length, Hash("(hash table)", 3), false);
        byte[] b = Slice(data, BlockPos, (long)BlockCount * 16); Crypt(b, 0, b.Length, Hash("(block table)", 3), false);
        hashes = new uint[HashCount * 4]; Buffer.BlockCopy(h, 0, hashes, 0, h.Length);
        blocks = new uint[BlockCount * 4]; Buffer.BlockCopy(b, 0, blocks, 0, b.Length);
    }

    public int Find(string name) {
        if (HashCount == 0) return -1;
        uint i = Hash(name, 0) % (uint)HashCount, a = Hash(name, 1), b = Hash(name, 2);
        for (int n = 0; n < HashCount; n++) {
            uint blk = hashes[i * 4 + 3];
            if (blk == 0xFFFFFFFF) return -1;
            if (hashes[i * 4] == a && hashes[i * 4 + 1] == b && blk != 0xFFFFFFFE) return blk < BlockCount ? (int)blk : -1;
            i = (i + 1) % (uint)HashCount;
        }
        return -1;
    }
    public bool Has(string name) { return Find(name) >= 0; }

    public byte[] Read(string name) {
        int blk = Find(name);
        if (blk < 0) throw new Exception(name + " isn't in pd2data.mpq");
        uint off = blocks[blk * 4], csz = blocks[blk * 4 + 1], usz = blocks[blk * 4 + 2], fl = blocks[blk * 4 + 3];
        if ((fl & 0x80000000) == 0) throw new Exception(name + " is deleted in pd2data.mpq");
        uint key = 0; bool enc = (fl & 0x10000) != 0;
        if (enc) {
            key = Hash(name.Substring(name.LastIndexOfAny(new char[] { '\\', '/' }) + 1), 3);
            if ((fl & 0x20000) != 0) unchecked { key = (key + off) ^ usz; }
        }
        if ((fl & 0x01000000) != 0) {                          // stored as one unit
            byte[] one = Slice(Data, off, csz);
            if (enc) Crypt(one, 0, one.Length, key, false);
            if (csz >= usz) return one;
            return (fl & 0x200) != 0 ? Decompress(one, (int)usz, name) : Explode(one, 0, one.Length, (int)usz);
        }
        if ((fl & 0x300) == 0) {                               // not compressed
            byte[] raw = Slice(Data, off, usz);
            if (enc) Crypt(raw, 0, raw.Length, key, false);
            return raw;
        }
        int ns = (int)((usz + SectorSize - 1) / SectorSize);
        byte[] tab = Slice(Data, off, (ns + 1) * 4);
        if (enc) unchecked { Crypt(tab, 0, tab.Length, key - 1, false); }
        byte[] outb = new byte[usz];
        int pos = 0;
        for (int s = 0; s < ns; s++) {
            uint so = U32(tab, s * 4), se = U32(tab, s * 4 + 4);
            if (se < so) throw new Exception(name + " has a damaged sector table");
            byte[] sec = Slice(Data, (long)off + so, se - so);
            if (enc) unchecked { Crypt(sec, 0, sec.Length, key + (uint)s, false); }
            int want = Math.Min(SectorSize, (int)usz - pos);
            byte[] d = sec.Length == want ? sec
                     : (fl & 0x200) != 0 ? Decompress(sec, want, name) : Explode(sec, 0, sec.Length, want);
            if (d.Length != want) throw new Exception(name + " didn't unpack to the right size");
            Array.Copy(d, 0, outb, pos, want); pos += want;
        }
        return outb;
    }

    static byte[] Decompress(byte[] sec, int want, string name) {
        byte mask = sec[0];
        if (mask == 0x08) return Explode(sec, 1, sec.Length - 1, want);
        if (mask == 0x02) {
            using (var ms = new MemoryStream(sec, 3, sec.Length - 3))       // skip mask + 2-byte zlib header
            using (var z = new DeflateStream(ms, CompressionMode.Decompress))
            using (var o = new MemoryStream()) { z.CopyTo(o); return o.ToArray(); }
        }
        throw new Exception(name + " uses a compression this script doesn't read (0x" + mask.ToString("X2") + ")");
    }

    // A copy of the archive with these files replaced. The new contents go after the
    // original archive, stored plainly (no compression, no encryption), then the hash
    // table (unchanged) and the block table pointing at them.
    public byte[] Rebuild(System.Collections.IDictionary repl) {
        uint[] nb = (uint[])blocks.Clone();
        using (var ms = new MemoryStream()) {
            ms.Write(Data, 0, ArchiveSize);
            foreach (System.Collections.DictionaryEntry kv in repl) {
                string name = (string)kv.Key; byte[] v = (byte[])kv.Value;
                int blk = Find(name);
                if (blk < 0) throw new Exception(name + " isn't in pd2data.mpq");
                nb[blk * 4] = (uint)ms.Length; nb[blk * 4 + 1] = (uint)v.Length;
                nb[blk * 4 + 2] = (uint)v.Length; nb[blk * 4 + 3] = 0x80000000;
                ms.Write(v, 0, v.Length);
            }
            long hpos = ms.Length; ms.Write(hashRaw, 0, hashRaw.Length);
            byte[] bt = new byte[nb.Length * 4]; Buffer.BlockCopy(nb, 0, bt, 0, bt.Length);
            Crypt(bt, 0, bt.Length, Hash("(block table)", 3), true);
            long bpos = ms.Length; ms.Write(bt, 0, bt.Length);
            byte[] o = ms.ToArray();
            Put32(o, 8, (uint)o.Length); Put32(o, 16, (uint)hpos); Put32(o, 20, (uint)bpos);
            return o;
        }
    }

    // PKWARE Data Compression Library "explode", after Mark Adler's blast.c.
    static readonly byte[] LitLen = {
        11, 124, 8, 7, 28, 7, 188, 13, 76, 4, 10, 8, 12, 10, 12, 10, 8, 23, 8,
        9, 7, 6, 7, 8, 7, 6, 55, 8, 23, 24, 12, 11, 7, 9, 11, 12, 6, 7, 22, 5,
        7, 24, 6, 11, 9, 6, 7, 22, 7, 11, 38, 7, 9, 8, 25, 11, 8, 11, 9, 12,
        8, 12, 5, 38, 5, 38, 5, 11, 7, 5, 6, 21, 6, 10, 53, 8, 7, 24, 10, 27,
        44, 253, 253, 253, 252, 252, 252, 13, 12, 45, 12, 45, 12, 61, 12, 45,
        44, 173 };
    static readonly byte[] LenLen = { 2, 35, 36, 53, 38, 23 };
    static readonly byte[] DistLen = { 2, 20, 53, 230, 247, 151, 248 };
    static readonly int[] LenBase = { 3, 2, 4, 5, 6, 7, 8, 9, 10, 12, 16, 24, 40, 72, 136, 264 };
    static readonly int[] LenExtra = { 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8 };
    const int MaxBits = 13;
    class Huff { public int[] Count = new int[MaxBits + 1]; public int[] Sym; }
    static Huff Construct(byte[] rep) {
        var len = new List<int>();
        foreach (byte b in rep) for (int n = (b >> 4) + 1; n > 0; n--) len.Add(b & 15);
        var h = new Huff(); h.Sym = new int[len.Count];
        foreach (int l in len) h.Count[l]++;
        int[] offs = new int[MaxBits + 2];
        for (int l = 1; l < MaxBits; l++) offs[l + 1] = offs[l] + h.Count[l];
        for (int s = 0; s < len.Count; s++) if (len[s] != 0) h.Sym[offs[len[s]]++] = s;
        return h;
    }
    static readonly Huff HLit = Construct(LitLen), HLen = Construct(LenLen), HDist = Construct(DistLen);
    class BitReader {
        readonly byte[] d; int p; readonly int end; int buf, cnt;
        public BitReader(byte[] d, int p, int n) { this.d = d; this.p = p; end = p + n; }
        public int Bit() {
            if (cnt == 0) { if (p >= end) throw new Exception("compressed data ended early"); buf = d[p++]; cnt = 8; }
            int b = buf & 1; buf >>= 1; cnt--; return b;
        }
        public int Bits(int n) { int v = 0; for (int i = 0; i < n; i++) v |= Bit() << i; return v; }
        public int Decode(Huff h) {
            int code = 0, first = 0, index = 0;
            for (int l = 1; l <= MaxBits; l++) {
                code |= Bit() ^ 1;
                int c = h.Count[l];
                if (code < first + c) return h.Sym[index + code - first];
                index += c; first += c; first <<= 1; code <<= 1;
            }
            throw new Exception("bad compressed data");
        }
    }
    public static byte[] Explode(byte[] src, int off, int n, int want) {
        var br = new BitReader(src, off, n);
        int lit = br.Bits(8), dict = br.Bits(8);
        if (lit > 1 || dict < 4 || dict > 6) throw new Exception("bad compressed data header");
        byte[] o = new byte[want]; int pos = 0;
        while (true) {
            if (br.Bit() != 0) {
                int sym = br.Decode(HLen);
                int len = LenBase[sym] + br.Bits(LenExtra[sym]);
                if (len == 519) break;
                int sh = len == 2 ? 2 : dict;
                int dist = (br.Decode(HDist) << sh) + br.Bits(sh) + 1;
                if (dist > pos || pos + len > want) throw new Exception("bad compressed data");
                for (int i = 0; i < len; i++, pos++) o[pos] = o[pos - dist];
            } else {
                if (pos >= want) throw new Exception("bad compressed data");
                o[pos++] = (byte)(lit != 0 ? br.Decode(HLit) : br.Bits(8));
            }
        }
        if (pos != want) throw new Exception("compressed data unpacked to the wrong size");
        return o;
    }

    // Diablo II .tbl string table: key -> text.
    public static Dictionary<string, string> ReadTbl(byte[] d) {
        var r = new Dictionary<string, string>();
        int n = BitConverter.ToUInt16(d, 2), hn = (int)U32(d, 4);
        int ho = 21 + 2 * n;
        for (int i = 0; i < hn; i++) {
            int e = ho + i * 17;
            if (d[e] == 0) continue;
            string k = CStr(d, (int)U32(d, e + 7), 256), v = CStr(d, (int)U32(d, e + 11), 4096);
            if (!r.ContainsKey(k)) r[k] = v;
        }
        return r;
    }
    public static bool Same(byte[] a, byte[] b) {
        if (a.Length != b.Length) return false;
        for (int i = 0; i < a.Length; i++) if (a[i] != b[i]) return false;
        return true;
    }
    public static string CStr(byte[] d, int o, int max) {
        int e = o; while (e < d.Length && e < o + max && d[e] != 0) e++;
        return Encoding.GetEncoding(28591).GetString(d, o, e - o);
    }
}
}
'@
}

# ------------------------------------------------------------- the fix ----

$EXCEL = "data\global\excel\"
$TC_BIN = $EXCEL + "treasureclassex.bin"; $TC_TXT = $EXCEL + "TreasureClassEx.txt"
$CM_BIN = $EXCEL + "cubemain.bin";        $CM_TXT = $EXCEL + "CubeMain.txt"
$TBL    = "data\local\LNG\ENG\patchstring.tbl"
$LATIN1 = [Text.Encoding]::GetEncoding(28591)

# record layouts of Diablo II 1.13 compiled tables (the first DWORD is the count)
$ITEM_REC = 0x1A8; $ITEM_CODE = 0x80                       # weapons/armor/misc.bin
$TC_ITEM = 0x38; $TC_ITEM_LEN = 0x40; $TC_ITEMS = 10        # treasureclassex.bin: Item1-10
$CM_REC = 0x148; $CM_IN = 0x14; $CM_INS = 7; $CM_OUT = 0x4C; $CM_OUT_LEN = 0x54; $CM_OUTS = 3
$CM_TXT_OUT = @("output", "output b", "output c")

function U16([byte[]]$a, [int]$o) { [BitConverter]::ToUInt16($a, $o) }
function U32([byte[]]$a, [int]$o) { [BitConverter]::ToUInt32($a, $o) }
function Put16([byte[]]$a, [int]$o, [int]$v) { $a[$o] = $v -band 0xFF; $a[$o + 1] = ($v -shr 8) -band 0xFF }

# Records of a compiled table; stops if the file isn't count + count * $size bytes.
function Get-RecCount([byte[]]$bin, [int]$size, [string]$what) {
    $n = U32 $bin 0
    if ($bin.Length -ne 4 + $n * $size) { Fail "$what doesn't have the expected layout ($($bin.Length) bytes for $n records)." }
    $n
}

# A tab-separated table, split into lines (each keeping its own line ending) and the
# header's column positions. Rows = the non-empty lines after the header, one per record.
function Read-Txt([byte[]]$raw, [string]$what) {
    $lines = $LATIN1.GetString($raw).Split("`n")
    $cols = @{}; $i = 0
    foreach ($c in $lines[0].TrimEnd("`r").Split("`t")) { if (-not $cols.ContainsKey($c)) { $cols[$c] = $i }; $i++ }
    $rows = New-Object System.Collections.Generic.List[int]
    for ($k = 1; $k -lt $lines.Length; $k++) { if ($lines[$k].TrimEnd("`r") -ne "") { $rows.Add($k) } }
    [PSCustomObject]@{ Lines = $lines; Cols = $cols; Rows = $rows; What = $what }
}
function Get-Fields($t, [int]$row) { , $t.Lines[$t.Rows[$row]].TrimEnd("`r").Split("`t") }
function Set-Fields($t, [int]$row, [string[]]$f) {
    $cr = if ($t.Lines[$t.Rows[$row]].EndsWith("`r")) { "`r" } else { "" }
    $t.Lines[$t.Rows[$row]] = ($f -join "`t") + $cr
}
function Get-Col($t, [string]$name) {
    if (-not $t.Cols.ContainsKey($name)) { Fail "$($t.What) has no '$name' column." }
    $t.Cols[$name]
}
# item code at the start of a cube field: "r10s,qty=10" / "`"r10s,qty=10`"" -> r10s
function CodeOf([string]$f) { $f.Trim().Trim('"').Split(',')[0].Trim() }
function Swap-Code([string]$f, [string]$from, [string]$to) {
    [regex]::Replace($f, '^(\s*"?\s*)' + [regex]::Escape($from) + '(?=\s*(,|"|$))', '${1}' + $to)
}

function Mismatch([string]$m) { [PSCustomObject]@{ Error = $m } }

# Item codes in the order item indexes count them (weapons, armor, misc), and the old
# items: PD2 names them "... (old)"; each is its Season 14 item's code + "s".
# (item codes are case-sensitive, so no PowerShell hashtables for them)
function Get-Items($m) {
    $codes = New-Object System.Collections.Generic.List[string]
    foreach ($n in "weapons", "armor", "misc") {
        $bin = $m.Read($EXCEL + "$n.bin")
        $cnt = Get-RecCount $bin $ITEM_REC "$n.bin"
        for ($i = 0; $i -lt $cnt; $i++) { $codes.Add($LATIN1.GetString($bin, 4 + $i * $ITEM_REC + $ITEM_CODE, 4).TrimEnd(' ', [char]0)) }
    }
    $index = New-Object 'System.Collections.Generic.Dictionary[string,int]'
    for ($i = 0; $i -lt $codes.Count; $i++) { if (-not $index.ContainsKey($codes[$i])) { $index[$codes[$i]] = $i } }

    $names = [SpPlus.Mpq]::ReadTbl($m.Read($TBL))
    $newOf = New-Object 'System.Collections.Generic.Dictionary[string,string]'
    $newIdx = New-Object 'System.Collections.Generic.Dictionary[int,int]'
    foreach ($c in $codes) {
        if ($c.Length -eq 4 -and $c.EndsWith("s") -and $index.ContainsKey($c.Substring(0, 3)) -and
            $names.ContainsKey($c) -and $names[$c].TrimEnd().EndsWith("(old)")) {
            $newOf[$c] = $c.Substring(0, 3)
            $newIdx[$index[$c]] = $index[$c.Substring(0, 3)]
        }
    }
    [PSCustomObject]@{ Codes = $codes; Index = $index; NewOf = $newOf; NewIdx = $newIdx }
}

# The two Repair functions swap the old items for their Season 14 items in a compiled
# table and in its text, both in place. Every record is first checked against its text
# row. The table may have records after the text's last row (it was compiled from a
# longer text); those are changed in the table only. They return the counts, or
# .Error = what doesn't match (then the table and the text are not to be used).

# TreasureClassEx: Item1-10 are 64-byte strings.
function Repair-Tc([byte[]]$tcb, $tct, $items) {
    $newOf = $items.NewOf
    $tcN = [int](U32 $tcb 0)
    $tcRec = if ($tcN -gt 0) { [int][math]::Floor(($tcb.Length - 4) / $tcN) } else { 0 }
    if ($tcN -eq 0 -or $tcb.Length -ne 4 + $tcN * $tcRec -or $tcRec -lt $TC_ITEM + $TC_ITEMS * $TC_ITEM_LEN) {
        return (Mismatch "treasureclassex.bin doesn't have the expected layout.")
    }
    $txtRows = $tct.Rows.Count
    if ($txtRows -gt $tcN) { return (Mismatch "TreasureClassEx.txt has $txtRows rows but treasureclassex.bin only $tcN - they don't match.") }
    $itemCols = 1..$TC_ITEMS | ForEach-Object { Get-Col $tct "Item$_" }
    $tcFix = 0; $txtFix = 0
    for ($r = 0; $r -lt $tcN; $r++) {
        $f = $null; if ($r -lt $txtRows) { $f = Get-Fields $tct $r }
        $changed = $false
        for ($k = 0; $k -lt $TC_ITEMS; $k++) {
            $o = 4 + $r * $tcRec + $TC_ITEM + $k * $TC_ITEM_LEN
            $inBin = [SpPlus.Mpq]::CStr($tcb, $o, $TC_ITEM_LEN)
            if ($r -lt $txtRows) {
                $inTxt = if ($itemCols[$k] -lt $f.Length) { $f[$itemCols[$k]] } else { "" }
                if ($inBin -cne $inTxt) { return (Mismatch "treasureclassex.bin row $r Item$($k + 1) is '$inBin' but the .txt says '$inTxt' - they don't match.") }
            }
            if ($newOf.ContainsKey($inBin)) {
                $new = [byte[]]::new($TC_ITEM_LEN)
                $LATIN1.GetBytes($newOf[$inBin]).CopyTo($new, 0)
                [Array]::Copy($new, 0, $tcb, $o, $TC_ITEM_LEN)
                if ($r -lt $txtRows) {
                    $f[$itemCols[$k]] = Swap-Code $f[$itemCols[$k]] $inBin $newOf[$inBin]
                    $changed = $true; $txtFix++
                }
                $tcFix++
            }
        }
        if ($changed) { Set-Fields $tct $r $f }
    }
    [PSCustomObject]@{ Error = $null; Changes = $tcFix; TxtChanges = $txtFix; Extra = $tcN - $txtRows }
}

# CubeMain: inputs {WORD flags, WORD item, ...} (flag 1 = that exact item),
#           outputs {BYTE, BYTE, WORD item, ...}
function Repair-Cube([byte[]]$cmb, $cmt, $items) {
    $codes = $items.Codes; $index = $items.Index; $newOf = $items.NewOf; $newIdx = $items.NewIdx
    $cmN = [int](U32 $cmb 0)
    if ($cmb.Length -ne 4 + $cmN * $CM_REC) { return (Mismatch "cubemain.bin doesn't have the expected layout ($($cmb.Length) bytes for $cmN records).") }
    $txtRows = $cmt.Rows.Count
    if ($txtRows -gt $cmN) { return (Mismatch "CubeMain.txt has $txtRows rows but cubemain.bin only $cmN - they don't match.") }
    $inCols  = 1..$CM_INS | ForEach-Object { Get-Col $cmt "input $_" }
    $outCols = $CM_TXT_OUT | ForEach-Object { Get-Col $cmt $_ }

    # each record's old-item slots, checked against its .txt row
    $oldIn = @{}; $oldOut = @{}
    for ($r = 0; $r -lt $cmN; $r++) {
        $f = $null; if ($r -lt $txtRows) { $f = Get-Fields $cmt $r }
        $base = 4 + $r * $CM_REC
        for ($k = 0; $k -lt $CM_INS; $k++) {
            $o = $base + $CM_IN + $k * 8; $it = [int](U16 $cmb ($o + 2))
            $binOld = ((U16 $cmb $o) -band 1) -and $newIdx.ContainsKey($it)
            if ($r -lt $txtRows) {
                $txt = if ($inCols[$k] -lt $f.Length) { CodeOf $f[$inCols[$k]] } else { "" }
                if ($binOld -ne $newOf.ContainsKey($txt) -or ($binOld -and $codes[$it] -cne $txt)) {
                    return (Mismatch "cubemain.bin row $r input $($k + 1) doesn't match the .txt ('$txt').")
                }
            }
            if ($binOld) { $oldIn["$r/$k"] = $codes[$it] }
        }
        for ($k = 0; $k -lt $CM_OUTS; $k++) {
            $o = $base + $CM_OUT + $k * $CM_OUT_LEN + 2; $it = [int](U16 $cmb $o)
            $binOld = $newIdx.ContainsKey($it)
            if ($r -lt $txtRows) {
                $txt = if ($outCols[$k] -lt $f.Length) { CodeOf $f[$outCols[$k]] } else { "" }
                if ($binOld -ne $newOf.ContainsKey($txt) -or ($binOld -and $codes[$it] -cne $txt)) {
                    return (Mismatch "cubemain.bin row $r $($CM_TXT_OUT[$k]) doesn't match the .txt ('$txt').")
                }
            }
            if ($binOld) { $oldOut["$r/$k"] = $codes[$it] }
        }
    }

    # A record with every old item swapped for its Season 14 item.
    function Get-Swapped([int]$r) {
        $x = [byte[]]::new($CM_REC); [Array]::Copy($cmb, 4 + $r * $CM_REC, $x, 0, $CM_REC)
        for ($k = 0; $k -lt $CM_INS; $k++) {
            $o = $CM_IN + $k * 8; $it = [int](U16 $x ($o + 2))
            if (((U16 $x $o) -band 1) -and $newIdx.ContainsKey($it)) { Put16 $x ($o + 2) $newIdx[$it] }
        }
        for ($k = 0; $k -lt $CM_OUTS; $k++) {
            $o = $CM_OUT + $k * $CM_OUT_LEN + 2; $it = [int](U16 $x $o)
            if ($newIdx.ContainsKey($it)) { Put16 $x $o $newIdx[$it] }
        }
        , $x
    }
    $hasOldIn = @{}; foreach ($key in $oldIn.Keys) { $hasOldIn[[int]$key.Split('/')[0]] = $true }
    # recipes that take no old items, as they'll be once their outputs are swapped
    $s14 = New-Object 'System.Collections.Generic.HashSet[string]'
    for ($r = 0; $r -lt $cmN; $r++) {
        if (-not $hasOldIn.ContainsKey($r)) { [void]$s14.Add([Convert]::ToBase64String((Get-Swapped $r))) }
    }

    # outputs: always the Season 14 item. Inputs: the Season 14 item, unless
    #  - that recipe already exists for Season 14 items: then this one stays for the old
    #    items, or
    #  - the recipe turns an old item into its Season 14 item (one of its results is an
    #    old ingredient's new item): swapping would leave "new item -> the same item".
    $cmOut = 0; $cmIn = 0; $cmKept = 0; $cmConv = 0; $txtFix = 0; $touch = @{}
    foreach ($key in $oldOut.Keys) { $touch[[int]$key.Split('/')[0]] = $true }
    foreach ($r in $hasOldIn.Keys) { $touch[$r] = $true }
    foreach ($r in $touch.Keys) {
        $base = 4 + $r * $CM_REC
        $f = $null; if ($r -lt $txtRows) { $f = Get-Fields $cmt $r }
        $keepIn = $false
        if ($hasOldIn.ContainsKey($r)) {
            $sw = Get-Swapped $r
            if ($s14.Contains([Convert]::ToBase64String($sw))) { $keepIn = $true; $cmKept++ }
            else {
                for ($k = 0; $k -lt $CM_INS -and -not $keepIn; $k++) {
                    if (-not $oldIn.ContainsKey("$r/$k")) { continue }
                    $want = [int](U16 $sw ($CM_IN + $k * 8 + 2))
                    for ($j = 0; $j -lt $CM_OUTS; $j++) {
                        if ([int](U16 $sw ($CM_OUT + $j * $CM_OUT_LEN + 2)) -eq $want) { $keepIn = $true }
                    }
                }
                if ($keepIn) { $cmConv++ }
            }
        }
        for ($k = 0; $k -lt $CM_OUTS; $k++) {
            if (-not $oldOut.ContainsKey("$r/$k")) { continue }
            $o = $base + $CM_OUT + $k * $CM_OUT_LEN + 2; $old = $oldOut["$r/$k"]
            Put16 $cmb $o $index[$newOf[$old]]
            if ($r -lt $txtRows) { $f[$outCols[$k]] = Swap-Code $f[$outCols[$k]] $old $newOf[$old]; $txtFix++ }
            $cmOut++
        }
        if (-not $keepIn) {
            for ($k = 0; $k -lt $CM_INS; $k++) {
                if (-not $oldIn.ContainsKey("$r/$k")) { continue }
                $o = $base + $CM_IN + $k * 8 + 2; $old = $oldIn["$r/$k"]
                Put16 $cmb $o $index[$newOf[$old]]
                if ($r -lt $txtRows) { $f[$inCols[$k]] = Swap-Code $f[$inCols[$k]] $old $newOf[$old]; $txtFix++ }
                $cmIn++
            }
        }
        if ($r -lt $txtRows) { Set-Fields $cmt $r $f }
    }
    [PSCustomObject]@{
        Error = $null; Changes = $cmOut + $cmIn; TxtChanges = $txtFix; Extra = $cmN - $txtRows
        Out = $cmOut; In = $cmIn; Kept = $cmKept; Conv = $cmConv
    }
}

# Everything this fixes in one copy of pd2data.mpq. Returns the changed files and counts.
function Get-Fix([byte[]]$data, [string]$label) {
    $m = [SpPlus.Mpq]::new($data)
    foreach ($need in @($TC_BIN, $TC_TXT, $CM_BIN, $CM_TXT, $TBL, ($EXCEL + "weapons.bin"), ($EXCEL + "armor.bin"), ($EXCEL + "misc.bin"))) {
        if (-not $m.Has($need)) { Fail "$label has no $need - this isn't PD2's data archive." }
    }
    $items = Get-Items $m

    $tcb = $m.Read($TC_BIN); $tct = Read-Txt $m.Read($TC_TXT) "TreasureClassEx.txt"
    $tc = Repair-Tc $tcb $tct $items
    if ($tc.Error) { Fail $tc.Error }
    $cmb = $m.Read($CM_BIN); $cmt = Read-Txt $m.Read($CM_TXT) "CubeMain.txt"
    $cm = Repair-Cube $cmb $cmt $items
    if ($cm.Error) { Fail $cm.Error }

    $files = New-Object System.Collections.Specialized.OrderedDictionary ([StringComparer]::OrdinalIgnoreCase)
    if ($tc.Changes -gt 0) {
        $files[$TC_BIN] = $tcb
        if ($tc.TxtChanges -gt 0) { $files[$TC_TXT] = $LATIN1.GetBytes($tct.Lines -join "`n") }
    }
    if ($cm.Changes -gt 0) {
        $files[$CM_BIN] = $cmb
        if ($cm.TxtChanges -gt 0) { $files[$CM_TXT] = $LATIN1.GetBytes($cmt.Lines -join "`n") }
    }
    [PSCustomObject]@{
        Mpq = $m; Files = $files; Items = $items; OldItems = $items.NewOf.Count
        Runes = @($items.NewOf.Keys | Where-Object { $_ -match '^r\d\ds$' }).Count
        Tc = $tc.Changes; CubeOut = $cm.Out; CubeIn = $cm.In; CubeKept = $cm.Kept; CubeConv = $cm.Conv
        Extra = @{ $TC_BIN = $tc.Extra; $CM_BIN = $cm.Extra }
    }
}

# Every file the archive lists, read back from $new, equals $old's - except the
# replaced ones, which must equal their new contents.
function Test-Rebuilt($old, [byte[]]$newData, $files) {
    $n = [SpPlus.Mpq]::new($newData)
    $list = @()
    if ($old.Has("(listfile)")) {
        $list = $LATIN1.GetString($old.Read("(listfile)")).Split("`r`n;".ToCharArray(), [StringSplitOptions]::RemoveEmptyEntries)
    }
    $names = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($name in @($list) + @($files.Keys)) { if ($old.Has($name)) { [void]$names.Add($name) } }
    foreach ($name in $names) {
        $want = if ($files.Contains($name)) { [byte[]]$files[$name] } else { $old.Read($name) }
        if (-not [SpPlus.Mpq]::Same($n.Read($name), $want)) { Fail "the rebuilt archive gives a different $name - not written." }
    }
    $names.Count
}

# Is $now (nothing left to fix) this script's patch of the backup? Patching the backup
# again has to give exactly the files in $now. Returns the backup's fix, or $null.
function Get-PatchOfBackup($now) {
    if (-not (Test-Path $backup)) { return $null }
    $was = Get-Fix ([IO.File]::ReadAllBytes($backup)) "pd2data.mpq.stock-backup"
    if ($was.Files.Count -eq 0) { return $null }
    foreach ($name in $was.Files.Keys) {
        if (-not [SpPlus.Mpq]::Same($now.Mpq.Read($name), [byte[]]$was.Files[$name])) { return $null }
    }
    $was
}

# Loose copies of the tables in data\global\excel. The game writes them there when it's
# started with -txt (testing mode), and from then on reads them instead of pd2data.mpq.
# A loose copy that's the mod's original gets the same fix (backed up as
# <file>.stock-backup); any other version is left alone, with a warning.
#
# The game compiles those copies from the text files. Where the mod's own compiled table
# has records its text doesn't (14.0.2's cubemain.bin), the game's copy can't equal the
# mod's. There a compiled copy is recognised by checking it against the text instead.
$TXT_OF = @{ $TC_BIN = $TC_TXT; $CM_BIN = $CM_TXT }

# The fix run on a copy of the compiled table $b, against the text $txt.
function Invoke-Repair([string]$name, [byte[]]$b, [byte[]]$txt, $items) {
    $bin = [byte[]]$b.Clone()
    $r = if ($name -eq $TC_BIN) { Repair-Tc $bin (Read-Txt $txt "TreasureClassEx.txt") $items }
         else { Repair-Cube $bin (Read-Txt $txt "CubeMain.txt") $items }
    $r | Add-Member -NotePropertyName Bin -NotePropertyValue $bin
    $r
}
function Test-FromText($fix, [string]$name) { $TXT_OF.ContainsKey($name) -and $fix.Extra[$name] -gt 0 }

# What the fix makes of the loose copy $b of $name, or $null if $b isn't the mod's.
function Get-LooseFix($fix, [string]$name, [byte[]]$b) {
    if ([SpPlus.Mpq]::Same($b, $fix.Mpq.Read($name))) { return , ([byte[]]$fix.Files[$name]) }
    if (-not (Test-FromText $fix $name)) { return $null }
    $r = Invoke-Repair $name $b ($fix.Mpq.Read($TXT_OF[$name])) $fix.Items
    if ($r.Error -or $r.Changes -eq 0) { return $null }
    , $r.Bin
}
# Is the loose copy $b a table the game compiled from the fixed text?
function Test-LooseFixed($fix, [string]$name, [byte[]]$b) {
    if (-not (Test-FromText $fix $name)) { return $false }
    $t = $TXT_OF[$name]; $txt = $null
    if ($fix.Files.Contains($t)) { $txt = [byte[]]$fix.Files[$t] } else { $txt = $fix.Mpq.Read($t) }
    $r = Invoke-Repair $name $b $txt $fix.Items
    (-not $r.Error) -and $r.Changes -eq 0
}

function Update-Loose($fix) {
    $changed = 0
    foreach ($name in $fix.Files.Keys) {
        $loose = Join-Path $Path $name
        if (-not (Test-Path -LiteralPath $loose)) { continue }
        $short = $name.Substring($name.IndexOf("excel\") + 6)
        $b = [IO.File]::ReadAllBytes($loose)
        if ([SpPlus.Mpq]::Same($b, [byte[]]$fix.Files[$name])) { Ok "loose copy data\global\excel\$short is patched too"; continue }
        $new = Get-LooseFix $fix $name $b
        if ($null -eq $new) {
            if (Test-LooseFixed $fix $name $b) {
                Ok "loose copy data\global\excel\$short has the fix too (the game compiled it from the patched text)"
                continue
            }
            Write-Host ("  [!] data\global\excel\$short is a different version from the mod's, so it's left as is.`n" +
                        "      The game reads it instead of pd2data.mpq - move it out of that folder to use the fix.") -ForegroundColor Yellow
            continue
        }
        Copy-Item -LiteralPath $loose "$loose.stock-backup" -Force
        [IO.File]::WriteAllBytes($loose, $new)
        Ok "patched the loose copy data\global\excel\$short (testing mode reads it first)"
        $changed++
    }
    $changed
}
# Puts back the loose copies Update-Loose changed: those that are the fix of their backup.
function Restore-Loose($fix) {
    foreach ($name in $fix.Files.Keys) {
        $loose = Join-Path $Path $name
        if (-not (Test-Path -LiteralPath $loose) -or -not (Test-Path -LiteralPath "$loose.stock-backup")) { continue }
        $want = Get-LooseFix $fix $name ([IO.File]::ReadAllBytes("$loose.stock-backup"))
        if ($null -eq $want -or -not [SpPlus.Mpq]::Same([IO.File]::ReadAllBytes($loose), $want)) { continue }
        Copy-Item -LiteralPath "$loose.stock-backup" $loose -Force
        Ok "restored the loose copy data\global\excel\$($name.Substring($name.IndexOf("excel\") + 6))"
    }
}

# ------------------------------------------------------------- restore ----

$cur = [IO.File]::ReadAllBytes($mpq)
Info ("pd2data.mpq: {0:N0} bytes" -f $cur.Length)

if ($Restore) {
    if (-not (Test-Path $backup)) { Fail "no backup found at pd2data.mpq.stock-backup" }
    $now = Get-Fix $cur "pd2data.mpq"
    if ($now.Files.Count -gt 0) {
        Ok "pd2data.mpq isn't patched - nothing to restore."
        Info "(A mod update replaces it with an unpatched one, so this is normal after an update.)"
        Stop-Here 0
    }
    # Only put the backup back over a patched copy of the same file.
    $was = Get-PatchOfBackup $now
    if (-not $was) {
        Fail ("pd2data.mpq.stock-backup is from a different version of the mod than pd2data.mpq,`n" +
              "          so putting it back would mix them up. Reinstall the mod's pd2data.mpq instead.")
    }
    Copy-Item $backup $mpq -Force
    Ok "restored the original pd2data.mpq"
    Restore-Loose $was
    Stop-Here 0
}

# ------------------------------------------------------------------ patch ----

Write-Host ""
Write-Host "Checking the mod's data..." -ForegroundColor Cyan
$fix = Get-Fix $cur "pd2data.mpq"
if ($fix.Files.Count -eq 0) {
    Write-Host ""
    $was = Get-PatchOfBackup $fix
    if ($was) {
        Ok "pd2data.mpq is patched"
        if ((Update-Loose $was) -gt 0) {
            Write-Host ""
            Write-Host "  ============================================" -ForegroundColor Green
            Write-Host "   PATCHED (the loose copies)" -ForegroundColor Green
            Write-Host "  ============================================" -ForegroundColor Green
            Write-Host ""
            Write-Host "  Monsters and the cube now give Season 14 runes and gems in testing mode too."
            Write-Host "  (Use -Restore / Restore-SPPlus.bat to undo.)" -ForegroundColor DarkGray
            Stop-Here 0
        }
        Write-Host ""
        Write-Host "  ============================================" -ForegroundColor Green
        Write-Host "   ALREADY PATCHED - nothing to do" -ForegroundColor Green
        Write-Host "  ============================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Monsters and the cube give Season 14 runes and gems." -ForegroundColor DarkGray
        Write-Host "  (Use -Restore / Restore-SPPlus.bat to undo.)" -ForegroundColor DarkGray
        Stop-Here 0
    }
    Ok "nothing to fix: this pd2data.mpq doesn't drop or make `"(old)`" items."
    Info "(It's probably PD2's own data, or a version of the mod that already fixed this.)"
    Stop-Here 0
}
Ok ("{0} `"(old)`" items in the data ({1} runes, {2} gems and skulls)" -f $fix.OldItems, $fix.Runes, ($fix.OldItems - $fix.Runes))
Ok ("treasure classes: {0} drops of old items" -f $fix.Tc)
Ok ("cube: {0} recipe results and {1} ingredients are old items" -f $fix.CubeOut, $fix.CubeIn)
if ($fix.CubeKept -gt 0) { Info ("{0} recipes for old items that already exist for Season 14 items stay for the old ones" -f $fix.CubeKept) }
if ($fix.CubeConv -gt 0) { Info ("{0} recipes that turn old items into their Season 14 items stay as they are" -f $fix.CubeConv) }
if ($fix.Extra[$CM_BIN] -gt 0) {
    Info ("cubemain.bin has {0} recipes that CubeMain.txt doesn't (the mod is built that way)." -f $fix.Extra[$CM_BIN])
    Info "Those get the fix in cubemain.bin only. Testing mode builds its recipes from the text, so it doesn't have them."
}
if ($fix.Extra[$TC_BIN] -gt 0) {
    Info ("treasureclassex.bin has {0} treasure classes that TreasureClassEx.txt doesn't; those get the fix there only." -f $fix.Extra[$TC_BIN])
}

$new = $fix.Mpq.Rebuild($fix.Files)
$n = Test-Rebuilt $fix.Mpq $new $fix.Files
Ok ("rebuilt archive checked: all {0} files read back as intended" -f $n)
$again = Get-Fix $new "the rebuilt pd2data.mpq"
if ($again.Files.Count -ne 0) { Fail "the rebuilt archive still has old items to fix - not written." }

Write-Host ""
Write-Host "Patching..." -ForegroundColor Cyan
Copy-Item $mpq $backup -Force
Ok "backed up original -> pd2data.mpq.stock-backup"
[IO.File]::WriteAllBytes($mpq, $new)
Ok ("wrote pd2data.mpq ({0:N0} bytes)" -f $new.Length)
[void](Update-Loose $fix)

Write-Host ""
Write-Host "  ============================================" -ForegroundColor Green
Write-Host "   PATCHED" -ForegroundColor Green
Write-Host "  ============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Monsters and the cube's recipes now give Season 14 runes and gems."
Write-Host "  Old runes and gems you already have stay old; they still work in the"
Write-Host "  rune upgrade recipes and in the old-item downgrades (which now give new runes)."
Write-Host ""
Write-Host "  Re-run this after updating the mod. To undo: Restore-SPPlus.bat" -ForegroundColor DarkGray
Stop-Here 0
