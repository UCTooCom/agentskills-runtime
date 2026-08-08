# HTTP 服务器示例

演示带有路由、JSON/表单/多部分处理和所有标准 HTTP 方法的基本 HTTP 服务器。

## 构建和运行

```bash
cd sample/server
cjpm build
cjpm run
```

测试：`curl http://127.0.0.1:8080/`

## 主要特性

- 带有路径参数（`:id`）的基数树路由
- GET、POST、PUT、PATCH、DELETE 处理器
- JSON、表单和多部分体解析
- 使用 kaca_json 构建 JSON 响应
- 未知路由的 404 处理

```cangjie
let router = Router()
    .get("/", handleRoot).get("/users", handleListUsers).get("/users/:id", handleGetUser)
    .post("/users", handleCreateUser).post("/login", handleLogin).post("/upload", handleUpload)
```

## 预期输出

服务器在 8080 端口启动。所有端点返回 JSON 响应。/login 端点解析表单数据，/upload 解析多部分数据。
