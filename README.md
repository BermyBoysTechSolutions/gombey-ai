# Gombey AI

Private AI Chat for Your Business

This repository supports two deliberately different deployment modes:

- **Cloud/hybrid mode** uses the default `librechat.yaml` and OpenRouter.
- **Private proof mode** uses `librechat.private.yaml` and a local Ollama model. It is the mode to use when the promise is that inference stays inside the customer's environment.

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

The proof checks that a local model answers successfully, the private LibreChat configuration contains no external model provider, and the app containers use an internal Docker network. The bootstrap script temporarily gives only the Ollama container outbound access to download the selected model, disconnects it from the default bridge, and then starts the API. See [`docs/private-proof.md`](docs/private-proof.md) for the exact boundary and remaining customer-specific checks.

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
3. **Send them credentials** — they log in at `chat.gombeytech.com`
4. **They start using Gombey AI**

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
