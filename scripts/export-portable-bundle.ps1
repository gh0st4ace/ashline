<#
.SYNOPSIS
    Exports the toolchain as a portable archive, for offline transport.

.DESCRIPTION
    Git cannot carry the toolchain: GitHub's per-file limit is 100 MB and
    several tools exceed it several times over (Ghidra 865 MiB, hashcat
    371 MiB, Sysinternals 272 MiB, JDK 328 MiB). Some are also under a
    commercial or EULA license that redistribution would violate.

    This script is the OTHER channel. It packages the installed toolchain into
    a zip you can hand to someone directly - AirDrop, USB, private S3, whatever
    your situation allows. It is deliberately separate from the git repository,
    because mixing the two means one of them is wrong.

    Read LICENSE COMPLIANCE before running. The default profile excludes
    anything you should not redistribute.

.PARAMETER What
    triage    - capa, DIE, upx, radare2, dnlib        (~130 MiB, safe to share)
    re        - the decompilers and debuggers           (~1.8 GiB, check licenses)
    game      - game/IL2CPP/.NET tooling                (~250 MiB, check licenses)
    all       - everything except VM media              (~3 GiB)

.PARAMETER IncludeUnsafe
    Include TitanHide, kdmapper and other offensive tooling. Off by default.

.PARAMETER OutDir
    Where to write the archive. Default: the repository root.

.PARAMETER DryRun
    List what would be packed, write nothing.

.NOTES
    ASCII only: PowerShell 5.1 reads a BOM-less file as ANSI.
#>
[CmdletBinding()]
param(
    [ValidateSet('triage', 're', 'game', 'all')]
    [string]$What = 'triage',
    [switch]$IncludeUnsafe,
    [string]$OutDir,
    [switch]$DryRun
)

# -- Path resolution ---------------------------------------------------------
if (-not $ToolsDir)    { $ToolsDir    = if ($env:WB_TOOLS_DIR) { $env:WB_TOOLS_DIR } else { 'D:\Tools' } }
if (-not $UserProfile) { $UserProfile = $env:USERPROFILE }
# ---------------------------------------------------------------------------

$ErrorActionPreference = 'Stop'

if (-not $OutDir) { $OutDir = if ($PSScriptRoot) { Split-Path $PSScriptRoot -Parent } else { (Get-Location).Path } }
$RepoRoot = if ($PSScriptRoot) { Split-Path $PSScriptRoot -Parent } else { (Get-Location).Path }

# name -> which profile includes it
$PROFILES = @{
    triage = @('capa', 'die', 'upx', 'radare2-6.2.4-w64', 'nuget', 'de4dot')
    re     = @('ghidra_12.1.4_PUBLIC', 'jdk-21.0.12.1+1', 'x64dbg', 'radare2-6.2.4-w64',
               'SysinternalsSuite', 'capa', 'die', 'upx', 'dnSpy', 'nuget', 'de4dot',
               'hashcat-7.1.2', 'ReClass.NET', 'pdbfetch', 'de4dot')
    game   = @('Il2CppDumper', 'Cpp2IL', 'ReClass.NET', 'unluau', 'luau', 'nuget')
    all    = @('ghidra_12.1.4_PUBLIC', 'jdk-21.0.12.1+1', 'x64dbg', 'radare2-6.2.4-w64',
               'SysinternalsSuite', 'capa', 'die', 'upx', 'dnSpy', 'nuget', 'de4dot',
               'hashcat-7.1.2', 'Il2CppDumper', 'Cpp2IL', 'ReClass.NET', 'unluau',
               'luau', 'pdbfetch', 'renderdoc-mcp', 'renderdoc-mcp-bin')
}

# Never bundled without an explicit switch.
$UNSAFE = @('TitanHide', 'kdmapper', 'cheat-mcp', 'luau-decompiler', 'reverify', 'lib', 'ida-pro-mcp-venv')

function Say($m) { Write-Host "  $m" -ForegroundColor Gray }
function Warn($m) { Write-Host "  ! $m" -ForegroundColor Yellow }

$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$list  = @($PROFILES[$What])

# expand 'all' with the unsafe set only when asked
if ($IncludeUnsafe) { $list = @($list + $UNSAFE) }

Write-Host ""
Write-Host "ashline - portable toolchain export" -ForegroundColor Cyan
Write-Host "  profile: $What    root: $ToolsDir" -ForegroundColor Gray

$packed = @(); $skipped = @(); $missing = @()
$totalBytes = 0

foreach ($name in ($list | Select-Object -Unique)) {
    $p = Join-Path $ToolsDir $name
    if (-not (Test-Path $p)) { $missing += $name; continue }
    $bytes = (Get-ChildItem $p -Recurse -File -Force -EA SilentlyContinue | Measure-Object -Sum Length).Sum
    $totalBytes += $bytes
    $packed += [pscustomobject]@{ name = $name; path = $p; bytes = $bytes }
    Say ("{0,-26} {1,9:N1} MiB" -f $name, ($bytes / 1MB))
}

foreach ($u in $UNSAFE) {
    if (-not $IncludeUnsafe -and (Test-Path (Join-Path $ToolsDir $u))) { $skipped += $u }
}

Write-Host ""
Say ("total {0} tools, {1:N2} GiB" -f $packed.Count, ($totalBytes / 1GB))
if ($skipped.Count) {
    Warn "excluded as not redistributable without review: $($skipped -join ', ')"
    Say  "pass -IncludeUnsafe to override (you are then responsible for compliance)"
}
if ($missing.Count) { Warn "not on this machine: $($missing -join ', ')" }

if ($DryRun) {
    Write-Host ""
    Write-Host "  DRY RUN - nothing written." -ForegroundColor Green
    exit 0
}

$outFile = Join-Path $OutDir "ashline-tools-$What-$stamp.zip"
Write-Host ""
Say "packing to $outFile"

# -r recurse, -CompressionLevel Fastest (these are already-compressed binaries),
# -ErrorAction so one locked file does not abort an 800 MB pack.
$staging = @($packed | ForEach-Object { $_.path })
$paths = ($staging | ForEach-Object { '"' + $_ + '"' }) -join ','
& tar.exe -a -c -f "$outFile" --force-local --exclude='*.pdb' --exclude='*.ilk' --exclude='__pycache__' $staging 2>&1 |
    Where-Object { $_ -match 'error|Error' } | ForEach-Object { Warn $_ }

if (Test-Path $outFile) {
    $sz = (Get-Item $outFile).Length
    Write-Host ""
    Write-Host ("  archive: {0:N2} GiB  ({1:N0} bytes)" -f ($sz / 1GB), $sz) -ForegroundColor Green
    Say "  verify before sharing: unzip somewhere and run verify-setup.ps1"
    Write-Host ""

    $manifestNote = @(
        "This archive contains REDISTRIBUTED BINARIES and is separate from the",
        "git repository on purpose.",
        "",
        "Contents and versions: config/tool-manifest.json",
        "Provisioning instead of copying: scripts/install-all-tools.ps1",
        "",
        "LICENSE COMPLIANCE IS ON YOU. Excluded by default:",
        "  $($skipped -join ', ')",
        "",
        "Each tool keeps its own license. Redistributing a binary is not the same",
        "as sharing a script that installs it, and several of these are under a",
        "commercial or EULA license.",
        "",
        "If in doubt, do not share the archive. Share the repository instead -",
        "it is 1 MB and reproduces the toolchain from pinned sources."
    ) -join "`r`n"
    [System.IO.File]::WriteAllText(
        (Join-Path $OutDir "ashline-tools-$What-$stamp-README.txt"),
        $manifestNote, (New-Object System.Text.UTF8Encoding($false)))
    Say "wrote accompanying README"
}