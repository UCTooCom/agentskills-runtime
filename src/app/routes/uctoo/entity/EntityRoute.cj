/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.uctoo.entity

import magic.app.controllers.uctoo.entity.EntityController
import magic.app.core.router.Router

public class EntityRoute {
    private var router: Router
    private var controller: EntityController
    
    public init(router: Router, controller: EntityController) {
        this.router = router
        this.controller = controller
    }
    
    //#region AutoCreateCode
    
    public func register(): Router {
        // 按照 uctoo v4 规范，路由路径带 /v1 前缀
        router.post("/api/v1/uctoo/entity/add", controller.add)
        router.post("/api/v1/uctoo/entity/edit", controller.edit)
        router.post("/api/v1/uctoo/entity/del", controller.delete)
        
        // 单条查询：必须放在列表查询之前，因为UUID格式与数字不同
        router.get("/api/v1/uctoo/entity/:id", controller.getSingle)
        
        // 列表查询：支持 :limit/:page 和 :limit/:page/:skip 两种格式
        router.get("/api/v1/uctoo/entity/:limit/:page/:skip", controller.getManyWithSkip)
        router.get("/api/v1/uctoo/entity/:limit/:page", controller.getManyWithPathParams)
        
        // 导出功能
        router.get("/api/v1/uctoo/entity/export", controller.export)
        
        return router
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义路由）==========
}
