/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.api

import std.collection.{HashMap, ArrayList}
import std.convert.*
import stdx.net.http.{HttpContext, HttpRequest, WebSocket, WebSocketFrameType, HttpHeaders}
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonArray}
import std.time.DateTime
import std.sync.Mutex
import magic.log.LogUtils
import magic.core.skill.SkillManager
import magic.model.ModelManager
import magic.core.model.{ChatModel, ChatRequest, ChatResponse}
import magic.core.message.{Message, MessageList}
import magic.core.agent.{AgentRequest, AgentResponse}
import magic.agent_executor.react.ReactExecutor
import magic.skill.{SkillAwareAgent, SkillToToolAdapter}
import magic.jsonable.JsonUtils

func _getJsonString(jsonObj: JsonObject, key: String, defaultValue: String): String {
    return JsonUtils.getString(jsonObj, key) ?? defaultValue
}

public class WebSocketMessage {
    public let messageType: String
    public let payload: JsonObject
    public let timestamp: Int64
    
    public init(messageType: String, payload: JsonObject, timestamp: Int64) {
        this.messageType = messageType
        this.payload = payload
        this.timestamp = timestamp
    }
    
    public func toJsonString(): String {
        let jo = JsonObject()
        jo.put("type", JsonString(messageType))
        jo.put("payload", payload)
        jo.put("timestamp", JsonInt(timestamp))
        return jo.toJsonString()
    }
}

public class WebSocketSession {
    public let sessionId: String
    public let websocket: WebSocket
    private let _connectedAt: Int64
    
    public init(sessionId: String, websocket: WebSocket) {
        this.sessionId = sessionId
        this.websocket = websocket
        this._connectedAt = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
    }
    
    public prop connectedAt: Int64 {
        get() { _connectedAt }
    }
    
    public func sendMessage(message: WebSocketMessage): Unit {
        try {
            let jsonStr = message.toJsonString()
            let bytes = jsonStr.toArray()
            websocket.write(WebSocketFrameType.TextWebFrame, bytes)
        } catch (ex: Exception) {
            LogUtils.error("Failed to send message to session ${sessionId}: ${ex.message}")
        }
    }
    
    public func close(): Unit {
        try {
            websocket.writeCloseFrame()
        } catch (ex: Exception) {
            LogUtils.error("Error closing WebSocket session ${sessionId}: ${ex.message}")
        }
    }
}

public class WebSocketChatHandler {
    private let _skillManager: SkillManager
    private let _chatModel: ChatModel
    private let _agent: SkillAwareAgent
    private let _sessions: HashMap<String, WebSocketSession>
    private let _sessionsMutex: Mutex
    private var _sessionCounter: Int64 = 0
    
    public init(skillManager: SkillManager, modelName: String) {
        _skillManager = skillManager
        _chatModel = ModelManager.createChatModel(modelName)
        _sessions = HashMap<String, WebSocketSession>()
        _sessionsMutex = Mutex()
        _sessionCounter = 0
        
        let executor = ReactExecutor()
        _agent = SkillAwareAgent(
            skillManager: skillManager,
            model: _chatModel,
            executor: executor,
            name: "Skill Assistant",
            description: "An intelligent assistant that can use skills to help users"
        )
    }
    
    public init(skillManager: SkillManager, chatModel: ChatModel) {
        _skillManager = skillManager
        _chatModel = chatModel
        _sessions = HashMap<String, WebSocketSession>()
        _sessionsMutex = Mutex()
        _sessionCounter = 0
        
        let executor = ReactExecutor()
        _agent = SkillAwareAgent(
            skillManager: skillManager,
            model: chatModel,
            executor: executor,
            name: "Skill Assistant",
            description: "An intelligent assistant that can use skills to help users"
        )
    }
    
    public func handleWebSocket(ctx: HttpContext): Unit {
        let websocket = WebSocket.upgradeFromServer(
            ctx,
            subProtocols: ArrayList<String>(["skill-chat", "agent-execution"]),
            userFunc: { request: HttpRequest =>
                let headers = HttpHeaders()
                headers.add("X-Connection-Type", "skill-chat")
                headers
            }
        )
        
        let sessionId = _generateSessionId()
        let session = WebSocketSession(sessionId, websocket)
        
        _sessionsMutex.lock()
        _sessions.add(sessionId, session)
        _sessionsMutex.unlock()
        
        LogUtils.info("WebSocket session established: ${sessionId}")
        
        _sendWelcomeMessage(session)
        
        _messageLoop(session)
        
        _sessionsMutex.lock()
        _sessions.remove(sessionId)
        _sessionsMutex.unlock()
        
        LogUtils.info("WebSocket session closed: ${sessionId}")
    }
    
    private func _generateSessionId(): String {
        _sessionCounter = _sessionCounter + 1
        let count = _sessionCounter
        let timestamp = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
        return "ws-${timestamp}-${count}"
    }
    
    private func _sendWelcomeMessage(session: WebSocketSession): Unit {
        let payload = JsonObject()
        payload.put("session_id", JsonString(session.sessionId))
        payload.put("message", JsonString("Welcome to AgentSkills Runtime WebSocket"))
        payload.put("timestamp", JsonInt((DateTime.now() - DateTime.UnixEpoch).toMilliseconds()))
        
        let message = WebSocketMessage("welcome", payload, (DateTime.now() - DateTime.UnixEpoch).toMilliseconds())
        session.sendMessage(message)
    }
    
    private func _messageLoop(session: WebSocketSession): Unit {
        var frame = session.websocket.read()
        while (true) {
            match (frame.frameType) {
                case WebSocketFrameType.TextWebFrame =>
                    let message = String.fromUtf8(frame.payload)
                    _handleTextMessage(session, message)
                case WebSocketFrameType.BinaryWebFrame =>
                    _handleBinaryMessage(session, frame.payload)
                case WebSocketFrameType.CloseWebFrame =>
                    session.websocket.write(WebSocketFrameType.CloseWebFrame, frame.payload)
                    break
                case WebSocketFrameType.PingWebFrame =>
                    session.websocket.writePongFrame(frame.payload)
                case _ => ()
            }
            frame = session.websocket.read()
        }
        session.close()
    }
    
    private func _handleTextMessage(session: WebSocketSession, message: String): Unit {
        try {
            let jsonObj = JsonValue.fromStr(message).asObject()
            let messageType = _getJsonString(jsonObj, "type", "unknown")
            
            LogUtils.info("Received message type: ${messageType} from session: ${session.sessionId}")
            
            match (messageType) {
                case "chat" => _handleChatMessage(session, jsonObj)
                case "execute_skill" => _handleSkillExecution(session, jsonObj)
                case "list_skills" => _handleListSkills(session)
                case "ping" => _handlePing(session)
                case _ => _handleUnknownMessage(session, messageType)
            }
        } catch (ex: Exception) {
            LogUtils.error("Error handling text message: ${ex.message}")
            _sendErrorMessage(session, "Failed to parse message: ${ex.message}")
        }
    }
    
    private func _handleBinaryMessage(session: WebSocketSession, payload: Array<UInt8>): Unit {
        LogUtils.info("Received binary message from session: ${session.sessionId}, size: ${payload.size}")
        _sendErrorMessage(session, "Binary messages are not supported")
    }
    
    private func _handleChatMessage(session: WebSocketSession, jsonObj: JsonObject): Unit {
        let content = _getJsonString(jsonObj, "content", "")
        
        if (content.isEmpty()) {
            _sendErrorMessage(session, "Message content is required")
            return
        }
        
        LogUtils.info("=== [Chat Processing] ===")
        LogUtils.info("Processing chat message: ${content}")
        LogUtils.info("Session ID: ${session.sessionId}")
        
        _sendStatusMessage(session, "thinking", "Processing your request...")
        
        try {
            let systemPrompt = _buildAgentSystemPrompt()
            _agent.systemPrompt = systemPrompt
            
            LogUtils.info("=== [System Prompt] ===")
            LogUtils.info(systemPrompt)
            LogUtils.info("=== [End System Prompt] ===")
            
            LogUtils.info("Agent tools: ${_agent.toolManager.tools.size.toString()} tools registered")
            for (tool in _agent.toolManager.tools) {
                LogUtils.info("  - Tool: ${tool.name} - ${tool.description}")
            }
            
            LogUtils.info("=== [Agent Request] ===")
            let agentRequest = AgentRequest(content)
            
            LogUtils.info("=== [Calling Agent.chat()] ===")
            let agentResponse = _agent.chat(agentRequest)
            LogUtils.info("=== [Agent.chat() returned] ===")
            
            LogUtils.info("Agent response status: ${agentResponse.status}")
            LogUtils.info("Agent response content length: ${agentResponse.content.size}")
            LogUtils.info("Agent response content: ${agentResponse.content}")
            
            let responseContent = agentResponse.content
            
            let responsePayload = JsonObject()
            responsePayload.put("content", JsonString(responseContent))
            responsePayload.put("role", JsonString("assistant"))
            
            let message = WebSocketMessage("chat_response", responsePayload, (DateTime.now() - DateTime.UnixEpoch).toMilliseconds())
            session.sendMessage(message)
            
            LogUtils.info("=== [Chat Processing Complete] ===")
        } catch (ex: Exception) {
            LogUtils.error("=== [Error in Chat Processing] ===")
            LogUtils.error("Error in chat processing: ${ex.message}")
            LogUtils.error("Exception stack trace (if available): ${ex}")
            LogUtils.error("=== [End Error] ===")
            _sendErrorMessage(session, "Failed to process chat: ${ex.message}")
        }
    }
    
    private func _buildAgentSystemPrompt(): String {
        let skills = _skillManager.availableSkills.values().toArray()
        let skillInfoBuilder = StringBuilder()
        skillInfoBuilder.append("你是一个智能助手，你可以访问以下已安装的技能（Skills）来帮助用户完成任务。\n\n")
        skillInfoBuilder.append("【重要说明】\n")
        skillInfoBuilder.append("1. 每个技能都是一个可用的工具，你可以根据用户的需求选择合适的技能来执行。\n")
        skillInfoBuilder.append("2. 当你需要使用某个技能时，必须通过工具调用的方式来执行该技能。\n")
        skillInfoBuilder.append("3. 技能工具的调用方式：使用 query 参数传递用户的自然语言请求。\n")
        skillInfoBuilder.append("4. 技能执行后会返回结果，请将结果清晰地展示给用户。\n\n")
        
        if (skills.isEmpty()) {
            skillInfoBuilder.append("当前没有安装任何技能。\n")
        } else {
            skillInfoBuilder.append("【已安装的技能列表】\n")
            for (skill in skills) {
                skillInfoBuilder.append("- **${skill.name}**: ${skill.description}\n")
                skillInfoBuilder.append("  - 使用方法：通过工具调用，将用户的请求作为 query 参数传递\n")
                skillInfoBuilder.append("  - 示例：如果用户说'使用 ${skill.name} 来...'，你应该调用 ${skill.name} 工具，query 参数设置为'...'\n\n")
            }
        }
        
        skillInfoBuilder.append("\n【使用指南】\n")
        skillInfoBuilder.append("- 如果用户的问题明确需要使用某个技能，请直接调用相应的技能工具\n")
        skillInfoBuilder.append("- 调用技能时，将用户的完整自然语言请求作为 query 参数传递\n")
        skillInfoBuilder.append("- 技能执行完成后，将返回的结果清晰、友好地展示给用户\n")
        skillInfoBuilder.append("- 如果技能返回了JSON格式的结果，请解析并以易读的方式展示\n")
        skillInfoBuilder.append("- 如果用户的问题不需要使用技能，请直接回答用户的问题\n")
        
        return skillInfoBuilder.toString()
    }
    
    private func _handleSkillExecution(session: WebSocketSession, jsonObj: JsonObject): Unit {
        let skillId = _getJsonString(jsonObj, "skill_id", "")
        
        if (skillId.isEmpty()) {
            _sendErrorMessage(session, "skill_id is required")
            return
        }
        
        let parameters = if (jsonObj.containsKey("parameters")) {
            jsonObj["parameters"].asObject()
        } else {
            JsonObject()
        }
        
        let timeoutStr = _getJsonString(jsonObj, "timeout", "60s")
        let timeoutMs = _parseTimeoutString(timeoutStr)
        
        LogUtils.info("Executing skill: ${skillId} with timeout: ${timeoutMs}ms")
        
        _sendStatusMessage(session, "skill_started", "Starting skill execution: ${skillId}")
        
        try {
            let skillOpt = _skillManager.getSkill(skillId)
            if (skillOpt.isNone()) {
                _sendErrorMessage(session, "Skill not found: ${skillId}")
                return
            }
            
            let skill = skillOpt.getOrThrow()
            
            _sendStatusMessage(session, "skill_loading", "Loading skill: ${skill.name}")
            
            let args = HashMap<String, JsonValue>()
            for ((key, value) in parameters.getFields()) {
                args.add(key, value)
            }
            
            _sendStatusMessage(session, "skill_executing", "Executing skill...")
            
            let startTime = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
            
            let result = skill.execute(args)
            
            let endTime = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
            
            let resultPayload = JsonObject()
            resultPayload.put("skill_id", JsonString(skillId))
            resultPayload.put("success", JsonString("true"))
            resultPayload.put("output", JsonString(result))
            resultPayload.put("execution_time", JsonString("${endTime - startTime}ms"))
            
            let message = WebSocketMessage("skill_result", resultPayload, endTime)
            session.sendMessage(message)
            
            LogUtils.info("Skill ${skillId} execution completed in ${endTime - startTime}ms")
        } catch (ex: Exception) {
            LogUtils.error("Error executing skill: ${ex.message}")
            _sendErrorMessage(session, "Skill execution failed: ${ex.message}")
        }
    }
    
    private func _handleListSkills(session: WebSocketSession): Unit {
        let skills = _skillManager.availableSkills.values().toArray()
        
        let skillsArray = JsonArray()
        for (skill in skills) {
            let skillObj = JsonObject()
            skillObj.put("id", JsonString(skill.name))
            skillObj.put("name", JsonString(skill.name))
            skillObj.put("description", JsonString(skill.description))
            
            let version = if (skill.metadata.get("version").isSome()) {
                skill.metadata.get("version").getOrThrow()
            } else {
                "1.0.0"
            }
            skillObj.put("version", JsonString(version))
            
            skillsArray.add(skillObj)
        }
        
        let payload = JsonObject()
        payload.put("skills", skillsArray)
        payload.put("count", JsonInt(Int64(skills.size)))
        
        let message = WebSocketMessage("skills_list", payload, (DateTime.now() - DateTime.UnixEpoch).toMilliseconds())
        session.sendMessage(message)
    }
    
    private func _handlePing(session: WebSocketSession): Unit {
        let payload = JsonObject()
        payload.put("timestamp", JsonInt((DateTime.now() - DateTime.UnixEpoch).toMilliseconds()))
        
        let message = WebSocketMessage("pong", payload, (DateTime.now() - DateTime.UnixEpoch).toMilliseconds())
        session.sendMessage(message)
    }
    
    private func _handleUnknownMessage(session: WebSocketSession, messageType: String): Unit {
        _sendErrorMessage(session, "Unknown message type: ${messageType}")
    }
    
    private func _sendStatusMessage(session: WebSocketSession, status: String, description: String): Unit {
        let payload = JsonObject()
        payload.put("status", JsonString(status))
        payload.put("description", JsonString(description))
        payload.put("timestamp", JsonInt((DateTime.now() - DateTime.UnixEpoch).toMilliseconds()))
        
        let message = WebSocketMessage("status", payload, (DateTime.now() - DateTime.UnixEpoch).toMilliseconds())
        session.sendMessage(message)
    }
    
    private func _sendErrorMessage(session: WebSocketSession, errorMessage: String): Unit {
        let payload = JsonObject()
        payload.put("error", JsonString(errorMessage))
        payload.put("timestamp", JsonInt((DateTime.now() - DateTime.UnixEpoch).toMilliseconds()))
        
        let message = WebSocketMessage("error", payload, (DateTime.now() - DateTime.UnixEpoch).toMilliseconds())
        session.sendMessage(message)
    }
    
    private func _parseTimeoutString(timeout: String): Int64 {
        if (timeout.endsWith("ms")) {
            let runes = timeout.toRuneArray()
            let numStr = String(runes[..runes.size - 2])
            return Int64.parse(numStr)
        } else if (timeout.endsWith("s")) {
            let runes = timeout.toRuneArray()
            let numStr = String(runes[..runes.size - 1])
            return Int64.parse(numStr) * 1000
        } else if (timeout.endsWith("m")) {
            let runes = timeout.toRuneArray()
            let numStr = String(runes[..runes.size - 1])
            return Int64.parse(numStr) * 60 * 1000
        } else {
            return Int64.parse(timeout) * 1000
        }
    }
}
