#requires -Version 5.1
<#
.SYNOPSIS
    Installs the offensive/defensive tooling the installed skills actually instruct using.

.DESCRIPTION
    Measured gap before this script: 109 skills referenced frida (54 files),
    radare2 (46), nmap (41), sqlmap (24), jadx (24), hashcat (18), apktool (15)
    and binwalk (14), while none of those binaries were on PATH. A skill that
    loads and then tells the model to run an absent tool is a dead end.

    Installs into $ToolsDir (the operator keeps bulk data off the system drive)
    and adds a shim directory to the user PATH.

    Idempotent: re-running skips anything already present. Always exits 0.
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

$log = Join-Path $PSScriptRoot 'logs\install-tools.log'
New-Item -ItemType Directory -Force -Path (Split-Path $log) | Out-Null
if ((Test-Path $log) -and ((Get-Item $log).Length -gt 1MB)) { Move-Item $log "$log.old" -Force }

function Say($msg) {
    $line = '{0} {1}' -f (Get-Date -Format 'HH:mm:ss'), $msg
    Add-Content -Path $log -Value $line -Encoding utf8
    Write-Host $line
}

function Shim($name, $target) {
    if (-not $target) { return }
    $p = Join-Path $shim "$name.cmd"
    "@echo off`r`n`"$target`" %*" | Set-Content -Path $p -Encoding ascii -NoNewline
}

$winget = 'Insecure.Nmap', 'Rizin.Rizin', 'Skylot.jadx'
$pip    = @('sqlmap', 'frida-tools', 'binwalk', 'capstone', 'uncompyle6', 'volatility3')
$zip    = @(
    @{ name = 'radare2'; url = 'https://github.com/radareorg/radare2/releases/download/6.2.4/radare2-6.2.4-w64.zip'; dir = 'radare2' },
    @{ name = 'hashcat'; url = 'https://github.com/hashcat/hashcat/releases/download/v7.1.2/hashcat-7.1.2.7z';  dir = 'hashcat' },
    @{ name = 'apktool'; url = 'https://github.com/iBotPeaches/Apktool/releases/download/v3.0.3/apktool_3.0.3.jar'; file = 'apktool.jar' }
)

# ---- winget ----
foreach ($id in $winget) {
    Say "winget install $id"
    winget install --id $id --exact --silent --accept-package-agreements --accept-source-agreements 2>&1 |
        Out-Null
    Say "  exit=$LASTEXITCODE"
}

# ---- pip ----
foreach ($p in $pip) {
    Say "pip install $p"
    python -m pip install --quiet --upgrade $p 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        python -m pip install --quiet --upgrade --break-system-packages $p 2>&1 | Out-Null
    }
    Say "  exit=$LASTEXITCODE"
}

# ---- archives ----
foreach ($z in $zip) {
    if ($z.file) {
        $out = Join-Path $tools $z.file
        if (Test-Path $out) { Say "$($z.name): already present"; continue }
        Say "download $($z.name)"
        curl.exe -L --retry 10 --retry-delay 5 --retry-all-errors -o $out $z.url 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Say "  ok $((Get-Item $out).Length) bytes" }
        else { Say "  FAILED exit=$LASTEXITCODE" }
    } else {
        $dir = Join-Path $tools $z.dir
        if (Test-Path $dir) { Say "$($z.name): already present"; continue }
        $zipPath = Join-Path $env:TEMP "$($z.name).zip"
        Say "download $($z.name)"
        curl.exe -L --retry 10 --retry-delay 5 --retry-all-errors -o $zipPath $z.url 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { Say "  download FAILED exit=$LASTEXITCODE"; continue }
        Say "  extracting"
        tar.exe -xf $zipPath -C $tools 2>&1 | Out-Null
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        Say "  extracted to $dir"
    }
}

# ---- shims for things not on PATH ----
$jdk = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'User')
Shim 'r2'      (Get-ChildItem $tools -Recurse -Filter 'radare2.exe' -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
Shim 'rabin2'  (Get-ChildItem $tools -Recurse -Filter 'rabin2.exe' -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
Shim 'apktool' $(if (Test-Path "$tools\apktool.jar") { "$jdk\bin\java.exe" } else { $null })
if (Test-Path "$tools\apktool.jar") {
    (Join-Path $shim 'apktool.cmd') | Out-Null
    "@echo off`r`n`"$jdk\bin\java.exe`" -jar `"$tools\apktool.jar`" %*" |
        Set-Content -Path (Join-Path $shim 'apktool.cmd') -Encoding ascii -NoNewline
}
Shim 'hashcat' (Get-ChildItem $tools -Recurse -Filter 'hashcat.exe' -ErrorAction SilentlyContinue | Select-Object -First 1).FullName

# ---- PATH ----
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$shim*") {
    [Environment]::SetEnvironmentVariable('Path', "$userPath;$shim", 'User')
    Say "added $shim to user PATH"
} else {
    Say 'shim dir already on user PATH'
}

Say '=== verification ==='
$env:Path = "$shim;$env:Path"
foreach ($b in 'nmap', 'r2', 'rabin2', 'jadx', 'apktool', 'hashcat', 'sqlmap', 'frida', 'binwalk') {
    $c = Get-Command $b -ErrorAction SilentlyContinue
    Say ("  {0,-10} {1}" -f $b, $(if ($c) { 'OK  ' + $c.Source } else { 'MISSING' }))
}
exit 0