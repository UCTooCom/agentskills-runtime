# -*- coding: utf-8 -*-
"""使用 Bing RSS 输出获取真实检索结果"""
import sys, io, os, json
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
import urllib.request, urllib.parse, gzip, re

UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
OUTDIR = os.path.dirname(os.path.abspath(__file__))

def fetch(url, timeout=25):
    req = urllib.request.Request(url, headers={
        'User-Agent': UA,
        'Accept': 'application/rss+xml,application/xml,text/xml,*/*;q=0.9',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
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

def parse_rss(xml):
    items = []
    for m in re.finditer(r'<item>(.*?)</item>', xml, re.S):
        block = m.group(1)
        def g(tag):
            mm = re.search(r'<%s>(.*?)</%s>' % (tag, tag), block, re.S)
            return mm.group(1) if mm else ''
        t = re.sub(r'<!\[CDATA\[(.*?)\]\]>', r'\1', g('title'))
        l = g('link')
        d = re.sub(r'<!\[CDATA\[(.*?)\]\]>', r'\1', g('description'))
        d = re.sub(r'<[^>]+>', '', d)
        items.append({'title': re.sub(r'\s+', ' ', t).strip(), 'url': l.strip(), 'desc': re.sub(r'\s+', ' ', d).strip()})
    return items

queries = [
    '2025年高考物理真题 压轴题',
    '2025 湖南卷 物理 压轴题',
    '2025高考物理 山东卷 最后一道大题',
    '2025年高考物理 全国卷 试题及答案',
]

allres = {}
for q in queries:
    url = 'https://www.bing.com/search?q=' + urllib.parse.quote(q) + '&format=rss&count=20'
    try:
        xml = fetch(url)
        items = parse_rss(xml)
        allres[q] = items
        print('#### QUERY:', q, '-> items:', len(items), 'xml_len:', len(xml))
        for it in items[:12]:
            print('  -', it['title'])
            print('    ', it['url'])
            print('    >>', it['desc'][:200])
        if not items:
            print('  RAW HEAD:', xml[:500].replace('\n', ' '))
    except Exception as e:
        print('#### QUERY:', q, 'ERROR:', e)
    print()

with open(os.path.join(OUTDIR, 'bing_rss_results.json'), 'w', encoding='utf-8') as f:
    json.dump(allres, f, ensure_ascii=False, indent=2)
print('saved bing_rss_results.json')
