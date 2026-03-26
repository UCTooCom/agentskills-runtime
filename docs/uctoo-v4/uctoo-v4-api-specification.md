# uctoo V4.0 API规范

## 文档信息
- **版本**: 1.0.0
- **创建日期**: 2026-03-13
- **适用范围**: uctoo V4.0 应用服务器

## 1. 概述

uctoo V4.0 API 遵循与 backend 一致的 RESTful API 规范，确保前后端接口的一致性。

### 1.1 设计原则
- 采用 RESTful 风格 API
- 遵循全栈模型同构 UMI 设计理念
- 采用 JWT 进行接口权限验证
- 单表对应的 CRUD 操作默认以 id 字段作为主标识

## 2. 路由规范

### 2.1 标准 CRUD 路由

以 uctoo 数据库 entity 表为例：

| 方法 | 路由 | 说明 | 认证 |
|------|------|------|------|
| POST | `/api/v1/uctoo/entity/add` | 新增数据 | 需要 |
| POST | `/api/v1/uctoo/entity/edit` | 更新数据 | 需要 |
| POST | `/api/v1/uctoo/entity/del` | 删除数据 | 需要 |
| GET | `/api/v1/uctoo/entity/:id` | 查询单条 | 可选 |
| GET | `/api/v1/uctoo/entity/:limit/:page` | 分页查询 | 可选 |
| GET | `/api/v1/uctoo/entity/:limit/:page/:skip` | 分页查询（带跳过） | 可选 |

### 2.2 多数据库路由规则

将 `/uctoo/entity` 部分替换为对应的数据库名和表名：
```
/api/v1/{database}/{table}
```

## 3. 请求规范

### 3.1 认证方式

需要权限的接口需先通过登录接口获取动态 token，再以 Bearer token 作为 Authorization header 进行调用：

```
Authorization: Bearer <token>
```

Token 过期时间默认为 172800 秒（48小时）。

### 3.2 请求格式

POST 请求 body 数据以 JSON 格式提交：

```json
{
    "name": "示例名称",
    "description": "示例描述"
}
```

### 3.3 查询参数

列表查询接口支持以下查询参数（通过 URL 查询字符串传递）：

| 参数 | 类型 | 说明 |
|------|------|------|
| sort | String | 排序字段，负号表示降序 |
| filter | JSON | 过滤条件 |

示例：
```
/api/v1/uctoo/entity/10/0?sort=-privacy_level,id&filter={"link":{"endsWith":"opencangjie.com"}}
```

**注意**：分页参数通过路径参数传递，而不是查询参数：
- `:limit` - 每页条数
- `:page` - 页码，从0开始
- `:skip` - 跳过条数（可选）

## 4. 响应规范

### 4.1 成功响应

**单条数据**：
```json
{
    "data": {
        "id": "uuid",
        "name": "名称",
        "createdAt": "2026-03-13T00:00:00Z"
    }
}
```

**列表数据**：
```json
{
    "data": [...],
    "currentPage": 0,
    "totalCount": 100,
    "totalPage": 10
}
```

### 4.2 错误响应

```json
{
    "errno": "42002",
    "errmsg": "错误描述"
}
```

### 4.3 HTTP 状态码

| 状态码 | 说明 |
|--------|------|
| 200 | 请求成功 |
| 400 | 客户端请求语法错误 |
| 401 | 未认证 |
| 403 | 权限不足 |
| 404 | 资源不存在 |
| 500 | 服务器内部错误 |

## 5. 错误码规范

### 5.1 错误码格式

错误码一般为 5 位数，格式为 `XXYYZ`：
- `XX`: 模块代码
- `YY`: 错误类型
- `Z`: 具体错误

### 5.2 常用错误码

| 错误码 | 说明 |
|--------|------|
| 40001 | 参数错误 |
| 40101 | 未授权访问 |
| 40301 | 权限不足 |
| 40401 | 资源不存在 |
| 50001 | 服务器内部错误 |

## 6. 接口详情

### 6.1 新增接口

**请求**：
```http
POST /api/v1/uctoo/entity/add
Content-Type: application/json
Authorization: Bearer <token>

{
    "name": "示例名称",
    "description": "示例描述"
}
```

**响应**：
```json
{
    "data": {
        "id": "generated-uuid",
        "name": "示例名称",
        "description": "示例描述",
        "creator": "user-uuid",
        "createdAt": "2026-03-13T00:00:00Z",
        "updatedAt": "2026-03-13T00:00:00Z"
    }
}
```

### 6.2 更新接口

**请求**：
```http
POST /api/v1/uctoo/entity/edit
Content-Type: application/json
Authorization: Bearer <token>

{
    "id": "entity-uuid",
    "name": "更新后的名称"
}
```

**响应**：
```json
{
    "data": {
        "id": "entity-uuid",
        "name": "更新后的名称",
        "updatedAt": "2026-03-13T01:00:00Z"
    }
}
```

**批量更新**：
```json
{
    "ids": "[\"uuid1\", \"uuid2\"]",
    "status": "active"
}
```

**恢复软删除数据**：
```json
{
    "id": "entity-uuid",
    "deletedAt": "0"
}
```

### 6.3 删除接口

**请求**：
```http
POST /api/v1/uctoo/entity/del
Content-Type: application/json
Authorization: Bearer <token>

{
    "id": "entity-uuid"
}
```

**软删除**（默认）：
```json
{
    "id": "entity-uuid"
}
```

**硬删除**：
```json
{
    "id": "entity-uuid",
    "force": 1
}
```

**批量删除**：
```json
{
    "ids": "[\"uuid1\", \"uuid2\"]"
}
```

**响应**：成功时不返回任何数据，HTTP 状态码 200。

### 6.4 单条查询接口

**请求**：
```http
GET /api/v1/uctoo/entity/:id
```

**响应**：
```json
{
    "data": {
        "id": "entity-uuid",
        "name": "名称",
        "description": "描述",
        "createdAt": "2026-03-13T00:00:00Z"
    }
}
```

### 6.5 列表查询接口

**请求**：
```http
GET /api/v1/uctoo/entity/:limit/:page
```

**带跳过参数**：
```http
GET /api/v1/uctoo/entity/:limit/:page/:skip
```

**带排序和过滤**：
```http
GET /api/v1/uctoo/entity/10/0?sort=-privacy_level,id&filter={"link":{"endsWith":"opencangjie.com"}}
```

**响应**：
```json
{
    "data": [
        {
            "id": "uuid1",
            "name": "名称1"
        },
        {
            "id": "uuid2",
            "name": "名称2"
        }
    ],
    "currentPage": 0,
    "totalCount": 100,
    "totalPage": 10
}
```

## 7. 安全规范

### 7.1 敏感字段过滤

API 不应输出的模型字段，可以使用 `hideSelectedObjectKeys()` 方法过滤：
- 密码字段
- 内部标识字段
- 其他敏感信息

### 7.2 权限验证

需要权限的接口必须：
1. 验证 JWT token 有效性
2. 检查用户权限
3. 必要时检查行级权限

## 8. 当前实现状态

### 8.1 已实现的功能

uctoo V4.0 当前版本已实现以下功能：

**CRUD操作**：
- ✅ 创建数据（POST /add）
- ✅ 更新数据（POST /edit）
- ✅ 删除数据（POST /del，支持软删除和硬删除）
- ✅ 单条查询（GET /:id）
- ✅ 分页查询（GET /:limit/:page）
- ✅ 带跳过参数的分页查询（GET /:limit/:page/:skip）

**批量操作**：
- ✅ 批量更新（通过ids参数）
- ✅ 批量删除（通过ids参数）
- ✅ 批量恢复软删除数据

**其他功能**：
- ✅ 软删除和恢复功能
- ✅ 统计功能（countAll、countByUser）
- ✅ 按创建者分页查询

### 8.2 待实现的功能（TODO）

以下功能需要在仓颉语言生态成熟后实现：

**排序功能（sort参数）**：
- ⏳ 动态排序支持
- 当前状态：接口已定义，但未实现动态排序逻辑
- 实现需求：
  - JSON解析库支持
  - 动态ORDER BY子句构建
  - 支持多字段排序（如 `-created_at,id`）
- 临时方案：使用默认排序（按created_at降序）

**过滤功能（filter参数）**：
- ⏳ 动态过滤支持
- 当前状态：接口已定义，但未实现动态过滤逻辑
- 实现需求：
  - JSON解析库支持
  - 动态WHERE条件构建
  - 支持Prisma风格的查询条件（如 `{"link":{"endsWith":"opencangjie.com"}}`）
  - 支持复杂条件组合（AND、OR、NOT）
- 临时方案：返回所有数据，由客户端过滤

**实现路线图**：
1. 等待仓颉语言JSON解析库成熟
2. 实现查询条件解析器（类似Prisma的RequestParserService）
3. 实现动态SQL构建器
4. 集成到DAO层的查询方法中

### 8.3 技术限制说明

由于仓颉语言目前处于早期阶段，以下技术限制影响了部分功能的实现：

1. **JSON解析**：缺乏成熟的JSON解析库，无法动态解析filter参数
2. **动态SQL**：缺乏动态SQL构建能力，无法根据参数动态生成WHERE和ORDER BY子句
3. **反射机制**：缺乏反射机制，无法动态访问对象属性

这些限制是暂时的，随着仓颉语言生态的成熟将逐步解决。

## 9. 参考文档

- [uctoo API设计规范](../../../backend/docs/uctoo-api-design-specification.md)
- [子系统架构说明](./uctoo-v4-architecture.md)
