# Unzips the pre-seeded Gradle distribution and marks it ready for the wrapper.
# Usage: pwsh -ExecutionPolicy Bypass -File scripts\install_gradle.ps1
$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$tc = Join-Path $ProjectRoot '.toolchains'
$distRoot = Join-Path $tc 'gradle\wrapper\dists\gradle-9.3.1-all'
$distDir = Get-ChildItem $distRoot -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $distDir) { throw 'Gradle dist dir missing; run: node scripts/fetch_gradle.mjs' }

$zip = Join-Path $distDir.FullName 'gradle-9.3.1-all.zip'
if (-not (Test-Path $zip)) { throw "Gradle zip missing at $zip" }

if (-not (Test-Path (Join-Path $distDir.FullName 'gradle-9.3.1\bin\gradle.bat'))) {
    Write-Host '[extract] gradle-9.3.1-all.zip'
    & tar.exe -xf $zip -C $distDir.FullName
    if ($LASTEXITCODE -ne 0) { throw "tar failed: $LASTEXITCODE" }
}

$ok = Join-Path $distDir.FullName '.ok'
if (-not (Test-Path $ok)) { New-Item -ItemType File -Path $ok | Out-Null }

Write-Host "[done] Gradle ready at $($distDir.FullName)"
