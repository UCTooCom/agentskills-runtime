# -*- coding: utf-8 -*-
import os, sys, io, json, re
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
from urllib.parse import urljoin

OUT = r"D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\skills\long-running-task\output\rounds\7e3b3121-4fa2-44b6-9938-8bd8afeb0c02"
SAVE = os.path.join(OUT, "fetch")

def links_from(path, base):
    if not os.path.exists(path):
        print("MISSING", path); return []
    t = open(path, 'r', encoding='utf-8', errors='replace').read()
    out = []
    for href, label in re.findall(r'href=["\']([^"\']+)["\'][^>]*>\s*([^<]{0,120})', t):
        lab = re.sub(r'\s+', ' ', label).strip()
        if not lab:
            continue
        blob = href + ' ' + lab
        if ('2025' in blob) and any(k in blob for k in ['物理', 'wl', '理综', '试题', '真题', '答案']):
            out.append((urljoin(base, href.strip()), lab))
    # dedupe
    seen = set(); res = []
    for u, l in out:
        if u in seen: continue
        seen.add(u); res.append((u, l))
    return res

for name, base in [("eol_wl_list", "http://gaokao.eol.cn/shiti/wl/"), ("eol_shiti_list", "http://gaokao.eol.cn/shiti/")]:
    p = os.path.join(SAVE, name + ".html")
    ls = links_from(p, base)
    print("="*70)
    print(name, "hits=", len(ls))
    for u, l in ls:
        print("  ", l[:80], "|", u)
    json.dump([{"url": u, "label": l} for u, l in ls], open(os.path.join(SAVE, name + "_links.json"), 'w', encoding='utf-8'), ensure_ascii=False, indent=2)

# also dump any <a> text mentioning 物理 in wl list for context
p = os.path.join(SAVE, "eol_wl_list.html")
t = open(p, 'r', encoding='utf-8', errors='replace').read()
idx = [m.start() for m in re.finditer('物理', t)][:10]
print("\n--- 物理 context samples in wl_list ---")
for i in idx:
    print(re.sub(r'\s+', ' ', t[max(0,i-160):i+160]))
    print('-'*40)
