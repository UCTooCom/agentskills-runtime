# -*- coding: utf-8 -*-
import sys, io, json, urllib.request, urllib.parse, gzip, io as _io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'

def get(url, referer=None):
    req = urllib.request.Request(url)
    req.add_header('User-Agent', UA)
    req.add_header('Accept-Language', 'zh-CN,zh;q=0.9')
    req.add_header('Accept-Encoding', 'gzip, deflate')
    if referer:
        req.add_header('Referer', referer)
    try:
        r = urllib.request.urlopen(req, timeout=25)
        data = r.read()
        if r.headers.get('Content-Encoding') == 'gzip':
            data = gzip.decompress(data)
        enc = r.headers.get_content_charset() or 'utf-8'
        return r.status, data.decode(enc, 'ignore')
    except Exception as e:
        return -1, str(e)

q1 = '2025年高考化学新课标卷真题及答案'
q2 = '2025年高考化学最后一题解析'
targets = [
    ('baidu', 'https://www.baidu.com/s?wd=' + urllib.parse.quote(q1)),
    ('baidu_q2', 'https://www.baidu.com/s?wd=' + urllib.parse.quote(q2)),
    ('so360', 'https://www.so.com/s?q=' + urllib.parse.quote(q1)),
    ('so360_q2', 'https://www.so.com/s?q=' + urllib.parse.quote(q2)),
    ('sogou', 'https://www.sogou.com/web?query=' + urllib.parse.quote(q1)),
    ('toutiao', 'https://so.toutiao.com/search?keyword=' + urllib.parse.quote(q1)),
    ('zhihu', 'https://www.zhihu.com/search?type=content&q=' + urllib.parse.quote(q1)),
]

res = {}
for name, url in targets:
    st, txt = get(url)
    res[name] = {'status': st, 'len': len(txt), 'head': txt[:3000]}
    print('===', name, st, len(txt))

with open('search_results2.json', 'w', encoding='utf-8') as f:
    json.dump(res, f, ensure_ascii=False, indent=1)
print('DONE')
