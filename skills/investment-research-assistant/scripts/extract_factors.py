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
    # v8 修复：pe 经 clean 已 /100 还原为真实值，但东财可能返回非数值，需 isinstance 守卫避免 TypeError
    if isinstance(factors.get("pe"), (int, float)) and factors["pe"] > 60:
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
    # v17修复：--outdir 默认值改为基于脚本所在目录的绝对路径，避免 cwd 不一致导致相对路径写到了别处
    # 根因：原 default="output/factors"（相对路径），agent 调用 cli_execute 时 cwd 可能是 runtime 项目根目录而非投研技能目录，
    #       导致 output/factors 目录不存在，第 4 步 generate_report.py 报 FileNotFoundError，链路断链
    _script_dir = os.path.dirname(os.path.abspath(__file__))
    _default_outdir = os.path.normpath(os.path.join(_script_dir, "..", "output", "factors"))
    parser.add_argument("--outdir", default=_default_outdir, help="输出目录")
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
