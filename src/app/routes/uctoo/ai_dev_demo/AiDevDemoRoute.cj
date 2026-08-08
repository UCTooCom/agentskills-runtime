/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.uctoo.ai_dev_demo

import magic.app.controllers.uctoo.ai_dev_demo.AiDevDemoController
import magic.app.core.router.Router

public class AiDevDemoRoute {
    private var router: Router
    private var controller: AiDevDemoController

    public init(router: Router, controller: AiDevDemoController) {
        this.router = router
        this.controller = controller
    }

    public func register(): Router {
        router.post("/api/v1/uctoo/ai_dev_demo/start", controller.start)
        router.get("/api/v1/uctoo/ai_dev_demo/status", controller.status)
        router.get("/api/v1/uctoo/ai_dev_demo/evidences", controller.evidences)
        router.get("/api/v1/uctoo/ai_dev_demo/team", controller.teamInfo)
        return router
    }
}