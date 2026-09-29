#!/usr/bin/env node
// Picks a Claude/Codex delegation mode from both quotas.
//   node quota-route.js          -> human-readable summary
//   node quota-route.js --hook   -> UserPromptSubmit hook JSON (additionalContext)
//   node quota-route.js --tap    -> statusLine command: saves Claude usage, then prints the
//                                   original statusline (~/.claude/state/statusline-inner.json)
// Claude usage: ~/.claude/state/claude-usage.json (written by --tap or by a statusline).
// Codex usage:  the newest "rate_limits" event in ~/.codex/sessions rollout logs.
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');

const HOME = os.homedir();
const NOW = Math.floor(Date.now() / 1000);
const LOW_5H = 20;      // % left in the 5-hour window below which a side is "low"
const LOW_WEEK = 15;    // % left in the weekly window below which a side is "low"
const CLAUDE_STALE = 6 * 3600;

// A window whose reset time has passed is back to 0% used.
function left(win) {
  if (!win || win.used == null) return null;
  if (win.resets_at && win.resets_at <= NOW) return 100;
  return Math.max(0, Math.round(100 - win.used));
}

function claudeUsage() {
  try {
    const s = JSON.parse(fs.readFileSync(path.join(HOME, '.claude/state/claude-usage.json'), 'utf8'));
    if (NOW - s.saved_at > CLAUDE_STALE) return null;
    const rl = s.rate_limits || {};
    const w = (x) => x && { used: x.used_percentage, resets_at: x.resets_at };
    return { five: w(rl.five_hour), week: w(rl.seven_day) };
  } catch (_) { return null; }
}

function newestRollouts(dir, n) {
  const found = [];
  const walk = (d) => {
    let entries;
    try { entries = fs.readdirSync(d, { withFileTypes: true }); } catch (_) { return; }
    for (const e of entries) {
      const p = path.join(d, e.name);
      if (e.isDirectory()) walk(p);
      else if (e.name.endsWith('.jsonl')) found.push([fs.statSync(p).mtimeMs, p]);
    }
  };
  walk(dir);
  return found.sort((a, b) => b[0] - a[0]).slice(0, n).map((x) => x[1]);
}

function codexUsage() {
  for (const file of newestRollouts(path.join(HOME, '.codex/sessions'), 8)) {
    let text;
    try { text = fs.readFileSync(file, 'utf8'); } catch (_) { continue; }
    const lines = text.split('\n');
    for (let i = lines.length - 1; i >= 0; i--) {
      if (!lines[i].includes('"rate_limits"')) continue;
      try {
        const rl = findKey(JSON.parse(lines[i]), 'rate_limits');
        if (!rl || !rl.primary) continue;
        const w = (x) => x && { used: x.used_percent, resets_at: x.resets_at };
        return { five: w(rl.primary), week: w(rl.secondary) };
      } catch (_) { /* partial line */ }
    }
  }
  return null;
}

function findKey(obj, key) {
  if (!obj || typeof obj !== 'object') return null;
  if (obj[key]) return obj[key];
  for (const v of Object.values(obj)) {
    const r = findKey(v, key);
    if (r) return r;
  }
  return null;
}

function summarize(u) {
  if (!u) return { known: false, low: false, text: 'unknown' };
  const f = left(u.five);
  const w = left(u.week);
  const low = (f != null && f < LOW_5H) || (w != null && w < LOW_WEEK);
  const reset = u.five && u.five.resets_at > NOW
    ? ' resets ' + new Date(u.five.resets_at * 1000).toTimeString().slice(0, 5)
    : '';
  return { known: true, low, text: `${f ?? '?'}% 5h left${reset}, ${w ?? '?'}% week left` };
}

function tap() {
  let raw = '';
  process.stdin.on('data', (c) => { raw += c; });
  process.stdin.on('end', () => {
    const state = path.join(HOME, '.claude', 'state');
    try {
      const d = JSON.parse(raw || '{}');
      if (d.rate_limits) {
        fs.mkdirSync(state, { recursive: true });
        fs.writeFileSync(path.join(state, 'claude-usage.json'),
          JSON.stringify({ saved_at: Math.floor(Date.now() / 1000), rate_limits: d.rate_limits }));
      }
    } catch (_) { /* never break the statusline */ }
    let inner = null;
    try { inner = JSON.parse(fs.readFileSync(path.join(state, 'statusline-inner.json'), 'utf8')).command; } catch (_) {}
    if (inner) {
      const r = require('child_process').spawnSync(inner, { shell: true, input: raw, encoding: 'utf8' });
      process.stdout.write(r.stdout || '');
    } else {
      process.stdout.write(`Claude ${summarize(claudeUsage()).text} | Codex ${summarize(codexUsage()).text}`);
    }
  });
}

if (process.argv.includes('--tap')) {
  tap();
} else {
  report();
}

function report() {
const claude = summarize(claudeUsage());
const codex = summarize(codexUsage());

let mode;
if (claude.low && codex.low) mode = 'BOTH_LOW';
else if (codex.low) mode = 'CODEX_LOW';
else if (claude.low) mode = 'CLAUDE_LOW';
else mode = 'BALANCED';

const ROUTE = {
  BALANCED: 'Codex implements (Agent codex:codex-rescue: complex → --model gpt-5.6-sol --effort medium; routine → --model gpt-5.6-terra; tiny → --model gpt-5.6-luna) and does per-task reviews on gpt-5.6-terra.',
  CODEX_LOW: 'Codex is low: implement with native Claude subagents (Agent, model sonnet for routine, opus for complex, haiku for lookups). Use Codex only for tiny jobs on --model gpt-5.6-luna.',
  CLAUDE_LOW: 'Claude is low: send implementation, investigation and per-task reviews to Codex (gpt-5.6-sol complex / gpt-5.6-terra routine). Keep Claude turns short.',
  BOTH_LOW: 'Both quotas are low: tell the user the reset times, do only small inline work, and avoid dispatching agents.',
};
const ALWAYS = 'Always Claude, never delegated: the final code review before deploy, and the deploy itself (skill deploying-to-prod). Codex never gets prod access. Skill: delegating-work.';

const line = `[DELEGATION ${mode}] Claude: ${claude.text}. Codex: ${codex.text}. ${ROUTE[mode]} ${ALWAYS}`;

if (process.argv.includes('--hook')) {
  process.stdout.write(JSON.stringify({ hookSpecificOutput: { hookEventName: 'UserPromptSubmit', additionalContext: line } }));
} else {
  process.stdout.write(line + '\n');
}
}
