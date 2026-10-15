# Mac mini local staging

This procedure runs the customer template as a separate, loopback-only Docker
Compose project. It does not turn the Mac mini into a public VPS and does not
validate DNS, public HTTPS, firewall rules, or cloud-provider networking.

The local overlay publishes only `127.0.0.1:3083`, disables Caddy, and applies
memory caps. It must be used with `compose.yaml` and must not be combined with
`compose.bootstrap.yaml` (that cloud bootstrap overlay uses port 3080).

## Prepare

From the repository root, create a staging-only environment file. The init
script refuses to overwrite an existing customer environment file:

```bash
./scripts/customer-init.sh staging.gombey.test staging@example.test "Gombey AI Local Staging"
```

Keep `deploy/customer/.env` private; it contains unique local staging secrets
and is git-ignored. Do not use real customer data or production credentials.

Keep persistent staging data on the external APFS SSD. Set this in the shell
before running any Compose commands below:

```bash
export GOMBEY_LOCAL_DATA_ROOT="/Volumes/Mac Mini SSD/Gombey AI Local Staging"
```

The overlay requires this path instead of silently falling back to internal
disk storage. Docker's shared image cache remains in Docker Desktop's own disk
image; moving that global store would interrupt the existing Gombey containers.

The RAG service requires a separate embeddings API key. Use a disposable,
customer-owned test key with a low spend limit before testing document
retrieval. Do not substitute a ChatGPT subscription, the personal GPT bridge,
or a Gombey-owned production credential. Until that key is configured, use the
stack only for startup, login, account, and non-RAG permission checks.

## Start the local admin bootstrap

First check that port 3083 is free. Then start the local stack with registration
temporarily enabled only on loopback:

```bash
LOCAL_BOOTSTRAP=true docker compose \
  --env-file deploy/customer/.env \
  -f deploy/customer/compose.yaml \
  -f deploy/customer/compose.local.yaml \
  config --quiet

LOCAL_BOOTSTRAP=true docker compose \
  --env-file deploy/customer/.env \
  -f deploy/customer/compose.yaml \
  -f deploy/customer/compose.local.yaml \
  up -d
```

Register the designated synthetic customer owner at `http://localhost:3083`.
Immediately restart the stack without the bootstrap variable so public
registration stays disabled:

```bash
docker compose \
  --env-file deploy/customer/.env \
  -f deploy/customer/compose.yaml \
  -f deploy/customer/compose.local.yaml \
  up -d --force-recreate api
```

Because the overlay defaults `LOCAL_BOOTSTRAP` to false, the recreated API has
registration disabled. Confirm the rendered config and logs before creating
member accounts with LibreChat's supported `npm run create-user` command.

## Acceptance checks

1. Create one synthetic customer admin and two separate member logins.
2. Verify member chats and personal files are not visible to the other member.
3. Create one admin-managed File Search agent and verify members can use it but
   cannot edit its instructions or source files.
4. After adding a disposable embeddings key, upload synthetic documents with
   unique facts and verify both members can retrieve cited facts through the
   shared agent; also check unsupported questions and document deletion.
5. Start a second Compose project with a different project name, secrets, and
   synthetic fact. Verify there is no cross-project account or data access.
6. Recreate/restart the local stack and verify accounts and files persist.
7. Back up MongoDB, PostgreSQL/pgvector, uploads, and configuration; restore to
   a fresh test project and repeat the key retrieval checks.

Use `docker compose ... down` to stop only this staging project. Do not use
`down -v`, `docker system prune`, or broad Docker cleanup commands; the Mac
contains other Gombey test data and persistent volumes.
