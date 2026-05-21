package magic.app.routes.uctoo.mcp

//#region AutoCreateCode
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
        // 先注册自定义路由，避免被动态路由 :id 匹配
        registerCustomRoutes()

        // GET /api/v1/uctoo/mcp/stream - MCP 管理页面
        router.get("/api/v1/uctoo/mcp/stream", controller.handleStream)
        // POST /api/v1/uctoo/mcp/stream - MCP 消息处理（工具注册、工具调用、消息发送等）
        router.post("/api/v1/uctoo/mcp/stream", controller.handleStream)
        return router
    }

//#endregion AutoCreateCode
    
    /**
     * 注册自定义路由
     * 在此方法中添加定制开发的路由
     */
    public func registerCustomRoutes(): Router {
        
        return router
    }
}