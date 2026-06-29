---
name: claude-codex-delegation
description: Use when starting any task and deciding who does the work (Claude vs Codex), when tempted to Edit/Write a code file directly, or when asked to "install the claude-codex-delegation skill" on a machine. Portable, self-installing delegation system — Claude conducts, Codex does the heavy lifting (implementation + investigation + spec/plan drafting + review). Includes an installer that wires up CLAUDE.md and the settings.json reminder hook.
---

# Claude–Codex Delegation (portable, self-installing)

Claude **conducts**; Codex **does the heavy lifting**. This keeps Claude token usage low
and uses the user's Codex/ChatGPT subscription for the expensive work.

> **The 80/10 problem this solves:** implementation is the *smallest* slice of token spend.
> Reading the codebase, drafting specs/plans, and review are what burn Claude's limit.
> Delegating only code-writing leaves Claude at ~80–90% and Codex at ~10%. The fix is to
> delegate **investigation, spec/plan drafting, and review to Codex too** — not just code.

---

## TWO MODES

This skill does two things. Pick by what the user asked:

- **Install mode** — user said something like "install the claude-codex-delegation skill",
  "set up codex delegation on this machine". → Go to **§ Installation** at the bottom.
- **Delegation mode** — any normal task. → Use everything above § Installation.

---

## Agent Roster

| Agent | Tool to invoke | Handles |
|-------|---------------|---------|
| Claude (main) | — inline — | **Orchestration only:** brainstorming dialogue, sequencing, approving, reporting, config files, ≤2-file quick peeks |
| Claude superpowers subagents | `Skill` tool | Process disciplines: brainstorming, planning, verification, debugging (only if the superpowers plugin is installed) |
| Codex implementer | **Agent tool** (`subagent_type: "codex:codex-rescue"`) **or** `codex exec` CLI — `gpt-5.5`, medium effort | All PHP / JS / CSS / SQL / HTML writes |
| Codex investigator / reviewer / drafter | **Agent tool** (`subagent_type: "codex:codex-rescue"`) **or** `codex exec` CLI — default model | Codebase investigation (>2 files), spec/plan drafting, speckit.tasks/analyze, code review, rescue/diagnosis |

### ⚠️ How to invoke Codex (CORRECT vs WRONG)

Three distinct things — do **NOT** confuse them:
- `/codex:rescue` — a **slash command** (human entry point); the user can type it.
- `codex:codex-rescue` — a **subagent**; Claude launches it via the **Agent tool**
  (`subagent_type: "codex:codex-rescue"`).
- `Skill(codex:rescue)` / `Skill(codex:codex-rescue)` — **WRONG, never call.** No such skill;
  `Skill(codex:rescue)` re-enters the slash command and **HANGS the session**.

**Never delegate to Codex via the `Skill` tool.** Delegate by, in order:

1. **Agent tool** — `subagent_type: "codex:codex-rescue"` (+ model/effort flags).
2. If that agent type is **not registered this session** (resumed sessions / some CLI builds
   error "Agent type not found"), run the **CLI via Bash** (Path B below), preferably in the
   **background** (`run_in_background: true`) — the harness auto-wakes Claude when it exits.
3. Or ask the user to type `/codex:rescue <request>`.

**Path B — Codex CLI via Bash** (when the Agent type isn't found this session):
```
command -v codex && codex login status        # expect "Logged in ..."
codex exec -m gpt-5.5 -c model_reasoning_effort="medium" \
  --sandbox workspace-write --dangerously-bypass-approvals-and-sandbox \
  - < /path/to/brief.md
```
- Model routing → CLI flags: `--model gpt-5.5 --effort medium` → `-m gpt-5.5 -c model_reasoning_effort="medium"`.
  Review/investigation runs omit `-m` (CLI default model).
- `--sandbox workspace-write` to edit files; `read-only` for review/investigation.
- A missing Agent type / plugin skill **alone is not** a reason to fall back to a Claude
  subagent — try Path B first.

---

## What goes to Codex

**Always delegate** any write to: `.php`, `.js`, `.css`, `.sql`, `.html` (and other code).

**Also delegate (the rebalancing wins — do NOT do these inline):**

1. **Codebase investigation / reading >2 files.** Instead of Claude running Read/Grep/Glob
   across many files, send Codex: *"Read files X/Y/Z, trace how feature F works, return a
   digest + the exact functions/lines to change."* Claude orchestrates from the digest.
   A quick **≤2-file peek inline is fine**.
2. **Spec & plan *drafting*.** Codex drafts `spec.md` / `plan.md` (e.g. speckit.specify /
   speckit.plan / writing-plans); Claude reviews, tweaks, approves. Brainstorming *dialogue*
   with the user stays on Claude.
3. **`speckit.tasks` + `speckit.analyze`** — always via Codex, never inline.
4. **Review & verification** — code-review passes, running linters/tests, checking output
   against acceptance criteria.

**Stays on Claude:** brainstorming dialogue, sequencing/orchestration, applying the user's
approved decisions, the final report.

### Model routing
```
Implementation / code writing → --model gpt-5.5 --effort medium
Everything else (investigate, draft, tasks/analyze, review) → default model (omit --model)
```

---

## Full workflow for an implementation task

```
1. Codex:  investigate — read the relevant files, trace the feature, return a digest
           (Agent tool subagent_type "codex:codex-rescue", default model)
           [skip to 2 only if ≤2 files — quick inline peek allowed]
2. Claude: brainstorm with the user (if new feature) — dialogue stays on Claude
3. Codex:  draft spec/plan from the digest (specify / plan / writing-plans)
4. Claude: review the draft, tweak, describe to the user, get approval
5. Codex:  speckit.tasks + speckit.analyze (Agent tool, default model)
6. Codex:  implement — Agent tool "codex:codex-rescue" --model gpt-5.5 --effort medium
7. Claude: verify (orchestrate the check; run/inspect)
8. Codex:  code review pass (if pre-merge) — Agent tool, default model
9. Claude: report to user
```

Claude's job is to **sequence, decide, approve, report** — not to read files or write
artifacts itself. The token-heavy reading/drafting/reviewing lives in Codex.

### Waiting & verifying (after every delegated run)
1. **Don't poll.** A background `codex exec` / background Agent is harness-tracked; Claude
   is re-invoked automatically when it finishes. Don't burn turns with sleep/timeout loops.
2. **Verify before reporting done.** Read the diff/files, run `php -l` (or the relevant
   linter), check against the spec/acceptance criteria.
3. **Report** with evidence. If Codex drifted, send a corrective follow-up brief — don't fix
   inline.

---

## Files Claude may write directly (no Codex)
- `CLAUDE.md` and any `.claude/` config files
- `settings.json` / `settings.local.json`
- A single one-line typo fix explicitly confirmed by the user as "not worth delegating"

Everything else — PHP, JS, SQL, CSS, HTML — goes to Codex.

## Red flags — STOP and delegate

| Thought | Action |
|---------|--------|
| "I'll just Edit this .php file quickly" | STOP — delegate to Codex |
| "It's a one-liner, not worth a Codex call" | STOP — delegate anyway |
| "Let me spawn a Claude Agent to implement this" | STOP — Agent tool `codex:codex-rescue` |
| "I'll just Read/Grep these 10 files to understand it" | STOP — delegate investigation; get a digest |
| "I'll draft the spec/plan myself, it's faster" | STOP — Codex drafts, Claude reviews |
| "I'll run speckit.tasks/analyze inline" | STOP — delegate to Codex |
| "I'll call codex:rescue via the Skill tool" | STOP — that HANGS; use the Agent tool |

## Fallback to a native Claude subagent — ONLY if BOTH fail
- The `codex:codex-rescue` Agent type is not registered (Agent tool errors "Agent type not found"), **AND**
- The Codex CLI is unavailable — `command -v codex` fails, or `codex login status` shows not logged in.

Also fall back if the user explicitly requests a Claude subagent.

---

## Installation

Trigger: the user asks to **install / set up** this delegation system on a machine.

This wires up two things so delegation is enforced automatically every session:
1. A **delegation block** appended to a `CLAUDE.md` (global `~/.claude/CLAUDE.md` and/or the
   project's `./CLAUDE.md`).
2. A **UserPromptSubmit reminder hook** in `settings.json` that injects the delegation
   reminder on every message.

### Steps for Claude to run

1. **Confirm Codex is available** (so the rules actually work):
   ```
   codex --version            # CLI present?
   codex login status         # expect "Logged in ..."
   ```
   Also confirm the plugin is installed (look for `codex@openai-codex` in
   `~/.claude/plugins/installed_plugins.json`). If the plugin/CLI is missing, tell the user
   to install it (`/plugin marketplace add openai/codex-plugin-cc`, then `/codex:setup`)
   before the rules will function — but the CLAUDE.md/hook can still be installed.

2. **Ask the user the install scope** (use AskUserQuestion): global `~/.claude/CLAUDE.md`
   (applies everywhere) or this project's `./CLAUDE.md` (this repo only), or both.

3. **Run the installer** (idempotent — safe to re-run; it uses BEGIN/END markers and skips
   if already present). Use the script for the OS:
   - Windows / PowerShell: `assets/install.ps1` in this skill folder
     ```
     powershell -ExecutionPolicy Bypass -File "<skill>/assets/install.ps1" -Scope global
     ```
     (Scope: `global`, `project`, or `both`.)
   - macOS / Linux / Git-Bash: `assets/install.sh`
     ```
     bash "<skill>/assets/install.sh" global
     ```
   `<skill>` = this skill's folder (`CLAUDE_PLUGIN_ROOT` or `~/.claude/skills/claude-codex-delegation`).

   If a script can't run, do the edits manually instead:
   - Append the contents of `assets/CLAUDE-block.md` (verbatim, including the
     `<!-- BEGIN/END claude-codex-delegation -->` markers) to the chosen `CLAUDE.md`,
     only if those markers aren't already present.
   - Merge the `UserPromptSubmit` hook from `assets/settings-hook.json` into
     `~/.claude/settings.json` (or project `.claude/settings.json`) without dropping existing
     hooks. On non-Windows, change the hook `shell` to `bash` and the `command` to the
     `echo`/`printf` JSON form noted inside that file.

4. **Verify & report:** show that the CLAUDE.md block and the hook are present, and that
   `codex login status` is logged in. Tell the user to **restart the session** so the new
   hook + CLAUDE.md load.

### Getting this skill onto a brand-new machine
The skill folder must exist before Claude can be told to "install" it. Easiest options:
- Copy `~/.claude/skills/claude-codex-delegation/` to the new machine's `~/.claude/skills/`.
- Or keep it in a git repo / dotfiles and clone it into `~/.claude/skills/`.
Once the folder is in `~/.claude/skills/`, restart Claude and say
"install the claude-codex-delegation skill".
