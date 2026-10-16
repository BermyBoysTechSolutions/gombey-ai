# Gombey AI customer pilot deployment

This is the reusable, single-customer deployment template. Each customer gets a separate VPS, Docker Compose project, MongoDB database, PostgreSQL/pgvector store, upload volume, secrets, and chat hostname. Do not combine customers in one Compose project or LibreChat database. The Gombey hosting operator retains VPS-level access; call this an isolated dedicated deployment, not customer-controlled hosting.

## Included in this MVP

- HTTPS chat app behind Caddy; only ports 80 and 443 are published.
- Individual accounts for the customer's administrator and members. Public registration is disabled; Gombey provisions member accounts by a controlled command.
- Customer-owned model billing: employees can bring their own OpenAI, Anthropic, Google, or OpenRouter API key, or the customer can configure a provider key centrally for the instance. ChatGPT subscriptions are not API keys and are not used by this deployment.
- One separate customer-owned embeddings API key for shared document search. The default is OpenRouter's OpenAI-compatible embeddings endpoint; it can be changed to a compatible embeddings provider. Per-user chat keys are not automatically available to the RAG service.
- The customer's administrator can maintain one shared File Search agent by uploading/updating its source documents and sharing it as Viewer with the `USER` role. Members can use that shared knowledge, while their chats remain their own.
- Separate Docker volumes and databases for every customer. MongoDB and pgvector have no published host ports; the app and RAG services get outbound access needed for model/embedding requests.
- Password reset is disabled until a verified SMTP or Mailgun service is configured; a trusted operator can perform a reset through LibreChat's supported prompt-based command.
- Gombey branding by default. The brand title/description are configuration values; full custom theme work is outside this pilot template.

This is an isolated hosted deployment, not local-only inference. Prompts and retrieved document excerpts go to the model provider selected for each chat. If OpenRouter is selected, requests also pass through OpenRouter to the selected upstream model provider. Document text is sent to the configured embeddings provider. The customer owns and pays these provider accounts. Do not promise that data stays on the VPS or that this is a compliance certification; the customer must review the selected providers' data handling terms.

This template uses the published LibreChat v0.8.8 image with its RAG API and PostgreSQL/pgvector. The companion RAG image digest is pinned to its verified Linux/amd64 manifest. `compose.yaml` applies two fail-closed compatibility fixes at API startup. `patches/librechat-vector-crud.js` scopes shared-agent vector deletion to each file's recorded `metadata.embeddedEntities`; upstream v0.8.8 otherwise deletes only by uploader. `patches/librechat-agent-route.js` explicitly passes `false` to the basic agent-view handler; without that wrapper, Express passes its `next` function as the handler's third argument, which LibreChat interprets as a request for the expanded editor/configuration response. The patch script refuses to start if the pinned upstream source no longer matches its expected shape. Keep the LibreChat image pinned and revalidate both patches whenever upgrading it. New customer installs use the dedicated single-customer deployment described here; this template does not enable LibreChat's pooled tenant mode. An existing v0.8.7 database needs LibreChat's tenant-index migration before upgrading to v0.8.8; take a backup and follow the official migration guide rather than simply replacing the image.

The Compose template runs one API replica per customer and enables the single-process scheduler guard so schedule writes work on a dedicated VPS without Redis. Do not scale the API beyond one replica unless Redis Streams are configured and `SCHEDULES_SINGLE_PROCESS` is disabled; otherwise each replica could disagree about active jobs.

## Workspace and isolation model

- Isolation between customers comes from separate VPSs, Compose projects, databases, volumes, and secrets. This is the MVP's customer boundary; do not put multiple customers into one unscoped LibreChat instance.
- Inside one customer's deployment, the customer owner is the instance administrator. Employees receive individual `USER` accounts. The owner maintains the shared Company Knowledge Assistant and shares it as Viewer with the `USER` role. The assistant's approved File Search corpus is shared; ordinary member accounts cannot see one another's private chats or personal files. The customer administrator and Gombey's VPS operator are privileged parties, so do not describe employee data as inaccessible to admins or the hosting operator.
- This is a shared knowledge workspace, not a shared inbox or a promise that employees can read one another's chats. LibreChat Projects are currently documented as personal to their creator, so do not sell them as shared team folders. Shared links are for selectively sharing conversation copies, not team collaboration.
- Gombey currently provisions and revokes employee accounts using the supported operator command. The customer administrator can control the shared assistant and its source files in the chat app, but self-service invitations and a customer-facing user-management portal are not included in this MVP.
- LibreChat v0.8.8 has tenant-aware isolation features, but using them for pooled multi-customer hosting requires a trusted source of tenant context on authentication requests, strict isolation settings, and trusted tenant-admin provisioning. Merely enabling a strict-mode flag or accepting a client-supplied tenant header is unsafe. Keep pooled hosting out of scope until that separate design and cross-tenant tests are complete.

## Create a deployment configuration

On the VPS, clone this repository into a customer-specific directory, then run:

```bash
./scripts/customer-init.sh chat.customer-domain.com ops@your-company.com
```

The script creates a mode-600 `deploy/customer/.env` with new, per-customer secrets. It never prints them and refuses to overwrite an existing file. By default, the direct provider variables and `OPENROUTER_KEY` are `user_provided`: each employee enters their own API key in LibreChat, where the key is stored encrypted to that employee's account. To use a customer-owned shared chat key instead, replace `user_provided` with the actual customer key in the matching variable; that routes all users of that endpoint through the customer's account. Never use a Gombey-owned key for client usage.

Document search needs a separate server-side embeddings key because LibreChat's RAG service cannot reuse an employee's private chat key. Add the customer's key to `RAG_OPENAI_API_KEY`; the default `RAG_OPENAI_BASEURL` is `https://openrouter.ai/api/v1` and the default embedding model is `openai/text-embedding-3-small`. If the customer wants another compatible embeddings service, set the base URL and model accordingly. Do not put keys in GitHub, tickets, screenshots, or outreach notes. A ChatGPT subscription is not an API key.

Direct OpenAI, Anthropic, and Google model lists are curated fallback catalogs in `.env`; check and update them when providers rename or retire models. OpenRouter's model catalog is fetched dynamically. Users can only call models their own key or the customer's shared key is authorized to use.

Run the preflight after entering the customer's embeddings key and actual hostname (and any optional centrally shared chat keys):

```bash
./scripts/customer-preflight.sh
```

It checks that the template placeholders are gone, registration and password reset remain disabled, Docker Compose can render the configuration, and Caddy is the only service publishing the allowed web ports. The VPS needs Docker Compose and Python 3 for this check. It does not prove DNS, provider credentials, runtime health, or data isolation.

Create a DNS `A` record for the chat hostname pointing to the VPS IPv4 address. Open inbound TCP 80/443 and UDP 443; restrict SSH to the operator's IP where practical. Make sure the VPS has at least 8 GB RAM for this cloud-model stack. A small VPS is not suitable for running a frontier local model.

### Create the first administrator safely

The first account on this unscoped, dedicated instance becomes its administrator. Do not expose an open signup page to the public. Instead, use the bootstrap Compose overlay, which publishes the API only on the VPS loopback interface and enables signup only for this temporary phase:

```bash
docker compose --env-file deploy/customer/.env \
  -f deploy/customer/compose.yaml \
  -f deploy/customer/compose.bootstrap.yaml config --quiet
docker compose --env-file deploy/customer/.env \
  -f deploy/customer/compose.yaml \
  -f deploy/customer/compose.bootstrap.yaml up -d
```

From the operator's computer, open an SSH tunnel to the VPS and visit `http://localhost:3080`:

```bash
ssh -N -L 3080:127.0.0.1:3080 <operator>@<vps-address>
```

Register the designated customer owner as the first account. It receives the `ADMIN` role. Then stop the bootstrap stack before starting the public deployment:

```bash
docker compose --env-file deploy/customer/.env \
  -f deploy/customer/compose.yaml \
  -f deploy/customer/compose.bootstrap.yaml down
```

The normal `.env` keeps `ALLOW_REGISTRATION=false`, and the normal Compose file does not publish the API port. Do not change those protections. The bootstrap overlay binds only to `127.0.0.1`; do not alter it to `0.0.0.0`.

For local staging, chat-provider BYOK keys are entered by each authorized test
user in LibreChat; do not put personal or future-client chat keys in the shared
environment file. The separate server-side embeddings key is entered at a
hidden prompt with `python3 scripts/set_rag_embeddings_key.py`. Use only a newly
rotated, low-limit test key; the helper updates only `RAG_OPENAI_API_KEY`,
requires an owner-owned mode-600 file, and never displays the value. Afterward,
recreate only the local RAG API service for the key to take effect:

```bash
GOMBEY_LOCAL_DATA_ROOT="/Volumes/Mac Mini SSD/Gombey AI Local Staging" \
  docker compose --env-file deploy/customer/.env \
  -f deploy/customer/compose.yaml -f deploy/customer/compose.local.yaml \
  up -d --force-recreate rag_api
```

Do not paste keys into chat, shell arguments, screenshots, or repository files.

### Validate and start the public deployment

Validate the rendered Compose configuration before starting:

```bash
docker compose --env-file deploy/customer/.env -f deploy/customer/compose.yaml config --quiet
```

Then start it:

```bash
docker compose --env-file deploy/customer/.env -f deploy/customer/compose.yaml up -d
docker compose --env-file deploy/customer/.env -f deploy/customer/compose.yaml ps
```

Caddy obtains the HTTPS certificate after the DNS record resolves. Only Caddy publishes host ports. Do not publish the API, MongoDB, Meilisearch, PostgreSQL, or RAG API ports.

## Add employees and confirm roles

Use LibreChat's supported prompt-based command to add each employee after the owner account is active:

```bash
docker compose --env-file deploy/customer/.env \
  -f deploy/customer/compose.yaml exec api npm run create-user
```

The command prompts for credentials; do not put passwords in shell history or outreach notes. Keep public registration disabled. Admin account creation and employee account provisioning are different: the customer owner manages the shared assistant, while Gombey currently provisions/removes employee accounts from the VPS.

## Configure the shared knowledge assistant

1. Sign in as the customer administrator and create one named company assistant.
2. Enable only File Search for its capability; do not enable external actions or tools for this pilot.
3. Upload the approved synthetic/customer-approved SOPs into the assistant's File Search knowledge.
4. Share the assistant with the `USER` role as Viewer so all provisioned employees in this dedicated customer instance can use it. Do not share it publicly outside the authenticated instance.
5. Members should see/use the assistant but not edit its instructions or source files. The administrator alone updates the knowledge set.

Use [the shared-agent template](shared-agent-template.md) for the repeatable instructions and quick retrieval checks. This provides admin-managed shared knowledge; employees must select the agent to use the shared corpus. It does not make every ordinary new chat automatically search the shared corpus, create shared Projects, or share conversations between users.

## Required acceptance checks before a real customer dataset

- Create one admin and two separate member accounts; verify they are separate accounts with private chats.
- On two separate staging deployments, create distinct synthetic customer facts and verify neither deployment can retrieve the other customer's fact. Use separate Compose project names and fresh databases/volumes.
- Upload a synthetic document with a unique fact to the admin-managed agent; confirm both members retrieve it with a citation.
- Confirm a member cannot edit the shared agent or upload/remove its source files.
- Confirm one member cannot read the other member's private chat or personal files.
- Confirm an unsupported question is answered with uncertainty and no fabricated source.
- Confirm a deleted test file stops appearing in future File Search answers.
- Confirm MongoDB, pgvector, Meilisearch, and RAG API have no host-published ports.
- Confirm each configured chat endpoint works with a customer-owned key and that usage appears in that provider account. Confirm RAG embeddings use only the separate customer-owned embeddings key and usage appears in its provider account.
- Reboot the VPS and verify chat, HTTPS, and stored test data return.
- Take a backup of MongoDB, PostgreSQL/pgvector, uploads, and config; restore it to a clean test deployment. Provider snapshots alone are not considered a completed restore test.
- Verify access revocation, password reset/support process, and data deletion/retention expectations.

Until the backup/restore, account-isolation, and shared-file tests pass, treat this as an implementation-ready template—not a production-ready service or security guarantee.

For existing deployments upgraded from LibreChat v0.8.7 or earlier, back up MongoDB and run the tenant-index migration from the updated image before bringing the API back up. Follow [LibreChat's tenant-index migration guide](https://www.librechat.ai/docs/configuration/mongodb/tenant_index_migration) exactly, including stopping API writers and running the dry run first. Fresh customer databases created from this template do not need that upgrade migration.

## Operational notes

- Keep `.env` and customer document data out of source control. The repository ignores `deploy/customer/.env`.
- Keep `ALLOW_PASSWORD_RESET=false` until a valid SMTP or Mailgun integration is configured and tested. LibreChat documents an unsafe password-reset fallback when mail is not configured; do not enable reset without working mail. Use `docker compose ... exec api npm run reset-password` as the trusted operator when necessary.
- Use a separate Git checkout/branch or immutable release per customer. Do not edit the shared chat UI source for routine branding.
- Keep a record of the pinned image versions, customer's model provider, DNS, backup destination, and support contact.
- Updates require a backup, staging/acceptance test, and rollback plan; do not run `docker compose pull` blindly on a customer's live deployment.
- Local model serving, custom integrations, autonomous actions, SSO, compliance guarantees, and customer-specific code changes are not in this base pilot.
