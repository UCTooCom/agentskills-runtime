# -*- coding: utf-8 -*-
"""第二轮：补充查询 + 尝试抓取正文全文，输出 UTF-8 JSON"""
import urllib.request, urllib.parse, json, re, os, time, html as htmlmod

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

def http_get(url, timeout=20):
    req = urllib.request.Request(url, headers={
        "User-Agent": UA,
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
        "Referer": "https://www.sogou.com/",
    })
    with urllib.request.urlopen(req, timeout=timeout) as r:
        raw = r.read()
    for enc in ("utf-8", "gb18030", "gbk"):
        try:
            return raw.decode(enc)
        except Exception:
            continue
    return raw.decode("utf-8", errors="replace")

def strip_tags(s):
    s = re.sub(r"<script[\s\S]*?</script>", " ", s, flags=re.I)
    s = re.sub(r"<style[\s\S]*?</style>", " ", s, flags=re.I)
    s = re.sub(r"<[^>]+>", " ", s)
    s = htmlmod.unescape(s)
    return re.sub(r"\s+", " ", s).strip()

def sogou_search(q, count=10):
    url = "https://www.sogou.com/web?query=" + urllib.parse.quote(q)
    try:
        page = http_get(url)
    except Exception as e:
        return {"error": str(e), "results": []}
    out = []
    for m in re.finditer(r'<h3[^>]*>\s*<a[^>]*href="([^"]+)"[^>]*>([\s\S]*?)</a>', page, re.I):
        href, title = m.group(1), strip_tags(m.group(2))
        if not title:
            continue
        seg = page[m.end():m.end() + 2000]
        t = strip_tags(seg)
        # 优先抽含数字的句子
        sents = re.split(r'[\u3002\uff01\uff1f\.\!\?;\uff1b]', t)
        picks = [s.strip() for s in sents if re.search(r'\d', s)]
        snippet = " | ".join(picks[:3])[:400] if picks else t[:200]
        out.append({"title": title, "snippet": snippet, "url": href, "source": "sogou"})
        if len(out) >= count:
            break
    return {"results": out, "page_len": len(page)}

QUERIES = [
    "全球人工智能市场规模 2022年 增长率",
    "IDC 全球人工智能支出 2025 预测",
    "中国人工智能核心产业规模 2024 亿元",
    "2025年全球AI市场规模 增速 CAGR",
    "生成式人工智能市场规模 2024 2025 亿美元",
    "人工智能投资 2023 2024 2025 全球 融资",
]

allres = {}
for q in QUERIES:
    r = sogou_search(q, 10)
    allres[q] = r
    print("[OK] %s -> %d results, page_len=%s" % (q, len(r.get("results", [])), r.get("page_len")))
    time.sleep(1.2)

outdir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "output", "raw")
os.makedirs(outdir, exist_ok=True)
outpath = os.path.join(outdir, "ai_market_raw2.json")
with open(outpath, "w", encoding="utf-8") as f:
    json.dump(allres, f, ensure_ascii=False, indent=2)
print("[SAVED] " + os.path.abspath(outpath))
