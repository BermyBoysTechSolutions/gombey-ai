#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CUSTOMER_DIR="$REPO_DIR/deploy/customer"
CUSTOMER_ENV="$CUSTOMER_DIR/.env"

fail() {
  echo "Customer deployment preflight failed: $*" >&2
  exit 1
}

[[ -f "$CUSTOMER_ENV" ]] || fail "deploy/customer/.env is missing; run scripts/customer-init.sh first"
if ENV_MODE="$(stat -c '%a' "$CUSTOMER_ENV" 2>/dev/null)"; then
  :
elif ENV_MODE="$(stat -f '%Lp' "$CUSTOMER_ENV" 2>/dev/null)"; then
  :
else
  fail "could not check deploy/customer/.env permissions"
fi
[[ "$ENV_MODE" == "600" ]] || fail "deploy/customer/.env must be mode 600; run chmod 600 deploy/customer/.env"
grep -q '^ALLOW_REGISTRATION=false$' "$CUSTOMER_ENV" || fail "public registration must remain disabled"
grep -q '^ALLOW_PASSWORD_RESET=false$' "$CUSTOMER_ENV" || fail "password reset must remain disabled until secure email is configured"
for setting in OPENAI_API_KEY OPENAI_MODELS ANTHROPIC_API_KEY ANTHROPIC_MODELS GOOGLE_KEY GOOGLE_MODELS OPENROUTER_KEY RAG_OPENAI_API_KEY RAG_OPENAI_BASEURL EMBEDDINGS_MODEL; do
  setting_line="$(grep -m 1 "^${setting}=" "$CUSTOMER_ENV" || true)"
  [[ -n "$setting_line" && "${setting_line#*=}" != "" ]] || fail "required provider setting ${setting} is missing or empty"
done
if grep -Eq 'REPLACE_ME|REPLACE_WITH_CUSTOMER_OWNED_EMBEDDINGS_API_KEY|chat\.customer\.example|ops@example\.com' "$CUSTOMER_ENV"; then
  fail "replace the sample domain/email and the customer-owned embeddings API key placeholder"
fi

command -v python3 >/dev/null 2>&1 || fail "python3 is required to inspect the rendered Compose configuration"

docker compose \
  --env-file "$CUSTOMER_ENV" \
  -f "$CUSTOMER_DIR/compose.yaml" \
  config --format json |
python3 -c '
import json
import sys

config = json.load(sys.stdin)
services = config.get("services", {})
published = {name for name, service in services.items() if service.get("ports")}
if published != {"caddy"}:
    print("Customer deployment preflight failed: only Caddy may publish host ports.", file=sys.stderr)
    raise SystemExit(1)

ports = services["caddy"].get("ports", [])
allowed = {(80, 80, "tcp"), (443, 443, "tcp"), (443, 443, "udp")}
actual = set()
for port in ports:
    try:
        actual.add((int(port["published"]), int(port["target"]), port.get("protocol", "tcp")))
    except (KeyError, TypeError, ValueError):
        print("Customer deployment preflight failed: unrecognized Caddy port mapping.", file=sys.stderr)
        raise SystemExit(1)
if not actual or not actual.issubset(allowed) or (80, 80, "tcp") not in actual or (443, 443, "tcp") not in actual:
    print("Customer deployment preflight failed: Caddy may publish only TCP 80/443 and optional UDP 443.", file=sys.stderr)
    raise SystemExit(1)
'

echo "Preflight passed: secret-file checks are clean, Compose resolves, and only Caddy publishes web ports. This does not verify DNS, provider credentials, runtime health, or account isolation."
