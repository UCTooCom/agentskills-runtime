# -*- coding: utf-8 -*-
import sys, os, json, time, re
sys.stdout.reconfigure(encoding='utf-8')
import urllib.request, urllib.parse

OUT = r"D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime/skills/long-running-task/output/rounds/a298ea47-8af2-4432-8180-21f62c2b8b72"
os.makedirs(OUT, exist_ok=True)

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"

def fetch(url, timeout=30):
    req = urllib.request.Request(url, headers={
        "User-Agent": UA,
        "Accept-Language": "zh-CN,zh;q=0.9",
        "Accept": "text/html,application/xhtml+xml,*/*;q=0.8",
    })
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            data = r.read()
            return r.status, data
    except Exception as e:
        return None, ("ERR: " + repr(e)).encode('utf-8')

queries = [
    "2025\u5317\u4eac\u5377\u7269\u7406\u7b2c20\u9898 \u9759\u7535\u9664\u5c18\u5668",
    "2025\u5317\u4eac\u7269\u7406\u7b2c20\u9898 \u539f\u9898 \u8f90\u5411\u7535\u573a",
]

report = {}
# 1) try r.jina.ai text proxy over a search engine
for q in queries:
    for eng in [
        "https://www.baidu.com/s?wd=",
        "https://www.sogou.com/web?query=",
        "https://www.so.com/s?q=",
    ]:
        target = eng + urllib.parse.quote(q)
        proxied = "https://r.jina.ai/" + target
        st, data = fetch(proxied, timeout=40)
        txt = data.decode('utf-8', 'replace')
        key = "JINA|" + eng
        report[key + "|" + q[:12]] = {"status": st, "len": len(txt)}
        fn = os.path.join(OUT, "jina_" + re.sub(r'\W+', '_', key)[:40] + "_" + q[:6] + ".txt")
        try:
            with open(fn, 'w', encoding='utf-8') as fh:
                fh.write(txt)
        except Exception:
            pass
        print(f"[{st}] {len(txt):>7}  {key}  <- {q[:20]}")

print(json.dumps(report, ensure_ascii=False, indent=1))
