# Gombey AI

Private AI Chat for Your Business

This repository supports two deliberately different deployment modes:

- **Cloud/hybrid mode** uses the default `librechat.yaml` and OpenRouter.
- **Private proof mode** uses `librechat.private.yaml` and a local Ollama model. It has an isolated-container option for customer deployments and a host-local option for the Mac test environment.

## Quick Start

```bash
# 1. Clone
git clone https://github.com/BermyBoysTechSolutions/gombey-ai.git
cd gombey-ai

# 2. Configure
cp .env.example .env
# Edit .env with your OpenRouter key

# Optional: create this directory if you enable Google Drive integration.
mkdir -p gdrive

# 3. Deploy
docker-compose up -d
```

## First private-AI proof

The default deployment is not local-only: its model requests go to OpenRouter. To test the stronger private-AI promise, use a separate environment file and Compose override:

```bash
cp .env.private.example .env.private
# Replace the generated-secret placeholders.
# Confirm LOCAL_MODEL exists in the host's Ollama installation.
ollama list

./scripts/private-proof.sh
./scripts/private-model-bootstrap.sh
```

The proof checks that a local model answers successfully, the private LibreChat configuration contains no external model provider, and MongoDB/private services remain on an internal Docker network. The home test configuration points the API at the Mac's existing Ollama install, so all models returned by `ollama list` can be selected without downloading another copy. For an isolated customer deployment, point `OLLAMA_BASE_URL` back to `http://ollama:11434/v1` and use the bootstrap script to download the selected model into the private Ollama container. See [`docs/private-proof.md`](docs/private-proof.md) for the exact boundary and remaining customer-specific checks.

## Admin User Management

Since `ALLOW_REGISTRATION=false`, new accounts must be created manually by the admin.

### Create a new user account

```bash
# Use the helper script
./scripts/create-user.sh username email@example.com password
```

### User Onboarding Flow

1. **Customer pays you** (Stripe, PayPal, etc.)
2. **You create their account** using the script above
3. **Seed approved onboarding files** without logging into their account manually:

   ```bash
   ./scripts/seed-user-files.sh username-or-email proof-fixtures/property-management-pilot
   ```

4. **Send them credentials** — they log in at `chat.gombeytech.com`
5. **They attach the seeded files from My Files when starting the pilot**

The seeding script runs locally as an operator action, targets exactly one username/email, skips duplicate filenames, and stores files in the persistent `uploads_data` volume. It does not create a global file pool or expose files to other users. These are account-owned files, not yet an automatically injected knowledge base for every conversation; a tenant-scoped Agent/RAG layer is the next product step for that behavior.

### Team Accounts

For teams that want shared access:
- **Option A**: Create one shared account (everyone uses same login)
- **Option B**: Create individual accounts per team member (isolated chats)

For true team workspaces (shared chats between users), use Option A for now; full client workspaces can be added later if demand justifies it.

## Configuration

- `.env` - Environment variables
- `librechat.yaml` - Gombey AI model and UI configuration
- `docker-compose.yml` - Deployment orchestration

## Support

Built by [Gombey Tech LLC](https://gombeytech.com)
