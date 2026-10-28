# Stripe billing rehearsal (sandbox only)

Status: prepared, not executed. The connected Stripe account available in this
Codex session is live-only; no test customer, invoice, subscription, product,
price, or payment method was created. Do not use a live account for this test.
The preferred flow below captures a payment method once at kickoff and avoids
asking the customer to enroll again at delivery. It is not implemented or
verified yet.

## Intended customer timeline

1. At kickoff, collect 50% of the agreed one-time setup amount and, only with
   explicit consent, save the payment method for the stated setup installment
   and future monthly subscription charges. The hosted checkout must identify
   the Stripe Customer and use
   `payment_intent_data.setup_future_usage=off_session`. Clearly disclose the
   recurring amount, cadence, first-charge timing, launch duration and later
   standard rate, cancellation terms, and permission to initiate future
   off-session charges. Keep a record of the affirmative agreement. The current
   live kickoff links do not do this and must not be used for the preferred
   flow.
2. At delivery, after written acceptance, collect the remaining 50% of setup.
   Do not create the monthly subscription before delivery is accepted and the
   delivery installment is paid.
3. At accepted delivery, create exactly one subscription for the same Stripe
   Customer, using the saved payment method, with automatic collection and a
   30-day trial starting at subscription creation. Stripe should attempt the
   first monthly charge about 30 days after accepted delivery; an off-session
   attempt can still fail or require customer authentication, so a
   recovery/contact path is required. This avoids a second customer checkout,
   but Gombey currently has no billing code or webhook workflow to create the
   subscription automatically. Until that is built and tested, an operator
   must perform and verify this delivery-day step in Stripe.
4. Apply the approved launch rate for its agreed term, then bill the normal
   monthly rate. The current live catalog and public page were read-only
   reconciled on 2026-10-28; use the signed proposal to confirm which tier and
   founding offer apply to a particular customer:

   | Tier / public offer | Setup standard | Setup founding | Each 50% setup installment | Monthly standard | Monthly founding (first 12 months) |
   |---|---:|---:|---:|---:|---:|
   | Plus — Cloud Workspace (VPS, cloud inference) | $2,500 | $1,995 | $997.50 / $997.50 | $399 | $349 |
   | Pro — Workspace Appliance (SER5, cloud inference) | $4,500 | $3,995 | $1,997.50 / $1,997.50 | $699 | $599 |
   | Max — Private Local AI (customer-owned local-inference hardware) | $7,500 | $6,995 | $3,497.50 / $3,497.50 | $1,499 | $1,299 |

   The founding setup price is $505 below standard for each offer; the
   published monthly founding rate is also discounted for the first 12 paid
   periods. Combined savings over setup plus those 12 paid periods are $1,105
   for Cloud Workspace, $1,705 for Workspace Appliance, and $2,905 for Private
   Local AI. This is the current offer; it is not a $1,000 setup-only discount.

   The founding offer is advertised for the first three deployments total; the
   Stripe redemption limits are per coupon/promotion code, not a shared cap,
   and the current codes are not product-restricted. The operator must enforce
   both the correct tier and the global cross-tier cap manually until safe,
   product-scoped replacements are tested. Re-check current catalog and signed
   proposal immediately before each test or customer invoice.

For an initial pilot, use a Stripe-hosted kickoff checkout only after the
saved-payment-method and consent configuration passes in a dedicated sandbox.
Gombey has no billing code, signed-webhook processing, or account provisioning
that reacts to Stripe events. Stripe can automate recurring attempts after a
subscription exists; Gombey does not yet automate the handoff from accepted
delivery to subscription creation. If a customer declines to save a payment
method, use the separate subscription-checkout fallback at delivery and state
that the 30-day timer starts when that later checkout is completed.
Stripe documents saving a Checkout payment method for off-session use through
`payment_intent_data.setup_future_usage`, and requires terms, explicit consent,
and a record of the customer's agreement. An off-session attempt may still fail
or require authentication; provide a customer recovery path. See [saving
payment details during Checkout](https://docs.stripe.com/checkout/save-during-payment?ui=full-page),
[Setup Intents](https://docs.stripe.com/payments/setup-intents), and
[off-session payments](https://docs.stripe.com/payments/off-session-payments).

### Checkout disclosure checklist (draft, review before live use)

The kickoff checkout and signed proposal should state, in plain language:

- The exact deposit charged now and the remaining setup amount, which is due
  only after the customer accepts delivery.
- The monthly launch amount, the number of paid periods at that amount, the
  later standard monthly amount, and the expected first charge date (30 days
  after accepted delivery).
- That the saved method may be charged off-session for the delivery installment
  and recurring service; that a bank may still require authentication; and how
  the customer can update their method, cancel, or resolve a failed payment.
- That model-provider/API usage is billed separately by the customer's chosen
  provider and is not included in Gombey's platform subscription.
- The specific project/tier and agreement version. Preserve the customer's
  affirmative consent with the associated Stripe Customer and proposal.

This is a disclosure checklist, not a legal contract. Have the merchant's
legal/tax advisor review the actual wording and cancellation terms before live
use.

## Sandbox prerequisites

- Use a dedicated Stripe sandbox/test mode, never Live mode.
- Use a fresh synthetic customer and Stripe test clock for date-advance tests.
- Reconcile the exact standard setup amount, kickoff/delivery installment
  amounts, monthly amount, promotion duration, cancellation terms, and tax
  treatment before making test objects. Do not change the live catalog as part
  of this rehearsal.
- The current live launch coupons repeat fixed monthly discounts for 12 months:
  $50/month for Cloud Workspace, $100/month for Workspace Appliance, and
  $200/month for Private Local AI. Direct read-only retrieval of each coupon on
  2026-10-28 returned no `applies_to` field, so none is product-restricted;
  tier names/metadata are not enforcement. Each coupon and active promotion
  code allows three redemptions, with zero used and no coupon `redeem_by` or
  code `expires_at`. Do not share or apply these codes in a customer checkout:
  the wrong tier's fixed amount could produce a monthly price different from
  the public offer. In a dedicated sandbox, create and verify product-scoped
  replacement coupons/codes and prove each is rejected for the other products
  before replacing the live codes. Per-tier three-redemption caps still do not
  enforce the site's first-three-deployments total across all tiers; the
  operator must track that global count and stop offering the launch discount
  after the third accepted deployment.
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
  not add or remove registrations as part of this sandbox rehearsal. A fresh
  read-only check found live Tax Settings are `pending` because the head-office
  address is missing; the registrations list is empty. The threshold-monitoring
  response returned no locations and no `computed_at` timestamp, so it provides
  neither a fresh signal nor a legal conclusion. Do not enter the head-office
  address or add a registration until the owner/accountant confirms the
  appropriate business details and tax treatment. [Stripe
  Tax and Payment Links](https://docs.stripe.com/tax/payment-links).
- A fresh 2026-10-28 read-only API check confirmed the three active live
  Payment Links collect only the 50% founding kickoff installment. They have
  `payment_method_collection=if_required`, no `payment_intent_data`, no
  `subscription_data`, and no `consent_collection.payment_method_reuse_agreement`.
  They do not save a future-use payment method, record off-session reuse
  consent, or create a subscription. Their `automatic_tax.enabled` flag is
  true, but Tax Settings are pending and there are no active registrations;
  Stripe will not calculate tax until the merchant/accountant resolves setup.
  Do not send these links or describe tax as configured.
- The three separate monthly subscription Payment Links remain inactive. Each
  uses its standard monthly Price, allows promotion codes, requires payment
  method collection, sets a 30-day trial with cancellation if no method is
  available, and has automatic tax disabled. These are only a fallback because
  they require a separate customer checkout. Their actual trial, promotion,
  payment-failure, consent, and tax behavior has not been rehearsed.
- In the sandbox, test a kickoff checkout with Customer creation and
  `payment_intent_data.setup_future_usage=off_session`, plus explicit consent,
  then create the subscription at accepted delivery from that Customer's saved
  method. Verify the matching launch rate, consent record, tax treatment,
  failure/authentication recovery, and test-clock timeline before using any
  live link. No live Payment Link or account setting was changed during the
  read-only check.
- Identify the existing sandbox products/prices/coupons or create disposable
  test-only objects. Avoid copying live IDs into test mode; Stripe objects are
  mode-specific.
- Use Stripe test payment methods only. Cancel disposable test subscriptions
  and delete disposable test customers after recording the results, as
  supported by Stripe.

## Test flow

### 1. Kickoff payment

- In the sandbox, create a one-time hosted checkout for exactly half of the
  approved setup amount. Require Customer creation and set
  `payment_intent_data.setup_future_usage=off_session` so the submitted method
  is attached to that Customer. Show and record the explicit agreement for the
  two setup installments and future subscription charges; include timing,
  cadence, launch duration, standard renewal price, and cancellation terms.
- Pay with a Stripe test method. Record the checkout/payment IDs, amount,
  consent evidence, Customer/payment-method association, and event timestamp.
  The pass signal is a successful server-side payment event, not only a browser
  success page.
- Confirm exactly one setup deposit is collected, the intended reusable method
  is attached to the correct Customer, and no subscription begins at kickoff.
- Also test declining consent: the method must not be saved for off-session
  use, and the customer must be offered the separate-checkout fallback instead.

### 2. Delivery and deferred subscription

- Mark acceptance only after the written pilot checklist is approved.
- Send the second one-time invoice for the remaining half of setup and collect
  it only after written acceptance. Test both automatic payment from the
  consented saved method and the recovery path when that payment fails.
- After acceptance and successful delivery payment, create exactly one
  subscription for that same Customer using its saved payment method, automatic
  collection, and `trial_period_days=30`. The customer should not have to enter
  payment details or enroll again. Record the accepted-delivery and
  subscription-created timestamps; because creation occurs at accepted
  delivery, the first subscription invoice should be attempted about 30 days
  after delivery.
- Apply the approved launch discount/rate only to the intended paid monthly
  periods, then transition to the standard monthly price. Do not assume coupon
  duration interaction with a trial; verify the invoice timeline in the
  sandbox first.
- Confirm exactly one subscription is attached to the correct Customer and
  saved method, is `trialing`, and has the expected trial end. If the customer
  declined saving a payment method, do not charge off-session; use a separate
  customer-confirmed subscription checkout and explain that its 30-day timer
  starts on that later signup.
### 3. Advance time and verify billing

Use the test clock to advance to one day before the trial ends, the first
charge, the 12th paid launch-rate invoice, and the first standard-rate
renewal. Stripe supports [Billing test clocks](https://docs.stripe.com/billing/testing)
for simulating subscription events over time. At each point, record expected
and actual dates, invoice line items, discounts, tax, amount due, payment
status, and notification/webhook receipt. In the preferred flow, the first
monthly invoice must not be earlier than 30 days after subscription creation
at accepted delivery. In the fallback, the timer starts when the customer
completes the separate subscription checkout; do not describe that fallback as
delivery-plus-30-days if signup happened later.

Stripe recommends handling fulfillment from server-side events such as
`invoice.paid`; do not rely only on the browser redirect. If a future Gombey
integration is built, it must also handle payment failure, subscription
changes/cancellation, duplicate and out-of-order event delivery, and safe
retries. See [Stripe's invoice integration](https://docs.stripe.com/invoicing/integration)
and [subscription webhooks guide](https://docs.stripe.com/billing/subscriptions/webhooks).

## Required cases and pass criteria

| Case | Expected result |
|---|---|
| Kickoff checkout paid | One half-setup payment; explicit consent captured; reusable method attached to the correct Customer; no subscription yet. |
| Kickoff payment fails | No deployment is treated as paid/started; operator sees failure and no subscription is created. |
| Consent declined | No off-session use; customer is directed to the separate-checkout fallback. |
| Delivery invoice paid | Second half-setup payment occurs only after accepted delivery. |
| Subscription created at delivery | Exactly one `trialing` subscription uses the same Customer/method; no second customer checkout; trial end is 30 days after creation. |
| Deferred start | No recurring invoice/payment before the 30-day trial ends. |
| First monthly invoice | Correct agreed launch amount and due date; payment result is visible. |
| Launch term end | Exactly the approved number of paid periods receive the launch rate; next invoice uses standard price. |
| Wrong-tier launch code | Each tier's code is rejected by both other tier products; fail until product restrictions are verified. |
| Renewal failure | Failed invoice is visible and the operator has a clear retry/customer-contact path; no duplicate subscription is created. |
| Cancellation | Customer can cancel according to the agreement; the subscription stops at the agreed time. |
| Cleanup | All disposable test subscriptions and customers are canceled/deleted as supported; no live object is created. |

## Go/no-go

Do not describe the deferred subscription as configured or promise an
automatic first charge until the saved-method, consent, delivery trigger,
date/amount, failure/recovery, and webhook cases above pass in a sandbox.
The current approved offer is Cloud Workspace, Workspace Appliance, and
Private Local AI; see the dated audit in `mvp-readiness-2026-10-27.md` for the
published prices. Creating the subscription at accepted delivery is an
operator-managed step until Gombey's billing/webhook implementation and its
tests pass; Stripe handles recurring attempts only after subscription
enrollment. Do not use live links for the sandbox rehearsal. No customer
charge should be created from this runbook.
