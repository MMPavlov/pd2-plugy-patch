<#
    PD2-Diag.ps1

    A report for PlugY start-up errors such as "EXCEPTION_ACCESS_VIOLATION" or
    "Read process memory failed". Put PD2-Diag.bat and this file in Diablo II\ProjectD2
    (next to Game.exe and PlugY.exe), close the game, and double-click PD2-Diag.bat.
    It writes PD2-diag.txt in that folder and opens it. The report lists file paths,
    program and Windows versions and the antivirus' name; the Windows user name,
    profile folder and computer name in it are replaced by %USERNAME%, %USERPROFILE%
    and %COMPUTERNAME%. It reads no saves, passwords or personal files.

    It changes no files and no settings. What it reads: the game's .exe/.dll files
    (sizes, dates, hashes, header fields), PlugY.ini, the end of PlugY.log and D2's
    own log, Windows compatibility and exploit-protection settings for Game.exe and
    PlugY.exe, the antivirus Windows knows about, and Game.exe/PlugY.exe crashes in the
    Application event log of the last 3 days.

    The last part starts Game.exe three times the way PlugY.exe does (as its debugger,
    with PlugY's command line), records where D2gfx.dll loads, whether PlugY.exe would
    accept it, and the first access violation if there is one, and closes Game.exe
    again. If D2gfx.dll is accepted, Game.exe is closed before any of the game's own
    code runs. -NoTrace skips this part.

    USAGE
      Double-click PD2-Diag.bat
      .\PD2-Diag.ps1 [-Path <PD2 folder>] [-Out <report file>] [-NoTrace]
                     [-StopAtD2gfx] [-Runs 3] [-TimeoutSec 20]
      -StopAtD2gfx closes Game.exe at the D2gfx.dll check even when PlugY.exe
      wouldn't accept it, so none of the game's code ever runs.
#>
[CmdletBinding()]
param([string]$Path, [switch]$NoTrace, [switch]$TraceOnly, [switch]$StopAtD2gfx,
      [string]$Exe = "Game.exe", [int]$Runs = 3, [int]$TimeoutSec = 20, [string]$Out)

$ErrorActionPreference = "Continue"
$VERSION = "6.2.0"   # bump on every change - see CHANGELOG.md
if (-not $Path) { $Path = $PSScriptRoot }
if (-not $Path) { $Path = (Get-Location).Path }
$Path = $Path.TrimEnd('\')

function Get-IniValue([string]$ini, [string]$section, [string]$key) {
    if (-not (Test-Path -LiteralPath $ini)) { return $null }
    $cur = ""
    foreach ($line in [IO.File]::ReadAllLines($ini)) {
        $t = $line.Trim()
        if ($t -match '^\[([^\]]*)\]') { $cur = $Matches[1].Trim(); continue }
        if ($cur -eq $section -and $t -match ('^' + [regex]::Escape($key) + '\s*=(.*)$')) { return $Matches[1].Trim() }
    }
    ""
}

# The command line PlugY.exe gives Game.exe: <folder>\Game.exe [-w] <its own arguments> <Param=>.
# Launch-PD2-PlugY.bat 6.1.0 passes -plugy when Param= lacks it.
function Get-PlugyCommandArgs {
    $ini = Join-Path $Path "PlugY.ini"
    $param = Get-IniValue $ini "LAUNCHING" "Param"
    $win = Get-IniValue $ini "WINDOWED" "ActiveWindowed"
    $a = ""
    if ($win -and $win -ne "0") { $a += " -w" }
    if (-not (@("$param" -split '\s+') -ccontains "-plugy")) { $a += " -plugy" }
    $a += " " + "$param"
    $a.TrimStart()
}

$traceSource = @"
using System; using System.Text; using System.Collections.Generic; using System.Runtime.InteropServices;
public static class PlugYTrace {
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
  struct STARTUPINFO { public int cb; public string lpReserved, lpDesktop, lpTitle; public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags; public short wShowWindow, cbReserved2; public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError; }
  [StructLayout(LayoutKind.Sequential)]
  struct PROCESS_INFORMATION { public IntPtr hProcess, hThread; public int dwProcessId, dwThreadId; }
  [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
  static extern bool CreateProcessW(string app, StringBuilder cmd, IntPtr pa, IntPtr ta, bool inherit, uint flags, IntPtr env, string dir, ref STARTUPINFO si, out PROCESS_INFORMATION pi);
  [DllImport("kernel32.dll")] static extern bool WaitForDebugEvent(IntPtr ev, uint ms);
  [DllImport("kernel32.dll")] static extern bool ContinueDebugEvent(int pid, int tid, uint status);
  [DllImport("kernel32.dll", SetLastError=true)] static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, int size, out IntPtr read);
  [DllImport("kernel32.dll")] static extern bool TerminateProcess(IntPtr h, uint code);
  [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] static extern uint GetFinalPathNameByHandleW(IntPtr h, StringBuilder sb, uint cap, uint flags);

  class Mod { public uint Base, Size, HdrBase; public string Name; }

  static byte[] Read(IntPtr h, uint addr, int n, out int err) {
    var b = new byte[n]; IntPtr got;
    err = 0;
    if (!ReadProcessMemory(h, (IntPtr)unchecked((int)addr), b, n, out got) || (int)got < n) { err = Marshal.GetLastWin32Error(); if (err == 0) err = -1; return null; }
    return b;
  }
  static Mod AddModule(IntPtr h, IntPtr hFile, uint b, List<Mod> mods) {
    var m = new Mod { Base = b, Name = "?" };
    if (hFile != IntPtr.Zero) {
      var sb = new StringBuilder(1024);
      if (GetFinalPathNameByHandleW(hFile, sb, 1024, 0) > 0) { m.Name = sb.ToString(); if (m.Name.StartsWith(@"\\?\")) m.Name = m.Name.Substring(4); }
    }
    int err; var hdr = Read(h, b, 0x400, out err);
    if (hdr != null) {
      int o = BitConverter.ToInt32(hdr, 0x3C);
      if (o > 0 && o + 0x60 < 0x400) { m.HdrBase = BitConverter.ToUInt32(hdr, o + 24 + 28); m.Size = BitConverter.ToUInt32(hdr, o + 24 + 56); }
    }
    mods.Add(m); return m;
  }
  static string Where(uint a, List<Mod> mods) {
    foreach (var m in mods) if (m.Size > 0 && a >= m.Base && a < m.Base + m.Size) return System.IO.Path.GetFileName(m.Name) + "+" + (a - m.Base).ToString("X");
    return "not in a loaded module";
  }
  static readonly uint[] Sums = { 0x1743E, 0x1F6C4, 0x1F0B2, 0x1BE5C, 0x18542 };

  static bool Accepted;
  // Returns true when PlugY.exe would stop debugging here (installed, or its own error box).
  // Accepted = it would install PlugY without an error.
  static bool CheckD2gfx(IntPtr h, uint b, List<string> log) {
    Accepted = false;
    int err; var hdr = Read(h, b, 0x300, out err);
    log.Add(string.Format("D2gfx.dll loaded at {0:X8} (PlugY wants 6FA80000)", b));
    if (hdr == null) { log.Add("  can't read its header (error " + err + "). PlugY.exe can't either, so it doesn't install PlugY"); return false; }
    int o = BitConverter.ToInt32(hdr, 0x3C);
    if (o + 0x5C >= 0x300) { log.Add("  odd header, PlugY.exe doesn't recognize it"); return false; }
    uint ib = BitConverter.ToUInt32(hdr, o + 24 + 28), soi = BitConverter.ToUInt32(hdr, o + 24 + 56), ck = BitConverter.ToUInt32(hdr, o + 24 + 64);
    log.Add(string.Format("  header in memory: ImageBase {0:X8}, SizeOfImage {1:X}, CheckSum {2:X}", ib, soi, ck));
    bool ok = (ib == 0x6FA80000 && soi == 0x21000 && Array.IndexOf(Sums, ck) >= 0) || ((ib == 0x6FAA0000 || ib == 0x6FA70000) && soi == 0x21000 && ck == 0);
    if (!ok) { log.Add("  PlugY.exe does NOT recognize this D2gfx.dll: it doesn't install PlugY, stays attached, and shows EXCEPTION_ACCESS_VIOLATION at the game's next access violation"); return false; }
    if (ck != 0x1BE5C) { log.Add("  recognized, but not 1.13c (PD2 uses 1.13c)"); return true; }
    var c1 = Read(h, b + 0xB423, 6, out err); var c2 = Read(h, b + 0xB3CA, 6, out err);
    bool r1 = c1 != null && c1[0] == 0xFF && c1[1] == 0x15 && BitConverter.ToUInt32(c1, 2) == b + 0xD11C;
    bool r2 = c2 != null && c2[0] == 0xFF && c2[1] == 0x15 && BitConverter.ToUInt32(c2, 2) == b + 0xD12C;
    if (c1 != null) log.Add(string.Format("  LoadLibrary call at +B423: {0}", BitConverter.ToString(c1)));
    if (r1 && r2) { Accepted = true; log.Add("  PlugY.exe accepts it: it installs PlugY here and lets go, so this start would NOT give EXCEPTION_ACCESS_VIOLATION"); }
    else log.Add("  PlugY.exe would stop with 'Read process memory failed' here (the code isn't what it expects at this address)");
    return true;
  }

  public static List<string> Run(string dir, string exe, string args, int timeoutMs, bool stopAtD2gfx) {
    var log = new List<string>();
    if (!dir.EndsWith("\\")) dir += "\\";
    var cmd = new StringBuilder(dir + exe + (args.Length > 0 ? " " + args : ""), 2048);
    log.Add("command line: " + cmd);
    var si = new STARTUPINFO(); si.cb = Marshal.SizeOf(si);
    PROCESS_INFORMATION pi;
    if (!CreateProcessW(null, cmd, IntPtr.Zero, IntPtr.Zero, false, 1 /*DEBUG_PROCESS, as PlugY.exe*/, IntPtr.Zero, dir, ref si, out pi)) {
      log.Add("CreateProcess failed, error " + Marshal.GetLastWin32Error()); return log;
    }
    IntPtr ev = Marshal.AllocHGlobal(256);
    var mods = new List<Mod>();
    var sw = System.Diagnostics.Stopwatch.StartNew();
    bool done = false, exited = false, sawGfx = false, accepted = false; int nexc = 0;
    int lastPid = 0, lastTid = 0; bool pending = false;
    try {
      while (!done && sw.ElapsedMilliseconds < timeoutMs) {
        if (!WaitForDebugEvent(ev, 500)) continue;
        int code = Marshal.ReadInt32(ev, 0); lastPid = Marshal.ReadInt32(ev, 4); lastTid = Marshal.ReadInt32(ev, 8); pending = true;
        switch (code) {
          case 3: { IntPtr hf = Marshal.ReadIntPtr(ev, 12); AddModule(pi.hProcess, hf, (uint)Marshal.ReadInt32(ev, 24), mods); if (hf != IntPtr.Zero) CloseHandle(hf); break; }
          case 6: {
            IntPtr hf = Marshal.ReadIntPtr(ev, 12);
            var m = AddModule(pi.hProcess, hf, (uint)Marshal.ReadInt32(ev, 16), mods);
            if (hf != IntPtr.Zero) CloseHandle(hf);
            if (!sawGfx && m.Name.EndsWith("\\D2gfx.dll", StringComparison.OrdinalIgnoreCase)) {
              sawGfx = true;
              if (CheckD2gfx(pi.hProcess, m.Base, log)) { accepted = Accepted; log.Add("  closing " + exe + " now, before the game's own code runs"); done = true; }
              else if (stopAtD2gfx) { log.Add("  closing " + exe + " now (-StopAtD2gfx)"); done = true; }
            }
            break; }
          case 1: {
            uint ex = (uint)Marshal.ReadInt32(ev, 12), at = (uint)Marshal.ReadInt32(ev, 24);
            int first = Marshal.ReadInt32(ev, 92);
            if (ex == 0xC0000005) {
              uint rw = (uint)Marshal.ReadInt32(ev, 32), target = (uint)Marshal.ReadInt32(ev, 36);
              log.Add(string.Format("ACCESS VIOLATION at {0:X8} ({1}), {2} {3:X8} ({4}){5}", at, Where(at, mods),
                rw == 0 ? "reading" : rw == 1 ? "writing" : "executing", target, Where(target, mods), first != 0 ? "" : ", second chance"));
              log.Add("  this is where PlugY.exe shows its EXCEPTION_ACCESS_VIOLATION box; closing " + exe);
              done = true;
            } else if (++nexc <= 12) log.Add(string.Format("exception {0:X8} at {1:X8} ({2})", ex, at, Where(at, mods)));
            break; }
          case 5: log.Add("Game.exe exited by itself, exit code " + Marshal.ReadInt32(ev, 12)); exited = true; done = true; break;
        }
        if (!done) { ContinueDebugEvent(lastPid, lastTid, 0x00010002 /*DBG_CONTINUE, as PlugY.exe*/); pending = false; }
      }
      if (!done) log.Add("no access violation within " + (timeoutMs / 1000) + " s" + (sawGfx ? "" : " (and D2gfx.dll never loaded)"));
    } finally {
      if (!exited) {
        TerminateProcess(pi.hProcess, 1);
        if (pending) ContinueDebugEvent(lastPid, lastTid, 0x00010002);
        var t = System.Diagnostics.Stopwatch.StartNew();
        while (t.ElapsedMilliseconds < 5000 && WaitForDebugEvent(ev, 1000)) {
          int c = Marshal.ReadInt32(ev, 0);
          ContinueDebugEvent(Marshal.ReadInt32(ev, 4), Marshal.ReadInt32(ev, 8), 0x00010002);
          if (c == 5) break;
        }
      }
      CloseHandle(pi.hThread); CloseHandle(pi.hProcess); Marshal.FreeHGlobal(ev);
    }
    if (accepted) return log;
    log.Add("modules (base-end, header ImageBase if different, file):");
    mods.Sort((x, y) => x.Base.CompareTo(y.Base));
    foreach (var m in mods)
      log.Add(string.Format("  {0:X8}-{1:X8} {2}{3}", m.Base, m.Base + m.Size, m.HdrBase != 0 && m.HdrBase != m.Base ? "(hdr " + m.HdrBase.ToString("X8") + ") " : "", m.Name));
    return log;
  }
}
"@

function Invoke-Trace {
    if ([Environment]::Is64BitProcess) { throw "the trace must run in 32-bit PowerShell" }
    Add-Type -TypeDefinition $traceSource
    $args2 = Get-PlugyCommandArgs
    for ($i = 1; $i -le $Runs; $i++) {
        "--- start $i of $Runs ---"
        [PlugYTrace]::Run($Path, $Exe, $args2, $TimeoutSec * 1000, [bool]$StopAtD2gfx)
        Start-Sleep -Milliseconds 800
    }
}

if ($TraceOnly) {
    try { Invoke-Trace } catch { "trace failed: $($_.Exception.Message)" }
    exit 0
}

# ---------------------------------------------------------------- the report
$lines = New-Object System.Collections.Generic.List[string]
function Add([string]$s = "") { $lines.Add($s) }
function Part([string]$title, [scriptblock]$body) {
    Add ""; Add ("== " + $title + " " + ("=" * [Math]::Max(3, 74 - $title.Length)))
    try { & $body } catch { Add "  (couldn't read this: $($_.Exception.Message))" }
}

Write-Host "PD2-Diag: collecting..." -ForegroundColor Cyan
Add "PD2-Diag v$VERSION report, $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Add "folder: $Path"

Part "Windows" {
    $os = Get-CimInstance Win32_OperatingSystem
    Add "  $($os.Caption) $($os.Version) build $($os.BuildNumber), 64-bit Windows: $([Environment]::Is64BitOperatingSystem)"
    Add "  last boot: $($os.LastBootUpTime)"
    $drive = Split-Path -Qualifier $Path
    $d = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$drive'"
    if ($d) { Add ("  drive {0} {1}, free {2:N1} of {3:N1} GB" -f $drive, $d.FileSystem, ($d.FreeSpace / 1GB), ($d.Size / 1GB)) }
}

Part "Scripts in the folder" {
    foreach ($f in "Launch-PD2-PlugY.ps1", "Patch-PD2-PlugY.ps1", "Patch-SPPlus.ps1") {
        $p = Join-Path $Path $f
        if (Test-Path -LiteralPath $p) {
            $m = Select-String -LiteralPath $p -Pattern '^\$VERSION\s*=\s*"([^"]+)"' | Select-Object -First 1
            Add ("  {0,-22} {1}" -f $f, $(if ($m) { $m.Matches[0].Groups[1].Value } else { "?" }))
        } else { Add ("  {0,-22} not here" -f $f) }
    }
}

Part "PlugY.ini" {
    $ini = Join-Path $Path "PlugY.ini"
    if (-not (Test-Path -LiteralPath $ini)) { Add "  no PlugY.ini"; return }
    foreach ($k in @(@("LAUNCHING","Param"), @("LAUNCHING","Library"), @("GENERAL","ActivePlugin"), @("GENERAL","ActiveLogFile"),
                     @("GENERAL","DllToLoad"), @("GENERAL","DllToLoad2"), @("WINDOWED","ActiveWindowed"), @("STATS POINTS","ActiveShiftClickLimit"))) {
        Add ("  [{0}] {1}={2}" -f $k[0], $k[1], (Get-IniValue $ini $k[0] $k[1]))
    }
    Add "  Game.exe would get: $(Get-PlugyCommandArgs)"
}

Part "Programs and DLLs (size, modified, sha256, header; vs PD2's own file list)" {
    $manifest = @{}
    $meta = Join-Path $Path "local_metadata.json"
    if (Test-Path -LiteralPath $meta) {
        foreach ($m in [regex]::Matches([IO.File]::ReadAllText($meta), '"([0-9a-fA-F]{32})\s+([^"]+)"')) { $manifest[$m.Groups[2].Value.ToLower()] = $m.Groups[1].Value.ToLower() }
        Add "  PD2's file list (local_metadata.json): $($manifest.Count) files, modified $((Get-Item -LiteralPath $meta).LastWriteTime.ToString('yyyy-MM-dd HH:mm'))"
    } else { Add "  no local_metadata.json (PD2's file list)" }
    $md5 = [Security.Cryptography.MD5]::Create()
    $files = Get-ChildItem -LiteralPath $Path -File | Where-Object { $_.Extension -in ".exe", ".dll" -or $_.Name -like "ProjectDiablo.dll.*" -or $_.Name -like "PlugY*.dll" } | Sort-Object Name
    foreach ($f in $files) {
        $bytes = [IO.File]::ReadAllBytes($f.FullName)
        $sha = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash.Substring(0, 16)
        $hex = -join ($md5.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") })
        $vs = if ($manifest.ContainsKey($f.Name.ToLower())) { if ($manifest[$f.Name.ToLower()] -eq $hex) { "= PD2" } else { "DIFFERS from PD2" } } else { "" }
        $pe = ""
        if ($bytes.Length -gt 0x200 -and $bytes[0] -eq 0x4D -and $bytes[1] -eq 0x5A) {
            $o = [BitConverter]::ToInt32($bytes, 0x3C)
            if ($o -gt 0 -and $o + 0x60 -lt $bytes.Length) {
                $opt = $o + 24
                $pe = "base {0:X8} size {1:X} cksum {2:X} {3}" -f [BitConverter]::ToUInt32($bytes, $opt + 28), [BitConverter]::ToUInt32($bytes, $opt + 56),
                    [BitConverter]::ToUInt32($bytes, $opt + 64), $(if ([BitConverter]::ToUInt16($bytes, $opt + 70) -band 0x40) { "aslr" } else { "fixed" })
            }
        }
        Add ("  {0,-34} {1,9} {2:yyyy-MM-dd HH:mm} {3} {4,-40} {5}" -f $f.Name, $f.Length, $f.LastWriteTime, $sha, $pe, $vs)
    }
}

Part "Newest files in the folder" {
    Get-ChildItem -LiteralPath $Path -File | Sort-Object LastWriteTime -Descending | Select-Object -First 25 |
        ForEach-Object { Add ("  {0:yyyy-MM-dd HH:mm:ss} {1,10} {2}" -f $_.LastWriteTime, $_.Length, $_.Name) }
    $ex = Join-Path $Path "data\global\excel"
    if (Test-Path -LiteralPath $ex) {
        $loose = @(Get-ChildItem -LiteralPath $ex -File)
        Add "  data\global\excel: $($loose.Count) files ($(@($loose | Where-Object Extension -eq '.bin').Count) .bin, $(@($loose | Where-Object Extension -eq '.txt').Count) .txt)"
        $loose | Sort-Object LastWriteTime -Descending | Select-Object -First 5 | ForEach-Object { Add ("    {0:yyyy-MM-dd HH:mm} {1}" -f $_.LastWriteTime, $_.Name) }
    }
}

Part "Logs" {
    $pl = Join-Path $Path "PlugY.log"
    if (Test-Path -LiteralPath $pl) {
        Add "  PlugY.log, modified $((Get-Item -LiteralPath $pl).LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')), last lines:"
        Get-Content -LiteralPath $pl -Tail 25 | ForEach-Object { Add "    $_" }
    } else { Add "  no PlugY.log" }
    $d2 = Get-ChildItem -LiteralPath $Path -File | Where-Object Name -match '^D2\d{6}\.txt$' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($d2) {
        Add "  $($d2.Name) (D2's own log), modified $($d2.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')), last lines:"
        Get-Content -LiteralPath $d2.FullName -Tail 25 | Where-Object { $_ -notmatch 'Local IP|Computer name|Realm startup' } | ForEach-Object { Add "    $_" }
    } else { Add "  no D2 log (D2yymmdd.txt)" }
}

Part "Compatibility mode (right-click > Properties > Compatibility)" {
    $n = 0
    foreach ($root in "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers",
                      "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers") {
        $k = Get-Item -LiteralPath $root -ErrorAction SilentlyContinue
        if (-not $k) { continue }
        foreach ($v in $k.GetValueNames()) {
            if ($v -like "$Path\*") { Add "  $($root.Substring(0,4)) $(Split-Path -Leaf $v) = $($k.GetValue($v))"; $n++ }
        }
    }
    if ($n -eq 0) { Add "  none set for programs in this folder" }
}

Part "Exploit protection (Windows Security > App & browser control)" {
    if (-not (Get-Command Get-ProcessMitigation -ErrorAction SilentlyContinue)) { Add "  Get-ProcessMitigation not available"; return }
    $s = Get-ProcessMitigation -System
    Add "  system: Mandatory ASLR (ForceRelocateImages)=$($s.Aslr.ForceRelocateImages)  BottomUp=$($s.Aslr.BottomUp)  HighEntropy=$($s.Aslr.HighEntropy)  DEP=$($s.Dep.Enable)"
    foreach ($n in "Game.exe", "PlugY.exe", "Diablo II.exe") {
        $m = Get-ProcessMitigation -Name $n -ErrorAction SilentlyContinue
        if ($m) { Add "  ${n}: ForceRelocateImages=$($m.Aslr.ForceRelocateImages)  BottomUp=$($m.Aslr.BottomUp)  DEP=$($m.Dep.Enable)  (NOTSET = system default)" }
        else { Add "  ${n}: no own settings" }
    }
}

Part "Antivirus" {
    $av = @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction Stop)
    if ($av.Count -eq 0) { Add "  none reported" }
    foreach ($a in $av) { Add ("  {0} (state {1:X6})" -f $a.displayName, $a.productState) }
}

Part "Game.exe / PlugY.exe crashes in the Application log, last 3 days" {
    $ev = @(Get-WinEvent -FilterHashtable @{ LogName = 'Application'; StartTime = (Get-Date).AddDays(-3); Id = 1000, 1001, 1002 } -MaxEvents 300 -ErrorAction SilentlyContinue |
            Where-Object { $_.Message -match 'Game\.exe|PlugY\.exe' } | Select-Object -First 8)
    if ($ev.Count -eq 0) { Add "  none" }
    foreach ($e in $ev) {
        Add "  $($e.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')) event $($e.Id) ($($e.ProviderName))"
        $e.Message -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -First 9 | ForEach-Object { Add "    $($_.Trim())" }
    }
}

if (-not $NoTrace) {
    Part "Starting Game.exe the way PlugY.exe does" {
        if (Get-Process -Name "Game" -ErrorAction SilentlyContinue) { Add "  skipped: Game.exe is running. Close the game and run PD2-Diag.bat again."; return }
        if (-not (Test-Path -LiteralPath (Join-Path $Path $Exe))) { Add "  skipped: no $Exe here"; return }
        Write-Host "PD2-Diag: starting Game.exe briefly ($Runs times)..." -ForegroundColor Cyan
        $traceOut = if ([Environment]::Is64BitProcess) {
            $ps32 = Join-Path $env:SystemRoot "SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
            $a = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $PSCommandPath, "-TraceOnly", "-Path", $Path, "-Exe", $Exe, "-Runs", $Runs, "-TimeoutSec", $TimeoutSec)
            if ($StopAtD2gfx) { $a += "-StopAtD2gfx" }
            & $ps32 @a 2>&1
        } else { Invoke-Trace }
        foreach ($l in $traceOut) { Add "  $l" }
    }
}

$report = if ($Out) { $Out } else { Join-Path $Path "PD2-diag.txt" }
# keep the user's and the computer's names out of the report
$scrub = @()
if ($env:USERPROFILE)  { $scrub += , @([regex]::Escape($env:USERPROFILE), '%USERPROFILE%') }
if ($env:USERNAME)     { $scrub += , @('(?<![\w-])' + [regex]::Escape($env:USERNAME) + '(?![\w-])', '%USERNAME%') }
if ($env:COMPUTERNAME) { $scrub += , @('(?<![\w-])' + [regex]::Escape($env:COMPUTERNAME) + '(?![\w-])', '%COMPUTERNAME%') }
for ($i = 0; $i -lt $lines.Count; $i++) {
    foreach ($s in $scrub) { $lines[$i] = $lines[$i] -ireplace $s[0], $s[1] }
}
[IO.File]::WriteAllLines($report, $lines, (New-Object Text.UTF8Encoding($false)))
Write-Host "PD2-Diag: wrote $report" -ForegroundColor Green
if (-not $env:PD2DIAG_NOOPEN) { Start-Process notepad.exe -ArgumentList "`"$report`"" }
