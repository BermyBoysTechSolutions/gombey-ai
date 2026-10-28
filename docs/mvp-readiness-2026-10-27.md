# Gombey AI MVP readiness

Status snapshot: 2026-10-27. This is a validation checklist, not a claim that
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
- `python3 scripts/test_set_rag_embeddings_key.py` passes (6 tests).
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
  passwords were withheld and not recorded. This verifies provisioning
  capacity only: the two additional users have not yet been signed in or run
  through shared-agent/private-data authorization checks.
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
- The RAG upload failure path is now fail-closed: an isolated synthetic upload
  with a loopback-only unavailable embeddings endpoint returned HTTP 500 and
  left zero vectors in its dedicated disposable database. Four exact-match,
  idempotency, and source-drift unit tests pass. A corrected isolated
  integration runner was also verified. The active staging RAG service is
  healthy and its 101 existing synthetic vectors were unchanged.
- A staging embeddings credential was printed by an earlier diagnostic and
  must be treated as compromised. No provider request was made after that
  diagnostic. Revoke and replace it before further embeddings-backed tests;
  never copy the value into this document or chat. The credential was disabled
  in the active staging and restore environment files; the active staging RAG
  service was stopped, and the restore project's stateless RAG container was
  removed. Application and database services remain running; document search
  is paused until a fresh key is supplied.

## Remaining go/no-go gates for the cloud workspace

1. Repeat grounded retrieval/citation as a second member with the agreed
   customer-owned provider/embedding credentials. Confirm the result and usage
   appear under the intended customer billing account. Do not use Gombey's or
   the owner's subscription/API credentials for customer traffic. First
   rotate the potentially exposed prior embeddings key; do not reuse it.
2. Decide whether model keys are per-member BYOK or customer-managed centrally,
   then test the chosen flow end-to-end for both members.
3. Reconcile the public site's read-only-connector claim. The current shared
   agent has File Search only; no MCP/calendar/CRM integration or write-action
   workflow has passed acceptance. A local website-source draft removes the
   connector from the base Cloud offer and gates hardware-specific claims; it
   is not deployed. Do not advertise a connector as included unless one named
   integration passes authorization, data-path, and acceptance tests.
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
- The current setup reduction is $505 per tier, not the earlier requested
  $1,000; the current monthly rates are also discounted for 12 months, whereas
  an earlier direction said to leave monthly rates unchanged. The current
  public/catalog tier labels are descriptive, not Plus/Pro/Max. These are
  unresolved pricing/positioning decisions; do not alter live prices until the
  owner confirms which direction is current. The current live catalog and
  production page remain aligned on descriptive names and amounts; current
  website copy edits are only a separate branch draft.
- Stripe currently has three active descriptive products and 15 active prices,
  including setup installments and recurring prices, plus three 12-month
  coupons with per-coupon redemption caps. No active subscriptions, invoices,
  or payment links were created. The connector exposed only the live account;
  test-mode access was not available, so deferred billing and consent have not
  been rehearsed.

| Public claim | Current evidence | Gate still open |
|---|---|---|
| Cloud: dedicated VPS per customer | Separate Compose project, secrets, database, network, and storage were tested locally. | Public VPS, DNS/TLS, firewall, reboot, and restore acceptance. |
| Cloud: up to 5 named accounts with admin/member roles | Five total accounts (one admin, four members) were provisioned on isolated restore with public registration disabled. One disposable member passed interactive shared-agent and privacy checks; a second member still needs provider-backed retrieval. | Repeat grounded retrieval with the intended customer-owned provider key, verify key isolation/revocation, and rehearse account recovery. |
| Cloud: one workflow, one custom agent, shared knowledge | One synthetic shared File Search agent and admin-managed Viewer access are configured. Local lexical-mock upload/index/query/delete plumbing passed. | Real customer-template semantic retrieval/citations with a member account and customer-owned model + embeddings credentials. |
| Cloud: one supported read-only connector | Customer template has no MCP server. A synthetic calendar sandbox exists on a separate test network; it is not a customer connector. The website-source draft removes connectors from base Cloud scope. | Ensure production copy no longer claims a connector, or fully acceptance-test one named integration before including it. |
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
