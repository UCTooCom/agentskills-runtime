# -*- coding: utf-8 -*-
"""综合探测：Bing 调试 + 直接抓取候选教育站点"""
import sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
import urllib.request, urllib.parse, gzip, re

UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'

def fetch(url, timeout=25, extra=None):
    h = {
        'User-Agent': UA,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        'Referer': 'https://cn.bing.com/',
    }
    if extra:
        h.update(extra)
    req = urllib.request.Request(url, headers=h)
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

# 1) Bing 调试
print('===== BING DEBUG =====')
q = '2025年高考物理真题 湖南卷 压轴题'
url = 'https://cn.bing.com/search?q=' + urllib.parse.quote(q)
st, html = fetch(url)
print('status:', st, 'len:', len(html) if isinstance(html, str) else html)
if isinstance(html, str):
    # 打印搜索框 value 确认查询被接收
    m = re.search(r'<input[^>]*name="q"[^>]*value="([^"]*)"', html)
    print('echoed q:', m.group(1) if m else 'N/A')
    print('has b_algo:', html.count('b_algo'))
    print(html[:1500].replace('\n', ' '))
print()

# 2) 直接抓取候选教育站点
urls = [
    ('51test', 'https://www.51test.net/gaokao/wuli/shiti/'),
    ('gaokao-com', 'https://www.gaokao.com/e/20250610/'),
    ('diyifanwen', 'https://www.diyifanwen.com/zuowen/gaokaozuowen/'),
    ('oh100', 'https://www.oh100.com/'),
    ('sogou-weixin', 'https://weixin.sogou.com/weixin?type=2&query=' + urllib.parse.quote('2025高考物理湖南卷压轴题')),
    ('baidu-baike', 'https://baike.baidu.com/item/2025%E5%B9%B4%E6%99%AE%E9%80%9A%E9%AB%98%E7%AD%89%E5%AD%A6%E6%A0%A1%E6%8B%9B%E7%94%9F%E5%85%A8%E5%9B%BD%E7%BB%9F%E4%B8%80%E8%80%83%E8%AF%95'),
]
for name, u in urls:
    st, txt = fetch(u)
    print('===== %s ===== status=%s' % (name, st))
    if isinstance(txt, str):
        print('len:', len(txt))
        print(txt[:400].replace('\n', ' '))
    else:
        print(txt)
    print()
