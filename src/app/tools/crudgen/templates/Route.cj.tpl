/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.{{dbName}}.{{tableName}}

//#region AutoCreateCode

import magic.app.controllers.{{dbName}}.{{tableName}}.{{className}}Controller
import magic.app.core.router.Router

public class {{className}}Route {
    private var router: Router
    private var controller: {{className}}Controller

    public init(router: Router, controller: {{className}}Controller) {
        this.router = router
        this.controller = controller
    }

    public func register(): Router {
        // 先注册自定义路由，避免被动态路由 :id 匹配
        registerCustomRoutes()

        // 按照 uctoo v4 规范，路由路径带 /v1 前缀
        router.post("/api/v1/{{dbName}}/{{tableName}}/add", controller.add)
        router.post("/api/v1/{{dbName}}/{{tableName}}/edit", controller.edit)
        router.post("/api/v1/{{dbName}}/{{tableName}}/del", controller.delete)

        // 单条查询：必须放在列表查询之前，因为UUID格式与数字不同
        router.get("/api/v1/{{dbName}}/{{tableName}}/:id", controller.getSingle)

        // 列表查询：支持 :limit/:page 和 :limit/:page/:skip 两种格式
        router.get("/api/v1/{{dbName}}/{{tableName}}/:limit/:page/:skip", controller.getManyWithSkip)
        router.get("/api/v1/{{dbName}}/{{tableName}}/:limit/:page", controller.getManyWithPathParams)

        // 导出功能
        router.get("/api/v1/{{dbName}}/{{tableName}}/export", controller.export)
        // 清空回收站
        router.post("/api/v1/{{dbName}}/{{tableName}}/empty-recycle-bin", controller.emptyRecycleBin{{className}})

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