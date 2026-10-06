# Gombey private-AI proof

This proof separates Gombey's existing cloud mode from a local-only deployment.

## What this proves

The proof is intentionally narrow:

1. Ollama is running on a private host.
2. A named local model can answer a chat request through its OpenAI-compatible API.
3. The model can answer using a synthetic private-document fixture without an external provider.
4. LibreChat is configured with one local endpoint and no external model provider.
5. The Gombey API reaches Ollama and MongoDB over an internal Docker network. The API also has a separate host-facing network solely so the browser UI can be published; the private config contains no external model provider.

This is evidence for **local inference**, not a complete security certification. Backups, identity, physical access, patching, logging, and any later integrations still need a customer-specific review.

The document step is a context smoke test, not a full retrieval-quality evaluation. The next product proof should upload a small synthetic document set through the Gombey UI and measure citation accuracy, retrieval misses, and response latency.

## Run it

```bash
cp .env.private.example .env.private
# Replace the secrets in .env.private.
# Ensure LOCAL_MODEL is already installed in Ollama.
ollama list

./scripts/private-proof.sh
./scripts/private-model-bootstrap.sh
```

The bootstrap script temporarily attaches only the Ollama container to Docker's default bridge so it can download the selected model. It disconnects that route before starting the API. Open `http://localhost:3080` after the containers report healthy. Create a test user with `scripts/create-user.sh`, then use the **Gombey Local** endpoint.

## What is not private mode

The default `docker-compose.yml` plus `librechat.yaml` uses OpenRouter. That is the existing cloud/hybrid deployment and must not be marketed as local-only. Do not add remote model providers or remote tool integrations to `librechat.private.yaml` without reclassifying the deployment as hybrid.

## Customer evidence to collect next

- Model and embedding location
- Network egress policy and exception list
- Storage encryption and backup location
- User/role model and audit-log retention
- Update and rollback procedure
- A small customer document set with repeatable answer-quality tests
