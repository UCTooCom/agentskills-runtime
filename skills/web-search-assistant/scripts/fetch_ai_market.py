# -*- coding: utf-8 -*-
"""抓取全球AI市场规模公开数据（搜狗搜索 + 正文提取），输出 UTF-8 JSON"""
import urllib.request, urllib.parse, json, re, sys, os, time, html as htmlmod

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

def http_get(url, timeout=20):
    req = urllib.request.Request(url, headers={
        "User-Agent": UA,
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
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
    # 标题块：<h3 ...><a href="..." ...>标题</a>
    for m in re.finditer(r'<h3[^>]*>\s*<a[^>]*href="([^"]+)"[^>]*>([\s\S]*?)</a>', page, re.I):
        href, title = m.group(1), strip_tags(m.group(2))
        if not title:
            continue
        start = m.end()
        seg = page[start:start + 1500]
        # 摘要：取该结果块内的文本
        sm = re.search(r'<(?:p|div|span)[^>]*class="[^"]*(?:space_txt|vrwrap-info|str_info|str-text-info|fz-mid|text-lh)[^"]*"[^>]*>([\s\S]*?)</(?:p|div|span)>', seg, re.I)
        snippet = strip_tags(sm.group(1)) if sm else ""
        if not snippet:
            t = strip_tags(seg)
            snippet = t[:200]
        out.append({"title": title, "snippet": snippet, "url": href, "source": "sogou"})
        if len(out) >= count:
            break
    return {"results": out, "page_len": len(page)}

QUERIES = [
    "全球AI市场规模2025",
    "全球人工智能市场规模2023",
    "全球人工智能市场规模2024",
    "生成式AI市场规模2025",
    "中国AI核心产业规模2025",
]

allres = {}
for q in QUERIES:
    r = sogou_search(q, 10)
    allres[q] = r
    print("[OK] %s -> %d results, page_len=%s" % (q, len(r.get("results", [])), r.get("page_len")))
    time.sleep(1)

outdir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "output", "raw")
os.makedirs(outdir, exist_ok=True)
outpath = os.path.join(outdir, "ai_market_raw.json")
with open(outpath, "w", encoding="utf-8") as f:
    json.dump(allres, f, ensure_ascii=False, indent=2)
print("[SAVED] " + os.path.abspath(outpath))
