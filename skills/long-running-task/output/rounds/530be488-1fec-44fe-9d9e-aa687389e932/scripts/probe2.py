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
    return html.unescape(re.sub('<[^>]+>', ' ', s)).strip()

# Try Bing with market params
urls = [
    ("bing_mkt", "https://www.bing.com/search?q=" + urllib.parse.quote("2025年高考物理压轴题 解析") + "&mkt=zh-CN&setlang=zh-CN&cc=CN"),
    ("bing_broad", "https://www.bing.com/search?q=" + urllib.parse.quote("2025高考物理 计算题 25题") + "&mkt=zh-CN&setlang=zh-CN"),
]
res = {}
for name, url in urls:
    rec = {}
    try:
        st, txt = fetch(url)
        fn = os.path.join(OUTDIR, name + ".html")
        with open(fn, 'w', encoding='utf-8') as f:
            f.write(txt)
        rec["status"] = st
        rec["len"] = len(txt)
        rec["saved"] = fn
        # extract b_algo title + caption
        blocks = re.findall(r'<li class="b_algo".*?</li>', txt, re.S)
        items = []
        for b in blocks[:15]:
            hm = re.search(r'href="(https?://[^"]+)"', b)
            tm = re.search(r'<h2[^>]*>(.*?)</h2>', b, re.S)
            cm = re.search(r'<p[^>]*>(.*?)</p>', b, re.S)
            items.append({
                "title": clean(tm.group(1)) if tm else "",
                "url": hm.group(1) if hm else "",
                "snippet": clean(cm.group(1))[:200] if cm else "",
            })
        rec["items"] = items
        for kw in ["物理", "高考", "压轴", "试题", "计算题"]:
            rec["kw_" + kw] = txt.count(kw)
    except Exception as e:
        rec["error"] = repr(e)
    res[name] = rec

print(json.dumps(res, ensure_ascii=False, indent=2))
