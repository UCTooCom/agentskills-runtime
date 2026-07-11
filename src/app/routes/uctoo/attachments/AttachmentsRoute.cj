/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.uctoo.attachments
// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import magic.app.controllers.uctoo.attachments.AttachmentsController
import magic.app.core.router.Router

public class AttachmentsRoute {
    private var router: Router
    private var controller: AttachmentsController

    public init(router: Router, controller: AttachmentsController) {
        this.router = router
        this.controller = controller
    }

    public func register(): Router {
        // 先注册自定义路由，避免被动态路由 :id 匹配
        registerCustomRoutes()

        // 按照 uctoo v4 规范，路由路径带 /v1 前缀
        router.post("/api/v1/uctoo/attachments/add", controller.add)
        router.post("/api/v1/uctoo/attachments/edit", controller.edit)
        router.post("/api/v1/uctoo/attachments/del", controller.delete)

        // 单条查询：必须放在列表查询之前，因为UUID格式与数字不同
        router.get("/api/v1/uctoo/attachments/:id", controller.getSingle)

        // 列表查询：支持 :limit/:page 和 :limit/:page/:skip 两种格式
        router.get("/api/v1/uctoo/attachments/:limit/:page/:skip", controller.getManyWithSkip)
        router.get("/api/v1/uctoo/attachments/:limit/:page", controller.getManyWithPathParams)

        // 导出功能
        router.get("/api/v1/uctoo/attachments/export", controller.export)
        // 清空回收站
        router.post("/api/v1/uctoo/attachments/empty-recycle-bin", controller.emptyRecycleBinAttachments)

        return router
    }

//#endregion AutoCreateCode

    /**
     * 注册自定义路由
     * 在此方法中添加定制开发的路由
     */
    public func registerCustomRoutes(): Router {
        // 上传文件到腾讯云 COS
        router.post("/api/v1/uctoo/attachments/upload", controller.upload)

        return router
    }
}