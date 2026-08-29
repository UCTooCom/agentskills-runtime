#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
金融匹配智能体 - Step 1: 融资需求采集与初步审核（Collect Financing Need）
结构化采集企业融资需求，完整性校验 + 可行性初判，生成 case_id，进入 SOP 阶段一。

用法:
    python collect_financing_need.py --company "公司名" --amount "500万" --purpose "研发投入" [--term 2年] [--guarantee 信用]

说明:
    - 必填项缺失时输出补全提示，档案状态 draft；
    - 通过校验后状态 intaked，生成 case_id，阶段一截止 = 1 个工作日；
    - 若存在对应企业画像（output/profiles），自动带入画像信息。
"""

import argparse
import json
import os
import re
import sys
import uuid
from datetime import datetime, timedelta


def script_dir():
    return os.path.dirname(os.path.abspath(__file__))


def default_outdir():
    return os.path.normpath(os.path.join(script_dir(), "..", "output", "needs"))


def default_profiles():
    return os.path.normpath(os.path.join(script_dir(), "..", "..", "beichen-policy-assistant", "output", "profiles"))


def make_slug(s):
    s = re.sub(r'[\s\u3000]+', '', s or "")
    s = re.sub(r'[()（）【】\[\]《》·,.，。、/\\:：;；\'"“”]', '', s)
    return s or "company"


def parse_amount(amount: str):
    """解析金额字符串为 (数值, 单位)，如 '500万' -> (500.0, '万')。"""
    m = re.search(r'([\d.]+)\s*(万|亿|元|千)?', amount or "")
    if not m:
        return None, None
    return float(m.group(1)), (m.group(2) or "元")


def amount_to_wan(value, unit) -> float:
    """统一折算为万元。"""
    if unit == "亿":
        return value * 10000
    if unit == "万":
        return value
    return value / 10000


def add_workdays(start: datetime, days: int) -> str:
    d = start
    while days > 0:
        d += timedelta(days=1)
        if d.weekday() < 5:  # 周六(5)/周日(6)跳过
            days -= 1
    return d.strftime("%Y-%m-%d")


def feasibility_check(need: dict) -> list:
    """可行性初判（规则可解释），返回提示列表。"""
    tips = []
    val, unit = parse_amount(need.get("amount", ""))
    if val is None:
        tips.append("金额格式无法识别，请使用如 500万 / 3000万")
    rev_val, rev_unit = parse_amount(need.get("revenue", "")) if need.get("revenue") else (None, None)
    if val is not None and rev_val is not None:
        amt = amount_to_wan(val, unit)
        rev = amount_to_wan(rev_val, rev_unit)
        if rev > 0 and amt / rev > 1.0:
            tips.append("融资金额超过上年度营收，建议补充抵质押或降低额度")
    purpose = need.get("purpose", "")
    if purpose and purpose not in ("流动资金", "研发投入", "设备采购", "股权融资", "并购", "其他"):
        tips.append("融资用途建议从 流动资金/研发投入/设备采购/股权融资/并购 中选择")
    return tips


def main():
    parser = argparse.ArgumentParser(description="融资需求采集与初步审核")
    parser.add_argument("--company", required=True, help="企业名称")
    parser.add_argument("--amount", required=True, help="融资金额（如 500万）")
    parser.add_argument("--purpose", required=True, help="融资用途")
    parser.add_argument("--term", default="", help="融资期限（如 2年）")
    parser.add_argument("--guarantee", default="", help="可接受担保方式（信用/抵押/质押/保证）")
    parser.add_argument("--revenue", default="", help="营收概况（粗粒度）")
    parser.add_argument("--outdir", default=default_outdir(), help="需求档案输出目录")
    args = parser.parse_args()

    company = args.company.strip()
    if not company:
        print("错误: --company 不能为空", file=sys.stderr)
        sys.exit(1)

    need = {
        "case_id": f"FC-{datetime.now().strftime('%Y%m%d')}-{uuid.uuid4().hex[:6].upper()}",
        "company_name": company,
        "amount": args.amount,
        "purpose": args.purpose,
        "term": args.term or "待补充",
        "guarantee": args.guarantee or "待补充",
        "revenue": args.revenue or "待补充",
        "created_at": datetime.now().isoformat(),
        "profile": {},
    }

    # 自动带入企业画像（若存在）
    profile_path = os.path.join(default_profiles(), f"{make_slug(company)}.json")
    if os.path.exists(profile_path):
        with open(profile_path, encoding="utf-8") as f:
            need["profile"] = json.load(f)

    missing = [k for k in ("amount", "purpose") if not need.get(k)]
    feasibility = feasibility_check(need)
    if missing or feasibility:
        need["status"] = "draft"
        need["validation"] = {"missing": missing, "feasibility_tips": feasibility}
    else:
        need["status"] = "intaked"
        need["validation"] = {"missing": [], "feasibility_tips": []}
        need["sop_stage"] = 1
        need["sop_stage_name"] = "资料提交与审核"
        need["due_date"] = add_workdays(datetime.now(), 1)
        need["owner"] = ""

    os.makedirs(args.outdir, exist_ok=True)
    out = os.path.join(args.outdir, f"{need['case_id']}.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(need, f, ensure_ascii=False, indent=2)

    print(json.dumps({"success": True, "case_id": need["case_id"], "status": need["status"],
                      "output": out, "missing": missing, "feasibility_tips": feasibility,
                      "due_date": need.get("due_date", "")}, ensure_ascii=False))


if __name__ == "__main__":
    main()