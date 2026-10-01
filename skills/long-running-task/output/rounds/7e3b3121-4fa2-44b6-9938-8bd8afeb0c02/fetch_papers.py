# -*- coding: utf-8 -*-
import os, sys, io, json, re, ssl, gzip, zlib
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
import urllib.request
from urllib.parse import urljoin

OUT = r"D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\skills\long-running-task\output\rounds\7e3b3121-4fa2-44b6-9938-8bd8afeb0c02"
SAVE = os.path.join(OUT, "fetch")
os.makedirs(SAVE, exist_ok=True)
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
HDR = {"User-Agent": UA, "Accept": "text/html,application/xhtml+xml,*/*;q=0.8", "Accept-Language": "zh-CN,zh;q=0.9"}
CTX = ssl.create_default_context(); CTX.check_hostname = False; CTX.verify_mode = ssl.CERT_NONE

def decode(raw, headers):
    ce = headers.get('Content-Encoding', '').lower()
    if ce == 'gzip':
        try: raw = gzip.decompress(raw)
        except Exception: pass
    elif ce == 'deflate':
        try: raw = zlib.decompress(raw)
        except Exception: pass
    for cand in ['utf-8', 'gb18030', 'gbk']:
        try: return raw.decode(cand), cand
        except Exception: pass
    return raw.decode('utf-8', 'replace'), 'replace'

def grab(url, name, timeout=25):
    try:
        req = urllib.request.Request(url, headers=HDR)
        with urllib.request.urlopen(req, timeout=timeout, context=CTX) as r:
            raw = r.read(); txt, enc = decode(raw, dict(r.headers)); status = r.status
        p = os.path.join(SAVE, name + ".html")
        open(p, 'w', encoding='utf-8', errors='replace').write(txt)
        # strip scripts/styles -> text
        t = re.sub(r'<script.*?</script>', ' ', txt, flags=re.S | re.I)
        t = re.sub(r'<style.*?</style>', ' ', t, flags=re.S | re.I)
        text = re.sub(r'<[^>]+>', '\n', t)
        text = re.sub(r'&nbsp;', ' ', text)
        text = re.sub(r'\n{2,}', '\n', text)
        tp = os.path.join(SAVE, name + ".txt")
        open(tp, 'w', encoding='utf-8', errors='replace').write(text)
        # images
        imgs = re.findall(r'<img[^>]+src=["\']([^"\']+)["\']', txt, re.I)
        imgs = [urljoin(url, u) for u in imgs]
        # question tokens
        qn = len(re.findall(r'\d{1,2}\.\s*[（(]?\d+\s*分', text))
        res = {"ok": True, "status": status, "len": len(txt), "text_len": len(text), "encoding": enc, "file": p, "text": tp, "n_imgs": len(imgs), "n_qnum": qn, "imgs": imgs[:40]}
    except Exception as e:
        res = {"ok": False, "error": repr(e)[:300]}
    print(json.dumps({k: res.get(k) for k in ['ok','status','text_len','encoding','n_imgs','n_qnum','error']}, ensure_ascii=False))
    return res

pages = [
    ("yn2025_stem", "http://gaokao.eol.cn/shiti/wl/202506/t20250612_2674338.shtml"),
    ("yn2025_ans",  "http://gaokao.eol.cn/shiti/wl/202506/t20250612_2674351.shtml"),
    ("nm2025_stem", "http://gaokao.eol.cn/shiti/wl/202506/t20250612_2674314.shtml"),
    ("ln2025_stem", "http://gaokao.eol.cn/shiti/wl/202506/t20250612_2674313.shtml"),
    ("jl2025_stem", "http://gaokao.eol.cn/shiti/wl/202506/t20250612_2674312.shtml"),
    ("hlj2025_stem","http://gaokao.eol.cn/shiti/wl/202506/t20250612_2674311.shtml"),
]
res = []
for n, u in pages:
    res.append(grab(u, n))
json.dump(res, open(os.path.join(SAVE, "_papers.json"), 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
print("DONE")
