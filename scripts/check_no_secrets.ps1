# Scans the client and server source for API keys. Exits non-zero on any match.
# Run from the repo root:  pwsh -ExecutionPolicy Bypass -File scripts\check_no_secrets.ps1
$ErrorActionPreference = 'SilentlyContinue'
$root = Split-Path -Parent $PSScriptRoot

$secrets = @(
  '552407f0651e68efb4a55fa670880b3dbb7c7163',
  '743ce2c9-73f7-4b43-be97-9f56dd9c7c13:fx'
)
$patterns = @(
  '(?i)\b(sk|pk|rk)_[A-Za-z0-9]{16,}\b',
  '(?i)api[_-]?key\s*[:=]\s*["''][A-Za-z0-9_\-]{20,}["'']',
  '(?i)deepgram[_-]api[_-]?key\s*=\s*[A-Za-z0-9]{20,}',
  '(?i)deepl[_-]api[_-]?key\s*=\s*[A-Za-z0-9:]{20,}'
)

$roots = @((Join-Path $root 'client'), (Join-Path $root 'server'))
$exclude = '\\build\\|\\.dart_tool\\|\\.venv\\|\\.toolchains\\|\\.git\\|\\\.env$|selftest_|last_result\.json|\\.pytest_cache\\|__pycache__'
$ext = '\.(dart|py|md|yaml|yml|ps1|mjs|gradle|kts|xml|json|example|ini|txt|cmake|h|cpp|cc|rc)$'

$found = @()
foreach ($target in $roots) {
  Get-ChildItem $target -Recurse -File | Where-Object {
    $_.FullName -notmatch $exclude -and $_.Extension -match $ext
  } | ForEach-Object {
    $text = Get-Content -LiteralPath $_.FullName -Raw
    if (-not $text) { return }
    $secrets | ForEach-Object { if ($text.Contains($_)) { $found += $_.FullName } }
    $patterns | ForEach-Object { if ($text -match $_) { $found += $_.FullName } }
  }
}

if ($found.Count -gt 0) {
  Write-Host 'SECRET LEAK DETECTED in:'
  $found | Sort-Object -Unique | ForEach-Object { Write-Host "  $_" }
  exit 1
}
Write-Host 'OK: no API keys found in client/ or server/ source.'
exit 0
