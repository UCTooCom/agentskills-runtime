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
import http_lib.server.{WebSocketConn, ConnectionController, WebSocketOpcode}
import http_lib.message.{HttpRequest as LibHttpRequest, HttpResponse as LibHttpResponse}
import http_lib.core.HttpStatus
import http_lib.connection.Connection
import stdx.encoding.json.{JsonObject, JsonString, JsonBool, JsonValue, JsonArray, JsonInt}
import std.time.DateTime
import std.time.*
import std.sync.AtomicBool
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
     * 设置 CORS 响应头
     * 注意：当使用 credentials 时，不能使用通配符 *，需要回显请求的 Origin
     */
    private func setCorsHeaders(req: HttpRequest, res: HttpResponse): HttpResponse {
        let origin = req.header("Origin")
        // 在 credentials 模式下，必须回显具体 origin 而不是使用 *
        let allowOrigin = if (let Some(o) <- origin) {
            o
        } else {
            "*"
        }
        res.header("Access-Control-Allow-Origin", allowOrigin)
           .header("Access-Control-Allow-Credentials", "true")
        return res
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
            setCorsHeaders(req, res)
            res.status(400)
               .header("Content-Type", "application/json")
               .send("{\"error\": \"Empty request body\"}")
            return
        }

        LogUtils.info("WebMCP request body: ${body}")

        // 设置 CORS 头部
        setCorsHeaders(req, res)
           .header("Access-Control-Allow-Methods", "POST, OPTIONS")
           .header("Access-Control-Allow-Headers", "*")
        
        try {
            let (method, requestId) = parseMethodAndId(body)
            if (method.startsWith("notifications/")) {
                LogUtils.info("WebMCP notification early return: ${method}, skipping protocol initialization")
                if (requestId.isSome()) {
                    let resultObj = JsonObject()
                    resultObj.put("success", JsonBool(true))
                    resultObj.put("message", JsonString("Notification received"))
                    let responseObj = JsonObject()
                    responseObj.put("jsonrpc", JsonString("2.0"))
                    responseObj.put("result", resultObj)
                    responseObj.put("id", requestId.getOrThrow())
                    res.status(200).json(responseObj.toString())
                } else {
                    res.status(204).send("")
                }
                return
            }
            
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
                // v24 真流式：劫持 POST /mcp 连接，SSE 事件（reasoning-start/delta/end、
                // response.output_text.delta、response.completed）实时写入该连接，
                // 前端从 fetch 响应流增量解析，实现真正的流式思维链。
                // 恢复说明：此前因"连接劫持导致后续请求 body 丢失 → 400"改走非劫持模式，
                // 但 v21 已查明该 400 的真正根因是 http_lib request.cj 的 copyTo 参数顺序 bug
                // （bodyRead 误传为 srcStart，多段读取时越界），与连接劫持无关，已修复。
                LogUtils.info("WebMCP streaming response requested (real-stream hijack mode)")
                handleStreamableHttpRealStream(req, res, body)
                return
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
     * 真流式 HTTP 响应（P2-3.3）
     *
     * 利用 http_lib ConnectionController 劫持连接，实现真流式 HTTP 响应。
     * SSE 事件通过 conn.write+flush 逐步推送，最后写入 MCP JSON-RPC 响应。
     *
     * 仓颉规范约束（已复核 design.md D-5/D-7）：
     * 1. spawn 闭包捕获语义：仓颉 spawn { ... } 创建新协程，
     *    闭包内引用的 req、res、body、controller、conn、sessionId 等应为 let 不可变绑定；
     *    若需在协程间共享可变状态（如停止标志），必须使用 AtomicBool / Ref<T> 等线程安全容器，
     *    禁止直接捕获 var。
     * 2. 连接生命周期：劫持连接后，主请求处理流程不得再操作 res
     *    （此时由 conn.write() 直接写入裸字节流）。
     *    conn.write() + conn.flush() 必须成对调用，确保 SSE 事件立即送达浏览器缓冲区。
     * 3. 异常不外泄：spawn 块内的异常必须捕获并记录日志，
     *    禁止让异常逃逸导致协程静默崩溃（无错误堆栈）。
     * 4. SSE 事件通过 SSEConnectionManager 注册的 sessionId→writer 回调推送，
     *    writer = message => conn.write(message) + conn.flush()。
     *
     * 异常映射：
     * - 连接劫持失败（req.connection 为 None）→ 降级调用 handleStreamableHttp 假流式分支
     * - conn.write 异常 → 记录 error 日志，关闭连接
     *
     * 注意：本方法需要 http_lib ConnectionController 的底层 API 支持。
     * 当前实现为架构占位，具体 conn.write/flush 调用需根据实际 http_lib 版本确认。
     */
    public func handleStreamableHttpRealStream(req: HttpRequest, res: HttpResponse, body: String): Unit {
        LogUtils.info("WebMCP real stream HTTP request received")

        // 前置条件检查：body 为空时返回 400
        if (body.isEmpty()) {
            LogUtils.warn("WebMCP real stream request body is empty")
            setCorsHeaders(req, res)
            res.status(400)
               .header("Content-Type", "application/json")
               .send("{\"error\": \"Empty request body\"}")
            return
        }

        // 设置 CORS 头部
        setCorsHeaders(req, res)
           .header("Access-Control-Allow-Methods", "POST, OPTIONS")
           .header("Access-Control-Allow-Headers", "*")

        // 解析方法和 ID
        let (method, requestId) = parseMethodAndId(body)

        // notifications/* 方法提前返回（非流式，无需劫持连接）
        if (method.startsWith("notifications/")) {
            LogUtils.info("WebMCP real stream notification early return: ${method}")
            if (requestId.isSome()) {
                let resultObj = JsonObject()
                resultObj.put("success", JsonBool(true))
                resultObj.put("message", JsonString("Notification received"))
                let responseObj = JsonObject()
                responseObj.put("jsonrpc", JsonString("2.0"))
                responseObj.put("result", resultObj)
                responseObj.put("id", requestId.getOrThrow())
                res.status(200).json(responseObj.toString())
            } else {
                res.status(204).send("")
            }
            return
        }

        // 获取会话 ID 和用户 ID
        let sessionId = "webmcp-default"
        let userId = _extractUserId(req)

        // 初始化或获取 protocol 实例
        let protocol = if (_sessions.contains(sessionId)) {
            let p = _sessions.get(sessionId).getOrThrow()
            _initProtocolInfrastructure(p, sessionId, userId)
            p
        } else {
            let p = WebMCPProtocol(_skillManager, _chatModel, getMainAgentDef())
            _initProtocolInfrastructure(p, sessionId, userId)
            _sessions.add(sessionId, p)
            p
        }

        // 真流式实现：通过 http_lib ConnectionController 劫持 POST /webmcp/mcp 连接，
        // 写入 SSE 响应头，注册 sessionId→writer 回调到 SSEConnectionManager，
        // 调用 protocol.handleCompletionCompleteStream 异步执行，
        // SSE 事件在执行过程中通过 writer 回调实时 conn.write+flush 推送到前端，
        // 最后写入 MCP JSON-RPC 2.0 响应并关闭连接。
        //
        // 参考 handleSSE（第 722-794 行）的连接劫持模式。
        //
        // 仓颉规范约束：
        // 1. spawn 闭包捕获：req、res、body、conn 等应为 let 不可变绑定；
        //    线程间共享可变状态必须使用 AtomicBool / Ref<T> 等线程安全容器。
        // 2. 连接生命周期：劫持连接后，主请求处理流程不得再操作 res
        //    （此时由 conn.write() 直接写入裸字节流）。
        // 3. conn.write() + conn.flush() 必须成对调用，确保 SSE 事件立即送达浏览器缓冲区。
        // 4. 异常不外泄：spawn 块内的异常必须捕获并记录日志，
        //    禁止让异常逃逸导致协程静默崩溃。
        match (req.connection) {
            case Some(conn) =>
                // === 真流式分支：劫持连接 ===
                let controller = ConnectionController(conn)

                // 写入 SSE 响应头（Content-Type: text/event-stream）
                // 参考 handleSSE 第 743 行，不声明 chunked，用 Connection: close 让浏览器按裸字节流模式解析
                let sseHeader = "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nCache-Control: no-cache\r\nConnection: close\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
                controller.write(unsafe { sseHeader.rawData() })
                req.takenOver = true

                LogUtils.info("[WebMCPController] Real stream connection hijacked: sessionId=${sessionId}")

                // 注册 sessionId→writer 回调到 SSEConnectionManager
                // writer 回调：将 SSE 消息字符串写入连接并 flush
                // SSEConnectionManager.pushMessage 内部构建 "event: ${eventType}\ndata: ${data}\n\n" 格式
                _sseConnectionManager.registerConnection(sessionId, { message: String =>
                    try {
                        conn.write(unsafe { message.rawData() })
                        conn.flush()
                    } catch (e: Exception) {
                        LogUtils.warn("[WebMCPController] Real stream SSE write failed: ${e.message}")
                    }
                })

                // 推送 connected 事件，通知前端 SSE 连接已建立
                conn.write(unsafe { "event: connected\ndata: {\"sessionId\":\"${sessionId}\"}\n\n".rawData() })
                conn.flush()

                // 启动 SSE 心跳保活协程（每 15 秒推送 ": ping\n\n"）
                // 参考 handleSSE 第 760-772 行的心跳保活模式
                let stopHeartbeat = AtomicBool(false)
                spawn {
                    while (!stopHeartbeat.load()) {
                        sleep(Duration.second * 15)
                        if (stopHeartbeat.load()) {
                            break
                        }
                        try {
                            conn.write(unsafe { ": ping ${DateTime.now()}\n\n".rawData() })
                            conn.flush()
                        } catch (e: Exception) {
                            LogUtils.info("[WebMCPController] Real stream heartbeat failed, connection closed: sessionId=${sessionId}")
                            break
                        }
                    }
                }

                // 调用 protocol.handleCompletionCompleteStream 异步执行
                // 执行过程中 SSE 事件通过注册的 writer 回调实时 conn.write+flush 推送到前端
                // 方法返回最终的 MCP JSON-RPC 2.0 响应字符串
                var streamResponse = ""
                var streamSucceeded = false
                try {
                    // 解析请求体为 JsonObject
                    let jsonObj = JsonValue.fromStr(body)
                    if (jsonObj is JsonObject) {
                        let obj = jsonObj.asObject()
                        streamResponse = protocol.handleCompletionCompleteStream(obj)
                        streamSucceeded = true
                        LogUtils.debug("[WebMCPController] Real stream response: ${streamResponse}")
                    } else {
                        LogUtils.error("[WebMCPController] Real stream: invalid JSON body")
                        // 推送错误事件到前端
                        conn.write(unsafe { "event: response.failed\ndata: {\"error\":\"Invalid JSON body\"}\n\n".rawData() })
                        conn.flush()
                    }
                } catch (e: Exception) {
                    LogUtils.error("[WebMCPController] Real stream error: ${e.message}")
                    // 推送错误事件到前端
                    let errorMsg = e.message
                    conn.write(unsafe { "event: response.failed\ndata: {\"error\":\"${errorMsg}\"}\n\n".rawData() })
                    conn.flush()
                }

                // 停止心跳保活协程
                stopHeartbeat.store(true)

                // 流式完成后，写入最终的 MCP JSON-RPC 2.0 响应
                // 响应格式：event: response.completed\ndata: ${MCP响应}\n\n
                if (streamSucceeded && !streamResponse.isEmpty()) {
                    try {
                        let finalEvent = "event: response.completed\ndata: ${streamResponse}\n\n"
                        conn.write(unsafe { finalEvent.rawData() })
                        conn.flush()
                        LogUtils.info("[WebMCPController] Real stream completed: sessionId=${sessionId}")
                    } catch (e: Exception) {
                        LogUtils.error("[WebMCPController] Real stream final write failed: ${e.message}")
                    }
                }

                // 注销 SSEConnectionManager 回调，关闭连接
                _sseConnectionManager.removeConnection(sessionId)
                try {
                    conn.close()
                } catch (e: Exception) {
                    LogUtils.warn("[WebMCPController] Real stream connection close failed: ${e.message}")
                }

            case None =>
                // === 降级分支：连接不可劫持，降级为 handleStreamableHttp 假流式 ===
                // 参考 spec 5.4.3.2 "连接劫持失败 → 降级为 spawn + res.send() 假流式"
                LogUtils.warn("[WebMCPController] Real stream: connection not hijackable, falling back to handleStreamableHttp")
                handleStreamableHttp(req, res)
        }
    }
    
    /**
     * 解析请求体中的 stream 标志
     */
    private func parseStreamFlag(body: String): Bool {
        try {
            let jsonValue = JsonValue.fromStr(body)
            // v24 修复：前端 _chatViaWebMCP 直接 POST JsonObject（{method, params:{stream:true}}），
            // 此前只解析 JsonArray 包装格式，JsonObject 恒返回 false → isStream 恒为 false
            // → 请求永远走阻塞分支，SSE 事件无法增量推送（表现为接口一直"待处理"，
            // 思维链和正文最后一次性返回渲染）。
            if (jsonValue is JsonObject) {
                let obj = jsonValue.asObject()
                let params = obj.get("params")
                if (params.isSome() && params.getOrThrow() is JsonObject) {
                    let paramsObj = params.getOrThrow().asObject()
                    let stream = paramsObj.get("stream")
                    if (stream.isSome() && stream.getOrThrow() is JsonBool) {
                        return stream.getOrThrow().asBool().getValue()
                    }
                }
            }
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
    
    private func parseMethodAndId(body: String): (String, ?JsonValue) {
        try {
            let jsonValue = JsonValue.fromStr(body)
            if (jsonValue is JsonArray) {
                let arr = jsonValue.asArray()
                if (arr.size() > 0) {
                    let item = arr.get(0)
                    if (item.isSome() && item.getOrThrow() is JsonObject) {
                        let obj = item.getOrThrow().asObject()
                        let method = obj.get("method")
                        let methodStr = if (method.isSome() && method.getOrThrow() is JsonString) {
                            method.getOrThrow().asString().getValue()
                        } else {
                            ""
                        }
                        let requestId = obj.get("id")
                        return (methodStr, requestId)
                    }
                }
                return ("", None<JsonValue>)
            } else if (jsonValue is JsonObject) {
                let obj = jsonValue.asObject()
                let method = obj.get("method")
                let methodStr = if (method.isSome() && method.getOrThrow() is JsonString) {
                    method.getOrThrow().asString().getValue()
                } else {
                    ""
                }
                let requestId = obj.get("id")
                return (methodStr, requestId)
            } else {
                return ("", None<JsonValue>)
            }
        } catch (_: Exception) {
            return ("", None<JsonValue>)
        }
    }
    
    /**
     * 处理 WebSocket 连接（使用 http_lib HttpRequest）
     */
    public func handleConnection(req: LibHttpRequest): LibHttpResponse {
        LogUtils.info("WebMCP WebSocket connection attempt")

        match (req.connection) {
            case Some(conn) =>
                let controller = ConnectionController(conn)
                try {
                    controller.upgradeToWebSocket(req)
                } catch (ex: Exception) {
                    return LibHttpResponse.text(HttpStatus.BAD_REQUEST, "WebSocket upgrade failed: ${ex.message}")
                }

                let wsConn = WebSocketConn(conn)
                let sessionId = UUID.random().toString()

                LogUtils.info("WebMCP WebSocket connection established, sessionId: ${sessionId}")

                let userId = _extractUserIdFromRequest(req)

                let protocol = WebMCPProtocol(_skillManager, _chatModel, getMainAgentDef())
                _initProtocolInfrastructure(protocol, sessionId, userId)
                _sessions.add(sessionId, protocol)

                handleMessageLoop(wsConn, sessionId, protocol)

                _sessions.remove(sessionId)
                LogUtils.info("WebMCP WebSocket session closed: ${sessionId}")
                return LibHttpResponse.empty(HttpStatus.OK)
            case None =>
                return LibHttpResponse.text(HttpStatus.INTERNAL_SERVER_ERROR, "Connection hijack not supported")
        }
    }

    /**
     * 处理消息循环
     */
    private func handleMessageLoop(websocket: WebSocketConn, sessionId: String, protocol: WebMCPProtocol): Unit {
        var buffer = ""

        var msgOpt = websocket.readMessage()
        while (true) {
            match (msgOpt) {
                case Some(msg) =>
                    if (msg.isText()) {
                        let message = msg.text()
                        LogUtils.debug("WebMCP received text message: ${message}")
                        buffer = buffer + message
                        buffer = processMessages(buffer, websocket, protocol)
                    } else if (msg.isBinary()) {
                        LogUtils.error("WebMCP received binary message (unsupported)")
                        websocket.writeText("{\"error\": \"Binary messages not supported\"}\n")
                    } else if (msg.isClose()) {
                        LogUtils.info("WebMCP WebSocket close frame received")
                        break
                    } else if (msg.isPing()) {
                        websocket.writePong(msg.data)
                    }
                case None =>
                    LogUtils.error("WebMCP WebSocket connection closed")
                    break
            }
            msgOpt = websocket.readMessage()
        }
    }

    /**
     * 处理消息缓冲区中的完整消息
     */
    private func processMessages(buffer: String, websocket: WebSocketConn, protocol: WebMCPProtocol): String {
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
    private func processMessage(message: String, websocket: WebSocketConn, protocol: WebMCPProtocol): Unit {
        try {
            let response = protocol.handleMessage(message)
            LogUtils.debug("WebMCP sending response: ${response}")

            if (!response.isEmpty()) {
                websocket.writeText("${response}\n")
            }
        } catch (e: Exception) {
            LogUtils.error("WebMCP message processing error: ${e.message}")
            let errorResponse = "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32603,\"message\":\"${e.message}\"}}\n"
            websocket.writeText(errorResponse)
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
        setCorsHeaders(req, res)
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
        setCorsHeaders(req, res)
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

        let sessionIdOpt = req.queryParam("sessionId")
        if (sessionIdOpt.isNone()) {
            res.status(400)
               .header("Content-Type", "application/json")
               .send("{\"error\": \"Missing 'sessionId' query parameter\"}")
            return
        }
        let sessionId = sessionIdOpt.getOrThrow()

        match (req.connection) {
            case Some(conn) =>
                let controller = ConnectionController(conn)
                // v18修复：去掉裸写的 Transfer-Encoding: chunked 头，改用 SSE 标准的裸 keep-alive 字节流
                // 根因：原裸写 chunked 头但后续 conn.write()+flush() 从不按 chunked 分块格式封装
                //       （每块需 \r\n<块大小>\r\n 前缀 + \r\n 后缀，结束需 0\r\n\r\n），
                //       浏览器按 chunked 解析时遇到裸 SSE 字节 → 非法分块 → net::ERR_INVALID_CHUNKED_ENCODING
                // 修复：SSE 是无限流，不应声明 chunked（除非每块手动封装）。改用 Connection: close 让
                //       浏览器按"读到连接关闭即响应结束"的裸字节流模式解析，避免分块编码校验失败。
                controller.write(unsafe { "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nCache-Control: no-cache\r\nConnection: close\r\nAccess-Control-Allow-Origin: *\r\n\r\n".rawData() })
                req.takenOver = true

                _sseConnectionManager.registerConnection(sessionId, { message: String =>
                    try {
                        conn.write(unsafe { message.rawData() })
                        conn.flush()
                    } catch (e: Exception) {
                        LogUtils.warn("[WebMCPController] SSE write failed: ${e.message}")
                    }
                })

                LogUtils.info("[WebMCPController] SSE connection registered: sessionId=${sessionId}")

                conn.write(unsafe { "event: connected\ndata: {\"sessionId\":\"${sessionId}\"}\n\n".rawData() })
                conn.flush()

                spawn {
                    while (true) {
                        sleep(Duration.second * 15)
                        try {
                            conn.write(unsafe { ": ping ${DateTime.now()}\n\n".rawData() })
                            conn.flush()
                        } catch (e: Exception) {
                            LogUtils.info("[WebMCPController] SSE connection closed: sessionId=${sessionId}")
                            _sseConnectionManager.removeConnection(sessionId)
                            break
                        }
                    }
                }

            case None =>
                LogUtils.warn("[WebMCPController] SSE connection not available, falling back to res.send")
                // v18修复：fallback 分支同样不声明 chunked，且只 send 一次完整响应避免重复写头/分块
                res.status(200)
                   .header("Content-Type", "text/event-stream")
                   .header("Cache-Control", "no-cache")
                   .header("Connection", "close")
                setCorsHeaders(req, res)

                // fallback 无法劫持连接做无限流，只能返回单次初始事件；后续实时事件依赖主分支的 conn.write()
                LogUtils.warn("[WebMCPController] SSE fallback: connection not hijackable, real-time events will not be pushed (use main branch instead)")
                _sseConnectionManager.registerConnection(sessionId, { message: String =>
                    LogUtils.info("[WebMCPController] SSE fallback register (events will not be delivered without hijackable connection): ${message}")
                })

                LogUtils.info("[WebMCPController] SSE connection registered (fallback): sessionId=${sessionId}")

                let initEvent = "event: connected\ndata: {\"sessionId\":\"${sessionId}\"}\n\n"
                res.send(initEvent)
        }
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
     * 从 http_lib HttpRequest 中提取用户 ID
     * 通过请求头获取用户 ID（用于菜单数据查询）
     * 实际用户 ID 也可通过 WebSocket 消息传递
     */
    private func _extractUserIdFromRequest(req: LibHttpRequest): String {
        match (req.headers.get("x-user-id")) {
            case Some(userId) => userId
            case None => ""
        }
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
