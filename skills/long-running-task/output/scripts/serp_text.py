# -*- coding: utf-8 -*-
import sys, os, re, html
sys.stdout.reconfigure(encoding='utf-8')

OUT = r"D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime/skills/long-running-task/output/rounds/a298ea47-8af2-4432-8180-21f62c2b8b72"
KEYS = ["\u9664\u5c18", "\u8f90\u5411", "\u7b2c20\u9898", "\u7b2c 20 \u9898", "\u5317\u4eac\u5377", "\u9759\u7535", "13.6", "a0", "a\u2080", "2k\u03bb"]

def strip(t):
    t = re.sub(r'<script[\s\S]*?</script>', ' ', t, flags=re.I)
    t = re.sub(r'<style[\s\S]*?</style>', ' ', t, flags=re.I)
    t = re.sub(r'<[^>]+>', ' ', t)
    t = html.unescape(t)
    t = re.sub(r'\s+', ' ', t)
    return t

for fn in sorted(os.listdir(OUT)):
    if not fn.startswith("raw_probe_") or not fn.endswith(".html"):
        continue
    p = os.path.join(OUT, fn)
    txt = strip(open(p, 'r', encoding='utf-8', errors='replace').read())
    print("\n\n############### " + fn + f"  text={len(txt)}")
    any_hit = False
    for k in KEYS:
        c = txt.count(k)
        if c:
            any_hit = True
            idx = txt.find(k)
            print(f"  [{k}] x{c} @{idx}: ...{txt[max(0,idx-150):idx+250]}...")
    if not any_hit:
        print("  [no keyword] sample head: " + txt[:400])
