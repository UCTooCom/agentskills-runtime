# REST API 服务器示例

演示具有 CRUD 操作、中间件和安全功能的完整 REST API 服务器。

## 构建和运行

```bash
cd sample/rest_api
cjpm build
cjpm run
```

测试：`curl http://127.0.0.1:8080/api/users`

## 主要特性

- CRUD 端点：GET/POST/PUT/DELETE /api/users
- 使用 `:id` 语法的路径参数
- 可配置来源的 CORS 中间件
- HSTS、安全头、速率限制
- 访问日志
- 使用内存数据存储的 JSON 请求/响应

```cangjie
let router = Router()
    .get("/", healthCheck)
    .get("/api/users", listUsers)
    .get("/api/users/:id", getUser)
    .post("/api/users", createUser)
    .put("/api/users/:id", updateUser)
    .delete("/api/users/:id", deleteUser)
```

## 预期输出

服务器在 8080 端口启动，预置了 3 个用户。所有 REST 端点可访问，中间件添加安全头和速率限制。
