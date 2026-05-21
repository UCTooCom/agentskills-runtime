/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.uctoo_user

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.models.uctoo.UctooUserPO
import magic.app.services.uctoo.{UctooUserService, LoginLogService}
import magic.app.utils.auth.{BcryptUtil, AuthorizeUtil, JWTUtil, AuthProvider}
import magic.log.LogUtils
import std.time.DateTime
import std.collection.{HashMap, Map, ArrayList}
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonFloat, JsonBool}

/**
 * UctooUserAuthController - 用户认证控制器
 * 
 * 提供用户登录、注册、登出等认证功能
 */
public class UctooUserAuthController {
    private let userService: UctooUserService
    private let bcryptUtil: BcryptUtil
    private let authorizeUtil: AuthorizeUtil
    private let jwtUtil: JWTUtil
    
    public init(
        userService: UctooUserService,
        bcryptUtil: BcryptUtil,
        authorizeUtil: AuthorizeUtil,
        jwtUtil: JWTUtil
    ) {
        this.userService = userService
        this.bcryptUtil = bcryptUtil
        this.authorizeUtil = authorizeUtil
        this.jwtUtil = jwtUtil
    }
    
    /**
     * 用户登录
     * POST /api/v1/uctoo/uctoo_user/signin
     * 
     * 支持两种登录方式：
     * 1. 用户名 + 密码：{ "username": "xxx", "password": "xxx" }
     * 2. 邮箱 + 密码：{ "email": "xxx@example.com", "password": "xxx" }
     */
    public func signin(req: HttpRequest, res: HttpResponse): Unit {
        try {
            // 获取客户端信息用于记录登录日志
            let clientIp = getClientIp(req)
            let userAgent = req.header("User-Agent") ?? ""
            let (browser, os) = parseUserAgent(userAgent)
            
            let body = req.body
            let jsonValue = JsonValue.fromStr(body)
            
            if (!(jsonValue is JsonObject)) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"请求格式错误\"}")
                return
            }
            
            let obj = jsonValue.asObject()
            
            // 获取用户名/邮箱和密码
            let username = getStringFromJson(obj, "username")
            let email = getStringFromJson(obj, "email")
            let password = getStringFromJson(obj, "password")
            
            // 支持用户名或邮箱登录
            let loginAccount = if (username.isEmpty()) { email } else { username }
            
            if (loginAccount.isEmpty() || password.isEmpty()) {
                // 记录登录失败日志
                LoginLogService.recordLoginFailed(loginAccount, clientIp, browser, os)
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"用户名/邮箱和密码不能为空\"}")
                return
            }
            
            // 查询用户（优先按用户名查询，如果包含@则按邮箱查询）
            let user = if (loginAccount.contains('@')) {
                userService.findByEmail(loginAccount)
            } else {
                userService.findByUsername(loginAccount)
            }
            
            if (user.isNone()) {
                // 记录登录失败日志
                LoginLogService.recordLoginFailed(loginAccount, clientIp, browser, os)
                res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"用户不存在\"}")
                return
            }
            
            let u = user.getOrThrow()
            
            // 验证密码
            if (!bcryptUtil.comparePassword(password, u.password)) {
                // 记录登录失败日志
                LoginLogService.recordLoginFailed(loginAccount, clientIp, browser, os)
                res.status(400).json("{\"errno\":\"42007\",\"errmsg\":\"登录失败，用户名或密码错误\"}")
                return
            }
            
            // 检查用户状态
            if (u.status == 0) {
                // 记录登录失败日志
                LoginLogService.recordLoginFailed(loginAccount, clientIp, browser, os)
                res.status(403).json("{\"errno\":\"40302\",\"errmsg\":\"用户已被禁用\"}")
                return
            }
            
            // 记录登录成功日志
            LoginLogService.recordLoginSuccess(loginAccount, clientIp, browser, os, Some<String>(u.id))
            
            // 授权登录
            authorizeUtil.authorizeAndEnd(u, req, res, AuthProvider.Local, true)
            
        } catch (e: Exception) {
            LogUtils.error("Signin failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }
    
    /**
     * 用户注册
     * POST /api/v1/uctoo/uctoo_user/signup
     */
    public func signup(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = req.body
            let jsonValue = JsonValue.fromStr(body)
            
            if (!(jsonValue is JsonObject)) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"请求格式错误\"}")
                return
            }
            
            let obj = jsonValue.asObject()
            
            // 获取注册信息
            let name = getStringFromJson(obj, "name")
            let username = getStringFromJson(obj, "username")
            let email = getStringFromJson(obj, "email")
            let password = getStringFromJson(obj, "password")
            
            if (username.isEmpty() || email.isEmpty() || password.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"用户名、邮箱和密码不能为空\"}")
                return
            }
            
            // 检查用户名是否已存在
            if (userService.findByUsername(username).isSome()) {
                res.status(400).json("{\"errno\":\"40003\",\"errmsg\":\"用户名已存在\"}")
                return
            }
            
            // 检查邮箱是否已存在
            if (userService.findByEmail(email).isSome()) {
                res.status(400).json("{\"errno\":\"40004\",\"errmsg\":\"邮箱已存在\"}")
                return
            }
            
            // 创建用户
            let user = UctooUserPO()
            user.name = if (name.isEmpty()) { username } else { name }
            user.username = username
            user.email = email
            user.password = bcryptUtil.hashPassword(password)
            user.authProvider = AuthProvider.Local
            user.status = 1
            user.createdAt = DateTime.now()
            
            let result = userService.create(user, "")
            if (result.success) {
                // 注册成功，自动登录
                authorizeUtil.authorizeAndEnd(user, req, res, AuthProvider.Local, true)
            } else {
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"注册失败\"}")
            }
            
        } catch (e: Exception) {
            LogUtils.error("Signup failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }
    
    /**
     * 用户登出
     * POST /api/v1/uctoo/uctoo_user/logout
     */
    public func logout(req: HttpRequest, res: HttpResponse): Unit {
        try {
            // 获取用户信息
            let userId = req.getLocals("userId")
            let sessionId = req.getLocals("sessionId")
            
            if (userId is Option<Any>) {
                match (userId) {
                    case Some(uid) =>
                        let uidStr = uid as String
                        let sidStr = if (sessionId is Option<Any>) {
                            match (sessionId) {
                                case Some(sid) =>
                                    let s = sid as String
                                    if (let Some(str) <- s) { str } else { "" }
                                case None => ""
                            }
                        } else { "" }
                        
                        if (let Some(userIdStr) <- uidStr) {
                            // 执行登出
                            authorizeUtil.logout(userIdStr, sidStr, res)
                            res.status(200).json("{\"errno\":\"0\",\"errmsg\":\"登出成功\"}")
                        } else {
                            res.status(200).json("{\"errno\":\"0\",\"errmsg\":\"登出成功\"}")
                        }
                    case None =>
                        res.status(200).json("{\"errno\":\"0\",\"errmsg\":\"登出成功\"}")
                }
            } else {
                res.status(200).json("{\"errno\":\"0\",\"errmsg\":\"登出成功\"}")
            }
            
        } catch (e: Exception) {
            LogUtils.error("Logout failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }
    
    /**
     * 获取当前用户信息
     * GET /api/v1/uctoo/uctoo_user/me
     */
    public func me(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let user = req.getLocals("user")
            
            if (user is Option<Any>) {
                match (user) {
                    case Some(u) =>
                        let userPO = u as UctooUserPO
                        if (let Some(userObj) <- userPO) {
                            res.status(200).json(userObj.toJson())
                        } else {
                            res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"用户不存在\"}")
                        }
                    case None =>
                        res.status(403).json("{\"errno\":\"40300\",\"errmsg\":\"未登录\"}")
                }
            } else {
                res.status(403).json("{\"errno\":\"40300\",\"errmsg\":\"未登录\"}")
            }
            
        } catch (e: Exception) {
            LogUtils.error("Get user info failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }
    
    /**
     * 管理员重置密码
     * POST /api/v1/uctoo/uctoo_user/resetpassword
     * 
     * 管理员强制重置用户密码，无需验证旧密码
     * 参数：{ "email": "xxx@example.com", "new_password": "xxx" }
     */
    public func resetPassword(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = req.body
            LogUtils.info("ResetPassword", "=== Received body: [${body}] ===")
            LogUtils.info("ResetPassword", "=== Body length: ${body.size} ===")

            if (body.isEmpty()) {
                LogUtils.error("ResetPassword", "=== Body is empty! ===")
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"请求体为空\"}")
                return
            }

            let jsonValue = JsonValue.fromStr(body)
            LogUtils.info("ResetPassword", "=== JSON parsed, type check: isJsonObject=${jsonValue is JsonObject} ===")
            
            if (!(jsonValue is JsonObject)) {
                LogUtils.error("ResetPassword", "=== JSON is not JsonObject! ===")
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"请求格式错误\"}")
                return
            }
            
            let obj = jsonValue.asObject()
            LogUtils.info("ResetPassword", "=== JsonObject fields count: iterating to log keys ===")
            for ((key, value) in obj.getFields()) {
                if (value is JsonString) {
                    LogUtils.info("ResetPassword", "=== Field: ${key} = ${value.asString().getValue()} ===")
                } else {
                    LogUtils.info("ResetPassword", "=== Field: ${key} = (non-string type) ===")
                }
            }
            
            let email = getStringFromJson(obj, "email")
            let newPassword = getStringFromJson(obj, "new_password")
            LogUtils.info("ResetPassword", "=== Parsed email: [${email}], newPassword: [${newPassword}] ===")

            if (email.isEmpty() || newPassword.isEmpty()) {
                LogUtils.error("ResetPassword", "=== Parameter missing! email.isEmpty=${email.isEmpty()}, newPassword.isEmpty=${newPassword.isEmpty()} ===")
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"参数不完整，email和new_password不能为空\"}")
                return
            }

            let userResult = userService.findByEmail(email)
            LogUtils.info("ResetPassword", "=== findByEmail result: isNone=${userResult.isNone()} ===")
            if (userResult.isNone()) {
                res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"用户不存在\"}")
                return
            }

            if (let Some(u) <- userResult) {
                let newHash = bcryptUtil.hashPassword(newPassword)
                u.password = newHash
                u.updatedAt = DateTime.now()

                if (userService.update(u.id, u).success) {
                    LogUtils.info("ResetPassword", "=== Password reset success for user: ${email} ===")
                    res.status(200).json("{\"errno\":\"0\",\"errmsg\":\"密码重置成功\"}")
                } else {
                    LogUtils.error("ResetPassword", "=== Password reset failed for user: ${email} ===")
                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"密码重置失败\"}")
                }
            } else {
                res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"用户不存在\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("ResetPassword", "=== Exception: ${e.message} ===")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }
    
    /**
     * 检查Token
     * GET /api/v1/uctoo/uctoo_user/checktoken
     */
    public func checkToken(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            
            if (userId is Option<Any>) {
                match (userId) {
                    case Some(uid) =>
                        res.status(200).json("{\"errno\":\"0\",\"errmsg\":\"Token有效\"}")
                    case None =>
                        res.status(403).json("{\"errno\":\"40300\",\"errmsg\":\"Token无效\"}")
                }
            } else {
                res.status(403).json("{\"errno\":\"40300\",\"errmsg\":\"Token无效\"}")
            }
            
        } catch (e: Exception) {
            LogUtils.error("Check token failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }
    
    // ==================== 辅助方法 ====================
    
    /**
     * 获取客户端IP地址
     */
    private func getClientIp(req: HttpRequest): String {
        // 优先从 X-Forwarded-For 获取（经过代理）
        let xForwardedFor = req.header("X-Forwarded-For") ?? ""
        if (!xForwardedFor.isEmpty()) {
            // X-Forwarded-For 可能包含多个IP，取第一个
            let parts = xForwardedFor.split(",")
            if (parts.size > 0) {
                return parts[0].trimAscii()
            }
        }
        
        // 其次从 X-Real-IP 获取
        let xRealIp = req.header("X-Real-IP") ?? ""
        if (!xRealIp.isEmpty()) {
            return xRealIp.trimAscii()
        }
        
        // 最后从 Remote-Addr 获取
        let remoteAddr = req.header("Remote-Addr") ?? ""
        if (!remoteAddr.isEmpty()) {
            return remoteAddr.trimAscii()
        }
        
        return "127.0.0.1"
    }
    
    /**
     * 解析User-Agent，提取浏览器和操作系统信息
     */
    private func parseUserAgent(userAgent: String): (String, String) {
        let browser: String
        let os: String
        
        // 解析浏览器
        if (userAgent.contains("Edg")) {
            browser = "Edge"
        } else if (userAgent.contains("Chrome") && !userAgent.contains("Edg")) {
            browser = "Chrome"
        } else if (userAgent.contains("Firefox")) {
            browser = "Firefox"
        } else if (userAgent.contains("Safari") && !userAgent.contains("Chrome")) {
            browser = "Safari"
        } else if (userAgent.contains("Opera") || userAgent.contains("OPR")) {
            browser = "Opera"
        } else {
            browser = "Unknown"
        }
        
        // 解析操作系统
        if (userAgent.contains("Windows")) {
            os = "Windows"
        } else if (userAgent.contains("Mac OS X")) {
            os = "MacOS"
        } else if (userAgent.contains("Linux") && !userAgent.contains("Android")) {
            os = "Linux"
        } else if (userAgent.contains("Android")) {
            os = "Android"
        } else if (userAgent.contains("iPhone") || userAgent.contains("iPad") || userAgent.contains("iOS")) {
            os = "iOS"
        } else {
            os = "Unknown"
        }
        
        return (browser, os)
    }
    
    private func getStringFromJson(obj: JsonObject, key: String): String {
        let valueOpt = obj.get(key)
        if (valueOpt.isNone()) {
            LogUtils.info("GetStringFromJson", "=== Key '${key}' not found in JsonObject ===")
            return ""
        }
        if (let Some(value) <- valueOpt) {
            if (value is JsonString) {
                return value.asString().getValue()
            } else {
                LogUtils.info("GetStringFromJson", "=== Key '${key}' value is not JsonString, type mismatch ===")
            }
        }
        ""
    }

    private func parseBody(req: HttpRequest): ?Map<String, Any> {
        try {
            let body = req.body

            if (body.isEmpty()) {
                return None<Map<String, Any>>
            }

            let jsonValue = JsonValue.fromStr(body)
            if (!(jsonValue is JsonObject)) {
                return None<Map<String, Any>>
            }

            let jsonObj = jsonValue.asObject()
            let map = HashMap<String, Any>()

            for ((key, value) in jsonObj.getFields()) {
                let anyValue = jsonValueToAny(value)
                map.add(key, anyValue)
            }

            return Some<Map<String, Any>>(map)
        } catch (e: Exception) {
            return None<Map<String, Any>>
        }
    }

    private func jsonValueToAny(value: JsonValue): Any {
        if (value is JsonString) {
            return value.asString().getValue()
        } else if (value is JsonInt) {
            return value.asInt().getValue()
        } else if (value is JsonFloat) {
            return value.asFloat().getValue()
        } else if (value is JsonBool) {
            return value.asBool().getValue()
        } else {
            return ""
        }
    }
}
