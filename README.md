# claude-codex-delegation

Two [Claude Code](https://claude.com/claude-code) **skills** that split implementation
work between Claude and [Codex](https://github.com/openai/codex): Claude orchestrates,
reasons, and does lightweight edits — Codex does the heavy code writing. This keeps
Claude token usage low and puts real implementation work on your Codex/ChatGPT subscription.

## The skills

| Skill | Use it when |
|-------|-------------|
| **`codex-daily-delegation`** | Deciding *who* does any piece of work. Simple (1–5 lines, one file) → Claude. Complex (multi-step, multi-file, new feature, refactor, review, investigation) → Codex. |
| **`hybrid-claude-codex-delegation`** | Starting any implementation task. Defines the full three-agent roster (Claude main, Claude superpowers subagents, Codex) and the mandatory delegate → verify → report workflow. |

Both are auto-discovered by Claude Code once installed under `~/.claude/skills/`, and
surface in the `Skill` tool. They reference `codex:rescue` (plugin) and the `codex exec`
CLI generically — no machine-specific paths.

## Requirements

For the skills to actually delegate, the target machine needs **one** of:
- the **Codex CLI** installed and logged in (`codex login status` → "Logged in …"), **or**
- the **`openai/codex-plugin-cc`** plugin installed in Claude Code (`/codex:setup` → `ready: true`).

Without Codex, the skills still load — Claude just falls back to doing the work itself.

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

## Make them fire automatically (optional)

Skills are invoked by the model when relevant. To *force* the delegation rule on every
turn, add this to your project `CLAUDE.md` (or global `~/.claude/CLAUDE.md`):

```markdown
At the start of any implementation task, invoke the `hybrid-claude-codex-delegation` skill.
For any code file change (PHP/JS/CSS/SQL/HTML): read+plan inline, then delegate to
codex:rescue --model gpt-5.5 --effort medium. Do NOT use Edit/Write on code files directly.
```

You can also wire a `UserPromptSubmit` hook in `settings.json` that injects a one-line
reminder each prompt — see the Claude Code docs on hooks.

## Manual install

Copy the two folders under `skills/` into `~/.claude/skills/` yourself:

```
~/.claude/skills/codex-daily-delegation/SKILL.md
~/.claude/skills/hybrid-claude-codex-delegation/SKILL.md
```
