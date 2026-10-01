# -*- coding: utf-8 -*-
"""多引擎 + 多教育站点探测"""
import sys, io, os, json
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
import urllib.request, urllib.parse, gzip, re

UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
OUTDIR = os.path.dirname(os.path.abspath(__file__))

def fetch(url, timeout=25, extra=None):
    h = {
        'User-Agent': UA,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
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

# 多引擎
engines = [
    ('ddg-html', 'https://html.duckduckgo.com/html/?q=' + urllib.parse.quote('2025高考物理 压轴题 原题')),
    ('ddg-lite', 'https://lite.duckduckgo.com/lite/?q=' + urllib.parse.quote('2025高考物理 压轴题')),
    ('baidu-m', 'https://m.baidu.com/s?word=' + urllib.parse.quote('2025高考物理压轴题')),
    ('yandex', 'https://yandex.com/search/?text=' + urllib.parse.quote('2025高考物理 压轴题 原题')),
    ('ecosia', 'https://www.ecosia.org/search?q=' + urllib.parse.quote('2025高考物理压轴题')),
]
for name, u in engines:
    st, txt = fetch(u)
    print('===== ENGINE %s ===== status=%s' % (name, st))
    if isinstance(txt, str):
        print('len:', len(txt))
        # 找标题/链接
        links = re.findall(r'https?://[^"\'<> ]{15,120}', txt)
        links = [l for l in links if any(k in l for k in ('gaokao', 'wuli', 'physics', 'zxxk', 'jyeoo', 'xkw', 'eol', 'zhihu', 'sohu', '163', 'baidu.com'))]
        print('rel links:', len(links))
        for l in links[:10]:
            print('   ', l)
        if '验证' in txt or 'verify' in txt.lower() or 'captcha' in txt.lower():
            print('  [ANTI-BOT DETECTED]')
        print(txt[:300].replace('\n', ' '))
    else:
        print(txt)
    print()

# 教育站点直接探测
sites = [
    ('zxxk', 'https://www.zxxk.com/'),
    ('jyeoo', 'https://www.jyeoo.com/'),
    ('xkw', 'https://zujuan.xkw.com/'),
    ('21cnjy', 'https://www.21cnjy.com/'),
    ('ks5u', 'https://www.ks5u.com/'),
    ('eol-gaokao', 'https://gaokao.eol.cn/'),
    ('zxxk-wl', 'https://www.zxxk.com/wuli/'),
]
print('\n########## EDUCATION SITES ##########')
for name, u in sites:
    st, txt = fetch(u)
    print('===== SITE %s ===== status=%s' % (name, st))
    if isinstance(txt, str):
        print('len:', len(txt), '| title:', (re.search(r'<title>(.*?)</title>', txt, re.S).group(1).strip() if re.search(r'<title>(.*?)</title>', txt, re.S) else 'N/A'))
    else:
        print(txt)
    print()
