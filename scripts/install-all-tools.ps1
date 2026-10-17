<#
.SYNOPSIS
    Provisions the full reverse-engineering toolchain, in the correct order.

.DESCRIPTION
    Orchestrates the six installers that close the gaps, then reports what is
    still missing against config/tool-manifest.json.

    ORDER IS LOAD-BEARING. The three install-missing-tools scripts are
    sequential passes over ONE measured gap list, not three scopes:

      pass 1  install-missing-tools.ps1   highest-frequency gaps
      pass 2  install-missing-tools2.ps1  remaining second-tier gaps
      pass 3  install-missing-tools3.ps1  REPAIRS four bugs pass 2 shipped

    Pass 3 is not optional. Its header names what pass 2 got wrong:

      1. httpx matched by FILENAME and captured an unrelated Python httpx
         client living inside ida-pro-mcp-venv
      2. releases/latest/download/<asset> is invalid where the asset lives
         under a tag-specific path, so a 404 HTML page was written to disk
         as if it were the binary
      3. Sysinternals extracted 164 files with zero shims
      4. impacket ships .py entry points, not .exe, on this Python install

    Pass 3 overlaps pass 2 for nuclei, httpx, ffuf, gobuster and upx, and WINS.
    Running them out of order leaves the broken versions in place.

.PARAMETER What
    toolchain  - the six installers (default)
    python     - the Python RE/security stack only
    game       - game/IL2CPP/.NET stack only
    triage     - binary triage stack only
    all        - everything, including collections and ECC

.PARAMETER DryRun
    List the steps, run nothing.

.PARAMETER ToolsDir
    Where tools are installed. Default: D:\Tools

.EXAMPLE
    .\install-all-tools.ps1 -What toolchain -DryRun

.NOTES
    ASCII only: PowerShell 5.1 reads a BOM-less file as ANSI.
#>
[CmdletBinding()]
param(
    [ValidateSet('toolchain', 'python', 'game', 'triage', 'all')]
    [string]$What = 'toolchain',
    [switch]$DryRun,
    [string]$ToolsDir = 'D:\Tools',
    [switch]$SkipCollection
)

# -- Path resolution ---------------------------------------------------------
if (-not $ToolsDir) { $ToolsDir = if ($env:WB_TOOLS_DIR) { $env:WB_TOOLS_DIR } else { 'D:\Tools' } }
if (-not $ConfigDir) { $ConfigDir = if ($env:WB_CONFIG_DIR) { $env:WB_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.config\opencode' } }
# ---------------------------------------------------------------------------

$ErrorActionPreference = 'Continue'   # one installer failing must not abort the rest
$ProgressPreference    = 'SilentlyContinue'

$Scripts = $ConfigDir -replace '\\$', ''
function Say($m) { Write-Host "  $m" -ForegroundColor Gray }
function Step($m) { Write-Host ""; Write-Host "==> $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host "  ! $m" -ForegroundColor Yellow }

function Run($label, $file, $argv) {
    # Look next to this script first, then in the installed config dir, so the
    # orchestrator works from a clone before install.ps1 has been run.
    $candidates = @(
        (Join-Path $PSScriptRoot $file),
        (Join-Path $ConfigDir "scripts\$file")
    )
    $path = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $path) {
        Warn "missing $file - run install.ps1 first"
        return
    }
    if ($DryRun) {
        Write-Host "    [dry-run] $label  ->  $file $argv" -ForegroundColor DarkGray
        return
    }
    Write-Host "    $label" -ForegroundColor White
    & powershell -NoProfile -ExecutionPolicy Bypass -File $path @argv 2>&1 |
        Where-Object { $_ -match '^\s*(!|\[BAD\]|FAIL|ERROR)' } |
        ForEach-Object { Write-Host "      $_" -ForegroundColor DarkYellow }
    # No return value on purpose: a PowerShell function's return value is
    # emitted into the pipeline, and a stray True/False lands in the console.
}

# ============================================================================
Step 'Toolchain'
# ============================================================================

if ($What -in @('toolchain', 'python')) {
    Step 'Pass 1 - highest-frequency gaps'
    Say 'nmap rizin jadx (winget) | radare2 hashcat apktool (archives)'
    Say 'pip: sqlmap frida-tools binwalk capstone uncompyle6 volatility3'
    Run 'pass 1' 'install-missing-tools.ps1' @()
}

if ($What -in @('toolchain', 'python')) {
    Step 'Pass 2 - second-tier gaps'
    Say 'pip: impacket objection pwntools(--no-deps) | Go: nuclei httpx ffuf gobuster'
    Say 'upx john sysinternals de4dot'
    Say 'KNOWN BUGGY on its own - pass 3 repairs it, do not stop here'
    Run 'pass 2' 'install-missing-tools2.ps1' @()
}

if ($What -in @('toolchain', 'python')) {
    Step 'Pass 3 - repair pass (REQUIRED after pass 2)'
    Say 'deletes the bad httpx shim first, then re-fetches with tag-pinned URLs'
    Say 'nuclei v3.11.1  httpx v1.12.0  ffuf v2.3.0  gobuster v3.8.2  upx v5.2.1'
    Say 'adds 16 Sysinternals shims + 12 impacket .py shims'
    Run 'pass 3' 'install-missing-tools3.ps1' @()
}

if ($What -in @('toolchain', 'triage')) {
    Step 'Binary triage stack'
    Say 'capa 9.4.0 + rules | FLOSS | LIEF | DIE (live API, unpinned)'
    Run 'triage' 'install-triage-tools.ps1' @()
}

if ($What -in @('toolchain', 'game')) {
    Step 'Game / IL2CPP / .NET stack'
    Say 'Cheat Engine 7.7 | Il2CppDumper 6.7.46 | Cpp2IL | dnlib + AsmResolver | Scylla'
    Say 'dnlib/AsmResolver are BUILT here via dotnet, not downloaded'
    Run 'game' 'install-game-tools.ps1' @()
}

# ============================================================================
Step 'Report against the manifest'
# ============================================================================

$manifest = Join-Path $PSScriptRoot '..\config\tool-manifest.json'
if (-not (Test-Path $manifest)) { $manifest = Join-Path (Get-Location) 'config\tool-manifest.json' }

if (Test-Path $manifest) {
    $m = Get-Content $manifest -Raw | ConvertFrom-Json
    $present = 0; $absent = @()
    foreach ($t in $m.tools) {
        # Repoint at this machine's ToolsDir.
        $p = $t.path -replace [regex]::Escape($m.toolchain_root), $ToolsDir
        if (Test-Path $p) { $present++ } else { $absent += $t.name }
    }
    Write-Host ""
    Write-Host "  manifest: $present/$($m.tools.count) present, $([math]::Round($m.totals.size_gib,2)) GiB expected at $ToolsDir" -ForegroundColor Cyan
    if ($absent.Count -eq 0) {
        Write-Host "  every catalogued tool is present" -ForegroundColor Green
    } else {
        Write-Host "  missing ($($absent.Count)):" -ForegroundColor Yellow
        foreach ($a in $absent) { Write-Host "    - $a" -ForegroundColor Yellow }
        Write-Host ""
        Write-Host "  Some are expected to be manual. The manifest names the" -ForegroundColor DarkGray
        Write-Host "  installer for each - check whether it says 'manual'." -ForegroundColor DarkGray
    }
} else {
    Warn "tool-manifest.json not found - run: py -3 tools/gen-tool-manifest.py"
}

# ============================================================================
Step 'Verify'
# ============================================================================

$v = Join-Path $ConfigDir 'scripts\verify-setup.ps1'
if (Test-Path $v) {
    Say 'running verify-setup.ps1'
    Write-Host ""
    Write-Host '  Read the returned TEXT, not just the colour. Some checks print a' -ForegroundColor Yellow
    Write-Host '  green OK while describing a failure state.' -ForegroundColor Yellow
    if (-not $DryRun) {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $v
    }
} else {
    Warn 'verify-setup.ps1 not found - run install.ps1 first'
}

if ($DryRun) {
    Write-Host ""
    Write-Host "  DRY RUN - nothing installed." -ForegroundColor Green
}
Write-Host ""