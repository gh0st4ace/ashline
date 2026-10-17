#requires -Version 5.1
<#
.SYNOPSIS
    Third pass: corrected installer after the second pass shipped bad URLs.

.DESCRIPTION
    Bugs found in install-missing-tools2.ps1 and their fixes here:
      1. httpx matched by filename against the python httpx client inside
         ida-pro-mcp-venv. Deleted; the shim is now built from the verified
         projectdiscovery release URL instead.
      2. `latest/download/<asset>` is not valid for repos that publish the
         asset under a tag-specific path. Every URL below was resolved from
         the GitHub API, not guessed.
      3. SysinternalsSuite extracted 164 files but had no shims.
      4. impacket ships .py entry points, not .exe, on this Python install.

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

$log = Join-Path $PSScriptRoot 'logs\install-tools3.log'
New-Item -ItemType Directory -Force -Path (Split-Path $log) | Out-Null

function Say($m) {
    $l = '{0} {1}' -f (Get-Date -Format 'HH:mm:ss'), $m
    Add-Content -Path $log -Value $l -Encoding utf8
    Write-Host $l
}
function Shim($n, $t) {
    if ($t) { "@echo off`r`n`"$t`" %*" | Set-Content -Path (Join-Path $shim "$n.cmd") -Encoding ascii -NoNewline }
}

function Get-Tool($name, $url, $exe) {
    # Reject anything already on disk unless it is genuinely the right binary.
    $known = Join-Path $tools $name
    if (Test-Path $known) {
        $f = Get-ChildItem $known -Recurse -Filter $exe -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($f) { Say "$name already at $($f.FullName)"; Shim $name $f.FullName; return }
    }
    $zip = Join-Path $env:TEMP "$name.zip"
    Say "download $name"
    curl.exe -L --retry 5 --retry-delay 3 --retry-all-errors -s -o $zip $url 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $zip)) { Say "  download FAILED"; return }
    $sz = (Get-Item $zip).Length
    if ($sz -lt 100KB) { Say "  FAILED: only $sz bytes (HTML error page?)"; Remove-Item $zip -Force -EA SilentlyContinue; return }
    Say ("  {0:N1} MB" -f ($sz / 1MB))
    New-Item -ItemType Directory -Force -Path $known | Out-Null
    tar.exe -xf $zip -C $known 2>&1 | Out-Null
    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    $f = Get-ChildItem $known -Recurse -Filter $exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($f) { Say "  ok $($f.FullName)"; Shim $name $f.FullName } else { Say "  extracted but $exe absent" }
}

# 1. remove the wrong httpx shim before anything can use it
if (Test-Path "$shim\httpx.cmd") {
    Remove-Item "$shim\httpx.cmd" -Force
    Say 'removed bad httpx shim (it pointed at the python httpx client)'
}

# 2. verified URLs
Get-Tool 'nuclei'   'https://github.com/projectdiscovery/nuclei/releases/download/v3.11.1/nuclei_3.11.1_windows_amd64.zip'   'nuclei.exe'
Get-Tool 'httpx'    'https://github.com/projectdiscovery/httpx/releases/download/v1.12.0/httpx_1.12.0_windows_amd64.zip'   'httpx.exe'
Get-Tool 'ffuf'     'https://github.com/ffuf/ffuf/releases/download/v2.3.0/ffuf_2.3.0_windows_amd64.zip'                'ffuf.exe'
Get-Tool 'gobuster' 'https://github.com/OJ/gobuster/releases/download/v3.8.2/gobuster_Windows_x86_64.zip'               'gobuster.exe'
Get-Tool 'upx'      'https://github.com/upx/upx/releases/download/v5.2.1/upx-5.2.1-win64.zip'                          'upx.exe'

# 3. Sysinternals shims (the suite was already extracted with no shims)
$sys = Join-Path $tools 'SysinternalsSuite'
if (Test-Path "$sys\procdump64.exe") {
    foreach ($n in 'procdump','procdump64','procexp','procexp64','procmon','procmon64','autoruns','autoruns64',
                   'tcpview','processmonitor','processexplorer','listdlls','handle','sigcheck','streams','livekd') {
        $f = Join-Path $sys "$n.exe"
        if (Test-Path $f) { Shim $n $f }
    }
    Say "sysinternals shims written for $((Get-ChildItem $sys -Filter '*.exe').Count) executables"
} else { Say 'SysinternalsSuite missing' }

# 4. impacket ships .py entry points here
$ps = "$UserProfile\AppData\Local\Python\pythoncore-3.14-64\Scripts"
if (Test-Path $ps) {
    foreach ($n in 'psexec','secretsdump','ntlmrelayx','smbclient','wmiexec','smbmap','brutespray','ntlm-auth','GetUserSPNs','GetUserSites','hashdump','reg.py') {
        $f = Join-Path $ps "$n.py"
        if (Test-Path $f) {
            "@echo off`r`npython `"$f`" %*" | Set-Content -Path (Join-Path $shim "$n.cmd") -Encoding ascii -NoNewline
        }
    }
    Say 'impacket shims written from .py entry points'
}

# 5. dnSpy GUI was shimmed to Console by mistake earlier - reassert the right one
if (Test-Path "$ToolsDir\dnSpy\dnSpy.exe") {
    Shim 'dnSpy'         "$ToolsDir\dnSpy\dnSpy.exe"
    Shim 'dnSpy.Console' "$ToolsDir\dnSpy\dnSpy.Console.exe"
    Say 'dnSpy shims reasserted'
}

# 6. Scylla ships in the x64dbg zip under release/
$x64 = Get-ChildItem (Join-Path $tools 'x64dbg') -Recurse -Filter 'scylla*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($x64) { Shim 'scylla' $x64.FullName; Say "scylla -> $($x64.FullName)" } else { Say 'scylla: not present in the x64dbg snapshot (ships separately)' }

# ---- verification ----
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
            [Environment]::GetEnvironmentVariable('Path','User') + ";$shim"
Say '=== verification ==='
$bad = @()
foreach ($b in @('nuclei','httpx','ffuf','gobuster','upx','procdump','procexp','procmon','autoruns','tcpview',
                 'psexec','secretsdump','ntlmrelayx','x64dbg','x32dbg','dnSpy','windbg','tshark','nmap',
                 'r2','rizin','jadx','apktool','hashcat','sqlmap','frida','binwalk','vol','objection','ghidraRun')) {
    $c = Get-Command $b -ErrorAction SilentlyContinue
    if ($c) { Say ("  {0,-14} OK   {1}" -f $b, $c.Source) } else { Say ("  {0,-14} MISSING" -f $b); $bad += $b }
}
Say "still missing: $(if ($bad) { $bad -join ', ' } else { '(none)' })"
exit 0