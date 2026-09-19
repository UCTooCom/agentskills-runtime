/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */

/**
 * 长程任务事件桥接器（Ch9.2）
 *
 * 设计要点（design 2.1.4 / tasks 9.2）：
 * 1. **复用优先**：不新建事件基础设施，长程任务事件直接复用
 *    `WebSocketEventBridge` 的 `buildEventJson` / `broadcastToSessions`
 *    与 `SSEEventBridge` 的 SSEConnectionManager 推送通道。
 * 2. **不重复建模 trace**：tasks 9.2 明确要求先复用已存在的
 *    `trace_start` / `trace_step` / `trace_token_usage` / `trace_end`，
 *    仅在不足时新增。经核对，trace_* 四类事件已覆盖"追踪 + 步骤"语义，
 *    本桥接器**不重建**它们，只在长程任务专有事件上做扩展字段补充。
 * 3. **双通道**：同一事件同时投递 WebSocket（广播）与 SSE（按会话），
 *    前端无论走哪条链路都能收到，不依赖前端选路。
 * 4. **投递失败不阻断业务**：事件推送属观测面而非控制面；推送异常只记日志，
 *    绝不让异常冒泡到执行主链路（否则一次推送失败会中断长程任务回合）。
 */

package magic.app.services.bridge

import magic.log.LogUtils
import magic.tool.webmcp.SSEConnectionManager
import stdx.encoding.json.{JsonObject, JsonString, JsonInt, JsonFloat, JsonBool, JsonArray, JsonNull}
import std.time.DateTime

/**
 * 长程任务专用事件类型（tasks 9.2 的 8 类）
 *
 * 与已有事件的关系：
 * - `checkpoint_saved` / `progress_update` 是长程任务特有语义，新建；
 * - `step_start` / `step_complete` / `step_failed` 承载 **SOP 步骤**（COMPOSITION.yaml 的
 *   一步），与 ReAct 的 `trace_step`（承载一次 ReAct 迭代）不是同一层，故并存不冲突；
 * - `subtask_dispatched` / `subtask_completed` 与已有 `sub_agent_start` / `sub_agent_end`
 *   的区别是前者携带任务树节点信息（subTaskId / parentTaskId），后者只有 agent 名；
 * - `goal_achieved` 是长程任务的终态达成事件，无对应已有事件。
 */
public enum LrtEventType {
    | StepStart
    | StepComplete
    | StepFailed
    | CheckpointSaved
    | ProgressUpdate
    | SubtaskDispatched
    | SubtaskCompleted
    | GoalAchieved
    | ReviewRequired
    | MonitorAlert

    /// 事件类型字符串（与前端约定的 `type` 字段值）
    public func wireName(): String {
        match (this) {
            case StepStart => "step_start"
            case StepComplete => "step_complete"
            case StepFailed => "step_failed"
            case CheckpointSaved => "checkpoint_saved"
            case ProgressUpdate => "progress_update"
            case SubtaskDispatched => "subtask_dispatched"
            case SubtaskCompleted => "subtask_completed"
            case GoalAchieved => "goal_achieved"
            case ReviewRequired => "review_required"
            case MonitorAlert => "monitor_alert"
        }
    }
}

public class LrtEventBridge {
    private static var instance_: Option<LrtEventBridge> = None<LrtEventBridge>

    /**
     * SSE 连接管理器引用（由宿主侧在 Protocol 基础设施初始化时注入一次）
     *
     * 与 SSEEventBridge 的「每次请求 init/clear」不同：长程任务是**后台长跑**的，
     * 没有"当前请求"可依附，因此这里采用**一次性注入、长期持有**，
     * 推送时按 sessionId 取具体连接（连接不存在则只走 WebSocket 通道）。
     */
    private static var _sseManagerHolder: ?SSEConnectionManager = None

    /// 注入 SSE 连接管理器（幂等；宿主侧 _initProtocolInfrastructure 调用）
    public static func attachSSEManager(sseManager: SSEConnectionManager): Unit {
        LrtEventBridge._sseManagerHolder = Some(sseManager)
    }

    public static prop instance: LrtEventBridge {
        get() {
            match (instance_) {
                case Some(v) => v
                case None =>
                    let inst = LrtEventBridge()
                    instance_ = Some(inst)
                    inst
            }
        }
    }

    public init() {}

    // ── 8 类事件推送入口 ───────────────────────────────────────────
    // 统一形参：(taskId, sessionId, agentId) + 事件专有字段
    //   - taskId     ：长程任务根任务 ID（事件去重与串联用）
    //   - sessionId  ：SSE 会话 ID（为空则只走 WebSocket 广播）
    //   - agentId    ：Agent 标识（WebSocket 缓冲按 agentId 归档，与既有事件一致）

    /**
     * 步骤开始（SOP 步骤级，非 ReAct 迭代级）
     *
     * @param stepName SOP 步骤名（COMPOSITION.yaml 的 step.name）
     * @param stepIndex 当前步骤序号（从 1 开始）
     * @param totalSteps 总步骤数
     */
    public func pushStepStart(
        taskId: String,
        sessionId: String,
        agentId: String,
        stepName: String,
        stepIndex: Int64,
        totalSteps: Int64,
        traceId: String
    ): Unit {
        let data = this.buildLrtEvent(LrtEventType.StepStart, taskId, agentId, traceId)
        data.put("stepName", JsonString(stepName))
        data.put("stepIndex", JsonInt(stepIndex))
        data.put("totalSteps", JsonInt(totalSteps))
        this.dispatch(data, sessionId, agentId)
    }

    /**
     * 步骤完成
     *
     * @param durationMs 本步骤耗时
     * @param intermediateResult 中间结果预览（截断后的产物摘要，避免 payload 过大）
     */
    public func pushStepComplete(
        taskId: String,
        sessionId: String,
        agentId: String,
        stepName: String,
        stepIndex: Int64,
        totalSteps: Int64,
        durationMs: Int64,
        intermediateResult: String,
        traceId: String
    ): Unit {
        let data = this.buildLrtEvent(LrtEventType.StepComplete, taskId, agentId, traceId)
        data.put("stepName", JsonString(stepName))
        data.put("stepIndex", JsonInt(stepIndex))
        data.put("totalSteps", JsonInt(totalSteps))
        data.put("durationMs", JsonInt(durationMs))
        data.put("intermediateResult", JsonString(intermediateResult))
        // 进度百分比由 stepIndex/totalSteps 推导，前端不必自行猜测
        data.put("progressPercent", JsonFloat(LrtEventBridge.computePercent(stepIndex, totalSteps)))
        this.dispatch(data, sessionId, agentId)
    }

    /**
     * 步骤失败（降级链的每一次尝试失败都应上报，便于前端展示"已重试 N 次"）
     *
     * @param attempt 第几次尝试（从 1 开始）
     * @param willRetry 是否还有后续降级方案可尝试
     */
    public func pushStepFailed(
        taskId: String,
        sessionId: String,
        agentId: String,
        stepName: String,
        stepIndex: Int64,
        errorMessage: String,
        attempt: Int64,
        willRetry: Bool,
        traceId: String
    ): Unit {
        let data = this.buildLrtEvent(LrtEventType.StepFailed, taskId, agentId, traceId)
        data.put("stepName", JsonString(stepName))
        data.put("stepIndex", JsonInt(stepIndex))
        data.put("error", JsonString(errorMessage))
        data.put("attempt", JsonInt(attempt))
        data.put("willRetry", JsonBool(willRetry))
        this.dispatch(data, sessionId, agentId)
    }

    /// 检查点已保存（回合级，Ch4.1）
    public func pushCheckpointSaved(
        taskId: String,
        sessionId: String,
        agentId: String,
        checkpointId: String,
        chatRound: Int64,
        traceId: String
    ): Unit {
        let data = this.buildLrtEvent(LrtEventType.CheckpointSaved, taskId, agentId, traceId)
        data.put("checkpointId", JsonString(checkpointId))
        data.put("chatRound", JsonInt(chatRound))
        this.dispatch(data, sessionId, agentId)
    }

    /**
     * 进度更新（Ch9.1 的 progress API 与事件双写，保证前端两条路都能拿到同一份进度）
     *
     * @param estimatedRemainingMs 预估剩余毫秒；**无基线时为 null**，不得填 0
     *        （0 会被前端解读为"马上完成"，是误导；见 tasks 9.1）
     */
    public func pushProgressUpdate(
        taskId: String,
        sessionId: String,
        agentId: String,
        completedSteps: Int64,
        totalSteps: Int64,
        currentStep: String,
        estimatedRemainingMs: ?Int64,
        intermediateResult: String,
        traceId: String
    ): Unit {
        let data = this.buildLrtEvent(LrtEventType.ProgressUpdate, taskId, agentId, traceId)
        data.put("completedSteps", JsonInt(completedSteps))
        data.put("totalSteps", JsonInt(totalSteps))
        data.put("currentStep", JsonString(currentStep))
        data.put("progressPercent", JsonFloat(LrtEventBridge.computePercent(completedSteps, totalSteps)))
        match (estimatedRemainingMs) {
            case Some(ms) => data.put("estimatedRemaining", JsonInt(ms))
            case None => data.put("estimatedRemaining", JsonNull())  // 显式 null，非 0
        }
        data.put("intermediateResult", JsonString(intermediateResult))
        this.dispatch(data, sessionId, agentId)
    }

    /**
     * 子任务已派发
     *
     * @param subTaskId 子任务 ID
     * @param parentTaskId 父任务 ID（任务树父子关系来自 agent_tasks.parent_task_id）
     * @param skillSequence 该子任务计划使用的技能序列（JSON 数组）
     */
    public func pushSubtaskDispatched(
        taskId: String,
        sessionId: String,
        agentId: String,
        subTaskId: String,
        parentTaskId: String,
        description: String,
        skillSequence: JsonArray,
        traceId: String
    ): Unit {
        let data = this.buildLrtEvent(LrtEventType.SubtaskDispatched, taskId, agentId, traceId)
        data.put("subTaskId", JsonString(subTaskId))
        data.put("parentTaskId", JsonString(parentTaskId))
        data.put("description", JsonString(description))
        data.put("skillSequence", skillSequence)
        this.dispatch(data, sessionId, agentId)
    }

    /// 子任务已完成（resultSummary 为子任务 result 字段的预览）
    public func pushSubtaskCompleted(
        taskId: String,
        sessionId: String,
        agentId: String,
        subTaskId: String,
        status: Int64,
        resultSummary: String,
        traceId: String
    ): Unit {
        let data = this.buildLrtEvent(LrtEventType.SubtaskCompleted, taskId, agentId, traceId)
        data.put("subTaskId", JsonString(subTaskId))
        data.put("status", JsonInt(status))
        data.put("resultSummary", JsonString(resultSummary))
        this.dispatch(data, sessionId, agentId)
    }

    /**
     * 目标达成（长程任务终态）
     *
     * @param goalAchievement 目标达成度 0.0-1.0（来自 LrtVerifier 的验核报告）
     * @param artifactCount 交付产物数量
     */
    public func pushGoalAchieved(
        taskId: String,
        sessionId: String,
        agentId: String,
        goalAchievement: Float64,
        artifactCount: Int64,
        summary: String,
        traceId: String
    ): Unit {
        let data = this.buildLrtEvent(LrtEventType.GoalAchieved, taskId, agentId, traceId)
        data.put("goalAchievement", JsonFloat(goalAchievement))
        data.put("artifactCount", JsonInt(artifactCount))
        data.put("summary", JsonString(summary))
        this.dispatch(data, sessionId, agentId)
    }

    /**
     * 用户评审请求（spec 5.6.1 规则 3 / Ch6.3）
     *
     * 任务完成且全部产物验核通过后推送，前端据此渲染评审卡片，用户可：
     *   - 确认交付 → 调 lrt-deliver(action=confirm)
     *   - 要求改进 → 调 lrt-review(action=improve, feedback=...)
     *   - 放弃     → 调 lrt-deliver(action=abandon)
     *
     * 与 goal_achieved 的区别：goal_achieved 是执行器内部终态通知（"跑完了"），
     * review_required 是面向用户的交互请求（"请确认"）。两者都由 executor 在
     * outcome=completed 时相继推送。
     */
    public func pushReviewRequired(
        taskId: String,
        sessionId: String,
        agentId: String,
        goalAchievement: Float64,
        artifactCount: Int64,
        summary: String,
        goal: String,
        traceId: String
    ): Unit {
        let data = this.buildLrtEvent(LrtEventType.ReviewRequired, taskId, agentId, traceId)
        data.put("goalAchievement", JsonFloat(goalAchievement))
        data.put("artifactCount", JsonInt(artifactCount))
        data.put("summary", JsonString(summary))
        data.put("goal", JsonString(goal))
        this.dispatch(data, sessionId, agentId)
    }

    /**
     * 监控告警（spec §11.3 / Ch11.3）。
     *
     * 由插件侧 LrtMonitorService（阈值突破）或宿主侧日志水位探针推送。
     * sessionId 非空时走 SSE 定向推送，为空时仅 WS 广播（系统级告警的降级路径）。
     * payload 与前端约定：metric / value / threshold / level / message / window。
     */
    public func pushMonitorAlert(
        taskId: String,
        sessionId: String,
        agentId: String,
        metric: String,
        value: Float64,
        threshold: Float64,
        level: String,
        message: String,
        window: Int64,
        traceId: String
    ): Unit {
        let data = this.buildLrtEvent(LrtEventType.MonitorAlert, taskId, agentId, traceId)
        data.put("metric", JsonString(metric))
        data.put("value", JsonFloat(value))
        data.put("threshold", JsonFloat(threshold))
        data.put("level", JsonString(level))
        data.put("message", JsonString(message))
        data.put("window", JsonInt(window))
        this.dispatch(data, sessionId, agentId)
    }

    // ── 内部实现 ──────────────────────────────────────────────────

    /**
     * 构造长程任务事件 JSON（复用既有事件的字段风格：type / agentId / timestamp）
     *
     * 额外统一携带 traceId，使前端能把长程任务事件与既有 trace_* 事件串成一条链
     * （spec 5.18 规则 5：trace 贯穿）。
     */
    private func buildLrtEvent(
        eventType: LrtEventType,
        taskId: String,
        agentId: String,
        traceId: String
    ): JsonObject {
        let obj = JsonObject()
        obj.put("type", JsonString(eventType.wireName()))
        obj.put("agentId", JsonString(agentId))
        obj.put("timestamp", JsonString(DateTime.now().toString()))
        obj.put("lrtTaskId", JsonString(taskId))
        if (!traceId.isEmpty()) {
            obj.put("traceId", JsonString(traceId))
        }
        obj
    }

    /**
     * 双通道投递：WebSocket 广播 + SSE 按会话推送
     *
     * 核心约束：**全程 try/catch，异常只记日志不上抛**。
     * 理由是这两个通道都是观测面：一次 SSE 连接断开或 WS 会话已销毁，
     * 不应该让正在跑的长程任务回合失败。
     */
    private func dispatch(data: JsonObject, sessionId: String, agentId: String): Unit {
        // 通道 1：WebSocket —— 复用 WebSocketEventBridge 的广播实现
        try {
            WebSocketEventBridge.instance.broadcastLrtEvent(agentId, data)
        } catch (e: Exception) {
            LogUtils.warn("[LrtEventBridge] WS 投递失败（不影响执行）: ${e.message}")
        }

        // 通道 2：SSE —— 仅当调用方提供了会话 ID 时推送
        if (sessionId.isEmpty()) {
            return
        }
        try {
            let sseMgr = LrtEventBridge._sseManagerHolder
            match (sseMgr) {
                case None =>
                    LogUtils.debug("[LrtEventBridge] SSE 管理器未注入，跳过 SSE 投递")
                case Some(mgr) =>
                    if (mgr.hasConnection(sessionId)) {
                        mgr.pushMessage(sessionId, "lrt_event", data.toString())
                    }
            }
        } catch (e: Exception) {
            LogUtils.warn("[LrtEventBridge] SSE 投递失败（不影响执行）: ${e.message}")
        }
    }

    /// 进度百分比计算：totalSteps <= 0 时返回 0（避免除零）
    private static func computePercent(done: Int64, total: Int64): Float64 {
        if (total <= 0) {
            return 0.0
        }
        Float64(done) / Float64(total) * 100.0
    }
}
