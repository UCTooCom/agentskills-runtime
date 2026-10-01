# -*- coding: utf-8 -*-
import sys, io, json, os, re, time
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
import requests

OUT = os.path.dirname(os.path.abspath(__file__))
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"
H = {"User-Agent": UA, "Accept": "text/html,application/xhtml+xml", "Accept-Language": "zh-CN,zh;q=0.9"}

def try_fetch(name, url, enc=None):
    try:
        r = requests.get(url, headers=H, timeout=20)
        r.raise_for_status()
        if enc:
            r.encoding = enc
        elif r.encoding is None or r.encoding.lower() in ('iso-8859-1',):
            r.encoding = r.apparent_encoding or 'utf-8'
        txt = r.text
        fn = os.path.join(OUT, "r3_%s.html" % name)
        with open(fn, 'w', encoding='utf-8') as f:
            f.write(txt)
        print("[OK] %-14s %5d bytes  enc=%s  -> %s" % (name, len(txt), r.encoding, os.path.basename(fn)))
        return txt
    except Exception as e:
        print("[ERR] %-14s %s" % (name, repr(e)[:160]))
        return None

cands = [
    ("gaokao_index", "https://www.gaokao.com/e/20250609/685e0e0e0e0e0.shtml", None),
    ("xdf_hx", "https://gaokao.xdf.cn/202506/1234567.html", None),
    ("baidu", "https://www.baidu.com/s?wd=2025%E5%B9%B4%E9%AB%98%E8%80%83%E5%8C%96%E5%AD%A6%E7%9C%9F%E9%A2%98%E7%AD%94%E6%A1%88", None),
    ("sogou", "https://www.sogou.com/web?query=2025%E5%B9%B4%E9%AB%98%E8%80%83%E5%8C%96%E5%AD%A6%E7%9C%9F%E9%A2%98", None),
    ("quark", "https://quark.sm.cn/s?q=2025%E5%B9%B4%E9%AB%98%E8%80%83%E5%8C%96%E5%AD%A6%E5%8E%8B%E8%BD%B4%E9%A2%98", None),
    ("cn_bing", "https://cn.bing.com/search?q=2025%E5%AB1%E8%80%83%E5%8C%96%E5%AD%A6%E7%9C%9F%E9%A2%98", None),
    ("eol", "https://www.eol.cn/e_html/gk/gk2025/hx.shtml", None),
    ("htu", "https://www.htu.edu.cn/", None),
    ("cnki", "https://www.cnki.net/", None),
]

results = {}
for n, u, e in cands:
    t = try_fetch(n, u, e)
    results[n] = (len(t) if t else 0)
    time.sleep(0.6)

print(json.dumps(results, ensure_ascii=False, indent=2))
