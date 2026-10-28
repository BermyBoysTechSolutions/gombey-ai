# Stripe billing rehearsal (sandbox only)

Status: prepared, not executed. The connected Stripe account available in this
Codex session was live-only; no test customer, invoice, subscription, product,
price, or payment method was created. Do not use a live account for this test.

## Intended customer timeline

1. At kickoff, collect 50% of the agreed one-time setup amount.
2. At delivery, after the customer accepts the agreed checklist, collect the
   remaining 50% of setup.
3. Start recurring monthly service 30 days after accepted delivery, using the
   customer's explicitly authorized saved payment method.
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

The initial pilot should be operator-managed in Stripe Dashboard. Gombey does
not currently have billing code, webhook processing, or account provisioning
that reacts to Stripe events. “Automatically” should mean Stripe attempts the
future recurring payments after the customer has expressly agreed and a
payment method has been saved—not that Gombey presently automates the whole
sale-to-deployment workflow.

## Sandbox prerequisites

- Use a dedicated Stripe sandbox/test mode, never Live mode.
- Use a fresh synthetic customer and Stripe test clock for date-advance tests.
- Reconcile the exact standard setup amount, kickoff/delivery installment
  amounts, monthly amount, promotion duration, cancellation terms, and tax
  treatment before making test objects. Do not change the live catalog as part
  of this rehearsal.
- The live per-tier launch coupons currently have redemption caps but no
  `applies_to` product list. A tier-specific name/code is not a Stripe
  restriction. Create product-scoped replacement coupons and promotion codes
  in sandbox, and verify each code is accepted only for its matching product
  and rejected for both other tiers before any live recurring link is enabled.
- Confirm the founding monthly amount-only discount produces exactly 12 paid
  periods at the advertised price, then transitions to the standard price.
  Promotion-code eligibility, first charge date, and coupon duration must be
  tested together with the delayed subscription schedule.
- The live account's three existing Payment Links have automatic tax enabled,
  while the live account currently has zero active Tax registrations. Stripe
  documents that it calculates tax only in jurisdictions with an active
  registration. Have the owner/accountant resolve the live tax treatment before
  sending a live link or describing tax as configured; do not add or remove
  registrations as part of this sandbox rehearsal. [Stripe Tax and Payment
  Links](https://docs.stripe.com/tax/payment-links).
- The three current live Payment Links collect only the 50% founding kickoff
  installment. They do not create a subscription, schedule a later charge, or
  accept extra promotion codes. They are not a complete customer signup flow;
  test the delivery installment and deferred monthly billing separately.
- Identify the existing sandbox products/prices/coupons or create disposable
  test-only objects. Avoid copying live IDs into test mode; Stripe objects are
  mode-specific.
- Use Stripe test payment methods only. Delete/cancel disposable schedules and
  subscriptions after recording the results.

## Test flow

### 1. Kickoff payment

- Create a test customer and send a one-time invoice for exactly half of the
  approved setup amount, with the first installment clearly identified.
- Pay it with a Stripe test payment method.
- Record the invoice ID, amount, payment status, and event timestamp. The pass
  signal is `invoice.paid`, not merely a browser success page.
- Confirm no recurring subscription or second setup charge starts at kickoff.

### 2. Obtain explicit recurring-charge consent

Before saving a payment method for future off-session use, show the customer
the exact recurring amount (or a clear amount/range if contractually variable),
frequency, first charge date, launch-price duration and later regular price,
how cancellation works, and that Stripe may attempt charges when the customer
is not present. Capture their affirmative consent in the accepted agreement.

In the sandbox, attach a test payment method to the same test customer using a
SetupIntent or Checkout setup flow with future off-session use. Confirm setup
succeeded and the payment method is attached to the intended customer. A
successful one-time invoice payment does not, by itself, prove the method is
available for future off-session charges. See Stripe's [Setup Intents guide](https://docs.stripe.com/payments/setup-intents)
and [saving/reusing payment details](https://docs.stripe.com/payments/save-and-reuse).

### 3. Delivery and deferred subscription

- Mark acceptance only after the written pilot checklist is approved.
- Send/pay a second one-time invoice for the other half of setup. Confirm no
  monthly subscription charge occurs on the delivery date.
- Schedule the subscription to begin exactly 30 days after accepted delivery,
  using the saved customer payment method. A future-start Subscription
  Schedule is the candidate mechanism; Stripe documents schedules and future
  phase configuration [here](https://docs.stripe.com/billing/subscriptions/subscription-schedules).
- Apply the approved launch discount/rate only to the intended 12 paid monthly
  periods, then transition to the standard monthly price. Do not assume how a
  coupon's duration interacts with a delayed start or trial—verify the actual
  invoice timeline in the sandbox first.
- Confirm the generated subscription/schedule is attached to the correct
  customer and payment method and has the exact future start timestamp.

### 4. Advance time and verify billing

Use the test clock to advance to one day before the deferred start, the exact
start, the first renewal, the 12th paid launch-rate invoice, and the first
standard-rate renewal. Stripe supports [Billing test clocks](https://docs.stripe.com/billing/testing)
for simulating subscription events over time. At each point, record expected
and actual dates, invoice line items, discounts, tax, amount due, payment
status, and notification/webhook receipt. The first monthly invoice must not
be earlier than 30 days after the accepted-delivery timestamp.

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
| Payment method setup | Test method is attached to the correct customer for future off-session use; consent record is retained. |
| Delivery invoice paid | Second half-setup payment occurs only after accepted delivery. |
| Deferred start | No recurring invoice/payment before delivery + 30 days. |
| First monthly invoice | Correct agreed launch amount and due date; payment result is visible. |
| Launch term end | Exactly the approved number of paid periods receive the launch rate; next invoice uses standard price. |
| Wrong-tier launch code | Each tier's code is rejected by both other tier products; fail until product restrictions are verified. |
| Renewal failure | Failed invoice is visible and the operator has a clear retry/customer-contact path; no duplicate subscription is created. |
| Cancellation | Customer can cancel according to the agreement; schedule/subscription stops at the agreed time. |
| Cleanup | All disposable test subscriptions/schedules are canceled and no live object is created. |

## Go/no-go

Do not describe the deferred subscription as configured or promise an
automatic first charge until every date/amount case above passes in a sandbox.
The current approved offer is Cloud Workspace, Workspace Appliance, and
Private Local AI; see the dated audit in `mvp-readiness-2026-10-27.md` for the
published prices. The recurring schedule is an operator-managed process until
the test and billing implementation gates pass. Do not use live links for the
sandbox rehearsal. No customer charge should be created from this runbook.
