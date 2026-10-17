#requires -Version 5.1
<#
.SYNOPSIS
    Pulls the latest awesome-game-security content and re-syncs the OpenCode skills.

.DESCRIPTION
    Runs unattended from Task Scheduler, so it must not prompt and must not fail
    loudly when the network is unavailable. Every step is logged to
    %USERPROFILE%\.config\opencode\logs\awgs-update.log and the script always
    exits 0.

    Git runs under whatever account the task uses, which usually is not the
    account that owns the clone. Each invocation therefore passes
    -c safe.directory explicitly instead of mutating global git config.
#>

[CmdletBinding()]
param(
    [string]$Repo = "$CollectionsDir\awesome-game-security"
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

function Write-Log {
    param([string]$Level, [string]$Message)
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -Path $log -Value $line -Encoding utf8
    if ($Level -eq 'ERROR') { Write-Warning $Message }
}

# Keep the log bounded; it appends on every scheduled run.
if ((Test-Path $log) -and ((Get-Item $log).Length -gt 2MB)) {
    Move-Item $log "$log.old" -Force
}

$repoSkills = Join-Path $Repo '.claude\skills'
if (-not (Test-Path $repoSkills)) {
    Write-Log ERROR "Repo not found at $Repo - skipping"
    exit 0
}

$before = (& git -c "safe.directory=$Repo" -C $Repo rev-parse HEAD 2>$null)
if ($LASTEXITCODE -ne 0) {
    Write-Log ERROR "git rev-parse failed in $Repo - skipping"
    exit 0
}

# archive/ (~18 GiB of upstream source mirrors) is not managed by git. It is
# fetched separately from the GitHub tarball, because a blobless partial clone
# stalls materializing that many lazy-fetched blobs. Refresh it with
# -ArchiveOnly on the same schedule.
$sparse = @('.claude', 'description', 'scripts', 'wiki')
& git -c "safe.directory=$Repo" -C $Repo sparse-checkout set @sparse 2>&1 |
    ForEach-Object { Write-Log INFO "sparse: $_" }
if ($LASTEXITCODE -ne 0) { Write-Log WARN "sparse-checkout set failed (exit $LASTEXITCODE)" }

# Upstream may add or remove skills. Reset before pulling so renames apply.
& git -c "safe.directory=$Repo" -C $Repo reset --hard HEAD 2>&1 | Out-Null
& git -c "safe.directory=$Repo" -C $Repo clean -fd 2>&1 | Out-Null

$pull = & git -c "safe.directory=$Repo" -C $Repo pull --ff-only 2>&1
$code = $LASTEXITCODE
foreach ($l in $pull) { Write-Log INFO "pull: $l" }

if ($code -ne 0) {
    Write-Log WARN "git pull did not fast-forward (exit $code); keeping the current checkout"
}

$after = (& git -c "safe.directory=$Repo" -C $Repo rev-parse HEAD 2>$null)

if ($after -eq $before) {
    Write-Log INFO "Already up to date at $before"
} else {
    Write-Log INFO "Updated $before -> $after"
}

# Recreate junctions and refresh the renamed reverse-engineering copy.
& (Join-Path $PSScriptRoot 'sync-awgs-skills.ps1') -Repo $Repo -SkipPull 2>&1 |
    ForEach-Object { Write-Log INFO "sync: $_" }

$skillCount = (Get-ChildItem (Join-Path $Repo '.claude\skills') -Directory).Count
Write-Log INFO "Done. Repo now exposes $skillCount skills."

exit 0