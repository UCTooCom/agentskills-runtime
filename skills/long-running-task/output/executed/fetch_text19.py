# -*- coding: utf-8 -*-
import os, io, re, json, ssl, urllib.request, urllib.parse
BASE = os.path.dirname(os.path.abspath(__file__))
T1 = os.path.join(BASE, "t1")
PAGES = os.path.join(T1, "pages")
os.makedirs(PAGES, exist_ok=True)
CTX = ssl.create_default_context()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE
HDR = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0 Safari/537.36", "Accept-Language": "zh-CN,zh;q=0.9"}

def get(url, timeout=25):
    try:
        req = urllib.request.Request(url, headers=HDR)
        with urllib.request.urlopen(req, timeout=timeout, context=CTX) as r:
            return r.read(), r.geturl()
    except Exception as e:
        return None, "ERR:" + str(e)[:120]

def dec(data):
    for enc in ("utf-8", "gbk", "gb18030", "big5"):
        try:
            return data.decode(enc), enc
        except Exception:
            continue
    return data.decode("utf-8", "replace"), "utf-8(replace)"

def plain(t):
    p = re.sub(r"<script[^>]*>.*?</script>", " ", t, flags=re.S | re.I)
    p = re.sub(r"<style[^>]*>.*?</style>", " ", p, flags=re.S | re.I)
    p = re.sub(r"<br\s*/?>", "\n", p, flags=re.I)
    p = re.sub(r"</(p|div|li|h[1-6]|tr)>?", "\n", p, flags=re.I)
    p = re.sub(r"<[^>]+>", " ", p)
    p = p.replace("&nbsp;", " ").replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
    p = re.sub(r"[ \t\r\f\v]+", " ", p)
    p = re.sub(r"\n\s*\n+", "\n", p)
    return p

QUERIES = [
    "2025\u5e74\u9ad8\u8003\u6570\u5b66\u65b0\u8bfe\u6807I\u5377\u7b2c19\u9898\u771f\u9898",
    "2025\u65b0\u8bfe\u6807I\u5377\u6570\u5b66\u7b2c19\u9898\u9898\u5e72",
    "2025\u9ad8\u8003\u6570\u5b66\u5168\u56fd\u4e00\u5377\u7b2c19\u9898\u65b0\u5b9a\u4e49",
]
ENGINES = ["https://cn.bing.com/search?ensearch=0&q=%s", "https://www.so.com/s?q=%s", "https://duckduckgo.com/html/?q=%s"]
result = {"search": [], "pages": [], "hits": []}
seen = set()
for q in QUERIES:
    qe = urllib.parse.quote(q)
    for tmpl in ENGINES:
        for page in (1,):
            u = tmpl % qe
            data, fin = get(u)
            if data is None:
                result["search"].append({"url": u, "error": fin})
                continue
            t, enc = dec(data)
            links = re.findall(r'''href\s*=\s*["'](https?://[^"']+)["']''', t, re.I)
            result["search"].append({"url": u, "enc": enc, "bytes": len(data), "links": len(links)})
            for L in links:
                if any(b in L for b in ("bing.com", "so.com", "duckduckgo", "baidu.com", "microsoft", "w3.org")):
                    continue
                if L in seen:
                    continue
                seen.add(L)
                d2, f2 = get(L, 20)
                if d2 is None:
                    continue
                t2, e2 = dec(d2)
                p2 = plain(t2)
                if len(p2) < 2000:
                    continue
                kws = {"19.": p2.count("19."), "\u7b2c19\u9898": p2.count("\u7b2c19\u9898"), "\u65b0\u5b9a\u4e49": p2.count("\u65b0\u5b9a\u4e49"), "17\u5206": p2.count("17\u5206")}
                if sum(kws.values()) == 0:
                    continue
                fn = "p%03d.txt" % len(result["pages"])
                with io.open(os.path.join(PAGES, fn), "w", encoding="utf-8") as f:
                    f.write("URL: " + L + "\nENC: " + e2 + "\n\n" + p2)
                rec = {"url": L, "file": fn, "bytes": len(d2), "plain": len(p2), "kws": kws}
                for k in ("19.", "\u7b2c19\u9898"):
                    i = p2.find(k)
                    if i >= 0:
                        rec.setdefault("ctx", []).append(p2[max(0, i - 300): i + 1200])
                result["pages"].append(rec)
                result["hits"].append(rec)
                print("PAGE|" + json.dumps(rec, ensure_ascii=True))
with io.open(os.path.join(T1, "fetch_text19.json"), "w", encoding="utf-8") as f:
    json.dump(result, f, ensure_ascii=False, indent=2)
print("SEARCH_DONE|%d|PAGES=%d" % (len(result["search"]), len(result["pages"])))
