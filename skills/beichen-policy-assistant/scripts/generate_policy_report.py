#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
产业政策智能体 - Step 3: 适配研判报告（Generate Policy Report）
基于企业画像 + 匹配矩阵生成结构化适配研判报告 Markdown。
默认调用昇腾 API / AtomGit 生成；未配置 LLM 时降级为模板生成（矩阵直出对比表）。

用法:
    python generate_policy_report.py --profile {画像json} --matches {匹配json} [--outdir output/reports]
"""

import argparse
import json
import os
import re
import sys
import urllib.request
from datetime import datetime

try:
    import requests
    HAS_REQUESTS = True
except ImportError:
    HAS_REQUESTS = False


def script_dir():
    return os.path.dirname(os.path.abspath(__file__))


def default_outdir():
    return os.path.normpath(os.path.join(script_dir(), "..", "output", "reports"))


def llm_available() -> bool:
    return bool(os.environ.get("LLM_API_KEY") or os.environ.get("OPENAI_API_KEY"))


def call_llm(prompt: str) -> str:
    base = os.environ.get("LLM_BASE_URL") or os.environ.get("OPENAI_BASE_URL") or "https://api-ai.gitcode.com/v1"
    key = os.environ.get("LLM_API_KEY") or os.environ.get("OPENAI_API_KEY") or "sk-dummy-key"
    model = os.environ.get("LLM_MODEL") or "deepseek-v4-flash"
    url = f"{base.rstrip('/')}/chat/completions"
    payload = {"model": model, "stream": False,
               "messages": [{"role": "system",
                             "content": "你是园区产业政策研判助手，输出结构化政策适配报告。内容仅供申报参考，不构成法律意见。"},
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


def check_condition(cond_val: str, profile: dict, kind: str) -> str:
    """对比单项申报条件与画像现状，返回 满足/部分满足/不满足/待核实。"""
    if not cond_val:
        return "满足"
    if kind == "region":
        return "满足" if (cond_val in profile.get("region", "") or profile.get("region", "") in cond_val or cond_val == "北京市") else "不满足"
    if kind == "qualification":
        qual = "、".join(profile.get("qualification", []) or [])
        return "满足" if (cond_val in qual or any(k in qual for k in ["高新技术", "专精特新", "科技型"])) else ("待核实" if not qual else "不满足")
    if kind == "industry":
        inds = set(profile.get("industry", []) or [])
        return "满足" if (not cond_val or inds & set(cond_val)) else "部分满足"
    return "待核实"


def build_template_report(profile: dict, matches: dict) -> str:
    lines = [f"# 政策适配研判报告 - {profile.get('company_name', '')}", ""]
    lines.append(f"- 生成日期：{matches.get('match_date', '')}")
    lines.append(f"- 注册区域：{profile.get('region', '')}")
    lines.append(f"- 所属行业：{'、'.join(profile.get('industry', [])) or '待核实'}")
    lines.append(f"- 企业资质：{'、'.join(profile.get('qualification', [])) or '暂无'}")
    lines.append("")
    lines.append("## 匹配政策清单（按匹配度排序）")
    lines.append("")
    lines.append("| 序号 | 政策编号 | 政策名称 | 层级/领域 | 匹配度 | 匹配依据 |")
    lines.append("|------|---------|---------|----------|--------|---------|")
    for i, m in enumerate(matches.get("matches", []), 1):
        lines.append(f"| {i} | {m.get('policy_no')} | {m.get('title')} | {m.get('level')}/{m.get('domain')} | {m.get('score')} | {m.get('basis')} |")
    lines.append("")
    lines.append("## 申报条件对标分析")
    lines.append("")
    for m in matches.get("matches", []):
        lines.append(f"### 政策 {m.get('policy_no')} - {m.get('title')}")
        cond = m.get("conditions") or {}
        if cond.get("region"):
            lines.append(f"- 注册区域（条件 {cond['region']}）：{check_condition(cond['region'], profile, 'region')}")
        if cond.get("qualification"):
            lines.append(f"- 资质要求（条件 {cond['qualification']}）：{check_condition(cond['qualification'], profile, 'qualification')}")
        if cond.get("industry"):
            lines.append(f"- 行业要求（条件 {'、'.join(cond['industry'])}）：{check_condition(cond['industry'], profile, 'industry')}")
        gaps = m.get("gap") or []
        if gaps:
            lines.append(f"- 缺口项：{'、'.join(gaps)}")
        else:
            lines.append("- 缺口项：无（以申报通知为准）")
        lines.append("")
    lines.append("## 申报建议与优先级")
    lines.append("")
    for i, m in enumerate(matches.get("matches", [])[:5], 1):
        lines.append(f"{i}. 【高优先级】可申报" + (f"（匹配度 {m.get('score')} 分）" if m.get('score') else ""))
        lines.append(f"   - 政策：{m.get('title')}（编号 {m.get('policy_no')}）")
        lines.append(f"   - 支持方式：{m.get('support', '待补充')}")
        lines.append(f"   - 建议关注 {m.get('department', '')} 官网申报通知")
    lines.append("")
    lines.append("## 合规声明")
    lines.append("")
    lines.append("> 本报告由产业政策智能体自动生成，数据来源于公开渠道与政策知识库，每条匹配结论均已溯源至政策原文库编号；仅供申报参考，不构成法律意见。")
    lines.append("")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="生成政策适配研判报告")
    parser.add_argument("--profile", required=True, help="企业画像 JSON")
    parser.add_argument("--matches", required=True, help="匹配矩阵 JSON")
    parser.add_argument("--outdir", default=default_outdir(), help="报告输出目录")
    args = parser.parse_args()

    with open(args.profile, encoding="utf-8") as f:
        profile = json.load(f)
    with open(args.matches, encoding="utf-8") as f:
        matches = json.load(f)

    date = matches.get("match_date", datetime.now().strftime("%Y-%m-%d"))
    llm_used = False
    if llm_available():
        prompt = f"请基于以下企业画像与匹配矩阵，生成政策适配研判报告（Markdown，含匹配清单、条件对标表、缺口分析、申报建议）。\n画像：{json.dumps(profile, ensure_ascii=False, indent=2)}\n匹配矩阵：{json.dumps(matches, ensure_ascii=False, indent=2)}"
        try:
            report = call_llm(prompt)
            if report.strip():
                llm_used = True
            else:
                report = build_template_report(profile, matches)
        except Exception as e:
            print(f"LLM 调用失败，降级模板生成: {e}", file=sys.stderr)
            report = build_template_report(profile, matches)
    else:
        report = build_template_report(profile, matches)

    if not report.rstrip().endswith("不构成法律意见。") and "不构成法律意见" not in report:
        report += "\n\n> 本报告仅供申报参考，不构成法律意见。\n"

    os.makedirs(args.outdir, exist_ok=True)
    slug = profile.get("slug", os.path.splitext(os.path.basename(args.profile))[0])
    out = os.path.join(args.outdir, f"{slug}-{date}.md")
    with open(out, "w", encoding="utf-8") as f:
        f.write(report)

    print(json.dumps({"success": True, "output": out, "llm_used": llm_used}, ensure_ascii=False))


if __name__ == "__main__":
    main()