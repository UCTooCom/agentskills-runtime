/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.utils.auth

import magic.app.core.http.HttpResponse

/**
 * CookieUtil - Cookie管理工具类
 * 
 * 提供Cookie的设置和清除功能
 * 
 * 注意：当前版本为简化实现，Cookie通过响应头设置
 */
public class CookieUtil {
    private let isProduction: Bool
    private let domain: ?String
    
    public init(isProduction: Bool, domain: ?String) {
        this.isProduction = isProduction
        this.domain = domain
    }
    
    /**
     * 设置access_token Cookie
     * @param res HTTP响应对象
     * @param token access_token值
     */
    public func setAccessTokenCookie(res: HttpResponse, token: String): Unit {
        // 通过Set-Cookie响应头设置
        let cookieValue = buildCookieValue("access_token", token, 365 * 24 * 60 * 60, true)
        setCookieHeader(res, cookieValue)
    }
    
    /**
     * 设置refresh_token Cookie
     * @param res HTTP响应对象
     * @param token refresh_token值
     */
    public func setRefreshTokenCookie(res: HttpResponse, token: String): Unit {
        let cookieValue = buildCookieValue("refresh_token", token, 365 * 24 * 60 * 60, true)
        setCookieHeader(res, cookieValue)
    }
    
    /**
     * 清除认证Cookie
     * @param res HTTP响应对象
     */
    public func clearAuthCookies(res: HttpResponse): Unit {
        // 设置过期时间为过去时间来清除Cookie
        let expiredValue = buildCookieValue("access_token", "", -1, true)
        setCookieHeader(res, expiredValue)
        let expiredValue2 = buildCookieValue("refresh_token", "", -1, true)
        setCookieHeader(res, expiredValue2)
    }
    
    /**
     * 设置用户ID Cookie（可选，用于前端）
     * @param res HTTP响应对象
     * @param userId 用户ID
     */
    public func setUserIdCookie(res: HttpResponse, userId: String): Unit {
        let cookieValue = buildCookieValue("user_id", userId, 365 * 24 * 60 * 60, false)
        setCookieHeader(res, cookieValue)
    }
    
    /**
     * 清除用户ID Cookie
     * @param res HTTP响应对象
     */
    public func clearUserIdCookie(res: HttpResponse): Unit {
        let expiredValue = buildCookieValue("user_id", "", -1, false)
        setCookieHeader(res, expiredValue)
    }
    
    /**
     * 设置Cookie响应头
     */
    private func setCookieHeader(res: HttpResponse, cookieValue: String): Unit {
        // 使用HttpResponse的header方法设置Cookie
        res.header("Set-Cookie", cookieValue)
    }
    
    /**
     * 构建Cookie值字符串
     */
    private func buildCookieValue(name: String, value: String, maxAge: Int64, httpOnly: Bool): String {
        let sb = StringBuilder()
        sb.append("${name}=${value}")
        sb.append("; Path=/")
        if (maxAge > 0) {
            sb.append("; Max-Age=${maxAge}")
        } else {
            sb.append("; Max-Age=0")
        }
        if (isProduction) {
            sb.append("; Secure")
        }
        sb.append("; SameSite=Lax")
        if (httpOnly) {
            sb.append("; HttpOnly")
        }
        if (let Some(d) <- domain) {
            sb.append("; Domain=${d}")
        }
        sb.toString()
    }
}

/**
 * Cookie选项配置
 */
public class CookieOptions {
    public let maxAge: Int64
    public let httpOnly: Bool
    public let secure: Bool
    public let sameSite: String
    public let path: String
    public let domain: ?String
    
    public init(
        maxAge: Int64,
        httpOnly: Bool,
        secure: Bool,
        sameSite: String,
        path: String,
        domain: ?String
    ) {
        this.maxAge = maxAge
        this.httpOnly = httpOnly
        this.secure = secure
        this.sameSite = sameSite
        this.path = path
        this.domain = domain
    }
}
