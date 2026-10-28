#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${GOMBEY_REPO_DIR:-$SCRIPT_DIR/..}" && pwd -P)"
CUSTOMER_DIR="${GOMBEY_CUSTOMER_DIR:-$REPO_DIR/deploy/customer}"
CUSTOMER_ENV="${GOMBEY_CUSTOMER_ENV_PATH:-$CUSTOMER_DIR/.env}"
COMPOSE_OVERRIDE="${GOMBEY_CUSTOMER_COMPOSE_OVERRIDE:-}"
BACKUP_KEYCHAIN_SERVICE="${GOMBEY_BACKUP_KEYCHAIN_SERVICE:-}"
BACKUP_KEYCHAIN_ACCOUNT="${GOMBEY_BACKUP_KEYCHAIN_ACCOUNT:-$(id -un)}"
BACKUP_PASSPHRASE_FILE="${GOMBEY_BACKUP_PASSPHRASE_FILE:-}"

fail() {
  echo "Customer backup failed: $*" >&2
  exit 1
}

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <existing-private-backup-directory>" >&2
  exit 2
fi

[[ -d "$CUSTOMER_DIR" ]] || fail "customer deployment directory does not exist"
[[ -f "$CUSTOMER_ENV" && ! -L "$CUSTOMER_ENV" ]] || fail "customer .env must be a regular file, not a symlink"
if ENV_MODE="$(stat -c '%a' "$CUSTOMER_ENV" 2>/dev/null)"; then
  :
elif ENV_MODE="$(stat -f '%Lp' "$CUSTOMER_ENV" 2>/dev/null)"; then
  :
else
  fail "could not check customer .env permissions"
fi
[[ "$ENV_MODE" == "600" ]] || fail "customer .env must be mode 600"
command -v openssl >/dev/null 2>&1 || fail "OpenSSL is required for encrypted backups"
if [[ -n "$BACKUP_KEYCHAIN_SERVICE" && -n "$BACKUP_PASSPHRASE_FILE" ]]; then
  fail "choose either a Keychain item or a passphrase file, not both"
elif [[ -n "$BACKUP_KEYCHAIN_SERVICE" ]]; then
  command -v security >/dev/null 2>&1 || fail "macOS Keychain access is unavailable"
  security find-generic-password -s "$BACKUP_KEYCHAIN_SERVICE" -a "$BACKUP_KEYCHAIN_ACCOUNT" -w >/dev/null 2>&1 \
    || fail "the requested recovery key is not available in the login Keychain"
elif [[ -n "$BACKUP_PASSPHRASE_FILE" ]]; then
  [[ -f "$BACKUP_PASSPHRASE_FILE" && ! -L "$BACKUP_PASSPHRASE_FILE" ]] || fail "passphrase file must be a regular file, not a symlink"
  [[ -s "$BACKUP_PASSPHRASE_FILE" ]] || fail "passphrase file must not be empty"
  if PASSPHRASE_MODE="$(stat -c '%a' "$BACKUP_PASSPHRASE_FILE" 2>/dev/null)"; then
    :
  elif PASSPHRASE_MODE="$(stat -f '%Lp' "$BACKUP_PASSPHRASE_FILE" 2>/dev/null)"; then
    :
  else
    fail "could not check passphrase-file permissions"
  fi
  [[ "$PASSPHRASE_MODE" == "600" ]] || fail "passphrase file must be mode 600"
else
  fail "encrypted backup required: set GOMBEY_BACKUP_KEYCHAIN_SERVICE or GOMBEY_BACKUP_PASSPHRASE_FILE"
fi

BACKUP_ROOT="$1"
[[ "$BACKUP_ROOT" == /* ]] || fail "backup directory must be an absolute path"
[[ "$BACKUP_ROOT" != "/" ]] || fail "refusing to use the filesystem root as a backup directory"
umask 077
mkdir -p "$BACKUP_ROOT"
BACKUP_ROOT="$(cd "$BACKUP_ROOT" && pwd -P)"
case "$BACKUP_ROOT/" in
  "$REPO_DIR/"*) fail "backup directory must be outside the Git checkout" ;;
esac
CUSTOMER_REPO_DIR="$(cd "$CUSTOMER_DIR/../.." && pwd -P)"
case "$BACKUP_ROOT/" in
  "$CUSTOMER_REPO_DIR/"*) fail "backup directory must be outside the customer Git checkout" ;;
esac
if [[ -n "$BACKUP_PASSPHRASE_FILE" ]]; then
  case "$BACKUP_PASSPHRASE_FILE" in
    "$BACKUP_ROOT/"*) fail "passphrase file must be stored outside the backup directory" ;;
    "$REPO_DIR/"*|"$CUSTOMER_REPO_DIR/"*) fail "passphrase file must be stored outside the Git checkout" ;;
  esac
fi

if [[ -n "${GOMBEY_LOCAL_DATA_ROOT:-}" ]]; then
  export GOMBEY_LOCAL_DATA_ROOT
fi

COMPOSE_ARGS=(docker compose --project-directory "$CUSTOMER_DIR" --env-file "$CUSTOMER_ENV" -f "$CUSTOMER_DIR/compose.yaml")
if [[ -n "$COMPOSE_OVERRIDE" ]]; then
  [[ "$COMPOSE_OVERRIDE" == /* ]] || COMPOSE_OVERRIDE="$CUSTOMER_DIR/$COMPOSE_OVERRIDE"
  [[ -f "$COMPOSE_OVERRIDE" ]] || fail "Compose override does not exist"
  COMPOSE_ARGS+=(-f "$COMPOSE_OVERRIDE")
fi
"${COMPOSE_ARGS[@]}" version >/dev/null 2>&1 || fail "Docker Compose is unavailable"

RUNNING_SERVICES="$("${COMPOSE_ARGS[@]}" ps --status running --services)"
for service in api rag_api mongodb vectordb meilisearch; do
  printf '%s\n' "$RUNNING_SERVICES" | grep -Fxq "$service" || fail "required service ${service} is not running"
done

API_ID="$("${COMPOSE_ARGS[@]}" ps -q api)"
MEILI_ID="$("${COMPOSE_ARGS[@]}" ps -q meilisearch)"
[[ -n "$API_ID" && -n "$MEILI_ID" ]] || fail "could not identify data containers"
COMPOSE_PROJECT="$(docker inspect "$API_ID" --format '{{index .Config.Labels "com.docker.compose.project"}}')"
[[ -n "$COMPOSE_PROJECT" && "$COMPOSE_PROJECT" != "<no value>" ]] || fail "could not identify the running Compose project"

MONGO_DATABASE="$(sed -n 's/^MONGO_DATABASE=//p' "$CUSTOMER_ENV" | head -n 1)"
[[ "$MONGO_DATABASE" =~ ^[A-Za-z0-9_-]+$ ]] || fail "MONGO_DATABASE is missing or has an unsupported value"

TEMP_DIR="$(mktemp -d "$BACKUP_ROOT/.gombey-customer-backup.XXXXXX")"
PAYLOAD_DIR="$TEMP_DIR/payload"
mkdir -m 700 "$PAYLOAD_DIR" "$PAYLOAD_DIR/config" "$PAYLOAD_DIR/runtime"
WRITERS_STOPPED=0

cleanup() {
  exit_status=$?
  trap - EXIT
  if [[ "$WRITERS_STOPPED" == "1" ]]; then
    if ! "${COMPOSE_ARGS[@]}" start api rag_api meilisearch >/dev/null; then
      echo "Customer backup warning: could not restart api/rag_api/meilisearch; inspect the Compose project." >&2
      exit_status=1
    fi
  fi
  if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
    rm -rf -- "$TEMP_DIR"
  fi
  exit "$exit_status"
}
trap cleanup EXIT

echo "Pausing customer app, RAG, and search writers for a consistent local backup..."
WRITERS_STOPPED=1
"${COMPOSE_ARGS[@]}" stop api rag_api meilisearch >/dev/null

"${COMPOSE_ARGS[@]}" exec -T -e "BACKUP_MONGO_DATABASE=$MONGO_DATABASE" mongodb sh -lc \
  'mongodump --host 127.0.0.1 --port 27017 --username "$MONGO_INITDB_ROOT_USERNAME" --password "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin --db "$BACKUP_MONGO_DATABASE" --archive --gzip --quiet' \
  > "$PAYLOAD_DIR/runtime/mongodb.archive.gz"

"${COMPOSE_ARGS[@]}" exec -T vectordb sh -lc \
  'PGPASSWORD="$POSTGRES_PASSWORD" pg_dump --host 127.0.0.1 --port 5432 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --format=custom' \
  > "$PAYLOAD_DIR/runtime/vectordb.pgdump"

docker cp "$API_ID:/app/data" - > "$PAYLOAD_DIR/runtime/app-data.tar"
docker cp "$API_ID:/app/uploads" - > "$PAYLOAD_DIR/runtime/uploads.tar"
docker cp "$MEILI_ID:/meili_data" - > "$PAYLOAD_DIR/runtime/meilisearch-data.tar"

for archive in "$PAYLOAD_DIR/runtime/mongodb.archive.gz" \
  "$PAYLOAD_DIR/runtime/vectordb.pgdump" \
  "$PAYLOAD_DIR/runtime/app-data.tar" \
  "$PAYLOAD_DIR/runtime/uploads.tar" \
  "$PAYLOAD_DIR/runtime/meilisearch-data.tar"; do
  [[ -s "$archive" ]] || fail "backup component is empty"
  chmod 600 "$archive"
done

tar -tf "$PAYLOAD_DIR/runtime/app-data.tar" >/dev/null || fail "app-data archive is invalid"
tar -tf "$PAYLOAD_DIR/runtime/uploads.tar" >/dev/null || fail "uploads archive is invalid"
tar -tf "$PAYLOAD_DIR/runtime/meilisearch-data.tar" >/dev/null || fail "Meilisearch archive is invalid"

cp -p "$CUSTOMER_ENV" "$PAYLOAD_DIR/config/.env"
cp -p "$CUSTOMER_DIR/compose.yaml" "$PAYLOAD_DIR/config/compose.yaml"
cp -p "$CUSTOMER_DIR/librechat.yaml" "$PAYLOAD_DIR/config/librechat.yaml"
cp -p "$CUSTOMER_DIR/Caddyfile" "$PAYLOAD_DIR/config/Caddyfile"
cp -R "$CUSTOMER_DIR/patches" "$PAYLOAD_DIR/config/patches"
if [[ -n "$COMPOSE_OVERRIDE" ]]; then
  cp -p "$COMPOSE_OVERRIDE" "$PAYLOAD_DIR/config/compose.override.yaml"
fi
for asset in branding assets/logo.svg assets/logo.png assets/icon-192x192.png \
  assets/gombey-agent-avatar.png assets/maskable-icon.png \
  assets/apple-touch-icon-180x180.png assets/favicon-16x16.png \
  assets/favicon-32x32.png images/gombey_logo.png; do
  [[ -e "$REPO_DIR/$asset" ]] || fail "required runtime asset is missing: $asset"
  mkdir -p "$PAYLOAD_DIR/config/$(dirname "$asset")"
  cp -R "$REPO_DIR/$asset" "$PAYLOAD_DIR/config/$asset"
done

cat > "$PAYLOAD_DIR/README.txt" <<'EOF'
Gombey AI customer deployment backup.

After decryption, the archive contains customer account data, uploaded
documents, deployment secrets, provider configuration, and potentially
private application data. The outer archive is AES-256 encrypted. Keep the
recovery key separate from the archive; do not upload plaintext to GitHub,
tickets, or an unencrypted cloud folder.

The app, RAG, and search services were paused while the database and file data
were captured, then are restarted by the script. Caddy's certificate cache is
not included; on restore, Caddy can obtain a fresh certificate after DNS and
ports are correct.

Before restoring, verify the checksum and decrypt only on an authorized host.
Restore the same deployment secrets needed to decrypt stored credentials into
a clean, isolated recovery deployment; do not publish that recovery copy.
Never restore over the active production database.
EOF

cat > "$PAYLOAD_DIR/manifest.txt" <<EOF
created_utc=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
compose_project=$COMPOSE_PROJECT
source_commit=$(git -C "$CUSTOMER_REPO_DIR" rev-parse HEAD 2>/dev/null || echo unknown)
source_tree_dirty=$(if [[ -n "$(git -C "$CUSTOMER_REPO_DIR" status --porcelain 2>/dev/null)" ]]; then echo true; else echo false; fi)
mongo_database=$MONGO_DATABASE
writers_paused_during_capture=true
encrypted=true
encryption=AES-256-CBC-PBKDF2-SHA256
EOF

chmod -R go-rwx "$PAYLOAD_DIR"
tar -czf "$TEMP_DIR/customer-backup.tar.gz" -C "$PAYLOAD_DIR" .
tar -tzf "$TEMP_DIR/customer-backup.tar.gz" >/dev/null || fail "final backup archive failed validation"
if [[ -n "$BACKUP_KEYCHAIN_SERVICE" ]]; then
  openssl enc -aes-256-cbc -salt -pbkdf2 -iter 600000 -md sha256 \
    -pass fd:3 -in "$TEMP_DIR/customer-backup.tar.gz" \
    -out "$TEMP_DIR/customer-backup.tar.gz.enc" \
    3< <(security find-generic-password -s "$BACKUP_KEYCHAIN_SERVICE" -a "$BACKUP_KEYCHAIN_ACCOUNT" -w) \
    || fail "could not encrypt the backup with the Keychain recovery key"
else
  openssl enc -aes-256-cbc -salt -pbkdf2 -iter 600000 -md sha256 \
    -pass "file:$BACKUP_PASSPHRASE_FILE" \
    -in "$TEMP_DIR/customer-backup.tar.gz" \
    -out "$TEMP_DIR/customer-backup.tar.gz.enc" \
    || fail "could not encrypt the backup with the passphrase file"
fi
if [[ -n "$BACKUP_KEYCHAIN_SERVICE" ]]; then
  openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -md sha256 \
    -pass fd:3 -in "$TEMP_DIR/customer-backup.tar.gz.enc" \
    3< <(security find-generic-password -s "$BACKUP_KEYCHAIN_SERVICE" -a "$BACKUP_KEYCHAIN_ACCOUNT" -w) \
    | tar -tzf - >/dev/null || fail "encrypted backup failed its decrypt-and-list validation"
else
  openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -md sha256 \
    -pass "file:$BACKUP_PASSPHRASE_FILE" \
    -in "$TEMP_DIR/customer-backup.tar.gz.enc" \
    | tar -tzf - >/dev/null || fail "encrypted backup failed its decrypt-and-list validation"
fi
chmod 600 "$TEMP_DIR/customer-backup.tar.gz.enc"
rm -f "$TEMP_DIR/customer-backup.tar.gz"
if command -v sha256sum >/dev/null 2>&1; then
  (cd "$TEMP_DIR" && sha256sum customer-backup.tar.gz.enc > SHA256SUMS.txt)
elif command -v shasum >/dev/null 2>&1; then
  (cd "$TEMP_DIR" && shasum -a 256 customer-backup.tar.gz.enc > SHA256SUMS.txt)
else
  fail "sha256sum or shasum is required to verify the backup"
fi
chmod 600 "$TEMP_DIR/SHA256SUMS.txt"
rm -rf -- "$PAYLOAD_DIR"

STAMP="$(date -u '+%Y%m%dT%H%M%SZ')"
FINAL_DIR="$BACKUP_ROOT/gombey-customer-backup-$STAMP-$$"
mv "$TEMP_DIR" "$FINAL_DIR"
TEMP_DIR=""
"${COMPOSE_ARGS[@]}" start api rag_api meilisearch >/dev/null
WRITERS_STOPPED=0

echo "Encrypted backup archive created and checksum verified: $FINAL_DIR/customer-backup.tar.gz.enc"
echo "Security: archive mode is 600; backup directory mode is 700; recovery key is stored separately."
