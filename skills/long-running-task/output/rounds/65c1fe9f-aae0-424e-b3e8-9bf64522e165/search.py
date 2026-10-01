# -*- coding: utf-8 -*-
import sys, json, ssl, re
import urllib.request, urllib.parse

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

HDRS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    'Accept': 'text/html,application/xhtml+xml',
}

def fetch(url, timeout=30):
    req = urllib.request.Request(url, headers=HDRS)
    with urllib.request.urlopen(req, timeout=timeout, context=ctx) as r:
        raw = r.read()
        try:
            return r.status, raw.decode('utf-8', 'ignore')
        except Exception:
            return r.status, raw.decode('gbk', 'ignore')

def try_engine(name, url):
    try:
        st, txt = fetch(url)
        print('=== %s status=%s len=%d ===' % (name, st, len(txt)))
        return txt
    except Exception as e:
        print('=== %s ERROR: %r ===' % (name, e))
        return ''

def links(txt, kw=None, n=25):
    out = []
    for m in re.finditer(r'href="(https?://[^"]+)"[^>]*>(.*?)</a>', txt, re.S):
        href = m.group(1)
        title = re.sub(r'<[^>]+>', '', m.group(2))
        title = re.sub(r'\s+', ' ', title).strip()
        if not title:
            continue
        if kw and kw not in (title + href):
            continue
        out.append({'title': title[:120], 'href': href})
        if len(out) >= n:
            break
    return out

if __name__ == '__main__':
    q = sys.argv[1] if len(sys.argv) > 1 else '2025年高考化学压轴题'
    qq = urllib.parse.quote(q)
    engines = [
        ('ddg-html', 'https://html.duckduckgo.com/html/?q=' + qq),
        ('ddg-lite', 'https://lite.duckduckgo.com/lite/?q=' + qq),
        ('sogou', 'https://www.sogou.com/web?query=' + qq),
        ('baidu', 'https://www.baidu.com/s?wd=' + qq),
        ('so360', 'https://www.so.com/s?q=' + qq),
    ]
    for name, url in engines:
        txt = try_engine(name, url)
        if txt and ('result' in txt or '结果' in txt or len(txt) > 5000):
            print(json.dumps(links(txt)[:15], ensure_ascii=False, indent=2))
            break
