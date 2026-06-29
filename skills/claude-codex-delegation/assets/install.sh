#!/usr/bin/env bash
# install.sh — wire up claude-codex-delegation on this machine (macOS / Linux / Git-Bash).
#
# Usage:
#   bash install.sh global
#   bash install.sh project [/path/to/repo]
#   bash install.sh both    [/path/to/repo]
#
# Idempotent: re-running is safe. CLAUDE.md block uses BEGIN/END markers; the settings.json
# reminder hook is keyed on "[CODEX DELEGATION ACTIVE]" and replaced in place.
# JSON hook merge requires `jq`. If jq is missing, the CLAUDE.md block is still installed and
# you'll be told to add the hook manually.
set -euo pipefail

SCOPE="${1:-global}"
PROJECT_DIR="${2:-$(pwd)}"
ASSET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLOCK_FILE="$ASSET_DIR/CLAUDE-block.md"
HOOK_FILE="$ASSET_DIR/settings-hook.json"
MARKER='<!-- BEGIN claude-codex-delegation -->'

add_block() {
  local md="$1"
  if [ -f "$md" ] && grep -qF "$MARKER" "$md"; then
    echo "  [skip] delegation block already present in $md"; return
  fi
  mkdir -p "$(dirname "$md")"
  { [ -f "$md" ] && printf '\n\n'; cat "$BLOCK_FILE"; } >> "$md"
  echo "  [ok]   appended delegation block to $md"
}

merge_hook() {
  local settings="$1"
  if ! command -v jq >/dev/null 2>&1; then
    echo "  [warn] jq not found — cannot merge hook automatically."
    echo "         Add the '_bash_variant' entry from $HOOK_FILE to settings.json UserPromptSubmit manually."
    return
  fi
  mkdir -p "$(dirname "$settings")"
  [ -f "$settings" ] || echo '{}' > "$settings"
  # Build the bash-variant hook entry, drop any prior delegation reminder, then append ours.
  local entry
  entry="$(jq '{hooks:[ ._bash_variant ]}' "$HOOK_FILE")"
  jq --argjson entry "$entry" '
    .hooks = (.hooks // {}) |
    .hooks.UserPromptSubmit = ((.hooks.UserPromptSubmit // [])
      | map(select(any(.hooks[]?; .command | test("\\[CODEX DELEGATION ACTIVE\\]")) | not)))
      + [ $entry ]
  ' "$settings" > "$settings.tmp" && mv "$settings.tmp" "$settings"
  echo "  [ok]   merged delegation reminder hook into $settings"
}

echo "claude-codex-delegation installer (scope: $SCOPE)"
if [ "$SCOPE" = "global" ] || [ "$SCOPE" = "both" ]; then
  echo "Global (~/.claude):"
  add_block "$HOME/.claude/CLAUDE.md"
  merge_hook "$HOME/.claude/settings.json"
fi
if [ "$SCOPE" = "project" ] || [ "$SCOPE" = "both" ]; then
  echo "Project ($PROJECT_DIR):"
  add_block "$PROJECT_DIR/CLAUDE.md"
  merge_hook "$PROJECT_DIR/.claude/settings.json"
fi

echo ""
echo "Verifying Codex availability..."
if command -v codex >/dev/null 2>&1; then
  echo "  codex CLI: $(command -v codex)"; codex login status || true
else
  echo "  [warn] codex CLI not found. Install: /plugin marketplace add openai/codex-plugin-cc  then  /codex:setup"
fi
echo ""
echo "Done. RESTART your Claude session so the new hook + CLAUDE.md load."
