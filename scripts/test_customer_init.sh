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
grep -qx 'GOMBEY_PROJECT_NAME_SCHEME=sha256-v1' "$VALID_ENV" || fail "project-name scheme marker is missing"
PROJECT_NAME="$(sed -n 's/^COMPOSE_PROJECT_NAME=//p' "$VALID_ENV")"
[[ "$PROJECT_NAME" =~ ^gombey_[a-z0-9_]+_[a-f0-9]{20}$ ]] || fail "Compose project name is not normalized and collision-resistant"
[[ "${#PROJECT_NAME}" -le 63 ]] || fail "Compose project name exceeds 63 characters"

secret_count="$(grep -Ec '^(MONGO_ROOT_PASSWORD|POSTGRES_PASSWORD|MEILI_MASTER_KEY|JWT_SECRET|JWT_REFRESH_SECRET|CREDS_KEY|CREDS_IV)=' "$VALID_ENV")"
unique_secret_count="$(grep -E '^(MONGO_ROOT_PASSWORD|POSTGRES_PASSWORD|MEILI_MASTER_KEY|JWT_SECRET|JWT_REFRESH_SECRET|CREDS_KEY|CREDS_IV)=' "$VALID_ENV" | cut -d= -f2- | sort -u | wc -l | tr -d '[:space:]')"
[[ "$secret_count" == "7" && "$unique_secret_count" == "7" ]] || fail "expected seven distinct generated secrets"
temp_count="$(find "$(dirname "$VALID_ENV")" -maxdepth 1 -name 'customer.env.tmp.*' -print | wc -l | tr -d '[:space:]')"
[[ "$temp_count" == "0" ]] || fail "temporary file was not cleaned up"

# Long hostnames that previously shared the same truncated prefix must still
# resolve to distinct Docker project names.
COLLISION_A_ENV="$TEST_ROOT/collision-a.env"
COLLISION_B_ENV="$TEST_ROOT/collision-b.env"
COLLISION_A_DOMAIN="customer-deployment-gombey-agency-alpha.example.test"
COLLISION_B_DOMAIN="customer-deployment-gombey-agency-bravo.example.test"
OLD_A_SUFFIX="$(printf '%s' "$COLLISION_A_DOMAIN" | tr '[:upper:]' '[:lower:]' | tr '.-' '__' | tr -cd 'a-z0-9_' | cut -c1-30)"
OLD_B_SUFFIX="$(printf '%s' "$COLLISION_B_DOMAIN" | tr '[:upper:]' '[:lower:]' | tr '.-' '__' | tr -cd 'a-z0-9_' | cut -c1-30)"
[[ "$OLD_A_SUFFIX" == "$OLD_B_SUFFIX" ]] || fail "collision fixtures do not reproduce the old truncated-prefix collision"
GOMBEY_CUSTOMER_ENV_PATH="$COLLISION_A_ENV" bash "$INIT_SCRIPT" \
  "$COLLISION_A_DOMAIN" ops@example.test >/dev/null
GOMBEY_CUSTOMER_ENV_PATH="$COLLISION_B_ENV" bash "$INIT_SCRIPT" \
  "$COLLISION_B_DOMAIN" ops@example.test >/dev/null
COLLISION_A_NAME="$(sed -n 's/^COMPOSE_PROJECT_NAME=//p' "$COLLISION_A_ENV")"
COLLISION_B_NAME="$(sed -n 's/^COMPOSE_PROJECT_NAME=//p' "$COLLISION_B_ENV")"
[[ "$COLLISION_A_NAME" != "$COLLISION_B_NAME" ]] || fail "long customer hostnames collided in Compose project naming"

# DNS hostnames are case-insensitive; canonical casing must not fork the same
# deployment into two project names.
CASE_ENV="$TEST_ROOT/case.env"
GOMBEY_CUSTOMER_ENV_PATH="$CASE_ENV" bash "$INIT_SCRIPT" \
  CHAT.EXAMPLE.TEST ops@example.test >/dev/null
CASE_NAME="$(sed -n 's/^COMPOSE_PROJECT_NAME=//p' "$CASE_ENV")"
[[ "$CASE_NAME" == "$PROJECT_NAME" ]] || fail "hostname casing changed the Compose project name"

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
