/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.webmcp

import magic.app.services.webmcp.WebMCPProtocol
import magic.app.services.webmcp.MenuDataProvider
import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.core.skill.SkillManager
import magic.core.model.ChatModel
import magic.core.agent.{AgentDefinition, AgentLoadManager}
import magic.log.LogUtils
import magic.tool.webmcp.{SSEConnectionManager, PendingToolCallManager, FrontendToolRegistry, WebMCPToolContext}
import stdx.net.http.{HttpContext, WebSocket, WebSocketFrameType, HttpHeaders}
import stdx.encoding.json.{JsonObject, JsonString, JsonBool, JsonValue, JsonArray, JsonInt}
import std.time.DateTime
import std.time.*
import f_util.UUID
import std.collection.{HashMap, ArrayList}

/**
 * WebMCP WebSocket 控制器
 * 处理 /api/v1/uctoo/webmcp/mcp 端点的 WebSocket 连接
 * 实现与前端 webmcp-sdk 的通信
 */
public class WebMCPController {
    private let _skillManager: SkillManager
    private let _chatModel: ChatModel
    private let _agentLoadManager: AgentLoadManager
    private var _sessions = HashMap<String, WebMCPProtocol>()

    // WebMCP 工具链路基础设施（单例，所有会话共享）
    private let _sseConnectionManager = SSEConnectionManager()
    private let _pendingToolCallManager = PendingToolCallManager()
    private let _frontendToolRegistry = FrontendToolRegistry()
    private let _menuDataProvider = MenuDataProvider()

    public init(skillManager: SkillManager, chatModel: ChatModel, agentLoadManager: AgentLoadManager) {
        this._skillManager = skillManager
        this._chatModel = chatModel
        this._agentLoadManager = agentLoadManager

        // 启动超时清理定时任务
        startCleanupTask()
    }

    private func getMainAgentDef(): ?AgentDefinition {
        _agentLoadManager.getMainAgent()
    }

    /**
     * 初始化 WebMCPProtocol 的基础设施注入
     * 包括：SSE 连接管理器、待处理工具调用管理器、前端工具注册表、菜单数据提供者
     * 同时设置 WebMCPToolContext 全局单例的会话上下文
     *
     * @param protocol WebMCP 协议处理器
     * @param sessionId 会话 ID
     * @param userId 用户 ID（用于菜单数据查询）
     */
    private func _initProtocolInfrastructure(protocol: WebMCPProtocol, sessionId: String, userId: String): Unit {
        // 注入基础设施到 Protocol
        protocol.setInfrastructure(_sseConnectionManager, _pendingToolCallManager, _frontendToolRegistry)
        protocol.setMenuDataProvider(_menuDataProvider)
        protocol.setSessionInfo(sessionId, "", userId)

        // 设置 WebMCPToolContext 全局单例的会话上下文
        // （供 WebMCPToolHelper.executeToolCall 使用）
        WebMCPToolContext.instance.setSessionContext(
            sessionId,
            _sseConnectionManager,
            _pendingToolCallManager
        )

        // 将用户菜单数据注入 Agent system prompt
        // 让大模型知道用户有权限访问的页面列表，从而引导用户通过前端工具操作页面
        protocol.injectMenuContextToAgent()
    }

    /**
     * 处理 WebSocket 连接（使用 HttpRequest 和 HttpResponse）
     */
    public func handleConnection(req: HttpRequest, res: HttpResponse): Unit {
        // 直接返回初始化响应（兼容 streamableHttp 协议）
        let toolsCapabilities = JsonObject()
        toolsCapabilities.put("list", JsonBool(true))
        toolsCapabilities.put("invoke", JsonBool(true))
        
        let capabilities = JsonObject()
        capabilities.put("tools", toolsCapabilities)
        capabilities.put("streaming", JsonBool(true))
        capabilities.put("sessionPersistence", JsonBool(true))
        
        let serverInfo = JsonObject()
        serverInfo.put("name", JsonString("WebMCP Server"))
        serverInfo.put("version", JsonString("1.0.0"))
        
        let result = JsonObject()
        result.put("sessionId", JsonString(UUID.random().toString()))
        result.put("protocolVersion", JsonString("2025-11-25"))
        result.put("capabilities", capabilities)
        result.put("serverInfo", serverInfo)
        
        // 使用 JSON-RPC 格式包装结果（符合 WebMCP SDK 期望）
        let response = JsonObject()
        response.put("jsonrpc", JsonString("2.0"))
        response.put("result", result)
        
        res.status(200)
           .header("Content-Type", "application/json")
           .json(response.toJsonString())
    }
    
    /**
     * 处理 HTTP POST 请求（streamableHttp 协议支持）
     * 支持前端通过 streamableHttp 类型连接 WebMCP 端点
     */
    public func handleStreamableHttp(req: HttpRequest, res: HttpResponse): Unit {
        LogUtils.info("WebMCP streamable HTTP request received")
        
        let body = req.body
        LogUtils.info("WebMCP request body length: ${body.size}")
        if (body.isEmpty()) {
            LogUtils.warn("WebMCP request body is empty")
            res.status(400)
               .header("Access-Control-Allow-Origin", "*")
               .header("Content-Type", "application/json")
               .send("{\"error\": \"Empty request body\"}")
            return
        }
        
        LogUtils.info("WebMCP request body: ${body}")
        
        // 设置 CORS 头部
        res.header("Access-Control-Allow-Origin", "*")
           .header("Access-Control-Allow-Methods", "POST, OPTIONS")
           .header("Access-Control-Allow-Headers", "*")
        
        try {
            // 复用或创建协议处理器（基于 session 保持 Agent 会话状态连续性）
            let sessionId = "webmcp-default"
            // 从请求头或查询参数获取用户 ID（用于菜单数据查询）
            let userId = _extractUserId(req)
            let protocol = if (_sessions.contains(sessionId)) {
                let p = _sessions.get(sessionId).getOrThrow()
                // 已存在会话也更新用户上下文（确保菜单数据基于当前用户）
                _initProtocolInfrastructure(p, sessionId, userId)
                p
            } else {
                let p = WebMCPProtocol(_skillManager, _chatModel, getMainAgentDef())
                _initProtocolInfrastructure(p, sessionId, userId)
                _sessions.add(sessionId, p)
                p
            }
            
            // 解析请求中的 stream 参数
            let isStream = parseStreamFlag(body)
            
            if (isStream) {
                // 流式响应：使用分块传输编码
                LogUtils.info("WebMCP streaming response requested")
                res.status(200)
                   .header("Content-Type", "application/json")
                   .header("Transfer-Encoding", "chunked")
                   .header("Connection", "keep-alive")
                
                // 使用异步方式处理流式响应
                spawn {
                    let response = protocol.handleMessage(body)
                    LogUtils.debug("WebMCP streamable HTTP response: ${response}")
                    res.send(response)
                }
            } else {
                // 非流式响应：同步处理
                let response = protocol.handleMessage(body)
                LogUtils.debug("WebMCP streamable HTTP response: ${response}")
                
                // 设置状态码并发送 JSON 响应
                res.status(200)
                   .header("Content-Type", "application/json")
                
                // 处理空响应（JSON-RPC 通知不需要响应）
                if (response.isEmpty()) {
                    // 对于真正的通知（无 id），返回 204 No Content
                    res.status(204).send("")
                } else {
                    res.json(response)
                }
            }
        } catch (e: Exception) {
            LogUtils.error("WebMCP streamable HTTP error: ${e.message}")
            res.status(500)
               .header("Content-Type", "application/json")
               .json("{\"error\": \"${e.message}\"}")
        }
    }
    
    /**
     * 解析请求体中的 stream 标志
     */
    private func parseStreamFlag(body: String): Bool {
        try {
            let jsonValue = JsonValue.fromStr(body)
            if (jsonValue is JsonArray) {
                let arr = jsonValue.asArray()
                if (arr.size() > 0) {
                    let item = arr.get(0)
                    if (item.isSome() && item.getOrThrow() is JsonObject) {
                        let obj = item.getOrThrow().asObject()
                        let params = obj.get("params")
                        if (params.isSome() && params.getOrThrow() is JsonObject) {
                            let paramsObj = params.getOrThrow().asObject()
                            let stream = paramsObj.get("stream")
                            if (stream.isSome() && stream.getOrThrow() is JsonBool) {
                                return stream.getOrThrow().asBool().getValue()
                            }
                        }
                    }
                }
            }
        } catch (_: Exception) {}
        return false
    }
    
    /**
     * 处理 WebSocket 连接（使用 HttpContext，直接处理）
     */
    public func handleConnection(ctx: HttpContext): Unit {
        LogUtils.info("WebMCP WebSocket connection attempt from ${ctx.request.remoteAddr}")
        
        // 升级 HTTP 连接为 WebSocket
        let websocket = WebSocket.upgradeFromServer(
            ctx,
            subProtocols: ArrayList<String>(["model-context-protocol"]),
            userFunc: { _ =>
                let headers = HttpHeaders()
                headers.add("X-Connection-Type", "webmcp")
                headers
            }
        )
        
        let sessionId = UUID.random().toString()
        
        LogUtils.info("WebMCP WebSocket connection established, sessionId: ${sessionId}")
        
        // 从请求头获取用户 ID（用于菜单数据查询）
        let userId = _extractUserIdFromContext(ctx)
        
        // 创建协议处理器（使用从AGENTS.md加载的动态Agent）
        let protocol = WebMCPProtocol(_skillManager, _chatModel, getMainAgentDef())
        _initProtocolInfrastructure(protocol, sessionId, userId)
        _sessions.add(sessionId, protocol)
        
        // 处理消息循环
        handleMessageLoop(websocket, sessionId, protocol)
        
        // 清理会话
        _sessions.remove(sessionId)
        LogUtils.info("WebMCP WebSocket session closed: ${sessionId}")
    }

    /**
     * 处理消息循环
     */
    private func handleMessageLoop(websocket: WebSocket, sessionId: String, protocol: WebMCPProtocol): Unit {
        var buffer = ""
        
        var frame = websocket.read()
        while (true) {
            match (frame.frameType) {
                case WebSocketFrameType.TextWebFrame =>
                    let message = String.fromUtf8(frame.payload)
                    LogUtils.debug("WebMCP received text message: ${message}")
                    buffer = buffer + message
                    
                    // 尝试处理完整消息
                    buffer = processMessages(buffer, websocket, protocol)
                
                case WebSocketFrameType.BinaryWebFrame =>
                    LogUtils.error("WebMCP received binary message (unsupported)")
                    let errorBytes = "{\"error\": \"Binary messages not supported\"}\n".toArray()
                    websocket.write(WebSocketFrameType.TextWebFrame, errorBytes)
                
                case WebSocketFrameType.CloseWebFrame =>
                    LogUtils.info("WebMCP WebSocket close frame received")
                    websocket.write(WebSocketFrameType.CloseWebFrame, frame.payload)
                    break
                
                case WebSocketFrameType.PingWebFrame =>
                    websocket.writePongFrame(frame.payload)
                
                case _ => 
                    LogUtils.error("WebMCP received unknown frame type")
            }
            frame = websocket.read()
        }
    }

    /**
     * 处理消息缓冲区中的完整消息
     */
    private func processMessages(buffer: String, websocket: WebSocket, protocol: WebMCPProtocol): String {
        var content = buffer
        var pos: Int64 = 0
        
        while (pos < content.size) {
            // 查找消息分隔符（换行符）
            let newlinePos = content.indexOf("\n", pos)
            
            if (newlinePos.isSome()) {
                let np = newlinePos.getOrThrow()
                let message = content[pos..np].trimAscii()
                pos = np + 1
                
                if (!message.isEmpty()) {
                    processMessage(message, websocket, protocol)
                }
            } else {
                // 没有找到完整消息，返回剩余内容
                return content[pos..]
            }
        }
        
        return ""
    }

    /**
     * 处理单条消息
     */
    private func processMessage(message: String, websocket: WebSocket, protocol: WebMCPProtocol): Unit {
        try {
            let response = protocol.handleMessage(message)
            LogUtils.debug("WebMCP sending response: ${response}")
            
            // 对于真正的通知（无 id），不发送响应（JSON-RPC 规范）
            if (!response.isEmpty()) {
                let responseBytes = ("${response}\n").toArray()
                websocket.write(WebSocketFrameType.TextWebFrame, responseBytes)
            }
        } catch (e: Exception) {
            LogUtils.error("WebMCP message processing error: ${e.message}")
            let errorResponse = "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32603,\"message\":\"${e.message}\"}}\n"
            let errorBytes = errorResponse.toArray()
            websocket.write(WebSocketFrameType.TextWebFrame, errorBytes)
        }
    }

    /**
     * 获取活跃会话数量
     */
    public func getActiveSessionCount(): Int32 {
        return Int32(_sessions.size)
    }
    
    /**
     * 处理客户端短码解析请求（/client 端点）
     *
     * 前端 TinyRemoter 在收到以 "/" 开头的识别码（如 /abc123）时，
     * 会调用 `${agentRoot}client?sessionId=xxx` 解析短码为完整的 sessionId。
     *
     * 请求格式：GET /api/v1/uctoo/webmcp/client?sessionId=abc123
     * 响应格式：{ "data": { "sessionId": "完整的sessionId" } }
     */
    public func handleClientRequest(req: HttpRequest, res: HttpResponse): Unit {
        // 设置 CORS 头部
        res.header("Access-Control-Allow-Origin", "*")
           .header("Access-Control-Allow-Methods", "GET, OPTIONS")
           .header("Access-Control-Allow-Headers", "*")

        let sessionIdOpt = req.queryParam("sessionId")
        let sessionId = if (let Some(id) <- sessionIdOpt) { id } else { "" }

        LogUtils.info("WebMCP client request received, sessionId param: ${sessionId}")

        if (sessionId.isEmpty()) {
            res.status(400)
               .header("Content-Type", "application/json")
               .json("{\"error\": \"Missing sessionId parameter\"}")
            return
        }

        // 在当前实现中，直接返回传入的 sessionId 作为完整 sessionId
        // 后续可以扩展为短码到完整 sessionId 的映射机制
        let responseJson = """
            {
                "data": {
                    "sessionId": "${sessionId}"
                }
            }
            """

        LogUtils.debug("WebMCP client response: ${responseJson}")

        res.status(200)
           .header("Content-Type", "application/json")
           .json(responseJson)
    }

    /**
     * 处理远程控制请求
     * 用于生成扫码连接的二维码数据，支持移动端扫码连接到 WebMCP 会话
     */
    public func handleRemoteRequest(req: HttpRequest, res: HttpResponse): Unit {
        LogUtils.info("WebMCP remote request received")
        
        // 获取查询参数中的 sessionId
        let sessionIdOpt = req.queryParam("sessionId")
        let sessionId = if (let Some(id) <- sessionIdOpt) { id } else { UUID.random().toString() }
        
        // 生成远程连接令牌（有效期内可用）
        let token = UUID.random().toString()
        let now = DateTime.now()
        let epoch = DateTime.ofEpoch(second: 0, nanosecond: 0)
        let duration = now - epoch
        let expiresAt = duration.toSeconds() * 1000 + 300000 // 5分钟过期（毫秒）
        
        // 构建远程连接信息
        let responseJson = 
            """
            {
                "success": true,
                "sessionId": "${sessionId}",
                "token": "${token}",
                "expiresAt": ${expiresAt},
                "remoteUrl": "/api/v1/uctoo/webmcp/mcp?sessionId=${sessionId}&token=${token}",
                "message": "Remote control token generated successfully"
            }
            """
        
        LogUtils.debug("WebMCP remote response: ${responseJson}")
        
        res.status(200)
           .header("Content-Type", "application/json")
           .json(responseJson)
    }

    /**
     * 处理工具调用结果回传（/tool-result 端点）
     *
     * 前端在执行完工具调用后，通过此端点回传执行结果。
     * 请求格式：
     * ```json
     * {
     *   "callId": "call_xxx",
     *   "result": "{\"success\":true,...}",
     *   "error": null
     * }
     * ```
     *
     * 处理流程：
     * 1. 解析请求体中的 callId 和 result
     * 2. 调用 _pendingToolCallManager.handleResult(callId, result) 唤醒等待的线程
     * 3. 返回成功响应
     */
    public func handleToolResult(req: HttpRequest, res: HttpResponse): Unit {
        LogUtils.info("WebMCP tool-result request received")

        // 设置 CORS 头部
        res.header("Access-Control-Allow-Origin", "*")
           .header("Access-Control-Allow-Methods", "POST, OPTIONS")
           .header("Access-Control-Allow-Headers", "*")

        let body = req.body
        if (body.isEmpty()) {
            res.status(400)
               .header("Content-Type", "application/json")
               .send("{\"error\": \"Empty request body\"}")
            return
        }

        try {
            // 解析请求体
            let jsonValue = JsonValue.fromStr(body)
            if (!(jsonValue is JsonObject)) {
                res.status(400)
                   .header("Content-Type", "application/json")
                   .send("{\"error\": \"Invalid JSON format\"}")
                return
            }
            let obj = jsonValue.asObject()

            // 提取 callId
            let callIdOpt = obj.get("callId")
            if (callIdOpt.isNone()) {
                res.status(400)
                   .header("Content-Type", "application/json")
                   .send("{\"error\": \"Missing 'callId' field\"}")
                return
            }
            let callIdVal = callIdOpt.getOrThrow()
            if (!(callIdVal is JsonString)) {
                res.status(400)
                   .header("Content-Type", "application/json")
                   .send("{\"error\": \"Invalid 'callId' field type\"}")
                return
            }
            let callId = callIdVal.asString().getValue()

            // 提取 result（如果有 error，将 error 作为结果）
            var resultStr = ""
            let resultOpt = obj.get("result")
            if (resultOpt.isSome()) {
                let resultVal = resultOpt.getOrThrow()
                if (resultVal is JsonString) {
                    resultStr = resultVal.asString().getValue()
                } else {
                    resultStr = resultVal.toString()
                }
            } else {
                let errorOpt = obj.get("error")
                if (errorOpt.isSome()) {
                    let errorVal = errorOpt.getOrThrow()
                    if (errorVal is JsonString) {
                        resultStr = "{\"error\":\"${errorVal.asString().getValue()}\"}"
                    } else {
                        resultStr = "{\"error\":${errorVal.toString()}}"
                    }
                } else {
                    resultStr = "{}"
                }
            }

            // 调用 PendingToolCallManager 唤醒等待的线程
            let handled = _pendingToolCallManager.handleResult(callId, resultStr)
            if (handled) {
                LogUtils.info("[WebMCPController] Tool result handled: callId=${callId}")
                let responseJson = "{\"success\":true,\"callId\":\"${callId}\",\"message\":\"Tool result processed\"}"
                res.status(200)
                   .header("Content-Type", "application/json")
                   .json(responseJson)
            } else {
                LogUtils.warn("[WebMCPController] Tool result not found (maybe timed out): callId=${callId}")
                let responseJson = "{\"success\":false,\"callId\":\"${callId}\",\"message\":\"Tool call not found or already completed\"}"
                res.status(404)
                   .header("Content-Type", "application/json")
                   .json(responseJson)
            }
        } catch (e: Exception) {
            LogUtils.error("[WebMCPController] Tool result processing error: ${e.message}")
            res.status(500)
               .header("Content-Type", "application/json")
               .json("{\"error\": \"${e.message}\"}")
        }
    }

    /**
     * 处理 SSE 连接（/sse 端点）
     *
     * 前端通过 EventSource 连接此端点，接收 Agent 推送的工具调用指令。
     * 连接建立后，将 sessionId 和 writer 注册到 SSEConnectionManager。
     *
     * 查询参数：
     * - sessionId: 会话 ID（必填，与 MCP 会话 ID 一致）
     */
    public func handleSSE(req: HttpRequest, res: HttpResponse): Unit {
        LogUtils.info("WebMCP SSE connection request received")

        // 获取 sessionId
        let sessionIdOpt = req.queryParam("sessionId")
        if (sessionIdOpt.isNone()) {
            res.status(400)
               .header("Content-Type", "application/json")
               .send("{\"error\": \"Missing 'sessionId' query parameter\"}")
            return
        }
        let sessionId = sessionIdOpt.getOrThrow()

        // 设置 SSE 响应头
        res.status(200)
           .header("Content-Type", "text/event-stream")
           .header("Cache-Control", "no-cache")
           .header("Connection", "keep-alive")
           .header("Access-Control-Allow-Origin", "*")

        // 注册 SSE 连接到 SSEConnectionManager
        // writer 函数：将消息写入 HTTP 响应流
        _sseConnectionManager.registerConnection(sessionId, { message: String =>
            res.send(message)
        })

        LogUtils.info("[WebMCPController] SSE connection registered: sessionId=${sessionId}")

        // 发送初始连接成功事件
        let initEvent = "event: connected\ndata: {\"sessionId\":\"${sessionId}\"}\n\n"
        res.send(initEvent)

        // 注意：SSE 连接保持打开状态，由前端关闭或超时清理
        // 实际实现中，这里需要保持连接不返回，具体取决于 HTTP 框架的流式响应支持
    }

    /**
     * 从 HttpRequest 中提取用户 ID
     * 优先级：查询参数 userId > 请求头 X-User-Id > 空字符串
     */
    private func _extractUserId(req: HttpRequest): String {
        // 1. 查询参数
        let queryOpt = req.queryParam("userId")
        if (queryOpt.isSome()) {
            let userId = queryOpt.getOrThrow()
            if (!userId.isEmpty()) {
                return userId
            }
        }
        // 2. 请求头
        let headerOpt = req.header("X-User-Id")
        if (headerOpt.isSome()) {
            return headerOpt.getOrThrow()
        }
        // 3. 默认空字符串
        return ""
    }

    /**
     * 从 HttpContext 中提取用户 ID
     * 由于 stdx.net.http HttpContext 不提供请求头访问，暂时返回空字符串
     * 实际用户 ID 通过 WebSocket 消息传递
     */
    private func _extractUserIdFromContext(ctx: HttpContext): String {
        // stdx.net.http 的 HttpRequest 没有 header 方法
        // 用户 ID 通过 WebSocket 消息传递，此处返回空字符串
        return ""
    }

    /**
     * 启动超时清理定时任务
     * 每 5 分钟清理一次 PendingToolCallManager 中的超时条目
     * 防止长时间等待的工具调用占用内存
     */
    private func startCleanupTask(): Unit {
        spawn {
            LogUtils.info("[WebMCPController] Cleanup task started, running every 5 minutes")
            while (true) {
                try {
                    // 睡眠 5 分钟
                    sleep(Duration.minute * 5)
                    // 清理超时条目
                    _pendingToolCallManager.cleanupTimedOut()
                } catch (e: Exception) {
                    LogUtils.error("[WebMCPController] Cleanup task error: ${e.message}")
                }
            }
        }
    }
}
