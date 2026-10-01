# -*- coding: utf-8 -*-
import os, json
OUT = os.path.dirname(os.path.abspath(__file__))
recs = json.load(open(os.path.join(OUT, 'img_results.json'), encoding='utf-8'))
KW = ['2025', '压轴', '高考', '物理', '最后一题', '全国卷', '真题']
rows = []
for r in recs:
    u = r.get('img') or ''
    if not u.startswith('http'):
        continue
    t = r.get('title') or ''
    try:
        s = sum(1 for k in KW if k in t)
    except Exception:
        s = 0
    rows.append((s, u))
rows.sort(key=lambda x: -x[0])
seen, uniq = set(), []
for s, u in rows:
    k = u.split('?')[0]
    if k in seen:
        continue
    seen.add(k)
    uniq.append((s, u))
for i, (s, u) in enumerate(uniq[:15]):
    print('%02d score=%d %s' % (i, s, u))
