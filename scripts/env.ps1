# Puts the local toolchains on PATH for the current PowerShell session.
# Usage:  . .\scripts\env.ps1
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$TC = Join-Path $ProjectRoot '.toolchains'

$env:FLUTTER_ROOT = Join-Path $TC 'flutter'
if (Test-Path (Join-Path $TC 'jdk')) { $env:JAVA_HOME = Join-Path $TC 'jdk' }
if (Test-Path (Join-Path $TC 'android-sdk')) {
    $env:ANDROID_HOME = Join-Path $TC 'android-sdk'
    $env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
}
$env:PUB_CACHE = Join-Path $TC 'pub-cache'
$env:GRADLE_USER_HOME = Join-Path $TC 'gradle'
# sdkmanager/avdmanager cache lives in the user profile by default; Java resolves
# user.home from the OS profile, so point the SDK tools at a workspace folder.
$env:ANDROID_USER_HOME = Join-Path $TC 'state\Android'

# Flutter/Dart/Gradle write user state outside the repo by default, which the
# file sandbox blocks. Keep all of it under .toolchains/state instead.
$state = Join-Path $TC 'state'
$env:APPDATA = Join-Path $state 'Roaming'
$env:LOCALAPPDATA = Join-Path $state 'Local'
$env:HOME = Join-Path $state 'Home'
$env:TMP = Join-Path $state 'Temp'
$env:TEMP = $env:TMP
New-Item -ItemType Directory -Force -Path $env:APPDATA, $env:LOCALAPPDATA, $env:HOME, $env:TMP, (Join-Path $env:ANDROID_USER_HOME 'cache') | Out-Null

$extra = @(
    (Join-Path $TC 'flutter\bin'),
    (Join-Path $TC 'jdk\bin'),
    (Join-Path $TC 'android-sdk\platform-tools'),
    (Join-Path $TC 'android-sdk\cmdline-tools\latest\bin'),
    (Join-Path $TC 'git\cmd')
) | Where-Object { Test-Path $_ }

$env:Path = ($extra -join ';') + ';' + $env:Path
