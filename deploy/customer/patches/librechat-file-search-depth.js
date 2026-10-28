const fs = require('node:fs');

const sourcePath = '/app/packages/api/dist/index.cjs';
const perFileDepthPattern = /(file_id:\s*file\.file_id,\s*query,\s*k:\s*)(\d+)/g;
const mergedContextLimitPattern =
  /(const formattedResults = validResults\.flatMap\([\s\S]*?\.sort\(\(a, b\) => a\.distance - b\.distance\)\.slice\(0,\s*)(\d+)(\))/g;
const TARGET_LIMIT = 20;

function replaceVerifiedLimit(source, pattern, label, verifiedLimits) {
  const matches = [...source.matchAll(pattern)];
  if (matches.length !== 1) {
    throw new Error(
      `Expected one upstream ${label}; found ${matches.length}. ` +
        'Refusing to start with an unverified retrieval implementation.',
    );
  }

  const currentLimit = Number(matches[0][2]);
  if (!verifiedLimits.has(currentLimit)) {
    throw new Error(
      `Expected a verified upstream ${label}; found ${currentLimit}. ` +
        'Refusing to apply an unverified patch.',
    );
  }
  if (currentLimit === TARGET_LIMIT) {
    return { source, changed: false };
  }

  return {
    source: source.replace(pattern, (_match, prefix, _limit, suffix) =>
      `${prefix}${TARGET_LIMIT}${typeof suffix === 'string' ? suffix : ''}`,
    ),
    changed: true,
  };
}

function patchSource(source) {
  const perFile = replaceVerifiedLimit(
    source,
    perFileDepthPattern,
    'per-file File Search depth (5, 10, or 20)',
    new Set([5, 10, 20]),
  );
  const merged = replaceVerifiedLimit(
    perFile.source,
    mergedContextLimitPattern,
    'merged File Search context limit (10 or 20)',
    new Set([10, 20]),
  );
  return { source: merged.source, changed: perFile.changed || merged.changed };
}

function main() {
  const source = fs.readFileSync(sourcePath, 'utf8');
  const result = patchSource(source);
  if (result.changed) {
    fs.writeFileSync(sourcePath, result.source);
  }
  process.stdout.write(
    result.changed
      ? 'Raised per-file File Search candidates and merged model context to 20 passages.\n'
      : 'Per-file File Search depth and merged context limit already set to 20.\n',
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
