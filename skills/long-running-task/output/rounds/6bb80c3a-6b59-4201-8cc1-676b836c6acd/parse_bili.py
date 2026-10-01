# -*- coding: utf-8 -*-
import os, re, json, html
OUT = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(OUT, 'raw')
p = os.path.join(RAW, 'bili_api.html')
t = open(p, encoding='utf-8', errors='ignore').read()
try:
    j = json.loads(t)
except Exception as e:
    print('not json:', e)
    j = None
res = []
if isinstance(j, dict):
    data = j.get('data', {})
    for r in data.get('result', []):
        for it in (r.get('data') or []):
            title = re.sub('<[^>]+>', '', html.unescape(it.get('title', '')))
            res.append({'title': title, 'author': it.get('author'), 'url': it.get('arcurl'), 'play': it.get('play')})
print(json.dumps(res[:30], ensure_ascii=False, indent=1))
json.dump(res, open(os.path.join(OUT, 'bili_results.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
