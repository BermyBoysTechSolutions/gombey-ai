const fs = require('node:fs');

const sourcePath = '/app/api/server/routes/agents/v1.js';
const source = fs.readFileSync(sourcePath, 'utf8');
const unsafeHandler = '  v1.getAgent,';
const safeHandler = '  (req, res) => v1.getAgent(req, res, false),';

if (source.includes(safeHandler)) {
  process.stdout.write('LibreChat basic-agent route guard already applied.\n');
  process.exit(0);
}

const matches = source.split(unsafeHandler).length - 1;
if (matches !== 1) {
  throw new Error(
    `Expected one upstream basic-agent handler to patch; found ${matches}. ` +
      'Refusing to start with an unverified LibreChat route.',
  );
}

fs.writeFileSync(sourcePath, source.replace(unsafeHandler, safeHandler));
process.stdout.write('Applied explicit viewer-only basic-agent response guard.\n');
