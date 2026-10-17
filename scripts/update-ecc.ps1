#Requires -Version 5.1
<#
.SYNOPSIS
  Обновление ECC из $CollectionsDir\ecc + переустановка в OpenCode + реаппликация локальных фиксов.
.DESCRIPTION
  Держит всё в $CollectionsDir (клон https://github.com/affaan-m/ecc).
  Профиль: full + hooks. opencode.jsonc НЕ трогается.

  После переустановки скрипт заново применяет 2 локальные адаптации
  (исходники лежат в $CollectionsDir\ecc-v2-shim, бэкапы — в backups/):
    1. v2-порт плагинов (plugins/ecc-hooks.ts + plugins/index.ts).
       Апстрим ECC 2.2.3 поставляет v1-функции, которые OpenCode >= 2.x
       отклоняет ("must export a default definition"). Без порта плагины красные.
    2. Удаление легаси-ключа "plugin": ["./plugins"] из opencode.json.
       Ключ дублирует файловый автодискавери v2: index.ts грузился дважды,
       второй инстанс падал с дублирующимся id (красный ecc-entry в TUI).

  Правило безопасности (выучено 2026-10-16): НИКОГДА не переименовывать и не
  удалять файлы, на которые ссылаются {file:...} в opencode.json — недостающий
  файл роняет сервер с HTTP 500 на /api/config. Скрипт только ПРОВЕРЯЕТ все
  {file:} ссылки и громко предупреждает о битых, но не чинит их сам.

  doctor после этого показывает WARNING drifted-managed-files: 3 — это честный
  сигнал о трёх намеренных дивергенциях (2 файла плагинов + opencode.json),
  а не поломка. install-state НЕ правится.
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File $CollectionsDir\update-ecc.ps1
#>
[CmdletBinding()]
param()

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
$EccRoot = "$CollectionsDir\ecc"
$ShimDir = "$CollectionsDir\ecc-v2-shim"
$ConfigRoot = Join-Path $HOME '.config\opencode'

if (-not (Test-Path $EccRoot)) {
  throw "Нет $EccRoot — сначала склонируй: git clone https://github.com/affaan-m/ecc.git $EccRoot"
}
if (-not (Test-Path $ShimDir)) {
  throw "Нет $ShimDir с v2-портом плагинов"
}

Push-Location $EccRoot
try {
  Write-Host '== git pull ==' -ForegroundColor Cyan
  git pull --ff-only

  Write-Host '== npm install ==' -ForegroundColor Cyan
  npm install --no-audit --no-fund

  Write-Host '== build opencode plugin ==' -ForegroundColor Cyan
  node scripts/build-opencode.js

  Write-Host '== install --target opencode --profile full ==' -ForegroundColor Cyan
  node scripts/install-apply.js --target opencode --profile full --enable-hooks

  # 1. Реаппликация v2-порта плагинов.
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $backupDir = Join-Path $ConfigRoot 'backups'
  foreach ($name in @('ecc-hooks.ts', 'index.ts')) {
    $dest = Join-Path $ConfigRoot "plugins\$name"
    if (Test-Path $dest) {
      Copy-Item $dest (Join-Path $backupDir "plugins.$name.$stamp.bak") -Force
    }
    Copy-Item (Join-Path $ShimDir $name) $dest -Force
    Write-Host "Применён v2-порт: plugins\$name" -ForegroundColor Yellow
  }

  # 2. Удаление легаси-ключа "plugin": ["./plugins"] (дубль автодискавери).
  $jsonPath = Join-Path $ConfigRoot 'opencode.json'
  $jsonText = [System.IO.File]::ReadAllText($jsonPath)
  $legacyBlock = '"plugin": [' + [Environment]::NewLine + '    "./plugins"' + [Environment]::NewLine + '  ],' + [Environment]::NewLine
  if ($jsonText.Contains($legacyBlock)) {
    Copy-Item $jsonPath "$jsonPath.$stamp.bak" -Force
    $jsonText = $jsonText.Replace($legacyBlock, '')
    [System.IO.File]::WriteAllText($jsonPath, $jsonText, [System.Text.UTF8Encoding]::new($false))
    $null = Get-Content $jsonPath -Raw | ConvertFrom-Json -ErrorAction Stop
    Write-Host 'Удалён легаси-ключ "plugin": ["./plugins"] (JSON валиден)' -ForegroundColor Yellow
  } else {
    Write-Host 'Легаси-ключа "plugin" нет — пропускаю' -ForegroundColor DarkGray
  }

  # 3. Аудит {file:} ссылок: только проверка, никакого автофикса.
  Write-Host '== аудит {file:} ссылок ==' -ForegroundColor Cyan
  $broken = @()
  foreach ($f in @('opencode.json', 'opencode.jsonc')) {
    $p = Join-Path $ConfigRoot $f
    if (-not (Test-Path $p)) { continue }
    $t = [System.IO.File]::ReadAllText($p)
    foreach ($m in [regex]::Matches($t, '\{file:([^}]+)\}')) {
      $rel = $m.Groups[1].Value -replace '/', '\'
      if (-not (Test-Path (Join-Path $ConfigRoot $rel))) { $broken += "$f :: $($m.Groups[1].Value)" }
    }
  }
  if ($broken.Count -gt 0) {
    Write-Host 'БИТЫЕ ССЫЛКИ (сервер упадёт с 500 — чинить руками!):' -ForegroundColor Red
    $broken | ForEach-Object { Write-Host "  MISSING $_" -ForegroundColor Red }
  } else {
    Write-Host 'Все {file:} ссылки резолвятся' -ForegroundColor Green
  }

  Write-Host '== doctor (WARNING drifted-managed-files: 3 — ожидаемо, это наши 3 дивергенции) ==' -ForegroundColor Cyan
  node scripts/ecc.js doctor --target opencode

  Write-Host '== плагины ==' -ForegroundColor Cyan
  opencode plugin list
}
finally {
  Pop-Location
}
