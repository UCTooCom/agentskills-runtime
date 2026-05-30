/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.webmcp

import magic.log.LogUtils
import magic.core.skill.{Skill, SkillManager}
import magic.core.model.{ChatModel, ChatRequest}
import magic.core.message.{Message, MessageRole}
import magic.skill.SkillAwareAgent
import magic.agent_executor.react.ReactExecutor
import magic.core.agent.{AgentRequest, AgentResponse}
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonFloat, JsonBool, JsonNull}
import std.collection.{HashMap, ArrayList}

/**
 * WebMCP 协议处理器
 * 实现 Model Context Protocol 核心协议处理逻辑
 * 参考: https://docs.opentiny.design/next-sdk/guide/mcp-host.html
 */
public class WebMCPProtocol {
    private var _skillManager: ?SkillManager
    private var _chatModel: ?ChatModel
    private var _agent: ?SkillAwareAgent
    private var _sessionId: String = ""
    private var _clientId: String = ""

    /**
     * 构造函数，接受可空类型的 SkillManager 和 ChatModel
     */
    public init(skillManager: ?SkillManager, chatModel: ?ChatModel) {
        this._skillManager = skillManager
        this._chatModel = chatModel
        
        // 初始化 SkillAwareAgent
        if (skillManager.isSome() && chatModel.isSome()) {
            let executor = ReactExecutor()
            this._agent = Some(SkillAwareAgent(
                skillManager: skillManager.getOrThrow(),
                model: chatModel.getOrThrow(),
                executor: executor,
                name: "WebMCP Skill Assistant",
                description: "An intelligent assistant that can use skills to help users through WebMCP protocol"
            ))
        } else {
            this._agent = None
        }
    }

    public func setSessionInfo(sessionId: String, clientId: String): Unit {
        this._sessionId = sessionId
        this._clientId = clientId
    }

    /**
     * 处理客户端发送的消息
     */
    public func handleMessage(message: String): String {
        LogUtils.debug("WebMCP received message: ${message}")
        
        let jsonValue = JsonValue.fromStr(message)
        
        if (jsonValue is JsonObject) {
            return handleRequest(jsonValue.asObject())
        } else {
            LogUtils.error("Invalid JSON message format")
            return createErrorResponse("Invalid JSON message format")
        }
    }

    private func handleRequest(obj: JsonObject): String {
        let method = obj.get("method")
        
        if (method.isNone()) {
            return createErrorResponse("Missing or invalid 'method' field")
        }
        
        let methodValue = method.getOrThrow()
        
        if (!(methodValue is JsonString)) {
            return createErrorResponse("Invalid 'method' field type")
        }
        
        let methodStr = methodValue.asString().getValue()
        return handleMethod(methodStr, obj)
    }

    private func handleMethod(method: String, obj: JsonObject): String {
        LogUtils.debug("WebMCP handling method: ${method}")
        
        if (method == "initialize") {
            return handleInitialize(obj)
        } else if (method == "getTools" || method == "listTools" || method == "tools/list") {
            // 支持 MCP 协议标准方法名 listTools、tools/list 和向后兼容的 getTools
            return handleGetTools(obj)
        } else if (method == "invokeTool" || method == "tools/invoke" || method == "tools/call") {
            // 支持 MCP 协议标准方法名 tools/call 和向后兼容的 invokeTool、tools/invoke
            return handleInvokeTool(obj)
        } else if (method == "sendMessage") {
            return handleSendMessage(obj)
        } else if (method == "listSessions") {
            return handleListSessions(obj)
        } else if (method == "closeSession") {
            return handleCloseSession(obj)
        } else if (method == "completion/complete") {
            return handleCompletionComplete(obj)
        } else {
            return createErrorResponse("Unknown method: ${method}")
        }
    }

    /**
     * 处理初始化请求
     */
    private func handleInitialize(obj: JsonObject): String {
        let requestId = obj.get("id")
        
        var clientId = ""
        
        // 尝试从顶层获取 clientId
        let cidOpt = obj.get("clientId")
        if (cidOpt.isSome()) {
            let cidJson = cidOpt.getOrThrow()
            if (cidJson is JsonString) {
                clientId = cidJson.asString().getValue()
            }
        }
        
        // 如果顶层没有，从 params 中获取
        if (clientId.isEmpty()) {
            let params = obj.get("params")
            if (params.isSome()) {
                let paramsVal = params.getOrThrow()
                if (paramsVal is JsonObject) {
                    let p = paramsVal.asObject()
                    let cidOpt2 = p.get("clientId")
                    if (cidOpt2.isSome()) {
                        let cidJson = cidOpt2.getOrThrow()
                        if (cidJson is JsonString) {
                            clientId = cidJson.asString().getValue()
                        }
                    }
                }
            }
        }
        
        this._clientId = clientId
        
        LogUtils.info("WebMCP session initialized for client: ${clientId}")
        
        // 构建 tools 能力对象（符合 MCP 协议标准格式）
        let toolsCapabilities = JsonObject()
        toolsCapabilities.put("list", JsonBool(true))
        toolsCapabilities.put("invoke", JsonBool(true))
        
        // 构建 capabilities 对象
        let capabilities = JsonObject()
        capabilities.put("tools", toolsCapabilities)
        capabilities.put("streaming", JsonBool(true))
        capabilities.put("sessionPersistence", JsonBool(true))
        
        // 构建 serverInfo 对象
        let serverInfo = JsonObject()
        serverInfo.put("name", JsonString("WebMCP Server"))
        serverInfo.put("version", JsonString("1.0.0"))
        
        // 构建结果对象（符合 MCP 协议标准）
        let result = JsonObject()
        result.put("sessionId", JsonString(_sessionId))
        result.put("protocolVersion", JsonString("2025-11-25"))
        result.put("capabilities", capabilities)
        result.put("serverInfo", serverInfo)
        
        // 使用 JSON-RPC 格式包装结果（符合 WebMCP SDK 期望）
        return createSuccessResponse(result, requestId)
    }
    
    /**
     * 获取所有工具（供外部调用）
     */
    public func getTools(): JsonArray {
        let toolArray = JsonArray()
        
        // 添加后端技能作为工具
        if (let Some(sm) <- _skillManager) {
            let skills = sm.availableSkills
            for (key in skills.keys()) {
                if (let Some(skill) <- skills.get(key)) {
                    if (sm.isSkillEnabled(key)) {
                        toolArray.add(skillToJson(skill))
                    }
                }
            }
        }
        
        return toolArray
    }
    
    /**
     * 处理获取工具列表请求
     */
    private func handleGetTools(obj: JsonObject): String {
        let requestId = obj.get("id")
        
        let toolArray = JsonArray()
        
        // 添加后端技能作为工具
        if (let Some(sm) <- _skillManager) {
            let skills = sm.availableSkills
            let keys = skills.keys()
            for (key in keys) {
                if (let Some(skill) <- skills.get(key)) {
                    // 只返回启用的技能
                    if (sm.isSkillEnabled(key)) {
                        toolArray.add(skillToJson(skill))
                    }
                }
            }
        }
        
        let result = JsonObject()
        result.put("tools", toolArray)
        
        return createSuccessResponse(result, requestId)
    }

    /**
     * 处理工具调用请求
     * 仅调用后端技能
     */
    private func handleInvokeTool(obj: JsonObject): String {
        let requestId = obj.get("id")
        let params = obj.get("params")
        
        if (params.isNone()) {
            return createErrorResponse("Missing 'params' field", requestId)
        }
        
        let paramsVal = params.getOrThrow()
        if (!(paramsVal is JsonObject)) {
            return createErrorResponse("Invalid 'params' field type", requestId)
        }
        
        let paramsObj = paramsVal.asObject()
        let toolName = paramsObj.get("toolName")
        
        if (toolName.isNone()) {
            return createErrorResponse("Missing 'toolName' field", requestId)
        }
        
        let toolNameVal = toolName.getOrThrow()
        if (!(toolNameVal is JsonString)) {
            return createErrorResponse("Invalid 'toolName' field type", requestId)
        }
        
        let toolNameStr = toolNameVal.asString().getValue()
        
        // 查找后端技能
        if (let Some(sm) <- _skillManager) {
            let skillOpt = sm.getSkill(toolNameStr)
            
            if (skillOpt.isNone()) {
                return createErrorResponse("Tool not found: ${toolNameStr}", requestId)
            }
            
            // 检查技能是否启用
            if (!sm.isSkillEnabled(toolNameStr)) {
                return createErrorResponse("Tool is not enabled: ${toolNameStr}", requestId)
            }
            
            // 准备参数
            let argsMap = HashMap<String, JsonValue>()
            let args = paramsObj.get("args")
            if (args.isSome()) {
                let argsVal = args.getOrThrow()
                if (argsVal is JsonObject) {
                    let argsObj = argsVal.asObject()
                    for ((key, value) in argsObj.getFields()) {
                        argsMap.add(key, value)
                    }
                }
            }
            
            LogUtils.info("WebMCP invoking skill: ${toolNameStr} with args: ${argsMap}")
            
            // 调用后端技能
            let result = try {
                let skill = skillOpt.getOrThrow()
                let skillResult = skill.execute(argsMap)
                LogUtils.debug("Skill call result: ${skillResult}")
                
                // 返回符合 MCP 协议标准格式的响应
                let content = JsonArray()
                let textBlock = JsonObject()
                textBlock.put("type", JsonString("text"))
                textBlock.put("text", JsonString(skillResult))
                content.add(textBlock)
                
                let resultObj = JsonObject()
                resultObj.put("content", content)
                resultObj.put("isError", JsonBool(false))
                resultObj
            } catch (e: Exception) {
                LogUtils.error("Skill call error: ${e.message}")
                
                // 返回符合 MCP 协议标准格式的错误响应
                let content = JsonArray()
                let textBlock = JsonObject()
                textBlock.put("type", JsonString("text"))
                textBlock.put("text", JsonString(e.message))
                content.add(textBlock)
                
                let resultObj = JsonObject()
                resultObj.put("content", content)
                resultObj.put("isError", JsonBool(true))
                resultObj
            }
            
            return createSuccessResponse(result, requestId)
        }
        
        // 如果没有 skillManager，返回工具未找到错误
        return createErrorResponse("Tool not found: ${toolNameStr}", requestId)
    }

    /**
     * 处理发送消息请求（流式响应）
     */
    private func handleSendMessage(obj: JsonObject): String {
        let requestId = obj.get("id")
        let params = obj.get("params")
        
        if (params.isNone()) {
            return createErrorResponse("Missing 'params' field", requestId)
        }
        
        let paramsVal = params.getOrThrow()
        if (!(paramsVal is JsonObject)) {
            return createErrorResponse("Invalid 'params' field type", requestId)
        }
        
        let paramsObj = paramsVal.asObject()
        let message = paramsObj.get("message")
        
        if (message.isNone()) {
            return createErrorResponse("Missing 'message' field", requestId)
        }
        
        let messageVal = message.getOrThrow()
        if (!(messageVal is JsonString)) {
            return createErrorResponse("Invalid 'message' field type", requestId)
        }
        
        let messageStr = messageVal.asString().getValue()
        
        LogUtils.info("WebMCP sending message: ${messageStr}")
        
        // 检查是否需要流式响应
        let stream = paramsObj.get("stream")
        var isStream = true
        
        if (stream.isSome()) {
            let streamVal = stream.getOrThrow()
            if (streamVal is JsonBool) {
                isStream = streamVal.asBool().getValue()
            }
        }
        
        if (isStream) {
            // 流式响应 - 返回初始响应，后续通过事件发送
            let result = JsonObject()
            result.put("messageId", JsonString("msg_${requestId}"))
            result.put("streaming", JsonBool(true))
            result.put("status", JsonString("started"))
            return createSuccessResponse(result, requestId)
        } else {
            // 非流式响应 - WebMCP 协议不直接调用大模型，由前端 SDK 处理
            let result = JsonObject()
            result.put("messageId", JsonString("msg_${requestId}"))
            result.put("streaming", JsonBool(false))
            result.put("response", JsonString("WebMCP protocol does not support direct model calls"))
            return createSuccessResponse(result, requestId)
        }
    }

    /**
     * 处理列出会话请求
     */
    private func handleListSessions(obj: JsonObject): String {
        let requestId = obj.get("id")
        
        let sessionObj = JsonObject()
        sessionObj.put("sessionId", JsonString(_sessionId))
        sessionObj.put("clientId", JsonString(_clientId))
        sessionObj.put("status", JsonString("active"))
        
        let sessions = JsonArray()
        sessions.add(sessionObj)
        
        let result = JsonObject()
        result.put("sessions", sessions)
        
        return createSuccessResponse(result, requestId)
    }

    /**
     * 处理关闭会话请求
     */
    private func handleCloseSession(obj: JsonObject): String {
        let requestId = obj.get("id")
        
        LogUtils.info("WebMCP session closed: ${_sessionId}")
        
        let result = JsonObject()
        result.put("success", JsonBool(true))
        result.put("message", JsonString("Session closed successfully"))
        
        return createSuccessResponse(result, requestId)
    }

    /**
     * 处理 completion/complete 请求
     * MCP 协议标准方法，用于完成对话并返回最终响应
     */
    private func handleCompletionComplete(obj: JsonObject): String {
        let requestId = obj.get("id")
        
        LogUtils.info("WebMCP handling completion/complete request")
        
        // 获取请求参数
        let params = obj.get("params")
        var userMessage = ""
        
        if (params.isSome()) {
            let paramsVal = params.getOrThrow()
            if (paramsVal is JsonObject) {
                let paramsObj = paramsVal.asObject()
                let messagesJson = paramsObj.get("messages")
                if (messagesJson.isSome()) {
                    let msgs = messagesJson.getOrThrow()
                    if (msgs is JsonArray) {
                        let msgsArray = msgs.asArray()
                        let size = msgsArray.size()
                        var i = 0
                        while (i < size) {
                            let msg = msgsArray.get(i)
                            if (msg.isSome()) {
                                let msgVal = msg.getOrThrow()
                                if (msgVal is JsonObject) {
                                    let msgObj = msgVal.asObject()
                                    let role = msgObj.get("role")
                                    let content = msgObj.get("content")
                                    
                                    if (role.isSome() && content.isSome()) {
                                        let roleStr = role.getOrThrow().toString().replace("\"", "")
                                        if (roleStr == "user") {
                                            let contentVal = content.getOrThrow()
                                            if (contentVal is JsonString) {
                                                userMessage = contentVal.asString().getValue()
                                            } else {
                                                userMessage = contentVal.toString().replace("\"", "")
                                            }
                                        }
                                    }
                                }
                            }
                            i = i + 1
                        }
                    }
                }
            }
        }
        
        LogUtils.debug("WebMCP completion/complete user message: ${userMessage}")
        
        // 调用大模型生成响应（使用 SkillAwareAgent）
        var responseContent = "WebMCP server received your message."
        
        if (!userMessage.isEmpty()) {
            try {
                // 优先使用 SkillAwareAgent（支持技能调用）
                if (let Some(agent) <- _agent) {
                    // 设置系统提示词（包含技能信息）
                    let systemPrompt = buildAgentSystemPrompt()
                    agent.systemPrompt = systemPrompt
                    
                    // 创建 Agent 请求并处理
                    let agentRequest = AgentRequest(userMessage)
                    let agentResponse = agent.chat(agentRequest)
                    responseContent = agentResponse.content
                    LogUtils.debug("WebMCP completion response (via SkillAwareAgent): ${responseContent}")
                } else if (let Some(cm) <- _chatModel) {
                    // 降级到直接调用 ChatModel（不支持技能）
                    let request = ChatRequest([Message(MessageRole.User, userMessage)], temperature: None, stop: None, tools: [])
                    let chatResponse = cm.create(request)
                    responseContent = chatResponse.message.content
                    LogUtils.debug("WebMCP completion response (direct model call): ${responseContent}")
                } else {
                    responseContent = "Error: Chat model not available"
                }
            } catch (e: Error) {
                LogUtils.error("WebMCP completion error: ${e.toString()}")
                responseContent = "Error: Failed to generate response from model"
            }
        }
        
        // 返回符合 MCP 协议标准格式的响应
        let values = JsonArray()
        values.add(JsonString(responseContent))
        
        let completion = JsonObject()
        completion.put("values", values)
        completion.put("total", JsonInt(1))
        completion.put("hasMore", JsonBool(false))
        
        let result = JsonObject()
        result.put("completion", completion)
        
        return createSuccessResponse(result, requestId)
    }

    /**
     * 构建 Agent 系统提示词（包含技能信息）
     */
    private func buildAgentSystemPrompt(): String {
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

        // 添加后端技能信息
        if (let Some(sm) <- _skillManager) {
            let skills = sm.availableSkills.values().toArray()
            if (!skills.isEmpty()) {
                skillInfoBuilder.append("【已安装的技能知识库】\n")
                for (skill in skills) {
                    skillInfoBuilder.append("### " + skill.name + "\n")
                    skillInfoBuilder.append(skill.description + "\n\n")
                }
            }
        }

        return skillInfoBuilder.toString()
    }

    /**
     * 将技能转换为 JSON 对象
     * 返回格式符合 MCP 协议标准，使用 inputSchema 字段
     */
    private func skillToJson(skill: Skill): JsonObject {
        let description = skill.description
        let name = skill.name
        
        // 构建 inputSchema（符合 MCP 协议标准）
        let properties = JsonObject()
        let metadata = skill.metadata
        let keys = metadata.keys()
        for (key in keys) {
            if (let Some(value) <- metadata.get(key)) {
                // 创建参数描述对象
                let paramObj = JsonObject()
                paramObj.put("type", JsonString("string"))
                paramObj.put("description", JsonString(value))
                properties.put(key, paramObj)
            }
        }
        
        let inputSchema = JsonObject()
        inputSchema.put("type", JsonString("object"))
        inputSchema.put("properties", properties)
        inputSchema.put("additionalProperties", JsonBool(false))
        
        let toolObj = JsonObject()
        toolObj.put("name", JsonString(name))
        toolObj.put("description", JsonString(description))
        toolObj.put("inputSchema", inputSchema)
        
        // 添加额外信息
        if (skill.license.isSome()) {
            toolObj.put("license", JsonString(skill.license.getOrThrow()))
        }
        
        if (skill.compatibility.isSome()) {
            toolObj.put("compatibility", JsonString(skill.compatibility.getOrThrow()))
        }
        
        return toolObj
    }

    /**
     * 将 JSON 值转换为字符串
     */
    private func valueToString(value: JsonValue): String {
        if (value is JsonString) {
            return value.asString().getValue()
        } else if (value is JsonInt) {
            return value.asInt().getValue().toString()
        } else if (value is JsonFloat) {
            return value.asFloat().getValue().toString()
        } else if (value is JsonBool) {
            return value.asBool().getValue().toString()
        } else if (value is JsonNull) {
            return "null"
        } else {
            return value.toString()
        }
    }

    /**
     * 创建成功响应
     */
    private func createSuccessResponse(result: JsonObject, requestIdOpt: Option<JsonValue>): String {
        let response = JsonObject()
        response.put("jsonrpc", JsonString("2.0"))
        response.put("result", result)
        
        if (requestIdOpt.isSome()) {
            response.put("id", requestIdOpt.getOrThrow())
        }
        
        return response.toString()
    }

    /**
     * 创建错误响应
     */
    private func createErrorResponse(message: String, requestIdOpt: Option<JsonValue>): String {
        let error = JsonObject()
        error.put("code", JsonInt(-32603))
        error.put("message", JsonString(message))
        
        let response = JsonObject()
        response.put("jsonrpc", JsonString("2.0"))
        response.put("error", error)
        
        if (requestIdOpt.isSome()) {
            response.put("id", requestIdOpt.getOrThrow())
        }
        
        LogUtils.error("WebMCP error response: ${message}")
        return response.toString()
    }
    
    private func createErrorResponse(message: String): String {
        return createErrorResponse(message, None)
    }
}
