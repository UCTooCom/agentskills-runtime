# -*- coding: utf-8 -*-
import os, re, json, ssl, html, urllib.request

OUT = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(OUT, 'raw')
os.makedirs(RAW, exist_ok=True)

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE
H = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9',
}

def fetch(url, tag):
    try:
        req = urllib.request.Request(url, headers=H)
        with urllib.request.urlopen(req, timeout=30, context=ctx) as r:
            b = r.read()
        open(os.path.join(RAW, tag + '.html'), 'wb').write(b)
        t = b.decode('utf-8', 'ignore')
        # try gbk if messy
        if t.count('\ufffd') > len(t) * 0.02:
            t = b.decode('gbk', 'ignore')
        return {'tag': tag, 'ok': True, 'bytes': len(b), 'text': t}
    except Exception as e:
        return {'tag': tag, 'ok': False, 'err': str(e)[:180]}

def visible(t):
    t = re.sub(r'(?is)<(script|style|noscript)[^>]*>.*?</\1>', ' ', t)
    t = re.sub(r'(?s)<[^>]+>', ' ', t)
    t = html.unescape(t)
    t = re.sub(r'[ \t\r\f\v]+', ' ', t)
    t = re.sub(r'\n\s*\n+', '\n', t)
    return t.strip()

jobs = [
    ('mfpapers', 'https://www.mfpapers.com/'),
    ('wenku_zz', 'https://wenku.so.com/d/b66d201ac50229eb35e03ce4f53886d5'),
    ('wenku_b1', 'https://wenku.so.com/d/962a18f12bd39378052641e11755b370'),
    ('wenku_b2', 'https://wenku.so.com/d/ab1a98872eeee6033260d4f30223ce8d'),
]

out = {}
for tag, u in jobs:
    r = fetch(u, tag)
    if r.get('ok'):
        v = visible(r['text'])
        r['visible_len'] = len(v)
        r['has_formula'] = bool(re.search(r'[（(]\d+[）)]|如图|求|解|质量为|速度|加速度', v))
        open(os.path.join(RAW, tag + '.txt'), 'w', encoding='utf-8').write(v)
        out[tag] = {'len': len(v), 'kw': r['has_formula'], 'sample': v[:800]}
    else:
        out[tag] = r
    print('===', tag, json.dumps({k: out[tag][k] for k in out[tag] if k != 'sample'}, ensure_ascii=False))

json.dump(out, open(os.path.join(OUT, 'docs_dump.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
