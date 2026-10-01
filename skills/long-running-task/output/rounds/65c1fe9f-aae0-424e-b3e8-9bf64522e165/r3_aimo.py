# -*- coding: utf-8 -*-
import sys, io, os, re, json, time, gzip, zlib, ssl, urllib.parse, hashlib
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

def fetch(url, timeout=25, referer=None):
    h = dict(H)
    if referer: h["Referer"] = referer
    try:
        req = urllib.request.Request(url, headers=h)
        with urllib.request.urlopen(req, timeout=timeout, context=CTX) as resp:
            return decode(resp)
    except Exception as e:
        return None, repr(e)[:120]

def strip_tags(s):
    s = re.sub(r'<script[\s\S]*?</script>','',s,flags=re.I)
    s = re.sub(r'<style[\s\S]*?</style>','',s,flags=re.I)
    s = re.sub(r'<!--[\s\S]*?-->','',s)
    s = re.sub(r'<(br|/p|/div|/li|/h[1-6]|/tr)[^>]*>','\n',s,flags=re.I)
    s = re.sub(r'<[^>]+>',' ',s)
    for a,b in [('&nbsp;',' '),('&amp;','&'),('&quot;','"'),('&#39;',"'"),('&lt;','<'),('&gt;','>')]:
        s = s.replace(a,b)
    s = re.sub(r'[ \t\xa0]+',' ',s)
    s = re.sub(r'\n{2,}','\n',s)
    return s.strip()

queries = [
    "2025高考化学 艾拉莫德 合成路线",
    "2025年高考化学 艾拉莫德 有机合成 答案",
    "2025新课标卷化学 艾拉莫德",
]
alllinks = []
for q in queries:
    u = "https://weixin.sogou.com/weixin?type=2&query=%s" % urllib.parse.quote(q)
    txt, err = fetch(u, referer="https://weixin.sogou.com/")
    if not txt:
        print("[ERR] %s -> %s" % (q, err)); continue
    print("[OK ] weixin search '%s' len=%d" % (q, len(txt)))
    for m in re.finditer(r'href="(/link\?url=[^"]+)"', txt):
        alllinks.append(urllib.parse.urljoin('https://weixin.sogou.com', m.group(1)))
    for m in re.finditer(r'<a[^>]+href="(https?://mp\.weixin\.qq\.com/[^"]+)"', txt):
        alllinks.append(m.group(1))
    time.sleep(1.0)

seen=set(); uniq=[]
for l in alllinks:
    if l not in seen:
        seen.add(l); uniq.append(l)
print("links: %d" % len(uniq))

found = []
for i, l in enumerate(uniq[:25]):
    txt, err = fetch(l, timeout=25)
    if not txt:
        continue
    plain = strip_tags(txt)
    if '艾拉莫德' in plain or '艾拉莫' in plain:
        sig = plain.count('艾拉莫德')
        print("\n### HIT [%d] 艾拉莫德 x%d  len=%d" % (i, sig, len(plain)))
        for m in re.finditer('艾拉莫德', plain):
            s=max(0,m.start()-300); e=min(len(plain),m.end()+600)
            print('   ...%s...' % plain[s:e].replace('\n',' '))
        fn = os.path.join(OUT, 'r3aimo_%02d.txt' % i)
        with open(fn,'w',encoding='utf-8',errors='replace') as f:
            f.write(plain)
        found.append(fn)
    time.sleep(0.6)

print('\nHIT files: %s' % found)
