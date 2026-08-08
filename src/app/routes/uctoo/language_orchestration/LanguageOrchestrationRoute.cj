/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.uctoo.language_orchestration

import magic.app.controllers.uctoo.language_orchestration.LanguageOrchestrationController
import magic.app.core.router.Router

public class LanguageOrchestrationRoute {
    private var router: Router
    private var controller: LanguageOrchestrationController

    public init(router: Router, controller: LanguageOrchestrationController) {
        this.router = router
        this.controller = controller
    }

    public func register(): Router {
        router.get("/api/v1/uctoo/language_orchestration/languages", controller.listLanguages)
        router.get("/api/v1/uctoo/language_orchestration/mapping/:language", controller.getMapping)
        router.post("/api/v1/uctoo/language_orchestration/orchestrate", controller.orchestrate)
        router.post("/api/v1/uctoo/language_orchestration/cross-language", controller.crossLanguageOrchestrate)
        router.get("/api/v1/uctoo/language_orchestration/task/:task_id", controller.getTaskProgress)
        router.get("/api/v1/uctoo/language_orchestration/active-tasks", controller.getActiveTasks)
        return router
    }
}