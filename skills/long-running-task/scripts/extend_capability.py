#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
extend_capability.py —— 长程任务 SOP Step 5：能力扩展（D 层脚本，Ch8 / tasks.md #369）

输入：--plan_file <plan.json>  [--outdir output/extended]
      [--installed-skills "a,b,c"]  或  [--installed-skills-file skills.json]
      [--task_id <uuid>]  [--execute]
输出：<outdir>/skill_gaps.json        能力缺口清单（**COMPOSITION condition 依赖它非空**）
      <outdir>/extension_plan.json   每个缺口 → 由谁补齐、怎么补、验收标准
      <outdir>/commands.txt          --execute 时可交给 cli_execute 执行的命令清单
      {"ok":true,"output":...,"gap_count":N}

── 为什么"补能力"这件事必须落在长程任务闭环里 ────────────────────────────
长程任务的天敌是**中途发现缺技能就停下来问人**。spec §5.3 要求 AI 在遇到能力缺口时
自主编排"创建技能 / 写码"子任务补齐，而不是挂死等资源。本脚本就是把
"plan 声称需要的技能" 与 "实际已安装的技能" 做差集，产出可执行的补齐方案。

── 三项自律约束（比"能不能补齐"更重要）──────────────────────────────────
1. **不臆造缺口**：plan 没声明 required_skills/skill_sequence 时，
   gap 列表为空，本步骤在 COMPOSITION 里被 condition 跳过——宁可不补，也不乱补。
2. **能复用就不新建**：缺口命中内置工具白名单（python_execute / cli_execute /
   db_query 等）时标 `builtin_available=true`，方案写"直接用"，不生成新技能。
3. **生成代码必须过质量闸门**（tasks.md #222）：凡是落到 cangjie-coder 的缺口，
   方案里强制追加 `code-gen-verifier` 验证子任务，验证不通过再回 cangjie-coder
   修复——没有验证环节的代码生成子任务一律不允许进 plan。

无第三方依赖：仅标准库。
"""
import argparse
import json
import os
import sys
from datetime import datetime, timezone, timedelta

# 内置工具白名单：命中即视为"已有能力"，不需要为它新建技能。
# 依据 design.md 的工具清单；写成常量而非配置，是因为它变化频率极低，
# 把它开放出去只会让"该不该新建技能"的判定变得不可预测。
BUILTIN_TOOLS = {
    "python_execute", "cli_execute", "db_query", "web_search", "web_fetch",
    "file_read", "file_write", "file_edit", "glob", "grep", "bash",
}

# 命中这些词 → 判定为"要写代码"，走 cangjie-coder 而非 skill-creator
CODE_SIGNALS = ("cangjie", "cj_", "_cj", "仓颉")

VERIFIER_TASK = "code-gen-verifier"

# 质量闸门的**可执行**入口。
# 此前写的是 skills/code-gen-verifier/scripts/run.py —— 该文件并不存在，
# 闸门只被"声明"、永远不会被真正执行。
# 路径相对**本技能根**（skills/long-running-task）：LrtCompositionRunner 执行
# script 步时 workingDirectory 就是 _skillDir，commands.txt 也按同一 cwd 消费。
# 注意 plugin.yaml 已注明「进程 cwd 不保证是技能根」，生产部署请显式设 LRT_SKILL_ROOT。
VERIFIER_ENTRY = "../%s/scripts/verify.py" % VERIFIER_TASK

# cangjie-coder / skill-creator 是 LLM 驱动的 agent 技能：**没有 CLI 入口**
# （实测 skills/<name>/scripts/run.py 在这两个技能下均不存在）。
# 此前为它们生成的 `python skills/<name>/scripts/run.py ...` 是必然失败的假命令。
AGENT_DRIVEN_HANDLERS = {"cangjie-coder", "skill-creator"}


def _now() -> str:
    return datetime.now(timezone(timedelta(hours=8))).isoformat(timespec="seconds")


def _load_json(path: str):
    if not path or not os.path.exists(path):
        return None
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        sys.stderr.write("extend_capability: 读取 %s 失败（按空处理）: %s\n" % (path, e))
        return None


def load_installed(skills_arg: str, file_arg: str) -> set:
    """已安装技能清单：命令行 > 文件 > 环境变量 LRT_INSTALLED_SKILLS > 空集。"""
    raw = ""
    if skills_arg:
        raw = skills_arg
    elif file_arg:
        obj = _load_json(file_arg)
        if isinstance(obj, list):
            return {str(x).strip() for x in obj if str(x).strip()}
        if isinstance(obj, dict):
            names = obj.get("skills") or obj.get("names") or []
            return {str(x.get("name", "")).strip() for x in names if isinstance(x, dict)}
        return set()
    elif os.environ.get("LRT_INSTALLED_SKILLS"):
        raw = os.environ["LRT_INSTALLED_SKILLS"]
    return {x.strip() for x in raw.split(",") if x.strip()}


def extract_required(plan: dict) -> list:
    """
    从 plan 里抽出"需要的技能/能力"。

    兼容多种写法：plan.skill_sequence（树节点上带的）、plan.required_skills、
    plan.steps[].skill。全部统一成 {name, task, language} 三元组，
    缺失字段用空串——下游只判 name，不判完整性。
    """
    if not isinstance(plan, dict):
        return []
    out = []

    def push(name, task="", language=""):
        if isinstance(name, dict):
            language = name.get("language", "") or language
            task = name.get("name") or name.get("description") or task
            name = name.get("skill") or name.get("name") or ""
        name = str(name or "").strip()
        if name:
            out.append({"name": name, "task": str(task or ""), "language": str(language or "")})

    for v in plan.get("skill_sequence") or []:
        push(v)
    for v in plan.get("required_skills") or []:
        push(v)
    for st in plan.get("steps") or plan.get("sub_goals") or []:
        if isinstance(st, dict):
            if st.get("skill"):
                push(st["skill"], st.get("name") or st.get("description", ""), st.get("language", ""))
            for v in st.get("skills") or []:
                push(v, st.get("name") or "", st.get("language", ""))
    # 去重保序
    seen, uniq = set(), []
    for r in out:
        if r["name"] not in seen:
            seen.add(r["name"])
            uniq.append(r)
    return uniq


def classify(req: dict) -> dict:
    """给单个缺口定补齐方案。"""
    name = req["name"]
    if name in BUILTIN_TOOLS:
        return {
            "handler": "builtin",
            "builtin_available": True,
            "action": "直接使用内置工具 %s，无需新建技能" % name,
            "verifier": None,
        }
    lower = (name + " " + req.get("language", "")).lower()
    if any(s in lower for s in CODE_SIGNALS) or req.get("language", "").lower() == "cangjie":
        return {
            "handler": "cangjie-coder",
            "builtin_available": False,
            "action": "编排 cangjie-coder 编写仓颉代码子任务补齐能力 %s" % name,
            # 质量闸门：生成代码必须经验证器，不允许"生成即交付"
            "verifier": VERIFIER_TASK,
        }
    return {
        "handler": "skill-creator",
        "builtin_available": False,
        "action": "编排 skill-creator 创建技能 %s" % name,
        "verifier": VERIFIER_TASK,
    }


def generator_cmd(gap: dict) -> str:
    """补齐命令。

    agent 驱动型技能（cangjie-coder / skill-creator）没有 CLI 入口，这里**不编造**
    python 命令——编造的命令一旦被执行必然失败，还会让"已编排补齐"看起来像是成功了。
    改为输出显式标注，由宿主 LLM 调度，同时把事实留在 commands.txt 里。
    """
    handler = gap.get("handler", "")
    name = gap.get("name", "")
    if handler in AGENT_DRIVEN_HANDLERS:
        return ("# [agent-skill] 由宿主 LLM 调度技能 %s 补齐「%s」"
                "（无 CLI 入口，不出可执行命令）" % (handler, name))
    if handler == "builtin":
        return "# [builtin] 「%s」已由内置工具覆盖，无需补齐命令" % name
    return "# [unknown] 「%s」的 handler=%s 无已知执行方式，需人工介入" % (name, handler)


def verifier_cmd(gap: dict) -> str:
    """质量闸门命令。

    验证发生在生成**之后**，编排期拿不到产物路径，故 --files 用占位符，
    由执行器在生成步骤产出文件后替换（与 COMPOSITION 的 ${step.output} 同风格）。
    """
    name = gap.get("name", "")
    return (
        "python %s --files \"${%s.generated_files}\" "
        "--project-path \"${project_path}\" --verify-level compile"
        % (VERIFIER_ENTRY, name)
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="长程任务能力缺口检测与补齐方案生成")
    parser.add_argument("--plan_file", default="", help="plan-tasks 产出的 plan.json")
    parser.add_argument("--outdir", default="output/extended", help="产出目录")
    parser.add_argument("--installed-skills", default="", help="已安装技能，逗号分隔")
    parser.add_argument("--installed-skills-file", default="", help="已安装技能 JSON 文件")
    parser.add_argument("--task_id", default="", help="透传 task_id")
    parser.add_argument("--execute", action="store_true",
                        help="已废弃（保留兼容）：commands.txt 现只要有缺口就产出，不再受此开关控制")
    args = parser.parse_args()

    os.makedirs(args.outdir, exist_ok=True)

    plan = _load_json(args.plan_file) or {}
    installed = load_installed(args.installed_skills, args.installed_skills_file)
    required = extract_required(plan)

    gaps, covered = [], []
    for req in required:
        if req["name"] in installed or req["name"] in BUILTIN_TOOLS:
            covered.append({"name": req["name"], "status": "installed_or_builtin"})
            continue
        item = dict(req)
        item.update(classify(req))
        item["acceptance_criteria"] = [
            "产物通过 %s 验证" % item["verifier"] if item["verifier"] else "能力可直接调用",
            "补齐后以最小用例实跑一次，产出非空且不报错",
        ]
        gaps.append(item)

    gaps_path = os.path.join(args.outdir, "skill_gaps.json")
    plan_path = os.path.join(args.outdir, "extension_plan.json")
    generated_at = _now()

    gap_doc = {
        "task_id": args.task_id,
        "generated_at": generated_at,
        "gap_count": len(gaps),
        "installed_count": len(installed),
        "gaps": gaps,
    }
    plan_doc = {
        "task_id": args.task_id,
        "generated_at": generated_at,
        "covered": covered,
        # 质量闸门闭环：生成器 → 验证器 → 失败回修复器 → 再验证
        "quality_gate": {
            "generator_to_verifier": "cangjie-coder / skill-creator → %s" % VERIFIER_TASK,
            "on_verify_failed": "回 cangjie-coder 修复后重试，最多 2 轮；仍失败则上报人工",
            "max_retry": 2,
        },
        "steps": gaps,
    }

    with open(gaps_path, "w", encoding="utf-8") as f:
        json.dump(gap_doc, f, ensure_ascii=False, indent=2)
    with open(plan_path, "w", encoding="utf-8") as f:
        json.dump(plan_doc, f, ensure_ascii=False, indent=2)

    # commands.txt 在缺口存在时**总是**产出。
    # 此前挂在 --execute 上，而 COMPOSITION 的 input 并未传该开关
    # （且 runner 以 `--key value` 传参，store_true 型开关传值还会报
    # "unrecognized arguments"），结果 commands.txt 从未生成——
    # 与 acceptance_criteria「gap_count=0 时不生成内容」的隐含前提（非 0 时应有内容）不符。
    cmds = []
    if gaps:
        cmds_path = os.path.join(args.outdir, "commands.txt")
        for g in gaps:
            cmds.append("# %s → %s%s" % (g["name"], g["handler"],
                                          " → %s" % g["verifier"] if g["verifier"] else ""))
            cmds.append(generator_cmd(g))
            if g["verifier"]:
                cmds.append(verifier_cmd(g))
        with open(cmds_path, "w", encoding="utf-8") as f:
            f.write("\n".join(cmds) + "\n" if cmds else "")

    print(json.dumps({
        "ok": True,
        "output": gaps_path,
        "extension_plan": plan_path,
        "gap_count": len(gaps),
        "covered_count": len(covered),
        "commands": cmds,
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
