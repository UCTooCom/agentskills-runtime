# -*- coding: utf-8 -*-
"""深挖已抓取的官方试题页与评析文：抽取题干/图片直链/评析描述"""
import os, re, json, io

BASE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(BASE, "raw")


def to_plain(text):
    p = re.sub(r"<script[^>]*>.*?</script>", " ", text, flags=re.S | re.I)
    p = re.sub(r"<style[^>]*>.*?</style>", " ", p, flags=re.S | re.I)
    p = re.sub(r"<[^>]+>", "\n", p)
    p = p.replace("&nbsp;", " ").replace("&amp;", "&")
    p = re.sub(r"[ \t\r\f\v]+", " ", p)
    p = re.sub(r"\n{2,}", "\n", p)
    return p


def rd(name):
    p = os.path.join(RAW, name)
    if not os.path.exists(p):
        return ""
    with io.open(p, "r", encoding="utf-8", errors="replace") as f:
        return f.read()


print("=" * 70)
print("[A] 评析文 qg_pingxi.txt 全文")
print("=" * 70)
px = rd("qg_pingxi.txt")
print(px[:12000])

print("=" * 70)
print("[B] qg1_st.html 图片直链")
print("=" * 70)
h1 = rd("qg1_st.html")
imgs = re.findall(r'''(?:src|data-src|href)\s*=\s*["']([^"']+\.(?:jpg|jpeg|png|gif|webp)(?:\?[^"']*)?)["']''', h1, re.I)
seen = set()
for u in imgs:
    if u not in seen:
        seen.add(u)
        print(u)

print("=" * 70)
print("[C] qg1_st.html 纯文本（前 3500 字）")
print("=" * 70)
print(to_plain(h1)[:3500])

print("=" * 70)
print("[D] eol_2025st.txt 中 压轴/19题 上下文")
print("=" * 70)
st = rd("eol_2025st.txt")
for kw in ("压轴", "19题", "第19题", "新定义"):
    for m in re.finditer(re.escape(kw), st):
        i = m.start()
        print("---", kw, "---")
        print(st[max(0, i - 300): i + 400])
        break
