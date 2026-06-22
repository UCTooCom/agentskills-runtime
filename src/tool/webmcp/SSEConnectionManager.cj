/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool.webmcp

import std.collection.HashMap
import std.sync.ReentrantMutex
import magic.log.LogUtils

/**
 * SSE 连接管理器
 *
 * 管理 SSE 连接的注册、移除和消息推送。每个 sessionId 对应一个 SSE 写入回调，
 * 通过该回调向前端推送 tool_call 等事件指令。
 *
 * 包路径：magic.tool.webmcp（基础设施层，不依赖 magic.app.services.webmcp）
 */
public class SSEConnectionManager {
    /// sessionId → SSE 写入回调
    private var _connections = HashMap<String, (String) -> Unit>()

    /// 保护并发访问
    private let _mutex = ReentrantMutex()

    public init() {}

    /**
     * 注册 SSE 连接
     * @param sessionId 会话 ID
     * @param writer SSE 写入回调，接收完整的 SSE 消息字符串
     */
    public func registerConnection(sessionId: String, writer: (String) -> Unit): Unit {
        synchronized(_mutex) {
            _connections.add(sessionId, writer)
            LogUtils.debug("[SSEConnectionManager] Connection registered, sessionId=${sessionId}, total=${_connections.size.toString()}")
        }
    }

    /**
     * 移除 SSE 连接
     * @param sessionId 会话 ID
     */
    public func removeConnection(sessionId: String): Unit {
        synchronized(_mutex) {
            _connections.remove(sessionId)
            LogUtils.debug("[SSEConnectionManager] Connection removed, sessionId=${sessionId}, total=${_connections.size.toString()}")
        }
    }

    /**
     * 向指定会话推送 SSE 消息
     * @param sessionId 会话 ID
     * @param eventType 事件类型（如 tool_call）
     * @param data 事件数据（JSON 字符串）
     * @return true 表示推送成功，false 表示连接不存在或推送失败（推送失败时自动移除该连接）
     */
    public func pushMessage(sessionId: String, eventType: String, data: String): Bool {
        var writerOpt: ?(String) -> Unit = None
        synchronized(_mutex) {
            writerOpt = _connections.get(sessionId)
        }

        if (let Some(writer) <- writerOpt) {
            // 构建 SSE 推送格式
            let message = "event: ${eventType}\ndata: ${data}\n\n"
            try {
                writer(message)
                LogUtils.debug("[SSEConnectionManager] Message pushed, sessionId=${sessionId}, eventType=${eventType}")
                return true
            } catch (e: Exception) {
                LogUtils.warn("[SSEConnectionManager] Push failed, removing connection, sessionId=${sessionId}, error=${e.message}")
                _connections.remove(sessionId)
                return false
            }
        } else {
            LogUtils.warn("[SSEConnectionManager] Connection not found, sessionId=${sessionId}")
            return false
        }
    }

    /**
     * 检查指定会话的 SSE 连接是否存在
     * @param sessionId 会话 ID
     * @return true 表示连接存在
     */
    public func hasConnection(sessionId: String): Bool {
        synchronized(_mutex) {
            _connections.contains(sessionId)
        }
    }
}
