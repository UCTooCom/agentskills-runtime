# -*- coding: utf-8 -*-
"""Round4: Bing search + candidate page fetch, via urllib (requests unavailable)."""
import urllib.request, urllib.parse, gzip, zlib, io, re, json, os, sys, time

OUT = os.path.dirname(os.path.abspath(__file__))
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0 Safari/537.36"

def fetch(url, timeout=25):
    req = urllib.request.Request(url, headers={
        "User-Agent": UA,
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
        "Accept-Encoding": "gzip, deflate",
        "Connection": "close",
    })
    with urllib.request.urlopen(req, timeout=timeout) as r:
        raw = r.read()
        enc = r.headers.get("Content-Encoding", "").lower()
        if "gzip" in enc:
            raw = gzip.decompress(raw)
        elif "deflate" in enc:
            try:
                raw = zlib.decompress(raw)
            except Exception:
                raw = zlib.decompress(raw, -zlib.MAX_WBITS)
        ctype = r.headers.get("Content-Type", "")
        m = re.search(r"charset=([\w\-]+)", ctype, re.I)
        cs = m.group(1) if m else "utf-8"
        try:
            return raw.decode(cs, "replace"), cs, r.status
        except Exception:
            return raw.decode("utf-8", "replace"), "utf-8*", r.status

QUERIES = [
    "2025年高考化学真题 压轴题 解析",
    "2025高考化学 全国卷 最后一题 有机合成",
    "2025年高考化学试题及答案 完整版",
]

report = {"queries": [], "candidates": []}
for q in QUERIES:
    url = "https://cn.bing.com/search?q=" + urllib.parse.quote(q) + "&ensearch=0&count=30"
    try:
        html, cs, st = fetch(url)
    except Exception as e:
        report["queries"].append({"q": q, "ok": False, "err": repr(e)})
        print("[FAIL]", q, repr(e))
        continue
    fn = os.path.join(OUT, "r4_bing_%d.html" % len(report["queries"]))
    open(fn, "w", encoding="utf-8").write(html)
    # extract result anchors
    items = []
    for m in re.finditer(r'<h2>\s*<a[^>]+href="(http[^"]+)"[^>]*>(.*?)</a>', html, re.S | re.I):
        href, title = m.group(1), re.sub(r"<[^>]+>", "", m.group(2)).strip()
        items.append({"url": href, "title": title})
    report["queries"].append({"q": q, "ok": True, "charset": cs, "html_len": len(html), "n_results": len(items), "results": items[:30], "file": os.path.basename(fn)})
    print("[OK]", q, "->", len(items), "results, charset=", cs, "len=", len(html))
    for it in items[:10]:
        print("   -", it["title"][:70], "|", it["url"][:110])
    time.sleep(2)

json.dump(report, open(os.path.join(OUT, "r4_bing_report.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print("\nWROTE r4_bing_report.json")
