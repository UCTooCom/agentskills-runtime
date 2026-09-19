# -*- coding: utf-8 -*-
"""第四轮：解析 Bing RSS 条目 + 抓取 EOL 真题入口 + 提取 2025 数学真题链接"""
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
        rec["file"] = os.path.join(RAW, name + ".txt")
        with open(rec["file"], "w", encoding="utf-8") as f:
            f.write(text)
        rec["hits"] = {k: text.count(k) for k in ("2025", "数学", "真题", "压轴", "试题", "新课标")}
    except Exception as e:
        rec["error"] = "%s: %s" % (type(e).__name__, e)
    return rec


print("===== PART A: parse Bing RSS items =====")
rss_items = []
for rn in ("b_rss_1.txt", "b_rss_2.txt"):
    p = os.path.join(RAW, rn)
    if not os.path.exists(p):
        continue
    with open(p, "r", encoding="utf-8", errors="replace") as f:
        x = f.read()
    for m in re.finditer(r'<item>(.*?)</item>', x, re.S):
        blk = m.group(1)
        def g(tag):
            mm = re.search(r'<%s>(.*?)</%s>' % (tag, tag), blk, re.S)
            if not mm:
                return ""
            v = mm.group(1)
            v = re.sub(r'<!\[CDATA\[(.*?)\]\]>', r'\1', v, flags=re.S)
            return html.unescape(re.sub(r'<[^>]+>', '', v)).strip()
        it = {"src": rn, "title": g("title"), "link": g("link"), "desc": g("description")}
        if it["title"] or it["link"]:
            rss_items.append(it)

print("  rss items:", len(rss_items))
for i, it in enumerate(rss_items[:30]):
    print("  [%02d] %s" % (i, it["title"][:80]))
    print("       %s" % it["link"][:130])
    if it["desc"]:
        print("       desc: %s" % it["desc"][:150])
with open(os.path.join(RAW, "_rss_items.json"), "w", encoding="utf-8") as f:
    json.dump(rss_items, f, ensure_ascii=False, indent=2)

print("\n===== PART B: fetch EOL zhenti entry pages =====")
entries = [
    ("eol_gkst", "https://gaokao.eol.cn/e_html/gk/gkst/"),
    ("eol_sx", "http://gaokao.eol.cn/shiti/sx/"),
    ("eol_2025st", "https://gaokao.eol.cn/e_html/gk/gkst/2025st.shtml"),
]
res = []
for n, u in entries:
    res.append(fetch(n, u))
    time.sleep(0.5)
for r in res:
    print("  %-14s ok=%-5s st=%-5s len=%-8s enc=%-12s hits=%s err=%s" % (
        r["name"], r.get("ok"), r.get("status", "-"), r.get("length", "-"), r.get("encoding", "-"),
        json.dumps(r.get("hits", {}), ensure_ascii=False), r.get("error", "")[:80]))

print("\n===== PART C: extract candidate links (2025 + shuxue) =====")
cands = {}
for r in res:
    fp = r.get("file")
    if not fp or not os.path.exists(fp):
        continue
    with open(fp, "r", encoding="utf-8", errors="replace") as f:
        doc = f.read()
    for m in re.finditer(r'<a[^>]+href="([^"]+)"[^>]*>(.{2,90}?)</a>', doc, re.S):
        href = html.unescape(m.group(1))
        txt = html.unescape(re.sub(r'<[^>]+>', '', m.group(2))).strip()
        if not txt:
            continue
        if ("数学" in txt or "真题" in txt or "试题" in txt) and ("2025" in txt or "2025" in href or "真题" in txt):
            key = (r["name"], txt[:70])
            cands[key] = href[:200]
print("  candidates:", len(cands))
for (src, t), h in list(cands.items())[:50]:
    print("    [%s] %-46s -> %s" % (src, t, h))
with open(os.path.join(RAW, "_cand_links.json"), "w", encoding="utf-8") as f:
    json.dump([{"src": s, "text": t, "href": h} for (s, t), h in cands.items()], f, ensure_ascii=False, indent=2)
