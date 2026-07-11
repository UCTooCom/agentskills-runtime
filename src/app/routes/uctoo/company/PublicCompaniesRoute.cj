/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.uctoo.company

import magic.app.controllers.uctoo.company.PublicCompaniesController
import magic.app.core.router.Router

/**
 * PublicCompaniesRoute - 公开组织路由注册
 *
 * 注册无需登录即可访问的组织相关路由：
 * - GET /api/v1/uctoo/company/public/:limit/:page
 * - GET /api/v1/uctoo/company/public/:id
 * - GET /api/v1/uctoo/company/public/:id/tasks/:limit/:page
 * - GET /api/v1/uctoo/company/public/:id/growth
 */
public class PublicCompaniesRoute {
    private var router: Router
    private var controller: PublicCompaniesController

    public init(router: Router, controller: PublicCompaniesController) {
        this.router = router
        this.controller = controller
    }

    public func register(): Router {
        // 公开组织列表（必须放在 :id 之前，避免被动态路由匹配）
        router.get("/api/v1/uctoo/company/public/:limit/:page", controller.getPublicList)
        // 公开组织详情
        router.get("/api/v1/uctoo/company/public/:id", controller.getPublicDetail)
        // 组织下的任务列表
        router.get("/api/v1/uctoo/company/public/:id/tasks/:limit/:page", controller.getCompanyTasks)
        // 组织成长数据
        router.get("/api/v1/uctoo/company/public/:id/growth", controller.getCompanyGrowth)
        // 组织成员列表
        router.get("/api/v1/uctoo/company/public/:id/members", controller.getOrgMembers)
        return router
    }
}
