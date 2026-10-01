/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.bridge

import magic.log.LogUtils
import magic.tool.webmcp.SSEConnectionManager
import stdx.encoding.json.{JsonObject, JsonString, JsonInt, JsonBool}
import std.time.DateTime

/**
 * SDD 六步进度事件桥接器（REQ-SDD-001 DFX / design §2.4 / tasks.md T-12）。
 *
 * ## 与 LrtEventBridge 的关系：复用通道，不复用事件
 * 投递通道完全复用既有两条（WebSocket 广播 + SSE 按会话推送），事件类型则是
 * SDD 专属的 `sdd_*`——六步编排的进度语义（第几步 / 哪个子 agent / 产物落在哪）
 * 长程任务事件里没有对应项，混用会让前端无法区分。
 *
 * ## 两条铁律
 * 1. **投递失败不阻断业务**：事件是观测面不是控制面，异常只记日志，绝不上抛
 *    （一次 SSE 断连不该让正在跑的六步失败）。
 * 2. **SSE 单行**：`SSEConnectionManager.pushMessage` 的帧格式是
 *    `id: N\nevent: T\ndata: ${data}\n\n`，前端只收以 `data:` 开头的行。
 *    data 里残留裸换行会把一帧切成多段，后续各行没有前缀被丢弃，
 *    剩下的残缺 JSON 连解析都过不了 → 整条事件静默丢失。故推送前一律转义。
 *
 * ## 无 session 时的处理
 * 六步编排常由 cron 驱动（无会话），此时 SSE 无连接可推——**早退且不打日志**
 * （不是异常，打日志会被误判成故障）。WebSocket 广播照常。
 */
public enum SddEventType {
    | StepStart
    | StepComplete
    | StepFailed
    | Progress
    | SubagentSpawn
    | SubagentDone
    | GoalAchieved
    | ReviewRequired

    /// 事件类型字符串（与前端约定的 `type` 字段值）
    public func wireName(): String {
        match (this) {
            case StepStart => "sdd_step_start"
            case StepComplete => "sdd_step_complete"
            case StepFailed => "sdd_step_failed"
            case Progress => "sdd_progress"
            case SubagentSpawn => "sdd_subagent_spawn"
            case SubagentDone => "sdd_subagent_done"
            case GoalAchieved => "sdd_goal_achieved"
            case ReviewRequired => "sdd_review_required"
        }
    }
}

public class SddEventBridge {
    /**
     * SSE 连接管理器引用（一次性注入、长期持有）。
     *
     * 与 LrtEventBridge 同一注入时机：宿主 Protocol 基础设施初始化处
     * （`WebMCPController` 里 `LrtEventBridge.attachSSEManager` 的同一行附近）。
     */
    private static var _sseManagerHolder: ?SSEConnectionManager = None

    public static func attachSSEManager(sseManager: SSEConnectionManager): Unit {
        SddEventBridge._sseManagerHolder = Some(sseManager)
    }

    // ── 事件推送入口 ──────────────────────────────────────────────
    // 统一形参：(featureName, sessionId, agentId) + 事件专有字段
    //   - featureName：SDD 工程唯一键（事件的业务主键）
    //   - sessionId  ：SSE 会话 ID（为空则只走 WebSocket 广播）
    //   - agentId    ：Agent 标识（WebSocket 缓冲按 agentId 归档）

    /// 阶段开始
    public func pushStepStart(
        featureName: String,
        sessionId: String,
        agentId: String,
        stage: String,
        stageIndex: Int64,
        totalStages: Int64
    ): Unit {
        let data = buildEvent(SddEventType.StepStart, featureName, agentId)
        data.put("stage", JsonString(stage))
        data.put("stageIndex", JsonInt(stageIndex))
        data.put("totalStages", JsonInt(totalStages))
        dispatch(data, sessionId, agentId)
    }

    /// 阶段完成（携带产物相对路径，便于前端直接链到文档）
    public func pushStepComplete(
        featureName: String,
        sessionId: String,
        agentId: String,
        stage: String,
        stageIndex: Int64,
        totalStages: Int64,
        artifactPath: String,
        durationMs: Int64
    ): Unit {
        let data = buildEvent(SddEventType.StepComplete, featureName, agentId)
        data.put("stage", JsonString(stage))
        data.put("stageIndex", JsonInt(stageIndex))
        data.put("totalStages", JsonInt(totalStages))
        data.put("artifactPath", JsonString(artifactPath))
        data.put("durationMs", JsonInt(durationMs))
        dispatch(data, sessionId, agentId)
    }

    /// 阶段失败（不降级、不重试，直接暴露给前端）
    public func pushStepFailed(
        featureName: String,
        sessionId: String,
        agentId: String,
        stage: String,
        error: String
    ): Unit {
        let data = buildEvent(SddEventType.StepFailed, featureName, agentId)
        data.put("stage", JsonString(stage))
        data.put("error", JsonString(error))
        dispatch(data, sessionId, agentId)
    }

    /// 子 agent 派生开始 / 结束（REQ-SDD-010 的可观测面）
    public func pushSubagentSpawn(
        featureName: String,
        sessionId: String,
        agentId: String,
        stage: String,
        subAgentName: String
    ): Unit {
        let data = buildEvent(SddEventType.SubagentSpawn, featureName, agentId)
        data.put("stage", JsonString(stage))
        data.put("subAgent", JsonString(subAgentName))
        dispatch(data, sessionId, agentId)
    }

    public func pushSubagentDone(
        featureName: String,
        sessionId: String,
        agentId: String,
        stage: String,
        subAgentName: String,
        success: Bool,
        durationMs: Int64
    ): Unit {
        let data = buildEvent(SddEventType.SubagentDone, featureName, agentId)
        data.put("stage", JsonString(stage))
        data.put("subAgent", JsonString(subAgentName))
        data.put("success", JsonBool(success))
        data.put("durationMs", JsonInt(durationMs))
        dispatch(data, sessionId, agentId)
    }

    /// 六步全部走完
    public func pushGoalAchieved(
        featureName: String,
        sessionId: String,
        agentId: String
    ): Unit {
        let data = buildEvent(SddEventType.GoalAchieved, featureName, agentId)
        dispatch(data, sessionId, agentId)
    }

    /// 停在闸口等人工决策（confirm / revise / abandon）
    public func pushReviewRequired(
        featureName: String,
        sessionId: String,
        agentId: String,
        stage: String,
        gateName: String
    ): Unit {
        let data = buildEvent(SddEventType.ReviewRequired, featureName, agentId)
        data.put("stage", JsonString(stage))
        data.put("gate", JsonString(gateName))
        dispatch(data, sessionId, agentId)
    }

    // ── 内部实现 ──────────────────────────────────────────────────

    private func buildEvent(
        eventType: SddEventType,
        featureName: String,
        agentId: String
    ): JsonObject {
        let obj = JsonObject()
        obj.put("type", JsonString(eventType.wireName()))
        obj.put("agentId", JsonString(agentId))
        obj.put("featureName", JsonString(featureName))
        obj.put("timestamp", JsonString(DateTime.now().toString()))
        obj
    }

    /**
     * 双通道投递：WebSocket 广播 + SSE 按会话推送。
     *
     * 复用 `WebSocketEventBridge.broadcastLrtEvent`（既有实现，按 agentId 归档广播）；
     * SSE 侧只在**会话存在**时推送，不存在则早退且不打日志（cron 场景常态）。
     */
    private func dispatch(data: JsonObject, sessionId: String, agentId: String): Unit {
        try {
            WebSocketEventBridge.instance.broadcastLrtEvent(agentId, data)
        } catch (e: Exception) {
            LogUtils.warn("[SddEventBridge] WS 投递失败（不影响执行）: ${e.message}")
        }

        if (sessionId.isEmpty()) {
            return
        }
        try {
            match (SddEventBridge._sseManagerHolder) {
                case None => ()
                case Some(mgr) =>
                    if (mgr.hasConnection(sessionId)) {
                        var wire = data.toString()
                        if (wire.contains("\n") || wire.contains("\r")) {
                            wire = wire.replace("\r", "\\r").replace("\n", "\\n")
                        }
                        mgr.pushMessage(sessionId, "sdd_event", wire)
                    }
            }
        } catch (e: Exception) {
            LogUtils.warn("[SddEventBridge] SSE 投递失败（不影响执行）: ${e.message}")
        }
    }
}
