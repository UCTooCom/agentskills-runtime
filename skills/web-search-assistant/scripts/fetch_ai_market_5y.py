#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Fetch global/China/generative AI market size data for 2020-2025 via Sogou search."""

import urllib.request
import urllib.parse
import json
import re
import sys
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
    s = re.sub(r"\s+", " ", s)
    return s.strip()


def sogou_search(q, count=10):
    url = "https://www.sogou.com/web?query=" + urllib.parse.quote(q)
    try:
        page = http_get(url)
    except Exception as e:
        return {"error": str(e), "results": [], "page_len": 0}
    results = []
    try:
        for m in re.finditer(r'<h3[^>]*>\s*<a[^>]*href="([^"]+)"[^>]*>([\s\S]*?)</a>', page, re.I):
            href = html.unescape(m.group(1))
            title = strip_tags(m.group(2))
            seg = page[m.end():m.end() + 1500]
            sm = re.search(
                r'class="[^"]*(space_txt|vrwrap-info|str_info|str-text-info|fz-mid|text-lh)[^"]*"[^>]*>([\s\S]*?)</',
                seg, re.I)
            snippet = strip_tags(sm.group(2)) if sm else strip_tags(seg)[:200]
            if not title:
                continue
            results.append({
                "title": title,
                "snippet": snippet,
                "url": href,
                "source": "sogou",
            })
            if len(results) >= count:
                break
    except Exception as e:
        return {"error": str(e), "results": results, "page_len": len(page)}
    return {"results": results, "page_len": len(page)}


QUERIES = [
    "全球人工智能市场规模 2020 2021 2022 2023 2024 2025 亿美元",
    "global AI market size 2021 2022 2023 2024 2025 billion",
    "中国人工智能市场规模 2021 2022 2023 2024 2025 亿元",
    "生成式AI 市场规模 2023 2024 2025 亿美元",
    "人工智能市场 CAGR 2021 2022 2023 2024 2025 年复合增长率",
    "IDC 全球AI市场规模 2025 预测",
]


def main():
    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "output", "raw")
    out_dir = os.path.abspath(out_dir)
    os.makedirs(out_dir, exist_ok=True)
    data = {}
    for q in QUERIES:
        r = sogou_search(q, count=10)
        data[q] = r
        print("[OK] %s -> %d results, page_len=%d" % (q.encode("utf-8", "replace").decode("utf-8"), len(r.get("results", [])), r.get("page_len", 0)))
        time.sleep(1)
    out_path = os.path.join(out_dir, "ai_market_raw_5y.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print("[SAVED] " + out_path)


if __name__ == "__main__":
    main()
