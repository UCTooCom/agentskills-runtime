# uctoo V4.0 中间件使用指南

## 文档信息
- **版本**: 1.0.0
- **创建日期**: 2026-03-13
- **适用范围**: uctoo V4.0 应用服务器

## 1. 概述

uctoo V4.0 中间件机制用于在请求处理前后执行通用逻辑，如认证、权限检查、日志记录等。

### 1.1 中间件接口

```cangjie
public interface Middleware {
    func handle(req: HttpRequest, res: HttpResponse, next: () -> Unit): Unit
}
```

### 1.2 中间件执行流程

```
请求 → 中间件1 → 中间件2 → ... → 路由处理器 → 响应
         ↓          ↓              ↓
       前置处理    前置处理       业务处理
         ↓          ↓              ↓
       后置处理    后置处理       响应封装
```

## 2. 已实现中间件

### 2.1 JWT认证中间件

**文件位置**: `src/app/middlewares/auth/JWTAuthMiddleware.cj`

**功能**:
- 验证 JWT token 有效性
- 解析用户信息并注入请求对象
- 处理 token 过期

**使用方式**:
```cangjie
import magic.app.middlewares.auth.JWTAuthMiddleware

// 在路由中使用
router.group("/api/v1/protected") { group =>
    group.use(JWTAuthMiddleware())
    group.get("/profile", controller.profile)
}
```

**配置项**:
```env
JWT_SECRET=your-secret-key
JWT_EXPIRES_IN=172800
```

**错误响应**:
```json
{
    "errno": "40101",
    "errmsg": "未授权访问"
}
```

### 2.2 权限中间件

**文件位置**: `src/app/middlewares/permission/PermissionMiddleware.cj`

**功能**:
- 检查用户是否有特定权限
- 支持行级权限检查
- 支持 RBAC3 权限模型

**使用方式**:
```cangjie
import magic.app.middlewares.permission.PermissionMiddleware

// 检查特定权限
router.group("/api/v1/admin") { group =>
    group.use(JWTAuthMiddleware())
    group.use(PermissionMiddleware("admin:access"))
    group.get("/users", controller.listUsers)
}

// 检查资源权限
router.use(PermissionMiddleware("entity:write"))
```

**权限级别**:
```cangjie
public enum PermissionLevel {
    READ = 1      // 可读
    WRITE = 2     // 可写
    AUTHORIZE = 3 // 可授权
}
```

**错误响应**:
```json
{
    "errno": "40301",
    "errmsg": "权限不足"
}
```

## 3. 自定义中间件

### 3.1 创建中间件

创建 `src/app/middlewares/custom/CustomMiddleware.cj`:

```cangjie
package magic.app.middlewares.custom

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.middleware.Middleware

public class CustomMiddleware <: Middleware {
    public func handle(req: HttpRequest, res: HttpResponse, next: () -> Unit): Unit {
        // 前置处理
        println("Request started: ${req.path}")
        
        // 调用下一个中间件或路由处理器
        next()
        
        // 后置处理
        println("Request completed: ${req.path}")
    }
}
```

### 3.2 注册中间件

**全局中间件**:
```cangjie
// main.cj
router.use(CustomMiddleware())
```

**路由组中间件**:
```cangjie
router.group("/api/v1") { group =>
    group.use(CustomMiddleware())
    // ...
}
```

**单路由中间件**:
```cangjie
router.get("/special", controller.special, [CustomMiddleware()])
```

## 4. 常用中间件示例

### 4.1 日志中间件

```cangjie
public class LoggingMiddleware <: Middleware {
    private let logger: Logger
    
    public init() {
        this.logger = Logger.getLogger("HTTP")
    }
    
    public func handle(req: HttpRequest, res: HttpResponse, next: () -> Unit): Unit {
        let start = DateTime.now()
        
        next()
        
        let duration = DateTime.now() - start
        logger.info("${req.method} ${req.path} ${res.statusCode} ${duration}ms")
    }
}
```

### 4.2 CORS中间件

```cangjie
public class CORSMiddleware <: Middleware {
    public func handle(req: HttpRequest, res: HttpResponse, next: () -> Unit): Unit {
        res.setHeader("Access-Control-Allow-Origin", "*")
        res.setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization")
        
        if (req.method == "OPTIONS") {
            res.status(200).send("")
            return
        }
        
        next()
    }
}
```

### 4.3 请求限流中间件

```cangjie
public class RateLimitMiddleware <: Middleware {
    private let limit: Int32
    private let window: Int64
    private var requests: HashMap<String, Array<Int64>> = HashMap<String, Array<Int64>>()
    
    public init(limit: Int32, windowSeconds: Int64) {
        this.limit = limit
        this.window = windowSeconds * 1000
    }
    
    public func handle(req: HttpRequest, res: HttpResponse, next: () -> Unit): Unit {
        let ip = req.getClientIP()
        let now = DateTime.now().toUnixTimestamp()
        
        // 清理过期请求
        cleanupExpiredRequests(ip, now)
        
        // 检查限制
        let count = requests.get(ip).map({ arr => arr.size }).getOrElse(0)
        if (count >= limit) {
            res.status(429).json(APIError("42901", "请求过于频繁"))
            return
        }
        
        // 记录请求
        recordRequest(ip, now)
        
        next()
    }
    
    private func cleanupExpiredRequests(ip: String, now: Int64): Unit {
        // ...
    }
    
    private func recordRequest(ip: String, now: Int64): Unit {
        // ...
    }
}
```

### 4.4 请求体解析中间件

```cangjie
public class BodyParserMiddleware <: Middleware {
    public func handle(req: HttpRequest, res: HttpResponse, next: () -> Unit): Unit {
        if (req.method == "POST" || req.method == "PUT") {
            let contentType = req.getHeader("Content-Type")
            if (contentType.contains("application/json")) {
                try {
                    let body = parseJson(req.body)
                    req.setParsedBody(body)
                } catch {
                    res.status(400).json(APIError("40001", "JSON解析失败"))
                    return
                }
            }
        }
        
        next()
    }
}
```

## 5. 中间件执行顺序

中间件按照注册顺序执行：

```cangjie
// 执行顺序: CORS -> Logging -> JWT -> Permission -> 路由处理器
router.use(CORSMiddleware())
router.use(LoggingMiddleware())
router.use(JWTAuthMiddleware())
router.use(PermissionMiddleware())
```

## 6. 中间件配置

### 6.1 环境变量配置

```env
# JWT配置
JWT_SECRET=your-secret-key
JWT_EXPIRES_IN=172800

# 限流配置
RATE_LIMIT=100
RATE_WINDOW=60
```

### 6.2 配置文件

```json
// config/middleware.json
{
    "jwt": {
        "secret": "${JWT_SECRET}",
        "expiresIn": 172800
    },
    "rateLimit": {
        "limit": 100,
        "window": 60
    }
}
```

## 7. 最佳实践

### 7.1 中间件职责单一

每个中间件只负责一个功能：
- ✅ JWT认证中间件只负责token验证
- ❌ JWT认证中间件同时处理权限检查

### 7.2 错误处理

中间件应该正确处理错误并返回适当的响应：
```cangjie
public func handle(req: HttpRequest, res: HttpResponse, next: () -> Unit): Unit {
    try {
        // 处理逻辑
        next()
    } catch (e: Exception) {
        res.status(500).json(APIError("50001", "服务器内部错误"))
    }
}
```

### 7.3 性能考虑

- 避免在中间件中执行耗时操作
- 使用缓存减少重复计算
- 异步处理非关键逻辑

## 8. 参考文档

- [子系统架构说明](./uctoo-v4-architecture.md)
- [用户权限体系](../../../backend/docs/user-permission-system.md)
