# -*- coding: utf-8 -*-
"""抓取候选页面正文，提取 2025 高考数学压轴题题干（纯标准库）"""
import sys, re, json, time, gzip
from urllib.parse import quote

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

import ssl, urllib.request

CTX = ssl.create_default_context()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
    "Accept-Encoding": "gzip, deflate",
    "Connection": "close",
}

def fetch(url, timeout=25):
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=timeout, context=CTX) as resp:
        raw = resp.read()
        enc = (resp.headers.get("Content-Encoding") or "").lower()
        if "gzip" in enc:
            try:
                raw = gzip.decompress(raw)
            except Exception:
                pass
        ctype = resp.headers.get("Content-Type") or ""
        m = re.search(r"charset=([\w\-]+)", ctype, re.I)
        cs = m.group(1) if m else "utf-8"
        if cs.lower() in ("gb2312", "gbk", "gb18030"):
            cs = "gb18030"
        return resp.status, raw.decode(cs, errors="replace")

SCRIPT = re.compile(r"<(script|style)\b.*?</\1>", re.S | re.I)
TAGS = re.compile(r"<[^>]+>")

def to_text(html):
    h = SCRIPT.sub(" ", html)
    h = re.sub(r"<br\s*/?>", "\n", h, flags=re.I)
    h = re.sub(r"</(p|div|li|h[1-6]|tr)>\n?", "\n", h, flags=re.I)
    h = TAGS.sub(" ", h)
    h = h.replace("&nbsp;", " ").replace("&amp;", "&").replace("&quot;", '"')
    h = h.replace("&lt;", "<").replace("&gt;", ">")
    lines = [re.sub(r"[ \t]+", " ", ln).strip() for ln in h.split("\n")]
    return "\n".join([ln for ln in lines if ln])

# 候选来源：精确关键词搜索 + 具体文档页
TARGETS = [
    ("search_exact_1", "https://www.so.com/s?q=" + quote("2025年新高考一卷数学第19题 原题")),
    ("search_exact_2", "https://www.so.com/s?q=" + quote("2025年高考数学 压轴题 第19题 题干")),
    ("search_exact_3", "https://www.so.com/s?q=" + quote("2025 新高考 I 卷 数学 19题 数列")),
    ("wenku_1", "https://wenku.so.com/d/85c5b7db0b7eb2ea2e6c87c824f3c230"),
    ("wenku_2", "https://wenku.so.com/d/fe77ff322f9cead09e99c918d1d27847"),
]

for name, url in TARGETS:
    try:
        st, html = fetch(url)
        txt = to_text(html)
        fn = "page_%s.txt" % name
        with open(fn, "w", encoding="utf-8") as f:
            f.write("URL: %s\nSTATUS: %s\nLEN: %d\n\n" % (url, st, len(txt)) + txt)
        print("=== %s status=%s textlen=%d -> %s" % (name, st, len(txt), fn))
        # 打印含关键词的片段
        for kw in ("压轴", "第19题", "19题", "19.", "设", "已知"):
            for m in re.finditer(re.escape(kw), txt):
                s = max(0, m.start() - 60)
                e = min(len(txt), m.start() + 200)
                seg = txt[s:e].replace("\n", " ")
                print("   [%s] %s" % (kw, seg[:240]))
                break
    except Exception as e:
        print("=== %s ERROR %s: %s" % (name, type(e).__name__, e))
    time.sleep(1.5)

print("DONE")
