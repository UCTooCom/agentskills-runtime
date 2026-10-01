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

def fetch(name, url, timeout=25):
    try:
        req = urllib.request.Request(url, headers=H)
        with urllib.request.urlopen(req, timeout=timeout, context=CTX) as resp:
            txt, cs = decode(resp)
        with open(os.path.join(OUT, 'r3e_%s.html' % name), 'w', encoding='utf-8', errors='replace') as f:
            f.write(txt)
        chem = sum(1 for kw in ['化学','有机','真题','答案','解析'] if kw in txt)
        print("[OK ] %-16s len=%7d cs=%s chem=%d" % (name, len(txt), cs, chem))
        return txt
    except Exception as e:
        print("[ERR] %-16s %s" % (name, repr(e)[:120]))
        return None

def strip_tags(s):
    s = re.sub(r'<script[\s\S]*?</script>','',s,flags=re.I)
    s = re.sub(r'<style[\s\S]*?</style>','',s,flags=re.I)
    s = re.sub(r'<[^>]+>',' ',s)
    for a,b in [('&nbsp;',' '),('&amp;','&')]:
        s = s.replace(a,b)
    return re.sub(r'\s+',' ',s).strip()

Q = urllib.parse.quote("2025年高考化学真题及答案解析")
Q2 = urllib.parse.quote("2025高考化学 有机 压轴 试题")

targets = [
    ("ddg_html", "https://html.duckduckgo.com/html/?q=%s" % Q),
    ("ddg_lite", "https://lite.duckduckgo.com/lite/?q=%s" % Q),
    ("wx_sogou", "https://weixin.sogou.com/weixin?type=2&query=%s" % Q2),
    ("toutiao_so", "https://so.toutiao.com/search?keyword=%s" % Q),
    ("mojeek", "https://www.mojeek.com/search?q=%s" % Q),
    ("yandex", "https://yandex.com/search/?text=%s" % Q),
    ("brave", "https://search.brave.com/search?q=%s" % Q),
]
res = {}
for n, u in targets:
    t = fetch(n, u)
    res[n] = len(t) if t else 0
    if t:
        plain = strip_tags(t)
        for kw in ['gaosan','21cnjy','doc88','book118','renrendoc','docin','zxxk','eol.cn','hx']:
            if kw in plain:
                n2 = len(re.findall(kw, plain))
                print('     contains %s x%d' % (kw, n2))
    time.sleep(1.0)
print(json.dumps(res, ensure_ascii=False, indent=1))
