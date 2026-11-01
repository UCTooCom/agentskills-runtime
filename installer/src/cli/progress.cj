package uc_installer.cli

// ============================================================================
// NDJSON 流式进度输出（任务 T053；REQ-RNI-106 / AC-262~266）。
//
// 与 `--json` 的关系：`--json` 是**结束时一行**的机器可读报告（§4.11.1 骨架）；
// `--progress=ndjson` 是**逐事件一行**的流式形态，供宿主进程实时渲染进度条。
// 两者互斥（AC-265），同时指定即参数冲突、拒绝执行。
//
// 契约（逐条对应 AC）：
//   - stdout：每行一个完整 JSON 事件对象，可独立解析，**禁止跨行**（AC-262/263）；
//   - 末行必须含最终退出码与终态摘要（AC-264），缺失即判"未正常结束"；
//   - stderr：诊断/告警/错误详情**只走 stderr**，绝不混入 stdout 事件序列（AC-262）；
//   - 事件按发生顺序输出（start → steps → items → final）（AC-266）。
//
// ⚠️ 已知限制（如实记录，不冒充已实现）：
// 本版**步骤级事件由报告回放在命令结束后按序吐出**，`start` 事件是实时吐出的。
// 要做到"每一步刚发生就吐出"，需要 `core/orchestrator.cj` 的 `resume()` 暴露
// 逐步骤回调（当前签名 `resume(ctx, force)` 没有该形参）。
// 仓颉函数类型的默认实参写法在本工程尚无先例，为避免引入编译风险，
// 本次未改 orchestrator —— 该限制留给下一轮随回调一起补，不在此处假装已完成。
// ============================================================================

import std.time.DateTime
import stdx.encoding.json.{JsonObject, JsonString, JsonInt, JsonBool}

/// `--progress` 的唯一合法取值。
public let PROGRESS_NDJSON: String = "ndjson"

/// 事件类型。
public let EV_START: String = "start"
public let EV_STEP: String = "step"
public let EV_ITEM: String = "item"
public let EV_FINAL: String = "final"

/// 是否请求了 NDJSON 进度流。
public func progressRequested(parsed: CliArgs): Bool {
    return parsed.progress == PROGRESS_NDJSON
}

/// 参数冲突：`--json` 与 `--progress=ndjson` 同时指定（AC-265）。
public func progressConflict(parsed: CliArgs): Bool {
    return parsed.json && progressRequested(parsed)
}

/// 事件行：一个完整 JSON 对象，**单行**（NDJSON 铁律）。
private func eventLine(kind: String, id: String, status: String, message: String): String {
    let o = JsonObject()
    o.put("kind", JsonString(kind))
    o.put("id", JsonString(id))
    o.put("status", JsonString(status))
    o.put("message", JsonString(message))
    o.put("ts", JsonString(nowText()))
    return o.toJsonString()
}

/// 命令开始事件（**实时**吐出，不等命令结束）。
///
/// ⚠️ 必须带 `flush: true`：installer 的 stdout 在管道（非 TTY）下是**块缓冲**的，
/// 仅 `println` 不会立即冲刷。若进程在后续步骤里卡死再被宿主 SIGTERM 杀掉，
/// 缓冲里的事件会随进程一起丢失——宿主只得 `events=0` / `exitCode=-1`，
/// 用户只看到一个「安装失败（退出码 -1）」却无任何进度（正是本次卡死复现的根因之一）。
/// 每行事件都 flush，宿主才能拿到实时的 start / final（及其真实退出码）。
public func emitStart(command: String): Unit {
    print(eventLine(EV_START, command, STATUS_PASS, "命令开始") + "\n", flush: true)
}

/// 末行：最终退出码 + 终态摘要（AC-264）。消费方缺此行即判"未正常结束"。
public func emitFinal(report: Report): Unit {
    let o = JsonObject()
    o.put("kind", JsonString(EV_FINAL))
    o.put("id", JsonString(report.command))
    o.put("status", JsonString(if (report.ok) { STATUS_PASS } else { STATUS_FAIL }))
    o.put("exitCode", JsonInt(report.exitCode))
    o.put("ok", JsonBool(report.ok))
    o.put("steps", JsonInt(report.steps.size))
    o.put("items", JsonInt(report.items.size))
    o.put("ts", JsonString(nowText()))
    print(o.toJsonString() + "\n", flush: true)
}

/// 把报告的 steps / items 按发生顺序回放为事件行（step 先于 item）。
public func emitReportEvents(report: Report): Unit {
    for (st in report.steps) {
        print(eventLine(EV_STEP, st.id, st.status, st.actual) + "\n", flush: true)
    }
    for (it in report.items) {
        print(eventLine(EV_ITEM, it.id, it.status, it.actual) + "\n", flush: true)
    }
}

/// 诊断只走 stderr（AC-262）：不得混入 stdout 的事件序列。
public func emitDiagnosticsStderr(report: Report): Unit {
    for (d in report.diagnostics) {
        eprintln("diagnostic: ${d}")
    }
    for (r in report.remediation) {
        eprintln("remediation: ${r}")
    }
}

private func nowText(): String {
    return DateTime.now().format("yyyy-MM-dd HH:mm:ss")
}
