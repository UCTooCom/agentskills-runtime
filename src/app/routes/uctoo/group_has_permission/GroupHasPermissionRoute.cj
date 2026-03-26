/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.uctoo.group_has_permission

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

import magic.app.controllers.uctoo.group_has_permission.GroupHasPermissionController
import magic.app.core.router.Router

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========

/**
 * GroupHasPermissionRoute - 组权限关联路由
 * 
 * 提供group_has_permission表的路由注册，遵循UCTOO V4 API规范
 * 
 * 注意: 此表使用复合主键 (group_id, permission_name)
 */
public class GroupHasPermissionRoute {
    private var router: Router
    private var controller: GroupHasPermissionController
    
    public init(router: Router, controller: GroupHasPermissionController) {
        this.router = router
        this.controller = controller
    }
    
    //#region AutoCreateCode
    
    public func register(): Router {
        // 按照 uctoo v4 规范，路由路径带 /v1 前缀
        
        // 添加权限到组
        router.post("/api/v1/uctoo/group_has_permission/add", controller.add)
        
        // 删除组权限关联
        router.post("/api/v1/uctoo/group_has_permission/del", controller.delete)
        
        // 查询单个组权限关联（复合主键）
        router.get("/api/v1/uctoo/group_has_permission/:groupId/:permissionName", controller.getSingle)
        
        // 查询组拥有的所有权限
        router.get("/api/v1/uctoo/group_has_permission/byGroupId/:groupId", controller.getByGroupId)
        
        // 查询使用某权限的所有组
        router.get("/api/v1/uctoo/group_has_permission/byPermissionName/:permissionName", controller.getByPermissionName)
        
        return router
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义路由）==========
}
