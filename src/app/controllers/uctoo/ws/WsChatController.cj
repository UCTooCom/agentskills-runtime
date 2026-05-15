package magic.app.controllers.uctoo.ws

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.core.skill.SkillManager
import magic.core.model.ChatModel
import magic.skill.SkillAwareAgent
import magic.agent_executor.react.ReactExecutor
import magic.core.agent.{AgentRequest, AgentResponse}
import magic.tool.{TokenManager, SessionContext}
import stdx.net.http.{HttpContext, WebSocket, WebSocketFrameType, HttpHeaders}
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonArray}
import std.time.DateTime
import std.sync.Mutex
import std.collection.{HashMap, ArrayList}
import magic.log.LogUtils
import magic.jsonable.JsonUtils

// Helper function
func _getJsonString(jsonObj: JsonObject, key: String, defaultValue: String): String {
    return JsonUtils.getString(jsonObj, key) ?? defaultValue
}

// WebSocket Message
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

// WebSocket Session
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

public class WsChatController {
    private let _skillManager: SkillManager
    private let _chatModel: ChatModel
    private let _agent: SkillAwareAgent
    private let _sessions: HashMap<String, WebSocketSession>
    private let _sessionsMutex: Mutex
    private var _sessionCounter: Int64 = 0
    // 存储前端注册的工具（会话级别的）
    private var _frontendTools: ArrayList<JsonObject> = ArrayList<JsonObject>()

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

    /**
     * 处理 WebSocket 聊天连接（使用 HttpRequest 和 HttpResponse）
     * WS /api/v1/uctoo/ws/chat
     */
    public func handleChat(req: HttpRequest, res: HttpResponse): Unit {
        res.status(200).json("{\"message\":\"WebSocket endpoint - use /ws/chat for WebSocket connection\"}")
    }
    
    /**
     * 处理 WebSocket 聊天连接（使用 HttpContext，直接处理）
     * WS /api/v1/uctoo/ws/chat
     */
    public func handleChat(ctx: HttpContext): Unit {
        handleWebSocket(ctx)
    }

    /**
     * 处理 WebSocket 连接（使用 HttpContext）
     */
    public func handleWebSocket(ctx: HttpContext): Unit {
        let websocket = WebSocket.upgradeFromServer(
            ctx,
            subProtocols: ArrayList<String>(["skill-chat", "agent-execution"]),
            userFunc: { _ =>
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

        let tokenManager = TokenManager.getInstance()
        tokenManager.removeToken(sessionId)

        let sessionContext = SessionContext.getInstance()
        sessionContext.clearCurrentSession()

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
                case "register_tools" => _handleRegisterTools(session, jsonObj)
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

        LogUtils.info("Processing chat message: ${content}")

        let sessionContext = SessionContext.getInstance()
        sessionContext.setCurrentSession(session.sessionId)

        _sendStatusMessage(session, "thinking", "Processing your request...")

        try {
            let systemPrompt = _buildAgentSystemPrompt()
            _agent.systemPrompt = systemPrompt

            let agentRequest = AgentRequest(content)
            let agentResponse = _agent.chat(agentRequest)

            let responseContent = agentResponse.content

            let responsePayload = JsonObject()
            responsePayload.put("content", JsonString(responseContent))
            responsePayload.put("role", JsonString("assistant"))

            let message = WebSocketMessage("chat_response", responsePayload, (DateTime.now() - DateTime.UnixEpoch).toMilliseconds())
            session.sendMessage(message)
        } catch (ex: Exception) {
            LogUtils.error("Error in chat processing: ${ex.message}")
            _sendErrorMessage(session, "Failed to process chat: ${ex.message}")
        }
    }

    private func _buildAgentSystemPrompt(): String {
        let skills = _skillManager.availableSkills.values().toArray()
        let skillInfoBuilder = StringBuilder()
        skillInfoBuilder.append("你是一个智能助手，可以帮助用户完成各种任务。\n\n")
        skillInfoBuilder.append("【重要说明】\n")
        skillInfoBuilder.append("1. 你可以直接使用框架内置的 http_request 工具来发送 HTTP 请求。\n")
        skillInfoBuilder.append("2. http_request 工具参数格式：\n")
        skillInfoBuilder.append("   - method: HTTP 方法（GET、POST、PUT、DELETE）\n")
        skillInfoBuilder.append("   - url: 完整的请求 URL\n")
        skillInfoBuilder.append("   - headers: JSON 字符串格式的请求头（可选）\n")
        skillInfoBuilder.append("   - body: JSON 字符串格式的请求体（可选，POST/PUT 需要）\n")
        skillInfoBuilder.append("3. 当用户需要调用后端 API 时，请直接使用 http_request 工具。\n\n")

        // 添加前端页面工具信息
        if (!_frontendTools.isEmpty()) {
            skillInfoBuilder.append("【前端页面工具】\n")
            skillInfoBuilder.append("以下工具对应前端页面的操作功能，调用时会自动跳转到对应页面执行：\n\n")
            for (toolObj in _frontendTools) {
                let nameOpt = toolObj.get("name")
                let titleOpt = toolObj.get("title")
                let descriptionOpt = toolObj.get("description")
                let routeOpt = toolObj.get("route")
                
                if (nameOpt.isSome()) {
                    let nameVal = nameOpt.getOrThrow()
                    if (nameVal is JsonString) {
                        let name = nameVal.asString().getValue()
                        var title = ""
                        if (titleOpt.isSome()) {
                            let titleVal = titleOpt.getOrThrow()
                            if (titleVal is JsonString) {
                                title = titleVal.asString().getValue()
                            }
                        }
                        let description = if (descriptionOpt.isSome()) {
                            let descVal = descriptionOpt.getOrThrow()
                            if (descVal is JsonString) {
                                descVal.asString().getValue()
                            } else {
                                ""
                            }
                        } else {
                            ""
                        }
                        let route = if (routeOpt.isSome()) {
                            let routeVal = routeOpt.getOrThrow()
                            if (routeVal is JsonString) {
                                routeVal.asString().getValue()
                            } else {
                                ""
                            }
                        } else {
                            ""
                        }

                        skillInfoBuilder.append("### ${name}")
                        if (!title.isEmpty() && title != name) {
                            skillInfoBuilder.append(" (${title})")
                        }
                        skillInfoBuilder.append("\n")
                        if (!description.isEmpty()) {
                            skillInfoBuilder.append("${description}\n")
                        }
                        if (!route.isEmpty()) {
                            skillInfoBuilder.append("对应页面: ${route}\n")
                        }
                        skillInfoBuilder.append("\n")
                    }
                }
            }
        }

        if (!skills.isEmpty()) {
            skillInfoBuilder.append("【已安装的技能知识库】\n")
            for (skill in skills) {
                skillInfoBuilder.append("### ${skill.name}\n")
                skillInfoBuilder.append("${skill.description}\n\n")
            }
        }

        return skillInfoBuilder.toString()
    }

    /**
     * 处理前端工具注册消息
     * 前端通过 WebSocket 发送工具注册消息，后端接收并存储这些工具
     */
    private func _handleRegisterTools(session: WebSocketSession, jsonObj: JsonObject): Unit {
        let payloadOpt = jsonObj.get("payload")
        
        if (payloadOpt.isNone()) {
            _sendErrorMessage(session, "Missing 'payload' field")
            return
        }
        
        let payloadVal = payloadOpt.getOrThrow()
        if (!(payloadVal is JsonObject)) {
            _sendErrorMessage(session, "Invalid 'payload' field type")
            return
        }
        
        let payload = payloadVal.asObject()
        let toolsOpt = payload.get("tools")
        
        if (toolsOpt.isNone()) {
            _sendErrorMessage(session, "Missing 'tools' field in payload")
            return
        }
        
        let toolsVal = toolsOpt.getOrThrow()
        if (!(toolsVal is JsonArray)) {
            _sendErrorMessage(session, "Invalid 'tools' field type")
            return
        }
        
        let toolsArray = toolsVal.asArray()
        
        // 清空之前注册的前端工具
        _frontendTools.clear()
        
        // 存储前端工具
        var toolCount = 0
        let size = toolsArray.size()
        var i = 0
        while (i < size) {
            let toolOpt = toolsArray.get(i)
            if (toolOpt.isSome()) {
                let toolVal = toolOpt.getOrThrow()
                if (toolVal is JsonObject) {
                    _frontendTools.add(toolVal.asObject())
                    toolCount = toolCount + 1
                }
            }
            i = i + 1
        }
        
        LogUtils.info("Registered ${toolCount} frontend tools from session: ${session.sessionId}")
        
        // 注册前端工具到 agent
        _registerFrontendToolsToAgent()
        
        // 发送成功响应
        let resultPayload = JsonObject()
        resultPayload.put("success", JsonString("true"))
        resultPayload.put("message", JsonString("Tools registered successfully"))
        resultPayload.put("count", JsonString("${toolCount}"))
        
        let message = WebSocketMessage("tools_registered", resultPayload, (DateTime.now() - DateTime.UnixEpoch).toMilliseconds())
        session.sendMessage(message)
    }
    
    /**
     * 将前端工具注册到 agent
     */
    private func _registerFrontendToolsToAgent(): Unit {
        for (toolObj in _frontendTools) {
            let nameOpt = toolObj.get("name")
            if (nameOpt.isSome()) {
                let nameVal = nameOpt.getOrThrow()
                if (nameVal is JsonString) {
                    let name = nameVal.asString().getValue()

                    var title: ?String = None
                    let titleOpt = toolObj.get("title")
                    if (titleOpt.isSome()) {
                        let titleVal = titleOpt.getOrThrow()
                        if (titleVal is JsonString) {
                            title = Some(titleVal.asString().getValue())
                        }
                    }

                    var description: ?String = None
                    let descriptionOpt = toolObj.get("description")
                    if (descriptionOpt.isSome()) {
                        let descVal = descriptionOpt.getOrThrow()
                        if (descVal is JsonString) {
                            description = Some(descVal.asString().getValue())
                        }
                    }

                    var route: ?String = None
                    let routeOpt = toolObj.get("route")
                    if (routeOpt.isSome()) {
                        let routeVal = routeOpt.getOrThrow()
                        if (routeVal is JsonString) {
                            route = Some(routeVal.asString().getValue())
                        }
                    }

                    var inputSchema: ?JsonObject = None
                    let inputSchemaOpt = toolObj.get("inputSchema")
                    if (inputSchemaOpt.isSome()) {
                        let schemaVal = inputSchemaOpt.getOrThrow()
                        if (schemaVal is JsonObject) {
                            inputSchema = Some(schemaVal.asObject())
                        }
                    }

                    // 调用 agent 的方法注册前端工具
                    _agent.addFrontendTool(name, title, description, route, inputSchema)
                }
            }
        }
    }
    
    private func _handleSkillExecution(session: WebSocketSession, jsonObj: JsonObject): Unit {
        let skillId = _getJsonString(jsonObj, "skill_id", "")

        if (skillId.isEmpty()) {
            _sendErrorMessage(session, "skill_id is required")
            return
        }

        let skillOpt = _skillManager.getSkill(skillId)
        if (skillOpt.isNone()) {
            _sendErrorMessage(session, "Skill not found: ${skillId}")
            return
        }

        let skill = skillOpt.getOrThrow()

        _sendStatusMessage(session, "skill_started", "Starting skill execution: ${skillId}")

        try {
            let args = HashMap<String, JsonValue>()
            if (jsonObj.containsKey("parameters")) {
                let paramsObj = jsonObj["parameters"].asObject()
                for ((key, value) in paramsObj.getFields()) {
                    args.add(key, value)
                }
            }

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
}
