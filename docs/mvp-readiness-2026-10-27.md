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

## Owner-confirmed offer ladder (2026-10-28)

The intended progression is a dedicated VPS with cloud inference at the entry
tier; an on-site Beelink SER5 workspace that still uses cloud inference at the
middle tier; and a workload-benchmarked Mac Studio, DGX Spark, or Strix
Halo-based workstation for local inference at the highest tier. This is the
intended product design, not a tier mismatch. Device cost and scope remain
separately quoted and acceptance-gated.

## Verified locally

- The customer deployment preflight now fails closed on a missing or
  mode-insecure `.env`, invalid or reserved hostnames/email, missing provider
  configuration, weak/malformed/duplicate deployment secrets, unsafe public
  registration/password-reset settings, and unexpected host-published ports.
- `scripts/test_customer_init.sh` passes.
- `scripts/test_customer_preflight.sh` passes, including invalid hostname,
  reserved domain, short-secret, and duplicate-secret cases.
- `python3 scripts/test_set_rag_embeddings_key.py` passes (7 tests).
- On 2026-10-28, the init, preflight, backup-safety, and full 13-test Python
  suite passed; both loopback staging login pages returned HTTP 200 and the
  staging app/RAG containers were healthy. The deployment branch was clean
  and matched its GitHub remote after verification.
- Continuation recheck on 2026-10-28: customer-init, customer-preflight,
  encrypted-backup safety, all 15 Python checks across the RAG smoke CLI,
  fail-closed patch, and embeddings-key suites passed. A fresh synthetic RAG
  ingest, own-scope lookup, unrelated-scope isolation check, retrieval, and
  scoped delete also returned HTTP 200; the unique synthetic vector was absent
  afterward. No customer data or chat-model request was used.
- Sanitized runtime config audit on 2026-10-28: the primary staging, restore,
  and clean-candidate stacks all list GPT-6 Luna plus the optional Qwen 3.5 9B
  and DeepSeek V4 Flash test models. The clean candidate at `127.0.0.1:3085`
  has `maxContextTokens: 128000`; the older primary and restore stacks do not.
  The candidate's checked-out source remains detached at `e31577f`, while the
  pushed MVP branch is `4d1e0a7`. A comparison of the candidate's effective
  LibreChat YAML (ignoring comments) against the branch file found them
  identical, including the 128k setting; the intervening diff otherwise
  consists of documentation and the RAG smoke-test harness. Local runtime
  evidence therefore matches the pushed runtime configuration, but the
  candidate is not an exact source checkout. Use the current pushed branch head
  when preparing a VPS and rerun its preflight there.
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
- Qualification from the 2026-10-28 checkout audit: the primary and restore
  staging APIs are bind-mounted from separate development checkouts rather
  than a clean checkout of this pushed MVP branch. Their HTTP-200 status and
  earlier functional results do not prove that this branch has been deployed
  into either running instance. The dirty development checkout and its data
  are preserved.
- A clean local candidate was then started from detached commit `e31577f` on
  the external SSD, as an isolated Compose project on `127.0.0.1:3085`. The API,
  MongoDB, pgvector, and RAG health checks pass; `/login` and `/health` return
  HTTP 200; only the API is host-published and it is loopback-bound. All
  candidate app/upload/database data is on the external SSD. No model or
  embeddings request was made: the candidate has `user_provided` chat-provider
  settings and the generated embeddings placeholder. A later audit found two
  accounts (one ADMIN and one USER), no agents, files, conversations, or
  messages. Their account labels matched QA/test fixture naming patterns, but
  neither account was modified or deleted. The candidate has no uploaded
  evaluation documents. Its server-side provider settings remain placeholders;
  this count-only audit did not inspect account passwords or user-scoped keys.
- Candidate RAG authentication was then tested without persisting a credential
  to its external-SSD `.env`: the first synthetic smoke correctly failed closed
  because that file still held the embeddings placeholder and stored no vector.
  For a second run, the already-authorized owner staging embeddings credential
  was passed only to the candidate RAG container at runtime. Synthetic ingest,
  own-scope and unrelated-scope checks, exact-marker retrieval, deletion, and
  post-delete absence all passed. The candidate RAG container was recreated
  afterward from its placeholder config and returned healthy. This validates
  provider-backed RAG mechanics with synthetic data; it does not verify a
  customer-owned key, LibreChat member File Search, shared-agent UX, or chat
  model access. No credential value was displayed or written to the candidate
  env file.
- Continuation regression on 2026-10-28: customer init, deployment preflight,
  backup-safety, 16 Python tests, the fail-closed upload integration (HTTP 500
  with zero vectors, using only a disposable loopback endpoint), and both
  primary/restore-versus-candidate network/storage isolation checks passed.
  Login routes on ports 3083, 3084, and 3085 plus candidate health all returned
  HTTP 200. The temporary integration resources were fully removed.
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
- Three generated synthetic evaluation manuals are 33, 31, and 33 pages. Their
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
- Final candidate browser recheck on 2026-10-28: unauthenticated navigation to
  `/c/new` redirected to `/login`. A disposable candidate `USER` then completed
  an authenticated login (login HTTP 200; authenticated profile matched that
  exact test account), saw and selected the shared Juniper & Slate test agent,
  and retained the configured GPT-6 Luna default. No model generation or file
  upload was sent. LibreChat's supported self-delete endpoint returned HTTP 200
  for that disposable account and the browser returned to the login screen.
  This proves sign-in plus shared-agent discovery/selection only; it does not
  replace the separate member-edit-denial, grounded browser-answer, or provider
  billing checks. The test account had no chats, uploads, or provider key.
- Regression rerun on 2026-10-28: customer-init, customer-preflight,
  encrypted-backup safety, RAG smoke CLI (5 tests), fail-closed patch (4 tests),
  embeddings-key setter (7 tests), and File Search depth patch (5 tests) all
  passed against the candidate source at `820e4b7`. The pre-existing untracked
  `tmp/` directory was left untouched.

## Remaining go/no-go gates for the cloud workspace

1. Repeat grounded retrieval/citation as a second member with the agreed
   customer-owned provider/embedding credentials. Confirm the result and usage
   appear under the intended customer billing account. Do not use Gombey's or
   the owner's subscription/API credentials for customer traffic. The latest
   synthetic request to the normal candidate RAG service failed at the
   OpenRouter embeddings call with HTTP 401 (`Missing Authentication header`).
   A sanitized runtime check confirms that this container still has the
   template placeholder, so this is an expected unconfigured-credential
   failure, not evidence of an application-code or offer mismatch. Its health
   endpoint still returns HTTP 200, which only proves the service starts. No
   working embeddings credential is configured on this persistent stack; enter
   a fresh authorized test/customer credential through the protected setup path
   and rerun the member flow before passing this gate.
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

The read-only Hostinger account-inventory request timed out again on
2026-10-28, so no existing account VPS was confirmed. Hostinger's public USD
pricing page, checked the same day, lists KVM 2 at 2 vCPU / 8 GB RAM / 100 GB
NVMe and KVM 4 at 4 vCPU / 16 GB RAM / 200 GB NVMe. The displayed promotional
24-month totals are $210.96 for KVM 2 (renewal $14.99/month) and $311.76 for
KVM 4 (renewal $28.99/month); plans are paid upfront, so the advertised
monthly promo rate is not month-to-month billing. For the full app/RAG/search
stack, KVM 4 is the safer provisional VPS acceptance target; this is an
engineering inference, not a completed benchmark. Account-specific monthly
checkout pricing and availability remain unconfirmed. See
[Hostinger VPS pricing](https://www.hostinger.com/vps-hosting?lang=en). No VPS
was purchased or changed.

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
| Cloud: up to 5 named accounts with admin/member roles | Five accounts (one admin, four members) are provisioned with registration disabled. Two disposable members signed in through the app in headless Chromium, saw the same agent, and were denied edit/version access; a third selected that agent in the model picker. Prior synthetic grounded File Search answers and private-chat isolation passed through API harnesses. | Run member-facing grounded chat and citation checks with customer-owned model and embeddings credentials; verify provider-key ownership/isolation/revocation and account recovery. |
| Cloud: one workflow, one custom agent, shared knowledge | Shared File Search agent and admin-managed Viewer access are configured. Synthetic 31–36-page manuals were retrieved with expected facts/citations; unsupported facts were abstained; scope and deletion checks passed. A member can discover/select the assistant in the picker. | Repeat the full member chat flow with approved customer-owned model + embeddings credentials and record citations/deletion evidence. |
| Cloud: connector, only if separately scoped and accepted | Customer template has no MCP server. A synthetic calendar sandbox exists on a separate test network; it is not a customer connector. Production Cloud copy excludes connectors from base scope. | Keep connectors out of the base offer until a named integration passes compatibility, permission, and data-path acceptance tests. |
| Cloud: managed hosting, updates, backups, restore checks | Encrypted local snapshot and isolated full restore passed. New deployment wording requires a per-customer backup/recovery plan. | Secure/remove legacy plaintext test snapshots; define cadence/retention and portable key escrow; test off-host backup, VPS patch/update procedure, recovery target, monitoring, and restore on the actual VPS. |
| Cloud: setup guide, onboarding, 1.5 support hours and 2-business-day response | Reusable pilot scope/acceptance worksheet and operator handoff runbook are now in `deploy/customer/`. | Rehearse onboarding, support intake/time tracking, response target, and recovery on a real deployment. |
| Cloud: customer-owned provider billing | An earlier disposable user-scoped Qwen chat succeeded and a no-key member was denied rather than inheriting a peer's key. Provider-account usage was not confirmed. Current staging chat-provider keys are placeholders; OpenClaw CLI currently fails local config validation. | Configure the test/customer-owned provider key through the approved secure path, repeat the member test, and confirm usage in that provider account. |
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
- Correction from the 06:14 EDT expanded coupon read: the earlier
  non-expanded response was insufficient to determine product scope. All
  three live coupons do have `applies_to` lists, each matching its
  corresponding active product; all three were valid and unused
  (`times_redeemed=0`) and each promotion code allows three redemptions. Keep
  monthly links inactive until sandbox tests prove each code is accepted for
  its matching product and rejected for the other two. The site's
  first-three-deployments cap is still manual across tiers. See [Stripe coupon
  product restrictions](https://docs.stripe.com/billing/subscriptions/coupons).
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
  prove customer-owned provider billing, substitute for member-facing grounded
  chat/citation acceptance, or prove the public VPS boundary. Customer deployments
  must use the customer's own embeddings credential.
- The remaining gates are: member-facing grounded chat/citation acceptance with
  customer-owned credentials; a dedicated Stripe sandbox rehearsal and
  customer-consented deferred-billing test; owner/tax-advisor resolution of tax
  setup; review or encryption
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

## Credential and runbook consistency recheck — 2026-10-28 06:17 EDT

- Read-only runtime classification (values withheld): the primary staging RAG
  container has a non-placeholder embeddings key, but key identity and
  billing-account ownership are unverified. The restore-copy RAG key is
  placeholder/unset. The running primary LibreChat API's OpenRouter, OpenAI,
  Anthropic, and Google chat-key variables are placeholders.
- `openclaw models status` fails before model discovery because the local
  OpenClaw config does not pass the installed CLI's schema validation. No key
  was extracted or copied, no OpenClaw config was changed, and no model request
  was made. The requested low-cost model test remains open.
- Corrected the pilot scope's stale statement about coupon eligibility and
  updated the readiness matrix with the latest member/API evidence and its
  limits. `git diff --check` passed; no app or customer runtime state changed.

## Post-resume regression check — 2026-10-28 06:22 EDT

- Re-ran customer-init, customer-preflight, backup-safety, seven embeddings-key
  helper tests, and four fail-closed patch tests; all passed. The primary and
  restore-copy loopback login pages both returned HTTP 200.
- Re-ran the isolated fail-closed RAG integration using a generated synthetic
  environment on the external SSD, an intentionally invalid provider key, and
  a loopback-only endpoint. The upload correctly returned HTTP 500 and stored
  zero vectors; the disposable app/database containers, network, and volume
  were removed. No external provider request or customer data was used.
- Stripe's connected-account list still exposes only Gombey Tech in live mode,
  and the Stripe CLI is not installed. No sandbox was created and no live
  billing objects or settings were changed. A dedicated test environment and
  its billing rehearsal remain open.
- The existing untracked `tmp/` was preserved. These local checks do not close
  the authenticated member UI, customer-owned provider billing, Stripe
  sandbox/tax/consent, or approved production VPS acceptance gates.

## Current two-deployment isolation audit — 2026-10-28 06:32 EDT

- Re-ran `scripts/customer-isolation-check.py` against the running primary
  staging and backup-restore deployments. The read-only audit passed: networks
  and persistent storage roots are disjoint, each app resolves its own MongoDB,
  cross-project Mongo DNS is blocked both ways, and MongoDB, Meilisearch,
  pgvector, and RAG publish no host ports.
- This verifies deployment-level separation only; it does not establish
  member authentication, customer-owned provider billing, public VPS exposure,
  or production readiness. No container or data was changed.

## Continuation regression check — 2026-10-28 10:36 EDT

- Re-ran customer initialization, customer preflight, encrypted-backup safety,
  and all 13 Python unit tests; all passed. Both loopback staging login pages
  returned HTTP 200.
- The primary staging RAG service passed a self-cleaning synthetic
  embed/scope/query/delete smoke. Every request returned HTTP 200, the exact
  synthetic marker was retrieved only in its own entity scope, and the vector
  was confirmed absent after cleanup. No chat completion or customer content
  was used; the configured owner test embeddings credential was not printed.
- The disposable fail-closed integration passed again: upload to the
  deliberately unavailable loopback embeddings endpoint returned HTTP 500,
  zero vectors were written, and its unique test containers, networks, and
  volume were removed. The read-only deployment isolation check also passed:
  separate networks/storage, blocked cross-project Mongo service discovery,
  and no host-published database, search, vector, or RAG ports.
- Stripe account discovery still exposes only the live Gombey Tech account.
  The official Stripe CLI v1.55.3 macOS ARM binary was checksum-verified and
  run temporarily from the external SSD; CLI authentication was unavailable,
  so no login, sandbox creation, or Stripe API mutation was attempted. The
  temporary download was removed. Dedicated sandbox access and the billing
  rehearsal remain open; Live mode was not changed.
- The checkout was synced at `23fd87b` before this note; the pre-existing
  untracked `tmp/` directory was preserved. No customer data, production
  website, VPS, DNS, live Stripe objects, or live tax settings changed.

## Headless Chromium member agent-picker acceptance — 2026-10-28 10:55 UTC

- In the isolated restore copy at `127.0.0.1:3084`, two disposable `USER`
  accounts signed in through the actual login page. Both returned HTTP 200 for
  the authenticated user and agent-list requests, saw the same single shared
  `Juniper & Slate Studio Workflow Assistant`, and could read its basic detail
  (HTTP 200). Both received HTTP 403 for expanded agent configuration and
  version history, confirming viewer-only access.
- A separate disposable member opened the model picker, switched to “My
  Agents,” saw the shared assistant, and selected it; the chat header reflected
  the selection. No message was sent, so this did not call a model or consume
  provider usage.
- All three disposable accounts were deleted through LibreChat's supported
  account-deletion paths. The restored database again lists only its five
  baseline synthetic accounts; no temporary `mvp-ui-*` account remains. The
  restore API was restarted after the offline cleanup and is healthy; its login
  page returns HTTP 200.
- This closes the member sign-in, shared-agent discovery/selection, and viewer
  ACL checks in headless Chromium. It does not close a member-facing grounded
  chat with citations using customer-owned chat and embeddings credentials,
  provider billing ownership, Stripe sandbox/deferred-billing rehearsal, tax
  review, or production VPS acceptance. No live billing, DNS, VPS, or customer
  data was used.
- The Hostinger read-only VPS inventory request was attempted again but timed
  out; no inventory result was available. No VPS purchase, setup, power, DNS,
  or nameserver action was issued, so existing account VPS state remains
  unverified.

## Public-offer source-copy audit — 2026-10-28 07:05 EDT

- Compared the Vercel site's current local source with the live HTML response
  and the MVP acceptance matrix. The published prices and tier boundaries stay
  unchanged.
- Updated local `index.html` copy to state the verified base scope more plainly:
  one agreed workflow, one shared/admin-managed knowledge assistant, named
  accounts, and customer-owned AI-provider billing. It now explicitly says
  ordinary chats do not automatically retrieve from the shared collection and
  that extra agents, connectors, write actions, and automation require separate
  scope and acceptance.
- Corrected the billing explanation: setup installments do not create a
  subscription; the customer must complete a separate recurring checkout and
  authorize payment. The 30-day trial starts at that checkout; it aligns to
  delivery + 30 days only when enrollment happens at accepted delivery. This is
  consistent with the configured Stripe link behavior and does not claim the
  setup payment automates subscription enrollment.
- Source checks passed: Python HTMLParser parse, required offer/billing boundary
  assertions, and `git diff --check`. This is source-only on
  `codex/mvp-offer-scope-2026-10-27`; no production deployment, prices, Stripe,
  VPS, DNS, or customer data were changed.
- This copy change is committed as `08b1f93` and pushed to
  `codex/mvp-offer-scope-2026-10-27` in the website repo. Public production
  retains the previous wording until a website deployment is made. The
  separate hard gates in this matrix remain.

## Provider input status check — 2026-10-28 07:09 EDT

- Read-only container-environment classification found the primary and restore
  LibreChat API containers both use `user_provided` sentinels for their
  instance-wide OpenAI/OpenRouter keys. This is consistent with BYOK and is not
  a usable chat credential for a new synthetic member.
- Both RAG containers have an embeddings value present, but this check did not
  inspect or print it and did not verify validity or account ownership. Prior
  acceptance notes distinguish the primary owner's test setting from the
  restore copy's rejected credential; do not treat either as customer proof.
- No account database credentials were queried, no key was copied or revealed,
  and no provider request was made. A further live member chat needs a valid
  key entered into that member's own LibreChat provider settings through the
  approved secure path; existing OpenClaw secrets remain non-exported.
- Both local stacks remain healthy on loopback ports 3083/3084. No Docker,
  customer data, Stripe, website, VPS, or DNS state changed.

## Public offer copy deployment — 2026-10-28 07:11 EDT

- Deployed website source commit `08b1f93` to Vercel production as
  `dpl_8JK19dxJYuU6i1a2MDnQDjZX2K66`; Vercel reports Ready and the aliases
  include `https://gombeytech.com` and `https://www.gombeytech.com`.
- Read-only live HTML checks passed for title, one-workflow/shared-assistant
  boundary, ordinary-chat retrieval limitation, separate subscription
  checkout, trial-start timing, removal of the old automatic-start wording,
  and unchanged $1,995 founding setup price.
- No Stripe settings/products, prices, VPS, DNS, customer data, or application
  runtime were changed. Website source stays on its feature branch; no merge.

## Candidate member-agent permission gate — 2026-10-28

- The clean local candidate is running on `127.0.0.1:3085`, with two synthetic
  accounts and empty agent/file/chat/key data after cleanup. Its application
  source is `e31577f`; the latest branch commit `4f778b7` is documentation-only.
- A runtime test found that the default USER role could create private agents.
  We corrected the candidate's USER agent permissions through LibreChat's
  supported role API, retaining Use while disabling Create, Share, and Public
  Share. The follow-up test passed admin create/share, member discover/basic
  view, and member denial (HTTP 403) for expanded config, version history,
  edit, ACL access, duplication, and creating another agent. The disposable
  File Search agent was deleted; no provider calls or real data were used.
- `deploy/customer/README.md` now makes the role setting a required step after
  first-admin bootstrap and before employee provisioning. It is persisted in
  the customer database, not guaranteed by YAML alone, so each fresh install
  and post-restore/upgrade check must verify it.
- This closes the branch-matched member-agent authorization check only. The
  visible-browser test on this candidate, customer-owned provider/embedding
  billing, persistent customer-key File Search, secure off-device backups,
  Stripe sandbox billing rehearsal, and Hostinger VPS acceptance remain open.

## Stripe sandbox access recheck — 2026-10-28 07:12 EDT

- Read-only Stripe account discovery still returns only the Gombey Tech live
  account. The local Stripe CLI is not installed in the current environment.
- No sandbox was created or claimed, and no live/test payment objects or
  settings were changed. Subscription trial, payment-method consent, coupon,
  and tax rehearsal remains blocked on a dedicated sandbox.

## Stripe live offer recheck — 2026-10-28

- Re-fetched `https://gombeytech.com` read-only (HTTP 200, title “Gombey AI”).
  The live page currently presents Cloud Workspace ($399 standard / $349 for
  12 months; $2,500 setup / $1,995 launch), Workspace Appliance ($699 / $599;
  $4,500 / $3,995), and Private Local AI ($1,499 / $1,299; $7,500 / $6,995).
  It says the founding offer is limited to the first three deployments total,
  setup is split 50/50, monthly billing uses a separate customer-authorized
  subscription checkout, and the 30-day trial starts at enrollment.
- Read-only Live Stripe reads confirm the three active products and their
  matching product-scoped, valid repeating coupons: $50/$100/$200 off per
  month for 12 months, with zero redemptions at this check. Their active
  promotion codes each allow three redemptions and have no expiry; the site's
  global first-three-deployments limit therefore still needs manual tracking.
- The three active payment links collect only the launch setup kickoff halves
  ($997.50/$1,997.50/$3,497.50). Each has automatic tax enabled, but the latest
  read returned zero active Stripe Tax registrations. Hold these links until
  the owner/accountant confirms the correct tax treatment and required
  registration; enabling automatic tax alone does not establish registration.
- The three recurring subscription links remain inactive. Each uses the
  standard monthly price, permits promotion codes, requires a payment method,
  and starts a 30-day trial at the separate enrollment checkout; automatic tax
  is disabled. No active delivery-balance links were found. Do not activate or
  send these until the dedicated sandbox rehearsal verifies consent wording,
  product-specific discount eligibility, trial/coupon timing, tax behavior,
  cancellation, and first-charge handling.
- This was a read-only audit: no Stripe products, prices, coupons, promotion
  codes, payment links, invoices, subscriptions, tax settings, or payments
  were changed or created. The MVP remains open on the sandbox billing rehearsal,
  tax-treatment decision, authenticated member File Search with customer-owned
  credentials, and approved public VPS acceptance.

## OpenRouter credential and model smoke — 2026-10-28

- The requested OpenClaw OpenRouter credential was read in-process from its
  protected credential store (mode `0600`) and was never printed, committed,
  or saved into Gombey. `openclaw models status` itself timed out at 10 seconds;
  no OpenClaw config was edited.
- A direct, synthetic OpenRouter request to
  `deepseek/deepseek-v4.1-flash-1017` with a 16-token output cap returned no
  visible answer because reasoning consumed the output budget. A second
  request with reasoning disabled and a 32-token cap returned the expected
  text (`finish_reason=stop`, 12 input and 6 output tokens, reported cost
  $0.00000426). Combined cost for both calls was $0.000010498. OpenRouter's
  docs confirm reasoning tokens count toward `max_tokens` and recommend a
  larger budget or lower/disabled reasoning.
- This verifies the credential and model route only; it bypassed Gombey and
  does not prove a member's LibreChat BYOK settings or customer billing. The
  candidate API chat-provider environment remains placeholder-only, and its
  RAG embeddings value is placeholder-like. The primary staging RAG value is
  non-empty but provider identity, validity, and billing ownership were not
  verified. No app/database setting or provider key was changed.
- The OpenRouter credential/model test is now complete. Gombey's per-user
  provider-key setup, customer-owned embeddings, 30-page shared File Search
  with citations, visible member UX, and customer billing verification remain
  open. No customer content, Stripe mutation, production deployment, or VPS
  was involved.

## Candidate read-only follow-up — 2026-10-28

- Reconfirmed the branch-matched candidate at `127.0.0.1:3085`: `/health` and
  `/login` both return HTTP 200, and the API remains loopback-only. The Codex
  browser was pointed at the candidate login page; no authenticated UI actions
  were performed.
- The current candidate database has one ADMIN and one USER, with no agents,
  files, conversations, or messages. Both account labels match QA/test fixture
  naming patterns; no account passwords or provider keys were read or changed.
- A fresh read-only isolation check between the candidate and
  `gombey_backup_restore_20261027` passed: networks and storage roots are
  distinct, cross-project Mongo DNS is blocked in both directions, and
  MongoDB/Meilisearch/pgvector/RAG have no published host ports.
- Customer init, preflight, backup-safety, RAG fail-closed (4), embeddings-key
  helper (7), and full Python (13) test suites passed again; `git diff --check`
  passed. This still does not establish visible-browser member acceptance,
  customer-owned provider billing, Stripe sandbox/tax readiness, or public VPS
  security.

## Continuation verification — 2026-10-28 12:10 UTC

- Re-ran the primary local staging RAG smoke with synthetic text and its
  configured owner test credential. Embed, own-scope lookup, unrelated-scope
  isolation, retrieval of the exact marker, deletion, and post-delete absence
  all returned the expected results (HTTP 200). No test vector remains. This
  validates the local RAG service path, not customer-owned billing.
- Re-read the live Stripe products, prices, coupons, all six payment-link
  records, and active Tax registrations. Product prices and the three
  product-scoped 12-month coupons still match the public offer; no coupons
  have been redeemed. The three active links map to only the founding setup
  kickoff halves: Cloud $997.50, Appliance $1,997.50, and Private Local AI
  $3,497.50. Each has automatic tax enabled, but Stripe still reports no
  active tax registrations. Hold these links pending owner/accountant review.
- The three delivery-half setup prices exist, but there are no active links
  for them. The separate monthly links remain inactive and require a separate
  customer-authorized enrollment; they collect a payment method and start a
  30-day trial at enrollment. Their metadata says to send after accepted
  delivery, but Stripe does not tie that event to the earlier setup payment.
  Therefore the setup checkout does not automatically schedule a charge
  30 days after delivery. No Stripe objects or settings were changed.
- The three active founding kickoff links have no completion restriction. The
  per-tier three-use coupons/codes do not enforce the website's global cap of
  three deployments across all tiers. Added an operator-only allocation
  procedure to deploy/customer/OPERATIONS-HANDOFF.md: keep the links private,
  track three slots outside GitHub, verify a slot before offering the rate,
  and stop sharing founding links after the third allocation.
- Explicit reruns passed: customer-init, customer-preflight, customer-backup
  safety, RAG fail-closed (4 tests), embeddings-key helper (7 tests), and
  git diff --check. Root-level python3 -m unittest discover found no tests and
  exited 5; it is not counted as a passing test suite.
- The native Codex browser was opened to the isolated candidate login at
  127.0.0.1:3085; no authenticated interaction was possible with the current
  synthetic candidate credentials. The prior headless member-agent checks
  remain valid, but a visible-browser walkthrough is still open.
- A read-only Hostinger VPS inventory request again remained pending for more
  than two minutes and was stopped without a result. Existing account VPS
  availability remains unknown; no purchase, power, DNS, or network action
  was issued.
- No production app, public website, live Stripe state, VPS, DNS, or customer
  data was changed. The MVP goal remains open on customer-owned provider proof,
  Stripe sandbox and tax/consent rehearsal, off-device recovery, and approved
  public VPS acceptance.

## Candidate and Calendly continuation — 2026-10-28 08:39 EDT

- Rechecked branch-matched candidate `e31577f` on loopback port 3085. Login
  and health both return HTTP 200. Its database contains two synthetic test
  accounts (one ADMIN and one USER), but zero agents, files, conversations,
  or user API-key records. The candidate has no usable RAG embeddings key;
  production preflight correctly rejects the placeholder configuration.
- The candidate's synthetic RAG smoke therefore returned HTTP 500 at embed,
  and its cleanup endpoint could not confirm cleanup. A separate read-only
  pgvector row count returned zero, so no vector was stored. Do not count this
  as grounded retrieval acceptance. A separate fail-closed integration using
  an invalid key and a loopback-only endpoint passed: upload returned HTTP 500,
  zero vectors were written, and its disposable containers, networks, and
  volume were removed.
- Candidate-versus-restore isolation passed again: networks and persistent
  data roots are separate, cross-project Mongo discovery is blocked both
  ways, and MongoDB, Meilisearch, pgvector, and RAG have no published host
  ports. Customer init/preflight tests, encrypted-backup safety, all 13 Python
  unit tests, four fail-closed patch tests, and `git diff --check` passed.
- Calendly still lists only the existing active generic 30-minute event. Three
  requests to create Plus/Pro/Max-specific event types were denied by the
  connected account; no event types were created or altered. Write-capable
  Calendly authorization is still required before linking tier-specific
  booking pages on the website.
- No real data, provider request, Stripe object, production website, VPS, or
  DNS was changed. Member-facing shared File Search, customer-owned provider
  billing, visible-browser acceptance, Calendly write access, Stripe sandbox
  and tax/consent rehearsal, encrypted off-device recovery, and approved
  public VPS acceptance remain open.

## Billing and Hostinger access recheck — 2026-10-28 08:48 EDT

- Current Stripe account discovery exposes only Gombey Tech in live mode; no
  sandbox account is connected to this session. The Stripe CLI is not
  installed. I did not switch modes, inspect or mutate live billing objects,
  create a sandbox, or create any payment/invoice/subscription.
- Hostinger's read-only `vps_virtual-machines_list` request again timed out
  after 300 seconds. No inventory result was returned and no VPS, DNS, or
  billing write was issued. Do not infer that a VPS is or is not present.
- The candidate environment file remains mode 600 with the embeddings value
  set to a placeholder, and the running candidate RAG container has no
  embeddings key. Positive File Search acceptance remains blocked until an
  owner-approved test key is entered through a protected path.

## Resumed verification — 2026-10-28

- Re-ran customer initialization, deployment preflight, encrypted-backup
  safety, all 13 Python unit tests, and all four RAG fail-closed tests; all
  passed. `customer-isolation-check.py` again confirmed the branch-matched
  candidate and restore copy use disjoint networks and storage, cannot resolve
  each other's Mongo service, and expose no database/search/vector/RAG host
  ports. Candidate `/health` and `/login` both return HTTP 200; only its API is
  published, on `127.0.0.1:3085`.
- One isolated OpenClaw request to DeepSeek V4 Flash returned the expected
  synthetic result (`63`) with HTTP 200; OpenRouter reported `$0` for that
  request. This validates the saved OpenClaw model profile only. It does not
  configure or validate provider access inside the Gombey candidate.
- The candidate `.env` remains mode 600 and has no usable chat-provider or
  embeddings credential. No real credential was written there, and no
  candidate agent, test account, file, or conversation was created. The native
  Codex browser is open to the candidate login, but an authenticated browser
  walkthrough is still pending.
- The candidate's positive embeddings/File Search test therefore remains
  blocked. Other open gates remain customer-owned provider proof, Stripe
  sandbox and tax/consent rehearsal, off-device recovery, and approved public
  VPS acceptance. No live billing, production website, VPS, DNS, or customer
  data changed.

## Current Stripe and offer alignment — 2026-10-28 09:05 EDT

- Re-read the public `gombeytech.com` page and the live Stripe catalog. The
  three product names and standard/launch amounts match: Cloud $2,500 setup /
  $1,995 launch and $399/$349 monthly; Appliance $4,500 / $3,995 and
  $699/$599 monthly; Private Local AI $7,500 / $6,995 and $1,499/$1,299
  monthly. Public workflow, provider-billing, and hardware boundaries remain
  reflected in the Stripe product descriptions.
- Stripe has three active launch setup-kickoff payment links at $997.50,
  $1,997.50, and $3,497.50. Each link has no completion cap and has
  `automatic_tax.enabled=true`. Stripe returned no active Tax registrations;
  its [official Payment Links guidance](https://docs.stripe.com/tax/payment-links)
  says it calculates tax only where the
  merchant has an active registration and returns zero without one. Keep these
  links private and do not send them until the owner's tax/accountant review
  resolves registration and tax treatment. No link or tax setting was changed.
- Three recurring checkout links remain inactive, one per tier. They are
  separate from setup checkout, require a payment method, and start a 30-day
  trial when the customer enrolls; they do not automatically enroll or reuse
  the setup payment method. Each launch promotion code permits up to three
  redemptions, but the promised three-deployments-total cap across tiers still
  requires a manual shared allocation register.
- Stripe account discovery still exposes only the Gombey Tech live account;
  no sandbox is connected. A Stripe account-management authorization URL was
  generated for the owner to connect a dedicated sandbox. No sandbox, live
  billing object, invoice, subscription, checkout, or charge was created.

## Branch candidate RAG recheck — 2026-10-28

- Rechecked the branch-matched candidate on `127.0.0.1:3085`: `/health` and
  `/login` return HTTP 200. Its embeddings configuration is still the
  unconfigured placeholder. The synthetic positive RAG smoke therefore
  returned HTTP 500 at embed and cannot be counted as retrieval acceptance.
- The smoke's scoped ID and delete endpoints also returned HTTP 500. A direct,
  read-only PostgreSQL catalog check found zero public tables in the candidate
  vector database, so the failed request created no vector records. No
  customer or evaluation-document content was sent.
- Hardened `scripts/customer-rag-smoke.py` to check the unique entity/file scope
  before deleting, avoid a blind delete after a failed ingest when the scoped
  check is unavailable, and report cleanup uncertainty explicitly. Added a
  regression test proving a failed ingest with an empty scope does not issue a
  delete. The full Python suite now passes 14 tests; customer init, preflight,
  encrypted-backup safety, and four fail-closed patch tests also pass.
- A fresh rotated embeddings credential is still required to run positive
  File Search on this candidate. No credential was read from the older
  OpenClaw profile or written to the candidate environment; the existing
  primary/restore synthetic test results remain separate evidence.
- Restarted only the isolated candidate's API, MongoDB, Meilisearch, pgvector,
  and RAG services. Each returned healthy; candidate `/health` and `/login`
  stayed HTTP 200, and its synthetic database counts were unchanged (two
  accounts, zero agents/files/conversations/provider-key records). The
  candidate and restored-copy isolation check passed again with disjoint
  networks/storage and no database, search, vector, or RAG host ports.
- The candidate's API and RAG Compose configuration hashes match the
  branch-mounted Compose files. This verifies config alignment, not a
  successful embeddings/provider integration. No customer or evaluation
  documents were uploaded.

## No-key RAG smoke regression — 2026-10-28 09:25 EDT

- Added a deterministic local fake-service test for the successful smoke path:
  embed the synthetic marker, verify own and unrelated scopes, retrieve the
  marker, delete only the exact synthetic file, and confirm it is absent.
  This uses no external provider and incurs no API cost.
- All 15 Python tests across the three script test suites passed, as did
  customer initialization, deployment preflight, encrypted-backup safety, and
  `git diff --check`.
- Rechecked the candidate and protected env files: the embeddings key remains
  the setup placeholder, and the hidden-input prompt is still waiting. No key
  was used or printed. This improves the smoke runner's local test coverage
  but does not pass provider-backed embeddings or member-facing File Search.
- Committed and pushed the scoped test/doc change as `9116e02` to
  `codex/gombey-mvp-preflight-2026-10-27`; unrelated `tmp/` remains untouched.

## Stripe billing and offer recheck — 2026-10-28 09:33 EDT

- Read-only Stripe and public-site recheck: `gombeytech.com` returns HTTP 200;
  the three published service offers and their standard/founding setup and
  monthly amounts match the active Stripe products/prices. All three active
  products have an image. No catalog object was changed.
- Stripe still exposes only the live Gombey Tech account. It has three active
  one-time kickoff links ($997.50/$1,997.50/$3,497.50), each with
  `automatic_tax.enabled=true`, no completion cap, no subscription data, and
  no `payment_intent_data.setup_future_usage`. Thus these links do not save a
  payment method for a later off-session subscription. Three separate monthly
  subscription links remain inactive, with standard rates and 30-day trials.
- Zero Stripe Tax registrations are configured. Treat the live kickoff links
  as not ready to send until tax treatment is reviewed; enabling automatic tax
  alone does not establish collection in an unregistered jurisdiction.
- The 15 active Price objects include duplicates: each of the six one-time
  installment amounts exists twice. Line-item inspection found one duplicate
  of each founding kickoff installment used by the active link; the standard
  setup installments have no active payment link. Do not deactivate or delete
  prices until sandbox/dependency review confirms they're unused.
- Updated `docs/STRIPE-BILLING-TEST-PLAN.md` to match the owner's desired
  no-second-checkout flow: collect explicit off-session consent and save a
  reusable method at kickoff; after accepted delivery and the second setup
  installment, create one subscription on that same customer with a 30-day
  trial. This remains a proposed sandbox test, not a live configuration;
  Gombey has no billing/webhook code to automate the delivery transition.
- Added a checkout-disclosure checklist for the setup balance, launch and
  renewal prices, first-charge date, off-session consent, failure/cancellation
  path, and separately billed provider usage. It is a draft checklist, not a
  legal contract; legal/tax review is still required before live use.
- No Stripe settings, links, prices, invoices, subscriptions, tax settings,
  website, VPS, or DNS were modified. The dedicated Stripe sandbox and tax
  review remain prerequisites to a live charge.

## Resumed local MVP checks — 2026-10-28 09:38 EDT

- The branch is synchronized with origin at `baa04d3`. Pre-existing untracked
  `tmp/` is user data and remains untouched.
- Candidate `127.0.0.1:3085` and restore `127.0.0.1:3084` are healthy; their
  login and health endpoints return HTTP 200. The read-only deployment
  isolation check passed again: networks and storage roots are disjoint,
  cross-project Mongo DNS is blocked, and MongoDB/Meilisearch/pgvector/RAG have
  no published host ports.
- Fifteen Python tests, customer initialization, deployment preflight, and
  encrypted-backup safety tests passed. The disposable fail-closed container
  integration returned the expected HTTP 500 for a synthetic invalid key,
  stored zero vectors, and removed its container, database, networks, and
  volume. The legacy Docker builder emitted a missing-buildx warning but the
  AMD64 image build and test succeeded under local ARM emulation.
- The generated synthetic corpus is present locally: the Operations Manual is
  33 pages, Campaign Briefs 31 pages, and Workflow SOPs 33 pages. The separate
  answer key is not for upload. These PDFs have not been imported into the
  branch candidate; no agent or test files are present there.
- Candidate model configuration defaults to GPT-6 Luna and lists optional
  DeepSeek V4 Flash and Qwen 3.5 9B OpenRouter test entries. They require a
  valid owner-controlled provider key. Sanitized candidate env inspection
  confirms both chat and embeddings credential fields are still setup markers;
  the protected key-entry prompt remains open. No key was copied from another
  profile or used.
- Provider-backed File Search, citations, member-visible shared-agent access,
  Stripe sandbox/Tax and consent rehearsal, off-host recovery, and approved
  public VPS acceptance remain open gates. No live Stripe/site/DNS/VPS or
  customer-data change occurred.

## Live offer and capability alignment recheck — 2026-10-28 09:42 EDT

- `https://gombeytech.com` returned HTTP 200 and the page title is `Gombey AI`.
  The live page lists Cloud Workspace ($2,500 standard/$1,995 launch setup;
  $399 standard/$349 monthly for 12 months), Workspace Appliance ($4,500/
  $3,995 setup; $699/$599 monthly), and Private Local AI ($7,500/$6,995 setup;
  $1,499/$1,299 monthly). It labels the founding offer as the first three
  deployments and distinguishes launch from renewal pricing.
- The cloud offer says VPS, DNS/TLS, and recovery checks must pass before
  customer data is loaded. Appliance and local-inference offers explicitly
  require hardware-specific validation, workload fit, and written scope; the
  page also says hardware is quoted separately and makes no blanket privacy
  guarantee. Keep those offers acceptance-gated rather than representing them
  as already verified deployments.
- The page's three-deployment cap is operationally enforced by a private shared
  allocation register; Stripe's individual live promo codes are not a global
  cross-tier cap. No public copy, live Stripe object, or checkout link was
  changed in this review.

## Fresh restored-copy member ACL check — 2026-10-28

- A read-only probe using all four existing synthetic `USER` accounts and an
  `ADMIN` against the restore deployment confirmed that every member can list
  and open the shared Juniper & Slate agent's basic view (HTTP 200), and every
  member is denied expanded configuration and version history (HTTP 403); the
  admin can open both (HTTP 200). The probe generated short-lived access
  tokens in memory using LibreChat's own token helper, created no account or
  database record, and sent no provider/model request.
- The initial failed probe was aimed at `/api/agents/v1/agents/...`, which is
  LibreChat's machine-to-machine OIDC management API, and used MongoDB `_id`
  instead of the agent's public `id`. Its 401/404 responses were harness
  mistakes, not an application defect. The correct member routes are
  `/api/agents` and `/api/agents/{agent.id}`.
- Sanitized checks found the candidate and restore API/RAG container chat and
  embeddings environment values absent or still setup placeholders. No
  credential was printed or used. Candidate member File Search with grounded
  citations remains gated on approved credential entry; this read-only ACL
  result does not substitute for that test.
- No live payment, Stripe object, production website, DNS, VPS, or customer
  data was changed.

## Base-pilot role least-privilege verification — 2026-10-28

- Set the `USER` role on the isolated branch candidate to allow shared-agent
  use and File Search/citations while denying agent creation/sharing, MCP
  servers, skills, schedules, code execution, and web search. The candidate
  remains a synthetic two-account database with no agent or customer files;
  its `ADMIN` role was left unchanged.
- Applied that profile to the restored synthetic workspace and tested every
  existing member. All four members listed and opened the shared Juniper &
  Slate assistant (HTTP 200) and were denied its expanded configuration and
  version history (HTTP 403). MCP server, schedule, and skill list requests
  returned HTTP 403. The admin retained HTTP 200 access.
- The assistant's only configured tool is File Search. Both deployments use
  the same pinned LibreChat image digest. This closes the role and shared-agent
  authorization checks for the base pilot, but not provider-backed member
  chat, vector ingestion, grounded citations, or the visible-browser flow.
- The credential-entry prompt remains a user-side gate: candidate chat and
  embedding keys are still absent or placeholders. No key was read from an
  older profile or printed. No live Stripe, public site, DNS, VPS, or customer
  data was changed.

## Embeddings credential parity follow-up — 2026-10-28 10:33 EDT

- Re-ran the synthetic RAG smoke against the primary staging service. Embed,
  own-scope lookup, unrelated-scope isolation, retrieval, scoped deletion, and
  post-delete absence all passed (HTTP 200; expected marker retrieved).
- Ran the same self-cleaning synthetic smoke against the candidate and restored
  copies. Candidate embed returned HTTP 500; restore returned an HTTP 200
  wrapper but reported an unsuccessful embed. Filtered logs from both show an
  upstream embeddings HTTP 401 / `AuthenticationError`. The restore scope check
  confirmed the synthetic vector was absent, so no cleanup was needed.
- Non-secret endpoint metadata is consistent across the copies:
  `openai/text-embedding-3-small` via `openrouter.ai/api/v1`. In-memory equality
  checks (no credential values or hashes emitted) found candidate and restore
  credentials identical to one another and different from the primary
  credential that just passed. Do not copy credentials between stacks; the
  candidate/restore credential needs fresh secure entry or correction.
- No customer/evaluation content, live Stripe object, production site, DNS, or
  VPS was touched. The branch candidate's provider-backed File Search remains
  unverified until its own embeddings credential works and a member retrieval
  test passes.

## Fresh deployment-isolation audit — 2026-10-28 10:36 EDT

- Re-ran `scripts/customer-isolation-check.py` against primary staging vs the
  clean branch candidate and restored copy vs candidate. Both read-only checks
  passed: private networks are disjoint, each API resolves its own MongoDB but
  cannot resolve the other deployment's Mongo container, MongoDB/Meilisearch/
  pgvector/RAG publish no host ports, and app/upload/database/search/vector
  persistent roots are distinct.
- This verifies current local deployment separation only; it does not prove
  member ACLs, provider billing, public firewall/DNS/TLS, or VPS exposure. No
  containers or data were modified by the isolation checks.

## RAG smoke diagnostic hardening — 2026-10-28 10:37 EDT

- Updated `scripts/customer-rag-smoke.py` to report whether the RAG API accepted
  an embed, in addition to the HTTP status. This distinguishes HTTP 200 wrappers
  with `status: false` from a successful ingestion without printing provider
  response bodies or sensitive details.
- Added a regression test for HTTP 200 with a rejected embed status; it confirms
  the runner fails and does not issue a blind delete when the synthetic scope
  is empty. All 16 tests across the RAG smoke CLI, fail-closed patch, and
  embeddings-key helper suites pass; `git diff --check` is clean.
- This is harness/test coverage only. No live provider request, customer data,
  live Stripe, production website, DNS, or VPS was changed.

## Known-private-IP isolation check — 2026-10-28 10:39 EDT

- Extended `scripts/customer-isolation-check.py` to probe TCP/27017 from each
  API container to the other project's MongoDB private IP. The check accepts
  only a timeout or explicit host/network-unreachable result; a successful
  connection or unexpected socket error fails closed.
- Primary-vs-candidate and restore-vs-candidate audits both passed in both
  directions. DNS was blocked and direct-IP TCP timed out; own-service DNS,
  distinct networks/storage, and no internal host ports also passed. The audit
  is read-only and remains local-container evidence, not a VPS firewall test.
- Updated `deploy/customer/LOCAL-STAGING.md` with the expanded check contract.
  No container/data or external service was modified.

## Billing workflow alignment — 2026-10-28 10:41 EDT

- Reconciled the customer acceptance worksheet and operations handoff with the
  Stripe rehearsal plan. They now distinguish the intended consented
  saved-method flow (manual subscription creation at delivery) from the
  separate-subscription-checkout fallback, and state that neither is live-ready
  with the current links until sandbox and tax gates pass.
- Stripe account discovery still exposes only the live Gombey Tech account.
  Generated and queued the account-management authorization page in the Codex
  browser so the owner can add a dedicated sandbox. No live Stripe object or
  setting was changed; no test account is connected yet.

## Onboarding regression and tracked-secret scan — 2026-10-28 10:42 EDT

- Re-ran `scripts/test_customer_init.sh` and
  `scripts/test_customer_preflight.sh`; both passed. The latter checks safe
  loopback binding/resource ceilings as well as bad hostname, weak/duplicate
  secrets, copied project namespace, and provider-placeholder cases.
- A limited tracked-file scan for common OpenAI/OpenRouter/Stripe/GitHub token
  prefixes returned no matching tracked path; only `.env.example` templates
  are tracked. No dedicated secret scanner is installed, so this is not a
  comprehensive secret-history audit. No credential values were printed.

## Resumed MVP preflight — 2026-10-28 10:49 EDT

- Re-ran the RAG smoke CLI suite (5), fail-closed patch suite (4), and secure
  embeddings-key helper suite (7); all 16 Python tests passed. Customer init,
  customer preflight, and encrypted-backup safety scripts passed as well.
- Candidate and isolated restore Compose configurations both render cleanly
  with their local-only overlays. The candidate's current API is healthy at
  `127.0.0.1:3085`; MongoDB, Meilisearch, pgvector, and RAG are not published
  on host ports. Candidate login returns HTTP 200. GPT-6 Luna remains the
  configured default; Qwen and DeepSeek are optional test choices.
- The candidate environment file is owner-only mode 600, but its RAG embeddings
  value is still a setup placeholder. The hidden-input helper is waiting and
  targets this candidate environment. No key value was read, copied, or
  printed. A healthy RAG container does not validate provider authentication;
  shared File Search/citation acceptance still needs fresh secure key entry,
  an isolated RAG restart, and member-side retrieval tests.
- Stripe account discovery still returns only the live Gombey Tech account;
  no sandbox is connected. No Stripe object/settings, public site, DNS, VPS,
  customer data, or model-provider request was changed in this check.

## Expanded local deployment-isolation probes — 2026-10-28 10:54 EDT

- Hardened `scripts/customer-isolation-check.py` to require the target API,
  MongoDB, Meilisearch, pgvector, and RAG containers on the deployment's
  internal private network. It now checks cross-project container-name DNS and
  direct TCP reachability to each service's private IP/port in both directions,
  rather than probing MongoDB alone.
- The expanded read-only check passed for primary-staging vs candidate and
  restore-copy vs candidate. Cross-project DNS and private-IP TCP access to all
  five service ports were blocked in both directions; network/storage
  separation and internal host-port checks also passed.
- Updated `deploy/customer/LOCAL-STAGING.md` to document the stronger check.
  No container, data, provider request, billing object, VPS, or DNS setting was
  changed.

## Continued MVP preflight — 2026-10-28 11:31 EDT

- Fresh local regression: customer-init, customer-preflight, encrypted-backup
  safety, the five RAG smoke CLI tests, four fail-closed patch tests, and seven
  embeddings-key helper tests all passed. Read-only isolation checks passed
  again for primary staging vs candidate and restored copy vs candidate:
  cross-project DNS/TCP was blocked, service ports were not host-published,
  and each deployment's persistent storage remained distinct.
- In isolated Chromium (not the owner's Chrome), a disposable `USER` signed in
  to primary staging and discovered the shared synthetic Juniper & Slate
  assistant (HTTP 200). Storing a user-scoped OpenRouter key returned HTTP
  201, and the key metadata endpoint returned HTTP 200. The assistant's actual
  provider-backed answer was not verified in this pass: repeated test logins
  reached the app's five-minute rate limit (HTTP 429). The disposable account
  was then deleted with LibreChat's supported command after stopping only the
  target API; the user-scoped key was removed with it, the temporary credential
  file was removed, and primary staging returned to HTTP 200. No existing
  account was changed. The provider-backed member answer remains unverified in
  this pass.
- Read-only live Stripe recheck (only the live Gombey Tech account is
  connected): three active products and their standard monthly prices remain
  Cloud Workspace $399, Workspace Appliance $699, and Private Local AI $1,499;
  the three valid, unused, product-scoped launch coupons reduce those amounts
  by $50/$100/$200 for 12 months. The active setup links charge only the
  respective 50% founding kickoff: $997.50, $1,997.50, and $3,497.50.
  Each active link has no subscription data and no `setup_future_usage`, uses
  `payment_method_collection=if_required`, and has automatic tax enabled.
- The three monthly subscription links are inactive. Each carries a 30-day
  trial and is a separate checkout; it is not automatically enrolled by the
  setup-payment links. No subscriptions of any status or tax registrations
  were returned. Automatic tax on the active links therefore does not establish
  tax collection; do not send them until the owner/accountant resolves tax
  registration and confirms the applicable treatment. A Stripe sandbox is
  still not connected, so the billing lifecycle has not been rehearsed.
- This pass made no Stripe writes and created no billing objects. No customer
  data, production deployment, DNS, or VPS was changed.

## Member-side Qwen text inference confirmed — 2026-10-28 15:52 EDT

- The current OpenClaw OpenRouter credential was accepted by the provider's
  model-list endpoint (HTTP 200) and by a direct synthetic Qwen completion
  (HTTP 200, exact marker returned). This proves the credential currently
  works; it does not independently prove any older key was revoked or that a
  spend limit is configured. The key stayed in memory and was not printed,
  committed, or written to a deployment environment file.
- In isolated Chromium, a disposable `USER` signed into primary staging,
  selected `Qwen 3.5 9B (OpenRouter test)` in the rendered chat UI, and got the
  exact synthetic reply `QWEN-STAGING-OK`. The endpoint-scoped member key must
  be saved under the exact endpoint name `OpenRouter` and as a JSON envelope
  containing `apiKey` and `baseURL`; a raw-string/lowercase diagnostic write
  produced an error and was replaced before the passing test. No test data was
  sent to the model besides the one-line synthetic prompt.
- Deleted the disposable member with LibreChat's supported CLI after stopping
  only the target staging API. Transaction history was left untouched. A
  database check confirmed no matching user, key, conversation, or message;
  host and container credential files were removed. Staging API and local
  restore/candidate health endpoints returned HTTP 200 after restart.
- This closes ordinary member-side provider-backed text chat for Qwen. It does
  not close member-side File Search, semantic retrieval through the Gombey
  agent UI, citations, uploaded-document deletion, or the production VPS gate.
  No customer records, live billing, production deployment, DNS, or VPS was
  changed.

## Shared long-document retrieval and RAG-scope check — 2026-10-28 12:01 EDT

- A first evaluation pass compared the attached agent corpus with a newer local
  answer key and used mismatched facts. The apparent misses were a test-fixture
  mismatch, not evidence of retrieval failure. The actual shared agent corpus
  is the older synthetic Juniper & Slate set; its three attached PDFs are 31,
  36, and 31 pages. The newer generated PDFs and their answer key are separate
  artifacts and the answer key is not uploaded.
- Re-ran read-only retrieval against the three actual attached file IDs and
  their shared agent scope. Beacon Trail's campaign/date/churn facts were
  present in the Campaign Playbook results; Alder & Finch's HOLD state, missing
  Jamie Rivera written approval, and tentative slot were present in the
  Delivery Records results; and the two independent release gates plus exact
  final-version requirement were present in the Operations Manual results.
  All three requests returned HTTP 200 with six passages, and each result set
  pointed only to its intended PDF. Relevant PDF pages were retrieved for all
  three questions.
- Scope isolation also passed: the shared-agent scope returned all three
  attached file IDs and five query passages, while an unrelated synthetic
  scope returned zero IDs and zero passages for the same file/query request.
- This confirms the configured RAG service can retrieve representative facts
  from each long PDF and filters by the agent scope. It is not yet a member-side
  File Search answer/citation-rendering test, does not verify abstention on
  unknown facts, and does not prove citations in the browser UI. Keep those
  acceptance items open. No upload, vector mutation, customer data, provider
  request, billing, public deployment, DNS, or VPS change occurred.

## Member-side shared File Search, citations, and abstention — 2026-10-28 12:14 EDT

- In isolated Chromium, a disposable `USER` opened the shared, read-only
  Juniper & Slate agent from the member UI. For this test only, the agent's
  provider/model was temporarily switched from `openAI` / `gpt-6-luna` to
  `OpenRouter` / `qwen/qwen3.5-9b`; its instructions, `file_search` tool, and
  three attached PDFs were unchanged. After the checks, provider/model were
  restored and read back as `openAI` / `gpt-6-luna`.
- The member saved the current owner-authorized OpenRouter key through the
  normal per-user UI with the displayed 12-hour expiry. Three synthetic
  member turns each showed `Searched your files` / `Ran File Search`:
  - Beacon Trail Coffee returned the campaign name, Q2 dates, 8.1% baseline,
    and 6.7% target with the Campaign Playbook and Delivery Records cited.
  - The Alder & Finch release question returned `HOLD`, identified Jamie
    Rivera's missing written approval, and treated the reserved date as
    tentative. The answer displayed source titles and page-level citations to
    the Operations Manual and Delivery Records.
  - The deliberately absent public street address was answered “Not specified”
    without inventing an address, with the relevant source titles shown.
- Read-only staging configuration showed the chat completion used OpenRouter
  Qwen 3.5 9B, while query/document embeddings use `text-embedding-3-small`
  through the OpenRouter base URL. In-memory equality comparison confirmed the
  staging RAG credential matched the authorized OpenClaw OpenRouter credential;
  no credential value was printed. This is cloud processing: member prompts,
  retrieval queries, and retrieved passages go to OpenRouter. It is not a
  local-only privacy path.
- Deleted the disposable member with LibreChat's supported deletion CLI after
  stopping only primary staging's API. The CLI retained transaction history.
  A post-restart Mongo check found no matching user, provider-key, conversation,
  or message records. The shared agent remains on GPT-6 Luna with only
  `file_search` and its same three attached files; primary staging health is
  HTTP 200 and Docker reports healthy. The exact temporary credential file and
  isolated browser session were removed/reset.
- This closes a member-side Qwen File Search answer, visible-citation, and
  unsupported-fact abstention check for the attached synthetic corpus. A
  second-member shared File Search/provider-key test was completed afterward;
  see the follow-up below. Customer document removal/reindex acceptance,
  billing rehearsal, and production VPS acceptance remain open. No customer
  data, production deployment, DNS, Stripe write, or VPS was involved.

## Second-member shared File Search and provider-key isolation — 2026-10-28

- A second disposable member could see/select the shared read-only agent but
  could not send a prompt before saving their own provider key; the UI blocked
  inference with “An API key is required to send messages.” After saving their
  own authorized OpenRouter key with the normal 12-hour expiry, the member used
  File Search through `qwen/qwen3.5-9b` and received the correct Renewal Rhythm
  campaign and 8.1% → 6.7% churn target, with PDF source and page citations.
- The test temporarily changed only the shared agent's provider/model; its
  `file_search` tool and three attached file IDs were preserved, and the agent
  was restored to `openAI` / `gpt-6-luna`. The exact synthetic account was then
  deleted from its Account settings. Mongo found no matching user or related
  provider-key, conversation, or message records; the credential file and
  isolated browser session were removed. Staging health returned HTTP 200.
- This verifies shared-agent access plus per-member provider-key separation
  for two members; it is not a blanket proof of all tenant boundaries. This is
  cloud processing through OpenRouter, not local inference. File removal/
  reindex, billing rehearsal, and production VPS acceptance remain open. No
  customer data, live billing, DNS, or public VPS was involved.

## Live Stripe offer/catalog audit — 2026-10-28 (read-only)

- The public pricing page and the connected live Stripe catalog currently agree
  on three active offers: Cloud Workspace, Workspace Appliance (cloud
  inference), and Private Local AI. Stripe has 15 active Prices: three standard
  monthly Prices plus twelve one-time setup-installment Prices (kickoff and
  accepted-delivery halves, each with standard and launch amounts).
- Setup totals match the published page: Cloud $2,500 standard / $1,995
  launch (halves $1,250 / $997.50); Appliance $4,500 / $3,995 (halves $2,250 /
  $1,997.50); Private Local AI $7,500 / $6,995 (halves $3,750 / $3,497.50).
  Standard monthly Prices are $399, $699, and $1,499 respectively. The three
  repeating 12-month coupons reduce monthly by $50, $100, and $200, matching
  the page's $349, $599, and $1,299 founding rates.
- The live coupons are not product-restricted, have no end date, and each allow
  three redemptions independently. Consequently, Stripe does not enforce the
  website's “first three deployments across all tiers” global cap; that cap
  remains an operator check. The setup launch Prices also have no automatic
  global redemption cap. Keep the offers call/proposal-first and check the
  global count before applying a setup or monthly launch rate.
- The website says recurring service is a separate checkout with explicit
  recurring-payment authorization and a 30-day trial; it is not started by the
  setup payment. Stripe's active monthly Prices have no default trial period,
  so the 30-day trial must be set on the later subscription checkout. This
  read-only review did not create invoices, checkout links, subscriptions, or
  charges. The end-to-end subscription consent, trial, first invoice, payment
  failure, and cancellation flow remains untested.
- The only Stripe account available to Codex is Gombey Tech live mode; the
  Stripe CLI is not installed. Do not rehearse this process in live mode. A
  connected Stripe sandbox/test-mode account is required before the billing
  rehearsal. The three retired Plus/Pro/Max product records are inactive; no
  cleanup write was made.
- Stripe returned zero Tax registrations. Product tax behavior/tax codes do
  not themselves register the business or ensure tax collection. Do not enable
  automatic tax based on this catalog alone; confirm obligations and register
  with the relevant authority before relying on Stripe Tax. No Tax setting was
  changed.

## Local cross-deployment isolation and RAG failure-path verification — 2026-10-28

- `scripts/customer-isolation-check.py` passed between primary local staging
  and the restored backup clone: separate Docker networks, private internal
  networks, distinct storage roots, no published internal service ports, and
  no cross-deployment DNS or TCP reachability to API, MongoDB, Meilisearch,
  pgvector, or RAG services.
- `scripts/test_rag_fail_closed_patch.py` passed 4/4 checks. Customer init and
  preflight scripts passed. The disposable RAG integration test used a
  synthetic invalid embedding credential and unreachable endpoint; upload
  failed closed with HTTP 500 and wrote zero vectors. Its temporary Compose
  project, volume, and network were removed by the test script.
- Primary staging remained loopback-only and healthy. This does not replace
  production VPS acceptance or a real-embedding/UI stale-fact deletion test.
  No customer data, live billing, public deployment, DNS, or VPS was involved.

## MVP readiness regression rerun — 2026-10-28

- Re-ran the RAG smoke CLI (5 tests), fail-closed patch (4), and embeddings-key
  helper (7): all 16 Python tests passed. Customer init, customer preflight,
  and encrypted-backup safety tests passed.
- Re-ran the read-only isolation audit for all three pairs among primary
  staging, restored backup, and branch candidate. All passed: networks and
  storage roots are disjoint, cross-project DNS/TCP to API, MongoDB,
  Meilisearch, pgvector, and RAG are blocked, and internal services have no
  published host ports.
- The generated synthetic evaluation PDFs are 33, 31, and 33 pages. This
  confirms the long-file materials exist locally, not that this newer corpus
  has been uploaded to a separate shared agent or fully evaluated in the UI.
  Billing sandbox, native-browser walkthrough, deletion/retrieval, and public
  VPS acceptance remain open.

## RAG upload, retrieval, and deletion smoke — 2026-10-28

- `scripts/customer-rag-smoke.py` passed against primary staging: synthetic
  embed accepted (HTTP 200), own-scope ID lookup passed, unrelated-scope
  lookup did not expose the file, retrieval returned the exact marker, and
  scoped deletion plus post-delete absence both passed (HTTP 200).
- The same smoke against the branch candidate failed at embed (HTTP 500). A
  sanitized runtime check found its `RAG_OPENAI_API_KEY` is still the template
  placeholder; the scoped ID endpoint returned HTTP 200 and confirmed no
  vector remained. This is an unconfigured candidate credential, not evidence
  of a retrieval/code-path failure. Enter a customer-owned test embeddings key
  through the hidden-input helper before retrying candidate File Search.
- This exercises backend vector lifecycle, not uploaded-file deletion through
  the visible app UI. The generated 33/31/33-page PDFs remain local; the
  already-tested shared agent uses its separate 31/36/31-page synthetic
  corpus. Do not treat the new corpus as platform-tested until attached to a
  separate evaluation agent and verified through the member UI.

## Candidate RAG credential-isolated smoke follow-up — 2026-10-28

- A disposable RAG container joined only the candidate's existing private and
  outbound Docker networks. The owner-authorized OpenRouter key was injected
  into that temporary container from memory, not saved to a file or the
  candidate's persistent RAG service. A single synthetic embeddings-provider
  probe returned HTTP 200 with 1,536 dimensions.
- The candidate lifecycle smoke passed: embedding accepted; own-scope ID check
  passed; unrelated-scope check did not expose the synthetic file; retrieval
  returned the exact marker; scoped deletion returned HTTP 200; and a follow-up
  ID check confirmed the vector was absent. The disposable container was
  removed afterward.
- The regular candidate RAG container remains healthy but uses its template
  placeholder. A customer deployment still needs its own embeddings credential
  entered through the protected setup path. This test used synthetic data and
  does not verify customer-owned credentials, uploaded-file deletion/reindex
  through the visible app, or member-side shared-agent UX on this candidate.

## Offer mapping and local regression recheck — 2026-10-28

- Owner confirmed that the hardware/deployment ladder is intentional, not a
  mismatch: entry is a dedicated VPS with cloud inference; the middle tier is
  an on-site Beelink SER5 with cloud inference; the top tier is a locally
  benchmarked Mac Studio, DGX Spark, or Strix Halo workstation. The live
  `gombeytech.com` offer copy explicitly describes these same deployment and
  inference modes; no tier or price change was needed.
- Re-ran customer initialization, customer preflight, encrypted-backup safety,
  and all 16 Python regression tests; all passed. Re-ran all three pairwise
  network/storage isolation checks among primary staging, restored backup,
  and clean candidate; all passed.
- Re-ran the disposable RAG fail-closed integration with a generated
  throwaway environment, synthetic invalid key, and unreachable loopback
  embeddings endpoint. The synthetic upload returned HTTP 500, wrote zero
  vectors, and the temporary containers, volume, and networks were removed.
- The three candidate local login pages and candidate health endpoint returned
  HTTP 200. The clean candidate still has no uploaded evaluation corpus on a
  separate shared agent; member-side long-document UX, customer-owned provider
  billing, Stripe sandbox rehearsal, and public VPS acceptance remain open.
- No production VPS, live billing object, DNS, customer data, or production
  deployment was changed.

## Member shared-agent long-document regression and cleanup — 2026-10-28

- On the loopback candidate, a synthetic member signed in, opened the
  admin-owned, Viewer-shared Juniper & Slate agent, and completed grounded
  File Search questions against the three generated 31–33-page PDFs using
  Qwen 3.5 9B. The tested behaviors included exact-date retrieval, cross-file
  approval/workflow synthesis, abstention when the documents did not contain
  an answer, and refusal to claim that it had published or sent anything.
  Responses included document/page citations. A final-page prompt also
  correctly treated calendar/MCP write access as unavailable and approval-
  gated rather than taking an external action.
- Account-boundary checks passed: the member could read their own conversation
  and use the shared agent, while an admin request for the member's private
  conversation returned 404. The member could not enumerate or manage the
  admin-owned source files directly; the shared assistant performed retrieval.
  These are authenticated API checks, not a visible-browser acceptance run.
- The member's temporary OpenRouter chat key was deleted through the supported
  key endpoint and verified absent. A temporary synthetic smoke file was also
  deleted. The three generated PDFs remain attached to the shared test agent;
  no answer key or customer data was uploaded.
- After removing the temporary evaluator service and reconnecting the normal
  candidate RAG service to its intended networks, both its health endpoint and
  the candidate app health check returned HTTP 200. However, a live synthetic
  embeddings request through that persistent RAG configuration returned HTTP
  401 (`Missing Authentication header`). A sanitized runtime check confirmed
  the normal RAG container still has the template placeholder. Thus the
  successful member File Search run used a temporary evaluator with a working
  test credential; it does not prove the persistent candidate RAG/provider
  path is ready. Enter a fresh authorized test credential through the protected
  setup path and repeat the member retrieval test on the normal candidate
  before closing this gate. This is a missing-credential configuration gate,
  not evidence of a defect in the tier mapping or product description.
- The verified offer ladder remains intentional: entry is VPS-hosted cloud
  inference, the middle tier deploys a Beelink SER5 Mini PC with cloud
  inference, and the highest tier offers an on-device local-inference system
  such as Mac Studio, DGX Spark, or Strix Halo, with hardware/site scope quoted
  separately. No public prices, Stripe products, payment links, DNS, or
  production services were changed during these checks.

## Public offer and live billing follow-up — 2026-10-28

- Fetched the current public pricing page and confirmed its deployment ladder:
  dedicated cloud VPS, Beelink SER5 appliance with cloud AI, and a Mac Studio,
  DGX Spark, or Strix Halo workstation for locally validated inference. This
  matches the owner's intended offer; no tier rename or price edit is needed.
- Read the live Stripe catalog and all six Payment Links without mutation. The
  three active links are one-time founding setup kickoff payments of $997.50
  (Cloud), $1,997.50 (Workspace Appliance), and $3,497.50 (Private Local AI).
  The three monthly subscription links remain inactive; each is configured at
  its standard monthly amount ($399/$699/$1,499), permits the matching launch
  promotion code, and starts a 30-day trial. If used after accepted delivery,
  this fallback starts the 30-day clock when the customer completes that
  separate subscription checkout, not at delivery automatically.
- The public launch prices remain $1,995/$3,995/$6,995 setup and $349/$599/
  $1,299 monthly for 12 months, versus standard setup of $2,500/$4,500/$7,500
  and standard monthly of $399/$699/$1,499. Standard active Stripe Prices
  plus the existing 12-month coupons yield those advertised monthly rates.
  Promotion codes are tier-specific but each permits up to three redemptions;
  the public first-three-deployments-total cap still needs manual cross-tier
  enforcement.
- Rechecked live tax state: zero active Stripe Tax registrations. The active
  setup links have automatic tax enabled, while the inactive monthly links have
  automatic tax disabled. Do not represent either as tax-ready until the owner
  and qualified tax advisor settle registration and treatment.
- The connected Stripe tool currently exposes only the live account. No
  sandbox context is available in this session, so no billing rehearsal was
  run; no mode switch, checkout, invoice, subscription, charge, catalog, link,
  or tax setting was changed. Connect a dedicated sandbox before rehearsing
  the deferred subscription and payment-method-consent flow.

## Public launch-route and Hostinger access follow-up — 2026-10-28

- A fresh HTTP GET to `https://chat.gombeytech.com/` returned HTTP 200 and
  Gombey AI page content. The earlier Cloudflare 1033 was not reproduced, and
  the live landing-page launch links target this hostname. This confirms the
  public login destination is reachable, not that a customer can authenticate
  or that a deployment's acceptance checks passed. No DNS or tunnel settings
  were changed.
- Retried the read-only Hostinger `vps_virtual-machines_list` operation once;
  the tool timed out after 300 seconds without returning inventory. Two earlier
  attempts also timed out. No VPS was created or changed; stop retrying this
  inventory call for now and obtain any required account/server details from a
  successful Hostinger read or the owner before production provisioning.

## Fresh three-deployment isolation recheck — 2026-10-28

- Re-ran all three pairwise checks among primary staging, the restored backup,
  and the clean candidate using `scripts/customer-isolation-check.py`; all
  three passed. Each pair had disjoint Docker networks and persistent storage,
  own-service DNS resolution, blocked cross-project private-service DNS and
  TCP access in both directions, and no published MongoDB, Meilisearch,
  pgvector, or RAG host ports.
- The app's only host binding in these stacks remains loopback-only. Login
  pages on ports 3083, 3084, and 3085 each returned HTTP 200. This is local
  network/storage and route evidence only; it does not replace VPS firewall,
  DNS/TLS, reboot, provider billing, or member UI acceptance.
- Checks were read-only; no containers, data, environment, accounts, or
  provider credentials were changed.

## Continuation regression and provider-state check — 2026-10-28

- Re-ran customer initialization, customer preflight, and encrypted-backup
  safety tests; all passed. Re-ran the RAG smoke CLI (5 tests), fail-closed
  upload patch (4), and protected embeddings-key helper (7); all 16 Python
  tests passed.
- Re-ran the three pairwise deployment-isolation checks across primary staging,
  restored backup, and clean candidate. All passed: private networks and
  persistent storage are disjoint, own-service DNS resolves, cross-deployment
  service DNS/TCP is blocked in both directions, and databases/search/RAG have
  no host-published ports.
- The login and health endpoints on candidate ports 3083, 3084, and 3085 each
  returned HTTP 200. These are loopback staging checks, not public VPS
  acceptance.
- Inspected the candidate's protected environment without displaying any
  secret values: the file is owner-only mode `0600`, but `RAG_OPENAI_API_KEY`
  is still the template placeholder. Therefore no provider-backed request was
  sent; persistent member File Search/provider acceptance remains open until a
  fresh authorized test/customer-owned embeddings key is entered through the
  hidden-input helper and the member test is repeated.
- Clarified the credential runbook: per-user chat-provider keys and the
  server-side embeddings key are separate, and a local candidate must target
  the exact `.env` file used by that Compose project. This avoids silently
  updating the default deployment or a different sibling stack.
- The offer mapping remains as designed: dedicated VPS/cloud inference;
  on-site Beelink SER5/cloud inference; and selected Mac Studio, DGX Spark, or
  Strix Halo hardware/local inference. The Cloud Workspace template does not
  certify the appliance or local-inference hardware tiers; those still require
  commissioning and acceptance on the actual selected device. No tier, price,
  live Stripe setting, DNS record, production deployment, customer data, or
  provider credential was changed.

## Stripe test-access recheck — 2026-10-28

- The connected Stripe account listing currently exposes only Gombey Tech with
  `livemode=true`. The Stripe CLI is not installed in this environment, so no
  sandbox account or sandbox API context was available. No live API write,
  checkout, invoice, subscription, or charge was made.
- A fresh read-only `GET /v1/tax/registrations?status=active` returned an empty
  list. Automatic-tax flags alone therefore do not establish that tax will be
  collected; the owner and qualified tax advisor must determine applicable
  obligations and live configuration before sending links.
- Rechecked the official Stripe billing/payment guidance against the prepared
  rehearsal plan: a one-time Checkout payment does not by default make its
  payment method reusable. Off-session reuse requires the appropriate
  future-use setup plus explicit customer agreement to the timing, frequency,
  amount basis, and cancellation terms. The test plan includes these gates and
  the 30-day trial that begins only when the operator creates the subscription
  after accepted delivery.
- A source scan found no Gombey Stripe API client, webhook endpoint, or
  subscription-creation code. The current onboarding remains an
  operator-managed Stripe process; do not describe subscription creation or
  payment-failure handling as automated. Sandbox rehearsal, live tax review,
  and a confirmed payment-method consent flow remain no-go gates before sending
  any live kickoff link.

## Offer ladder clarification and Stripe read-back — 2026-10-28

- Confirmed the owner’s intended hardware/deployment ladder: Plus is a
  dedicated VPS workspace using cloud inference; Pro is an on-site Beelink
  SER5 workspace that still uses cloud inference; Max is the higher-cost
  customer-owned local-inference workstation option (Mac Studio, NVIDIA DGX
  Spark, or Strix Halo). These are intentionally different deployment levels,
  not a tier mismatch. The public offer mapping and Stripe product descriptions
  now communicate that distinction.
- Read back the live Stripe products after the description edits. Workspace
  Appliance explicitly names the SER5 and says it hosts the workspace without
  running local inference. Private Local AI names the three workstation
  options and states that hardware is separately quoted and performance is
  benchmark-dependent. No product/price activation state was changed in this
  read-back. The product display titles were still the internal descriptive
  names, so they were aligned with the previously requested customer-facing
  tier names: Gombey AI Plus (VPS/cloud), Gombey AI Pro (SER5/cloud), and
  Gombey AI Max (local hardware). A final live read-back confirmed all three
  remain active and all 15 active prices remain attached to the same products.
- Read back all 15 active Stripe Prices: each tier has four one-time prices
  (standard and launch totals split into 50% kickoff and 50% delivery), plus
  one standard monthly recurring Price. Kickoff/delivery amounts reconcile to
  standard setup totals of $2,500/$4,500/$7,500 and launch totals of
  $1,995/$3,995/$6,995. Monthly standard Prices remain $399/$699/$1,499;
  launch monthly amounts depend on the existing tier-specific promotion
  codes/coupons. No price, payment link, coupon, tax setting, invoice,
  subscription, or charge was changed during verification.
- This confirms catalog wording and price arithmetic, not a tested checkout or
  automatic deferred subscription. Sandbox rehearsal, live tax review, and
  explicit consent for future off-session charges remain prerequisites before
  collecting a customer payment or promising automatic monthly billing.

## Long-document retrieval-depth regression and candidate check — 2026-10-28

- The owner reconfirmed the intended offer ladder: Plus is a VPS with cloud
  inference; Pro is an on-site Beelink SER5 with cloud inference; Max is a
  customer workstation for local inference (Mac Studio, DGX Spark, or Strix
  Halo). This is intentional, not a mismatch; no tier, price, or public copy
  change was made for this clarification.
- The loopback candidate's persistent RAG service passed the self-cleaning
  synthetic smoke after the API restart: embedding, own-scope lookup,
  unrelated-scope isolation, exact-marker retrieval, scoped deletion, and
  post-delete absence all returned expected results. The test vector was
  deleted. The candidate embeddings credential remains in its external-SSD
  `.env` with owner-only mode `600`; its value was not displayed.
- Reproduced the JS-C30 retrieval miss directly against the candidate vector
  store. For “What were the actual observed conversion results for JS-C30?
  Give exact count,” the JS-C30 page ranked sixth in the Campaign Briefs PDF
  and was excluded by LibreChat's per-file `k=5`. With per-file `k=10`, page 31
  entered the combined top ten at rank seven. The final model-context merge
  remains capped at ten chunks.
- Added `patches/librechat-file-search-depth.js`, a fail-closed, idempotent
  startup patch for the pinned LibreChat bundle, five Node regression tests,
  and the broad-identifier query to the corpus plan. All five tests pass;
  customer-init, customer-preflight, encrypted-backup, all 16 Python checks,
  Compose validation, candidate health, and another persistent RAG smoke also
  passed. The candidate runtime bundle currently reports per-file depth 10.
- At this checkpoint, a post-patch member answer was not verified: LibreChat's
  supported `create-user` CLI did not produce a disposable member in the
  non-interactive harness. This was later superseded by the dated member test
  below.
- The branch checkout at `/private/tmp` is not mounted into Colima. Attempting
  to recreate the candidate API from that checkout failed on a host bind mount;
  the API was restored from its external-SSD Compose source, then the guarded
  patch was applied to the isolated candidate bundle and its health returned
  HTTP 200. Candidate databases/uploads were not moved or deleted. This proves
  the patch against the exact pinned bundle at that checkpoint. The later
  source-controlled, Docker-shared checkout validation is recorded below.

## Post-patch member retrieval verification — 2026-10-28

- From the external-SSD, Colima-shared candidate running the guarded per-file
  retrieval-depth patch, a synthetic member authenticated and used the
  admin-owned, Viewer-shared Juniper & Slate test agent. With a short-lived,
  member-scoped OpenRouter key and Qwen 3.5 9B, the member's saved answer to
  the JS-C30 question correctly says actual observed conversions are not
  reported, distinguishes the documented target of 1,483 add-to-cart events
  from actual conversions, and cites
  `02-juniper-slate-campaign-briefs.pdf`, page 31. The message records File
  Search tool results; this closes the post-patch member answer/grounding check
  for this synthetic corpus. The short-lived provider key was revoked through
  the supported key endpoint (HTTP 204).
- The synthetic member was then deleted through LibreChat's authenticated
  self-delete endpoint (HTTP 200); Mongo verification found zero matching user,
  conversation, message, file, or API-key records. The CLI deletion path was
  intentionally aborted because its global shutdown warning applied while
  unrelated LibreChat stacks were active. No unrelated app was stopped.
- Candidate API was restarted on loopback port 3085 and returned healthy.
  Registration remains disabled. All test documents are synthetic; no
  customer material, live payment, public DNS, or VPS was involved.
- This test closes the synthetic member-side post-patch File Search answer
  check. It does not by itself close public VPS ingress, DNS/TLS, production
  backup/restore, billing/consent, or actual hardware acceptance. The tier
  mapping is intentional: Plus is dedicated VPS/cloud;
  Pro is an on-site Beelink SER5 workspace with cloud inference; Max is local
  inference on customer-owned hardware such as Mac Studio, DGX Spark, or Strix
  Halo.

## Local dedicated-deployment isolation regression — 2026-10-28

- Ran `scripts/customer-isolation-check.py` read-only against the patched
  candidate and the isolated backup/restore copy. It passed both directions:
  Compose networks were disjoint; each API resolved its own Mongo service but
  not the other project's service names; cross-project TCP was blocked for
  API, MongoDB, Meilisearch, pgvector, and RAG; internal services exposed no
  host ports; and app data, uploads, MongoDB, Meilisearch, and pgvector storage
  sources were distinct.
- This verifies Docker-level separation between two local dedicated projects,
  not member ACL behavior, public VPS/firewall/DNS/TLS, or isolation from a
  privileged host operator. Those remain separate acceptance items.

## Current Stripe test-access check — 2026-10-28

- The connected Stripe integration currently exposes the live Gombey Tech
  account only. The Stripe CLI is not installed in this environment, so there
  is no authenticated sandbox route available for a safe setup/installment,
  saved-payment-method, delayed-subscription, renewal, or failure rehearsal.
- No live Stripe write was made. Do not test the billing flow in live mode.
  To close this gate, connect a dedicated Stripe sandbox to the Stripe
  integration (or authorize a sandbox-capable Stripe CLI session), then run
  the test plan there. Live tax registration and product tax treatment also
  remain owner/accountant decisions; no tax settings were changed.

## Candidate second-member shared-agent permission check — 2026-10-28 15:26 EDT

- A disposable synthetic member authenticated against the loopback candidate.
  The member's agent list contained the Juniper & Slate shared agent when
  requesting VIEW access; the basic agent record returned HTTP 200 and the
  expanded/edit configuration request returned HTTP 403 as intended.
- The member was deleted through the authenticated self-delete endpoint
  (HTTP 200). Mongo checks found zero records for the account across users,
  conversations, messages, files, and API-key collections. No provider key was
  added and no model request was made in this check.
- This confirms candidate-side shared-agent visibility and the VIEW/EDIT
  boundary for a second disposable member. It is an authenticated API check,
  not a browser UX test or proof of cross-customer tenant isolation. The
  intended deployment ladder remains Plus = customer VPS/cloud inference,
  Pro = on-site SER5/cloud inference, Max = customer hardware/local inference.

## Local pre-VPS regression rerun — 2026-10-28 15:26 EDT

- Re-ran the five File Search retrieval-depth patch tests, four RAG
  fail-closed patch tests, customer-init tests, customer-preflight tests, and
  encrypted-backup safety tests; all passed.
- Re-ran all three pairwise read-only isolation checks across primary staging,
  the clean candidate, and the restored backup copy. All passed: disjoint
  networks and persistent storage, blocked cross-project service DNS/TCP, and
  no published internal service ports.
- These checks strengthen the local pre-VPS evidence only; they do not replace
  public DNS/TLS/firewall/reboot/backup-restore acceptance or Stripe sandbox
  billing rehearsal.

## Stripe catalog label and tax-state verification — 2026-10-28 15:33 EDT

- The owner reconfirmed the intended tier progression: Plus is a dedicated
  customer VPS with cloud inference; Pro is an on-site SER5 appliance with
  cloud inference; Max is customer hardware (Mac Studio, DGX Spark, or Strix
  Halo) for local inference. This is intentional offer design, not a tier
  mismatch.
- To match the public offer names, the three active live Stripe product titles
  were updated to Gombey Cloud Workspace, Gombey Workspace Appliance, and
  Gombey Private Local AI. A live read-back confirmed the titles and existing
  hat product images. Tier metadata, descriptions, standard monthly amounts,
  setup installment amounts, prices, coupons, and links were not changed.
- Billing state remains gated: three setup links are active; the separate
  recurring links remain inactive; there are no subscriptions. Stripe Tax
  settings are `pending` because no head-office address is configured, and the
  account has zero Tax registrations. The active setup links have automatic
  tax enabled, but that flag does not establish tax collection without an
  active registration. No tax configuration or payment behavior was changed;
  owner/accountant tax review and a dedicated Stripe sandbox rehearsal remain
  open before sending live links.

## Local regression and RAG failure-path integration — 2026-10-28 15:38 EDT

- Re-ran customer initialization, customer preflight, encrypted-backup safety,
  RAG fail-closed patch, File Search retrieval-depth patch, embeddings-key
  setter, and customer RAG smoke CLI tests. All passed.
- Ran `scripts/test_rag_fail_closed_integration.sh` against a new disposable
  Compose project using a deliberately invalid test key and loopback-only
  provider URL. The synthetic upload failed closed with HTTP 500 and the vector
  store held zero rows. The test confirmed and removed its containers, network,
  and volume; its temporary mode-600 config on the external SSD was also
  removed. No external provider request, customer document, or live billing
  operation was involved.
- This adds current evidence for the RAG failure path; it does not prove a
  successful customer-owned provider transaction, public VPS acceptance, or
  live billing readiness. The connected Stripe session still exposes only
  live mode, and live tax setup remains unresolved as recorded above.

## Candidate provider-backed RAG smoke — 2026-10-28 15:41 EDT

- Ran `scripts/customer-rag-smoke.py` inside the isolated candidate RAG
  service using its configured OpenRouter endpoint and
  `openai/text-embedding-3-small`. Synthetic embedding, own-scope lookup,
  unrelated-scope exclusion, and retrieval of a unique marker all returned
  HTTP 200. The test deleted its vector and verified it was absent afterward.
- The candidate web API remained healthy and returned HTTP 200 after the
  smoke test. No customer content was used. This proves the configured
  embeddings route works, but does not independently establish which OpenRouter
  account owns the credential or prove customer billing ownership; verify that
  in the provider dashboard before a customer deployment.

## Current three-stack isolation matrix — 2026-10-28 15:42 EDT

- Re-ran the read-only isolation checker for every pair among the current
  candidate, primary staging, and restored-copy Compose projects. All three
  pairs passed in both directions: networks and persistent storage roots are
  distinct; each API resolves only its own Mongo service; cross-project service
  DNS and private-IP TCP probes are blocked; and internal service ports are
  unpublished.
- This is runtime evidence for dedicated-deployment isolation on this Colima
  host. It does not establish public VPS ingress controls or protect against a
  privileged host operator.

## Public offer and deferred-billing configuration recheck — 2026-10-28 15:42 EDT

- A fresh read of `https://gombeytech.com` confirms the intended ladder and
  published pricing: Cloud Workspace/VPS ($2,500 standard setup, $1,995 launch;
  $399 standard/$349 monthly for 12 months), Workspace Appliance/SER5 with
  cloud AI ($4,500/$3,995; $699/$599 monthly), and Private Local AI ($7,500/
  $6,995; $1,499/$1,299 monthly). The page says appliance scope requires
  hardware-specific validation and written approval; local hardware is quoted
  separately. This is consistent with the owner's intended tier mapping.
- Read-only live Stripe reconciliation confirms the three active product names
  match the public offers, with 15 active Prices: three standard recurring
  Prices and twelve one-time 50/50 setup-installment Prices (standard and
  founding kickoff/delivery amounts). Product metadata still maps them to
  `cloud`, `appliance`, and `local`. No price or link was changed.
- Current live setup links are active founding kickoff payments ($997.50,
  $1,997.50, and $3,497.50). `payment_method_collection=if_required` and
  `payment_intent_data.setup_future_usage` is unset; these links do not
  currently require or save a card for off-session monthly billing.
- Separate monthly subscription links remain inactive. Each uses the standard
  monthly Price, requires payment-method collection, has a 30-day trial and
  cancels at trial end if no payment method is available, and accepts the
  tier-specific promotion code. No setup payment is linked to these
  subscriptions; the first charge is 30 days after a customer completes that
  separate subscription checkout, not automatically 30 days after delivery.
  A live subscription list with `status=all` returned zero subscriptions. Do
  not send or activate links until the dedicated
  sandbox rehearsal and tax review pass; no live billing or tax settings were
  changed in this audit.
