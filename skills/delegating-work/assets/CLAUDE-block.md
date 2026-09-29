<!-- BEGIN claude-codex-delegation -->
# Delegation between Claude and Codex (quota-aware)

Who does delegated work (implementation, per-task reviews, investigation, spec/plan drafting, `speckit.tasks`/`speckit.analyze`) depends on **both live quotas**, not a fixed rule. Every prompt carries a `[DELEGATION <MODE>]` line from `~/.claude/bin/quota-route.js`. Follow it, and use the `delegating-work` skill for modes, models and how to dispatch Codex. Claude always orchestrates.

**Always Claude, never delegated:**
- The final code review of a finished branch or fix, before any deploy.
- The deploy itself. Claude offers it once its own review is clean and runs it only after the user approves. Codex never gets production access.

Model names live only in the `delegating-work` skill.
<!-- END claude-codex-delegation -->
