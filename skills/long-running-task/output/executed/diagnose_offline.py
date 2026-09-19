# -*- coding: utf-8 -*-
"""纯离线诊断（零网络）：载体形态 + 正文回读，结果写文件而非大量打印"""
import html
import json
import os
import re

BASE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(BASE, "raw")
report = {}

for name in ("qg1_st", "qg2_st"):
    p = os.path.join(RAW, name + ".html")
    if not os.path.exists(p):
        report[name] = {"error": "missing html"}
        continue
    with open(p, "r", encoding="utf-8", errors="replace") as f:
        doc = f.read()
    imgs = re.findall(r'<img[^>]+src="([^"]+)"', doc, re.I)
    ifs = re.findall(r'<iframe[^>]+src="([^"]+)"', doc, re.I)
    pdfs = re.findall(r'href="([^"]+\.pdf[^"]*)"', doc, re.I)
    tp = os.path.join(RAW, name + ".txt")
    t = ""
    if os.path.exists(tp):
        with open(tp, "r", encoding="utf-8", errors="replace") as f:
            t = f.read()
    report[name] = {
        "html_len": len(doc),
        "img_count": len(imgs),
        "imgs": imgs[:25],
        "iframe_count": len(ifs),
        "iframes": ifs[:10],
        "pdf_count": len(pdfs),
        "pdfs": pdfs[:10],
        "text_len": len(t),
        "text_head": t[:1200],
        "text_tail": t[-800:],
    }

with open(os.path.join(RAW, "_diag_offline.json"), "w", encoding="utf-8") as f:
    json.dump(report, f, ensure_ascii=False, indent=2)

# 精简打印
for k, v in report.items():
    print("### %s" % k)
    if "error" in v:
        print("   ", v["error"])
        continue
    print("    html=%-8d img=%-3d iframe=%-3d pdf=%-3d text=%-6d" % (
        v["html_len"], v["img_count"], v["iframe_count"], v["pdf_count"], v["text_len"]))
    for u in v["imgs"][:12]:
        print("      IMG:", u[:130])
    for u in v["iframes"][:5]:
        print("      IFRAME:", u[:130])
    for u in v["pdfs"][:5]:
        print("      PDF:", u[:130])
    print("    ---- text head ----")
    print(v["text_head"][:900])
    print("    ---- text tail ----")
    print(v["text_tail"][-600:])
print("\nsaved -> raw/_diag_offline.json")
