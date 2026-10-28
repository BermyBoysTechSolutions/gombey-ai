#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFLIGHT_SCRIPT="$SCRIPT_DIR/customer-preflight.sh"
INIT_SCRIPT="$SCRIPT_DIR/customer-init.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/gombey-customer-preflight.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  echo "customer-preflight test failed: $*" >&2
  exit 1
}

run_case() {
  local name="$1" host="$2" email="$3" expected="$4"
  local env_path="$TEST_ROOT/$name.env" output_path="$TEST_ROOT/$name.out"

  printf 'SITE_DOMAIN=%s\nACME_EMAIL=%s\nALLOW_REGISTRATION=false\nALLOW_PASSWORD_RESET=false\n' \
    "$host" "$email" > "$env_path"
  chmod 600 "$env_path"

  if GOMBEY_CUSTOMER_ENV_PATH="$env_path" bash "$PREFLIGHT_SCRIPT" >"$output_path" 2>&1; then
    fail "$name unexpectedly passed preflight"
  fi
  grep -Fq "$expected" "$output_path" || fail "$name failed for the wrong reason"
}

run_case staging-host staging.gombey.test staging@example.test \
  "SITE_DOMAIN uses a reserved testing/example domain"
run_case reserved-email chat.customer.com ops@example.test \
  "ACME_EMAIL uses a reserved testing/example domain"
run_case example-com-email chat.customer.com ops@example.com \
  "ACME_EMAIL uses a reserved testing/example domain"
run_case ip-address 127.0.0.1 ops@customer.com \
  "SITE_DOMAIN must be a public hostname"

# A public hostname/email pair must get past these checks and fail later only
# because this intentionally minimal fixture omits provider configuration.
run_case public-host chat.customer.com ops@customer.com \
  "required provider setting OPENAI_API_KEY is missing or empty"

VALID_ENV="$TEST_ROOT/valid/deploy/customer.env"
GOMBEY_CUSTOMER_ENV_PATH="$VALID_ENV" bash "$INIT_SCRIPT" \
  chat.acmeai.com ops@acmeai.com "Synthetic Preflight" >/dev/null
sed 's/^RAG_OPENAI_API_KEY=.*/RAG_OPENAI_API_KEY=test-only-not-a-real-key/' \
  "$VALID_ENV" > "$VALID_ENV.tmp"
chmod 600 "$VALID_ENV.tmp"
mv "$VALID_ENV.tmp" "$VALID_ENV"
GOMBEY_CUSTOMER_ENV_PATH="$VALID_ENV" bash "$PREFLIGHT_SCRIPT" >/dev/null

BAD_SECRET_ENV="$TEST_ROOT/bad-secret.env"
sed 's/^JWT_SECRET=.*/JWT_SECRET=short/' "$VALID_ENV" > "$BAD_SECRET_ENV"
chmod 600 "$BAD_SECRET_ENV"
if GOMBEY_CUSTOMER_ENV_PATH="$BAD_SECRET_ENV" bash "$PREFLIGHT_SCRIPT" > "$TEST_ROOT/bad-secret.out" 2>&1; then
  fail "preflight accepted a short JWT secret"
fi
grep -Fq "security secret JWT_SECRET must be 64 hexadecimal characters" "$TEST_ROOT/bad-secret.out" || \
  fail "short JWT secret failed for the wrong reason"

MONGO_SECRET="$(sed -n 's/^MONGO_ROOT_PASSWORD=//p' "$VALID_ENV" | head -n 1)"
DUPLICATE_SECRET_ENV="$TEST_ROOT/duplicate-secret.env"
sed "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$MONGO_SECRET/" "$VALID_ENV" > "$DUPLICATE_SECRET_ENV"
chmod 600 "$DUPLICATE_SECRET_ENV"
if GOMBEY_CUSTOMER_ENV_PATH="$DUPLICATE_SECRET_ENV" bash "$PREFLIGHT_SCRIPT" > "$TEST_ROOT/duplicate-secret.out" 2>&1; then
  fail "preflight accepted duplicate database secrets"
fi
grep -Fq "security secrets must be unique" "$TEST_ROOT/duplicate-secret.out" || \
  fail "duplicate secrets failed for the wrong reason"

echo "customer-preflight tests passed"
