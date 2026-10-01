# -*- coding: utf-8 -*-
import os, re, json, ssl, urllib.request

OUT = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(OUT, 'raw')
IMG = os.path.join(OUT, 'imgs')
os.makedirs(IMG, exist_ok=True)

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE
H = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'Referer': 'https://image.so.com/',
}

recs = json.load(open(os.path.join(OUT, 'img_results.json'), encoding='utf-8'))
print('total recs:', len(recs))

KW = ['2025', '压轴', '高考', '物理', '最后一题', '全国卷', '真题']
cands = []
for r in recs:
    t = (r.get('title') or '')
    img = r.get('img') or ''
    if not img.startswith('http'):
        continue
    score = sum(1 for k in KW if k in t)
    if score > 0:
        cands.append((score, t, img))

cands.sort(key=lambda x: -x[0])
# dedupe by url
seen, uniq = set(), []
for s, t, u in cands:
    k = u.split('?')[0]
    if k in seen:
        continue
    seen.add(k)
    uniq.append((s, t, u))
print('uniq candidates:', len(uniq))

dl = []
for i, (s, t, u) in enumerate(uniq[:20]):
    try:
        req = urllib.request.Request(u, headers=H)
        with urllib.request.urlopen(req, timeout=25, context=ctx) as r:
            b = r.read()
        ext = '.jpg'
        if b[:8].startswith(b'\x89PNG'):
            ext = '.png'
        elif b[:3] == b'GIF':
            ext = '.gif'
        elif b[:4] == b'RIFF':
            ext = '.webp'
        p = os.path.join(IMG, 'img_%02d%s' % (i, ext))
        open(p, 'wb').write(b)
        dl.append({'i': i, 'score': s, 'title': t[:80], 'url': u, 'file': p, 'bytes': len(b)})
        print('OK', i, len(b), '|', t[:60])
    except Exception as e:
        print('ERR', i, str(e)[:90], '|', u[:80])

json.dump(dl, open(os.path.join(OUT, 'img_downloaded.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('downloaded:', len(dl))
