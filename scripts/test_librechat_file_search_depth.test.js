const assert = require('node:assert/strict');
const test = require('node:test');

const { patchSource } = require('../deploy/customer/patches/librechat-file-search-depth');

const upstreamSnippet = `
const body = {
  file_id: file.file_id,
  query,
  k: 5
};
const formattedResults = validResults.flatMap((result) => result.data.map(([docInfo, distance]) => ({
  filename: docInfo.metadata.source.split("/").pop(),
  content: docInfo.page_content,
  distance,
  file_id: result.file_id
}))).sort((a, b) => a.distance - b.distance).slice(0, 10);
const unrelated = values.slice(0, 10);
const other = { query, k: 5 };`;

test('raises per-file candidates and merged File Search context together', () => {
  const result = patchSource(upstreamSnippet);
  assert.equal(result.changed, true);
  assert.match(result.source, /file_id: file\.file_id,\s*query,\s*k: 20/);
  assert.match(result.source, /\.sort\(\(a, b\) => a\.distance - b\.distance\)\.slice\(0, 20\)/);
  assert.match(result.source, /const unrelated = values\.slice\(0, 10\)/);
  assert.match(result.source, /const other = \{ query, k: 5 \}/);
});

test('is idempotent after both verified limits are applied', () => {
  const once = patchSource(upstreamSnippet).source;
  const twice = patchSource(once);
  assert.equal(twice.changed, false);
  assert.equal(twice.source, once);
});

test('accepts the already-raised per-file depth while raising the merge cap', () => {
  const alreadyRaised = upstreamSnippet.replace('k: 5', 'k: 10');
  const result = patchSource(alreadyRaised);
  assert.equal(result.changed, true);
  assert.match(result.source, /k: 20/);
  assert.match(result.source, /\.slice\(0, 20\)/);
});

test('refuses an unknown per-file candidate depth', () => {
  assert.throws(() => patchSource(upstreamSnippet.replace('k: 5', 'k: 7')), /found 7/);
});

test('refuses an unknown merged context limit', () => {
  assert.throws(() => patchSource(upstreamSnippet.replace('.slice(0, 10)', '.slice(0, 15)')), /found 15/);
});

test('refuses either unrecognized source shape', () => {
  assert.throws(() => patchSource('const body = { query, k: 5 };'), /per-file File Search depth.*found 0/);
  assert.throws(() => patchSource(upstreamSnippet.replace('const formattedResults =', 'const results =')), /merged File Search context limit.*found 0/);
});

test('refuses ambiguous duplicate matches without changing source', () => {
  assert.throws(() => patchSource(`${upstreamSnippet}\n${upstreamSnippet}`), /per-file File Search depth.*found 2/);
});
