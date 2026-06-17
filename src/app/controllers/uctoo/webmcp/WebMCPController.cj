/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.webmcp

import magic.app.services.webmcp.WebMCPProtocol
import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.core.skill.SkillManager
import magic.core.model.ChatModel
import magic.core.agent.{AgentDefinition, AgentLoadManager}
import magic.log.LogUtils
import stdx.net.http.{HttpContext, WebSocket, WebSocketFrameType, HttpHeaders}
import stdx.encoding.json.{JsonObject, JsonString, JsonBool, JsonValue, JsonArray}
import std.time.DateTime
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

    public init(skillManager: SkillManager, chatModel: ChatModel, agentLoadManager: AgentLoadManager) {
        this._skillManager = skillManager
        this._chatModel = chatModel
        this._agentLoadManager = agentLoadManager
    }

    private func getMainAgentDef(): ?AgentDefinition {
        _agentLoadManager.getMainAgent()
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
        if (body.isEmpty()) {
            res.status(400)
               .header("Access-Control-Allow-Origin", "*")
               .header("Content-Type", "application/json")
               .send("{\"error\": \"Empty request body\"}")
            return
        }
        
        // 设置 CORS 头部
        res.header("Access-Control-Allow-Origin", "*")
           .header("Access-Control-Allow-Methods", "POST, OPTIONS")
           .header("Access-Control-Allow-Headers", "*")
        
        try {
            // 复用或创建协议处理器（基于 session 保持 Agent 会话状态连续性）
            let sessionId = "webmcp-default"
            let protocol = if (_sessions.contains(sessionId)) {
                _sessions.get(sessionId).getOrThrow()
            } else {
                let p = WebMCPProtocol(_skillManager, _chatModel, getMainAgentDef())
                p.setSessionInfo(sessionId, "")
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
        
        // 创建协议处理器（使用从AGENTS.md加载的动态Agent）
        let protocol = WebMCPProtocol(_skillManager, _chatModel, getMainAgentDef())
        protocol.setSessionInfo(sessionId, "")
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
}
