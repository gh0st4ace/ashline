
# -- Path resolution ---------------------------------------------------------
# Overridable via environment. Defaults match the machine this was authored on;
# set WB_TOOLS_DIR / WB_COLLECTIONS_DIR / WB_CONFIG_DIR to relocate without
# editing this file.
if (-not $ToolsDir)       { $ToolsDir       = if ($env:WB_TOOLS_DIR)      { $env:WB_TOOLS_DIR }      else { 'D:\Tools' } }
if (-not $CollectionsDir) { $CollectionsDir = if ($env:WB_COLLECTIONS_DIR) { $env:WB_COLLECTIONS_DIR } else { 'D:\opencode' } }
if (-not $UserProfile)    { $UserProfile    = $env:USERPROFILE }
if (-not $ConfigDir)      { $ConfigDir      = if ($env:WB_CONFIG_DIR)     { $env:WB_CONFIG_DIR }     else { Join-Path $UserProfile '.config\opencode' } }
# ---------------------------------------------------------------------------
# fix-ghost-sessions.ps1
#
# Clears the "Session not found" popups in OpenCode Desktop.
#
# What it does
#   1. stops the desktop app and its background service
#   2. moves the app's state folders aside (rename, never delete)
#   3. that is all - start the app afterwards and it rebuilds them clean
#
# What survives
#   every session, every message, the whole history - those live in
#   ~\.local\share\opencode\opencode.db, not in the folders moved here.
#
# What is lost
#   window position, recent tabs, interface layout.
#
# Rollback
#   rename the .bak-<timestamp> folder back to its original name.
#
# Run it from a normal PowerShell window. It asks for nothing and needs no admin.

$ErrorActionPreference = 'Stop'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

Write-Host ''
Write-Host 'OpenCode ghost-session cleanup' -ForegroundColor Cyan
Write-Host ('=' * 56)

# ---------------------------------------------------------------- 1. stop
$names = @('opencode', 'opencode-cli', 'OpenCode', 'opencode-desktop')
$found = @()
foreach ($n in $names) {
    $found += Get-Process -Name $n -ErrorAction SilentlyContinue
}
$found = $found | Sort-Object Id -Unique

if ($found) {
    Write-Host ("stopping {0} process(es): {1}" -f $found.Count,
        (($found | ForEach-Object { "$($_.ProcessName)($($_.Id))" }) -join ', '))
    foreach ($p in $found) {
        try { Stop-Process -Id $p.Id -Force -ErrorAction Stop }
        catch { Write-Host "  could not stop pid $($p.Id): $_" -ForegroundColor Yellow }
    }
    Start-Sleep -Seconds 4
} else {
    Write-Host 'no OpenCode process was running'
}

# verify they are really gone
$still = @()
foreach ($n in $names) {
    $still += Get-Process -Name $n -ErrorAction SilentlyContinue
}
if ($still) {
    Write-Host ''
    Write-Host 'These are still running - close them by hand and run this script again:' -ForegroundColor Red
    $still | Select-Object Id, ProcessName | Format-Table -AutoSize | Out-Host
    Write-Host 'Nothing was changed.' -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------- 2. move
$targets = @(
    (Join-Path $env:APPDATA    'ai.opencode.desktop'),
    (Join-Path $env:LOCALAPPDATA 'ai.opencode.desktop')
)

$moved = 0
foreach ($t in $targets) {
    if (-not (Test-Path -LiteralPath $t)) {
        Write-Host "absent, nothing to do: $t"
        continue
    }
    $bak = "$t.bak-$stamp"
    try {
        Rename-Item -LiteralPath $t -NewName (Split-Path $bak -Leaf) -ErrorAction Stop
        Write-Host "moved aside: $t" -ForegroundColor Green
        Write-Host "         ->  $bak"
        $moved++
    } catch {
        Write-Host "FAILED to move $t" -ForegroundColor Red
        Write-Host "   $_"
        Write-Host ''
        Write-Host 'The app is probably still holding a file. Close it completely' -ForegroundColor Red
        Write-Host '(check Task Manager for opencode / OpenCode) and run again.' -ForegroundColor Red
        exit 1
    }
}

# ---------------------------------------------------------------- 3. report
Write-Host ''
Write-Host ('=' * 56)
if ($moved -gt 0) {
    Write-Host "done - $moved folder(s) moved aside" -ForegroundColor Green
    Write-Host ''
    Write-Host 'Now start OpenCode Desktop. It will rebuild its state folder empty,'
    Write-Host 'and the ghost sessions stop being requested.'
    Write-Host ''
    Write-Host 'The sessions themselves are untouched - they are in'
    Write-Host '  ~\.local\share\opencode\opencode.db'
    Write-Host ''
    Write-Host 'To roll back, rename the .bak folder back to its original name.'
} else {
    Write-Host 'nothing was moved - no app folder existed'
}
