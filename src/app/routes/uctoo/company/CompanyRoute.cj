/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.uctoo.company
// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========
import magic.app.controllers.uctoo.company.PublicCompaniesController
import magic.app.services.uctoo.CompanyService

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import magic.app.controllers.uctoo.company.CompanyController
import magic.app.core.router.Router

public class CompanyRoute {
    private var router: Router
    private var controller: CompanyController

    public init(router: Router, controller: CompanyController) {
        this.router = router
        this.controller = controller
    }

    public func register(): Router {
        // 先注册自定义路由，避免被动态路由 :id 匹配
        registerCustomRoutes()

        // 按照 uctoo v4 规范，路由路径带 /v1 前缀
        router.post("/api/v1/uctoo/company/add", controller.add)
        router.post("/api/v1/uctoo/company/edit", controller.edit)
        router.post("/api/v1/uctoo/company/del", controller.delete)

        // 单条查询：必须放在列表查询之前，因为UUID格式与数字不同
        router.get("/api/v1/uctoo/company/:id", controller.getSingle)

        // 列表查询：支持 :limit/:page 和 :limit/:page/:skip 两种格式
        router.get("/api/v1/uctoo/company/:limit/:page/:skip", controller.getManyWithSkip)
        router.get("/api/v1/uctoo/company/:limit/:page", controller.getManyWithPathParams)

        // 导出功能
        router.get("/api/v1/uctoo/company/export", controller.export)
        // 清空回收站
        router.post("/api/v1/uctoo/company/empty-recycle-bin", controller.emptyRecycleBinCompany)

        return router
    }

//#endregion AutoCreateCode

    /**
     * 注册自定义路由
     * 在此方法中添加定制开发的路由
     */
    public func registerCustomRoutes(): Router {
        // 定制路由需在动态 :id 路由之前注册，避免被 :id 错误匹配
        // "my" 是固定关键字路径，必须先于 :id 注册
        router.get("/api/v1/uctoo/company/my/:limit/:page", controller.getMyCompanies)

        // 公开组织路由（必须在动态路由之前注册）
        let publicService = CompanyService()
        let publicController = PublicCompaniesController(publicService)
        // 公开组织列表（必须放在 :id 之前，避免被动态路由匹配）
        router.get("/api/v1/uctoo/company/public/:limit/:page", publicController.getPublicList)
        // 公开组织详情
        router.get("/api/v1/uctoo/company/public/:id", publicController.getPublicDetail)
        // 组织下的任务列表
        router.get("/api/v1/uctoo/company/public/:id/tasks/:limit/:page", publicController.getCompanyTasks)
        // 组织成长数据
        router.get("/api/v1/uctoo/company/public/:id/growth", publicController.getCompanyGrowth)

        // 以下路由使用 :id 动态参数
        router.post("/api/v1/uctoo/company/:id/toggle-follow", controller.toggleFollow)
        router.post("/api/v1/uctoo/company/:id/join", controller.joinCompany)
        router.post("/api/v1/uctoo/company/:id/leave", controller.leaveCompany)
        return router
    }
}