# -*- coding: utf-8 -*-
import sys, io, os, re, json, time, gzip, zlib, ssl
import urllib.request, urllib.parse
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

OUT = os.path.dirname(os.path.abspath(__file__))
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
H = {"User-Agent": UA, "Accept": "text/plain,text/html,*/*", "Accept-Language": "zh-CN,zh;q=0.9", "Accept-Encoding": "gzip, deflate", "Connection": "close"}
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
    return data.decode('utf-8', errors='replace')

def jina(target, name, timeout=45):
    url = "https://r.jina.ai/" + target
    try:
        req = urllib.request.Request(url, headers=H)
        with urllib.request.urlopen(req, timeout=timeout, context=CTX) as resp:
            txt = decode(resp)
        with open(os.path.join(OUT, 'r3j_%s.txt' % name), 'w', encoding='utf-8', errors='replace') as f:
            f.write(txt)
        sig = sum(1 for kw in ['化学','有机','mol','溶液','反应','合成','答案','解析','方程式'] if kw in txt)
        print("[OK ] %-14s len=%7d sig=%d" % (name, len(txt), sig))
        return txt
    except Exception as e:
        print("[ERR] %-14s %s" % (name, repr(e)[:130]))
        return None

targets = [
    ("gaosan_1124039", "https://www.gaosan.com/gaokao/1124039.html"),
    ("gaosan_1125274", "https://www.gaosan.com/gaokao/1125274.html"),
    ("gaosan_1125350", "https://www.gaosan.com/gaokao/1125350.html"),
    ("gaosan_chem", "https://www.gaosan.com/gaokao/chem/"),
    ("eol_gkst", "https://www.eol.cn/kaoshi/gaokao/gkst/"),
    ("21cnjy_31070", "https://www.21cnjy.com/2/31070/"),
]
res = {}
for n, t in targets:
    x = jina(t, n)
    res[n] = len(x) if x else 0
    time.sleep(1.0)
print(json.dumps(res, ensure_ascii=False, indent=1))
