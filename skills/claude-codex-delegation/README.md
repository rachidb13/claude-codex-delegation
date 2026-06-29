# claude-codex-delegation

A portable, self-installing Claude Code skill that makes **Claude conduct and Codex do the
heavy lifting** — implementation *and* the token-heavy work (codebase investigation,
spec/plan drafting, speckit.tasks/analyze, review). Solves the "Claude at 80–90%, Codex at
10%" imbalance.

## What it contains
```
claude-codex-delegation/
  SKILL.md                     the delegation rules + an Installation section
  README.md                    this file
  assets/
    CLAUDE-block.md            the delegation block appended to CLAUDE.md (BEGIN/END markers)
    settings-hook.json         the UserPromptSubmit reminder hook (PowerShell + bash variants)
    install.ps1                Windows installer (idempotent; merges CLAUDE.md + settings.json)
    install.sh                 macOS/Linux/Git-Bash installer (needs jq for the hook merge)
```

## Install on a new machine
1. Copy this whole folder to the new machine's `~/.claude/skills/claude-codex-delegation/`
   (or clone it there from your dotfiles repo).
2. Restart Claude Code.
3. Tell Claude: **"install the claude-codex-delegation skill"**.
   Claude will confirm Codex is available, ask global vs project scope, run the installer,
   verify, and tell you to restart.

Or run the installer directly:
```powershell
# Windows
powershell -ExecutionPolicy Bypass -File "~/.claude/skills/claude-codex-delegation/assets/install.ps1" -Scope global
```
```bash
# macOS / Linux / Git-Bash
bash ~/.claude/skills/claude-codex-delegation/assets/install.sh global
```

## Prerequisite
The Codex plugin + CLI must be installed and logged in for the rules to function:
```
/plugin marketplace add openai/codex-plugin-cc
/codex:setup        # expect "ready": true
codex login status  # expect "Logged in ..."
```
The CLAUDE.md block and reminder hook can be installed even before Codex is set up.

## Key rule (do not forget)
Delegate to Codex via the **Agent tool** (`subagent_type: "codex:codex-rescue"`), or the
`codex exec` CLI, or by the user typing `/codex:rescue`. **Never** via the `Skill` tool —
`Skill(codex:rescue)` re-enters the slash command and hangs the session.
