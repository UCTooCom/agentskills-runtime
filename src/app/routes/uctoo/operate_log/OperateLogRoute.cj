/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.uctoo.operate_log

//#region AutoCreateCode

import magic.app.controllers.uctoo.operate_log.OperateLogController
import magic.app.core.router.Router

public class OperateLogRoute {
    private var router: Router
    private var controller: OperateLogController

    public init(router: Router, controller: OperateLogController) {
        this.router = router
        this.controller = controller
    }

    public func register(): Router {
        // 按照 uctoo v4 规范，路由路径带 /v1 前缀
        router.post("/api/v1/uctoo/operate_log/add", controller.add)
        router.post("/api/v1/uctoo/operate_log/edit", controller.edit)
        router.post("/api/v1/uctoo/operate_log/del", controller.delete)

        // 单条查询：必须放在列表查询之前，因为UUID格式与数字不同
        router.get("/api/v1/uctoo/operate_log/:id", controller.getSingle)

        // 列表查询：支持 :limit/:page 和 :limit/:page/:skip 两种格式
        router.get("/api/v1/uctoo/operate_log/:limit/:page/:skip", controller.getManyWithSkip)
        router.get("/api/v1/uctoo/operate_log/:limit/:page", controller.getManyWithPathParams)

        // 导出功能
        router.get("/api/v1/uctoo/operate_log/export", controller.export)
        // 清空回收站
        router.post("/api/v1/uctoo/operate_log/empty-recycle-bin", controller.emptyRecycleBinOperateLog)

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