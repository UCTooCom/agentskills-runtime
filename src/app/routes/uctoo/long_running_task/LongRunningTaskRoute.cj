/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.uctoo.long_running_task

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import magic.app.controllers.uctoo.long_running_task.LongRunningTaskController
import magic.app.core.router.Router

/**
 * 长程任务用户 API 路由（spec §9.1）
 *
 * 路径前缀 `/api/v1/uctoo/long_running_task`。
 *
 * 注册顺序：**静态段路径先注册，`:param` 路径后注册**。
 * 因为 Router 按注册顺序做线性匹配（`Router.match` 遍历 routes），
 * 若先注册 `/intervene/:taskId` 再注册设想的 `/intervene/stats`，
 * 后者会被前者吃掉——这是本项目其它路由里已踩过的坑，保持一致。
 */
public class LongRunningTaskRoute {
    private let router: Router
    private let controller: LongRunningTaskController

    public init(router: Router, controller: LongRunningTaskController) {
        this.router = router
        this.controller = controller
    }

    public func register(): Router {
        // ── 9.1.1 提交长程任务 ─────────────────────────────────────
        router.post("/api/v1/uctoo/long_running_task/add", controller.add)

        // ── 9.1.2 人工干预 ─────────────────────────────────────────
        // design 2.2.1 的用户 API 清单写的是 `POST /intervene`（taskId 在 body）。
        // 这里**同时**注册精确路径与 `:taskId` 变体，两种调用姿势都能命中：
        // controller.intervene 本就是「path 参数 > query > body」三级取值，
        // 缺精确路由会让「按 design 原样调用」的客户端直接 404。（review 偏差 #14）
        // 顺序按本文件约定「静态段在前」：精确路径先注册。
        router.post("/api/v1/uctoo/long_running_task/intervene", controller.intervene)
        router.post("/api/v1/uctoo/long_running_task/intervene/:taskId", controller.intervene)

        // ── 9.1.3 任务树 ───────────────────────────────────────────
        router.get("/api/v1/uctoo/long_running_task/tree/:rootId", controller.getTree)

        // ── 9.1.4 任务进度 ─────────────────────────────────────────
        router.get("/api/v1/uctoo/long_running_task/progress/:taskId", controller.getProgress)

        // ── 9.1.5 检查点列表 ───────────────────────────────────────
        router.get("/api/v1/uctoo/long_running_task/checkpoints/:taskId", controller.getCheckpoints)

        // ── 9.1.6 触发验核 ─────────────────────────────────────────
        router.post("/api/v1/uctoo/long_running_task/verify/:taskId", controller.verify)

        // ── 9.1.7 触发自进化 ───────────────────────────────────────
        router.post("/api/v1/uctoo/long_running_task/evolve/:agentId", controller.evolve)

        // ── 9.1.8 交付确认（Ch6.3：用户确认后才置 status=2）──────────
        router.post("/api/v1/uctoo/long_running_task/deliver/:taskId", controller.deliver)

        // ── 9.1.9 评审改进（Ch6.3：用户反馈 → replan → 继续执行）─────
        router.post("/api/v1/uctoo/long_running_task/review/:taskId", controller.review)

        return router
    }

//#endregion AutoCreateCode

    /**
     * 注册自定义路由
     * 在此方法中添加定制开发的路由
     */
    public func registerCustomRoutes(): Router {
        // 9.3 执行轨迹查询：静态段路径，不带 :param。
        // 放在这里而不是 register()，是为了以后 crud-generator 重新生成
        // register() 时不会被覆盖掉。
        router.get("/api/v1/uctoo/long_running_task/trace", controller.getTrace)

        return router
    }
}
