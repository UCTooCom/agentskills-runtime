/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.uctoo.mock

import magic.app.controllers.uctoo.mock.MockController
import magic.app.core.router.Router

/**
 * MockRoute - Mock数据路由配置
 *
 * 提供dashboard页面所需的mock数据接口路由
 */
public class MockRoute {
    private var router: Router
    private var controller: MockController
    
    public init(router: Router, controller: MockController) {
        this.router = router
        this.controller = controller
    }
    
    /**
     * 注册路由
     */
    public func register(): Router {
        // GET /api/user/getdata - 获取用户数据选项
        router.get("/api/user/getdata", controller.getUserData)
        
        // GET /api/user/getrpractic - 获取实践数据
        router.get("/api/user/getrpractic", controller.getUserPractic)
        
        // GET /api/user/getrtrain - 获取培训数据
        router.get("/api/user/getrtrain", controller.getUserTrain)
        
        // POST /api/user/getselect - 切换数据源
        router.post("/api/user/getselect", controller.getUserChange)
        
        return router
    }
}
