# -*- coding: utf-8 -*-
import sys, io, json, re, urllib.request, urllib.parse, gzip as _g, os
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'

def get(url, ref=None):
    req = urllib.request.Request(url)
    req.add_header('User-Agent', UA)
    req.add_header('Accept-Language', 'zh-CN,zh;q=0.9')
    req.add_header('Accept-Encoding', 'gzip, deflate')
    if ref: req.add_header('Referer', ref)
    try:
        r = urllib.request.urlopen(req, timeout=25)
        d = r.read()
        ce = r.headers.get('Content-Encoding')
        if ce == 'gzip': d = _g.decompress(d)
        enc = r.headers.get_content_charset() or 'utf-8'
        return r.status, d.decode(enc, 'ignore')
    except Exception as e:
        return -1, str(e)

os.makedirs('pages', exist_ok=True)
results = {}

# 1. weixin.sogou 微信文章搜索（化学压轴/真题）
queries = [
    '2025年高考化学压轴题解析',
    '2025年高考化学新课标卷真题及答案',
    '2025高考化学全国卷最后一题解析',
]
for i, q in enumerate(queries):
    url = 'https://weixin.sogou.com/weixin?type=2&query=' + urllib.parse.quote(q)
    st, html = get(url)
    fn = 'pages/weixin_%d.html' % i
    with open(fn, 'w', encoding='utf-8') as f: f.write(html)
    # 提取 article link
    links = re.findall(r'href="(/link\?url=[^"]+)"', html)
    results['weixin_%d' % i] = {'q': q, 'status': st, 'len': len(html), 'nlinks': len(links), 'links': ['https://weixin.sogou.com' + l.replace('&amp;', '&') for l in links]}
    print('weixin_%d' % i, st, len(html), 'links', len(links))

# 2. 直接尝试若干教育站点
cands = {
    'eol_sh': 'https://www.eol.cn/e_html/gk/gk2025/shx.shtml',
    'eol_zx': 'https://www.eol.cn/e_html/gk/gk2025/',
    'zhihu_search': 'https://www.zhihu.com/search?type=content&q=' + urllib.parse.quote('2025高考化学真题及答案'),
    'cnjy_m': 'https://m.21cnjy.com/H/23616335.shtml',
    'zxxk_pack': 'https://m.zxxk.com/docpack/3508877.html',
    'baidu_1': 'https://www.baidu.com/s?wd=' + urllib.parse.quote('2025年高考化学新课标Ⅰ卷 最后一道大题 有机合成 解析'),
    'baidu_2': 'https://www.baidu.com/s?wd=' + urllib.parse.quote('2025高考化学真题 word 下载 mp.weixin.qq.com'),
}
for name, url in cands.items():
    st, txt = get(url)
    with open('pages/%s.html' % name, 'w', encoding='utf-8') as f: f.write(txt)
    results[name] = {'status': st, 'len': len(txt), 'head': txt[:1200]}
    print(name, st, len(txt))

with open('batch_results.json', 'w', encoding='utf-8') as f:
    json.dump(results, f, ensure_ascii=False, indent=1)
print('DONE')
