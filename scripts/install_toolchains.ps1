# Extracts the downloaded toolchain archives and installs the Android SDK packages.
# Everything stays inside .toolchains (no admin rights, no global installs).
# Usage:  pwsh -File scripts\install_toolchains.ps1
$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$TC = Join-Path $ProjectRoot '.toolchains'
$DL = Join-Path $TC 'downloads'

function Expand-ArchiveFast([string]$Zip, [string]$Destination) {
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    Write-Host "[extract] $(Split-Path -Leaf $Zip) -> $Destination"
    & tar.exe -xf $Zip -C $Destination
    if ($LASTEXITCODE -ne 0) { throw "tar failed for $Zip (exit $LASTEXITCODE)" }
}

# --- Flutter -------------------------------------------------------------
$flutterZip = Get-ChildItem $DL -Filter 'flutter-*-stable.zip' | Select-Object -First 1
if (-not $flutterZip) { throw 'Flutter zip not found; run scripts/fetch_toolchains.mjs first' }
if (-not (Test-Path (Join-Path $TC 'flutter\bin\flutter.bat'))) {
    Expand-ArchiveFast $flutterZip.FullName $TC
} else {
    Write-Host '[skip] Flutter already extracted'
}

# --- JDK 17 --------------------------------------------------------------
if (-not (Test-Path (Join-Path $TC 'jdk\bin\java.exe'))) {
    $jdkZip = Join-Path $DL 'jdk17-win-x64.zip'
    if (-not (Test-Path $jdkZip)) { throw 'JDK zip not found' }
    $jdkTmp = Join-Path $TC '_jdk_tmp'
    if (Test-Path $jdkTmp) { Remove-Item $jdkTmp -Recurse -Force }
    Expand-ArchiveFast $jdkZip $jdkTmp
    $inner = Get-ChildItem $jdkTmp -Directory | Select-Object -First 1
    if (-not $inner) { throw 'unexpected JDK archive layout' }
    Move-Item $inner.FullName (Join-Path $TC 'jdk')
    Remove-Item $jdkTmp -Recurse -Force
} else {
    Write-Host '[skip] JDK already extracted'
}

# --- MinGit --------------------------------------------------------------
if (-not (Test-Path (Join-Path $TC 'git\cmd\git.exe'))) {
    $gitZip = Get-ChildItem $DL -Filter 'MinGit-*-64-bit.zip' | Select-Object -First 1
    if ($gitZip) {
        Expand-ArchiveFast $gitZip.FullName (Join-Path $TC 'git')
    } else {
        Write-Warning 'MinGit zip not found; Flutter will run without git (version detection may warn)'
    }
} else {
    Write-Host '[skip] MinGit already extracted'
}

# --- Android command-line tools -----------------------------------------
$sdk = Join-Path $TC 'android-sdk'
if (-not (Test-Path (Join-Path $sdk 'cmdline-tools\latest\bin\sdkmanager.bat'))) {
    $cmdZip = Get-ChildItem $DL -Filter 'commandlinetools-win-*_latest.zip' | Select-Object -First 1
    if (-not $cmdZip) { throw 'Android cmdline-tools zip not found' }
    $cmdTmp = Join-Path $TC '_cmd_tmp'
    if (Test-Path $cmdTmp) { Remove-Item $cmdTmp -Recurse -Force }
    Expand-ArchiveFast $cmdZip.FullName $cmdTmp
    New-Item -ItemType Directory -Force -Path (Join-Path $sdk 'cmdline-tools') | Out-Null
    Move-Item (Join-Path $cmdTmp 'cmdline-tools') (Join-Path $sdk 'cmdline-tools\latest')
    Remove-Item $cmdTmp -Recurse -Force
} else {
    Write-Host '[skip] cmdline-tools already extracted'
}

# --- Environment for sdkmanager -----------------------------------------
. (Join-Path $PSScriptRoot 'env.ps1')
$sdkmanager = Join-Path $env:ANDROID_HOME 'cmdline-tools\latest\bin\sdkmanager.bat'

Write-Host '[sdk] accepting licenses'
$answers = ((1..60) | ForEach-Object { 'y' }) -join "`r`n"
$answers | & $sdkmanager --sdk_root="$env:ANDROID_HOME" --licenses | Out-Host
if ($LASTEXITCODE -ne 0) { Write-Warning "license acceptance exited with $LASTEXITCODE (often harmless)" }

Write-Host '[sdk] installing platform-tools, platforms, build-tools'
& $sdkmanager --sdk_root="$env:ANDROID_HOME" --install `
    'platform-tools' 'platforms;android-35' 'platforms;android-36' `
    'build-tools;35.0.0' 'build-tools;36.0.0'
if ($LASTEXITCODE -ne 0) { throw "sdkmanager install failed with exit $LASTEXITCODE" }

Write-Host '[done] toolchains installed'
