// Claude Code statusline: model name + rate-limit usage, styled to match
// Claude Code's own understated terminal UI (dim secondary text, restrained
// color used only for warning-level usage, thin subtle progress bars).
//
// Port of the previous jq-based statusline.sh, moved to Node so this has no
// dependency beyond what Claude Code itself already requires to run at all.
// Invoked directly by claude/settings.json's statusLine.command
// ("node ~/.claude/statusline.js") - no wrapper script needed. This does
// mean a missing `node` on PATH surfaces as a raw shell error rather than
// a graceful empty line - accepted tradeoff for not needing an extra file.

const fs = require('fs');

const DIM = '\x1b[2m';
const RESET = '\x1b[0m';

// Original hierarchy: the data (bar fill + percentage) is plain default
// foreground - readable but not colorful; color appears only as a
// warning (yellow >=70% used, red >=90% used). Decoration stays dim.
function warnColor(pct) {
  if (pct >= 90) return '\x1b[31m';
  if (pct >= 70) return '\x1b[33m';
  return '';
}

// resets_at is documented as a Unix epoch number, but tolerate an
// ISO-8601 string too (and fall back to "now" rather than hard-erroring
// on an unrecognized shape). Returns seconds, matching jq's `now`.
function toEpochSeconds(v) {
  if (typeof v === 'number') return v;
  const ms = Date.parse(v);
  return Number.isNaN(ms) ? Date.now() / 1000 : ms / 1000;
}

function remaining(epochSeconds) {
  const seconds = Math.max(0, Math.floor(epochSeconds - Date.now() / 1000));
  if (seconds >= 86400) {
    const d = Math.floor(seconds / 86400);
    const h = Math.floor((seconds % 86400) / 3600);
    return `${d}d${h}h`;
  }
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  return `${h}h${m}m`;
}

// .repeat() throws RangeError on a negative count - guard against that.
function repeatChar(ch, n) {
  return n <= 0 ? '' : ch.repeat(n);
}

// Progress bar: rounded-block pair - filled segments colored, empty
// counterparts dimmed. Medium weight, chosen by the user over thin
// lines (unreadable) and solid blocks (too heavy).
function bar(pct, color) {
  const width = 5;
  const raw = Math.round((pct / 100) * width);
  const f0 = raw > width ? width : raw < 0 ? 0 : raw;
  const f = pct > 0 && f0 === 0 ? 1 : f0;
  return (
    color + repeatChar('▰', f) + RESET + DIM + repeatChar('▱', width - f) + RESET
  );
}

// Shows REMAINING (not used): the bar drains as the window is consumed,
// and the number is what is left. Warning colors still key off usage
// (yellow at >=70% used, red at >=90% used).
function window(data, label) {
  if (!data || data.used_percentage == null || data.resets_at == null) return null;
  const pct = Math.round(data.used_percentage);
  const rem = 100 - pct;
  const c = warnColor(pct);
  return (
    DIM + `${label} ` + RESET +
    bar(rem, c) + ' ' +
    c + `${rem}% remain` + RESET +
    DIM + ` ↻ ${remaining(toEpochSeconds(data.resets_at))}` + RESET
  );
}

// Pace projection for the 7-day window, in the spirit of codexbar
// (github.com/steipete/codexbar) and its predictive pace warnings: given
// how much of the window has elapsed and how much quota that burned,
// linearly extrapolate forward and compare against the time left until
// reset. codexbar itself requires 3+ weeks of historical samples and fits
// a weighted historical curve rather than a straight line - there is no
// sample history available here (this script only ever sees one snapshot
// at a time), so this is deliberately the simpler linear at-this-pace
// projection instead, not a port of the actual algorithm.
function pacePart(data) {
  if (!data || data.used_percentage == null || data.resets_at == null) return null;
  const pct = data.used_percentage;
  const resets = toEpochSeconds(data.resets_at);
  const windowSecs = 7 * 86400;
  const start = resets - windowSecs;
  const elapsed = Date.now() / 1000 - start;

  // Too little of the window has passed for a sane projection, or usage
  // is still at 0 (nothing to extrapolate from) - show nothing.
  if (!(elapsed > 3600 && pct > 0)) return null;

  const projectedPctAtReset = (pct * windowSecs) / elapsed;

  if (projectedPctAtReset >= 100) {
    const days = Math.floor((elapsed * (100 / pct) - elapsed) / 86400);
    return `\x1b[31m⚡ ${days}d to exhaust${RESET}`;
  }

  const remainingPct = Math.round(100 - projectedPctAtReset);
  // A comfortable-looking "N% left" reads as reassuring even when N is
  // small - reuse the same 70%-used threshold the rest of this bar warns
  // at (see warnColor) so a thin margin gets flagged instead of looking
  // indistinguishable from a wide one.
  if (projectedPctAtReset >= 70) {
    return `\x1b[33m⚡ ${remainingPct}% left at reset, tight${RESET}`;
  }
  return DIM + `⚡ ${remainingPct}% left at reset` + RESET;
}

// Context-window usage segment, in the same drain style as the rate-limit
// windows: the bar shows what is left, and color warns off percent used.
// There is no reset time here, since context does not refill on a timer
// the way a rate-limit window does.
function ctxPart(data) {
  const cw = data && data.context_window;
  if (!cw || cw.used_percentage == null || cw.remaining_percentage == null) return null;
  const pct = Math.round(cw.used_percentage);
  const rem = Math.round(cw.remaining_percentage);
  const c = warnColor(pct);
  return DIM + 'ctx ' + RESET + bar(rem, c) + ' ' + c + `${rem}%` + RESET;
}

// Model name, with the reasoning effort level appended dim when present
// (effort is absent when the model has no effort parameter).
function modelPart(data) {
  const model = (data.model && data.model.display_name) ?? '';
  const level = (data.effort && data.effort.level) ?? '';
  if (model === '') return '';
  if (level === '') return model;
  return model + DIM + ' · ' + level + RESET;
}

function render(data) {
  const rateLimits = data.rate_limits || {};
  const parts = [
    modelPart(data),
    ctxPart(data),
    window(rateLimits.five_hour, '5h'),
    window(rateLimits.seven_day, '7d'),
    pacePart(rateLimits.seven_day),
  ];
  return parts.filter((s) => s != null && s !== '').join(DIM + ' │ ' + RESET);
}

function main() {
  let raw;
  try {
    raw = fs.readFileSync(0, 'utf-8');
  } catch (e) {
    if (process.env.STATUSLINE_DEBUG) console.error(e);
    process.exit(0);
  }

  let data;
  try {
    data = JSON.parse(raw);
    if (typeof data !== 'object' || data === null || Array.isArray(data)) {
      throw new Error('statusline input is not a JSON object');
    }
  } catch (e) {
    if (process.env.STATUSLINE_DEBUG) console.error(e);
    process.exit(0);
  }

  try {
    console.log(render(data));
  } catch (e) {
    if (process.env.STATUSLINE_DEBUG) console.error(e);
    process.exit(0);
  }
}

main();
