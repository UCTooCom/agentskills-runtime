#!/usr/bin/env python3
"""
风险分级研判（T5.3）

功能：
  - 从司法/行政处罚/经营异常等多源风险数据采集风险条目
  - 按明确规则分级（高/中/低），附分级依据说明（可解释）
  - 分级依据缺失标注"分级待定"及原因

用法：
  python tier_risks.py --input risk_data.json --enterprise "腾讯科技"
  python tier_risks.py --risk-data '{"judicial_cases":[...],"admin_penalties":[...],"operation_anomalies":[...]}'

输入 risk_data.json 格式（dd-fetch 返回的风险数据）：
  {
    "judicial_cases": [{"case_type": "被告", "amount": 1000000, "date": "2024-01-01", ...}],
    "admin_penalties": [{"penalty_type": "罚款", "amount": 50000, "date": "2024-03-01", ...}],
    "operation_anomalies": [{"anomaly_type": "经营异常", "date": "2024-05-01", ...}],
    "dishonest_records": [...],
    "tax_anomalies": [...]
  }

输出 output/risks/{name}.json：
  {
    "enterprise": "腾讯科技",
    "risks": [
      {
        "risk_type": "司法案件",
        "risk_level": "高",
        "level_basis": "作为被告且涉案金额≥100万",
        "risk_description": "...",
        "source_tool": "judicial-case",
        "source_data": {...}
      },
      ...
    ],
    "summary": {"high": 2, "medium": 3, "low": 1, "pending": 0}
  }
"""
import argparse
import json
import os
import sys
from typing import Dict, List, Any


HIGH_AMOUNT_THRESHOLD = 1_000_000
MEDIUM_AMOUNT_THRESHOLD = 100_000


def tier_judicial_cases(cases: List[Dict]) -> List[Dict]:
    risks = []
    for case in cases:
        case_type = case.get("case_type", "")
        amount = case.get("amount", 0) or 0
        date = case.get("date", "")

        if case_type in ("被告", "被执行人") and amount >= HIGH_AMOUNT_THRESHOLD:
            level = "高"
            basis = f"作为{case_type}且涉案金额≥{HIGH_AMOUNT_THRESHOLD}元"
        elif case_type in ("被告", "被执行人") and amount >= MEDIUM_AMOUNT_THRESHOLD:
            level = "中"
            basis = f"作为{case_type}且涉案金额≥{MEDIUM_AMOUNT_THRESHOLD}元"
        elif case_type in ("被告", "被执行人"):
            level = "低"
            basis = f"作为{case_type}且涉案金额<{MEDIUM_AMOUNT_THRESHOLD}元"
        elif case_type in ("原告",):
            level = "低"
            basis = "作为原告，风险较低"
        else:
            level = "分级待定"
            basis = f"案件类型'{case_type}'无明确分级规则"

        risks.append({
            "risk_type": "司法案件",
            "risk_level": level,
            "level_basis": basis,
            "risk_description": f"{case_type}案件，涉案金额{amount}元，日期{date}",
            "source_tool": "judicial-case",
            "source_data": case
        })
    return risks


def tier_admin_penalties(penalties: List[Dict]) -> List[Dict]:
    risks = []
    for pen in penalties:
        penalty_type = pen.get("penalty_type", "")
        amount = pen.get("amount", 0) or 0
        date = pen.get("date", "")

        if amount >= HIGH_AMOUNT_THRESHOLD:
            level = "高"
            basis = f"行政处罚金额≥{HIGH_AMOUNT_THRESHOLD}元"
        elif amount >= MEDIUM_AMOUNT_THRESHOLD:
            level = "中"
            basis = f"行政处罚金额≥{MEDIUM_AMOUNT_THRESHOLD}元"
        else:
            level = "低"
            basis = f"行政处罚金额<{MEDIUM_AMOUNT_THRESHOLD}元"

        risks.append({
            "risk_type": "行政处罚",
            "risk_level": level,
            "level_basis": basis,
            "risk_description": f"{penalty_type}，处罚金额{amount}元，日期{date}",
            "source_tool": "administrative-penalty",
            "source_data": pen
        })
    return risks


def tier_operation_anomalies(anomalies: List[Dict]) -> List[Dict]:
    risks = []
    for anom in anomalies:
        anomaly_type = anom.get("anomaly_type", "经营异常")
        date = anom.get("date", "")

        risks.append({
            "risk_type": "经营异常",
            "risk_level": "中",
            "level_basis": "存在经营异常记录",
            "risk_description": f"{anomaly_type}，日期{date}",
            "source_tool": "operation-anomaly",
            "source_data": anom
        })
    return risks


def tier_dishonest_records(records: List[Dict]) -> List[Dict]:
    risks = []
    for rec in records:
        risks.append({
            "risk_type": "失信记录",
            "risk_level": "高",
            "level_basis": "存在失信被执行人记录",
            "risk_description": f"失信记录：{rec.get('description', '无描述')}",
            "source_tool": "dishonest-record",
            "source_data": rec
        })
    return risks


def tier_tax_anomalies(records: List[Dict]) -> List[Dict]:
    risks = []
    for rec in records:
        risks.append({
            "risk_type": "税务异常",
            "risk_level": "高",
            "level_basis": "存在税务异常记录",
            "risk_description": f"税务异常：{rec.get('description', '无描述')}",
            "source_tool": "tax-anomaly",
            "source_data": rec
        })
    return risks


def tier_risks(risk_data: Dict[str, Any], enterprise: str = "") -> Dict[str, Any]:
    all_risks: List[Dict] = []

    all_risks.extend(tier_judicial_cases(risk_data.get("judicial_cases", [])))
    all_risks.extend(tier_admin_penalties(risk_data.get("admin_penalties", [])))
    all_risks.extend(tier_operation_anomalies(risk_data.get("operation_anomalies", [])))
    all_risks.extend(tier_dishonest_records(risk_data.get("dishonest_records", [])))
    all_risks.extend(tier_tax_anomalies(risk_data.get("tax_anomalies", [])))

    summary = {"high": 0, "medium": 0, "low": 0, "pending": 0}
    for r in all_risks:
        level = r["risk_level"]
        if level == "高":
            summary["high"] += 1
        elif level == "中":
            summary["medium"] += 1
        elif level == "低":
            summary["low"] += 1
        else:
            summary["pending"] += 1

    return {
        "enterprise": enterprise,
        "risks": all_risks,
        "summary": summary
    }


def main():
    parser = argparse.ArgumentParser(description="风险分级研判")
    parser.add_argument("--input", type=str, default="", help="风险数据 JSON 文件路径")
    parser.add_argument("--risk-data", type=str, default="", help="风险数据 JSON 字符串")
    parser.add_argument("--enterprise", type=str, default="", help="企业名称")
    parser.add_argument("--outdir", type=str, default="output/risks", help="输出目录")
    args = parser.parse_args()

    if args.input:
        with open(args.input, "r", encoding="utf-8") as f:
            risk_data = json.load(f)
    elif args.risk_data:
        risk_data = json.loads(args.risk_data)
    else:
        print(json.dumps({"error": "请通过 --input 或 --risk-data 提供风险数据"},
                         ensure_ascii=False))
        sys.exit(1)

    result = tier_risks(risk_data, args.enterprise)

    enterprise_name = args.enterprise or result.get("enterprise", "unknown")
    os.makedirs(args.outdir, exist_ok=True)
    safe_name = enterprise_name.replace("/", "_").replace("\\", "_")
    output_path = os.path.join(args.outdir, f"{safe_name}.json")
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    result["output_path"] = output_path
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()