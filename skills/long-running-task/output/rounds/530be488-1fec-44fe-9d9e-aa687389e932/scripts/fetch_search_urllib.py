# -*- coding: utf-8 -*-
import sys, io, json, urllib.parse, urllib.request, ssl, socket
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36",
    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
}

def fetch(url, timeout=20):
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=timeout, context=ctx) as resp:
        raw = resp.read()
        enc = resp.headers.get_content_charset() or 'utf-8'
        try:
            return resp.status, raw.decode(enc, errors='replace')
        except Exception:
            return resp.status, raw.decode('utf-8', errors='replace')

q = "2025年高考物理压轴题"
engines = {
    "bing": "https://www.bing.com/search?q={q}",
    "cn_bing": "https://cn.bing.com/search?q={q}",
    "ddg_html": "https://html.duckduckgo.com/html/?q={q}",
    "sogou": "https://www.sogou.com/web?query={q}",
    "so360": "https://www.so.com/s?q={q}",
    "baidu": "https://www.baidu.com/s?wd={q}",
    "yandex": "https://yandex.com/search/?text={q}",
}
out = []
for name, tpl in engines.items():
    url = tpl.format(q=urllib.parse.quote(q))
    rec = {"engine": name, "url": url}
    try:
        st, txt = fetch(url)
        rec["status"] = st
        rec["len"] = len(txt)
        rec["head"] = txt[:500]
    except Exception as e:
        rec["error"] = repr(e)
    out.append(rec)

print(json.dumps(out, ensure_ascii=False, indent=2))
