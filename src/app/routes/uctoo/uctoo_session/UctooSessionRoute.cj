/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.uctoo.uctoo_session

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========

    //#region AutoCreateCode

import magic.app.controllers.uctoo.uctoo_session.UctooSessionController
import magic.app.core.router.Router

public class UctooSessionRoute {
    private var router: Router
    private var controller: UctooSessionController

    public init(router: Router, controller: UctooSessionController) {
        this.router = router
        this.controller = controller
    }

    public func register(): Router {
        // 先注册自定义路由，避免被动态路由 :id 匹配
        registerCustomRoutes()

        // 按照 uctoo v4 规范，路由路径带 /v1 前缀
        router.post("/api/v1/uctoo/uctoo_session/add", controller.add)
        router.post("/api/v1/uctoo/uctoo_session/edit", controller.edit)
        router.post("/api/v1/uctoo/uctoo_session/del", controller.delete)

        // 单条查询：必须放在列表查询之前，因为UUID格式与数字不同
        router.get("/api/v1/uctoo/uctoo_session/:id", controller.getSingle)

        // 列表查询：支持 :limit/:page 和 :limit/:page/:skip 两种格式
        router.get("/api/v1/uctoo/uctoo_session/:limit/:page/:skip", controller.getManyWithSkip)
        router.get("/api/v1/uctoo/uctoo_session/:limit/:page", controller.getManyWithPathParams)

        // 导出功能
        router.get("/api/v1/uctoo/uctoo_session/export", controller.export)
        // 清空回收站
        router.post("/api/v1/uctoo/uctoo_session/empty-recycle-bin", controller.emptyRecycleBinUctooSession)

        return router
    }

//#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义路由）==========
    
    /**
     * 注册自定义路由
     * 在此方法中添加定制开发的路由
     */
    public func registerCustomRoutes(): Router {
        
        return router
    }
}
