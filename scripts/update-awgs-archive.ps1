#requires -Version 5.1
<#
.SYNOPSIS
    Mirrors archive/ from the awesome-game-security repo.

.DESCRIPTION
    The main clone is a blobless partial clone on purpose so that daily git pulls
    stay cheap. Materializing archive/ (~18 GiB, 4086 upstream source snapshots)
    through git's lazy blob fetch is slow and stalls easily, so archive/ is
    mirrored from the GitHub tarball instead.

    The tarball is gzip-compressed, so roughly 3-4x less data crosses the wire
    than the raw blob sizes. Downloads are retried; a completed .tar.gz is kept
    as a cache and only re-downloaded when -Force is passed.

    Exit code is always 0: this runs unattended from Task Scheduler.
#>

[CmdletBinding()]
param(
    [string]$ArchiveDir = "$CollectionsDir\awesome-game-security-archive",
    [string]$Cache      = "$CollectionsDir\ags-archive.tar.gz",
    [string]$Url        = 'https://codeload.github.com/gmh5225/awesome-game-security/tar.gz/refs/heads/main',
    [int]$MaxAgeDays    = 7,
    [switch]$Force,
    [switch]$ExtractOnly
)

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

$logDir = Join-Path $PSScriptRoot 'logs'
$log    = Join-Path $logDir 'awgs-update.log'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
if ((Test-Path $log) -and ((Get-Item $log).Length -gt 2MB)) {
    Move-Item $log "$log.old" -Force
}

function Write-Log {
    param([string]$Level, [string]$Message)
    Add-Content -Path $log -Value ('{0} [{1}] archive: {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message) -Encoding utf8
}

if (-not $ExtractOnly) {
    # Re-download when the cached tarball is older than -MaxAgeDays. Without this
    # the cache would be reused forever and archive/ would never advance.
    $cacheAge = if (Test-Path $Cache) { (Get-Date) - (Get-Item $Cache).LastWriteTime } else { $null }
    $fresh = $cacheAge -and $cacheAge.TotalDays -lt $MaxAgeDays

    if ($fresh -and -not $Force) {
        Write-Log INFO ("tarball cache is {0:N1} days old, reusing it" -f $cacheAge.TotalDays)
    } else {
        $part = "$Cache.part"
        Write-Log INFO "downloading $Url"
        $started = Get-Date
        # --speed-limit/--speed-time abort only when throughput truly collapses,
        # so a slow but live link is not restarted from zero.
        & curl.exe -L --retry 20 --retry-delay 10 --retry-all-errors `
            --connect-timeout 60 --speed-limit 20000 --speed-time 120 `
            -o $part $Url
        $code = $LASTEXITCODE
        $gb = if (Test-Path $part) { [math]::Round((Get-Item $part).Length / 1GB, 2) } else { 0 }
        $mins = [math]::Round(((Get-Date) - $started).TotalMinutes, 1)

        if ($code -ne 0) {
            Write-Log ERROR "curl failed (exit $code) after $gb GB / $mins min"
            exit 0
        }
        Move-Item $part $Cache -Force
        Write-Log INFO "downloaded $gb GB in $mins min"
    }
}

if (-not (Test-Path $Cache)) {
    Write-Log ERROR "no tarball at $Cache and download did not produce one"
    exit 0
}

# Extract the tarball into a staging directory, then swap it into place. tar on
# Windows 10+ handles gzip natively.
$stage = Join-Path (Split-Path $Cache -Parent) 'ags-extract'
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $stage | Out-Null

Write-Log INFO 'extracting tarball'
# No include filter: the whole repository is ~18.3 GiB and archive/ is ~18.2 GiB
# of it, so filtering out the remaining 67 MB saves nothing. bsdtar on Windows
# does not accept --wildcards here.
& tar.exe -xzf $Cache -C $stage 2>&1 |
    Select-Object -Last 5 | ForEach-Object { Write-Log INFO "tar: $_" }

$extracted = Get-ChildItem $stage -Directory | ForEach-Object { Join-Path $_.FullName 'archive' } |
    Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $extracted) {
    Write-Log ERROR 'tarball did not contain an archive/ subtree'
    exit 0
}

# Swap directories so the mirror is never half-written.
$new = "$ArchiveDir.new"
if (Test-Path $new) { Remove-Item $new -Recurse -Force -ErrorAction SilentlyContinue }
Move-Item $extracted $new -Force

$old = "$ArchiveDir.old"
if (Test-Path $old) { Remove-Item $old -Recurse -Force -ErrorAction SilentlyContinue }
if (Test-Path $ArchiveDir) { Move-Item $ArchiveDir $old -Force }
Move-Item $new $ArchiveDir -Force
Remove-Item $old -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue

$files = (Get-ChildItem $ArchiveDir -Recurse -File -Force).Count
$gb = [math]::Round((Get-ChildItem $ArchiveDir -Recurse -File -Force | Measure-Object Length -Sum).Sum / 1GB, 2)
Write-Log INFO "archive/ mirrored to $ArchiveDir ($gb GB, $files files)"

exit 0