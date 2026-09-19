/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool.webmcp

import std.collection.{HashMap, ArrayList}
import std.sync.ReentrantMutex
import magic.log.LogUtils

/**
 * 单会话 SSE 事件环形缓冲
 * frames 存储 (eventId, 完整SSE帧) 元组，按 id 升序追加；超出 CAP 时丢弃最旧条目。
 */
private class SSEEventLog {
    public static let CAP: Int64 = 2048
    public let frames: ArrayList<(Int64, String)> = ArrayList<(Int64, String)>()
    public init() {}
}

/**
 * SSE 连接管理器（v26 韧性增强版）
 *
 * 相较旧版的两点关键变化：
 * 1. 多订阅者：每个 sessionId 下维护一组 writer（HashMap<subId, writer>），
 *    支持同会话同时存在「POST 真流式」与「GET /events 重连流」等多个消费者，
 *    任一消费者连接断开只移除自身，不影响其他消费者。
 * 2. 事件缓冲 + 单调 eventId：每次 pushMessage 都分配一个全局单调递增的 eventId，
 *    并把原始 SSE 帧存入该会话的环形缓冲（最近 N 条）。断线重连的客户端可凭
 *    lastEventId 回放错过事件，实现「断线续传」。
 *
 * writer 约定返回 Bool：true=写入成功，false=连接已失效。pushMessage 据此精确移除失效订阅，
 * 避免旧实现中「闭包静默吞掉异常 → 持续向已关闭 socket 写入 → 刷屏 Socket is already closed」。
 *
 * 包路径：magic.tool.webmcp（基础设施层，不依赖 magic.app.services.webmcp）
 */
public class SSEConnectionManager {
    /// sessionId -> { subId -> SSE 写入回调（返回是否写入成功） }
    private var _connections = HashMap<String, HashMap<Int64, (String) -> Bool>>()

    /// sessionId -> 环形事件缓冲
    private var _buffers = HashMap<String, SSEEventLog>()

    /// 保护并发访问
    private let _mutex = ReentrantMutex()

    /// 自增订阅 id 分配器
    private var _nextSubId: Int64 = 0

    /// 全局单调递增事件序号（作为 SSE 的 id 字段，供 Last-Event-ID 重连语义使用）
    private var _eventSeq: Int64 = 0

    public init() {}

    /**
     * 注册 SSE 连接（多订阅者）
     * @param sessionId 会话 ID
     * @param writer SSE 写入回调，接收完整的 SSE 消息字符串（已含 id/event/data），返回写入是否成功
     * @return 订阅 id，用于后续精确注销（避免误删其他消费者）
     */
    public func registerConnection(sessionId: String, writer: (String) -> Bool): Int64 {
        synchronized(_mutex) {
            let subId = _nextSubId
            _nextSubId = _nextSubId + 1
            if (!_connections.contains(sessionId)) {
                _connections[sessionId] = HashMap<Int64, (String) -> Bool>()
            }
            let subsMap = _connections[sessionId]
            subsMap[subId] = writer
            LogUtils.debug("[SSEConnectionManager] Connection registered, sessionId=${sessionId}, subId=${subId.toString()}, total=${_connections.size.toString()}")
            return subId
        }
    }

    /**
     * 注销指定订阅
     * @param sessionId 会话 ID
     * @param subId registerConnection 返回的订阅 id
     */
    public func unregister(sessionId: String, subId: Int64): Unit {
        synchronized(_mutex) {
            let subsOpt = _connections.get(sessionId)
            if (subsOpt.isSome()) {
                let subs = subsOpt.getOrThrow()
                subs.remove(subId)
                if (subs.size == 0) {
                    _connections.remove(sessionId)
                }
            }
            LogUtils.debug("[SSEConnectionManager] Subscription removed, sessionId=${sessionId}, subId=${subId.toString()}")
        }
    }

    /**
     * 移除会话的所有连接（向后兼容，仅在确认该会话无其它消费者时调用）
     */
    public func removeConnection(sessionId: String): Unit {
        synchronized(_mutex) {
            _connections.remove(sessionId)
            LogUtils.debug("[SSEConnectionManager] All connections removed, sessionId=${sessionId}")
        }
    }

    /**
     * 检查指定会话是否存在任一活跃 SSE 连接
     */
    public func hasConnection(sessionId: String): Bool {
        synchronized(_mutex) {
            let subsOpt = _connections.get(sessionId)
            if (subsOpt.isSome()) {
                return subsOpt.getOrThrow().size > 0
            }
            return false
        }
    }

    /**
     * 向指定会话推送 SSE 消息，并写入环形缓冲（带单调 eventId）
     * @param sessionId 会话 ID
     * @param eventType 事件类型（如 tool_call、reasoning-delta、response.completed）
     * @param data 事件数据（JSON 字符串）
     * @return true 表示至少推送到一个活跃连接；false 表示无连接或全部失败
     */
    public func pushMessage(sessionId: String, eventType: String, data: String): Bool {
        // 1. 分配单调 id 并构造带 id 的 SSE 帧，同时写入缓冲
        var frame = ""
        var subIds: ArrayList<Int64> = ArrayList<Int64>()
        synchronized(_mutex) {
            let id = _eventSeq
            _eventSeq = _eventSeq + 1
            frame = "id: ${id}\nevent: ${eventType}\ndata: ${data}\n\n"
            bufferEvent(sessionId, id, frame)
            let subsOpt = _connections.get(sessionId)
            if (subsOpt.isSome()) {
                for ((sid, _) in subsOpt.getOrThrow()) {
                    subIds.add(sid)
                }
            }
        }

        if (subIds.isEmpty()) {
            LogUtils.debug("[SSEConnectionManager] No active connection, event buffered only, sessionId=${sessionId}, eventType=${eventType}")
            return false
        }

        // 2. 转发到所有活跃订阅者；写入失败（返回 false）者视为失效，精确移除
        var ok = false
        var dead: ArrayList<Int64> = ArrayList<Int64>()
        synchronized(_mutex) {
            let subsOpt = _connections.get(sessionId)
            if (subsOpt.isSome()) {
                let subs = subsOpt.getOrThrow()
                for (sid in subIds) {
                    let wOpt = subs.get(sid)
                    if (wOpt.isSome()) {
                        var okWrite = false
                        try {
                            okWrite = wOpt.getOrThrow()(frame)
                        } catch (e: Exception) {
                            // 防御：writer 意外抛异常也按失效处理
                            okWrite = false
                            LogUtils.warn("[SSEConnectionManager] Writer threw, marking dead, sessionId=${sessionId}, subId=${sid.toString()}, error=${e.message}")
                        }
                        if (okWrite) {
                            ok = true
                        } else {
                            dead.add(sid)
                        }
                    }
                }
            }
        }
        for (sid in dead) {
            unregister(sessionId, sid)
        }
        return ok
    }

    /**
     * 回放缓冲中 id > fromId 的事件帧（按 id 升序），供断线重连的客户端续传
     * @param sessionId 会话 ID
     * @param fromId 客户端已收到的最后一个事件 id（不含）；传 0 表示从头回放本会话缓冲
     * @return SSE 帧字符串列表（每个元素已含 "id:/event:/data:" 完整格式）
     */
    public func replayEvents(sessionId: String, fromId: Int64): ArrayList<String> {
        let result = ArrayList<String>()
        synchronized(_mutex) {
            let logOpt = _buffers.get(sessionId)
            if (logOpt.isSome()) {
                for ((id, f) in logOpt.getOrThrow().frames) {
                    if (id > fromId) {
                        result.add(f)
                    }
                }
            }
        }
        return result
    }

    /**
     * 获取会话缓冲中最后一个事件的 id（无缓冲返回 0）
     */
    public func getLastEventId(sessionId: String): Int64 {
        synchronized(_mutex) {
            let logOpt = _buffers.get(sessionId)
            if (logOpt.isSome()) {
                let frames = logOpt.getOrThrow().frames
                if (frames.size > 0) {
                    return frames[frames.size - 1][0]
                }
            }
            return 0
        }
    }

    /**
     * 清空会话缓冲（在一轮 agent 运行开始时调用，使 /events 回放范围收敛到当前轮次）
     */
    public func resetBuffer(sessionId: String): Unit {
        synchronized(_mutex) {
            _buffers.remove(sessionId)
            LogUtils.debug("[SSEConnectionManager] Buffer reset, sessionId=${sessionId}")
        }
    }

    /// 单条缓冲记录写入（调用方须持 _mutex）
    private func bufferEvent(sessionId: String, id: Int64, frame: String): Unit {
        if (!_buffers.contains(sessionId)) {
            _buffers[sessionId] = SSEEventLog()
        }
        let log = _buffers[sessionId]
        log.frames.add((id, frame))
        while (log.frames.size > SSEEventLog.CAP) {
            log.frames.remove(at: 0)
        }
    }
}
