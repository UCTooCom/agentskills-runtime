/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.bridge

import magic.interaction.{EventHandlerManager, ChatModelEndEvent, ChatModelEndEventHandler, ToolCallStartEvent, ToolCallStartEventHandler, ToolCallEndEvent, ToolCallEndEventHandler, EventResponse}
import magic.tool.webmcp.SSEConnectionManager
import magic.log.LogUtils
import std.sync.{AtomicBool, ReentrantMutex}
import std.core.Duration

import stdx.encoding.json.JsonString

/**
 * SSE 事件桥接器
 *
 * v16 实时思维链显示：在 ReAct 执行过程中，每次 LLM 调用完成时（ChatModelEndEvent），
 * 将 reasoning_content 实时推送到前端 SSE 通道，而非等 agent.chat() 返回后才推送。
 *
 * 设计模式：与 WebSocketEventBridge 类似的单例 + 全局事件处理器注册，
 * 但推送目标是 SSEConnectionManager（按 sessionId 推送），而非 WebSocket 广播。
 *
 * 生命周期：
 *   WebMCPProtocol.handleCompletionComplete
 *     ├── SSEEventBridge.instance.init(sseManager, sessionId)  // agent.chat() 之前
 *     ├── agent.chat(agentRequest)                              // ReAct 执行，ChatModelEndEvent 自动触发
 *     └── SSEEventBridge.instance.clear()                      // agent.chat() 之后
 */
public class SSEEventBridge {
    private static var instance_: Option<SSEEventBridge> = None<SSEEventBridge>

    /// SSE 连接管理器引用（由 WebMCPProtocol 注入）
    private var _sseManager: ?SSEConnectionManager = None

    /// 当前会话 ID
    private var _sessionId: String = ""

    /// 是否已注册事件处理器（避免重复注册）
    private static var _registered: AtomicBool = AtomicBool(false)

    /// 保护 init/clear 的并发访问
    private let _mutex = ReentrantMutex()

    /// reasoning 步骤计数器（为每个 reasoning 块生成唯一 id）
    private var _reasoningStepCount: Int64 = 0

    public static prop instance: SSEEventBridge {
        get() {
            match (instance_) {
                case Some(v) => v
                case None =>
                    let inst = SSEEventBridge()
                    instance_ = Some(inst)
                    inst
            }
        }
    }

    public init() {}

    /**
     * 初始化 SSE 事件桥接，注册全局事件处理器
     * 在 agent.chat() 调用前由 WebMCPProtocol 调用
     */
    public func initialize(sseManager: ?SSEConnectionManager, sessionId: String): Unit {
        synchronized(_mutex) {
            this._sseManager = sseManager
            this._sessionId = sessionId
            this._reasoningStepCount = 0
        }

        // 注册全局事件处理器（只注册一次）
        if (!_registered.load()) {
            registerGlobalHandlers()
            _registered.store(true)
            LogUtils.info("SSEEventBridge", "全局事件处理器已注册")
        }

        LogUtils.info("SSEEventBridge", "已初始化，sessionId=${sessionId}")
    }

    /**
     * 清理 SSE 事件桥接，断开与 SSE 连接的关联
     * 在 agent.chat() 返回后由 WebMCPProtocol 调用
     */
    public func clear(): Unit {
        synchronized(_mutex) {
            this._sseManager = None
            this._sessionId = ""
            this._reasoningStepCount = 0
        }
        LogUtils.info("SSEEventBridge", "已清理")
    }

    /**
     * 注册全局事件处理器到 EventHandlerManager.global
     * ChatModelEndEvent：每次 LLM 调用完成时触发，推送 reasoning 到 SSE
     * ToolCallStartEvent/ToolCallEndEvent：工具调用状态推送
     */
    private func registerGlobalHandlers(): Unit {
        let manager = EventHandlerManager.global

        // ChatModelEndEvent 处理器：实时推送 reasoning_content 到 SSE
        let h1: ChatModelEndEventHandler = { evt =>
            var sseMgrOpt: ?SSEConnectionManager = None
            var sid = ""
            var stepCount: Int64 = 0
            synchronized(instance._mutex) {
                sseMgrOpt = instance._sseManager
                sid = instance._sessionId
                stepCount = instance._reasoningStepCount
                instance._reasoningStepCount = stepCount + 1
            }

            if (let Some(sseMgr) <- sseMgrOpt) {
                if (!sid.isEmpty() && sseMgr.hasConnection(sid)) {
                    // 推送 reasoning_content（逐字推送，替代原有整段推送）
                    if (let Some(reason) <- evt.chatResponse.message.reason) {
                        let reasoningId = "reasoning-sse-${stepCount.toString()}"
                        // 超长思维链动态调整 chunkSize（spec.md 5.3.1 规则 3）
                        let runeLen = Int64(reason.toRuneArray().size)
                        let dynamicChunkSize = CharDeltaSplitter.recommendChunkSize(runeLen, 30, 30000)
                        instance.pushReasoningStream(sseMgr, sid, reasoningId, reason, dynamicChunkSize, 30)
                    }
                    // 推送正文 content 增量（新增，design.md 2.2.2.3）
                    let content = evt.chatResponse.message.content
                    if (!content.isEmpty()) {
                        instance.pushContentStream(sseMgr, sid, content, 0)
                    }
                }
            }

        }
        manager.addHandler(h1)

        // ToolCallStartEvent 处理器：推送工具调用开始状态
        let h2: ToolCallStartEventHandler = { evt =>
            var sseMgrOpt: ?SSEConnectionManager = None
            var sid = ""
            synchronized(instance._mutex) {
                sseMgrOpt = instance._sseManager
                sid = instance._sessionId
            }

            if (let Some(sseMgr) <- sseMgrOpt) {
                if (!sid.isEmpty() && sseMgr.hasConnection(sid)) {
                    let toolName = evt.toolRequest.name
                    let data = "{\"toolName\":\"${toolName}\",\"status\":\"running\"}"
                    sseMgr.pushMessage(sid, "tool-call-start", data)
                    LogUtils.debug("SSEEventBridge", "tool-call-start 已推送：${toolName}")
                }
            }
            EventResponse.Continue
        }
        manager.addHandler(h2)

        // ToolCallEndEvent 处理器：推送工具调用完成状态
        let h3: ToolCallEndEventHandler = { evt =>
            var sseMgrOpt: ?SSEConnectionManager = None
            var sid = ""
            synchronized(instance._mutex) {
                sseMgrOpt = instance._sseManager
                sid = instance._sessionId
            }

            if (let Some(sseMgr) <- sseMgrOpt) {
                if (!sid.isEmpty() && sseMgr.hasConnection(sid)) {
                    let toolName = evt.toolRequest.name
                    let data = "{\"toolName\":\"${toolName}\",\"status\":\"success\"}"
                    sseMgr.pushMessage(sid, "tool-call-end", data)
                    LogUtils.debug("SSEEventBridge", "tool-call-end 已推送：${toolName}")
                }
            }
        }
        manager.addHandler(h3)

        LogUtils.info("SSEEventBridge", "已注册3个全局事件处理器（ChatModelEnd/ToolCallStart/ToolCallEnd）")
    }

    /**
     * 逐字推送 reasoning_content（思维链）
     *
     * 将完整的 reasoning_content 拆分为逐字增量，通过多个 reasoning-delta SSE 事件推送，
     * 模拟大模型逐字输出效果。
     *
     * 仓颉规范约束（已复核 design.md D-1/D-2/D-6）：
     * 1. sleep 接收 Duration 而非 Int64，必须写 sleep(Duration.millisecond * intervalMs)。
     *    参考 WebMCPProtocol.cj:1276 现有写法 sleep(Duration.second * 15)。
     * 2. JSON 转义责任：推送 reasoning-delta 前，增量字符串必须经过 JSON 转义。
     *    禁止使用手工 replace 链（遗漏 Unicode 控制字符 \u0000-\u001F，存在注入风险）。
     *    应使用仓颉标准库的 JsonString(value).toString() 进行标准化转义。
     * 3. 默认参数位置：chunkSize: Int64 = 5 和 intervalMs: Int64 = 30 为带默认值参数，
     *    必须排在无默认值参数（sseMgr, sessionId, reasoningId, reason）之后，当前签名满足此约束。
     *
     * 事件序列：reasoning-start → N × reasoning-delta（间隔 intervalMs）→ reasoning-end
     *
     * 参数：
     * - sseMgr: SSE 连接管理器
     * - sessionId: 会话 ID
     * - reasoningId: 思维链块唯一标识（格式 reasoning-sse-{stepCount}）
     * - reason: 完整 reasoning_content
     * - chunkSize: 每块最大字符数（按 Rune 计数），默认 5
     * - intervalMs: 推送间隔（毫秒），默认 30
     */
    public func pushReasoningStream(
        sseMgr: SSEConnectionManager,
        sessionId: String,
        reasoningId: String,
        reason: String,
        chunkSize: Int64,
        intervalMs: Int64
    ): Unit {
        // 前置条件检查：连接不存在则跳过
        if (sessionId.isEmpty() || !sseMgr.hasConnection(sessionId)) {
            LogUtils.warn("SSEEventBridge", "pushReasoningStream 跳过：连接不存在，sessionId=${sessionId}")
            return
        }

        // 前置条件检查：reason 为空则只推送 start + end
        if (reason.isEmpty()) {
            let startData = "{\"id\":\"${reasoningId}\"}"
            sseMgr.pushMessage(sessionId, "reasoning-start", startData)
            let endData = "{\"id\":\"${reasoningId}\"}"
            sseMgr.pushMessage(sessionId, "reasoning-end", endData)
            return
        }

        // 推送 reasoning-start
        let startData = "{\"id\":\"${reasoningId}\"}"
        sseMgr.pushMessage(sessionId, "reasoning-start", startData)

        // 使用 CharDeltaSplitter 拆分 reason 为逐字增量数组
        let chunks = CharDeltaSplitter.split(reason, chunkSize)
        var idx: Int64 = 0
        while (idx < Int64(chunks.size)) {
            // 连接断开时停止推送
            if (!sseMgr.hasConnection(sessionId)) {
                LogUtils.warn("SSEEventBridge", "pushReasoningStream 中途断开：sessionId=${sessionId}，已推送 ${idx.toString()} 块")
                return
            }

            let delta = chunks[idx]
            // 仓颉规范 D-6：JSON 转义使用 JsonString(value).toString() 标准化转义
            let escapedDelta = JsonString(delta).toString()
            let deltaData = "{\"id\":\"${reasoningId}\",\"reasoning\":${escapedDelta}}"
            sseMgr.pushMessage(sessionId, "reasoning-delta", deltaData)

            // 仓颉规范 D-2：sleep 接收 Duration，必须写 sleep(Duration.millisecond * intervalMs)
            if (idx < Int64(chunks.size) - 1) {
                sleep(Duration.millisecond * intervalMs)
            }

            idx++
        }

        // 推送 reasoning-end
        let endData = "{\"id\":\"${reasoningId}\"}"
        sseMgr.pushMessage(sessionId, "reasoning-end", endData)

        LogUtils.debug("SSEEventBridge", "pushReasoningStream 完成：reasoningId=${reasoningId}，块数=${idx.toString()}，总长度=${reason.size.toString()}")
    }

    /**
     * 推送正文 content 增量（response.output_text.delta）
     *
     * 将正文 content 拆分为增量块，通过 response.output_text.delta SSE 事件实时推送。
     * delta 为正文增量字符串（非完整正文），前端需累加拼接为完整正文。
     *
     * 仓颉规范约束（已复核 design.md D-3/D-6）：
     * 1. 默认参数位置：outputIndex: Int64 = 0 为带默认值参数，排在无默认值参数
     *    （sseMgr, sessionId, content）之后，满足仓颉默认参数约束。
     * 2. JSON 转义责任：推送 response.output_text.delta 前，增量字符串 delta 必须经过
     *    JSON 转义。禁止使用手工 replace 链（遗漏 Unicode 控制字符 \u0000-\u001F，
     *    存在注入风险）。应使用仓颉标准库的 JsonString(value).toString() 标准化转义。
     *
     * data 字段格式：{"output_index":${outputIndex},"delta":${escapedDelta}}
     * 参考 AIController.cj:212-214 现有实现。
     *
     * 参数：
     * - sseMgr: SSE 连接管理器
     * - sessionId: 会话 ID
     * - content: 正文 content（完整或增量，取决于调用场景）
     * - outputIndex: 正文输出索引，默认 0
     */
    public func pushContentStream(
        sseMgr: SSEConnectionManager,
        sessionId: String,
        content: String,
        outputIndex: Int64
    ): Unit {
        // 前置条件检查：连接不存在则跳过
        if (sessionId.isEmpty() || !sseMgr.hasConnection(sessionId)) {
            LogUtils.warn("SSEEventBridge", "pushContentStream 跳过：连接不存在，sessionId=${sessionId}")
            return
        }

        // 前置条件检查：content 为空则不推送
        if (content.isEmpty()) {
            return
        }

        // 使用 CharDeltaSplitter 拆分 content 为增量块
        let chunks = CharDeltaSplitter.split(content, 5)
        var idx: Int64 = 0
        while (idx < Int64(chunks.size)) {
            // 连接断开时停止推送
            if (!sseMgr.hasConnection(sessionId)) {
                LogUtils.warn("SSEEventBridge", "pushContentStream 中途断开：sessionId=${sessionId}，已推送 ${idx.toString()} 块")
                return
            }

            let delta = chunks[idx]
            // 仓颉规范 D-6：JSON 转义使用 JsonString(value).toString() 标准化转义
            let escapedDelta = JsonString(delta).toString()
            // data 格式：{"output_index":${outputIndex},"delta":${escapedDelta}}
            // 参考 AIController.cj:212-214 现有实现
            let deltaData = "{\"output_index\":${outputIndex.toString()},\"delta\":${escapedDelta}}"
            sseMgr.pushMessage(sessionId, "response.output_text.delta", deltaData)

            idx++
        }

        LogUtils.debug("SSEEventBridge", "pushContentStream 完成：outputIndex=${outputIndex.toString()}，块数=${idx.toString()}")
    }
}