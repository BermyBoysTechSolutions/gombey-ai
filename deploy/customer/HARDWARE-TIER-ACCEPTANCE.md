# Hardware-tier commissioning and acceptance

Status: preproduction checklist. This is a test plan, not evidence that a
SER5, Mac Studio, DGX Spark, or Strix Halo installation has passed.

## The intended tier boundary

- **Workspace Appliance:** the on-site Beelink SER5 hosts the Gombey workspace
  and its agreed data. Model inference remains cloud-based through the
  customer's selected provider. A SER5 deployment is not a local-inference
  promise.
- **Private Local AI:** the selected customer workstation runs the accepted
  local model for the agreed workflow. A Mac Studio, NVIDIA DGX Spark, or
  AMD Strix Halo system is a candidate only after sizing and testing the exact
  configuration.

These are intentional, different deployment levels. Do not describe either
as a pooled tenant deployment or imply that local model inference alone keeps
all data on-site. Use the public offer and written proposal to set user,
agent, workflow, connector, support, hardware ownership, and travel scope; do
not infer fixed quantities from the other tier.

## Before quoting or purchasing hardware

- Record the exact manufacturer, model/SKU, memory, storage, operating system,
  warranty, shipping, tax, installation, and replacement plan. Confirm in
  writing who buys and owns the device and who pays for third-party services.
- Obtain the customer's approval of the hardware quote, service location,
  travel, network access method, physical access, maintenance window, and
  support boundaries before ordering or visiting.
- Write down the agreed user count, workflows, knowledge sources, expected
  questions, unsupported questions, response-quality criteria, and the exact
  model/provider. Do not promise performance or privacy beyond that test.
- Draw the data path for chat prompts, retrieved document excerpts, embeddings,
  inference, logs/telemetry, updates, backups, and remote support. For each
  path record the destination, owner, retention, and encryption. Get approval
  for every external provider or transfer.
- Do not load real customer files until the scope is signed, access controls
  pass, the backup destination and recovery-key custody are agreed, and the
  exact acceptance test is ready.

## Workspace Appliance: SER5 commissioning

1. Verify the delivered device matches the approved quote. Record serial,
   firmware/BIOS version, storage, memory, OS version, warranty, and assigned
   owner in the customer's secured operations record.
2. Apply supported firmware/OS updates, secure boot where supported, a unique
   operator account, least-privilege access, full-disk encryption where
   supported, and a documented recovery method. Do not retain default
   credentials.
3. Install the pinned Gombey customer deployment with a unique environment,
   secrets, database, upload store, vector store, and Compose project. Keep
   service ports private; do not expose MongoDB, PostgreSQL, Meilisearch, or
   the RAG API to the LAN or internet.
4. Decide and test how authorized employees reach the on-site workspace. Do
   not enable router port forwarding or an unreviewed public tunnel by
   default. Require an approved VPN/tunnel design, identity boundary, TLS,
   revocation path, and tested failure recovery before remote access is
   enabled. Until then, state that access is limited to the approved local
   network or access path.
5. Configure the customer's chosen cloud chat provider and separate
   embeddings provider using their own accounts and an approved secure secret
   entry method. Confirm that the customer is billed directly. Explain that
   prompts/retrieved excerpts and embedding text leave the appliance for
   those providers; the SER5 is not doing local inference.
6. Create the exact agreed admin/member accounts with public registration
   disabled. Test with at least two disposable members: they can select the
   admin-shared knowledge agent, cannot edit its configuration or source files,
   and cannot access each other's private chats/files.
7. With synthetic or customer-approved acceptance files, test grounded answers,
   citations, unsupported-fact abstention, document deletion, provider failure,
   and account revocation. Confirm the selected provider's usage is attributed
   to the customer's account.
8. Test a controlled reboot, loss/restoration of power and internet, encrypted
   off-device backup, clean restore, and the documented remote recovery path.
   Verify no customer file is lost and no service port becomes public.
9. Claim monitoring, remote administration, or routine updates only after the
   specific mechanism is installed, access-controlled, exercised, and included
   in the signed scope.

## Private Local AI: workstation commissioning

1. Repeat the hardware and ownership inventory above for the exact selected
   Mac Studio, DGX Spark, or Strix Halo configuration. Confirm the OS, local
   inference runtime, supported model format, available memory, storage, and
   warranty before selecting a model.
2. Select the model only after running the agreed synthetic evaluation corpus
   on that actual hardware. Record model name/version, quantization, runtime,
   context setting, generation settings, peak memory, latency, and any
   concurrency limit. Test representative short and long requests, grounded
   retrieval, citations, unsupported facts, and restart/recovery. A different
   model or hardware configuration requires a new acceptance run.
3. Verify that the accepted chat workflow sends inference to the local runtime
   and does not call a third-party model API. Separately inspect embeddings,
   file extraction, telemetry, crash reports, updates, backups, connectors,
   and remote support. If any of those leave the site, disclose the destination
   and do not describe the whole system as fully local/private.
4. Configure a local embeddings path if the agreed privacy boundary requires
   it. Otherwise, document the external embeddings provider, customer billing,
   data transfer, and retention. Do not infer embeddings privacy from local
   text generation.
5. Apply least-privilege accounts, disk encryption where supported, private
   service networks, and the approved employee access design. Test at least
   two members, shared-agent access, private chats, source visibility,
   offboarding, and session revocation.
6. Test backup/restore, update rollback, model/runtime restart, disk-full and
   network-loss behavior, and the support/recovery procedure. Confirm how
   encrypted backups leave the device, who controls the key, and when backups
   expire or are deleted.
7. Keep connectors and write actions out of scope unless a named integration
   separately passes authorization, data-path, least-privilege, and human
   approval tests. A tool appearing in the UI is not proof of safe operation.

## Delivery acceptance record

Before handoff, record the exact accepted configuration and obtain customer
sign-off for:

- Hardware ownership, warranty, model/runtime versions, and any quoted extras.
- Named accounts and tested role boundaries.
- The accepted workflow, questions, sample sources, expected answers, and
  known limitations.
- Cloud provider and embeddings destinations for the Appliance tier, or the
  separately verified local/external data paths for Private Local AI.
- Access method, backup destination, encryption/key custody, retention,
  restore result, update/rollback procedure, and incident contact.
- Included support hours, response target, escalation path, and what requires
  a new quote.

If a required test fails, record the failure and keep the affected claim out of
the accepted scope. Do not substitute a Mac Mini test for the SER5 or offered
workstation acceptance, and do not accept production customer data until the
relevant device-specific gates pass.
