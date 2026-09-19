#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Extra data collection for global AI market 2020-2025:
 - focused Sogou searches (early years)
 - direct urllib fetch attempts on candidate public pages
Saves combined result to output/raw/ai_market_extra.json
"""

import urllib.request
import urllib.parse
import json
import re
import os
import time
import html

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")


def http_get(url, timeout=20):
    req = urllib.request.Request(url, headers={
        "User-Agent": UA,
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
    })
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        raw = resp.read()
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
    s = html.unescape(s)
    return re.sub(r"\s+", " ", s).strip()


def sogou_search(q, count=10):
    url = "https://www.sogou.com/web?query=" + urllib.parse.quote(q)
    try:
        page = http_get(url)
    except Exception as e:
        return {"error": str(e), "results": [], "page_len": 0}
    results = []
    for m in re.finditer(r'<h3[^>]*>\s*<a[^>]*href="([^"]+)"[^>]*>([\s\S]*?)</a>', page, re.I):
        href = html.unescape(m.group(1))
        title = strip_tags(m.group(2))
        seg = page[m.end():m.end() + 1500]
        sm = re.search(
            r'class="[^"]*(space_txt|vrwrap-info|str_info|str-text-info|fz-mid|text-lh)[^"]*"[^>]*>([\s\S]*?)</',
            seg, re.I)
        snippet = strip_tags(sm.group(2)) if sm else strip_tags(seg)[:200]
        if title:
            results.append({"title": title, "snippet": snippet, "url": href, "source": "sogou"})
        if len(results) >= count:
            break
    return {"results": results, "page_len": len(page)}


QUERIES = [
    "2020年全球人工智能市场规模 亿美元 同比增长",
    "2021年全球人工智能市场规模 亿美元 IDC",
    "2022年全球人工智能市场规模 4328亿美元",
    "全球AI市场规模 2020 2021 2022 2023 2024 2025 增长趋势",
    "中国人工智能市场规模 2020 2021 2022 2023 2024",
    "generative AI market size 2021 2022 2023 2024 2025 billion USD",
]

CANDIDATES = [
    "https://www.idc.com/getdoc.jsp?containerId=prUS51802224",
    "https://www.gartner.com/en/newsroom/press-releases/2024-07-31-gartner-forecasts-worldwide-ai-spending-to-reach-1-5-trillion-in-2025",
    "https://www.sohu.com/a/590612345_121124363",
    "https://www.163.com/dy/article/JGQ0JQ0J0511D3QS.html",
]


def main():
    base = os.path.dirname(os.path.abspath(__file__))
    out_dir = os.path.abspath(os.path.join(base, "..", "output", "raw"))
    os.makedirs(out_dir, exist_ok=True)

    out = {"searches": {}, "direct_fetches": {}}

    for q in QUERIES:
        r = sogou_search(q, count=10)
        out["searches"][q] = r
        print("[SEARCH-OK] results=%d page_len=%d" % (len(r.get("results", [])), r.get("page_len", 0)))
        time.sleep(1)

    for u in CANDIDATES:
        try:
            page = http_get(u, timeout=20)
            out["direct_fetches"][u] = {"ok": True, "len": len(page), "text_head": strip_tags(page)[:1200]}
            print("[FETCH-OK] len=%d url=%s" % (len(page), u[:60]))
        except Exception as e:
            out["direct_fetches"][u] = {"ok": False, "error": str(e)[:200]}
            print("[FETCH-FAIL] %s | %s" % (u[:60], str(e)[:80]))
        time.sleep(1)

    p = os.path.join(out_dir, "ai_market_extra.json")
    with open(p, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
    print("[SAVED] " + p)


if __name__ == "__main__":
    main()
