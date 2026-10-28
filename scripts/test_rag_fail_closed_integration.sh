#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="${GOMBEY_TEST_ENV_FILE:-$repo_root/deploy/customer/.env}"
compose_file="$repo_root/deploy/customer/compose.yaml"

if [[ ! -f "$env_file" ]]; then
  echo "Missing private staging environment file: $env_file" >&2
  exit 2
fi

project="gombey-rag-failclosed-$(date -u +%Y%m%d%H%M%S)-$$-$RANDOM"
if [[ ! "$project" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
  echo "Refusing invalid disposable project name: $project" >&2
  exit 2
fi
export COMPOSE_PROJECT_NAME="$project"
compose=(docker compose --project-name "$project" --env-file "$env_file" -f "$compose_file")

existing_containers="$(docker ps -aq --filter "label=com.docker.compose.project=$project")"
existing_volumes="$(docker volume ls -q --filter "label=com.docker.compose.project=$project")"
existing_networks="$(docker network ls -q --filter "label=com.docker.compose.project=$project")"
if [[ -n "$existing_containers$existing_volumes$existing_networks" ]]; then
  echo "Refusing to reuse non-empty test project: $project" >&2
  exit 2
fi

created=false
cleanup() {
  if [[ "$created" == true ]]; then
    project_containers="$(docker ps -aq --filter "label=com.docker.compose.project=$project")"
    project_volumes="$(docker volume ls -q --filter "label=com.docker.compose.project=$project")"
    project_networks="$(docker network ls -q --filter "label=com.docker.compose.project=$project")"
    if [[ -n "$project_containers$project_volumes$project_networks" ]]; then
      "${compose[@]}" down --volumes --remove-orphans >/dev/null
    fi
  fi
}
trap cleanup EXIT

# This key is intentionally invalid and the base URL is loopback-only. The
# failure-path test must never contact an external model or embeddings vendor.
export RAG_OPENAI_API_KEY="gombey-synthetic-invalid-test-key"
export RAG_OPENAI_BASEURL="http://127.0.0.1:9/v1"
"${compose[@]}" config --quiet
created=true
"${compose[@]}" up -d --build rag_api

container="${project}-rag_api-1"
actual_project="$(docker inspect "$container" --format '{{index .Config.Labels "com.docker.compose.project"}}' 2>/dev/null || true)"
if [[ "$actual_project" != "$project" ]]; then
  echo "Disposable service has unexpected Compose project ownership; refusing cleanup." >&2
  exit 1
fi
healthy=false
for _ in {1..60}; do
  health="$(docker inspect "$container" --format '{{.State.Health.Status}}' 2>/dev/null || true)"
  if [[ "$health" == healthy ]]; then
    healthy=true
    break
  fi
  state="$(docker inspect "$container" --format '{{.State.Status}}' 2>/dev/null || true)"
  if [[ "$state" == exited || "$state" == dead ]]; then
    docker logs "$container" 2>&1 | tail -40 >&2
    exit 1
  fi
  sleep 2
done
if [[ "$healthy" != true ]]; then
  echo "Disposable RAG API did not become healthy." >&2
  exit 1
fi

docker exec "$container" python -c 'import requests, sys; response = requests.post("http://127.0.0.1:8000/embed-upload", data={"file_id": "gombey-failclosed-probe", "entity_id": "agent__synthetic-failclosed-test"}, files={"uploaded_file": ("synthetic-failure-probe.txt", b"Synthetic test only. No customer information.", "text/plain")}, timeout=45); print(f"synthetic upload status: {response.status_code}"); sys.exit(0 if response.status_code == 500 else 1)'

rows="$(docker exec "${project}-vectordb-1" sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc "SELECT COUNT(*) FROM langchain_pg_embedding;"')"
if [[ "$rows" != 0 ]]; then
  echo "Expected zero vectors after a failed embedding; found $rows." >&2
  exit 1
fi
echo "Fail-closed integration check passed; failed upload stored zero vectors."

"${compose[@]}" down --volumes --remove-orphans >/dev/null
created=false
if [[ -n "$(docker ps -aq --filter "label=com.docker.compose.project=$project")" || \
      -n "$(docker volume ls -q --filter "label=com.docker.compose.project=$project")" ]]; then
  echo "Disposable test resources remain after cleanup: $project" >&2
  exit 1
fi
echo "Disposable RAG API, database, networks, and volume were removed."
