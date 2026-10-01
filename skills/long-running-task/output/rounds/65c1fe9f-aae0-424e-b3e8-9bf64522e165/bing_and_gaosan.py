# -*- coding: utf-8 -*-
import sys, io, json, re, os, urllib.request, urllib.parse, gzip as _g, html as _h
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'

def get(url, ref=None, maxb=3_000_000):
    req = urllib.request.Request(url)
    req.add_header('User-Agent', UA)
    req.add_header('Accept-Language', 'zh-CN,zh;q=0.9')
    req.add_header('Accept-Encoding', 'gzip, deflate')
    if ref: req.add_header('Referer', ref)
    try:
        r = urllib.request.urlopen(req, timeout=25)
        d = r.read(maxb)
        if r.headers.get('Content-Encoding') == 'gzip': d = _g.decompress(d)
        enc = r.headers.get_content_charset() or 'utf-8'
        return r.status, d.decode(enc, 'ignore')
    except Exception as e:
        return -1, str(e)

def to_text(h):
    h = re.sub(r'<script[^>]*>.*?</script>', ' ', h, flags=re.S|re.I)
    h = re.sub(r'<style[^>]*>.*?</style>', ' ', h, flags=re.S|re.I)
    h = re.sub(r'<[^>]+>', ' ', h)
    return re.sub(r'\s+', ' ', _h.unescape(h)).strip()

# ===== 1. 解析 gaosan_ct 页面 =====
if os.path.exists('probe/gaosan_ct.html'):
    h = open('probe/gaosan_ct.html', encoding='utf-8', errors='ignore').read()
    t = to_text(h)
    print('===== GAOSAN_CT TEXT =====')
    print(t[:4000])
    links = re.findall(r'href="([^"]+)"[^>]*>([^<]*)<', h)
    good = [(u, _h.unescape(txt).strip()) for u, txt in links if ('gaokao/' in u or 'huaxue' in u.lower()) and txt.strip()]
    print('\n===== GAOSAN LINKS =====')
    for u, txt in good[:40]:
        print(u, '|', txt[:50])

# ===== 2. cn.bing.com 搜索 =====
os.makedirs('bing', exist_ok=True)
queries = [
    '2025年高考化学新课标卷真题及答案',
    '2025年高考化学全国卷压轴题最后一道大题',
    '2025年高考化学试题及答案 site:mp.weixin.qq.com',
]
allresults = {}
for i, q in enumerate(queries):
    url = 'https://cn.bing.com/search?q=' + urllib.parse.quote(q) + '&count=30'
    st, h = get(url)
    open('bing/q%d.html' % i, 'w', encoding='utf-8').write(h)
    # 解析结果
    items = []
    for m in re.finditer(r'<li class="b_algo".*?</li>', h, re.S):
        block = m.group(0)
        am = re.search(r'<h2>.*?<a[^>]*href="([^"]+)"[^>]*>(.*?)</a>', block, re.S)
        if not am: continue
        u = am.group(1)
        title = to_text(am.group(2))
        pm = re.search(r'<p[^>]*>(.*?)</p>', block, re.S)
        snip = to_text(pm.group(1)) if pm else ''
        items.append({'url': u, 'title': title, 'snippet': snip})
    allresults['q%d' % i] = {'query': q, 'status': st, 'n': len(items), 'items': items}
    print('\n===== BING q%d [%s] status=%s n=%d =====' % (i, q, st, len(items)))
    for it in items[:20]:
        print(it['url'])
        print('   ', it['title'][:80])
        if it['snippet']: print('   ', it['snippet'][:150])

json.dump(allresults, open('bing_results.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('\nDONE')
