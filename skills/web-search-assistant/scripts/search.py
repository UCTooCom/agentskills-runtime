#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
国产网页搜索助理 - Step 1~4: 搜索/解析/去重/输出
封装百度/搜狗等国产搜索引擎，获取公开网页信息。

用法:
    python3 search.py --query "贵州茅台 最新新闻" [--count 10] [--engine baidu] [--outdir output/search]

数据源（均为公开/合规接口）:
    - 百度: https://www.baidu.com/s?wd=<keyword>
    - 搜狗: https://www.sogou.com/web?query=<keyword>
"""

import argparse
import json
import os
import re
import sys
import time
import urllib.request
import urllib.parse
from datetime import datetime

try:
    import requests
    HAS_REQUESTS = True
except ImportError:
    HAS_REQUESTS = False

try:
    from bs4 import BeautifulSoup
    HAS_BS4 = True
except ImportError:
    HAS_BS4 = False


DEFAULT_UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"


def http_get(url: str, timeout: int = 15, headers: dict = None) -> str:
    """通用 HTTP GET，返回文本（自动处理编码，兼容 GBK/UTF-8）"""
    hdrs = {"User-Agent": DEFAULT_UA, "Accept-Language": "zh-CN,zh;q=0.9"}
    if headers:
        hdrs.update(headers)
    if HAS_REQUESTS:
        resp = requests.get(url, headers=hdrs, timeout=timeout)
        # requests 自动按 charset 解码，失败时 fallback
        return resp.text
    req = urllib.request.Request(url, headers=hdrs)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        raw = r.read()
        # 检测编码
        ctype = r.headers.get("Content-Type", "")
        enc = "utf-8"
        if "charset=" in ctype.lower():
            enc = ctype.lower().split("charset=")[-1].split(";")[0].strip()
        try:
            return raw.decode(enc, errors="replace")
        except Exception:
            return raw.decode("utf-8", errors="replace")


def search_baidu(query: str, count: int = 10) -> list:
    """百度搜索，返回结构化结果列表"""
    url = "https://www.baidu.com/s?wd=" + urllib.parse.quote(query)
    html = http_get(url, headers={"Referer": "https://www.baidu.com/"})
    results = []

    if HAS_BS4:
        soup = BeautifulSoup(html, "html.parser")
        for item in soup.select("div.result, div.c-container"):
            title_tag = item.select_one("h3 a, .t a")
            snippet_tag = item.select_one(".c-abstract, .content-right_8Zs40, [class*=abstract]")
            link = title_tag.get("href", "") if title_tag else ""
            title = title_tag.get_text(strip=True) if title_tag else ""
            snippet = snippet_tag.get_text(strip=True) if snippet_tag else ""
            if title:
                results.append({
                    "title": title,
                    "snippet": snippet,
                    "url": link,
                    "source": "baidu",
                    "query": query,
                })
    else:
        # 无 BeautifulSoup 时用正则粗解析（容错降级）
        for m in re.finditer(r'<h3[^>]*>\s*<a[^>]*href="([^"]+)"[^>]*>(.*?)</a>', html, re.S):
            title = re.sub(r"<[^>]+>", "", m.group(2)).strip()
            if title:
                results.append({
                    "title": title,
                    "snippet": "",
                    "url": m.group(1),
                    "source": "baidu",
                    "query": query,
                })

    return results[:count]


def search_sogou(query: str, count: int = 10) -> list:
    """搜狗搜索，返回结构化结果列表"""
    url = "https://www.sogou.com/web?query=" + urllib.parse.quote(query)
    html = http_get(url, headers={"Referer": "https://www.sogou.com/"})
    results = []

    if HAS_BS4:
        soup = BeautifulSoup(html, "html.parser")
        for item in soup.select("div.vrwrap, div.results div.rb"):
            title_tag = item.select_one("h3 a, .vr-title a")
            snippet_tag = item.select_one(".space_txt, .vrwrap-info, [class*=abstract]")
            link = title_tag.get("href", "") if title_tag else ""
            title = title_tag.get_text(strip=True) if title_tag else ""
            snippet = snippet_tag.get_text(strip=True) if snippet_tag else ""
            if title:
                results.append({
                    "title": title,
                    "snippet": snippet,
                    "url": link,
                    "source": "sogou",
                    "query": query,
                })
    else:
        for m in re.finditer(r'<h3[^>]*>\s*<a[^>]*href="([^"]+)"[^>]*>(.*?)</a>', html, re.S):
            title = re.sub(r"<[^>]+>", "", m.group(2)).strip()
            if title:
                results.append({
                    "title": title,
                    "snippet": "",
                    "url": m.group(1),
                    "source": "sogou",
                    "query": query,
                })

    return results[:count]


def dedup(results: list) -> list:
    """按 URL 和标题相似度去重"""
    seen_url = set()
    seen_title = set()
    out = []
    for r in results:
        u = r.get("url", "")
        t = r.get("title", "")
        # 标题取前 20 字符作为相似度键
        tkey = t[:20] if t else ""
        if u and u in seen_url:
            continue
        if tkey and tkey in seen_title:
            continue
        if u:
            seen_url.add(u)
        if tkey:
            seen_title.add(tkey)
        out.append(r)
    return out


def main():
    parser = argparse.ArgumentParser(description="国产网页搜索助理")
    parser.add_argument("--query", required=True, help="搜索关键词，多关键词用英文逗号分隔")
    parser.add_argument("--count", type=int, default=10, help="最大结果数（默认 10）")
    parser.add_argument("--engine", default="baidu", choices=["baidu", "sogou"], help="搜索引擎（默认 baidu）")
    parser.add_argument("--outdir", default="output/search", help="输出目录")
    args = parser.parse_args()

    queries = [q.strip() for q in args.query.replace("，", ",").split(",") if q.strip()]
    if not queries:
        print(json.dumps({"success": False, "error": "empty query"}, ensure_ascii=False))
        sys.exit(1)

    os.makedirs(args.outdir, exist_ok=True)
    all_results = []
    fetched_at = datetime.now().isoformat()

    for q in queries:
        try:
            if args.engine == "sogou":
                rs = search_sogou(q, count=args.count)
            else:
                rs = search_baidu(q, count=args.count)
            all_results.extend(rs)
            time.sleep(0.3)  # 控制抓取频率
        except Exception as e:
            all_results.append({
                "title": "",
                "snippet": "",
                "url": "",
                "source": args.engine,
                "query": q,
                "error": str(e),
            })

    all_results = dedup(all_results)

    out_file = os.path.join(args.outdir, f"{queries[0][:30]}.json")
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump({
            "query": args.query,
            "engine": args.engine,
            "count": len(all_results),
            "fetched_at": fetched_at,
            "results": all_results,
        }, f, ensure_ascii=False, indent=2)

    # 控制台摘要输出（前 N 条），供 agent 直接消费
    print(json.dumps({
        "success": True,
        "output": out_file,
        "count": len(all_results),
        "preview": all_results[:5],
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
