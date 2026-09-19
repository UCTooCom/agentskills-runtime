#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
notify_progress.py —— 长程任务 SOP Step 4：进度通知（D 层脚本，Ch8 / tasks.md #367）

输入：--task_id <uuid>  [--outdir output/executed]  [--plan_file <plan.json>]
      [--round N]  [--endpoint <宿主通知端点>]
输出：<outdir>/progress.json              汇总进度（供后续步骤与人工查阅）
      <outdir>/progress_events.jsonl      每行一条事件，追加写（幂等：同 round 覆盖）
      {"ok":true,"output":...,"events":[...],"pushed":N}

── 为什么 D 层脚本不能直接推 WebSocket ────────────────────────────────────
本项目里真正的推送通道在**宿主进程**手里：`LrtEventEmitter`（插件进程）经
`ctx.invoke("host.event", ...)` → `LrtEventRelay` → `LrtEventBridge` → SSE/WebSocket。
D 层是独立 Python 子进程，**既拿不到 ctx，也不该直连数据库**（design 附录 A
明确要求：D 层经 HTTP API 调用宿主 MCP 开放服务）。所以本脚本的定位是：
  1. 把回合产物**换算**成宿主事件协议要求的字段（completedSteps/totalSteps/
     currentStep/estimatedRemaining/intermediateResult）——这是它的本职工作；
  2. 落 `progress_events.jsonl`，由宿主的事件中继读取并推送；
  3. 仅在显式配置了 `--endpoint` / `LRT_NOTIFY_ENDPOINT` 时才自己 POST，
     且**推送失败一律 warn 不中断**（遇挫不停，spec §5.4）。

── estimatedRemaining 的取值纪律（spec §9.1）──────────────────────────────
没有历史基线时写 **null**，不写 0。0 会被前端解读成"马上完成"，是误导。

无第三方依赖：仅用标准库 urllib。
"""
import argparse
import json
import os
import sys
import urllib.request
import urllib.error
from datetime import datetime, timezone, timedelta

# 与宿主 LrtEventBridge 约定的事件类型（详见 lrt_event_bridge.cj / lrt_event_relay.cj）
EVENT_PROGRESS = "progress_update"
EVENT_STEP_FAILED = "step_failed"
EVENT_STEP_COMPLETE = "step_complete"

DEFAULT_ENDPOINT_ENV = "LRT_NOTIFY_ENDPOINT"


def _now() -> str:
    return datetime.now(timezone(timedelta(hours=8))).isoformat(timespec="seconds")


def _load_json(path: str) -> dict:
    """读 JSON 文件；不存在/损坏一律返回空 dict —— 缺少输入不能让整个步骤崩掉。"""
    if not path or not os.path.exists(path):
        return {}
    try:
        with open(path, "r", encoding="utf-8") as f:
            obj = json.load(f)
        return obj if isinstance(obj, dict) else {}
    except Exception as e:
        sys.stderr.write("notify_progress: 读取 %s 失败（按空处理）: %s\n" % (path, e))
        return {}


def _load_jsonl(path: str) -> list:
    if not os.path.exists(path):
        return []
    rows = []
    try:
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    rows.append(json.loads(line))
                except Exception:
                    # 单行脏数据跳过，不拖垮整份日志
                    continue
    except Exception as e:
        sys.stderr.write("notify_progress: 读取 %s 失败: %s\n" % (path, e))
    return rows


def collect_round_state(outdir: str, plan_file: str, round_no: int) -> dict:
    """
    汇总当前进度状态。

    数据来源优先级：
      1. <outdir>/round_state.json —— 由 execute-rounds 步骤写入的权威态
      2. plan.json 里的 steps / sub_goals —— 只能算出分母，算不出完成数
      3. 都没有 → completedSteps=0，totalSteps=0（不发假进度）
    """
    plan = _load_json(plan_file)
    state = _load_json(os.path.join(outdir, "round_state.json"))

    total = state.get("total_steps")
    completed = state.get("completed_steps")
    if total is None:
        total = len(plan.get("steps") or plan.get("sub_goals") or [])
    if completed is None:
        completed = 0

    failed = state.get("failed_steps", 0)
    current = state.get("current_step") or (
        (plan.get("steps") or plan.get("sub_goals") or [None])[min(completed, max(total - 1, 0))]
        if total else ""
    )
    if isinstance(current, dict):
        current = current.get("name") or current.get("description") or ""

    elapsed = state.get("elapsed_ms")
    return {
        "total_steps": int(total or 0),
        "completed_steps": int(completed or 0),
        "failed_steps": int(failed or 0),
        "current_step": str(current or ""),
        "round": int(round_no or state.get("round") or 0),
        # 已耗时基线：有了它才能对外推剩余时间，没有就保持 None（事件里输出显式 null）
        "elapsed_ms": int(elapsed) if isinstance(elapsed, (int, float)) else None,
        "source": "round_state.json" if state else ("plan.json" if plan else "none"),
    }


def build_events(task_id: str, agent_id: str, session_id: str, trace_id: str, st: dict) -> list:
    """
    生成宿主事件协议要求的事件列表。

    estimated_remaining：**只有在完成数 > 0 且有已耗时基线**时才按线性外推估算；
    否则写 None（宿主会序列化成显式 null），绝不用 0 假装"马上好"。
    """
    total = st["total_steps"]
    completed = st["completed_steps"]
    remaining_ms = None
    elapsed_ms = st.get("elapsed_ms")
    if isinstance(elapsed_ms, (int, float)) and completed > 0 and total > completed:
        remaining_ms = int(elapsed_ms / completed * (total - completed))

    events = []
    base = {
        "type": EVENT_PROGRESS,
        "task_id": task_id,
        "agent_id": agent_id,
        "session_id": session_id,
        "trace_id": trace_id,
        "round": st["round"],
        "timestamp": _now(),
    }
    evt = dict(base)
    evt["data"] = {
        "completedSteps": completed,
        "totalSteps": total,
        "currentStep": st["current_step"],
        "estimatedRemaining": remaining_ms,
        "intermediateResult": "第 %d 回合：完成 %d/%d 步" % (st["round"], completed, total),
    }
    events.append(evt)

    if st["failed_steps"] > 0:
        failed_evt = dict(base)
        failed_evt["type"] = EVENT_STEP_FAILED
        failed_evt["data"] = {
            "step": st["current_step"],
            "errorMessage": "本回合有 %d 个步骤失败，已进入降级重试" % st["failed_steps"],
            "retryable": True,
            "hasNextStep": True,
            "round": st["round"],
        }
        events.append(failed_evt)
    return events


def push(endpoint: str, events: list, timeout: int = 10) -> int:
    """
    逐条 POST 到宿主通知端点。

    失败只告警不抛：进度通知是**旁路**，它失败不应该把一个本来就跑得好好的
    长程任务拖成败（这是 §5.4「遇挫不停」最容易被忽略的一处）。
    """
    if not endpoint or not events:
        return 0
    pushed = 0
    for evt in events:
        try:
            req = urllib.request.Request(
                endpoint.rstrip("/") + "/events",
                data=json.dumps(evt).encode("utf-8"),
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                if 200 <= resp.status < 300:
                    pushed += 1
                else:
                    sys.stderr.write("notify_progress: 推送返回 %s，跳过\n" % resp.status)
        except Exception as e:
            sys.stderr.write("notify_progress: 推送失败（不阻断）: %s\n" % e)
    return pushed


def write_events(jsonl_path: str, events: list, round_no: int) -> None:
    """
    追加写事件日志，但对**同一 round 做覆盖**，保证脚本可重复执行而不产生重复行。

    为什么必须幂等：execute-rounds 失败重试时会再次触发本步骤，
    若纯追加，同一 round 的进度会被重放一次，前端进度条会跳回去。
    """
    existing = [e for e in _load_jsonl(jsonl_path) if e.get("round") != round_no]
    existing.extend(events)
    with open(jsonl_path, "w", encoding="utf-8") as f:
        for e in existing:
            f.write(json.dumps(e, ensure_ascii=False) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description="长程任务进度通知（生成宿主事件协议的事件）")
    parser.add_argument("--task_id", required=True, help="agent_tasks.id")
    parser.add_argument("--outdir", default="output/executed", help="回合产物目录")
    parser.add_argument("--plan_file", default="", help="plan-tasks 产出的 plan.json")
    parser.add_argument("--round", type=int, default=0, help="当前回合序号")
    parser.add_argument("--agent_id", default="", help="透传 agent_id")
    parser.add_argument("--session_id", default="", help="透传 session_id")
    parser.add_argument("--trace_id", default="", help="trace 贯穿（spec §5.18 规则 5）")
    parser.add_argument("--endpoint", default=os.environ.get(DEFAULT_ENDPOINT_ENV, ""),
                        help="宿主通知端点；不配则只落盘，由宿主事件中继读取")
    args = parser.parse_args()

    os.makedirs(args.outdir, exist_ok=True)

    st = collect_round_state(args.outdir, args.plan_file, args.round)
    events = build_events(args.task_id, args.agent_id, args.session_id, args.trace_id, st)

    progress_path = os.path.join(args.outdir, "progress.json")
    summary = dict(st)
    summary["task_id"] = args.task_id
    summary["updated_at"] = _now()
    summary["event_count"] = len(events)
    with open(progress_path, "w", encoding="utf-8") as f:
        json.dump(summary, f, ensure_ascii=False, indent=2)

    write_events(os.path.join(args.outdir, "progress_events.jsonl"), events, st["round"])
    pushed = push(args.endpoint, events)

    print(json.dumps({
        "ok": True,
        "output": progress_path,
        "events": events,
        "pushed": pushed,
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
