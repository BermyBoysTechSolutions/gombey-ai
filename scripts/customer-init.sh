#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CUSTOMER_ENV="${GOMBEY_CUSTOMER_ENV_PATH:-$REPO_DIR/deploy/customer/.env}"

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 <chat-domain> <ops-email> [brand-name]" >&2
  exit 2
fi

SITE_DOMAIN="$1"
ACME_EMAIL="$2"
BRAND_NAME="${3:-Gombey AI}"

HOSTNAME_RE='^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$'
if [[ ! "$SITE_DOMAIN" =~ $HOSTNAME_RE ]]; then
  echo "Error: chat-domain must be a valid hostname only (no scheme, path, or wildcard)." >&2
  exit 2
fi
if [[ ! "$ACME_EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
  echo "Error: provide a valid email address for TLS certificate notices." >&2
  exit 2
fi
if [[ ! "$BRAND_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9\ .-]{0,47}$ ]]; then
  echo "Error: brand-name may contain only letters, numbers, spaces, periods, and hyphens." >&2
  exit 2
fi
if [[ -e "$CUSTOMER_ENV" || -L "$CUSTOMER_ENV" ]]; then
  echo "Error: $CUSTOMER_ENV already exists; refusing to overwrite secrets." >&2
  exit 1
fi
mkdir -p "$(dirname "$CUSTOMER_ENV")"
if ! command -v openssl >/dev/null 2>&1; then
  echo "Error: openssl is required to generate deployment secrets." >&2
  exit 1
fi

DOMAIN_CANONICAL="$(printf '%s' "$SITE_DOMAIN" | tr '[:upper:]' '[:lower:]')"
PROJECT_SUFFIX="$(printf '%s' "$DOMAIN_CANONICAL" | tr '.-' '__' | tr -cd 'a-z0-9_' | cut -c1-22)"
DOMAIN_HASH="$(printf '%s' "$DOMAIN_CANONICAL" | openssl dgst -sha256 | awk '{print substr($NF, 1, 20)}')"
PROJECT_NAME="gombey_${PROJECT_SUFFIX:-customer}_${DOMAIN_HASH}"
MONGO_PASSWORD="$(openssl rand -hex 32)"
POSTGRES_PASSWORD="$(openssl rand -hex 32)"
MEILI_MASTER_KEY="$(openssl rand -hex 32)"
JWT_SECRET="$(openssl rand -hex 32)"
JWT_REFRESH_SECRET="$(openssl rand -hex 32)"
CREDS_KEY="$(openssl rand -hex 32)"
CREDS_IV="$(openssl rand -hex 16)"

umask 077
TEMP_ENV="$(mktemp "${CUSTOMER_ENV}.tmp.XXXXXX")"
trap 'if [[ -n "${TEMP_ENV:-}" ]]; then rm -f "$TEMP_ENV"; fi' EXIT
{
  printf 'COMPOSE_PROJECT_NAME=%s\n' "$PROJECT_NAME"
  printf 'GOMBEY_PROJECT_NAME_SCHEME=sha256-v1\n'
  printf 'SITE_DOMAIN=%s\n' "$SITE_DOMAIN"
  printf 'ACME_EMAIL=%s\n' "$ACME_EMAIL"
  printf 'GOMBEY_BRAND_NAME=%s\n' "$BRAND_NAME"
  printf 'GOMBEY_BRAND_DESCRIPTION=Dedicated AI workspace for your business\n'
  printf 'LIBRECHAT_IMAGE=ghcr.io/librechat-ai/librechat:v0.8.8\n'
  printf 'RAG_API_IMAGE=registry.librechat.ai/librechat-ai/librechat-rag-api-dev-lite:latest@sha256:3577689eedb1a74d4de69d70cee70b4cd42a9375ad74cdd5238ffc19a97392e3\n'
  printf 'MONGO_IMAGE=mongo:8.0.20\nMEILI_IMAGE=getmeili/meilisearch:v1.35.1\n'
  printf 'VECTORDB_IMAGE=pgvector/pgvector:0.8.0-pg15-trixie\nCADDY_IMAGE=caddy:2.10.2-alpine\n'
  printf 'MONGO_ROOT_USERNAME=gombey-root\nMONGO_ROOT_PASSWORD=%s\n' "$MONGO_PASSWORD"
  printf 'MONGO_DATABASE=GombeyAI\nPOSTGRES_DB=rag_db\nPOSTGRES_USER=rag_user\nPOSTGRES_PASSWORD=%s\n' "$POSTGRES_PASSWORD"
  printf 'MEILI_MASTER_KEY=%s\nJWT_SECRET=%s\nJWT_REFRESH_SECRET=%s\n' "$MEILI_MASTER_KEY" "$JWT_SECRET" "$JWT_REFRESH_SECRET"
  printf 'CREDS_KEY=%s\nCREDS_IV=%s\n' "$CREDS_KEY" "$CREDS_IV"
  printf 'OPENAI_API_KEY=user_provided\n'
  printf 'OPENAI_MODELS=gpt-6.1-sol,gpt-6-sol,gpt-6-luna,gpt-6-astra,gpt-5.6,gpt-5.6-luna,gpt-5.5,gpt-5.4,gpt-5.4-mini,gpt-4.1,gpt-4.1-mini,o3,o4-mini\n'
  printf 'ANTHROPIC_API_KEY=user_provided\n'
  printf 'ANTHROPIC_MODELS=claude-sonnet-5,claude-opus-5,claude-sonnet-4-6,claude-opus-4-6\n'
  printf 'GOOGLE_KEY=user_provided\n'
  printf 'GOOGLE_MODELS=gemini-3.8-flash,gemini-3.7-flash,gemini-3.6-flash,gemini-3.5-flash,gemini-3.5-flash-lite,gemini-3.1-pro-preview,gemini-2.5-pro,gemini-2.5-flash\n'
  printf 'OPENROUTER_KEY=user_provided\n'
  printf 'RAG_OPENAI_API_KEY=REPLACE_WITH_CUSTOMER_OWNED_EMBEDDINGS_API_KEY\n'
  printf 'RAG_OPENAI_BASEURL=https://openrouter.ai/api/v1\n'
  printf 'EMBEDDINGS_PROVIDER=openai\nEMBEDDINGS_MODEL=openai/text-embedding-3-small\n'
  printf 'ALLOW_REGISTRATION=false\nALLOW_PASSWORD_RESET=false\n'
} > "$TEMP_ENV"

chmod 600 "$TEMP_ENV"
if ! ln "$TEMP_ENV" "$CUSTOMER_ENV" 2>/dev/null; then
  echo "Error: $CUSTOMER_ENV appeared during initialization; refusing to overwrite." >&2
  exit 1
fi
rm -f "$TEMP_ENV"
TEMP_ENV=""
trap - EXIT
echo "Created $CUSTOMER_ENV with unique secrets and restrictive file permissions."
echo "Next: keep provider keys set to user_provided for per-user BYOK, or enter customer-owned shared keys in the file."
echo "Set the separate customer-owned RAG_OPENAI_API_KEY, point DNS at the VPS, then follow deploy/customer/README.md."
