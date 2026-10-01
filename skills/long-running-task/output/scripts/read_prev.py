# -*- coding: utf-8 -*-
import os, sys, json, io
sys.stdout.reconfigure(encoding='utf-8')

BASE = r"D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime/skills/long-running-task/output"
PREV = os.path.join(BASE, "rounds", "530be488-1fec-44fe-9d9e-aa687389e932")

print("=== LIST PREV DIR ===")
for root, dirs, files in os.walk(PREV):
    for f in files:
        p = os.path.join(root, f)
        print(f"{os.path.getsize(p):>9}  {p}")

for name in ["findings.md", "\u72ec\u7acb\u89e3\u7b54\u5168\u6587.md", "round-1.md"]:
    p = os.path.join(PREV, name)
    print("\n\n========== " + name + " ==========")
    if os.path.exists(p):
        with open(p, 'r', encoding='utf-8', errors='replace') as fh:
            print(fh.read())
    else:
        print("[MISSING]")
