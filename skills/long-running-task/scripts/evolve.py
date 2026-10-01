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
    skill_md_updates: [{skill, section, before, after}], generated_at, model,
    frontend_coordination: {detected, changed_files[], build_tasks[], note} }

AI 行为：基于 context 定位根因（非表面现象）、产出复用现有基础设施的增量优化、
显式「防回退」约束（错误行为示例 + 正确行为示例）。失败降级为骨架，保证闭环不中断。

§7.3 前后端协同（tasks.md 819）：
  当本轮优化涉及**前端文件**时，额外编排两条子任务——
  1) 经 cli_execute 执行 `npm run build`；2) 产物经 sync 服务同步。
  本脚本**不直接执行**这两步（D 层脚本不经 cli_execute 调宿主命令，那是编排层职责），
  而是产出结构化任务清单交编排层消费，与 extend_capability.py 产 commands.txt 同一套路。
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


# ── §7.3 前后端协同 ────────────────────────────────────────────────────
# 前端文件的判定口径：扩展名 + 典型目录标记（二者取「或」）。
# 只看扩展名会漏掉 .js/.json 这类通用后缀；只看目录又会把后端 src 误判进来。
FRONTEND_EXTS = (".vue", ".tsx", ".jsx", ".scss", ".less", ".svelte")
FRONTEND_DIR_MARKERS = ("web/src", "frontend/", "web-admin", "/components/", "/composable/")
# 明确排除：这些路径里出现 .ts 也属后端（本插件仓颉工程不在此列，但宿主侧有 TS 工具链）
BACKEND_DIR_MARKERS = ("apps/agentskills-runtime/src", "/store/models/")


def _is_frontend_path(path: str) -> bool:
    """判定一个路径是否属前端改动。"""
    if not path:
        return False
    low = path.replace("\\", "/").lower()
    if any(m in low for m in BACKEND_DIR_MARKERS):
        return False
    if low.endswith(FRONTEND_EXTS):
        return True
    # .ts/.js 只在前端目录标记下才算前端
    if low.endswith((".ts", ".js", ".css", ".html")):
        return any(m in low for m in FRONTEND_DIR_MARKERS)
    return False


def _collect_frontend_files(skill_md_updates: list, context: str) -> list:
    """从 skill_md_updates 与 context 里收集被提及的前端文件路径。"""
    found = []
    seen = set()

    def _add(p):
        p = (p or "").strip()
        if p and _is_frontend_path(p) and p not in seen:
            seen.add(p)
            found.append(p)

    for item in skill_md_updates or []:
        if isinstance(item, dict):
            _add(item.get("skill", ""))
            for key in ("before", "after", "section"):
                v = item.get(key)
                if isinstance(v, str):
                    for tok in _extract_path_tokens(v):
                        _add(tok)

    for tok in _extract_path_tokens(context or ""):
        _add(tok)
    return found


def _extract_path_tokens(text: str) -> list:
    """从自由文本里抽文件路径 token（保守匹配：只认带扩展名的连续串）。"""
    import re
    # 匹配含斜杠且带常见扩展名的片段，避免把整句 prose 当成路径
    pat = re.compile(r"[A-Za-z0-9_\-./]+\.(?:vue|tsx|jsx|ts|js|css|scss|less|html)\b")
    return pat.findall(text or "")


def build_frontend_coordination(skill_md_updates: list, context: str) -> dict:
    """
    §7.3 前后端协同：前端有改动时编排「构建 + 同步」两条子任务。

    设计取舍（重要，勿改坏）：
    - 本脚本**不执行** npm run build。D 层脚本的定位是「产出结构化结果」，
      真正经 cli_execute 跑命令是编排层（LrtExecutor / LrtCompositionRunner）的职责；
      在这里起子进程会让 D 层脚本与宿主机环境强耦合，且失败时无法回写任务状态。
      故只产出任务清单，与 extend_capability.py 产 commands.txt 同一套路。
    - frontend_root 未配置时**只标记 detected，不产出命令**：不知道前端根在哪
      就臆造一条 npm run build，比不做更糟（会在错误目录构建出无意义产物）。
    """
    files = _collect_frontend_files(skill_md_updates, context)
    root = (os.environ.get("LRT_FRONTEND_ROOT") or "").strip()
    detected = len(files) > 0

    tasks = []
    if detected and root:
        tasks.append({
            "type": "cli_execute",
            "command": "npm run build",
            "cwd": root,
            "reason": "前端文件已修改，需重新构建产物（§7.3 前后端协同）",
        })
        tasks.append({
            "type": "sync",
            "target": root,
            "reason": "构建产物经 sync 服务同步到数据库（SyncManager + ChangeDetector）",
        })

    if detected and not root:
        note = ("检测到前端改动，但 LRT_FRONTEND_ROOT 未配置——**不臆造构建命令**。"
                "请设置该环境变量（前端工程根目录）以启用自动构建与同步。")
    elif detected:
        note = "已编排构建 + 同步两条子任务，交编排层经 cli_execute / sync 服务执行。"
    else:
        note = "本轮未检测到前端文件改动，无需构建。"

    return {
        "detected": detected,
        "changed_files": files,
        "frontend_root": root,
        "build_tasks": tasks,
        "note": note,
    }


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
        "frontend_coordination": {"detected": False, "changed_files": [],
                                  "frontend_root": "", "build_tasks": [], "note": ""},
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
        # 保留原降级语义：LLM 不可用时填占位文案，保证闭环不中断
        sys.stderr.write("evolve LLM 失败，降级骨架: %s\n" % e)
        base["root_cause"] = "LLM 不可用，无法自动定位根因（请看 context 人工分析）"
        base["optimization_plan"] = "待人工基于 context 制定增量优化"
        base["anti_regression"] = "禁止复现本轮观察到的失败行为"

    # §7.3 前后端协同：**无论 LLM 成功与否都要算**——LLM 降级时 skill_md_updates 为空、
    # 但 context 里仍可能提到前端文件；只在成功分支里算会漏掉降级场景。
    try:
        base["frontend_coordination"] = build_frontend_coordination(
            base.get("skill_md_updates", []), ctx
        )
    except Exception as fe:
        sys.stderr.write("frontend_coordination 计算失败（已降级为空）: %s\n" % fe)
        base["frontend_coordination"] = {
            "detected": False, "changed_files": [], "frontend_root": "",
            "build_tasks": [], "note": "计算失败，已降级为未检测到前端改动",
        }
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
