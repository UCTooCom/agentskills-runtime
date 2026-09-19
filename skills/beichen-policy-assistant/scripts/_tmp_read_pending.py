# -*- coding: utf-8 -*-
import json, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

pending = r"D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\skills\beichen-policy-assistant\output\pending\2026-09-11.json"
idxp = r"D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\skills\beichen-policy-assistant\knowledge\policy-index.json"

with open(pending, 'r', encoding='utf-8') as f:
    p = json.load(f)
print("=== PENDING 2026-09-11 ===")
print("count:", p.get('count'), "fetched_at:", p.get('fetched_at'))
for i, it in enumerate(p.get('items', []), 1):
    print(f"[{i}] status={it.get('status')} | url={it.get('url')}")
    print(f"    title={it.get('title')}")
    print(f"    dept={it.get('department')} | level={it.get('level')} | domain={it.get('domain')} | date={it.get('published_date')}")
    if it.get('error'):
        print(f"    ERROR={it.get('error')}")

with open(idxp, 'r', encoding='utf-8') as f:
    idx = json.load(f)
print("\n=== POLICY INDEX ===")
print("count:", idx.get('count'), "generated_at:", idx.get('generated_at'))
from collections import Counter, defaultdict
dom = Counter(); lvl = Counter()
dg = defaultdict(list)
for pol in idx.get('policies', []):
    dom[pol.get('domain')] += 1
    lvl[pol.get('level')] += 1
    dg[pol.get('domain')].append(pol)
print("--- by domain ---")
for d, c in dom.items():
    print(f"{d}: {c}")
print("--- by level ---")
for l, c in lvl.items():
    print(f"{l}: {c}")
print("--- titles by domain ---")
for d, lst in dg.items():
    print(f"\n[{d}]")
    for pol in lst:
        print(f"  {pol.get('policy_no')}. {pol.get('title')} ({pol.get('level')} / {pol.get('department')})")
print("\nDONE")
