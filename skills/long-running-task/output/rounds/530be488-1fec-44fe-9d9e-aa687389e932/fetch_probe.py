# -*- coding: utf-8 -*-
"""探测多个数据源，抓取 2025 年高考物理压轴题题干（使用 urllib 标准库）"""
import sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
import urllib.request, urllib.parse, gzip, io as _io

UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'

def fetch(url, timeout=20):
    req = urllib.request.Request(url, headers={
        'User-Agent': UA,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    })
    try:
        resp = urllib.request.urlopen(req, timeout=timeout)
        raw = resp.read()
        if resp.headers.get('Content-Encoding') == 'gzip':
            raw = gzip.decompress(raw)
        for enc in ('utf-8', 'gbk', 'gb18030'):
            try:
                return resp.status, raw.decode(enc)
            except Exception:
                continue
        return resp.status, raw.decode('utf-8', 'replace')
    except Exception as e:
        return 'ERR', str(e)

targets = [
    ('bing', 'https://cn.bing.com/search?q=2025%E5%B9%B4%E9%AB%98%E8%80%83%E7%89%A9%E7%90%86%E5%8E%8B%E8%BD%B4%E9%A2%98%E9%A2%98%E5%B9%B2'),
    ('sogou', 'https://www.sogou.com/web?query=2025%E5%B9%B4%E9%AB%98%E8%80%83%E7%89%A9%E7%90%86%E5%8E%8B%E8%BD%B4%E9%A2%98'),
    ('google', 'https://www.google.com/search?q=2025%E5%B9%B4%E9%AB%98%E8%80%83%E7%89%A9%E7%90%86%E5%8E%8B%E8%BD%B4%E9%A2%98'),
    ('zhihu', 'https://www.zhihu.com/search?type=content&q=2025%E9%AB%98%E8%80%83%E7%89%A9%E7%90%86%E5%8E%8B%E8%BD%B4%E9%A2%98'),
]

for name, url in targets:
    st, txt = fetch(url)
    print('===== %s ===== status=%s len=%s' % (name, st, len(txt) if isinstance(txt, str) else '?'))
    if isinstance(txt, str):
        print(txt[:600].replace('\n', ' '))
    else:
        print(txt)
    print()
