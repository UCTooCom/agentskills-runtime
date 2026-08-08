#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
智能投研助理 - Step 2: 数据清洗（Clean Market Data）
对抓取到的原始数据进行去重、格式统一、无效数据剔除。

用法:
    python3 clean_market_data.py --input output/raw/2026-08-07.json [--outdir output/clean]
"""

import argparse
import json
import os
import sys


def clean_value(v):
    """归一化数值：东财接口原始值通常放大 100 倍，统一转为标准值"""
    if v is None:
        return None
    try:
        return round(float(v) / 100.0, 4)
    except (TypeError, ValueError):
        return v


def clean_quote(q: dict) -> dict:
    if not q:
        return {}
    return {
        "code": q.get("code"),
        "name": q.get("name"),
        "price": clean_value(q.get("price")),
        "change_pct": clean_value(q.get("change_pct")),
        "volume": q.get("volume"),
        "amount": q.get("amount"),
        "pe": clean_value(q.get("pe")),
        "pb": clean_value(q.get("pb")),
        "market_cap": clean_value(q.get("market_cap")),
        "high": clean_value(q.get("high")),
        "low": clean_value(q.get("low")),
        "open": clean_value(q.get("open")),
        "prev_close": clean_value(q.get("prev_close")),
    }


def clean_records(raw: dict) -> dict:
    """清洗主流程：逐公司清洗，剔除无效行情"""
    cleaned = {
        "date": raw.get("date"),
        "companies": [],
        "cleaned_at": None,
    }
    seen_titles = set()

    for comp in raw.get("companies", []):
        q = clean_quote(comp.get("quotes") or {})
        # 剔除无效行情：无代码或无价格
        if not q.get("code") or q.get("price") is None:
            continue
        news = []
        for n in comp.get("news") or []:
            title = (n.get("title") or "").strip()
            if not title or title in seen_titles:
                continue  # 去重
            seen_titles.add(title)
            news.append(n)
        cleaned["companies"].append({
            "code": q.get("code"),
            "name": q.get("name") or comp.get("name"),
            "quotes": q,
            "news": news,
            "raw_news_count": len(comp.get("news") or []),
        })
    return cleaned


def main():
    parser = argparse.ArgumentParser(description="清洗抓取数据")
    parser.add_argument("--input", required=True, help="原始数据 JSON")
    parser.add_argument("--outdir", default="output/clean", help="输出目录")
    args = parser.parse_args()

    with open(args.input, encoding="utf-8") as f:
        raw = json.load(f)

    cleaned = clean_records(raw)
    os.makedirs(args.outdir, exist_ok=True)
    out_file = os.path.join(args.outdir, os.path.basename(args.input))
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(cleaned, f, ensure_ascii=False, indent=2)

    print(json.dumps({
        "success": True,
        "output": out_file,
        "total": len(raw.get("companies", [])),
        "kept": len(cleaned["companies"]),
        "dropped": len(raw.get("companies", [])) - len(cleaned["companies"]),
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
