# Replaces the SDK command-line tools with the pinned stable build and installs
# the Android SDK packages required by Flutter.
# Usage: pwsh -ExecutionPolicy Bypass -File scripts\install_android_sdk.ps1
$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$TC = Join-Path $ProjectRoot '.toolchains'
$DL = Join-Path $TC 'downloads'
$sdk = Join-Path $TC 'android-sdk'

$zip = Get-ChildItem $DL -Filter 'commandlinetools-win-13114758_latest.zip' | Select-Object -First 1
if (-not $zip) { throw 'pinned cmdline-tools zip missing; run: node scripts/fetch_cmdline_tools.mjs' }

# SDK archives contain paths longer than MAX_PATH; Remove-Item cannot delete
# them, so shell out to rd with the \\?\ prefix.
function Remove-LongPath([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    & cmd.exe /c rd /s /q "\\?\$Path"
    if (Test-Path -LiteralPath $Path) { throw "failed to remove long path: $Path" }
}

$tmp = Join-Path $TC '_cmd_legacy'
Remove-LongPath $tmp
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
Write-Host '[extract] cmdline-tools 13114758'
& tar.exe -xf $zip.FullName -C $tmp
if ($LASTEXITCODE -ne 0) { throw "tar failed: $LASTEXITCODE" }

$latest = Join-Path $sdk 'cmdline-tools\latest'
Remove-LongPath $latest
New-Item -ItemType Directory -Force -Path (Join-Path $sdk 'cmdline-tools') | Out-Null
Move-Item (Join-Path $tmp 'cmdline-tools') $latest
Remove-LongPath $tmp

. (Join-Path $PSScriptRoot 'env.ps1')
$sdkmanager = Join-Path $env:ANDROID_HOME 'cmdline-tools\latest\bin\sdkmanager.bat'

Write-Host '[sdk] accepting licenses'
$answers = ((1..80) | ForEach-Object { 'y' }) -join "`r`n"
$answers | & $sdkmanager --sdk_root="$env:ANDROID_HOME" --licenses | Out-Host

Write-Host '[sdk] installing packages'
& $sdkmanager --sdk_root="$env:ANDROID_HOME" --install `
    'platform-tools' 'platforms;android-35' 'platforms;android-36' `
    'build-tools;35.0.0' 'build-tools;36.0.0'
if ($LASTEXITCODE -ne 0) { throw "sdkmanager install failed: $LASTEXITCODE" }

Write-Host '[done] Android SDK ready'
