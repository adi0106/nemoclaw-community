# Market Analysis

| Catalog field | Value |
| --- | --- |
| Description | Helps market analysts review a synthetic equity market, covering what the tables hold, who led and lagged, which sessions were unusual, who moves together, what a model expects next, and what SEC disclosure rules require, and ending in a short list of issuers to take forward for human review. |
| Industry | 💳 Financial Services |
| Requirements | Docker · NemoClaw · NVIDIA Endpoints API key · PyPI reachable at install time · optional GPU stage: an NVIDIA GPU with a working CDI setup and about 5 GB more · optional Auto Ontology deployment you run yourself |
| NemoClaw | Unpinned |
| Harness | OpenClaw Unpinned |
| OpenShell | Unpinned |

An OpenClaw agent (or, optionally, a Hermes agent) in a NemoClaw sandbox reviews 36 fictional issuers over 166
trading days (2026-01-02 to 2026-08-31): prices, company news and declared peers, plus three real, public-domain
SEC rule texts. The agent writes its own short pandas, scikit-learn and NetworkX analyses and runs them with a
helper that uses RAPIDS on a GPU sandbox. It asks Kumo for a five-session ranking, retrieves the rule text with
Nemotron embed and rerank, and can ask Auto Ontology a business question about the tables. It proposes issuers
for human review and never gives investment advice, places trades or approves anything.

The scenario is built around the **NVIDIA Agent Knowledge Foundation**: components that ground an agent's
analysis in governed definitions, relational predictions, retrieved evidence and GPU-accelerated analytics
instead of model memory. This recipe is the NemoClaw sandbox version of the market-analysis example in the Agent
Knowledge Foundation (AKF) examples repository, which will be published soon. That repository also holds the
evaluation kit; this recipe covers the integration only.

> **Status: under development; run once per harness in a CPU-only sandbox, with gaps.** The lifecycle scripts,
> the Python environments, the egress policy, the Kumo call and the skill loading were exercised live on OpenClaw and
> on Hermes (see [Verification](#verification)). Retrieval was **not** verified: the hosted embedding model returned
> HTTP 503 and timeouts during testing, so the Nemotron embed and rerank path and the rule citations never succeeded.
> Neither agent reliably followed every skill rule in those first runs (see [Known limitations](#known-limitations)),
> the GPU stage was not run, and Auto Ontology answered a count question but not the median question (see
> [Auto Ontology](#auto-ontology-optional)). Do not read any statement below as a measured accuracy or
> speed-up.

## Agent Knowledge Foundation

| Question | Component | In this recipe |
| --- | --- | --- |
| What do we have? | **Auto Ontology** text-to-SQL | **Optional.** `ontology_qa.py` asks a host-side deployment you run, shows its SQL, and the skill requires reading it. Reports `blocked` when not installed. |
| Who led and lagged, what was unusual, who moves together? | **RAPIDS** (cuDF, cuML, nx-cugraph) under the agent's own pandas, scikit-learn and NetworkX | **Included.** `accelerate.py` runs the agent's scripts on the CPU, or on RAPIDS on a GPU sandbox with no change to the script, and records which engine ran. |
| What does a model expect next? | **Kumo** relational prediction | **Included.** `kumo_predict.py` ranks the 12 most liquid issuers; reports `blocked` if the hosted call fails. |
| What do the rules require? | **Nemotron embed and rerank** retrieval | **Included.** `retrieve.py` returns passages from three SEC rule texts with a ready-made `[document, chunk N]` tag the skill requires in every policy statement. |

A component that is unavailable is reported as **blocked** with a reason and nothing is substituted.

## At A Glance

| Question | Answer |
| --- | --- |
| Category | NVIDIA Recipe |
| Contributor or provenance | NVIDIA |
| Use this when | You want to see an agent in a NemoClaw sandbox run a multi-question market analysis with reviewed egress, hosted NVIDIA models and optional GPU acceleration, or to adapt that pattern to your own data. |
| You will get | An agent that answers the six analysis questions below from the bundled synthetic data, quoting the command or script behind each number and the passage behind each rule. |
| Runs on | A host that runs NemoClaw with Docker. The optional GPU stage also needs an NVIDIA GPU. |
| Requires | NemoClaw, OpenShell, Docker, an NVIDIA Endpoints (build.nvidia.com) API key, and PyPI reachable at install time. |
| Verified on | NemoClaw on one Linux host, CPU-only sandboxes, OpenClaw and Hermes harnesses, one run each, partly; see [Verification](#verification). |
| Evidence level | integration |
| Support and maturity | Best-effort community support; see [SUPPORT.md](../../../../SUPPORT.md). Under development. |
| External access, data, and actions | Python in the sandbox may POST to build.nvidia.com on three paths: embeddings and rerank (the rule text and your question) and Kumo, **which receives the issuer, price and news tables**. With Auto Ontology, three paths on `host.openshell.internal:<port>`; that deployment then sends the schema and question to its own hosted models, outside the sandbox policy. The install reaches PyPI temporarily to build Python environments and creates a second OpenShell provider from your key. No write actions. All market data is synthetic. |
| Start here | [Quickstart](#quickstart) |
| Confirm success | [Verification](#verification) |

## Quickstart

The only credential is your NVIDIA Endpoints key. NemoClaw stores it through OpenShell provider plumbing and does
not write it into the sandbox.

```bash
cd examples/recipes/nvidia/market-analysis
cp .env.example .env      # add NVIDIA_INFERENCE_API_KEY (and optionally AUTO_ONTOLOGY_API_TOKEN, AUTO_ONTOLOGY_PORT)
bash scripts/onboard.sh   # create the sandbox (OpenClaw by default; NEMOCLAW_AGENT=hermes for Hermes)
bash scripts/install.sh   # install the skill, data and tools, and build the Python environments
bash scripts/start.sh     # ensure the sandbox is running
```

Ask a question:

```bash
nemoclaw market-analysis agent --agent main -m \
  "Using the market-analysis skill: who were the leaders and laggards among the 12 most liquid issuers over the 20 sessions ending 2026-08-31, and how did news sentiment line up with the following five sessions?"
```

### The six questions

The skill answers any of these on their own, or all six as a review. The wording is the AKF example's.

| # | Question | Component |
| --- | --- | --- |
| 1 | What do we have? Tables, reconciliation, issuers and median 20-session return per sector | Auto Ontology (optional) |
| 2 | Who led and lagged, and how did news line up with what followed? | pandas, on cuDF on a GPU |
| 3 | Which sessions were unusual? | scikit-learn or pandas, on cuML on a GPU |
| 4 | Who moves together? | NetworkX PageRank, on nx-cugraph on a GPU |
| 5 | What does a model expect for the next five sessions? | Kumo |
| 6 | What does Form 8-K Item 1.05 require, and what should we take forward? | Nemotron embed and rerank |

## Commands

| Script | Purpose |
| --- | --- |
| `scripts/onboard.sh` | Create the sandbox with the OpenClaw harness, or Hermes with `NEMOCLAW_AGENT=hermes` (CPU-only; `NEMOCLAW_SANDBOX_GPU=1` enables direct GPU access). |
| `scripts/install.sh` | Install the skill. With the `build` provider it also imports the provider profile, creates and attaches a second provider from your key, applies the egress policy, builds the analysis Python environment in `/sandbox/analysis-venv` (pandas, scikit-learn, NetworkX, the Kumo client; using a temporary `pypi` egress preset, removed again unless it was already applied), and restarts the sandbox (workspace kept) so the agent sees the new credential. With `NEMOCLAW_SANDBOX_GPU=1` it also builds `/sandbox/rapids-venv` after checking `nvidia-smi` works in the sandbox. If `AUTO_ONTOLOGY_API_TOKEN` is set in `.env` it also renders `providers/auto-ontology.yaml` for `AUTO_ONTOLOGY_PORT` (default 4000), creates and attaches a provider from the token, and writes the deployment URL for the skill. |
| `scripts/start.sh` | Recover the gateway and host forwards. |
| `scripts/stop.sh` | Stop the gateway while keeping the sandbox and workspace. |
| `scripts/build_database.py` | Build the SQLite database from the bundled CSVs for an Auto Ontology deployment to ingest (host side, optional). |

To delete the sandbox permanently, run `nemoclaw market-analysis destroy` and confirm. An environment variable you
set when running a script beats the same name in `.env`.

## What the skill ships

- `skills/market-analysis/SKILL.md`: the rules and the order of work.
- `skills/market-analysis/scenario.json`: the approved inputs and the definitions the agent must use (return,
  volatility, news alignment, peers, anomaly, prediction, centrality).
- `skills/market-analysis/data/`: five CSV tables and three SEC rule texts. Synthetic issuers, prices and news;
  real, public-domain rule text. The rules apply to real SEC registrants, never to the fictional issuers.
- `skills/market-analysis/utilities/accelerate.py`: runs the agent's scripts on the matching Python environment and
  records the engine. `kumo_predict.py`, `retrieve.py` and `ontology_qa.py` are the three service tools.

## CUDA-X on a GPU sandbox (optional)

The default sandbox is CPU-only. For the GPU path create a second sandbox with direct GPU access, then install into it:

```bash
export NEMOCLAW_SANDBOX_NAME=ma-gpu NEMOCLAW_SANDBOX_GPU=1
bash scripts/onboard.sh && bash scripts/install.sh
```

This needs a host NVIDIA GPU, a driver that supports CUDA 13 (the wheels in `requirements-gpu.txt` are `-cu13`; swap in
the `-cu12` names for a CUDA 12 driver) and a working CDI setup (`nvidia-ctk cdi generate`). `install.sh` builds
`/sandbox/rapids-venv` (cuDF, cuML, nx-cugraph; a few GB from PyPI). Then `accelerate.py run` puts cuDF, cuML and
nx-cugraph under the agent's pandas, scikit-learn and NetworkX with no change to the script, and `accelerate.py status`
reports whether the stack works. Without a GPU or that environment, analyses run on the CPU and the engine receipt says
so. Direct device access widens what the sandbox can touch, so enable it only where you want it.

**About speed.** This is a sample dataset (36 issuers, about 6,000 price rows), so the GPU path is expected to be
slower than the CPU one: the work is tiny and the fixed costs of starting the device and moving data dominate. This
recipe does not measure speed. The AKF examples repository, to be published soon, benchmarks the same kind of analyses
on scaled data outside a sandbox.

## Auto Ontology (optional)

Auto Ontology is a service you run on the host, not part of the sandbox. This recipe ships only the sandbox side: an
OpenShell provider profile (`providers/auto-ontology.yaml`) that binds an API token to `host.openshell.internal:<port>`
and sends it as `x-api-key`, and `ontology_qa.py`. The deployment must ingest the SQLite database from
`scripts/build_database.py` and have its semantic layer compiled. Set `AUTO_ONTOLOGY_API_TOKEN` and
`AUTO_ONTOLOGY_PORT` (the deployment's web port) in `.env`, then run `scripts/install.sh`. The profile allows three
paths and nothing else: `GET /api/semantic-compilation/status`, `POST /api/question-entity-coverage` and
`POST /api/chat/completions`.

Setting up the deployment, as tested with a local build of Auto Ontology (`22e22c89`) and its Docker Compose stack:
- Name the SQLite file `market.sqlite`: the database name comes from the file stem and must match `TARGET_DB` in
  `ontology_qa.py` (`market`).
- Semantic compilation is off by default; turn it on (`PUT /api/configurations/semantic-compilation` with
  `{"enabled": true}`) and wait for `/api/semantic-compilation/status` to show `calculated: true`.
- `AUTO_ONTOLOGY_PORT` is the deployment's **web** port (the one that serves `/api/*`), not its backend port.
- `APP_URL` in the deployment's configuration must equal the origin you sign in from, or sign-in returns HTTP 403.
- A call can take several minutes. The agent must wait for it rather than stop it.
- `scripts/install.sh` replaces the installed skill, so edits made inside the sandbox are lost on re-install.

**The deployment sends the database schema and each question to its own hosted model endpoints, using its own
configuration. That transfer is outside this sandbox's egress policy**, so review it separately.

**Check the SQL it returns.** Auto Ontology generates SQL, and an answer can be wrong in ways its text hides, such as
the wrong denominator or a missing as-of date. The skill requires the agent to read and quote the SQL and cross-check
a figure that matters. That is an instruction, not an enforced control.

**What was tested.** The wiring worked against a local deployment: the database ingested, the layer compiled in about
38 seconds, the provider and egress policy attached, the three allowed paths were reached from the sandbox, and a
count question ("how many issuers are in each sector as of 2026-08-31") returned correct SQL and rows in about 30
seconds. The **median-by-sector question was not answered**: the layer returned no SQL after about four minutes, twice.
The deployment log showed its generated SQL using three-part table names (`market.main.assets`), which SQLite
rejects, and the build only strips a `PUBLIC.` prefix. So this recipe does not show Auto Ontology answering the
median question; the agent computes it from the CSVs and says so. That failure is in the deployment build, not in
this recipe, and another build may behave differently. In one agent turn the agent also stopped the call early and
named the wrong cause, which is why the skill now tells it to wait and to quote the tool's own message.

## Security notes

- Without Auto Ontology, egress is limited to three POST paths for Python only; with it, add three paths on the host
  deployment. The hosted-model paths are `integrate.api.nvidia.com` `/v1/embeddings`, and on `ai.api.nvidia.com` the
  rerank path and `/v1/structured-data/nvidia/kumo-relational/predictions` (`policies/nvidia-hosted-models.yaml`), plus
  the agent's inference provider.
- **Any Python the agent runs can use these paths.** The allowed binaries are `python3*`, so the agent could send other
  text to embed, rerank or Kumo, not only what the tools send. The policy limits where and which paths, not what is
  sent. The Auto Ontology profile also allows `172.16.0.0/12` for the host route, wider than one address, narrowed by
  hostname binding.
- **What leaves the sandbox:** the rule text chunks and your question go to embed and rerank. **Kumo receives the
  graph tables**: the 12 most liquid issuers' identifiers, company name, sector, industry and exchange; their price
  rows (adjusted close, volume, returns) on or before 2026-08-24; and their news rows (event type, sentiment label).
  Do not point this at real data without a review of that transfer.
- `install.sh` adds the `pypi` egress preset only while it builds the Python environments and removes it afterwards,
  unless it was already applied.
- The raw API key stays in the OpenShell gateway. The sandbox holds `openshell:resolve:env:` placeholders, and
  OpenShell substitutes the key at egress, only on the host each credential is bound to. The embed credential is
  bound to `integrate.api.nvidia.com`; a second provider created by `install.sh` (`providers/nvidia-ai-api.yaml`)
  binds the same key to `ai.api.nvidia.com`. Without it, rerank fails with `credential_endpoint_mismatch`.
- The agent works on synthetic data only. Do not load real prices, news or holdings into this example.
- Outputs are proposals for human review. The skill instructs the agent not to give investment advice, place trades
  or say any issuer filed anything; that is a prompt-level rule, not an enforced control.
- To remove the GPU sandbox: `nemoclaw ma-gpu destroy`; the providers `install.sh` created for it are named
  `ma-gpu-ai-api` (and `ma-gpu-ontology`), removed as below with that name.
- To remove Auto Ontology: `openshell sandbox provider detach market-analysis market-analysis-ontology`,
  `openshell provider delete market-analysis-ontology` and
  `openshell provider profile delete market-analysis-auto-ontology`.
- To remove the hosted-model setup: `openshell sandbox provider detach market-analysis market-analysis-ai-api`,
  `openshell provider delete market-analysis-ai-api`, `nemoclaw market-analysis policy-remove nvidia-hosted-models`
  and `openshell provider profile delete market-analysis-nvidia-ai-api`.

## Verification

**Evidence level:** integration.

Offline checks, without a sandbox or any service call, from `examples/recipes/nvidia/market-analysis`:

```bash
bash scripts/tests/test_lifecycle_commands.sh
python3 scripts/tests/test_ontology_qa.py
bash -n scripts/*.sh scripts/tests/*.sh
python3 scripts/build_database.py --out /tmp/market.sqlite
python3 skills/market-analysis/utilities/kumo_predict.py --frames-only   # needs the analysis environment; no network
```

**Expected result:** the two test scripts print `ok`; `bash -n` prints nothing when the scripts parse;
`build_database.py` prints the row counts (`assets: 36 rows`, `trading_sessions: 166`, `daily_prices: 5976`,
`company_news: 484`, `asset_relationships: 54`); and `--frames-only`, run with `ANALYSIS_VENV` pointing at a
Python 3.13 environment built from `utilities/requirements.txt`, prints
`{"asset_entities": 12, "price_events": 1932, "news_events": 295}`.

**Sandbox run.** On one host, `onboard.sh`, `install.sh` and `start.sh` were run for OpenClaw (sandbox
`market-analysis`) and for Hermes (`NEMOCLAW_AGENT=hermes`, sandbox `ma-hermes`), CPU-only, with no Auto Ontology.
Then the agent was asked questions 1, 2, 4, 5 and 6 in separate turns.

- Both installs completed: `/sandbox/analysis-venv` imports the Kumo client, pandas, scikit-learn and NetworkX; the
  second provider and the `nvidia-hosted-models` policy attached; the skill was installed and the agent found and
  loaded it; `work/` was writable.
- Kumo: the call went through the egress proxy (allowed, HTTP 200) on both harnesses and the agent reported the ranking
  with the anchor and horizon. The same ranking appeared in every turn on Hermes.
- Numbers checked on the host: on Hermes, the question 1 sector medians (to six decimals), the question 4 peer
  correlations and PageRank scores matched a host recomputation. `accelerate.py status` reported no usable GPU, as
  expected, and a script run through `accelerate.py run` printed a CPU engine receipt.
- Question 1 without Auto Ontology: Hermes reported it blocked and computed from the CSVs.
- Auto Ontology, on OpenClaw with a local deployment (see [Auto Ontology](#auto-ontology-optional)): the provider, the
  egress policy and the three allowed paths worked from the sandbox, and a sector-count question returned correct SQL
  and rows. The median-by-sector question returned no SQL, and in one agent turn the agent stopped the call early.

**This verifies:** that the host scripts run against a real gateway on both harnesses, that the Python environments
build in the sandbox, that the egress policy and credential placeholders let Kumo through, that the agent can load the
skill and write scripts in `work/`, and the offline checks above.

**This does not verify:**
- **Retrieval and rule citations.** The hosted embedding model returned HTTP 503 and then read timeouts, from the
  sandbox and from the host, so `retrieve.py` never succeeded and the rerank path was not exercised. Whether a policy
  sentence carries the right `cite` tag is untested.
- **Agent correctness.** The agents were observed to skip `accelerate.py`, to compute the 20-session return one
  session short, and, on OpenClaw, to write policy text while retrieval was blocked (see the next section). The skill
  was tightened for these afterwards; the tightened skill has not been run again.
- The GPU stage, Auto Ontology on Hermes or answering the median question, and more than one run per harness.

## Known limitations

- **First sandbox runs showed the agents deviating from the skill.** On both harnesses the agent ran its scripts
  without `accelerate.py` (so no engine receipt), and computed the 20-session return from the 20th-last close instead of
  the 21st-last, which shifts returns and sector medians. On OpenClaw the agent wrote the Form 8-K Item 1.05 text with a
  `[document, chunk N]` tag while retrieval was blocked, answered question 1 without running `ontology_qa.py`, and
  computed forward returns and news alignment differently from `scenario.json`. On Hermes the agent ran Kumo and
  retrieval during a question that did not need them. The skill now states each of these rules explicitly, but a prompt
  rule is not enforced, and the changed text has not been re-run. Check receipts and cite tags in the answers.
- **Hermes and OpenClaw share one host lock.** Two `nemoclaw` commands at once can wait on
  `~/.nemoclaw-portable-host.lock`, so run one harness's setup at a time.
- **Hermes harness (optional).** Set `NEMOCLAW_AGENT=hermes` for `onboard.sh` and `install.sh`; the skill goes to
  `/sandbox/.hermes/skills/market-analysis`. One turn: `nemoclaw <sandbox> exec -- hermes -z '<question>' --skills market-analysis`.
  The Hermes agent needed its working directory set to the skill directory for the tool paths to resolve.
- The CPU analysis environment pins pandas 2.3 and Python 3.13 wheels; the RAPIDS environment lets cuDF choose pandas,
  and its versions float (the requirements file pins only the 26.10 series). Wheels are `-cu13`.
- The Kumo hosted model and the `kumo-relational-client` can change what they accept; the adapter drops
  `inference.inference_config`, which the hosted model rejects, and the graph keeps free-text columns out. Either
  change, or the hosted model itself, could affect results.
- NemoClaw limits sandbox names to 19 characters.
- The data is synthetic and small; results show the method works, not that it would perform on real markets.

## Third-party services and dependencies

Uses the installed NemoClaw and OpenClaw (or Hermes) components and NVIDIA Endpoints for inference. `retrieve.py` and
`ontology_qa.py` use only the Python standard library. The analysis environment needs `pandas`, `numpy`, `networkx`,
`scikit-learn` and `kumo-relational-client[relational]==1.0.2` (`skills/market-analysis/utilities/requirements.txt`),
installed from PyPI into `/sandbox/analysis-venv`. The optional GPU path needs `cudf-cu13`, `cuml-cu13` and
`nx-cugraph-cu13` (RAPIDS 26.10) (`utilities/requirements-gpu.txt`), installed into `/sandbox/rapids-venv`; RAPIDS is
Apache-2.0 and the CUDA libraries it pulls in carry NVIDIA's own license terms. Nothing is vendored, and transitive
dependencies are not pinned. Each package and the hosted services are subject to their own terms and availability.
The SEC rule text under `skills/market-analysis/data/documents/` is public-domain U.S. regulation text. Nothing in
this recipe is investment advice.
