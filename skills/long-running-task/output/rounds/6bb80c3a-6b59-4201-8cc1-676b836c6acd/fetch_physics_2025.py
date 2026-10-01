# -*- coding: utf-8 -*-
"""抓取 2025 年高考物理压轴题题干相关页面（urllib + Chrome UA）。"""
import sys, re, json, time, gzip, ssl, html as htmlmod, os
from urllib.parse import quote, urljoin
import urllib.request

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

OUT = os.path.dirname(os.path.abspath(__file__))
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
    with urllib.request.urlopen(req, timeout=timeout, context=CTX) as r:
        raw = r.read()
        if (r.headers.get("Content-Encoding") or "").lower().find("gzip") >= 0:
            try:
                raw = gzip.decompress(raw)
            except Exception:
                pass
        ctype = (r.headers.get("Content-Type") or "").lower()
        enc = "utf-8"
        m = re.search(r"charset=([\w\-]+)", ctype)
        if m:
            enc = m.group(1)
            if enc in ("gb2312", "gbk", "gb18030"):
                enc = "gb18030"
        try:
            text = raw.decode(enc, errors="replace")
        except Exception:
            text = raw.decode("utf-8", errors="replace")
        return r.status, text

def to_text(h):
    h = re.sub(r"(?is)<script.*?</script>", " ", h)
    h = re.sub(r"(?is)<style.*?</style>", " ", h)
    h = re.sub(r"(?i)<br\s*/?>", "\n", h)
    h = re.sub(r"(?i)</(p|div|li|h[1-6]|tr|table|section|article)>\s*", "\n", h)
    h = re.sub(r"<[^>]+>", " ", h)
    h = htmlmod.unescape(h)
    h = h.replace("\u00a0", " ")
    h = re.sub(r"[ \t\r\f\v]+", " ", h)
    h = re.sub(r"\n\s*\n+", "\n", h)
    return h.strip()

QUERIES = [
    "2025年高考物理压轴题原题",
    "2025高考物理最后一道大题题干",
    "2025年全国甲卷物理压轴题 第25题",
    "2025年高考物理新课标卷压轴题",
]

ENGINES = {
    "so360": "https://www.so.com/s?q={q}",
    "sogou": "https://www.sogou.com/web?query={q}",
    "bingcn": "https://cn.bing.com/search?q={q}&ensearch=0",
}

report = {"searches": [], "pages": []}

for qi, query in enumerate(QUERIES):
    q = quote(query)
    for name, tpl in ENGINES.items():
        url = tpl.format(q=q)
        try:
            st, body = fetch(url)
            txt = to_text(body)
            fn = os.path.join(OUT, "s%d_%s.txt" % (qi + 1, name))
            with open(fn, "w", encoding="utf-8") as f:
                f.write("URL: %s\nSTATUS: %s\nLEN: %d\n\n" % (url, st, len(txt)))
                f.write(txt)
            # extract links
            links = re.findall(r'href="(https?://[^"]+)"', body)
            links = [l for l in links if not re.search(r"(so\.com/link|sogou\.com|bing\.com|miibeian|w3\.org|\.css|\.js|/search)", l)]
            seen = []
            for l in links:
                if l not in seen:
                    seen.append(l)
            report["searches"].append({"q": query, "engine": name, "status": st, "textlen": len(txt), "file": fn, "top_links": seen[:15]})
            print("=== [%s] %s status=%s textlen=%d" % (name, query, st, len(txt)))
            print("   top_links:")
            for l in seen[:10]:
                print("     " + l)
        except Exception as e:
            print("=== [%s] %s ERROR %s: %s" % (name, query, type(e).__name__, e))
        time.sleep(1.2)

with open(os.path.join(OUT, "search_links_physics.json"), "w", encoding="utf-8") as f:
    json.dump(report, f, ensure_ascii=False, indent=2)
print("DONE")
