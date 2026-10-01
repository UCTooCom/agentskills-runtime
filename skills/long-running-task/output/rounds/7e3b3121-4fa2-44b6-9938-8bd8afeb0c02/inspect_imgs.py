# -*- coding: utf-8 -*-
import os, sys, io, json, re
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

OUT = r"D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\skills\long-running-task\output\rounds\7e3b3121-4fa2-44b6-9938-8bd8afeb0c02"
SAVE = os.path.join(OUT, "fetch")
J = json.load(open(os.path.join(SAVE, "_papers.json"), encoding='utf-8'))
for r in J:
    print("=" * 70)
    print(r.get('text'), "file=", r.get('file'), "n_imgs=", r.get('n_imgs'))
    for u in r.get('imgs', []):
        print("   ", u)

p = os.path.join(SAVE, "yn2025_stem.txt")
if os.path.exists(p):
    t = open(p, encoding='utf-8', errors='replace').read()
    print("\n\n##### YN STEM TEXT (first 6000) #####")
    print(t[:6000])
