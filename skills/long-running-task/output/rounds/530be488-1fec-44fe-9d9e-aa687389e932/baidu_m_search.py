# -*- coding: utf-8 -*-
"""抓取百度移动版搜索结果，解析标题/链接/摘要"""
import sys, io, os, json
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
import urllib.request, urllib.parse, gzip, re
from html.parser import HTMLParser

UA = 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1'
OUTDIR = os.path.dirname(os.path.abspath(__file__))

def fetch(url, timeout=25):
    req = urllib.request.Request(url, headers={
        'User-Agent': UA,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        'Referer': 'https://m.baidu.com/',
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
    s = re.sub(r'<[^>]+>', '', s)
    s = s.replace('&nbsp;', ' ').replace('&amp;', '&')
    return re.sub(r'\s+', ' ', s).strip()

class TextParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.texts = []
        self._skip = 0
    def handle_starttag(self, tag, attrs):
        if tag in ('script', 'style'):
            self._skip += 1
    def handle_endtag(self, tag):
        if tag in ('script', 'style') and self._skip > 0:
            self._skip -= 1
    def handle_data(self, data):
        if self._skip == 0:
            t = data.strip()
            if t:
                self.texts.append(t)

def visible_text(html):
    p = TextParser()
    try:
        p.feed(html)
    except Exception:
        pass
    return '\n'.join(p.texts)

queries = [
    '2025高考物理湖南卷压轴题原题',
    '2025年高考物理真题 压轴题 题干',
    '2025高考物理山东卷最后一题',
]

for q in queries:
    print('################ QUERY:', q)
    url = 'https://m.baidu.com/s?word=' + urllib.parse.quote(q)
    try:
        html = fetch(url)
        print('html_len:', len(html))
        if '安全验证' in html or 'wappass' in html.lower():
            print('[ANTI-BOT]')
        txt = visible_text(html)
        print('--- VISIBLE TEXT (first 2500 chars) ---')
        print(txt[:2500])
        # 提取可能的相关链接
        links = re.findall(r'https?://[^"\'<> ]{20,160}', html)
        links = list(dict.fromkeys(links))
        rel = [l for l in links if any(k in l for k in ('zxxk', 'jyeoo', 'xkw', '21cnjy', 'ks5u', 'eol', 'zhihu', 'sohu', '163.com', 'gaokao', 'wuli', 'shiti', 'baijiahao', 'baidu.com/s?'))]
        print('--- RELATED LINKS:', len(rel))
        for l in rel[:25]:
            print('   ', l)
    except Exception as e:
        print('ERROR:', e)
    print()
