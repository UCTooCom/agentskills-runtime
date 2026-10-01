# -*- coding: utf-8 -*-
import sys, os, re
sys.stdout.reconfigure(encoding='utf-8')

BASE = r"D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime/skills/long-running-task/output"

p1 = os.path.join(BASE, "rounds/6bb80c3a-6b59-4201-8cc1-676b836c6acd/raw/art_15.txt")
print("=========== art_15.txt (FULL) ===========")
with open(p1, 'r', encoding='utf-8', errors='replace') as f:
    print(f.read())

p2 = os.path.join(BASE, "rounds/530be488-1fec-44fe-9d9e-aa687389e932/2025\u5317\u4eac\u5377\u7269\u7406\u7b2c20\u9898_\u72ec\u7acb\u89e3\u7b54.html")
print("\n\n=========== PREV HTML (FULL TEXT) ===========")
raw = open(p2, 'r', encoding='utf-8', errors='replace').read()
txt = re.sub(r'<script[\s\S]*?</script>', ' ', raw, flags=re.I)
txt = re.sub(r'<style[\s\S]*?</style>', ' ', txt, flags=re.I)
txt = re.sub(r'<[^>]+>', '\n', txt)
txt = re.sub(r'\n{2,}', '\n', txt)
print(txt)
