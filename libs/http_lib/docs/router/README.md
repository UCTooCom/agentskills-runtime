# http_lib 路由模块（router）

## 概述

`router` 模块提供基于 Radix Tree 的高性能 HTTP 路由器和中间件链。
支持路径参数提取、CORS 跨域、中间件洋葱模型、路由分组等功能。

## 主要类型

| 类型 | 说明 |
|------|------|
| `Router` | Radix Tree 路由器，支持 GET/POST/PUT/DELETE 等方法的路径注册 |
| `Handler` | 请求处理器类型（`(HttpRequest) -> HttpResponse`） |
| `MiddlewareChain` | 中间件洋葱模型链 |
| `Middleware` | 中间件类型，支持在请求处理前后添加逻辑 |

## 功能特性

| 功能 | 说明 |
|------|------|
| Radix Tree 路由 | 高性能路径匹配，支持参数化路径 |
| 路径参数 | `:param` 和 `*splat` 模式匹配 |
| CORS 中间件 | 跨域资源共享支持，可配置允许来源、方法、头部 |
| 中间件链 | 洋葱模型，请求从外向内经过中间件，响应从内向外返回 |
| 路由分组 | 按路径前缀分组管理路由 |
| StripPrefix | 路径前缀剥离中间件 |
| Handler 工具 | `handler()` 将 `Router` 转换为 `Handler` |

## 使用示例

```cangjie
// 基本路由
let router = Router()
    .get("/", indexHandler)
    .get("/api/users/:id", userHandler)
    .post("/api/users", createUserHandler)

// 路径参数提取
func userHandler(req: HttpRequest): HttpResponse {
    match (req.params.get("id")) {
        case Some(id) => HttpResponse.text(HttpStatus.OK, "User ${id}")
        case None => HttpResponse.text(HttpStatus.NOT_FOUND, "Missing id")
    }
}

// 中间件
router.use(loggingMiddleware)
router.use(authMiddleware)

// CORS
router.use(corsMiddleware(allowedOrigins: ["https://example.com"]))

// 路由分组
let api = router.group("/api/v2")
api.get("/users", listUsers)
api.post("/users", createUser)
```

## 中间件洋葱模型

请求从外向内依次经过注册的中间件，响应从内向外返回：

```
请求 → [Logger] → [Auth] → [CORS] → [Handler] → 响应
                ←        ←        ←        ←
```

## 参考

- [Radix Tree 路由算法](https://en.wikipedia.org/wiki/Radix_tree)
- [HTTP 路由中间件模式](https://en.wikipedia.org/wiki/Middleware)
