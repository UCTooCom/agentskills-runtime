#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
evolve.py —— 长程任务 LrtSelfEvolutionLoop 闭环（Ch8 / Ch7）

输入：
  --agent_id <uuid>  --round <int>
  --context <文本或文件路径>   （最近一轮的日志/指标/失败现象，供根因分析）
  [--outdir output/extended]  [--skill <skill名>]
输出：<outdir>/evolution_<round>.json
  { agent_id, round, root_cause, optimization_plan, anti_regression,
    skill_md_updates: [{skill, section, before, after}], generated_at, model }

AI 行为：基于 context 定位根因（非表面现象）、产出复用现有基础设施的增量优化、
显式「防回退」约束（错误行为示例 + 正确行为示例）。失败降级为骨架，保证闭环不中断。
"""
import argparse
import json
import os
import sys
import urllib.request
import urllib.error
from datetime import datetime, timezone, timedelta

SYSTEM_PROMPT = """你是「自主 Agent 自进化」引擎。给定某次长程任务执行失败的现象与上下文，
请输出 JSON：
- root_cause: 根因分析（聚焦机制/系统性原因，不要停在表面现象）
- optimization_plan: 增量优化方案（必须复用现有基础设施，避免大改写）
- anti_regression: 防回退约束文本（明确写出「错误行为示例」与「正确行为示例」）
- skill_md_updates: 数组，每项 {skill, section, before, after}（对 SKILL.md 的具体修订建议；无则空数组）
只输出 JSON，不要解释。"""


def _model_cfg() -> dict:
    return {
        "base_url": os.environ.get("LRT_MODEL_BASE_URL") or os.environ.get("OPENAI_BASE_URL")
                   or "https://api.deepseek.com/v1",
        "api_key": os.environ.get("LRT_MODEL_API_KEY") or os.environ.get("OPENAI_API_KEY") or "",
        "model": os.environ.get("LRT_MODEL_NAME") or os.environ.get("MODEL_NAME") or "deepseek-chat",
    }


def _chat(user_text: str) -> str:
    cfg = _model_cfg()
    if not cfg["api_key"]:
        raise RuntimeError("缺少模型 API Key")
    payload = {"model": cfg["model"],
               "messages": [{"role": "system", "content": SYSTEM_PROMPT},
                            {"role": "user", "content": user_text}],
               "temperature": 0.3, "response_format": {"type": "json_object"}}
    req = urllib.request.Request(cfg["base_url"].rstrip("/") + "/chat/completions",
                                 data=json.dumps(payload).encode("utf-8"),
                                 headers={"Content-Type": "application/json",
                                          "Authorization": "Bearer " + cfg["api_key"]}, method="POST")
    with urllib.request.urlopen(req, timeout=120) as resp:
        return json.loads(resp.read().decode("utf-8"))["choices"][0]["message"]["content"]


def _read_context(context: str) -> str:
    if context and os.path.isfile(context):
        try:
            with open(context, "r", encoding="utf-8", errors="replace") as f:
                return f.read()[:6000]
        except Exception:
            pass
    return (context or "")[:6000]


def evolve(agent_id: str, round: int, context: str, skill: str) -> dict:
    generated_at = datetime.now(timezone(timedelta(hours=8))).isoformat(timespec="seconds")
    base = {
        "agent_id": agent_id, "round": round,
        "root_cause": "", "optimization_plan": "", "anti_regression": "",
        "skill_md_updates": [], "generated_at": generated_at, "model": "",
    }
    ctx = _read_context(context)
    try:
        user = "agent_id=%s, round=%d\n" % (agent_id, round)
        if skill:
            user += "skill=%s\n" % skill
        user += "上下文/失败现象：\n%s" % ctx
        obj = json.loads(_chat(user))
        for k in ("root_cause", "optimization_plan", "anti_regression"):
            if isinstance(obj.get(k), str):
                base[k] = obj[k]
        if isinstance(obj.get("skill_md_updates"), list):
            base["skill_md_updates"] = obj["skill_md_updates"]
        base["model"] = _model_cfg()["model"]
    except Exception as e:
        sys.stderr.write("evolve LLM 失败，降级骨架: %s\n" % e)
        base["root_cause"] = "LLM 不可用，无法自动定位根因（请看 context 人工分析）"
        base["optimization_plan"] = "待人工基于 context 制定增量优化"
        base["anti_regression"] = "禁止复现本轮观察到的失败行为"
    return base


def main() -> int:
    parser = argparse.ArgumentParser(description="长程任务自进化闭环（LLM）")
    parser.add_argument("--agent_id", required=True)
    parser.add_argument("--round", required=True)
    parser.add_argument("--context", default="")
    parser.add_argument("--skill", default="")
    parser.add_argument("--outdir", default="output/extended")
    args = parser.parse_args()

    try:
        round_n = int(args.round)
    except Exception:
        print("ERROR: round 必须为整数", file=sys.stderr)
        return 2

    os.makedirs(args.outdir, exist_ok=True)
    result = evolve(args.agent_id, round_n, args.context, args.skill)
    out_path = os.path.join(args.outdir, "evolution_%d.json" % round_n)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    print(json.dumps({"ok": True, "output": out_path, "evolution": result}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
