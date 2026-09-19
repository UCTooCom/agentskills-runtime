# -*- coding: utf-8 -*-
"""第六轮：抓取 2025 全国卷数学试题正文，提取压轴题(第19题)题干【只取题干，不取解析】"""
import html
import json
import os
import re
import ssl
import socket
import time
import urllib.request

socket.setdefaulttimeout(10)

BASE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(BASE, "raw")
os.makedirs(RAW, exist_ok=True)

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")

TARGETS = [
    ("qg1_st", "http://gaokao.eol.cn/shiti/sx/202506/t20250607_2673303.shtml", "2025年全国统一高考数学试卷（新高考I卷）试题"),
    ("qg2_st", "http://gaokao.eol.cn/shiti/sx/202506/t20250608_2673332.shtml", "2025年全国统一高考数学试卷（新高考II卷）试题"),
]


def fetch(name, url, timeout=10):
    rec = {"name": name, "url": url, "ok": False, "fetched_at": time.strftime("%Y-%m-%d %H:%M:%S")}
    try:
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        req = urllib.request.Request(url, headers={
            "User-Agent": UA,
            "Accept-Language": "zh-CN,zh;q=0.9",
            "Accept-Encoding": "identity",
        })
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


res = []
for n, u, d in TARGETS:
    r = fetch(n, u)
    r["desc"] = d
    res.append(r)
    print("  %-8s ok=%-5s st=%-5s len=%-8s err=%s" % (
        n, r.get("ok"), r.get("status", "-"), r.get("length", "-"), r.get("error", "")[:90]))

# ---------- 正文纯文本化 ----------
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


print("\n===== text extraction =====")
report = []
for r in res:
    if not r.get("file") or not os.path.exists(r["file"]):
        continue
    with open(r["file"], "r", encoding="utf-8", errors="replace") as f:
        doc = f.read()
    txt = to_text(doc)
    tp = os.path.join(RAW, r["name"] + ".txt")
    with open(tp, "w", encoding="utf-8") as f:
        f.write(txt)
    print("\n--- %s text len=%d ---" % (r["name"], len(txt)))
    # 定位第 19 题 / 压轴
    for pat in (r'(?:^|\n)\s*(?:19|20)\s*[\.、．]', r'第\s*19\s*题'):
        ms = list(re.finditer(pat, txt))
        if ms:
            m = ms[-1] if len(ms) > 1 else ms[0]
            seg = txt[max(0, m.start() - 100): m.start() + 1400]
            print("  [match %s] %s" % (pat[:22], seg[:1400]))
            break
    # 关键词命中
    hits = {k: txt.count(k) for k in ("19", "压轴", "参考答案", "解析", "如图", "抛物线", "椭圆", "导数")}
    r["hits"] = hits
    print("  hits:", json.dumps(hits, ensure_ascii=False))
    report.append({"name": r["name"], "url": r["url"], "desc": r["desc"],
                   "fetched_at": r["fetched_at"], "text_file": tp, "text_len": len(txt), "hits": hits})

with open(os.path.join(RAW, "_round6.json"), "w", encoding="utf-8") as f:
    json.dump({"fetch": res, "report": report}, f, ensure_ascii=False, indent=2)
print("\nsaved -> raw/_round6.json")
