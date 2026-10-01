# -*- coding: utf-8 -*-
import sys, io, json, re, urllib.parse, urllib.request, ssl, os
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

CTX = ssl.create_default_context()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36",
    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
}

def fetch(url, timeout=20):
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=timeout, context=CTX) as resp:
        raw = resp.read()
        enc = resp.headers.get_content_charset() or 'utf-8'
        return resp.status, raw.decode(enc, errors='replace')

q = urllib.parse.quote("2025高考物理压轴题 解析")
cands = {
    "ddg_lite": "https://lite.duckduckgo.com/lite/?q=" + q,
    "brave": "https://search.brave.com/search?q=" + q,
    "ecosia": "https://www.ecosia.org/search?q=" + q,
    "startpage": "https://www.startpage.com/sp/search?query=" + q,
    "searx_be": "https://searx.be/search?q=" + q,
    "mojeek": "https://www.mojeek.com/search?q=" + q,
    "marginalia": "https://search.marginalia.nu/search?query=" + q,
}
out = {}
for name, url in cands.items():
    rec = {"url": url}
    try:
        st, txt = fetch(url)
        rec["status"] = st
        rec["len"] = len(txt)
        rec["has_gk"] = txt.count("高考")
        rec["has_wl"] = txt.count("物理")
        rec["title"] = (re.search(r'<title[^>]*>(.*?)</title>', txt, re.S).group(1).strip() if re.search(r'<title[^>]*>(.*?)</title>', txt, re.S) else "")[:120]
        rec["head"] = re.sub(r'\s+', ' ', txt[:200])
    except Exception as e:
        rec["error"] = repr(e)
    out[name] = rec

print(json.dumps(out, ensure_ascii=False, indent=2))
