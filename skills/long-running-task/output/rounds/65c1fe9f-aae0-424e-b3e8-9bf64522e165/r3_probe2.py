# -*- coding: utf-8 -*-
import sys, io, os, re, json, time, urllib.parse
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
import requests

OUT = os.path.dirname(os.path.abspath(__file__))
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
BASE_H = {
    "User-Agent": UA,
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
    "Connection": "keep-alive",
}
S = requests.Session()
S.headers.update(BASE_H)

def get(url, referer=None, timeout=20):
    h = {}
    if referer:
        h["Referer"] = referer
    try:
        r = S.get(url, headers=h, timeout=timeout, allow_redirects=True)
        enc = r.encoding
        if enc is None or enc.lower() in ('iso-8859-1',):
            r.encoding = r.apparent_encoding or 'utf-8'
        return r
    except Exception as e:
        return e

def save_raw(name, r):
    if isinstance(r, Exception):
        print("  [ERR] %s -> %s" % (name, repr(r)[:140]))
        return None
    fn = os.path.join(OUT, 'r3_%s.html' % name)
    with open(fn, 'w', encoding='utf-8', errors='replace') as f:
        f.write(r.text)
    print("  [OK ] %-18s http=%s len=%d enc=%s -> %s" % (name, r.status_code, len(r.text), r.encoding, os.path.basename(fn)))
    return r.text

Q = "2025%E5%B9%B4%E9%AB%98%E8%80%83%E5%8C%96%E5%AD%A6%E7%9C%9F%E9%A2%98%E7%AD%94%E6%A1%88"

print("== Search engines ==")
engines = [
    ("bing_cn", "https://cn.bing.com/search?q=%s&ensearch=0" % Q, None),
    ("bing_www", "https://www.bing.com/search?q=%s" % Q, None),
    ("baidu", "https://www.baidu.com/s?wd=%s" % Q, None),
    ("sogou", "https://www.sogou.com/web?query=%s" % Q, None),
    ("so360", "https://www.so.com/s?q=%s" % Q, None),
]
keep = {}
for n, u, ref in engines:
    r = get(u, ref)
    t = save_raw(n, r)
    if t:
        keep[n] = len(t)
    time.sleep(0.8)
print(json.dumps(keep, ensure_ascii=False))

print("\n== Direct candidate pages ==")
cands = [
    ("gaosan_chem", "https://www.gaosan.com/gaokao/chem/", None),
    ("gaosan_search", "https://www.gaosan.com/search.php?q=2025%E9%AB%98%E8%80%83%E5%8C%96%E5%AD%A6", None),
    ("gaokao_chem", "https://www.gaokao.com/e/2025gk/huaxue/", None),
    ("eol_gk2025", "https://www.eol.cn/e_html/gk/gk2025/", None),
]
for n, u, ref in cands:
    r = get(u, ref)
    save_raw(n, r)
    time.sleep(0.6)

print("\nDONE")
