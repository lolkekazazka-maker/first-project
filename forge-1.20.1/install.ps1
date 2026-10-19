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

# Minecraft 1.20.1 молча выкидывает из options.txt паки с чужим pack_format (старше или новее 15) и не понимает supported_formats.
# Поэтому для каждого такого пака делаем копию с pack_format 15; у Overgrown Flowery GUI/Hotbar заодно убираем icons.png:
# в нём здоровье нарисовано цветами, а голод каплями воды, без него иконки будут обычные
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$mcFormat = 15
function Read-ZipText($entry) {
  $sr = New-Object IO.StreamReader($entry.Open(), [Text.Encoding]::UTF8)
  try { return $sr.ReadToEnd() } finally { $sr.Dispose() }
}
function Get-PackFormat($path) {
  $z = [IO.Compression.ZipFile]::OpenRead($path)
  try {
    $e = $z.GetEntry('pack.mcmeta')
    if (-not $e) { return $mcFormat }
    $m = [regex]::Match((Read-ZipText $e), '"pack_format"\s*:\s*(\d+)')
    if ($m.Success) { return [int]$m.Groups[1].Value } else { return $mcFormat }
  } finally { $z.Dispose() }
}
function New-FixedPack($srcPath, $dstName, $drop) {
  $dst = Join-Path $rp $dstName
  Copy-Item -LiteralPath $srcPath -Destination $dst -Force
  $zip = [IO.Compression.ZipFile]::Open($dst, [IO.Compression.ZipArchiveMode]::Update)
  try {
    foreach ($e in @($zip.Entries)) { foreach ($re in $drop) { if ($e.FullName -match $re) { $e.Delete(); break } } }
    $m = $zip.GetEntry('pack.mcmeta')
    if ($m) {
      $txt = [regex]::Replace((Read-ZipText $m), '"pack_format"\s*:\s*\d+', ('"pack_format": ' + $mcFormat))
      $m.Delete()
      $sw = New-Object IO.StreamWriter(($zip.CreateEntry('pack.mcmeta')).Open(), $utf8)
      try { $sw.Write($txt) } finally { $sw.Dispose() }
    }
  } finally { $zip.Dispose() }
  return $dstName
}
$iconsEntry = @('^assets/minecraft/textures/gui/icons\.png$')
# овца целиком берётся из Mizuno (модель, текстура и лицо одного автора), а не из Fresh Animations / Mizuno x FA
$sheepRe = @('(^|/)assets/minecraft/(optifine/cem/sheep|optifine/random/entity/sheep/|textures/entity/sheep/)')

# порядок: от нижнего слоя к верхнему (последний в списке перекрывает остальные)
$enable = @()
if ($mizuno) { $enable += '@mizuno' }
# Mizuno x Fresh Animations заменяет модель и текстуру овцы и других мобов: вместе с Fresh Animations Extensions/Details
# части моделей перемешиваются, и у окрашенных овец пропадает лицо. Поэтому с Mizuno ставим только базовый Fresh Animations
$enable += @('fresh-animations')
if (-not $mizuno) { $enable += @('fresh-animations-extensions', 'fresh-animations-details') }
$enable += @('fa-player-extension', 'polaris-animation-for-punchy', 'blacksea-animation-for-punchy')
if ($mizuno) { $enable += 'mizuno-x-fresh-animations' }
$enable += @('3d-workbenches')
$enable += @('better-lanterns', 'fancy-crops', '3d-crops')
if ($mizuno) { $enable += 'mizunos-better-crops' }
$enable += @('rays-3d-ladders', 'rays-3d-rails', 'simple-grass-flowers')
if ($mizuno) { $enable += @('mizunos-better-grass', 'mizuno-connected-texture', 'mizunos-connected-glass') }
$enable += @('fresh-flower-pots', 'just-expressions', '3d-food', 'mikapika-s-3d-mushrooms', 'cutegirlvillagers', 'iron-girl',
             'overgrown-flowery-gui', 'overgrown-flowery-hotbar')
$enable += $(if ($mizuno) { 'mizuno-better-leaves' } else { 'better-leaves' })
$packs = @('"vanilla"')
foreach ($s in $enable) {
  if ($s -eq '@mizuno') { $file = $mizuno.Name }
  else {
    $p = $lock.resourcepacks | Where-Object { $_.slug -eq $s } | Select-Object -First 1
    if (-not $p) { continue }
    $file = $p.file
  }
  $path = Join-Path $rp $file
  $drop = @()
  if ($s -eq 'overgrown-flowery-gui' -or $s -eq 'overgrown-flowery-hotbar') { $drop = $iconsEntry }
  if ($mizuno -and ($s -eq 'fresh-animations' -or $s -eq 'mizuno-x-fresh-animations')) { $drop = $sheepRe }
  if ((Get-PackFormat $path) -ne $mcFormat -or $drop.Count -gt 0) {
    $file = New-FixedPack $path ([IO.Path]::GetFileNameWithoutExtension($file) + ' [1.20.1].zip') $drop
  }
  $packs += ('"file/' + $file + '"')
}
# карта JourneyMap на клавишу M (по умолчанию J; J освобождаем, чтобы она не прятала миникарту)
# без строки version Minecraft считает options.txt очень старым, не понимает имя клавиши и сбрасывает все настройки
$optPath = Join-Path $Mc 'options.txt'
$opts = [ordered]@{ 'lang' = 'ru_ru'; 'renderDistance' = '12'; 'key_key.journeymap.map_toggle_alt' = 'key.keyboard.m'; 'key_key.journeymap.minimap_toggle_alt' = 'key.keyboard.unknown'; 'resourcePacks' = ('[' + ($packs -join ',') + ']') }
if (-not ((Test-Path -LiteralPath $optPath) -and (Select-String -LiteralPath $optPath -Pattern '^version:' -Quiet))) { $opts['version'] = '3465' }
Set-Lines $optPath $opts ':'
New-Item -ItemType Directory -Force -Path (Join-Path $Mc 'config') | Out-Null
$cfg = Join-Path $Mc 'config'
Set-Lines (Join-Path $cfg 'oculus.properties') ([ordered]@{ 'enableShaders' = 'true'; 'shaderPack' = @($lock.shaderpacks)[0].file }) '='
# готовые настройки из старой сборки и мои правки (папка config рядом с install.bat): ставим один раз на версию набора,
# заменённые файлы сохраняем в config_backup_*_replaced
$cfgVer = $lock.build
$cfgMarker = Join-Path $Mc ('.bmc5_config_' + $cfgVer)
$bundle = Join-Path $PSScriptRoot 'config'
if ((Test-Path $bundle) -and -not (Test-Path $cfgMarker)) {
  $bak = Join-Path $Mc ('config_backup_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '_replaced')
  $n = 0
  foreach ($f in Get-ChildItem $bundle -Recurse -File) {
    $rel = $f.FullName.Substring($bundle.Length).TrimStart('\', '/')
    $to = Join-Path $cfg $rel
    New-Item -ItemType Directory -Force -Path (Split-Path $to) | Out-Null
    if (Test-Path -LiteralPath $to) {
      $b = Join-Path $bak $rel
      New-Item -ItemType Directory -Force -Path (Split-Path $b) | Out-Null
      Copy-Item -LiteralPath $to -Destination $b -Force
    }
    Copy-Item -LiteralPath $f.FullName -Destination $to -Force
    $n++
  }
  # MCA Reborn: без стартового экрана «Кто ты?» и истории (Destiny) и без редактора внешности игрока:
  # он менял форму тела, а скин не сохранялся, и игрок становился «Стивом другой формы»
  $mca = Join-Path $cfg 'mca.json'
  if (Test-Path -LiteralPath $mca) {
    $txt = [IO.File]::ReadAllText($mca)
    foreach ($k in @('enableVillagerPlayerModel', 'forceVillagerPlayerModel', 'launchIntoDestiny', 'allowFullPlayerEditor', 'allowLimitedPlayerEditor')) {
      if ($txt -match ('"' + $k + '"\s*:')) { $txt = [regex]::Replace($txt, '("' + $k + '"\s*:\s*)(true|false)', '${1}false') }
      else { $txt = [regex]::Replace($txt, '^\s*\{', ('{' + [Environment]::NewLine + '  "' + $k + '": false,'), 1) }
    }
    [IO.File]::WriteAllText($mca, $txt, $utf8)
  } else {
    [IO.File]::WriteAllText($mca, "{`n  `"enableVillagerPlayerModel`": false,`n  `"forceVillagerPlayerModel`": false,`n  `"launchIntoDestiny`": false,`n  `"allowFullPlayerEditor`": false,`n  `"allowLimitedPlayerEditor`": false`n}`n", $utf8)
  }
  New-Item -ItemType File -Force -Path $cfgMarker | Out-Null
  Write-Host "  Настройки скопированы: $n файлов (прежние версии, если были, в $bak)"
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
