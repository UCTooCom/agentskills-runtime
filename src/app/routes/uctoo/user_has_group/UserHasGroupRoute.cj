/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.uctoo.user_has_group

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

import magic.app.controllers.uctoo.user_has_group.UserHasGroupController
import magic.app.core.router.Router

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========

/**
 * UserHasGroupRoute - 用户组关联路由
 * 
 * 提供user_has_group表的路由注册，遵循UCTOO V4 API规范
 * 
 * 注意: 此表使用复合主键 (groupable_id, group_id)
 */
public class UserHasGroupRoute {
    private var router: Router
    private var controller: UserHasGroupController
    
    public init(router: Router, controller: UserHasGroupController) {
        this.router = router
        this.controller = controller
    }
    
    //#region AutoCreateCode
    
    public func register(): Router {
        // 按照 uctoo v4 规范，路由路径带 /v1 前缀
        
        // 添加用户到组
        router.post("/api/v1/uctoo/user_has_group/add", controller.add)
        
        // 删除用户组关联
        router.post("/api/v1/uctoo/user_has_group/del", controller.delete)
        
        // 查询单个用户组关联（复合主键）
        router.get("/api/v1/uctoo/user_has_group/:groupableId/:groupId", controller.getSingle)
        
        // 查询用户所属的所有组
        router.get("/api/v1/uctoo/user_has_group/byGroupableId/:groupableId", controller.getByGroupableId)
        
        // 查询组内的所有成员
        router.get("/api/v1/uctoo/user_has_group/byGroupId/:groupId", controller.getByGroupId)
        
        return router
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义路由）==========
}
