# -*- coding: utf-8 -*-
import sys, io, os, json, time, gzip, zlib, ssl, re
import urllib.request, urllib.parse, urllib.error
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

OUT = os.path.dirname(os.path.abspath(__file__))
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
H = {
    "User-Agent": UA,
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
    "Accept-Encoding": "gzip, deflate",
    "Connection": "close",
}
CTX = ssl.create_default_context()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE

def decode(resp):
    data = resp.read()
    enc = (resp.headers.get("Content-Encoding") or "").lower()
    if "gzip" in enc:
        try: data = gzip.decompress(data)
        except Exception: pass
    elif "deflate" in enc:
        try: data = zlib.decompress(data, -zlib.MAX_WBITS)
        except Exception:
            try: data = zlib.decompress(data)
            except Exception: pass
    ctype = resp.headers.get("Content-Type", "")
    cs = "utf-8"
    m = re.search(r'charset=([\w\-]+)', ctype, re.I)
    if m: cs = m.group(1)
    for cand in [cs, 'utf-8', 'gb18030', 'gbk', 'latin-1']:
        try:
            return data.decode(cand, errors='strict'), cand
        except Exception:
            continue
    return data.decode('utf-8', errors='replace'), 'utf-8(replace)'

def fetch(name, url, referer=None, timeout=25):
    h = dict(H)
    if referer: h["Referer"] = referer
    try:
        req = urllib.request.Request(url, headers=h)
        with urllib.request.urlopen(req, timeout=timeout, context=CTX) as resp:
            txt, cs = decode(resp)
            fn = os.path.join(OUT, 'r3_%s.html' % name)
            with open(fn, 'w', encoding='utf-8', errors='replace') as f:
                f.write(txt)
            print("[OK ] %-16s len=%7d cs=%-12s -> %s" % (name, len(txt), cs, os.path.basename(fn)))
            return txt
    except Exception as e:
        print("[ERR] %-16s %s" % (name, repr(e)[:150]))
        return None

Q = urllib.parse.quote("2025年高考化学真题及答案")
Q2 = urllib.parse.quote("2025年高考化学 压轴题 解析")

targets = [
    ("bing_cn", "https://cn.bing.com/search?q=%s" % Q, None),
    ("bing_www", "https://www.bing.com/search?q=%s" % Q, None),
    ("baidu", "https://www.baidu.com/s?wd=%s" % Q, None),
    ("sogou", "https://www.sogou.com/web?query=%s" % Q, None),
    ("so360", "https://www.so.com/s?q=%s" % Q2, None),
    ("gaosan_chem", "https://www.gaosan.com/gaokao/chem/", None),
    ("gaokao_chem", "https://www.gaokao.com/e/2025gk/huaxue/", None),
    ("eol_gk2025", "https://www.eol.cn/e_html/gk/gk2025/", None),
]
keep = {}
for n, u, ref in targets:
    t = fetch(n, u, ref)
    keep[n] = len(t) if t else 0
    time.sleep(0.8)

print("\n" + json.dumps(keep, ensure_ascii=False, indent=2))
