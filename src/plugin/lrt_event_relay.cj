/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin

import jsonvalue.JsonValue
import std.collection.ArrayList
import magic.log.LogUtils
import magic.app.services.bridge.LrtEventBridge
import stdx.encoding.json.{JsonArray, JsonObject, JsonString, JsonFloat, JsonBool, JsonNull, JsonValue as StdJsonValue}

/**
 * LrtEventRelay - `host.event` 的落地实现（spec §9.2）
 *
 * 职责单一：把插件进程经 `ctx.invoke("host.event","emit",args)` 送来的
 * 通用 JSON 事件，翻译成 `LrtEventBridge` 的**类型化 push 方法**调用。
 *
 * 为什么要这一层翻译，而不是让插件自己拼出宿主要的 JSON：
 * 1. `LrtEventBridge.push*` 会补算派生字段（`progressPercent`、显式
 *    `estimatedRemaining: null`），这些约定属于宿主，插件不该复制一份；
 * 2. 事件字段名（`stepName` / `subTaskId` / `goalAchievement`…）**在前端是契约**，
 *    入口收敛在一处，改名时只有这里要动；
 * 3. 插件侧是 Cangjie + 另一份 SDK，少一次"字段名拼错只在运行时暴露"的机会。
 *
 * 设计上的取舍：**未知事件类型不抛异常，只记 warn 并返回 false**。
 * 事件是观测面，插件可能比宿主先升级（新增事件类型）。此时投递失败应该
 * 只丢一条观测记录，而不是让正在跑的长程任务回合失败。
 */
public class LrtEventRelay {
    /**
     * 按 `type` 分派到对应的 push 方法
     *
     * @param eventType `LrtEventType.wireName()` 之一（step_start 等 8 种）
     * @param taskId    长程任务根任务 ID
     * @param sessionId SSE 会话 ID（空则只走 WebSocket）
     * @param agentId   Agent 标识
     * @param traceId   追踪 ID（空则不写 traceId 字段）
     * @param extra     事件专有字段（JsonValue.Map）
     * @return true=已投递；false=类型不识别或参数结构不对
     */
    public static func emit(
        eventType: String,
        taskId: String,
        sessionId: String,
        agentId: String,
        traceId: String,
        extra: JsonValue
    ): Bool {
        let bridge = LrtEventBridge.instance
        try {
            match (eventType) {
                case "step_start" =>
                    bridge.pushStepStart(
                        taskId, sessionId, agentId,
                        str(extra, "stepName"),
                        num(extra, "stepIndex", 0),
                        num(extra, "totalSteps", 0),
                        traceId
                    )
                    true
                case "step_complete" =>
                    bridge.pushStepComplete(
                        taskId, sessionId, agentId,
                        str(extra, "stepName"),
                        num(extra, "stepIndex", 0),
                        num(extra, "totalSteps", 0),
                        num(extra, "durationMs", 0),
                        str(extra, "intermediateResult"),
                        traceId
                    )
                    true
                case "step_failed" =>
                    bridge.pushStepFailed(
                        taskId, sessionId, agentId,
                        str(extra, "stepName"),
                        num(extra, "stepIndex", 0),
                        str(extra, "error"),
                        num(extra, "attempt", 1),
                        bool(extra, "willRetry", false),
                        traceId
                    )
                    true
                case "checkpoint_saved" =>
                    bridge.pushCheckpointSaved(
                        taskId, sessionId, agentId,
                        str(extra, "checkpointId"),
                        num(extra, "chatRound", 0),
                        traceId
                    )
                    true
                case "progress_update" =>
                    // estimatedRemaining 缺省 → None → 事件里输出 null（不是 0）
                    bridge.pushProgressUpdate(
                        taskId, sessionId, agentId,
                        num(extra, "completedSteps", 0),
                        num(extra, "totalSteps", 0),
                        str(extra, "currentStep"),
                        optNum(extra, "estimatedRemaining"),
                        str(extra, "intermediateResult"),
                        traceId
                    )
                    true
                case "subtask_dispatched" =>
                    bridge.pushSubtaskDispatched(
                        taskId, sessionId, agentId,
                        str(extra, "subTaskId"),
                        str(extra, "parentTaskId"),
                        str(extra, "description"),
                        arr(extra, "skillSequence"),
                        traceId
                    )
                    true
                case "subtask_completed" =>
                    bridge.pushSubtaskCompleted(
                        taskId, sessionId, agentId,
                        str(extra, "subTaskId"),
                        num(extra, "status", 0),
                        str(extra, "resultSummary"),
                        traceId
                    )
                    true
                case "goal_achieved" =>
                    bridge.pushGoalAchieved(
                        taskId, sessionId, agentId,
                        fnum(extra, "goalAchievement", 0.0),
                        num(extra, "artifactCount", 0),
                        str(extra, "summary"),
                        traceId
                    )
                    true
                case "review_required" =>
                    // spec 5.6.1 规则 3 / Ch6.3：面向用户的评审请求，驱动前端渲染确认/改进/放弃卡片
                    bridge.pushReviewRequired(
                        taskId, sessionId, agentId,
                        fnum(extra, "goalAchievement", 0.0),
                        num(extra, "artifactCount", 0),
                        str(extra, "summary"),
                        str(extra, "goal"),
                        traceId
                    )
                    true
                case "monitor_alert" =>
                    // spec §11.3 / Ch11.3：监控阈值告警，驱动前端渲染告警卡片。
                    // sessionId 为空时为系统级告警，dispatch 只走 WS 广播。
                    bridge.pushMonitorAlert(
                        taskId, sessionId, agentId,
                        str(extra, "metric"),
                        fnum(extra, "value", 0.0),
                        fnum(extra, "threshold", 0.0),
                        str(extra, "level"),
                        str(extra, "message"),
                        num(extra, "window", 0),
                        traceId
                    )
                    true
                case _ =>
                    false
            }
        } catch (e: Exception) {
            // 事件投递失败绝不上抛：观测面故障不应打断任务执行
            LogUtils.warn("[LrtEventRelay] 事件投递异常（已忽略）type=${eventType}: ${e.message}")
            false
        }
    }

    // ── 字段读取（宽容：缺失/类型不符一律用默认值）────────────────────
    // 插件侧字段拼写错误时表现为"事件字段为空"，而不是整个事件丢失——
    // 对观测面来说前者更好排查。

    private static func field(extra: JsonValue, key: String): ?JsonValue {
        match (extra) {
            case JsonValue.Map(m) => m.get(key)
            case _ => None<JsonValue>
        }
    }

    /// 取字符串字段（JsonValue.String → String）
    private static func str(extra: JsonValue, key: String): String {
        match (LrtEventRelay.field(extra, key)) {
            case Some(JsonValue.String(s)) => s
            case _ => ""
        }
    }

    /// 取数字字段（JsonValue.Number → Int64）
    private static func num(extra: JsonValue, key: String, default: Int64): Int64 {
        match (LrtEventRelay.field(extra, key)) {
            case Some(JsonValue.Number(n)) => Int64(n)
            case _ => default
        }
    }

    /// 取数字字段（Float64）
    private static func fnum(extra: JsonValue, key: String, default: Float64): Float64 {
        match (LrtEventRelay.field(extra, key)) {
            case Some(JsonValue.Number(n)) => n
            case _ => default
        }
    }

    /// 取可选数字字段（缺失 → None，用于 estimatedRemaining 的 null 语义）
    private static func optNum(extra: JsonValue, key: String): ?Int64 {
        match (LrtEventRelay.field(extra, key)) {
            case Some(JsonValue.Number(n)) => Some<Int64>(Int64(n))
            case _ => None<Int64>
        }
    }

    /// 取布尔字段
    private static func bool(extra: JsonValue, key: String, default: Bool): Bool {
        match (LrtEventRelay.field(extra, key)) {
            case Some(JsonValue.Boolean(b)) => b
            case _ => default
        }
    }

    /// 取 JSON 数组字段（skillSequence；缺失时返回空数组而非 null，便于前端直接遍历）
    private static func arr(extra: JsonValue, key: String): JsonArray {
        let out = JsonArray()
        match (LrtEventRelay.field(extra, key)) {
            case Some(JsonValue.Array(a)) =>
                for (elem in a) {
                    out.add(LrtEventRelay.toStdJson(elem))
                }
            case _ => ()
        }
        out
    }

    /// `jsonvalue.JsonValue` → `stdx.encoding.json.JsonValue`
    ///
    /// `pushSubtaskDispatched` 的形参是 stdx 侧的 `JsonArray`（宿主事件层统一用
    /// stdx），而插件发来的是 `jsonvalue` 侧的树。两棵树不同源，只能逐层搬。
    /// 覆盖到 Map/Array 是因为 skillSequence 里的元素实际是对象（skill+params）。
    /// 两库同名 `JsonValue` 用别名区分：jsonvalue 侧用简短名，stdx 侧用 `StdJsonValue`。
    private static func toStdJson(v: JsonValue): StdJsonValue {
        match (v) {
            case JsonValue.Null => JsonNull()
            case JsonValue.Boolean(b) => JsonBool(b)
            case JsonValue.Number(n) => JsonFloat(n)
            case JsonValue.String(s) => JsonString(s)
            case JsonValue.Array(a) =>
                let out = JsonArray()
                for (elem in a) {
                    out.add(LrtEventRelay.toStdJson(elem))
                }
                out
            case JsonValue.Map(m) =>
                let obj = JsonObject()
                for (key in m.keys()) {
                    match (m.get(key)) {
                        case Some(val) => obj.put(key, LrtEventRelay.toStdJson(val))
                        case None => ()
                    }
                }
                obj
        }
    }
}
