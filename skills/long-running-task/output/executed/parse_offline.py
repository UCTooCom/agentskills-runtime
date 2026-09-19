# -*- coding: utf-8 -*-
"""纯离线解析：Bing RSS 条目 + bing_s.html 结果块（无网络请求，避免超时）"""
import html
import json
import os
import re

BASE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(BASE, "raw")
out = {"rss_items": [], "bing_html_items": [], "keyword_ctx": []}

# ---------- PART A: Bing RSS ----------
for rn in ("b_rss_1.txt", "b_rss_2.txt"):
    p = os.path.join(RAW, rn)
    if not os.path.exists(p):
        print("missing:", rn)
        continue
    with open(p, "r", encoding="utf-8", errors="replace") as f:
        x = f.read()
    print("--- %s len=%d ---" % (rn, len(x)))
    for m in re.finditer(r'<item>(.*?)</item>', x, re.S):
        blk = m.group(1)

        def g(tag, blk=blk):
            mm = re.search(r'<%s>(.*?)</%s>' % (tag, tag), blk, re.S)
            if not mm:
                return ""
            v = mm.group(1)
            v = re.sub(r'<!\[CDATA\[(.*?)\]\]>', r'\1', v, flags=re.S)
            return html.unescape(re.sub(r'<[^>]+>', '', v)).strip()

        it = {"src": rn, "title": g("title"), "link": g("link"), "desc": g("description")}
        if it["title"] or it["link"]:
            out["rss_items"].append(it)

print("\nrss items total:", len(out["rss_items"]))
for i, it in enumerate(out["rss_items"]):
    print("[%02d] %s" % (i, it["title"][:95]))
    print("      L: %s" % it["link"][:150])
    if it["desc"]:
        print("      D: %s" % it["desc"][:220])

# ---------- PART B: bing_s.html ----------
bp = os.path.join(RAW, "bing_s.html")
if os.path.exists(bp):
    with open(bp, "r", encoding="utf-8", errors="replace") as f:
        doc = f.read()
    print("\n--- bing_s.html len=%d ---" % len(doc))
    # 多种可能的容器类名
    blocks = re.findall(r'<li class="b_algo".*?</li>', doc, re.S)
    if not blocks:
        blocks = re.findall(r'<div class="b_algo".*?</div>\s*</div>', doc, re.S)
    print("b_algo blocks:", len(blocks))
    for blk in blocks:
        a = re.search(r'<h2>\s*<a[^>]*href="(.*?)"[^>]*>(.*?)</a>', blk, re.S)
        if not a:
            continue
        url = html.unescape(a.group(1))
        title = html.unescape(re.sub(r'<[^>]+>', '', a.group(2))).strip()
        caps = re.findall(r'<p[^>]*>(.*?)</p>', blk, re.S)
        snip = " / ".join(html.unescape(re.sub(r'<[^>]+>', '', c)).strip() for c in caps)[:300]
        out["bing_html_items"].append({"title": title, "url": url, "snippet": snip})
    print("") 
    for i, it in enumerate(out["bing_html_items"][:25]):
        print("[%02d] %s" % (i, it["title"][:95]))
        print("      U: %s" % it["url"][:150])
        print("      S: %s" % it["snippet"][:200])

    # 关键词上下文
    for kw in ("压轴", "新课标I卷", "新课标一卷", "19题", "新定义"):
        for m in list(re.finditer(re.escape(kw), doc))[:3]:
            s = max(0, m.start() - 300)
            e = min(len(doc), m.end() + 300)
            ctx = html.unescape(re.sub(r'\s+', ' ', re.sub(r'<[^>]+>', ' ', doc[s:e]))).strip()
            out["keyword_ctx"].append({"kw": kw, "ctx": ctx[:600]})

print("\n--- keyword contexts ---")
for k in out["keyword_ctx"]:
    print("[%s] %s" % (k["kw"], k["ctx"][:400]))
    print("")

with open(os.path.join(RAW, "_offline_parse.json"), "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False, indent=2)
print("saved -> raw/_offline_parse.json")
