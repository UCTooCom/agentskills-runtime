# -*- coding: utf-8 -*-
"""诊断：检查试题页载体形态(img/iframe/pdf) + 回读正文文本 + 抓取评析页"""
import html
import json
import os
import re
import ssl
import socket
import urllib.request

socket.setdefaulttimeout(10)

BASE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(BASE, "raw")

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")

print("===== PART A: 载体形态诊断 =====")
for name in ("qg1_st", "qg2_st"):
    p = os.path.join(RAW, name + ".html")
    if not os.path.exists(p):
        print("missing", p)
        continue
    with open(p, "r", encoding="utf-8", errors="replace") as f:
        doc = f.read()
    imgs = re.findall(r'<img[^>]+src="([^"]+)"', doc, re.I)
    ifs = re.findall(r'<iframe[^>]+src="([^"]+)"', doc, re.I)
    pdfs = re.findall(r'href="([^"]+\.pdf[^"]*)"', doc, re.I)
    print("\n--- %s ---" % name)
    print("  img count:", len(imgs))
    for u in imgs[:20]:
        print("    IMG:", u[:150])
    print("  iframe count:", len(ifs))
    for u in ifs[:10]:
        print("    IFRAME:", u[:150])
    print("  pdf count:", len(pdfs))
    for u in pdfs[:10]:
        print("    PDF:", u[:150])

print("\n===== PART B: 已提取正文全文回读 =====")
for name in ("qg1_st", "qg2_st"):
    tp = os.path.join(RAW, name + ".txt")
    if not os.path.exists(tp):
        continue
    with open(tp, "r", encoding="utf-8", errors="replace") as f:
        t = f.read()
    print("\n########## %s (len=%d) ##########" % (name, len(t)))
    print(t[:3000])
    print("  ......[中略]......")
    print(t[-1500:])

print("\n===== PART C: fetch 评析页 =====")

def fetch(name, url, timeout=10):
    rec = {"name": name, "url": url, "ok": False}
    try:
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        req = urllib.request.Request(url, headers={"User-Agent": UA,
                                                  "Accept-Language": "zh-CN,zh;q=0.9",
                                                  "Accept-Encoding": "identity"})
        with urllib.request.urlopen(req, timeout=timeout, context=ctx) as resp:
            rawb = resp.read()
            rec["status"] = resp.status
        text = None
        for enc in ("utf-8", "gb18030"):
            try:
                text = rawb.decode(enc)
                rec["encoding"] = enc
                break
            except UnicodeDecodeError:
                continue
        if text is None:
            text = rawb.decode("utf-8", errors="replace")
        rec["ok"] = rec["status"] == 200
        rec["length"] = len(text)
        rec["file"] = os.path.join(RAW, name + ".html")
        with open(rec["file"], "w", encoding="utf-8") as f:
            f.write(text)
    except Exception as e:
        rec["error"] = "%s: %s" % (type(e).__name__, e)
    return rec


def to_text(doc):
    doc = re.sub(r'(?is)<script.*?</script>', ' ', doc)
    doc = re.sub(r'(?is)<style.*?</style>', ' ', doc)
    doc = re.sub(r'(?i)<br\s*/?>', '\n', doc)
    doc = re.sub(r'(?i)</p>', '\n', doc)
    doc = re.sub(r'<[^>]+>', ' ', doc)
    doc = html.unescape(doc)
    doc = re.sub(r'[ \t\u3000]+', ' ', doc)
    doc = re.sub(r'\n\s*\n+', '\n', doc)
    return doc.strip()


ping = fetch("qg_pingxi", "http://gaokao.eol.cn/shiti/sx/202506/t20250607_2673301.shtml")
print("  qg_pingxi ok=%s st=%s len=%s err=%s" % (ping.get("ok"), ping.get("status", "-"),
                                                ping.get("length", "-"), ping.get("error", "")[:80]))
if ping.get("file") and os.path.exists(ping["file"]):
    with open(ping["file"], "r", encoding="utf-8", errors="replace") as f:
        d = f.read()
    t = to_text(d)
    with open(os.path.join(RAW, "qg_pingxi.txt"), "w", encoding="utf-8") as f:
        f.write(t)
    print("  text len:", len(t))
    for kw in ("压轴", "19", "新定义", "结构不良", "创新", "区分度"):
        print("   hit %-6s : %d" % (kw, t.count(kw)))
    idx = t.find("压轴")
    if idx < 0:
        idx = t.find("19")
    if idx >= 0:
        print("  ctx:", t[max(0, idx - 500): idx + 900])
