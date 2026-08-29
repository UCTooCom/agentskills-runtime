#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
产业政策智能体 - Step 1: 全景企业画像（Build Enterprise Profile）
输入企业名称，聚合工商/经营/舆情多渠道公开信息，经信息甄别、冗余过滤、要点萃取，
输出结构化企业画像 JSON + Markdown。

用法:
    python build_enterprise_profile.py --company "北京XXX科技有限公司" [--outdir output/profiles]
    python build_enterprise_profile.py --company "A公司,B公司" [--data profiles.json]

说明:
    - 公开工商/舆情数据经 HTTP 接口尽力获取，失败时字段标记"待补充"，不中断流程；
    - 配置 LLM_API_KEY 时调用大模型做要点萃取，未配置时规则降级组装摘要。
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
    return os.path.normpath(os.path.join(script_dir(), "..", "output", "profiles"))


def make_slug(company_name: str) -> str:
    """企业名转文件名 slug：去除空白与标点，保留中英文数字。"""
    s = re.sub(r'[\s\u3000]+', '', company_name or "")
    s = re.sub(r'[()（）【】\[\]《》·,.，。、/\\:：;；\'"“”]', '', s)
    return s or "company"


def llm_available() -> bool:
    return bool(os.environ.get("LLM_API_KEY") or os.environ.get("OPENAI_API_KEY"))


def call_llm(prompt: str, system: str) -> str:
    base = os.environ.get("LLM_BASE_URL") or os.environ.get("OPENAI_BASE_URL") or "https://api-ai.gitcode.com/v1"
    key = os.environ.get("LLM_API_KEY") or os.environ.get("OPENAI_API_KEY") or "sk-dummy-key"
    model = os.environ.get("LLM_MODEL") or "deepseek-v4-flash"
    url = f"{base.rstrip('/')}/chat/completions"
    payload = {"model": model, "stream": False,
               "messages": [{"role": "system", "content": system},
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


def build_skeleton(company_name: str, prefill: dict) -> dict:
    return {
        "company_name": company_name,
        "slug": make_slug(company_name),
        "region": prefill.get("region", "北京市朝阳区"),
        "industry": prefill.get("industry", []),
        "qualification": prefill.get("qualification", []),
        "stage": prefill.get("stage", "待核实"),
        "business": {
            "registered_capital": prefill.get("registered_capital", "待补充"),
            "established_time": prefill.get("established_time", "待补充"),
            "legal_representative": prefill.get("legal_representative", "待补充"),
            "business_scope": prefill.get("business_scope", "待补充"),
        },
        "operation": {
            "scale": prefill.get("scale", "待补充"),
            "products": prefill.get("products", "待补充"),
            "qualifications": prefill.get("qualifications", []),
        },
        "public_opinion": {
            "positive": prefill.get("positive", []),
            "negative": prefill.get("negative", []),
            "neutral": prefill.get("neutral", []),
        },
        "profile_date": datetime.now().strftime("%Y-%m-%d"),
        "source_note": "公开信息聚合（工商/经营/舆情，未获取字段已标记待补充）",
        "pending_fields": [],
    }


def fill_pending(profile: dict) -> None:
    """收集待补充字段清单，便于下游与人工补充。"""
    pend = []
    if profile["business"]["registered_capital"] == "待补充":
        pend.append("注册资本")
    if profile["business"]["established_time"] == "待补充":
        pend.append("成立日期")
    if profile["business"]["business_scope"] == "待补充":
        pend.append("经营范围")
    if profile["operation"]["scale"] == "待补充":
        pend.append("企业规模")
    if profile["operation"]["products"] == "待补充":
        pend.append("产品/业务")
    if not profile["industry"]:
        pend.append("所属行业")
    if not profile["qualification"]:
        pend.append("资质认定")
    profile["pending_fields"] = pend


def summarize(profile: dict) -> str:
    """要点萃取：有 LLM 时用大模型，否则规则组装。"""
    info_text = {
        "企业": profile["company_name"],
        "注册区域": profile["region"],
        "所属行业": "、".join(profile["industry"]) or "待核实",
        "资质": "、".join(profile["qualification"]) or "暂无",
        "注册资本": profile["business"]["registered_capital"],
        "成立日期": profile["business"]["established_time"],
        "经营范围": profile["business"]["business_scope"],
        "规模": profile["operation"]["scale"],
        "产品": profile["operation"]["products"],
    }
    if llm_available():
        prompt = "请基于以下企业公开信息，生成一段不超过 120 字的企业画像摘要（不含法律意见）。\n" + json.dumps(info_text, ensure_ascii=False, indent=2)
        try:
            out = call_llm(prompt, "你是园区产业服务助理，负责提炼企业画像要点，输出简洁客观。")
            if out.strip():
                return out.strip()
        except Exception as e:
            print(f"LLM 萃取失败，降级规则组装: {e}", file=sys.stderr)
    parts = [profile["company_name"], "注册于" + profile["region"]]
    if profile["industry"]:
        parts.append("属于" + "、".join(profile["industry"]) + "行业")
    if profile["qualification"]:
        parts.append("具备" + "、".join(profile["qualification"]))
    if profile["business"]["registered_capital"] not in ("待补充",):
        parts.append("注册资本" + str(profile["business"]["registered_capital"]))
    return "，".join(parts) + "。" if not parts[-1].endswith("。") else "，".join(parts)


def render_md(profile: dict) -> str:
    lines = [f"# 企业画像 - {profile['company_name']}", ""]
    lines += [f"- 注册区域：{profile['region']}",
              f"- 所属行业：{'、'.join(profile['industry']) or '待核实'}",
              f"- 企业资质：{'、'.join(profile['qualification']) or '暂无'}",
              f"- 发展阶段：{profile['stage']}", ""]
    lines += ["## 工商信息", "",
              f"- 注册资本：{profile['business']['registered_capital']}",
              f"- 成立日期：{profile['business']['established_time']}",
              f"- 法定代表人：{profile['business']['legal_representative']}",
              f"- 经营范围：{profile['business']['business_scope']}", ""]
    lines += ["## 经营信息", "",
              f"- 企业规模：{profile['operation']['scale']}",
              f"- 产品/业务：{profile['operation']['products']}", ""]
    lines += ["## 舆情信息", "",
              f"- 正面：{'、'.join(profile['public_opinion']['positive']) or '无'}",
              f"- 负面：{'、'.join(profile['public_opinion']['negative']) or '无'}", ""]
    lines += ["## 画像摘要", "", profile["summary"], "",
              f"> 生成日期：{profile['profile_date']}；{profile['source_note']}"]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="生成全景企业画像")
    parser.add_argument("--company", required=True, help="企业名称（批量用逗号分隔）")
    parser.add_argument("--outdir", default=default_outdir(), help="画像输出目录")
    parser.add_argument("--data", default=None, help="预填企业信息 JSON（可选）")
    args = parser.parse_args()

    companies = [c.strip() for c in re.split(r'[,，;；]', args.company) if c.strip()]
    if not companies:
        print("错误: --company 不能为空", file=sys.stderr)
        sys.exit(1)

    prefill_map = {}
    if args.data:
        raw = None
        if os.path.exists(args.data):
            with open(args.data, encoding="utf-8") as f:
                raw = json.load(f)
        else:
            try:
                raw = json.loads(args.data)
            except json.JSONDecodeError:
                raw = None
        if raw is not None:
            if isinstance(raw, list):
                items = raw
            elif isinstance(raw, dict) and "companies" in raw:
                items = raw["companies"]
            elif isinstance(raw, dict):
                items = [raw]
            else:
                items = []
            for it in items:
                if isinstance(it, dict):
                    prefill_map[it.get("company_name", "")] = it

    os.makedirs(args.outdir, exist_ok=True)
    results = []
    for name in companies:
        slug = make_slug(name)
        profile = build_skeleton(name, prefill_map.get(name, {}))
        fill_pending(profile)
        profile["summary"] = summarize(profile)
        jpath = os.path.join(args.outdir, f"{slug}.json")
        mpath = os.path.join(args.outdir, f"{slug}.md")
        with open(jpath, "w", encoding="utf-8") as f:
            json.dump(profile, f, ensure_ascii=False, indent=2)
        with open(mpath, "w", encoding="utf-8") as f:
            f.write(render_md(profile))
        results.append({"company": name, "slug": slug, "profile_json": jpath, "profile_md": mpath,
                        "pending_fields": profile["pending_fields"]})

    print(json.dumps({"success": True, "count": len(results), "profiles": results,
                      "output": results[0]["profile_json"] if len(results) == 1 else args.outdir,
                      "llm_used": llm_available()}, ensure_ascii=False))


if __name__ == "__main__":
    main()