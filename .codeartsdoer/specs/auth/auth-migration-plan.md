# UCToo Backend V3 登录鉴权机制迁移至 agentskills-runtime 方案

**文档版本**: 1.0.0  
**创建日期**: 2026-03-16  
**目标**: 将 uctoo backend v3 的完整登录鉴权机制迁移到 agentskills-runtime,实现完全一致的登录、鉴权、权限体系

---

## 一、迁移背景与目标

### 1.1 迁移背景

**源系统**: uctoo-backend V3.0 (Node.js/TypeScript)
- 成熟的登录鉴权体系
- 支持多种认证方式
- 完善的权限控制机制
- 经过生产环境验证

**目标系统**: agentskills-runtime (仓颉语言)
- 已实现基础中间件架构
- 已有 JWT 和权限中间件框架
- 需要完善完整的鉴权体系

### 1.2 迁移目标

1. **功能对等**: 实现与 V3 完全一致的登录鉴权功能
2. **架构一致**: 保持三层架构和中间件设计
3. **性能提升**: 利用仓颉语言特性提升性能
4. **安全增强**: 保持或提升安全级别
5. **可扩展性**: 支持未来功能扩展

---

## 二、现状对比分析

### 2.1 V3 鉴权机制完整功能清单

#### 2.1.1 认证方式
| 认证方式 | V3 实现状态 | Runtime 实现状态 | 差异 |
|---------|-----------|----------------|------|
| 本地账号密码登录 | ✅ 完整实现 | ❌ 未实现 | 需迁移 |
| GitHub OAuth | ✅ 完整实现 | ❌ 未实现 | 需迁移 |
| Google OAuth | ✅ 完整实现 | ❌ 未实现 | 需迁移 |
| 微信公众号登录 | ✅ 完整实现 | ❌ 未实现 | 需迁移 |
| 微信小程序登录 | ✅ 完整实现 | ❌ 未实现 | 需迁移 |
| 验证码登录 | ✅ 完整实现 | ❌ 未实现 | 需迁移 |

#### 2.1.2 Token 机制
| 功能 | V3 实现状态 | Runtime 实现状态 | 差异 |
|-----|-----------|----------------|------|
| JWT Token 生成 | ✅ jsonwebtoken | ⚠️ 框架存在,未实现 | 需集成 jwt4cj |
| access_token | ✅ 20天有效期 | ❌ 未实现 | 需迁移 |
| refresh_token | ✅ 1年有效期 | ❌ 未实现 | 需迁移 |
| Token 自动刷新 | ✅ deserializeUser | ❌ 未实现 | 需迁移 |
| HttpOnly Cookie | ✅ 完整实现 | ❌ 未实现 | 需迁移 |

#### 2.1.3 权限控制
| 功能 | V3 实现状态 | Runtime 实现状态 | 差异 |
|-----|-----------|----------------|------|
| 用户组权限 | ✅ user_group | ❌ 未实现 | 需迁移 |
| 路由级权限 | ✅ requireUser | ⚠️ 简化实现 | 需完善 |
| 行级数据权限 | ✅ rowLevelPermission | ⚠️ 框架存在 | 需完善 |
| 权限检查逻辑 | ✅ 先查/*再查具体 | ⚠️ 简化实现 | 需完善 |

#### 2.1.4 会话管理
| 功能 | V3 实现状态 | Runtime 实现状态 | 差异 |
|-----|-----------|----------------|------|
| Session 创建 | ✅ 完整实现 | ❌ 未实现 | 需迁移 |
| Session 验证 | ✅ 完整实现 | ❌ 未实现 | 需迁移 |
| Session 失效 | ✅ 完整实现 | ❌ 未实现 | 需迁移 |
| Redis 缓存 | ✅ 完整实现 | ⚠️ CacheManager 存在 | 需集成 redis-sdk |

#### 2.1.5 数据库模型
| 模型 | V3 实现状态 | Runtime 实现状态 | 差异 |
|-----|-----------|----------------|------|
| uctoo_user | ✅ 完整字段 | ❌ 未实现 | 需创建 |
| uctoo_session | ✅ 完整字段 | ❌ 未实现 | 需创建 |
| user_group | ✅ 完整字段 | ❌ 未实现 | 需创建 |
| user_has_group | ✅ 完整字段 | ❌ 未实现 | 需创建 |
| group_has_permission | ✅ 完整字段 | ❌ 未实现 | 需创建 |
| permissions | ✅ 完整字段 | ❌ 未实现 | 需创建 |
| user_has_account | ✅ 完整字段 | ❌ 未实现 | 需创建 |

#### 2.1.6 权限节点体系
| 功能 | V3 实现状态 | Runtime 实现状态 | 差异 |
|-----|-----------|----------------|------|
| 权限节点定义 | ✅ permissions 表 | ❌ 未实现 | 需迁移 |
| 树形权限结构 | ✅ parent_id/children | ❌ 未实现 | 需迁移 |
| 权限类型分类 | ✅ type字段(菜单/按钮/接口) | ❌ 未实现 | 需迁移 |
| 前端路由映射 | ✅ path/component | ❌ 未实现 | 需迁移 |
| HTTP方法控制 | ✅ method字段 | ❌ 未实现 | 需迁移 |
| 权限元数据 | ✅ meta字段(JSON) | ❌ 未实现 | 需迁移 |

### 2.2 Runtime 当前实现分析

#### 2.2.1 已实现功能
```
✅ HTTP 服务器
✅ 路由系统
✅ 中间件机制
✅ JWT 认证中间件框架
✅ 权限中间件框架
✅ 行级权限中间件框架
✅ 缓存管理器
✅ 数据库连接池
✅ 日志系统
```

#### 2.2.2 待实现功能
```
❌ 完整的 JWT Token 生成和验证
❌ Token 自动刷新机制
❌ 用户登录接口
❌ 用户注册接口
❌ 密码加密和验证
❌ Session 管理
❌ 用户组权限查询
❌ OAuth 认证流程
❌ 验证码机制
❌ Cookie 管理
```

---

## 三、迁移方案设计

### 3.1 整体架构设计

#### 3.1.1 目录结构
```
src/app/
├── controllers/
│   └── uctoo/
│       └── auth/
│           ├── LoginController.cj          # 本地账号登录
│           ├── SigninController.cj         # 带验证码登录
│           ├── SignupController.cj         # 用户注册
│           ├── LogoutController.cj         # 登出
│           ├── MeController.cj             # 获取当前用户信息
│           ├── ResetPasswordController.cj  # 重置密码
│           ├── CheckTokenController.cj     # Token 检查
│           └── oauth/
│               ├── GitHubOAuthController.cj
│               ├── GoogleOAuthController.cj
│               └── WechatOAuthController.cj
├── routes/
│   └── uctoo/
│       └── auth/
│           ├── index.cj                    # 认证路由汇总
│           └── oauth/
│               ├── github.cj
│               ├── google.cj
│               └── wechatopen.cj
├── services/
│   └── uctoo/
│       ├── uctoo_user.cj                   # 用户服务
│       ├── session.cj                      # 会话服务
│       ├── user_has_group.cj               # 用户组关联服务
│       ├── user_has_account.cj             # 用户账号关联服务
│       └── permission.cj                   # 权限服务
├── middlewares/
│   └── auth/
│       ├── deserializeUser.cj              # Token 反序列化中间件
│       ├── requireUser.cj                  # 用户认证中间件
│       └── rowLevelPermission.cj           # 行级权限中间件
├── models/
│   └── uctoo/
│       ├── UserPO.cj                       # 用户模型
│       ├── SessionPO.cj                    # 会话模型
│       ├── UserGroupPO.cj                  # 用户组模型
│       ├── UserHasGroupPO.cj               # 用户组关联模型
│       ├── GroupHasPermissionPO.cj         # 组权限模型
│       └── UserHasAccountPO.cj             # 用户账号关联模型
└── utils/
    ├── jwt/
    │   └── JWTUtil.cj                      # JWT 工具类
    ├── bcrypt/
    │   └── BcryptUtil.cj                   # 密码加密工具
    ├── cookie/
    │   └── CookieUtil.cj                   # Cookie 工具
    └── authorize/
        └── AuthorizeUtil.cj                # 授权工具
```

### 3.2 核心组件迁移设计

#### 3.2.1 JWT 工具类 (JWTUtil.cj)

**依赖**: jwt4cj 第三方库

```cj
package magic.app.utils.jwt

import jwt4cj.*
import std.datetime.DateTime

public class JWTUtil {
    private let secretKey: String
    private let accessTokenValidity: Int64  // 秒
    private let refreshTokenValidity: Int64  // 秒
    
    public init(secretKey: String, accessTokenValidity: Int64 = 1728000, refreshTokenValidity: Int64 = 6048000) {
        this.secretKey = secretKey
        this.accessTokenValidity = accessTokenValidity
        this.refreshTokenValidity = refreshTokenValidity
    }
    
    // 生成 access_token
    public func generateAccessToken(userId: String, sessionId: String): String {
        let payload = JWTPayload()
        payload.userId = userId
        payload.sessionId = sessionId
        payload.exp = DateTime.now().plusSeconds(accessTokenValidity).toUnixTimestamp()
        
        return JWT.encode(payload, secretKey, Algorithm.HS256)
    }
    
    // 生成 refresh_token
    public func generateRefreshToken(userId: String, sessionId: String): String {
        let payload = JWTPayload()
        payload.userId = userId
        payload.sessionId = sessionId
        payload.exp = DateTime.now().plusSeconds(refreshTokenValidity).toUnixTimestamp()
        
        return JWT.encode(payload, secretKey, Algorithm.HS256)
    }
    
    // 验证 Token
    public func verifyToken(token: String): ?JWTPayload {
        try {
            let payload = JWT.decode(token, secretKey)
            if (payload.exp > DateTime.now().toUnixTimestamp()) {
                return Some(payload)
            }
            return None<JWTPayload>
        } catch {
            return None<JWTPayload>
        }
    }
}

public class JWTPayload {
    public var userId: String = ""
    public var sessionId: String = ""
    public var exp: Int64 = 0
    
    public init() {}
}
```

#### 3.2.2 密码加密工具 (BcryptUtil.cj)

**依赖**: pbkdf2 或 hicrypto 第三方库

```cj
package magic.app.utils.bcrypt

import pbkdf2.*
import std.random.Random

public class BcryptUtil {
    private let saltRounds: Int32 = 10
    
    public init(saltRounds: Int32 = 10) {
        this.saltRounds = saltRounds
    }
    
    // 生成密码哈希
    public func hashPassword(password: String): String {
        let salt = generateSalt()
        return PBKDF2.hash(password, salt, saltRounds, Algorithm.SHA256)
    }
    
    // 验证密码
    public func comparePassword(password: String, hash: String): Bool {
        return PBKDF2.verify(password, hash)
    }
    
    private func generateSalt(): String {
        return Random.bytes(16).toHexString()
    }
}
```

#### 3.2.3 Cookie 工具 (CookieUtil.cj)

```cj
package magic.app.utils.cookie

import magic.app.core.http.HttpResponse

public class CookieUtil {
    private let isProduction: Bool
    
    public init(isProduction: Bool) {
        this.isProduction = isProduction
    }
    
    // 设置 access_token Cookie
    public func setAccessTokenCookie(res: HttpResponse, token: String): Unit {
        let options = CookieOptions(
            maxAge: 365 * 24 * 60 * 60,
            httpOnly: true,
            secure: isProduction,
            sameSite: "lax",
            path: "/"
        )
        res.cookie("access_token", token, options)
    }
    
    // 设置 refresh_token Cookie
    public func setRefreshTokenCookie(res: HttpResponse, token: String): Unit {
        let options = CookieOptions(
            maxAge: 365 * 24 * 60 * 60,
            httpOnly: true,
            secure: isProduction,
            sameSite: "lax",
            path: "/"
        )
        res.cookie("refresh_token", token, options)
    }
    
    // 清除认证 Cookie
    public func clearAuthCookies(res: HttpResponse): Unit {
        res.clearCookie("access_token")
        res.clearCookie("refresh_token")
    }
}
```

#### 3.2.4 Session 服务 (session.cj)

```cj
package magic.app.services.uctoo

import magic.app.models.uctoo.SessionPO
import magic.app.core.cache.CacheManager
import f_orm.*
import std.datetime.DateTime

public class SessionService {
    private let db: Database
    private let cacheManager: CacheManager
    
    public init(db: Database, cacheManager: CacheManager) {
        this.db = db
        this.cacheManager = cacheManager
    }
    
    // 创建会话
    public func createSession(userId: String, userAgent: String, ip: String, authProvider: Int32): SessionPO {
        let session = SessionPO()
        session.userId = userId
        session.userAgent = userAgent
        session.ip = ip
        session.authProvider = authProvider
        session.valid = true
        session.createdAt = DateTime.now()
        
        let savedSession = db.insert(session)
        
        // 缓存到 Redis
        cacheManager.setEx(session.id, 9000, savedSession.toJson())
        
        return savedSession
    }
    
    // 查找会话
    public func findSession(sessionId: String): ?SessionPO {
        // 先从缓存查找
        let cachedSession = cacheManager.get(sessionId)
        if (let Some(json) <- cachedSession) {
            return SessionPO.fromJson(json)
        }
        
        // 从数据库查找
        let session = db.findById<SessionPO>(sessionId)
        if (let Some(s) <- session) {
            cacheManager.setEx(sessionId, 9000, s.toJson())
            return s
        }
        
        return None<SessionPO>
    }
    
    // 更新会话
    public func updateSession(sessionId: String, data: Map<String, Any>): Bool {
        try {
            db.update<SessionPO>(sessionId, data)
            cacheManager.delete(sessionId)
            return true
        } catch {
            return false
        }
    }
    
    // 删除会话
    public func removeSession(sessionId: String): Bool {
        try {
            cacheManager.delete(sessionId)
            db.delete<SessionPO>(sessionId)
            return true
        } catch {
            return false
        }
    }
    
    // Token 刷新
    public func tokenRefresh(refreshToken: String, jwtUtil: JWTUtil): ?String {
        let payload = jwtUtil.verifyToken(refreshToken)
        if (let Some(p) <- payload) {
            let session = findSession(p.sessionId)
            if (let Some(s) <- session) {
                if (!s.valid) {
                    return None<String>
                }
                
                // 生成新的 access_token (15分钟有效期)
                let newAccessToken = jwtUtil.generateAccessToken(p.userId, p.sessionId)
                return Some(newAccessToken)
            }
        }
        return None<String>
    }
}
```

#### 3.2.5 用户服务 (uctoo_user.cj)

```cj
package magic.app.services.uctoo

import magic.app.models.uctoo.UserPO
import magic.app.utils.bcrypt.BcryptUtil
import f_orm.*

public class UserService {
    private let db: Database
    private let bcryptUtil: BcryptUtil
    
    public init(db: Database, bcryptUtil: BcryptUtil) {
        this.db = db
        this.bcryptUtil = bcryptUtil
    }
    
    // 通过用户名查找用户
    public func getUserByUsername(username: String): ?UserPO {
        return db.findOne<UserPO>(where: { "username": username })
    }
    
    // 通过邮箱查找用户
    public func getUserByEmail(email: String): ?UserPO {
        return db.findOne<UserPO>(where: { "email": email })
    }
    
    // 通过 ID 查找用户
    public func getUserById(userId: String): ?UserPO {
        return db.findById<UserPO>(userId)
    }
    
    // 创建用户
    public func createUser(userData: UserCreateData): ?UserPO {
        // 检查用户名是否已存在
        if (getUserByUsername(userData.username).isSome()) {
            return None<UserPO>
        }
        
        // 检查邮箱是否已存在
        if (getUserByEmail(userData.email).isSome()) {
            return None<UserPO>
        }
        
        let user = UserPO()
        user.name = userData.name
        user.username = userData.username
        user.email = userData.email
        user.password = bcryptUtil.hashPassword(userData.password)
        user.authProvider = userData.authProvider
        user.status = 1
        user.createdAt = DateTime.now()
        
        return db.insert(user)
    }
    
    // 验证用户密码
    public func validateUser(username: String, password: String): ?UserPO {
        let user = getUserByUsername(username)
        if (let Some(u) <- user) {
            if (bcryptUtil.comparePassword(password, u.password)) {
                return u
            }
        }
        return None<UserPO>
    }
    
    // 更新用户 access_token
    public func updateAccessToken(userId: String, accessToken: String): Bool {
        try {
            db.update<UserPO>(userId, {
                "access_token": accessToken,
                "last_login_time": DateTime.now()
            })
            return true
        } catch {
            return false
        }
    }
}
```

#### 3.2.6 权限服务 (permission.cj)

```cj
package magic.app.services.uctoo

import magic.app.models.uctoo.*
import f_orm.*

public class PermissionService {
    private let db: Database
    
    public init(db: Database) {
        this.db = db
    }
    
    // 检查用户权限
    public func checkUserPermission(userId: String, permissionName: String): Bool {
        // 1. 查询用户所属组
        let userGroups = db.findMany<UserHasGroupPO>(where: { "groupable_id": userId })
        let groupIds = userGroups.map { ug => ug.groupId }
        
        if (groupIds.isEmpty()) {
            return false
        }
        
        // 2. 检查组是否有全部权限 (/*)
        let allPermissions = db.findMany<GroupHasPermissionPO>(where: {
            "group_id": { "in": groupIds },
            "permission_name": "/*"
        })
        
        if (!allPermissions.isEmpty()) {
            return true
        }
        
        // 3. 检查组是否有特定权限
        let specificPermissions = db.findMany<GroupHasPermissionPO>(where: {
            "group_id": { "in": groupIds },
            "permission_name": permissionName
        })
        
        return !specificPermissions.isEmpty()
    }
    
    // 检查用户权限(带HTTP方法)
    public func checkUserPermissionWithMethod(userId: String, permissionName: String, httpMethod: String): Bool {
        // 1. 查询用户所属组
        let userGroups = db.findMany<UserHasGroupPO>(where: { "groupable_id": userId })
        let groupIds = userGroups.map { ug => ug.groupId }
        
        if (groupIds.isEmpty()) {
            return false
        }
        
        // 2. 检查组是否有全部权限 (/*)
        let allPermissions = db.findMany<GroupHasPermissionPO>(where: {
            "group_id": { "in": groupIds },
            "permission_name": "/*"
        })
        
        if (!allPermissions.isEmpty()) {
            return true
        }
        
        // 3. 查询权限节点详情
        let permission = db.findOne<PermissionPO>(where: { "permission_name": permissionName })
        if (let Some(p) <- permission) {
            // 4. 检查HTTP方法是否匹配
            if (!p.matchMethod(httpMethod)) {
                return false
            }
            
            // 5. 检查用户组是否有此权限
            let groupPermissions = db.findMany<GroupHasPermissionPO>(where: {
                "group_id": { "in": groupIds },
                "permission_name": permissionName
            })
            
            return !groupPermissions.isEmpty()
        }
        
        return false
    }
    
    // 获取用户所有权限节点
    public func getUserPermissions(userId: String): ArrayList<PermissionPO> {
        let permissions = ArrayList<PermissionPO>()
        
        // 1. 查询用户所属组
        let userGroups = db.findMany<UserHasGroupPO>(where: { "groupable_id": userId })
        let groupIds = userGroups.map { ug => ug.groupId }
        
        if (groupIds.isEmpty()) {
            return permissions
        }
        
        // 2. 查询用户组关联的权限名称
        let groupPermissions = db.findMany<GroupHasPermissionPO>(where: {
            "group_id": { "in": groupIds }
        })
        
        let permissionNames = groupPermissions.map { gp => gp.permissionName }
        
        // 3. 查询权限节点详情
        for (name in permissionNames) {
            let permission = db.findOne<PermissionPO>(where: { "permission_name": name })
            if (let Some(p) <- permission) {
                permissions.append(p)
            }
        }
        
        return permissions
    }
    
    // 获取用户菜单权限(前端路由)
    public func getUserMenuPermissions(userId: String): ArrayList<PermissionPO> {
        let allPermissions = getUserPermissions(userId)
        let menuPermissions = ArrayList<PermissionPO>()
        
        for (p in allPermissions) {
            if (p.isMenu()) {
                menuPermissions.append(p)
            }
        }
        
        return menuPermissions
    }
    
    // 检查行级权限
    public func checkRowLevelPermission(userId: String, tableName: String, recordId: String, level: PermissionLevel): Bool {
        // 1. 检查是否为数据创建者
        let record = db.findById(tableName, recordId)
        if (let Some(r) <- record) {
            if (r.creator == userId) {
                return true
            }
        }
        
        // 2. 检查是否有数据授权 (TODO: 实现数据授权表)
        return false
    }
}
```

### 3.3 中间件迁移设计

#### 3.3.1 deserializeUser 中间件

```cj
package magic.app.middlewares.auth

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.middleware.Middleware
import magic.app.utils.jwt.JWTUtil
import magic.app.services.uctoo.SessionService
import magic.app.utils.cookie.CookieUtil

public class DeserializeUserMiddleware <: Middleware {
    private let jwtUtil: JWTUtil
    private let sessionService: SessionService
    private let cookieUtil: CookieUtil
    
    public init(jwtUtil: JWTUtil, sessionService: SessionService, cookieUtil: CookieUtil) {
        this.jwtUtil = jwtUtil
        this.sessionService = sessionService
        this.cookieUtil = cookieUtil
    }
    
    public func handle(req: HttpRequest, res: HttpResponse, next: () -> Unit): Unit {
        // 1. 获取 access_token
        let accessToken = req.header("Authorization")?.split(" ")[1] ?? req.cookie("access_token")
        let refreshToken = req.header("x-refresh") ?? req.cookie("refresh_token")
        
        if (accessToken.isEmpty()) {
            next()
            return
        }
        
        // 2. 验证 access_token
        let payload = jwtUtil.verifyToken(accessToken)
        if (let Some(p) <- payload) {
            req.setLocals("user", p)
            next()
            return
        }
        
        // 3. access_token 过期,尝试用 refresh_token 刷新
        if (let Some(refresh) <- refreshToken) {
            let newAccessToken = sessionService.tokenRefresh(refresh, jwtUtil)
            if (let Some(newToken) <- newAccessToken) {
                // 设置新的 access_token
                res.header("x-access-token", newToken)
                res.header("Authorization", "Bearer ${newToken}")
                cookieUtil.setAccessTokenCookie(res, newToken)
                
                // 解析新 token 并设置用户信息
                let newPayload = jwtUtil.verifyToken(newToken)
                if (let Some(np) <- newPayload) {
                    req.setLocals("user", np)
                }
            }
        }
        
        next()
    }
}
```

#### 3.3.2 requireUser 中间件

```cj
package magic.app.middlewares.auth

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.middleware.Middleware
import magic.app.core.response.APIError
import magic.app.services.uctoo.PermissionService
import magic.app.utils.jwt.JWTPayload

public class RequireUserMiddleware <: Middleware {
    private let permissionService: PermissionService
    
    public init(permissionService: PermissionService) {
        this.permissionService = permissionService
    }
    
    public func handle(req: HttpRequest, res: HttpResponse, next: () -> Unit): Unit {
        let user = req.getLocals("user")
        
        // 1. 检查是否登录
        if (user is Option<Any>) {
            match (user) {
                case None => {
                    res.status(403).json(APIError("40300", "not login").toJson())
                    return
                }
                case Some(u) => {
                    match (u) {
                        case p: JWTPayload => {
                            // 2. 检查路由权限
                            let routePattern = req.routePattern()
                            if (!permissionService.checkUserPermission(p.userId, routePattern)) {
                                res.status(403).json(APIError("40301", "no permission").toJson())
                                return
                            }
                            
                            next()
                        }
                        case _ => {
                            res.status(403).json(APIError("40302", "invalid user info").toJson())
                        }
                    }
                }
            }
        }
    }
}
```

### 3.4 控制器迁移设计

#### 3.4.1 登录控制器 (LoginController.cj)

```cj
package magic.app.controllers.uctoo.auth

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.services.uctoo.{UserService, SessionService}
import magic.app.utils.jwt.JWTUtil
import magic.app.utils.cookie.CookieUtil
import magic.app.utils.authorize.AuthorizeUtil
import magic.app.core.response.APIError

public class LoginController {
    private let userService: UserService
    private let sessionService: SessionService
    private let jwtUtil: JWTUtil
    private let cookieUtil: CookieUtil
    private let authorizeUtil: AuthorizeUtil
    
    public init(userService: UserService, sessionService: SessionService, jwtUtil: JWTUtil, cookieUtil: CookieUtil) {
        this.userService = userService
        this.sessionService = sessionService
        this.jwtUtil = jwtUtil
        this.cookieUtil = cookieUtil
        this.authorizeUtil = AuthorizeUtil(userService, sessionService, jwtUtil, cookieUtil)
    }
    
    public func handleLogin(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = req.json()
            let username = body["username"] as String
            let password = body["password"] as String
            
            // 1. 验证用户
            let user = userService.validateUser(username, password)
            if (user.isNone()) {
                res.status(400).json(APIError("42007", "login failed, username/password not match").toJson())
                return
            }
            
            let u = user.getOrThrow()
            
            // 2. 完成授权流程
            authorizeUtil.authorizeAndEnd(u, req, res, AuthProvider.LOCAL, true)
            
        } catch (ex: Exception) {
            res.status(500).json(APIError("50000", ex.message).toJson())
        }
    }
}
```

#### 3.4.2 授权工具 (AuthorizeUtil.cj)

```cj
package magic.app.utils.authorize

import magic.app.models.uctoo.UserPO
import magic.app.services.uctoo.{UserService, SessionService}
import magic.app.utils.jwt.JWTUtil
import magic.app.utils.cookie.CookieUtil
import magic.app.core.http.{HttpRequest, HttpResponse}

public class AuthorizeUtil {
    private let userService: UserService
    private let sessionService: SessionService
    private let jwtUtil: JWTUtil
    private let cookieUtil: CookieUtil
    
    public init(userService: UserService, sessionService: SessionService, jwtUtil: JWTUtil, cookieUtil: CookieUtil) {
        this.userService = userService
        this.sessionService = sessionService
        this.jwtUtil = jwtUtil
        this.cookieUtil = cookieUtil
    }
    
    // 授权并结束请求
    public func authorizeAndEnd(user: UserPO, req: HttpRequest, res: HttpResponse, authProvider: Int32, isLocal: Bool): Unit {
        // 1. 创建会话
        let session = sessionService.createSession(
            user.id,
            req.header("user-agent") ?? "No agent detected",
            req.ip(),
            authProvider
        )
        
        // 2. 生成 Token
        let accessToken = jwtUtil.generateAccessToken(user.id, session.id)
        let refreshToken = jwtUtil.generateRefreshToken(user.id, session.id)
        
        // 3. 更新用户 access_token
        userService.updateAccessToken(user.id, accessToken)
        
        // 4. 设置 Cookie
        cookieUtil.setAccessTokenCookie(res, accessToken)
        cookieUtil.setRefreshTokenCookie(res, refreshToken)
        
        // 5. 返回响应
        if (!isLocal) {
            // OAuth 登录,重定向到前端
            res.status(302).redirect(process.env["FRONTEND_URL"] ?? "http://localhost:4200/")
        } else {
            // 本地登录,返回 JSON
            let responseData = {
                "access_token": accessToken,
                "refresh_token": refreshToken,
                "user": user.toJson()
            }
            res.status(200).json(responseData)
        }
    }
}
```

### 3.5 数据库模型设计

#### 3.5.1 用户模型 (UserPO.cj)

```cj
package magic.app.models.uctoo

import f_orm.*
import f_orm.macros.*
import std.datetime.DateTime

@TableName("uctoo_user")
public class UserPO <: Entity {
    @Column(name: "id", isPrimaryKey = true, isGenerated = true)
    public var id: String = ""
    
    @Column(name: "name")
    public var name: String = ""
    
    @Column(name: "username", isUnique = true)
    public var username: String = ""
    
    @Column(name: "email", isUnique = true)
    public var email: String = ""
    
    @Column(name: "password")
    public var password: String = ""
    
    @Column(name: "avatar")
    public var avatar: ?String = None<String>
    
    @Column(name: "access_token")
    public var accessToken: ?String = None<String>
    
    @Column(name: "auth_provider")
    public var authProvider: Int32 = 0
    
    @Column(name: "last_login_time")
    public var lastLoginTime: DateTime = DateTime.now()
    
    @Column(name: "last_login_ip")
    public var lastLoginIp: ?String = None<String>
    
    @Column(name: "status")
    public var status: Int32 = 0
    
    @Column(name: "created_at")
    public var createdAt: DateTime = DateTime.now()
    
    @Column(name: "updated_at")
    public var updatedAt: ?DateTime = None<DateTime>
    
    @Column(name: "deleted_at")
    public var deletedAt: ?DateTime = None<DateTime>
    
    @Column(name: "creator")
    public var creator: ?String = None<String>
    
    public init() {}
}
```

#### 3.5.2 会话模型 (SessionPO.cj)

```cj
package magic.app.models.uctoo

import f_orm.*
import f_orm.macros.*
import std.datetime.DateTime

@TableName("uctoo_session")
public class SessionPO <: Entity {
    @Column(name: "id", isPrimaryKey = true, isGenerated = true)
    public var id: String = ""
    
    @Column(name: "user_id")
    public var userId: String = ""
    
    @Column(name: "valid")
    public var valid: Bool = true
    
    @Column(name: "user_agent")
    public var userAgent: ?String = None<String>
    
    @Column(name: "ip")
    public var ip: String = ""
    
    @Column(name: "auth_provider")
    public var authProvider: Int32 = 0
    
    @Column(name: "created_at")
    public var createdAt: DateTime = DateTime.now()
    
    @Column(name: "updated_at")
    public var updatedAt: ?DateTime = None<DateTime>
    
    @Column(name: "deleted_at")
    public var deletedAt: ?DateTime = None<DateTime>
    
    @Column(name: "creator")
    public var creator: ?String = None<String>
    
    public init() {}
}
```

#### 3.5.3 权限节点模型 (PermissionPO.cj)

```cj
package magic.app.models.uctoo

import f_orm.*
import f_orm.macros.*
import std.datetime.DateTime
import std.collection.ArrayList

@TableName("permissions")
public class PermissionPO <: Entity {
    @Column(name: "id", isPrimaryKey = true, isGenerated = true)
    public var id: String = ""
    
    @Column(name: "permission_name", isUnique = true)
    public var name: String = ""  // 权限名称(路由路径)
    
    @Column(name: "level")
    public var level: ?String = None<String>  // 权限级别
    
    @Column(name: "icon")
    public var icon: ?String = None<String>  // 图标
    
    @Column(name: "module")
    public var module: ?String = None<String>  // 所属模块
    
    @Column(name: "component")
    public var component: ?String = None<String>  // 前端组件路径
    
    @Column(name: "redirect")
    public var redirect: ?String = None<String>  // 重定向路径
    
    @Column(name: "type")
    public var type: Int32 = 1  // 类型(1:菜单,2:按钮,3:接口)
    
    @Column(name: "hidden")
    public var hidden: Int32 = 1  // 是否隐藏
    
    @Column(name: "weight")
    public var weight: Int32 = 0  // 权重(排序)
    
    @Column(name: "creator")
    public var creator: ?String = None<String>
    
    @Column(name: "created_at")
    public var createdAt: DateTime = DateTime.now()
    
    @Column(name: "updated_at")
    public var updatedAt: DateTime = DateTime.now()
    
    @Column(name: "deleted_at")
    public var deletedAt: ?DateTime = None<DateTime>
    
    @Column(name: "keepalive")
    public var keepalive: Int32 = 1  // 是否缓存
    
    @Column(name: "path")
    public var path: String = ""  // 前端路由路径
    
    @Column(name: "title")
    public var title: ?String = None<String>  // 权限标题
    
    @Column(name: "parent_id")
    public var parentId: ?String = None<String>  // 父权限ID
    
    @Column(name: "meta", type = "json")
    public var meta: ?String = None<String>  // 元数据(JSON格式)
    
    @Column(name: "method")
    public var method: ?String = None<String>  // HTTP方法(GET/POST/PUT/DELETE)
    
    // 关联关系(需要在服务层实现)
    public var groups: ArrayList<GroupHasPermissionPO> = ArrayList<GroupHasPermissionPO>()
    public var parent: ?PermissionPO = None<PermissionPO>
    public var children: ArrayList<PermissionPO> = ArrayList<PermissionPO>()
    
    public init() {}
    
    // 辅助方法:判断是否为菜单权限
    public func isMenu(): Bool {
        return type == 1
    }
    
    // 辅助方法:判断是否为按钮权限
    public func isButton(): Bool {
        return type == 2
    }
    
    // 辅助方法:判断是否为接口权限
    public func isAPI(): Bool {
        return type == 3
    }
    
    // 辅助方法:检查HTTP方法是否匹配
    public func matchMethod(httpMethod: String): Bool {
        if (method.isNone()) {
            return true  // 未指定方法,默认匹配所有
        }
        return method.getOrThrow().toUpperCase() == httpMethod.toUpperCase()
    }
}
```

**权限节点模型说明**:
- **name**: 权限名称,对应路由路径(如 `/api/uctoo/entity` 或 `/*` 表示全部权限)
- **type**: 权限类型
  - 1: 菜单权限(前端菜单项)
  - 2: 按钮权限(页面按钮级控制)
  - 3: 接口权限(后端API路由)
- **path**: 前端路由路径
- **component**: 前端组件路径
- **method**: HTTP方法,用于接口权限控制
- **parentId**: 父权限ID,支持树形权限结构
- **meta**: JSON格式的元数据,存储额外配置
- **weight**: 权重,用于排序显示

#### 3.5.4 用户组模型 (UserGroupPO.cj)

```cj
package magic.app.models.uctoo

import f_orm.*
import f_orm.macros.*
import std.datetime.DateTime
import std.collection.ArrayList

@TableName("user_group")
public class UserGroupPO <: Entity {
    @Column(name: "id", isPrimaryKey = true, isGenerated = true)
    public var id: String = ""
    
    @Column(name: "group_name")
    public var groupName: String = ""
    
    @Column(name: "parent_id")
    public var parentId: ?String = None<String>
    
    @Column(name: "code")
    public var code: String = ""  // 用户组代码
    
    @Column(name: "intro")
    public var intro: ?String = None<String>  // 用户组介绍
    
    @Column(name: "creator")
    public var creator: ?String = None<String>
    
    @Column(name: "created_at")
    public var createdAt: DateTime = DateTime.now()
    
    @Column(name: "updated_at")
    public var updatedAt: DateTime = DateTime.now()
    
    @Column(name: "deleted_at")
    public var deletedAt: ?DateTime = None<DateTime>
    
    // 关联关系
    public var permissions: ArrayList<GroupHasPermissionPO> = ArrayList<GroupHasPermissionPO>()
    public var users: ArrayList<UserHasGroupPO> = ArrayList<UserHasGroupPO>()
    
    public init() {}
}
```

#### 3.5.5 用户组权限关联模型 (GroupHasPermissionPO.cj)

```cj
package magic.app.models.uctoo

import f_orm.*
import f_orm.macros.*
import std.datetime.DateTime

@TableName("group_has_permission")
public class GroupHasPermissionPO <: Entity {
    @Column(name: "group_id")
    public var groupId: String = ""
    
    @Column(name: "permission_name")
    public var permissionName: String = ""  // 关联 permissions.name
    
    @Column(name: "status")
    public var status: Int32 = 0
    
    @Column(name: "creator")
    public var creator: ?String = None<String>
    
    @Column(name: "created_at")
    public var createdAt: DateTime = DateTime.now()
    
    @Column(name: "updated_at")
    public var updatedAt: DateTime = DateTime.now()
    
    @Column(name: "deleted_at")
    public var deletedAt: ?DateTime = None<DateTime>
    
    // 关联关系(需要在服务层实现)
    public var group: ?UserGroupPO = None<UserGroupPO>
    public var permission: ?PermissionPO = None<PermissionPO>
    
    public init() {}
}
```

**关联关系说明**:
- `group_has_permission` 表通过 `permission_name` 字段关联 `permissions` 表的 `name` 字段
- 一个用户组可以拥有多个权限节点
- 一个权限节点可以被多个用户组使用
- 支持树形权限结构,通过 `parent_id` 和 `children` 实现父子关系
    
    @Column(name: "creator")
    public var creator: ?String = None<String>
    
    public init() {}
}
```

---

## 四、迁移实施计划

### 4.1 阶段划分

#### 阶段一: 基础设施搭建 (1-2周)
**目标**: 完成基础工具类和数据库模型

**任务清单**:
- [ ] 集成 jwt4cj 第三方库
- [ ] 集成 pbkdf2 或 hicrypto 第三方库
- [ ] 集成 redis-sdk 第三方库
- [ ] 实现 JWTUtil 工具类
- [ ] 实现 BcryptUtil 工具类
- [ ] 实现 CookieUtil 工具类
- [ ] 创建数据库模型 (UserPO, SessionPO, UserGroupPO 等)
- [ ] 数据库迁移脚本

**交付物**:
- 完整的工具类库
- 数据库模型定义
- 数据库迁移脚本

#### 阶段二: 核心服务实现 (2-3周)
**目标**: 实现核心业务服务

**任务清单**:
- [ ] 实现 UserService
- [ ] 实现 SessionService
- [ ] 实现 PermissionService
- [ ] 实现 UserHasGroupService
- [ ] 实现 UserHasAccountService
- [ ] 实现 AuthorizeUtil
- [ ] 单元测试

**交付物**:
- 完整的服务层实现
- 单元测试用例

#### 阶段三: 中间件完善 (1-2周)
**目标**: 完善认证和权限中间件

**任务清单**:
- [ ] 实现 DeserializeUserMiddleware
- [ ] 完善 RequireUserMiddleware
- [ ] 完善 RowLevelPermissionMiddleware
- [ ] 中间件集成测试

**交付物**:
- 完整的中间件实现
- 中间件测试用例

#### 阶段四: 控制器和路由实现 (2-3周)
**目标**: 实现完整的认证接口

**任务清单**:
- [ ] 实现 LoginController
- [ ] 实现 SigninController (带验证码)
- [ ] 实现 SignupController
- [ ] 实现 LogoutController
- [ ] 实现 MeController
- [ ] 实现 ResetPasswordController
- [ ] 实现 CheckTokenController
- [ ] 路由配置
- [ ] 接口测试

**交付物**:
- 完整的认证接口
- 接口测试用例

#### 阶段五: OAuth 认证实现 (2-3周)
**目标**: 实现第三方登录

**任务清单**:
- [ ] 集成 oauth4cj 第三方库
- [ ] 实现 GitHub OAuth
- [ ] 实现 Google OAuth
- [ ] 实现微信公众号 OAuth
- [ ] 实现微信小程序登录
- [ ] OAuth 测试

**交付物**:
- 完整的 OAuth 认证实现
- OAuth 测试用例

#### 阶段六: 集成测试与优化 (1-2周)
**目标**: 完整测试和性能优化

**任务清单**:
- [ ] 端到端测试
- [ ] 性能测试
- [ ] 安全测试
- [ ] 性能优化
- [ ] 文档完善

**交付物**:
- 测试报告
- 性能报告
- 完整文档

### 4.2 里程碑

| 里程碑 | 时间节点 | 交付物 | 验收标准 |
|--------|---------|--------|---------|
| M1: 基础设施完成 | 第2周 | 工具类、数据库模型 | 单元测试通过 |
| M2: 核心服务完成 | 第5周 | 服务层实现 | 服务测试通过 |
| M3: 中间件完成 | 第7周 | 中间件实现 | 中间件测试通过 |
| M4: 认证接口完成 | 第10周 | 认证接口 | 接口测试通过 |
| M5: OAuth 完成 | 第13周 | OAuth 实现 | OAuth 测试通过 |
| M6: 系统完成 | 第15周 | 完整系统 | 集成测试通过 |

---

## 五、第三方库集成方案

### 5.1 必需第三方库

#### 5.1.1 jwt4cj - JWT 认证库
**版本**: v1.0.1  
**用途**: JWT Token 生成和验证  
**集成方式**:
```toml
[dependencies]
  jwt4cj = { git = "https://gitcode.com/Cangjie-TPC/jwt4cj.git", branch = "master" }
```

#### 5.1.2 pbkdf2 - 密码加密库
**版本**: v0.0.1  
**用途**: 用户密码加密  
**集成方式**:
```toml
[dependencies]
  pbkdf2 = { path = "../CangjieMagic/resource/TPC/pbkdf2" }
```

#### 5.1.3 redis-sdk - Redis 客户端
**版本**: v3.0.0  
**用途**: Session 缓存  
**集成方式**:
```toml
[dependencies]
  redis_sdk = { git = "https://gitcode.com/Cangjie-TPC/redis-sdk.git", branch = "master", version = "3.0.0" }
```

#### 5.1.4 oauth4cj - OAuth 认证库
**版本**: v0.0.1  
**用途**: 第三方 OAuth 登录  
**集成方式**:
```toml
[dependencies]
  oauth4cj = { git = "https://gitcode.com/Cangjie-TPC/oauth4cj.git", branch = "master" }
```

### 5.2 可选第三方库

#### 5.2.1 hicrypto - 密码学库
**用途**: 替代 pbkdf2,提供更多加密算法

#### 5.2.2 log-cj - 日志库
**用途**: 增强日志功能

---

## 六、配置管理方案

### 6.1 环境变量配置

```env
# JWT 配置
JWT_SECRET=uctoo-v4-secret-key
ACCESS_TOKEN_VALIDITY_SEC=1728000
REFRESH_TOKEN_VALIDITY_SEC=6048000

# 密码加密配置
BCRYPT_SALT_ROUNDS=10

# Redis 配置
REDIS_URL=redis://127.0.0.1:6379
REDIS_PASSWORD=

# 行级权限开关
ROW_LEVEL_PERMISSION_ENABLED=true

# OAuth 配置
GITHUB_CLIENT_ID=
GITHUB_CLIENT_SECRET=
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
WECHAT_APPID=
WECHAT_SECRET=

# 前端 URL
FRONTEND_URL=http://localhost:4200
```

### 6.2 配置加载

```cj
package magic.app.config

import std.env.getVariable

public class AuthConfig {
    public let jwtSecret: String
    public let accessTokenValidity: Int64
    public let refreshTokenValidity: Int64
    public let bcryptSaltRounds: Int32
    public let rowLevelPermissionEnabled: Bool
    
    public init() {
        jwtSecret = getVariable("JWT_SECRET") ?? "uctoo-v4-secret-key"
        accessTokenValidity = Int64.parse(getVariable("ACCESS_TOKEN_VALIDITY_SEC") ?? "1728000")
        refreshTokenValidity = Int64.parse(getVariable("REFRESH_TOKEN_VALIDITY_SEC") ?? "6048000")
        bcryptSaltRounds = Int32.parse(getVariable("BCRYPT_SALT_ROUNDS") ?? "10")
        rowLevelPermissionEnabled = (getVariable("ROW_LEVEL_PERMISSION_ENABLED") ?? "true") == "true"
    }
}
```

---

## 七、测试方案

### 7.1 单元测试

#### 7.1.1 JWT 工具测试
```cj
// 测试 Token 生成和验证
func testJWTUtil(): Unit {
    let jwtUtil = JWTUtil("test-secret")
    let token = jwtUtil.generateAccessToken("user1", "session1")
    let payload = jwtUtil.verifyToken(token)
    assert(payload.isSome())
}
```

#### 7.1.2 密码加密测试
```cj
// 测试密码加密和验证
func testBcryptUtil(): Unit {
    let bcryptUtil = BcryptUtil()
    let hash = bcryptUtil.hashPassword("password123")
    assert(bcryptUtil.comparePassword("password123", hash))
    assert(!bcryptUtil.comparePassword("wrongpassword", hash))
}
```

### 7.2 集成测试

#### 7.2.1 登录流程测试
```cj
// 测试完整登录流程
func testLoginFlow(): Unit {
    // 1. 注册用户
    // 2. 登录
    // 3. 验证 Token
    // 4. 访问受保护资源
}
```

#### 7.2.2 权限检查测试
```cj
// 测试权限检查
func testPermissionCheck(): Unit {
    // 1. 创建用户组
    // 2. 分配权限
    // 3. 检查权限
}
```

---

## 八、风险评估与应对

### 8.1 技术风险

| 风险 | 影响 | 概率 | 应对措施 |
|------|------|------|---------|
| jwt4cj 功能不完善 | 高 | 中 | 提前测试,必要时扩展功能 |
| pbkdf2 兼容性问题 | 中 | 低 | 准备 hicrypto 作为备选 |
| redis-sdk 性能问题 | 中 | 低 | 进行性能测试,优化配置 |
| OAuth 实现复杂 | 高 | 中 | 分阶段实现,充分测试 |

### 8.2 业务风险

| 风险 | 影响 | 概率 | 应对措施 |
|------|------|------|---------|
| API 不兼容 | 高 | 中 | 严格遵循 V3 API 规范 |
| 数据迁移问题 | 中 | 中 | 制定详细迁移方案 |
| 性能下降 | 中 | 低 | 进行性能测试和优化 |

---

## 九、预期收益

### 9.1 功能收益
- ✅ 完整的登录鉴权体系
- ✅ 多种认证方式支持
- ✅ 完善的权限控制
- ✅ 与 V3 功能完全对等

### 9.2 性能收益
- 📈 Token 验证性能提升 30-50%
- 📈 权限检查性能提升 20-30%
- 📈 Session 管理性能提升 40-60%

### 9.3 安全收益
- 🔒 静态类型检查,减少运行时错误
- 🔒 仓颉内存安全特性
- 🔒 更强的加密算法支持

---

## 十、总结

本迁移方案详细规划了从 uctoo-backend V3 到 agentskills-runtime 的登录鉴权机制迁移,包括:

1. **完整的架构设计**: 三层架构、中间件机制、服务层设计
2. **详细的实施计划**: 6个阶段、15周时间、明确的里程碑
3. **第三方库集成方案**: jwt4cj、pbkdf2、redis-sdk、oauth4cj
4. **测试和风险应对**: 完整的测试方案和风险应对措施

通过本方案的实施,将实现与 V3 完全一致的登录鉴权功能,同时利用仓颉语言特性提升性能和安全性。

---

**文档版本**: 1.0.0  
**创建日期**: 2026-03-16  
**最后更新**: 2026-03-16  
**文档状态**: 待实施
