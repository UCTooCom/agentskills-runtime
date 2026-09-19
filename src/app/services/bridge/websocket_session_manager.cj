/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.bridge

import magic.app.services.ws_support.{WebSocketSession, WebSocketMessage}
import magic.log.LogUtils
import std.collection.concurrent.ConcurrentHashMap
import std.collection.ArrayList
import std.collection.Map
import std.sync.{Mutex, Condition}
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt}
import std.time.DateTime
import std.core.Duration

public class WebSocketSessionManager {
    private static var instance_: Option<WebSocketSessionManager> = None<WebSocketSessionManager>

    private let sessions = ConcurrentHashMap<String, WebSocketSession>()

    private let pendingApprovals = ConcurrentHashMap<String, ApprovalWaiter>()

    private let cancelFlags = ConcurrentHashMap<String, Bool>()

    public static prop instance: WebSocketSessionManager {
        get() {
            match (instance_) {
                case Some(v) => v
                case None =>
                    let inst = WebSocketSessionManager()
                    instance_ = Some(inst)
                    inst
            }
        }
    }

    public init() {}

    public func registerSession(session: WebSocketSession): Unit {
        sessions.add(session.sessionId, session)
        LogUtils.info("WebSocketSessionManager: registered session ${session.sessionId}")
    }

    public func unregisterSession(sessionId: String): Unit {
        sessions.remove(sessionId)
        LogUtils.info("WebSocketSessionManager: unregistered session ${sessionId}")
    }

    public func getSession(sessionId: String): Option<WebSocketSession> {
        match (sessions.get(sessionId)) {
            case Some(v) => Some(v)
            case None => None<WebSocketSession>
        }
    }

    public func getAllSessionIds(): ArrayList<String> {
        let ids = ArrayList<String>()
        for ((key, _) in sessions) {
            ids.add(key)
        }
        return ids
    }

    /// 下发审批请求并阻塞等待用户响应。
    ///
    /// Ch13.2（design 2.6.3）：新增 `options` / `defaultOption` / `recommended` 三个**可选**入参。
    ///   - 三者同时缺省时，payload 与改造前**逐字节一致**（不带 options 字段），老前端零影响。
    ///   - `options` 为 JSON 数组文本，元素形如 `{id,label,description,tradeoff}`；
    ///     `defaultOption` 为超时后自动采用的选项 id；`recommended` 为前端高亮的推荐项 id。
    ///
    /// 注意：超时返回 None 的既有语义**保持不变**。「超时自动采用 default」由调用方
    /// （WebHumanAgent）负责，因为只有它知道 default 值并需要记录
    /// `decision_timeout_default_applied` 日志；本方法只负责"有没有等到响应"这一层。
    public func sendApprovalRequest(
        sessionId: String,
        approvalId: String,
        question: String,
        approvalType: String,
        timeoutMs: Int64,
        options: String,
        defaultOption: String,
        recommended: String
    ): Option<String> {
        match (sessions.get(sessionId)) {
            case Some(session) =>
                let payload = JsonObject()
                payload.put("approval_id", JsonString(approvalId))
                payload.put("question", JsonString(question))
                payload.put("approval_type", JsonString(approvalType))
                payload.put("timeout_ms", JsonInt(timeoutMs))
                payload.put("timestamp", JsonInt((DateTime.now() - DateTime.UnixEpoch).toMilliseconds()))

                // Ch13.2：仅在提供 options 时下发，保证无 options 的调用方 payload 不变
                if (!options.isEmpty()) {
                    payload.put("options", JsonString(options))
                    if (!defaultOption.isEmpty()) {
                        payload.put("default", JsonString(defaultOption))
                    }
                    if (!recommended.isEmpty()) {
                        payload.put("recommended", JsonString(recommended))
                    }
                }

                let message = WebSocketMessage("approval_request", payload, (DateTime.now() - DateTime.UnixEpoch).toMilliseconds())
                session.sendMessage(message)

                let mutex = Mutex()
                let waiter = ApprovalWaiter(approvalId, mutex, mutex.condition())
                pendingApprovals.add(approvalId, waiter)

                waiter.mutex.lock()
                var waited: Int64 = 0
                let checkInterval: Int64 = 100
                while (!waiter.resolved && waited < timeoutMs) {
                    let remaining = timeoutMs - waited
                    let waitTime = if (remaining < checkInterval) { remaining } else { checkInterval }
                    waiter.condition.wait(timeout: Duration.millisecond * waitTime)
                    waited = waited + waitTime
                }
                let responseOpt = waiter.response
                waiter.mutex.unlock()

                pendingApprovals.remove(approvalId)

                if (waiter.resolved) {
                    match (responseOpt) {
                        case Some(resp) => Some(resp)
                        case None => None<String>
                    }
                } else {
                    LogUtils.info("Approval ${approvalId} timed out after ${timeoutMs}ms")
                    None<String>
                }
            case None =>
                LogUtils.error("WebSocketSessionManager: session ${sessionId} not found for approval request")
                None<String>
        }
    }

    public func resolveApproval(approvalId: String, response: String): Unit {
        match (pendingApprovals.get(approvalId)) {
            case Some(waiter) =>
                waiter.mutex.lock()
                waiter.response = Some(response)
                waiter.resolved = true
                waiter.condition.notifyAll()
                waiter.mutex.unlock()
            case None =>
                LogUtils.error("WebSocketSessionManager: no pending approval found for ${approvalId}")
        }
    }

    public func cancelAgent(sessionId: String): Unit {
        cancelFlags.add(sessionId, true)
        LogUtils.info("WebSocketSessionManager: cancel flag set for session ${sessionId}")
    }

    public func isCancelled(sessionId: String): Bool {
        match (cancelFlags.get(sessionId)) {
            case Some(v) => v
            case None => false
        }
    }

    public func clearCancelFlag(sessionId: String): Unit {
        cancelFlags.remove(sessionId)
    }
}

public class ApprovalWaiter {
    public let approvalId: String
    public let mutex: Mutex
    public let condition: Condition
    public var response: Option<String> = None<String>
    public var resolved: Bool = false

    public init(approvalId: String, mutex: Mutex, condition: Condition) {
        this.approvalId = approvalId
        this.mutex = mutex
        this.condition = condition
    }
}