#!/usr/bin/env bash
# Run the first Gombey private-AI proof against a local Ollama model.
# This intentionally does not start or stop Ollama, Docker, or customer data.

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${PRIVATE_ENV_FILE:-$ROOT_DIR/.env.private}"
COMPOSE=(docker compose --env-file "$ENV_FILE" -f "$ROOT_DIR/docker-compose.yml" -f "$ROOT_DIR/docker-compose.private.yml")
MARKER="GOMBEY_LOCAL_ONLY_PROOF"
EXPECTED_FACT="LOCAL_DOCUMENT_FACT_18_MONTHS"
PROOF_DOCUMENT="$ROOT_DIR/proof-fixtures/private-demo-policy.md"

fail() {
  echo "Private proof failed: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

read_env_value() {
  local key="$1"
  awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$ENV_FILE"
}

[ -f "$ENV_FILE" ] || fail "copy .env.private.example to .env.private first"
[ -f "$PROOF_DOCUMENT" ] || fail "proof fixture is missing: $PROOF_DOCUMENT"
require_command curl
require_command jq
require_command docker

OLLAMA_BASE_URL="$(read_env_value OLLAMA_BASE_URL)"
PRIVATE_PROOF_BASE_URL="$(read_env_value PRIVATE_PROOF_BASE_URL)"
LOCAL_MODEL="$(read_env_value LOCAL_MODEL)"
[ -n "$OLLAMA_BASE_URL" ] || fail "OLLAMA_BASE_URL is missing from $ENV_FILE"
[ -n "$PRIVATE_PROOF_BASE_URL" ] || PRIVATE_PROOF_BASE_URL="$OLLAMA_BASE_URL"
[ -n "$LOCAL_MODEL" ] || fail "LOCAL_MODEL is missing from $ENV_FILE"

case "$OLLAMA_BASE_URL" in
  http://localhost:*|http://127.0.0.1:*|http://host.docker.internal:*|http://ollama:*) ;;
  *) fail "private proof only accepts a local Ollama URL, got: $OLLAMA_BASE_URL" ;;
esac

case "$PRIVATE_PROOF_BASE_URL" in
  http://localhost:*|http://127.0.0.1:*|http://host.docker.internal:*|http://ollama:*) ;;
  *) fail "private proof only accepts a local proof URL, got: $PRIVATE_PROOF_BASE_URL" ;;
esac

echo "[1/4] Checking the local model runtime"
OLLAMA_ROOT="${PRIVATE_PROOF_BASE_URL%/v1}"
TAGS_JSON="$(curl --fail --silent --show-error --connect-timeout 3 "$OLLAMA_ROOT/api/tags")" \
  || fail "Ollama is not reachable at $OLLAMA_ROOT"

jq -e --arg model "$LOCAL_MODEL" \
  '(.models // []) | any(.[]; .name == $model or (.name | startswith($model + ":")))' \
  >/dev/null <<<"$TAGS_JSON" \
  || fail "model $LOCAL_MODEL is not installed in Ollama"

echo "[2/4] Sending a proof request to the local model"
DOCUMENT_TEXT="$(<"$PROOF_DOCUMENT")"
REQUEST_JSON="$(jq -n \
  --arg model "$LOCAL_MODEL" \
  --arg marker "$MARKER" \
  --arg expectedFact "$EXPECTED_FACT" \
  --arg document "$DOCUMENT_TEXT" \
  '{model: $model, messages: [
    {role: "system", content: "You are a local-only proof assistant. Do not use tools or external services."},
    {role: "user", content: ("Reply with the marker " + $marker + ". Using only the private document below, include the exact policy identifier " + $expectedFact + " in your answer.\n\nPRIVATE DOCUMENT:\n" + $document)}
  ], temperature: 0, max_tokens: 512}')"

RESPONSE_JSON="$(curl --fail --silent --show-error --connect-timeout 5 \
  -H 'Content-Type: application/json' \
  -d "$REQUEST_JSON" \
  "$PRIVATE_PROOF_BASE_URL/chat/completions")" \
  || fail "local chat completion failed"

RESPONSE_TEXT="$(jq -r '.choices[0].message.content // empty' <<<"$RESPONSE_JSON")"
[ -n "$RESPONSE_TEXT" ] || fail "local model returned no assistant content"
[[ "$RESPONSE_TEXT" == *"$MARKER"* ]] || fail "local model did not return the local proof marker"
[[ "$RESPONSE_TEXT" == *"$EXPECTED_FACT"* ]] || fail "local model did not use the private document fixture"

echo "  Model response: ${RESPONSE_TEXT//$'\n'/ }"

echo "[3/4] Validating the private deployment configuration"
if grep -niE 'openrouter|api\.openai|api\.anthropic|generativelanguage|mcpServers' "$ROOT_DIR/librechat.private.yaml"; then
  fail "private LibreChat config contains a non-local provider or integration"
fi

COMPOSE_CONFIG="$("${COMPOSE[@]}" config)" \
  || fail "private Docker Compose configuration is invalid"
grep -q 'name: gombey-private' <<<"$COMPOSE_CONFIG" \
  || fail "private Docker network is not present"
grep -q 'internal: true' <<<"$COMPOSE_CONFIG" \
  || fail "private Docker network is not marked internal"

echo "[4/4] Proof result"
echo "  PASS: model=${LOCAL_MODEL}"
echo "  PASS: host-side proof request reached local Ollama (${PRIVATE_PROOF_BASE_URL})"
echo "  PASS: private runtime endpoint is internal (${OLLAMA_BASE_URL})"
echo "  PASS: local model used the synthetic private document fixture"
echo "  PASS: private config exposes no external model provider"
echo "  PASS: app containers use an internal Docker network"
echo
echo "Next: start the private UI with:"
echo "  ./scripts/private-model-bootstrap.sh"
