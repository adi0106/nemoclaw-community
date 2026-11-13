#!/usr/bin/env python3
# SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
"""CPU tools for provider-billing integrity: a rule baseline and related-entity expansion. pandas only.

  python3 utilities/integrity_tool.py scan [--as-of 2026-06-30] [--top 10]
  python3 utilities/integrity_tool.py related P001 [--as-of 2026-06-30]
  python3 utilities/integrity_tool.py cluster-exposure P001 [--as-of 2026-06-30]

scan      ranks providers by a transparent rule score: share of office visits billed at the top level (99215) and
          claim volume against the specialty peer median. It is the baseline the Kumo ranking is compared with.
related   expands one provider to everyone linked through a shared address, bank account or owner, with the reason for
          each link and the transitive closure (a link chain counts, not only direct neighbours).
cluster-exposure  paid dollars and claim counts for the related cluster, per provider and in total.
Everything is computed from data/*.csv restricted to dates on or before --as-of; the output is JSON on stdout.
"""
import argparse
import json
import sys
from pathlib import Path

import pandas as pd

DATA = Path(__file__).resolve().parent.parent / 'data'
LINKS = ['address_id', 'bank_account_id', 'owner_id']
VISITS = ['99213', '99214', '99215']


def load(as_of):
    providers = pd.read_csv(DATA / 'providers.csv')
    claims = pd.read_csv(DATA / 'claims.csv', dtype={'procedure_code': str})
    return providers, claims[claims['claim_date'] <= as_of]


def scan(as_of, top):
    providers, claims = load(as_of)
    visits = claims[claims['procedure_code'].isin(VISITS)]
    share = (visits.assign(top=visits['procedure_code'] == '99215').groupby('provider_id')['top'].mean().rename('top_level_share'))
    volume = claims.groupby('provider_id').size().rename('claims')
    frame = providers.set_index('provider_id')[['specialty']].join(share).join(volume).fillna({'top_level_share': 0, 'claims': 0})
    frame['peer_volume_ratio'] = frame['claims'] / frame.groupby('specialty')['claims'].transform('median')
    frame['score'] = (frame['top_level_share'] * 0.7 + (frame['peer_volume_ratio'].clip(upper=5) / 5) * 0.3).round(4)
    rows = frame.reset_index().sort_values(['score', 'provider_id'], ascending=[False, True]).head(top)
    return [{'provider_id': r.provider_id, 'specialty': r.specialty, 'claims': int(r.claims),
             'top_level_share': round(r.top_level_share, 3), 'peer_volume_ratio': round(r.peer_volume_ratio, 2), 'score': r.score}
            for r in rows.itertuples()]


def components(providers):
    parent = {p: p for p in providers['provider_id']}

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    reasons = {}
    for column in LINKS:
        for value, group in providers.groupby(column):
            ids = sorted(group['provider_id'])
            for other in ids[1:]:
                parent[find(other)] = find(ids[0])
            if len(ids) > 1:
                reasons[(column, value)] = ids
    groups = {}
    for p in parent:
        groups.setdefault(find(p), []).append(p)
    return groups, reasons


def related(provider, as_of):
    providers, _ = load(as_of)
    providers = providers[providers['enrolled_date'] <= as_of]
    groups, reasons = components(providers)
    cluster = next((sorted(g) for g in groups.values() if provider in g), None)
    if cluster is None:
        raise SystemExit(f'unknown provider {provider}')
    links = [{'shared': column, 'value': value, 'providers': ids} for (column, value), ids in sorted(reasons.items())
             if set(ids) <= set(cluster)]
    return {'provider': provider, 'cluster': cluster, 'size': len(cluster), 'links': links}


def exposure(provider, as_of):
    cluster = related(provider, as_of)['cluster']
    _, claims = load(as_of)
    sub = claims[claims['provider_id'].isin(cluster)]
    per = sub.groupby('provider_id')['paid_usd'].agg(['count', 'sum']).round(2)
    return {'cluster': cluster, 'total_claims': int(per['count'].sum()), 'total_paid_usd': round(float(per['sum'].sum()), 2),
            'per_provider': {p: {'claims': int(r['count']), 'paid_usd': float(r['sum'])} for p, r in per.iterrows()}}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('command', choices=['scan', 'related', 'cluster-exposure'])
    ap.add_argument('provider', nargs='?')
    ap.add_argument('--as-of', default='2026-06-30')
    ap.add_argument('--top', type=int, default=10)
    a = ap.parse_args()
    if a.command == 'scan':
        out = scan(a.as_of, a.top)
    elif not a.provider:
        ap.error(f'{a.command} needs a provider id')
    else:
        out = (related if a.command == 'related' else exposure)(a.provider, a.as_of)
    json.dump(out, sys.stdout, indent=2)
    print()


if __name__ == '__main__':
    main()
