/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.uctoo.tasks
// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========
import magic.app.controllers.uctoo.tasks.PublicTasksController
import magic.app.services.uctoo.TasksService

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import magic.app.controllers.uctoo.tasks.TasksController
import magic.app.core.router.Router

public class TasksRoute {
    private var router: Router
    private var controller: TasksController

    public init(router: Router, controller: TasksController) {
        this.router = router
        this.controller = controller
    }

    public func register(): Router {
        // 先注册自定义路由，避免被动态路由 :id 匹配
        registerCustomRoutes()

        // 按照 uctoo v4 规范，路由路径带 /v1 前缀
        router.post("/api/v1/uctoo/tasks/add", controller.add)
        router.post("/api/v1/uctoo/tasks/edit", controller.edit)
        router.post("/api/v1/uctoo/tasks/del", controller.delete)

        // 单条查询：必须放在列表查询之前，因为UUID格式与数字不同
        router.get("/api/v1/uctoo/tasks/:id", controller.getSingle)

        // 列表查询：支持 :limit/:page 和 :limit/:page/:skip 两种格式
        router.get("/api/v1/uctoo/tasks/:limit/:page/:skip", controller.getManyWithSkip)
        router.get("/api/v1/uctoo/tasks/:limit/:page", controller.getManyWithPathParams)

        // 导出功能
        router.get("/api/v1/uctoo/tasks/export", controller.export)
        // 清空回收站
        router.post("/api/v1/uctoo/tasks/empty-recycle-bin", controller.emptyRecycleBinTasks)

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
        router.get("/api/v1/uctoo/tasks/my/:limit/:page", controller.getMyTasks)

        // 公开任务路由（必须在动态路由之前注册）
        let publicService = TasksService()
        let publicController = PublicTasksController(publicService)
        // 首页统计数据（必须放在 :id 之前，避免被动态路由匹配）
        router.get("/api/v1/uctoo/tasks/public/home-stats", publicController.getHomeStats)
        // 公开任务列表
        router.get("/api/v1/uctoo/tasks/public/:limit/:page", publicController.getPublicList)
        // 公开任务详情
        router.get("/api/v1/uctoo/tasks/public/:id", publicController.getPublicDetail)

        // 以下路由使用 :id 动态参数
        router.post("/api/v1/uctoo/tasks/:id/update-status", controller.updateStatus)
        router.post("/api/v1/uctoo/tasks/:id/toggle-follow", controller.toggleFollow)
        router.post("/api/v1/uctoo/tasks/:id/join", controller.joinTask)
        return router
    }
}