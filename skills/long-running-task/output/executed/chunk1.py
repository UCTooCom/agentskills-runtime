# -*- coding: utf-8 -*-
import os, re, io

BASE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(BASE, "raw")
OUT = os.path.join(BASE, "t1")
os.makedirs(OUT, exist_ok=True)


def rd(name):
    p = os.path.join(RAW, name)
    if not os.path.exists(p):
        return ""
    for enc in ("utf-8", "gbk", "gb18030"):
        try:
            with io.open(p, "r", encoding=enc, errors="strict") as f:
                return f.read()
        except Exception:
            continue
    with io.open(p, "r", encoding="utf-8", errors="replace") as f:
        return f.read()


def to_plain(t):
    p = re.sub(r"<script[^>]*>.*?</script>", " ", t, flags=re.S | re.I)
    p = re.sub(r"<style[^>]*>.*?</style>", " ", p, flags=re.S | re.I)
    p = re.sub(r"<[^>]+>", "\n", p)
    p = p.replace("&nbsp;", " ").replace("&amp;", "&")
    p = re.sub(r"[ \t\r\f\v]+", " ", p)
    p = re.sub(r"\n{2,}", "\n", p)
    return p


plain_map = {}
for name in ("qg_pingxi.html", "qg1_st.html", "qg2_st.html", "eol_2025st.txt"):
    t = rd(name)
    if not t:
        continue
    p = to_plain(t) if name.endswith(".html") else t
    plain_map[name] = p
    with io.open(os.path.join(OUT, name.replace(".", "_") + ".plain.txt"), "w", encoding="utf-8") as f:
        f.write(p)

KWS = ["19", "\u538b\u8f74", "\u65b0\u5b9a\u4e49", "\u5bfc\u6570", "\u89e3\u6790\u51e0\u4f55",
       "\u692d\u5706", "\u629b\u7269\u7ebf", "\u6570\u5217", "f(x)", "\u6700\u5c0f\u503c",
       "\u6700\u5927\u503c", "\u8bc1\u660e", "\u6c42"]
lines = []
for name, p in plain_map.items():
    segs = [s.strip() for s in p.split("\n") if len(s.strip()) >= 10]
    for i, s in enumerate(segs):
        if any(k in s for k in KWS):
            lines.append("[%s#%d] %s" % (name, i, s))

with io.open(os.path.join(OUT, "segments.txt"), "w", encoding="utf-8") as f:
    f.write("\n".join(lines))

for name, p in plain_map.items():
    base = name.replace(".", "_")
    for i in range(0, len(p), 1000):
        with io.open(os.path.join(OUT, "%s.part%02d.txt" % (base, i // 1000)), "w", encoding="utf-8") as f:
            f.write(p[i:i + 1000])

print("OK")
for name, p in plain_map.items():
    print(name, "plain_len=", len(p))
print("segments=", len(lines))
