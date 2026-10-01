# -*- coding: utf-8 -*-
import sys, json, ssl, urllib.parse, urllib.request

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

H = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36',
    'Accept-Language': 'zh-CN,zh;q=0.9',
}

def get(u, enc='utf-8'):
    try:
        req = urllib.request.Request(u, headers=H)
        with urllib.request.urlopen(req, timeout=20, context=ctx) as r:
            b = r.read()
        t = b.decode(enc, 'ignore')
        return {'url': u, 'code': 200, 'len': len(t), 'head': t[:600]}
    except Exception as e:
        return {'url': u, 'err': str(e)[:200]}

q = urllib.parse.quote('2025年高考物理压轴题 最后一题 原题')
targets = [
    'https://www.sogou.com/web?query=' + q,
    'https://www.baidu.com/s?wd=' + q,
    'https://cn.bing.com/search?q=' + q,
]
out = []
for t in targets:
    out.append(get(t))
print(json.dumps(out, ensure_ascii=False, indent=2)[:8000])
