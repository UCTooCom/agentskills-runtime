#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
parse_goal.py —— 长程任务 SOP Step 1：目标解析（D 层脚本，Ch8）

输入：--goal "<用户目标文本>"  [--outdir output/parsed]  [--task_id <uuid>]
输出：<outdir>/goal.json
      { goal, success_criteria[], constraints[], sub_goals[], parsed_at, model }

AI 行为：调 OpenAI 兼容端点抽取「成功标准 / 约束 / 子目标」，非确定性骨架。
LLM 接入：环境变量 LRT_MODEL_BASE_URL / LRT_MODEL_API_KEY / LRT_MODEL_NAME
          （缺省回退 OPENAI_BASE_URL / OPENAI_API_KEY / MODEL_NAME，再回退 deepseek）。
无第三方依赖：仅用标准库 urllib。
"""
import argparse
import json
import os
import sys
import urllib.request
import urllib.error
from datetime import datetime, timezone, timedelta

SYSTEM_PROMPT = """你是一个「长程自主任务」规划助手。用户会给你一个自然语言目标。
请将其结构化为 JSON，字段：
- goal: 复述目标
- success_criteria: 字符串数组，每条是一个可验证的完成标准（具体、可判定）
- constraints: 字符串数组，约束（技术栈/合规/资源/时间等）
- sub_goals: 字符串数组，建议的执行子目标分解（2-6 个，有序）
只输出 JSON，不要解释。"""


def _model_cfg() -> dict:
    return {
        "base_url": os.environ.get("LRT_MODEL_BASE_URL")
                   or os.environ.get("OPENAI_BASE_URL")
                   or "https://api.deepseek.com/v1",
        "api_key": os.environ.get("LRT_MODEL_API_KEY")
                   or os.environ.get("OPENAI_API_KEY")
                   or "",
        "model": os.environ.get("LRT_MODEL_NAME")
                 or os.environ.get("MODEL_NAME")
                 or "deepseek-chat",
    }


def _chat(user_text: str, data_contract: str = "") -> str:
    cfg = _model_cfg()
    if not cfg["api_key"]:
        raise RuntimeError("缺少模型 API Key：请设置 LRT_MODEL_API_KEY 或 OPENAI_API_KEY")
    # §14.2 按步注入：编排器把当前步骤用到的表结构（data_contract）拼好传进来，
    # 在此填入 ReAct system prompt 的「可用数据契约」小节，供模型参考真实表结构落库。
    system = SYSTEM_PROMPT
    if data_contract:
        system = system + "\n\n" + data_contract
    payload = {
        "model": cfg["model"],
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user_text},
        ],
        "temperature": 0.2,
        "response_format": {"type": "json_object"},
    }
    req = urllib.request.Request(
        cfg["base_url"].rstrip("/") + "/chat/completions",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": "Bearer " + cfg["api_key"],
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    return data["choices"][0]["message"]["content"]


def parse_goal(goal: str, data_contract: str = "") -> dict:
    """调用 LLM 抽取结构化目标；失败则降级为确定性骨架（保证脚本永远可产出）。"""
    parsed_at = datetime.now(timezone(timedelta(hours=8))).isoformat(timespec="seconds")
    base = {
        "goal": goal,
        "success_criteria": [],
        "constraints": [],
        "sub_goals": [],
        "parsed_at": parsed_at,
        "model": "",
    }
    try:
        raw = _chat("目标：\n" + goal, data_contract)
        obj = json.loads(raw)
        for k in ("success_criteria", "constraints", "sub_goals"):
            if isinstance(obj.get(k), list):
                base[k] = [str(x) for x in obj[k]]
        if isinstance(obj.get("goal"), str) and obj["goal"].strip():
            base["goal"] = obj["goal"].strip()
        base["model"] = _model_cfg()["model"]
    except Exception as e:  # 降级：不阻断主流程
        sys.stderr.write("parse_goal LLM 失败，使用确定性骨架: %s\n" % e)
        base["constraints"] = ["LLM 解析不可用，已降级为最小骨架"]
    return base


def main() -> int:
    parser = argparse.ArgumentParser(description="长程任务目标解析（AI）")
    parser.add_argument("--goal", required=True, help="用户自然语言目标")
    parser.add_argument("--task_id", default="", help="关联 agent_tasks.id（透传写入产出）")
    parser.add_argument("--outdir", default="output/parsed", help="产出目录")
    parser.add_argument("--data_contract", default="", help="由编排器按步注入的表结构契约（数据契约），填入 system prompt")
    args = parser.parse_args()

    if not args.goal or not args.goal.strip():
        print("ERROR: goal 不能为空", file=sys.stderr)
        return 2

    os.makedirs(args.outdir, exist_ok=True)
    result = parse_goal(args.goal.strip(), args.data_contract)
    if args.task_id:
        result["task_id"] = args.task_id
    out_path = os.path.join(args.outdir, "goal.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    print(json.dumps({"ok": True, "output": out_path, "goal": result}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
