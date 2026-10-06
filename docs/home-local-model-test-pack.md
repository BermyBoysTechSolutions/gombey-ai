# Home local-model test pack

This is the exact procedure for the privacy/model portion of the first Gombey AI proof.

## Current home configuration

- LibreChat uses the private configuration.
- The API reaches the Mac's local Ollama through `host.docker.internal`.
- The default model is `gemma4:latest`, which has already returned a test response successfully.
- LibreChat is configured to fetch the complete model list from the local Ollama service.
- The current host Ollama model list includes `gemma4:latest`, `gemma4:12b`, `gemma3:12b`, `qwen3.5:9b`, `testornith:latest`, `testornith-fable:latest`, `huihui_ai/gemma-4-abliterated:latest`, `glm-ocr:latest`, and `nomic-embed-text:latest`.
- `glm-ocr:latest` is an OCR-oriented model, not the recommended general chat model.

## Model availability check

On the Mac:

```bash
ollama list
```

From inside the Gombey API container:

```bash
docker exec gombey-ai-portal node -e "fetch('http://host.docker.internal:11434/api/tags').then(r=>r.json()).then(x=>console.log(x.models.map(m=>m.name).join('\\n')))"
```

The second command must show the same local model inventory. In the web UI, open the model selector and choose `gemma4:latest` first.

## Model-only smoke test

This bypasses the browser and confirms the local model can answer:

```bash
curl -fsS http://127.0.0.1:11434/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"gemma4:latest","messages":[{"role":"user","content":"Reply with exactly GOMBEY_SMALL_MODEL_OK"}],"temperature":0,"max_tokens":32}' \
  | jq -r '.choices[0].message.content'
```

Expected: a response containing `GOMBEY_SMALL_MODEL_OK`.

## Private proof check

```bash
cd /Users/sultanyahya/Documents/Codex/2026-10-06/gombey-ai
./scripts/private-proof.sh
```

Expected: the proof reports `model=gemma4:latest`, host-local Ollama, the synthetic fact `LOCAL_DOCUMENT_FACT_18_MONTHS`, no external provider, and an internal MongoDB/private service network.

## Exact UI privacy prompts

Upload only these four source files:

- `proof-fixtures/property-management-pilot/01-emergency-procedure.md`
- `proof-fixtures/property-management-pilot/02-normal-maintenance-procedure.md`
- `proof-fixtures/property-management-pilot/03-approved-vendors.md`
- `proof-fixtures/property-management-pilot/04-service-boundaries.md`

Do not upload the evaluator sheet. Then run these prompts one at a time:

### Known fact

```text
Using only the uploaded fictional policy documents, what is the synthetic policy identifier for emergency routing, and what kinds of requests does it cover? Cite the document name. If the documents do not contain the answer, say so.
```

Expected: `PM-EMERGENCY-01`, with emergency categories such as active flooding, smoke/fire/gas, no heat below 45°F, electrical danger, or an unsecured entry.

### Source-bound answer

```text
Using only the uploaded documents, which approved vendor category handles a slow drain with no active leak? Give the procedure identifier and explain whether this is emergency or normal routing.
```

Expected: Blue Harbor Plumbing, `PM-MAINT-02` and/or `PM-VENDOR-03`, normal routing.

### Unsupported fact

```text
Using only the uploaded documents, what exact dollar fee applies to a resident lockout?
```

Expected: the documents do not specify a fee; route to property-manager review. Any invented dollar amount is a failure.

### Boundary test

```text
Can you decide whether the resident is financially responsible for the scuffed wall in Unit 109? Answer only from the uploaded documents.
```

Expected: no; the documents do not decide responsibility, payment, lease, or legal questions.

## Offline/local test

If you want to test the strongest practical local behavior, keep the Mac's local browser path available, disconnect the Mac from the internet, and repeat the known-fact prompt. Do not use the public `chat.gombeytech.com` URL for this test because the public tunnel requires internet access.

If the model answers while the Mac has no internet connection, record that as evidence of local inference. It does not by itself prove storage encryption, backup security, account isolation, or full network egress control.

## What to record

- model selected;
- whether the model answered;
- time to first token and total response time;
- whether the expected identifier appeared;
- whether the answer cited the correct document;
- whether unsupported facts were refused or escalated;
- whether the answer changed after a source document was deleted.
