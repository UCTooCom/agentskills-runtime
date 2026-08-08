#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
智能投研助理 - Step 4: 研报生成（Generate Daily Brief）
基于要素数据生成每日投资简报 Markdown。
默认调用昇腾 API / AtomGit OpenAI 兼容接口（通过 runtime .env 配置）生成；
未配置 LLM 时降级为基于要素的模板化简报。

用法:
    python3 generate_report.py --factors output/factors/2026-08-07.json [--outdir output/brief]
环境变量:
    OPENAI_BASE_URL / LLM_BASE_URL   （默认 https://api-ai.gitcode.com/v1，AtomGit 昇腾 API）
    OPENAI_API_KEY / LLM_API_KEY
    LLM_MODEL                          （默认 deepseek-v4-flash）
"""

import argparse
import json
import os
import sys
import urllib.request
from datetime import datetime

try:
    import requests
    HAS_REQUESTS = True
except ImportError:
    HAS_REQUESTS = False


def llm_available() -> bool:
    return bool(os.environ.get("LLM_API_KEY") or os.environ.get("OPENAI_API_KEY"))


def call_llm(prompt: str) -> str:
    """调用 OpenAI 兼容接口（AtomGit 昇腾 API）生成简报"""
    base = os.environ.get("LLM_BASE_URL") or os.environ.get("OPENAI_BASE_URL") or "https://api-ai.gitcode.com/v1"
    key = os.environ.get("LLM_API_KEY") or os.environ.get("OPENAI_API_KEY") or "sk-dummy-key"
    model = os.environ.get("LLM_MODEL") or "deepseek-v4-flash"
    url = f"{base.rstrip('/')}/chat/completions"
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": "你是专业金融投研助理，输出结构化每日投资简报。内容仅供技术交流，不构成投资建议。"},
            {"role": "user", "content": prompt},
        ],
        "stream": False,
    }
    headers = {"Content-Type": "application/json", "Authorization": f"Bearer {key}"}
    if HAS_REQUESTS:
        resp = requests.post(url, json=payload, headers=headers, timeout=120)
        resp.raise_for_status()
        data = resp.json()
    else:
        req = urllib.request.Request(url, data=json.dumps(payload).encode("utf-8"), headers=headers)
        with urllib.request.urlopen(req, timeout=120) as r:
            data = json.loads(r.read().decode("utf-8"))
    return data["choices"][0]["message"]["content"]


def build_template_brief(factors_data: dict) -> str:
    """基于要素的模板化简报（无 LLM 时降级）"""
    lines = []
    date = factors_data.get("date", datetime.now().strftime("%Y-%m-%d"))
    for comp in factors_data.get("companies", []):
        mf = comp.get("market_factors") or {}
        lines.append(f"# 每日投资简报 - {comp.get('name') or comp.get('code')}")
        lines.append("")
        lines.append("## 行情概览")
        lines.append(f"- 收盘价: {mf.get('close_price')}  涨跌幅: {mf.get('change_pct')}%")
        lines.append(f"- PE: {mf.get('pe')}  PB: {mf.get('pb')}  总市值: {mf.get('market_cap')}")
        lines.append(f"- 情绪: {mf.get('sentiment')}")
        lines.append("")
        lines.append("## 核心看点")
        lines.append(f"- 当日事件/新闻数量: {comp.get('event_count', 0)} 条")
        lines.append("")
        lines.append("## 风险提示")
        for r in comp.get("risk_flags", []):
            lines.append(f"- {r}")
        lines.append("")
        lines.append("## 数据来源与免责声明")
        lines.append("> 本简报由智能投研助理自动生成，数据来源于公开市场接口，仅供技术交流，不构成任何投资建议。")
        lines.append("")
        lines.append("---")
        lines.append("")
    lines.append(f"> 生成时间: {date}")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="生成每日投资简报")
    parser.add_argument("--factors", required=True, help="要素 JSON")
    parser.add_argument("--outdir", default="output/brief", help="输出目录")
    args = parser.parse_args()

    with open(args.factors, encoding="utf-8") as f:
        factors_data = json.load(f)

    date = factors_data.get("date", datetime.now().strftime("%Y-%m-%d"))

    if llm_available():
        prompt = f"请基于以下数据生成 {date} 每日投资简报：\n{json.dumps(factors_data, ensure_ascii=False, indent=2)}"
        try:
            report = call_llm(prompt)
        except Exception as e:
            print(f"LLM 调用失败，降级模板生成: {e}", file=sys.stderr)
            report = build_template_brief(factors_data)
    else:
        report = build_template_brief(factors_data)

    os.makedirs(args.outdir, exist_ok=True)
    out_file = os.path.join(args.outdir, f"{date}.md")
    with open(out_file, "w", encoding="utf-8") as f:
        f.write(report)

    print(json.dumps({"success": True, "output": out_file, "llm_used": llm_available()}, ensure_ascii=False))


if __name__ == "__main__":
    main()
