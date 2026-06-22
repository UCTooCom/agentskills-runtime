/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool.webmcp

import std.sync.Mutex
import magic.log.LogUtils

/**
 * WebMCP 工具执行上下文全局单例
 *
 * 为 WebMCP 工具（WebNavigateTool/WebNotifyTool/WebRequestApprovalTool/FrontendToolAdapter）
 * 提供 SSE 推送能力和会话上下文。
 *
 * 工具通过 instance 全局获取当前会话的 sessionId、SSEConnectionManager 和 PendingToolCallManager，
 * 无需修改工具注册方式。WebMCPProtocol 在调用 Agent 前设置上下文，Agent 调用返回后清除上下文。
 *
 * 包路径：magic.tool.webmcp（基础设施层，不依赖 magic.app.services.webmcp）
 * 同包内的 SSEConnectionManager 和 PendingToolCallManager 默认可见，不需要 import。
 */
public class WebMCPToolContext {
    /// 全局单例
    public static let instance = WebMCPToolContext()

    /// 当前会话 ID
    private var _sessionId: String = ""

    /// SSE 连接管理器
    private var _sseManager: ?SSEConnectionManager = None

    /// 待处理工具调用管理器
    private var _pendingManager: ?PendingToolCallManager = None

    /// 保护并发访问
    private let _mutex = Mutex()

    public init() {}

    /**
     * 设置当前会话上下文
     * @param sessionId 会话 ID
     * @param sseManager SSE 连接管理器
     * @param pendingManager 待处理工具调用管理器
     */
    public func setSessionContext(sessionId: String, sseManager: SSEConnectionManager, pendingManager: PendingToolCallManager): Unit {
        synchronized(_mutex) {
            this._sessionId = sessionId
            this._sseManager = sseManager
            this._pendingManager = pendingManager
        }
        LogUtils.debug("[WebMCPToolContext] Session context set, sessionId=${sessionId}")
    }

    /**
     * 清除当前会话上下文（所有字段重置为默认值/None）
     */
    public func clearSessionContext(): Unit {
        var prevSessionId = ""
        synchronized(_mutex) {
            prevSessionId = this._sessionId
            this._sessionId = ""
            this._sseManager = None
            this._pendingManager = None
        }
        LogUtils.debug("[WebMCPToolContext] Session context cleared, sessionId=${prevSessionId}")
    }

    /**
     * 获取当前会话 ID
     * @return 会话 ID（空字符串返回 None）
     */
    public func getSessionId(): ?String {
        synchronized(_mutex) {
            if (this._sessionId.isEmpty()) {
                return None
            } else {
                return this._sessionId
            }
        }
    }

    /**
     * 获取 SSE 连接管理器
     */
    public func getSSEManager(): ?SSEConnectionManager {
        synchronized(_mutex) {
            this._sseManager
        }
    }

    /**
     * 获取待处理工具调用管理器
     */
    public func getPendingManager(): ?PendingToolCallManager {
        synchronized(_mutex) {
            this._pendingManager
        }
    }
}
