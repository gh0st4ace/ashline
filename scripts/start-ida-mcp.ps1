#requires -Version 5.1
<#
.SYNOPSIS
    Opens a binary in IDA Pro and starts the MCP bridge that REA's `ida` provider needs.

.DESCRIPTION
    REA's `ida` provider runs in attached mode: it talks to the JSON-RPC server
    that `mcp-plugin.py` exposes inside a live IDA GUI. The plugin is a UI plugin
    with no autostart, so it must be started once per IDA session. This script
    does that automatically by sending the plugin hotkey (Ctrl+Alt+M) to the
    IDA window after auto-analysis settles, then waits for port 13337.

    Verified working: with the port open, `rea decompile <binary> <address>
    --provider ida --format json` returns Hex-Rays pseudocode with Evidence.

.EXAMPLE
    pwsh -File "$env:USERPROFILE\.config\opencode\start-ida-mcp.ps1" C:\path\to\game.exe
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Binary,
    [int]$SettleSeconds = 12,
    [switch]$NoRaise
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
Add-Type -AssemblyName System.Windows.Forms
if (-not ('IdaMcpWin' -as [type])) {
    Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class IdaMcpWin {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr h);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
}
"@
}

$ida = [Environment]::GetEnvironmentVariable('REA_IDA_INSTALL', 'User')
if (-not $ida) { $ida = 'D:\Programs\IDA Professional 9.4' }
$exe = Join-Path $ida 'ida.exe'
if (-not (Test-Path $exe)) { Write-Error "IDA not found at $exe. Set REA_IDA_INSTALL."; exit 1 }

$Binary = (Resolve-Path $Binary -ErrorAction Stop).Path

if (-not $NoRaise -and (Get-NetTCPConnection -LocalPort 13337 -State Listen -ErrorAction SilentlyContinue)) {
    Write-Host 'MCP bridge already listening on 13337 - reusing the running IDA.' -ForegroundColor DarkGray
    exit 0
}

Get-Process ida -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "closing IDA pid $($_.Id)" -ForegroundColor DarkGray
    Stop-Process -Id $_.Id -Force
}
Start-Sleep -Seconds 2

Write-Host "opening $Binary" -ForegroundColor Cyan
Start-Process -FilePath $exe -ArgumentList '-A', "`"$Binary`"" | Out-Null

$proc = $null
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 2
    $proc = Get-Process ida -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if ($proc) { break }
}
if (-not $proc) { Write-Error 'IDA window never appeared.'; exit 1 }

Write-Host "IDA ready: $($proc.MainWindowTitle)" -ForegroundColor DarkGray
Start-Sleep -Seconds $SettleSeconds

$null = [IdaMcpWin]::ShowWindow($proc.MainWindowHandle, 9)
$null = [IdaMcpWin]::SetForegroundWindow($proc.MainWindowHandle)
Start-Sleep -Milliseconds 900
[System.Windows.Forms.SendKeys]::SendWait('^%m')

for ($i = 1; $i -le 15; $i++) {
    Start-Sleep -Seconds 2
    $c = Get-NetTCPConnection -LocalPort 13337 -State Listen -ErrorAction SilentlyContinue
    if ($c) {
        Write-Host "MCP bridge is live on 127.0.0.1:13337 (ida pid $($c.OwningProcess))." -ForegroundColor Green
        Write-Host ''
        Write-Host 'REA can now bind to it. Use an address, not a bare name:' -ForegroundColor DarkGray
        Write-Host "  rea decompile `"$Binary`" 0x140001000 --provider ida --format json" -ForegroundColor DarkGray
        exit 0
    }
}

Write-Error 'MCP bridge did not start. Open Edit -> Plugins -> MCP (Ctrl+Alt+M) in IDA and re-run.'
exit 1