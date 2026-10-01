# -*- coding: utf-8 -*-
import os, re, json, ssl, html, urllib.parse, urllib.request

OUT = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(OUT, 'raw')
os.makedirs(RAW, exist_ok=True)
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE
H = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'Accept-Language': 'zh-CN,zh;q=0.9',
    'Referer': 'https://image.so.com/',
}

def get(u, timeout=25):
    req = urllib.request.Request(u, headers=H)
    with urllib.request.urlopen(req, timeout=timeout, context=ctx) as r:
        return r.read()

queries = [
    '2025年高考物理压轴题 最后一题 原题',
    '2025全国卷高考物理压轴题真题',
]
imgs = []
for q in queries:
    for pn in [0, 30]:
        u = 'https://image.so.com/j?q=%s&pn=%d&src=srp' % (urllib.parse.quote(q), pn)
        try:
            b = get(u)
            t = b.decode('utf-8', 'ignore')
            fn = 'img_%d_%d.json' % (len(queries), pn)
            try:
                j = json.loads(t)
                for it in j.get('list', []):
                    imgs.append({'title': it.get('title', ''), 'img': it.get('img') or it.get('imgurl'),
                                 'thumb': it.get('thumb'), 'from': it.get('fromurl') or it.get('from')})
            except Exception as e:
                imgs.append({'err': str(e)[:100], 'raw_head': t[:200]})
        except Exception as e:
            imgs.append({'err': str(e)[:150], 'u': u})

json.dump(imgs, open(os.path.join(OUT, 'img_results.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('total imgs:', len(imgs))
for it in imgs[:25]:
    print('-', str(it.get('title'))[:60], '|', str(it.get('img') or it.get('err'))[:110])
