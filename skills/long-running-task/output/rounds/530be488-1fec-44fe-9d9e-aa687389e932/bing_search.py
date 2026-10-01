# -*- coding: utf-8 -*-
"""用 Bing 检索 2025 高考物理压轴题，解析结果标题/链接/摘要"""
import sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
import urllib.request, urllib.parse, gzip, re
from html.parser import HTMLParser

UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'

def fetch(url, timeout=25):
    req = urllib.request.Request(url, headers={
        'User-Agent': UA,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
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

def strip_tags(s):
    return re.sub(r'<[^>]+>', '', s).strip()

def bing_search(q, count=15):
    url = 'https://cn.bing.com/search?q=' + urllib.parse.quote(q) + '&count=%d&setlang=zh-CN' % count
    html = fetch(url)
    # 解析 <li class="b_algo"> 块
    items = []
    for block in re.findall(r'<li class="b_algo".*?</li>', html, re.S):
        m = re.search(r'<h2[^>]*>\s*<a[^>]*href="([^"]+)"[^>]*>(.*?)</a>', block, re.S)
        if not m:
            continue
        link = m.group(1)
        title = strip_tags(m.group(2))
        # 摘要
        pm = re.search(r'<p[^>]*>(.*?)</p>', block, re.S)
        snippet = strip_tags(pm.group(1)) if pm else ''
        items.append((title, link, snippet))
    return items

queries = [
    '2025年高考物理压轴题 原题 题干',
    '2025高考物理 山东卷 压轴题 第18题',
    '2025高考物理 湖南卷 压轴题 题干',
    '2025年高考物理真题 压轴题 最后一道大题',
]

for q in queries:
    print('############ QUERY:', q)
    try:
        items = bing_search(q)
        for i, (t, l, s) in enumerate(items[:12]):
            print('[%d] %s' % (i, t))
            print('    URL:', l)
            print('    SNIP:', s[:300])
            print()
    except Exception as e:
        print('ERROR:', e)
    print()
