# -*- coding: utf-8 -*-
import sys, io, os, re, json
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

OUT = os.path.dirname(os.path.abspath(__file__))
KEY = ['化学','真题','试题','答案','解析','高考','2025','试卷','压轴','有机','工艺流程']
BAD = ['javascript:','bing.com','microsoft','.css','.js','.png','.jpg','.ico','privacy']

def strip_tags(s):
    s = re.sub(r'<script[\s\S]*?</script>','',s,flags=re.I)
    s = re.sub(r'<style[\s\S]*?</style>','',s,flags=re.I)
    s = re.sub(r'<[^>]+>',' ',s)
    for a,b in [('\u0026nbsp;',' '),('\u0026amp;','\u0026'),('\u0026quot;','"'),('\u0026#39;',"'"),('\u0026lt;','<'),('\u0026gt;','>')]:
        s = s.replace(a,b)
    return re.sub(r'\s+',' ',s).strip()

files = sorted([f for f in os.listdir(OUT) if f.endswith('.html')])
all_links = {}
for fn in files:
    p = os.path.join(OUT, fn)
    try:
        with open(p,'r',encoding='utf-8',errors='replace') as f:
            html = f.read()
    except Exception:
        continue
    links = []
    for m in re.finditer(r'<a\s[^>]*href=["\']([^"\']+)["\'][^>]*>([\s\S]*?)</a>', html, re.I):
        href, txt = m.group(1), strip_tags(m.group(2))
        if not href.startswith('http'):
            continue
        if any(b in href.lower() for b in BAD):
            continue
        if not txt:
            continue
        score = sum(1 for k in KEY if k in txt) + sum(1 for k in KEY if k in href)
        links.append({'url':href,'text':txt[:100],'score':score})
    links.sort(key=lambda x:-x['score'])
    all_links[fn] = links
    top = [l for l in links if l['score']>0][:30]
    print('\n===== %s  (total %d, relevant %d) =====' % (fn, len(links), len(top)))
    for l in top:
        print('  [%d] %s' % (l['score'], l['text'][:70]))
        print('      %s' % l['url'][:170])

with open(os.path.join(OUT,'r3_all_links.json'),'w',encoding='utf-8') as f:
    json.dump(all_links, f, ensure_ascii=False, indent=1)
print('\nsaved r3_all_links.json')
