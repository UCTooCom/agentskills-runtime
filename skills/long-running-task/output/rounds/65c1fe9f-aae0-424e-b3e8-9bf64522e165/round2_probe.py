# -*- coding: utf-8 -*-
import sys, io, json, re, os, urllib.request, urllib.parse, gzip as _g, html as _h
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'

def get(url, ref=None, enc=None, maxb=3_000_000):
    req = urllib.request.Request(url)
    req.add_header('User-Agent', UA)
    req.add_header('Accept-Language', 'zh-CN,zh;q=0.9')
    req.add_header('Accept-Encoding', 'gzip, deflate')
    if ref: req.add_header('Referer', ref)
    try:
        r = urllib.request.urlopen(req, timeout=25)
        d = r.read(maxb)
        if r.headers.get('Content-Encoding') == 'gzip': d = _g.decompress(d)
        use = enc or r.headers.get_content_charset() or 'utf-8'
        return r.status, d.decode(use, 'ignore')
    except Exception as e:
        return -1, str(e)

def to_text(h):
    h = re.sub(r'<script[^>]*>.*?</script>', ' ', h, flags=re.S|re.I)
    h = re.sub(r'<style[^>]*>.*?</style>', ' ', h, flags=re.S|re.I)
    h = re.sub(r'<[^>]+>', ' ', h)
    return re.sub(r'\s+', ' ', _h.unescape(h)).strip()

# ---- A. 重新解码 GBK 源 ----
print('##### A. GBK re-decode #####')
for name, url in [('gaokao_com','https://www.gaokao.com/'), ('51test','https://www.51test.net/gaokao/')]:
    for enc in ['gb18030','utf-8']:
        st, h = get(url, enc=enc)
        t = to_text(h)
        chem = t.count('化学')
        print(name, enc, st, len(h), 'chem=', chem)
        if chem > 3:
            os.makedirs('probe2', exist_ok=True)
            open('probe2/%s_%s.txt' % (name, enc), 'w', encoding='utf-8').write(t)
            print(t[:800])
            break

# ---- B. Bing 正确解析 ----
print('\n##### B. Bing parse #####')
if os.path.exists('bing/q0.html'):
    h = open('bing/q0.html', encoding='utf-8', errors='ignore').read()
    print('bing q0 text head:', to_text(h)[:500])
    # b_algo blocks
    blocks = re.findall(r'<li class="b_algo"[^>]*>(.*?)</li>\s*(?=<li|</ol>)', h, re.S)
    print('b_algo blocks:', len(blocks))
    if not blocks:
        blocks = re.findall(r'<li class="b_algo".*?(?=<li class="b_algo"|</ol>)', h, re.S)
        print('fallback blocks:', len(blocks))
    # 所有 h2 链接
    hs = re.findall(r'<h2[^>]*>\s*<a[^>]*href="([^"]+)"[^>]*>(.*?)</a>', h, re.S)
    print('h2 links:', len(hs))
    for u, t in hs[:25]:
        print('  ', u)
        print('     ', to_text(t)[:80])
    # 任何外部链接
    exts = [u for u in set(re.findall(r'href="(https?://[^"]+)"', h)) if 'bing.com' not in u]
    print('ext links:', len(exts))
    for u in list(exts)[:30]:
        print('  E', u)

# ---- C. toutiao 精确搜索 ----
print('\n##### C. toutiao precise #####')
for i, kw in enumerate(['2025高考化学 艾拉莫德 合成路线', '2025高考化学全国卷 有机合成 29题', '2025年高考化学真题 有机合成 解析']):
    st, h = get('https://so.toutiao.com/search?keyword=' + urllib.parse.quote(kw))
    os.makedirs('tt', exist_ok=True)
    open('tt/tt%d.html' % i, 'w', encoding='utf-8').write(h)
    print('---', kw, st, len(h))
    # 提取结果标题 + url
    items = re.findall(r'"title":"(.*?)","(?:[^"]*?)"(?:article_url|url|display_url)":"(https?://[^"]+)"', h)
    print('pair items:', len(items))
    arts = re.findall(r'"article_url":"(https?://[^"]+)"', h)
    print('article_urls:', len(arts))
    for a in list(dict.fromkeys(arts))[:15]:
        print('  ', a)
    # 其它 url 字段
    for u in list(dict.fromkeys(re.findall(r'"(?:share_url|display_url|url)":"(https?://[^"]+)"', h)))[:20]:
        print('  U', u)
print('DONE')
