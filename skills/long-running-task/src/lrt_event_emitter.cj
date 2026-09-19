/*
 * LrtEventEmitter（long-running-task / Ch9.2）
 * 长程任务 8 类事件上报（spec §9.2）——插件侧封装
 *
 * 通道：ctx.invoke("host.event", "emit", args)
 *   插件进程拿不到宿主的 SSE 连接表与 WebSocket 广播缓冲，事件出口必须收敛在宿主。
 *   宿主侧 CordisHostServices.createEventHandler → LrtEventRelay → LrtEventBridge
 *   → WebSocketEventBridge + SSEConnectionManager。
 *
 * 失败策略：**上报失败一律吞掉，只记 stderr**。
 *   事件是观测面。SSE 断开、宿主尚未注册 handler、事件类型宿主不认识——这些都不该让
 *   正在跑的长程任务回合失败。这条与宿主侧 LrtEventRelay 的 try/catch 是同一决策的两端。
 *
 * 时效要求（spec §9.2）：进度类事件的上报延迟要求 ≤1s。因此本类只做"构造 + 一次
 *   invoke"，不做重试、不排队；如果这一跳就超时，重试也不会更快。
 *
 * 编码依据：lrt_persist_service.cj 的 ctx 单例模式（PluginContext 由 main.cj 注入一次）。
 */
package skill_long_running_task

import ystyle::cordis_plugin.PluginContext
import jsonvalue.*
import std.collection.{HashMap, ArrayList}

public class LrtEventEmitter {
    private static var ctx: ?PluginContext = None

    /// 初始化插件上下文（与 LrtPersistService.initialize 同源，可共用同一个 ctx）
    public static func initialize(ctx: PluginContext): Unit {
        LrtEventEmitter.ctx = ctx
    }

    // ── 8 类事件 ────────────────────────────────────────────────────
    // 形参顺序与宿主 LrtEventBridge.push* 保持一致，(taskId, sessionId, agentId) 打头，
    // 便于对照；sessionId 为空时宿主只走 WebSocket 广播。

    /// 步骤开始
    public static func stepStart(
        taskId: String, sessionId: String, agentId: String,
        stepName: String, stepIndex: Int64, totalSteps: Int64, traceId: String
    ): Unit {
        let extra = HashMap<String, JsonValue>()
        extra["stepName"] = JsonValue.String(stepName)
        extra["stepIndex"] = JsonValue.Number(Float64(stepIndex))
        extra["totalSteps"] = JsonValue.Number(Float64(totalSteps))
        LrtEventEmitter.emit("step_start", taskId, sessionId, agentId, traceId, extra)
    }

    /// 步骤完成（durationMs 为本步骤耗时，intermediateResult 为产物摘要预览）
    public static func stepComplete(
        taskId: String, sessionId: String, agentId: String,
        stepName: String, stepIndex: Int64, totalSteps: Int64,
        durationMs: Int64, intermediateResult: String, traceId: String
    ): Unit {
        let extra = HashMap<String, JsonValue>()
        extra["stepName"] = JsonValue.String(stepName)
        extra["stepIndex"] = JsonValue.Number(Float64(stepIndex))
        extra["totalSteps"] = JsonValue.Number(Float64(totalSteps))
        extra["durationMs"] = JsonValue.Number(Float64(durationMs))
        extra["intermediateResult"] = JsonValue.String(intermediateResult)
        LrtEventEmitter.emit("step_complete", taskId, sessionId, agentId, traceId, extra)
    }

    /// 步骤失败（attempt 从 1 起；willRetry 表示是否还有后续降级方案）
    public static func stepFailed(
        taskId: String, sessionId: String, agentId: String,
        stepName: String, stepIndex: Int64, errorMessage: String,
        attempt: Int64, willRetry: Bool, traceId: String
    ): Unit {
        let extra = HashMap<String, JsonValue>()
        extra["stepName"] = JsonValue.String(stepName)
        extra["stepIndex"] = JsonValue.Number(Float64(stepIndex))
        extra["error"] = JsonValue.String(errorMessage)
        extra["attempt"] = JsonValue.Number(Float64(attempt))
        extra["willRetry"] = JsonValue.Boolean(willRetry)
        LrtEventEmitter.emit("step_failed", taskId, sessionId, agentId, traceId, extra)
    }

    /// 检查点已保存（回合级）
    public static func checkpointSaved(
        taskId: String, sessionId: String, agentId: String,
        checkpointId: String, chatRound: Int64, traceId: String
    ): Unit {
        let extra = HashMap<String, JsonValue>()
        extra["checkpointId"] = JsonValue.String(checkpointId)
        extra["chatRound"] = JsonValue.Number(Float64(chatRound))
        LrtEventEmitter.emit("checkpoint_saved", taskId, sessionId, agentId, traceId, extra)
    }

    /**
     * 进度更新
     *
     * @param estimatedRemainingMs 无基线时传 **None**，宿主侧会写成显式 `null`；
     *        传 `Some(0)` 会被前端解读为"马上完成"，是误导（spec §9.1 明确要求 null 而非 0）
     */
    public static func progressUpdate(
        taskId: String, sessionId: String, agentId: String,
        completedSteps: Int64, totalSteps: Int64, currentStep: String,
        estimatedRemainingMs: ?Int64, intermediateResult: String, traceId: String
    ): Unit {
        let extra = HashMap<String, JsonValue>()
        extra["completedSteps"] = JsonValue.Number(Float64(completedSteps))
        extra["totalSteps"] = JsonValue.Number(Float64(totalSteps))
        extra["currentStep"] = JsonValue.String(currentStep)
        // None → 不写该键 → 宿主 LrtEventRelay.optNum 得到 None → 事件里输出 null
        match (estimatedRemainingMs) {
            case Some(ms) => extra["estimatedRemaining"] = JsonValue.Number(Float64(ms))
            case None => ()
        }
        extra["intermediateResult"] = JsonValue.String(intermediateResult)
        LrtEventEmitter.emit("progress_update", taskId, sessionId, agentId, traceId, extra)
    }

    /// 子任务已派发（skillSequence 为该子任务计划使用的技能序列）
    public static func subtaskDispatched(
        taskId: String, sessionId: String, agentId: String,
        subTaskId: String, parentTaskId: String, description: String,
        skillSequence: ArrayList<JsonValue>, traceId: String
    ): Unit {
        let extra = HashMap<String, JsonValue>()
        extra["subTaskId"] = JsonValue.String(subTaskId)
        extra["parentTaskId"] = JsonValue.String(parentTaskId)
        extra["description"] = JsonValue.String(description)
        extra["skillSequence"] = JsonValue.Array(skillSequence)
        LrtEventEmitter.emit("subtask_dispatched", taskId, sessionId, agentId, traceId, extra)
    }

    /// 子任务已完成（resultSummary 为子任务 result 字段的预览）
    public static func subtaskCompleted(
        taskId: String, sessionId: String, agentId: String,
        subTaskId: String, status: Int64, resultSummary: String, traceId: String
    ): Unit {
        let extra = HashMap<String, JsonValue>()
        extra["subTaskId"] = JsonValue.String(subTaskId)
        extra["status"] = JsonValue.Number(Float64(status))
        extra["resultSummary"] = JsonValue.String(resultSummary)
        LrtEventEmitter.emit("subtask_completed", taskId, sessionId, agentId, traceId, extra)
    }

    /**
     * 目标达成（长程任务终态）
     *
     * @param goalAchievement 目标达成度 0.0-1.0（来自 LrtVerifier 的验核报告）
     */
    public static func goalAchieved(
        taskId: String, sessionId: String, agentId: String,
        goalAchievement: Float64, artifactCount: Int64, summary: String, traceId: String
    ): Unit {
        let extra = HashMap<String, JsonValue>()
        extra["goalAchievement"] = JsonValue.Number(goalAchievement)
        extra["artifactCount"] = JsonValue.Number(Float64(artifactCount))
        extra["summary"] = JsonValue.String(summary)
        LrtEventEmitter.emit("goal_achieved", taskId, sessionId, agentId, traceId, extra)
    }

    /**
     * 用户评审请求（spec 5.6.1 规则 3 / Ch6.3）。
     *
     * 任务完成且全部产物验核通过后推送，用户可：
     *   - 确认交付 → 调 lrt-deliver(action=confirm)
     *   - 要求改进 → 调 lrt-review(action=improve, feedback=...)
     *   - 放弃     → 调 lrt-deliver(action=abandon)
     *
     * 与 goal_achieved 的区别：goal_achieved 是执行器内部终态通知，
     * review_required 是面向用户的交互请求——前者通知"跑完了"，后者要求"请确认"。
     */
    public static func reviewRequired(
        taskId: String, sessionId: String, agentId: String,
        goalAchievement: Float64, artifactCount: Int64,
        summary: String, goal: String, traceId: String
    ): Unit {
        let extra = HashMap<String, JsonValue>()
        extra["goalAchievement"] = JsonValue.Number(goalAchievement)
        extra["artifactCount"] = JsonValue.Number(Float64(artifactCount))
        extra["summary"] = JsonValue.String(summary)
        extra["goal"] = JsonValue.String(goal)
        LrtEventEmitter.emit("review_required", taskId, sessionId, agentId, traceId, extra)
    }

    /**
     * 契约漂移告警（spec 5.16.3 规则 7 / Ch14.3）。
     *
     * DATA_CONTRACT.yaml 声明的表结构与 db_schema_lookup 返回的实际结构不一致时推送。
     * 事件 payload 含 findings 数组，每项含 table/field/type/expected/actual/severity。
     */
    public static func emitContractDrift(
        taskId: String, sessionId: String, agentId: String,
        traceId: String, extra: HashMap<String, JsonValue>
    ): Unit {
        LrtEventEmitter.emit("contract_drift", taskId, sessionId, agentId, traceId, extra)
    }

    /**
     * 监控告警（spec §11.3 / Ch11.3）。
     *
     * 由 LrtMonitorService 在阈值突破时调用，或由宿主日志水位探针调用。
     * payload 含 metric/value/threshold/level/message/window，前端可据此渲染告警卡片。
     */
    public static func emitMonitorAlert(
        taskId: String, sessionId: String, agentId: String, traceId: String,
        metric: String, value: Float64, threshold: Float64,
        level: String, message: String, window: Int64
    ): Unit {
        let extra = HashMap<String, JsonValue>()
        extra["metric"] = JsonValue.String(metric)
        extra["value"] = JsonValue.Number(value)
        extra["threshold"] = JsonValue.Number(threshold)
        extra["level"] = JsonValue.String(level)
        extra["message"] = JsonValue.String(message)
        extra["window"] = JsonValue.Number(Float64(window))
        // 任务级告警携带真实 sessionId → 宿主 dispatch 同时走 SSE（浏览器聊天流可见）与 WS 广播，
        // 与 review_required 同通道。系统级告警（如宿主日志水位探针）可传空 sessionId，
        // 此时 dispatch 只走 WS 广播（SSE 通道按约定跳过空 sessionId）。
        LrtEventEmitter.emit("monitor_alert", taskId, sessionId, agentId, traceId, extra)
    }

    // ── 内部实现 ────────────────────────────────────────────────────

    /// 统一构造一次 invoke 并把异常吞掉（失败只记 stderr）
    private static func emit(
        eventType: String, taskId: String, sessionId: String,
        agentId: String, traceId: String, extra: HashMap<String, JsonValue>
    ): Unit {
        let ctxOpt = LrtEventEmitter.ctx
        match (ctxOpt) {
            case None =>
                // 未注入 ctx（理论上只在插件启动前发生）——静默跳过
                eprintln("[lrt-event] ctx 未初始化，丢弃事件 ${eventType}")
                return
            case Some(ctx) =>
                let params = HashMap<String, JsonValue>()
                params["type"] = JsonValue.String(eventType)
                params["taskId"] = JsonValue.String(taskId)
                params["sessionId"] = JsonValue.String(sessionId)
                params["agentId"] = JsonValue.String(agentId)
                params["traceId"] = JsonValue.String(traceId)
                params["payload"] = JsonValue.from(extra)

                let args = Array<JsonValue>(1, { _ => JsonValue.Null })
                args[0] = JsonValue.from(params)
                try {
                    // 显式 <JsonValue, JsonValue> 消歧：不写类型实参会因两个同形重载
                    // （plugin_runtime.cj:115 非泛型版 / :131 泛型版）报 ambiguous match。
                    // T 必须取 JsonValue（与实参元素类型一致），否则形参会被按 T 重写成
                    // Array<PluginContext> 之类的类型而报 mismatched types。
                    let _ = ctx.invoke<JsonValue, JsonValue>("host.event", "emit", args)
                } catch (e: Exception) {
                    // 事件是观测面：投递失败不上抛，否则会打断正在跑的回合
                    eprintln("[lrt-event] 事件上报失败（已忽略）type=${eventType}: ${e}")
                }
        }
    }
}
