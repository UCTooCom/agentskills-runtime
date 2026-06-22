/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool.webmcp

import std.collection.{HashMap, ArrayList}
import std.sync.{Mutex, Condition}
import std.time.DateTime
import std.core.Duration
import magic.log.LogUtils

/**
 * 待处理工具调用条目
 *
 * 记录一次工具调用的上下文，通过 Condition 阻塞等待前端回传结果。
 * 调用方通过 register() 获取 entry 后，在 entry.mutex 上阻塞等待，
 * 前端回传结果时通过 handleResult() 设置 result 并 notifyAll 唤醒等待线程。
 */
public class PendingToolCallEntry {
    /// 工具调用 ID（唯一标识一次工具调用）
    public let callId: String

    /// 工具名称
    public let toolName: String

    /// 创建时间（毫秒时间戳）
    public let createdAt: Int64

    /// 超时时间（毫秒）
    public let timeoutMs: Int64

    /// 保护并发访问的互斥锁
    public let mutex: Mutex

    /// 条件变量，用于阻塞等待和唤醒
    public let condition: Condition

    /// 工具调用结果（前端回传）
    public var result: String = ""

    /// 是否已完成（正常完成或超时）
    public var completed: Bool = false

    /// 是否超时
    public var timedOut: Bool = false

    public init(callId: String, toolName: String, timeoutMs: Int64) {
        this.callId = callId
        this.toolName = toolName
        this.timeoutMs = timeoutMs
        this.createdAt = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
        this.mutex = Mutex()
        // Condition 必须在 mutex 锁定状态下创建
        this.mutex.lock()
        this.condition = this.mutex.condition()
        this.mutex.unlock()
    }
}

/**
 * 待处理工具调用管理器
 *
 * 管理工具调用的回调注册、触发和超时清理。
 * 工具调用时通过 register() 注册 entry，前端回传结果时通过 handleResult() 触发回调唤醒等待线程。
 *
 * 包路径：magic.tool.webmcp（基础设施层，不依赖 magic.app.services.webmcp）
 */
public class PendingToolCallManager {
    /// callId → entry 映射
    private var _entries = HashMap<String, PendingToolCallEntry>()

    /// 保护 _entries 并发访问
    private let _mutex = Mutex()

    public init() {}

    /**
     * 注册待处理工具调用
     * @param callId 工具调用 ID
     * @param toolName 工具名称
     * @param timeoutMs 超时时间（毫秒）
     * @return 创建的 entry，供调用方阻塞等待
     */
    public func register(callId: String, toolName: String, timeoutMs: Int64): PendingToolCallEntry {
        let entry = PendingToolCallEntry(callId, toolName, timeoutMs)
        synchronized(_mutex) {
            _entries.add(callId, entry)
        }
        LogUtils.info("[PendingToolCallManager] Registered, callId=${callId}, toolName=${toolName}, timeoutMs=${timeoutMs.toString()}")
        return entry
    }

    /**
     * 处理工具调用结果（前端回传）
     * @param callId 工具调用 ID
     * @param result 工具调用结果
     * @return true 表示找到对应 entry 并触发回调，false 表示未找到
     */
    public func handleResult(callId: String, result: String): Bool {
        var entryOpt: ?PendingToolCallEntry = None
        synchronized(_mutex) {
            entryOpt = _entries.get(callId)
            if (entryOpt.isSome()) {
                _entries.remove(callId)
            }
        }

        if (let Some(entry) <- entryOpt) {
            entry.mutex.lock()
            entry.result = result
            entry.completed = true
            entry.condition.notifyAll()
            entry.mutex.unlock()
            LogUtils.info("[PendingToolCallManager] Result handled, callId=${callId}, toolName=${entry.toolName}")
            return true
        } else {
            LogUtils.warn("[PendingToolCallManager] callId not found: ${callId}")
            return false
        }
    }

    /**
     * 检查 callId 是否存在
     */
    public func contains(callId: String): Bool {
        synchronized(_mutex) {
            _entries.contains(callId)
        }
    }

    /**
     * 移除指定 callId（用于超时后清理）
     */
    public func remove(callId: String): Unit {
        synchronized(_mutex) {
            _entries.remove(callId)
        }
    }

    /**
     * 清理所有超时条目
     * 遍历所有 entry，超时的标记 completed=true、timedOut=true、设置超时错误 result、notifyAll 唤醒，然后从 _entries 移除
     */
    public func cleanupTimedOut(): Unit {
        let now = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
        var timedOutEntries = ArrayList<PendingToolCallEntry>()

        synchronized(_mutex) {
            let toRemove = ArrayList<String>()
            for ((callId, entry) in _entries) {
                if (now - entry.createdAt >= entry.timeoutMs) {
                    toRemove.add(callId)
                    timedOutEntries.add(entry)
                }
            }
            for (callId in toRemove) {
                _entries.remove(callId)
            }
        }

        // 在 _mutex 外唤醒等待线程，避免长时间持锁
        for (entry in timedOutEntries) {
            entry.mutex.lock()
            if (!entry.completed) {
                entry.completed = true
                entry.timedOut = true
                entry.result = "{\"error\":\"${entry.toolName}操作超时，未收到前端响应\",\"callId\":\"${entry.callId}\"}"
                entry.condition.notifyAll()
                LogUtils.warn("[PendingToolCallManager] Timed out, callId=${entry.callId}, toolName=${entry.toolName}")
            }
            entry.mutex.unlock()
        }
    }
}
