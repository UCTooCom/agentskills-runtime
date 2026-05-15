/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.uctoo.permissions

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========

    
    //#region AutoCreateCode

import magic.app.controllers.uctoo.permissions.PermissionsController
import magic.app.core.router.Router

public class PermissionsRoute {
    private var router: Router
    private var controller: PermissionsController

    public init(router: Router, controller: PermissionsController) {
        this.router = router
        this.controller = controller
    }

    public func register(): Router {
        // 先注册自定义路由，避免被动态路由 :id 匹配
        registerCustomRoutes()

        // 按照 uctoo v4 规范，路由路径带 /v1 前缀
        router.post("/api/v1/uctoo/permissions/add", controller.add)
        router.post("/api/v1/uctoo/permissions/edit", controller.edit)
        router.post("/api/v1/uctoo/permissions/del", controller.delete)

        // 单条查询：必须放在列表查询之前，因为UUID格式与数字不同
        router.get("/api/v1/uctoo/permissions/:id", controller.getSingle)

        // 列表查询：支持 :limit/:page 和 :limit/:page/:skip 两种格式
        router.get("/api/v1/uctoo/permissions/:limit/:page/:skip", controller.getManyWithSkip)
        router.get("/api/v1/uctoo/permissions/:limit/:page", controller.getManyWithPathParams)

        // 导出功能
        router.get("/api/v1/uctoo/permissions/export", controller.export)
        // 清空回收站
        router.post("/api/v1/uctoo/permissions/empty-recycle-bin", controller.emptyRecycleBinPermissions)

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
        
        // 获取所有权限节点（超级管理员专用）
        router.get("/api/v1/uctoo/permissions/all", controller.getAllPermissions)
        
        // 批量授权接口（超级管理员专用）
        router.post("/api/v1/uctoo/permissions/authorize", controller.batchAuthorize)
        
        // 批量取消授权接口（超级管理员专用）
        router.post("/api/v1/uctoo/permissions/revoke", controller.batchRevoke)
        
        return router
    }
}
