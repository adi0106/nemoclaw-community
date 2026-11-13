# Provider Billing Integrity

| Catalog field | Value |
| --- | --- |
| Description | Helps program-integrity reviewers find anomalous provider billing, expand each lead to providers linked by shared addresses, bank accounts or owners, and total the paid exposure of each group, ending in a referral recommendation for a human. |
| Industry | 🏛️ Public Sector |
| Requirements | Docker · NemoClaw · NVIDIA Endpoints API key · Python 3 with pandas inside the sandbox (unverified) |
| NemoClaw | Unpinned |
| Harness | OpenClaw Unpinned |
| OpenShell | Unpinned |

An OpenClaw agent in a NemoClaw sandbox reviews 80 synthetic healthcare
providers and about 5,800 synthetic claims. It ranks providers with a
transparent billing-rule baseline, follows shared-entity links to build related
groups, and reports paid exposure. It recommends review and never determines
fraud or suspends payment.

> **Status: skeleton under development.** Only the offline CPU workflow is
> included. Kumo risk ranking, Nemotron policy retrieval, GPU acceleration and
> Auto Ontology are planned and are not in the skill yet (see
> [Roadmap](#roadmap)). The sandbox flow has not been run end to end.

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
| Verified on | Not yet verified in a sandbox. |
| Evidence level | local/static |
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
nemoclaw provider-billing-integrity agent --agent main -m \
  "Which providers are connected to P001 through shared entities as of 2026-06-30, and what was paid to that group?"
```

Or connect and use the TUI: `nemoclaw provider-billing-integrity connect`, then
`openclaw tui`.

## Commands

| Script | Purpose |
| --- | --- |
| `scripts/onboard.sh` | Create the sandbox with the OpenClaw harness. |
| `scripts/install.sh` | Install the skill. Applies no network policy. |
| `scripts/start.sh` | Recover the gateway and host forwards. |
| `scripts/stop.sh` | Stop the gateway while keeping the sandbox and workspace. |
| `scripts/generate_data.py` | Regenerate the synthetic data (deterministic). |

To delete the sandbox permanently, run `nemoclaw provider-billing-integrity destroy`
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

**Evidence level:** local/static

From this directory, check the lifecycle command contracts and shell syntax
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

**Expected result:** the first command prints `ok`; the second prints a JSON
list of three providers with `score` values.

**This verifies:** the host scripts issue the expected commands and the bundled
tool runs on the bundled data.

**This does not verify:** sandbox creation, skill installation, whether
Python and pandas are available in the sandbox, or the agent's answers.

## Roadmap

| Stage | Needs |
| --- | --- |
| Kumo risk ranking | Egress policy for `ai.api.nvidia.com`, a pinned Python 3.12 environment with `kumo-relational-client`, and a decision on how the API key reaches the call. |
| Policy retrieval | Embed and rerank egress policy and the same key decision, or an offline BM25 option. |
| GPU path | A host-side service, not the sandbox. |
| Auto Ontology | A host-side deployment reached through an authenticated, reviewed path. |
| Evidence | A real sandbox run, a screenshot, and an upgraded evidence level. |

## Known limitations

- The sandbox flow, skill installation and pandas availability are untested.
- The data is synthetic and small; results show the method works, not that it
  would perform on real programs.

## Third-party services and dependencies

Uses the installed NemoClaw and OpenClaw components and NVIDIA Endpoints for
inference. The bundled tool needs pandas (`utilities/requirements.txt`). The
42 CFR text under `data/documents/` is public-domain U.S. regulation text.
