# -*- coding: utf-8 -*-
"""稳健解析 Bing 结果，导出标题/链接/摘要，并保存原始 HTML"""
import sys, io, os, json
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
import urllib.request, urllib.parse, gzip, re

UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
OUTDIR = os.path.dirname(os.path.abspath(__file__))

def fetch(url, timeout=25):
    req = urllib.request.Request(url, headers={
        'User-Agent': UA,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        'Referer': 'https://cn.bing.com/',
    })
    resp = urllib.request.urlopen(req, timeout=timeout)
    raw = resp.read()
    if resp.headers.get('Content-Encoding') == 'gzip':
        raw = gzip.decompress(raw)
    for enc in ('utf-8', 'gbk', 'gb18030'):
        try:
            return raw.decode(enc)
        except Exception:
            continue
    return raw.decode('utf-8', 'replace')

def strip_tags(s):
    s = re.sub(r'<[^>]+>', '', s)
    s = s.replace('&nbsp;', ' ').replace('&amp;', '&').replace('&quot;', '"')
    return re.sub(r'\s+', ' ', s).strip()

def parse_bing(html):
    items = []
    blocks = re.findall(r'<li class="b_algo".*?</li>', html, re.S)
    if not blocks:
        blocks = re.findall(r'<h2>.*?</h2>.*?(?=<li class="b_algo"|<li class="b_ans)', html, re.S)
    for block in blocks:
        m = re.search(r'<h2[^>]*>\s*<a[^>]*href="(http[^"]+)"[^>]*>(.*?)</a>', block, re.S)
        if not m:
            m = re.search(r'<a[^>]*href="(http[^"]+)"[^>]*>(.*?)</a>', block, re.S)
        if not m:
            continue
        link, title = m.group(1), strip_tags(m.group(2))
        pm = re.search(r'<p[^>]*>(.*?)</p>', block, re.S)
        snippet = strip_tags(pm.group(1)) if pm else ''
        items.append({'title': title, 'url': link, 'snippet': snippet})
    return items

queries = [
    '2025年高考物理真题 压轴题',
    '2025高考物理湖南卷最后一题',
    '2025年高考物理全国卷18题',
]

allres = {}
for q in queries:
    url = 'https://cn.bing.com/search?q=' + urllib.parse.quote(q)
    try:
        html = fetch(url)
        items = parse_bing(html)
        allres[q] = items
        print('#### QUERY:', q, '-> results:', len(items))
        for it in items[:10]:
            print('  -', it['title'])
            print('    ', it['url'])
            print('    >>', it['snippet'][:200])
        # 保存原始 HTML
        fn = os.path.join(OUTDIR, 'bing_raw_%s.html' % str(abs(hash(q)))[:6])
        with open(fn, 'w', encoding='utf-8') as f:
            f.write(html)
    except Exception as e:
        print('#### QUERY:', q, 'ERROR:', e)
    print()

with open(os.path.join(OUTDIR, 'bing_results.json'), 'w', encoding='utf-8') as f:
    json.dump(allres, f, ensure_ascii=False, indent=2)
print('saved bing_results.json')