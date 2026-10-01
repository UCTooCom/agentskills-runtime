# -*- coding: utf-8 -*-
import os, re, json, html

OUT = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(OUT, 'raw')

KEYS = ['压轴', '最后一题', '第25题', '15题', '物理', '真题', '解析']

def strip(s):
    s = re.sub(r'<[^>]+>', '', s)
    return html.unescape(s).strip()

def scan(fname):
    p = os.path.join(RAW, fname)
    if not os.path.exists(p):
        return []
    t = open(p, encoding='utf-8', errors='ignore').read()
    items = []
    # 360 / generic anchors
    for m in re.finditer(r'<a[^>]+href="(https?://[^"]+)"[^>]*>(.{0,200}?)</a>', t, re.S):
        u, txt = m.group(1), strip(m.group(2))
        if len(txt) < 6:
            continue
        if any(k in txt for k in KEYS):
            items.append({'title': txt[:120], 'url': u})
    # dedupe
    seen, out = set(), []
    for it in items:
        k = it['url'].split('?')[0]
        if k in seen:
            continue
        seen.add(k)
        out.append(it)
    return out

res = {}
for f in ['so360.html', 'so360b.html', 'so360c.html', 'toutiao.html', 'bili_api.html']:
    res[f] = scan(f)[:40]

with open(os.path.join(OUT, 'candidate_links.json'), 'w', encoding='utf-8') as fh:
    json.dump(res, fh, ensure_ascii=False, indent=1)

for k, v in res.items():
    print('==', k, len(v))
    for it in v[:12]:
        print('   -', it['title'][:70], '|', it['url'][:100])
