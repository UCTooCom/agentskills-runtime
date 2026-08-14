package magic.app.controllers.uctoo.ws

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.core.skill.SkillManager
import magic.core.model.ChatModel
import magic.skill.SkillAwareAgent
import magic.agent_executor.react.ReactExecutor
import magic.core.agent.{AgentRequest, AgentResponse}
import magic.agent.memory.tiered.TieredMemory
import magic.interaction.EventHandlerManager
import magic.app.services.bridge.AgentRuntimeBridge
import magic.app.models.uctoo.AgentMessagesPO
import magic.app.services.uctoo.AgentMessagesService
import magic.tool.{TokenManager, SessionContext}
import f_util.UUID
import http_lib.server.{WebSocketConn, ConnectionController, WebSocketOpcode, WebSocketMessage as LibWsMessage}
import http_lib.message.{HttpRequest as LibHttpRequest, HttpResponse as LibHttpResponse}
import http_lib.core.HttpStatus
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonArray}
import std.time.DateTime
import std.sync.Mutex
import std.collection.{HashMap, ArrayList}
import magic.log.LogUtils
import magic.jsonable.JsonUtils
import magic.app.services.bridge.WebSocketSessionManager
import magic.app.services.ws_support.{WebSocketSession, WebSocketMessage}
import magic.core.agent.{AgentDefinition, AgentLoadManager}
import magic.app.services.uctoo.AgentsService
import magic.model.ModelManager
// v17: prompt_config.cj 已废弃删除，系统提示词由 AGENTS.md 统一管理

// Helper function
func _getJsonString(jsonObj: JsonObject, key: String, defaultValue: String): String {
    return JsonUtils.getString(jsonObj, key) ?? defaultValue
}


public class WsChatController {
    private let _skillManager: SkillManager
    private let _chatModel: ChatModel
    private let _agent: SkillAwareAgent
    private var _agentId: String = ""
    private let _agentLoadManager: AgentLoadManager
    private let _sessions: HashMap<String, WebSocketSession>
    private let _sessionsMutex: Mutex
    private var _sessionCounter: Int64 = 0
    // 存储前端注册的工具（会话级别的）
    private var _frontendTools: ArrayList<JsonObject> = ArrayList<JsonObject>()

    public init(skillManager: SkillManager, chatModel: ChatModel, agentLoadManager: AgentLoadManager) {
        _skillManager = skillManager
        _chatModel = chatModel
        _agentLoadManager = agentLoadManager
        _sessions = HashMap<String, WebSocketSession>()
        _sessionsMutex = Mutex()
        _sessionCounter = 0

        let executor = ReactExecutor()

        // v17: 从 AGENTS.md 动态加载主 Agent 定义（与 WebMCPProtocol.cj 一致的加载机制）
        let mainAgentDef = agentLoadManager.getMainAgent()
        if (let Some(def) <- mainAgentDef) {
            let systemPrompt = def.systemPrompt
            let agentName = def.name
            let modelName = if (let Some(m) <- def.model) { m } else { "deepseek" }
            let agentModel = if (modelName.contains(":")) {
                ModelManager.createChatModel(modelName)
            } else {
                chatModel
            }

            // 查数据库是否已存在同名 agent，复用 UUID
            let agentsService = AgentsService()
            let (agentList, _) = agentsService.getListWithFilter(1, 1, "", "{\"name\":{\"equals\":\"${def.name}\"}}")
            if (agentList.size > 0) {
                _agentId = agentList[0].id
                LogUtils.info("WsChatController: resolved agent UUID=${_agentId} for ${def.name} from agents table (systemPrompt from AGENTS.md, length=${systemPrompt.size.toString()})")
            } else {
                // 数据库不存在，通过 AgentRuntimeBridge 创建并持久化
                let bridge = AgentRuntimeBridge.instance
                let createResult = bridge.createRuntimeAgent(def)
                if (createResult.success) {
                    let runtimeIds = bridge.getAllRuntimeAgentIds()
                    for (id in runtimeIds) {
                        if (let Some(agent) <- bridge.getRuntimeAgent(id)) {
                            if (agent.name == def.name) {
                                _agentId = id
                                break
                            }
                        }
                    }
                }
                LogUtils.info("WsChatController: agent ${def.name} not found in DB, created via AgentRuntimeBridge, UUID=${_agentId}")
            }

            let memory = TieredMemory(agentId: _agentId)
            _agent = SkillAwareAgent(
                skillManager: skillManager,
                model: agentModel,
                executor: executor,
                name: agentName,
                description: def.description,
                systemPrompt: systemPrompt,
                memory: Some(memory),
                eventHandlerManager: Some(EventHandlerManager.global)
            )
            LogUtils.info("WsChatController: created agent from AGENTS.md: name=${agentName}, UUID=${_agentId}, systemPrompt length=${systemPrompt.size.toString()}")
        } else {
            // 降级：AGENTS.md 未找到主 Agent 定义，使用硬编码默认值
            LogUtils.warn("WsChatController: no main agent found in AGENTS.md, using fallback hardcoded agent")
            _agentId = "ws-skill-assistant"
            let memory = TieredMemory(agentId: _agentId)
            _agent = SkillAwareAgent(
                skillManager: skillManager,
                model: chatModel,
                executor: executor,
                name: "Skill Assistant",
                description: "An intelligent assistant that can use skills to help users",
                memory: Some(memory),
                eventHandlerManager: Some(EventHandlerManager.global)
            )
        }
    }

    /**
     * 处理 WebSocket 聊天连接（使用 HttpRequest 和 HttpResponse）
     * WS /api/v1/uctoo/ws/chat
     */
    public func handleChat(req: HttpRequest, res: HttpResponse): Unit {
        res.status(200).json("{\"message\":\"WebSocket endpoint - use /ws/chat for WebSocket connection\"}")
    }
    
    /**
     * 处理 WebSocket 聊天连接（使用 http_lib HttpRequest）
     * WS /api/v1/uctoo/ws/chat
     */
    public func handleChat(req: LibHttpRequest): LibHttpResponse {
        match (req.connection) {
            case Some(conn) =>
                let controller = ConnectionController(conn)
                try {
                    controller.upgradeToWebSocket(req)
                } catch (ex: Exception) {
                    return LibHttpResponse.text(HttpStatus.BAD_REQUEST, "WebSocket upgrade failed: ${ex.message}")
                }

                let wsConn = WebSocketConn(conn)
                handleWebSocketSession(wsConn)
                return LibHttpResponse.empty(HttpStatus.OK)
            case None =>
                return LibHttpResponse.text(HttpStatus.INTERNAL_SERVER_ERROR, "Connection hijack not supported")
        }
    }

    /**
     * 处理 WebSocket 会话
     */
    private func handleWebSocketSession(wsConn: WebSocketConn): Unit {
        let sessionId = _generateSessionId()
        let session = WebSocketSession(sessionId, wsConn)

        _sessionsMutex.lock()
        _sessions.add(sessionId, session)
        _sessionsMutex.unlock()

        WebSocketSessionManager.instance.registerSession(session)

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

        WebSocketSessionManager.instance.unregisterSession(sessionId)

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
        var msgOpt = session.websocket.readMessage()
        while (true) {
            match (msgOpt) {
                case Some(msg) =>
                    if (msg.isText()) {
                        _handleTextMessage(session, msg.text())
                    } else if (msg.isBinary()) {
                        _handleBinaryMessage(session, msg.data)
                    } else if (msg.isClose()) {
                        break
                    } else if (msg.isPing()) {
                        session.websocket.writePong(msg.data)
                    }
                case None =>
                    break
            }
            msgOpt = session.websocket.readMessage()
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
                case "cancel" => _handleCancelMessage(session, jsonObj)
                case "execute_skill" => _handleSkillExecution(session, jsonObj)
                case "list_skills" => _handleListSkills(session)
                case "ping" => _handlePing(session)
                case "register_tools" => _handleRegisterTools(session, jsonObj)
                case "approval_response" => _handleApprovalResponse(session, jsonObj)
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

        if (WebSocketSessionManager.instance.isCancelled(session.sessionId)) {
            WebSocketSessionManager.instance.clearCancelFlag(session.sessionId)
            _sendErrorMessage(session, "Request cancelled before execution")
            return
        }

        LogUtils.info("Processing chat message: ${content}")

        let sessionContext = SessionContext.getInstance()
        sessionContext.setCurrentSession(session.sessionId)

        _sendStatusMessage(session, "thinking", "Processing your request...")

        // 持久化用户消息到 agent_messages
        spawn {
            try {
                let messagesService = AgentMessagesService()
                let msg = AgentMessagesPO()
                msg.fromAgentId = None<String>
                msg.messageType = "user"
                msg.content = Some("\"${content.replace("\\", "\\\\").replace("\"", "\\\"").replace("\r", "\\r").replace("\n", "\\n")}\"")
                msg.status = Some(1)
                msg.creator = None<String>
                let createResult = messagesService.create(msg, "user")
                if (!createResult.success) {
                    LogUtils.error("WsChatController: save user message FAILED, reason: ${match (createResult.reason) { case Some(s) => s; case None => "unknown" }}")
                }
            } catch (e: Exception) {
                LogUtils.error("WsChatController: save user message error: ${e.message}")
            }
        }

        try {
            // v17: systemPrompt 已由 AGENTS.md 在构造函数中加载，此处追加后端技能知识和前端工具信息
            let backendSkillPrompt = _buildAgentSystemPrompt()
            if (_agent.systemPrompt.isEmpty()) {
                _agent.systemPrompt = backendSkillPrompt
            } else {
                _agent.systemPrompt = _agent.systemPrompt + "\n\n" + backendSkillPrompt
            }

            let agentRequest = AgentRequest(content)
            let agentResponse = _agent.chat(agentRequest)

            let responseContent = agentResponse.content

            // 异步同步 Agent 状态到数据库
            spawn {
                try {
                    AgentRuntimeBridge.instance.syncToDatabase(_agent.name, _agent)
                } catch (_: Exception) {}
            }

            let responsePayload = JsonObject()
            responsePayload.put("content", JsonString(responseContent))
            responsePayload.put("role", JsonString("assistant"))
            // 传递思维链（reasoning_content）到前端
            // v10 根治：前端 _chatViaWebMCP 提取的字段名是 reasoning_content（非 reasoning），字段名不匹配导致思维链不显示
            // 同时转发 reasoning 和 reasoning_content 两个字段，兼容前端已有的提取逻辑
            try {
                let answerMsg = agentResponse.execution.chatRound.answer
                if (let Some(r) <- answerMsg.reason) {
                    if (!r.isEmpty()) {
                        responsePayload.put("reasoning", JsonString(r))
                        responsePayload.put("reasoning_content", JsonString(r))
                    }
                }
            } catch (_: Exception) {}

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
        // v17: 基础提示词已由 AGENTS.md 的 systemPrompt 提供（构造函数中动态加载），
        // 此处只构建后端技能知识和前端工具信息，在调用时追加到 agent.systemPrompt

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
            // 第1段：仅注入 frontmatter（name + description），不注入正文 instructions
            // 遵循 agentskills 开放标准的三段渐进式加载
            skillInfoBuilder.append("【已安装的技能知识库】\n以下技能可用，如需使用请先调用 get_skill_content 工具获取完整说明（SOP 步骤、脚本接口等）。\n\n")
            for (skill in skills) {
                skillInfoBuilder.append("- ${skill.name}: ${skill.description}\n")
                // 仅 frontmatter，不注入 instructions 正文
            }
            skillInfoBuilder.append("\n")

            // v17: skillGuideSection 已迁至 AGENTS.md，此处不再注入
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

    private func _handleCancelMessage(session: WebSocketSession, jsonObj: JsonObject): Unit {
        LogUtils.info("Received cancel request from session: ${session.sessionId}")
        
        WebSocketSessionManager.instance.cancelAgent(session.sessionId)
        
        let payload = JsonObject()
        payload.put("status", JsonString("cancelled"))
        payload.put("timestamp", JsonInt((DateTime.now() - DateTime.UnixEpoch).toMilliseconds()))
        
        let message = WebSocketMessage("cancel_response", payload, (DateTime.now() - DateTime.UnixEpoch).toMilliseconds())
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

    private func _handleApprovalResponse(session: WebSocketSession, jsonObj: JsonObject): Unit {
        let approvalId = _getJsonString(jsonObj, "approval_id", "")
        let response = _getJsonString(jsonObj, "response", "")

        if (approvalId.isEmpty()) {
            _sendErrorMessage(session, "Missing 'approval_id' field in approval_response")
            return
        }

        if (response.isEmpty()) {
            _sendErrorMessage(session, "Missing 'response' field in approval_response")
            return
        }

        WebSocketSessionManager.instance.resolveApproval(approvalId, response)
        LogUtils.info("Approval response received: approvalId=${approvalId} from session: ${session.sessionId}")
    }

    private func _sendErrorMessage(session: WebSocketSession, errorMessage: String): Unit {
        let payload = JsonObject()
        payload.put("error", JsonString(errorMessage))
        payload.put("timestamp", JsonInt((DateTime.now() - DateTime.UnixEpoch).toMilliseconds()))

        let message = WebSocketMessage("error", payload, (DateTime.now() - DateTime.UnixEpoch).toMilliseconds())
        session.sendMessage(message)
    }
}
