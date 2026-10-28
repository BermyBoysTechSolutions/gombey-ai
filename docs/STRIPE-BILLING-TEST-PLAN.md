# Stripe billing rehearsal (sandbox only)

Status: prepared, not executed. The connected Stripe account available in this
Codex session was live-only; no test customer, invoice, subscription, product,
price, or payment method was created. Do not use a live account for this test.

## Intended customer timeline

1. At kickoff, collect 50% of the agreed one-time setup amount.
2. At delivery, after the customer accepts the agreed checklist, collect the
   remaining 50% of setup.
3. At accepted delivery, send a separate recurring-subscription checkout link.
   The customer must review the monthly terms, provide/confirm a payment
   method, and affirmatively authorize recurring charges. The link starts a
   30-day trial; Stripe attempts the first monthly payment when that trial ends.
   Send it at accepted delivery if the intended first attempt is 30 days after
   delivery. If the customer completes it later, the 30-day timer starts later.
   The kickoff setup payment does not create the subscription or automatically
   reuse its payment method.
4. Apply the approved launch rate for its agreed term, then bill the normal
   monthly rate. The current live catalog and public page were read-only
   reconciled on 2026-10-28; use the signed proposal to confirm which tier and
   founding offer apply to a particular customer:

   | Tier | Setup standard | Setup founding | Each 50% setup installment | Monthly standard | Monthly founding (first 12 months) |
   |---|---:|---:|---:|---:|---:|
   | Cloud Workspace | $2,500 | $1,995 | $997.50 / $997.50 | $399 | $349 |
   | Workspace Appliance | $4,500 | $3,995 | $1,997.50 / $1,997.50 | $699 | $599 |
   | Private Local AI | $7,500 | $6,995 | $3,497.50 / $3,497.50 | $1,499 | $1,299 |

   The founding offer is advertised for the first three deployments total; the
   Stripe coupon/promotion-code limits are per tier, so the operator must
   enforce the cross-tier cap manually. Re-check current catalog and signed
   proposal immediately before each test or customer invoice.

The initial pilot should be operator-managed with Stripe-hosted payment links
and invoices. Gombey does not currently have billing code, webhook processing,
or account provisioning that reacts to Stripe events. “Automatically” means
Stripe attempts recurring payments after the customer has expressly agreed
and completed the separate subscription checkout—not that Gombey presently
automates the transition from kickoff payment to delivery or subscription
signup.

## Sandbox prerequisites

- Use a dedicated Stripe sandbox/test mode, never Live mode.
- Use a fresh synthetic customer and Stripe test clock for date-advance tests.
- Reconcile the exact standard setup amount, kickoff/delivery installment
  amounts, monthly amount, promotion duration, cancellation terms, and tax
  treatment before making test objects. Do not change the live catalog as part
  of this rehearsal.
- The current live launch coupons are product-scoped through `applies_to`, and
  the matching active promotion codes each allow three redemptions (zero used
  at the 2026-10-28 read-only check). Verify in sandbox that each code works
  for its matching product and is rejected for the other two; do not create
  replacement live coupons unless that test finds a defect. Per-tier
  three-redemption caps do not enforce the site's first-three-deployments
  total across all tiers; the operator must track the global count and stop
  offering the launch discount after the third accepted deployment.
- Confirm the founding monthly amount-only discount produces exactly 12 paid
  periods at the advertised price, then transitions to the standard price.
  Promotion-code eligibility, first charge date, and coupon duration must be
  tested together with the 30-day subscription trial; if Stripe's actual trial
  and coupon behavior differs from the public promise, correct the live terms
  before accepting a customer.
- The live account's three active kickoff Payment Links have automatic tax
  enabled, while the account has zero active Tax registrations at the
  2026-10-28 read-only check. The three inactive monthly links have automatic
  tax disabled. Stripe documents that it calculates tax only in jurisdictions
  with an active registration. Have the owner/accountant resolve live tax
  treatment before sending any live link or describing tax as configured; do
  not add or remove registrations as part of this sandbox rehearsal. [Stripe
  Tax and Payment Links](https://docs.stripe.com/tax/payment-links).
- The three current active live Payment Links collect only the 50% founding
  kickoff installment; they do not create a subscription or authorize a
  payment method for later use. Three separate monthly subscription links are
  inactive. At the 2026-10-28 read-only check each uses the standard monthly
  price, permits promotion codes, requires a payment method, starts a 30-day
  trial, cancels at trial end if no method is available, and has automatic tax
  disabled. They are not ready to send: verify the matching founding code,
  amount, consent text, tax treatment, and trial/invoice timeline in a
  dedicated sandbox before activation. The monthly enrollment is a separate
  delivery-day step, not a continuation of kickoff checkout.
- Identify the existing sandbox products/prices/coupons or create disposable
  test-only objects. Avoid copying live IDs into test mode; Stripe objects are
  mode-specific.
- Use Stripe test payment methods only. Cancel disposable test subscriptions
  and delete disposable test customers after recording the results, as
  supported by Stripe.

## Test flow

### 1. Kickoff payment

- Create a test customer and send a one-time invoice for exactly half of the
  approved setup amount, with the first installment clearly identified.
- Pay it with a Stripe test payment method.
- Record the invoice ID, amount, payment status, and event timestamp. The pass
  signal is `invoice.paid`, not merely a browser success page.
- Confirm no recurring subscription or second setup charge starts at kickoff.

### 2. Obtain explicit recurring-charge consent at delivery

Before saving a payment method for future off-session use, show the customer
the exact recurring amount (or a clear amount/range if contractually variable),
frequency, first charge date, launch-price duration and later regular price,
how cancellation works, and that Stripe may attempt charges when the customer
is not present. Capture their affirmative consent in the accepted agreement.

The kickoff invoice payment does not, by itself, authorize or save a payment
method for future off-session subscription billing. In the sandbox, use the
separate subscription Payment Link/Checkout flow at delivery with payment
method collection required and a 30-day trial. Confirm the completed
subscription is attached to the intended customer, has a payment method
available for automatic collection, and has the expected trial end. Confirm
the customer-facing checkout and signed agreement both clearly state the
recurring amount, cadence, first-charge timing, launch-price duration, later
standard price, cancellation terms, and authorization for off-session charges.
Stripe documents automatic collection and trial behavior in its
[subscription overview](https://docs.stripe.com/billing/subscriptions/overview),
[free-trial guide](https://docs.stripe.com/billing/subscriptions/trials), and
[collection-method guide](https://docs.stripe.com/billing/collection-method).

### 3. Accepted delivery and separate subscription checkout

- Mark acceptance only after the written pilot checklist is approved.
- Send/pay a second one-time invoice for the other half of setup. Confirm no
  monthly subscription charge occurs on the delivery date.
- At accepted delivery, issue/pay the second one-time setup installment and
  send the separate monthly subscription link. The customer reviews the terms,
  supplies a payment method, and authorizes recurring billing in that checkout.
  Complete it on the same day if the target first charge is 30 days after
  delivery. Verify the created subscription is `trialing`, has the expected
  trial end, collects payment automatically, and cancels at trial end if no
  payment method is available. Do not create a second subscription or reuse
  the kickoff payment method.
- Apply the approved launch discount/rate only to the intended 12 paid monthly
  periods, then transition to the standard monthly price. Do not assume how a
  coupon's duration interacts with a delayed start or trial—verify the actual
  invoice timeline in the sandbox first.
- Confirm exactly one subscription is attached to the correct customer and
  payment method, with trial end 30 days after subscription checkout. Do not
  describe it as 30 days after delivery unless checkout was completed at
  accepted delivery.

### 4. Advance time and verify billing

Use the test clock to advance to one day before the trial ends, the first
charge, the 12th paid launch-rate invoice, and the first standard-rate
renewal. Stripe supports [Billing test clocks](https://docs.stripe.com/billing/testing)
for simulating subscription events over time. At each point, record expected
and actual dates, invoice line items, discounts, tax, amount due, payment
status, and notification/webhook receipt. If the subscription checkout is
completed at accepted delivery, the first monthly invoice must not be earlier
than 30 days after that timestamp. If checkout is completed later, the timer
starts then; do not claim a precise delivery-plus-30-day charge.

Stripe recommends handling fulfillment from server-side events such as
`invoice.paid`; do not rely only on the browser redirect. If a future Gombey
integration is built, it must also handle payment failure, subscription
changes/cancellation, duplicate and out-of-order event delivery, and safe
retries. See [Stripe's invoice integration](https://docs.stripe.com/invoicing/integration)
and [subscription webhooks guide](https://docs.stripe.com/billing/subscriptions/webhooks).

## Required cases and pass criteria

| Case | Expected result |
|---|---|
| Kickoff invoice paid | One half-setup payment; no subscription charge. |
| Kickoff payment fails | No deployment is treated as paid/started; operator sees failure. |
| Subscription checkout at delivery | Test method is attached to the correct customer, consent is recorded, and subscription is `trialing` for 30 days. |
| Delivery invoice paid | Second half-setup payment occurs only after accepted delivery. |
| Deferred start | No recurring invoice/payment before trial end (30 days after subscription checkout; complete it at delivery for the target delivery-plus-30-day first charge). |
| First monthly invoice | Correct agreed launch amount and due date; payment result is visible. |
| Launch term end | Exactly the approved number of paid periods receive the launch rate; next invoice uses standard price. |
| Wrong-tier launch code | Each tier's code is rejected by both other tier products; fail until product restrictions are verified. |
| Renewal failure | Failed invoice is visible and the operator has a clear retry/customer-contact path; no duplicate subscription is created. |
| Cancellation | Customer can cancel according to the agreement; the subscription stops at the agreed time. |
| Cleanup | All disposable test subscriptions and customers are canceled/deleted as supported; no live object is created. |

## Go/no-go

Do not describe the deferred subscription as configured or promise an
automatic first charge until every date/amount case above passes in a sandbox.
The current approved offer is Cloud Workspace, Workspace Appliance, and
Private Local AI; see the dated audit in `mvp-readiness-2026-10-27.md` for the
published prices. Moving a customer from kickoff to the delivery checkout is
an operator-managed process until the test and billing implementation gates
pass; Stripe handles recurring attempts only after subscription enrollment.
Do not use live links for the sandbox rehearsal. No customer charge should
be created from this runbook.
