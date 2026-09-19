#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
金融匹配智能体 - Step 3: 定制金融方案（Generate Finance Plan）
基于融资需求 + 匹配矩阵生成定制融资方案 Markdown。
默认调用昇腾 API / AtomGit 生成；未配置 LLM 时降级为模板（矩阵直出对比表）。

用法:
    python generate_finance_plan.py --need {需求json} --matches {匹配json} [--outdir output/plans]
"""

import argparse
import json
import os
import sys
import urllib.request

try:
    import requests
    HAS_REQUESTS = True
except ImportError:
    HAS_REQUESTS = False


def script_dir():
    return os.path.dirname(os.path.abspath(__file__))


def default_outdir():
    return os.path.normpath(os.path.join(script_dir(), "..", "output", "plans"))


def llm_available() -> bool:
    return bool(os.environ.get("LLM_API_KEY") or os.environ.get("OPENAI_API_KEY"))


def call_llm(prompt: str) -> str:
    base = os.environ.get("LLM_BASE_URL") or os.environ.get("OPENAI_BASE_URL") or "https://api-ai.gitcode.com/v1"
    key = os.environ.get("LLM_API_KEY") or os.environ.get("OPENAI_API_KEY") or "sk-dummy-key"
    model = os.environ.get("LLM_MODEL") or "deepseek-flash"
    url = f"{base.rstrip('/')}/chat/completions"
    payload = {"model": model, "stream": False,
               "messages": [{"role": "system",
                             "content": "你是园区产业金融服务顾问，输出定制融资方案。方案仅供融资决策参考，不构成投资建议，最终以金融机构审批为准。"},
                            {"role": "user", "content": prompt}]}
    headers = {"Content-Type": "application/json", "Authorization": f"Bearer {key}"}
    if HAS_REQUESTS:
        resp = requests.post(url, json=payload, headers=headers, timeout=120)
        resp.raise_for_status()
        data = resp.json()
    else:
        req = urllib.request.Request(url, data=json.dumps(payload).encode("utf-8"), headers=headers)
        with urllib.request.urlopen(req, timeout=120) as r:
            data = json.loads(r.read().decode("utf-8"))
    choices = data.get("choices") or []
    if not choices:
        raise ValueError("LLM 返回空 choices")
    return choices[0].get("message", {}).get("content", "")


def build_template_plan(need: dict, matches: dict, policies: list) -> str:
    lines = [f"# 定制融资方案 - {need.get('company_name', '')}", "",
             "## 需求概览", "",
             f"- 融资金额：{need.get('amount', '')}",
             f"- 融资期限：{need.get('term', '')}",
             f"- 融资用途：{need.get('purpose', '')}",
             f"- 担保方式：{need.get('guarantee', '')}",
             f"- 服务单号：{need.get('case_id', '')}", "",
             "## 备选机构方案对比", "",
             "| 机构 | 推荐产品 | 产品类型 | 额度 | 期限 | 担保 | 匹配度 |",
             "|------|---------|---------|------|------|------|--------|"]
    for m in matches.get("matches", []):
        partner = m.get("partner")
        prods = m.get("products", [])
        if prods:
            for p in prods[:2]:
                lines.append(f"| {partner} | {p.get('name')} | {p.get('type')} | {p.get('amount')} | {p.get('term')} | {p.get('guarantee')} | {m.get('score')} |")
        else:
            lines.append(f"| {partner} | — | — | — | — | — | {m.get('score')} |")
    lines += ["", "## 各方案适配理由", ""]
    for m in matches.get("matches", []):
        lines.append(f"### {m.get('partner')}（匹配度 {m.get('score')}）")
        lines.append(f"- 匹配依据：{m.get('basis')}")
        lines.append(f"- 优势领域：{'、'.join(m.get('strength_domains', []))}")
        lines.append("")
    lines += ["## 组合融资建议", ""]
    if policies:
        lines.append("可叠加以下金融类政策降低综合成本：")
        for pol in policies[:5]:
            lines.append(f"- {pol.get('name')}（{pol.get('provider')}）：{pol.get('detail')}")
    else:
        lines.append("- 可考虑\"信贷 + 贴息\"组合，具体以机构审批与政策兑现为准。")
    lines += ["", "## 风险提示", "",
              "- 融资可行性、利率与放款以金融机构独立审批为准。",
              "- 产品额度/利率为公开资料区间，实际以合同条款为准。", "",
              "## 对接路径", "",
              "1. 企业与匹配机构联系人对接，提交对接材料包；",
              "2. 机构审核资料并出具初步方案；",
              "3. 双方洽谈细节并签约落地。", "",
              "## 合规声明", "",
              "> 本方案由金融匹配智能体自动生成，仅供融资决策参考，不构成投资建议，最终以金融机构审批为准。", ""]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="生成定制融资方案")
    parser.add_argument("--need", required=True, help="融资需求档案 JSON")
    parser.add_argument("--matches", required=True, help="匹配矩阵 JSON")
    parser.add_argument("--outdir", default=default_outdir(), help="方案输出目录")
    args = parser.parse_args()

    with open(args.need, encoding="utf-8") as f:
        need = json.load(f)
    with open(args.matches, encoding="utf-8") as f:
        matches = json.load(f)

    # 金融类政策（用于组合融资建议，随匹配矩阵或索引引用）
    policies = matches.get("finance_policies", [])

    llm_used = False
    if llm_available():
        prompt = f"请基于以下融资需求与匹配结果，生成定制融资方案（Markdown：需求概览、备选方案对比表、逐方案适配理由、组合融资建议、风险提示、对接路径）。\n需求：{json.dumps(need, ensure_ascii=False, indent=2)}\n匹配：{json.dumps(matches, ensure_ascii=False, indent=2)}"
        try:
            plan = call_llm(prompt)
            if plan.strip():
                llm_used = True
            else:
                plan = build_template_plan(need, matches, policies)
        except Exception as e:
            print(f"LLM 调用失败，降级模板生成: {e}", file=sys.stderr)
            plan = build_template_plan(need, matches, policies)
    else:
        plan = build_template_plan(need, matches, policies)

    if "不构成投资建议" not in plan:
        plan += "\n\n> 本方案仅供融资决策参考，不构成投资建议，最终以金融机构审批为准。\n"

    os.makedirs(args.outdir, exist_ok=True)
    case_id = need.get("case_id", os.path.splitext(os.path.basename(args.need))[0])
    out = os.path.join(args.outdir, f"{case_id}.md")
    with open(out, "w", encoding="utf-8") as f:
        f.write(plan)

    print(json.dumps({"success": True, "output": out, "llm_used": llm_used}, ensure_ascii=False))


if __name__ == "__main__":
    main()