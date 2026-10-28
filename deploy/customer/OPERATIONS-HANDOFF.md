# Cloud Workspace operations handoff

This runbook is for the first dedicated customer deployment. It does not
replace the deployment README, a customer contract, or the required VPS
acceptance checks. Fill in customer-specific values in the operator's secured
record, not in this reusable source file.

## Before kickoff

- Confirm the signed scope, customer admin, up to five named accounts, selected
  workflow, acceptance questions, approved files, and prohibited data.
- Confirm the customer controls and pays for the selected chat-model account
  and a separate embeddings account/key. Do not request secrets in chat/email;
  use the hidden-input helper or the customer's approved secret manager.
- Confirm the customer has reviewed the model and embeddings providers' terms
  and the data path. ChatGPT subscriptions are not API keys.
- Obtain explicit approval for exact VPS provider/plan, initial and renewal
  cost, region, hostname, DNS changes, and who can access the host. Do not
  purchase or expose a VPS before the approval is recorded.
- Agree backup destination, encryption-key custody, retention, deletion, and
  recovery target. A provider snapshot alone is not a completed restore test.
- Agree support channel, business hours/time zone, monthly support cap, and
  response target. The response target is not a resolution or uptime guarantee.

## Founding-offer cap (operator-controlled)

The public offer is limited to the first three deployments across all tiers.
Stripe's launch coupons and codes are product-specific, with a three-use limit
per tier; they do not enforce one shared three-customer cap. The three current
founding kickoff links are reusable and have no Stripe completion restriction.
Do not publish them on the website, in an email signature, or in a reusable
campaign template.

- Keep a three-slot register in an access-controlled operator record outside
  GitHub. Track slot number, tier, proposal reference, status (available,
  held, assigned, or released), proposal-valid-through date, kickoff-link
  share time, payment status, subscription enrollment date, and matching
  monthly promotion code. Do not store payment details, provider keys, or
  customer documents in this register.
- Confirm availability before offering the founding price. Place a hold when
  issuing the written proposal and use its stated validity; mark the slot
  assigned only after the scope is accepted and kickoff payment clears. Release
  a declined or expired hold. Share only the matching tier's private kickoff
  link after confirming its slot, and later use its matching monthly code at
  the separate subscription enrollment. The monthly code is not a substitute
  for customer consent to recurring billing.
- After three slots are assigned, stop sharing all founding kickoff links and
  quote standard pricing for new clients. Stripe will not enforce this
  cross-tier cap. If an assigned customer cancels or receives a refund, record
  the event and have the owner decide whether the slot reopens.
- The live kickoff links currently have automatic tax enabled while the live
  account reports no active tax registrations. Do not send them until the
  owner/accountant confirms the applicable tax treatment and the required
  Stripe sandbox billing rehearsal has passed.

## Provision and secure

1. Create a fresh per-customer checkout/release and unique Compose project.
   Never point two customers at the same MongoDB, vector database, uploads,
   secrets, or Docker project.
2. Generate a mode-600 environment file with `scripts/customer-init.sh`; run
   `scripts/customer-preflight.sh` and review its output before starting.
3. Configure DNS and firewall only after approved. Publish only Caddy on 80/443;
   keep application, MongoDB, Meilisearch, PostgreSQL, and RAG service ports
   private. Restrict SSH to the operator's address where practical.
4. Bootstrap the customer owner through loopback and an SSH tunnel, disable
   bootstrap signup, then create member accounts with the supported prompt.
   Public registration and unauthenticated password reset remain disabled.
5. Configure one Company Knowledge Assistant with File Search only. The owner
   uploads approved sources and shares it with the authenticated `USER` role
   as Viewer. Do not add MCP tools or write actions in the base pilot.
6. Have the owner configure the agreed customer-owned model provider and the
   separately customer-owned embeddings key. Confirm which provider is billed.

## Delivery and customer handoff

- Follow the billing milestones and consent language in section 6 of
  `PILOT-SCOPE-AND-ACCEPTANCE.md`. The second setup installment and monthly
  subscription are separate checkouts; the setup payment does not enroll the
  customer or authorize reuse of its payment method. A separately authorized
  subscription starts its 30-day trial when checkout completes, so the first
  charge is 30 days after delivery only if the customer enrolls at accepted
  delivery. Do not send a live recurring link until the documented Stripe
  sandbox, discount-scope, and tax gates pass.

- Walk the owner through admin access, member provisioning/revocation requests,
  approving/updating source documents, and selecting the shared agent.
- Walk members through their own sign-in, provider-key ownership (if BYOK),
  choosing the shared assistant, citations, and how to flag an incorrect or
  unsupported answer.
- Explain the boundary: the customer admin and VPS operator are privileged;
  each member's chats/files are private from peers; the shared corpus is used
  only through the shared agent; model/embedding requests leave the VPS for
  the configured providers.
- Run every item in `PILOT-SCOPE-AND-ACCEPTANCE.md` and give the customer a
  copy of the signed acceptance record and agreed operating terms.
- Record software/image versions, hostname, backup schedule/destination,
  recovery-key custody reference, admin contact, support channel, and billing
  milestones in the access-controlled customer record.

## Routine care and support

- Check service health and disk capacity on the agreed schedule; investigate
  only through the authorized operator account.
- Announce maintenance according to the signed scope. Before an upgrade, take
  an encrypted backup, test the change in an isolated copy, and retain a
  rollback path. Never run an unreviewed image pull against production.
- For a support request, capture timestamp/time zone, affected accounts,
  symptom, sanitized error, business impact, and whether a recent change
  occurred. Do not ask the customer to email prompts, documents, passwords, or
  API keys unless an approved secure channel and data-handling procedure exist.
- Use this intake template in the agreed support channel; keep the report free
  of credentials, customer documents, and unredacted prompt content:

  ```text
  Subject: [short symptom] — [workspace name]
  Reported at (date/time/time zone):
  Affected account(s) or workflow:
  Business impact / is work blocked?:
  What happened and expected result:
  Sanitized error text or screenshot (redacted):
  Steps to reproduce (if known):
  Recent changes or last known good time:
  Workaround tried / current workaround:
  Is there a suspected security or data-exposure concern?:
  ```

- Acknowledge the report within the signed tier's business-hours response
  target; separately estimate resolution. Confirm before work that would
  exceed the included monthly allowance or signed workflow scope.
- Record time against the included monthly support allowance. Notify the
  customer before exceeding it or starting out-of-scope work.
- Distinguish a response-time target from a fix-time guarantee. Escalate
  provider outages or billing issues to the customer-owned provider account.

## Access changes and offboarding

- Verify an authorized admin request before adding or revoking a member.
- On departure, disable/revoke the account promptly, verify it cannot sign in,
  and record the date. Do not promise immediate erasure of backups unless the
  agreed retention cycle and deletion procedure support that promise.
- For a forgotten password, keep public password reset disabled unless a
  customer email provider has been configured and tested. Verify the request
  through the customer's agreed admin/support channel, SSH to the approved
  deployment, change to the deployment repository root, and run the supported
  interactive reset command:

  ```bash
  docker compose --env-file deploy/customer/.env \
    -f deploy/customer/compose.yaml exec api npm run reset-password
  ```

  It prompts for the account email and hides the new password while it is
  entered; do not pass a password as a command-line argument or store it in
  this runbook. The command updates the password version, invalidating existing
  sessions. Coordinate entry/delivery through the separately agreed secure
  channel and confirm the affected user can sign in afterward. This is an
  operator-assisted recovery path, not customer self-service.
- At termination, follow the written export/deletion plan; remove DNS and
  credentials only after the customer confirms whether data export is needed.
  Provide a deletion confirmation only after checking active volumes and
  retained backups against the agreed policy.

## Open launch gate

This runbook does not by itself prove public-host security, DNS/TLS, off-host
backup, recovery time, provider billing, or ongoing monitoring. Complete and
record the customer VPS acceptance checks before loading live customer data.
