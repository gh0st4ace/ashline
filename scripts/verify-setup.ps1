#requires -Version 5.1
<#
.SYNOPSIS
    Health check for the whole workspace stack. Run after any change.

.DESCRIPTION
    Everything here is hand-edited JSON, NTFS junctions, and environment
    variables, so it breaks quietly. This answers one question: is it still
    wired up?

    Read-only. Never modifies anything. Always exits 0.
    Windows PowerShell 5.1 compatible.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.config\opencode\verify-setup.ps1"
#>

[CmdletBinding()]
param()

# -- Path resolution ---------------------------------------------------------
# Overridable via environment. Defaults match the machine this was authored on;
# set WB_TOOLS_DIR / WB_COLLECTIONS_DIR / WB_CONFIG_DIR to relocate without
# editing this file.
if (-not $ToolsDir)       { $ToolsDir       = if ($env:WB_TOOLS_DIR)      { $env:WB_TOOLS_DIR }      else { 'D:\Tools' } }
if (-not $CollectionsDir) { $CollectionsDir = if ($env:WB_COLLECTIONS_DIR) { $env:WB_COLLECTIONS_DIR } else { 'D:\opencode' } }
if (-not $UserProfile)    { $UserProfile    = $env:USERPROFILE }
if (-not $ConfigDir)      { $ConfigDir      = if ($env:WB_CONFIG_DIR)     { $env:WB_CONFIG_DIR }     else { Join-Path $UserProfile '.config\opencode' } }
# ---------------------------------------------------------------------------

$ErrorActionPreference = 'Continue'
$cfg = $PSScriptRoot
$script:ok = 0
$script:bad = 0

function Say($mark, $name, $detail, $color) {
    Write-Host ("  [{0}] {1,-28} {2}" -f $mark, $name, $detail) -ForegroundColor $color
    if ($mark.Trim() -eq 'OK') { $script:ok++ } else { $script:bad++ }
}

function Check($name, [scriptblock]$body) {
    try {
        $r = & $body
        if ($null -eq $r -or ($r -is [string] -and $r.Trim() -eq '')) { $r = 'MISSING' }
        if ($r -ne 'MISSING') { Say ' OK' $name $r 'Green' } else { Say 'FAIL' $name 'MISSING' 'Red' }
    } catch {
        Say 'FAIL' $name $_.Exception.Message 'Red'
    }
}

function ReadJsonc($path) {
    $raw = Get-Content $path -Raw
    (($raw -split "`n" | Where-Object { $_ -notmatch '^\s*//' }) -join "`n") | ConvertFrom-Json
}

# Recompose PATH so newly installed tooling is visible to this process.
$script:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
               [Environment]::GetEnvironmentVariable('Path', 'User') + ';' +
               "$env:LOCALAPPDATA\opencode-shims"
$env:Path = $script:Path

Write-Host ''
Write-Host '== configuration ==' -ForegroundColor Cyan
Check 'opencode.jsonc valid' {
    $o = ReadJsonc "$cfg\opencode.jsonc"
    "agent=$($o.default_agent) plugins=$($o.plugins.Count) cmds=$($o.commands.PSObject.Properties.Count) refs=$($o.references.PSObject.Properties.Count) perms=$($o.permissions.Count)"
}
Check 'opencode-mem.jsonc valid' {
    $o = ReadJsonc "$cfg\opencode-mem.jsonc"
    "storage=$($o.storagePath) model=$($o.embeddingModel)"
}
Check 'compaction state' {
    $c = (ReadJsonc "$cfg\opencode.jsonc").compaction
    "auto=$($c.auto) keep=$($c.keep.tokens) buffer=$($c.buffer)"
}
Check 'config backups present' {
    $n = @(Get-ChildItem "$cfg\backups" -Filter '*.bak' -ErrorAction SilentlyContinue).Count
    if ($n -gt 0) { "$n files" } else { 'MISSING' }
}
Check 'AGENTS.md present' { if (Test-Path "$cfg\AGENTS.md") { "{0:N1} KB" -f ((Get-Item "$cfg\AGENTS.md").Length / 1KB) } else { 'MISSING' } }

Write-Host ''
Write-Host '== skills ==' -ForegroundColor Cyan
Check 'gameskills junctions' { "$(@(Get-ChildItem "$cfg\gameskills" -Directory -EA SilentlyContinue).Count)/12" }
Check 'hackskills junctions' { "$(@(Get-ChildItem "$cfg\hackskills" -Directory -EA SilentlyContinue).Count)/93" }
Check 'reaskills junctions' { "$(@(Get-ChildItem "$cfg\reaskills" -Directory -EA SilentlyContinue).Count)/3" }
Check 'REA skill' { if (Test-Path "$env:USERPROFILE\.agents\skills\reverse-engineer-anything") { 'installed' } else { 'MISSING' } }
Check 'custom RE skill' { if (Test-Path "$cfg\skills\game-security-reverse-engineering\SKILL.md") { 'installed' } else { 'MISSING' } }

Write-Host ''
Write-Host '== reference collections ==' -ForegroundColor Cyan
$refs = [ordered]@{
    'awesome-game-security'  = "$CollectionsDir\awesome-game-security"
    'game-security-archive' = "$CollectionsDir\awesome-game-security-archive"
    'hack-skills'           = "$CollectionsDir\hack-skills"
    'cyber-skills'          = "$CollectionsDir\cybersecurity-skills"
    'game-hacking-refs'     = "$CollectionsDir\game-hacking-references"
    'hacking-online-games'  = "$CollectionsDir\hacking-online-games"
    'rea'                   = "$CollectionsDir\rea"
}
foreach ($k in $refs.Keys) { Check $k { if (Test-Path $refs[$k]) { $refs[$k] } else { 'MISSING' } } }

Write-Host ''
Write-Host '== REA engines ==' -ForegroundColor Cyan
$env:GHIDRA_INSTALL_DIR = [Environment]::GetEnvironmentVariable('GHIDRA_INSTALL_DIR', 'User')
$env:JAVA_HOME          = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'User')
$env:REA_IDA_MCP_CONFIG = [Environment]::GetEnvironmentVariable('REA_IDA_MCP_CONFIG', 'User')
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
Check 'ghidra install' { if (Test-Path "$env:GHIDRA_INSTALL_DIR\ghidraRun.bat") { $env:GHIDRA_INSTALL_DIR } else { 'MISSING' } }
Check 'jdk' { if (Test-Path "$env:JAVA_HOME\bin\java.exe") { (& "$env:JAVA_HOME\bin\java.exe" -version 2>&1 | Select-Object -First 1) } else { 'MISSING' } }
Check 'ida install' { if (Test-Path 'D:\Programs\IDA Professional 9.4\ida.exe') { '9.4' } else { 'MISSING' } }
# D:\Programs\ is on the MACHINE PATH ahead of every user entry and holds a
# loose 9.3 copy, so a bare `ida` in a shell can launch the wrong build. Every
# script here uses the absolute 9.4 path, so this is reported, not fatal.
Check 'ida PATH shadow' {
    $resolved = (Get-Command ida -ErrorAction SilentlyContinue).Source
    $orphan   = Test-Path 'D:\Programs\ida.exe'
    if ($orphan -and $resolved -eq 'D:\Programs\ida.exe') {
        'SHADOWED: bare `ida` -> 9.3; run fix-ida-shadow.ps1 elevated (scripts use 9.4)'
    } elseif ($orphan) {
        '9.3 loose copy present but not first on PATH'
    } else {
        'clean'
    }
}
Check 'ida mcp plugin' { if (Test-Path "$env:APPDATA\Hex-Rays\IDA Pro\plugins\mcp-plugin.py") { 'installed' } else { 'MISSING' } }
Check 'ida mcp config' { if (Test-Path $env:REA_IDA_MCP_CONFIG) { 'present' } else { 'MISSING' } }
Check 'REA doctor' {
    $d = (rea setup --client opencode --json 2>&1 | Out-String | ConvertFrom-Json).doctor
    "healthy=$($d.healthy) providers=$($d.availableProviders -join ',')"
}

Write-Host ''
Write-Host '== memory ==' -ForegroundColor Cyan
Check 'mem storage' { if (Test-Path "$CollectionsDir\opencode-mem\data") { "$CollectionsDir\opencode-mem\data" } else { 'MISSING' } }
Check 'mem web UI' { if (Get-NetTCPConnection -LocalPort 4747 -State Listen -EA SilentlyContinue) { '127.0.0.1:4747' } else { 'not listening' } }

Write-Host ''
Write-Host '== tooling the skills reference (resolves AND runs) ==' -ForegroundColor Cyan
<#
    Resolution alone is not proof. Three shims written by an earlier installer
    resolved fine and were broken: the script emitted the literal text
    "%target" because the variable reference was missing its sigil. Every tool
    below is therefore executed with a version banner, and the first line of
    real output is reported.

    GUI-only tools are listed in $guiOnly: launching them would block.
#>
$probes = [ordered]@{
    'nmap'         = @('--version')
    'r2'           = @('-version')
    'rabin2'       = @('-v')
    'rizin'        = @('-v')
    'jadx'         = @('--version')
    'apktool'      = @('--version')
    # hashcat: -v is VERBOSE mode, not version. With -v and no hash/mode it
    # starts a full run and never returns, which hangs the whole check.
    'hashcat'      = @('--version')
    'sqlmap'       = @('--version')
    'frida'        = @('--version')
    # binwalk removed 15.10.2026: pip 2.1.0 sdist lacks binwalk.core (ModuleNotFoundError,
    # reproduced by --no-cache-dir reinstall); Rust v3.1.0 has no Windows release assets
    # and no Rust toolchain on host. Fallbacks: r2/rizin, 7z, DIE. See DISCOVERY_SHEET.
    'vol'          = @('-h')
    'uncompyle6'   = @('--version')
    'upx'          = @('-V')
    'nuclei'       = @('-version')
    'httpx'        = @('-version')
    'ffuf'         = @('-V')
    'gobuster'     = @('--version')
    'tshark'       = @('-v')
    'procdump'     = @('-?')
    'objection'    = @('version')
    'Il2CppDumper' = @()
    'Cpp2IL'       = @('--help')
    'luau-compile' = @('--help')
    'unluau'       = @('--help')
    'windbg'       = @()   # -? opens the WinDbg GUI; never probe it
    'cdb'          = @('-?')
    'interactsh-client' = @('-version')
    'psexec'       = @('-h')
    'ntlmrelayx'   = @('-h')
    'secretsdump'  = @('-h')
    'frida-ps'     = @()   # -U blocks waiting for a USB device that is not attached
}
$guiOnly = @('x64dbg', 'x32dbg', 'dnSpy', 'cheatengine', 'wireshark', 'ghidraRun')

<#
    Libraries with no CLI entry point. Resolving nothing on PATH proves nothing
    about them, so they are exercised by importing and calling one API.
    pwntools is the notable case: it installs only with --no-deps because its
    unicorn pin (>=2.0.1, !=2.1.3, !=2.1.4) makes pip backtrack to a source
    tarball that will not build on Windows.
#>
<#
    Versions come from importlib.metadata, not from module attributes:
    impacket has no __version__, and importing a submodule through the package
    name fails for names like smbclient. Then each one is actually used, so a
    package that installs but cannot load still fails here.
#>
$pyModules = [ordered]@{
    'pwntools' = 'from pwn import *; from pwn import context; print("pwntools", version, context.arch)'
    'impacket' = 'import impacket.smb3; from importlib.metadata import version; print("impacket", version("impacket"))'
    'lief'     = 'import lief; from importlib.metadata import version; print("lief", version("lief"))'
    'capstone' = 'import capstone; from importlib.metadata import version; print("capstone", version("capstone"))'
    'frida'    = 'import frida; from importlib.metadata import version; print("frida", version("frida"))'
    'unicorn'  = 'import unicorn; print("unicorn", unicorn.__version__)'
}
$pyScratch = Join-Path $env:TEMP 'verify-pymod.py'
foreach ($m in $pyModules.Keys) {
    $snippet = [string]$pyModules[$m]
    try {
        # Windows PowerShell strips the double quotes when a snippet is passed
        # to `python -c`, so Python receives print(impacket) instead of
        # print("impacket") and raises TypeError: got 'module'. Writing the
        # snippet to a file and running that avoids the re-quoting entirely.
        [System.IO.File]::WriteAllText($pyScratch, $snippet)
        $o = & python $pyScratch 2>&1 | Out-String
        # A traceback is non-empty output, so "first non-empty line" is not
        # evidence of success. Look for the exception text first, then fall
        # back to the version line.
        if ($o -match 'Traceback \(most recent call last\)|ModuleNotFoundError|ImportError|SyntaxError') {
            $detail = ($o -split "`r?`n" | Where-Object { $_ -match 'Error' } | Select-Object -First 1)
            Say 'FAIL' "py:$m" ($detail.Trim()) 'Red'
            continue
        }
        $line = ($o -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -First 1)
        if ($line) {
            $t = $line.Trim()
            Say ' OK' "py:$m" ($t.Substring(0, [Math]::Min(48, $t.Length))) 'Green'
        } else {
            Say 'FAIL' "py:$m" 'ran, no output' 'Red'
        }
    } catch {
        Say 'FAIL' "py:$m" 'not importable' 'Red'
    }
}

foreach ($b in $probes.Keys) {
    $c = Get-Command $b -ErrorAction SilentlyContinue
    if (-not $c) { Say 'FAIL' $b 'not on PATH' 'Red'; continue }
    if ($probes[$b].Count -eq 0) { Say ' OK' $b "$($c.Source) (no safe banner)" 'Green'; continue }
    try {
        $out = & $b @($probes[$b]) 2>&1 | Out-String
        $line = ($out -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -First 1)
        # A traceback is non-empty output, not a working tool (binwalk 2.1.0
        # shipped exactly this false-OK: banner = "Traceback (most recent...)").
        if ($line -match 'Traceback \(most recent call last\)|ModuleNotFoundError|ImportError') {
            $detail = ($out -split "`r?`n" | Where-Object { $_ -match 'Error' } | Select-Object -First 1)
            Say 'FAIL' $b ($detail.Trim().Substring(0, [Math]::Min(64, $detail.Trim().Length))) 'Red'
            continue
        }
        if ($line) {
            $t = $line.Trim()
            Say ' OK' $b ($t.Substring(0, [Math]::Min(48, $t.Length))) 'Green'
        } else {
            Say 'FAIL' $b 'ran but produced no output' 'Red'
        }
    } catch {
        Say 'FAIL' $b "threw: $($_.Exception.Message.Split([char]10)[0])" 'Red'
    }
}

foreach ($b in $guiOnly) {
    $c = Get-Command $b -ErrorAction SilentlyContinue
    if ($c) { Say ' OK' $b $c.Source 'Green' } else { Say 'FAIL' $b 'MISSING' 'Red' }
}

Write-Host ''
Write-Host '== shim integrity ==' -ForegroundColor Cyan
<#
    A shim that resolves on PATH but contains an unexpanded variable is worse
    than a missing shim: every check above passes and every real command fails.
    install-missing-tools.ps1 shipped exactly that bug (`"%target`"` instead of
    `"$target`"`), so it gets an explicit check rather than relying on the
    execution probes to notice.
#>
$shimDir = Join-Path $env:LOCALAPPDATA 'opencode-shims'
Check 'shim dir' { if (Test-Path $shimDir) { "$(@(Get-ChildItem $shimDir -Filter '*.cmd').Count) shims" } else { 'MISSING' } }
Check 'no unexpanded vars' {
    $bad = @(Get-ChildItem $shimDir -Filter '*.cmd' -ErrorAction SilentlyContinue |
             Where-Object { (Get-Content $_.FullName -Raw) -match '%(target|t|path|src)\b' })
    if ($bad.Count -eq 0) { 'all shims expand their target' }
    else { "BROKEN: $($bad.Name -join ', ')" }
}
Check 'shims point at something real' {
    # Legitimate shapes: "<abs path>" %*  (exe shims)  and  python "<path>" %*
    # / python -m <module> %*  (pip-installed console scripts). Anything else
    # is a shim that would fail when actually invoked.
    $bad = @(Get-ChildItem $shimDir -Filter '*.cmd' -ErrorAction SilentlyContinue |
             Where-Object { (Get-Content $_.FullName -Raw) -notmatch '@echo\s+off\s+("?\s*python\b|"[A-Za-z]:)' })
    if ($bad.Count -eq 0) { 'every shim invokes an absolute path or python' }
    else { "SUSPECT: $($bad.Name -join ', ')" }
}

Write-Host ''
Write-Host '== MCP servers ==' -ForegroundColor Cyan
$servers = (opencode mcp list 2>&1 | Out-String)
foreach ($s in 'rea', 'cheat-mcp', 'js-reverse', 'jshook', 'context7') {
    $line = ($servers -split "`r?`n" | Where-Object { $_ -match [regex]::Escape($s) } | Select-Object -First 1)
    if ($line -and $line -match '\u2713|connected') { Say ' OK' $s 'connected' 'Green' }
    elseif ($line) { Say 'FAIL' $s 'not connected' 'Red' }
    else { Say 'FAIL' $s 'not registered' 'Red' }
}

Write-Host ''
Write-Host '== developer environment ==' -ForegroundColor Cyan
$ds = Join-Path $PSScriptRoot 'devshell.cmd'
Check 'devshell.cmd present' { if (Test-Path $ds) { 'devshell.cmd' } else { 'MISSING' } }
Check 'vcvarsall.bat' { if (Test-Path 'D:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvarsall.bat') { 'VS 2026' } else { 'MISSING' } }
Check 'signtool' { if (Test-Path 'D:\Windows Kits\10\bin\10.0.26100.0\x64\signtool.exe') { 'WDK 10.0.26100' } else { 'MISSING' } }
Check 'WDK km headers' { if (Test-Path 'D:\Windows Kits\10\Include\10.0.26100.0\km\wdm.h') { 'kernel headers present' } else { 'MISSING' } }

Write-Host ''
Write-Host '== virtualization ==' -ForegroundColor Cyan
Check 'VBoxManage' { if (Test-Path 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe') { (& 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe' --version 2>&1 | Select-Object -First 1) } else { 'MISSING' } }
Check 'test ISO' {
    $iso = Get-ChildItem "$ToolsDir\iso" -Filter '*.iso' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($iso) { '{0} ({1:N2} GB)' -f $iso.Name, ($iso.Length/1GB) } else { 'MISSING' }
}

Write-Host ''
Write-Host '== .NET libraries (read/write assemblies) ==' -ForegroundColor Cyan
foreach ($p in 'dnlib', 'AsmResolver') {
    $dll = Get-ChildItem "$ToolsDir\nuget" -Recurse -Filter "$p.dll" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($dll) { Say ' OK' $p $dll.FullName 'Green' } else { Say 'FAIL' $p 'MISSING' 'Red' }
}

Write-Host ''
Write-Host '== env ==' -ForegroundColor Cyan
foreach ($k in @('REA_ANALYSIS_PROVIDER', 'REA_IDA_MCP_CONFIG', 'REA_IDA_INSTALL', 'GHIDRA_INSTALL_DIR', 'JAVA_HOME')) {
    $v = [Environment]::GetEnvironmentVariable($k, 'User')
    if ($v) { Say ' OK' $k $v 'Green' } else { Say 'FAIL' $k 'MISSING' 'Red' }
}

Write-Host ''
Write-Host ('  {0} ok, {1} failing' -f $ok, $bad) -ForegroundColor $(if ($bad -eq 0) { 'Green' } else { 'Yellow' })
Write-Host ''
exit 0