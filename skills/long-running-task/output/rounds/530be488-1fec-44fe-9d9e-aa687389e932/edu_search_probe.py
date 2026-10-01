# -*- coding: utf-8 -*-
"""探测教育站点站内搜索，寻找 2025 高考物理真题入口"""
import sys, io, os, json
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
import urllib.request, urllib.parse, gzip, re

UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
OUTDIR = os.path.dirname(os.path.abspath(__file__))
SVDIR = os.path.join(OUTDIR, 'raw_html')
if not os.path.isdir(SVDIR):
    os.makedirs(SVDIR)

def fetch(url, timeout=25, extra=None):
    h = {
        'User-Agent': UA,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    }
    if extra:
        h.update(extra)
    req = urllib.request.Request(url, headers=h)
    try:
        resp = urllib.request.urlopen(req, timeout=timeout)
        raw = resp.read()
        if resp.headers.get('Content-Encoding') == 'gzip':
            raw = gzip.decompress(raw)
        for enc in ('utf-8', 'gbk', 'gb18030'):
            try:
                return resp.status, raw.decode(enc), raw
            except Exception:
                continue
        return resp.status, raw.decode('utf-8', 'replace'), raw
    except Exception as e:
        return 'ERR', str(e), b''

def title_of(html):
    m = re.search(r'<title>(.*?)</title>', html, re.S)
    return re.sub(r'\s+', ' ', m.group(1)).strip() if m else 'N/A'

candidates = [
    # 高考资源网
    ('ks5u_search', 'https://www.ks5u.com/search/?keyword=' + urllib.parse.quote('2025年高考物理真题')),
    ('ks5u_wuli', 'https://www.ks5u.com/wuli/'),
    # 21世纪教育网
    ('21cnjy_search', 'https://so.21cnjy.com/search?q=' + urllib.parse.quote('2025高考物理真题')),
    # 菁优网
    ('jyeoo_search', 'https://so.jyeoo.com/search?q=' + urllib.parse.quote('2025年高考物理')),
    # 教育在线高考
    ('eol_search', 'https://gaokao.eol.cn/e/action/ListInfo.php?search=1&keyword=' + urllib.parse.quote('2025高考物理真题')),
    # 组卷网
    ('zujuan', 'https://zujuan.xkw.com/gz/wl/'),
]

summary = {}
for name, u in candidates:
    st, txt, raw = fetch(u)
    t = title_of(txt) if isinstance(txt, str) else 'N/A'
    print('===== %s ===== status=%s len=%s' % (name, st, len(txt) if isinstance(txt, str) else 0))
    print('   title:', t)
    if isinstance(txt, str) and len(txt) > 200:
        # 提取含 2025 且含 物理 的链接
        links = re.findall(r'href=["\']([^"\']+)["\'][^>]*>([^<]{2,60})<', txt)
        hot = [(l, re.sub(r'\s+', '', lt)) for l, lt in links if ('2025' in lt and ('物理' in lt or '高考' in lt))]
        print('   hot links:', len(hot))
        for l, lt in hot[:15]:
            print('      ', lt, '|', l[:130])
        with open(os.path.join(SVDIR, name + '.html'), 'w', encoding='utf-8') as f:
            f.write(txt)
    summary[name] = {'status': st, 'len': len(txt) if isinstance(txt, str) else 0, 'title': t}
    print()

with open(os.path.join(OUTDIR, 'edu_search_summary.json'), 'w', encoding='utf-8') as f:
    json.dump(summary, f, ensure_ascii=False, indent=2)
print('done, saved raw_html/ and edu_search_summary.json')
