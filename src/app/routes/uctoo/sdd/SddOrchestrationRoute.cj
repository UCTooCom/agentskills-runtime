/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.uctoo.sdd

import magic.app.controllers.uctoo.sdd.SddOrchestrationController
import magic.app.core.router.Router

/**
 * SDD 编排薄路由（T-09）。
 *
 * 只暴露三个**语义**入口，刻意不生成 add/edit/del/get/list 通用 CRUD
 * （ADR-001：`sdd_projects` 是 agent_tasks 状态机的投影，写入责任方是宿主编排服务）。
 */
public class SddOrchestrationRoute {
    private var router: Router
    private var controller: SddOrchestrationController

    public init(router: Router, controller: SddOrchestrationController) {
        this.router = router
        this.controller = controller
    }

    public func register(): Router {
        // 语义入口：启动工程 / 执行单步 / 查询进度
        router.post("/api/v1/uctoo/sdd/start", controller.start)
        // 异步六步编排（crontab executor 驱动，HTTP 立即返回）
        router.post("/api/v1/uctoo/sdd/run", controller.run)
        // 同步单步（探针/联调用，会阻塞到子 agent 返回）
        router.post("/api/v1/uctoo/sdd/run-stage", controller.runStage)
        // 闸口决策回执（confirm / revise / abandon）—— 人在回路的落点
        router.post("/api/v1/uctoo/sdd/review", controller.review)

        // 查询：feature_name 走 path 或 query 均可
        router.get("/api/v1/uctoo/sdd/status/:featureName", controller.status)
        router.get("/api/v1/uctoo/sdd/status", controller.status)

        return router
    }

    public func registerCustomRoutes(): Router {
        return router
    }
}
