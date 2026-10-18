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

# старые моды (например, от 1.21.1) уносим в бэкап: Forge 1.20.1 их не загрузит
$mods = Join-Path $Mc 'mods'
if ((Test-Path $mods) -and (Get-ChildItem $mods -Filter *.jar -ErrorAction SilentlyContinue)) {
  $names = Get-Content (Join-Path $PSScriptRoot 'mods.lock.json') -Raw -Encoding UTF8
  $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
  $foreign = Get-ChildItem $mods -Filter *.jar | Where-Object { -not $names.Contains($_.Name) }
  if ($foreign) {
    $bak = Join-Path $Mc ("mods_backup_" + $stamp)
    New-Item -ItemType Directory -Force -Path $bak | Out-Null
    $foreign | Move-Item -Destination $bak
    Write-Host "  Чужие моды перенесены в $bak"
  }
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
Set-Lines (Join-Path $Mc 'config\oculus.properties') ([ordered]@{ 'enableShaders' = 'true'; 'shaderPack' = @($lock.shaderpacks)[0].file }) '='

if ($failed.Count -gt 0) {
  Write-Host "НЕ СКАЧАЛОСЬ:" -ForegroundColor Red
  $failed | ForEach-Object { Write-Host "  $_" }
  exit 1
}
Write-Host "Всё скачано и проверено."
