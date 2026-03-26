package magic.app.routes.uctoo.ws

import magic.app.controllers.uctoo.ws.WsChatController
import magic.app.core.router.Router

public class WsRoute {
    private var router: Router
    private var controller: WsChatController

    public init(router: Router, controller: WsChatController) {
        this.router = router
        this.controller = controller
    }

    /**
     * 注册 WebSocket 路由
     */
    public func register(): Router {
        // WS /api/v1/uctoo/ws/chat - WebSocket 聊天接口
        router.get("/api/v1/uctoo/ws/chat", controller.handleChat)
        return router
    }
}
