# Gombey AI

Private AI Chat for Your Business

> **Deployment boundary:** The repository-root Compose setup and the Mac Mini
> instance are development/demo environments, not customer onboarding or a
> production service. For the current paid Cloud Workspace scope, use
> [`deploy/customer/README.md`](deploy/customer/README.md) and the evidence in
> [`docs/mvp-readiness-2026-10-27.md`](docs/mvp-readiness-2026-10-27.md).
> Do not load customer data into the Mac demo.

This repository supports two deliberately different deployment modes:

- **Cloud/hybrid mode** uses the default `librechat.yaml` and OpenRouter.
- **Legacy private proof mode** uses `librechat.private.yaml` and local Ollama for synthetic experiments. It is not the production customer template or proof that a Mac Studio, DGX Spark, or other workstation offer has passed workload, access, backup, and recovery acceptance.

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

The proof checks that a local model answers successfully, the private LibreChat configuration contains no external model provider, and MongoDB/private services remain on an internal Docker network. In home mode, the API points at a local document gateway, which converts PDF attachments to text before forwarding the request to the Mac's Ollama install; all models returned by `ollama list` remain available without downloading another copy. For an isolated customer deployment, keep the API pointed at the gateway, set `OLLAMA_UPSTREAM_URL=http://ollama:11434`, and use the bootstrap script to download the selected model into the private Ollama container. See [`docs/private-proof.md`](docs/private-proof.md) for the exact boundary and remaining customer-specific checks.

## Local synthetic-demo account management

The scripts below manage accounts in the repository-root Mac demo only. Use
them for disposable synthetic tests; they are not the customer provisioning
procedure. Customer accounts belong in a fresh dedicated deployment from
`deploy/customer/` after its production acceptance gates pass.

### Create a new user account

```bash
# Use the helper script
./scripts/create-user.sh username email@example.com password

# Or create the account and seed the pilot files in one step
./scripts/create-user.sh username email@example.com password proof-fixtures/property-management-pilot
```

### Synthetic test flow

1. Create a disposable test account using the script above.
2. To seed that same test account with the legacy fictional property-management fixture, pass the fixture directory as the optional fourth argument.
3. For an existing synthetic account, seed the fixture with:

   ```bash
   ./scripts/seed-user-files.sh username-or-email proof-fixtures/property-management-pilot
   ```

4. Sign in only at the local loopback URL documented for the selected demo stack.
5. Attach the synthetic files from My Files when running the old local-model test.

The seeding script runs locally as an operator action, targets exactly one username/email, skips duplicate filenames, and stores files in the persistent `uploads_data` volume. It does not create a global file pool. The property-management files are legacy synthetic fixtures, not the selected current outreach niche or a customer offer. The customer template uses a dedicated per-customer RAG store and admin-managed shared agent; it does not turn the Mac demo into a team tenant.

### Current customer deployment boundary

The Mac Mini demo remains a personal/testing instance; it is not the customer deployment. The current public packages are Cloud Workspace, Workspace Appliance, and Private Local AI. The first paid Cloud scope is a dedicated deployment per customer with up to five named accounts, an admin-managed shared File Search agent, and customer-owned model and embeddings billing. Gombey provisions employee accounts; self-service invitations are not included. Member chats remain private, and shared knowledge is used only when a member selects the shared agent.

The owner-confirmed offer ladder is intentional and distinguishes where the
workspace runs from where model inference runs:

- **Cloud Workspace:** the customer's isolated Gombey deployment runs on a
  dedicated VPS; model inference is cloud-based through the customer's chosen
  provider.
- **Workspace Appliance:** the workspace is deployed on-site on a Beelink
  SER5 Mini PC, while model inference remains cloud-based through the
  customer's chosen provider. The SER5 is not, by itself, a local-inference
  promise.
- **Private Local AI:** a selected customer workstation—such as a Mac Studio,
  NVIDIA DGX Spark, or AMD Strix Halo system—runs the accepted local model.
  Benchmark the agreed workload on the actual hardware before promising model
  quality or performance. Local model inference alone does not establish that
  embeddings, backups, telemetry, updates, or optional integrations stay
  local; verify and disclose each data path separately.

`deploy/customer/` currently provides the dedicated Cloud Workspace template.
The Appliance and Private Local AI tiers require commissioning and acceptance
on the actual selected hardware; follow the [hardware-tier acceptance
checklist](deploy/customer/HARDWARE-TIER-ACCEPTANCE.md) and the tier-specific
open gates in the [readiness record](docs/mvp-readiness-2026-10-27.md). This is
a delivery-status distinction, not a change to the intended tier mapping.

Loopback tests have verified role boundaries, member File Search answers/citations with temporary test credentials, separate local deployment stores, and encrypted backup/restore on synthetic data. This is not production approval: persistent customer-owned embeddings configuration, visible-browser acceptance, Stripe test-mode billing, and public VPS/DNS/TLS/firewall/reboot/off-host-restore checks remain open. See the current readiness record before any customer data is accepted.

## Configuration

- `.env` - Environment variables
- `librechat.yaml` - Gombey AI model and UI configuration
- `docker-compose.yml` - Deployment orchestration

## Support

Built by [Gombey Tech LLC](https://gombeytech.com)
