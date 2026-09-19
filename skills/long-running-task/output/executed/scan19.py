# -*- coding: utf-8 -*-
import os, io, re, json
BASE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(BASE, "raw")
KWS = ["\u65b0\u5b9a\u4e49", "\u4e09\u89d2\u51fd\u6570", "\u4efb\u610f\u89d2", "sin", "cos", "f(x)",
       "\u7b2c19\u9898", "19.", "17\u5206", "\u5bf9\u79f0", "\u5468\u671f"]
files = [f for f in os.listdir(RAW) if f.endswith((".txt", ".html"))]
print("FILES=%d" % len(files))
for fn in sorted(files):
    p = os.path.join(RAW, fn)
    try:
        sz = os.path.getsize(p)
    except Exception:
        continue
    if sz < 3000:
        continue
    t = None
    for enc in ("utf-8", "gbk", "gb18030"):
        try:
            with io.open(p, "r", encoding=enc, errors="strict") as f:
                t = f.read()
            break
        except Exception:
            continue
    if t is None:
        continue
    hits = {}
    for k in KWS:
        c = t.count(k)
        if c:
            hits[k] = c
    if hits:
        print("HIT|%s|%d|%s" % (fn, sz, json.dumps(hits, ensure_ascii=True)))
print("DONE")
