#!/usr/bin/env node
// Installs quota-aware Claude/Codex delegation on this machine (Windows, macOS, Linux).
//   node install.js            install or upgrade (idempotent, backs up everything it changes)
//   node install.js --dry-run  show what would change
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');

const DRY = process.argv.includes('--dry-run');
const HOME = os.homedir();
const CLAUDE = path.join(HOME, '.claude');
const REPO = __dirname;
const SKILL_SRC = path.join(REPO, 'skills', 'delegating-work');
const STAMP = new Date().toISOString().replace(/[-:T]/g, '').slice(0, 14);
const IS_WIN = process.platform === 'win32';
const OLD_SKILLS = ['claude-codex-delegation', 'codex-daily-delegation', 'hybrid-claude-codex-delegation'];
const CODEX_MODEL = 'gpt-5.6-sol';
const RETIRED_MODELS = ['gpt-5.5', 'gpt-5.4'];
const BEGIN = '<!-- BEGIN claude-codex-delegation -->';
const END = '<!-- END claude-codex-delegation -->';

const say = (tag, msg) => console.log(`  [${tag}] ${msg}`);
const fwd = (p) => p.split(path.sep).join('/');

function write(file, text) {
  if (DRY) return;
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, text);
}

function backup(file) {
  if (!DRY && fs.existsSync(file)) fs.copyFileSync(file, `${file}.bak-${STAMP}`);
}

function copyDir(src, dst) {
  if (DRY) return;
  fs.mkdirSync(dst, { recursive: true });
  for (const e of fs.readdirSync(src, { withFileTypes: true })) {
    const s = path.join(src, e.name);
    const d = path.join(dst, e.name);
    if (e.isDirectory()) copyDir(s, d);
    else fs.copyFileSync(s, d);
  }
}

// 1. Skill, plus archiving the superseded skills so they stop triggering.
function installSkill() {
  const skills = path.join(CLAUDE, 'skills');
  const dst = path.join(skills, 'delegating-work');
  if (fs.existsSync(dst) && !DRY) {
    fs.mkdirSync(path.join(CLAUDE, 'skill-backups'), { recursive: true });
    fs.renameSync(dst, path.join(CLAUDE, 'skill-backups', `delegating-work-${STAMP}`));
  }
  copyDir(SKILL_SRC, dst);
  say('ok', `skill delegating-work -> ${dst}`);

  if (!fs.existsSync(skills)) return;
  const archive = path.join(CLAUDE, 'skill-backups', `delegation-${STAMP}`);
  for (const name of fs.readdirSync(skills)) {
    if (!OLD_SKILLS.some((o) => name === o || name.startsWith(`${o}.bak`))) continue;
    if (!DRY) {
      fs.mkdirSync(archive, { recursive: true });
      fs.renameSync(path.join(skills, name), path.join(archive, name));
    }
    say('ok', `archived old skill ${name} -> ${archive}`);
  }
}

// 2. quota-route.js into ~/.claude/bin.
function installRouter() {
  const dst = path.join(CLAUDE, 'bin', 'quota-route.js');
  if (!DRY) {
    fs.mkdirSync(path.dirname(dst), { recursive: true });
    fs.copyFileSync(path.join(SKILL_SRC, 'assets', 'quota-route.js'), dst);
  }
  say('ok', `router -> ${dst}`);
  return dst;
}

// 3. settings.json: live hook instead of the static reminder, and a statusline tap.
function patchSettings(router) {
  const file = path.join(CLAUDE, 'settings.json');
  let s = {};
  if (fs.existsSync(file)) {
    try { s = JSON.parse(fs.readFileSync(file, 'utf8').replace(/^﻿/, '')); } catch (e) {
      say('FAIL', `${file} is not valid JSON, leaving it alone: ${e.message}`);
      return;
    }
  }
  const routerCmd = `node "${fwd(router)}"`;

  s.hooks = s.hooks || {};
  const kept = (s.hooks.UserPromptSubmit || []).filter((entry) => !(entry.hooks || []).some((h) =>
    typeof h.command === 'string' && (h.command.includes('[CODEX DELEGATION ACTIVE]') || h.command.includes('quota-route'))));
  kept.push({ hooks: [{
    type: 'command',
    command: `${routerCmd} --hook`,
    shell: IS_WIN ? 'powershell' : 'bash',
    timeout: 10,
    statusMessage: 'Checking Claude/Codex quota...',
  }] });
  s.hooks.UserPromptSubmit = kept;
  say('ok', 'UserPromptSubmit hook -> quota-route --hook (old static reminder removed)');

  // Claude's usage only reaches the statusline, so the statusline must save it.
  const current = s.statusLine && s.statusLine.command;
  if (current && current.includes('quota-route')) {
    say('skip', 'statusline already tapped');
  } else if (current && statuslineSavesUsage(current)) {
    say('skip', 'statusline already saves claude-usage.json');
  } else {
    if (current) {
      write(path.join(CLAUDE, 'state', 'statusline-inner.json'), JSON.stringify({ command: current }, null, 2));
      say('ok', `statusline wrapped; original kept in state/statusline-inner.json`);
    } else {
      say('ok', 'statusline added (shows both quotas)');
    }
    s.statusLine = { type: 'command', command: `${routerCmd} --tap` };
  }

  backup(file);
  write(file, JSON.stringify(s, null, 2) + '\n');
}

function statuslineSavesUsage(cmd) {
  for (const token of cmd.match(/"[^"]+"|\S+/g) || []) {
    const p = token.replace(/^"|"$/g, '').replace(/^~/, HOME);
    try {
      if (fs.statSync(p).isFile() && fs.readFileSync(p, 'utf8').includes('claude-usage.json')) return true;
    } catch (_) { /* not a file */ }
  }
  return false;
}

// 4. CLAUDE.md: replace the marked block (older installs appended an "always Codex" block).
function patchClaudeMd() {
  const file = path.join(CLAUDE, 'CLAUDE.md');
  const block = fs.readFileSync(path.join(SKILL_SRC, 'assets', 'CLAUDE-block.md'), 'utf8').trim();
  let text = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
  const a = text.indexOf(BEGIN);
  const b = text.indexOf(END);
  if (a !== -1 && b > a) {
    text = text.slice(0, a) + block + text.slice(b + END.length);
    say('ok', `replaced delegation block in ${file}`);
  } else {
    text = (text ? text.replace(/\s*$/, '\n\n') : '') + block + '\n';
    say('ok', `appended delegation block to ${file}`);
  }
  if (/gpt-5\.5|gpt-5\.4|claude-codex-delegation skill/.test(text.replace(block, ''))) {
    say('warn', `${file} still mentions old models or the old skill outside the block; edit those lines by hand`);
  }
  backup(file);
  write(file, text);
}

// 5. Codex default model: move off retired models, only if this Codex offers the new one.
function patchCodexModel() {
  const file = path.join(HOME, '.codex', 'config.toml');
  if (!fs.existsSync(file)) { say('skip', 'no ~/.codex/config.toml'); return; }
  let offered = true;
  try {
    const cache = JSON.parse(fs.readFileSync(path.join(HOME, '.codex', 'models_cache.json'), 'utf8'));
    offered = (cache.models || []).some((m) => m.slug === CODEX_MODEL);
  } catch (_) { /* no cache yet: trust the default */ }
  if (!offered) { say('warn', `${CODEX_MODEL} not in this Codex's model list; run codex once, then re-run the installer`); return; }

  const text = fs.readFileSync(file, 'utf8');
  const m = text.match(/^model\s*=\s*"([^"]+)"/m);
  if (m && !RETIRED_MODELS.includes(m[1])) { say('skip', `Codex default model is ${m[1]}`); return; }
  const next = m ? text.replace(m[0], `model = "${CODEX_MODEL}"`) : `model = "${CODEX_MODEL}"\n` + text;
  backup(file);
  write(file, next);
  say('ok', `Codex default model ${m ? m[1] : '(unset)'} -> ${CODEX_MODEL}`);
}

function checkPlugin() {
  try {
    const p = fs.readFileSync(path.join(CLAUDE, 'plugins', 'installed_plugins.json'), 'utf8');
    if (/openai-codex/.test(p)) { say('ok', 'codex@openai-codex plugin found (run /codex:setup to confirm login)'); return; }
  } catch (_) { /* fall through */ }
  say('warn', 'codex@openai-codex plugin missing: /plugin marketplace add openai/codex-plugin-cc, then /plugin install codex@openai-codex');
}

console.log(`claude-codex-delegation installer${DRY ? ' (dry run)' : ''}`);
installSkill();
const router = installRouter();
patchSettings(router);
patchClaudeMd();
patchCodexModel();
checkPlugin();
console.log('\nDone. Restart Claude Code. Check: node ' + fwd(router));
