---
name: provider-billing-integrity
description: >-
  Help a program-integrity reviewer find providers whose billing looks anomalous, expand each to the
  providers linked through shared addresses, bank accounts or owners, and total the paid exposure of
  each linked group, using the synthetic provider-billing dataset bundled with this skill. Use for
  questions about upcoding, related-entity clusters, cluster exposure, and whether a similar-looking
  pair of providers deserves escalation. Produces referral recommendations for human review, never
  fraud determinations or payment suspensions.
---

# Provider Billing Integrity

## What this is for

A reviewer must decide which of 80 synthetic providers to refer for investigation, which other
providers are tied to them, and how much was paid to each group. Everything here is computed from
the CSV files in `data/` with the tools in `utilities/`. Nothing is fetched from the network, and
every provider, address, bank account and amount is synthetic.

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
6. **Out of scope in this version:** Kumo risk ranking, policy-text retrieval, GPU acceleration, and
   Auto Ontology. Say these are not available if asked.

## Tools

Run from this skill's directory. Output is JSON on stdout.

```bash
python3 utilities/integrity_tool.py scan --as-of 2026-06-30 --top 10
python3 utilities/integrity_tool.py related <PROVIDER_ID> --as-of 2026-06-30
python3 utilities/integrity_tool.py cluster-exposure <PROVIDER_ID> --as-of 2026-06-30
```

- `scan` ranks providers by a transparent rule score: the share of office visits (99213, 99214,
  99215) billed at the top level, 99215, and claim volume against the specialty peer median.
- `related` expands a provider through shared address, bank account or owner, with the reason for
  each link and the transitive closure.
- `cluster-exposure` returns paid dollars and claim counts for the related cluster, per provider
  and in total.

Data files are in `data/`: `providers.csv`, `claims.csv`, `addresses.csv`, `bank_accounts.csv`,
`beneficiaries.csv`, `audit_findings.csv`. Use pandas for any question the three commands do not
cover, and show the code you ran.

## How to answer

Work in this order unless the question dictates otherwise:

1. **Who looks risky?** Run `scan`. Note the score is a baseline, not a finding.
2. **Who is connected?** Run `related` for each high-scoring provider. Explain chains, where two
   providers share no entity directly but sit in one cluster through a third.
3. **How much is at stake?** Run `cluster-exposure`.
4. **Is each link meaningful?** Compare the billing behaviour of cluster members and of any
   look-alike groups. Say why each group is or is not worth escalating.
5. **Write the recommendation.** Combine payment evidence, related entities and what remains
   uncertain, ending with a recommended next step for a human reviewer.

Cite the command or file behind every number. Keep observed facts, associations and judgments
separate.
