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


def clean_raw(v):
    """v11新增：不归一化，直接转 float（用于 PE/PB 等本身就是倍数的字段）"""
    if v is None:
        return None
    try:
        return round(float(v), 4)
    except (TypeError, ValueError):
        return v


def clean_market_cap(v):
    """v11新增：市值归一化，东财返回元，转为亿元"""
    if v is None:
        return None
    try:
        return round(float(v) / 100000000.0, 4)
    except (TypeError, ValueError):
        return v


def clean_quote(q: dict) -> dict:
    if not q:
        return {}
    # v17修复：新浪源返回的price/change_pct已是真实值，不应再/100
    # 东财源返回的price放大100倍（分→元），需要/100
    source = (q.get("source") or "").lower()
    is_sina = "sina" in source
    # 价格类字段：东财/100，新浪不处理
    clean_price = clean_raw if is_sina else clean_value
    return {
        "code": q.get("code"),
        "name": q.get("name"),
        "price": clean_price(q.get("price")),
        "change_pct": clean_price(q.get("change_pct")),
        "volume": q.get("volume"),
        "amount": q.get("amount"),
        "pe": clean_price(q.get("pe")),
        "pb": clean_price(q.get("pb")),
        "market_cap": clean_market_cap(q.get("market_cap")),
        "high": clean_price(q.get("high")),
        "low": clean_price(q.get("low")),
        "open": clean_price(q.get("open")),
        "prev_close": clean_price(q.get("prev_close")),
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
    # v13修复：以脚本所在目录为基准，不依赖工作目录
    script_dir = os.path.dirname(os.path.abspath(__file__))
    skill_root = os.path.dirname(script_dir)  # skills/investment-research-assistant/

    parser = argparse.ArgumentParser(description="清洗抓取数据")
    parser.add_argument("--input", required=True, help="原始数据 JSON")
    parser.add_argument("--outdir", default=None, help="输出目录（默认: {skill_root}/output/clean）")
    args = parser.parse_args()

    # v13修复：未指定outdir时，用skill_root/output/clean绝对路径
    outdir = args.outdir if args.outdir else os.path.join(skill_root, "output", "clean")
    outdir = os.path.normpath(outdir)

    # v13修复：如果input是相对路径，尝试用skill_root/output/raw解析
    input_path = args.input
    if not os.path.isabs(input_path) and not os.path.exists(input_path):
        candidate = os.path.join(skill_root, "output", "raw", os.path.basename(input_path))
        if os.path.exists(candidate):
            input_path = candidate
    input_path = os.path.normpath(input_path)

    with open(input_path, encoding="utf-8") as f:
        raw = json.load(f)

    cleaned = clean_records(raw)
    os.makedirs(outdir, exist_ok=True)
    out_file = os.path.join(outdir, os.path.basename(input_path))
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
