# -*- coding: utf-8 -*-
import os, sys, io, json, re, ssl, gzip, zlib
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
import urllib.request, urllib.error
from urllib.parse import urljoin

OUT = r"D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\skills\long-running-task\output\rounds\7e3b3121-4fa2-44b6-9938-8bd8afeb0c02"
SAVE = os.path.join(OUT, "fetch")
os.makedirs(SAVE, exist_ok=True)

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")
HDR = {
    "User-Agent": UA,
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
    "Connection": "keep-alive",
}
CTX = ssl.create_default_context()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE

def decode(raw, headers):
    enc = None
    if headers.get('Content-Encoding','').lower() == 'gzip':
        try: raw = gzip.decompress(raw)
        except Exception: pass
    elif headers.get('Content-Encoding','').lower() == 'deflate':
        try: raw = zlib.decompress(raw)
        except Exception: pass
    for cand in ['utf-8', 'gb18030', 'gbk', 'latin-1']:
        try:
            return raw.decode(cand), cand
        except Exception:
            continue
    return raw.decode('utf-8', errors='replace'), 'replace'

def grab(url, name, timeout=25):
    rec = {"url": url, "name": name}
    try:
        req = urllib.request.Request(url, headers=HDR)
        with urllib.request.urlopen(req, timeout=timeout, context=CTX) as r:
            raw = r.read()
            rec['status'] = r.status
            rec['final_url'] = r.geturl()
            hdrs = dict(r.headers)
            txt, enc = decode(raw, hdrs)
            rec['encoding'] = enc
            rec['len_bytes'] = len(raw)
            rec['len_chars'] = len(txt)
        p = os.path.join(SAVE, name + ".html")
        open(p, 'w', encoding='utf-8', errors='replace').write(txt)
        rec['file'] = p
        m = re.search(r'<title[^>]*>(.*?)</title>', txt, re.S | re.I)
        rec['title'] = (m.group(1).strip()[:200] if m else '')
        links = re.findall(r'href=["\']([^"\']+)["\'][^>]*>\s*([^<]{0,100})', txt)
        hit = []
        for href, label in links:
            blob = href + ' ' + label
            if any(k in blob for k in ['2025', '物理', '/wl/', 'shiti', '真题', '试卷']):
                hit.append([urljoin(url, href.strip()), re.sub(r'\s+', ' ', label).strip()])
        rec['links_hit'] = hit[:120]
        rec['ok'] = True
    except Exception as e:
        rec['ok'] = False
        rec['error'] = repr(e)[:400]
    print(json.dumps({k: rec.get(k) for k in ['ok', 'status', 'len_bytes', 'len_chars', 'encoding', 'title', 'error', 'file']}, ensure_ascii=False))
    return rec

candidates = [
    ("eol_wl_list", "http://gaokao.eol.cn/shiti/wl/"),
    ("eol_shiti_list", "http://gaokao.eol.cn/shiti/"),
    ("eol_home", "https://gaokao.eol.cn/"),
    ("eol_sx_2025", "http://gaokao.eol.cn/shiti/sx/202506/t20250607_2673303.shtml"),
]
results = []
for name, url in candidates:
    results.append(grab(url, name))
with open(os.path.join(SAVE, "_probe.json"), 'w', encoding='utf-8') as f:
    json.dump(results, f, ensure_ascii=False, indent=2)
print("SAVED", os.path.join(SAVE, "_probe.json"))
