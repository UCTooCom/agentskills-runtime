/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.uctoo.data_access_authorization
//#region AutoCreateCode

import magic.app.controllers.uctoo.data_access_authorization.DataAccessAuthorizationController
import magic.app.core.router.Router

public class DataAccessAuthorizationRoute {
    private var router: Router
    private var controller: DataAccessAuthorizationController

    public init(router: Router, controller: DataAccessAuthorizationController) {
        this.router = router
        this.controller = controller
    }

    public func register(): Router {
        // 先注册自定义路由，避免被动态路由 :id 匹配
        registerCustomRoutes()

        // 按照 uctoo v4 规范，路由路径带 /v1 前缀
        router.post("/api/v1/uctoo/data_access_authorization/add", controller.add)
        router.post("/api/v1/uctoo/data_access_authorization/edit", controller.edit)
        router.post("/api/v1/uctoo/data_access_authorization/del", controller.delete)

        // 单条查询：必须放在列表查询之前，因为UUID格式与数字不同
        router.get("/api/v1/uctoo/data_access_authorization/:id", controller.getSingle)

        // 列表查询：支持 :limit/:page 和 :limit/:page/:skip 两种格式
        router.get("/api/v1/uctoo/data_access_authorization/:limit/:page/:skip", controller.getManyWithSkip)
        router.get("/api/v1/uctoo/data_access_authorization/:limit/:page", controller.getManyWithPathParams)

        // 导出功能
        router.get("/api/v1/uctoo/data_access_authorization/export", controller.export)
        // 清空回收站
        router.post("/api/v1/uctoo/data_access_authorization/empty-recycle-bin", controller.emptyRecycleBinDataAccessAuthorization)

        return router
    }

//#endregion AutoCreateCode

    /**
     * 注册自定义路由
     * 在此方法中添加定制开发的路由
     */
    public func registerCustomRoutes(): Router {
        router.post("/api/v1/uctoo/data_access_authorization/authorize", controller.authorize)
        router.post("/api/v1/uctoo/data_access_authorization/revoke", controller.revoke)
        router.get("/api/v1/uctoo/data_access_authorization/:entityType/:entityId/authorizations", controller.getAuthorizations)
        return router
    }
}
