const assert = require('node:assert/strict');
const test = require('node:test');

const { patchSource } = require('../deploy/customer/patches/librechat-file-search-depth');

const upstreamSnippet = `
const body = {
  file_id: file.file_id,
  query,
  k: 5
};`;

test('raises only the pinned per-file File Search candidate depth', () => {
  const result = patchSource(`${upstreamSnippet}\nconst other = { query, k: 5 };`);
  assert.equal(result.changed, true);
  assert.match(result.source, /file_id: file\.file_id,\s*query,\s*k: 10/);
  assert.match(result.source, /const other = \{ query, k: 5 \}/);
});

test('is idempotent after the verified depth is applied', () => {
  const once = patchSource(upstreamSnippet).source;
  const twice = patchSource(once);
  assert.equal(twice.changed, false);
  assert.equal(twice.source, once);
});

test('refuses an unknown upstream depth', () => {
  assert.throws(() => patchSource(upstreamSnippet.replace('k: 5', 'k: 7')), /found 7/);
});

test('refuses an unrecognized source shape', () => {
  assert.throws(() => patchSource('const body = { query, k: 5 };'), /found 0/);
});

test('refuses ambiguous duplicate matches without changing the source', () => {
  const duplicate = `${upstreamSnippet}\n${upstreamSnippet}`;
  assert.throws(() => patchSource(duplicate), /found 2/);
  assert.match(duplicate, /file_id: file\.file_id,\s*query,\s*k: 5/);
});
