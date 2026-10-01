# -*- coding: utf-8 -*-
import os, sys, io, json, re, ssl, gzip, zlib, time
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
import urllib.request, urllib.parse

OUT = r"D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\skills\long-running-task\output\rounds\7e3b3121-4fa2-44b6-9938-8bd8afeb0c02"
SAVE = os.path.join(OUT, "search")
os.makedirs(SAVE, exist_ok=True)
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
HDR = {
    "User-Agent": UA,
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
    "Cookie": "",
}
CTX = ssl.create_default_context(); CTX.check_hostname = False; CTX.verify_mode = ssl.CERT_NONE

def decode(raw, headers):
    ce = headers.get('Content-Encoding', '').lower()
    if ce == 'gzip':
        try: raw = gzip.decompress(raw)
        except Exception: pass
    elif ce == 'deflate':
        try: raw = zlib.decompress(raw)
        except Exception: pass
    for cand in ['utf-8', 'gb18030', 'gbk', 'latin-1']:
        try: return raw.decode(cand), cand
        except Exception: pass
    return raw.decode('utf-8', 'replace'), 'replace'

def grab(url, name, timeout=25):
    rec = {"url": url, "name": name}
    try:
        req = urllib.request.Request(url, headers=HDR)
        with urllib.request.urlopen(req, timeout=timeout, context=CTX) as r:
            raw = r.read(); txt, enc = decode(raw, dict(r.headers)); rec['status'] = r.status
        p = os.path.join(SAVE, name + ".html")
        open(p, 'w', encoding='utf-8', errors='replace').write(txt)
        t = re.sub(r'<script.*?</script>', ' ', txt, flags=re.S | re.I)
        t = re.sub(r'<style.*?</style>', ' ', t, flags=re.S | re.I)
        t = re.sub(r'<[^>]+>', ' ', t)
        t = re.sub(r'\s+', ' ', t)
        open(os.path.join(SAVE, name + ".txt"), 'w', encoding='utf-8', errors='replace').write(t)
        rec.update(ok=True, enc=enc, len=len(t), file=p)
        rec['title'] = (re.search(r'<title[^>]*>(.*?)</title>', txt, re.S | re.I) or [None, ''])[1][:150]
        rec['phys_hits'] = t.count('物理')
        rec['snippet'] = t[:400]
    except Exception as e:
        rec.update(ok=False, error=repr(e)[:250])
    print(json.dumps({k: rec.get(k) for k in ['ok','status','len','enc','phys_hits','title','error']}, ensure_ascii=False))
    return rec

queries = [
    "2025年高考物理压轴题",
    "2025高考物理试题及答案 最后一题",
]
results = []
engines = [
    ("bing", "https://www.bing.com/search?q={q}"),
    ("sogou", "https://www.sogou.com/web?query={q}"),
    ("baidu", "https://www.baidu.com/s?wd={q}"),
]
for eng, tmpl in engines:
    for qi, q in enumerate(queries):
        url = tmpl.format(q=urllib.parse.quote(q))
        results.append(grab(url, "%s_%d" % (eng, qi)))
        time.sleep(1)

json.dump(results, open(os.path.join(SAVE, "_search.json"), 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
print("DONE", len(results))
