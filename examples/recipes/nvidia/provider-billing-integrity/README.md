# Provider Billing Integrity

| Catalog field | Value |
| --- | --- |
| Description | Helps program-integrity reviewers find anomalous provider billing, expand each lead to providers linked by shared addresses, bank accounts or owners, and total the paid exposure of each group, ending in a referral recommendation for a human. |
| Industry | 🏛️ Public Sector |
| Requirements | Docker · NemoClaw · NVIDIA Endpoints API key |
| NemoClaw | Unpinned |
| Harness | OpenClaw Unpinned |
| OpenShell | Unpinned |

An OpenClaw agent in a NemoClaw sandbox reviews 80 synthetic healthcare
providers and about 5,800 synthetic claims. It ranks providers with a
transparent billing-rule baseline, follows shared-entity links to build related
groups, and reports paid exposure. It recommends review and never determines
fraud or suspends payment.

The scenario is built around the **NVIDIA Agent Knowledge Foundation**: the
components that ground an agent's analysis in governed definitions, relational
predictions, retrieved evidence and GPU-accelerated analytics instead of model
memory. See [Agent Knowledge Foundation](#agent-knowledge-foundation) for what
each component does here and which ones this version includes.

> **Status: under development.** The CPU baseline and **Nemotron embed and
> rerank** policy retrieval are included and verified. Kumo, Auto Ontology and
> RAPIDS are planned (see [Roadmap](#roadmap)). See
> [Verification](#verification) for exactly what was run.

## Agent Knowledge Foundation

Each question a reviewer asks here has a component of the NVIDIA Agent
Knowledge Foundation that answers it best. The table shows the intended design
and what this version actually ships.

| Reviewer question | Foundation component | In this version |
| --- | --- | --- |
| What do the tables mean, and what is the right denominator? | **Auto Ontology**: a semantic layer over the provider-billing database with terms, relationships and measures that carry explicit as-of dates, queried through grounded text-to-SQL | Not included. The skill reads the CSV files directly. |
| Who is likely to be audited in the next 90 days? | **Kumo** (`nvidia/kumo-relational`, hosted on build.nvidia.com): relational prediction over providers, addresses, claims and audit findings | Not included. `scan` is a transparent rule baseline, which is also the comparison point for a Kumo ranking. |
| What does policy say? | **Nemotron embed and rerank**: retrieval over four public 42 CFR sections with citable passages | **Included.** `retrieve.py` embeds the chunks and query, reranks the closest, and returns each passage with a ready-made `[document, chunk N]` tag the skill requires in every policy statement. If the hosted call fails it reports `blocked` and substitutes nothing. |
| Who is connected, and does it scale? | **RAPIDS** (cuDF, cuGraph through nx-cugraph): the same baseline and related-entity expansion on GPU | Not included. `related` and `cluster-exposure` run on CPU in the standard library. |

What the foundation adds is grounding. An answer that names a provider, a
dollar figure or a regulation can be traced to a query, a model run with its
inputs, or a retrieved passage, and a step that cannot run is reported as
blocked rather than filled in from memory. The skill's rules already enforce
the last part: every number comes from a command that was run, and an
unavailable step is reported as blocked.

The same scenario ran with these components outside NemoClaw in the source
experiments, where the CPU and GPU tools produced matching answers, hosted
Kumo ranked the planted ring highest, and Auto Ontology answered three of four
grounded questions correctly. Those results are not reproduced by this recipe.
This recipe's job is to place them inside a NemoClaw sandbox with reviewed
network policy, one component at a time.

## Screenshot

Not yet captured. A sanitized screenshot or terminal capture of a real run is
required before submission.

## At A Glance

| Question | Answer |
| --- | --- |
| Category | NVIDIA Recipe |
| Contributor or provenance | NVIDIA |
| Use this when | A reviewer needs a worked example of agent-assisted related-entity analysis with a human making the final decision. |
| You will get | Ranked leads, related-provider groups with the reason for each link, per-group paid totals, and a referral recommendation. |
| Runs on | A host that runs NemoClaw with Docker. |
| Requires | NemoClaw, an NVIDIA Endpoints API key for the agent's model. |
| Verified on | NemoClaw v0.0.142, OpenShell v0.0.116, OpenClaw harness, Ubuntu 22.04, `nvidia/nemotron-3.5-lightning-30b-a3b` on NVIDIA Endpoints, a handful of runs, not repeated at scale. |
| Evidence level | live end-to-end |
| Support and maturity | Best-effort community support; see the repository support policy. |
| External access, data, and actions | Inference calls to the configured provider, plus two POST paths from sandbox Python to build.nvidia.com for policy retrieval (embeddings and rerank; the 42 CFR text, not provider data, is what is embedded, along with the question). A second OpenShell provider is created from your key. No write actions. All data is synthetic. |
| Start here | [Quickstart](#quickstart) |
| Confirm success | [Verification](#verification) |

## Quickstart

The only credential is your NVIDIA Endpoints key. NemoClaw stores it through
OpenShell provider plumbing and does not write it into the sandbox.

```bash
cd examples/recipes/nvidia/provider-billing-integrity
cp .env.example .env      # add NVIDIA_INFERENCE_API_KEY
bash scripts/onboard.sh   # create the OpenClaw sandbox
bash scripts/install.sh   # install the skill, data and tools
bash scripts/start.sh     # ensure the sandbox is running
```

Ask a question:

```bash
nemoclaw billing-integrity agent --agent main -m \
  "Which providers are connected to P001 through shared entities as of 2026-06-30, and what was paid to that group?"
```

Or connect and use the TUI: `nemoclaw billing-integrity connect`, then
`openclaw tui`.

## Commands

| Script | Purpose |
| --- | --- |
| `scripts/onboard.sh` | Create the sandbox with the OpenClaw harness. |
| `scripts/install.sh` | Install the skill. With the `build` provider it also imports the provider profile, creates and attaches a second provider from your key, applies the egress policy, and restarts the sandbox (workspace kept) so the agent sees the new credential. |
| `scripts/start.sh` | Recover the gateway and host forwards. |
| `scripts/stop.sh` | Stop the gateway while keeping the sandbox and workspace. |
| `scripts/generate_data.py` | Regenerate the synthetic data (deterministic). |

To delete the sandbox permanently, run `nemoclaw billing-integrity destroy`
and confirm.

## What the skill ships

`skills/provider-billing-integrity/` is installed into the sandbox with its data:

- `data/`: synthetic providers, claims, addresses, bank accounts, beneficiaries
  and audit findings, plus four public-domain 42 CFR sections in `data/documents/`.
- `utilities/integrity_tool.py`: `scan` (rule baseline), `related` (transitive
  related-entity expansion) and `cluster-exposure` (paid totals per group).

The skill sets an as-of date of 2026-06-30 and states that a shared entity is a
lead rather than guilt.

## Security notes

- Egress is limited to two POST paths for Python only: `integrate.api.nvidia.com`
  `/v1/embeddings` and `ai.api.nvidia.com` `/v1/retrieval/.../reranking`
  (`policies/nvidia-hosted-models.yaml`), plus the agent's inference provider.
  What is sent is the policy text chunks and the reviewer's question; the
  provider and claims data is not sent to these services.
- The raw API key stays in the OpenShell gateway. The sandbox holds
  `openshell:resolve:env:` placeholders, and OpenShell substitutes the key at
  egress, only on the host each credential is bound to. The embed credential is
  bound to `integrate.api.nvidia.com`; a second provider created by
  `install.sh` (`providers/nvidia-ai-api.yaml`) binds the same key to
  `ai.api.nvidia.com`. Without it, rerank fails with `credential_endpoint_mismatch`.
- The agent works on synthetic data only. Do not load real claims, beneficiary
  or provider data into this example.
- Outputs are recommendations for human review. The skill instructs the agent
  not to assert fraud or order a payment suspension; that is a prompt-level
  rule, not an enforced control.
- Remove it with `openshell sandbox provider detach billing-integrity billing-integrity-ai-api`,
  `openshell provider delete billing-integrity-ai-api`,
  `nemoclaw billing-integrity policy remove nvidia-hosted-models`, and
  `openshell provider profile delete billing-integrity-nvidia-ai-api`.

## Verification

**Evidence level:** live end-to-end (one run per workflow below; offline CPU workflow and Nemotron retrieval)

Onboard, install, then ask one question:

```bash
bash scripts/onboard.sh && bash scripts/install.sh && bash scripts/start.sh
nemoclaw billing-integrity agent --agent main -m \
  "Using the provider-billing-integrity skill: which providers are connected to P001 through shared addresses, bank accounts or owners as of 2026-06-30, what was paid to that group in total, and is P020 part of it? Give a short referral recommendation."
```

**Expected result:** an answer that runs `integrity_tool.py`, names the six-provider
cluster P001 to P006 linked by two addresses, one bank account and one owner,
reports 1,255 claims and a total paid of $211,006.18, states that P020 (206
claims, $24,418.69) shares no entity with the cluster, and ends with a
recommendation for human review that does not assert fraud. Wording varies by
model; the numbers come from the tool and are deterministic.

**This verifies:** sandbox creation, skill installation with its data and
tools, the tool running inside the sandbox, and an agent answer whose figures
match the same tool run on the host.

**This does not verify:** other models, other questions, repeat runs, GPU hosts,
or the planned Kumo and Auto Ontology stages.

**Policy retrieval.** Reset the agent session first (see
[Known limitations](#known-limitations)), then ask a policy question in a fresh session:

```bash
nemoclaw billing-integrity sessions reset agent:main:main --agent main
nemoclaw billing-integrity agent --agent main --session-id demo-1 -m \
  "Using the provider-billing-integrity skill, answer in this chat: under 42 CFR 455.23, within how many days must a State send notice of a payment suspension, how many days if law enforcement asks in writing to delay it, and what is the longest the delay can run? And what is the normal range of the reenrollment bar after a revocation under 42 CFR 424.535?"
```

**Expected result:** 5 days, 30 days and a 90-day maximum, and a 1 to 10 year bar,
each quote ending in a tag such as `[42-cfr-455-23-payment-suspension.md, chunk 0]`
and `[42-cfr-424-535-revocation.md, chunk 16]`. In the observed run both chunks
contain the quoted text, and the gateway audit log
(`openshell logs billing-integrity | grep reranking`) shows two allowed rerank
calls from `python3`. Chunk numbers depend on the shipped documents.

**This verifies:** the egress policy and second credential binding, that
`retrieve.py` runs from the agent's own shell with placeholders only, and that
an answer's policy quotes match the retrieved chunks.

**This does not verify:** that every policy statement an agent writes is
retrieved. See the limitations.

Offline checks, without a sandbox or any service call:

```bash
bash scripts/tests/test_lifecycle_commands.sh
bash -n scripts/*.sh scripts/tests/*.sh
```

Check the CPU tool directly:

```bash
cd skills/provider-billing-integrity
python3 utilities/integrity_tool.py scan --as-of 2026-06-30 --top 3
```

Expected: the first command prints `ok`; the second prints a JSON list of three
providers with `score` values. These two checks cover only the host scripts and
the bundled tool.

## Roadmap

Each stage adds one Agent Knowledge Foundation component and keeps the CPU tool
as the baseline to compare against.

| Stage | Component | Needs |
| --- | --- | --- |
| 1 | CPU baseline | Done: standard-library tool, offline. |
| 2 | Nemotron embed and rerank for policy evidence | Done: `retrieve.py`, egress policy, second provider, restart on install. Remaining: a larger document set, and measuring retrieval against BM25 (`--method bm25` is included for the comparison). |
| 3 | Kumo risk ranking | Add the Kumo path to the policy and provider profile (the route was reachable in a spike; a real prediction was not run). Needs a pinned Python 3.12 environment with `kumo-relational-client`, built into the image because package installs inside the sandbox are fragile. |
| 4 | Auto Ontology | A host-side deployment reached through an authenticated, reviewed path, with its own API token. |
| 5 | RAPIDS on GPU | A host-side service, not the sandbox. |
| Evidence | Screenshot and a higher evidence level per stage | A real sandbox run of each stage. |

`policies/nvidia-hosted-models.yaml` and `providers/nvidia-ai-api.yaml` cover stage 2
only. The Kumo route is not allowed yet and is added with stage 3.

## Known limitations

- **Reset the agent session after changing the skill, and between unrelated
  tests.** OpenClaw keeps one long session (`agent:main:main`). In testing, an
  agent that had earlier read the regulation files directly kept doing so and
  skipped retrieval; after `sessions reset` it ran retrieval as the skill
  instructs. `nemoclaw billing-integrity sessions reset agent:main:main --agent main`.
- **A new credential reaches the agent only after the sandbox container
  restarts.** `install.sh` does this when it attaches the provider. Without
  it, the agent's rerank call fails with HTTP 403.
- **The skill's rules are instructions, not enforcement.** With the 30B test
  model, retrieval was skipped in a long-running session even after the
  instructions were tightened, and ran in a fresh one. Policy quotes were
  tagged reliably once the tool emitted a ready-made `cite` string to copy. The model's own
  section and paragraph references (for example "(d)(1)") can still be wrong, so
  trust the quoted passage and its `cite` tag, not paragraph numbers the agent
  adds. Check that retrieval ran when it matters.
- The first retrieval builds an embedding cache in the sandbox's temp directory
  (about 12 seconds); later queries take about 2 seconds. One early first run
  failed after two minutes and could not be reproduced.
- Verified with one model and a few questions. The default model for `build` was
  changed to `nvidia/nemotron-3.5-lightning-30b-a3b` because the previous
  default returned HTTP 404 for the test key; availability depends on your
  NVIDIA Endpoints account. Set `NEMOCLAW_MODEL` in `.env` to any model your
  key can call.
- The sandbox is created with `--no-sandbox-gpu` because this recipe is
  CPU-only. On the test host GPU passthrough failed on a stale CDI file.
- NemoClaw limits sandbox names to 19 characters.
- The data is synthetic and small; results show the method works, not that it
  would perform on real programs.

## Third-party services and dependencies

Uses the installed NemoClaw and OpenClaw components and NVIDIA Endpoints for
inference. The bundled tool uses only the Python standard library, so nothing is
installed in the sandbox. The 42 CFR text under `data/documents/` is public-domain U.S. regulation text.
