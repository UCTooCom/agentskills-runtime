# -*- coding: utf-8 -*-
import sys, io, os, re, json, time, gzip, zlib, ssl, urllib.parse
import urllib.request
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

OUT = os.path.dirname(os.path.abspath(__file__))
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
H = {"User-Agent": UA, "Accept": "text/html,application/xhtml+xml,*/*;q=0.8", "Accept-Language": "zh-CN,zh;q=0.9", "Accept-Encoding": "gzip, deflate", "Connection": "close"}
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

def fetch(url, timeout=20, referer=None):
    h = dict(H)
    if referer: h["Referer"] = referer
    try:
        req = urllib.request.Request(url, headers=h)
        with urllib.request.urlopen(req, timeout=timeout, context=CTX) as resp:
            return decode(resp)[0]
    except Exception as e:
        return None

def strip_tags(s):
    s = re.sub(r'<script[\s\S]*?</script>','',s,flags=re.I)
    s = re.sub(r'<style[\s\S]*?</style>','',s,flags=re.I)
    s = re.sub(r'<!--[\s\S]*?-->','',s)
    s = re.sub(r'<(br|/p|/div|/li|/h[1-6]|/tr)[^>]*>','\n',s,flags=re.I)
    s = re.sub(r'<[^>]+>',' ',s)
    for a,b in [('\u0026nbsp;',' '),('\u0026amp;','\u0026'),('\u0026quot;','"'),('\u0026#39;',"'"),('\u0026lt;','<'),('\u0026gt;','>')]:
        s = s.replace(a,b)
    s = re.sub(r'[ \t\xa0]+',' ',s); s = re.sub(r'\n{2,}','\n',s)
    return s.strip()

KW = "艾拉莫德"
queries = ["艾拉莫德 高考化学", "艾拉莫德 有机合成 2025", "2025高考化学 艾拉莫德 合成"]
engines = [
    ("sogou", "https://www.sogou.com/web?query=%s"),
    ("bingcn", "https://cn.bing.com/search?q=%s&count=30"),
    ("bingww", "https://www.bing.com/search?q=%s&count=30"),
    ("so360", "https://www.so.com/s?q=%s"),
]
alllinks = {}
for q in queries:
    for en, tpl in engines:
        u = tpl % urllib.parse.quote(q)
        txt = fetch(u, referer="https://%s/" % ("cn.bing.com" if "bing" in en else en+".com"))
        if not txt:
            print("[ERR] %s | %s" % (en, q)); continue
        found = []
        for m in re.finditer(r'href=["\']?(https?://[^"\'\s>]+)', txt):
            l = m.group(1)
            if any(b in l for b in ['bing.com','sogou.com','so.com','baidu.com','microsoft','javascript']): continue
            found.append(l)
        for m in re.finditer(r'href="(/link\?url=[^"]+)"', txt):
            found.append(urllib.parse.urljoin('https://www.sogou.com', m.group(1)))
        has = KW in txt
        print("[OK ] %-7s len=%6d kw=%s links=%d | %s" % (en, len(txt), has, len(found), q))
        if has:
            plain = strip_tags(txt)
            for mm in re.finditer(KW, plain):
                s=max(0,mm.start()-250); e=min(len(plain),mm.end()+450)
                print("     >>> ...%s..." % plain[s:e].replace(chr(10),' '))
        for l in found: alllinks[l] = alllinks.get(l,0)+1
        time.sleep(0.8)

seen=set(); uniq=[]
for l in sorted(alllinks, key=lambda x:-alllinks[x]):
    if l in seen: continue
    seen.add(l); uniq.append(l)
print("\nuniq links: %d" % len(uniq))

hits=[]
for i,l in enumerate(uniq[:30]):
    txt = fetch(l, timeout=18)
    if not txt: continue
    if KW in txt:
        plain = strip_tags(txt)
        fn = os.path.join(OUT, 'r3aimo2_%02d.txt' % i)
        with open(fn,'w',encoding='utf-8',errors='replace') as f: f.write(plain)
        print("\n### HIT %s -> %s (len=%d)" % (l[:100], os.path.basename(fn), len(plain)))
        for mm in re.finditer(KW, plain):
            s=max(0,mm.start()-300); e=min(len(plain),mm.end()+700)
            print("   ...%s..." % plain[s:e].replace(chr(10),' '))
        hits.append(fn)
    time.sleep(0.5)
print('\nHITS: %s' % hits)
