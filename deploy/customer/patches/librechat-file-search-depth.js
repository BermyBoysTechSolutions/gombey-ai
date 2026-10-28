const fs = require('node:fs');

const sourcePath = '/app/packages/api/dist/index.cjs';
const searchDepthPattern = /(file_id:\s*file\.file_id,\s*query,\s*k:\s*)(\d+)/g;

function patchSource(source) {
  const matches = [...source.matchAll(searchDepthPattern)];
  if (matches.length !== 1) {
    throw new Error(
      `Expected one upstream per-file File Search depth; found ${matches.length}. ` +
        'Refusing to start with an unverified retrieval implementation.',
    );
  }

  const currentDepth = Number(matches[0][2]);
  if (currentDepth === 10) {
    return { source, changed: false };
  }
  if (currentDepth !== 5) {
    throw new Error(
      `Expected the pinned upstream File Search depth to be 5 or 10; found ${currentDepth}. ` +
        'Refusing to apply an unverified patch.',
    );
  }

  return {
    source: source.replace(searchDepthPattern, (_match, prefix) => `${prefix}10`),
    changed: true,
  };
}

function main() {
  const source = fs.readFileSync(sourcePath, 'utf8');
  const result = patchSource(source);
  if (result.changed) {
    fs.writeFileSync(sourcePath, result.source);
  }
  process.stdout.write(
    result.changed
      ? 'Raised per-file File Search candidates to 10; merged context remains capped at 10.\n'
      : 'Per-file File Search candidate depth already set to 10.\n',
  );
}

if (require.main === module) {
  try {
    main();
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}

module.exports = { patchSource };
