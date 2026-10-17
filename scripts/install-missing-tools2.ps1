#requires -Version 5.1
<#
.SYNOPSIS
    Second pass: fills the tool gaps measured after the first install.

.DESCRIPTION
    Measured gaps (references across installed skills -> installed):
      impacket 18 no, objection 14 no, pwntools 12 no, nuclei 20 no,
      ffuf 17 no, httpx 12 no, gobuster 8 no, john 13 no, upx 9 no,
      sysinternals 6 no, de4dot 7 no.

    Wireshark and dnSpy were already on disk but off PATH / never installed;
    those are handled separately.

    Idempotent. Always exits 0.
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
$ProgressPreference    = 'SilentlyContinue'

$tools = "$ToolsDir"
$shim  = Join-Path $env:LOCALAPPDATA 'opencode-shims'
New-Item -ItemType Directory -Force -Path $tools, $shim | Out-Null

$log = Join-Path $PSScriptRoot 'logs\install-tools2.log'
New-Item -ItemType Directory -Force -Path (Split-Path $log) | Out-Null

function Say($msg) {
    $line = '{0} {1}' -f (Get-Date -Format 'HH:mm:ss'), $msg
    Add-Content -Path $log -Value $line -Encoding utf8
    Write-Host $line
}

function Shim($name, $target) {
    if (-not $target) { return }
    "@echo off`r`n`"$target`" %*" | Set-Content -Path (Join-Path $shim "$name.cmd") -Encoding ascii -NoNewline
}

function Fetch($name, $url, $destDir, $exePattern) {
    $existing = Get-ChildItem $tools -Recurse -Filter $exePattern -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($existing) { Say "$name already at $($existing.FullName)"; Shim $name $existing.FullName; return }

    $zipPath = Join-Path $env:TEMP "$name.zip"
    Say "download $name"
    curl.exe -L --retry 5 --retry-delay 3 --retry-all-errors -s -o $zipPath $url 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $zipPath)) { Say "  download FAILED"; return }
    Say "  extracting"
    tar.exe -xf $zipPath -C $tools 2>&1 | Out-Null
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    $found = Get-ChildItem $tools -Recurse -Filter $exePattern -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { Say "  ok $($found.FullName)"; Shim $name $found.FullName }
    else { Say "  extracted but $exePattern not found" }
}

function FetchExe($name, $url, $outName) {
    $out = Join-Path $tools $outName
    if (Test-Path $out) { Say "$name already at $out"; Shim $name $out; return }
    Say "download $name"
    curl.exe -L --retry 5 --retry-delay 3 --retry-all-errors -s -o $out $url 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0 -and (Test-Path $out)) { Say "  ok $((Get-Item $out).Length) bytes"; Shim $name $out }
    else { Say "  FAILED" }
}

# ---------- pip ----------
foreach ($p in @('impacket', 'objection', 'pwntools')) {
    Say "pip install $p"
    python -m pip install --quiet --upgrade $p 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        python -m pip install --quiet --upgrade --break-system-packages $p 2>&1 | Out-Null
    }
    Say "  exit=$LASTEXITCODE"
}

$pyScripts = python -c "import sysconfig; print(sysconfig.get_path('scripts'))" 2>$null
if ($pyScripts) {
    Say "pip scripts at $pyScripts"
    foreach ($n in @('impacket-ntlm', 'impacket-secretsdump', 'impacket-psexec',
                     'impacket-smbclient', 'impacket-wmiexec', 'ntlmrelayx',
                     'objection')) {
        $src = Join-Path $pyScripts "$n.exe"
        if (Test-Path $src) { Shim $n $src }
    }
}

# ---------- Go single-binary tools ----------
$goTools = @(
    @{ n = 'nuclei';   url = 'https://github.com/projectdiscovery/nuclei/releases/latest/download/nuclei_3.4.7_windows_amd64.zip'; exe = 'nuclei.exe' },
    @{ n = 'httpx';    url = 'https://github.com/projectdiscovery/httpx/releases/latest/download/httpx_1.7.1_windows_amd64.zip';   exe = 'httpx.exe' },
    @{ n = 'ffuf';     url = 'https://github.com/ffuf/ffuf/releases/latest/download/ffuf_2.1.0_windows_amd64.exe';                  exe = 'ffuf.exe' },
    @{ n = 'gobuster'; url = 'https://github.com/OJ/gobuster/releases/latest/download/gobuster_Windows_amd64.zip';                 exe = 'gobuster.exe' }
)
foreach ($t in $goTools) {
    if ($t.url -like '*.exe') { FetchExe $t.n $t.url $t.exe } else { Fetch $t.n $t.url $tools $t.exe }
}

# ---------- packer ----------
Fetch 'upx' 'https://github.com/upx/upx/releases/latest/download/upx-5.0.2-amd64_win64.zip' $tools 'upx.exe'

# ---------- john ----------
Fetch 'john' 'https://github.com/openwall/john/releases/download/1.9.4/john-1.9.4-win32.zip' $tools 'john.exe'

# ---------- sysinternals ----------
$sysDir = Join-Path $tools 'SysinternalsSuite'
if (Test-Path (Join-Path $sysDir 'procexp.exe')) {
    Say 'Sysinternals already present'
} else {
    New-Item -ItemType Directory -Force -Path $sysDir | Out-Null
    $zipPath = Join-Path $env:TEMP 'sysinternals.zip'
    Say 'download SysinternalsSuite'
    curl.exe -L --retry 5 --retry-delay 3 --retry-all-errors -s -o $zipPath 'https://download.sysinternals.com/files/SysinternalsSuite.zip' 2>&1 | Out-Null
    if (Test-Path $zipPath) {
        tar.exe -xf $zipPath -C $sysDir 2>&1 | Out-Null
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        Say "  extracted $((Get-ChildItem $sysDir -File).Count) files"
    } else { Say '  FAILED' }
}

# ---------- de4dot ----------
$de4 = Join-Path $tools 'de4dot'
if (Test-Path $de4) {
    Say 'de4dot already present'
} else {
    New-Item -ItemType Directory -Force -Path $de4 | Out-Null
    $zipPath = Join-Path $env:TEMP 'de4dot.zip'
    Say 'download de4dot'
    curl.exe -L --retry 5 --retry-delay 3 --retry-all-errors -s -o $zipPath 'https://github.com/de4dot/de4dot/releases/download/v3.1.415235/de4dot-v3.1.415235.zip' 2>&1 | Out-Null
    if (Test-Path $zipPath) {
        tar.exe -xf $zipPath -C $de4 2>&1 | Out-Null
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        $exe = Get-ChildItem $de4 -Recurse -Filter 'de4dot.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($exe) { Say "  ok $($exe.FullName)"; Shim 'de4dot' $exe.FullName }
        else { Say '  extracted but de4dot.exe not found' }
    } else { Say '  FAILED' }
}

# ---------- verification ----------
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
            [Environment]::GetEnvironmentVariable('Path','User') + ";$shim"
Say '=== verification ==='
$missing = @()
foreach ($b in @('impacket-ntlm','impacket-secretsdump','objection','nuclei','httpx','ffuf',
                 'gobuster','upx','john','de4dot','tshark','dnSpy','procdump','procmon','autoruns')) {
    $c = Get-Command $b -ErrorAction SilentlyContinue
    if ($c) { Say ("  {0,-24} OK" -f $b) } else { Say ("  {0,-24} MISSING" -f $b); $missing += $b }
}
Say "missing: $($missing -join ', ')"
exit 0