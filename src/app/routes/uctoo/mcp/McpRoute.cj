package magic.app.routes.uctoo.mcp

import magic.app.controllers.uctoo.mcp.McpController
import magic.app.core.router.Router

public class McpRoute {
    private var router: Router
    private var controller: McpController
    
    public init(router: Router, controller: McpController) {
        this.router = router
        this.controller = controller
    }
    
    /**
     * 注册 MCP 路由
     */
    public func register(): Router {
        // GET /api/v1/uctoo/mcp/stream - MCP 流式接口
        router.get("/api/v1/uctoo/mcp/stream", controller.handleStream)
        return router
    }
}
