# Mac mini local staging

This procedure runs the customer template as a separate, loopback-only Docker
Compose project. It does not turn the Mac mini into a public VPS and does not
validate DNS, public HTTPS, firewall rules, or cloud-provider networking.

The local overlay publishes only `127.0.0.1:3083`, disables Caddy, and applies
memory caps. It must be used with `compose.yaml` and must not be combined with
`compose.bootstrap.yaml` (that cloud bootstrap overlay uses port 3080).
Override the local port with `LOCAL_PORT` when running a second isolated
project; its default is `3083`.

The local overlay runs a one-shot storage-permissions helper before the API.
It grants the LibreChat runtime UID ownership of only the staging `app_data`
and `uploads_data` bind roots; it does not recursively change existing files or
make the directories world-writable. This is needed when Colima creates a
missing bind source as root. The helper does not make an unmounted `/Volumes`
path external-SSD-backed.

Colima normally mounts the home directory, not `/Volumes`. The tested local
profile explicitly mounts both the home directory and `/Volumes` with
`virtiofs`, so the configured `/Volumes/Mac Mini SSD/...` bind sources resolve
to the physical external drive. When adding custom Colima mounts, retain the
home-directory mount; mount the `/Volumes` parent rather than the SSD's
space-containing name. Verify host-side write-through before relying on this
storage location. Without that VM mount, Docker may silently use a same-named
directory inside Colima instead.

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

Storage verification (2026-10-15): the active Colima profile now mounts the
host's `/Volumes` through `virtiofs`. The staging database, app-data, uploads,
Meilisearch, and pgvector bind roots are under
`/Volumes/Mac Mini SSD/Gombey AI Local Staging`; the host and API container both
reported the external SSD's 1.8 TB filesystem, and the earlier VM-to-host
write-through probe passed. This supersedes the old “not on the external SSD”
warning. Recheck `df -h` and a harmless write-through probe after changing
Colima mounts or restoring the stack; a path with the same spelling inside
Colima is not proof of host storage. Do not move Colima's global Docker disk,
which would affect every local container.

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
- The admin's earlier Share dialog showed owner access for the synthetic admin
  and Viewer access for both QA members. A follow-up runtime API test replaced
  the two direct member grants with one Viewer grant to the system `USER` role;
  member "View insights" remains disabled and public access is off.
- With the role-level grant active, both QA members can retrieve the shared
  agent's basic view (HTTP 200) but cannot retrieve its expanded editor view
  (HTTP 403); the admin can retrieve the expanded view (HTTP 200). The ACL now
  has `principalType=role`, `principalId=USER`, and Viewer `VIEW` bit 1, with
  no direct ACL rows for the two members. Requests used short-lived in-memory
  test JWTs and a browser User-Agent. At that point this verified role
  authorization, not interactive login; the later browser sign-in result is
  recorded in the Team-member acceptance follow-up below.
- Private file authorization was tested with one disposable synthetic text
  record owned by `qa-member-1`: the owner saw it in `/api/files` and retrieved
  its preview (HTTP 200); `qa-member-2` did not see it and received HTTP 403
  for its preview. The record was deleted and the owner then received HTTP 404.
  This verifies runtime file-ownership checks, but not file-upload ingestion.
- The default USER role cannot create, share, or publicly share conversation
  links. The shared agent grants are Viewer-only (`VIEW`, bit 1).
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
- An initial Colima mount attempt did not expose the external SSD inside the
  VM. That issue was later corrected and the restored staging bind roots were
  verified against the external filesystem; see the storage and final team-
  member follow-up notes below.

Still outstanding: a customer-owned model API key and embeddings key for
real-model answers, semantic retrieval, citations, and provider-billing
verification in this customer staging deployment; then public VPS/DNS/HTTPS
testing. The owner-only ChatGPT-plan test below does not replace those checks
and is not a customer provider credential. The current staging bind-mounted
data roots are verified on the external SSD, as recorded above.

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
  Search index. A later local-only mock test exercised the staging RAG path, but
  real semantic retrieval and customer-provider behavior still require a
  customer-owned embeddings key and chat-model key.

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
- A temporary synthetic Markdown upload to Member 1 initially failed because
  the Colima-created bind directory was root-owned and the non-root API could
  not create `/app/uploads/temp/<user>`. The local overlay now runs a
  network-isolated, one-shot helper that gives UID 1000 ownership of the two
  staging directory roots. A follow-up synthetic text upload passed the file
  system step but failed at vector embedding because `RAG_OPENAI_API_KEY` is a
  placeholder. No file or agent association persisted; the upload directory is
  empty. Real File Search ingestion still needs a customer-owned embeddings
  key, and the model providers remain `user_provided` sentinels until the
  customer supplies chat credentials.
- No existing member password was reset or changed; the staging UI remains at
  its login screen when no owner session is present.
- The staging API container was replaced by Compose during the validation
  window and exited cleanly (exit status 0, `OOMKilled=false`). It is healthy
  and returns HTTP 200; the evidence points to a normal container replacement,
  not an OOM crash.

## Local acceptance follow-up (2026-10-15)

- The local storage-permissions helper completed successfully; `/app/data` and
  `/app/uploads` are owned by the LibreChat runtime UID 1000 with mode 755.
  A non-root write probe passed and its temporary directory was removed.
- The customer Compose template now defaults
  `SCHEDULES_SINGLE_PROCESS=true`, matching its one-API-replica-per-customer
  design. After recreation, the scheduler engine logged that it started,
  `/api/schedules` returned HTTP 200 for the admin, and the staging database
  contained zero schedules. Scale-out remains unsupported until Redis Streams
  are configured.
- After the API restart, both member role tokens still retrieve the shared
  agent (HTTP 200) and are denied its expanded editor (HTTP 403); the admin
  editor remains available (HTTP 200). Both member file-list routes respond
  HTTP 200. The Codex in-app browser still shows `GPT-6 Luna` selected.
- The GPT-plan bridge unit suite passed 10/10. LibreChat's focused Jest tests
  could not run from the production image because it does not contain Jest or
  development dependencies.
- The native in-app browser opened the File Search upload surface, but its
  file chooser was not controllable through the available UI surface. The
  equivalent local API upload test used a short-lived in-memory admin token
  and synthetic content; it reached the RAG embedding request and failed with
  the expected missing-key error. No token was printed or persisted.

## Shared File Search and vector-deletion follow-up (2026-10-15)

- A 31-page synthetic Operations Manual uploaded through the staging API and
  indexed against a private-network-only deterministic lexical embedding mock.
  The admin and a `USER` member each retrieved four relevant chunks (HTTP 200),
  including the known internal-QA and written-approval facts. This validates
  local upload/index/query wiring only; the mock is not a semantic embedding
  model, and page-level citation metadata was not returned.
- The first delete checks exposed a real scope mismatch: LibreChat v0.8.8 sent
  vector deletion with only the uploader ID, while the shared vectors are owned
  by the agent entity ID. The file records disappeared but 64 vector chunks
  remained. Those exact synthetic vectors were removed through the RAG API with
  the recorded agent scope; the pgvector embedding table returned to zero.
- Added a version-pinned LibreChat vector CRUD override to the customer Compose
  template. It reads `metadata.embeddedEntities` and deletes each recorded
  shared-agent scope, fails closed if that scope is missing or the RAG service
  is unavailable, and retains the file record for retry on failure. Repeating
  the synthetic upload, admin/member retrieval, and normal LibreChat file-delete
  flow returned HTTP 200 at each step; the Mongo file record and all pgvector
  chunks were both removed. This patch must be revalidated before changing the
  LibreChat image version.
- After the final API recreation, both member accounts again received HTTP 200
  for the shared agent and HTTP 403 for its expanded editor. Synthetic member
  attempts to upload or remove source files both returned HTTP 403. No file
  records or vector rows remained, and the shared agent had zero attached
  files.
- The role audit found `USER` can use and create schedules, and can use MCP
  servers if one is configured; none are configured in this staging instance,
  and the shared agent exposes only File Search. No schedules or external
  actions were created. Decide before a customer deployment whether member
  schedules should remain enabled or be disabled for the pilot.
- No real API key or customer data was used. The RAG service has been restored
  to its placeholder provider configuration, and the temporary mock container
  and uploaded file are removed. Real embeddings quality, model-generated
  answers/citations through this deployment, and provider billing remain
  unverified until customer-owned test credentials are configured.
- The initial `/Volumes` bind paths were only directories inside Colima because
  that profile did not mount `/Volumes`. Stopped the dedicated staging project,
  preserved a rollback archive on the external SSD, explicitly mounted the
  host `/Volumes` parent while retaining the home mount, and restored the
  staging data directories onto the physical SSD. Host-side files now show the
  expected Mongo, Meilisearch, and pgvector data sizes; a VM-to-host write
  probe passed. Mongo retained three QA users and one agent, while the file and
  conversation collections remained empty. After that verification, removed
  only the redundant internal copies of those five staging data roots; the
  separate stopped isolation-test data and its existing external files were
  left untouched. A mode-600 pre-mount rollback archive remains on the SSD,
  outside the repository.

## Team-member acceptance follow-up (2026-10-15)

- A disposable browser member signed in through the actual local sign-in page
  in the Codex in-app browser (not Chrome), saw `GPT-6 Luna`, and could select
  the shared Juniper & Slate workflow agent. The member was logged out and the
  temporary account was removed afterward.
- Two separately authenticated `USER` members passed the API isolation checks:
  both could read the shared agent's basic metadata, neither could read its
  editor configuration or version history, and Member B received `404` for
  Member A's synthetic private conversation. The conversation appeared in
  Member A's list only.
- A synthetic private-file metadata record appeared in Member A's file list,
  not Member B's; Member B's attempt to preview it was denied. This checks
  user-scoped file authorization, not binary upload or ingestion. Shared File
  Search upload/index/delete and admin/member retrieval plumbing were tested
  separately above with a deterministic lexical mock, not a semantic model.
- Source inspection confirms ordinary attachment uploads are routed through
  the selected model provider. That end-to-end private-attachment upload was
  not exercised here because the customer staging instance has no usable
  customer-owned provider credential; no fallback provider or personal plan
  connection was substituted.
- The first member-route test exposed that Express passed `next` as the third
  argument to LibreChat's basic-agent handler, unintentionally selecting its
  expanded configuration response. Added a fail-closed, version-pinned startup
  patch at `patches/librechat-agent-route.js` and re-ran member checks: basic
  metadata contains no instructions/tools/actions/file configuration; the
  dedicated expanded route and version history remain forbidden to members.
  The patch survives API recreation and is idempotent.
- The temporary UI account, synthetic private conversation, and file record
  are absent. Registration is currently `false`, the API is healthy on
  loopback port 3083, and the external SSD mount is confirmed.
- The persisted shared agent is configured for `gpt-6-luna` on the OpenAI
  endpoint and exposes only `file_search`; the customer config contains no
  MCP server. Password reset and public sharing are disabled. This verifies
  the configured model/tool boundary, not a real provider inference request.
- The supported `npm run create-user` and `npm run reset-password` operator
  commands are present in the pinned image. In a live check, `create-user`
  provisioned a verified `USER` account while public registration stayed off;
  its exact synthetic account was then deleted, returning the database to
  three users. Member provisioning is not self-service. The production
  preflight correctly refuses the local sample environment because it still
  has a sample hostname/email and placeholder embeddings key. No real provider
  credential was entered to bypass that gate.
- Revalidated the retained external-SSD backups without restoring over any
  live data: Mongo passed `mongorestore --dryRun`, the pgvector custom archive
  passed `pg_restore --list`, and both app-data/upload tar files parsed. The
  separate sibling deployment remains stopped after its earlier successful
  isolated restore test.
- Rechecked the three synthetic evaluation PDFs: 31, 36, and 31 pages, each
  with more than 5,000 extractable words. First-page renders were legible, and
  the workspace copies byte-match the copies in the external-SSD evaluation
  folder. They are ready to reuse for the real-provider RAG run.

Remaining before production-VPS testing: a real customer-owned model API key
and embeddings key are still needed to verify actual model-generated answers,
semantic retrieval, citations, and provider billing in this customer template.
The current synthetic agent has no attached files and no MCP server or external
action configured; this keeps its action boundary safe but does not yet verify
a customer-specific calendar/MCP integration. One member completed interactive
browser sign-in; the second member's login and isolation were validated through
separate authenticated API requests. Public VPS/DNS/HTTPS, firewall, and cloud
reboot/restore checks remain intentionally out of scope until local gates pass.

## OpenRouter smoke test via OpenClaw (2026-10-15)

- The saved OpenClaw OpenRouter profile successfully completed one isolated
  synthetic request using `deepseek/deepseek-v4-flash-0731`; it returned the
  exact requested marker. The provider-reported cost was $0.000225192 for
  12,084 input and 12 output tokens. No tools or customer documents were used.
- This proves the OpenClaw profile can make an OpenRouter request, not that
  LibreChat's OpenRouter endpoint in this customer deployment is configured or
  working. The protected OpenClaw secret was not exported or copied; the
  OpenClaw CLI treats secret-kind values as write-only. The staging UI still
  shows the saved agent on GPT-6 Luna and its `.env` retains the documented
  `user_provided`/placeholder provider settings. No Gombey provider settings
  were changed and no key was persisted in this repo.
- To run provider-backed Gombey chat and semantic-RAG acceptance, enter a
  dedicated test API key into the staging provider setting/secret file through
  the appropriate secure path, then re-run the documented synthetic upload,
  citations, unsupported-answer, and deletion cases. Confirm separately whether
  the same OpenRouter key can call the configured embeddings model. Keep this
  separate from any future customer credentials. Do not start production VPS
  testing until those Gombey-side checks pass.

### Follow-up test (2026-10-15)

- A second one-line synthetic request returned the expected marker using the
  saved OpenRouter profile and `deepseek/deepseek-v4-flash-0731`. The app-bundled
  OpenClaw CLI completed inference; it did not report usage or cost for this
  request. No tools, files, or customer data were involved.
- The key remained inside OpenClaw and was not printed, exported, or copied to
  Gombey. This is still an OpenClaw smoke test, not a Gombey/LibreChat provider
  test; the Gombey staging config and GPT-6 Luna agent were not changed.
- The Homebrew CLI (2026.7.1) rejects the current OpenClaw config. The bundled
  CLI (2026.9.7) accepts it with a warning that the config was written by
  2026.9.9, and the inference succeeded despite plugin warnings. Do not run
  `openclaw doctor --fix` without reviewing its proposed changes.
- A historical shared-vault note contains a pasted OpenRouter credential. It
  cannot be confirmed whether that value matches the current profile; treat the
  profile as potentially exposed and rotate it before further use.

## Runtime revalidation and RAG healthcheck (2026-10-15)

- Added a RAG API HTTP healthcheck against `/health` and changed the API startup
  dependency to wait for `rag_api` to become healthy. Verified that the pinned
  RAG image includes Python, `/health` returns `200 {"status":"UP"}`, and the
  merged local Compose configuration validates. Recreated the RAG and API
  services; both Docker healthchecks passed afterward.
- The app remained available at loopback-only `http://127.0.0.1:3083/health`
  (HTTP 200), and the native Codex browser remained on the signed-in new-chat
  screen with GPT-6 Luna selected. Docker publishes only the API on
  `127.0.0.1:3083`; MongoDB, PostgreSQL/pgvector, Meilisearch, and RAG have no
  host-published ports.
- Read-only database checks show one `ADMIN`, two `USER` accounts, and the
  persisted Juniper & Slate agent configured for `gpt-6-luna` with only
  `file_search`. It has zero attached files. The RAG `/ids` endpoint reports
  zero records.
- The mode-600 staging `.env` still contains placeholders for chat and
  embeddings keys; no key value was printed. Thus health proves the RAG service
  starts, not that real embeddings or provider-backed File Search work. The
  synthetic Calendar MCP container remains on its separate Docker network and
  is not connected to the customer agent.
- A second read-only audit confirmed the `.env` is Git-ignored, public
  registration and password reset are both `false`, and the only host-published
  mapping is API `127.0.0.1:3083`. App data, uploads, MongoDB, Meilisearch, and
  pgvector are mounted from the external SSD. The database currently has zero
  files, conversations, and schedules; RAG `/ids` also reports zero. The browser
  currently has an admin session, so this observation is not counted as a member
  UI login (the disposable member UI login is documented above).
- `scripts/customer-preflight.sh` correctly refuses this local sample config
  because it still has a sample hostname/email and an embeddings-key
  placeholder. No credentials were printed or changed. This is an expected
  production gate, not a staging-health failure.
- Added `scripts/set_rag_embeddings_key.py` as a secure local credential-entry
  path for the remaining embeddings gate. It prompts with hidden input, changes
  only `RAG_OPENAI_API_KEY` in an owner-owned mode-600 file using atomic replace,
  and refuses non-interactive use. Five unit tests pass using fake keys only;
  the live staging `.env` hash is unchanged. Use a newly rotated, low-limit key,
  then recreate only `rag_api` using the local overlay command in README.md.
- Added an optional `DeepSeek V4 Flash (OpenRouter test)` model spec for cheap
  synthetic chat checks. The Codex in-app browser showed the option under
  OpenRouter; GPT-6 Luna remained selected, and the persisted shared agent was
  not changed. No request was sent because the OpenRouter profile must be
  rotated first; the option requires each test user to supply their own key.

## Local acceptance recheck (2026-10-18)

- The customer staging API, RAG API, MongoDB, and pgvector containers are
  healthy. The API returns HTTP 200 on `127.0.0.1:3083`; the RAG health route
  returns HTTP 200 internally. Only the API is host-published, on loopback.
  MongoDB, pgvector, uploads, and app data are mounted from the external SSD.
- LibreChat is pinned to `ghcr.io/librechat-ai/librechat:v0.8.8`; the RAG
  image is pinned by digest. The current UI model selector shows GPT-6 Luna.
  The persisted shared agent uses `gpt-6-luna`, exposes only `file_search`,
  and has no attached source-file IDs. Its `USER`-role grant is Viewer-only
  (`permBits=1`).
- The database contains one `ADMIN` and two `USER` accounts. It currently has
  zero files, conversations, schedules, MCP servers, actions, shared links,
  and RAG index IDs. Registration and password reset are both disabled.
- The local `.env` remains Git-ignored and mode 600. Chat-provider settings
  are placeholders/`user_provided`, and the server-side embeddings key is
  empty. No model inference, file ingestion, or provider spend occurred during
  this recheck. The production preflight correctly rejects the sample
  hostname/email and missing embeddings key.
- Merged local Compose config validation, shell/Node syntax checks, all six
  credential-helper unit tests, and the customer-init regression tests pass.
  The initializer test verifies mode-600 creation, distinct secrets, refusal to
  overwrite, dangling-symlink rejection, and invalid-hostname rejection. The
  four retained 2026-10-15 backup artifacts still match `SHA256SUMS.txt`; Mongo
  gzip and app-data/uploads tar
  structure checks pass. PostgreSQL archive listing and the isolated restore
  drill are prior documented checks; neither was repeated here.
- Prior acceptance evidence remains applicable: one disposable member passed
  actual browser sign-in, and authenticated member tests verified shared-agent
  viewer access plus private-chat and file metadata/preview isolation. No
  existing password was changed for this recheck.

Remaining hard gate: rotate the potentially exposed OpenRouter credential,
then have the owner enter a fresh low-limit key through the staging account's
provider-key UI and supply a separate embeddings key through the hidden-input
helper. Run the single synthetic chat and full shared-document upload, semantic
retrieval, citation, unsupported-answer, and deletion checks before any public
VPS/DNS testing. Do not use the old OpenClaw profile until its key is rotated.
