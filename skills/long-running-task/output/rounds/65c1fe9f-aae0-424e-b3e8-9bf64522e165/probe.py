# -*- coding: utf-8 -*-
import sys, io, json, re, os, urllib.request, urllib.parse, gzip as _g
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'

def get(url, ref=None, maxb=2_000_000):
    req = urllib.request.Request(url)
    req.add_header('User-Agent', UA)
    req.add_header('Accept-Language', 'zh-CN,zh;q=0.9')
    req.add_header('Accept-Encoding', 'gzip, deflate')
    if ref: req.add_header('Referer', ref)
    try:
        r = urllib.request.urlopen(req, timeout=20)
        d = r.read(maxb)
        if r.headers.get('Content-Encoding') == 'gzip': d = _g.decompress(d)
        enc = r.headers.get_content_charset() or 'utf-8'
        return r.status, d.decode(enc, 'ignore')
    except Exception as e:
        return -1, str(e)

def text(html):
    h = re.sub(r'<script[^>]*>.*?</script>', ' ', html, flags=re.S|re.I)
    h = re.sub(r'<style[^>]*>.*?</style>', ' ', h, flags=re.S|re.I)
    h = re.sub(r'<[^>]+>', ' ', h)
    return re.sub(r'\s+', ' ', h).strip()

# --- A. 检查本地 toutiao html 里的 article 链接 ---
for fn in ['toutiao_q2.html', 'pages/toutiao.html']:
    if os.path.exists(fn):
        with open(fn, encoding='utf-8', errors='ignore') as f:
            h = f.read()
        arts = set(re.findall(r'(?:\\u002F|/)(?:article|item|w|a)(?:\\u002F|/)(\d{15,22})', h))
        print('LOCAL', fn, 'article ids', len(arts), list(arts)[:10])
        # 找 JSON 中的 title/url
        u = set(re.findall(r'"(?:article_url|url|share_url)":"(https?://[^"]+)"', h))
        print('LOCAL urls sample', list(u)[:10])

# --- B. 探测候选源 ---
CAND = {
  'eol_gk2025': 'https://www.eol.cn/e_html/gk/gk2025/index.shtml',
  'eol_hx': 'https://www.eol.cn/e_html/gk/gk2025/huaxue.shtml',
  'eol_zt': 'https://www.eol.cn/e_html/gk/gkzt/',
  'gaosan_home': 'https://www.gaosan.com/',
  'gaosan_ct': 'https://www.gaosan.com/gaokao/1124039.html',
  '51test': 'https://www.51test.net/gaokao/',
  'gaokao_com': 'https://www.gaokao.com/',
  'wangxiao': 'https://www.wangxiao.cn/',
  'xdf_gk': 'https://gaokao.xdf.cn/',
  'baidu_zhidao': 'https://zhidao.baidu.com/search?word=' + urllib.parse.quote('2025高考化学压轴题'),
  'sogou_wenku': 'https://wenku.sogou.com/search?query=' + urllib.parse.quote('2025高考化学真题'),
  'bing_cn': 'https://cn.bing.com/search?q=' + urllib.parse.quote('2025高考化学真题及答案'),
  'yandex': 'https://yandex.com/search/?text=' + urllib.parse.quote('2025高考化学真题'),
  'gitee_search': 'https://search.gitee.com/?q=' + urllib.parse.quote('2025高考化学'),
}
out = {}
for name, url in CAND.items():
    st, h = get(url)
    t = text(h)
    kw = {k: t.count(k) for k in ['化学'] if t.count(k) > 0}
    out[name] = {'status': st, 'len': len(h), 'textlen': len(t), 'kw': kw, 'head': t[:600]}
    print('===', name, st, len(h), 'text', len(t), kw)
    print(t[:300])
    os.makedirs('probe', exist_ok=True)
    with open('probe/%s.html' % name, 'w', encoding='utf-8') as f: f.write(h)

with open('probe_results.json', 'w', encoding='utf-8') as f:
    json.dump(out, f, ensure_ascii=False, indent=1)
print('DONE')
