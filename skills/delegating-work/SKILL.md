---
name: delegating-work
description: Use when deciding who does a piece of work (Claude main session, a Claude subagent, or Codex), which model to use, before dispatching any implementer, reviewer or investigation agent, when waiting on a Codex job, or when Claude or Codex usage is running low.
---

# Delegating work

## Overview
Route each job by **quota first, then difficulty**. Every prompt's hook line `[DELEGATION <MODE>]` comes from `~/.claude/bin/quota-route.js`, which reads both live quotas: Claude's from the statusline snapshot, Codex's from its session logs. Follow that mode. For a fresh reading, run `node ~/.claude/bin/quota-route.js`.

## Modes
| Mode | When | Implementation and per-task review | Investigation, spec/plan drafting |
|---|---|---|---|
| BALANCED | both sides above the thresholds | Codex | Codex |
| CODEX_LOW | Codex has <20% of its 5h window left, or <15% of its week | Claude subagents | Claude subagent or inline |
| CLAUDE_LOW | Claude is below the same thresholds | Codex, including reviews | Codex |
| BOTH_LOW | both low | small inline work only; tell the user the reset times | — |

**Always Claude, in every mode:** the final code review of a finished branch or fix, and the deploy. Codex never gets production access. Brainstorming dialogue and orchestration stay with Claude too.

## Models
| Job | Codex (`Agent`, subagent_type `codex:codex-rescue`) | Claude subagent (`Agent` `model`) |
|---|---|---|
| Complex implementation, multi-file, design judgment | `--model gpt-5.6-sol --effort medium` (installer sets this as the default) | `opus` |
| Routine implementation, per-task review, spec analysis | `--model gpt-5.6-terra` | `sonnet` |
| Tiny edits, lookups, one-file investigations | `--model gpt-5.6-luna` | `haiku` |

gpt-5.5 retires on 2026-10-14. Never pass it. If Codex's model list changes, check `~/.codex/models_cache.json` (the `upgrade` field names the successor).

## Dispatching Codex
1. **Agent tool**, `subagent_type: "codex:codex-rescue"`, with the model flags in the prompt. **Never the Skill tool**: `Skill(codex:rescue)` re-enters the slash command and hangs the session.
2. If the agent type is not registered in this session ("Agent type not found"), run the companion under Bash with `run_in_background: true`:
   `node ~/.claude/plugins/cache/openai-codex/codex/<ver>/scripts/codex-companion.mjs task --write --model gpt-5.6-sol --effort medium --prompt-file <prompt.txt>`
3. Or ask the user to type `/codex:rescue <request>`.

For direct `codex exec`, always append `< /dev/null`, or it waits on stdin forever.

## Waiting on a Codex job
| Path | Returns | How you learn it finished |
|---|---|---|
| Agent tool when it reports back directly | the final report | you are notified |
| Agent tool or companion that returns a job id (`task-…`) | immediately; the work runs detached | **nothing wakes you**: arm the watcher |
| `codex exec` with `run_in_background: true` | when Codex exits | the harness notifies you |

"Codex Task started in the background as `task-…`" means the work has barely begun. In the same turn, run under Bash with `run_in_background: true`:
`bash ~/.claude/skills/delegating-work/assets/watch-codex-job.sh <job-id> 3600 20`
Exit codes: 0 completed, 1 failed or cancelled, 2 still running at the deadline, 3 usage error. Then collect the output with `node <companion> result <job-id>`. Never write a `pgrep -f` wait loop: it matches its own command line and spins forever.

## Briefing and verifying
- Hand agents file paths (brief, report, diff package), not pasted content.
- Codex's sandbox usually can't write `.git`. Tell it "leave changes uncommitted". Claude checks `git status` (only the brief's files changed), re-runs the tests, and commits.
- Codex turns CRLF into LF: compare with `git diff --stat --ignore-cr-at-eol` and restore CRLF before committing.
- Codex's own summary is not verification. Read the diff and run the tests before reporting done.
- Small edits (under ~20 lines, 1-2 files) may be done inline by Claude in any mode except CLAUDE_LOW.
- When the user names who does a job ("fix it yourself"), that overrides the mode.

## Common mistakes
| Mistake | Fix |
|---|---|
| Routing to Codex out of habit while it is low | Read the hook line and follow the mode. |
| Delegating the final review or the deploy | Those are always Claude's. |
| opus or gpt-5.6-sol for mechanical work | Use sonnet or terra. They are cheaper and usually faster. |
| Hook line says "Claude: unknown" | The statusline isn't saving usage. Re-run the installer. |
| Hard-coding model names in CLAUDE.md files | Point to this skill instead. |
