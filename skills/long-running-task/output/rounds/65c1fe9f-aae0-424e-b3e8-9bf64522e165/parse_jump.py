# -*- coding: utf-8 -*-
import os, re, json, ssl, html
import urllib.request, urllib.parse

OUT = os.path.dirname(os.path.abspath(__file__))
ctx = ssl.create_default_context(); ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE
HDRS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
    'Accept-Language': 'zh-CN,zh;q=0.9',
    'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
}


def collect_urls():
    urls = []
    for fn in ['toutiao.html', 'sogou.html']:
        p = os.path.join(OUT, fn)
        if not os.path.exists(p):
            continue
        raw = open(p, encoding='utf-8').read()
        raw = html.unescape(raw)
        for m in re.finditer(r'url=([^&"<> ]+)', raw):
            u = urllib.parse.unquote(m.group(1))
            if u.startswith('http'):
                urls.append(u)
        for m in re.finditer(r'https?://[^\s"<>]+', raw):
            u = m.group(0)
            if any(d in u for d in ['gaosan.com', '21cnjy', 'zxxk', 'gaokao.cn', 'eol.cn']):
                urls.append(u)
    seen, out = set(), []
    for u in urls:
        u = u.strip().replace('\\/', '/')
        if u in seen or not u.startswith('http'):
            continue
        if any(x in u for x in ['sogou.com', 'toutiao.com', '/search', '.css', '.js', '.png', '.jpg']):
            continue
        seen.add(u)
        out.append(u)
    return out


if __name__ == '__main__':
    us = collect_urls()
    print('TOTAL URLS', len(us))
    chem = [u for u in us if any(k in urllib.parse.unquote(u) for k in ['化学', 'huaxue', 'chem', 'hx'])]
    print(json.dumps(chem[:80], ensure_ascii=False, indent=2))
    open(os.path.join(OUT, 'urls.txt'), 'w', encoding='utf-8').write('\n'.join(us))
