/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.utils.auth

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.models.uctoo.{UctooUserPO, UctooSessionPO}
import magic.app.services.uctoo.{UctooUserService, UctooSessionService}
import magic.log.LogUtils
import std.time.DateTime

/**
 * AuthorizeUtil - 授权工具类
 * 
 * 封装完整的授权流程
 */
public class AuthorizeUtil {
    private let userService: UctooUserService
    private let sessionService: UctooSessionService
    private let jwtUtil: JWTUtil
    private let cookieUtil: CookieUtil
    
    public init(
        userService: UctooUserService,
        sessionService: UctooSessionService,
        jwtUtil: JWTUtil,
        cookieUtil: CookieUtil
    ) {
        this.userService = userService
        this.sessionService = sessionService
        this.jwtUtil = jwtUtil
        this.cookieUtil = cookieUtil
    }
    
    /**
     * 授权并结束请求（本地登录）
     * @param user 用户对象
     * @param req HTTP请求对象
     * @param res HTTP响应对象
     * @param authProvider 认证提供者
     */
    public func authorizeAndEnd(user: UctooUserPO, req: HttpRequest, res: HttpResponse, authProvider: Int32): Unit {
        authorizeAndEnd(user, req, res, authProvider, true)
    }
    
    /**
     * 授权并结束请求
     * @param user 用户对象
     * @param req HTTP请求对象
     * @param res HTTP响应对象
     * @param authProvider 认证提供者
     * @param isLocal 是否本地登录
     */
    public func authorizeAndEnd(user: UctooUserPO, req: HttpRequest, res: HttpResponse, authProvider: Int32, isLocal: Bool): Unit {
        try {
            // 1. 创建会话
            let userAgent = req.header("user-agent") ?? "No agent detected"
            let ip = getClientIp(req)
            
            let session = sessionService.createSession(
                user.id,
                userAgent,
                ip,
                authProvider
            )
            
            if (let Some(s) <- session) {
                // 2. 生成Token
                let accessToken = jwtUtil.generateAccessToken(user.id, s.id)
                let refreshToken = jwtUtil.generateRefreshToken(user.id, s.id)
                
                // 3. 更新用户access_token
                userService.updateAccessToken(user.id, accessToken)
                
                // 4. 设置Cookie
                cookieUtil.setAccessTokenCookie(res, accessToken)
                cookieUtil.setRefreshTokenCookie(res, refreshToken)
                cookieUtil.setUserIdCookie(res, user.id)
                
                // 5. 返回响应
                if (!isLocal) {
                    // OAuth登录，重定向到前端
                    let frontendUrl = "http://localhost:4200/"  // TODO: 从配置读取
                    res.status(302).header("Location", frontendUrl)
                } else {
                    // 本地登录，返回JSON
                    let responseData = buildLoginResponse(user, accessToken, refreshToken)
                    res.status(200).json(responseData)
                }
            } else {
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"创建会话失败\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("Authorize failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }
    
    /**
     * 刷新Token
     * @param refreshToken refresh_token
     * @param res HTTP响应对象
     * @return 刷新成功返回true，失败返回false
     */
    public func refreshToken(refreshToken: String, res: HttpResponse): Bool {
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
                
                // 更新用户access_token
                userService.updateAccessToken(p.userId, newAccessToken)
                
                // 设置新的Cookie
                cookieUtil.setAccessTokenCookie(res, newAccessToken)
                
                return true
            }
        }
        false
    }
    
    /**
     * 登出
     * @param userId 用户ID
     * @param sessionId 会话ID
     * @param res HTTP响应对象
     */
    public func logout(userId: String, sessionId: String, res: HttpResponse): Unit {
        // 1. 使会话失效
        sessionService.updateStatus(sessionId, false)
        
        // 2. 清除用户access_token
        userService.updateAccessToken(userId, "")
        
        // 3. 清除Cookie
        cookieUtil.clearAuthCookies(res)
        cookieUtil.clearUserIdCookie(res)
    }
    
    // ==================== 辅助方法 ====================
    
    /**
     * 获取客户端IP
     */
    private func getClientIp(req: HttpRequest): String {
        // 尝试从X-Forwarded-For获取
        let forwardedFor = req.header("x-forwarded-for")
        if (let Some(ips) <- forwardedFor) {
            let parts = ips.split(",")
            if (!parts.isEmpty()) {
                return parts[0].trimAscii()
            }
        }
        
        // 尝试从X-Real-IP获取
        let realIp = req.header("x-real-ip")
        if (let Some(ip) <- realIp) {
            return ip
        }
        
        // 返回默认值
        "unknown"
    }
    
    /**
     * 构建登录响应
     */
    private func buildLoginResponse(user: UctooUserPO, accessToken: String, refreshToken: String): String {
        let sb = StringBuilder()
        sb.append("{")
        sb.append("\"errno\":\"0\",")
        sb.append("\"errmsg\":\"登录成功\",")
        sb.append("\"data\":{")
        sb.append("\"access_token\":\"${accessToken}\",")
        sb.append("\"refresh_token\":\"${refreshToken}\",")
        sb.append("\"user\":${userToJsonWithoutPassword(user)}")
        sb.append("}")
        sb.append("}")
        sb.toString()
    }
    
    /**
     * 将用户对象转换为JSON,但不包含password字段
     * 安全考虑:密码字段不应通过API返回
     */
    private func userToJsonWithoutPassword(user: UctooUserPO): String {
        let sb = StringBuilder()
        sb.append("{")
        sb.append("\"id\":\"${user.id}\",")
        sb.append("\"name\":\"${user.name}\",")
        sb.append("\"username\":\"${user.username}\",")
        sb.append("\"email\":\"${user.email}\",")
        // password字段已移除,不返回给客户端
        if (let Some(v) <- user.avatar) {
            sb.append("\"avatar\":\"${v}\",")
        } else {
            sb.append("\"avatar\":\"\",")
        }
        sb.append("\"created_at\":\"${user.createdAt}\",")
        sb.append("\"last_login\":\"${user.lastLogin}\",")
        if (let Some(v) <- user.authProvider) {
            sb.append("\"auth_provider\":${v},")
        } else {
            sb.append("\"auth_provider\":null,")
        }
        if (let Some(v) <- user.creator) {
            sb.append("\"creator\":\"${v}\",")
        } else {
            sb.append("\"creator\":\"\",")
        }
        if (let Some(v) <- user.deletedAt) {
            sb.append("\"deleted_at\":\"${v}\",")
        } else {
            sb.append("\"deleted_at\":\"\",")
        }
        if (let Some(v) <- user.lastLoginIp) {
            sb.append("\"last_login_ip\":\"${v}\",")
        } else {
            sb.append("\"last_login_ip\":\"\",")
        }
        sb.append("\"last_login_time\":\"${user.lastLoginTime}\",")
        if (let Some(v) <- user.rememberToken) {
            sb.append("\"remember_token\":\"${v}\",")
        } else {
            sb.append("\"remember_token\":\"\",")
        }
        if (let Some(v) <- user.status) {
            sb.append("\"status\":${v},")
        } else {
            sb.append("\"status\":null,")
        }
        sb.append("\"updated_at\":\"${user.updatedAt}\",")
        if (let Some(v) <- user.accessToken) {
            sb.append("\"access_token\":\"${v}\"")
        } else {
            sb.append("\"access_token\":\"\"")
        }
        sb.append("}")
        sb.toString()
    }
}

/**
 * 认证提供者枚举
 */
public class AuthProvider {
    public static let Local: Int32 = 0
    public static let GitHub: Int32 = 1
    public static let Google: Int32 = 2
    public static let WechatOpen: Int32 = 3
    public static let WechatMini: Int32 = 4
    public static let QintongTeacher: Int32 = 5
}
