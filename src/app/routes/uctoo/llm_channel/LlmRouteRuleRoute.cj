/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.uctoo.llm_channel

import magic.app.controllers.uctoo.llm_channel.LlmRouteRuleController
import magic.app.core.router.Router

/**
 * LlmRouteRuleRoute — 通道路由规则管理 API 路由（T027，design.md §8 / §7）。
 *
 * 端点（前缀 /api/v1/uctoo/llm_route_rule）：
 *   GET  /list       规则列表（管理面）
 *   POST /add        新增规则
 *   POST /edit       更新规则
 *   POST /del        删除规则（软删）
 *   POST /evaluate   选路校验（T006 / T029 调试入口：给定 scope + 能力，返回命中通道 + 候选顺序）
 */
public class LlmRouteRuleRoute {
    private var router: Router
    private var controller: LlmRouteRuleController

    public init(router: Router, controller: LlmRouteRuleController) {
        this.router = router
        this.controller = controller
    }

    public func register(): Router {
        registerCustomRoutes()

        // GET 列表（字面量，先于其它无参路由）
        router.get("/api/v1/uctoo/llm_route_rule/list", controller.list)

        // GET 影子流量对比指标（T032，字面量无参路由）
        router.get("/api/v1/uctoo/llm_route_rule/shadow-stats", controller.shadowStats)

        // POST 写操作
        router.post("/api/v1/uctoo/llm_route_rule/add", controller.add)
        router.post("/api/v1/uctoo/llm_route_rule/edit", controller.edit)
        router.post("/api/v1/uctoo/llm_route_rule/del", controller.del)
        router.post("/api/v1/uctoo/llm_route_rule/evaluate", controller.evaluate)

        return router
    }

    public func registerCustomRoutes(): Router {
        router
    }
}
