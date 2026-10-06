#!/usr/bin/env bash
# Provision a local Ollama model, then remove the temporary outbound route.
# Model downloads are a provisioning action; runtime inference stays on the
# internal gombey-private network.

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${PRIVATE_ENV_FILE:-$ROOT_DIR/.env.private}"
COMPOSE=(docker compose --env-file "$ENV_FILE" -f "$ROOT_DIR/docker-compose.yml" -f "$ROOT_DIR/docker-compose.private.yml")
OLLAMA_CONTAINER="gombey-ai-ollama"

fail() {
  echo "Private model bootstrap failed: $*" >&2
  exit 1
}

read_env_value() {
  local key="$1"
  awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$ENV_FILE"
}

[ -f "$ENV_FILE" ] || fail "copy .env.private.example to .env.private first"
command -v docker >/dev/null 2>&1 || fail "docker is required"

LOCAL_MODEL="$(read_env_value LOCAL_MODEL)"
[ -n "$LOCAL_MODEL" ] || fail "LOCAL_MODEL is missing from $ENV_FILE"

echo "Starting MongoDB and the private Ollama runtime..."
"${COMPOSE[@]}" up -d mongodb ollama

echo "Waiting for Ollama..."
for _ in $(seq 1 30); do
  if docker exec "$OLLAMA_CONTAINER" ollama list >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
docker exec "$OLLAMA_CONTAINER" ollama list >/dev/null 2>&1 \
  || fail "Ollama did not become ready"

echo "Temporarily enabling outbound access to download ${LOCAL_MODEL}..."
docker network connect bridge "$OLLAMA_CONTAINER" 2>/dev/null || true
disconnect_bridge() {
  docker network disconnect bridge "$OLLAMA_CONTAINER" >/dev/null 2>&1 || true
}
trap disconnect_bridge EXIT

docker exec "$OLLAMA_CONTAINER" ollama pull "$LOCAL_MODEL"
disconnect_bridge
trap - EXIT

echo "Starting the Gombey API on the internal network..."
"${COMPOSE[@]}" up -d api

echo "Private model bootstrap complete: ${LOCAL_MODEL} is loaded and Ollama is disconnected from the default bridge network."
