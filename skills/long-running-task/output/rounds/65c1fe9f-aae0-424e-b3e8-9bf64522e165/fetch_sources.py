# -*- coding: utf-8 -*-
import sys, os, json, ssl, re, time
import urllib.request, urllib.parse

OUT = os.path.dirname(os.path.abspath(__file__))
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

HDRS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Referer': 'https://www.sogou.com/',
}

def fetch(url, timeout=25):
    req = urllib.request.Request(url, headers=HDRS)
    with urllib.request.urlopen(req, timeout=timeout, context=ctx) as r:
        raw = r.read()
        enc = r.headers.get_content_charset() or 'utf-8'
        try:
            return r.status, raw.decode(enc, 'ignore')
        except Exception:
            return r.status, raw.decode('utf-8', 'ignore')

def save(name, txt):
    p = os.path.join(OUT, name)
    with open(p, 'w', encoding='utf-8') as f:
        f.write(txt)
    print('saved', p, len(txt))

def extract_top_domains(txt, n=40):
    seen = []
    for m in re.finditer(r'(?:https?://|//)([a-z0-9\.\-]+\.[a-z]{2,})', txt, re.I):
        d = m.group(1).lower()
        if any(x in d for x in ['sogou','baidu','360','bing','w3.org','schema','gstatic','google','qq.com','sina','weibo','doubleclick','adservice']):
            continue
        if d not in seen:
            seen.append(d)
        if len(seen) >= n:
            break
    return seen

if __name__ == '__main__':
    q = sys.argv[1] if len(sys.argv) > 1 else '2025年高考化学试题及答案'
    qq = urllib.parse.quote(q)
    targets = [
        ('sogou.html', 'https://www.sogou.com/web?query=' + qq),
        ('so.html', 'https://www.so.com/s?q=' + qq),
        ('toutiao.html', 'https://so.toutiao.com/search?keyword=' + qq),
        ('zhihu.html', 'https://www.zhihu.com/search?type=content&q=' + qq),
        ('chsi.html', 'https://www.chsi.com.cn/'),
    ]
    report = {}
    for name, url in targets:
        try:
            st, txt = fetch(url)
            print('=== %s status=%s len=%d ===' % (name, st, len(txt)))
            save(name, txt)
            report[name] = extract_top_domains(txt)
        except Exception as e:
            print('=== %s ERROR %r ===' % (name, e))
            report[name] = 'ERROR: %r' % (e,)
    print('\n=== DOMAINS ===')
    print(json.dumps(report, ensure_ascii=False, indent=2))
