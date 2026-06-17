/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.uctoo.model_pricing
// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import magic.app.controllers.uctoo.model_pricing.ModelPricingController
import magic.app.core.router.Router

public class ModelPricingRoute {
    private var router: Router
    private var controller: ModelPricingController

    public init(router: Router, controller: ModelPricingController) {
        this.router = router
        this.controller = controller
    }

    public func register(): Router {
        // 先注册自定义路由，避免被动态路由 :id 匹配
        registerCustomRoutes()

        // 按照 uctoo v4 规范，路由路径带 /v1 前缀
        router.post("/api/v1/uctoo/model_pricing/add", controller.add)
        router.post("/api/v1/uctoo/model_pricing/edit", controller.edit)
        router.post("/api/v1/uctoo/model_pricing/del", controller.delete)

        // 单条查询：必须放在列表查询之前，因为UUID格式与数字不同
        router.get("/api/v1/uctoo/model_pricing/:id", controller.getSingle)

        // 列表查询：支持 :limit/:page 和 :limit/:page/:skip 两种格式
        router.get("/api/v1/uctoo/model_pricing/:limit/:page/:skip", controller.getManyWithSkip)
        router.get("/api/v1/uctoo/model_pricing/:limit/:page", controller.getManyWithPathParams)

        // 导出功能
        router.get("/api/v1/uctoo/model_pricing/export", controller.export)
        // 清空回收站
        router.post("/api/v1/uctoo/model_pricing/empty-recycle-bin", controller.emptyRecycleBinModelPricing)

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