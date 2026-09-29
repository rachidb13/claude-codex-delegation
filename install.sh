#!/usr/bin/env bash
# macOS / Linux / Git-Bash wrapper. All logic lives in install.js (needs Node, which Claude Code's statusline and this router use).
set -euo pipefail
command -v node >/dev/null || { echo "Node.js is required: https://nodejs.org" >&2; exit 1; }
exec node "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/install.js" "$@"
