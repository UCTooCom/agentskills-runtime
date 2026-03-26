/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.uctoo.uctoo_user

import magic.app.controllers.uctoo.uctoo_user.UctooUserAuthController
import magic.app.middlewares.auth.{DeserializeUserMiddleware, RequireUserMiddleware}
import magic.app.core.router.Router

/**
 * UctooUserAuthRoute - 用户认证路由
 * 
 * 提供用户认证相关的路由注册
 */
public class UctooUserAuthRoute {
    private var router: Router
    private var authController: UctooUserAuthController
    private var deserializeUserMiddleware: DeserializeUserMiddleware
    private var requireUserMiddleware: RequireUserMiddleware
    
    public init(
        router: Router,
        authController: UctooUserAuthController,
        deserializeUserMiddleware: DeserializeUserMiddleware,
        requireUserMiddleware: RequireUserMiddleware
    ) {
        this.router = router
        this.authController = authController
        this.deserializeUserMiddleware = deserializeUserMiddleware
        this.requireUserMiddleware = requireUserMiddleware
    }
    
    public func register(): Router {
        // ========== 公开接口（无需认证）==========

        // 用户登录
        router.post("/api/v1/uctoo/uctoo_user/signin", authController.signin)

        // 用户注册
        router.post("/api/v1/uctoo/uctoo_user/signup", authController.signup)

        // ========== 需要认证的接口 ==========

        // 用户登出（需要认证）
        router.post("/api/v1/uctoo/uctoo_user/logout", authController.logout)
            .use(deserializeUserMiddleware)
            .use(requireUserMiddleware)

        // 获取当前用户信息（需要认证）
        router.get("/api/v1/uctoo/uctoo_user/me", authController.me)
            .use(deserializeUserMiddleware)
            .use(requireUserMiddleware)

        // 重置密码（需要认证）
        router.post("/api/v1/uctoo/uctoo_user/resetpassword", authController.resetPassword)
            .use(deserializeUserMiddleware)
            .use(requireUserMiddleware)

        // 检查Token（需要认证）
        router.get("/api/v1/uctoo/uctoo_user/checktoken", authController.checkToken)
            .use(deserializeUserMiddleware)
            .use(requireUserMiddleware)

        return router
    }
}
