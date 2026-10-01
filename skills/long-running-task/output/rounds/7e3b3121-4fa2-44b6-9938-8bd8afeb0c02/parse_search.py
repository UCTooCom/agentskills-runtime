# -*- coding: utf-8 -*-
import os, sys, io, json, re
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
from urllib.parse import urljoin

OUT = r"D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\skills\long-running-task\output\rounds\7e3b3121-4fa2-44b6-9938-8bd8afeb0c02"
S = os.path.join(OUT, "search")

for name in ["sogou_0", "sogou_1", "bing_0"]:
    p = os.path.join(S, name + ".html")
    if not os.path.exists(p):
        continue
    t = open(p, 'r', encoding='utf-8', errors='replace').read()
    print("=" * 70)
    print("FILE", name, "len", len(t))
    # sogou result links
    hits = []
    for href, label in re.findall(r'<a[^>]+href=["\']([^"\']+)["\'][^>]*>(.*?)</a>', t, re.S | re.I):
        lab = re.sub(r'<[^>]+>', ' ', label)
        lab = re.sub(r'\s+', ' ', lab).strip()
        if len(lab) > 6 and any(k in lab for k in ['物理', '压轴', '高考', '试题', '答案', '最后一题', '解析']):
            hits.append((href, lab[:120]))
    seen = set()
    for u, l in hits:
        if u in seen: continue
        seen.add(u)
        print("  L:", l)
        print("     U:", u[:200])
    tp = os.path.join(S, name + ".txt")
    if os.path.exists(tp):
        txt = open(tp, encoding='utf-8', errors='replace').read()
        print("---- TEXT (first 3000) ----")
        print(txt[:3000])
