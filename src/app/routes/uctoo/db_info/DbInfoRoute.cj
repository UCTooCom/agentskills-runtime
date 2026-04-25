/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.uctoo.db_info

//#region AutoCreateCode

import magic.app.controllers.uctoo.db_info.DbInfoController
import magic.app.core.router.Router

public class DbInfoRoute {
    private var router: Router
    private var controller: DbInfoController

    public init(router: Router, controller: DbInfoController) {
        this.router = router
        this.controller = controller
    }

    public func register(): Router {
        // 先注册自定义路由，避免被动态路由 :id 匹配
        registerCustomRoutes()
  
        // 按照 uctoo v4 规范，路由路径带 /v1 前缀
        router.post("/api/v1/uctoo/db_info/add", controller.add)
        router.post("/api/v1/uctoo/db_info/edit", controller.edit)
        router.post("/api/v1/uctoo/db_info/del", controller.delete)

        // 单条查询：必须放在列表查询之前，因为UUID格式与数字不同
        router.get("/api/v1/uctoo/db_info/:id", controller.getSingle)

        // 列表查询：支持 :limit/:page 和 :limit/:page/:skip 两种格式
        router.get("/api/v1/uctoo/db_info/:limit/:page/:skip", controller.getManyWithSkip)
        router.get("/api/v1/uctoo/db_info/:limit/:page", controller.getManyWithPathParams)

        return router
    }

//#endregion AutoCreateCode

    /**
     * 注册自定义路由
     * 在此方法中添加定制开发的路由
     */
    public func registerCustomRoutes(): Router {
        router.post("/api/v1/uctoo/db_info/load-db-info", controller.loadDbInfo)

        router.get("/api/v1/uctoo/db_info/get-db-table-list", controller.getDbTableList)

        return router
    }
}