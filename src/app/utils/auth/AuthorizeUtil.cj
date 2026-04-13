/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.utils.auth

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.models.uctoo.{UctooUserPO, UctooSessionPO}
import magic.app.services.uctoo.{UctooUserService, UctooSessionService, UserHasRolesService, UctooRoleService, RoleHasPermissionService, PermissionsService}
import magic.log.LogUtils
import std.time.DateTime
import std.env.getVariable
import std.collection.{ArrayList, HashSet}
import std.convert.*

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
    private let userHasRolesService: UserHasRolesService
    private let uctooRoleService: UctooRoleService
    private let roleHasPermissionService: RoleHasPermissionService
    private let permissionsService: PermissionsService
    
    public init(
        userService: UctooUserService,
        sessionService: UctooSessionService,
        jwtUtil: JWTUtil,
        cookieUtil: CookieUtil,
        userHasRolesService: UserHasRolesService,
        uctooRoleService: UctooRoleService,
        roleHasPermissionService: RoleHasPermissionService,
        permissionsService: PermissionsService
    ) {
        this.userService = userService
        this.sessionService = sessionService
        this.jwtUtil = jwtUtil
        this.cookieUtil = cookieUtil
        this.userHasRolesService = userHasRolesService
        this.uctooRoleService = uctooRoleService
        this.roleHasPermissionService = roleHasPermissionService
        this.permissionsService = permissionsService
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
                
                // 3. 更新用户access_token和refresh_token
                userService.updateTokens(user.id, accessToken, refreshToken)
                
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
        // 获取 Token TTL 配置
        let accessTokenTTL = getTokenTTL("ACCESS_TOKEN_VALIDITY_SEC", 1728000)
        let refreshTokenTTL = getTokenTTL("REFRESH_TOKEN_VALIDITY_SEC", 6048000)
        
        // 获取用户角色和权限
        let (roles, permissions) = getUserRolesAndPermissions(user.id)
        
        let sb = StringBuilder()
        sb.append("{")
        sb.append("\"errno\":\"0\",")
        sb.append("\"errmsg\":\"登录成功\",")
        sb.append("\"data\":{")
        sb.append("\"access_token\":\"${accessToken}\",")
        sb.append("\"refresh_token\":\"${refreshToken}\",")
        sb.append("\"access_token_ttl\":${accessTokenTTL},")
        sb.append("\"refresh_token_ttl\":${refreshTokenTTL},")
        sb.append("\"uctoo_user\":${userToJsonWithRolesAndPermissions(user, roles, permissions)}")
        sb.append("}")
        sb.append("}")
        sb.toString()
    }
    
    /**
     * 获取 Token TTL 配置
     * @param envKey 环境变量键名
     * @param defaultValue 默认值（秒）
     * @return TTL 值（秒）
     */
    private func getTokenTTL(envKey: String, defaultValue: Int64): Int64 {
        try {
            let envValue = getVariable(envKey)
            if (let Some(value) <- envValue) {
                let parsed = Int64.parse(value)
                if (let v <- parsed) {
                    v
                } else {
                    defaultValue
                }
            } else {
                defaultValue
            }
        } catch (e: Exception) {
            LogUtils.error("Failed to get Token TTL: ${e.message}")
            defaultValue
        }
    }
    
    /**
     * 获取用户角色和权限
     * @param userId 用户ID
     * @return (角色列表, 权限列表)
     */
    private func getUserRolesAndPermissions(userId: String): (ArrayList<String>, ArrayList<String>) {
        let roles = ArrayList<String>()
        let permissions = ArrayList<String>()
        
        try {
            // 1. 获取用户的角色关联
            let userRoles = userHasRolesService.findByUserId(userId)
            
            // 2. 获取角色ID列表
            let roleIds = ArrayList<String>()
            for (userRole in userRoles) {
                roleIds.add(userRole.roleId)
            }
            
            // 3. 获取角色详情
            for (roleId in roleIds) {
                let roleResult = uctooRoleService.getById(roleId)
                if (roleResult.success) {
                    if (let Some(role) <- roleResult.data) {
                        roles.add(role.name)
                    }
                }
            }
            
            // 4. 获取角色的权限
            let rolePermissions = roleHasPermissionService.findByRoleIds(roleIds)
            
            // 5. 获取权限名称列表（去重）
            let permissionSet = HashSet<String>()
            for (rolePermission in rolePermissions) {
                permissionSet.add(rolePermission.permissionName)
            }
            
            for (permissionName in permissionSet) {
                permissions.add(permissionName)
            }
            
        } catch (e: Exception) {
            LogUtils.error("Failed to get user roles and permissions: ${e.message}")
        }
        
        (roles, permissions)
    }
    
    /**
     * 将用户对象转换为JSON（包含角色和权限）
     */
    private func userToJsonWithRolesAndPermissions(user: UctooUserPO, roles: ArrayList<String>, permissions: ArrayList<String>): String {
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
        
        // 添加角色信息
        sb.append("\"roles\":[")
        for (i in 0..roles.size) {
            if (i > 0) {
                sb.append(",")
            }
            sb.append("\"${roles[i]}\"")
        }
        sb.append("],")
        
        // 添加权限信息
        sb.append("\"permissions\":[")
        for (i in 0..permissions.size) {
            if (i > 0) {
                sb.append(",")
            }
            sb.append("\"${permissions[i]}\"")
        }
        sb.append("]")
        
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
