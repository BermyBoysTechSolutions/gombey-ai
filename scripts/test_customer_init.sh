#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INIT_SCRIPT="$SCRIPT_DIR/customer-init.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/gombey-customer-init.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  echo "customer-init test failed: $*" >&2
  exit 1
}

assert_mode_600() {
  local mode
  if mode="$(stat -c '%a' "$1" 2>/dev/null)"; then
    :
  else
    mode="$(stat -f '%Lp' "$1")"
  fi
  [[ "$mode" == "600" ]] || fail "expected mode 600, got $mode"
}

VALID_ENV="$TEST_ROOT/valid/deploy/customer.env"
mkdir -p "$(dirname "$VALID_ENV")"
GOMBEY_CUSTOMER_ENV_PATH="$VALID_ENV" bash "$INIT_SCRIPT" \
  chat.example.test ops@example.test "Synthetic Test" >/dev/null
[[ -f "$VALID_ENV" ]] || fail "initializer did not create the environment file"
assert_mode_600 "$VALID_ENV"
grep -qx 'ALLOW_REGISTRATION=false' "$VALID_ENV" || fail "registration is not disabled"
grep -qx 'ALLOW_PASSWORD_RESET=false' "$VALID_ENV" || fail "password reset is not disabled"
grep -qx 'RAG_OPENAI_API_KEY=REPLACE_WITH_CUSTOMER_OWNED_EMBEDDINGS_API_KEY' "$VALID_ENV" || fail "embeddings placeholder is missing"

secret_count="$(grep -Ec '^(MONGO_ROOT_PASSWORD|POSTGRES_PASSWORD|MEILI_MASTER_KEY|JWT_SECRET|JWT_REFRESH_SECRET|CREDS_KEY|CREDS_IV)=' "$VALID_ENV")"
unique_secret_count="$(grep -E '^(MONGO_ROOT_PASSWORD|POSTGRES_PASSWORD|MEILI_MASTER_KEY|JWT_SECRET|JWT_REFRESH_SECRET|CREDS_KEY|CREDS_IV)=' "$VALID_ENV" | cut -d= -f2- | sort -u | wc -l | tr -d '[:space:]')"
[[ "$secret_count" == "7" && "$unique_secret_count" == "7" ]] || fail "expected seven distinct generated secrets"
temp_count="$(find "$(dirname "$VALID_ENV")" -maxdepth 1 -name 'customer.env.tmp.*' -print | wc -l | tr -d '[:space:]')"
[[ "$temp_count" == "0" ]] || fail "temporary file was not cleaned up"

EXISTING_ENV="$TEST_ROOT/existing.env"
printf 'preserve-this-file\n' > "$EXISTING_ENV"
if GOMBEY_CUSTOMER_ENV_PATH="$EXISTING_ENV" bash "$INIT_SCRIPT" \
  chat.example.test ops@example.test >/dev/null 2>&1; then
  fail "initializer overwrote an existing file"
fi
[[ "$(<"$EXISTING_ENV")" == "preserve-this-file" ]] || fail "existing file contents changed"

DANGLING_ENV="$TEST_ROOT/dangling.env"
ln -s "$TEST_ROOT/target-does-not-exist" "$DANGLING_ENV"
if GOMBEY_CUSTOMER_ENV_PATH="$DANGLING_ENV" bash "$INIT_SCRIPT" \
  chat.example.test ops@example.test >/dev/null 2>&1; then
  fail "initializer accepted a dangling symlink"
fi
[[ -L "$DANGLING_ENV" ]] || fail "dangling symlink was altered"
[[ ! -e "$TEST_ROOT/target-does-not-exist" ]] || fail "initializer created the symlink target"

INVALID_ENV="$TEST_ROOT/invalid.env"
if GOMBEY_CUSTOMER_ENV_PATH="$INVALID_ENV" bash "$INIT_SCRIPT" \
  https://chat.example.test ops@example.test >/dev/null 2>&1; then
  fail "initializer accepted a URL instead of a hostname"
fi
[[ ! -e "$INVALID_ENV" ]] || fail "invalid input created an environment file"

echo "customer-init tests passed"
