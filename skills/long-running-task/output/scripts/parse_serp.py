# -*- coding: utf-8 -*-
import sys, os, re, json, html
sys.stdout.reconfigure(encoding='utf-8')

OUT = r"D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime/skills/long-running-task/output/rounds/a298ea47-8af2-4432-8180-21f62c2b8b72"

def clean(t):
    t = re.sub(r'<[^>]+>', ' ', t)
    t = html.unescape(t)
    t = re.sub(r'\s+', ' ', t)
    return t.strip()

for fn in sorted(os.listdir(OUT)):
    if not fn.startswith("raw_probe_") or not fn.endswith(".html"):
        continue
    p = os.path.join(OUT, fn)
    raw = open(p, 'r', encoding='utf-8', errors='replace').read()
    print("\n\n################### " + fn + f"  ({len(raw)} bytes)")
    # find anchors with snippet-ish text
    anchors = re.findall(r'<a[^>]+href="(http[^"]+)"[^>]*>([\s\S]{0,300}?)</a>', raw)
    seen = set()
    n = 0
    for href, txt in anchors:
        t = clean(txt)
        if len(t) < 8:
            continue
        # favor chinese educational keywords
        if not re.search(r'(\u7269\u7406|\u9ad8\u8003|\u771f\u9898|\u5317\u4eac|\u7b2c20|\u9664\u5c18|\u7535\u573a|\u89e3\u6790|\u8bd5\u5377|\u9898\u76ee)', t):
            continue
        key = t[:40]
        if key in seen:
            continue
        seen.add(key)
        n += 1
        if n > 25:
            break
        print(f"\n- {t[:180]}")
        print(f"  URL: {href[:160]}")
    print(f"\n[extracted {n} candidate results]")
