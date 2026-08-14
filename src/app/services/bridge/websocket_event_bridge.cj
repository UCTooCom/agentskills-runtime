/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.bridge

import magic.interaction.{EventHandlerManager, AgentStartEvent, AgentEndEvent, AgentStepEvent, ChatModelEndEvent, ChatModelFailureEvent, ToolCallStartEvent, ToolCallEndEvent, SubAgentStartEvent, SubAgentEndEvent, AgentStartEventHandler, AgentEndEventHandler, AgentStepEventHandler, ChatModelEndEventHandler, ChatModelFailureEventHandler, ToolCallStartEventHandler, ToolCallEndEventHandler, SubAgentStartEventHandler, SubAgentEndEventHandler, EventResponse}
import magic.core.agent.AgentResponse
import magic.core.tool.ToolResponse
import magic.app.services.ws_support.WebSocketMessage
import magic.log.LogUtils
import std.collection.{ArrayList, concurrent.ConcurrentHashMap}
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonFloat, JsonBool, JsonArray}
import std.time.DateTime

public class WebSocketEventBridge {
    private static var instance_: Option<WebSocketEventBridge> = None<WebSocketEventBridge>

    private let sessionBuffers = ConcurrentHashMap<String, ArrayList<JsonObject>>()

    public static prop instance: WebSocketEventBridge {
        get() {
            match (instance_) {
                case Some(v) => v
                case None =>
                    let inst = WebSocketEventBridge()
                    instance_ = Some(inst)
                    inst
            }
        }
    }

    public init() {}

    public func registerGlobalHandlers(): Unit {
        let manager = EventHandlerManager.global

        let h1: AgentStartEventHandler = { evt =>
            let data = buildEventJson("agent_start", evt.agent.name)
            data.put("request", JsonString(evt.agentRequest.question))
            pushEvent(evt.agent.name, data)
            EventResponse.Continue
        }
        manager.addHandler(h1)

        let h2: AgentEndEventHandler = { evt =>
            let data = buildEventJson("agent_end", evt.agent.name)
            if (let Some(resp) <- evt.agentResponse) {
                data.put("status", JsonString("${resp.status}"))
                data.put("content", JsonString(resp.content))
            }
            pushEvent(evt.agent.name, data)
        }
        manager.addHandler(h2)

        let h3: AgentStepEventHandler = { evt =>
            let data = buildEventJson("agent_step", evt.agent.name)
            data.put("stepCount", JsonInt(evt.steps.size))
            pushEvent(evt.agent.name, data)
        }
        manager.addHandler(h3)

        let h4: ChatModelEndEventHandler = { evt =>
            let data = buildEventJson("chat_model_end", evt.agent.name)
            data.put("model", JsonString(evt.chatResponse.model))
            if (let Some(usage) <- evt.chatResponse.usage) {
                data.put("promptTokens", JsonInt(usage.promptTokens))
                data.put("completionTokens", JsonInt(usage.completionTokens))
                data.put("totalTokens", JsonInt(usage.totalTokens))
            }
            // 传递思维链（reasoning_content）到前端
            if (let Some(reason) <- evt.chatResponse.message.reason) {
                if (!reason.isEmpty()) {
                    data.put("reasoning", JsonString(reason))
                }
            }
            pushEvent(evt.agent.name, data)
        }
        manager.addHandler(h4)

        let h5: ChatModelFailureEventHandler = { evt =>
            let data = buildEventJson("chat_model_failure", evt.agent.name)
            data.put("error", JsonString(evt.error))
            pushEvent(evt.agent.name, data)
            EventResponse.Continue
        }
        manager.addHandler(h5)

        let h6: ToolCallStartEventHandler = { evt =>
            let data = buildEventJson("tool_call_start", evt.agent.name)
            data.put("toolName", JsonString(evt.toolRequest.name))
            pushEvent(evt.agent.name, data)
            EventResponse.Continue
        }
        manager.addHandler(h6)

        let h7: ToolCallEndEventHandler = { evt =>
            let data = buildEventJson("tool_call_end", evt.agent.name)
            data.put("toolName", JsonString(evt.toolRequest.name))
            data.put("toolResult", JsonString(evt.toolResponse.content))
            pushEvent(evt.agent.name, data)
        }
        manager.addHandler(h7)

        let h8: SubAgentStartEventHandler = { evt =>
            let data = buildEventJson("sub_agent_start", evt.agent.name)
            pushEvent(evt.agent.name, data)
            EventResponse.Continue
        }
        manager.addHandler(h8)

        let h9: SubAgentEndEventHandler = { evt =>
            let data = buildEventJson("sub_agent_end", evt.agent.name)
            pushEvent(evt.agent.name, data)
        }
        manager.addHandler(h9)

        LogUtils.info("WebSocketEventBridge", "已注册9个全局事件处理器到EventHandlerManager.global")
    }

    public func getBufferedEvents(sessionId: String): ArrayList<JsonObject> {
        match (sessionBuffers.get(sessionId)) {
            case Some(events) => events
            case None => ArrayList<JsonObject>()
        }
    }

    public func clearBufferedEvents(sessionId: String): Unit {
        sessionBuffers.remove(sessionId)
    }

    private func pushEvent(agentId: String, eventJson: JsonObject): Unit {
        match (sessionBuffers.get(agentId)) {
            case Some(events) => events.add(eventJson)
            case None =>
                let newEvents = ArrayList<JsonObject>()
                newEvents.add(eventJson)
                sessionBuffers.add(agentId, newEvents)
        }
        LogUtils.debug("WebSocketEventBridge", "事件已缓冲: ${eventJson}")
    }

    private func buildEventJson(eventType: String, agentId: String): JsonObject {
        let obj = JsonObject()
        obj.put("type", JsonString(eventType))
        obj.put("agentId", JsonString(agentId))
        obj.put("timestamp", JsonString(DateTime.now().toString()))
        obj
    }

    public func pushTraceStart(sessionId: String, agentName: String, traceId: String): Unit {
        let data = buildEventJson("trace_start", agentName)
        data.put("session_id", JsonString(sessionId))
        data.put("trace_id", JsonString(traceId))
        pushEvent(agentName, data)
        broadcastToSessions(data)
    }

    public func pushTraceStep(sessionId: String, agentName: String, stepType: String, stepData: JsonObject): Unit {
        let data = buildEventJson("trace_step", agentName)
        data.put("session_id", JsonString(sessionId))
        data.put("step_type", JsonString(stepType))
        data.put("step_data", stepData)
        pushEvent(agentName, data)
        broadcastToSessions(data)
    }

    public func pushTraceTokenUsage(sessionId: String, agentName: String, promptTokens: Int64, completionTokens: Int64, totalTokens: Int64): Unit {
        let data = buildEventJson("trace_token_usage", agentName)
        data.put("session_id", JsonString(sessionId))
        data.put("prompt_tokens", JsonInt(promptTokens))
        data.put("completion_tokens", JsonInt(completionTokens))
        data.put("total_tokens", JsonInt(totalTokens))
        pushEvent(agentName, data)
        broadcastToSessions(data)
    }

    public func pushTraceEnd(sessionId: String, agentName: String, status: String): Unit {
        let data = buildEventJson("trace_end", agentName)
        data.put("session_id", JsonString(sessionId))
        data.put("status", JsonString(status))
        pushEvent(agentName, data)
        broadcastToSessions(data)
    }

    public func pushEvaluationResult(agentId: String, evaluationType: String, successRate: Float64, avgDurationMs: Int64, totalTokens: Int64): Unit {
        let data = buildEventJson("evaluation_result", agentId)
        data.put("evaluation_type", JsonString(evaluationType))
        data.put("success_rate", JsonFloat(successRate))
        data.put("avg_duration_ms", JsonInt(avgDurationMs))
        data.put("total_tokens", JsonInt(totalTokens))
        pushEvent(agentId, data)
        broadcastToSessions(data)
    }

    public func pushTuningApplied(agentId: String, strategyType: String): Unit {
        let data = buildEventJson("tuning_applied", agentId)
        data.put("strategy_type", JsonString(strategyType))
        pushEvent(agentId, data)
        broadcastToSessions(data)
    }

    private func broadcastToSessions(eventJson: JsonObject): Unit {
        try {
            let sessionManager = WebSocketSessionManager.instance
            let sessionIds = sessionManager.getAllSessionIds()
            for (sessionId in sessionIds) {
                match (sessionManager.getSession(sessionId)) {
                    case Some(session) =>
                        let message = WebSocketMessage("agent_loop_event", eventJson, (DateTime.now() - DateTime.UnixEpoch).toMilliseconds())
                        session.sendMessage(message)
                    case None => ()
                }
            }
        } catch (e: Exception) {
            LogUtils.debug("WebSocketEventBridge", "广播事件到WebSocket会话失败: ${e.message}")
        }
    }
}