/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.middlewares.auth

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.middleware.Middleware
import magic.app.utils.auth.{JWTUtil, CookieUtil}
import magic.app.services.uctoo.UctooSessionService
import magic.log.LogUtils

/**
 * DeserializeUserMiddleware - Token反序列化中间件
 * 
 * 从请求中提取Token，验证并设置用户信息到req.locals
 * 支持Token自动刷新机制
 */
public class DeserializeUserMiddleware <: Middleware {
    private let jwtUtil: JWTUtil
    private let sessionService: UctooSessionService
    private let cookieUtil: CookieUtil
    
    public init(jwtUtil: JWTUtil, sessionService: UctooSessionService, cookieUtil: CookieUtil) {
        this.jwtUtil = jwtUtil
        this.sessionService = sessionService
        this.cookieUtil = cookieUtil
    }
    
    public func handle(req: HttpRequest, res: HttpResponse, next: () -> Unit): Unit {
        LogUtils.info("DeserializeUserMiddleware", "=== handle() called ===")

        // 1. 获取access_token
        let accessToken = getAccessToken(req)
        let refreshToken = getRefreshToken(req)

        LogUtils.info("DeserializeUserMiddleware", "=== accessToken: ${accessToken} ===")

        if (accessToken.isEmpty()) {
            // 没有Token，继续处理（可能是公开接口）
            LogUtils.info("DeserializeUserMiddleware", "=== No token, continuing ===")
            next()
            return
        }

        // 2. 验证access_token
        let payload = jwtUtil.verifyToken(accessToken)
        if (let Some(p) <- payload) {
            // Token有效，设置用户信息
            LogUtils.info("DeserializeUserMiddleware", "=== Token valid, userId: ${p.userId} ===")
            setUserToLocals(req, p.userId, p.sessionId)
            next()
            return
        }

        // 3. access_token过期，尝试用refresh_token刷新
        if (let Some(refresh) <- refreshToken) {
            if (refreshTokenAndSetUser(req, res, refresh)) {
                // 刷新成功，继续处理
                next()
                return
            }
        }

        // Token无效且刷新失败，继续处理（由RequireUserMiddleware处理）
        LogUtils.info("DeserializeUserMiddleware", "=== Token invalid, continuing ===")
        next()
    }
    
    // ==================== 辅助方法 ====================
    
    /**
     * 获取access_token
     */
    private func getAccessToken(req: HttpRequest): String {
        // 优先从Authorization header获取（尝试多种大小写）
        let authHeader = req.header("Authorization")
        let authHeader2 = req.header("authorization")
        let authHeaderLower = req.header("authorization")
        
        let authValue = if (let Some(h) <- authHeader) {
            h
        } else if (let Some(h) <- authHeader2) {
            h
        } else if (let Some(h) <- authHeaderLower) {
            h
        } else {
            ""
        }
        
        if (!authValue.isEmpty() && authValue.startsWith("Bearer ")) {
            return authValue[7..authValue.size]
        }
        
        // 从Cookie获取
        let cookieHeader = req.header("Cookie")
        if (let Some(cookieStr) <- cookieHeader) {
            // 解析Cookie字符串
            let cookies = cookieStr.split(";")
            for (cookie in cookies) {
                let trimmed = cookie.trimAscii()
                if (trimmed.startsWith("access_token=")) {
                    return trimmed[13..trimmed.size]
                }
            }
        }
        
        ""
    }
    
    /**
     * 获取refresh_token
     */
    private func getRefreshToken(req: HttpRequest): ?String {
        // 优先从header获取
        let headerToken = req.header("x-refresh")
        if (let Some(token) <- headerToken) {
            return Some<String>(token)
        }
        
        // 从Cookie获取
        let cookieHeader = req.header("Cookie")
        if (let Some(cookieStr) <- cookieHeader) {
            // 解析Cookie字符串
            let cookies = cookieStr.split(";")
            for (cookie in cookies) {
                let trimmed = cookie.trimAscii()
                if (trimmed.startsWith("refresh_token=")) {
                    return Some<String>(trimmed[14..trimmed.size])
                }
            }
        }
        
        None<String>
    }
    
    /**
     * 设置用户信息到req.locals
     */
    private func setUserToLocals(req: HttpRequest, userId: String, sessionId: String): Unit {
        // 设置用户ID和会话ID到locals
        req.setLocals("userId", userId)
        req.setLocals("sessionId", sessionId)
    }
    
    /**
     * 刷新Token并设置用户信息
     */
    private func refreshTokenAndSetUser(req: HttpRequest, res: HttpResponse, refreshToken: String): Bool {
        // 验证refresh_token
        let payload = jwtUtil.verifyToken(refreshToken)
        if (let Some(p) <- payload) {
            // 查找会话
            let session = sessionService.findById(p.sessionId)
            if (let Some(s) <- session) {
                // 检查会话是否有效
                if (!s.valid) {
                    return false
                }
                
                // 生成新的access_token
                let newAccessToken = jwtUtil.generateAccessToken(p.userId, p.sessionId)
                
                // 设置新的Token到响应头
                res.header("x-access-token", newAccessToken)
                res.header("Authorization", "Bearer ${newAccessToken}")
                
                // 设置新的Cookie
                cookieUtil.setAccessTokenCookie(res, newAccessToken)
                
                // 设置用户信息
                setUserToLocals(req, p.userId, p.sessionId)
                
                LogUtils.info("Token refreshed for user: ${p.userId}")
                return true
            }
        }
        false
    }
}
