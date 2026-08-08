#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
智能投研助理 - Step 3: 要素提取（Extract Factors）
从清洗后数据中提取结构化投资要素（行情指标、事件、情绪、风险提示）。

用法:
    python3 extract_factors.py --input output/clean/2026-08-07.json [--outdir output/factors]
"""

import argparse
import json
import os
import sys


def extract_quote_factors(q: dict) -> dict:
    """行情要素提取"""
    if not q:
        return {}
    change_pct = q.get("change_pct")
    price = q.get("price")
    pe = q.get("pe")
    pb = q.get("pb")
    market_cap = q.get("market_cap")

    # 情绪倾向：涨跌幅映射
    sentiment = "neutral"
    if change_pct is not None:
        if change_pct > 2:
            sentiment = "positive"
        elif change_pct < -2:
            sentiment = "negative"

    return {
        "close_price": price,
        "change_pct": change_pct,
        "pe": pe,
        "pb": pb,
        "market_cap": market_cap,
        "sentiment": sentiment,
        "volatility_flag": bool(change_pct is not None and abs(change_pct) >= 5),
    }


def extract_risk_factors(factors: dict, news_count: int) -> list:
    """风险提示提取"""
    risks = []
    if factors.get("volatility_flag"):
        risks.append("当日涨跌幅波动较大（≥5%），注意短期波动风险")
    if factors.get("pe") is not None and factors["pe"] > 60:
        risks.append("市盈率偏高（>60），估值需谨慎")
    if factors.get("sentiment") == "negative":
        risks.append("当日市场情绪偏负面")
    if news_count == 0:
        risks.append("当日未获取到有效公告/新闻数据，信息覆盖有限")
    if not risks:
        risks.append("未发现显著风险信号")
    return risks


def main():
    parser = argparse.ArgumentParser(description="提取投资要素")
    parser.add_argument("--input", required=True, help="清洗后数据 JSON")
    parser.add_argument("--outdir", default="output/factors", help="输出目录")
    args = parser.parse_args()

    with open(args.input, encoding="utf-8") as f:
        cleaned = json.load(f)

    result = {
        "date": cleaned.get("date"),
        "companies": [],
    }

    for comp in cleaned.get("companies", []):
        qf = extract_quote_factors(comp.get("quotes") or {})
        news_count = len(comp.get("news") or [])
        risks = extract_risk_factors(qf, news_count)
        result["companies"].append({
            "code": comp.get("code"),
            "name": comp.get("name"),
            "market_factors": qf,
            "event_count": news_count,
            "risk_flags": risks,
        })

    os.makedirs(args.outdir, exist_ok=True)
    out_file = os.path.join(args.outdir, os.path.basename(args.input))
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    print(json.dumps({
        "success": True,
        "output": out_file,
        "company_count": len(result["companies"]),
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
