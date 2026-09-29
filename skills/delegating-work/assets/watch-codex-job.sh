#!/usr/bin/env bash
# Watch a Codex companion job until it reaches a terminal state, then exit.
#
# Why this exists: the plugin's `task` command starts Codex in a DETACHED companion
# process and returns a job id immediately. The Claude Code harness does not track that
# process, so nothing ever wakes Claude when Codex finishes. Run this under Bash with
# run_in_background:true and the harness WILL notify on exit, because it tracks *this*
# script.
#
# Usage:
#   watch-codex-job.sh <job-id> [max-seconds] [poll-seconds]
#
# Exit codes:
#   0  job reached a terminal state successfully (status "completed")
#   1  job reached a terminal state unsuccessfully (failed / cancelled / anything else)
#   2  timed out while still queued or running  -- job is NOT dead, decide whether to keep
#      waiting or run `codex-companion.mjs cancel <job-id>`
#   3  usage / environment error
#
# The active-state test mirrors the companion's own isActive(): a job is finished when its
# status is neither "queued" nor "running". Testing for the absence of activity rather than
# for a known list of success values means new terminal states cannot cause a silent hang.

set -uo pipefail

JOB_ID="${1:-}"
MAX_SECONDS="${2:-3600}"
POLL_SECONDS="${3:-20}"

if [[ -z "$JOB_ID" ]]; then
  echo "usage: watch-codex-job.sh <job-id> [max-seconds] [poll-seconds]" >&2
  exit 3
fi

COMPANION="${CODEX_COMPANION_PATH:-}"
if [[ -z "$COMPANION" ]]; then
  COMPANION="$(ls -d "$HOME"/.claude/plugins/cache/openai-codex/codex/*/scripts/codex-companion.mjs 2>/dev/null | sort -V | tail -1)"
fi
if [[ ! -f "$COMPANION" ]]; then
  echo "codex-companion.mjs not found; set CODEX_COMPANION_PATH" >&2
  exit 3
fi

deadline=$(( SECONDS + MAX_SECONDS ))

while true; do
  raw="$(node "$COMPANION" status "$JOB_ID" --json 2>/dev/null || true)"

  # Tab-delimited: elapsed ("9m 47s") and summary both contain spaces, so splitting on
  # whitespace would shift the fields.
  IFS=$'\t' read -r status phase elapsed summary <<<"$(
    python3 - "$raw" <<'PY' 2>/dev/null || printf 'unknown\tunknown\t?\t-'
import json, sys
try:
    job = (json.loads(sys.argv[1]) or {}).get("job") or {}
except Exception:
    job = {}
summary = (job.get("summary") or "-").replace("\n", " ").replace("\t", " ")[:160] or "-"
print("\t".join([
    str(job.get("status", "unknown")),
    str(job.get("phase", "unknown")),
    str(job.get("elapsed", job.get("duration", "?"))),
    summary,
]))
PY
  )"

  # A transient status query failure must not be read as completion.
  if [[ "$status" == "unknown" ]]; then
    if (( SECONDS >= deadline )); then
      echo "TIMEOUT after ${MAX_SECONDS}s: job $JOB_ID status unreadable"
      exit 2
    fi
    sleep "$POLL_SECONDS"
    continue
  fi

  if [[ "$status" != "queued" && "$status" != "running" ]]; then
    echo "CODEX $JOB_ID -> $status (phase=$phase, elapsed=$elapsed)"
    echo "summary: $summary"
    [[ "$status" == "completed" ]] && exit 0
    exit 1
  fi

  if (( SECONDS >= deadline )); then
    echo "TIMEOUT after ${MAX_SECONDS}s: job $JOB_ID still $status (phase=$phase, elapsed=$elapsed)"
    echo "Job is still alive. Keep waiting, or cancel with: node \"$COMPANION\" cancel $JOB_ID"
    exit 2
  fi

  sleep "$POLL_SECONDS"
done
