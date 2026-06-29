<#
  install.ps1 — wire up claude-codex-delegation on this machine (Windows / PowerShell).

  Usage:
    powershell -ExecutionPolicy Bypass -File install.ps1 -Scope global
    powershell -ExecutionPolicy Bypass -File install.ps1 -Scope project -ProjectDir "C:\path\to\repo"
    powershell -ExecutionPolicy Bypass -File install.ps1 -Scope both    -ProjectDir "C:\path\to\repo"

  Idempotent: re-running is safe. The CLAUDE.md block uses BEGIN/END markers; the
  settings.json reminder hook is keyed on "[CODEX DELEGATION ACTIVE]" and replaced in place.
#>
param(
  [ValidateSet('global','project','both')]
  [string]$Scope = 'global',
  [string]$ProjectDir = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'
$AssetDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$BlockFile  = Join-Path $AssetDir 'CLAUDE-block.md'
$HookFile   = Join-Path $AssetDir 'settings-hook.json'
$MarkerBegin = '<!-- BEGIN claude-codex-delegation -->'

# PowerShell 5.1's Set-Content -Encoding UTF8 emits a BOM, which breaks settings.json
# parsers. Always write UTF-8 WITHOUT BOM.
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function Write-Text([string]$path, [string]$content) {
  [System.IO.File]::WriteAllText($path, $content, $Utf8NoBom)
}

function Add-ClaudeMdBlock([string]$claudeMd) {
  $block = Get-Content -Raw -Encoding UTF8 $BlockFile
  if (Test-Path $claudeMd) {
    $existing = Get-Content -Raw -Encoding UTF8 $claudeMd
    if ($existing -like "*$MarkerBegin*") {
      Write-Host "  [skip] delegation block already present in $claudeMd"
      return
    }
    $new = $existing.TrimEnd() + "`r`n`r`n" + $block
  } else {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $claudeMd) | Out-Null
    $new = $block
  }
  Write-Text $claudeMd $new
  Write-Host "  [ok]   appended delegation block to $claudeMd"
}

function Merge-Hook([string]$settingsPath) {
  $hookEntry = (Get-Content -Raw -Encoding UTF8 $HookFile | ConvertFrom-Json).hooks.UserPromptSubmit[0]

  if (Test-Path $settingsPath) {
    $settings = Get-Content -Raw -Encoding UTF8 $settingsPath | ConvertFrom-Json
  } else {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $settingsPath) | Out-Null
    $settings = [pscustomobject]@{}
  }
  if (-not $settings.PSObject.Properties.Name -contains 'hooks' -or $null -eq $settings.hooks) {
    $settings | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{}) -Force
  }
  # Collect existing UserPromptSubmit entries, dropping any previous delegation reminder.
  $existing = @()
  if ($settings.hooks.PSObject.Properties.Name -contains 'UserPromptSubmit') {
    foreach ($e in @($settings.hooks.UserPromptSubmit)) {
      $isOurs = $false
      foreach ($h in @($e.hooks)) { if ($h.command -like '*[CODEX DELEGATION ACTIVE]*') { $isOurs = $true } }
      if (-not $isOurs) { $existing += $e }
    }
  }
  $existing += $hookEntry
  $settings.hooks | Add-Member -NotePropertyName UserPromptSubmit -NotePropertyValue ([array]$existing) -Force

  Write-Text $settingsPath ($settings | ConvertTo-Json -Depth 20)
  Write-Host "  [ok]   merged delegation reminder hook into $settingsPath"
}

$homeDir = $env:USERPROFILE
Write-Host "claude-codex-delegation installer (scope: $Scope)"

if ($Scope -in @('global','both')) {
  Write-Host "Global (~/.claude):"
  Add-ClaudeMdBlock (Join-Path $homeDir '.claude\CLAUDE.md')
  Merge-Hook        (Join-Path $homeDir '.claude\settings.json')
}
if ($Scope -in @('project','both')) {
  Write-Host "Project ($ProjectDir):"
  Add-ClaudeMdBlock (Join-Path $ProjectDir 'CLAUDE.md')
  Merge-Hook        (Join-Path $ProjectDir '.claude\settings.json')
}

Write-Host ""
Write-Host "Verifying Codex availability..."
$codex = Get-Command codex -ErrorAction SilentlyContinue
if ($codex) { Write-Host "  codex CLI: $($codex.Source)"; & codex login status } else {
  Write-Host "  [warn] codex CLI not found. Install: /plugin marketplace add openai/codex-plugin-cc  then  /codex:setup"
}
Write-Host ""
Write-Host "Done. RESTART your Claude session so the new hook + CLAUDE.md load."
