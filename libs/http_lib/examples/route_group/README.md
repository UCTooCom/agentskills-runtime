# 路由组中间件示例

演示带有作用域中间件的路由分组：所有路由的全局日志，仅 API 路由的认证和压缩。

## 构建和运行

```bash
cd sample/route_group
cjpm build
cjpm run
```

测试：`curl -H "Authorization: Bearer test123" http://localhost:8080/api/users`

## 主要特性

- 应用于所有路由的全局中间件
- 通过 `MiddlewareChain` 为路由组设置作用域中间件
- API 端点的 Bearer Token 认证
- 公开路由：/、/health
- 受保护路由：/api/users、/api/me

```cangjie
// 全局中间件
router.use(loggingMiddleware)
// 带认证中间件的 API 组
let apiMiddleware = MiddlewareChain().use(authMiddleware).use(compressMiddleware)
let apiHandler = apiMiddleware.apply({req => ...})
router.get("/api/users", apiHandler)
```

## 预期输出

服务器在 8080 端口启动。公开路由无需认证即可访问。API 路由需要在 Authorization 头中提供有效的 Bearer Token。
