#requires -Version 5.1
<#
.SYNOPSIS
    Binary triage stack for cheat / game / software reverse engineering.

.DESCRIPTION
    capa    - automatically reports what a binary can DO (injection, memory
              write, anti-debug, persistence). Turns an unknown cheat binary
              into a capability list instead of manual reading.
    FLOSS   - recovers every string including stack-constructed, base64 and
              obfuscated ones. The single biggest time saver when reversing
              packed or string-obfuscated software.
    LIEF    - Python PE/ELF/Mach-O parser and editor; for injection, section
              work and header patching from scripts.
    DIE     - packer / protector / compiler identification.

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

$log = Join-Path $PSScriptRoot 'logs\install-triage.log'
New-Item -ItemType Directory -Force -Path (Split-Path $log) | Out-Null
function Say($m) {
    $l = '{0} {1}' -f (Get-Date -Format 'HH:mm:ss'), $m
    Add-Content -Path $log -Value $l -Encoding utf8
    Write-Host $l
}
function Shim($n, $t) { if ($t) { "@echo off`r`n`"$t`" %*" | Set-Content -Path (Join-Path $shim "$n.cmd") -Encoding ascii -NoNewline } }

# ---------- capa ----------
$dir = Join-Path $tools 'capa'
$c = Get-ChildItem $dir -Recurse -Filter 'capa.exe' -EA SilentlyContinue | Select-Object -First 1
if ($c) {
    Say "capa already at $($c.FullName)"
} else {
    $zip = Join-Path $env:TEMP 'capa.zip'
    Say 'download capa v9.4.0'
    curl.exe -L --retry 5 --retry-delay 3 --retry-all-errors -s -o $zip 'https://github.com/mandiant/capa/releases/download/v9.4.0/capa-v9.4.0-windows.zip' 2>&1 | Out-Null
    if (Test-Path $zip) {
        Say ("  {0:N1} MB" -f ((Get-Item $zip).Length/1MB))
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        tar.exe -xf $zip -C $dir 2>&1 | Out-Null
        Remove-Item $zip -Force -EA SilentlyContinue
        $c = Get-ChildItem $dir -Recurse -Filter 'capa.exe' -EA SilentlyContinue | Select-Object -First 1
    }
}
if ($c) {
    Say "  ok $($c.FullName)"
    Shim 'capa' $c.FullName
    # capa needs its rules next to the binary or pointed at explicitly
    $rules = Join-Path (Split-Path $c.FullName) 'capa-rules'
    if (-not (Test-Path $rules)) {
        $rz = Join-Path $env:TEMP 'capa-rules.zip'
        curl.exe -L --retry 3 --retry-delay 2 --retry-all-errors -s -o $rz 'https://github.com/mandiant/capa-rules/archive/refs/heads/master.zip' 2>&1 | Out-Null
        if (Test-Path $rz) {
            tar.exe -xf $rz -C (Split-Path $c.FullName) 2>&1 | Out-Null
            Remove-Item $rz -Force -EA SilentlyContinue
            Say "  rules extracted"
        }
    } else { Say '  capa-rules present' }
} else { Say 'capa FAILED' }

# ---------- DIE ----------
$die = Get-ChildItem (Join-Path $tools 'die') -Recurse -Filter 'die.exe' -EA SilentlyContinue | Select-Object -First 1
if ($die) {
    Say "DIE already at $($die.FullName)"
} else {
    # Detect It Easy publishes per-platform builds; resolve the Windows one.
    $url = $null
    try {
        $rel = Invoke-RestMethod 'https://api.github.com/repos/horsicq/Detect-It-Easy/releases/latest' -Headers @{ 'User-Agent' = 'ps' } -ErrorAction Stop
        $a = $rel.assets | Where-Object { $_.name -match 'win.*\.zip$' } | Select-Object -First 1
        if ($a) { $url = $a.browser_download_url; Say "DIE asset: $($a.name)" }
    } catch { Say "DIE release lookup failed: $($_.Exception.Message)" }
    if ($url) {
        $zip = Join-Path $env:TEMP 'die.zip'
        curl.exe -L --retry 5 --retry-delay 3 --retry-all-errors -s -o $zip $url 2>&1 | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $tools 'die') | Out-Null
        if (Test-Path $zip) { tar.exe -xf $zip -C (Join-Path $tools 'die') 2>&1 | Out-Null; Remove-Item $zip -Force -EA SilentlyContinue }
        $die = Get-ChildItem (Join-Path $tools 'die') -Recurse -Filter 'die.exe' -EA SilentlyContinue | Select-Object -First 1
    }
}
if ($die) { Say "  ok $($die.FullName)"; Shim 'die' $die.FullName } else { Say 'DIE: no Windows build resolved from the latest release' }

# ---------- python: LIEF + FLOSS ----------
foreach ($p in 'lief', 'flare-floss') {
    Say "pip install $p"
    python -m pip install --quiet --upgrade $p 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { python -m pip install --quiet --upgrade --break-system-packages $p 2>&1 | Out-Null }
    Say "  exit=$LASTEXITCODE"
}
$ps = "$UserProfile\AppData\Local\Python\pythoncore-3.14-64\Scripts"
foreach ($n in 'floss') {
    $f = Join-Path $ps "$n.exe"
    if (Test-Path $f) { Shim $n $f; Say "shim $n -> $f" } else { Say "$n entry point not found" }
}

# ---- verification: actually execute ----
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
            [Environment]::GetEnvironmentVariable('Path','User') + ";$shim"
Say '=== verification ==='
foreach ($p in @(@('capa','--version'), @('floss','--version'), @('die','--version'))) {
    $c = Get-Command $p[0] -EA SilentlyContinue
    if (-not $c) { Say ("  {0,-8} MISSING" -f $p[0]); continue }
    try {
        $o = & $p[0] $p[1] 2>&1 | Out-String
        $l = ($o -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -First 1)
        Say ("  {0,-8} OK {1}" -f $p[0], $(if($l){$l.Trim().Substring(0,[Math]::Min(46,$l.Trim().Length))}else{$c.Source}))
    } catch { Say ("  {0,-8} OK (no banner)" -f $p[0]) }
}
Say "lief import: $(python -c 'import lief; print(lief.__version__)' 2>&1 | Select-Object -First 1)"
exit 0