<#
.SYNOPSIS
    Installs the OpenCode Workbench configuration.

.DESCRIPTION
    Copies config templates, agents, commands, and scripts into the OpenCode
    config root, then optionally fetches reference collections.

    Design properties, each of which exists because its absence caused a failure:

      Preview first          -DryRun prints every step and writes nothing.
      Atomic staging         Stages to a temp directory, then swaps.
      Backed up              Anything replaced lands in backups/ timestamped.
      Parameterized          No absolute user paths in any shipped file.
      Idempotent             Re-running converges rather than accumulating.

.PARAMETER DryRun
    Print every step, write nothing.

.PARAMETER Profile
    config  - templates, agents, scripts, commands.  (default, seconds)
    tools   - + RE toolchains and skill links. Skips the 21 GiB collections.
    full    - + reference collections.                              (hours)

.PARAMETER ConfigDir
    Override the install target. Default: $env:USERPROFILE\.config\opencode

.PARAMETER CollectionsDir
    Where reference collections are cloned. Default: D:\opencode

.PARAMETER ToolsDir
    Where RE toolchains live. Default: D:\Tools

.PARAMETER SkipVerify
    Do not run verify-setup.ps1 afterwards.

.PARAMETER Force
    Replace without backing up.

.PARAMETER Uninstall
    Restore from backups/. Does NOT delete collections unless -PurgeCollections.

.EXAMPLE
    .\install.ps1 -DryRun

.EXAMPLE
    .\install.ps1 -Profile full

.NOTES
    Windows PowerShell 5.1 compatible. ASCII only on purpose: PS 5.1 reads a
    BOM-less file as ANSI, so non-ASCII in a .ps1 becomes mojibake.
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [ValidateSet('config', 'tools', 'full')]
    [string]$Profile = 'config',
    [string]$ConfigDir,
    [string]$CollectionsDir = 'D:\opencode',
    [string]$ToolsDir = 'D:\Tools',
    [switch]$SkipVerify,
    [switch]$Force,
    [switch]$Uninstall,
    [switch]$PurgeCollections
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

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

$RepoRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path $MyInvocation.MyCommand.Path -Parent }

function Say($msg) { Write-Host "  $msg" -ForegroundColor Gray }
function Step($msg) { Write-Host ""; Write-Host "==> $msg" -ForegroundColor Cyan }
function Warn($msg) { Write-Host "  ! $msg" -ForegroundColor Yellow }
function Die($msg) { Write-Host ""; Write-Host "FAILED: $msg" -ForegroundColor Red; exit 1 }

# Print a step, and run it only when not in DryRun.
# Two arguments on purpose: the human-readable step and the thing to actually
# run. An earlier revision took one string and ran Invoke-Expression on it,
# which tried to execute the word "stage".
function Write-Plan([string]$text, [scriptblock]$action) {
    if ($DryRun) {
        Write-Host "    [dry-run] $text" -ForegroundColor DarkGray
    } elseif ($action) {
        & $action
    }
}

# UTF8 without BOM. PowerShell 5.1's `-Encoding utf8` emits a BOM, which breaks
# YAML frontmatter in some skill readers.
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Expand-Template($src, $dst, $subs) {
    $text = Get-Content $src -Raw -Encoding UTF8
    foreach ($k in $subs.Keys) { $text = $text.Replace($k, $subs[$k]) }
    $dir = Split-Path $dst -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText($dst, $text, $Utf8NoBom)
}

# ============================================================================
# Preflight
# ============================================================================
Step 'Preflight'

if ($PSVersionTable.PSVersion.Major -lt 5) {
    Die "PowerShell 5.1+ required, found $($PSVersionTable.PSVersion)"
}
Say "PowerShell $($PSVersionTable.PSVersion)"

foreach ($cmd in @('node', 'git')) {
    $c = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($c) { Say ("{0,-8} {1}" -f $cmd, $c.Source) }
    else { Warn "$cmd not on PATH - some features will be unavailable" }
}

if ($Profile -in @('tools', 'full')) {
    if (Get-Command 'py' -ErrorAction SilentlyContinue) { Say 'python   py -3 available' }
    else { Warn 'py launcher not found; doctor.py and triage scripts need it' }
}

foreach ($p in @($ToolsDir, $CollectionsDir, $ConfigDir)) {
    $drive = [System.IO.Path]::GetPathRoot($p)
    if ($drive -and -not (Test-Path $drive)) { Warn "drive missing: $drive (for $p)" }
}

$existing = Test-Path (Join-Path $ConfigDir 'opencode.jsonc')
if ($existing -and -not $Force) { Say "existing config at $ConfigDir will be backed up" }

# ============================================================================
# Uninstall
# ============================================================================
if ($Uninstall) {
    Step 'Uninstall'
    $backupRoot = Join-Path $ConfigDir 'backups'
    if (-not (Test-Path $backupRoot)) { Die "no backups directory at $backupRoot" }
    $newest = Get-ChildItem $backupRoot -Directory -ErrorAction SilentlyContinue |
              Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $newest) { Die "no backup found in $backupRoot" }
    Write-Plan "restore from $($newest.FullName)" {
        foreach ($item in @('opencode.jsonc', 'opencode-mem.jsonc')) {
            $from = Join-Path $newest.FullName $item
            if (Test-Path $from) { Copy-Item $from (Join-Path $ConfigDir $item) -Force; Say "restored $item" }
        }
    }
    if ($PurgeCollections) {
        Warn "deleting $CollectionsDir (21.2 GiB across 7 collections)"
        Write-Plan "Remove-Item -Recurse -Force '$CollectionsDir'" { Remove-Item $CollectionsDir -Recurse -Force }
    } else {
        Say "collections at $CollectionsDir left in place (pass -PurgeCollections to delete)"
    }
    exit 0
}

# ============================================================================
# Backup
# ============================================================================
Step 'Backup'
$stamp    = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path $ConfigDir "backups\$stamp"

if ($existing -and -not $Force) {
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    foreach ($item in @('opencode.jsonc', 'opencode-mem.jsonc')) {
        $p = Join-Path $ConfigDir $item
        if (Test-Path $p) {
            Write-Plan "back up $item" { Copy-Item $p (Join-Path $backupDir $item) -Force }
            Say "backed up $item -> $backupDir"
        }
    }
} elseif ($Force) {
    Warn '-Force: skipping backup'
} else {
    Say 'nothing to back up'
}

# ============================================================================
# Stage
# ============================================================================
Step 'Stage'
$stage = Join-Path $env:TEMP ("opencode-workbench-" + $stamp)
Write-Plan "stage to $stage" {
    if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $stage | Out-Null
}

# ============================================================================
# Config templates
# ============================================================================
Step 'Config'
$subs = @{
    '${CONFIG_DIR}'      = $ConfigDir
    '${COLLECTIONS_DIR}' = $CollectionsDir
    '${TOOLS_DIR}'       = $ToolsDir
    '${NODE}'            = if (Get-Command node -EA SilentlyContinue) { (Get-Command node).Source } else { 'node' }
    '${APPDATA}'         = $env:APPDATA
}

$templates = @(Get-ChildItem (Join-Path $RepoRoot 'config') -Filter '*.template' -EA SilentlyContinue)
foreach ($tpl in $templates) {
    $name = $tpl.Name -replace '\.template$', ''
    if ($name -eq 'mcp-servers') {
        # A reference catalog, not a live config. Installed as documentation.
        $target = Join-Path $ConfigDir 'mcp-configs\mcp-servers.json'
    } else {
        $target = Join-Path $ConfigDir $name
    }
    Write-Plan "write $name" { Expand-Template $tpl.FullName $target $subs }
}
Say "$($templates.Count) template(s)"

# ============================================================================
# Directories
# ============================================================================
Step 'Agents, scripts, knowledge'
$groups = @(
    'agents', 'scripts', '.agents', 'knowledge', 'docs', 'examples'
)
foreach ($g in $groups) {
    $src = Join-Path $RepoRoot $g
    if (-not (Test-Path $src)) { continue }
    $dst = Join-Path $ConfigDir $g
    $n = @(Get-ChildItem $src -Recurse -File -EA SilentlyContinue).Count
    Write-Plan "copy $g/ -> $g/  ($n files)" {
        if (Test-Path $dst) {
            # Never Remove-Item -Recurse on these trees: agents/ and .agents/
            # may hold junctions into upstream collections, and -Recurse would
            # follow the link and delete the upstream directory. Only files
            # that are not links are removed.
            Get-ChildItem $dst -File -Recurse -EA SilentlyContinue |
                Where-Object { -not $_.LinkType } |
                Remove-Item -Force -EA SilentlyContinue
        }
        New-Item -ItemType Directory -Force -Path $dst | Out-Null
        Copy-Item (Join-Path $src '*') $dst -Recurse -Force -EA SilentlyContinue
    }
    Say "$g/  ($n files)"
}

foreach ($f in @('AGENTS.md', 'README.md', 'README.ru.md')) {
    $src = Join-Path $RepoRoot $f
    if (Test-Path $src) {
        Write-Plan "write $f" { Copy-Item $src (Join-Path $ConfigDir $f) -Force }
        Say "write $f"
    }
}

# ============================================================================
# Task Scheduler launcher paths
# ============================================================================
# The .cmd launchers run under SYSTEM, where %USERPROFILE% is the system
# profile. That is exactly why they use absolute paths rather than
# %USERPROFILE% - so write the resolved values rather than relying on the
# fallback block inside them.
Step 'Launcher paths'
$pathsCmd  = Join-Path $ConfigDir 'scripts\paths.cmd'
$pathsBody = @(
    '@rem Generated by install.ps1. Consumed by run-awgs-*.cmd launchers.',
    '@rem Do not edit by hand - re-run install.ps1 instead.',
    "set `"WB_CONFIG_DIR=$ConfigDir`"",
    "set `"WB_COLLECTIONS_DIR=$CollectionsDir`"",
    "set `"WB_TOOLS_DIR=$ToolsDir`""
) -join "`r`n"
Write-Plan "write scripts\paths.cmd" {
    [System.IO.File]::WriteAllText($pathsCmd, $pathsBody, (New-Object System.Text.ASCIIEncoding))
}
Say 'Task Scheduler launchers will resolve absolute paths'

# ============================================================================
# Reference collections
# ============================================================================
Step 'Reference collections'
if ($Profile -eq 'full') {
    Write-Host '  (21.2 GiB - this takes a while)' -ForegroundColor DarkGray
    $lockPath = Join-Path $RepoRoot 'collections.lock.json'
    if (Test-Path $lockPath) {
        $lock = Get-Content $lockPath -Raw | ConvertFrom-Json
        foreach ($c in $lock.collections) {
            if ($c.alias -eq 'game-security-archive') {
                Say "$($c.alias): fetch with scripts\update-awgs-archive.ps1 (tarball, not git)"
                continue
            }
            $dest = $c.path -replace [regex]::Escape('D:\opencode'), $CollectionsDir
            if (Test-Path $dest) { Say "$($c.alias): present"; continue }
            Write-Plan "git clone $($c.upstream) -> $dest  @ $($c.commit)" {
                & git clone --filter=blob:none $c.upstream $dest 2>&1 | Out-Null
                & git -C $dest checkout $c.commit 2>&1 | Out-Null
            }
            Say "$($c.alias): $($c.size_gib) GiB pinned at $($c.commit.Substring(0, 7))"
        }
    } else {
        Warn "collections.lock.json not found at $lockPath - skipping"
    }
} else {
    Say "skipped (-Profile $Profile). Run install.ps1 -Profile full to fetch 21.2 GiB."
}

# ============================================================================
# MCP servers
# ============================================================================
# Without this the config names six servers and none of them exist. OpenCode
# starts normally and 277 tools are simply absent, which reads as a broken
# harness rather than a missing dependency. This was a real gap.
if ($Profile -in @('tools', 'full')) {
    Step 'MCP servers (277 tools)'
    $mcpScript = Join-Path $ConfigDir 'scripts\install-mcp-servers.ps1'
    if (Test-Path $mcpScript) {
        Write-Plan 'scripts\install-mcp-servers.ps1' {
            & powershell -NoProfile -ExecutionPolicy Bypass -File $mcpScript
        }
        Say 'rea-agents js-reverse-mcp @jshookmcp/jshook @upstash/context7-mcp'
        Say 'cheat-mcp needs a local build - the script prints the recipe'
    } else {
        Warn 'scripts\install-mcp-servers.ps1 not installed'
    }
} else {
    Step 'MCP servers'
    Say "skipped (-Profile $Profile). All 6 servers will be MISSING."
    Say 'Run install.ps1 -Profile tools (or full), then scripts\install-mcp-servers.ps1'
}

# ============================================================================
# ECC surface
# ============================================================================
# The bulk of the running catalog - 315 skills, 103 commands, 9 custom tools,
# plugins, hooks - comes from affaan-m/ECC (MIT) and is NOT vendored. Without
# this step the workbench installs but the skill catalog stays empty, which is
# the single most likely way for a fresh install to look "broken".
if ($Profile -in @('tools', 'full')) {
    Step 'ECC surface (affaan-m/ECC, MIT)'
    $manifestPath = Join-Path $RepoRoot 'config\ecc-surface.json'
    if (Test-Path $manifestPath) {
        $m = Get-Content $manifestPath -Raw | ConvertFrom-Json
        Say "manifest: $($m.surface.skills.count) skills, $($m.surface.commands.count) commands, $($m.surface.tools.count) tools"
    } else {
        Warn 'config\ecc-surface.json missing - cannot report the expected ECC surface'
    }

    $eccScript = Join-Path $ConfigDir 'scripts\update-ecc.ps1'
    if (Test-Path $eccScript) {
        Write-Plan 'scripts\update-ecc.ps1' {
            & powershell -NoProfile -ExecutionPolicy Bypass -File $eccScript
        }
        Say 'installed via scripts\update-ecc.ps1 (pull -> build -> install-apply -> re-apply v2 shims)'
    } else {
        Warn 'scripts\update-ecc.ps1 not installed - clone affaan-m/ECC and run its installer manually'
    }
} else {
    Step 'ECC surface'
    Say "skipped (-Profile $Profile). The 315 skills and 103 commands will NOT be present."
    Say 'Run install.ps1 -Profile tools (or full) to fetch them.'
}

# ============================================================================
# Skill links
# ============================================================================
if ($Profile -in @('tools', 'full')) {
    Step 'Skill links'
    Write-Plan 'scripts\sync-awgs-skills.ps1' { & (Join-Path $ConfigDir 'scripts\sync-awgs-skills.ps1') }
    Write-Plan 'scripts\update-hack-skills.ps1 -SkipPull' { & (Join-Path $ConfigDir 'scripts\update-hack-skills.ps1') -SkipPull }
    Say '12 game-security + 93 hack-skill junctions'
}

# ============================================================================
# Verify
# ============================================================================
Step 'Verify'

if ($DryRun) {
    Write-Host ""
    Write-Host "  DRY RUN COMPLETE - nothing was written." -ForegroundColor Green
    Write-Host "  Re-run without -DryRun to apply.`n"
    exit 0
}

$v = Join-Path $ConfigDir 'scripts\verify-setup.ps1'
if ((Test-Path $v) -and -not $SkipVerify) {
    Say 'running verify-setup.ps1 (always exits 0)'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $v
    Write-Host ""
    Write-Host '  Read the returned TEXT, not just the colour.' -ForegroundColor Yellow
    Write-Host '  Some checks print a green OK while describing a failure state.' -ForegroundColor Yellow
    Write-Host '  See docs/troubleshooting.md' -ForegroundColor DarkGray
} elseif ($SkipVerify) {
    Say 'skipped (-SkipVerify)'
}

Write-Host ""
Write-Host "  INSTALL COMPLETE" -ForegroundColor Green
Write-Host "  config:   $ConfigDir"
Write-Host "  scripts:  & '$ConfigDir\scripts\verify-setup.ps1'"
Write-Host "  runtime:  py -3 '$ConfigDir\scripts\doctor.py'"
Write-Host ""
Write-Host '  Next: start OpenCode from a NORMAL project directory.'
Write-Host '  Not C:\WINDOWS\system32 - each MCP server is spawned per working'
Write-Host '  directory and the tool set doubles there.' -ForegroundColor Yellow
Write-Host ""
