# -*- coding: utf-8 -*-
import sys, os, json, time, re, ssl
sys.stdout.reconfigure(encoding='utf-8')
import urllib.request, urllib.parse

BASE = r"D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime/skills/long-running-task/output"
OUT = os.path.join(BASE, "rounds", "a298ea47-8af2-4432-8180-21f62c2b8b72")
os.makedirs(OUT, exist_ok=True)

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

def fetch(url, timeout=20):
    req = urllib.request.Request(url, headers={
        "User-Agent": UA,
        "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Connection": "close",
    })
    try:
        with urllib.request.urlopen(req, timeout=timeout, context=ctx) as r:
            return r.status, r.read()
    except Exception as e:
        return None, ("ERR: " + repr(e)[:200]).encode('utf-8')

q = "2025\u5e74\u5317\u4eac\u5377\u9ad8\u8003\u7269\u7406\u7b2c20\u9898 \u771f\u9898 \u9898\u5e72"
candidates = [
    "https://www.bing.com/search?q=" + urllib.parse.quote(q),
    "https://search.marcia.com/?q=" + urllib.parse.quote(q),
    "https://duckduckgo.com/html/?q=" + urllib.parse.quote(q),
    "https://lite.duckduckgo.com/lite/?q=" + urllib.parse.quote(q),
    "https://www.ecosia.org/search?q=" + urllib.parse.quote(q),
    "https://search.brave.com/search?q=" + urllib.parse.quote(q),
    "https://www.mojeek.com/search?q=" + urllib.parse.quote(q),
    "https://www.startpage.com/sp/search?query=" + urllib.parse.quote(q),
    "https://zh.wikipedia.org/wiki/\u9ad8\u7b49\u5b66\u6821\u62db\u751f\u5168\u56fd\u7edf\u4e00\u8003\u8bd5",
]

log = []
for url in candidates:
    st, data = fetch(url)
    txt = data.decode('utf-8', 'replace')
    info = {"url": url, "status": st, "len": len(txt), "head": txt[:200].replace('\n', ' ')}
    log.append(info)
    print(f"[{st}] len={len(txt):>7}  {url[:90]}")
    # save any promising results
    if st == 200 and len(txt) > 5000:
        fn = os.path.join(OUT, "raw_probe_" + re.sub(r'\W+', '_', url.split('/')[2])[:30] + ".html")
        try:
            with open(fn, 'w', encoding='utf-8') as fh:
                fh.write(txt)
        except Exception:
            pass
    time.sleep(1)

with open(os.path.join(OUT, "direct_probe_log.json"), 'w', encoding='utf-8') as fh:
    json.dump(log, fh, ensure_ascii=False, indent=1)
print("\nLOG SAVED: direct_probe_log.json")
