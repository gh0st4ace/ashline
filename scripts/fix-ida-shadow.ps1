
# -- Path resolution ---------------------------------------------------------
# Overridable via environment. Defaults match the machine this was authored on;
# set WB_TOOLS_DIR / WB_COLLECTIONS_DIR / WB_CONFIG_DIR to relocate without
# editing this file.
if (-not $ToolsDir)       { $ToolsDir       = if ($env:WB_TOOLS_DIR)      { $env:WB_TOOLS_DIR }      else { 'D:\Tools' } }
if (-not $CollectionsDir) { $CollectionsDir = if ($env:WB_COLLECTIONS_DIR) { $env:WB_COLLECTIONS_DIR } else { 'D:\opencode' } }
if (-not $UserProfile)    { $UserProfile    = $env:USERPROFILE }
if (-not $ConfigDir)      { $ConfigDir      = if ($env:WB_CONFIG_DIR)     { $env:WB_CONFIG_DIR }     else { Join-Path $UserProfile '.config\opencode' } }
# ---------------------------------------------------------------------------
# Run this ONCE in an elevated PowerShell (right-click -> Run as administrator).
#
# Why: D:\Programs\ is on the machine PATH before any user PATH entry, and the
# loose IDA 9.3 copy sitting directly in D:\Programs\ shadows the real 9.4
# install. Anything typed as bare `ida` therefore launches 9.3, which has no
# plugins/, python/ or loaders/ and no MCP plugin.
#
# The rename is reversible: change the .orphan.bak suffix back to .exe.
# Everything opencode-mem, REA and start-ida-mcp.ps1 already point at the
# absolute 9.4 path, so this is about your own shell, not the toolchain.

$ErrorActionPreference = 'Stop'

$orphan = 'D:\Programs\ida.exe'
if (Test-Path $orphan) {
    Rename-Item -Path $orphan -NewName 'ida.exe.9.3-orphan.bak' -Force
    Write-Host "renamed: $orphan -> ida.exe.9.3-orphan.bak" -ForegroundColor Green
} else {
    Write-Host "nothing to do: $orphan not present" -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'current resolution:' -ForegroundColor Cyan
Get-Command ida -ErrorAction SilentlyContinue |
    Select-Object -Property Source | Format-Table -AutoSize

Write-Host 'pointing at 9.4 instead:' -ForegroundColor Cyan
& 'D:\Programs\IDA Professional 9.4\ida.exe' -h 2>&1 | Select-Object -First 3