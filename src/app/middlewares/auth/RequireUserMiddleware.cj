/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.middlewares.auth

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.middleware.Middleware
import magic.app.services.uctoo.UctooUserService
import magic.log.LogUtils

/**
 * RequireUserMiddleware - 用户认证检查中间件
 * 
 * 检查用户是否已登录，未登录返回403错误
 */
public class RequireUserMiddleware <: Middleware {
    private let userService: UctooUserService
    
    public init(userService: UctooUserService) {
        this.userService = userService
    }
    
    public func handle(req: HttpRequest, res: HttpResponse, next: () -> Unit): Unit {
        // 1. 检查是否登录
        let userId = req.getLocals("userId")
        
        if (userId is Option<Any>) {
            match (userId) {
                case None =>
                    // 未登录
                    res.status(403).json("{\"errno\":\"40300\",\"errmsg\":\"not login\"}")
                    return
                case Some(uid) =>
                    // 已登录，检查用户状态
                    if (checkUserStatus(uid, req)) {
                        next()
                    } else {
                        res.status(403).json("{\"errno\":\"40302\",\"errmsg\":\"user status invalid\"}")
                    }
            }
        } else {
            // 未设置用户信息
            res.status(403).json("{\"errno\":\"40300\",\"errmsg\":\"not login\"}")
        }
    }
    
    // ==================== 辅助方法 ====================
    
    /**
     * 检查用户状态
     */
    private func checkUserStatus(userId: Any, req: HttpRequest): Bool {
        // 将userId转换为String
        let uidStr = userId as String
        if (let Some(uid) <- uidStr) {
            // 查询用户信息
            let result = userService.getById(uid)
            if (result.success) {
                if (let Some(u) <- result.data) {
                    // 检查用户状态
                    if (let Some(status) <- u.status) {
                        if (status == 0) {
                            // 用户被禁用
                            LogUtils.info("User ${uid} is disabled")
                            return false
                        }
                    }
                    
                    // 检查是否被软删除
                    if (u.deletedAt.isSome()) {
                        LogUtils.info("User ${uid} is deleted")
                        return false
                    }
                    
                    // 设置完整用户信息到locals
                    req.setLocals("user", u)
                    return true
                }
            }
        }
        false
    }
}
