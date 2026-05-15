/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.webmcp

import magic.app.core.router.Router
import magic.app.controllers.uctoo.webmcp.WebMCPController
import magic.core.skill.SkillManager
import magic.core.model.ChatModel
import magic.log.LogUtils

/**
 * WebMCP 路由配置
 * 注册 WebSocket 和 HTTP 端点
 */
public class WebMCPRoutes {
    private let _router: Router
    private let _controller: WebMCPController

    public init(router: Router, skillManager: SkillManager, chatModel: ChatModel) {
        this._router = router
        this._controller = WebMCPController(skillManager, chatModel)
    }

    /**
     * 注册所有 WebMCP 路由
     */
    public func register(): Unit {
        registerWebSocketRoutes()
        registerHttpRoutes()
        LogUtils.info("WebMCP routes registered successfully")
    }

    /**
     * 注册 WebSocket 路由
     */
    private func registerWebSocketRoutes(): Unit {
        // WebMCP 主端点 - 与前端 webmcp-sdk 通信
        _router.get("/api/v1/uctoo/webmcp/mcp", { req, res =>
            _controller.handleConnection(req, res)
        })
        
        // WebMCP 备用端点 - 兼容标准 MCP 协议
        _router.get("/api/v1/webmcp/mcp", { req, res =>
            _controller.handleConnection(req, res)
        })
        
        LogUtils.debug("WebMCP WebSocket routes registered")
    }

    /**
     * 注册 HTTP 路由
     */
    private func registerHttpRoutes(): Unit {
        // 获取活跃会话数
        _router.get("/api/v1/uctoo/webmcp/sessions/count", { req, res =>
            let count = _controller.getActiveSessionCount()
            res.status(200).json("{\"count\":${count}}")
        })
        
        // 健康检查
        _router.get("/api/v1/uctoo/webmcp/health", { req, res =>
            res.status(200).json("{\"status\":\"ok\",\"service\":\"webmcp\"}")
        })
        
        // 远程控制端点 - 用于生成扫码连接的二维码数据
        _router.get("/api/v1/uctoo/webmcp/remote", { req, res =>
            _controller.handleRemoteRequest(req, res)
        })
        
        // streamableHttp 端点 - 支持前端通过 streamableHttp 类型连接
        _router.post("/api/v1/uctoo/webmcp/mcp", { req, res =>
            _controller.handleStreamableHttp(req, res)
        })
        
        // streamableHttp 备用端点 - 兼容标准 MCP 协议
        _router.post("/api/v1/webmcp/mcp", { req, res =>
            _controller.handleStreamableHttp(req, res)
        })
        
        LogUtils.debug("WebMCP HTTP routes registered")
    }
}
