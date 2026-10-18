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

# Mizuno's 16 Craft есть только на CurseForge, скачать автоматически нельзя: если файл лежит рядом с install.bat
# (в папке forge-1.20.1) или уже в resourcepacks, подключаем его и дополнения к нему
$rp = Join-Path $Mc 'resourcepacks'
$mizunoRe = '(?i)mizuno.*16.*craft'
$mizunoSkip = '(?i)addon|better|connected|fresh|variants|crops|grass|glass|eating|tinker|modern|tweaks'
$mizuno = @(Get-ChildItem $PSScriptRoot, $rp -Filter *.zip -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $mizunoRe -and $_.Name -notmatch $mizunoSkip }) | Select-Object -First 1
if ($mizuno) {
  if ($mizuno.DirectoryName -ne $rp) { Copy-Item -LiteralPath $mizuno.FullName -Destination $rp -Force }
  Write-Host "  Mizuno's 16 Craft найден: $($mizuno.Name)"
} else {
  Write-Host "  Mizuno's 16 Craft не найден (он только на CurseForge): скачай zip вручную, положи в папку forge-1.20.1 и запусти install.bat ещё раз" -ForegroundColor Yellow
}

# порядок: от нижнего слоя к верхнему (последний в списке перекрывает остальные)
$enable = @()
if ($mizuno) { $enable += '@mizuno' }
$enable += @('fresh-animations', 'fresh-animations-extensions', 'fresh-animations-details', 'fa-player-extension')
if ($mizuno) { $enable += 'mizuno-x-fresh-animations' }
$enable += @('actually-3d-blocks-and-items', '3d-equipment', '3d-workbenches')
$enable += @('better-lanterns', 'fancy-crops', '3d-crops')
if ($mizuno) { $enable += 'mizunos-better-crops' }
$enable += @('rays-3d-ladders', 'rays-3d-rails', 'simple-grass-flowers')
if ($mizuno) { $enable += @('mizunos-better-grass', 'mizuno-connected-texture', 'mizunos-connected-glass') }
$enable += @('fresh-flower-pots', 'just-expressions', '3d-food', 'mikapika-s-3d-mushrooms', 'cutegirlvillagers', 'iron-girl',
             'overgrown-flowery-gui', 'overgrown-flowery-hotbar')
$enable += $(if ($mizuno) { 'mizuno-better-leaves' } else { 'better-leaves' })
$packs = @('"vanilla"')
foreach ($s in $enable) {
  if ($s -eq '@mizuno') { $packs += ('"file/' + $mizuno.Name + '"'); continue }
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

# Physics Mod: осколки у сломанных блоков оставляем, а цепные обвалы пещер (collapse) выключаем;
# остальные значения из уже существующего файла сохраняем
$pm = Join-Path $cfg 'physicsmod'
New-Item -ItemType Directory -Force -Path $pm | Out-Null
$srv = Join-Path $pm 'physics_server_config.json'
$phys = [ordered]@{ collapse = $false; maxCollapseObjects = 100; collapseSpeed = 10; dropBlocks = $true }
if (Test-Path -LiteralPath $srv) {
  try {
    $cur = Get-Content -LiteralPath $srv -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($p in $cur.PSObject.Properties) { if ($p.Name -ne 'collapse') { $phys[$p.Name] = $p.Value } }
  } catch { }
}
[IO.File]::WriteAllText($srv, ($phys | ConvertTo-Json), $utf8)

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
