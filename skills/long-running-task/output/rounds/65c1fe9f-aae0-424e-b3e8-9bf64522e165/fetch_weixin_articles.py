# -*- coding: utf-8 -*-
import sys, io, json, re, urllib.request, urllib.parse, gzip as _g, os, time
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'

def get(url, ref=None, maxbytes=3_000_000):
    req = urllib.request.Request(url)
    req.add_header('User-Agent', UA)
    req.add_header('Accept-Language', 'zh-CN,zh;q=0.9')
    req.add_header('Accept-Encoding', 'gzip, deflate')
    if ref: req.add_header('Referer', ref)
    try:
        r = urllib.request.urlopen(req, timeout=25)
        d = r.read(maxbytes)
        ce = r.headers.get('Content-Encoding')
        if ce == 'gzip': d = _g.decompress(d)
        enc = r.headers.get_content_charset() or 'utf-8'
        return r.status, d.decode(enc, 'ignore'), r.geturl()
    except Exception as e:
        return -1, str(e), url

os.makedirs('articles', exist_ok=True)

# 从 pages/weixin_*.html 提取文章链接
all_links = []
for i in range(3):
    fn = 'pages/weixin_%d.html' % i
    if not os.path.exists(fn): continue
    with open(fn, encoding='utf-8') as f:
        html = f.read()
    # sogou weixin 文章链接
    links = re.findall(r'href="(/link\?url=[^"&]+[^"]*)"', html)
    for l in links:
        full = 'https://weixin.sogou.com' + l.replace('&amp;', '&')
        if full not in all_links:
            all_links.append(full)
    # 直接 mp.weixin 链接
    links2 = re.findall(r'(https?://mp\.weixin\.qq\.com/s[^"\s]+)', html)
    for l in links2:
        if l not in all_links:
            all_links.append(l)

print('TOTAL LINKS', len(all_links))

# 先取标题
html0 = open('pages/weixin_0.html', encoding='utf-8').read()
titles = re.findall(r'<h3>.*?<a[^>]*>(.*?)</a>', html0, re.S)
titles = [re.sub(r'<[^>]+>', '', t).strip() for t in titles]
print('TITLES:', json.dumps(titles[:20], ensure_ascii=False))

# 逐条跟随跳转
out = []
for idx, link in enumerate(all_links[:30]):
    st, txt, final = get(link)
    fn = 'articles/wx_%02d.html' % idx
    with open(fn, 'w', encoding='utf-8') as f:
        f.write(txt)
    # 提取标题与正文摘要
    title = ''
    m = re.search(r'<title>(.*?)</title>', txt, re.S)
    if m: title = m.group(1).strip()
    body_ok = 'js_content' in txt or 'rich_media_content' in txt
    out.append({'idx': idx, 'final': final, 'status': st, 'len': len(txt), 'title': title, 'has_content': body_ok})
    print(idx, st, len(txt), 'content=' + str(body_ok), title[:60])
    time.sleep(0.5)

with open('weixin_articles.json', 'w', encoding='utf-8') as f:
    json.dump(out, f, ensure_ascii=False, indent=1)
print('DONE')
