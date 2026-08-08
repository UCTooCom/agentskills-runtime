/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.interaction

import std.collection.{ArrayList, HashMap}
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt}
import magic.log.LogUtils

public class TokenUsage {
    public var promptTokens: Int64 = 0
    public var completionTokens: Int64 = 0
    public var totalTokens: Int64 = 0

    public init() {}

    public init(promptTokens!: Int64, completionTokens!: Int64, totalTokens!: Int64) {
        this.promptTokens = promptTokens
        this.completionTokens = completionTokens
        this.totalTokens = totalTokens
    }

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("prompt_tokens", JsonInt(this.promptTokens))
        map.add("completion_tokens", JsonInt(this.completionTokens))
        map.add("total_tokens", JsonInt(this.totalTokens))
        return JsonObject(map)
    }
}

public class SessionTrace {
    public var sessionId: String = ""
    public var agentName: String = ""
    public var startTime: DateTime = DateTime.now()
    public var endTime: Option<DateTime> = None<DateTime>
    public var status: String = "running"
    public var evidenceIds: ArrayList<String> = ArrayList<String>()
    public var tokenUsage: TokenUsage = TokenUsage()
    public var toolCallCount: Int64 = 0
    public var sideEffectCount: Int64 = 0

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("session_id", JsonString(this.sessionId))
        map.add("agent_name", JsonString(this.agentName))
        map.add("start_time", JsonString(this.startTime.toString()))
        if (let Some(et) <- this.endTime) {
            map.add("end_time", JsonString(et.toString()))
        }
        map.add("status", JsonString(this.status))
        map.add("token_usage", this.tokenUsage.toJsonValue())
        map.add("tool_call_count", JsonInt(this.toolCallCount))
        map.add("side_effect_count", JsonInt(this.sideEffectCount))
        return JsonObject(map)
    }
}

public class AgentLoopTracer {
    private let _auditEventHandler: AuditEventHandler
    private var _activeTraces: HashMap<String, SessionTrace>
    private var _tokenAccumulator: HashMap<String, TokenUsage>
    private let _eventPusher: (String, String, JsonValue) -> Unit

    public init() {
        _auditEventHandler = AuditEventHandler()
        _activeTraces = HashMap<String, SessionTrace>()
        _tokenAccumulator = HashMap<String, TokenUsage>()
        _eventPusher = { _, _, _ => }
    }

    public init(auditEventHandler!: AuditEventHandler, eventPusher!: (String, String, JsonValue) -> Unit) {
        _auditEventHandler = auditEventHandler
        _activeTraces = HashMap<String, SessionTrace>()
        _tokenAccumulator = HashMap<String, TokenUsage>()
        _eventPusher = eventPusher
    }

    public func onAgentStart(agentName: String, sessionId: String, input: Option<JsonValue>): String {
        let evidenceId = _auditEventHandler.onAgentStart(agentName, sessionId, input)

        let trace = SessionTrace()
        trace.sessionId = sessionId
        trace.agentName = agentName
        trace.startTime = DateTime.now()
        trace.status = "running"
        trace.evidenceIds.add(evidenceId)

        _activeTraces.add(sessionId, trace)
        _tokenAccumulator.add(sessionId, TokenUsage())

        pushTraceEvent(sessionId, "agent_start", trace.toJsonValue())

        LogUtils.info("[AgentLoopTracer] Agent started: ${agentName}, session: ${sessionId}")
        return evidenceId
    }

    public func onAgentEnd(agentName: String, output: Option<JsonValue>): Unit {
        _auditEventHandler.onAgentEnd(agentName, output)

        var foundSessionId: Option<String> = None<String>
        for ((sid, trace) in _activeTraces) {
            if (trace.agentName == agentName) {
                foundSessionId = Some(sid)
                break
            }
        }

        if (let Some(sid) <- foundSessionId) {
            if (let Some(trace) <- _activeTraces.get(sid)) {
                trace.endTime = Some(DateTime.now())
                trace.status = "completed"
                pushTraceEvent(sid, "agent_end", trace.toJsonValue())
                LogUtils.info("[AgentLoopTracer] Agent ended: ${agentName}, session: ${sid}")
            }
        }
    }

    public func onAgentError(agentName: String, errorMessage: String): Unit {
        _auditEventHandler.onAgentError(agentName, errorMessage)

        var foundSessionId: Option<String> = None<String>
        for ((sid, trace) in _activeTraces) {
            if (trace.agentName == agentName) {
                foundSessionId = Some(sid)
                break
            }
        }

        if (let Some(sid) <- foundSessionId) {
            if (let Some(trace) <- _activeTraces.get(sid)) {
                trace.endTime = Some(DateTime.now())
                trace.status = "failed"
                pushTraceEvent(sid, "agent_error", trace.toJsonValue())
            }
        }
    }

    public func onToolCall(agentName: String, toolName: String, args: Option<JsonValue>, result: Option<JsonValue>): Unit {
        _auditEventHandler.onToolCall(agentName, toolName, args, result)

        var foundSessionId: Option<String> = None<String>
        for ((sid, trace) in _activeTraces) {
            if (trace.agentName == agentName) {
                foundSessionId = Some(sid)
                break
            }
        }

        if (let Some(sid) <- foundSessionId) {
            if (let Some(trace) <- _activeTraces.get(sid)) {
                trace.toolCallCount = trace.toolCallCount + 1
                var data = HashMap<String, JsonValue>()
                data.add("tool_name", JsonString(toolName))
                data.add("tool_call_count", JsonInt(trace.toolCallCount))
                pushTraceEvent(sid, "tool_call", JsonObject(data))
            }
        }
    }

    public func onTokenUsage(agentName: String, promptTokens: Int64, completionTokens: Int64, totalTokens: Int64): Unit {
        var foundSessionId: Option<String> = None<String>
        for ((sid, trace) in _activeTraces) {
            if (trace.agentName == agentName) {
                foundSessionId = Some(sid)
                break
            }
        }

        if (let Some(sid) <- foundSessionId) {
            if (let Some(trace) <- _activeTraces.get(sid)) {
                trace.tokenUsage.promptTokens = trace.tokenUsage.promptTokens + promptTokens
                trace.tokenUsage.completionTokens = trace.tokenUsage.completionTokens + completionTokens
                trace.tokenUsage.totalTokens = trace.tokenUsage.totalTokens + totalTokens
                pushTraceEvent(sid, "token_usage", trace.tokenUsage.toJsonValue())
            }
            if (let Some(acc) <- _tokenAccumulator.get(sid)) {
                acc.promptTokens = acc.promptTokens + promptTokens
                acc.completionTokens = acc.completionTokens + completionTokens
                acc.totalTokens = acc.totalTokens + totalTokens
            }
        }
    }

    public func getSessionTrace(sessionId: String): Option<SessionTrace> {
        return _activeTraces.get(sessionId)
    }

    public func getActiveTraces(): ArrayList<SessionTrace> {
        let traces = ArrayList<SessionTrace>()
        for ((_, trace) in _activeTraces) {
            traces.add(trace)
        }
        return traces
    }

    public func getTokenUsage(sessionId: String): Option<TokenUsage> {
        return _tokenAccumulator.get(sessionId)
    }

    public func pushTraceEvent(sessionId: String, eventType: String, data: JsonValue): Unit {
        _eventPusher(eventType, sessionId, data)
        LogUtils.debug("[AgentLoopTracer] Trace event pushed: ${eventType} for session ${sessionId}")
    }

    public func getAuditEventHandler(): AuditEventHandler {
        return _auditEventHandler
    }
}
