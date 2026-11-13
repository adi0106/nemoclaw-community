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

> **Status: skeleton under development.** Only the offline CPU workflow is
> included. None of the Agent Knowledge Foundation components below is wired
> into the skill yet; the CPU tool stands in for them (see
> [Roadmap](#roadmap)). The offline workflow has been run once end to end; see
> [Verification](#verification).

## Agent Knowledge Foundation

Each question a reviewer asks here has a component of the NVIDIA Agent
Knowledge Foundation that answers it best. The table shows the intended design
and what this version actually ships.

| Reviewer question | Foundation component | In this version |
| --- | --- | --- |
| What do the tables mean, and what is the right denominator? | **Auto Ontology**: a semantic layer over the provider-billing database with terms, relationships and measures that carry explicit as-of dates, queried through grounded text-to-SQL | Not included. The skill reads the CSV files directly. |
| Who is likely to be audited in the next 90 days? | **Kumo** (`nvidia/kumo-relational`, hosted on build.nvidia.com): relational prediction over providers, addresses, claims and audit findings | Not included. `scan` is a transparent rule baseline, which is also the comparison point for a Kumo ranking. |
| What does policy say? | **Nemotron embed and rerank**: retrieval over four public 42 CFR sections with citable passages | Not included. The text ships in `data/documents/` but the skill does not search it yet. |
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
| Verified on | NemoClaw v0.0.142, OpenShell v0.0.116, OpenClaw harness, Ubuntu 22.04, `nvidia/nemotron-3.5-lightning-30b-a3b` on NVIDIA Endpoints, one run. |
| Evidence level | live end-to-end |
| Support and maturity | Best-effort community support; see the repository support policy. |
| External access, data, and actions | Inference calls to the configured provider. No other network access, no write actions. All data is synthetic. |
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
| `scripts/install.sh` | Install the skill. Applies no network policy. |
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

- The v1 workflow is offline: `install.sh` applies no network policy, so the
  sandbox keeps NemoClaw's default egress. The only outbound traffic is the
  agent's inference provider.
- The agent works on synthetic data only. Do not load real claims, beneficiary
  or provider data into this example.
- Outputs are recommendations for human review. The skill instructs the agent
  not to assert fraud or order a payment suspension; that is a prompt-level
  rule, not an enforced control.
- `policies-optional/nvidia-hosted-models.yaml` is a draft for planned stages
  and is never applied by the scripts.

## Verification

**Evidence level:** live end-to-end (one run; the offline workflow only)

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
or the planned Kumo, retrieval and Auto Ontology stages.

Offline checks, without a sandbox, check the lifecycle command contracts and shell syntax
without creating a sandbox or contacting a service:

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
| 1 (this version) | CPU baseline | Standard-library tool, offline. |
| 2 | Nemotron embed and rerank for policy evidence | Spike passed: with the draft egress policy and a second provider bound to `ai.api.nvidia.com` (`providers-optional/`), embed and rerank calls from sandbox Python return HTTP 200 while the sandbox holds only credential placeholders. Remaining work: wire `retrieve.py` into the skill, apply the policy and provider in `install.sh`, and verify an agent answer cites retrieved passages. |
| 3 | Kumo risk ranking | The same provider covers the Kumo route (reachable in the spike; a real prediction was not run). Needs a pinned Python 3.12 environment with `kumo-relational-client`, built into the image because package installs inside the sandbox are fragile. |
| 4 | Auto Ontology | A host-side deployment reached through an authenticated, reviewed path, with its own API token. |
| 5 | RAPIDS on GPU | A host-side service, not the sandbox. |
| Evidence | Screenshot and a higher evidence level per stage | A real sandbox run of each stage. |

`policies-optional/nvidia-hosted-models.yaml` and `providers-optional/nvidia-ai-api.yaml`
are draft egress and credential definitions for stages 2 and 3 and are never
applied by the scripts.

## Known limitations

- Verified with one model and one question. The default model for `build` was
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
