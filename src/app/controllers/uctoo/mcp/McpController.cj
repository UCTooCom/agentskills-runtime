package magic.app.controllers.uctoo.mcp

import magic.app.services.webmcp.WebMCPProtocol
import magic.app.core.http.{HttpRequest, HttpResponse, HttpMethod}
import magic.app.core.response.APIError
import magic.core.skill.SkillManager
import magic.core.model.ChatModel
import magic.log.LogUtils
import stdx.encoding.json.{JsonValue, JsonObject, JsonString}
import std.collection.{HashMap, ArrayList}
import f_util.UUID

public class McpController {
    private var _skillManager: ?SkillManager
    private var _chatModel: ?ChatModel
    // 会话级别的 WebMCP 协议处理器缓存
    private var _protocols = HashMap<String, WebMCPProtocol>()

    /**
     * 无参数构造函数（向后兼容）
     */
    public init() {
        this._skillManager = None
        this._chatModel = None
    }

    /**
     * 带参数构造函数
     */
    public init(skillManager: SkillManager, chatModel: ChatModel) {
        this._skillManager = Some(skillManager)
        this._chatModel = Some(chatModel)
    }

    /**
     * 处理 MCP 流式接口
     * POST /api/v1/uctoo/mcp/stream
     * 支持 MCP SSE 协议，处理工具注册、工具调用、消息发送等请求
     */
    public func handleStream(req: HttpRequest, res: HttpResponse): Unit {
        try {
            LogUtils.info("MCP stream request received")
            
            // 设置 CORS 头部
            res.header("Access-Control-Allow-Origin", "*")
               .header("Access-Control-Allow-Methods", "POST, OPTIONS")
               .header("Access-Control-Allow-Headers", "*")
            
            // 处理 OPTIONS 请求
            if (req.method == HttpMethod.OPTIONS) {
                res.status(200)
                   .header("Content-Type", "application/json")
                   .send("{}")
                return
            }
            
            let body = req.body
            if (body.isEmpty()) {
                // GET 请求返回管理页面
                return handleGetRequest(res)
            }
            
            // POST 请求处理 MCP 消息
            handlePostRequest(body, req, res)
            
        } catch (e: Exception) {
            LogUtils.error("MCP stream error: ${e.message}")
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }
    
    /**
     * 处理 GET 请求，返回管理页面
     */
    private func handleGetRequest(res: HttpResponse): Unit {
        let htmlContent = """
<!DOCTYPE html>
<html>
<head>
    <title>MCP Server Stream</title>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            border-bottom: 2px solid #4CAF50;
            padding-bottom: 10px;
        }
        .info {
            background: #e7f3ff;
            padding: 15px;
            border-radius: 4px;
            margin: 20px 0;
        }
        .endpoint {
            background: #f9f9f9;
            padding: 10px;
            margin: 10px 0;
            border-left: 3px solid #4CAF50;
        }
        code {
            background: #f4f4f4;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: 'Courier New', monospace;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>MCP Server with HTTP Streaming</h1>

        <div class="info">
            <p><strong>AgentSkills Runtime MCP Interface</strong></p>
            <p>This endpoint provides an embedded web UI for MCP server management and skill execution.</p>
        </div>

        <h2>Available Endpoints</h2>

        <div class="endpoint">
            <h3>WebSocket Chat</h3>
            <p><code>WS /api/v1/uctoo/ws/chat</code></p>
            <p>Real-time chat interface with skill-aware AI assistant.</p>
        </div>

        <div class="endpoint">
            <h3>Skills Management</h3>
            <p><code>GET /api/v1/uctoo/skills</code> - List runtime skills</p>
            <p><code>POST /api/v1/uctoo/skills/install</code> - Install a skill</p>
            <p><code>POST /api/v1/uctoo/skills/execute</code> - Execute a skill</p>
        </div>

        <div class="endpoint">
            <h3>CRUD Operations</h3>
            <p><code>GET /api/v1/uctoo/agent_skills</code> - List all skills</p>
            <p><code>GET /api/v1/uctoo/agent_skills/:id</code> - Get skill by ID</p>
            <p><code>POST /api/v1/uctoo/agent_skills/add</code> - Add new skill</p>
            <p><code>POST /api/v1/uctoo/agent_skills/edit</code> - Edit skill</p>
            <p><code>POST /api/v1/uctoo/agent_skills/del</code> - Delete skill</p>
        </div>

        <div class="endpoint">
            <h3>Health Check</h3>
            <p><code>GET /api/v1/health</code> - Service health status</p>
            <p><code>GET /api/v1/info</code> - Service information</p>
        </div>

        <h2>Features</h2>
        <ul>
            <li>Skill-aware AI assistant with WebSocket support</li>
            <li>Skill installation from Git repositories and local paths</li>
            <li>Skill execution with parameter validation</li>
            <li>Public skill search (GitHub, Gitee, AtomGit)</li>
            <li>Hot reload for skill updates</li>
            <li>Token management and session handling</li>
        </ul>

        <div class="info">
            <p><strong>Version:</strong> 4.0.0</p>
            <p><strong>Language:</strong> Cangjie</p>
            <p><strong>Framework:</strong> uctoo v4</p>
        </div>
    </div>
</body>
</html>
"""
            res.status(200).header("Content-Type", "text/html; charset=utf-8").send(htmlContent)
    }
    
    /**
     * 处理 POST 请求，处理 MCP 消息
     */
    private func handlePostRequest(body: String, req: HttpRequest, res: HttpResponse): Unit {
        LogUtils.debug("MCP stream POST body: ${body}")
        
        // 解析请求体中的 sessionId
        var sessionId = ""
        let jsonValue = JsonValue.fromStr(body)
        if (jsonValue is JsonObject) {
            let obj = jsonValue.asObject()
            
            // 尝试从不同位置获取 sessionId
            let sessionIdOpt = obj.get("sessionId")
            if (sessionIdOpt.isSome()) {
                let sid = sessionIdOpt.getOrThrow()
                if (sid is JsonString) {
                    sessionId = sid.asString().getValue()
                }
            }
            
            // 从 params 中获取
            if (sessionId.isEmpty()) {
                let params = obj.get("params")
                if (params.isSome()) {
                    let p = params.getOrThrow()
                    if (p is JsonObject) {
                        let pObj = p.asObject()
                        let sidOpt = pObj.get("sessionId")
                        if (sidOpt.isSome()) {
                            let sid = sidOpt.getOrThrow()
                            if (sid is JsonString) {
                                sessionId = sid.asString().getValue()
                            }
                        }
                    }
                }
            }
        }
        
        // 如果没有 sessionId，生成一个新的
        if (sessionId.isEmpty()) {
            sessionId = UUID.random().toString()
            LogUtils.info("MCP creating new session: ${sessionId}")
        }
        
        // 获取或创建协议处理器
        let protocol = getOrCreateProtocol(sessionId)
        
        // 处理消息
        let response = protocol.handleMessage(body)
        LogUtils.debug("MCP response: ${response}")
        
        // 设置响应头并发送响应
        res.status(200)
           .header("Content-Type", "application/json")
           .json(response)
    }
    
    /**
     * 获取或创建 WebMCPProtocol 实例
     */
    private func getOrCreateProtocol(sessionId: String): WebMCPProtocol {
        let existing = _protocols.get(sessionId)
        
        if (existing.isSome()) {
            return existing.getOrThrow()
        }
        
        // 创建新的协议处理器
        let protocol = WebMCPProtocol(_skillManager, _chatModel)
        protocol.setSessionInfo(sessionId, "")
        _protocols.add(sessionId, protocol)
        
        LogUtils.info("Created new WebMCP protocol for session: ${sessionId}")
        return protocol
    }
    
    /**
     * 获取活跃会话数量
     */
    public func getActiveSessionCount(): Int32 {
        return Int32(_protocols.size)
    }
}