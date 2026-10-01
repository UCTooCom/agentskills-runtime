# -*- coding: utf-8 -*-
import sys, io, json, re, urllib.parse, urllib.request, ssl, os, html
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

CTX = ssl.create_default_context()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36",
    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
}
OUTDIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "raw")
os.makedirs(OUTDIR, exist_ok=True)

def fetch(url, timeout=25):
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=timeout, context=CTX) as resp:
        raw = resp.read()
        enc = resp.headers.get_content_charset() or 'utf-8'
        return resp.status, raw.decode(enc, errors='replace')

def clean(s):
    return html.unescape(re.sub('<[^>]+>', '', s)).strip()

queries = [
    "2025年高考物理新课标I卷 计算题 压轴题",
    "2025 高考物理 最后一道大题 解析",
]
allres = {}
for i, q in enumerate(queries):
    url = "https://www.bing.com/search?q=" + urllib.parse.quote(q) + "&count=30"
    try:
        st, txt = fetch(url)
    except Exception as e:
        allres[q] = {"error": repr(e)}
        continue
    fn = os.path.join(OUTDIR, f"bing_q{i}.html")
    with open(fn, 'w', encoding='utf-8') as f:
        f.write(txt)
    # extract result blocks: <li class="b_algo"> ... <h2><a href="...">title</a></h2>
    items = []
    for m in re.finditer(r'<h2[^>]*>\s*<a[^>]*href="(https?://[^"]+)"[^>]*>(.*?)</a>', txt, re.S):
        link = m.group(1)
        title = clean(m.group(2))
        items.append({"title": title, "url": link})
    allres[q] = {"status": st, "saved": fn, "n": len(items), "items": items[:25]}

print(json.dumps(allres, ensure_ascii=False, indent=2))
