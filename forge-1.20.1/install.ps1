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

$rp = Join-Path $Mc 'resourcepacks'
# Mizuno убран из сборки (по просьбе): если он остался от прошлой установки, уносим в бэкап, чтобы он не лежал среди паков
$oldMizuno = @(Get-ChildItem $rp -Filter *.zip -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '(?i)mizuno' })
if ($oldMizuno.Count -gt 0) {
  $mzBak = Join-Path $Mc ("resourcepacks_backup_" + (Get-Date -Format 'yyyyMMdd_HHmmss'))
  New-Item -ItemType Directory -Force -Path $mzBak | Out-Null
  $oldMizuno | ForEach-Object { Write-Host "  Убираю Mizuno: $($_.Name)"; Move-Item -LiteralPath $_.FullName -Destination $mzBak }
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
# в Minecraft 1.20.1 повороты элементов моделей бывают только -45, -22.5, 0, 22.5 и 45 градусов вокруг одной оси; паки, сделанные под
# новые версии, используют любые углы и поворот сразу по трём осям, и такая модель не грузится (вместо неё фиолетовая «шашечка»).
# Для таких паков в копии округляем угол до допустимого, а у поворота по трём осям берём главную ось
$validAngles = @(-45.0, -22.5, 0.0, 22.5, 45.0)
$inv = [Globalization.CultureInfo]::InvariantCulture
function Get-SnapAngle([double]$a) {
  $best = $script:validAngles[0]
  foreach ($v in $script:validAngles) { if ([math]::Abs($v - $a) -lt [math]::Abs($best - $a)) { $best = $v } }
  return [string]::Format($script:inv, '{0}', $best)
}
$num = '(-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)'
$reMulti = '"rotation"\s*:\s*\{\s*"x"\s*:\s*' + $num + '\s*,\s*"y"\s*:\s*' + $num + '\s*,\s*"z"\s*:\s*' + $num + '\s*,\s*"origin"\s*:\s*(\[[^\]]*\])\s*\}'
$reSingle = '("angle"\s*:\s*)' + $num
$evalMulti = [Text.RegularExpressions.MatchEvaluator] {
  param($m)
  $x = [double]::Parse($m.Groups[1].Value, $script:inv); $y = [double]::Parse($m.Groups[2].Value, $script:inv); $z = [double]::Parse($m.Groups[3].Value, $script:inv)
  $axis = 'x'; $val = $x
  if ([math]::Abs($y) -gt [math]::Abs($val)) { $axis = 'y'; $val = $y }
  if ([math]::Abs($z) -gt [math]::Abs($val)) { $axis = 'z'; $val = $z }
  return ('"rotation": {"angle": ' + (Get-SnapAngle $val) + ', "axis": "' + $axis + '", "origin": ' + $m.Groups[4].Value + '}')
}
$evalSingle = [Text.RegularExpressions.MatchEvaluator] {
  param($m)
  return ($m.Groups[1].Value + (Get-SnapAngle ([double]::Parse($m.Groups[2].Value, $script:inv))))
}
function New-FixedPack($srcPath, $dstName, $drop, $fixModels) {
  $dst = Join-Path $rp $dstName
  Copy-Item -LiteralPath $srcPath -Destination $dst -Force
  $zip = [IO.Compression.ZipFile]::Open($dst, [IO.Compression.ZipArchiveMode]::Update)
  try {
    foreach ($e in @($zip.Entries)) { foreach ($re in $drop) { if ($e.FullName -match $re) { $e.Delete(); break } } }
    if ($fixModels) {
      foreach ($e in @($zip.Entries)) {
        if ($e.FullName -notmatch '^assets/[^/]+/models/.+\.json$') { continue }
        $name = $e.FullName
        $old = Read-ZipText $e
        $new = [regex]::Replace([regex]::Replace($old, $script:reMulti, $script:evalMulti), $script:reSingle, $script:evalSingle)
        if ($new -ne $old) {
          $e.Delete()
          $sw = New-Object IO.StreamWriter(($zip.CreateEntry($name)).Open(), $utf8)
          try { $sw.Write($new) } finally { $sw.Dispose() }
        }
      }
    }
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

# порядок: от нижнего слоя к верхнему (последний в списке перекрывает остальные)
$enable = @('fresh-animations', 'fresh-animations-extensions', 'fresh-animations-details', 'fa-player-extension',
            'polaris-animation-for-punchy', 'blacksea-animation-for-punchy', '3d-workbenches', '3d-equipment',
            'better-lanterns', 'fancy-crops', '3d-crops', 'rays-3d-ladders', 'rays-3d-rails', 'simple-grass-flowers',
            'fresh-flower-pots', 'just-expressions', '3d-food', 'mikapika-s-3d-mushrooms', 'cutegirlvillagers', 'melodyswitches', 'melodysillagers', 'melodys-cute-girl-traders', 'iron-girl',
            'overgrown-flowery-gui', 'overgrown-flowery-hotbar', 'better-leaves')
$packs = @('"vanilla"')
foreach ($s in $enable) {
  $p = $lock.resourcepacks | Where-Object { $_.slug -eq $s } | Select-Object -First 1
  if (-not $p) { continue }
  $file = $p.file
  $path = Join-Path $rp $file
  $drop = @()
  if ($s -eq 'overgrown-flowery-gui' -or $s -eq 'overgrown-flowery-hotbar') { $drop = $iconsEntry }
  $fixModels = ($s -eq '3d-equipment')
  if ((Get-PackFormat $path) -ne $mcFormat -or $drop.Count -gt 0 -or $fixModels) {
    $file = New-FixedPack $path ([IO.Path]::GetFileNameWithoutExtension($file) + ' [1.20.1].zip') $drop $fixModels
  }
  $packs += ('"file/' + $file + '"')
}
# карта JourneyMap на клавишу M (по умолчанию J; J освобождаем, чтобы она не прятала миникарту);
# на G по умолчанию висят Curios, справочник More Villagers и меню Female Gender Mod, а K занята Oculus (шейдеры), Pro Placer и Dungeon Config:
# меню Female Gender Mod переносим на ], справочник снимаем
# без строки version Minecraft считает options.txt очень старым, не понимает имя клавиши и сбрасывает все настройки
$optPath = Join-Path $Mc 'options.txt'
$opts = [ordered]@{ 'lang' = 'ru_ru'; 'renderDistance' = '12'; 'key_key.journeymap.map_toggle_alt' = 'key.keyboard.m'; 'key_key.journeymap.minimap_toggle_alt' = 'key.keyboard.unknown'; 'key_key.more_villargers.guide_gui' = 'key.keyboard.unknown'; 'key_key.wildfire_gender.gender_menu' = 'key.keyboard.right.bracket'; 'resourcePacks' = ('[' + ($packs -join ',') + ']') }
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
