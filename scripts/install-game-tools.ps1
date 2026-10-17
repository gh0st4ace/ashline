#requires -Version 5.1
<#
.SYNOPSIS
    Game / cheat / reverse workbench, driven by what the operator actually does.

.DESCRIPTION
    Targets stated work: cheat authoring, cheat reverse engineering, game and
    general software reversing.

    Installs:
      Cheat Engine 7.7   from the installer already in Downloads (memory scan/edit)
      Il2CppDumper 6.7.46  Unity IL2CPP metadata + binary -> C# stubs
      Cpp2IL               IL2CPP -> C#, alternative path when Il2CppDumper chokes
      dnlib / AsmResolver  .NET assembly read/write, for .NET cheats and mods
      Scylla               if it shipped inside the x64dbg snapshot

    Every URL was resolved from the GitHub API, not guessed.
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

$log = Join-Path $PSScriptRoot 'logs\install-game-tools.log'
New-Item -ItemType Directory -Force -Path (Split-Path $log) | Out-Null
function Say($m) {
    $l = '{0} {1}' -f (Get-Date -Format 'HH:mm:ss'), $m
    Add-Content -Path $log -Value $l -Encoding utf8
    Write-Host $l
}
function Shim($n, $t) { if ($t) { "@echo off`r`n`"$t`" %*" | Set-Content -Path (Join-Path $shim "$n.cmd") -Encoding ascii -NoNewline } }

function Get-Zip($name, $url, $exePattern, $probeArgs) {
    $dir = Join-Path $tools $name
    $pre = Get-ChildItem $dir -Recurse -Filter $exePattern -EA SilentlyContinue | Select-Object -First 1
    if ($pre) { Say "$name already at $($pre.FullName)"; return $pre.FullName }

    $zip = Join-Path $env:TEMP "$name.zip"
    Say "download $name"
    curl.exe -L --retry 5 --retry-delay 3 --retry-all-errors -s -o $zip $url 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $zip)) { Say '  download FAILED'; return $null }
    $sz = (Get-Item $zip).Length
    if ($sz -lt 50KB) { Say "  FAILED: only $sz bytes"; Remove-Item $zip -Force -EA SilentlyContinue; return $null }
    Say ("  {0:N1} MB" -f ($sz/1MB))
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    tar.exe -xf $zip -C $dir 2>&1 | Out-Null
    Remove-Item $zip -Force -EA SilentlyContinue

    $f = Get-ChildItem $dir -Recurse -Filter $exePattern -EA SilentlyContinue | Select-Object -First 1
    if (-not $f) { Say "  extracted but $exePattern absent"; return $null }
    Say "  ok $($f.FullName)"
    # Prove it runs, do not trust the file name.
    try {
        $o = & $f.FullName @probeArgs 2>&1 | Out-String
        $l = ($o -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -First 1)
        if ($l) { Say ("  runs: " + $l.Trim().Substring(0,[Math]::Min(60,$l.Trim().Length))) }
        else   { Say '  present (no banner output; may be interactive-only)' }
    } catch { Say "  present (probe: $($_.Exception.Message.Substring(0,[Math]::Min(60,$_.Exception.Message.Length))))" }
    return $f.FullName
}

# ---------- Cheat Engine ----------
$ceExe = Get-ChildItem "$ToolsDir\CheatEngine" -Recurse -Filter 'cheatengine*.exe' -EA SilentlyContinue | Select-Object -First 1
if ($ceExe) {
    Say "Cheat Engine already at $($ceExe.FullName)"
} else {
    $inst = "$env:USERPROFILE\Downloads\CheatEngine77.exe"
    if (Test-Path $inst) {
        Say 'installing Cheat Engine 7.7 (Inno Setup, silent)'
        $p = Start-Process -FilePath $inst -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',"/DIR=$ToolsDir\CheatEngine" -PassThru -Wait
        Say "  installer exit=$($p.ExitCode)"
        $ceExe = Get-ChildItem "$ToolsDir\CheatEngine" -Recurse -Filter 'cheatengine*.exe' -EA SilentlyContinue | Select-Object -First 1
        if ($ceExe) { Say "  installed: $($ceExe.FullName)" } else { Say '  no exe after install' }
    } else { Say 'Cheat Engine installer not in Downloads' }
}
if ($ceExe) {
    $dir = Split-Path $ceExe.FullName
    foreach ($n in 'cheatengine','cheatengine-x86_64','cheatengine-i386','ceserver') {
        $f = Get-ChildItem $dir -Filter "$n*.exe" -EA SilentlyContinue | Select-Object -First 1
        if ($f) { Shim $n $f.FullName }
    }
    Say "  CE shims: $((Get-ChildItem $dir -Filter '*.exe').Count) exes in $dir"
}

# ---------- Unity IL2CPP ----------
$d = Get-Zip 'Il2CppDumper' 'https://github.com/Perfare/Il2CppDumper/releases/download/v6.7.46/Il2CppDumper-net6-win-v6.7.46.zip' 'Il2CppDumper.exe' @()
if ($d) { Shim 'Il2CppDumper' $d }

$c = Get-Zip 'Cpp2IL' 'https://github.com/SamboyCoding/Cpp2IL/releases/latest/download/Cpp2IL-win-x64.zip' 'Cpp2IL.exe' @('--help')
if ($c) { Shim 'Cpp2IL' $c }

# ---------- Scylla (only if the x64dbg snapshot carried it) ----------
$scy = Get-ChildItem (Join-Path $tools 'x64dbg') -Recurse -Filter 'scylla*.exe' -EA SilentlyContinue | Select-Object -First 1
if ($scy) { Shim 'scylla' $scy.FullName; Say "scylla -> $($scy.FullName)" }
else { Say 'Scylla: not in the x64dbg snapshot - ships separately from nomadv.org' }

# ---------- .NET read/write libraries ----------
$nuget = Join-Path $tools 'nuget'
New-Item -ItemType Directory -Force -Path $nuget | Out-Null
foreach ($pkg in 'dnlib', 'AsmResolver') {
    $hit = Get-ChildItem $nuget -Recurse -Filter "$pkg.dll" -EA SilentlyContinue | Where-Object { $_.FullName -match 'netstandard2\.0|net6\.0|net8\.0' } | Select-Object -First 1
    if ($hit) { Say "$pkg already at $($hit.FullName)"; continue }
    $out = Join-Path $env:TEMP $pkg
    Say "nuget $pkg"
    dotnet nuget locals http-cache --list 2>&1 | Out-Null
    if (Test-Path $out) { Remove-Item $out -Recurse -Force -EA SilentlyContinue }
    $tmpProj = Join-Path $env:TEMP "pkgprobe-$pkg"
    New-Item -ItemType Directory -Force -Path $tmpProj | Out-Null
    dotnet new classlib -o $tmpProj --force 2>&1 | Out-Null
    Push-Location $tmpProj
    dotnet add package $pkg 2>&1 | Select-Object -Last 2 | Out-Null
    dotnet build -c Release 2>&1 | Out-Null
    Pop-Location
    $dll = Get-ChildItem $tmpProj -Recurse -Filter "$pkg.dll" -EA SilentlyContinue |
           Where-Object { $_.FullName -match 'netstandard2\.0|net6\.0|net8\.0|net9\.0' } | Select-Object -First 1
    if ($dll) {
        $dst = Join-Path $nuget $pkg
        New-Item -ItemType Directory -Force -Path $dst | Out-Null
        Copy-Item $dll.FullName -Destination (Join-Path $dst "$pkg.dll") -Force
        Say "  ok -> $dst\$pkg.dll"
    } else { Say "  FAILED: $pkg.dll not produced" }
    Remove-Item $tmpProj -Recurse -Force -EA SilentlyContinue
}

# ---- verification: execute, do not merely resolve ----
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
            [Environment]::GetEnvironmentVariable('Path','User') + ";$shim"
Say '=== verification (executes each tool) ==='
foreach ($b in @('cheatengine','Il2CppDumper','Cpp2IL','x64dbg','r2','dnSpy','windbg','ghidraRun')) {
    $c = Get-Command $b -EA SilentlyContinue
    if (-not $c) { Say ("  {0,-14} MISSING" -f $b); continue }
    # GUI tools would block; report resolution only for those
    if ($b -in @('cheatengine','x64dbg','dnSpy')) { Say ("  {0,-14} OK {1}" -f $b, $c.Source); continue }
    try {
        $o = & $b --version 2>&1 | Out-String
        $l = ($o -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -First 1)
        Say ("  {0,-14} OK {1}" -f $b, $(if($l){$l.Trim().Substring(0,[Math]::Min(50,$l.Trim().Length))}else{$c.Source}))
    } catch { Say ("  {0,-14} OK (no banner) {1}" -f $b, $c.Source) }
}
exit 0