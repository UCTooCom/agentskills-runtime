# -*- coding: utf-8 -*-
import sys, os, re, json
sys.stdout.reconfigure(encoding='utf-8')

BASE = r"D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime/skills/long-running-task/output"
OUT = os.path.join(BASE, "rounds", "a298ea47-8af2-4432-8180-21f62c2b8b72")
os.makedirs(OUT, exist_ok=True)

KEYS = ["\u9664\u5c18", "\u8f90\u5411", "\u7b2c20\u9898", "\u5317\u4eac\u5377", "\u9759\u7535", "\u539f\u9898"]
EXTS = (".txt", ".html", ".md", ".json", ".text")

hits = {}
scanned = 0
for root, dirs, files in os.walk(BASE):
    # skip huge binary dirs
    for f in files:
        if not f.lower().endswith(EXTS):
            continue
        p = os.path.join(root, f)
        try:
            if os.path.getsize(p) > 5_000_000:
                continue
            with open(p, 'r', encoding='utf-8', errors='replace') as fh:
                txt = fh.read()
        except Exception:
            continue
        scanned += 1
        for k in KEYS:
            if k in txt:
                hits.setdefault(p, []).append(k)

print("scanned files:", scanned)
print("files with hits:", len(hits))
res = []
for p, ks in sorted(hits.items(), key=lambda x: -len(x[1])):
    res.append({"path": p, "size": os.path.getsize(p), "keys": ks})
    print(f"{len(ks):>2} {os.path.getsize(p):>8} {ks} {p}")

with open(os.path.join(OUT, "corpus_scan.json"), 'w', encoding='utf-8') as fh:
    json.dump(res, fh, ensure_ascii=False, indent=1)

# dump snippets around 除尘 from top files
print("\n\n===== SNIPPETS =====")
dumped = 0
for p, ks in sorted(hits.items(), key=lambda x: -len(x[1])):
    if dumped >= 6:
        break
    try:
        with open(p, 'r', encoding='utf-8', errors='replace') as fh:
            txt = fh.read()
    except Exception:
        continue
    idx = txt.find("\u9664\u5c18")
    if idx < 0:
        idx = txt.find("\u8f90\u5411")
    if idx < 0:
        continue
    dumped += 1
    print("\n##### " + p)
    print(txt[max(0, idx-800): idx+1600])
