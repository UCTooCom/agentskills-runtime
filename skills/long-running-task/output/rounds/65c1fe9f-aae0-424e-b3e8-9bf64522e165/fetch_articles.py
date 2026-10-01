# -*- coding: utf-8 -*-
import os, re, json, ssl, html
import urllib.request

OUT = os.path.dirname(os.path.abspath(__file__))
ctx = ssl.create_default_context(); ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE
HDRS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
    'Accept-Language': 'zh-CN,zh;q=0.9',
    'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
}

TARGETS = [
    ('gaosan_1125274', 'http://www.gaosan.com/gaokao/1125274.html'),
    ('gaosan_1125350', 'http://www.gaosan.com/gaokao/1125350.html'),
    ('cnjy_23616335', 'https://m.21cnjy.com/H/23616335.shtml'),
    ('zxxk_3508877', 'https://m.zxxk.com/docpack/3508877.html'),
]


def fetch(url, timeout=25):
    req = urllib.request.Request(url, headers=HDRS)
    with urllib.request.urlopen(req, timeout=timeout, context=ctx) as r:
        raw = r.read(); enc = r.headers.get_content_charset() or 'utf-8'
        try:
            return r.status, r.geturl(), raw.decode(enc, 'ignore')
        except Exception:
            return r.status, r.geturl(), raw.decode('utf-8', 'ignore')


def text_of(t):
    t = re.sub(r'(?is)<script.*?</script>', ' ', t)
    t = re.sub(r'(?is)<style.*?</style>', ' ', t)
    t = re.sub(r'(?is)<br\s*/?>', '\n', t)
    t = re.sub(r'(?is)</(p|div|li|tr|h[1-6]|td)>', '\n', t)
    t = re.sub(r'(?is)<[^>]+>', ' ', t)
    t = html.unescape(t)
    t = re.sub(r'[ \t\r\f\v\u3000]+', ' ', t)
    t = re.sub(r'\n\s*\n+', '\n', t)
    return t.strip()


if __name__ == '__main__':
    rep = {}
    for name, url in TARGETS:
        try:
            st, fin, raw = fetch(url)
            open(os.path.join(OUT, name + '.html'), 'w', encoding='utf-8').write(raw)
            txt = text_of(raw)
            open(os.path.join(OUT, name + '.txt'), 'w', encoding='utf-8').write(txt)
            rep[name] = {'status': st, 'final': fin, 'len': len(raw), 'tlen': len(txt), 'has_chem': ('化学' in txt), 'sample': txt[:400]}
            print('===', name, st, len(raw), len(txt), 'chem=', '化学' in txt)
        except Exception as e:
            rep[name] = {'error': repr(e)}
            print('===', name, 'ERR', repr(e))
    json.dump(rep, open(os.path.join(OUT, 'articles_report.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
