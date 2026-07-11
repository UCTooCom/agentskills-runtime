/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.uctoo.tasks

import magic.app.controllers.uctoo.tasks.PublicTasksController
import magic.app.core.router.Router

/**
 * PublicTasksRoute - 公开任务路由注册
 *
 * 注册无需登录即可访问的任务相关路由：
 * - GET /api/v1/uctoo/tasks/public/home-stats
 * - GET /api/v1/uctoo/tasks/public/:limit/:page
 * - GET /api/v1/uctoo/tasks/public/:id
 */
public class PublicTasksRoute {
    private var router: Router
    private var controller: PublicTasksController

    public init(router: Router, controller: PublicTasksController) {
        this.router = router
        this.controller = controller
    }

    public func register(): Router {
        // 首页统计数据（必须放在 :id 之前，避免被动态路由匹配）
        router.get("/api/v1/uctoo/tasks/public/home-stats", controller.getHomeStats)
        // 公开任务列表
        router.get("/api/v1/uctoo/tasks/public/:limit/:page", controller.getPublicList)
        // 公开任务详情
        router.get("/api/v1/uctoo/tasks/public/:id", controller.getPublicDetail)
        return router
    }
}
