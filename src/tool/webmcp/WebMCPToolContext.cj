/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool.webmcp

import std.sync.Mutex
import std.collection.ArrayList
import magic.log.LogUtils

/**
 * 一次会话上下文绑定（Ch0.5 新增）
 *
 * 每个绑定记录 sessionId + 两个管理器 + 绑定令牌与时间戳。
 * 提升为顶层类而非内部类，与同包 `PendingToolCallEntry` 的写法保持一致，
 * 避免内部类的可见性/构造语义差异。
 */
class SessionBinding {
    let token: Int64
    let sessionId: String
    let sseManager: SSEConnectionManager
    let pendingManager: PendingToolCallManager

    init(token: Int64, sessionId: String, sseManager: SSEConnectionManager, pendingManager: PendingToolCallManager) {
        this.token = token
        this.sessionId = sessionId
        this.sseManager = sseManager
        this.pendingManager = pendingManager
    }
}

/**
 * WebMCP 工具执行上下文全局单例
 *
 * 为 WebMCP 工具（WebNavigateTool/WebNotifyTool/WebRequestApprovalTool/FrontendToolAdapter）
 * 提供 SSE 推送能力和会话上下文。
 *
 * 工具通过 instance 全局获取当前会话的 sessionId、SSEConnectionManager 和 PendingToolCallManager，
 * 无需修改工具注册方式。
 *
 * ── Ch0.5（tasks 0.5 / design 2.4.5）并发安全改造 ─────────────────────
 * 原实现是**单槽可变单例**：一个 `_sessionId` 字段被所有请求/线程共享。
 * 这在同步链路（一次一个请求，顺序执行）勉强成立，但在异步链路
 * （`WebMCPProtocol.handleCompletionCompleteStream` → `agent.asyncChat` → `spawn`）
 * 与长程任务链路（`SchedulerEngine` 后台驱动）下会出现：
 *   1. **会话语义错乱**：会话 A 的 ReAct 还在跑，会话 B 的请求进来覆盖 `_sessionId`，
 *      会话 A 的工具调用被推到 B 的 SSE 连接上；
 *   2. **上下文被提前清空**：`clearSessionContext()` 由 A 调用时把正在跑长程任务的
 *      B 上下文一并抹掉 → 工具侧拿到 None → 误报"前端连接不可用"（这正是 Round2
 *      在异步路径观测到的"响应丢失"）。
 *
 * 改造策略（**保持既有 API 签名不变**，零调用方改动）：
 *   - `setSessionContext` 变为**入栈 + 绑定**：记录 push 次序，返回本次绑定令牌；
 *   - 新增 `endSessionContext(token)` 精准出栈，避免"清空一切"；
 *   - `clearSessionContext()` 保留但语义收缩为"弹出栈顶"，不再清空整张表；
 *   - 读接口 `getSessionId/getSSEManager/getPendingManager` 优先返回**栈顶**（最近绑定者），
 *     无栈顶时回退到**默认绑定**（controller 初始化时注册的那一份），保证老行为兼容。
 *
 * 栈深度有上限（`MAX_CONTEXT_DEPTH`），超出时丢弃最旧的绑定并告警，防止泄漏。
 *
 * 包路径：magic.tool.webmcp（基础设施层，不依赖 magic.app.services.webmcp）
 * 同包内的 SSEConnectionManager 和 PendingToolCallManager 默认可见，不需要 import。
 */
public class WebMCPToolContext {
    /// 全局单例
    public static let instance = WebMCPToolContext()

    /// 绑定栈深度上限（防止忘记出栈导致的泄漏）
    private static let MAX_CONTEXT_DEPTH = 64

    /// 绑定栈（栈顶 = 最近一次 setSessionContext）
    private let _stack = ArrayList<SessionBinding>()

    /// 默认绑定（controller 初始化注册，永不随请求出栈）
    private var _defaultBinding: ?SessionBinding = None

    /// 令牌自增源
    private var _nextToken: Int64 = 0

    /// 保护并发访问
    private let _mutex = Mutex()

    public init() {}

    /**
     * 设置当前会话上下文（入栈）
     *
     * 适用于**有明确生命周期的请求作用域**：调用方拿到返回令牌后，
     * 必须在 `finally` 中调用 `endSessionContext(token)` 配对出栈。
     *
     * 兼容性说明：签名与原实现一致（原返回 Unit，现返回 Int64 令牌），
     * 老调用方可忽略返回值——此时语义退化为"注册默认绑定 + 长驻栈顶"，
     * 读接口仍能拿到会话信息，行为不退化。
     *
     * ⚠️ 长驻调用方（如 controller 的每次请求注入）建议改用 `registerDefaultContext`，
     * 避免栈被逐次请求堆满。
     *
     * @param sessionId 会话 ID
     * @param sseManager SSE 连接管理器
     * @param pendingManager 待处理工具调用管理器
     * @return 本次绑定的令牌，供 `endSessionContext` 精准出栈
     */
    public func setSessionContext(sessionId: String, sseManager: SSEConnectionManager, pendingManager: PendingToolCallManager): Int64 {
        return _bind(sessionId, sseManager, pendingManager, true)
    }

    /**
     * 注册默认上下文（不入栈）
     *
     * 供 controller 在每次请求注入基础设施时调用。它只刷新"默认绑定"——
     * 即栈空时读接口回退到的那一份——不向绑定栈追加元素，
     * 因此**无论请求多少次，栈深度都是 0**，杜绝栈泄漏。
     *
     * 这样设计的原因：`_initProtocolInfrastructure` 是幂等的"当前会话挂载"操作，
     * 不是一次性的请求作用域；把幂等操作做成栈 push 会随请求数线性膨胀。
     *
     * @return 本次绑定的令牌（可用于显式注销，通常无需使用）
     */
    public func registerDefaultContext(sessionId: String, sseManager: SSEConnectionManager, pendingManager: PendingToolCallManager): Int64 {
        return _bind(sessionId, sseManager, pendingManager, false)
    }

    /// 绑定实现：pushToStack 决定是否追加到栈（默认绑定总是刷新）
    private func _bind(sessionId: String, sseManager: SSEConnectionManager, pendingManager: PendingToolCallManager, pushToStack: Bool): Int64 {
        var token: Int64 = 0
        var evicted = 0
        var depth = 0
        synchronized(_mutex) {
            _nextToken = _nextToken + 1
            token = _nextToken

            let binding = SessionBinding(token, sessionId, sseManager, pendingManager)
            // 默认绑定跟随最近一次注册刷新：它代表"controller 当前挂的会话"，
            // 栈空时读接口回退到它，保证没有配对出栈调用时老行为不退化。
            _defaultBinding = Some(binding)

            if (pushToStack) {
                _stack.add(binding)
                // 深度保护：超限时从栈底淘汰（最旧的绑定最可能是泄漏的）
                while (_stack.size > MAX_CONTEXT_DEPTH) {
                    _stack.remove(at: 0)
                    evicted = evicted + 1
                }
            }
            // 注意：Mutex 非可重入，深度必须在锁内就地取值，
            // 不能调用 stackDepth()（那会二次加锁 → 死锁）
            depth = _stack.size
        }
        if (evicted > 0) {
            LogUtils.warn("[WebMCPToolContext] binding stack overflow, evicted ${evicted} oldest binding(s), sessionId=${sessionId}")
        }
        LogUtils.debug("[WebMCPToolContext] Session context bound, sessionId=${sessionId}, token=${token.toString()}, pushed=${pushToStack}, depth=${depth.toString()}")
        return token
    }

    /**
     * 精准出栈：结束一次会话上下文绑定
     *
     * 按令牌移除对应绑定（不只是弹栈顶），这样乱序结束时也不会误伤他人。
     * 令牌不存在时静默忽略（幂等），只记 debug 日志。
     */
    public func endSessionContext(token: Int64): Unit {
        var removed = false
        var depth = 0
        synchronized(_mutex) {
            var i = _stack.size - 1
            while (i >= 0) {
                if (_stack[i].token == token) {
                    _stack.remove(at: i)
                    removed = true
                    break
                }
                i = i - 1
            }
            depth = _stack.size
        }
        if (removed) {
            LogUtils.debug("[WebMCPToolContext] Session context popped, token=${token.toString()}, depth=${depth.toString()}")
        } else {
            LogUtils.debug("[WebMCPToolContext] Session context pop ignored (token not found), token=${token.toString()}")
        }
    }

    /**
     * 清除当前会话上下文
     *
     * ⚠️ 语义变更（Ch0.5）：原实现把 `_sessionId` / `_sseManager` / `_pendingManager`
     * **全部清空**，在并发场景下会抹掉他人上下文。现收缩为"仅弹出栈顶一层"，
     * 绝不清空整张表，也**不动默认绑定**。
     */
    public func clearSessionContext(): Unit {
        var poppedSessionId = ""
        var hadPopped = false
        var depth = 0
        synchronized(_mutex) {
            if (_stack.size > 0) {
                let top = _stack[_stack.size - 1]
                poppedSessionId = top.sessionId
                _stack.remove(at: _stack.size - 1)
                hadPopped = true
            }
            depth = _stack.size
        }
        if (hadPopped) {
            LogUtils.debug("[WebMCPToolContext] Session context popped (clearSessionContext), sessionId=${poppedSessionId}, depth=${depth.toString()}")
        } else {
            LogUtils.debug("[WebMCPToolContext] clearSessionContext called with empty stack, no-op")
        }
    }

    /// 当前绑定栈深度（诊断用）
    public func stackDepth(): Int64 {
        synchronized(_mutex) {
            _stack.size
        }
    }

    /**
     * 取当前生效的绑定：优先栈顶，其次默认绑定
     */
    private func currentBinding(): ?SessionBinding {
        synchronized(_mutex) {
            if (_stack.size > 0) {
                return _stack[_stack.size - 1]
            }
            return _defaultBinding
        }
    }

    /**
     * 获取当前会话 ID
     * @return 会话 ID（空字符串返回 None）
     */
    public func getSessionId(): ?String {
        match (currentBinding()) {
            case Some(b) =>
                if (b.sessionId.isEmpty()) {
                    None<String>
                } else {
                    Some(b.sessionId)
                }
            case None => None<String>
        }
    }

    /**
     * 获取 SSE 连接管理器
     */
    public func getSSEManager(): ?SSEConnectionManager {
        match (currentBinding()) {
            case Some(b) => Some(b.sseManager)
            case None => None<SSEConnectionManager>
        }
    }

    /**
     * 获取待处理工具调用管理器
     */
    public func getPendingManager(): ?PendingToolCallManager {
        match (currentBinding()) {
            case Some(b) => Some(b.pendingManager)
            case None => None<PendingToolCallManager>
        }
    }
}
