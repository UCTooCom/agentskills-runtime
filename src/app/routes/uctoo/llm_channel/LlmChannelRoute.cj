/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.uctoo.llm_channel

import magic.app.controllers.uctoo.llm_channel.LlmChannelController
import magic.app.core.router.Router

/**
 * LlmChannelRoute — 通道管理 API 路由（T012，design.md §8）。
 *
 * 端点：
 *   GET  /api/v1/uctoo/llm_channel/list           通道列表（管理面）
 *   GET  /api/v1/uctoo/llm_channel/catalog        用户面通道目录（T035，普通用户可读、字段裁剪）
 *   GET  /api/v1/uctoo/llm_channel/health         健康总览（T018）
 *   GET  /api/v1/uctoo/llm_channel/audit          变更审计（T019）
 *   GET  /api/v1/uctoo/llm_channel/models         全通道模型清单（T016）
 *   GET  /api/v1/uctoo/llm_channel/:code          单通道详情
 *   POST /api/v1/uctoo/llm_channel/add            新增
 *   POST /api/v1/uctoo/llm_channel/edit           更新
 *   POST /api/v1/uctoo/llm_channel/del            删除
 *   POST /api/v1/uctoo/llm_channel/:code/toggle   启停
 *   POST /api/v1/uctoo/llm_channel/:code/default  设为默认（热生效核心动作）
 *   POST /api/v1/uctoo/llm_channel/:code/test     连通性测试
 *   POST /api/v1/uctoo/llm_channel/:code/sync-models  拉模型清单（T016）
 *   POST /api/v1/uctoo/llm_channel/:code/probe    三枪能力探测（T017）
 *   POST /api/v1/uctoo/llm_channel/reload         手动刷新注册表
 *
 * 注意：GET 字面量 /list 必须注册在 GET 参数路由 /:code 之前。
 * Router.match 按注册顺序返回首个匹配，若 /list 晚于 /:code 注册，
 * 则 /list 会被 /:code 捕获为 code="list" 而返回 404。
 */
public class LlmChannelRoute {
    private var router: Router
    private var controller: LlmChannelController

    public init(router: Router, controller: LlmChannelController) {
        this.router = router
        this.controller = controller
    }

    public func register(): Router {
        // 自定义路由（本模块暂无，保持范式占位）
        registerCustomRoutes()

        // GET 列表（字面量，必须先于 :code 参数路由注册）
        router.get("/api/v1/uctoo/llm_channel/list", controller.list)

        // GET 用户面通道目录（字面量，T035 / REQ-DMC-021；同样必须先于 :code）
        router.get("/api/v1/uctoo/llm_channel/catalog", controller.catalog)

        // GET 健康总览（字面量，T018；同样必须先于 :code）
        router.get("/api/v1/uctoo/llm_channel/health", controller.health)

        // GET 变更审计（字面量，T019；同样必须先于 :code）
        router.get("/api/v1/uctoo/llm_channel/audit", controller.audit)

        // GET 配置导出（T033，字面量；同样必须先于 :code）
        router.get("/api/v1/uctoo/llm_channel/export", controller.exportConfig)

        // GET 全通道模型清单（字面量，T016；同样必须先于 :code）
        router.get("/api/v1/uctoo/llm_channel/models", controller.models)

        // GET 单通道详情（参数路由）
        router.get("/api/v1/uctoo/llm_channel/:code", controller.detail)

        // POST 写操作（增删改）
        router.post("/api/v1/uctoo/llm_channel/add", controller.add)
        router.post("/api/v1/uctoo/llm_channel/edit", controller.edit)
        router.post("/api/v1/uctoo/llm_channel/del", controller.del)
        // POST 配置导入（T033，字面量；须在 /:code/* 参数路由之前，避免被当成 code=import）
        router.post("/api/v1/uctoo/llm_channel/import", controller.importConfig)

        // POST 针对单通道的动作（参数路由）
        router.post("/api/v1/uctoo/llm_channel/:code/toggle", controller.toggle)
        router.post("/api/v1/uctoo/llm_channel/:code/default", controller.setDefault)
        router.post("/api/v1/uctoo/llm_channel/:code/test", controller.test)
        router.post("/api/v1/uctoo/llm_channel/:code/sync-models", controller.syncModels)
        router.post("/api/v1/uctoo/llm_channel/:code/probe", controller.probe)

        // POST 手动刷新注册表（字面量）
        router.post("/api/v1/uctoo/llm_channel/reload", controller.reload)

        return router
    }

    /**
     * 注册自定义路由（定制开发的路由放在这里）。
     */
    public func registerCustomRoutes(): Router {
        return router
    }
}
