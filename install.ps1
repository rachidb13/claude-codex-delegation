# Claude Code — Codex delegation skills installer (Windows / PowerShell)
# Copies the skill folders into ~/.claude/skills/
# Usage:  powershell -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcSkills = Join-Path $scriptDir 'skills'
$dstSkills = Join-Path $env:USERPROFILE '.claude\skills'

if (-not (Test-Path $srcSkills)) {
    Write-Error "skills\ folder not found next to this installer ($srcSkills)."
}

if (-not (Test-Path $dstSkills)) {
    New-Item -ItemType Directory -Path $dstSkills -Force | Out-Null
}

Get-ChildItem -Path $srcSkills -Directory | ForEach-Object {
    $name   = $_.Name
    $target = Join-Path $dstSkills $name
    if (Test-Path $target) {
        Copy-Item "$target" "$target.bak-$(Get-Date -Format yyyyMMddHHmmss)" -Recurse -Force
        Write-Host "Backed up existing skill: $name" -ForegroundColor DarkGray
    }
    Copy-Item -Path $_.FullName -Destination $dstSkills -Recurse -Force
    Write-Host "Installed skill: $name -> $target" -ForegroundColor Green
}

Write-Host ""
Write-Host "Done. Restart Claude Code (or /reload) so it picks up the new skills." -ForegroundColor Cyan
Write-Host "Note: these skills delegate to Codex — install & log in to the Codex CLI / openai/codex-plugin-cc plugin for them to work fully." -ForegroundColor Yellow
