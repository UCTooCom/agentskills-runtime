/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.uctoo.llm_route_rule
// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import magic.app.controllers.uctoo.llm_route_rule.LlmRouteRuleController
import magic.app.core.router.Router

public class LlmRouteRuleRoute {
    private var router: Router
    private var controller: LlmRouteRuleController

    public init(router: Router, controller: LlmRouteRuleController) {
        this.router = router
        this.controller = controller
    }

    public func register(): Router {
        // 先注册自定义路由，避免被动态路由 :id 匹配
        registerCustomRoutes()

        // 按照 uctoo v4 规范，路由路径带 /v1 前缀
        router.post("/api/v1/uctoo/llm_route_rule/add", controller.add)
        router.post("/api/v1/uctoo/llm_route_rule/edit", controller.edit)
        router.post("/api/v1/uctoo/llm_route_rule/del", controller.delete)

        // 单条查询：必须放在列表查询之前，因为UUID格式与数字不同
        router.get("/api/v1/uctoo/llm_route_rule/:id", controller.getSingle)

        // 列表查询：支持 :limit/:page 和 :limit/:page/:skip 两种格式
        router.get("/api/v1/uctoo/llm_route_rule/:limit/:page/:skip", controller.getManyWithSkip)
        router.get("/api/v1/uctoo/llm_route_rule/:limit/:page", controller.getManyWithPathParams)

        // 导出功能
        router.get("/api/v1/uctoo/llm_route_rule/export", controller.export)
        // 清空回收站
        router.post("/api/v1/uctoo/llm_route_rule/empty-recycle-bin", controller.emptyRecycleBinLlmRouteRule)

        return router
    }

//#endregion AutoCreateCode

    /**
     * 注册自定义路由
     * 在此方法中添加定制开发的路由
     */
    public func registerCustomRoutes(): Router {
        // GET 字面量（必须先于标准 /:id 参数路由注册，避免被捕获为 id="list" 等）
        router.get("/api/v1/uctoo/llm_route_rule/list", controller.list)
        router.get("/api/v1/uctoo/llm_route_rule/shadow-stats", controller.shadowStats)
        // POST 写操作（增删改，委托 ChannelService 写库+重载路由，覆盖标准 CRUD 的 /add /edit /del）
        router.post("/api/v1/uctoo/llm_route_rule/add", controller.addRouteRule)
        router.post("/api/v1/uctoo/llm_route_rule/edit", controller.editRouteRule)
        router.post("/api/v1/uctoo/llm_route_rule/del", controller.delRouteRule)
        // 选路校验（只读调试入口，T006 / T029）
        router.post("/api/v1/uctoo/llm_route_rule/evaluate", controller.evaluate)
        return router
    }
}