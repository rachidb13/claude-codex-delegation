# Windows wrapper. All logic lives in install.js.
#   powershell -ExecutionPolicy Bypass -File install.ps1 [--dry-run]
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Write-Error "Node.js is required: https://nodejs.org"; exit 1 }
node (Join-Path $PSScriptRoot 'install.js') @args
exit $LASTEXITCODE
