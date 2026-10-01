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


QUERIES = [
    '2025年高考化学真题 有机合成 推断题',
    '2025高考化学 全国甲卷 试题及答案 解析',
    '2025年高考化学 化学反应原理 大题 真题',
]


def bing_links(q):
    url = 'https://cn.bing.com/search?q=' + urllib.parse.quote(q) + '&ensearch=0'
    try:
        st, fin, txt = fetch(url)
    except Exception as e:
        return 'BINGERR:%r' % (e,)
    out = []
    for m in re.finditer(r'<h2><a[^>]+href="([^"]+)"[^>]*>(.*?)</a>', txt, re.S):
        href = html.unescape(m.group(1)); title = re.sub(r'<[^>]+>', '', m.group(2)).strip()
        out.append({'title': title, 'href': href})
    return {'st': st, 'len': len(txt), 'items': out[:15]}


if __name__ == '__main__':
    rep = {}
    for q in QUERIES:
        rep[q] = bing_links(q)
        print('====', q, '====')
        print(json.dumps(rep[q], ensure_ascii=False, indent=2)[:2500])
    json.dump(rep, open(os.path.join(OUT, 'bing_report.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
