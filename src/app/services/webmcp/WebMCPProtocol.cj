/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.webmcp

import magic.log.LogUtils
import magic.core.skill.{Skill, SkillManager}
import magic.core.model.{ChatModel, ChatRequest}
import magic.model.ModelManager
import magic.core.message.{Message, MessageRole, Conversation}
import magic.skill.SkillAwareAgent
import magic.agent_executor.react.ReactExecutor
import magic.core.agent.{AgentRequest, AgentResponse}
import magic.core.agent.AgentDefinition
import magic.agent.memory.tiered.TieredMemory
import magic.interaction.EventHandlerManager
import magic.app.services.bridge.{AgentRuntimeBridge, CheckpointManager}
import magic.app.models.uctoo.AgentsPO
import magic.app.services.uctoo.AgentsService
import magic.tool.webmcp.{SSEConnectionManager, PendingToolCallManager, FrontendToolRegistry, FrontendToolDefinition, WebMCPToolContext, WebMCPToolHelper}
import magic.core.tool.{Tool, ToolParameter}
import magic.jsonable.TypeSchema
import f_util.UUID
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
    private var _agentId: String = ""  // 存储 Agent 的真正 UUID（从数据库加载）
    private var _sessionId: String = ""
    private var _clientId: String = ""

    // WebMCP 工具链路基础设施（由 WebMCPController 注入）
    private var _sseConnectionManager: ?SSEConnectionManager = None
    private var _pendingToolCallManager: ?PendingToolCallManager = None
    private var _frontendToolRegistry: ?FrontendToolRegistry = None
    private var _menuDataProvider: ?MenuDataProvider = None
    // 当前用户 ID（由 setSessionInfo 设置，供 MenuDataProvider 查询用户菜单）
    private var _userId: String = ""

    /**
     * 构造函数，接受可空类型的 SkillManager 和 ChatModel
     */
    public init(skillManager: ?SkillManager, chatModel: ?ChatModel) {
        this._skillManager = skillManager
        this._chatModel = chatModel
        
        if (skillManager.isSome() && chatModel.isSome()) {
            let executor = ReactExecutor()
            
            // 从数据库查询 MAIN agent
            let agentsService = AgentsService()
            let (agentList, _) = agentsService.getListWithFilter(1, 1, "", "{\"agent_type\":{\"equals\":\"MAIN\"}}")
            var agentId = "webmcp-skill-assistant"
            var agentName = "WebMCP Skill Assistant"
            
            if (agentList.size > 0) {
                let dbAgent = agentList[0]
                agentId = dbAgent.id
                agentName = dbAgent.name
                LogUtils.info("WebMCPProtocol: loaded MAIN agent from DB: ${agentName}, UUID=${agentId}")
            }
            
            this._agentId = agentId
            let memory = TieredMemory(agentId: agentId)
            this._agent = Some(SkillAwareAgent(
                skillManager: skillManager.getOrThrow(),
                model: chatModel.getOrThrow(),
                executor: executor,
                name: agentName,
                description: "An intelligent assistant that can use skills to help users through WebMCP protocol",
                memory: Some(memory),
                eventHandlerManager: Some(EventHandlerManager.global)
            ))
        } else {
            this._agent = None
        }
    }

    public init(skillManager: ?SkillManager, chatModel: ?ChatModel, agentDef: ?AgentDefinition) {
        this._skillManager = skillManager
        this._chatModel = chatModel
        
        if (skillManager.isSome() && chatModel.isSome()) {
            let executor = ReactExecutor()
            if (let Some(def) <- agentDef) {
                let systemPrompt = def.systemPrompt
                let agentName = def.name
                let modelName = if (let Some(m) <- def.model) { m } else { "tokendance:mimo-v2.5" }
                let agentModel = if (modelName.contains(":")) {
                    ModelManager.createChatModel(modelName)
                } else {
                    chatModel.getOrThrow()
                }
                
                let agentsService = AgentsService()
                let (agentList, _) = agentsService.getListWithFilter(1, 1, "", "{\"name\":{\"equals\":\"${def.name}\"}}")
                if (agentList.size > 0) {
                    this._agentId = agentList[0].id
                    LogUtils.info("WebMCPProtocol: resolved agent UUID=${this._agentId} for ${def.name} from agents table (systemPrompt from AgentDefinition, length=${systemPrompt.size.toString()})")
                } else {
                    let bridge = AgentRuntimeBridge.instance
                    let createResult = bridge.createRuntimeAgent(def)
                    if (createResult.success) {
                        let runtimeIds = bridge.getAllRuntimeAgentIds()
                        for (id in runtimeIds) {
                            if (let Some(agent) <- bridge.getRuntimeAgent(id)) {
                                if (agent.name == def.name) {
                                    this._agentId = id
                                    break
                                }
                            }
                        }
                    }
                    LogUtils.info("WebMCPProtocol: agent ${def.name} not found in DB, created via AgentRuntimeBridge, UUID=${this._agentId}")
                }
                
                let memory = TieredMemory(agentId: this._agentId)
                this._agent = Some(SkillAwareAgent(
                    skillManager: skillManager.getOrThrow(),
                    model: agentModel,
                    executor: executor,
                    name: agentName,
                    description: def.description,
                    systemPrompt: systemPrompt,
                    memory: Some(memory),
                    eventHandlerManager: Some(EventHandlerManager.global)
                ))
                LogUtils.info("WebMCPProtocol: created agent: name=${agentName}, UUID=${this._agentId}, systemPrompt length=${systemPrompt.size.toString()}")
            } else {
                LogUtils.warn("WebMCPProtocol: no AgentDefinition provided, querying agents table for MAIN agent")
                let agentsService = AgentsService()
                let (agentList, _) = agentsService.getListWithFilter(1, 1, "", "{\"agent_type\":{\"equals\":\"MAIN\"}}")
                var fallbackName = "WebMCP Skill Assistant"
                var fallbackPrompt = ""
                if (agentList.size > 0) {
                    let dbAgent = agentList[0]
                    fallbackName = dbAgent.name
                    this._agentId = dbAgent.id
                    if (let Some(sp) <- dbAgent.systemPrompt) {
                        fallbackPrompt = sp
                    }
                    LogUtils.info("WebMCPProtocol: found MAIN agent from database: ${fallbackName}, UUID=${this._agentId}")
                }
                
                let memory = TieredMemory(agentId: this._agentId)
                this._agent = Some(SkillAwareAgent(
                    skillManager: skillManager.getOrThrow(),
                    model: chatModel.getOrThrow(),
                    executor: executor,
                    name: fallbackName,
                    description: "An intelligent assistant that can use skills to help users through WebMCP protocol",
                    systemPrompt: fallbackPrompt,
                    memory: Some(memory),
                    eventHandlerManager: Some(EventHandlerManager.global)
                ))
            }
        } else {
            this._agent = None
        }
    }

    public func setSessionInfo(sessionId: String, clientId: String, userId: String): Unit {
        this._sessionId = sessionId
        this._clientId = clientId
        this._userId = userId
    }

    /**
     * 注入 WebMCP 工具链路基础设施
     * @param sseManager SSE 连接管理器
     * @param pendingManager 待处理工具调用管理器
     * @param frontendToolRegistry 前端工具注册表
     */
    public func setInfrastructure(sseManager: SSEConnectionManager, pendingManager: PendingToolCallManager, frontendToolRegistry: FrontendToolRegistry): Unit {
        this._sseConnectionManager = sseManager
        this._pendingToolCallManager = pendingManager
        this._frontendToolRegistry = frontendToolRegistry
    }

    /**
     * 注入菜单数据提供者
     * @param provider 菜单数据提供者
     */
    public func setMenuDataProvider(provider: MenuDataProvider): Unit {
        this._menuDataProvider = provider
    }

    /**
     * 将用户菜单数据注入 Agent system prompt
     *
     * 基于 MenuDataProvider 查询当前用户的菜单树，扁平化为页面路径列表，
     * 格式化为菜单信息字符串后追加到 Agent 的 system prompt 中。
     * 这样大模型就能知道用户有权限访问的页面列表，从而引导用户通过前端工具操作页面。
     * 应在 setSessionInfo 和 setMenuDataProvider 之后调用。
     */
    public func injectMenuContextToAgent(): Unit {
        // 检查依赖是否就绪
        if (_menuDataProvider.isNone() || _userId.isEmpty()) {
            LogUtils.warn("[WebMCPProtocol] Cannot inject menu context: menuDataProvider or userId not set")
            return
        }
        if (_agent.isNone()) {
            LogUtils.warn("[WebMCPProtocol] Cannot inject menu context: agent not available")
            return
        }

        let menuProvider = _menuDataProvider.getOrThrow()
        let agent = _agent.getOrThrow()

        // 查询用户菜单树并扁平化
        let menuTree = menuProvider.getUserMenuTree(_userId)
        let flatItems = menuProvider.flattenMenuPaths(menuTree)

        if (flatItems.size == 0) {
            LogUtils.info("[WebMCPProtocol] No menu items for userId=${_userId}, system prompt unchanged")
            return
        }

        // 格式化菜单信息字符串
        let menuInfoBuilder = StringBuilder()
        menuInfoBuilder.append("\n\n## 用户可访问的页面菜单列表\n")
        menuInfoBuilder.append("以下是当前用户有权限访问的页面菜单。当用户需要操作某个页面时，")
        menuInfoBuilder.append("你可以引导用户通过前端注册的工具来操作这些页面。\n\n")
        for (item in flatItems) {
            if (item.path.isEmpty()) {
                menuInfoBuilder.append("- ${item.title}\n")
            } else {
                menuInfoBuilder.append("- ${item.title} (路由: ${item.path})\n")
            }
        }
        let menuInfo = menuInfoBuilder.toString()

        // 将菜单信息追加到 agent 的 system prompt
        let currentPrompt = agent.systemPrompt
        // 避免重复注入：检查是否已包含菜单标记
        if (!currentPrompt.contains("## 用户可访问的页面菜单列表")) {
            agent.systemPrompt = currentPrompt + menuInfo
            LogUtils.info("[WebMCPProtocol] Menu context injected into system prompt: ${flatItems.size.toString()} menu items")
        } else {
            // 已注入过，替换旧内容
            let marker = "## 用户可访问的页面菜单列表"
            let markerIdxOpt = currentPrompt.indexOf(marker)
            if (let Some(markerIdx) <- markerIdxOpt) {
                // 使用切片获取 marker 之前的内容
                let beforeMarker = currentPrompt[0..markerIdx]
                // 去除之前的换行
                var trimmed = beforeMarker
                while (trimmed.endsWith("\n") || trimmed.endsWith(" ")) {
                    let trimLen = trimmed.size
                    trimmed = trimmed[0..trimLen - 1]
                }
                agent.systemPrompt = trimmed + menuInfo
                LogUtils.info("[WebMCPProtocol] Menu context updated in system prompt: ${flatItems.size.toString()} menu items")
            } else {
                agent.systemPrompt = currentPrompt + menuInfo
                LogUtils.info("[WebMCPProtocol] Menu context injected into system prompt: ${flatItems.size.toString()} menu items")
            }
        }
    }

    /**
     * 处理客户端发送的消息
     */
    public func handleMessage(message: String): String {
        LogUtils.debug("WebMCP received message: ${message}")
        
        let jsonValue = JsonValue.fromStr(message)
        
        if (jsonValue is JsonObject) {
            return handleRequest(jsonValue.asObject())
        } else if (jsonValue is JsonArray) {
            let arr = jsonValue.asArray()
            let size = arr.size()
            if (size == 1) {
                let item = arr.get(0)
                if (item.isSome() && item.getOrThrow() is JsonObject) {
                    return handleRequest(item.getOrThrow().asObject())
                }
            }
            let results = ArrayList<String>()
            var i = 0
            while (i < size) {
                let item = arr.get(i)
                if (item.isSome() && item.getOrThrow() is JsonObject) {
                    results.add(handleRequest(item.getOrThrow().asObject()))
                } else {
                    results.add(createErrorResponse("Invalid item in batch request"))
                }
                i++
            }
            let sb = StringBuilder()
            sb.append("[")
            var j = 0
            while (j < results.size) {
                if (j > 0) { sb.append(",") }
                sb.append(results[j])
                j++
            }
            sb.append("]")
            return sb.toString()
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
        } else if (method == "tools/register") {
            // WebMCP 扩展：前端注册工具到 Agent
            return handleToolsRegister(obj)
        } else if (method == "tools/unregister") {
            // WebMCP 扩展：前端注销工具
            return handleToolsUnregister(obj)
        } else if (method == "sendMessage") {
            return handleSendMessage(obj)
        } else if (method == "listSessions") {
            return handleListSessions(obj)
        } else if (method == "closeSession") {
            return handleCloseSession(obj)
        } else if (method == "completion/complete") {
            return handleCompletionComplete(obj)
        } else if (method == "notifications/cancelled" || method == "notifications/progress" || method == "notifications/message" || method == "notifications/initialized") {
            // MCP 协议通知方法，不需要返回响应
            // notifications/cancelled: 取消请求通知
            // notifications/progress: 进度通知  
            // notifications/message: 消息通知
            // notifications/initialized: 初始化完成通知
            LogUtils.info("WebMCP received notification: ${method}")
            return handleNotification(method, obj)
        } else {
            return createErrorResponse("Unknown method: ${method}")
        }
    }

    /**
     * 处理 MCP 通知方法
     * 通知方法通常不需要返回响应，但如果请求有 id，需要返回有效的 JSON-RPC 响应
     */
    private func handleNotification(method: String, obj: JsonObject): String {
        let requestId = obj.get("id")
        
        // 如果有 requestId，说明是一个带响应的请求，返回成功响应
        if (requestId.isSome()) {
            let result = JsonObject()
            result.put("success", JsonBool(true))
            result.put("message", JsonString("Notification received"))
            return createSuccessResponse(result, requestId)
        }
        
        // 真正的通知（无 id），返回空字符串表示不需要响应
        // 注意：JSON-RPC 规范中，通知不应返回响应
        return ""
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
     * 将 Tool 转换为 MCP 协议格式的 JSON
     * @param tool 工具实例
     * @return MCP 格式的工具 JSON 对象
     */
    private func toolToJson(tool: Tool): JsonObject {
        let toolJo = JsonObject()
        toolJo.put("name", JsonString(tool.name))
        toolJo.put("description", JsonString(tool.description))
        
        // 构建 inputSchema
        let inputSchema = JsonObject()
        inputSchema.put("type", JsonString("object"))
        
        let properties = JsonObject()
        let required = ArrayList<JsonValue>()
        
        for (param in tool.parameters) {
            let paramJo = param.typeSchema.toJsonValue().asObject()
            if (!param.description.isEmpty()) {
                paramJo.put("description", JsonString(param.description))
            }
            properties.put(param.name, paramJo)
            required.add(JsonString(param.name))
        }
        
        if (!tool.parameters.isEmpty()) {
            inputSchema.put("properties", properties)
            inputSchema.put("required", JsonArray(required))
        }
        
        toolJo.put("inputSchema", inputSchema)
        return toolJo
    }
    
    /**
     * 处理获取工具列表请求
     */
    private func handleGetTools(obj: JsonObject): String {
        let requestId = obj.get("id")
        
        let toolArray = JsonArray()
        let addedToolNames = HashMap<String, Bool>()
        
        // 1. 添加后端技能作为工具
        if (let Some(sm) <- _skillManager) {
            let skills = sm.availableSkills
            let keys = skills.keys()
            for (key in keys) {
                if (let Some(skill) <- skills.get(key)) {
                    // 只返回启用的技能
                    if (sm.isSkillEnabled(key)) {
                        let toolJson = skillToJson(skill)
                        toolArray.add(toolJson)
                        addedToolNames.add(skill.name, true)
                    }
                }
            }
        }
        
        // 2. 添加内置工具（从 agent.toolManager）
        if (let Some(agent) <- _agent) {
            let builtinTools = agent.toolManager.tools
            for (tool in builtinTools) {
                if (!addedToolNames.contains(tool.name)) {
                    let toolJson = toolToJson(tool)
                    toolArray.add(toolJson)
                    addedToolNames.add(tool.name, true)
                    LogUtils.debug("[WebMCPProtocol] Added builtin tool: ${tool.name}")
                }
            }
        }
        
        // 3. 添加前端注册的工具（从 _frontendToolRegistry）
        if (let Some(registry) <- _frontendToolRegistry) {
            let frontendTools = registry.getAllTools()
            for (frontendTool in frontendTools) {
                if (!addedToolNames.contains(frontendTool.name)) {
                    let toolJson = JsonObject()
                    toolJson.put("name", JsonString(frontendTool.name))
                    toolJson.put("description", JsonString(frontendTool.description))
                    toolJson.put("inputSchema", frontendTool.inputSchema)
                    toolArray.add(toolJson)
                    addedToolNames.add(frontendTool.name, true)
                    LogUtils.debug("[WebMCPProtocol] Added frontend tool: ${frontendTool.name}")
                }
            }
        }
        
        LogUtils.info("[WebMCPProtocol] tools/list returning ${toolArray.size().toString()} tools")
        
        let result = JsonObject()
        result.put("tools", toolArray)
        
        return createSuccessResponse(result, requestId)
    }

    /**
     * 处理工具调用请求
     * 支持：后端技能、内置工具、前端注册工具
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

        // 兼容两种参数格式：
        // 1. WebMCP 扩展格式：toolName + args
        // 2. MCP 协议标准格式：name + arguments
        var toolNameStr = ""
        let toolNameOpt = paramsObj.get("toolName")
        let nameOpt = paramsObj.get("name")

        if (toolNameOpt.isSome()) {
            let toolNameVal = toolNameOpt.getOrThrow()
            if (toolNameVal is JsonString) {
                toolNameStr = toolNameVal.asString().getValue()
            }
        }

        // 如果 toolName 为空，尝试从 name 字段获取（MCP 标准格式）
        if (toolNameStr.isEmpty() && nameOpt.isSome()) {
            let nameVal = nameOpt.getOrThrow()
            if (nameVal is JsonString) {
                toolNameStr = nameVal.asString().getValue()
            }
        }

        if (toolNameStr.isEmpty()) {
            return createErrorResponse("Missing 'toolName' or 'name' field", requestId)
        }

        // 准备参数：优先使用 args，其次使用 arguments（MCP 标准格式）
        let argsMap = HashMap<String, JsonValue>()
        let argsOpt = paramsObj.get("args")
        let argumentsOpt = paramsObj.get("arguments")

        let argsSourceOpt = if (argsOpt.isSome()) {
            argsOpt
        } else {
            argumentsOpt
        }

        if (argsSourceOpt.isSome()) {
            let argsVal = argsSourceOpt.getOrThrow()
            if (argsVal is JsonObject) {
                let argsObj = argsVal.asObject()
                for ((key, value) in argsObj.getFields()) {
                    argsMap.add(key, value)
                }
            }
        }
        
        // 1. 首先查找后端技能
        if (let Some(sm) <- _skillManager) {
            let skillOpt = sm.getSkill(toolNameStr)
            
            if (skillOpt.isSome() && sm.isSkillEnabled(toolNameStr)) {
                LogUtils.info("WebMCP invoking skill: ${toolNameStr} with args: ${argsMap}")
                
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
        }
        
        // 2. 查找内置工具（从 agent.toolManager）
        if (let Some(agent) <- _agent) {
            let toolOpt = agent.toolManager.findTool(toolNameStr)
            
            if (toolOpt.isSome()) {
                let tool = toolOpt.getOrThrow()
                LogUtils.info("WebMCP invoking builtin tool: ${toolNameStr} with args: ${argsMap}")
                
                let result = try {
                    let toolResponse = tool.invoke(argsMap)
                    LogUtils.debug("Builtin tool call result: ${toolResponse.content}")
                    
                    // 返回符合 MCP 协议标准格式的响应
                    let content = JsonArray()
                    let textBlock = JsonObject()
                    textBlock.put("type", JsonString("text"))
                    textBlock.put("text", JsonString(toolResponse.content))
                    content.add(textBlock)
                    
                    let resultObj = JsonObject()
                    resultObj.put("content", content)
                    resultObj.put("isError", JsonBool(toolResponse.isError))
                    resultObj
                } catch (e: Exception) {
                    LogUtils.error("Builtin tool call error: ${e.message}")
                    
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
        }
        
        // 3. 查找前端注册的工具（从 _frontendToolRegistry）
        if (let Some(registry) <- _frontendToolRegistry) {
            let frontendTools = registry.getAllTools()
            for (frontendTool in frontendTools) {
                if (frontendTool.name == toolNameStr) {
                    LogUtils.info("WebMCP invoking frontend tool: ${toolNameStr} with args: ${argsMap}")
                    
                    // 通过 WebMCPToolHelper 执行前端工具调用
                    // 前端工具的调用需要通过 SSE 推送指令并等待结果
                    // 增加超时时间到 120 秒，支持复杂的前端操作（如数据库查询、文件上传等）
                    let result = try {
                        let toolResult = WebMCPToolHelper.executeToolCall(
                            toolNameStr,
                            argsMap,
                            120000,  // 默认 120 秒超时
                            ""
                        )
                        
                        // 返回符合 MCP 协议标准格式的响应
                        let content = JsonArray()
                        let textBlock = JsonObject()
                        textBlock.put("type", JsonString("text"))
                        textBlock.put("text", JsonString(toolResult.content))
                        content.add(textBlock)
                        
                        let resultObj = JsonObject()
                        resultObj.put("content", content)
                        resultObj.put("isError", JsonBool(toolResult.isError))
                        resultObj
                    } catch (e: Exception) {
                        LogUtils.error("Frontend tool call error: ${e.message}")
                        
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
            }
        }
        
        // 工具未找到
        LogUtils.warn("[WebMCPProtocol] Tool not found: ${toolNameStr}")
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
     * 处理工具注册请求（WebMCP 扩展）
     *
     * 前端通过 `tools/register` 方法注册工具到 Agent。
     * 请求格式：
     * ```json
     * {
     *   "method": "tools/register",
     *   "params": {
     *     "tools": [
     *       {
     *         "name": "tool_name",
     *         "title": "工具标题",
     *         "description": "工具描述",
     *         "inputSchema": { "type": "object", "properties": {...} },
     *         "route": "/page/route",
     *         "annotations": null
     *       }
     *     ]
     *   }
     * }
     * ```
     *
     * 处理流程：
     * 1. 解析 params.tools 数组
     * 2. 对每个工具，创建 FrontendToolDefinition 并存入 FrontendToolRegistry
     * 3. 同步调用 agent.addFrontendTool 将工具注册到 Agent ToolManager
     * 4. 返回成功响应（包含已注册的工具数量）
     */
    private func handleToolsRegister(obj: JsonObject): String {
        let requestId = obj.get("id")

        // 1. 检查基础设施是否已注入
        if (_frontendToolRegistry.isNone()) {
            LogUtils.error("[WebMCPProtocol] tools/register failed: FrontendToolRegistry not injected")
            return createErrorResponse("FrontendToolRegistry not available", requestId)
        }
        let registry = _frontendToolRegistry.getOrThrow()

        // 2. 解析 params.tools 数组
        let paramsOpt = obj.get("params")
        if (paramsOpt.isNone()) {
            return createErrorResponse("Missing 'params' field in tools/register request", requestId)
        }
        let paramsVal = paramsOpt.getOrThrow()
        if (!(paramsVal is JsonObject)) {
            return createErrorResponse("Invalid 'params' field type in tools/register request", requestId)
        }
        let paramsObj = paramsVal.asObject()

        // 兼容两种格式：
        // 1. params.tools: [...] — 批量注册（数组）
        // 2. params.tool: {...} — 单个注册（对象）
        // 3. params 直接是工具对象（无 tools/tool 包裹）
        let toolsArray = JsonArray()
        let toolsOpt = paramsObj.get("tools")
        if (toolsOpt.isSome()) {
            let toolsVal = toolsOpt.getOrThrow()
            if (toolsVal is JsonArray) {
                let arr = toolsVal.asArray()
                let arrSize = arr.size()
                var idx = 0
                while (idx < arrSize) {
                    let itemOpt = arr.get(idx)
                    if (itemOpt.isSome()) {
                        toolsArray.add(itemOpt.getOrThrow())
                    }
                    idx++
                }
            }
        }
        
        // 如果 tools 数组为空，尝试从 tool（单数）字段获取
        if (toolsArray.size() == 0) {
            let toolOpt = paramsObj.get("tool")
            if (toolOpt.isSome()) {
                let toolVal = toolOpt.getOrThrow()
                if (toolVal is JsonObject) {
                    toolsArray.add(toolVal)
                }
            }
        }
        
        // 如果仍然为空，尝试将 params 本身作为工具对象
        if (toolsArray.size() == 0) {
            // 检查 params 是否直接包含 name 字段（作为工具对象）
            if (paramsObj.get("name").isSome()) {
                toolsArray.add(paramsVal)
            }
        }
        
        if (toolsArray.size() == 0) {
            return createErrorResponse("No valid tools found in tools/register params (expected 'tools' array or 'tool' object)", requestId)
        }

        // 3. 遍历工具数组，逐个注册
        var registeredCount = 0
        let size = toolsArray.size()
        var i = 0
        while (i < size) {
            let toolItemOpt = toolsArray.get(i)
            if (toolItemOpt.isNone()) {
                i++
                continue
            }
            let toolItem = toolItemOpt.getOrThrow()
            if (!(toolItem is JsonObject)) {
                LogUtils.warn("[WebMCPProtocol] tools/register: tool[${i.toString()}] is not JsonObject, skipped")
                i++
                continue
            }
            let toolObj = toolItem.asObject()

            // 解析工具字段
            let name = _extractStringField(toolObj, "name")
            if (name.isEmpty()) {
                LogUtils.warn("[WebMCPProtocol] tools/register: tool[${i.toString()}] missing 'name', skipped")
                i++
                continue
            }
            let title = _extractStringField(toolObj, "title")
            let description = _extractStringField(toolObj, "description")
            let route = _extractStringField(toolObj, "route")

            // 解析 inputSchema（JsonObject）
            var inputSchema = JsonObject()
            let schemaOpt = toolObj.get("inputSchema")
            if (schemaOpt.isSome()) {
                let schemaVal = schemaOpt.getOrThrow()
                if (schemaVal is JsonObject) {
                    inputSchema = schemaVal.asObject()
                }
            }

            // 解析 annotations（可选 JsonObject）
            var annotations: ?JsonObject = None
            let annotationsOpt = toolObj.get("annotations")
            if (annotationsOpt.isSome()) {
                let annotationsVal = annotationsOpt.getOrThrow()
                if (annotationsVal is JsonObject) {
                    annotations = Some(annotationsVal.asObject())
                }
            }

            // 创建 FrontendToolDefinition 并存入 FrontendToolRegistry
            let toolDef = FrontendToolDefinition(
                name, title, description, inputSchema, route, annotations
            )
            registry.register(toolDef)
            LogUtils.info("[WebMCPProtocol] Registered frontend tool to registry: ${name}")

            // 同步注册到 Agent ToolManager（通过 agent.addFrontendTool）
            if (let Some(agent) <- _agent) {
                let titleOpt = if (title.isEmpty()) { None<String> } else { Some<String>(title) }
                let descOpt = if (description.isEmpty()) { None<String> } else { Some<String>(description) }
                let routeOpt = if (route.isEmpty()) { None<String> } else { Some<String>(route) }
                agent.addFrontendTool(name, titleOpt, descOpt, routeOpt, Some<JsonObject>(inputSchema))
                LogUtils.info("[WebMCPProtocol] Synced frontend tool to Agent ToolManager: ${name}")
            } else {
                LogUtils.warn("[WebMCPProtocol] Agent not available, tool '${name}' only registered to registry")
            }

            registeredCount++
            i++
        }

        // 4. 返回成功响应
        let result = JsonObject()
        result.put("registered", JsonInt(Int64(registeredCount)))
        result.put("message", JsonString("Successfully registered ${registeredCount.toString()} tool(s)"))
        LogUtils.info("[WebMCPProtocol] tools/register completed: ${registeredCount.toString()} tools registered")
        return createSuccessResponse(result, requestId)
    }

    /**
     * 处理工具注销请求（WebMCP 扩展）
     *
     * 前端通过 `tools/unregister` 方法注销工具。
     * 请求格式：
     * ```json
     * {
     *   "method": "tools/unregister",
     *   "params": {
     *     "names": ["tool_name1", "tool_name2"]
     *   }
     * }
     * ```
     */
    private func handleToolsUnregister(obj: JsonObject): String {
        let requestId = obj.get("id")

        // 解析 params.names 数组
        let paramsOpt = obj.get("params")
        if (paramsOpt.isNone()) {
            return createErrorResponse("Missing 'params' field in tools/unregister request", requestId)
        }
        let paramsVal = paramsOpt.getOrThrow()
        if (!(paramsVal is JsonObject)) {
            return createErrorResponse("Invalid 'params' field type in tools/unregister request", requestId)
        }
        let paramsObj = paramsVal.asObject()

        let namesOpt = paramsObj.get("names")
        if (namesOpt.isNone()) {
            return createErrorResponse("Missing 'names' field in tools/unregister params", requestId)
        }
        let namesVal = namesOpt.getOrThrow()
        if (!(namesVal is JsonArray)) {
            return createErrorResponse("Invalid 'names' field type in tools/unregister params", requestId)
        }
        let namesArray = namesVal.asArray()

        var unregisteredCount = 0
        let size = namesArray.size()
        var i = 0
        while (i < size) {
            let nameItemOpt = namesArray.get(i)
            if (nameItemOpt.isNone()) {
                i++
                continue
            }
            let nameItem = nameItemOpt.getOrThrow()
            if (!(nameItem is JsonString)) {
                i++
                continue
            }
            let toolName = nameItem.asString().getValue()

            // 从 FrontendToolRegistry 注销
            if (let Some(registry) <- _frontendToolRegistry) {
                registry.unregister(toolName)
            }

            // 从 Agent ToolManager 注销
            if (let Some(agent) <- _agent) {
                agent.removeFrontendTool(toolName)
            }
            LogUtils.info("[WebMCPProtocol] Unregistered frontend tool: ${toolName}")
            unregisteredCount++
            i++
        }

        let result = JsonObject()
        result.put("unregistered", JsonInt(Int64(unregisteredCount)))
        result.put("message", JsonString("Successfully unregistered ${unregisteredCount.toString()} tool(s)"))
        return createSuccessResponse(result, requestId)
    }

    /// 从 JsonObject 中提取字符串字段（缺失或类型不匹配返回空字符串）
    private func _extractStringField(obj: JsonObject, field: String): String {
        let valOpt = obj.get(field)
        if (valOpt.isNone()) {
            return ""
        }
        let val = valOpt.getOrThrow()
        if (val is JsonString) {
            return val.asString().getValue()
        }
        return ""
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
        var systemMessage = ""  // 新增：存储 system 角色的消息内容
        var isStream = true  // 默认流式响应

        if (params.isSome()) {
            let paramsVal = params.getOrThrow()
            if (paramsVal is JsonObject) {
                let paramsObj = paramsVal.asObject()

                // 检查 stream 参数
                let streamParam = paramsObj.get("stream")
                if (streamParam.isSome()) {
                    let streamVal = streamParam.getOrThrow()
                    if (streamVal is JsonBool) {
                        isStream = streamVal.asBool().getValue()
                    }
                }

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
                                        let contentVal = content.getOrThrow()
                                        var contentStr = ""
                                        if (contentVal is JsonString) {
                                            contentStr = contentVal.asString().getValue()
                                        } else {
                                            contentStr = contentVal.toString().replace("\"", "")
                                        }

                                        if (roleStr == "user") {
                                            userMessage = contentStr
                                        } else if (roleStr == "system") {
                                            // 提取 system 角色的消息内容作为系统提示词
                                            systemMessage = contentStr
                                            LogUtils.info("WebMCP completion/complete received system message, length=${contentStr.size.toString()}")
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

        // 同步处理请求，返回完整响应
        var responseContent = "WebMCP server received your message."

        if (!userMessage.isEmpty()) {
            try {
                // 优先使用 SkillAwareAgent（支持技能调用）
                if (let Some(agent) <- _agent) {
                    LogUtils.info("WebMCPProtocol: agent name=${agent.name}, systemPrompt length=${agent.systemPrompt.size.toString()}")

                    // 如果前端发送了 system 消息，则使用它覆盖 agent 的系统提示词
                    if (!systemMessage.isEmpty()) {
                        LogUtils.info("WebMCPProtocol: using system message from frontend, length=${systemMessage.size.toString()}")
                        agent.systemPrompt = systemMessage
                    } else if (agent.systemPrompt.isEmpty()) {
                        let systemPrompt = buildAgentSystemPrompt()
                        agent.systemPrompt = systemPrompt
                        LogUtils.info("WebMCPProtocol: set fallback systemPrompt, length=${systemPrompt.size.toString()}")
                    }

                    // 加载历史上下文（用于多轮对话）
                    let checkpointManager = CheckpointManager()
                    var conversation: ?Conversation = None
                    if (!_agentId.isEmpty()) {
                        if (let Some(historyMessages) <- checkpointManager.loadLatestCheckpoint(_agentId)) {
                            LogUtils.info("WebMCPProtocol: loaded ${historyMessages.size} historical messages for agent ${_agentId}")
                            if (historyMessages.size > 0) {
                                // 创建对话历史
                                conversation = Some(Conversation())
                                var i = 0
                                while (i < historyMessages.size - 1) {
                                    if (i + 1 < historyMessages.size) {
                                        conversation.getOrThrow().addChatRound(historyMessages[i], historyMessages[i + 1])
                                    }
                                    i = i + 2
                                }
                            }
                        }
                    }

                    // 创建 Agent 请求并处理
                    let agentRequest = AgentRequest(userMessage, conversation: conversation)
                    let agentResponse = agent.chat(agentRequest)
                    responseContent = agentResponse.content
                    LogUtils.debug("WebMCP completion response (via SkillAwareAgent): ${responseContent}")

                    // 异步同步 Agent 状态到数据库
                    spawn {
                        try {
                            AgentRuntimeBridge.instance.syncToDatabase(agent.name, agent)
                        } catch (_: Exception) {}
                    }
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
     * 构建 Agent 系统提示词（包含技能信息、前端工具、页面导航信息）
     *
     * 注入内容：
     * 1. 基础说明（http_request 工具使用）
     * 2. 后端技能知识库
     * 3. 前端注册的工具列表（来自 FrontendToolRegistry）
     * 4. 页面导航信息（来自 MenuDataProvider，基于当前用户 ID 查询的菜单树）
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

        // 注入前端注册的工具列表
        if (let Some(registry) <- _frontendToolRegistry) {
            let frontendTools = registry.getAllTools()
            if (frontendTools.size > 0) {
                skillInfoBuilder.append("【前端可用工具】\n")
                skillInfoBuilder.append("以下工具由前端注册，调用时会通过 SSE 推送到前端执行，请根据用户需求选择合适的工具：\n\n")
                for (tool in frontendTools) {
                    skillInfoBuilder.append("### ${tool.name}\n")
                    if (!tool.title.isEmpty()) {
                        skillInfoBuilder.append("- 标题: ${tool.title}\n")
                    }
                    if (!tool.description.isEmpty()) {
                        skillInfoBuilder.append("- 描述: ${tool.description}\n")
                    }
                    if (!tool.route.isEmpty()) {
                        skillInfoBuilder.append("- 适用页面: ${tool.route}\n")
                    }
                    skillInfoBuilder.append("\n")
                }
            }
        }

        // 注入页面导航信息（基于当前用户 ID 查询的菜单树）
        if (let Some(menuProvider) <- _menuDataProvider) {
            if (!_userId.isEmpty()) {
                let menuTree = menuProvider.getUserMenuTree(_userId)
                if (menuTree.size > 0) {
                    skillInfoBuilder.append("【页面导航信息】\n")
                    skillInfoBuilder.append("当前用户可访问的页面菜单如下。当用户需要操作某个页面时，请引导用户使用前端注册的工具（通过 tools/list 可查看可用工具）来操作这些页面：\n\n")
                    _appendMenuTree(skillInfoBuilder, menuTree, 0)
                    skillInfoBuilder.append("\n")
                }
            }
        }

        return skillInfoBuilder.toString()
    }

    /// 递归将菜单树追加到 StringBuilder（带缩进）
    private func _appendMenuTree(builder: StringBuilder, items: ArrayList<MenuItem>, level: Int64): Unit {
        for (item in items) {
            // 缩进
            var indent = ""
            var i = 0
            while (i < level) {
                indent = indent + "  "
                i++
            }
            // 输出菜单项
            if (item.path.isEmpty()) {
                builder.append("${indent}- ${item.title}\n")
            } else {
                builder.append("${indent}- ${item.title} (path: ${item.path})\n")
            }
            // 递归子菜单
            if (item.children.size > 0) {
                _appendMenuTree(builder, item.children, level + 1)
            }
        }
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
