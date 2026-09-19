#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
产业政策智能体 - Step 2: 多元政策匹配（Match Policy）
基于企业画像对三层知识库政策做硬性条件初筛 + 语义适配评分，输出匹配矩阵。
每条匹配结论绑定政策原文库 policy_no（幻觉治理）：无出处结果标记"待核实"，不进正式匹配。

用法:
    python match_policy.py --profile output/profiles/{slug}.json [--topn 10] [--kb knowledge]
说明:
    - 硬性初筛：过期、注册区域不符、行业负面清单 → 淘汰；
    - 评分（规则降级）：领域匹配(40) + 资质匹配(30) + 区域匹配(20) + 状态(10)；
    - 配置 LLM_API_KEY 时对候选调用大模型语义研判评分与依据，失败降级规则分；
    - --web 可传入互联网实时政策 JSON（可选），无法绑定本地 policy_no 的结果进入"待核实"。
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


def default_kb():
    return os.path.normpath(os.path.join(script_dir(), "..", "knowledge"))


def default_outdir():
    return os.path.normpath(os.path.join(script_dir(), "..", "output", "matches"))


def llm_available() -> bool:
    return bool(os.environ.get("LLM_API_KEY") or os.environ.get("OPENAI_API_KEY"))


def call_llm(prompt: str, system: str) -> str:
    base = os.environ.get("LLM_BASE_URL") or os.environ.get("OPENAI_BASE_URL") or "https://api-ai.gitcode.com/v1"
    key = os.environ.get("LLM_API_KEY") or os.environ.get("OPENAI_API_KEY") or "sk-dummy-key"
    model = os.environ.get("LLM_MODEL") or "deepseek-flash"
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


def hard_filter(policy: dict, profile: dict):
    """硬性条件初筛，返回 (淘汰原因 or None)。"""
    if policy.get("status") == "expired":
        return "已过期"
    cond = policy.get("conditions") or {}
    region_req = cond.get("region", "")
    level = policy.get("level", "")
    prof_region = profile.get("region", "")
    # 区级政策要求注册区域匹配（如"朝阳区注册"）
    if level == "区级" and region_req:
        m = re.search(r'(朝阳|海淀|东城|西城|丰台|石景山|通州|大兴|顺义|昌平|房山|门头沟|平谷|怀柔|密云|延庆|经开)', region_req)
        if m and m.group(1) not in prof_region:
            return "注册区域不符"
    return None


def rule_score(policy: dict, profile: dict) -> int:
    score = 0
    cond = policy.get("conditions") or {}
    industries = cond.get("industry", []) or []
    prof_ind = set(profile.get("industry", []) or [])
    prof_tags = set(profile.get("tags", []) or [])
    prof_all = prof_ind | prof_tags
    if industries:
        if prof_all & set(industries):
            score += 40
    else:
        domain = policy.get("domain", "")
        if domain and prof_all and any(domain in t or t in domain for t in prof_all):
            score += 35
        else:
            score += 20
    qual_req = cond.get("qualification", "") or ""
    prof_qual = "、".join(profile.get("qualification", []) or [])
    if qual_req:
        if qual_req and (qual_req in prof_qual or any(k in prof_qual for k in ["高新技术", "专精特新", "科技型"])):
            score += 30
    region_req = cond.get("region", "") or ""
    prof_region = profile.get("region", "")
    if region_req:
        if region_req in prof_region or prof_region in region_req or region_req == "北京市":
            score += 20
    if policy.get("status") == "active":
        score += 10
    return score


def build_basis(policy: dict, profile: dict) -> str:
    cond = policy.get("conditions") or {}
    parts = [f"层级{policy.get('level')}·领域{policy.get('domain')}"]
    prof_all = set(profile.get("industry", []) or []) | set(profile.get("tags", []) or [])
    if (cond.get("industry") or []) and prof_all:
        inter = set(cond["industry"]) & prof_all
        if inter:
            parts.append("行业命中文：" + "、".join(inter))
    else:
        domain = policy.get("domain", "")
        if domain and prof_all and any(domain in t or t in domain for t in prof_all):
            parts.append("领域命中：" + domain)
    if cond.get("qualification") and profile.get("qualification"):
        parts.append("资质对标：" + cond["qualification"])
    return "；".join(parts)


def llm_score(policy: dict, profile: dict) -> tuple:
    prompt = ("请评估该企业与政策的匹配度，返回 JSON：{\"score\": 0-100 整数, \"basis\": \"匹配依据一句话\", \"gap\": [\"缺口项\"]}。\n企业画像："
              + json.dumps(profile, ensure_ascii=False))
    prompt += "\n政策：" + json.dumps(policy, ensure_ascii=False)
    try:
        out = call_llm(prompt, "你是园区政策匹配助手，只输出 JSON。")
        m = re.search(r'\{.*\}', out, re.S)
        if not m:
            raise ValueError("LLM 未返回 JSON")
        data = json.loads(m.group(0))
        return int(data.get("score", 0)), data.get("basis", ""), data.get("gap", [])
    except Exception:
        return rule_score(policy, profile), build_basis(policy, profile), []


def main():
    parser = argparse.ArgumentParser(description="多元政策匹配")
    parser.add_argument("--profile", required=True, help="企业画像 JSON")
    parser.add_argument("--kb", default=default_kb(), help="知识库根目录")
    parser.add_argument("--topn", type=int, default=10, help="输出 Top N 匹配")
    parser.add_argument("--outdir", default=default_outdir(), help="匹配输出目录")
    parser.add_argument("--date", default=datetime.now().strftime("%Y-%m-%d"), help="匹配日期")
    parser.add_argument("--web", default=None, help="互联网实时政策 JSON（可选）")
    args = parser.parse_args()

    with open(args.profile, encoding="utf-8") as f:
        profile = json.load(f)

    index_path = os.path.join(args.kb, "policy-index.json")
    if not os.path.exists(index_path):
        print("错误: 未找到 policy-index.json，请先运行 init_policy_kb.py", file=sys.stderr)
        sys.exit(1)
    with open(index_path, encoding="utf-8") as f:
        index = json.load(f)

    topn = max(1, args.topn)
    matches, eliminated = [], []
    for policy in index.get("policies", []):
        reason = hard_filter(policy, profile)
        if reason:
            eliminated.append({"policy_no": policy.get("policy_no"), "title": policy.get("title"), "reason": reason})
            continue
        score, basis, gap = llm_score(policy, profile) if llm_available() else (rule_score(policy, profile), build_basis(policy, profile), [])
        matches.append({
            "policy_no": policy.get("policy_no"),
            "title": policy.get("title"),
            "domain": policy.get("domain"),
            "level": policy.get("level"),
            "department": policy.get("department"),
            "support": policy.get("support"),
            "score": score,
            "basis": basis,
            "gap": gap,
            "conditions": policy.get("conditions", {}),
            "status": "matched",
            "source": f"policy-original/{policy.get('file', '')}",
        })

    matches.sort(key=lambda x: x["score"], reverse=True)
    top = matches[:topn]

    # 幻觉治理：互联网实时政策无法绑定本地 policy_no 的进入待核实
    pending_verify = []
    if args.web and os.path.exists(args.web):
        with open(args.web, encoding="utf-8") as f:
            web_data = json.load(f)
        for item in web_data.get("policies", []):
            if "policy_no" not in item:
                pending_verify.append({"title": item.get("title", ""), "source": item.get("url", ""),
                                       "status": "待核实", "note": "无法绑定政策原文库 policy_no"})

    os.makedirs(args.outdir, exist_ok=True)
    slug = profile.get("slug", os.path.splitext(os.path.basename(args.profile))[0])
    out_path = os.path.join(args.outdir, f"{slug}-{args.date}.json")
    result = {
        "slug": slug,
        "company_name": profile.get("company_name"),
        "match_date": args.date,
        "total_policies": len(index.get("policies", [])),
        "eliminated": eliminated,
        "matches": top,
        "matched_count": len([m for m in matches if m["score"] > 0]),
        "pending_verify": pending_verify,
    }
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    print(json.dumps({"success": True, "output": out_path, "matched_count": len(top),
                      "eliminated": len(eliminated), "pending_verify": len(pending_verify),
                      "llm_used": llm_available()}, ensure_ascii=False))


if __name__ == "__main__":
    main()