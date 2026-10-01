# -*- coding: utf-8 -*-
import os, re, json, ssl, time, urllib.parse, urllib.request

OUT = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(OUT, 'raw')
os.makedirs(RAW, exist_ok=True)

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

H = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
}

def fetch(url, tag, timeout=25):
    try:
        req = urllib.request.Request(url, headers=H)
        with urllib.request.urlopen(req, timeout=timeout, context=ctx) as r:
            b = r.read()
        p = os.path.join(RAW, tag + '.html')
        with open(p, 'wb') as f:
            f.write(b)
        t = b.decode('utf-8', 'ignore')
        return {'tag': tag, 'url': url, 'ok': True, 'bytes': len(b), 'chars': len(t), 'file': p}
    except Exception as e:
        return {'tag': tag, 'url': url, 'ok': False, 'err': str(e)[:180]}

Q = urllib.parse.quote('2025年高考物理压轴题 最后一题 原题')
Q2 = urllib.parse.quote('2025全国乙卷物理压轴题 第25题')
Q3 = urllib.parse.quote('2025年高考物理全国卷压轴题 小球 木板 弹簧')

jobs = [
    ('bili_api', 'https://api.bilibili.com/x/web-interface/search/all/v2?keyword=' + Q),
    ('toutiao', 'https://so.toutiao.com/search?keyword=' + Q),
    ('so360', 'https://www.so.com/s?q=' + Q),
    ('so360b', 'https://www.so.com/s?q=' + Q2),
    ('so360c', 'https://www.so.com/s?q=' + Q3),
]

res = [fetch(u, t) for (t, u) in jobs]
print(json.dumps(res, ensure_ascii=False, indent=1))
