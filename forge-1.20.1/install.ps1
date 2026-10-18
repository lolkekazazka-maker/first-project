param([Parameter(Mandatory = $true)][string]$Mc)
# Качает моды, ресурспаки и шейдер из mods.lock.json в папку игры, сверяя sha512.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$lock = Get-Content (Join-Path $PSScriptRoot 'mods.lock.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$failed = @()

function Get-Verified($item, $dir) {
  $path = Join-Path $dir $item.file
  if ((Test-Path -LiteralPath $path) -and ((Get-FileHash -LiteralPath $path -Algorithm SHA512).Hash.ToLower() -eq $item.sha512)) { return $true }
  for ($try = 1; $try -le 3; $try++) {
    try {
      Invoke-WebRequest -UseBasicParsing -Uri $item.url -OutFile $path -Headers @{ 'User-Agent' = 'bmc5-forge-installer' }
      if ((Get-FileHash -LiteralPath $path -Algorithm SHA512).Hash.ToLower() -eq $item.sha512) { return $true }
      Remove-Item -LiteralPath $path -Force
    } catch { Start-Sleep -Seconds 2 }
  }
  return $false
}

function Install-List($items, $folder, $title) {
  $dir = Join-Path $Mc $folder
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $i = 0
  foreach ($it in $items) {
    $i++
    Write-Host ("  {0} {1}/{2}: {3}" -f $title, $i, @($items).Count, $it.file)
    if (-not (Get-Verified $it $dir)) { $script:failed += $it.file }
  }
}

# версия установщика: по ней видно, что запущен свежий скрипт, а не старый из прежнего ZIP
$build = $lock.build
Write-Host "  Версия сборки: $build  (модов в списке: $(@($lock.mods).Count))"

# всё, чего нет в списке (моды от 1.21.1, снятые с поддержки Feature Recycler, Chunky и т.п.), уносим в бэкап:
# сравнение по точному имени файла
$mods = Join-Path $Mc 'mods'
if (Test-Path $mods) {
  $names = @{}
  foreach ($m in $lock.mods) { $names[$m.file] = $true }
  $foreign = @(Get-ChildItem $mods -Filter *.jar -ErrorAction SilentlyContinue | Where-Object { -not $names.ContainsKey($_.Name) })
  if ($foreign.Count -gt 0) {
    $bak = Join-Path $Mc ("mods_backup_" + (Get-Date -Format 'yyyyMMdd_HHmmss'))
    New-Item -ItemType Directory -Force -Path $bak | Out-Null
    $foreign | ForEach-Object { Write-Host "  Убираю лишний мод: $($_.Name)"; Move-Item -LiteralPath $_.FullName -Destination $bak }
    Write-Host "  Лишние моды ($($foreign.Count) шт.) перенесены в $bak"
  }
}

# настройки от сборки 1.21.1 (заставка FancyMenu, названия окна и т.п.) на Forge 1.20.1 не нужны и мешают:
# при первой установке уносим их в бэкап, мод создаст свои настройки заново
$marker = Join-Path $Mc '.bmc5_forge_1.20.1'
if (-not (Test-Path $marker)) {
  $oldCfg = Join-Path $Mc ("config_backup_" + (Get-Date -Format 'yyyyMMdd_HHmmss'))
  foreach ($d in @('config', 'defaultconfigs', 'configureddefaults', 'paxi')) {
    $src = Join-Path $Mc $d
    if (Test-Path $src) {
      New-Item -ItemType Directory -Force -Path $oldCfg | Out-Null
      Move-Item -LiteralPath $src -Destination (Join-Path $oldCfg $d)
    }
  }
  if (Test-Path $oldCfg) { Write-Host "  Старые настройки перенесены в $oldCfg" }
}

Install-List $lock.mods 'mods' 'мод'
Install-List $lock.resourcepacks 'resourcepacks' 'ресурспак'
Install-List $lock.shaderpacks 'shaderpacks' 'шейдер'

# настройки: язык, дальность, включённые ресурспаки и шейдер
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Set-Lines($path, $pairs, $sep) {
  $lines = @()
  if (Test-Path -LiteralPath $path) { Copy-Item -LiteralPath $path "$path.bak" -Force; $lines = @([IO.File]::ReadAllLines($path)) }
  foreach ($k in $pairs.Keys) {
    $found = $false
    for ($j = 0; $j -lt $lines.Count; $j++) { if ($lines[$j].StartsWith($k + $sep)) { $lines[$j] = $k + $sep + $pairs[$k]; $found = $true } }
    if (-not $found) { $lines += ($k + $sep + $pairs[$k]) }
  }
  [IO.File]::WriteAllLines($path, $lines, $utf8)
}

$enable = @('fresh-animations', 'fresh-animations-extensions', 'fresh-animations-details', 'fa-player-extension', 'better-lanterns',
            'fancy-crops', 'rays-3d-ladders', 'rays-3d-rails', 'simple-grass-flowers', 'fresh-flower-pots', 'just-expressions', 'better-leaves')
$packs = @('"vanilla"')
foreach ($s in $enable) {
  $p = $lock.resourcepacks | Where-Object { $_.slug -eq $s } | Select-Object -First 1
  if ($p) { $packs += ('"file/' + $p.file + '"') }
}
Set-Lines (Join-Path $Mc 'options.txt') ([ordered]@{ 'lang' = 'ru_ru'; 'renderDistance' = '12'; 'resourcePacks' = ('[' + ($packs -join ',') + ']') }) ':'
New-Item -ItemType Directory -Force -Path (Join-Path $Mc 'config') | Out-Null
$cfg = Join-Path $Mc 'config'
Set-Lines (Join-Path $cfg 'oculus.properties') ([ordered]@{ 'enableShaders' = 'true'; 'shaderPack' = @($lock.shaderpacks)[0].file }) '='
# панель редактора FancyMenu сверху экрана не нужна
$fm = Join-Path $cfg 'fancymenu'
New-Item -ItemType Directory -Force -Path $fm | Out-Null
if (-not (Test-Path (Join-Path $fm 'options.txt'))) {
  [IO.File]::WriteAllLines((Join-Path $fm 'options.txt'), @("B:show_customization_overlay = 'false';"), $utf8)
}

if ($failed.Count -gt 0) {
  Write-Host "НЕ СКАЧАЛОСЬ:" -ForegroundColor Red
  $failed | ForEach-Object { Write-Host "  $_" }
  exit 1
}
$stale = @(Get-ChildItem $mods -Filter *.jar | Where-Object { $_.Name -match 'Feature-?Recycler|^Chunky|distraction_free_recipes' })
if ($stale.Count -gt 0) {
  Write-Host "В папке mods остались вылетающие моды:" -ForegroundColor Red
  $stale | ForEach-Object { Write-Host "  $($_.Name)" }
  exit 1
}
New-Item -ItemType File -Force -Path $marker | Out-Null
Write-Host ("Всё скачано и проверено. Модов в папке: {0}" -f @(Get-ChildItem $mods -Filter *.jar).Count)
