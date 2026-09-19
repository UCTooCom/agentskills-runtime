# -*- coding: utf-8 -*-
import os, io, json
BASE = os.path.dirname(os.path.abspath(__file__))
T1 = os.path.join(BASE, "t1")
with io.open(os.path.join(T1, "segments.txt"), "r", encoding="utf-8", errors="replace") as f:
    lines = [l.rstrip("\n") for l in f if l.strip()]
print("TOTAL=%d" % len(lines))
for i, l in enumerate(lines):
    s = l if len(l) <= 600 else l[:600] + "<TRUNC>"
    print("SEG%02d|%s" % (i, json.dumps(s, ensure_ascii=True)))
