# claude-codex-delegation

[Claude Code](https://claude.com/claude-code) **skills** that split work between Claude and
[Codex](https://github.com/openai/codex): **Claude conducts; Codex does the heavy lifting** —
not just code writing, but also codebase investigation, spec/plan drafting, and review. This
keeps Claude token usage low and puts the expensive work on your Codex/ChatGPT subscription.

> **The 80/10 problem these solve:** implementation is the *smallest* slice of token spend.
> Reading the codebase, drafting specs/plans, and review are what burn Claude's limit.
> Delegating only code-writing leaves Claude at ~80–90% and Codex at ~10% — so these skills
> push investigation, drafting, and review to Codex too.

> **The 85% rule:** once Claude's rolling **5-hour session quota** hits **85%**, the skills
> flip into **conservation mode** — *every* task (investigation, drafting, implementation,
> tests, docs) is delegated to Codex, and Claude keeps only brainstorming questions and
> review, until the quota resets.

## The skills

| Skill | Use it when |
|-------|-------------|
| **`claude-codex-delegation`** | The complete, **self-installing** delegation system. Contains all the rules *and* an installer that wires the delegation block into `CLAUDE.md` and a reminder hook into `settings.json`. Say "install the claude-codex-delegation skill". |
| **`codex-daily-delegation`** | Deciding *who* does any piece of work. Simple (1–5 lines, one file) → Claude. Complex (multi-step, multi-file, new feature, refactor, review, investigation) → Codex. |
| **`hybrid-claude-codex-delegation`** | Starting any implementation task. Defines the full three-agent roster (Claude main, Claude superpowers subagents, Codex) and the mandatory delegate → verify → report workflow. |

All are auto-discovered by Claude Code once installed under `~/.claude/skills/`, and surface
in the `Skill` tool. No machine-specific paths.

> ⚠️ **Invocation:** delegate to Codex via the **Agent tool**
> (`subagent_type: "codex:codex-rescue"`), the `codex exec` CLI, or the `/codex:rescue` slash
> command. **Never** via the `Skill` tool — `Skill(codex:rescue)` re-enters the slash command
> and hangs the session.

## Requirements

**Required:** the **`codex@openai-codex`** plugin must be installed in Claude Code for these
skills to delegate. It provides the `codex:codex-rescue` subagent and the `/codex:setup`,
`/codex:rescue` commands the skills drive.

1. Add the marketplace and install the plugin:
   ```
   /plugin marketplace add openai/codex-plugin-cc
   /plugin install codex@openai-codex
   ```
2. Log in / verify it's ready: `/codex:setup` → expect `"ready": true`.

Verify it's present: `codex@openai-codex` should appear in
`~/.claude/plugins/installed_plugins.json`.

The plugin in turn needs the **Codex CLI** installed and logged in
(`codex login status` → "Logged in …") for delegation to actually run.

Without the `codex@openai-codex` plugin (and Codex), the skills still load — but Claude has
nothing to delegate to and falls back to doing the work itself, defeating the purpose.

## Install

**Windows (PowerShell)** — copy & paste all three lines:
```powershell
git clone https://github.com/rachidb13/claude-codex-delegation.git
cd claude-codex-delegation
powershell -ExecutionPolicy Bypass -File install.ps1
```

**macOS / Linux** — copy & paste all three lines:
```bash
git clone https://github.com/rachidb13/claude-codex-delegation.git
cd claude-codex-delegation
chmod +x install.sh && ./install.sh
```

The installer copies each skill folder into `~/.claude/skills/` (backing up any existing
folder of the same name). Restart Claude Code (or `/reload`) so it picks them up.

## Make them fire automatically (recommended)

After running `install.ps1` / `install.sh` (which copies the skill folders), tell Claude:

> **"install the claude-codex-delegation skill"**

That skill's own installer (`skills/claude-codex-delegation/assets/install.ps1` / `.sh`) then:
- appends a delegation block to your `CLAUDE.md` (global and/or project — it asks), and
- merges a `UserPromptSubmit` reminder hook into `settings.json`

so the delegation rule is enforced on every turn. It's **idempotent** (BEGIN/END markers +
a hook keyed on `[CODEX DELEGATION ACTIVE]`) and writes UTF-8 **without BOM** so
`settings.json` stays valid. Restart Claude Code afterwards.

To do it by hand instead, copy the block from
`skills/claude-codex-delegation/assets/CLAUDE-block.md` into your `CLAUDE.md`, and the hook
from `assets/settings-hook.json` into `settings.json`.

## Manual install

Copy the three folders under `skills/` into `~/.claude/skills/` yourself:

```
~/.claude/skills/claude-codex-delegation/        (SKILL.md + README.md + assets/)
~/.claude/skills/codex-daily-delegation/SKILL.md
~/.claude/skills/hybrid-claude-codex-delegation/SKILL.md
```
