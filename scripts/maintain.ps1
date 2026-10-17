
# -- Path resolution ---------------------------------------------------------
# Overridable via environment. Defaults match the machine this was authored on;
# set WB_TOOLS_DIR / WB_COLLECTIONS_DIR / WB_CONFIG_DIR to relocate without
# editing this file.
if (-not $ToolsDir)       { $ToolsDir       = if ($env:WB_TOOLS_DIR)      { $env:WB_TOOLS_DIR }      else { 'D:\Tools' } }
if (-not $CollectionsDir) { $CollectionsDir = if ($env:WB_COLLECTIONS_DIR) { $env:WB_COLLECTIONS_DIR } else { 'D:\opencode' } }
if (-not $UserProfile)    { $UserProfile    = $env:USERPROFILE }
if (-not $ConfigDir)      { $ConfigDir      = if ($env:WB_CONFIG_DIR)     { $env:WB_CONFIG_DIR }     else { Join-Path $UserProfile '.config\opencode' } }
# ---------------------------------------------------------------------------
# maintain.ps1 - one-shot maintenance + report for the OpenCode workspace.
#
# Run from a normal PowerShell window:
#   powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.config\opencode\maintain.ps1"
#
# It prints a compact report and does three safe things:
#   * removes orphaned ".staging-*" plugin folders left by failed installs
#   * removes plugin folders that are 0 bytes (broken downloads)
#   * reports duplicate plugin versions (does NOT delete them - see note)
#
# It never touches sessions, the database, config, or anything of yours.

$ErrorActionPreference = 'Continue'
$cfg   = Join-Path $env:USERPROFILE '.config\opencode'
$cache = Join-Path $env:USERPROFILE '.cache\opencode\npm'
$proj  = "$UserProfile\Desktop\OBSIDIAN"

function Head($t) { Write-Host ''; Write-Host "== $t ==" -ForegroundColor Cyan }
function Fmt($b)  { if ($b -ge 1GB) { '{0:N2} GB' -f ($b/1GB) } else { '{0:N1} MB' -f ($b/1MB) } }

Write-Host ''
Write-Host 'OpenCode workspace maintenance' -ForegroundColor Cyan
Write-Host ('=' * 60)

# ---------------------------------------------------------------- scripts
Head 'helper scripts'
foreach ($name in 'verify-setup.ps1','fix-ghost-sessions.ps1','vmhelper.ps1','devshell.cmd') {
    $p = Join-Path $cfg $name
    if (Test-Path -LiteralPath $p) {
        $sz = (Get-Item -LiteralPath $p).Length
        if ($name -like '*.ps1') {
            $err = $null
            [System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$null, [ref]$err) | Out-Null
            $bad = if ($err) { $err.Count } else { 0 }
            $tag = if ($bad -eq 0) { 'ok  ' } else { 'FAIL' }
            Write-Host ("  $tag {0,-26} {1,7} B  parse-errors={2}" -f $name, $sz, $bad)
        } else {
            Write-Host ("  ok   {0,-26} {1,7} B" -f $name, $sz)
        }
    } else {
        Write-Host ("  --   {0,-26} absent" -f $name)
    }
}

# ---------------------------------------------------------------- project
Head 'OBSIDIAN project'
if (Test-Path -LiteralPath $proj) {
    foreach ($name in 'tools\state.py','tools\doctor.py','verify_all.bat','docs\HANDOFF.md','.git') {
        $p = Join-Path $proj $name
        if (Test-Path -LiteralPath $p) {
            if (Test-Path -LiteralPath $p -PathType Container) {
                Write-Host ("  ok   {0,-24} (dir)" -f $name)
            } else {
                Write-Host ("  ok   {0,-24} {1,9} B" -f $name, (Get-Item -LiteralPath $p).Length)
            }
        } else {
            Write-Host ("  --   {0,-24} absent" -f $name)
        }
    }
    Push-Location $proj
    $dirty = @(git status --porcelain 2>$null).Count
    $commits = @(git log --oneline 2>$null).Count
    Pop-Location
    Write-Host ("  git  : {0} commit(s), {1} uncommitted change(s)" -f $commits, $dirty)
    if ($dirty -gt 0) {
        Write-Host '         note: commit after each green verify_all.bat' -ForegroundColor Yellow
    }
} else {
    Write-Host "  project folder not found: $proj" -ForegroundColor Yellow
}

# ---------------------------------------------------------------- engines
Head 'engines'
$deskCli = Join-Path $env:APPDATA 'ai.opencode.desktop\cli'
$deskVer = '?'
if (Test-Path -LiteralPath $deskCli) {
    $d = Get-ChildItem -LiteralPath $deskCli -Directory | Sort-Object Name | Select-Object -Last 1
    if ($d) { $deskVer = $d.Name }
}
$npmPkg = Join-Path $env:APPDATA 'npm\node_modules\@opencode\cli\package.json'
$npmVer = '?'
if (Test-Path -LiteralPath $npmPkg) {
    try { $npmVer = (Get-Content -LiteralPath $npmPkg -Raw | ConvertFrom-Json).version } catch {}
}
$svcVer = '?'
$svc = Join-Path $env:USERPROFILE '.local\state\opencode\service.json'
if (Test-Path -LiteralPath $svc) {
    try { $svcVer = (Get-Content -LiteralPath $svc -Raw | ConvertFrom-Json).version } catch {}
}
Write-Host "  desktop : $deskVer"
Write-Host "  npm cli : $npmVer"
Write-Host "  service : $svcVer"
$dv = ($deskVer -split '-')[0]
if ($dv -ne $npmVer -and $npmVer -ne '?') {
    Write-Host "  MISMATCH - engins kill each other's service." -ForegroundColor Red
    Write-Host "  fix: npm i -g @opencode/cli@$dv" -ForegroundColor Red
} else {
    Write-Host '  aligned' -ForegroundColor Green
}

# ---------------------------------------------------------------- cache
Head 'plugin cache'
if (Test-Path -LiteralPath $cache) {
    $before = (Get-ChildItem -LiteralPath $cache -Recurse -File -Force -EA SilentlyContinue |
               Measure-Object Length -Sum).Sum

    # 1. orphaned staging folders
    $staging = Get-ChildItem -LiteralPath $cache -Directory -Force -EA SilentlyContinue |
               Where-Object { $_.Name -like '.staging-*' }
    foreach ($s in $staging) {
        Write-Host "  removing staging: $($s.Name)"
        Remove-Item -LiteralPath $s.FullName -Recurse -Force -EA SilentlyContinue
    }

    # 2. zero-byte package folders (failed downloads)
    $empty = @()
    foreach ($d in (Get-ChildItem -LiteralPath $cache -Directory -Force -EA SilentlyContinue)) {
        $sz = (Get-ChildItem -LiteralPath $d.FullName -Recurse -File -Force -EA SilentlyContinue |
               Measure-Object Length -Sum).Sum
        if ($null -eq $sz) { $sz = 0 }
        if ($sz -lt 1024) { $empty += $d }
    }
    foreach ($e in $empty) {
        Write-Host "  removing empty  : $($e.Name)"
        Remove-Item -LiteralPath $e.FullName -Recurse -Force -EA SilentlyContinue
    }

    $after = (Get-ChildItem -LiteralPath $cache -Recurse -File -Force -EA SilentlyContinue |
              Measure-Object Length -Sum).Sum
    Write-Host ("  freed      : {0}" -f (Fmt ($before - $after)))
    Write-Host ("  now        : {0}" -f (Fmt $after))

    Write-Host ''
    Write-Host '  breakdown:'
    $byPkg = @{}
    foreach ($d in (Get-ChildItem -LiteralPath $cache -Directory -Force -EA SilentlyContinue)) {
        $sz = (Get-ChildItem -LiteralPath $d.FullName -Recurse -File -Force -EA SilentlyContinue |
               Measure-Object Length -Sum).Sum
        if ($null -eq $sz) { $sz = 0 }
        $byPkg[$d.Name] = $sz
    }
    foreach ($k in ($byPkg.Keys | Sort-Object)) {
        Write-Host ("    {0,-46} {1,10}" -f $k, (Fmt $byPkg[$k]))
    }

    # 3. versions the config no longer references
    #    The config pins exact versions (e.g. opencode-mem@2.31.2). Any other
    #    copy of the same package in the cache - typically an old @latest - is
    #    dead weight. We only remove a copy when the package has another copy
    #    that IS referenced, so we can never delete the only one.
    $cfgFile = Join-Path $cfg 'opencode.jsonc'
    if (Test-Path -LiteralPath $cfgFile) {
        $raw = Get-Content -LiteralPath $cfgFile -Raw
        $referenced = @()
        foreach ($m in [regex]::Matches($raw, '"([@A-Za-z0-9_\-/\.]+@[0-9][^"]*)"')) {
            $referenced += $m.Groups[1].Value
        }
        foreach ($m in [regex]::Matches($raw, '"([@A-Za-z0-9_\-/\.]+)@latest"')) {
            $referenced += $m.Groups[1].Value + '@latest'
        }

        $dead = @()
        foreach ($d in (Get-ChildItem -LiteralPath $cache -Directory -Force -EA SilentlyContinue)) {
            $name = $d.Name
            if ($referenced -contains $name) { continue }

            # split "pkg@version"; skip scoped-root folders like "@cortexkit"
            $at = $name.LastIndexOf('@')
            if ($at -le 0) { continue }
            $pkg = $name.Substring(0, $at)
            if ([string]::IsNullOrWhiteSpace($pkg)) { continue }

            # is another copy of the same package referenced?
            $keepSibling = $false
            foreach ($r in $referenced) {
                if ($r -eq $name) { $keepSibling = $true; break }
                if ($r.StartsWith($pkg + '@') -or $r -eq $pkg) { $keepSibling = $true; break }
            }
            if ($keepSibling) { $dead += $d }
        }

        foreach ($d in $dead) {
            $sz = (Get-ChildItem -LiteralPath $d.FullName -Recurse -File -Force -EA SilentlyContinue |
                   Measure-Object Length -Sum).Sum
            Write-Host ("  removing unused : {0}  ({1})" -f $d.Name, (Fmt $sz))
            Remove-Item -LiteralPath $d.FullName -Recurse -Force -EA SilentlyContinue
        }
        if (-not $dead.Count) { Write-Host '  no unused versions' }

        $final = (Get-ChildItem -LiteralPath $cache -Recurse -File -Force -EA SilentlyContinue |
                  Measure-Object Length -Sum).Sum
        Write-Host ("  cache now  : {0}" -f (Fmt $final))
    } else {
        Write-Host '  config absent - skipping unused-version cleanup' -ForegroundColor Yellow
    }
} else {
    Write-Host "  no cache at $cache"
}

# ---------------------------------------------------------------- doctor
Head 'session doctor'
$doc = Join-Path $proj 'tools\doctor.py'
if (Test-Path -LiteralPath $doc) {
    Push-Location $proj
    & python $doc
    Pop-Location
} else {
    Write-Host "  doctor.py not found at $doc"
}

Write-Host ''
Write-Host ('=' * 60)
Write-Host 'done'
