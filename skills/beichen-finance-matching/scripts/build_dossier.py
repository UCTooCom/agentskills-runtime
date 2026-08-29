#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
金融匹配智能体 - Step 4: 对接材料包（Build Dossier）
按目标机构类型生成标准材料清单，预填需求档案与画像已有信息，标注缺失材料与获取路径。

用法:
    python build_dossier.py --need {需求json} --partner "光大银行" [--kb knowledge]
"""

import argparse
import json
import os
import sys

BANK_MATERIALS = [
    ("营业执照（副本）", "提供企业营业执照复印件并加盖公章"),
    ("近两年财务报告", "提供近两个完整年度审计报告或财务报表"),
    ("纳税记录", "电子税务局打印最近 12 个月完税证明"),
    ("经营流水", "主要对公账户近 6 个月银行流水"),
    ("融资用途说明", "说明融资金额、用途与还款来源"),
    ("担保/抵质押材料", "如涉及抵质押，提供资产权属证明"),
]

EQUITY_MATERIALS = [
    ("商业计划书（BP）", "含商业模式、市场、团队、财务预测"),
    ("股权结构说明", "提供股东名册与股权结构图"),
    ("近两年财务报告", "提供审计报告或财务报表"),
    ("尽调材料", "业务合同、知识产权、合规证明等"),
    ("融资需求与估值说明", "说明融资额度、出让比例与资金用途"),
]


def script_dir():
    return os.path.dirname(os.path.abspath(__file__))


def default_kb():
    return os.path.normpath(os.path.join(script_dir(), "..", "knowledge"))


def default_outdir():
    return os.path.normpath(os.path.join(script_dir(), "..", "output", "dossiers"))


def find_partner_type(kb: str, name: str) -> str:
    index_path = os.path.join(kb, "finance-index.json")
    if not os.path.exists(index_path):
        return "bank"
    with open(index_path, encoding="utf-8") as f:
        index = json.load(f)
    for p in index.get("partners", []):
        if p.get("name") == name:
            return p.get("type", "bank")
    return "bank"


def main():
    parser = argparse.ArgumentParser(description="生成对接材料包")
    parser.add_argument("--need", required=True, help="融资需求档案 JSON")
    parser.add_argument("--partner", required=True, help="目标金融机构名称")
    parser.add_argument("--kb", default=default_kb(), help="知识库根目录")
    parser.add_argument("--outdir", default=default_outdir(), help="材料包输出目录")
    args = parser.parse_args()

    with open(args.need, encoding="utf-8") as f:
        need = json.load(f)

    ptype = find_partner_type(args.kb, args.partner)
    materials = EQUITY_MATERIALS if ptype in ("securities", "fund", "investor") else BANK_MATERIALS

    profile = need.get("profile") or {}
    region = profile.get("region", "待补充")
    lines = [f"# 对接材料包 - {need.get('company_name', '')} → {args.partner}", "",
             "## 融资需求信息（预填）", "",
             f"- 企业名称：{need.get('company_name', '')}",
             f"- 注册区域：{region}",
             f"- 融资金额：{need.get('amount', '')}",
             f"- 融资期限：{need.get('term', '')}",
             f"- 融资用途：{need.get('purpose', '')}",
             f"- 担保方式：{need.get('guarantee', '')}",
             f"- 营收概况：{need.get('revenue', '')}",
             f"- 服务单号：{need.get('case_id', '')}", "",
             "## 需准备材料清单", "",
             "| 序号 | 材料 | 说明 / 获取路径 | 状态 |",
             "|------|------|----------------|------|"]
    for i, (name, note) in enumerate(materials, 1):
        lines.append(f"| {i} | {name} | {note} | 待提交 |")
    lines += ["", "## 提示", "",
              "- 带“待补充”字段请在对接前补齐；",
              "- 财务信息属敏感数据，请通过合规渠道提交并做好脱敏。", ""]

    os.makedirs(args.outdir, exist_ok=True)
    case_id = need.get("case_id", os.path.splitext(os.path.basename(args.need))[0])
    out = os.path.join(args.outdir, f"{case_id}-{args.partner}.md")
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    print(json.dumps({"success": True, "output": out, "partner": args.partner,
                      "material_count": len(materials)}, ensure_ascii=False))


if __name__ == "__main__":
    main()