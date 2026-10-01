# -*- coding: utf-8 -*-
import os, sys, io, json, re, ssl, gzip, zlib, time
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
import urllib.request, urllib.parse

OUT = r"D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\skills\long-running-task\output\rounds\7e3b3121-4fa2-44b6-9938-8bd8afeb0c02"
S = os.path.join(OUT, "harvest")
os.makedirs(S, exist_ok=True)
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
HDR = {"User-Agent": UA, "Accept": "text/html,application/xhtml+xml,*/*;q=0.8", "Accept-Language": "zh-CN,zh;q=0.9"}
CTX = ssl.create_default_context(); CTX.check_hostname = False; CTX.verify_mode = ssl.CERT_NONE


def dec(raw, headers):
    ce = headers.get('Content-Encoding', '').lower()
    if ce == 'gzip':
        try: raw = gzip.decompress(raw)
        except Exception: pass
    elif ce == 'deflate':
        try: raw = zlib.decompress(raw)
        except Exception: pass
    for c in ['utf-8', 'gb18030', 'gbk']:
        try: return raw.decode(c), c
        except Exception: pass
    return raw.decode('utf-8', 'replace'), 'replace'


def get(url, timeout=25):
    req = urllib.request.Request(url, headers=HDR)
    with urllib.request.urlopen(req, timeout=timeout, context=CTX) as r:
        raw = r.read()
        return dec(raw, dict(r.headers))[0], r.status, r.geturl()


def totext(html):
    t = re.sub(r'<script.*?</script>', ' ', html, flags=re.S | re.I)
    t = re.sub(r'<style.*?</style>', ' ', t, flags=re.S | re.I)
    t = re.sub(r'<(p|div|br|li|tr|h[1-6])[^>]*>', '\n', t, flags=re.I)
    t = re.sub(r'<[^>]+>', ' ', t)
    t = t.replace('&nbsp;', ' ').replace('&amp;', '&').replace('&lt;', '<').replace('&gt;', '>')
    t = re.sub(r'[ \t]+', ' ', t)
    t = re.sub(r'\n{2,}', '\n', t)
    return t.strip()


# 1) search sogou for several queries, collect candidate links
queries = [
    "2025高考物理全国甲卷压轴题文字版",
    "2025年高考物理新课标卷最后一题",
    "2025高考物理真题及答案 21题 电场磁场",
    "2025高考物理 压轴 动量 电磁感应 试题",
]
cand = {}
for qi, q in enumerate(queries):
    u = "https://www.sogou.com/web?query=" + urllib.parse.quote(q)
    try:
        html, st, _ = get(u)
    except Exception as e:
        print("SEARCH FAIL", qi, repr(e)[:120]); continue
    open(os.path.join(S, "s%d.html" % qi), 'w', encoding='utf-8', errors='replace').write(html)
    for href, label in re.findall(r'<a[^>]+href=["\']([^"\']+)["\'][^>]*>(.*?)</a>', html, re.S | re.I):
        lab = re.sub(r'<[^>]+>', ' ', label); lab = re.sub(r'\s+', ' ', lab).strip()
        if len(lab) < 6:
            continue
        if not any(k in lab for k in ['物理', '压轴', '高考', '试题', '答案', '真题']):
            continue
        if href.startswith('http') and 'sogou.com' not in href:
            cand.setdefault(href, lab[:110])
    print("q%d links=%d" % (qi, len(cand)))
    time.sleep(1)

print("TOTAL CANDIDATES", len(cand))
json.dump(cand, open(os.path.join(S, "_cand.json"), 'w', encoding='utf-8'), ensure_ascii=False, indent=2)

# 2) fetch top candidates, score for physics final-question text
score_kw = ['压轴', '物理', '电场', '磁场', '带电粒子', '洛伦兹', '磁感应强度', '动能定理', '动量守恒', '电磁感应', '（1）', '(1)', '分）', '求']
rows = []
for i, (href, lab) in enumerate(list(cand.items())[:12]):
    try:
        html, st, fu = get(href, timeout=20)
        txt = totext(html)
        open(os.path.join(S, "p%02d.txt" % i), 'w', encoding='utf-8', errors='replace').write(txt)
        sc = sum(txt.count(k) for k in score_kw)
        rows.append({"i": i, "url": href, "final_url": fu, "label": lab, "len": len(txt), "score": sc, "status": st})
        print("p%02d len=%d score=%d %s" % (i, len(txt), sc, lab[:40]))
    except Exception as e:
        rows.append({"i": i, "url": href, "label": lab, "error": repr(e)[:150]})
        print("p%02d ERR %s" % (i, repr(e)[:100]))
    time.sleep(1)

json.dump(rows, open(os.path.join(S, "_harvest.json"), 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
print("DONE")
