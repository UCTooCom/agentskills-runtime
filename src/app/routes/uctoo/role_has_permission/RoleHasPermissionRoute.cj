/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.uctoo.role_has_permission

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

import magic.app.controllers.uctoo.role_has_permission.RoleHasPermissionController
import magic.app.core.router.Router

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========

/**
 * RoleHasPermissionRoute - 角色权限关联路由
 * 
 * 提供role_has_permission表的路由注册，遵循UCTOO V4 API规范
 * 
 * 注意: 此表使用复合主键 (role_id, permission_name)
 */
public class RoleHasPermissionRoute {
    private var router: Router
    private var controller: RoleHasPermissionController
    
    public init(router: Router, controller: RoleHasPermissionController) {
        this.router = router
        this.controller = controller
    }
    
    //#region AutoCreateCode
    
    public func register(): Router {
        // 按照 uctoo v4 规范，路由路径带 /v1 前缀
        
        // 添加权限到角色
        router.post("/api/v1/uctoo/role_has_permission/add", controller.add)
        
        // 删除角色权限关联
        router.post("/api/v1/uctoo/role_has_permission/del", controller.delete)
        
        // 查询单个角色权限关联（复合主键）
        router.get("/api/v1/uctoo/role_has_permission/:roleId/:permissionName", controller.getSingle)
        
        // 查询角色拥有的所有权限
        router.get("/api/v1/uctoo/role_has_permission/byRoleId/:roleId", controller.getByRoleId)
        
        // 查询使用某权限的所有角色
        router.get("/api/v1/uctoo/role_has_permission/byPermissionName/:permissionName", controller.getByPermissionName)
        
        return router
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义路由）==========
}
