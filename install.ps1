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

# Required dependency: the codex@openai-codex plugin provides the codex:codex-rescue subagent.
$installedPlugins = Join-Path $env:USERPROFILE '.claude\plugins\installed_plugins.json'
$hasCodexPlugin = (Test-Path $installedPlugins) -and `
    (Select-String -Path $installedPlugins -Pattern 'codex@openai-codex|openai-codex' -Quiet)
if (-not $hasCodexPlugin) {
    Write-Host ""
    Write-Host "REQUIRED: the codex@openai-codex plugin is not installed — the skills cannot delegate without it." -ForegroundColor Red
    Write-Host "  Install it in Claude Code:" -ForegroundColor Yellow
    Write-Host "    /plugin marketplace add openai/codex-plugin-cc" -ForegroundColor Yellow
    Write-Host "    /plugin install codex@openai-codex" -ForegroundColor Yellow
    Write-Host "  Then run /codex:setup and ensure the Codex CLI is logged in (codex login status)." -ForegroundColor Yellow
} else {
    Write-Host "Found codex@openai-codex plugin. Run /codex:setup to confirm it's ready." -ForegroundColor Green
}
