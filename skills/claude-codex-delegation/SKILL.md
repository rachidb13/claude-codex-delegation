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

### Waiting on Codex — read this before every delegated run

**The failure this prevents:** the session appears to hang for hours. Claude delegates, gets
no completion signal, and waits for a notification that will never arrive. Earlier versions of
this skill said "don't poll, the harness re-invokes you automatically." That is true for one
path and **false for the plugin path**, which is the one this skill tells you to use first.

Know which path you are on, because they behave differently:

| Path | What returns | Harness-tracked? | How you learn it finished |
|---|---|---|---|
| **Agent tool** `codex:codex-rescue` (plugin) | **Immediately**, with a job id like `task-abc-123` | **NO** — the real work runs in a detached companion process | **You must watch it.** Nothing will wake you. |
| **Bash `codex exec`** with `run_in_background: true` | when Codex actually exits | **YES** | Harness notifies on exit |

The plugin path returning a job id is **not** completion. Reading "Codex Task started in the
background as `task-…`" and then waiting is the exact mistake — that string means the work has
barely begun.

**After every Agent-tool delegation, immediately arm the watcher** (bundled with this skill).
Run it under Bash with `run_in_background: true`, which makes the harness track *the watcher*
and notify you when the job reaches a terminal state:

```bash
bash ~/.claude/skills/claude-codex-delegation/assets/watch-codex-job.sh <job-id> 3600 20
```

Exit codes: `0` completed · `1` failed/cancelled · `2` still running at the deadline (the job
is alive — keep waiting or `cancel`) · `3` usage/environment error.

Arm it in the **same turn** you launch the job. A watcher armed three turns later is three
turns of dead session.

Then collect the actual output — status alone never contains it:

```bash
node <companion> result <job-id>     # the report; `status --json` only gives state + summary
node <companion> cancel <job-id>     # if it has stalled or you no longer need it
```

**Never write your own `pgrep`-based wait loop.** `pgrep -f "some_script.py --flag"` matches
the watcher's *own* command line, because that string appears in it — so the loop matches
itself and spins forever. This has burned real sessions. Wait on the job id, on a PID captured
at launch (`$!`), or on a sentinel line in the log — never on a pattern that could match the
waiter.

### Scenarios this must cover

- **Job never terminates.** The watcher's deadline turns an infinite hang into an exit-2 you
  can act on. Choose it from the work: minutes for a review, up to an hour for a large
  implementation. On exit 2, decide explicitly — keep waiting or cancel. Don't re-delegate on
  top of a live job; the companion refuses a second task while one is active.
- **A zombie job blocks every future delegation.** This is the nastiest one, because the
  symptom appears far from the cause. The companion allows only one active task per workspace,
  so a job whose record is stuck at `running` makes *every* later delegation fail — and the
  reason surfaces only as a terse `Task <old-id> is still running` buried in the failed job's
  `result`, not in the error you first see. Observed: a job whose process had died sat at
  `running` for 22 hours (its work had actually completed) and silently blocked all delegation
  the next day.

  **When a delegation fails instantly (0s elapsed), suspect this first:**

  ```bash
  node <companion> status --all --json     # look for status=running with a stale updatedAt
  ps -p <pid> -o pid,etime,cmd             # the pid from the job record — is it even alive?
  node <companion> cancel <stale-job-id>   # reap it, then re-delegate
  ```

  A job record claiming `running` whose pid is dead is a zombie. Cancel it. Consider a quick
  `status --all` sweep before a long delegation session, since one zombie blocks everything
  after it.

  **`Task <id> is still running` has two very different meanings — check the pid before
  reacting.** Pid alive = the job is genuinely working; wait, do not cancel. Pid dead = zombie;
  cancel and re-delegate. Cancelling a live job because you mistook it for a zombie throws away
  real work.
- **A correction sent mid-flight is silently dropped.** Sending a follow-up to an agent whose
  Codex job is still running fails with the same `still running` message, and the correction
  never reaches Codex — it does not queue. So if you spot an error in your own brief while the
  job is in flight, you have two choices: wait for the job to finish and correct the *output*
  yourself, or cancel and re-delegate with a fixed brief. Decide by how load-bearing the error
  is. A wrong factual claim you can simply overrule when reading the report is not worth
  discarding a running investigation for; a wrong *objective* is.
- **Forwarding corrupts the prompt.** The forwarder passes your prompt through a shell.
  Backticks in the text get interpreted as command substitution and silently mangle the brief
  before Codex sees it. Avoid backticks, `$(...)`, and unescaped `$` in delegation prompts —
  name code identifiers in plain words or quotes instead. If a job's summary looks truncated
  or garbled, assume the brief was corrupted and re-send a clean version rather than reasoning
  about the output it produced.
- **Job fails or is cancelled.** Exit 1. Read `result` for the reason before re-delegating,
  and fix the brief rather than resending it unchanged.
- **Status query fails transiently.** Treated as "still unknown", never as success — a broker
  hiccup must not be misread as completion.
- **Resumed session / agent type missing.** The Agent tool errors "Agent type not found". Use
  Path B (`codex exec` via Bash, `run_in_background: true`), which *is* harness-tracked and
  needs no watcher.
- **Codex reports success but wrote nothing.** Its summary is a claim, not evidence. Always
  `git status` / read the diff before believing it.
- **Codex reports success and the fix does not work.** The most expensive failure mode, and no
  tooling catches it. A correct root-cause analysis can still be followed by a fix built on a
  false assumption, with a passing test suite that never exercises the real shape. Observed:
  a diagnosis was right, the fix probed an API per-symbol and gated on "a row with zero
  value", but the API returns an *empty list* rather than a zero row — so the fix changed
  nothing while 691 tests passed.

  **Verify the load-bearing assumption yourself**, against the real system where you can. Then
  ask: *does a test exist that fails without this fix?* When a fix targets a specific observed
  incident, require the regression test to be **shown failing on the pre-fix code first**. A
  test written after a bug that passes immediately proves nothing — it may be asserting the
  same wrong assumption the fix encodes.
- **Stale brokers.** Each project keeps an `app-server-broker.mjs` alive; several may linger
  across projects. Harmless, but if Codex behaves oddly, check `pgrep -af app-server-broker`
  before assuming a code fault.

### Verifying (after every delegated run)
1. **Verify before reporting done.** Read the diff/files, run the relevant linter/tests, check
   against the spec and acceptance criteria. Codex's own summary is not verification.
2. **Report** with evidence. If Codex drifted, send a corrective follow-up brief — don't fix
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
| "Codex says it started in the background, I'll wait for the notification" | STOP — none is coming on the plugin path; arm the watcher this turn |
| "I'll `pgrep -f` for the script to see when it's done" | STOP — the pattern matches your own wait loop; spins forever |
| "Codex reported success, so it's done" | STOP — `git status` / read the diff; the summary is a claim |

## Fallback to a native Claude subagent — ONLY if BOTH fail
- The `codex:codex-rescue` Agent type is not registered (Agent tool errors "Agent type not found"), **AND**
- The Codex CLI is unavailable — `command -v codex` fails, or `codex login status` shows not logged in.

Also fall back if the user explicitly requests a Claude subagent.

---

## Quota-aware escalation — the 85% rule (HARD)

Claude Code meters usage against a rolling **5-hour session quota**. **The moment usage
reaches 85% of that quota, switch into CONSERVATION MODE** and stay there until the quota
**resets** (the next 5-hour window).

In conservation mode:

| What | Who |
|------|-----|
| Brainstorming questions / dialogue, clarifying, deciding, approving | **Claude** |
| Reviewing Codex's output, verifying against the ask, final report | **Claude** |
| **Everything else** — investigation, reading files, drafting specs/plans, tasks/analyze, implementation, tests/linters, docs | **Codex** |

- No inline Read/Grep sweeps, no inline Edit/Write, no inline drafting — **all** delegated.
- Every "is this small enough to just do inline?" judgment is resolved **in Codex's favour**
  while in conservation mode. The only inline exceptions remain ≤1-line edits to
  `CLAUDE.md` / `.claude/` config / `settings.json`.

**How Claude knows it hit 85%:** the harness surfaces session-usage / approaching-limit
warnings, and the user may state it directly. On any ≥85% signal, announce *"entering
conservation mode — delegating all work to Codex until quota reset"*, apply this rule, and
resume the normal delegation rules only after the 5-hour window resets.

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
