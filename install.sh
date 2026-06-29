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
echo "Note: these skills delegate to Codex — install & log in to the Codex CLI / openai/codex-plugin-cc plugin for them to work fully."
