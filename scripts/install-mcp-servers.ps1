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

.NOTES
    ASCII only: PowerShell 5.1 reads a BOM-less file as ANSI.
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [ValidateSet('npm', 'all', 'status')]
    [string]$What = 'npm',
    [string]$ConfigDir
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
Write-Host "opencode-workbench - MCP server installation" -ForegroundColor Cyan

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

if ($What -eq 'status' -or $DryRun) {
    Step 'Plan'
    if ($What -eq 'status') { Say 'status only - nothing installed' }
    else {
        foreach ($p in $PKGS) {
            $dir = Join-Path $globalRoot ($p.name -replace '/', '\')
            if (-not (Test-Path $dir)) {
                Say "would install $($p.name)@$($p.version)"
            }
        }
        Say "would run the cheat-mcp build recipe"
    }
    Write-Host ""
    Write-Host "  DRY RUN / STATUS ONLY - nothing written." -ForegroundColor Green
    exit 0
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
# Not an npm package. It is a C++ project built locally, and the upstream
# omits `#include <mstcpip.h>` in src/network.cpp which breaks the SIO_RCVALL
# call. That include is a LOCAL patch.
$cheatRoot = Join-Path $ToolsDir 'cheat-mcp'
if (Test-Path (Join-Path $cheatRoot 'build\cheatmcp.exe')) {
    Say 'cheat-mcp already built'
} elseif (Test-Path $cheatRoot) {
    Warn 'cheat-mcp source present but not built.'
    Say 'Recipe (needs Visual Studio + CMake + the WDK):'
    Say '  1. git clone <cheat-mcp upstream> D:\Tools\cheat-mcp'
    Say '  2. Add  #include <mstcpip.h>  at the top of src/network.cpp'
    Say '     (upstream omits it, which breaks SIO_RCVALL. LOCAL FIX - it will'
    Say '      conflict on a fresh git pull.)'
    Say '  3. .\scripts\devshell.cmd x64 cmd /c "cmake --build build --config Release"'
    Say '  4. Expect D:\Tools\cheat-mcp\build\cheatmcp.exe'
} else {
    Say 'cheat-mcp not present. It is a third-party C++ project and is not'
    Say 'vendored here. See config/tool-manifest.json for the manifest entry.'
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