/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.uctoo.permissions

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

import magic.app.controllers.uctoo.permissions.PermissionsController
import magic.app.core.router.Router

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========


public class PermissionsRoute {
    private var router: Router
    private var controller: PermissionsController
    
    public init(router: Router, controller: PermissionsController) {
        this.router = router
        this.controller = controller
    }
    
    //#region AutoCreateCode
    
    public func register(): Router {
        // 按照 uctoo v4 规范，路由路径带 /v1 前缀
        router.post("/api/v1/uctoo/permissions/add", controller.add)
        router.post("/api/v1/uctoo/permissions/edit", controller.edit)
        router.post("/api/v1/uctoo/permissions/del", controller.delete)
        
        // 单条查询：必须放在列表查询之前，因为UUID格式与数字不同
        router.get("/api/v1/uctoo/permissions/:id", controller.getSingle)
        
        // 列表查询：支持 :limit/:page 和 :limit/:page/:skip 两种格式
        router.get("/api/v1/uctoo/permissions/:limit/:page/:skip", controller.getManyWithSkip)
        router.get("/api/v1/uctoo/permissions/:limit/:page", controller.getManyWithPathParams)
        
        return router
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义路由）==========
    
    /**
     * 注册自定义路由
     * 在此方法中添加定制开发的路由
     */
    public func registerCustomRoutes(): Router {
        // 从应用中加载路由到permissions表
        router.get("/api/v1/uctoo/permissions/loadRouteFromApp", controller.loadRouteFromApp)
        
        // 菜单相关接口 - V4标准RBAC
        router.post("/api/v1/uctoo/permissions/user/menu", controller.getUserMenuTree)
        router.get("/api/v1/uctoo/permissions/menu/all", controller.getAllMenuTree)
        router.post("/api/v1/uctoo/permissions/role/menu", controller.getRoleMenuTree)
        
        // 用户所有权限接口 - 不区分权限类型
        router.post("/api/v1/uctoo/permissions/user/all", controller.getUserAllPermissions)
        
        return router
    }
}
