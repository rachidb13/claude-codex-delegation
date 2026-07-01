#!/usr/bin/env bash
# Claude Code — Codex delegation skills installer (macOS / Linux)
# Copies the skill folders into ~/.claude/skills/
# Usage:  ./install.sh    (run: chmod +x install.sh first if needed)

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src_skills="$script_dir/skills"
dst_skills="$HOME/.claude/skills"

if [ ! -d "$src_skills" ]; then
  echo "Error: skills/ folder not found next to this installer ($src_skills)." >&2
  exit 1
fi

mkdir -p "$dst_skills"

for dir in "$src_skills"/*/; do
  name="$(basename "$dir")"
  target="$dst_skills/$name"
  if [ -d "$target" ]; then
    cp -r "$target" "$target.bak-$(date +%Y%m%d%H%M%S)"
    echo "Backed up existing skill: $name"
  fi
  cp -r "$dir" "$dst_skills/"
  echo "Installed skill: $name -> $target"
done

echo ""
echo "Done. Restart Claude Code (or /reload) so it picks up the new skills."

# Required dependency: the codex@openai-codex plugin provides the codex:codex-rescue subagent.
installed_plugins="$HOME/.claude/plugins/installed_plugins.json"
if [ -f "$installed_plugins" ] && grep -Eq 'codex@openai-codex|openai-codex' "$installed_plugins"; then
  echo "Found codex@openai-codex plugin. Run /codex:setup to confirm it's ready."
else
  echo ""
  echo "REQUIRED: the codex@openai-codex plugin is not installed — the skills cannot delegate without it."
  echo "  Install it in Claude Code:"
  echo "    /plugin marketplace add openai/codex-plugin-cc"
  echo "    /plugin install codex@openai-codex"
  echo "  Then run /codex:setup and ensure the Codex CLI is logged in (codex login status)."
fi
