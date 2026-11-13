---
name: provider-billing-integrity
description: >-
  Help a program-integrity reviewer find providers whose billing looks anomalous, expand each to the
  providers linked through shared addresses, bank accounts or owners, and total the paid exposure of
  each linked group, using the synthetic provider-billing dataset bundled with this skill. Use for
  questions about upcoding, related-entity clusters, cluster exposure, and whether a similar-looking
  pair of providers deserves escalation. Any statement about what 42 CFR 455.23, 424.535, 411.353 or
  1001.951 requires must come from this skill's retrieval tool (utilities/retrieve.py), quoted with its
  document and chunk. Produces referral recommendations for human review, never fraud determinations
  or payment suspensions.
---

# Provider Billing Integrity

## What this is for

A reviewer must decide which of 80 synthetic providers to refer for investigation, which other
providers are tied to them, and how much was paid to each group. Everything here is computed from
the CSV files in `data/` with the tools in `utilities/`. The only network use is policy retrieval
(below), which calls hosted Nemotron models. Every provider, address, bank account and amount is
synthetic.

## Before you write any answer

Run these in order and use their output. If a step does not apply to the question, skip only that step.

1. `integrity_tool.py` for the payment and entity facts the question needs.
2. **If the answer says anything about what a regulation requires, you must first run**
   `python3 utilities/retrieve.py --query "<what you need to know>" --top 3` **at least once.** One call per
   regulation question, for example `--query "when must a State suspend payments and when may it decline"`
   and `--query "revocation for a pattern of claims that fail Medicare requirements"`. Write the policy
   section only from the passages it returns.
3. Every policy statement in the answer ends with the passage's `cite` value, copied exactly from the tool
   output, for example `[42-cfr-455-23-payment-suspension.md, chunk 0]`. Do not write section or
   paragraph numbers from memory, and do not cite a passage you did not retrieve. A policy statement
   without a `cite` tag is not allowed; delete it, or report the policy part as blocked.

## Rules

1. **As-of date 2026-06-30.** Pass `--as-of 2026-06-30`. Nothing later may enter any number.
2. **Run the tool; do not estimate.** Every figure in an answer comes from a command you ran or a
   file you read. Quote the command.
3. **A link is a lead, not guilt.** Shared infrastructure alone proves nothing. Check each linked
   provider's billing behaviour (code mix, volume against specialty peers) before recommending
   escalation. Some look-alike groups are legitimate.
4. **Recommend, never determine.** Recommend referral or further review. Do not assert fraud, name
   a person as guilty, or order a payment suspension.
5. **If a step cannot run, say so.** Report it as blocked with the reason. Do not substitute memory
   or a guess.
6. **Policy claims need retrieved passages.** For any statement about what a regulation requires, run
   `retrieve.py` and cite the document and chunk it returns. Do not answer policy questions from
   memory, and do not paraphrase a rule that was not retrieved.
7. **A blocked retrieval stays blocked.** If `retrieve.py` exits with `blocked`, report the policy
   answer as blocked with that message. Do not substitute memory, and do not open the files in
   `data/documents/` to answer instead: an answer without a retrieval receipt is not a retrieved
   answer. `--method bm25` is a labeled
   offline comparison, not a fallback: use it only when asked, and say it is BM25.
8. **Out of scope in this version:** Kumo risk ranking, GPU acceleration, and Auto Ontology. Say
   these are not available if asked.

## Tools

Run from this skill's directory. Output is JSON on stdout.

```bash
python3 utilities/integrity_tool.py scan --as-of 2026-06-30 --top 10
python3 utilities/integrity_tool.py related <PROVIDER_ID> --as-of 2026-06-30
python3 utilities/integrity_tool.py cluster-exposure <PROVIDER_ID> --as-of 2026-06-30
```

```bash
python3 utilities/retrieve.py --query "<policy question>" --top 3
```

- `retrieve.py` finds citation-ready passages in the four public 42 CFR sections in
  `data/documents/` (455.23 payment suspension, 424.535 revocation, 411.353 referral prohibition,
  1001.951 fraud and kickbacks). It embeds the chunks and the query with Nemotron embed, then
  reorders the closest chunks with Nemotron rerank. The JSON lists each passage's document, chunk,
  scores and text. The first run builds an embedding cache and takes several seconds; later runs
  are faster.
- `scan` ranks providers by a transparent rule score: the share of office visits (99213, 99214,
  99215) billed at the top level, 99215, and claim volume against the specialty peer median.
- `related` expands a provider through shared address, bank account or owner, with the reason for
  each link and the transitive closure.
- `cluster-exposure` returns paid dollars and claim counts for the related cluster, per provider
  and in total.

Data files are in `data/`: `providers.csv`, `claims.csv`, `addresses.csv`, `bank_accounts.csv`,
`beneficiaries.csv`, `audit_findings.csv`. For any question the three commands do not cover, write a short
Python script with the standard library (`csv`, `statistics`, `collections`; pandas is not installed) and show the code you ran.

## How to answer

Work in this order unless the question dictates otherwise:

1. **Who looks risky?** Run `scan`. Note the score is a baseline, not a finding.
2. **Who is connected?** Run `related` for each high-scoring provider. Explain chains, where two
   providers share no entity directly but sit in one cluster through a third.
3. **How much is at stake?** Run `cluster-exposure`.
4. **Is each link meaningful?** Compare the billing behaviour of cluster members and of any
   look-alike groups. Say why each group is or is not worth escalating.
5. **Find the policy basis.** Run `retrieve.py` for what the regulations say about suspending
   payments, revocation or referral, and quote the passage you rely on with its document and chunk.
6. **Write the recommendation.** Combine payment evidence, related entities, the retrieved policy
   basis and what remains uncertain, ending with a recommended next step for a human reviewer.

Cite the command or file behind every number. Keep observed facts, associations and judgments
separate.
