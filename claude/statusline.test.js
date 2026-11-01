const { test } = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

function render(context) {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'statusline-test-'));
  try {
    const result = spawnSync(process.execPath, [path.join(__dirname, 'statusline.js')], {
      input: JSON.stringify({ model: { display_name: 'Example' }, context_window: context }),
      encoding: 'utf8', env: { ...process.env, HOME: home },
    });
    assert.equal(result.status, 0, result.stderr);
    return result.stdout.replace(/\x1b\[[0-9;]*m/g, '').trim();
  } finally {
    fs.rmSync(home, { recursive: true, force: true });
  }
}

function usage(input, creation, read) {
  return { input_tokens: input, cache_creation_input_tokens: creation, cache_read_input_tokens: read, output_tokens: 99000 };
}

test('ctx sums current input and cache tokens, excluding output and cumulative counts', () => {
  assert.equal(render({ current_usage: usage(10000, 30000, 200000),
    used_percentage: 24, remaining_percentage: 76, total_input_tokens: 900000 }), 'Example │ ctx 240k');
});

test('ctx formats zero, small counts, and compact thousands', () => {
  for (const [n, expected] of [[0, '0'], [999, '999'], [1500, '1.5k'], [1000000, '1000k']]) {
    assert.equal(render({ current_usage: usage(n, 0, 0) }), `Example │ ctx ${expected}`);
  }
});

test('ctx reports unavailable rather than inferring usage from percentages', () => {
  for (const context of [undefined, {}, { current_usage: null },
    { used_percentage: 24, remaining_percentage: 76 },
    { current_usage: { input_tokens: 100 } }]) {
    assert.equal(render(context), 'Example │ ctx --');
  }
});

test('ctx rejects malformed token counts without dropping the model segment', () => {
  for (const value of [-1, '100', true, null]) {
    assert.equal(render({ current_usage: usage(value, 0, 0) }), 'Example │ ctx --');
  }
});
