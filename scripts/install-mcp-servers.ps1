<#
.SYNOPSIS
    Installs the MCP servers the configuration references.

.DESCRIPTION
    The config in opencode.jsonc names six MCP servers. Without this script a
    fresh install has all six configured and none of them present, which looks
    like a broken harness rather than a missing dependency: OpenCode starts
    normally and 277 tools are simply absent.

    That was a real gap in this repository until this script existed. It is
    the single most likely reason a first run "does not work".

    Versions are PINNED. An unpinned `@latest` re-resolves on every load and
    leaves `.staging-*` directories behind - 746 MB were reclaimed in this
    workspace by switching to exact pins.

.PARAMETER DryRun
    Print the plan, install nothing.

.PARAMETER What
    npm      - the four Node-based servers (default)
    all      - npm servers plus a cheat-mcp build recipe
    status   - report only, install nothing

.PARAMETER ConfigDir
    Where the OpenCode config lives, for the post-install check.

.PARAMETER ToolsDir
    Where cheat-mcp is cloned and built. Default: from WB_TOOLS_DIR, else
    D:\Tools. Exposed so the build path can be exercised against an empty
    directory instead of a machine that already has the binary.

.NOTES
    ASCII only: PowerShell 5.1 reads a BOM-less file as ANSI.
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [ValidateSet('npm', 'all', 'status')]
    [string]$What = 'npm',
    [string]$ConfigDir,
    [string]$ToolsDir
)

# -- Path resolution ---------------------------------------------------------
if (-not $ConfigDir)   { $ConfigDir = if ($env:WB_CONFIG_DIR) { $env:WB_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.config\opencode' } }
if (-not $ToolsDir)    { $ToolsDir   = if ($env:WB_TOOLS_DIR) { $env:WB_TOOLS_DIR } else { 'D:\Tools' } }
# ---------------------------------------------------------------------------

$ErrorActionPreference = 'Continue'   # one failure must not abort the rest
$ProgressPreference    = 'SilentlyContinue'

function Say($m) { Write-Host "  $m" -ForegroundColor Gray }
function Step($m) { Write-Host ""; Write-Host "==> $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host "  ! $m" -ForegroundColor Yellow }
function Ok($m)   { Write-Host "  [ok] $m" -ForegroundColor Green }

# Exact versions. Do not relax to @latest - see the header.
$PKGS = @(
    [pscustomobject]@{ name = 'rea-agents';        version = '6.4.0';  server = 'rea';
                        why = '170 tools - native/JS/.NET/Android/firmware/wasm/EVM/PCAP' },
    [pscustomobject]@{ name = 'js-reverse-mcp';     version = 'latest'; server = 'js-reverse';
                        why = '24 tools - JS signature chains, runtime sampling' },
    [pscustomobject]@{ name = '@jshookmcp/jshook';   version = 'latest'; server = 'jshook';
                        why = '8 tools - JS hook and coverage instrumentation' },
    [pscustomobject]@{ name = '@upstash/context7-mcp'; version = 'latest'; server = 'context7';
                        why = '2 tools - live library documentation' }
)

Write-Host ""
Write-Host "ashline - MCP server installation" -ForegroundColor Cyan

# ============================================================================
Step 'Preflight'
# ============================================================================

$node = Get-Command node -EA SilentlyContinue
if (-not $node) {
    Write-Host ""
    Warn "node is not on PATH. All four Node servers need it."
    Warn "Install Node 20+ first:  winget install OpenJS.NodeJS.LTS"
    exit 1
}
Say "node $((node -v).Trim())  at $($node.Source)"

$npm = Get-Command npm -EA SilentlyContinue
if (-not $npm) {
    Warn "npm not on PATH - it ships with Node, so this is unexpected"
    exit 1
}
Say "npm $((npm -v).Trim())"

# Where the config expects to find them.
$globalRoot = Join-Path $env:APPDATA 'npm\node_modules'
Say "config expects: $($globalRoot -replace [regex]::Escape($env:APPDATA), '%APPDATA%')"

# ============================================================================
Step 'Status'
# ============================================================================

$present = 0
foreach ($p in $PKGS) {
    $installed = $null
    if ($node) {
        $installed = (& npm ls -g --depth=0 --json 2>$null | ConvertFrom-Json -EA SilentlyContinue)
    }
    $dir = Join-Path $globalRoot ($p.name -replace '/', '\')
    $isThere = Test-Path $dir
    if ($isThere) { $present++ }
    $mark = if ($isThere) { '[ok]  ' } else { '[MISS]' }
    Say ("{0} {1,-26} {2}" -f $mark, $p.name, $p.why)
}

# cheat-mcp is not npm - it is a build from source.
$cheatExe = Join-Path $ToolsDir 'cheat-mcp\build\cheatmcp.exe'
if (Test-Path $cheatExe) { Ok "cheat-mcp present (72 tools)" }
else { Warn "cheat-mcp MISSING (72 tools) - see the build recipe below" }

$renderdocExe = Join-Path $ToolsDir 'renderdoc-mcp-bin\renderdoc-mcp-windows-x64-v0.3.0\bin\renderdoc-mcp.exe'
if (Test-Path $renderdocExe) { Ok "renderdoc-mcp present" }
else { Warn "renderdoc-mcp MISSING - prebuilt Windows release, see docs/tools.md" }

if ($What -eq 'status') {
    Step 'Plan'
    Say 'status only - nothing installed'
    Write-Host ""
    Write-Host "  STATUS ONLY - nothing written." -ForegroundColor Green
    exit 0
}
# -DryRun deliberately does NOT exit here. The cheat-mcp section below has its
# own dry-run branch that prints the exact clone, patch and cmake commands, and
# an earlier revision returned early with "would run the build recipe" - which
# is the one thing a reader cannot act on. A plan that does not say what it
# would do is not a plan.

if ($DryRun) {
    Step 'Plan'
    foreach ($p in $PKGS) {
        $dir = Join-Path $globalRoot ($p.name -replace '/', '\')
        if (-not (Test-Path $dir)) { Say "would install $($p.name)@$($p.version)" }
    }
}

# ============================================================================
Step 'Install Node-based servers'
# ============================================================================

foreach ($p in $PKGS) {
    $dir = Join-Path $globalRoot ($p.name -replace '/', '\')
    if (Test-Path $dir) {
        Say "$($p.name): already present, skipping"
        continue
    }
    # `latest` is passed through only where the upstream has no stable tag to
    # pin. rea-agents is pinned because it is the one that carries REA engines.
    $spec = if ($p.version -eq 'latest') { $p.name } else { "$($p.name)@$($p.version)" }
    Write-Host "    installing $spec" -ForegroundColor White
    & npm install -g $spec --no-audit --no-fund 2>&1 |
        Where-Object { $_ -match 'error|ERR!' } |
        ForEach-Object { Write-Host "      $_" -ForegroundColor DarkYellow }

    # Verify rather than trust the exit code. A global install can report
    # success and land somewhere npm does not put it on PATH.
    if (Test-Path $dir) { Ok "$($p.name) -> $($p.server)" }
    else { Warn "$($p.name): not found at $dir after install. Check npm prefix." }
}

# ============================================================================
Step 'cheat-mcp - build from source'
# ============================================================================
# Not an npm package. A C++ project:
#   https://github.com/AnonymoDGH/cheat-mcp.git   pinned at e1d6952 (v1.1)
#
# It is present in THIS repository as a git submodule at vendor/cheat-mcp, so
# it arrives with `git clone --recursive`. This step clones it if missing,
# applies the one local patch, and builds it.
#
# THE PATCH: upstream omits `#include <mstcpip.h>` in src/network.cpp, which
# breaks the SIO_RCVALL WSAIoctl call at line 246 - the build fails without it.
# The fix is kept as a real .patch file at patches/cheat-mcp-mstcpip.patch and
# applied here, rather than as prose telling the reader what to type. Earlier
# revisions printed a literal "<cheat-mcp upstream>" placeholder, so the URL
# appeared nowhere in the repository and nobody could install it.
#
# NOTE ON LICENSING: the upstream repository has NO LICENSE file. Absence of a
# license means all rights reserved, which is why the source is a submodule -
# referenced and pinned, not redistributed - rather than copied in.
$CHEAT_URL    = 'https://github.com/AnonymoDGH/cheat-mcp.git'
$CHEAT_COMMIT = 'e1d6952'

$cheatRoot = Join-Path $ToolsDir 'cheat-mcp'
$exePath   = Join-Path $cheatRoot 'build\cheatmcp.exe'

if (Test-Path $exePath) {
    Say 'cheat-mcp already built'
    Say "  $exePath"
} else {
    $patchFile = Join-Path $PSScriptRoot '..\patches\cheat-mcp-mstcpip.patch'

    if (-not (Test-Path (Join-Path $cheatRoot '.git'))) {
        Say "cloning $CHEAT_URL"
        if ($DryRun) {
            Write-Host "    [dry-run] git clone $CHEAT_URL $cheatRoot" -ForegroundColor DarkGray
        } else {
            New-Item -ItemType Directory -Force -Path (Split-Path $cheatRoot -Parent) | Out-Null
            & git clone --filter=blob:none $CHEAT_URL $cheatRoot 2>&1 |
                Where-Object { $_ -match 'error|fatal' } | ForEach-Object { Write-Host "      $_" -ForegroundColor DarkYellow }
        }
    } else {
        Say 'cheat-mcp source already cloned'
    }

    if (-not $DryRun -and (Test-Path (Join-Path $cheatRoot '.git'))) {
        & git -C $cheatRoot checkout -q $CHEAT_COMMIT 2>&1 | Out-Null
        Say "  pinned to $CHEAT_COMMIT (v1.1)"

        # Apply the patch only if it is not already applied. `git apply
        # --reverse --check` succeeds when it IS applied, so this is the test
        # for "already done" rather than blindly patching a clean file.
        if (Test-Path $patchFile) {
            & git -C $cheatRoot apply --reverse --check $patchFile 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Say '  mstcpip.h patch already applied'
            } else {
                Say '  applying patches/cheat-mcp-mstcpip.patch'
                & git -C $cheatRoot apply $patchFile 2>&1 |
                    Where-Object { $_ -match 'error' } | ForEach-Object { Write-Host "      $_" -ForegroundColor DarkYellow }
            }
        } else {
            Warn "patch file missing at $patchFile - the build will fail at SIO_RCVALL"
        }
    }

    Say ''
    Say 'Building (needs Visual Studio + CMake 3.16+):'
    if ($DryRun) {
        Write-Host "    [dry-run] cmake -S $cheatRoot -B $cheatRoot\build" -ForegroundColor DarkGray
        Write-Host "    [dry-run] cmake --build $cheatRoot\build --config Release" -ForegroundColor DarkGray
    } else {
        $cmake = Get-Command cmake -EA SilentlyContinue
        if (-not $cmake) {
            Warn 'cmake not on PATH. Configure it from Visual Studio, or:'
            Say '  winget install Kitware.CMake'
            Say "  then: cmake -S $cheatRoot -B $cheatRoot\build"
            Say "        cmake --build $cheatRoot\build --config Release"
        } else {
            & cmake -S $cheatRoot -B "$cheatRoot\build" 2>&1 |
                Where-Object { $_ -match 'error|Error' } | Select-Object -First 5 |
                ForEach-Object { Write-Host "      $_" -ForegroundColor DarkYellow }
            & cmake --build "$cheatRoot\build" --config Release 2>&1 |
                Where-Object { $_ -match 'error|Error' } | Select-Object -First 8 |
                ForEach-Object { Write-Host "      $_" -ForegroundColor DarkYellow }
            if (Test-Path $exePath) {
                Ok "built: $exePath"
            } else {
                Warn "build finished but $exePath is absent - check the output above"
            }
        }
    }
}

# ============================================================================
Step 'Verify'
# ============================================================================

$oc = Get-Command opencode -EA SilentlyContinue
if ($oc) {
    Say 'running: opencode mcp list'
    & opencode mcp list 2>&1 | Select-Object -First 20 | ForEach-Object { Write-Host "    $_" }
} else {
    Warn 'opencode is not on PATH - cannot verify server registration.'
    Say 'Install it, then run:  opencode mcp list'
}

Write-Host ""
Write-Host "  MCP INSTALL COMPLETE" -ForegroundColor Green
Write-Host "  Restart OpenCode - MCP servers are spawned per session."
Write-Host ""
Write-Host '  If a server shows registered but not connected, its command path'
Write-Host '  is wrong. Compare it against the absolute path in' -ForegroundColor Yellow
Write-Host '  opencode.jsonc, and check npm prefix - global installs land under' -ForegroundColor Yellow
Write-Host "  $(Join-Path $env:APPDATA 'npm\node_modules'), which is not always where npm reports." -ForegroundColor Yellow
Write-Host ""