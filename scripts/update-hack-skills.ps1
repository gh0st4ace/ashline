#requires -Version 5.1
<#
.SYNOPSIS
    Pulls yaklang/hack-skills and re-links its 103 skills into OpenCode.

.DESCRIPTION
    Skills are exposed through NTFS directory junctions in hackskills\, so the
    repo content is read live and `git pull` alone refreshes every SKILL.md and
    its supporting .md files. This script only re-creates the junctions, which is
    needed when upstream adds, removes, or renames a skill directory.

    New skills upstream show up on the next session without any further action.

    Always exits 0: safe to run unattended.
#>

[CmdletBinding()]
param(
    [string]$Repo    = "$CollectionsDir\hack-skills",
    [switch]$SkipPull
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

# Generic routers are kept on disk but left out of the skill catalog. Their
# descriptions are broad enough to compete with every leaf skill in the same
# domain, which measurably degrades selection; the leaf skills are far more
# discriminating. `hack` additionally carries a 657-char catch-all description
# that wins the match on almost any security task and then applies an
# authorization gate. All ten remain readable at
# $CollectionsDir\hack-skills\skills\<id>\SKILL.md and can be loaded by hand.
$notInCatalog = @(
    'hack', 'api-sec', 'auth-sec', 'recon-for-sec',
    'business-logic-vuln', 'injection-checking', 'file-access-vuln',
    'recon-and-methodology', 'api-recon-and-docs', 'api-auth-and-jwt-abuse'
)

$ErrorActionPreference = 'Continue'

$logDir = Join-Path $PSScriptRoot 'logs'
$log    = Join-Path $logDir 'awgs-update.log'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
if ((Test-Path $log) -and ((Get-Item $log).Length -gt 2MB)) {
    Move-Item $log "$log.old" -Force
}

function Write-Log {
    param([string]$Level, [string]$Message)
    Add-Content -Path $log -Value ('{0} [{1}] hack-skills: {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message) -Encoding utf8
}

$repoSkills = Join-Path $Repo 'skills'
$staging    = Join-Path $PSScriptRoot 'hackskills'

if (-not (Test-Path $repoSkills)) {
    Write-Log ERROR "repo not found at $repoSkills - skipping"
    exit 0
}

if (-not $SkipPull) {
    $before = (& git -c "safe.directory=$Repo" -C $Repo rev-parse HEAD 2>$null)
    $pull = & git -c "safe.directory=$Repo" -C $Repo pull --ff-only 2>&1
    if ($LASTEXITCODE -ne 0) {
        foreach ($l in $pull) { Write-Log WARN "pull: $l" }
    } else {
        $after = (& git -c "safe.directory=$Repo" -C $Repo rev-parse HEAD 2>$null)
        if ($after -eq $before) {
            Write-Log INFO 'already up to date'
        } else {
            Write-Log INFO "updated $before -> $after"
        }
    }
}

New-Item -ItemType Directory -Force -Path $staging | Out-Null
$linked = 0
foreach ($d in Get-ChildItem $repoSkills -Directory) {
    if (-not (Test-Path (Join-Path $d.FullName 'SKILL.md'))) { continue }
    if ($notInCatalog -contains $d.Name) { continue }
    $link = Join-Path $staging $d.Name
    # Directory]::Delete removes the junction itself; Remove-Item -Recurse would
    # follow the link and delete the real skill directory in the repo.
    if (Test-Path $link) { [System.IO.Directory]::Delete($link, $false) }
    New-Item -ItemType Junction -Path $link -Target $d.FullName | Out-Null
    $linked++
}

# Drop junctions whose upstream directory is gone, so a removed skill actually
# disappears from OpenCode's catalog instead of dangling.
$live = (Get-ChildItem $repoSkills -Directory | Where-Object { $notInCatalog -notcontains $_.Name }).Name
$removed = 0
foreach ($l in Get-ChildItem $staging -Directory) {
    if ($live -notcontains $l.Name) {
        [System.IO.Directory]::Delete($l.FullName, $false)
        $removed++
        Write-Log INFO "removed stale link: $($l.Name)"
    }
}

$total = (Get-ChildItem $staging -Directory).Count
Write-Log INFO "linked $linked skills, removed $removed stale, catalog now $total"

exit 0