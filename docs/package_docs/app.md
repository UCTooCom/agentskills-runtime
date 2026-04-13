# app - 应用服务器模块

> **包路径**: `magic.app`  
> **描述**: 高性能HTTP/HTTPS应用服务器,提供企业级API服务

## 概述

`magic.app` 是AgentSkills Runtime的核心应用服务器模块,提供完整的HTTP/HTTPS服务能力,包括路由、中间件、认证、数据库连接等功能。

## 核心组件

### HTTPServer

**描述**: HTTP/HTTPS服务器

**功能**:
- 支持HTTP和HTTPS协议
- 可配置的线程池
- 请求/响应拦截器
- 静态文件服务
- WebSocket支持

**配置**:
```ini
PORT=443
HOST=0.0.0.0
SSL_CERT=./ssl/server.crt
SSL_KEY=./ssl/server.key
```

**启动**:
```bash
cjpm run --skip-build --name magic.app
```

---

### Router

**描述**: 高性能路由系统

**功能**:
- RESTful路由支持
- 路径参数提取
- 路由分组
- 中间件挂载
- Trie树匹配

**示例**:
```cangjie
router.get("/api/v1/users", handler)
router.post("/api/v1/users", handler)
router.get("/api/v1/users/:id", handler)
```

---

### Middleware

**描述**: 中间件系统

**内置中间件**:
- `DeserializeUserMiddleware` - JWT认证
- `RequirePermissionMiddleware` - 权限检查
- `CORSMiddleware` - 跨域支持
- `LoggingMiddleware` - 请求日志

**使用示例**:
```cangjie
app.use("/api/v1/*", [
    DeserializeUserMiddleware(),
    RequirePermissionMiddleware()
])
```

---

## API端点

### 健康检查

**端点**: `GET /hello`

**描述**: 检查服务是否正常运行

**认证**: 不需要

**请求示例**:
```bash
curl -X GET https://javatoarktsapi.uctoo.com/hello
```

**响应示例**:
```json
{
  "message": "AgentSkills-runtime,Hello World"
}
```

---

### 应用信息

**端点**: `GET /api/v1/info`

**描述**: 获取应用基本信息

**认证**: 不需要

**响应示例**:
```json
{
  "name": "uctoo-backend-v4",
  "version": "0.0.19",
  "language": "cangjie"
}
```

---

### 服务状态

**端点**: `GET /api/v1/health`

**描述**: 获取服务健康状态

**认证**: 不需要

**响应示例**:
```json
{
  "status": "ok",
  "version": "0.0.19"
}
```

---

## 认证API

### 用户登录

**端点**: `POST /api/v1/uctoo/uctoo_user/signin`

**描述**: 用户登录并获取访问令牌

**认证**: 不需要

**请求体**:
```json
{
  "username": "admin",
  "password": "123456"
}
```

**响应示例**:
```json
{
  "errno": "0",
  "errmsg": "登录成功",
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": "505cf909-5e0e-4dde-b215-74274d2cc548",
      "username": "admin",
      "email": "demo@uctoo.com"
    }
  }
}
```

---

### Token刷新

**端点**: `POST /api/v1/uctoo/uctoo_user/refresh`

**描述**: 使用refresh_token获取新的access_token

**请求体**:
```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

---

### 用户信息

**端点**: `GET /api/v1/uctoo/uctoo_user/info`

**描述**: 获取当前登录用户信息

**认证**: 需要Bearer Token

**请求示例**:
```bash
curl -X GET https://javatoarktsapi.uctoo.com/api/v1/uctoo/uctoo_user/info \
  -H "Authorization: Bearer <access_token>"
```

---

## 数据库CRUD API

### 标准CRUD操作

**基础路径**: `/api/v1/uctoo/:entity`

**支持实体**:
- `uctoo_user` - 用户
- `uctoo_role` - 角色
- `uctoo_permission` - 权限
- `uctoo_session` - 会话
- `operate_log` - 操作日志

### 实体列表

**端点**: `GET /api/v1/uctoo/:entity`

**查询参数**:
- `page`: 页码
- `size`: 每页数量
- `sort`: 排序字段
- `order`: 排序方向

**请求示例**:
```bash
curl -X GET "https://javatoarktsapi.uctoo.com/api/v1/uctoo/uctoo_user?page=0&size=10" \
  -H "Authorization: Bearer <access_token>"
```

---

### 创建实体

**端点**: `POST /api/v1/uctoo/:entity/add`

**请求示例**:
```bash
curl -X POST https://javatoarktsapi.uctoo.com/api/v1/uctoo/uctoo_user/add \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{"username": "newuser", "email": "new@example.com"}'
```

---

### 更新实体

**端点**: `POST /api/v1/uctoo/:entity/edit`

**请求示例**:
```bash
curl -X POST https://javatoarktsapi.uctoo.com/api/v1/uctoo/uctoo_user/edit \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{"id": "user-id", "email": "new@example.com"}'
```

---

### 删除实体

**端点**: `POST /api/v1/uctoo/:entity/del`

**请求示例**:
```bash
curl -X POST https://javatoarktsapi.uctoo.com/api/v1/uctoo/uctoo_user/del \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{"id": "user-id"}'
```

---

## 性能指标

- **并发连接**: 1000+
- **响应时间**: < 50ms
- **吞吐量**: > 10000 req/s
- **内存占用**: < 100MB

---

## 目录结构

```
src/app/
├── main.cj                 # 应用主入口
├── core/                   # 核心组件
│   ├── server/            # HTTP服务器
│   ├── router/            # 路由系统
│   ├── middleware/        # 中间件
│   ├── http/              # HTTP请求/响应
│   └── database/          # 数据库连接池
├── routes/                # 路由处理
│   ├── skill/            # 技能路由
│   └── tool/             # 工具路由
├── controllers/           # 控制器
├── services/              # 业务服务
├── middlewares/           # 中间件实现
└── registry/              # 自动路由注册
```

---

**包文档维护**: CodeArts Agent  
**最后更新**: 2026-03-26
