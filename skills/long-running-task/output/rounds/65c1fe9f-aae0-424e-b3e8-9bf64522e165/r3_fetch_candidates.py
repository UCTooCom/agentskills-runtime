# -*- coding: utf-8 -*-
import sys, io, os, re, json, time, gzip, zlib, ssl, hashlib
import urllib.request, urllib.parse, urllib.error
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

OUT = os.path.dirname(os.path.abspath(__file__))
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
H = {
    "User-Agent": UA,
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "zh-CN,zh;q=0.9",
    "Accept-Encoding": "gzip, deflate",
    "Connection": "close",
}
CTX = ssl.create_default_context(); CTX.check_hostname=False; CTX.verify_mode=ssl.CERT_NONE

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
    m = re.search(r'charset=([\w\-]+)', ctype, re.I)
    cs = m.group(1) if m else 'utf-8'
    for cand in [cs, 'utf-8', 'gb18030', 'gbk', 'latin-1']:
        try: return data.decode(cand, errors='strict'), cand
        except Exception: continue
    return data.decode('utf-8', errors='replace'), 'utf-8(replace)'

def strip_tags(s):
    s = re.sub(r'<script[\s\S]*?</script>','',s,flags=re.I)
    s = re.sub(r'<style[\s\S]*?</style>','',s,flags=re.I)
    s = re.sub(r'<[^>]+>','\n',s)
    for a,b in [('\u0026nbsp;',' '),('\u0026amp;','\u0026'),('\u0026quot;','"'),('\u0026#39;',"'"),('\u0026lt;','<'),('\u0026gt;','>')]:
        s = s.replace(a,b)
    s = re.sub(r'[ \t\xa0]+',' ',s)
    s = re.sub(r'\n{2,}','\n',s)
    return s.strip()

def pick_candidates():
    cands = {}
    # from r3_all_links.json
    p = os.path.join(OUT,'r3_all_links.json')
    if os.path.exists(p):
        with open(p,'r',encoding='utf-8',errors='replace') as f:
            data = json.load(f)
        for fn, links in data.items():
            for l in links:
                if l.get('score',0) >= 3:
                    cands[l['url']] = l.get('score',0)
    # from r3_search2.json
    p2 = os.path.join(OUT,'r3_search2.json')
    if os.path.exists(p2):
        with open(p2,'r',encoding='utf-8',errors='replace') as f:
            d2 = json.load(f)
        for k, v in d2.items():
            for it in v.get('items',[]):
                cands[it['url']] = cands.get(it['url'],0) + 1
    good_domains = ['gaosan','21cnjy','eol.cn','chsi','doc88','book118','renrendoc','docin','zxxk','gaokao','51test','qq.com','baidu.com','sohu','zhihu']
    res = []
    for u, sc in cands.items():
        if any(d in u for d in good_domains):
            res.append((u, sc))
    res.sort(key=lambda x:-x[1])
    return res

cands = pick_candidates()
print("candidates: %d" % len(cands))
for u,sc in cands[:40]:
    print("  [%d] %s" % (sc,u[:170]))

fetched = {}
for u, sc in cands[:40]:
    h = hashlib.md5(u.encode()).hexdigest()[:8]
    name = 'r3c_%s' % h
    try:
        req = urllib.request.Request(u, headers=H)
        with urllib.request.urlopen(req, timeout=20, context=CTX) as resp:
            txt, cs = decode(resp)
        with open(os.path.join(OUT,name+'.html'),'w',encoding='utf-8',errors='replace') as f:
            f.write(txt)
        plain = strip_tags(txt)
        with open(os.path.join(OUT,name+'.txt'),'w',encoding='utf-8',errors='replace') as f:
            f.write(plain)
        # chemistry content signals
        sig = sum(1 for kw in ['化学','有机','mol','溶液','反应','合成','解析','答案'] if kw in plain)
        qnum = len(re.findall(r'\n\s*1[6-9][\.、]', plain)) + len(re.findall(r'\n\s*20[\.、]', plain))
        fetched[u] = {'file':name, 'len':len(txt), 'plain_len':len(plain), 'cs':cs, 'sig':sig, 'qnum':qnum}
        print("[OK ] sig=%d qnum=%d len=%d cs=%s %s" % (sig,qnum,len(txt),cs,u[:110]))
    except Exception as e:
        print("[ERR] %s -> %s" % (u[:110], repr(e)[:100]))
    time.sleep(0.7)

with open(os.path.join(OUT,'r3_fetch_report.json'),'w',encoding='utf-8') as f:
    json.dump({'candidates':cands[:40],'fetched':fetched}, f, ensure_ascii=False, indent=1)
print('saved r3_fetch_report.json')
