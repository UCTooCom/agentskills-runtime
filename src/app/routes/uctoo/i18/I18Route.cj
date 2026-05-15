/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.uctoo.i18

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import magic.app.controllers.uctoo.i18.I18Controller
import magic.app.core.router.Router

public class I18Route {
    private var router: Router
    private var controller: I18Controller

    public init(router: Router, controller: I18Controller) {
        this.router = router
        this.controller = controller
    }

    public func register(): Router {
        // 先注册自定义路由，避免被动态路由 :id 匹配
        registerCustomRoutes()

        // 按照 uctoo v4 规范，路由路径带 /v1 前缀
        router.post("/api/v1/uctoo/i18/add", controller.add)
        router.post("/api/v1/uctoo/i18/edit", controller.edit)
        router.post("/api/v1/uctoo/i18/del", controller.delete)

        // 单条查询：必须放在列表查询之前，因为UUID格式与数字不同
        router.get("/api/v1/uctoo/i18/:id", controller.getSingle)

        // 列表查询：支持 :limit/:page 和 :limit/:page/:skip 两种格式
        router.get("/api/v1/uctoo/i18/:limit/:page/:skip", controller.getManyWithSkip)
        router.get("/api/v1/uctoo/i18/:limit/:page", controller.getManyWithPathParams)

        // 导出功能
        router.get("/api/v1/uctoo/i18/export", controller.export)
        // 清空回收站
        router.post("/api/v1/uctoo/i18/empty-recycle-bin", controller.emptyRecycleBinI18)

        return router
    }

//#endregion AutoCreateCode

    /**
     * 注册自定义路由
     * 在此方法中添加定制开发的路由
     */
    public func registerCustomRoutes(): Router {
        // format接口：必须放在单条查询之前
        router.get("/api/v1/uctoo/i18/format", controller.format)
        
        // 获取全部数据接口：必须放在单条查询之前
        router.get("/api/v1/uctoo/i18/all", controller.getAllItems)
        
        return router
    }
}
