/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.uctoo.config
// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import magic.app.controllers.uctoo.config.ConfigController
import magic.app.core.router.Router

public class ConfigRoute {
    private var router: Router
    private var controller: ConfigController

    public init(router: Router, controller: ConfigController) {
        this.router = router
        this.controller = controller
    }

    public func register(): Router {
        // 先注册自定义路由，避免被动态路由 :id 匹配
        registerCustomRoutes()

        // 按照 uctoo v4 规范，路由路径带 /v1 前缀
        router.post("/api/v1/uctoo/config/add", controller.add)
        router.post("/api/v1/uctoo/config/edit", controller.edit)
        router.post("/api/v1/uctoo/config/del", controller.delete)

        // 单条查询：必须放在列表查询之前，因为UUID格式与数字不同
        router.get("/api/v1/uctoo/config/:id", controller.getSingle)

        // 列表查询：支持 :limit/:page 和 :limit/:page/:skip 两种格式
        router.get("/api/v1/uctoo/config/:limit/:page/:skip", controller.getManyWithSkip)
        router.get("/api/v1/uctoo/config/:limit/:page", controller.getManyWithPathParams)

        // 导出功能
        router.get("/api/v1/uctoo/config/export", controller.export)
        // 清空回收站
        router.post("/api/v1/uctoo/config/empty-recycle-bin", controller.emptyRecycleBinConfig)

        return router
    }

//#endregion AutoCreateCode

    /**
     * 注册自定义路由
     * 在此方法中添加定制开发的路由
     */
    public func registerCustomRoutes(): Router {
        router.get("/api/v1/uctoo/config/metadata", controller.getConfigMetadata)
        router.get("/api/v1/uctoo/config/export-config", controller.exportConfigHandler)
        router.post("/api/v1/uctoo/config/batch", controller.batchUpdateConfigs)
        router.post("/api/v1/uctoo/config/import", controller.importConfigHandler)
        router.get("/api/v1/uctoo/config/key/:key", controller.getConfigByKey)
        router.post("/api/v1/uctoo/config/key/:key", controller.updateConfigByKey)

        return router
    }
}