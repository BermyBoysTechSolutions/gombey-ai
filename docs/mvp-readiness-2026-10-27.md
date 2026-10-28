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
- On 2026-10-28, the init, preflight, backup-safety, and full 11-test Python
  suite passed again; both loopback staging login pages returned HTTP 200 and
  the staging app/RAG containers were healthy. The deployment branch was clean
  and matched its GitHub remote after verification.
- A targeted scan for common credential prefixes across tracked files and
  available Git history found only the `OPENROUTER_KEY` placeholder in
  `.env.example`. No dedicated secret scanner is installed, so this is a
  limited pattern check, not a comprehensive secret audit.
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
- A fresh 2026-10-28 runtime inspection confirmed distinct private Docker
  networks and separate app, upload, MongoDB, pgvector, and Meilisearch data
  directories for the primary and restore deployments. Only the two app APIs
  are host-published, bound to `127.0.0.1:3083` and `127.0.0.1:3084`; MongoDB,
  pgvector, Meilisearch, and RAG have no host-published ports. Both deployments
  currently store their synthetic staging data on the external SSD.
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
- On 2026-10-28, the freshly rotated owner OpenRouter key was read directly
  from OpenClaw without displaying it and placed only in the mode-600 primary
  staging environment. A separate 14-token embeddings smoke returned HTTP 200
  with 1,536 dimensions. The primary staging RAG API then passed a synthetic
  ingest → semantic query → scoped delete check (HTTP 200 at each stage); the
  unique fact was retrieved, the scoped ID list was empty afterward, and a
  post-delete document read returned 404. No customer content was used. This
  validates the configured RAG service, not LibreChat's full member File Search
  experience or customer billing; production still requires customer-owned
  provider and embeddings credentials.
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
  is healthy. A later protected configuration audit found a non-placeholder
  `RAG_OPENAI_API_KEY` in the primary staging `.env` (mode `600`) and loaded in
  the RAG service. Its exact identity, rotation status, and billing-account
  ownership were not verified in that audit. The LibreChat API's `OPENROUTER_KEY`
  and `OPENAI_API_KEY` remain placeholders; an embeddings key does not by
  itself enable model chat.
- A repeat member-side API check on 2026-10-28 provisioned two disposable
  `USER` accounts using the instance's configured origin and browser User-Agent.
  Both members saw the same role-shared synthetic File Search agent in the
  agent list and basic view (HTTP 200); expanded configuration and version
  history returned 403, direct source-file listing returned an empty list, and
  each member received 404 when requesting the admin's private conversation.
  No model request or document contents were returned in these ACL checks.
- A synthetic member created only in primary staging was present in the primary
  MongoDB and absent from the restore copy (count 1 versus 0), confirming local
  deployment storage separation for this test. The eight disposable accounts
  created during the repeat checks were removed with LibreChat's supported
  delete-user command; the primary staging instance returned to its prior
  baseline of one `ADMIN`, four `USER` accounts, and zero stored provider keys.
  Both loopback login pages returned HTTP 200 after cleanup. These are local
  API/data-store checks, not a customer VPS acceptance test or a provider-backed
  File Search run; the latter still needs a known customer-owned chat key and
  verified embeddings billing.

## Remaining go/no-go gates for the cloud workspace

1. Repeat grounded retrieval/citation as a second member with the agreed
   customer-owned provider/embedding credentials. Confirm the result and usage
   appear under the intended customer billing account. Do not use Gombey's or
   the owner's subscription/API credentials for customer traffic. The primary
   local staging RAG service now has the owner's rotated OpenRouter key for
   synthetic validation only; this is not a customer credential and must not be
   carried into a customer deployment.
2. Decide whether model keys are per-member BYOK or customer-managed centrally,
   then test the chosen flow end-to-end for both members.
3. Keep connectors outside the base Cloud offer. The current shared agent has
   File Search only; no MCP/calendar/CRM integration or write-action workflow
   has passed acceptance. The capability-bounded offer copy was promoted to
   production on 2026-10-27 (deployment `dpl_6vwirUwoQtYfnwfngaj1pmq6XtCN`);
   hardware and connector-dependent work remains acceptance-gated. Do not
   advertise a connector as included unless one named integration passes
   authorization, data-path, and acceptance tests.
4. Run a Stripe sandbox rehearsal: kickoff and accepted-delivery setup
   installments, a separate subscription checkout completed at delivery,
   explicit consent and payment-method collection, a 30-day trial starting at
   checkout, first charge at trial end, founding discount, and transition to
   standard price. Do not promise delivery-plus-30-day billing unless checkout
   completes at delivery; live setup-payment links do not enroll a subscription.
5. Verify a real customer VPS: DNS, HTTPS/TLS, reboot persistence, restricted
   network exposure, backup, restore, and the same account-isolation checks.
   Purchase/production setup requires owner approval of exact plan and spend,
   hostname, and DNS control.

The read-only Hostinger VPS inventory request timed out twice on 2026-10-28;
no VPS inventory was confirmed, and no VPS was purchased or changed.

## Public-offer claims mapped to evidence

This matrix checks the public pricing page at `gombeytech.com` against the
current local customer template and acceptance record. “Not verified” means
the claim must not be presented as already proven; it may still be deliverable
after the corresponding implementation and acceptance test.

### Read-only public pricing and Stripe reconciliation (2026-10-28)

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
- A fresh read-only Stripe check on 2026-10-28 still finds three active
  products, 15 active prices, three valid 12-month coupons (each capped at
  three redemptions; none redeemed), and now three active Payment Links. The
  links have no subscription data or `setup_future_usage`, and use
  `payment_method_collection=if_required`; they do not schedule the first
  recurring charge 30 days after accepted delivery or guarantee a saved method.
  No billing objects were created or changed in this check.
- All three live Payment Links currently have `automatic_tax.enabled=true`,
  but Stripe returned zero active Tax registrations for the live account.
  Stripe's documentation says it calculates tax only in jurisdictions where
  an active registration exists; therefore, do not claim tax is being
  automatically collected until the owner/accountant resolves registrations
  and the exact tax treatment. No Tax or Payment Link setting was changed.
  Only the live Stripe account is connected; a dedicated sandbox must be
  connected before the deferred-billing rehearsal.

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
| Billing: 50% kickoff, 50% accepted delivery, separate customer-authorized subscription with a 30-day trial, 12-month launch rate | Live catalog contains setup installments, recurring prices, coupons, three active setup-only links, and three inactive monthly links. No customer billing artifacts or charges were created. | Rehearse the separate subscription checkout, payment-method consent, trial end, discount duration, renewal, product-specific coupon eligibility, and tax in a Stripe sandbox. First charge is delivery + 30 days only if checkout completes at delivery. |

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

- Added `docs/STRIPE-BILLING-TEST-PLAN.md`. The original 2026-10-27 draft
  assumed a monthly charge 30 days after accepted delivery. That timing
  assumption was corrected on 2026-10-28: the separate subscription checkout's
  30-day trial starts when the customer completes that checkout. Delivery + 30
  days is accurate only when subscription checkout is completed at delivery.
  The current sandbox-only rehearsal is in `docs/STRIPE-BILLING-TEST-PLAN.md`.
- Stripe's connected account access in this session was live-only; no test
  customer or billing objects were created and no live billing settings
  changed. Pricing and active tier names were reconciled to the current
  Cloud Workspace / Workspace Appliance / Private Local AI offer above; use
  that signed offer and a matching sandbox catalog for the rehearsal.
- The earlier future-start schedule approach is superseded by the separately
  authorized subscription checkout and trial described in the current test
  plan. Exact invoice dates and amounts must pass in a dedicated sandbox
  before this is described as ready. Gombey currently has no billing webhook
  integration; pilot billing remains operator-managed until that exists and is
  tested.

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
- A fresh object-level read found all three coupons valid and unused
  (`times_redeemed=0`), with `max_redemptions=3`; each associated promotion code
  also has a three-redemption limit. However, none of the coupon responses has
  an `applies_to` product list. The per-tier names/metadata therefore do not
  prove product restriction: the codes may be usable on a different tier's
  subscription link. Stripe documents that product scope is set when creating
  a coupon and is not editable afterward except for its name. Keep monthly
  links inactive; create and test product-scoped replacement coupons/codes in
  sandbox before any live monthly link is sent. See [Stripe coupon product
  restrictions](https://docs.stripe.com/billing/subscriptions/coupons).
- The current GETs show six products total (three current active products and
  three inactive historical Plus/Pro/Max products), 15 active prices (standard
  and founding setup installments plus three standard recurring prices), and
  nine inactive historical prices. No active subscription was found.
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
  monthly links are inactive. A fresh read-only recheck confirmed each is a
  recurring link at the standard monthly amount ($399/$699/$1,499), with a
  30-day subscription trial, required payment-method collection, and promo-code
  entry enabled. The launch code is not automatically applied; the customer
  must enter the applicable code at this second checkout. These links have
  `automatic_tax` disabled. If enabled and sent only after accepted delivery,
  they would provide a customer-confirmed second checkout whose trial then runs
  30 days; they will not reuse the card from the kickoff payment. The existing
  `automatic_tax` setting on kickoff links also does not collect tax while the
  account has no active registrations. A no-second-checkout flow would need a
  tested save-for-off-session-consent step at kickoff and a subscription
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

## Member File Search and documentation reconciliation (2026-10-28)

- A disposable synthetic member on the isolated restore copy and another on
  primary loopback staging each completed an authenticated agent-chat API
  request with File Search using DeepSeek V4 Flash. Both received HTTP 200
  streams, the expected Alder & Finch v6 HOLD/approval facts, and source
  citations. The primary member's unsupported annual-revenue question was
  answered as unspecified rather than invented. These were sequential API
  harness tests, not visible-browser acceptance or a simultaneous two-member
  session.
- To run these synthetic checks, the user's OpenClaw OpenRouter credential was
  supplied only as a temporary runtime override to the RAG process; it was not
  written to a repository or `.env`. Both disposable accounts and their
  provider-key/chat records were removed, and the agent was restored to GPT-6
  Luna. Each RAG process was returned to its saved environment configuration.
  No customer data was used.
- Persistent embeddings are still not ready: the primary staging `.env` has
  the placeholder, and the restore copy's configured embeddings credential
  returns HTTP 401. A fresh low-limit key must be entered through the hidden
  `scripts/set_rag_embeddings_key.py` helper before persistent File Search or
  customer data use. The helper prompt has been opened for owner input but no
  key has been entered.
- Stripe account discovery still returns only the live Gombey Tech account;
  no sandbox was connected and no billing objects were created. A read-only
  Hostinger VPS inventory request timed out after 300 seconds; no VPS state or
  order was changed. The available TinyFish browser profile has no signed-in
  sites, so it was not used to access Hostinger or the local app.
- The root README now distinguishes the Mac demo from customer onboarding,
  and the October 6 property-management/Ollama checklist and evaluator files
  are labeled historical. The property-management test fixture is not the
  approved current outreach niche or customer offer.
- Regression tests passed on the current branch: customer init, customer
  preflight, encrypted-backup safety, and all 11 Python unit tests. Test-only
  bytecode caches were removed. No product code, live Stripe state, DNS, or VPS
  was modified.

## MVP continuation verification (2026-10-28)

- Re-ran customer initialization, production preflight unit cases, encrypted
  backup safety, and all 11 Python unit tests; all passed. The production
  preflight correctly rejects the local staging environment because its
  hostname is reserved for testing, not a customer domain.
- Re-ran the disposable fail-closed RAG integration: synthetic upload against
  a loopback-only unavailable embeddings endpoint returned HTTP 500, stored
  zero vectors, and its disposable containers, networks, and database volume
  were removed.
- Queried the current primary and restore staging databases read-only: both
  contain the shared `Juniper & Slate Studio Workflow Assistant` configured
  for `gpt-6-luna` with `file_search` only. Both login pages returned HTTP 200.
- Tested Docker DNS in both directions with a positive control: each API
  resolved its own Mongo service, while neither could resolve the other
  deployment's Mongo container. Runtime inspection also confirmed separate
  project-specific networks and separate app, upload, MongoDB, and pgvector
  data roots on the external SSD. This is local network/storage isolation
  evidence, not a full security audit or the required customer VPS test.
- Added `scripts/customer-isolation-check.py` as a repeatable, read-only
  runtime check and ran it against both active staging projects. It passed
  checks for internal/disjoint networks, same-project Mongo DNS, blocked
  cross-project Mongo DNS, no host-published MongoDB/Meilisearch/pgvector/RAG
  ports, and distinct app, upload, MongoDB, Meilisearch, and pgvector storage
  sources. It does not test authenticated member ACLs, provider billing, or
  public VPS exposure.
- Both running RAG containers currently have placeholder embeddings values,
  and the primary `.env` is also still a placeholder; the protected helper
  session is still awaiting the fresh key. Persistent
  member-side File Search therefore remains unverified with a customer-owned
  embeddings credential. The remaining browser member sign-in/privacy checks,
  Stripe sandbox rehearsal, tax review, and cloud VPS acceptance are still
  open. No customer data, live billing objects, DNS, or VPS resources were
  created or changed.

## Persistent primary-staging RAG smoke correction (2026-10-28)

- A later state check found the owner-provided OpenRouter embeddings key now
  present in the primary staging `.env` (owner-only mode `600`) and in its
  running RAG container. The value was not printed. This corrects the earlier
  same-day snapshot that said the primary key was still a placeholder; the
  separate restored copy remains independent and was not changed.
- Added `scripts/customer-rag-smoke.py`, which accepts no key argument and
  prints no credential or document body. It writes one unique synthetic file
  and agent scope, verifies the ID is visible only in that scope, retrieves an
  exact random marker, deletes the vector, and asserts that it is absent.
- Ran the script in the primary staging RAG container: embed, own-scope ID,
  unrelated-scope isolation, and retrieval all returned HTTP 200 with the
  expected marker; deletion returned HTTP 200 and the post-cleanup check found
  no vector. Both primary and restore login pages remained HTTP 200.
- Re-ran the fail-closed upload integration from the clean worktree while
  referencing (not copying) the protected staging `.env`. The disposable test
  overrode the embedding endpoint to loopback port 9 and used an invalid
  synthetic key, returned HTTP 500, stored zero vectors, and removed its own
  containers, networks, and volume. It made no external provider call.
- This closes the persistent primary RAG service/credential smoke gate for
  synthetic tests. It does not make the owner key suitable for customer use,
  prove customer-owned provider billing, substitute for a visible-browser
  multi-member session, or prove the public VPS boundary. Customer deployments
  must use the customer's own embeddings credential.
- The remaining gates are: member-facing UX/privacy acceptance in the visible
  app; a dedicated Stripe sandbox rehearsal and customer-consented deferred
  billing test; owner/tax-advisor resolution of tax setup; review or encryption
  of local staging storage before any real data; and a separately approved
  customer VPS/hostname/DNS/TLS/firewall/backup acceptance. No live billing,
  public DNS, VPS purchase, or customer-data action occurred.

## Current MVP continuation verification (2026-10-28)

- The public landing page was fetched read-only and still presents Cloud
  Workspace, Workspace Appliance, and Private Local AI. It describes Cloud as
  one scoped workflow with customer-owned provider billing and marks the
  appliance as subject to device-specific validation. No live website edit or
  deployment was made.
- Rechecked local runtime: Colima is running; both customer-staging login pages
  (`127.0.0.1:3083` and `:3084`) returned HTTP 200. The read-only
  `customer-isolation-check.py` passed for the primary and restored Compose
  projects: internal networks are disjoint, own Mongo DNS resolves, cross-
  project Mongo DNS is blocked both ways, internal services publish no host
  ports, and app/upload/database storage sources are distinct.
- Customer-init, customer-preflight, encrypted-backup safety, and all 11 Python
  unit tests passed. No production/customer data or provider inference was used
  in this verification pass.
- Account onboarding/recovery remains operator-assisted: the customer
  template keeps public registration and email password reset disabled; the
  supported interactive `npm run create-user` and `npm run reset-password`
  commands are available to an authorized operator. The operations handoff now
  records identity verification, hidden password entry, session invalidation,
  and secure delivery expectations. This is not self-service recovery.
- The mounted external USB SSD is APFS, 1.8 TiB total with about 1.6 TiB free.
  Runtime mount inspection confirms primary and restore app data, uploads, and
  database roots are on that volume. The external volume is not encrypted;
  macOS FileVault is on for the internal disk, where the protected staging
  environment file resides. Keep the external staging data synthetic-only.
- Stripe still exposes only the live Gombey account. No sandbox is connected;
  deferred-billing consent and automatic monthly charging have not been
  rehearsed. Tax Settings remain `pending` with no head-office address and zero
  registrations; the existing monthly links are inactive and have automatic
  tax disabled. No Stripe mutation was made.
- Remaining external gates are sandbox account access and billing rehearsal,
  qualified tax review, a usable visible member-browser session if visual
  acceptance is still required, and explicit approval of customer hostname and
  VPS spend before public DNS/TLS/firewall/reboot/backup acceptance. No
  customer data or live payment should be used before those gates pass.

## Production Compose resource guardrails (2026-10-28)

- Closed a local/production configuration gap: the customer production Compose
  template now carries the per-service memory ceilings already exercised by
  local staging (API 2 GiB, MongoDB 1 GiB, Meilisearch 512 MiB, pgvector 1 GiB,
  RAG API 1 GiB). The local overlay inherits the same values rather than
  maintaining a second copy.
- Hardened production preflight to reject missing or changed limits, and added
  a regression check that the local overlay preserves the limits, exposes the
  API only on loopback, and omits public Caddy.
- `customer-preflight`, `customer-init`, backup-safety, and all 11 Python unit
  tests passed. Read-only runtime checks still pass for both local projects;
  login routes on 3083/3084 return HTTP 200 and the primary containers report
  the expected memory limits. No inference or customer data was used.
- The 5.5-GiB aggregate container ceiling leaves nominal room on the documented
  8-GiB VPS target, but is not a load/concurrency guarantee. A cloud VPS load,
  reboot, TLS, firewall, and backup/restore acceptance run remains required.
- Hostinger's read-only VPS inventory call timed out after five minutes. No
  Hostinger resource, DNS, or billing change was made. Stripe and tax gates are
  unchanged; this does not make the MVP production-ready.
- Commit `e457e3d` was pushed to
  `codex/gombey-mvp-preflight-2026-10-27`; no merge, PR, VPS, or site deployment
  was made.

## 2026-10-28: long-document synthetic corpus

- Generated three fictional creative-agency PDFs for staging-only retrieval tests:
  a 33-page operations manual, a 31-page set of 30 campaign briefs, and a
  33-page workflow/SOP manual. Every body page has substantive searchable text;
  visual samples and text extraction were checked.
- The 1,034-line answer key records the full ground truth and source page for
  all 94 sections. It is evaluator-only and must never be uploaded to an agent.
- A disposable USER received all three PDFs as user-owned, indexed test files.
  Using the normal agent chat API with its supported `text` and `files` fields,
  DeepSeek V4 Flash answered the final-page JS-C30 check correctly: date,
  $7,475 cap, Caleb Ward, 1,483 add-to-cart target, and the day-pass/private-
  office restriction, with citations to Campaign Briefs p.31 and Operations
  Manual p.16. It also distinguished internal QA from the named client's
  release approval. The earlier JS-C12 midpoint retrieval and missing-artist-
  arrival abstention also passed with citations.
- This verifies member-owned attachments and a low-cost File Search turn; it
  does **not** verify that these sources are attached to the admin-owned shared
  agent, that both members can retrieve the shared corpus, or the visible
  browser workflow. No shared-agent source was modified and no access-control
  bypass was used. The ordinary USER role still cannot create or edit a shared
  agent.
- Cleanup was verified: deleting the temporary OpenRouter user key returned
  HTTP 204; deleting the exact disposable USER account returned HTTP 200, and
  its prior session then returned HTTP 401. Its local credential file and
  in-memory test key/session were removed. The staging API and RAG services
  remain running; no customer deployment, VPS, Stripe object, or public site
  was changed.
- Remaining corpus step: use the authorized staging admin to attach only the
  three numbered PDFs to a separate shared File Search test agent, then repeat
  the key retrieval and abstention checks as two distinct members and verify
  private-chat/file isolation. Keep the answer key out of the agent.

## Final regression and billing recheck — 2026-10-28 (read-only)

- Re-ran customer-init and customer-preflight tests, encrypted-backup safety,
  all seven embeddings-key helper tests, and the two-deployment isolation
  checker; all passed. Both loopback login routes (3083 and 3084) returned
  HTTP 200.
- Re-ran the fail-closed RAG integration using only `.env.example`, an invalid
  synthetic key, and a loopback-only unavailable endpoint. The disposable
  upload returned HTTP 500, wrote zero vectors, and its uniquely named
  containers, networks, and database volume were removed. No real provider
  request, customer content, or active staging data was used.
- Re-read live Stripe products, prices, payment links, coupons, promotion codes,
  subscriptions, Tax Settings, and registrations. The three active kickoff
  links are one-time 50% founding deposits; they have `subscription_data=null`,
  `payment_intent_data=null`, `payment_method_collection=if_required`, and
  `automatic_tax.enabled=true`. They do not set up a deferred subscription or
  guarantee reuse consent for the card used at kickoff.
- The three monthly links remain inactive. Each uses its standard monthly rate,
  requires a payment method at that separate checkout, starts a 30-day trial,
  allows promotion-code entry, and has automatic tax disabled. If sent only
  after accepted delivery, its first payment would be attempted 30 days after
  that second checkout; it is not an automatic continuation of the kickoff
  payment. No active subscription was found.
- The initial unexpanded coupon responses omitted `applies_to`, so product
  scope was not established at this point in the audit. A later expanded
  read-only retrieval (recorded below) confirmed that each coupon is restricted
  to its matching product. The codes still have separate three-redemption
  ceilings, so the three-deployment cross-tier cap remains operator-enforced.
- Stripe Tax Settings remain `pending` because `head_office` is missing, with
  zero tax registrations. The live account is still the only connected Stripe
  account. No Stripe, website, VPS, DNS, or customer-data state was changed.

## Customer Compose namespace collision guard — 2026-10-28

- Found that the pre-existing initializer truncated sanitized hostnames at 30
  characters before forming `COMPOSE_PROJECT_NAME`; two long hostnames sharing
  that prefix could therefore collide and target one Docker resource namespace.
- Fresh initialization now canonicalizes hostname casing, uses a shorter prefix
  plus an 80-bit SHA-256 suffix, and marks the naming scheme. Production preflight
  verifies the new name against the hostname. Existing unmarked env files keep
  their exact legacy project name so a routine upgrade cannot silently create
  new empty volumes.
- Added regression checks for long-hostname collisions, case-insensitive DNS
  names, copied/mismatched new project names, and legacy preflight compatibility.
  Customer-init and preflight tests, backup-safety, all 11 Python tests, all 7
  embeddings-helper tests, and current two-project isolation checks passed.
- No existing `.env`, running Docker project, VPS, DNS, or customer data was
  changed. This hardens fresh customer setup; existing deployments still need
  an explicit, carefully planned namespace migration if they were created under
  the legacy rule.

## Per-tier booking-link gate — 2026-10-28

- Read-only review found one active Calendly event type: the generic 30-minute
  Zoom meeting at `https://calendly.com/ianinho/30min`. Its event-specific
  bookable schedule uses `America/New_York` hours; the account profile timezone
  is `Europe/Berlin`. Neither setting was changed.
- The current public offer page routes its call CTAs to general workflow
  discussions rather than distinct tier-specific meeting pages. For the
  requested split, the proposed events are: Cloud Workspace discovery (30
  minutes), Workspace Appliance device-fit review (45 minutes), and Private
  Local AI workload/hardware review (45 minutes), preserving the existing
  event's Zoom location and New York availability.
- Attempted to create the first event as inactive through the connected
  Calendly integration; Calendly returned “Permission Denied” before creating
  anything. No event type, availability, or website link changed. Reconnect
  Calendly with event-type write permission, then create/verify the three
  events and update the separate landing-page CTA links.

## Fresh synthetic RAG and failure-path verification — 2026-10-28

- The primary loopback staging RAG service passed a fresh synthetic
  ingest/scope/query/delete check: ingestion, own-scope and unrelated-scope
  checks, and retrieval all returned HTTP 200; the test file ID appeared in
  its own-scope listing and not in the unrelated-scope listing; the scoped
  query returned the unique marker; delete returned HTTP 200; and the
  post-delete ID check confirmed the vector was absent.
- Re-ran the disposable fail-closed integration using the protected mode-600
  staging environment file. The deliberately unavailable loopback embeddings
  endpoint made the synthetic upload return HTTP 500 and left zero vectors;
  the test's dedicated containers, networks, and volume were removed.
- The read-only two-deployment isolation check passed again: disjoint Docker
  networks, own-service DNS works, cross-deployment Mongo DNS is blocked in
  both directions, internal database/search/RAG services publish no host
  ports, and persistent data roots are distinct. Both staging login routes
  returned HTTP 200.
- Hardened `customer-rag-smoke.py`: `--help` now exits without contacting a
  service, and an unavailable endpoint reports cleanup uncertainty rather
  than emitting a traceback. Two CLI regression tests were added. Customer
  init/preflight, encrypted-backup safety, 13 Python tests, seven
  embeddings-helper tests, four fail-closed patch tests, and shell syntax
  checks passed.
- Tests used synthetic-only fixtures. This does not prove a customer-owned
  provider account, a second member's provider billing, public VPS/DNS/TLS,
  or customer acceptance. No VPS, DNS, billing, or production data changed.

## Billing-flow recheck — 2026-10-28

- A fresh read-only review of live Stripe confirms the active kickoff links
  collect setup installments only. They do not create a subscription or save
  the payment method for later use. The separate monthly subscription links
  are inactive; each requires payment-method collection, starts a 30-day
  trial, and cancels at trial end if no method is available. Thus, recurring
  billing requires a separate, customer-authorized subscription checkout; it
  is not automatic continuation of the setup payment.
- Stripe Tax Settings remain pending, with no head-office address and zero
  active tax registrations. Automatic tax being enabled on a link does not
  establish tax collection. The owner/accountant must determine tax obligations
  and confirm registrations before any live billing is represented as tax-ready.
- Updated `docs/STRIPE-BILLING-TEST-PLAN.md` to test the actual two-checkout
  flow and remove assumptions about a future subscription schedule. A dedicated
  Stripe sandbox is still required to test trial timing, launch-discount term,
  payment collection, failure, cancellation, and tax behavior.
- Prepared customer-facing clarification in the separate website branch
  `codex/gombey-billing-clarity-2026-10-28`, based on the current offer source.
  It is not deployed. Keep publication gated on sandbox validation and making
  the intended monthly enrollment flow available in Stripe.
- No live Stripe objects, tax settings, website deployment, customer data,
  VPS, or DNS were changed.

## Local deployment regression recheck — 2026-10-28 05:03 EDT

- Both loopback staging login routes returned HTTP 200. The current read-only
  two-deployment isolation check passed: project networks and data roots are
  distinct, each API resolves its own Mongo service, cross-project Mongo DNS is
  blocked in both directions, and database/search/vector/RAG services expose no
  host ports.
- Customer init, deployment preflight, encrypted-backup safety, all 13 Python
  unit tests, and shell syntax checks passed. Test temporary files were placed
  on the external SSD; no persistent staging data was changed.
- The primary staging login is queued in the Codex browser. No authenticated
  shared-agent browser session was available for this check, so member-visible
  File Search/citation and private-chat acceptance remain open. The browser step
  requires the staging administrator to sign in.
- No live billing, customer data, production website, VPS, DNS, or deployment
  state was changed.

## Billing source-of-truth alignment — 2026-10-28 05:05 EDT

- Corrected the pilot acceptance worksheet and operations handoff: setup
  installments are separate from subscription enrollment; the customer must
  complete and authorize a separate subscription checkout. Its 30-day trial
  starts at checkout, so delivery-plus-30-day billing is true only if enrollment
  happens on the delivery-acceptance date.
- Updated the current go/no-go checklist to test that exact timing, product-
  specific launch eligibility, and tax behavior in a dedicated Stripe sandbox.
  The account connection still exposes only the live Gombey Tech account; no
  sandbox or live billing object was created or changed.
- At this 05:05 snapshot, live monthly links remained inactive, coupon product
  scope had not yet been verified, and Tax had zero active registrations. The
  05:20 expanded read below confirmed matching product restrictions; sandbox
  and tax review are still hard gates for live recurring charges. No billing or
  customer state changed in this earlier snapshot.

## Staging RAG synthetic smoke — 2026-10-28 05:07 EDT

- Ran `scripts/customer-rag-smoke.py` against the isolated primary staging RAG
  service. Synthetic embedding and exact-marker retrieval passed; the marker
  was visible only in its own entity scope, absent from an unrelated scope,
  and the synthetic vector was deleted and confirmed absent afterward.
- This proves the RAG service's configured embedding/query path and basic
  entity scoping only. It does not prove shared-agent permissions, long-PDF
  retrieval, member-facing citations, or provider privacy. No corpus or
  customer data was uploaded; no production services changed. The positive
  smoke sent one tiny synthetic text to the configured embeddings provider
  (potentially metered); it did not run a chat-model completion.

## Fail-closed RAG integration and storage audit — 2026-10-28 05:11 EDT

- `scripts/test_rag_fail_closed_integration.sh` passed with a disposable
  Compose project. A synthetic upload to a loopback-only invalid embeddings
  endpoint returned HTTP 500 and stored zero vectors; the test removed its
  temporary API/database containers, networks, and vector volume.
- Confirmed primary staging app data, uploads, Mongo data, vector data, and
  Meilisearch data bind to `/Volumes/Mac Mini SSD/Gombey AI Local Staging`.
  Colima's sparse 100-GiB VM disk file remains on the internal drive (about
  30 GiB allocated, about 14 GiB free on the host). Avoid additional large
  image builds until storage is reviewed; no VM or persistent data was moved.
- This is staging-only evidence. Authenticated long-document/shared-agent
  member checks and public VPS acceptance remain open.

## Live billing and website recheck — 2026-10-28 05:20 EDT

- The latest economics decision and current public offer use Cloud Workspace,
  Workspace Appliance, and Private Local AI. A fresh read-only Stripe check
  confirms three active products and 15 active prices: standard setup totals
  of $2,500/$4,500/$7,500, founding totals of $1,995/$3,995/$6,995, and
  standard monthly prices of $399/$699/$1,499. Setup is represented by two
  one-time installments per option; no price changed in this check.
- Expanded reads of all three valid repeating coupons confirm they are
  restricted to their matching product and discount monthly prices by
  $50/$100/$200 for 12 cycles. Each associated promotion code permits three
  redemptions; the website's first-three-deployments cap is still a global
  operator rule, not one shared Stripe redemption cap. This corrects earlier
  notes based on coupon responses that did not expand `applies_to`.
- Three active live Payment Links collect only the founding kickoff halves
  ($997.50/$1,997.50/$3,497.50); there is no active delivery-balance link.
  The three monthly links remain inactive. Each monthly link requires a
  payment method, starts its 30-day trial at that separate checkout, and
  cancels at trial end if no method exists. Enrollment at accepted delivery
  yields a first charge 30 days later; later enrollment moves that date later.
  Monthly links still need the sandbox/visible-consent rehearsal before use.
- All active kickoff links have automatic tax enabled, but the live account
  has zero active Tax registrations. Stripe calculates tax only in
  jurisdictions with an active registration; automatic-tax being enabled is
  not evidence that tax will be collected. The monthly links currently have
  automatic tax disabled. Keep live collection gated on the owner/accountant's
  tax determination and correct account setup.
- Published the previously reviewed billing-copy clarification to production:
  Vercel deployment `dpl_CwaZtcCNxhUeUAazZ2x4ziMNKXZa` is Ready and aliased to
  `gombeytech.com`. The page now says setup and subscription are separate
  checkouts and explains the trial/first-charge timing. Prices, Stripe objects,
  and payment links were not changed by this deploy.
- No charge, invoice, subscription, VPS, DNS, or customer-data operation was
  performed. Remaining gates include authenticated two-member long-document
  UI acceptance, dedicated Stripe sandbox access and billing rehearsal, tax
  review, and owner-approved VPS hostname/spend plus public network/restore
  acceptance.

## Post-resume staging verification — 2026-10-28 09:28 UTC

- Re-ran customer-init, customer-preflight, backup-safety, and all 13 Python
  regression tests; all passed. The staging Compose configuration validates,
  and its API and RAG containers report healthy. Both loopback login routes
  (`3083` and `3084`) return HTTP 200.
- The read-only two-deployment isolation checker passed again: networks and
  persistent data roots are distinct, each API resolves its own Mongo service,
  cross-deployment Mongo DNS is blocked both ways, and internal data/search/RAG
  services publish no host ports.
- A fresh synthetic RAG smoke against the current staging embeddings
  configuration passed: embedding, own-scope ID check, unrelated-scope
  isolation, exact-marker retrieval, deletion, and post-delete absence all
  returned expected results. The configured credential was not printed. This
  was synthetic-only and may incur a tiny provider charge.
- No customer documents, production state, Stripe objects, public website,
  VPS, or DNS were changed. This does not replace the authenticated member UI
  test: no native-browser interaction control is available in this session.

## Regression and fail-closed recheck — 2026-10-28 06:08 EDT

- Customer-init, customer-preflight, backup-safety, and all 13 Python
  regression tests passed again. The read-only primary/restore isolation check
  passed: separate Compose networks and persistent stores, cross-project
  Mongo DNS blocked, and internal DB/search/vector/RAG ports unpublished.
- Re-ran `scripts/test_rag_fail_closed_integration.sh` in its unique disposable
  Compose project with an intentionally invalid synthetic provider key and a
  loopback-only endpoint. Synthetic upload returned HTTP 500 and stored zero
  vectors; the test removed its temporary containers, networks, and volume.
  No provider request or customer data was used.
- `git diff --check` passed. The MVP branch was synced with origin at
  `b3340a5` before this note; the pre-existing untracked `tmp/` was untouched.
- This does not complete production readiness. Authenticated two-member
  long-document retrieval/citation acceptance, customer-owned provider billing
  proof, Stripe sandbox/tax/consent rehearsal, and owner-approved VPS inputs
  plus public DNS/TLS/reboot/off-host-restore tests remain open. No production,
  live billing, website, VPS, or DNS state changed.

## Public offer and Stripe live-mode recheck — 2026-10-28 06:14 EDT

- Fetched the current public landing page and compared its three launch tiers
  with a read-only live Stripe catalog read. Product names, standard/setup and
  founding setup amounts, and monthly rates agree. All three Stripe products
  have an image. The public first-three-deployments limit is not globally
  enforced by Stripe: the product-specific promotion codes each allow three
  redemptions, so the total cap must be tracked manually.
- The three active Payment Links are one-time founding kickoff installments.
  The three inactive subscription links use standard monthly prices, allow
  promotion codes, require a payment method, provide a 30-day trial, and cancel
  if no payment method is available at trial end. Automatic tax is disabled on
  these monthly links. Their coupon, amount, consent, and date behavior still
  need sandbox rehearsal before activation.
- The three active kickoff links have automatic tax enabled, but a fresh
  read-only query returned zero active Stripe Tax registrations. Do not send
  live links or claim tax is configured until the owner/accountant resolves
  applicable tax treatment. No Stripe objects, charges, or settings were
  changed; the connected account list still exposes only Gombey Tech live mode.
- The billing runbook was corrected to match these current facts. MVP remains
  open on sandbox/consent/tax rehearsal, authenticated two-member
  shared-document retrieval and citations, customer-owned chat-provider proof,
  and approved public VPS acceptance.
- The running staging LibreChat API currently has placeholder/unset chat keys
  for OpenRouter, OpenAI, Anthropic, and Google (values withheld). The user had
  authorized a low-cost OpenRouter test via OpenClaw, but `openclaw models
  status` currently fails local configuration schema validation. No key was
  extracted, copied, or exposed, and no model request was made; repair or use
  of that credential path remains unresolved.
