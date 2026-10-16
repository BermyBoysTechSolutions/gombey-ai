# Mac mini local staging

This procedure runs the customer template as a separate, loopback-only Docker
Compose project. It does not turn the Mac mini into a public VPS and does not
validate DNS, public HTTPS, firewall rules, or cloud-provider networking.

The local overlay publishes only `127.0.0.1:3083`, disables Caddy, and applies
memory caps. It must be used with `compose.yaml` and must not be combined with
`compose.bootstrap.yaml` (that cloud bootstrap overlay uses port 3080).
Override the local port with `LOCAL_PORT` when running a second isolated
project; its default is `3083`.

## Prepare

From the repository root, create a staging-only environment file. The init
script refuses to overwrite an existing customer environment file:

```bash
./scripts/customer-init.sh staging.gombey.test staging@example.test "Gombey AI Local Staging"
```

Keep `deploy/customer/.env` private; it contains unique local staging secrets
and is git-ignored. Do not use real customer data or production credentials.

Set the data root before running any Compose commands below:

```bash
export GOMBEY_LOCAL_DATA_ROOT="/Volumes/Mac Mini SSD/Gombey AI Local Staging"
```

Important: this path is only on the external APFS SSD when the active Docker VM
actually mounts that host directory. The current Mac uses Colima, whose active
profile has no host mounts configured. In that state, this same-looking path
exists only inside Colima's Linux disk, so the staging database is **not** on
the external SSD. Verify both the mount source and `df -h` from inside the VM
before treating the data as external-drive-backed. Do not move Colima's global
Docker disk; that would affect every local container.

To put staging data on the external SSD, schedule a Colima maintenance window,
back up the staging databases and app files, then add a writable mount for
`/Volumes/Mac Mini SSD` to `~/.colima/default/colima.yaml` and restart Colima.
That restart stops every Docker workload in the profile, not just this staging
project. After it returns, verify the mount from inside the VM, restore/copy the
staging data into the host-backed folder, and only then bring staging back up.
Until that maintenance is explicitly scheduled and verified, leave the current
staging data untouched on Colima's VM disk.

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
   cannot edit its instructions or source files. The default USER role also has
   shared conversation links disabled (`interface.sharedLinks: false`).
4. After adding a disposable embeddings key, upload synthetic documents with
   unique facts and verify both members can retrieve cited facts through the
   shared agent; also check unsupported questions and document deletion.
5. Start a second Compose project with a different project name, secrets, and
   synthetic fact. Verify there is no cross-project account or data access.
6. Recreate/restart the local stack and verify accounts and files persist.
7. Back up MongoDB, PostgreSQL/pgvector, app data, uploads, and the protected
   environment file to the external SSD. Restore only into a fresh isolated
   test project, then repeat the key account and retrieval checks.

## Backup and recovery drill

Keep backups outside the repository, under a dated, owner-only directory on
the external SSD. These archives can include account hashes, uploaded files,
and deployment secrets; do not upload them to GitHub or a cloud drive.

```bash
GOMBEY_STAGING_BACKUP_DIR="/Volumes/Mac Mini SSD/Gombey AI Local Staging/backups/$(date +%F)"
mkdir -p "$GOMBEY_STAGING_BACKUP_DIR"
chmod 700 "$GOMBEY_STAGING_BACKUP_DIR"
umask 077

docker exec gombey_staging_gombey_test-mongodb-1 sh -c \
  'mongodump --host 127.0.0.1 --port 27017 --username "$MONGO_INITDB_ROOT_USERNAME" --password "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin --db GombeyAI --archive --gzip --quiet' \
  > "$GOMBEY_STAGING_BACKUP_DIR/staging-mongo.archive.gz"

docker exec gombey_staging_gombey_test-vectordb-1 sh -c \
  'pg_dump --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --format=custom' \
  > "$GOMBEY_STAGING_BACKUP_DIR/staging-vector.pgdump"

docker cp gombey_staging_gombey_test-api-1:/app/data - \
  > "$GOMBEY_STAGING_BACKUP_DIR/staging-app-data.tar"
docker cp gombey_staging_gombey_test-api-1:/app/uploads - \
  > "$GOMBEY_STAGING_BACKUP_DIR/staging-uploads.tar"

cp -p deploy/customer/.env "$GOMBEY_STAGING_BACKUP_DIR/customer.env"
chmod 600 "$GOMBEY_STAGING_BACKUP_DIR/customer.env"
chmod 600 "$GOMBEY_STAGING_BACKUP_DIR"/staging-*
```

Validate Mongo archives with `mongorestore --dryRun --archive --gzip` and
PostgreSQL archives with `pg_restore --list`; inspect tar archives with
`tar -tf`. A readable archive is not a complete restore test. For that, create
a second isolated Compose project with fresh volumes and secrets, restore there,
and verify account separation before considering production readiness. Never
restore over the active staging database.

Current validation evidence (2026-10-15):

- The staging API and regular app/GPT-test/Ollama remained healthy through a
  controlled Colima restart. Ports 3080, 3081, 3082, and 3083 returned HTTP
  200 afterward; the main app, GPT test, bridge, Ollama, staging API, Mongo,
  and pgvector reported healthy. Three synthetic accounts, one shared Luna
  agent, and both member Viewer grants persisted.
- The admin's visible Share dialog shows full control for the synthetic admin
  and Viewer access for both QA members; member "View insights" is unchecked.
  The member accounts have not been interactively signed into because their
  passwords are unavailable, so member-side UI behavior remains unverified.
- The default USER role cannot create, share, or publicly share conversation
  links. The shared agent's member grants are Viewer-only (`VIEW`, bit 1).
- Mongo archive dry-run passed; PostgreSQL custom archive parsed with
  `pg_restore --list`; app-data/uploads tar archives are readable and currently
  contain no files. SHA-256 checksums passed from the external SSD backup.
- A second isolated local project used distinct generated secrets, networks,
  and Mongo data. A marker inserted there was absent from the first project;
  neither API could resolve the other project's Mongo service.
- The Mongo/PostgreSQL/app-data/uploads backup was restored into that isolated
  project while retaining its own deployment secrets. The restored app served
  HTTP 200 with three synthetic users, one Luna agent, and Viewer-only member
  grants. That sibling project is stopped after the drill; it was not removed.
- The staging Mongo root password was rotated and verified after a diagnostic
  output mistake. The value is kept only in the mode-600 staging environment
  file and its owner-only external backup.
- An explicit Colima mount for the external SSD did not become visible inside
  the VM (`df` still showed `/dev/root` at that path). The profile was returned
  to its original default home-only mount configuration, and all Gombey
  services were brought back healthy. Do not treat active staging data as
  external-SSD-backed until a future mount is verified from inside the VM.

Still outstanding: interactive sign-in as both members (their passwords are
not available), persistent shared File Search/RAG checks in this customer
staging deployment (no customer-owned provider or embeddings keys are
configured), and a public VPS/DNS/HTTPS test. The owner-only ChatGPT-plan test
below does not replace those checks and is not a customer provider credential.
The actual staging bind-mounted database is still inside Colima's VM disk; only
the synthetic PDFs, backups, and sibling environment file are confirmed on the
host-mounted external SSD.

## Second-project isolation drill

The customer template is designed as one isolated Compose project per
customer, not as a shared multi-tenant database. For a local sibling test,
generate a fresh environment file at a separate path (the initializer refuses
to overwrite an existing file). `GOMBEY_CUSTOMER_ENV_PATH` lets the initializer
write to that separate path while preserving its normal default:

```bash
export GOMBEY_CUSTOMER_ENV_PATH="/Volumes/Mac Mini SSD/Gombey AI Local Staging/isolation-b/customer.env"
./scripts/customer-init.sh isolation-b.gombey.test ops@example.test "Gombey Isolation B"

export GOMBEY_LOCAL_DATA_ROOT="/Volumes/Mac Mini SSD/Gombey AI Local Staging/isolation-b/data"
export LOCAL_PORT=3084
docker compose --env-file "$GOMBEY_CUSTOMER_ENV_PATH" \
  -f deploy/customer/compose.yaml -f deploy/customer/compose.local.yaml config --quiet
docker compose --env-file "$GOMBEY_CUSTOMER_ENV_PATH" \
  -f deploy/customer/compose.yaml -f deploy/customer/compose.local.yaml up -d
```

Keep the sibling deployment synthetic and loopback-only. Insert a unique
synthetic marker in its `GombeyAI` database and confirm it is absent from the
first project's database; verify the two projects have distinct network IDs,
database mounts, and generated secrets. Stop only the sibling project when the
drill is complete. This tests local isolation, not cloud DNS, HTTPS, or
firewall behavior.

Use `docker compose ... down` to stop only this staging project. Do not use
`down -v`, `docker system prune`, or broad Docker cleanup commands; the Mac
contains other Gombey test data and persistent volumes.

## Owner-only GPT/Luna document and agent-tool test (2026-10-15)

This check used the separate Gombey AI GPT Test app on loopback port 3081. Its
provider sends prompts and attached files to OpenAI through the owner's
ChatGPT-plan bridge. Use only synthetic data there; this is not private/local
inference and is not available to client accounts.

- The model picker showed `gpt-6-luna` selected. The test app's context meter
  showed approximately 36.6k of 947.6k tokens used (4%), not a nearly full
  context window.
- Attached the synthetic Delivery Records PDF (36 pages), Campaign Playbook
  PDF (31 pages), and Operations Manual PDF (31 pages) directly to test-chat
  messages. The assistant correctly answered the exact offer, budget, status,
  approval, role, metric, and unknown-contact checks and supplied printed-page
  citations. A cross-document test correctly applied the current two-gate
  release policy over the retired rule and did not claim to publish or send a
  follow-up.
- Calculator tool call `1600/18600*100` returned 8.6021505; the assistant
  reported 8.6% and correctly described the reserve as already inside the
  approved total.
- Calendar MCP read returned an empty list tagged `synthetic-sandbox-only`.
  A clearly labeled no-attendee test event for 2026-10-16 14:00-14:30 Eastern
  was created in the isolated `gombey-calendar-sandbox` and read back
  successfully. No real Google/Outlook calendar, attendee, or invitation was
  involved. The synthetic event remains in that test sandbox.
- These PDFs were chat attachments processed by the owner-only cloud test;
  they were not uploaded to the customer staging app's persistent shared File
  Search index. The staging RAG/member retrieval test remains outstanding until
  a customer-owned model key and embeddings key are configured.

## Synthetic member authorization checks (2026-10-16)

The staging API was exercised as the two synthetic `USER` accounts using
short-lived JWTs minted in memory by LibreChat's own token helper. The tokens
were not printed or stored. This tests authorization after authentication; it
does **not** test the members' passwords, browser login, or full UI behavior.

- Both `qa-member-1` and `qa-member-2` can retrieve the shared
  `Juniper & Slate Studio Workflow Assistant` basic view (HTTP 200), and both
  are denied its expanded editor/configuration view (HTTP 403). The admin can
  retrieve both views (HTTP 200). The agent is configured for `gpt-6-luna` and
  has the File Search tool, but currently has zero source-file IDs attached.
- Private conversation isolation passed in both directions: each member could
  read their own temporary synthetic conversation (HTTP 200), while the other
  member received HTTP 404. Both temporary conversations were deleted through
  the owner-scoped endpoint and rechecked as unavailable (HTTP 404).
- Both members' file and conversation list endpoints returned HTTP 200 with
  zero records before/after the checks. This alone does not prove private-file
  isolation because neither account had a file to test.
- A temporary synthetic Markdown upload to Member 1 failed with HTTP 500 and
  no file was persisted; the staging provider keys are placeholders and the
  embeddings key is unset. Mongo still has zero file records. This did not
  establish personal-file ownership or shared File Search behavior; those
  checks still require a customer-owned provider and embeddings key.
- No existing member password was reset or changed; the staging UI remains at
  its login screen when no owner session is present.
- The staging API container restarted once during this validation window with
  exit status 0 (`OOMKilled=false`). It is healthy and returns HTTP 200 now, but
  the restart cause was not established; investigate before production use.
