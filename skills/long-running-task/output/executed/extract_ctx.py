# -*- coding: utf-8 -*-
"""提取 bing_s.html 中关键词上下文与所有外链，定位 2025 高考数学压轴题来源"""
import json, os, re, html

BASE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(BASE, "raw")

with open(os.path.join(RAW, "bing_s.html"), "r", encoding="utf-8", errors="replace") as f:
    doc = f.read()
print("doc len:", len(doc))

for kw in ["压轴", "新课标"]:
    print("\n===== %s =====" % kw)
    for m in re.finditer(kw, doc):
        s = max(0, m.start() - 260)
        e = min(len(doc), m.end() + 260)
        ctx = re.sub(r'<[^>]+>', ' ', doc[s:e])
        ctx = html.unescape(re.sub(r'\s+', ' ', ctx)).strip()
        print("---", ctx[:420])

# 提取所有外链
urls = set()
for m in re.finditer(r'href="(https?://[^"]+)"', doc):
    u = html.unescape(m.group(1))
    if "bing.com" not in u and "microsoft" not in u and "msn.com" not in u:
        urls.add(u)
print("\nn external urls:", len(urls))
for u in sorted(urls)[:60]:
    print("  ", u[:150])

with open(os.path.join(RAW, "_bing_ext.json"), "w", encoding="utf-8") as f:
    json.dump(sorted(urls), f, ensure_ascii=False, indent=2)
