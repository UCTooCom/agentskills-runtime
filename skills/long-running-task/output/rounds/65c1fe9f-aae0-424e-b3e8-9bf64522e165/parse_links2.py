# -*- coding: utf-8 -*-
import sys, io, json, re, urllib.parse
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

with open('search_results2.json', encoding='utf-8') as f:
    data = json.load(f)

for name in ['so360_q2', 'so360', 'toutiao']:
    html = data.get(name, {}).get('head', '')
    # 只head部分，重新需要完整内容；这里head是前3000字符，不够
    pass

# head 截断了，需要重新抓完整页面
import urllib.request, gzip as _g
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

url360 = 'https://www.so.com/s?q=' + urllib.parse.quote('2025年高考化学最后一题解析')
html = get(url360)
with open('so360_q2.html', 'w', encoding='utf-8') as f:
    f.write(html)

# 提取所有外链
links = re.findall(r'href="(https?://[^"]+)"', html)
cnt = {}
for l in links:
    dom = urllib.parse.urlparse(l).netloc
    cnt[dom] = cnt.get(dom, 0) + 1
print('DOMAINS:', sorted(cnt.items(), key=lambda x: -x[1])[:40])

# 找教育站点链接
edu_kw = ['zxxk', '21cnjy', 'gaosan', 'gaokao', 'doc88', 'docin', 'book118', 'renrendoc', '163.com', 'sohu', 'baidu', 'qq.com', 'weixin', 'zhihu', 'bilibili', 'xdf', 'koolearn', 'youtike', 'jyeoo', 'tiku']
sel = [l for l in set(links) if any(k in l for k in edu_kw)]
with open('links_so360_q2.txt', 'w', encoding='utf-8') as f:
    f.write('\n'.join(sel))
print('SELECTED', len(sel))
for l in sel[:60]:
    print(l)
print('DONE')
