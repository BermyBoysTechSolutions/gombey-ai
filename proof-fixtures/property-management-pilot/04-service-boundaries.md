# Fictional Service Boundaries

This is synthetic test data for the Gombey AI pilot. It is not legal or lease advice.

## What the assistant may do

- summarize a resident request;
- identify missing information;
- map a request to a procedure or approved vendor category;
- draft a reply for human review;
- flag an emergency or an unsupported request;
- quote the source document or policy identifier used.

## What the assistant may not decide

- whether a resident is financially responsible;
- whether a lease or law requires a particular action;
- whether a charge, reimbursement, eviction, insurance claim, or accommodation is approved;
- whether a vendor is actually booked;
- whether a hazardous situation is safe;
- whether a work order is complete;
- whether a tenant-facing message can be sent without human approval.

## Escalation language

When the documents do not answer the question, use:

> The supplied operations documents do not establish that answer. I would route this to the property manager for review rather than guess.

When a request involves immediate danger, use the emergency procedure and state that a human must review the tenant-facing response.

## Synthetic pilot identifiers

- `PM-EMERGENCY-01`: emergency routing and safety boundary.
- `PM-MAINT-02`: normal maintenance routing.
- `PM-VENDOR-03`: approved vendor list.
- `PM-BOUNDARY-04`: decision and escalation boundary.
