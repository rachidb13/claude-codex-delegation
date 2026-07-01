<!-- BEGIN claude-codex-delegation -->

## Codex delegation (MANDATORY when plugin present)

When the `openai/codex-plugin-cc` plugin is installed and authenticated (verify with
`/codex:setup` → expect `"ready": true` + active login), the token-heavy work goes to
Codex instead of staying on Claude — to use the user's Codex/ChatGPT subscription and keep
Claude token usage low. For the full decision logic, invoke the
`claude-codex-delegation` skill.

### How to invoke Codex (CORRECT vs WRONG)

Three distinct things — do NOT confuse them:
- `/codex:rescue` — a **slash command** (human entry point); the user can type it.
- `codex:codex-rescue` — a **subagent**; Claude launches it via the **Agent tool**
  (`subagent_type: "codex:codex-rescue"`).
- `Skill(codex:rescue)` / `Skill(codex:codex-rescue)` — **WRONG, never call.** No such
  skill; `Skill(codex:rescue)` re-enters the slash command and HANGS the session.

**Never delegate to Codex via the Skill tool.** Claude delegates by, in order:
1. **Agent tool** — `subagent_type: "codex:codex-rescue"` (+ model/effort flags).
2. If that agent type is **not registered this session** (resumed sessions / some CLI builds
   error "Agent type not found"), run the companion in the **background** via the Bash tool
   with `run_in_background: true` (wakes Claude on completion — no babysitting):
   ```
   CLAUDE_PLUGIN_ROOT=~/.claude/plugins/cache/openai-codex/codex/<ver> \
   node "$CLAUDE_PLUGIN_ROOT/scripts/codex-companion.mjs" task --write \
     --model gpt-5.5 --effort medium --prompt-file <prompt.txt>
   ```
   (`--write` enables file edits; verify `setup --json` → `ready:true` first.)
3. Or ask the user to type `/codex:rescue <request>`.

### What to delegate (rebalancing — fixes the 80/10 problem)

Implementation is the *smallest* slice of token spend. Delegating only code-writing leaves
Claude at ~80–90% and Codex at ~10%. The token-heavy work — reading the codebase, drafting
specs/plans, review — MUST also go to Codex:

1. **Codebase investigation / reading >2 files.** Do NOT Read/Grep many files inline.
   Send Codex: "Read X/Y/Z, trace feature F, return a digest + exact functions/lines to
   change." Claude orchestrates from the digest. (A quick ≤2-file peek inline is fine.)
2. **Spec & plan drafting.** Codex drafts the spec/plan (speckit.specify / speckit.plan);
   Claude reviews, tweaks, approves. Brainstorming *dialogue* stays on Claude.
3. **`speckit.tasks` + `speckit.analyze`** — always via Codex, never inline.
4. **Review & verification** — code-review passes, linters/tests, acceptance checks.

**Stays on Claude:** brainstorming dialogue, sequencing/orchestration, applying the user's
approved decisions, the final report. Claude conducts; Codex does the heavy lifting.

### Model routing
Implementation / code-writing → `--model gpt-5.5 --effort medium`.
Everything else (investigation, drafting, tasks/analyze, review) → default model (omit `--model`).

### No inline implementation (enforced)
Claude MUST NOT use Edit or Write on code files directly. For ANY implementation request:
1. (If needed) Codex investigates and returns a digest — don't Read/Grep many files inline.
2. Claude plans / sequences in the conversation.
3. Claude delegates via the **Agent tool** (`subagent_type: "codex:codex-rescue"`),
   NOT the Skill tool, forwarding `--model gpt-5.5 --effort medium`; background companion
   fallback if the agent type isn't registered.
4. Claude verifies and reports.

**The ONLY files Claude may Edit/Write directly:** `CLAUDE.md` files, `.claude/` config
files, `settings.json` / `settings.local.json`, and a single one-line typo fix the user
explicitly confirmed as "not worth delegating". Everything else — PHP, JS, SQL, CSS,
HTML — goes to Codex.

Fall back to a native Claude subagent only if Codex is unavailable/unauthenticated or the
user explicitly asks for a Claude subagent.

### Quota-aware escalation — the 85% rule (HARD)

Claude Code meters usage against a rolling **5-hour session quota**. **Once usage reaches
85% of that quota, enter CONSERVATION MODE** and stay in it until the quota **resets**
(the next 5-hour window):

- **Delegate EVERYTHING to Codex** — not just code. Investigation, reading files, drafting
  specs/plans, tasks/analyze, implementation, running tests/linters, writing docs — **all
  of it** goes to Codex via the Agent tool / CLI companion. No inline Read/Grep sweeps, no
  inline Edit/Write, no inline drafting.
- **Claude keeps ONLY two things:**
  1. **Brainstorming questions / dialogue** with the user (clarifying, deciding, approving).
  2. **Review** — reading back Codex's output and reporting/verifying against the ask.
- Everything else that would normally be a judgment call ("small enough to do inline?")
  is resolved **in Codex's favour** while in conservation mode — there are no inline
  exceptions except the ≤1-line config/CLAUDE.md/settings.json edits.

**How Claude knows it hit 85%:** the harness surfaces session-usage / approaching-limit
warnings, and the user may say so. On seeing an ≥85% signal (or if the user states it),
announce "entering conservation mode — delegating all work to Codex until quota reset" and
apply the rule until reset. When the window resets, resume normal delegation rules above.

<!-- END claude-codex-delegation -->
