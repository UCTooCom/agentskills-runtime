package magic.app.controllers.uctoo.mcp

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.response.APIError
import std.collection.HashMap

public class McpController {

    public init() {}

    /**
     * 处理 MCP 流式接口
     * GET /api/v1/uctoo/mcp/stream
     */
    public func handleStream(req: HttpRequest, res: HttpResponse): Unit {
        try {
            // MCP Server with HTTP Streaming
            // 返回一个 HTML 页面，提供 MCP 服务器管理和技能执行的 Web UI

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
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }
}
