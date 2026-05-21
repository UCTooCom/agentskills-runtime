package magic.app.routes.uctoo.ws

//#region AutoCreateCode
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
        // 先注册自定义路由，避免被动态路由 :id 匹配
        registerCustomRoutes()

        // WS /api/v1/uctoo/ws/chat - WebSocket 聊天接口
        router.get("/api/v1/uctoo/ws/chat", controller.handleChat)
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
