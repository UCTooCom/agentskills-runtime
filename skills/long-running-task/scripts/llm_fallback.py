#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
llm_fallback.py —— 降级链 llm 环节：让模型按验收条件产出兜底内容（Ch4.2 / tasks.md #244）

输入：--task_id / --round / --failure <失败描述> / --criteria <验收条件，多行文本>
      [--outdir output/executed]
输出：<outdir>/llm_fallback_<round>.json + {"ok":bool,"output":...,"content":...,"model":...}

── 它在降级链里的位置，以及为什么它不能"替模.argv完成任务的成果" ──────────────
降级链的顺序是 cli_execute → builtin_tool → llm → template。llm 排在第三，
意味着前面两条（重跑验证、拿上一轮快照）都已经失败——此时让模型产出的是
**最小可用的兜底内容**，用来让下游步骤还能往下走，而不是宣称任务已按原计划完成。
产出文本里必须写明这是 degraded 兜底，不许含糊。

── 失败纪律 ────────────────────────────────────────────────────────────────
模型不可用（缺 Key / 超时 / 返回非 JSON）时 `ok=false`，由上层降级链继续走 template。
本脚本自己不做二次降级——那会让 failure 的可观测性变差（谁也说不清到底用了哪条路）。

LLM 接入：环境变量 LRT_MODEL_BASE_URL / LRT_MODEL_API_KEY / LRT_MODEL_NAME
          （缺省回退 OPENAI_*，再回退 deepseek）。
无第三方依赖：仅用标准库 urllib。
"""
import argparse
import json
import os
import sys
import urllib.request
from datetime import datetime, timezone, timedelta

SYSTEM_PROMPT = """你是长程任务系统的兜底生成器。某个步骤的前两级降级都已失败。
请依据给定的「验收条件」产出最小可用内容：
- content: 兜底正文（可以是未完成的最小骨架，但必须真实可用，且开头写明这是降级兜底）
- caveats: 字符串数组，列出这份内容相对验收条件还缺什么（缺失项必须如实列出）
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


def call_llm(failure: str, criteria: str, task_id: str, round_no: int) -> dict:
    cfg = _model_cfg()
    if not cfg["api_key"]:
        raise RuntimeError("缺少模型 API Key：请设置 LRT_MODEL_API_KEY 或 OPENAI_API_KEY")
    payload = {
        "model": cfg["model"],
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content":
                "任务ID: %s\n回合: %d\n失败情况:\n%s\n\n验收条件:\n%s"
                % (task_id, round_no, failure or "(未给出)", criteria or "(未给出)")},
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
    content = data["choices"][0]["message"]["content"]
    obj = json.loads(content)
    return {
        "content": str(obj.get("content", "")).strip(),
        "caveats": [str(x) for x in obj.get("caveats", []) if x],
        "model": cfg["model"],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="降级链 llm 环节：产出兜底内容")
    parser.add_argument("--task_id", required=True)
    parser.add_argument("--round", type=int, default=0)
    parser.add_argument("--failure", default="", help="失败描述，作为模型输入背景")
    parser.add_argument("--criteria", default="", help="验收条件（多行文本）")
    parser.add_argument("--outdir", default="output/executed")
    args = parser.parse_args()

    os.makedirs(args.outdir, exist_ok=True)
    generated_at = datetime.now(timezone(timedelta(hours=8))).isoformat(timespec="seconds")

    # 失败一律如实返回 ok=false，交由上层继续降级到 template；
    # 不在这里做二次降级——failure 的可观测性会因为层层兜底而丢失。
    try:
        got = call_llm(args.failure, args.criteria, args.task_id, args.round)
        if not got["content"]:
            print(json.dumps({"ok": False, "output": "", "content": "",
                              "errmsg": "LLM 返回空内容"}, ensure_ascii=False))
            return 0
    except Exception as e:
        sys.stderr.write("llm_fallback LLM 失败: %s\n" % e)
        print(json.dumps({"ok": False, "output": "", "content": "",
                          "errmsg": str(e)}, ensure_ascii=False))
        return 0

    doc = {
        "task_id": args.task_id,
        "round": args.round,
        "generated_at": generated_at,
        "degraded": True,
        "content": got["content"],
        "caveats": got["caveats"],
        "model": got["model"],
    }
    out_path = os.path.join(args.outdir, "llm_fallback_%d.json" % args.round)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=2)

    print(json.dumps({
        "ok": True,
        "output": out_path,
        "content": got["content"],
        "caveats": got["caveats"],
        "model": got["model"],
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
