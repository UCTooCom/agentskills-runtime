/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.uctoo.llm_channel
// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import magic.app.controllers.uctoo.llm_channel.LlmChannelController
import magic.app.core.router.Router

public class LlmChannelRoute {
    private var router: Router
    private var controller: LlmChannelController

    public init(router: Router, controller: LlmChannelController) {
        this.router = router
        this.controller = controller
    }

    public func register(): Router {
        // 先注册自定义路由，避免被动态路由 :id 匹配
        registerCustomRoutes()

        // 按照 uctoo v4 规范，路由路径带 /v1 前缀
        router.post("/api/v1/uctoo/llm_channel/add", controller.add)
        router.post("/api/v1/uctoo/llm_channel/edit", controller.edit)
        router.post("/api/v1/uctoo/llm_channel/del", controller.delete)

        // 单条查询：必须放在列表查询之前，因为UUID格式与数字不同
        router.get("/api/v1/uctoo/llm_channel/:id", controller.getSingle)

        // 列表查询：支持 :limit/:page 和 :limit/:page/:skip 两种格式
        router.get("/api/v1/uctoo/llm_channel/:limit/:page/:skip", controller.getManyWithSkip)
        router.get("/api/v1/uctoo/llm_channel/:limit/:page", controller.getManyWithPathParams)

        // 导出功能
        router.get("/api/v1/uctoo/llm_channel/export", controller.export)
        // 清空回收站
        router.post("/api/v1/uctoo/llm_channel/empty-recycle-bin", controller.emptyRecycleBinLlmChannel)

        return router
    }

//#endregion AutoCreateCode

    /**
     * 注册自定义路由
     * 在此方法中添加定制开发的路由
     */
    public func registerCustomRoutes(): Router {
        // GET 字面量（必须先于 /:code 参数路由注册，避免被 /:code 捕获为 code="list" 等）
        router.get("/api/v1/uctoo/llm_channel/list", controller.list)
        router.get("/api/v1/uctoo/llm_channel/catalog", controller.catalog)
        router.get("/api/v1/uctoo/llm_channel/health", controller.health)
        router.get("/api/v1/uctoo/llm_channel/audit", controller.audit)
        router.get("/api/v1/uctoo/llm_channel/models", controller.models)
        router.get("/api/v1/uctoo/llm_channel/export", controller.exportConfig)
        // POST 字面量
        router.post("/api/v1/uctoo/llm_channel/import", controller.importConfig)
        router.post("/api/v1/uctoo/llm_channel/reload", controller.reload)
        // GET 单通道详情（参数路由）
        router.get("/api/v1/uctoo/llm_channel/:code", controller.detail)
        // POST 写操作（增删改，委托 ChannelService 写审计+广播，覆盖标准 CRUD）
        router.post("/api/v1/uctoo/llm_channel/add", controller.addChannel)
        router.post("/api/v1/uctoo/llm_channel/edit", controller.editChannel)
        router.post("/api/v1/uctoo/llm_channel/del", controller.delChannel)
        // POST 针对单通道的动作（参数路由）
        router.post("/api/v1/uctoo/llm_channel/:code/toggle", controller.toggle)
        router.post("/api/v1/uctoo/llm_channel/:code/default", controller.setDefault)
        router.post("/api/v1/uctoo/llm_channel/:code/test", controller.test)
        router.post("/api/v1/uctoo/llm_channel/:code/sync-models", controller.syncModels)
        router.post("/api/v1/uctoo/llm_channel/:code/probe", controller.probe)
        return router
    }
}