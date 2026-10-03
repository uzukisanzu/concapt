# Builds release packages into dist/: a signed APK and a portable Windows zip.
# Pass -Android or -Windows to build one; with neither, builds both.

param([switch]$Android, [switch]$Windows)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

if (-not $Android -and -not $Windows) { $Android = $true; $Windows = $true }

$version = (Select-String -Path pubspec.yaml -Pattern '^version:\s*([^+\s]+)').Matches[0].Groups[1].Value
$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force $dist | Out-Null

function Invoke-Flutter {
  & flutter @args
  if ($LASTEXITCODE -ne 0) { throw "flutter $args failed" }
}

if ($Android) {

  # Without key.properties, Gradle signs with the debug key, which can't update a release install.

  if (-not (Test-Path android/key.properties)) {
    throw 'android/key.properties is missing. See docs/releasing.md.'
  }
  Invoke-Flutter build apk --release
  Copy-Item build/app/outputs/flutter-apk/app-release.apk (Join-Path $dist "concapt-$version.apk") -Force
}

if ($Windows) {
  Invoke-Flutter build windows --release
  $stage = Join-Path $dist "concapt-$version-windows-x64"
  if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
  Copy-Item -Recurse build/windows/x64/runner/Release $stage

  # Flutter apps need the MSVC runtime; bundling it spares users the redistributable.

  foreach ($dll in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
    Copy-Item (Join-Path $env:WINDIR "System32\$dll") $stage
  }
  $zip = "$stage.zip"
  if (Test-Path $zip) { Remove-Item -Force $zip }
  Compress-Archive -Path "$stage\*" -DestinationPath $zip
  Remove-Item -Recurse -Force $stage
}

Get-ChildItem $dist | Select-Object Name, @{ n = 'MB'; e = { [math]::Round($_.Length / 1MB, 1) } }
