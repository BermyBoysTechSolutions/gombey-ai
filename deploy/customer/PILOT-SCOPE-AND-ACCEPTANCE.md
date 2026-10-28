# Cloud Workspace pilot scope and acceptance

Use this checklist to scope a first, single-customer Cloud Workspace pilot.
It is an implementation worksheet, not a contract, security certification, or
guarantee that an untested production VPS is ready. Copy the completed choices
into the customer's signed proposal before provisioning.

## 1. Customer and workflow

- Customer legal/business name: `[complete with customer]`
- Customer owner/admin: `[name and business contact]`
- Named accounts total (up to five, including the admin): `[names and roles]`
- One workflow to improve: `[specific repeatable task]`
- Current inputs and steps: `[what staff provide/do today]`
- Desired output and success measure: `[observable result]`
- Human review/approval point: `[who checks output before use]`
- Source documents approved for upload: `[list, owner, date/version]`
- Prohibited data or uses: `[complete with customer]`

Do not use legal, medical, financial-advice, employment, or similarly
high-impact decisions as an unreviewed automated workflow. The model's output
is a draft for a person to verify, not authority to take an action.

## 2. Hosting, access, and data path

- Dedicated customer VPS/hostname: `[only after VPS, DNS, and spend approval]`
- Customer's model provider and account owner: `[OpenAI / Anthropic / Google /
  OpenRouter / other approved provider]`
- Chat-key model: `[individual member BYOK or customer-owned central key]`
- Embeddings provider/key owner: `[customer-owned account; separate RAG key]`
- Approved data path: `[browser → Gombey VPS → chat provider; document text →
  embeddings provider; retrieved excerpts → chat provider]`
- Approved source/document retention and deletion request: `[agree before upload]`
- Customer admin controls the shared agent and source files. Each member has a
  separate login, private chats, and private personal files. Gombey's VPS
  operator has infrastructure-level access; do not promise that customer data
  is inaccessible to the hosting operator or customer administrator.
- A shared-knowledge answer is produced only when the member selects the
  shared Company Knowledge Assistant. New ordinary chats do not automatically
  search this collection. The product is not a shared inbox or a shared
  conversation history.

## 3. Included in the base Cloud pilot

- One customer-specific Compose deployment and database set.
- Up to five named accounts total, including the customer administrator.
- One admin-managed File Search agent and one approved knowledge collection.
- One workflow configuration, an agreed evaluation set, and one acceptance
  session.
- Customer-owned model-provider billing and a separately customer-owned
  embeddings credential. Gombey does not fund model usage.
- A handoff covering sign-in, selecting the shared agent, key ownership,
  support intake, and the agreed backup/recovery process.

## 4. Explicitly excluded unless added in a signed scope

- ChatGPT Plus/Business subscription OAuth as a client model backend.
- Gombey-funded API/model/embedding usage.
- Pooled multi-customer hosting or customer-managed tenant creation.
- Self-service member invitations, shared inboxes, automatic retrieval in
  every chat, or employees seeing one another's private chats/files.
- Calendar, CRM, email, MCP, or other external connector; autonomous write
  actions; or an action without a named human approval point.
- Local model inference, hardware/appliance installation, onsite travel,
  compliance certification, guaranteed privacy, or a 24/7 availability SLA.
- Work beyond the signed workflow, user count, support allowance, and
  acceptance criteria.

## 5. Acceptance checklist

Record pass/fail evidence and date for each item. Do not upload live customer
documents until the required customer-specific provider credentials and the
deployment's data path are approved.

1. **Deployment:** only the reverse proxy exposes public web ports; database,
   search, and RAG ports are not public. HTTPS, DNS, and reboot persistence
   pass on the customer VPS.
2. **Accounts:** owner and two sample members sign in separately. Public
   registration stays disabled. The owner can manage the shared agent; a
   member cannot edit its instructions or source files.
3. **Shared source:** both members select the shared agent and answer a
   customer-approved, document-grounded question with the expected citation.
   An unsupported question yields an explicit “not found” answer.
4. **Member privacy:** each member cannot view the other's private chat or
   personal files. The member does not inherit another account's provider key.
5. **Removal:** after an approved test source is removed and re-indexed, its
   unique test fact no longer appears in later answers.
6. **Provider billing:** the customer confirms the selected model and
   embeddings accounts own the requests and usage. No Gombey credential is
   used for customer inference.
7. **Recovery:** create an encrypted backup, restore it to a clean isolated
   deployment, and verify sign-in, source files, shared-agent access, and the
   synthetic acceptance facts. Record the recovery key's separate storage
   location without putting the key in this document.
8. **Workflow:** run the agreed evaluation questions. Record expected answer,
   actual answer, citation, pass/fail, and corrective action. The customer
   approves the result before production use.

| Test | Expected result / evidence | Pass? | Date / owner |
|---|---|---|---|
| HTTPS, firewall, reboot | `[record]` | `[ ]` | `[record]` |
| Two member sign-ins and roles | `[record]` | `[ ]` | `[record]` |
| Shared answer with citation (member 1) | `[record]` | `[ ]` | `[record]` |
| Shared answer with citation (member 2) | `[record]` | `[ ]` | `[record]` |
| Unsupported question | `[record]` | `[ ]` | `[record]` |
| Private chat/file isolation | `[record]` | `[ ]` | `[record]` |
| Provider billing ownership | `[record]` | `[ ]` | `[record]` |
| Source deletion/re-index | `[record]` | `[ ]` | `[record]` |
| Encrypted backup and clean restore | `[record]` | `[ ]` | `[record]` |
| Customer acceptance | `[signed acceptance record]` | `[ ]` | `[record]` |

## 6. Billing milestones (manual until Stripe sandbox rehearsal passes)

The setup and recurring service use separate Stripe checkouts:

1. Collect 50% of the agreed one-time setup price at kickoff.
2. After the customer accepts delivery, collect the remaining 50% of setup.
3. At accepted delivery, send a separate monthly subscription checkout only
   after the recurring flow is available and its Stripe sandbox tests pass. The
   customer must review the monthly amount, cadence, launch-rate duration and
   later standard rate, cancellation terms, and first-charge timing; provide or
   confirm a payment method; and explicitly authorize recurring charges.
4. Stripe's 30-day trial starts when the customer completes subscription
   checkout. Stripe attempts the first monthly payment when that trial ends.
   Complete checkout at accepted delivery for the intended first attempt to be
   30 days after delivery. If the customer enrolls later, the trial and first
   payment move later too.

The setup payment does not enroll the customer in the subscription or
automatically save/reuse its payment method. Gombey does not currently automate
the transition from kickoff to delivery or subscription signup; the operator
handles the separate invoices and subscription enrollment.

As of the 2026-10-28 read-only check, the live monthly subscription links are
inactive and use standard monthly prices with promotion-code entry enabled.
The three launch coupons are restricted to their matching products; each
promotion code allows up to three redemptions, so the advertised first-three-
deployments-total cap still requires manual cross-tier tracking. The Stripe
sandbox rehearsal has not passed and the live account has no active Tax
registrations. The active kickoff links have automatic tax enabled, while the
inactive monthly links have it disabled. Do not activate or send a live
monthly link or accept live payment until the sandbox amount/discount/consent
cases and owner/accountant tax treatment are resolved. Do not describe the
first charge as 30 days after delivery unless the customer completed
subscription checkout on the delivery-acceptance date.
See the [Stripe sandbox rehearsal plan](../../docs/STRIPE-BILLING-TEST-PLAN.md)
for exact test cases and no-go criteria.

Before kickoff, write down the standard and launch amounts, the launch offer's
eligibility/remaining slots, tax treatment, payment fees, renewal date, and
monthly price after any discount expires. Reconcile the exact numbers with the
current signed proposal and Stripe catalog; never calculate them from memory.

## 7. Sign-off

- Customer agrees to workflow, source material, provider/data path, exclusions,
  support terms, and acceptance criteria: `[name/date]`
- Gombey confirms every acceptance check passed or explicitly marks the
  unresolved exceptions accepted by both parties: `[name/date]`
- No production customer data before this sign-off: `[confirm]`
