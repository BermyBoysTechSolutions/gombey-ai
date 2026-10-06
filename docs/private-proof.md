# Gombey private-AI proof

This proof separates Gombey's existing cloud mode from a local Ollama deployment.

## What this proves

The proof is intentionally narrow:

1. Ollama is running locally, either in the isolated private container or on the Mac host for home testing.
2. A named local model can answer a chat request through its OpenAI-compatible API.
3. The model can answer using a synthetic private-document fixture without an external provider.
4. LibreChat is configured with one local endpoint and no external model provider.
5. MongoDB and the private services use an internal Docker network. In isolated mode the API reaches Ollama on that network; in home host-local mode the API reaches the Mac's loopback Ollama through Docker's host gateway. The private config contains no external model provider.

This is evidence for **local inference**, not a complete security certification. Host-local mode proves the model stays on the Mac but does not prove the stronger isolated-container network boundary. Backups, identity, physical access, patching, logging, and any later integrations still need a customer-specific review.

The document step is a context smoke test, not a full retrieval-quality evaluation. The next product proof should upload a small synthetic document set through the Gombey UI and measure citation accuracy, retrieval misses, and response latency.

## Run it

```bash
cp .env.private.example .env.private
# Replace the secrets in .env.private.
# Ensure LOCAL_MODEL is already installed in the Mac's Ollama for home testing.
ollama list

./scripts/private-proof.sh
./scripts/private-model-bootstrap.sh
```

For the home test configuration, `OLLAMA_BASE_URL` points to `host.docker.internal`, so LibreChat can fetch every model shown by the Mac's `ollama list`. Open `http://localhost:3080` after the containers report healthy. Create a test user with `scripts/create-user.sh`, then use the **Gombey Local** endpoint and select a small model such as `gemma4:latest`.

For an isolated customer deployment, change `OLLAMA_BASE_URL` to `http://ollama:11434/v1` before starting the API. The bootstrap script temporarily attaches only the Ollama container to Docker's default bridge so it can download the selected model, disconnects that route, and then starts the API. In that mode only models installed in the private Ollama volume are available.

## What is not private mode

The default `docker-compose.yml` plus `librechat.yaml` uses OpenRouter. That is the existing cloud/hybrid deployment and must not be marketed as local-only. Do not add remote model providers or remote tool integrations to `librechat.private.yaml` without reclassifying the deployment as hybrid.

## Customer evidence to collect next

- Model and embedding location
- Network egress policy and exception list
- Storage encryption and backup location
- User/role model and audit-log retention
- Update and rollback procedure
- A small customer document set with repeatable answer-quality tests
