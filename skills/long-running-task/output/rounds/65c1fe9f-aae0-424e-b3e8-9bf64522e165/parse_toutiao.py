# -*- coding: utf-8 -*-
import sys, io, json, re, urllib.parse, urllib.request, gzip as _g
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
def get(url):
    req = urllib.request.Request(url)
    req.add_header('User-Agent', UA)
    req.add_header('Accept-Encoding', 'gzip')
    r = urllib.request.urlopen(req, timeout=30)
    d = r.read()
    if r.headers.get('Content-Encoding') == 'gzip':
        d = _g.decompress(d)
    enc = r.headers.get_content_charset() or 'utf-8'
    return d.decode(enc, 'ignore')

kw = urllib.parse.quote('2025年高考化学最后一题解析')
html = get('https://so.toutiao.com/search?keyword=' + kw)
with open('toutiao_q2.html', 'w', encoding='utf-8') as f:
    f.write(html)
print('len', len(html))

# 提取所有链接
links = re.findall(r'"(https?://[^"\\]+)"', html)
edu = [l for l in set(links) if any(k in l for k in ['zxxk','21cnjy','gaosan','doc88','docin','book118','renrendoc','163.com','sohu','baidu','qq.com','weixin','zhihu','bilibili','jyeoo','tiku','xdf','cn','com'])]
edu = [l for l in edu if 'toutiao' not in l and 'bytedance' not in l and 'snssdk' not in l]
with open('linkts.txt','w',encoding='utf-8') as f:
    f.write('\n'.join(edu))
print('EDU', len(edu))
for l in edu[:80]:
    print(l)
print('DONE')
