# -*- coding: utf-8 -*-
"""第三轮：已有文件检索 + urllib 多源抓取 + 真题入口链接提取"""
import html
import json
import os
import re
import ssl
import time
import urllib.parse
import urllib.request

BASE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(BASE, "raw")
os.makedirs(RAW, exist_ok=True)

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")

KWS = ["压轴", "新课标", "19题", "导数", "椭圆", "数列", "解析几何", "新定义", "真题", "数学"]


def fetch(name, url, timeout=25):
    rec = {"name": name, "url": url, "ok": False}
    try:
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        req = urllib.request.Request(url, headers={
            "User-Agent": UA,
            "Accept-Language": "zh-CN,zh;q=0.9",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Encoding": "identity",
        })
        with urllib.request.urlopen(req, timeout=timeout, context=ctx) as resp:
            raw = resp.read()
            rec["status"] = resp.status
        text = None
        for enc in ("utf-8", "gb18030", "gbk"):
            try:
                text = raw.decode(enc)
                rec["encoding"] = enc
                break
            except UnicodeDecodeError:
                continue
        if text is None:
            text = raw.decode("utf-8", errors="replace")
            rec["encoding"] = "utf-8/replace"
        rec["ok"] = (rec["status"] == 200)
        rec["length"] = len(text)
        p = os.path.join(RAW, name + ".txt")
        with open(p, "w", encoding="utf-8") as f:
            f.write(text)
        rec["file"] = p
        rec["hits"] = {k: text.count(k) for k in KWS}
    except Exception as e:
        rec["error"] = "%s: %s" % (type(e).__name__, e)
    return rec


print("===== PART A: scan existing raw html =====")
if os.path.isdir(RAW):
    for fn in sorted(os.listdir(RAW)):
        if not fn.endswith(".html"):
            continue
        try:
            with open(os.path.join(RAW, fn), "r", encoding="utf-8", errors="replace") as f:
                doc = f.read()
        except Exception as e:
            print("  skip %s (%s)" % (fn, e))
            continue
        score = 0
        for k, w in (("压轴", 5), ("新课标", 3), ("真题", 3), ("19题", 2), ("数学", 1), ("导数", 2), ("数列", 1)):
            score += doc.count(k) * w
        print("  %-28s len=%-8d score=%d" % (fn, len(doc), score))

print("\n===== PART B: fetch new sources (urllib) =====")
queries = [
    "2025年高考数学新课标I卷压轴题",
    "2025高考数学新课标一卷第19题",
]
sources = []
for i, q in enumerate(queries, 1):
    sources.append(("b_rss_%d" % i,
                    "https://cn.bing.com/search?format=rss&q=" + urllib.parse.quote(q)))
sources.append(("baike_gk",
                "https://baike.baidu.com/item/" + urllib.parse.quote("2025年普通高等学校招生全国统一考试")))

res = []
for n, u in sources:
    res.append(fetch(n, u))
    time.sleep(0.5)
for r in res:
    print("  %-14s ok=%-5s st=%-5s len=%-7s enc=%-12s err=%s" % (
        r["name"], r.get("ok"), r.get("status", "-"), r.get("length", "-"),
        r.get("encoding", "-"), r.get("error", "")[:90]))

print("\n===== PART C: extract zhenti links from eol_gaokao =====")
eolp = os.path.join(RAW, "eol_gaokao.html")
if os.path.exists(eolp):
    with open(eolp, "r", encoding="utf-8", errors="replace") as f:
        doc = f.read()
    links = {}
    for m in re.finditer(r'<a[^>]+href="([^"]+)"[^>]*>(.{2,80}?)</a>', doc, re.S):
        href = html.unescape(m.group(1))
        txt = html.unescape(re.sub(r'<[^>]+>', '', m.group(2))).strip()
        if not txt:
            continue
        if any(k in txt for k in ("真题", "试题", "答案", "数学", "2025")):
            links[txt[:60]] = href[:160]
    print("  matched links:", len(links))
    for t, h in list(sorted(links.items()))[:45]:
        print("    %-42s -> %s" % (t, h))
