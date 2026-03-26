/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.uctoo_user

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.models.uctoo.UctooUserPO
import magic.app.services.uctoo.UctooUserService
import magic.app.utils.auth.{BcryptUtil, AuthorizeUtil, JWTUtil, AuthProvider}
import magic.log.LogUtils
import std.time.DateTime
import std.collection.{HashMap, Map, ArrayList}
import stdx.encoding.json.{JsonValue, JsonObject, JsonString}

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
     */
    public func signin(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = req.body
            let jsonValue = JsonValue.fromStr(body)
            
            if (!(jsonValue is JsonObject)) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"请求格式错误\"}")
                return
            }
            
            let obj = jsonValue.asObject()
            
            // 获取用户名和密码
            let username = getStringFromJson(obj, "username")
            let password = getStringFromJson(obj, "password")
            
            if (username.isEmpty() || password.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"用户名和密码不能为空\"}")
                return
            }
            
            // 查询用户
            let user = userService.findByUsername(username)
            if (user.isNone()) {
                res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"用户不存在\"}")
                return
            }
            
            let u = user.getOrThrow()
            
            // 验证密码
            if (!bcryptUtil.comparePassword(password, u.password)) {
                res.status(400).json("{\"errno\":\"42007\",\"errmsg\":\"登录失败，用户名或密码错误\"}")
                return
            }
            
            // 检查用户状态
            if (let Some(status) <- u.status) {
                if (status == 0) {
                    res.status(403).json("{\"errno\":\"40302\",\"errmsg\":\"用户已被禁用\"}")
                    return
                }
            }
            
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
            
            let result = userService.create(user)
            if (result.success) {
                if (let Some(newUser) <- result.data) {
                    // 注册成功，自动登录
                    authorizeUtil.authorizeAndEnd(newUser, req, res, AuthProvider.Local, true)
                } else {
                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"注册失败\"}")
                }
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
     * 重置密码
     * POST /api/v1/uctoo/uctoo_user/resetpassword
     */
    public func resetPassword(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = req.body
            let jsonValue = JsonValue.fromStr(body)
            
            if (!(jsonValue is JsonObject)) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"请求格式错误\"}")
                return
            }
            
            let obj = jsonValue.asObject()
            
            // 获取参数
            let userId = getStringFromJson(obj, "user_id")
            let oldPassword = getStringFromJson(obj, "old_password")
            let newPassword = getStringFromJson(obj, "new_password")
            
            if (userId.isEmpty() || oldPassword.isEmpty() || newPassword.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"参数不完整\"}")
                return
            }
            
            // 查询用户
            let userResult = userService.getById(userId)
            if (!userResult.success) {
                res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"用户不存在\"}")
                return
            }
            
            if (let Some(u) <- userResult.data) {
                // 验证旧密码
                if (!bcryptUtil.comparePassword(oldPassword, u.password)) {
                    res.status(400).json("{\"errno\":\"40005\",\"errmsg\":\"旧密码错误\"}")
                    return
                }
                
                // 更新密码
                let newHash = bcryptUtil.hashPassword(newPassword)
                u.password = newHash
                u.updatedAt = DateTime.now()
                
                if (userService.update(userId, u).success) {
                    res.status(200).json("{\"errno\":\"0\",\"errmsg\":\"密码重置成功\"}")
                } else {
                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"密码重置失败\"}")
                }
            } else {
                res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"用户不存在\"}")
            }
            
        } catch (e: Exception) {
            LogUtils.error("Reset password failed: ${e.message}")
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
    
    private func getStringFromJson(obj: JsonObject, key: String): String {
        if (let Some(value) <- obj.get(key)) {
            if (value is JsonString) {
                return value.asString().getValue()
            }
        }
        ""
    }
}
