# claude-codex-delegation

Quota-aware work splitting between [Claude Code](https://claude.com/claude-code) and
[Codex](https://github.com/openai/codex). Before every prompt, a hook reads **both** live
quotas and tells Claude who should do the work and on which model. Whichever side still has
room does the heavy lifting.

```
[DELEGATION CODEX_LOW] Claude: 53% 5h left resets 15:30, 81% week left. Codex: 9% 5h left resets 15:53, 52% week left. ...
```

## Why v2
v1 always sent work to Codex ("Claude conducts, Codex does the heavy lifting"). In practice
that drained Codex long before Claude: on one real day Codex hit 9% left while Claude still had
56%. It also pinned `gpt-5.5`, which Codex now marks Legacy and retires on 2026-10-14.

## Modes
| Mode | When | Who implements |
|---|---|---|
| BALANCED | both have >20% of the 5h window left and >15% of the week | Codex |
| CODEX_LOW | Codex is below either threshold | Claude subagents (sonnet / opus / haiku) |
| CLAUDE_LOW | Claude is below either threshold | Codex, including reviews |
| BOTH_LOW | both low | nothing heavy; Claude reports the reset times |

In every mode Claude does the final code review before a deploy and the deploy itself.
Models by difficulty: Codex `gpt-5.6-sol` / `gpt-5.6-terra` / `gpt-5.6-luna`, Claude `opus` / `sonnet` / `haiku`.
Details are in [`skills/delegating-work/SKILL.md`](skills/delegating-work/SKILL.md).

## How it reads the quotas
- **Claude:** Claude Code passes `rate_limits` only to the statusline. The installer wraps your
  existing statusline with `quota-route.js --tap`, which saves them to
  `~/.claude/state/claude-usage.json` and then prints your original statusline unchanged.
- **Codex:** the latest `rate_limits` event in `~/.codex/sessions/**.jsonl` (5h and weekly windows).
  A window whose reset time has passed counts as full again.

## Install / upgrade
Requires Node.js, the Codex CLI, and the `codex@openai-codex` plugin
(`/plugin marketplace add openai/codex-plugin-cc`, then `/plugin install codex@openai-codex`, then `/codex:setup`).

```bash
git clone https://github.com/rachidb13/claude-codex-delegation && cd claude-codex-delegation
bash install.sh --dry-run    # preview
bash install.sh              # macOS / Linux / Git-Bash
powershell -ExecutionPolicy Bypass -File install.ps1    # Windows
```

To upgrade an existing clone: `git pull && bash install.sh`.

The installer is idempotent and backs up every file it changes (`*.bak-<timestamp>`). It:
1. installs the `delegating-work` skill and archives the v1 skills (`claude-codex-delegation`,
   `codex-daily-delegation`, `hybrid-claude-codex-delegation`) to `~/.claude/skill-backups/`;
2. copies `quota-route.js` to `~/.claude/bin/`;
3. replaces the v1 static `[CODEX DELEGATION ACTIVE]` hook with the live `quota-route --hook`;
4. wraps the statusline (skipped when it already saves `claude-usage.json`);
5. replaces the marked delegation block in `~/.claude/CLAUDE.md`;
6. moves the Codex default model off `gpt-5.5`/`gpt-5.4` to `gpt-5.6-sol`, but only if this Codex
   offers it.

Restart Claude Code afterwards. Check with `node ~/.claude/bin/quota-route.js`.

Thresholds are constants at the top of `quota-route.js` (`LOW_5H = 20`, `LOW_WEEK = 15`).
