#requires -Version 5.1
<#
.SYNOPSIS
    Snapshot discipline for the anti-cheat test VM. Always snapshot before a
    risky test; restoring is the only cheap way back from a BSOD or a wedged
    driver.

.DESCRIPTION
    Testing kernel anti-cheat components or vulnerable drivers on the host risks
    an unbootable machine, and loading real AC components on the host can get
    the operator banned. This VM exists so that risk is disposable.

    Typical session:

        vmhelper.ps1 snap before-kernel-test
        # ... do whatever the test needs, in the VM ...
        vmhelper.ps1 rollback

    The VM is Windows 10 Enterprise LTSC Evaluation, installed unattended.
    Evaluation builds run without activation, which is exactly what a test VM
    wants: no licence to manage, no expiry to chase mid-test.

.PARAMETER Action
    status     - show VM state, snapshots, disk usage
    start      - boot the VM headless
    shutdown   - graceful ACPI power off
    snap       - take a snapshot; pass a name, default 'pre-test'
    rollback   - revert to the most recent snapshot
    snapshots  - list snapshots
    discard    - delete a snapshot by name

.EXAMPLE
    pwsh -File "$env:USERPROFILE\.config\opencode\vmhelper.ps1" snap before-eac-test
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('status', 'start', 'shutdown', 'snap', 'rollback', 'snapshots', 'discard')]
    [string]$Action = 'status',

    [Parameter(Position = 1)]
    [string]$Name = 'pre-test'
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

$vbm = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
if (-not (Test-Path $vbm)) { Write-Error 'VirtualBox not found'; exit 1 }
$vm = 'ac-test'

$exists = & $vbm list vms 2>&1 | Out-String
if ($exists -notmatch [regex]::Escape("""$vm""")) {
    Write-Error "VM '$vm' is not registered. Create it with start-ida-mcp-style install; see AGENTS.md."
    exit 1
}

function State {
    $s = & $vbm showvminfo $vm 2>&1 | Out-String
    $state = ([regex]::Match($s, '(?m)^State:\s+(.+)$')).Groups[1].Value.Trim()
    $mem   = ([regex]::Match($s, '(?m)^Memory size:\s+(.+)$')).Groups[1].Value.Trim()
    $cpus  = ([regex]::Match($s, '(?m)^Number of CPUs:\s+(.+)$')).Groups[1].Value.Trim()
    $state
}

switch ($Action) {

    'status' {
        $st = State
        Write-Host "VM $vm  state: $st" -ForegroundColor $(if ($st -match 'running') { 'Green' } else { 'DarkGray' })
        & $vbm showvminfo $vm 2>&1 |
            Select-String -Pattern 'Memory size|Number of CPUs|Video Memory|Storage Controllers' |
            ForEach-Object { "  $($_.Line.Trim())" }
        Write-Host ''
        Write-Host 'snapshots:' -ForegroundColor Cyan
        $snaps = & $vbm snapshot $vm list --machinereadable 2>&1 | Out-String
        $names = [regex]::Matches($snaps, '(?m)^SnapshotName="(.+)"$') | ForEach-Object { $_.Groups[1].Value }
        if ($names) { $names | ForEach-Object { "  $_" } } else { Write-Host '  (none - take one before any risky test)' -ForegroundColor DarkGray }
        Write-Host ''
        $vdi = Get-Item 'D:\VMs\ac-test\ac-test.vdi' -ErrorAction SilentlyContinue
        if ($vdi) { Write-Host ("disk: {0:N1} GB used of 80 GB virtual" -f ($vdi.Length / 1GB)) -ForegroundColor DarkGray }
    }

    'start' {
        $st = State
        if ($st -match 'running') { Write-Host 'already running' -ForegroundColor DarkGray; break }
        # Headless: no window on the desktop unless the operator asks for one.
        & $vbm start $vm --type headless 2>&1 | Out-Null
        Start-Sleep -Seconds 5
        Write-Host "started (headless). GUI if wanted: VBoxManage start $vm" -ForegroundColor Green
    }

    'shutdown' {
        $st = State
        if ($st -notmatch 'running') { Write-Host 'not running' -ForegroundColor DarkGray; break }
        & $vbm controlvm $vm acpipowerbutton 2>&1 | Out-Null
        for ($i = 0; $i -lt 30; $i++) {
            Start-Sleep -Seconds 2
            if ((State) -notmatch 'running') { break }
        }
        Write-Host "power state: $(State)" -ForegroundColor Green
    }

    'snap' {
        $st = State
        if ($st -match 'running') {
            Write-Host 'snapshotting a running VM; the disk may be mid-write.' -ForegroundColor Yellow
        }
        & $vbm snapshot $vm take $Name 2>&1 | Where-Object { $_ -match 'error' } | ForEach-Object { Write-Error $_; exit 1 }
        Write-Host "snapshot '$Name' taken" -ForegroundColor Green
        Write-Host "undo with: vmhelper.ps1 rollback" -ForegroundColor DarkGray
    }

    'rollback' {
        $st = State
        if ($st -match 'running') {
            Write-Host 'powering off before revert' -ForegroundColor DarkGray
            & $vbm controlvm $vm poweroff 2>&1 | Out-Null
            Start-Sleep -Seconds 4
        }
        & $vbm snapshot $vm restore --current 2>&1 | Where-Object { $_ -match 'error' } | ForEach-Object { Write-Error $_; exit 1 }
        Write-Host "restored to the current snapshot ($Name)" -ForegroundColor Green
    }

    'snapshots' {
        $snaps = & $vbm snapshot $vm list --machinereadable 2>&1 | Out-String
        $names = [regex]::Matches($snaps, '(?m)^SnapshotName="(.+)"$') | ForEach-Object { $_.Groups[1].Value }
        if ($names) { $names | ForEach-Object { "  $_" } } else { Write-Host '  (none)' }
    }

    'discard' {
        & $vbm snapshot $vm delete --name $Name 2>&1 | Where-Object { $_ -match 'error' } | ForEach-Object { Write-Error $_; exit 1 }
        Write-Host "deleted snapshot '$Name'" -ForegroundColor Green
    }
}
exit 0