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
    'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9',
}

def fetch_raw(url, timeout=25):
    req = urllib.request.Request(url, headers=H)
    with urllib.request.urlopen(req, timeout=timeout, context=ctx) as r:
        return r.read(), r.geturl()

def visible(t):
    t = re.sub(r'(?is)<(script|style|noscript)[^>]*>.*?</\1>', ' ', t)
    t = re.sub(r'(?s)<[^>]+>', ' ', t)
    t = html.unescape(t)
    t = re.sub(r'[ \t\r\f\v]+', ' ', t)
    return t.strip()

KEYS = ['压轴', '最后一道', '最后一题', '第25题', '第15题', '真题', '题干']
PHYS = ['质量为', '速度', '加速度', '如图', '光滑', '摩擦', '求', '磁场', '电场', '守恒', '小球']

cands = []
for fn in ['so360.html', 'so360b.html', 'so360c.html']:
    p = os.path.join(RAW, fn)
    if not os.path.exists(p):
        continue
    t = open(p, encoding='utf-8', errors='ignore').read()
    # 360 result blocks carry data-url or href to article + title text
    for m in re.finditer(r'href="(https?://[^"]+)"[^>]*>(.{4,200}?)</a>', t, re.S):
        u = html.unescape(m.group(1))
        title = visible(m.group(2))
        if any(k in title for k in KEYS) or 'so.com/link' in u:
            cands.append({'title': title[:100], 'url': u})

# dedupe
seen, uniq = set(), []
for c in cands:
    key = c['url'][:60]
    if key in seen:
        continue
    seen.add(key)
    uniq.append(c)
print('candidates:', len(uniq))

results = []
for i, c in enumerate(uniq[:25]):
    try:
        b, final = fetch_raw(c['url'])
        t = b.decode('utf-8', 'ignore')
        if t.count('\ufffd') > len(t) * 0.02:
            t = b.decode('gbk', 'ignore')
        v = visible(t)
        hit = sum(1 for k in KEYS if k in v) + sum(1 for k in PHYS if k in v)
        results.append({'i': i, 'title': c['title'], 'url': c['url'], 'final': final,
                        'vlen': len(v), 'hits': hit, 'sample': v[:300]})
        fn = 'art_%02d.txt' % i
        open(os.path.join(RAW, fn), 'w', encoding='utf-8').write('TITLE: ' + c['title'] + '\nURL: ' + c['url'] + '\nFINAL: ' + final + '\n\n' + v)
    except Exception as e:
        results.append({'i': i, 'title': c['title'], 'url': c['url'], 'err': str(e)[:150]})

results.sort(key=lambda x: -x.get('hits', -1))
json.dump(results, open(os.path.join(OUT, 'harvest_result.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
for r in results[:15]:
    print(r.get('hits'), '|', r.get('vlen'), '|', r.get('title', '')[:60], '|', r.get('final', r.get('err', ''))[:70])
