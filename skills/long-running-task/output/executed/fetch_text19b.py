# -*- coding: utf-8 -*-
import os, io, re, json, ssl, time, urllib.request, urllib.parse, http.cookiejar

BASE = os.path.dirname(os.path.abspath(__file__))
T1 = os.path.join(BASE, "t1")
P2 = os.path.join(T1, "pages2")
os.makedirs(P2, exist_ok=True)

CTX = ssl.create_default_context()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
HDR = {"User-Agent": UA, "Accept-Language": "zh-CN,zh;q=0.9", "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"}

cj = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(
    urllib.request.HTTPCookieProcessor(cj),
    urllib.request.HTTPSHandler(context=CTX),
)


def get(url, timeout=18):
    try:
        req = urllib.request.Request(url, headers=HDR)
        with opener.open(req, timeout=timeout) as r:
            return r.read()
    except Exception:
        return None


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
    p = re.sub(r"</(p|div|li|h[1-6]|tr|td)>", "\n", p, flags=re.I)
    p = re.sub(r"<[^>]+>", " ", p)
    p = p.replace("&nbsp;", " ").replace("&amp;", "&")
    p = p.replace("&lt;", "<").replace("&gt;", ">")
    p = p.replace("&quot;", '"').replace("&#39;", "'")
    p = re.sub(r"[ \t\r\f\v]+", " ", p)
    p = re.sub(r"\n\s*\n+", "\n", p)
    return p


get("https://www.baidu.com/", 15)
get("https://cn.bing.com/", 15)

QUERIES = [
    "2025\u5e74\u9ad8\u8003\u6570\u5b66\u65b0\u8bfe\u6807\u4e00\u5377\u7b2c19\u9898",
    "2025\u65b0\u8bfe\u6807I\u5377\u6570\u5b66\u7b2c19\u9898 \u4e09\u89d2\u51fd\u6570 \u65b0\u5b9a\u4e49",
    "2025\u9ad8\u8003\u6570\u5b66\u5168\u56fd\u4e00\u537719\u9898 \u771f\u9898 17\u5206",
    "2025\u5e74\u9ad8\u8003\u6570\u5b66\u5168\u56fd\u4e8c\u5377\u7b2c19\u9898",
]
ENGINES = [
    ("baidu", "https://www.baidu.com/s?rn=20&wd=%s"),
    ("sogou", "https://www.sogou.com/web?query=%s"),
    ("so360", "https://www.so.com/s?q=%s"),
    ("bingcn", "https://cn.bing.com/search?ensearch=0&q=%s"),
    ("weixin", "https://wx.sogou.com/weixin?type=2&query=%s"),
]

log = {"serp": [], "cand": 0, "pages": []}
cands = []
seen = set()
for q in QUERIES:
    qe = urllib.parse.quote(q)
    for ename, tmpl in ENGINES:
        u = tmpl % qe
        d = get(u, 18)
        if d is None:
            log["serp"].append({"engine": ename, "err": 1})
            continue
        t, enc = dec(d)
        links = re.findall(r'''href\s*=\s*["'](https?://[^"']+)["']''', t, re.I)
        log["serp"].append({"engine": ename, "bytes": len(d), "links": len(links)})
        for L in links:
            low = L.lower()
            if any(b in low for b in ("bing.com", "so.com", "sogou.com", "w3.org", "microsoft.com", "google.com", "baidu.com/s", "baidu.com/?")):
                continue
            if L in seen:
                continue
            seen.add(L)
            cands.append(L)
        time.sleep(0.6)

log["cand"] = len(cands)
HINTS = ("gaokao", "edu", "zhihu", "sohu", "163.com", "sina", "baijiahao", "zxxk", "jyeoo", "gaosan", "51test", "qq.com", "ifeng", "people.com", "xinhuanet", "chinanews", "eol.cn")


def score(u):
    low = u.lower()
    s = 0
    for h in HINTS:
        if h in low:
            s += 2
    if "baidu.com/link" in low:
        s += 1
    return s


cands = sorted(set(cands), key=score, reverse=True)[:26]
MARK = ["\u7b2c19\u9898", "19.\uff0817\u5206\uff09", "19.(17\u5206)", "17\u5206", "\u65b0\u5b9a\u4e49", "\u4e09\u89d2\u51fd\u6570"]
for i, L in enumerate(cands):
    d = get(L, 18)
    if d is None:
        continue
    t, enc = dec(d)
    p = plain(t)
    if len(p) < 1200:
        continue
    hits = {}
    for k in MARK:
        c = p.count(k)
        if c:
            hits[k] = c
    if not hits:
        continue
    fn = "q%02d.txt" % i
    with io.open(os.path.join(P2, fn), "w", encoding="utf-8") as f:
        f.write("URL: " + L + "\nENC: " + enc + "\n\n" + p)
    rec = {"url": L, "file": fn, "plain": len(p), "hits": hits}
    for k in ("\u7b2c19\u9898", "19.\uff0817\u5206\uff09", "19.(17\u5206)"):
        j = p.find(k)
        if j >= 0:
            rec["ctx"] = p[max(0, j - 300): j + 1200]
            break
    log["pages"].append(rec)
    print("PAGE|" + json.dumps(rec, ensure_ascii=True)[:1400])

with io.open(os.path.join(T1, "fetch_text19b.json"), "w", encoding="utf-8") as f:
    json.dump(log, f, ensure_ascii=False, indent=2)

print("SERP=" + json.dumps(log["serp"], ensure_ascii=True))
print("CAND=%d PAGES=%d" % (log["cand"], len(log["pages"])))
