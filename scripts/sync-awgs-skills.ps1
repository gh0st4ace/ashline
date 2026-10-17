#requires -Version 5.1
<#
.SYNOPSIS
    Syncs skills from the awesome-game-security repo into OpenCode.

.DESCRIPTION
    12 skills are exposed live through directory junctions in gameskills\, so a
    plain `git pull` inside the repo is enough to refresh them.

    The 13th skill (reverse-engineering) is copied instead of linked, because its
    ID would shadow the general-purpose reverse-engineering skill from
    ~/.agents/skills. It is installed as `game-security-reverse-engineering`.

.EXAMPLE
    pwsh -File "$env:USERPROFILE\.config\opencode\sync-awgs-skills.ps1"
#>

[CmdletBinding()]
param(
    [string]$Repo = "$CollectionsDir\awesome-game-security",
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

$ErrorActionPreference = 'Stop'
$repoSkills = Join-Path $Repo '.claude\skills'
$staging    = "$env:USERPROFILE\.config\opencode\gameskills"
$installDir = "$env:USERPROFILE\.config\opencode\skills\game-security-reverse-engineering"

# Skills wired up as junctions. `reverse-engineering` is deliberately absent.
$linked = @(
    'anti-cheat', 'dma-attack', 'game-engine', 'game-hacking',
    'game-server-security', 'game-supply-chain-security', 'graphics-api',
    'linux-platform-security', 'mobile-security', 'overview',
    'research-rigor', 'windows-kernel'
)

if (-not (Test-Path $repoSkills)) {
    throw "Repo skills not found at $repoSkills. Clone first: git clone --filter=blob:none --no-checkout --depth 1 https://github.com/gmh5225/awesome-game-security.git `"$Repo`""
}

if (-not $SkipPull) {
    Write-Host "Pulling latest from awesome-game-security..." -ForegroundColor Cyan
    git -C $Repo pull --ff-only
    if ($LASTEXITCODE -ne 0) { throw "git pull failed (exit $LASTEXITCODE)" }
}

# Refresh junctions: drop stale links, recreate ones whose target moved.
New-Item -ItemType Directory -Force -Path $staging | Out-Null
foreach ($id in $linked) {
    $target = Join-Path $repoSkills $id
    if (-not (Test-Path $target)) {
        Write-Warning "Skill '$id' no longer exists upstream - skipping"
        continue
    }
    $link = Join-Path $staging $id
    # Directory]::Delete removes the junction itself. Remove-Item -Recurse would
    # follow the link and delete the real skill directory in the repo.
    if (Test-Path $link) { [System.IO.Directory]::Delete($link, $false) }
    New-Item -ItemType Junction -Path $link -Target $target | Out-Null
}

# Refresh the renamed copy of reverse-engineering, preserving our frontmatter.
$src = Join-Path $repoSkills 'reverse-engineering'
if (Test-Path $src) {
    if (Test-Path $installDir) { Remove-Item $installDir -Recurse -Force }
    Copy-Item $src $installDir -Recurse -Force

    $skillMd = Join-Path $installDir 'SKILL.md'
    $text = Get-Content $skillMd -Raw
    $text = $text -replace '(?m)^name:.*$', 'name: game-security-reverse-engineering'
    $text = $text -replace '(?m)^description:.*$', 'description: Analyze supplied game binaries, anti-cheat and protection components, drivers, dumps, or traces through reproducible disassembly, decompilation, debugging, diffing, and interface reconstruction. Use for game/anti-cheat RE; use the general reverse-engineering skill for non-game binaries.'
    $text = $text -replace '(?m)^# Reverse-engineering tools', "# Game-security reverse-engineering tools`r`n`r`n> Installed as a renamed copy of the repo's ``reverse-engineering`` skill so it does not shadow the general-purpose ``reverse-engineering`` skill. Refresh with ``sync-awgs-skills.ps1``."
    # Write UTF-8 without BOM: Set-Content -Encoding utf8 in Windows PowerShell 5.1
    # emits a BOM, which breaks YAML frontmatter parsing in some skill readers.
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($skillMd, $text, $utf8NoBom)
    Write-Host "Refreshed: $installDir" -ForegroundColor Green
}

Write-Host ""
Write-Host "Linked skills: $($linked.Count)" -ForegroundColor Green
Write-Host "OpenCode watches these directories, so no restart is required." -ForegroundColor DarkGray