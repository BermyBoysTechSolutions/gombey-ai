# Gombey AI MVP readiness

Status snapshot: 2026-10-28. This is a validation checklist, not a claim that
the service is ready for unrestricted production use.

## Proposed first-sale boundary

The safest initial offer is one dedicated customer deployment, with separate
admin/member accounts, an admin-managed shared knowledge agent, private member
chats, and a customer-owned model-provider account. This is not pooled
multi-tenant SaaS, a shared inbox, local inference, or an autonomous workflow
platform. The customer and the VPS operator remain privileged administrators
of their infrastructure.

Do not accept customer data or promise a production deployment until the
following cloud-workspace gates pass.

## Verified locally

- The customer deployment preflight now fails closed on a missing or
  mode-insecure `.env`, invalid or reserved hostnames/email, missing provider
  configuration, weak/malformed/duplicate deployment secrets, unsafe public
  registration/password-reset settings, and unexpected host-published ports.
- `scripts/test_customer_init.sh` passes.
- `scripts/test_customer_preflight.sh` passes, including invalid hostname,
  reserved domain, short-secret, and duplicate-secret cases.
- `python3 scripts/test_set_rag_embeddings_key.py` passes (7 tests).
- The customer Compose template parses successfully; the sample `.env` emits
  expected warnings for unset provider fields. A real API credential and live
  provider response are not validated by that parse check.
- A separate local staging deployment is loopback-only. A disposable member
  completed an interactive browser login and shared-agent Viewer/private-data
  checks; the temporary account was deleted after approval. Role/API tests also
  verified a member cannot edit the shared agent or its source files.
- On the isolated restore copy, LibreChat's supported `npm run create-user`
  command provisioned two additional synthetic `USER` accounts: the instance
  now has one `ADMIN` and four `USER` accounts (five total) while
  `ALLOW_REGISTRATION=false`; the restored UI remained HTTP 200. Generated
  passwords were withheld and not recorded. Two `USER` principals then passed
  read-only API checks for shared-agent list/basic view (HTTP 200) and were
  denied expanded configuration/version history (HTTP 403). This confirms
  their role-based agent viewer boundary, not password-based sign-in or a new
  private-chat/file test for those accounts.
- An isolated second deployment used separate secrets, network, database, and
  storage; a synthetic marker was absent across deployments. An isolated
  restore drill also completed.
- `scripts/customer-backup.sh` now refuses plaintext output, writes a checksummed
  AES-256/PBKDF2 archive, and pauses only the target deployment's app/RAG/search
  writers during capture. Safety tests pass. A fresh encrypted backup was
  restored into a second loopback-only deployment; Mongo account/agent/file/
  conversation counts matched, pgvector restored 102 rows, Meilisearch and RAG
  were healthy, and the native browser showed the restored login page.
- The tested backup key is in this Mac user's login Keychain, not on the
  external SSD. This is local staging evidence, not an off-site key escrow or
  backup policy. The external SSD is not encrypted; its staging data remains
  synthetic only.
- Older plaintext staging backups (including an older customer `.env`) remain
  on that unencrypted external volume. They contain synthetic test state; they
  must be secured or removed before any real customer data is stored there.
- Three generated synthetic evaluation manuals are 31, 36, and 31 pages. Their
  covers, representative interior pages, and final pages were visually
  inspected. The evaluator answer key is separate and must not be uploaded as
  knowledge.
- A low-cost OpenRouter Qwen smoke test answered a synthetic chat for one
  disposable user. A second account without a provider key did not inherit the
  first account's key. This does not prove retrieval or tool calling through
  Qwen.
- On 2026-10-28, the loopback overlay was set to `OPENROUTER_KEY=user_provided`
  and a fresh synthetic member's user-scoped OpenRouter key completed a
  Qwen 3.5 9B chat through Gombey's normal chat API with the exact expected
  answer. The member and associated key/chat records were deleted and verified
  absent. This was an authenticated API harness check, not a visible-browser
  UX check. The RAG API is healthy, but its current embeddings key remains a
  placeholder. The same OpenClaw credential completed a separate direct
  OpenRouter `openai/text-embedding-3-small` smoke (HTTP 200, 1,536 dimensions,
  14 input tokens), but the key was not put in the staging RAG environment and
  the RAG pipeline, file retrieval, and citations remain unverified by this
  run.
- A later isolated restore-copy member test passed the shared agent's
  `file_search` path with low-cost DeepSeek V4 Flash after a runtime-only
  OpenClaw embeddings-key override. The authenticated chat and stream returned
  HTTP 200; the answer correctly reported Alder & Finch v6 on HOLD pending
  Jamie Rivera's written approval, Morgan Ellis as internal QA owner, and cited
  the synthetic manuals by filename and page/section. The temporary member,
  key, conversation, and messages were deleted, the agent was restored to GPT-6
  Luna, the RAG container was returned to its saved configuration, and the
  restore `.env` hash was unchanged. This was API-level proof using the owner's
  test key, not visible-browser UX or customer-billing proof. The restore
  `.env` embeddings key itself returns HTTP 401; the main staging RAG key is
  still a placeholder, so the persistent File Search path needs a fresh
  customer-owned embeddings key before it is production-ready.
- A separate synthetic member on primary loopback staging also passed the
  grounded shared-agent check with citations. An unsupported annual-revenue
  question invoked File Search and abstained without inventing a number. The
  tests were sequential API harnesses on restore and primary staging, not a
  simultaneous two-member browser session; all temporary accounts and records
  were deleted and both deployments returned to their original configuration.
- The RAG upload failure path is now fail-closed: an isolated synthetic upload
  with a loopback-only unavailable embeddings endpoint returned HTTP 500 and
  left zero vectors in its dedicated disposable database. Four exact-match,
  idempotency, and source-drift unit tests pass. A corrected isolated
  integration runner was also verified. Before credential containment, the
  staging vector database contained 101 synthetic vectors; those records were
  not changed by containment. The persistent staging RAG service is now running
  and healthy, but its embeddings setting remains a placeholder, so normal app
  File Search is still not ready.
- A staging embeddings credential was printed by an earlier diagnostic and
  must be treated as compromised. No provider request was made after that
  diagnostic. It was replaced with the unconfigured placeholder in the active
  staging and restore environment files; both were verified owner-owned and
  mode `600`, without printing any credential. At containment time, the active
  staging RAG service was stopped, and the restore project's stateless RAG
  container was removed. The staging RAG service has since been restarted and
  is healthy; its persistent embeddings key remains the placeholder, so
  document search through the app is still paused until a customer-owned key is
  supplied through the protected helper.
  The owner reported rotating/adding a replacement OpenRouter key, but
  revocation and exact placement were not independently verified. The staging
  embeddings environment still contains the placeholder; a chat-provider key
  does not by itself configure RAG embeddings.

## Remaining go/no-go gates for the cloud workspace

1. Repeat grounded retrieval/citation as a second member with the agreed
   customer-owned provider/embedding credentials. Confirm the result and usage
   appear under the intended customer billing account. Do not use Gombey's or
   the owner's subscription/API credentials for customer traffic. The owner
   reports rotating the potentially exposed prior OpenRouter key, but this was
   not independently verified; do not reuse the prior value. The separate
   staging embeddings setting remains a placeholder and needs a fresh key.
2. Decide whether model keys are per-member BYOK or customer-managed centrally,
   then test the chosen flow end-to-end for both members.
3. Keep connectors outside the base Cloud offer. The current shared agent has
   File Search only; no MCP/calendar/CRM integration or write-action workflow
   has passed acceptance. The capability-bounded offer copy was promoted to
   production on 2026-10-27 (deployment `dpl_6vwirUwoQtYfnwfngaj1pmq6XtCN`);
   hardware and connector-dependent work remains acceptance-gated. Do not
   advertise a connector as included unless one named integration passes
   authorization, data-path, and acceptance tests.
4. Run a Stripe test-mode rehearsal: kickoff payment, accepted-delivery
   payment, saved payment method and explicit recurring-charge consent, first
   subscription charge 30 days after delivery, founding discount, and
   transition to standard price. Live catalog entries alone do not automate
   this lifecycle.
5. Verify a real customer VPS: DNS, HTTPS/TLS, reboot persistence, restricted
   network exposure, backup, restore, and the same account-isolation checks.
   Purchase/production setup requires owner approval of exact plan and spend,
   hostname, and DNS control.

## Public-offer claims mapped to evidence

This matrix checks the public pricing page at `gombeytech.com` against the
current local customer template and acceptance record. “Not verified” means
the claim must not be presented as already proven; it may still be deliverable
after the corresponding implementation and acceptance test.

### Read-only public pricing and Stripe reconciliation (2026-10-27)

- The public page and the connected live Gombey Tech catalog currently agree
  on descriptive tier names and prices: Cloud Workspace ($2,500 standard /
  $1,995 founding setup; $399 standard / $349 founding monthly), Workspace
  Appliance ($4,500 / $3,995 setup; $699 / $599 monthly), and Private Local AI
  ($7,500 / $6,995 setup; $1,499 / $1,299 monthly).
- The Stripe setup prices are split into 50% kickoff and 50% delivery prices.
  Three recurring coupons provide the monthly reductions for 12 months, with a
  three-redemption limit per coupon. The website's “first three deployments”
  cap is therefore enforced globally by the operator, not by a single Stripe
  limit.
- The current offer is the Cloud Workspace / Workspace Appliance / Private
  Local AI catalog and its published prices above. The latest “Gombey AI
  Economics” thread reconciled Stripe to the public offer and archived the
  earlier Plus/Pro/Max catalog. Treat older Plus/Pro/Max and $1,000 setup-only
  discount directions as historical, not the active offer.
- On 2026-10-27, the capability-bounded copy from website commit `dec345b` was
  promoted to Vercel production deployment `dpl_6vwirUwoQtYfnwfngaj1pmq6XtCN`.
  A post-deploy HTTP 200 check confirmed the revised boundaries and all setup
  and monthly amounts remained unchanged.
- The three active Stripe product descriptions were updated to match the
  bounded scope: no base connector/autonomous writes, customer-owned provider
  billing, ordinary-chat retrieval limitation, and acceptance-gated hardware,
  backup, monitoring, and restore claims. Product names, prices, coupons,
  checkout/payment links, invoices, subscriptions, and charges were not
  changed or created in this update.
- The 2026-10-27 Stripe snapshot found three active descriptive products and 15
  active prices, including setup installments and recurring prices, plus three
  12-month coupons with per-coupon redemption caps. At that snapshot, there
  were no active subscriptions or payment links; no invoice or charge was
  created in that update. Treat that as historical, not current account status.
  The connector exposed only the live account; test-mode access was not
  available, so deferred billing and saved-payment-method consent had not been
  rehearsed. The first-three-deployments limit remains manually enforced
  across the three coupons.

| Public claim | Current evidence | Gate still open |
|---|---|---|
| Cloud: dedicated VPS per customer | Separate Compose project, secrets, database, network, and storage were tested locally. | Public VPS, DNS/TLS, firewall, reboot, and restore acceptance. |
| Cloud: up to 5 named accounts with admin/member roles | Five total accounts (one admin, four members) were provisioned on isolated restore with public registration disabled. One disposable member passed interactive shared-agent and privacy checks; a second member still needs provider-backed retrieval. | Repeat grounded retrieval with the intended customer-owned provider key, verify key isolation/revocation, and rehearse account recovery. |
| Cloud: one workflow, one custom agent, shared knowledge | One synthetic shared File Search agent and admin-managed Viewer access are configured. Local lexical-mock upload/index/query/delete plumbing passed. | Real customer-template semantic retrieval/citations with a member account and customer-owned model + embeddings credentials. |
| Cloud: connector, only if separately scoped and accepted | Customer template has no MCP server. A synthetic calendar sandbox exists on a separate test network; it is not a customer connector. Production Cloud copy excludes connectors from base scope. | Keep connectors out of the base offer until a named integration passes compatibility, permission, and data-path acceptance tests. |
| Cloud: managed hosting, updates, backups, restore checks | Encrypted local snapshot and isolated full restore passed. New deployment wording requires a per-customer backup/recovery plan. | Secure/remove legacy plaintext test snapshots; define cadence/retention and portable key escrow; test off-host backup, VPS patch/update procedure, recovery target, monitoring, and restore on the actual VPS. |
| Cloud: setup guide, onboarding, 1.5 support hours and 2-business-day response | Reusable pilot scope/acceptance worksheet and operator handoff runbook are now in `deploy/customer/`. | Rehearse onboarding, support intake/time tracking, response target, and recovery on a real deployment. |
| Cloud: customer-owned provider billing | One disposable user's Qwen chat succeeded with that user's own key; a second user without a key was denied rather than inheriting it. | Verify a member's grounded chat end-to-end and confirm actual usage appears in the intended provider account. |
| Appliance: standard Beelink SER5 included, on-site workspace, primary data hosted there | No SER5 has been commissioned for acceptance. | Confirm hardware SKU/cost; test install, storage, network/power failure, remote recovery, security, backup, and restore on the actual device. |
| Appliance: 10 users, three custom agents, one connector/tool | Current customer template has one shared agent and no MCP connector. Two-member authorization has passed. | Seed/configure three agents; test ten accounts; connect the named tool and enforce human approval for writes. |
| Appliance: monitoring, updates, encrypted off-device backup, restore test | Local backup/restore artifacts exist for staging only. | Implement and test monitoring, update rollback, encrypted off-device backup, and actual-device restore. |
| Appliance: training, support hours, response target, customer-paid cloud inference | These are not established by the local app tests. | Document and rehearse service operations; verify provider account ownership/usage and appliance acceptance with the customer. |
| Private Local AI: customer workstation, local inference for accepted workflow | No offered Mac Studio, DGX Spark, or Strix Halo system has passed acceptance. Mac mini/Ollama tests do not prove another workstation or blanket privacy. | Procure/commission the selected system; benchmark agreed workload; inspect telemetry, embeddings, connectors, backups, remote support, and every data path. |
| Private Local AI: 10 users, three agents, two workflows, up to two connectors | Current template exposes one shared File Search agent and no MCP connector. | Build/configure each scoped workflow and connector; test ten-user roles, local model behavior, and write-action approval. |
| Private Local AI: monitoring, updates, backup/restore, policy review, training, five support hours | Not verified on the advertised hardware. | Deliver and test the operating controls and support process on the commissioned system. |
| Billing: 50% kickoff, 50% accepted delivery, monthly starts 30 days after delivery, 12-month launch rate | Live catalog contains corresponding products, installment prices, recurring prices, and coupons. No customer billing artifacts or charges were created. | Rehearse kickoff/delivery invoices, saved-method consent, 30-day delayed start, discount duration, and renewal in Stripe test mode before automating or promising it. |

## Separate offer gates

- Workspace Appliance: commission the actual hardware and test power/network
  failure, backup/restore, remote recovery, and replacement/support boundaries.
- Private Local AI: validate inference quality/performance, multi-user access,
  recovery, and actual data paths on the offered workstation. Do not promise
  blanket privacy or performance based on Mac staging.

## Customer-owned inputs before production

- Confirmed hostname and certificate-contact email; customer controls DNS.
- Approved VPS plan/renewal cost and payment method.
- Customer-owned model and embedding credentials, entered through a secure
  path rather than pasted into chat, source, or handoff notes.
- Named customer admin, approved source documents, retention/deletion rules,
  and written scope/acceptance criteria.
- For Appliance/Local: hardware, service area, travel, warranty, and support
  terms agreed in writing.

No VPS purchase, invoice, checkout link, subscription, or customer charge is
created by this readiness work. Do not mark the MVP complete until the
applicable gates above have evidence.

## Stripe sandbox rehearsal plan (2026-10-27)

- Added `docs/STRIPE-BILLING-TEST-PLAN.md`. It specifies a sandbox-only
  rehearsal for the 50% kickoff invoice, 50% accepted-delivery invoice,
  explicit consent and saved payment method, monthly charge 30 days after
  accepted delivery, launch-rate period, and standard-price renewal.
- Stripe's connected account access in this session was live-only; no test
  customer or billing objects were created and no live billing settings
  changed. Pricing and active tier names were reconciled to the current
  Cloud Workspace / Workspace Appliance / Private Local AI offer above; use
  that signed offer and a matching sandbox catalog for the rehearsal.
- The recommended test uses a future-start subscription schedule or an
  equivalent Stripe-supported deferred start, then advances a test clock to
  verify the first charge and launch-to-standard transition. Exact invoice
  dates and amounts must pass before this is described as automated. Gombey
  currently has no billing webhook integration; pilot billing remains
  operator-managed until that exists and is tested.

## Stripe account and live-link recheck (2026-10-28)

- Read-only Stripe account discovery exposed only the live Gombey Tech
  account; no sandbox/test-mode account is connected to this session. No
  billing objects were created or changed during this check.
- The live catalog still has three active products matching the public offer:
  Cloud Workspace ($1,995 founding setup / $349 monthly for 12 months, then
  $399), Workspace Appliance ($3,995 / $599 for 12 months, then $699), and
  Private Local AI ($6,995 / $1,299 for 12 months, then $1,499). Setup is
  split into two 50% one-time prices; the active base recurring prices are
  standard rates with valid 12-month amount-off coupons for founding rates.
- Three active Stripe Payment Links were found. Each collects only its tier's
  50% founding kickoff installment; none has subscription data or schedules a
  day-30 recurring charge. The public site remains call-first. Use those links
  only after the proposal/scope and payment terms are agreed; the accepted-
  delivery installment and deferred subscription still need an operator
  workflow and a test-mode rehearsal.
- The three active links have automatic tax enabled, but the linked founding
  kickoff prices themselves already encode the discounted installment and do
  not accept additional promotion codes. The links are usable as kickoff
  collection after scope approval, not as a complete setup-plus-care signup.
- Each tier's promotion code independently allows up to three redemptions.
  The advertised “first three deployments” cap is not a Stripe-enforced global
  cap and must be tracked across all tiers by the operator unless the offer is
  redesigned.
- The Payment Links report `automatic_tax.enabled=true`, but this alone does
  not mean tax is being collected. Verify active tax registration for any
  relevant jurisdiction before using a live checkout link or invoice.
- Test-mode access is still the blocking billing prerequisite. Do not switch
  this workflow to the live account for rehearsal, and do not claim deferred
  subscription billing is automated until a sandbox test-clock run and the
  required signed-webhook lifecycle handling pass.

## Member authorization and local deployment-isolation recheck (2026-10-27)

- Two existing member-role accounts in the isolated restored copy each listed
  and viewed the shared agent (HTTP 200), and each received HTTP 403 for
  expanded configuration and version history. The role ACL is view-only; the
  admin-only `manage:agents` capability does not apply to `USER`. No write
  requests or model/provider calls were made.
- A previous Node-based request harness was rejected by LibreChat's browser
  User-Agent gate and returned an SSE `Illegal request` envelope with HTTP
  200. The corrected Chromium-User-Agent GET checks above are the valid result;
  the earlier 200 was not evidence of an ACL bypass.
- Four member accounts returned their own conversation/file metadata lists.
  One account had two conversations; all six cross-member attempts by the
  other three accounts to fetch those conversations returned HTTP 404. All
  four personal file lists were empty, so file-preview isolation was not
  repeated in this pass; the earlier synthetic-file denial remains the
  evidence for that route.
- Staging and restored-copy MongoDB and pgvector paths are separate. A unique
  temporary marker written only to the restored MongoDB was absent from
  staging, and its probe collection was removed afterward. This demonstrates
  local per-deployment data-store separation, not shared-instance tenant
  isolation.
- Local regression checks passed again: customer init, customer preflight,
  7 embeddings-key helper tests, and 4 RAG fail-closed patch tests. Shared-doc
  semantic retrieval remains blocked while RAG is stopped and the embeddings
  key is a placeholder. No production VPS was created or changed. The website
  promotion and product-description updates are recorded above; Stripe prices,
  coupons, and customer billing objects were not changed.

## OpenRouter credential checkpoint (2026-10-27)

- The active staging `.env` is owner-owned and mode `600`, but both
  `OPENROUTER_KEY` and `RAG_OPENAI_API_KEY` remain placeholders. The staging
  RAG API is stopped; no provider request was made after the credential was
  disabled.
- The OpenClaw `openrouter:default.json` credential file inspected for the
  requested test has an April 12, 2026 modification time, so it is not
  independently verified as the user's newly rotated key. It was not used.
  Do not reuse it; the replacement must be entered through the intended
  provider-specific secure path, and the prior key's revocation must be
  confirmed before any further provider call.

## Local staging recheck (2026-10-28)

- Re-ran `bash scripts/test_customer_init.sh`,
  `bash scripts/test_customer_preflight.sh`, and the scripts' Python unittest
  suite: all passed. On the current MVP branch, the encrypted-backup safety
  tests also pass (`bash scripts/test_customer_backup.sh`), and the Python
  unittest suite passes all 11 tests, including embeddings-key and RAG
  fail-closed checks.
- The active staging API and isolated restore API both returned HTTP 200 at
  their loopback health endpoints. Docker reports the staging API, RAG API,
  MongoDB, and pgvector healthy; the restore API, MongoDB, and pgvector are
  healthy. The deployment ports remain bound to loopback, not public network
  interfaces.
- Read-only inspection found three synthetic accounts, one shared agent, and
  zero records in LibreChat's user-key collection. The staging environment
  still has placeholders for both the OpenRouter chat key and RAG embeddings
  key. Therefore no second-member provider-backed answer, semantic retrieval,
  citation, or provider-billing check has passed in the current staging state.
  The disposable-user Qwen smoke recorded below remains historical evidence,
  not evidence that this current staging database has a usable provider key.
- Hostinger read-only inventory/catalog API requests did not return during this
  check; no account-specific order quote or existing VPS inventory was
  verified. The current public [Hostinger VPS page](https://www.hostinger.com/vps-hosting?lang=en)
  lists KVM 2 at 2 vCPU / 8 GB RAM / 100 GB NVMe, prepaid at $210.96 for 24
  months and renewing at $14.99 per month for the same term. KVM 4 is 4 vCPU /
  16 GB / 200 GB, prepaid at $311.76 for 24 months and renewing at $28.99 per
  month for the same term. KVM 2 is the template's minimum-size candidate, not
  a load-tested or approved purchase; prices exclude VAT and an account quote
  and billing term must be checked in hPanel. No purchase or other Hostinger
  write was made. Production VPS acceptance is still pending explicit
  hostname and spend approval.

## Disposable member Qwen smoke (2026-10-27; historical)

- A disposable USER entered a low-limit OpenRouter key directly in that
  account's provider settings, then received the synthetic answer `RESULT=4`
  from the optional Qwen 3.5 9B model through Gombey. The key was configured
  with the UI's 12-hour lifetime; its value was not printed or copied into
  application configuration.
- A second disposable USER without a key was denied before inference rather
  than inheriting the first user's credential. Both temporary accounts were
  deleted after the check, so the current staging database correctly has no
  user-key records. This verifies a simple member chat and per-user key
  separation, but not member-side shared File Search retrieval, citations,
  provider billing, or current-key availability.
- The stale OpenClaw credential file documented above was not used. No
  customer data or production service was involved.

## Restore-copy external-storage move (2026-10-28)

- Moved the isolated restore copy's 258 MB of database/app data, its deployment
  source/config, and its synthetic backup payload from the internal disk to
  the external SSD. The source and copy were compared before restart; no file
  differences were reported. The restored deployment's environment file
  remains owner-only (mode 600), and the restore root is owner-only (mode 700).
- Recreated only the restore Compose project from the SSD copy, with an
  explicit project name so the backup's copied environment could not target
  or stop the primary staging project. Added a local mode-700 control script
  with only `start`, `stop`, `status`, and `validate` actions; its validation
  passed.
- After restart, both staging and restore APIs returned HTTP 200 and the
  restore API became healthy. Restored state remained five synthetic users,
  one agent, three files, seven synthetic conversations, zero user-key
  records, and 101 pgvector embeddings. Both deployments returned DNS
  `ENOTFOUND` when probing the other deployment's MongoDB service name, and
  their API/database/search services remain on separate Compose networks;
  only their own API ports are published on loopback.
- Confirmed no running container referenced the old internal restore path,
  then removed only that exact stale internal restore directory. This freed
  its 265 MB working directory; primary staging remained running throughout.
  The restore environment and all test data are synthetic. This is local
  recovery/isolation evidence only, not public VPS acceptance.

## Continuation audit (2026-10-28)

- Current local cloud staging and the separate restored-copy stack both
  answered their loopback health checks (HTTP 200). The app publishes only
  `127.0.0.1:3083`; the restore copy publishes only `127.0.0.1:3084`. MongoDB,
  pgvector, Meilisearch, and RAG have no host-published ports. Customer-init,
  customer-preflight, and six embeddings-key helper tests passed in this pass.
  These are local checks, not proof of public DNS/TLS or external-provider
  availability.
- The second staging member can list the shared agent, but its synthetic
  provider-backed turn failed before inference with `no_user_key`. No OpenRouter
  key record was present for that member or the staging admin; the shared agent
  was restored to GPT-6 Luna after the bounded attempt. No credential was
  copied between accounts. Do not count member-two semantic retrieval as
  passed until a test user supplies its own key through the app's secure
  provider-key UI, or the owner deliberately chooses and tests a centrally
  managed customer key model.
- Read-only production review of `gombeytech.com` and the connected live Stripe
  catalog confirms the current approved offer is Cloud Workspace, Workspace
  Appliance, and Private Local AI—not the earlier Plus/Pro/Max draft. The page
  shows Cloud at $399/$349 monthly and $2,500/$1,995 setup; Appliance at
  $699/$599 monthly and $4,500/$3,995 setup; Local AI at $1,499/$1,299 monthly
  and $7,500/$6,995 setup. The three active Stripe products and their active
  standard/founding prices match those published figures. The setup reductions
  are $505 each; the launch monthly reductions run for 12 months. Earlier
  Plus/Pro/Max products are inactive and are not the current offer.
- The website remains call-first. Setup is described as 50% at kickoff and 50%
  at accepted delivery; recurring service is scheduled to begin 30 days after
  delivery, subject to written terms and saved-payment-method consent. This
  lifecycle is not yet automated or sandbox-tested; the billing test plan
  remains the acceptance gate.
- Production VPS acceptance, DNS/TLS, reboot persistence, public firewall
  checks, off-host backup/restore, and the member-key retrieval test remain
  open. No VPS was purchased or configured.

## Staging operator control (2026-10-28)

- Added a local owner-only wrapper on the external SSD for the primary
  synthetic staging Compose project. Its supported actions are `start`,
  `stop`, `status`, and `validate`; it pins the project name, Compose files,
  loopback port, and SSD data root. It has no delete/down action and does not
  print environment values. The Mac-specific wrapper is intentionally not
  part of the repository.
- Set the wrapper to mode 700. Its Compose validation passed, and its status
  check confirmed the API is healthy at `127.0.0.1:3083`; MongoDB, pgvector,
  Meilisearch, and the fail-closed RAG API are running without public host
  ports. These checks did not restart or mutate the running deployment.

## Provider-key smoke and regression recheck (2026-10-28)

- The staging OpenRouter variable is non-empty in the owner-only mode-600
  environment file and is injected into the loopback API container. A minimal
  Qwen 3.7 Flash arithmetic request was rejected with HTTP 401; no model answer
  was returned. Do not count provider inference as passed until a valid key is
  entered through the intended secure path and the app-level test succeeds.
- The separate RAG embeddings credential is still empty/placeholder. The
  OpenClaw OpenRouter credential available during this check was last modified
  on 2026-04-12 and was not reused. No credential value was printed or added to
  GitHub.
- Customer-init, customer-preflight, customer-backup safety, and all 11 Python
  unit tests passed again. The test run generated only local Python bytecode
  caches; those exact cache directories were removed afterward.

## Stripe offer and billing audit (2026-10-28, read-only)

- The public site returned HTTP 200 and presents Cloud Workspace, Workspace
  Appliance, and Private Local AI with standard and founding monthly/setup
  rates. The same three products are active in the live Stripe account; their
  standard monthly prices and 50/50 setup installment prices match the site.
  The active founding coupons discount monthly service by $50, $100, or $200
  for 12 months. Each tier's promotion code permits up to three redemptions;
  the site-wide “first 3 deployments” cap is metadata/manual enforcement, not
  one shared Stripe redemption limit.
- The three active live kickoff links are one-time founding deposits only
  ($997.50 Cloud, $1,997.50 Appliance, $3,497.50 Local). They do not create a
  subscription or establish reuse consent for later charges. The separate
  monthly links are inactive. Those links have a 30-day subscription trial,
  require a payment method at subscription checkout, and allow promo codes.
  If enabled and sent only after accepted delivery, that is a viable
  customer-confirmed second checkout whose trial then runs 30 days; it will
  not reuse the card from the kickoff payment. A no-second-checkout flow would
  need a tested save-for-off-session-consent step at kickoff and a subscription
  created after delivery; no such flow is implemented or tested.
- Live Stripe Tax settings currently report `pending` with no head-office
  address, and the account has no tax registrations. The three active kickoff
  links have automatic tax enabled, which does not prove tax will be
  calculated or collected. All three products currently use the “Software as a
  service (SaaS) - business use” code, whose suitability for the on-site
  appliance and local-inference offer has not been confirmed. No tax settings,
  registrations, product codes, links, or live prices were changed. The owner
  should confirm tax obligations and product classification with a qualified
  tax professional before sharing live payment links; see [Stripe Tax setup](https://docs.stripe.com/tax/set-up.md)
  and [Stripe's off-session consent guidance](https://docs.stripe.com/payments/off-session-payments).
- The connected Stripe tool exposes only the live Gombey Tech account, so the
  deferred-subscription, payment-method-consent, coupon, failure/cancellation,
  and tax behaviors remain untested in a sandbox. Do not mark the live billing
  flow production-ready or send live checkout links until the sandbox
  acceptance test and tax review are complete.

## Ephemeral RAG pipeline smoke (2026-10-28)

- State correction to earlier snapshots: the main local staging RAG API was
  running and healthy in this check, but `RAG_OPENAI_API_KEY` remained the
  unconfigured placeholder; an embedding attempt failed with OpenRouter HTTP
  401 (`Missing Authentication header`). The value was never printed or
  changed; the persistent staging RAG configuration is not a verified working
  setup.
- A disposable RAG container used the OpenClaw OpenRouter credential injected
  only at runtime, without writing it into the repository or deployment
  `.env`. With a unique synthetic owner/file scope, upload returned HTTP 200,
  retrieval returned HTTP 200 with the expected marker, and scoped deletion
  returned HTTP 200. A follow-up check found zero remaining vectors, and the
  disposable container was removed. The existing staging stack was left
  unchanged.
- This passes the RAG API embedding/retrieval/deletion path with an owner test
  credential and synthetic text. It does not validate the user-facing
  LibreChat File Search flow, member-level citations, or customer-owned
  provider billing. The next RAG gate is a member-side File Search test using
  a valid customer-owned embeddings credential; do not use the owner's key for
  customer traffic.
- The fail-closed integration regression also passed again: a synthetic upload
  against an unavailable loopback embeddings endpoint returned HTTP 500, stored
  zero vectors, and the disposable Compose containers, networks, and volume
  were removed.

## Direct shared-agent RAG scope check (2026-10-28)

- A disposable RAG API process used the configured OpenClaw OpenRouter key
  transiently, without changing persistent staging settings. Read-only queries
  against the existing three synthetic shared-agent vectors returned the known
  QA owner (Morgan Ellis), written client approver (Jamie Rivera), and the
  Alder & Finch version 6 HOLD/pending-approval state.
- The same delivery query with an unrelated agent entity ID returned no
  matching client/project facts; the real agent's scoped vector count remained
  three. The temporary RAG process was removed, and both local UI deployments
  remained HTTP 200.
- This is direct RAG retrieval plus vector entity-scope evidence only. It is
  not a member-authenticated LibreChat agent chat, citation/UI proof, a
  customer-owned billing test, or proof of isolation between separate customer
  deployments. The first go/no-go gate below remains open.
