# -*- coding: utf-8 -*-
"""Round4 deep: Baidu SERP -> resolve real links -> fetch candidate pages -> keyword scan."""
import urllib.request, urllib.parse, gzip, zlib, re, json, os, time, html as ihtml

OUT = os.path.dirname(os.path.abspath(__file__))
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0 Safari/537.36"

def fetch(url, timeout=25, maxbytes=4_000_000):
    req = urllib.request.Request(url, headers={
        "User-Agent": UA,
        "Accept": "text/html,application/xhtml+xml,*/*;q=0.8",
        "Accept-Language": "zh-CN,zh;q=0.9",
        "Accept-Encoding": "gzip, deflate",
        "Connection": "close",
    })
    with urllib.request.urlopen(req, timeout=timeout) as r:
        raw = r.read(maxbytes)
        enc = (r.headers.get("Content-Encoding") or "").lower()
        if "gzip" in enc:
            try: raw = gzip.decompress(raw)
            except Exception: pass
        elif "deflate" in enc:
            try: raw = zlib.decompress(raw)
            except Exception:
                try: raw = zlib.decompress(raw, -zlib.MAX_WBITS)
                except Exception: pass
        ct = r.headers.get("Content-Type", "")
        m = re.search(r"charset=([\w\-]+)", ct, re.I)
        cs = m.group(1) if m else "utf-8"
        txt = raw.decode(cs, "replace")
        return txt, r.status, r.geturl()

def bailian_links(html):
    """extract baidu /link?url= and direct external hrefs from SERP"""
    out = []
    for m in re.finditer(r'href="(https?://www\.baidu\.com/link\?url=[^"]+)"', html):
        out.append(ihtml.unescape(m.group(1)))
    for m in re.finditer(r'mu="(https?://[^"]+)"', html):
        out.append(ihtml.unescape(m.group(1)))
    res = []
    seen = set()
    for u in out:
        if u in seen: continue
        seen.add(u); res.append(u)
    return res

QUERIES = [
    "2025年高考化学试题及答案 全国卷 压轴题",
    "2025高考化学 有机合成 大题 解析",
    "2025年高考化学新课标卷 真题 第15题",
]

report = {"serp": [], "candidates": []}
for i, q in enumerate(QUERIES):
    url = "https://www.baidu.com/s?wd=" + urllib.parse.quote(q) + "&rn=30"
    try:
        html, st, fin = fetch(url)
    except Exception as e:
        print("[SERP FAIL]", q, repr(e)); report["serp"].append({"q": q, "err": repr(e)}); continue
    open(os.path.join(OUT, "r4_baidu_%d.html" % i), "w", encoding="utf-8").write(html)
    links = bailian_links(html)
    report["serp"].append({"q": q, "ok": True, "len": len(html), "n_links": len(links), "links": links[:40]})
    print("[SERP OK]", q, "len=", len(html), "links=", len(links))
    # resolve baidu redirects
    real = []
    for u in links[:25]:
        try:
            t, st2, fin2 = fetch(u, timeout=15)
            real.append({"start": u, "final": fin2})
            if fin2 and "baidu.com/link" not in fin2:
                real[-1]["final"] = fin2
        except Exception as e:
            real[-1] = {"start": u, "final": None, "err": repr(e)}
    report["serp"][-1]["resolved"] = real
    for r in real:
        if r.get("final"):
            print("   ->", r["final"][:140])
        elif "http" in r.get("start", ""):
            print("   ??", r["start"][:100])
    time.sleep(3)

json.dump(report, open(os.path.join(OUT, "r4_deep_report.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print("\nWROTE r4_deep_report.json")
