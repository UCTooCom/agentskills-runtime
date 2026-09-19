# -*- coding: utf-8 -*-
"""从 bing_s.html 提取搜索结果条目，并定位压轴题候选页面"""
import json, os, re, html

BASE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(BASE, "raw")
BING = os.path.join(RAW, "bing_s.html")

with open(BING, "r", encoding="utf-8", errors="replace") as f:
    doc = f.read()

items = []
# Bing 结果块
for m in re.finditer(r'<li class="b_algo".*?</li>', doc, re.S):
    blk = m.group(0)
    a = re.search(r'<h2>\s*<a[^>]*href="(.*?)"[^>]*>(.*?)</a>', blk, re.S)
    if not a:
        continue
    url = html.unescape(a.group(1))
    title = html.unescape(re.sub(r'<.*?>', '', a.group(2))).strip()
    cap = re.search(r'<p[^>]*>(.*?)</p>', blk, re.S)
    snippet = html.unescape(re.sub(r'<.*?>', '', cap.group(1))).strip() if cap else ''
    items.append({"title": title, "url": url, "snippet": snippet})

with open(os.path.join(RAW, "_bing_items.json"), "w", encoding="utf-8") as f:
    json.dump(items, f, ensure_ascii=False, indent=2)

print("bing items:", len(items))
for i, it in enumerate(items[:25]):
    print("[%02d] %s" % (i, it["title"][:90]))
    print("     %s" % it["url"][:120])

# 关键词命中统计
kw = ["压轴", "最后一题", "末题", "新高考", "全国一卷", "新课标", "导数", "椭圆", "抛物线", "数列", "解析"]
hits = {k: doc.count(k) for k in kw}
print("\nkeyword hits in bing_s.html:", json.dumps(hits, ensure_ascii=False))
