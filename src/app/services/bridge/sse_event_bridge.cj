/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.bridge

import magic.interaction.{EventHandlerManager, ChatModelEndEvent, ChatModelEndEventHandler, ToolCallStartEvent, ToolCallStartEventHandler, ToolCallEndEvent, ToolCallEndEventHandler, EventResponse}
import magic.tool.webmcp.SSEConnectionManager
import magic.log.LogUtils
import std.sync.{AtomicBool, ReentrantMutex}

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
                    // 推送 reasoning_content
                    if (let Some(reason) <- evt.chatResponse.message.reason) {
                        if (!reason.isEmpty()) {
                            let reasoningId = "reasoning-sse-${stepCount.toString()}"
                            // 推送 reasoning-start
                            let startData = "{\"id\":\"${reasoningId}\"}"
                            sseMgr.pushMessage(sid, "reasoning-start", startData)
                            // 推送 reasoning-delta（完整 reasoning 内容）
                            let escapedReason = reason.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
                            let deltaData = "{\"id\":\"${reasoningId}\",\"reasoning\":\"${escapedReason}\"}"
                            sseMgr.pushMessage(sid, "reasoning-delta", deltaData)
                            // 推送 reasoning-end
                            let endData = "{\"id\":\"${reasoningId}\"}"
                            sseMgr.pushMessage(sid, "reasoning-end", endData)
                            LogUtils.debug("SSEEventBridge", "reasoning 已推送，step=${stepCount.toString()}，length=${reason.size.toString()}")
                        }
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
}