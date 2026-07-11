/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.uctoo.messages
// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import magic.app.controllers.uctoo.messages.MessagesController
import magic.app.core.router.Router

public class MessagesRoute {
    private var router: Router
    private var controller: MessagesController

    public init(router: Router, controller: MessagesController) {
        this.router = router
        this.controller = controller
    }

    public func register(): Router {
        // 先注册自定义路由，避免被动态路由 :id 匹配
        registerCustomRoutes()

        // 按照 uctoo v4 规范，路由路径带 /v1 前缀
        router.post("/api/v1/uctoo/messages/add", controller.add)
        router.post("/api/v1/uctoo/messages/edit", controller.edit)
        router.post("/api/v1/uctoo/messages/del", controller.delete)

        // 单条查询：必须放在列表查询之前，因为UUID格式与数字不同
        router.get("/api/v1/uctoo/messages/:id", controller.getSingle)

        // 列表查询：支持 :limit/:page 和 :limit/:page/:skip 两种格式
        router.get("/api/v1/uctoo/messages/:limit/:page/:skip", controller.getManyWithSkip)
        router.get("/api/v1/uctoo/messages/:limit/:page", controller.getManyWithPathParams)

        // 导出功能
        router.get("/api/v1/uctoo/messages/export", controller.export)
        // 清空回收站
        router.post("/api/v1/uctoo/messages/empty-recycle-bin", controller.emptyRecycleBinMessages)

        return router
    }

//#endregion AutoCreateCode

    /**
     * 注册自定义路由
     * 在此方法中添加定制开发的路由
     */
    public func registerCustomRoutes(): Router {
        // 定制路由需在动态 :id 路由之前注册，避免被 :id 错误匹配
        // 以下三个路径都是固定关键字，必须先于 :id 注册
        router.get("/api/v1/uctoo/messages/unread-count", controller.getUnreadCount)
        router.get("/api/v1/uctoo/messages/my/:limit/:page", controller.getMyMessages)
        router.post("/api/v1/uctoo/messages/mark-all-read", controller.markAllAsRead)
        // 以下路由使用 :id 动态参数
        router.post("/api/v1/uctoo/messages/:id/mark-read", controller.markAsRead)
        return router
    }
}