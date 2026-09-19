# -*- coding: utf-8 -*-
import os, io, json, urllib.request, ssl
BASE = os.path.dirname(os.path.abspath(__file__))
IMG = os.path.join(BASE, "t1", "img")
os.makedirs(IMG, exist_ok=True)
CTX = ssl.create_default_context()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE
HDR = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0 Safari/537.36", "Accept-Language": "zh-CN,zh;q=0.9", "Referer": "http://gaokao.eol.cn/"}
res = []
for tag in ("qg1", "qg2"):
    for i in range(1, 31):
        u = "https://img.eol.cn/e_images/gk/2025/st/%s/sx%02d.png" % (tag, i)
        fn = "%s_sx%02d.png" % (tag, i)
        fp = os.path.join(IMG, fn)
        if os.path.exists(fp) and os.path.getsize(fp) > 1000:
            res.append({"tag": tag, "idx": i, "file": fn, "bytes": os.path.getsize(fp), "cached": True})
            continue
        try:
            req = urllib.request.Request(u, headers=HDR)
            with urllib.request.urlopen(req, timeout=15, context=CTX) as r:
                data = r.read()
            if len(data) > 1000:
                with open(fp, "wb") as f:
                    f.write(data)
                res.append({"tag": tag, "idx": i, "file": fn, "bytes": len(data)})
        except Exception as e:
            pass
print("TOTAL_OK=%d" % len(res))
for r in res:
    print("IMG|%s|sx%02d|%d" % (r["tag"], r["idx"], r["bytes"]))
with io.open(os.path.join(BASE, "t1", "img_index.json"), "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=2)
