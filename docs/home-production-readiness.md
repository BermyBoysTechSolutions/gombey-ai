# Gombey AI: at-home production-readiness checklist

Use this checklist to decide whether Gombey AI is ready for a tightly scoped paid pilot. It is not a security certification. Do not put real tenant, client, health, financial, or credential data into the system until the relevant checks pass.

## Current baseline

Last checked: 2026-10-06.

- `https://gombeytech.com` responds successfully.
- The landscape and portrait launch-pricing graphics respond successfully.
- `https://chat.gombeytech.com/health` responds `OK` when the public DNS path is reachable.
- The private proof script passed against local Ollama and the synthetic policy fixture.
- The running private containers are healthy: portal, Ollama, and MongoDB.
- The home test defaults to the host-local `gemma4:latest` model; LibreChat can see every model currently returned by the Mac's Ollama install.
- MongoDB and the private service network remain internal. During the home test, the API reaches the Mac's Ollama through Docker's host gateway; the isolated Ollama container remains available for a later customer deployment.
- The public chat URL currently depends on a quick Cloudflare tunnel that is kept alive by a Mac LaunchAgent. A named `gombey-chat` tunnel configuration exists but has no active connection or DNS cutover yet. Treat the quick-tunnel path as a pilot setup, not a production SLA.

## What “ready” means for the first pilot

The first pilot should be one workflow for a small property-management company:

> Turn a maintenance request into a clean work-order summary, identify missing information, draft the tenant reply, surface the relevant approved procedure, and flag emergencies for human escalation.

The pilot is ready when:

- the customer can reach the app and sign in from both Wi-Fi and cellular;
- a synthetic maintenance packet produces a useful answer with its source document identified;
- at least 8 of 10 test outputs are acceptable with light editing;
- the average response-drafting time is reduced from roughly 10 minutes to 3–4 minutes;
- emergency, uncertain, and unsupported requests are escalated instead of confidently invented;
- two users cannot see one another’s documents or conversations;
- the privacy mode is written down and matches the actual model path;
- a reboot and tunnel restart have a documented recovery procedure.

## Home session order

### 1. Prepare the test environment — 10 minutes

- Use the Mac that hosts the service and have the phone available.
- Keep all test data synthetic. Use the fixture in `proof-fixtures/` plus made-up maintenance requests.
- Open a notes page with four columns: test, expected result, actual result, pass/fail.
- Record the current date, model name, and whether the test is private-only or cloud/hybrid.

Run:

```bash
cd /Users/sultanyahya/Documents/Codex/2026-10-06/gombey-ai
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
docker exec gombey-ai-ollama ollama list
```

Expected: portal, Ollama, and MongoDB are healthy; `gemma4:latest` is available from the host Ollama; only the portal has a Docker-published port.

### 2. Test the public entry points — 10 minutes

From the phone, test the following on Wi-Fi and then cellular:

- `https://gombeytech.com`
- tap every “Launch Gombey AI” link;
- `https://chat.gombeytech.com/health`;
- load the login page, refresh it, and return to the landing page.

Record whether the domain works on each network. If it works on cellular but not Wi-Fi, the issue is probably local DNS, Tailscale, or router caching—not the public deployment. Do not change DNS records during this test. If it fails publicly, capture the exact error and timestamp before restarting anything.

On the Mac, also run:

```bash
curl -fsS https://chat.gombeytech.com/health
dig @1.1.1.1 +short chat.gombeytech.com A
```

Expected: `OK` and the Vercel/Cloudflare edge address. A stale local resolver can disagree with the public resolver; note that separately.

### 3. Verify access and account boundaries — 15 minutes

- Sign in with the current test account.
- Sign out and confirm the protected page sends you back to login.
- Refresh after signing in; confirm the session survives a refresh.
- Enter an incorrect password and confirm it is rejected without exposing implementation details.
- Confirm public registration is disabled.
- Create a second test account only if the current admin flow is already documented; never paste a real password into notes or chat.
- In two separate browser profiles, confirm conversations and uploaded files do not cross between accounts.
- Verify that an ordinary user cannot reach admin settings.

Expected: access is deliberate and isolated. If account creation, password recovery, or role boundaries are unclear, the app is not ready for customer data.

### 4. Prove which privacy mode is active — 20 minutes

There are two materially different products:

- **Private-only:** the model and retrieval path run on the customer-controlled machine or network. This is the mode that can support a carefully scoped private-AI promise.
- **Cloud/hybrid:** a hosted provider or OpenRouter receives prompts or files. This can still be useful, but it must not be sold as local-only privacy.

Run the repository checks:

```bash
cd /Users/sultanyahya/Documents/Codex/2026-10-06/gombey-ai
./scripts/verify-branding.sh
./scripts/private-proof.sh
docker network inspect gombey-private --format '{{.Name}} internal={{.Internal}} containers={{len .Containers}}'
```

Expected:

- branding check passes;
- private proof reports the local model, synthetic document fact, no external provider in the private config, and an internal network;
- the network reports `internal=true`.

The current home configuration is **host-local mode**, not the stronger isolated-container mode: the model still stays on the Mac, but the API reaches it through `host.docker.internal`. Test it with a known fact from the synthetic fixture. Ask a question that cannot be answered from general knowledge and verify the exact fixture identifier appears. Also ask an unrelated question and check that the answer does not claim access to a source it did not receive.

For a stronger proof, temporarily remove the Mac’s internet connection while keeping the local browser path available, then repeat the local synthetic test. If the local test cannot run without internet, record that as a gap instead of claiming local-only operation. Restore connectivity afterward.

### 5. Run the pilot workflow with synthetic documents — 30 minutes

Create a small test packet:

- emergency procedure;
- normal maintenance procedure;
- approved vendor list;
- sample lease/service boundary notes;
- ten fictional maintenance requests.

For each request, ask for exactly:

1. a one-sentence work-order summary;
2. missing information;
3. the appropriate procedure or source;
4. a draft tenant reply;
5. an escalation flag and reason;
6. a confidence note when the documents do not support an answer.

Measure for every request:

- time to first useful draft;
- total time including edits;
- whether the cited procedure was correct;
- whether any fact was invented;
- whether the request was escalated correctly.

Pass target: 8/10 outputs are usable with light edits, no invented emergency guidance, and a meaningful reduction in handling time.

### 6. Test document handling and deletion — 15 minutes

- Upload a synthetic document.
- Ask a question whose answer is in the document.
- Ask a question whose answer is deliberately absent.
- Confirm the absent answer is marked uncertain or escalated.
- Delete the document and repeat the question.
- Confirm the deleted document is no longer available to the user.
- Check that filenames and document text do not appear in public URLs, browser history links, or support screenshots.

If deletion behavior is not clear, stop before using customer files.

### 7. Test failure and recovery — 20 minutes

Test one failure at a time and record the recovery:

- restart the portal container;
- restart the Ollama container;
- restart MongoDB only if you have confirmed backups and understand the impact;
- close and reopen the Mac’s tunnel process;
- reboot the Mac only after confirming no unsaved data is important.

After each test, verify:

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
curl -fsS http://127.0.0.1:3080/health
curl -fsS https://chat.gombeytech.com/health
```

Expected: the local app recovers, the public URL recovers, and the documented restart path is short enough to perform under pressure. If the public URL goes down whenever the quick tunnel rotates or the Mac sleeps, that is a pilot reliability gap to fix before promising availability.

### 8. Check the actual security boundary — 15 minutes

- Confirm MongoDB and Ollama have no host-published ports.
- Confirm only the portal is exposed to the front-door network.
- Confirm registration remains disabled.
- Confirm no API keys, JWT secrets, passwords, or customer text are in git status, screenshots, or logs.
- Confirm the Mac account, Docker volumes, backups, and disk encryption are part of the customer’s operating plan.
- Decide who can administer the host and how access is revoked.
- Write down retention and deletion expectations before onboarding anyone.

Do not call the system “secure” in a broad sense. Say exactly what is proven: model runtime, network path, account boundary, storage, backups, and operational controls.

### 9. Package the first paid pilot — 20 minutes

Prepare a one-page pilot agreement with:

- one property-management workflow;
- one named customer owner;
- synthetic or narrowly approved data for the first week;
- 30-day founding pilot price: `$1,000`;
- what Gombey supplies and what the customer supplies;
- response-time and support boundaries;
- the success measures above;
- explicit exclusions: no emergency decision-making, no autonomous tenant communication, no guarantee beyond the tested privacy mode;
- a decision date at the end of the pilot.

Do not buy a Mac Studio, DGX Spark, or Strix Halo for a prospect before the workflow is accepted and paid for. Hardware is an implementation option after the first proof, not the proof itself.

### 10. Stop conditions

Stop and fix the issue before outreach if any of these occur:

- the public chat domain is intermittently unavailable;
- the model path is unclear or differs from the privacy claim;
- documents or conversations cross account boundaries;
- the model invents emergency instructions;
- deletion cannot be verified;
- a reboot loses the service or its configuration;
- you cannot explain where prompts, files, embeddings, logs, and backups live;
- you are tempted to test with real customer data because the synthetic test is inconvenient.

## First proof to complete before the first sale

The smallest credible proof is not a general-purpose AI assistant. It is one repeatable property-management workflow with synthetic data:

1. pass the local private proof;
2. run ten fictional maintenance requests;
3. record baseline and assisted handling times;
4. reach at least 8/10 usable outputs;
5. verify escalation and citation behavior;
6. document the exact data path and privacy mode;
7. show a five-minute demo to one decision-maker;
8. ask for the paid 30-day founding pilot.

If a step fails, keep the result as product evidence. Do not broaden the offer or start another project to avoid fixing it.
