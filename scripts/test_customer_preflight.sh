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
  local suffix project_name
  suffix="$(printf '%s' "$host" | tr '[:upper:]' '[:lower:]' | tr '.-' '__' | tr -cd 'a-z0-9_' | cut -c1-30)"
  project_name="gombey_${suffix:-customer}"

  printf 'SITE_DOMAIN=%s\nACME_EMAIL=%s\nCOMPOSE_PROJECT_NAME=%s\nALLOW_REGISTRATION=false\nALLOW_PASSWORD_RESET=false\n' \
    "$host" "$email" "$project_name" > "$env_path"
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

# Validate the production Compose stack as well as the loopback-only local
# overlay. Both checks use generated synthetic configuration and start no
# containers.
docker compose --env-file "$VALID_ENV" \
  -f "$SCRIPT_DIR/../deploy/customer/compose.yaml" \
  config --quiet

# Ensure the loopback-only Mac staging overlay inherits the same resource
# ceilings and never publishes the API beyond localhost.
GOMBEY_LOCAL_DATA_ROOT="$TEST_ROOT/local-data" docker compose \
  --env-file "$VALID_ENV" \
  -f "$SCRIPT_DIR/../deploy/customer/compose.yaml" \
  -f "$SCRIPT_DIR/../deploy/customer/compose.local.yaml" \
  config --format json |
python3 -c '
import json
import sys

services = json.load(sys.stdin)["services"]
expected_memory = {
    "api": 2 * 1024**3,
    "mongodb": 1 * 1024**3,
    "meilisearch": 512 * 1024**2,
    "vectordb": 1 * 1024**3,
    "rag_api": 1 * 1024**3,
}
for name, expected in expected_memory.items():
    try:
        actual_memory = int(services.get(name, {}).get("mem_limit"))
    except (TypeError, ValueError):
        actual_memory = None
    if actual_memory != expected:
        raise SystemExit(f"local Compose memory ceiling mismatch for {name}")
api_ports = services["api"].get("ports", [])
if len(api_ports) != 1 or api_ports[0].get("host_ip") != "127.0.0.1":
    raise SystemExit("local Compose API must publish only on loopback")
if "caddy" in services:
    raise SystemExit("local Compose must not include the public Caddy service")
'

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

COPIED_PROJECT_ENV="$TEST_ROOT/copied-project.env"
sed 's/^COMPOSE_PROJECT_NAME=.*/COMPOSE_PROJECT_NAME=gombey_other_customer_0123456789abcdef0123/' \
  "$VALID_ENV" > "$COPIED_PROJECT_ENV"
chmod 600 "$COPIED_PROJECT_ENV"
if GOMBEY_CUSTOMER_ENV_PATH="$COPIED_PROJECT_ENV" bash "$PREFLIGHT_SCRIPT" > "$TEST_ROOT/copied-project.out" 2>&1; then
  fail "preflight accepted a Compose project name copied from another deployment"
fi
grep -Fq "COMPOSE_PROJECT_NAME does not match SITE_DOMAIN" "$TEST_ROOT/copied-project.out" || \
  fail "copied project name failed for the wrong reason"

# Existing deployments created before the scheme marker keep their exact
# legacy project name through upgrades; changing it could create empty volumes.
LEGACY_ENV="$TEST_ROOT/legacy.env"
LEGACY_PROJECT_SUFFIX="$(printf '%s' 'chat.acmeai.com' | tr '[:upper:]' '[:lower:]' | tr '.-' '__' | tr -cd 'a-z0-9_' | cut -c1-30)"
LEGACY_PROJECT_NAME="gombey_${LEGACY_PROJECT_SUFFIX:-customer}"
sed -e '/^GOMBEY_PROJECT_NAME_SCHEME=/d' \
  -e "s/^COMPOSE_PROJECT_NAME=.*/COMPOSE_PROJECT_NAME=$LEGACY_PROJECT_NAME/" \
  "$VALID_ENV" > "$LEGACY_ENV"
chmod 600 "$LEGACY_ENV"
GOMBEY_CUSTOMER_ENV_PATH="$LEGACY_ENV" bash "$PREFLIGHT_SCRIPT" >/dev/null

echo "customer-preflight tests passed"
