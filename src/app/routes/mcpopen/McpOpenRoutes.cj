package magic.app.routes.mcpopen

import magic.app.core.router.Router
import magic.app.controllers.uctoo.mcpopen.McpOpenController

public class McpOpenRoutes {
    private var router: Router
    private var controller: McpOpenController

    public init(router: Router, controller: McpOpenController) {
        this.router = router
        this.controller = controller
    }

    public func register(): Router {
        router.post("/api/v1/uctoo/mcp/open/call", controller.handleCall)
        router.get("/api/v1/uctoo/mcp/open/tools", controller.handleListTools)
        return router
    }
}