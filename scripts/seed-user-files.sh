#!/usr/bin/env bash
# Seed account-owned files through LibreChat's normal authenticated upload route.
# Usage: ./scripts/seed-user-files.sh <username-or-email> <directory>

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINER_NAME="${GOMBEY_CONTAINER_NAME:-gombey-ai-portal}"

fail() {
  echo "User file seeding failed: $*" >&2
  exit 1
}

[ "$#" -eq 2 ] || fail "usage: $0 <username-or-email> <directory>"

USER_LOOKUP="$1"
SOURCE_DIR="$2"

[ -n "$USER_LOOKUP" ] || fail "username or email is empty"
[ -d "$SOURCE_DIR" ] || fail "source directory does not exist: $SOURCE_DIR"
command -v docker >/dev/null 2>&1 || fail "docker is required"

SOURCE_FILES=()
while IFS= read -r source_file; do
  SOURCE_FILES+=("$source_file")
done < <(find "$SOURCE_DIR" -maxdepth 1 -type f -name '*.md' -print | sort)
[ "${#SOURCE_FILES[@]}" -gt 0 ] || fail "no Markdown files found in $SOURCE_DIR"

STAGE_DIR="/tmp/gombey-seed-files-$$-${RANDOM}"
docker exec "$CONTAINER_NAME" mkdir -p "$STAGE_DIR"

cleanup() {
  docker exec "$CONTAINER_NAME" rm -rf "$STAGE_DIR" >/dev/null 2>&1 || true
}
trap cleanup EXIT

for source_file in "${SOURCE_FILES[@]}"; do
  docker cp "$source_file" "$CONTAINER_NAME:$STAGE_DIR/"
done

docker exec -i \
  -e "GOMBEY_SEED_USER=$USER_LOOKUP" \
  -e "GOMBEY_SEED_DIR=$STAGE_DIR" \
  "$CONTAINER_NAME" node - <<'NODE'
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

require('module-alias')({ base: path.resolve('/app/api') });

const mongoose = require('mongoose');
const { createModels } = require('@librechat/data-schemas');
createModels(mongoose);

const { connectDb } = require('./api/db/connect');
const db = require('./api/models');

const lookup = process.env.GOMBEY_SEED_USER;
const seedDir = process.env.GOMBEY_SEED_DIR;
const isEmail = lookup.includes('@');

async function main() {
  await connectDb();

  const user = await db.findUser(
    isEmail ? { email: lookup } : { username: lookup },
    '_id username email role tenantId',
  );

  if (!user) {
    throw new Error(`No user found for the supplied username/email: ${lookup}`);
  }

  const files = fs
    .readdirSync(seedDir)
    .filter((filename) => filename.endsWith('.md'))
    .sort();

  const filesCollection = mongoose.connection.db.collection('files');
  const existing = await filesCollection
    .find({ user: user._id }, { projection: { filename: 1, context: 1 } })
    .toArray();
  const existingNames = new Set((existing ?? []).map((file) => file.filename));
  const token = await db.generateToken(user, 10 * 60 * 1000);

  console.log(`Target account: ${user.username}`);
  console.log(`Files selected: ${files.length}`);

  for (const filename of files) {
    if (existingNames.has(filename)) {
      console.log(`SKIP ${filename} (already exists for this account)`);
      continue;
    }

    const content = fs.readFileSync(path.join(seedDir, filename));
    const form = new FormData();
    form.append('file', new Blob([content], { type: 'text/markdown' }), filename);
    form.set('file_id', crypto.randomUUID());
    form.set('endpoint', 'custom');
    form.set('model', 'gemma4:latest');
    form.set('message_file', 'true');

    const response = await fetch('http://127.0.0.1:3080/api/files', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        // LibreChat intentionally rejects non-browser User-Agent values on file routes.
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/140 Safari/537.36',
      },
      body: form,
    });

    const body = await response.text();
    if (!response.ok || body.startsWith('event: error')) {
      throw new Error(`upload failed for ${filename} (${response.status}): ${body}`);
    }

    console.log(`SEEDED ${filename}`);
    existingNames.add(filename);
  }

  const seeded = await filesCollection
    .find(
      { user: user._id, filename: { $in: files } },
      { projection: { filename: 1, file_id: 1, user: 1, context: 1 } },
    )
    .toArray();
  console.log(`Verified account-owned files: ${seeded.length}`);
  if (seeded.length !== files.length) {
    throw new Error(`expected ${files.length} account-owned files, found ${seeded.length}`);
  }
}

main()
  .catch((error) => {
    console.error(error.stack || error.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await mongoose.disconnect();
  });
NODE
