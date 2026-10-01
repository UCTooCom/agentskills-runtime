# -*- coding: utf-8 -*-
"""多引擎抓取 2025 年高考数学压轴大题（纯标准库 urllib，无第三方依赖）"""
import sys, re, time, json, gzip, io
from urllib.parse import quote, urlparse

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

QUERY = "2025年高考数学压轴题 原题"
q = quote(QUERY)

ENGINES = [
    ("bing_cn", "https://cn.bing.com/search?q=" + q + "&ensearch=0"),
    ("so360", "https://www.so.com/s?q=" + q),
    ("sogou", "https://www.sogou.com/web?query=" + q),
    ("shenma", "https://m.sm.cn/s?q=" + q),
]

TAG_RE = re.compile(r"<a\b[^>]*href=\"([^\"]+)\"[^>]*>(.*?)</a>", re.S | re.I)
TAG_CLEAN = re.compile(r"<[^>]+>")

def clean(s):
    s = TAG_CLEAN.sub("", s)
    s = s.replace("&nbsp;", " ").replace("&amp;", "&").replace("&quot;", '"')
    return re.sub(r"\s+", " ", s).strip()

def fetch(url):
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=25, context=CTX) as resp:
        raw = resp.read()
        enc = resp.headers.get("Content-Encoding", "") or ""
        if "gzip" in enc.lower():
            try:
                raw = gzip.decompress(raw)
            except Exception:
                pass
        # charset
        ctype = resp.headers.get("Content-Type", "") or ""
        m = re.search(r"charset=([\w\-]+)", ctype, re.I)
        cs = m.group(1) if m else "utf-8"
        if cs.lower() in ("gb2312", "gbk", "gb18030"):
            cs = "gb18030"
        return resp.status, raw.decode(cs, errors="replace")

out = {"query": QUERY, "engines": {}}
for name, url in ENGINES:
    rec = {"url": url, "ok": False, "count": 0, "results": [], "error": ""}
    try:
        status, html = fetch(url)
        rec["status"] = status
        rec["len"] = len(html)
        hits = []
        for m in TAG_RE.finditer(html):
            href, txt = m.group(1), clean(m.group(2))
            if len(txt) < 8 or len(txt) > 120:
                continue
            if href.startswith("javascript") or href.startswith("#"):
                continue
            hits.append({"title": txt, "url": href})
            if len(hits) >= 30:
                break
        rec["ok"] = True
        rec["results"] = hits
        rec["count"] = len(hits)
        # 保存原始 html
        with open("raw_%s.html" % name, "w", encoding="utf-8") as f:
            f.write(html)
    except Exception as e:
        rec["error"] = "%s: %s" % (type(e).__name__, e)
    out["engines"][name] = rec
    print("=== %s status=%s ok=%s count=%s err=%s" % (name, rec.get("status"), rec["ok"], rec["count"], rec["error"]))
    for it in rec["results"][:20]:
        print("   -", it["title"], "|", it["url"][:110])
    time.sleep(1.5)

with open("output_search_2025.json", "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False, indent=2)
print("\nSAVED output_search_2025.json")
