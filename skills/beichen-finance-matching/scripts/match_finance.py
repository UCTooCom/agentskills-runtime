#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
金融匹配智能体 - Step 2: 需求匹配优势金融机构（Match Finance）
硬性初筛（额度/担保对标产品要素）+ 优势匹配打分，输出 Top N 匹配矩阵。
打分构成：领域命中(50%) + 服务经验先验(30%) + 周期适配(20%)。

用法:
    python match_finance.py --need output/needs/{case_id}.json [--topn 3] [--kb knowledge]
"""

import argparse
import json
import os
import re
import sys
import urllib.request

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


def parse_amount_wan(s: str):
    """解析额度字符串为万元上限；'无上限/不限/视情况/-'返回 None 表示不限或未知。"""
    if not s:
        return None
    if re.search(r'无上限|不限|视企业情况|视情况|-', s):
        return None
    m = re.search(r'([\d.]+)\s*(万元|万元人民币|万|亿元|元)', s)
    if not m:
        return None
    val = float(m.group(1))
    unit = m.group(2)
    if "亿" in unit:
        return val * 10000
    if "元" == unit:
        return val / 10000
    return val


def parse_need_amount_wan(need: dict):
    m = re.search(r'([\d.]+)\s*(万|亿|元|千)?', need.get("amount", "") or "")
    if not m:
        return None
    val = float(m.group(1))
    unit = m.group(2) or "元"
    if unit == "亿":
        return val * 10000
    if unit == "万":
        return val
    return val / 10000


def need_domains(need: dict) -> list:
    """从企业画像与用途推断需求领域关键词。"""
    doms = []
    inds = (need.get("profile") or {}).get("industry", []) or []
    doms.extend(inds)
    purpose = need.get("purpose", "")
    if purpose == "研发投入":
        doms.append("科技")
    return doms


def hard_filter(partner: dict, need: dict):
    """硬性初筛（额度对标 + 担保对标），返回淘汰原因或 None。"""
    need_amt = parse_need_amount_wan(need)
    guarantee = need.get("guarantee", "")
    if need_amt is not None:
        all_limited = []
        for p in partner.get("products", []):
            cap = parse_amount_wan(p.get("amount", ""))
            if cap is not None:
                all_limited.append(cap)
        if all_limited and need_amt > max(all_limited):
            return "需求金额超过该机构产品最高额度"
    return None


def rule_score(partner: dict, need: dict) -> dict:
    doms = [d for d in need_domains(need) if d]
    strengths = partner.get("strength_domains", [])
    hit = 0
    for s in strengths:
        for d in doms:
            if d and (d in s or s in d):
                hit += 1
                break
    domain_score = (50.0 * hit / len(strengths)) if strengths else 20.0
    exp_score = 30.0 * min(partner.get("service_count", 0), 30) / 30.0
    cycle = partner.get("avg_cycle_days", 0) or 5
    cycle_score = 20.0 * max(0, 1.0 - cycle / 15.0)
    total = round(domain_score + exp_score + cycle_score, 1)
    reasons = []
    if hit:
        reasons.append(f"优势领域命中 {hit} 项（{hit} 项与需求领域相关）")
    reasons.append(f"服务经验 {partner.get('service_count', 0)} 家次")
    reasons.append(f"平均放款周期约 {cycle} 个工作日")
    return {"score": total, "domain_score": round(domain_score, 1), "exp_score": round(exp_score, 1),
            "cycle_score": round(cycle_score, 1), "basis": "；".join(reasons)}


def matched_products(partner: dict, need: dict, limit: int = 5) -> list:
    """从机构产品中筛选与需求匹配的产品（额度/担保/用途），返回顶部产品。"""
    need_amt = parse_need_amount_wan(need)
    purpose = need.get("purpose", "")
    guarantee = need.get("guarantee", "")
    out = []
    for p in partner.get("products", []):
        cap = parse_amount_wan(p.get("amount", ""))
        if need_amt is not None and cap is not None and need_amt > cap:
            continue
        purposes = p.get("purpose", []) or []
        if purpose and purposes and purpose not in purposes and not any(purpose in x or x in purpose for x in purposes):
            continue
        out.append(p)
    return out[:limit]


def main():
    parser = argparse.ArgumentParser(description="融资需求机构匹配")
    parser.add_argument("--need", required=True, help="融资需求档案 JSON")
    parser.add_argument("--kb", default=default_kb(), help="知识库根目录")
    parser.add_argument("--topn", type=int, default=3, help="输出 Top N 机构")
    parser.add_argument("--outdir", default=default_outdir(), help="匹配输出目录")
    args = parser.parse_args()

    with open(args.need, encoding="utf-8") as f:
        need = json.load(f)

    index_path = os.path.join(args.kb, "finance-index.json")
    if not os.path.exists(index_path):
        print("错误: 未找到 finance-index.json，请先运行 init_finance_kb.py", file=sys.stderr)
        sys.exit(1)
    with open(index_path, encoding="utf-8") as f:
        index = json.load(f)

    results, eliminated = [], []
    for partner in index.get("partners", []):
        reason = hard_filter(partner, need)
        if reason:
            eliminated.append({"partner": partner.get("name"), "reason": reason})
            continue
        sc = rule_score(partner, need)
        products = matched_products(partner, need)
        basis = sc["basis"]
        if llm_available():
            try:
                prompt = ("评估该融资需求与该机构的适配性，给一句话判定。\n需求："
                          + json.dumps({"amount": need.get("amount"), "purpose": need.get("purpose"), "term": need.get("term")}, ensure_ascii=False)
                          + "\n机构：" + json.dumps({"name": partner.get("name"), "strengths": partner.get("strength_domains")}, ensure_ascii=False))
                llm_out = call_llm(prompt, "你是园区金融服务匹配助手，输出一句话匹配依据。")
                if llm_out.strip():
                    basis = llm_out.strip()
            except Exception:
                pass
        results.append({
            "partner": partner.get("name"),
            "partner_no": partner.get("partner_no"),
            "type": partner.get("type"),
            "strength_domains": partner.get("strength_domains", []),
            "score": sc["score"],
            "score_breakdown": {"domain": sc["domain_score"], "experience": sc["exp_score"], "cycle": sc["cycle_score"]},
            "basis": basis,
            "products": products,
        })

    results.sort(key=lambda x: x["score"], reverse=True)
    topn = max(1, args.topn)
    case_id = need.get("case_id", os.path.splitext(os.path.basename(args.need))[0])
    os.makedirs(args.outdir, exist_ok=True)
    out = os.path.join(args.outdir, f"{case_id}.json")
    result = {"case_id": case_id, "company_name": need.get("company_name"),
              "need": {"amount": need.get("amount"), "purpose": need.get("purpose"), "term": need.get("term")},
              "matches": results[:topn], "eliminated": eliminated,
              "total_partners": len(index.get("partners", []))}
    with open(out, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    print(json.dumps({"success": True, "output": out, "matched": len(results[:topn]),
                      "eliminated": len(eliminated), "llm_used": llm_available()}, ensure_ascii=False))


if __name__ == "__main__":
    main()