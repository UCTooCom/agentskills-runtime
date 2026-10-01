# -*- coding: utf-8 -*-
import sys, os, re, json
sys.stdout.reconfigure(encoding='utf-8')

BASE = r"D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime/skills/long-running-task/output"
OUT = os.path.join(BASE, "rounds", "a298ea47-8af2-4432-8180-21f62c2b8b72")
os.makedirs(OUT, exist_ok=True)

TARGETS = [
    "rounds/6bb80c3a-6b59-4201-8cc1-676b836c6acd/raw/art_05.txt",
    "rounds/6bb80c3a-6b59-4201-8cc1-676b836c6acd/raw/art_07.txt",
    "rounds/6bb80c3a-6b59-4201-8cc1-676b836c6acd/raw/art_15.txt",
    "rounds/6bb80c3a-6b59-4201-8cc1-676b836c6acd/raw/art_18.txt",
    "rounds/6bb80c3a-6b59-4201-8cc1-676b836c6acd/raw/so360.html",
    "rounds/6bb80c3a-6b59-4201-8cc1-676b836c6acd/raw/toutiao.html",
    "rounds/6bb80c3a-6b59-4201-8cc1-676b836c6acd/harvest_result.json",
]
KEYS = ["\u9664\u5c18", "\u8f90\u5411", "\u7b2c20\u9898", "\u5317\u4eac\u5377", "\u9759\u7535", "\u7b2c 20 \u9898"]

def strip_html(t):
    t = re.sub(r'<script[\s\S]*?</script>', ' ', t, flags=re.I)
    t = re.sub(r'<style[\s\S]*?</style>', ' ', t, flags=re.I)
    t = re.sub(r'<[^>]+>', ' ', t)
    t = re.sub(r'&nbsp;', ' ', t)
    t = re.sub(r'&[a-z]+;', ' ', t)
    t = re.sub(r'\s+', ' ', t)
    return t

for rel in TARGETS:
    p = os.path.join(BASE, rel)
    print("\n\n############### " + rel)
    if not os.path.exists(p):
        print("[MISSING]")
        continue
    try:
        with open(p, 'r', encoding='utf-8', errors='replace') as fh:
            raw = fh.read()
    except Exception as e:
        print("ERR", e)
        continue
    txt = strip_html(raw) if rel.endswith('.html') else raw
    found = False
    for k in KEYS:
        idx = 0
        cnt = 0
        while True:
            idx = txt.find(k, idx)
            if idx < 0 or cnt >= 2:
                break
            found = True
            cnt += 1
            seg = txt[max(0, idx-600): idx+1200]
            print(f"\n---- key=[{k}] @{idx} ----")
            print(seg)
            idx += len(k)
    if not found:
        print("[no key hit in text]")
