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
| POST | `/api/v1/uctoo/entity/empty-recycle-bin` | 清空回收站 | 需要 |
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
/api/v1/uctoo/entity/10/1?sort=-privacy_level,id&filter={"link":{"endsWith":"opencangjie.com"}}
```

**注意**：分页参数通过路径参数传递，而不是查询参数：
- `:limit` - 每页条数
- `:page` - 页码，从1开始
- `:skip` - 跳过条数（可选）

## 4. 响应规范

### 4.1 成功响应

**单条数据**：
```json
{
    "id": "uuid",
    "name": "名称",
    "createdAt": "2026-03-13T00:00:00Z"
}
```

**说明**：单条数据直接返回实体对象，不包装在 `data` 中，与 UCToo V3 保持一致。

**列表数据**：
```json
{
    "entitys": [...],
    "currentPage": 1,
    "totalCount": 100,
    "totalPage": 10
}
```

**说明**：列表数据的键名为表名加 `s`（如 `entity` 表对应 `entitys`），符合 UMI 全栈模型同构规范。

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
    "id": "generated-uuid",
    "name": "示例名称",
    "description": "示例描述",
    "creator": "user-uuid",
    "createdAt": "2026-03-13T00:00:00Z",
    "updatedAt": "2026-03-13T00:00:00Z"
}
```

**说明**：新增成功后直接返回创建的实体对象，不包装在 `data` 中。

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
    "id": "entity-uuid",
    "name": "更新后的名称",
    "updatedAt": "2026-03-13T01:00:00Z"
}
```

**说明**：更新成功后直接返回更新后的实体对象，不包装在 `data` 中。

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

**响应**：
```json
{
    "desc": "删除成功"
}
```

**说明**：删除成功后返回简单确认消息，HTTP 状态码 200。

### 6.4 清空回收站接口

**请求**：
```http
POST /api/v1/uctoo/entity/empty-recycle-bin
Content-Type: application/json
Authorization: Bearer <token>
```

**响应**：
```json
{
    "desc": "清空回收站成功"
}
```

**说明**：
- 清空回收站接口用于一次性硬删除所有已软删除的数据
- 该接口会永久删除所有deleted_at不为null的记录，不可恢复
- 需要用户权限验证
- 成功后返回简单确认消息，HTTP 状态码 200

**使用场景**：
1. 用户在回收站页面点击"清空回收站"按钮
2. 系统定期清理过期的软删除数据
3. 数据管理员的批量清理操作

**注意事项**：
- 该操作不可逆，建议在前端进行二次确认
- 对于大量数据，可能需要较长时间执行
- 建议记录操作日志，便于审计追踪

### 6.5 单条查询接口

**请求**：
```http
GET /api/v1/uctoo/entity/:id
```

**响应**：
```json
{
    "id": "entity-uuid",
    "name": "名称",
    "description": "描述",
    "createdAt": "2026-03-13T00:00:00Z"
}
```

**说明**：单条查询直接返回实体对象，不包装在 `data` 中，与 UCToo V3 保持一致。

### 6.6 列表查询接口

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
GET /api/v1/uctoo/entity/10/1?sort=-privacy_level,id&filter={"link":{"endsWith":"opencangjie.com"}}
```

**响应**：
```json
{
    "entitys": [
        {
            "id": "uuid1",
            "name": "名称1"
        },
        {
            "id": "uuid2",
            "name": "名称2"
        }
    ],
    "currentPage": 1,
    "totalCount": 100,
    "totalPage": 10
}
```

**说明**：响应中的数据数组键名为 `entitys`（表名加 `s`），与 UCToo V3 保持一致，符合 UMI 全栈模型同构规范。前端使用 `dataKey: 'entitys'` 配置自动映射数据。

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

## 8. UMI 全栈模型同构规范

### 8.1 概述

UCToo V4.0 遵循 UMI（全栈模型同构）设计理念，在服务器端、Web前端、小程序端、APP端等所有应用端定义一致的数据模型结构，并定义统一的 API 进行数据一致性同步。

### 8.2 列表数据响应格式

**规范**：列表数据的键名为表名加 `s`（复数形式）

**示例**：
- `entity` 表 → `entitys` 键名
- `user` 表 → `users` 键名
- `application` 表 → `applications` 键名

**响应格式**：
```json
{
    "{表名}s": [...],
    "currentPage": 1,
    "totalCount": 100,
    "totalPage": 10
}
```

**实现示例**（EntityController.cj）：
```cangjie
res.status(200).json("{\"currentPage\":${currentPage},\"totalCount\":${total},\"totalPage\":${totalPage},\"entitys\":[${entitiesJson}]}")
```

### 8.3 前端对接

前端使用 `dataKey` 配置自动映射数据：

```typescript
// web-admin/web/src/store/models/uctoo/entity.ts
getEntityList(page: number, pageSize: number, searchParams?: any) {
  return useAxiosRepo(entity).api().get(`/api/v1/uctoo/entity/${pageSize}/${page}`, {
    params: searchParams,
    headers: {
      'Content-Type': 'application/json;charset=utf-8',
      'Authorization': `Bearer ${localStorage.getItem('accessToken')}`
    },
    baseURL: apiURL,
    dataKey: 'entitys'  // 指定数据键名
  })
}
```

### 8.4 与 UCToo V3 的兼容性

UCToo V4.0 的列表响应格式与 UCToo V3 完全一致，确保前后端无缝对接：

**UCToo V3 实现**（backend/src/app/controllers/uctoo/entity/index.ts）：
```typescript
res.status(200).json({
  currentPage: page,
  totalCount: totalCount,
  totalPage: Math.ceil(Number(totalCount)/limit),
  entitys: entitysFromDb  // 使用 entitys 而非 data
});
```

### 8.5 UMI 架构优势

1. **数据一致性**：全栈使用相同的数据模型定义
2. **自动同步**：API 返回数据自动保存到本地存储
3. **类型安全**：TypeScript 类型定义前后端共享
4. **开发效率**：减少数据转换代码，提高开发效率
5. **维护简单**：模型变更只需修改一处，自动同步到所有端

## 9. 当前实现状态

### 9.1 已实现的功能

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

**查询功能（Prisma风格）**：
- ✅ 动态排序支持（sort参数）
- ✅ 动态过滤支持（filter参数）
- ✅ 所有Prisma风格查询操作符
- ✅ 复杂条件组合（AND、OR、NOT）

**其他功能**：
- ✅ 软删除和恢复功能
- ✅ 统计功能（countAll、countByUser）
- ✅ 按创建者分页查询

### 9.2 查询操作符详细说明

#### 9.2.1 支持的查询操作符

系统完整支持以下Prisma风格的查询操作符：

| 操作符 | 说明 | 示例 | SQL等效 |
|--------|------|------|---------|
| `equals` | 等于 | `{"name": {"equals": "test"}}` | `name = 'test'` |
| `not` | 不等于 | `{"status": {"not": "deleted"}}` | `status != 'deleted'` |
| `lt` | 小于 | `{"age": {"lt": 18}}` | `age < 18` |
| `lte` | 小于等于 | `{"price": {"lte": 100}}` | `price <= 100` |
| `gt` | 大于 | `{"score": {"gt": 60}}` | `score > 60` |
| `gte` | 大于等于 | `{"level": {"gte": 5}}` | `level >= 5` |
| `contains` | 包含 | `{"title": {"contains": "关键词"}}` | `title LIKE '%关键词%'` |
| `startsWith` | 以...开头 | `{"code": {"startsWith": "PRD"}}` | `code LIKE 'PRD%'` |
| `endsWith` | 以...结尾 | `{"link": {"endsWith": ".com"}}` | `link LIKE '%.com'` |
| `in` | 在列表中 | `{"status": {"in": ["active", "pending"]}}` | `status IN ('active', 'pending')` |
| `notIn` | 不在列表中 | `{"role": {"notIn": ["admin", "super"]}}` | `role NOT IN ('admin', 'super')` |
| `isSet` | 字段是否设置 | `{"deletedAt": {"isSet": false}}` | `deletedAt IS NULL` |
| `between` | 区间查询 | `{"age": {"between": [18, 60]}}` | `age BETWEEN 18 AND 60` |
| `notBetween` | 不在区间 | `{"price": {"notBetween": [100, 500]}}` | `price NOT BETWEEN 100 AND 500` |

#### 9.2.2 逻辑操作符

支持以下逻辑操作符进行条件组合：

| 操作符 | 说明 | 示例 |
|--------|------|------|
| `AND` | 逻辑与 | `{"AND": [{"status": "active"}, {"level": {"gte": 5}}]}` |
| `OR` | 逻辑或 | `{"OR": [{"role": "admin"}, {"role": "super"}]}` |
| `NOT` | 逻辑非 | `{"NOT": {"status": "deleted"}}` |

#### 9.2.3 排序功能

支持多字段排序，通过sort参数指定：

**语法**：
- 正序：字段名（如 `created_at`）
- 倒序：字段名前加负号（如 `-created_at`）
- 多字段：用逗号分隔（如 `-created_at,name`）

**示例**：
```
GET /api/v1/uctoo/entity/10/1?sort=-privacy_level,id
```
表示先按 privacy_level 降序，再按 id 升序排序。

### 9.3 查询示例

#### 9.3.1 简单条件查询

**字符串精确匹配**：
```
GET /api/v1/uctoo/entity/10/1?filter={"name":"测试实体"}
```

**数值比较查询**：
```
GET /api/v1/uctoo/entity/10/1?filter={"privacy_level":{"gte":1,"lte":3}}
```

**字符串模糊查询**：
```
GET /api/v1/uctoo/entity/10/1?filter={"link":{"contains":"opencangjie"}}
```

**列表包含查询**：
```
GET /api/v1/uctoo/entity/10/1?filter={"privacy_level":{"in":[1,2,3]}}
```

#### 9.3.2 复合条件查询

**AND条件组合**：
```
GET /api/v1/uctoo/entity/10/1?filter={"AND":[{"privacy_level":{"gte":2}},{"name":{"contains":"测试"}}]}
```

**OR条件组合**：
```
GET /api/v1/uctoo/entity/10/1?filter={"OR":[{"privacy_level":1},{"privacy_level":3}]}
```

**NOT条件**：
```
GET /api/v1/uctoo/entity/10/1?filter={"NOT":{"privacy_level":0}}
```

**嵌套复合条件**：
```
GET /api/v1/uctoo/entity/10/1?filter={"AND":[{"OR":[{"privacy_level":1},{"privacy_level":2}]},{"name":{"contains":"测试"}}]}
```

#### 9.3.3 排序和过滤组合

```
GET /api/v1/uctoo/entity/10/1?sort=-created_at,name&filter={"privacy_level":{"gte":1}}
```

### 9.4 实现架构

查询功能的实现采用分层架构：

```
┌─────────────────────────────────────────────────────────┐
│                    Controller层                          │
│  接收HTTP请求，提取filter和sort参数                       │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│                    Service层                             │
│  EntityService / ApplicationService                      │
│  ├─ RequestParserService: 解析filter JSON和sort字符串    │
│  └─ buildWhereClause(): 构建SQL WHERE子句               │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│                    DAO层                                 │
│  EntityDAO / ApplicationDAO                              │
│  └─ findEntityByCondition(): 执行动态查询                │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│                    ORM层 (f_orm)                         │
│  ├─ WHERE(whereClause): 设置WHERE条件                    │
│  ├─ ORDER_BY(orderByClause): 设置排序                    │
│  └─ Pagination(page, size): 设置分页                     │
└─────────────────────────────────────────────────────────┘
```

### 9.5 核心类说明

#### QueryCondition.cj

定义查询条件的数据模型：

```cangjie
// 查询操作符枚举
public enum QueryOperator {
    | Equals | Not | Lt | Lte | Gt | Gte
    | Contains | StartsWith | EndsWith
    | In | NotIn | IsSet | Between | NotBetween
}

// 逻辑操作符枚举
public enum LogicOperator {
    | And | Or | Not
}

// 字段条件
public class FieldCondition {
    public var field: String        // 字段名
    public var op: QueryOperator    // 操作符
    public var value: QueryValue    // 值
}

// 组合条件
public class CompositeCondition {
    public var logic: LogicOperator              // 逻辑操作符
    public var fieldConditions: ArrayList<FieldCondition>    // 字段条件列表
    public var compositeConditions: ArrayList<CompositeCondition>  // 嵌套条件
}

// 排序条件
public class SortCondition {
    public var field: String       // 字段名
    public var ascending: Bool     // 是否升序
}

// 解析后的查询对象
public class ParsedQuery {
    public var page: Int64         // 页码
    public var pageSize: Int64     // 每页条数
    public var filter: ?CompositeCondition  // 过滤条件
    public var sort: ArrayList<SortCondition>  // 排序条件
}
```

#### RequestParserService.cj

解析查询参数：

```cangjie
public class RequestParserService {
    // 解析查询参数
    public func parseQuery(
        filterStr: String,
        sortStr: String,
        page: Int64,
        pageSize: Int64
    ): ParsedQuery

    // 解析filter JSON字符串
    private func parseFilter(filterStr: String): ?CompositeCondition

    // 解析sort字符串
    private func parseSort(sortStr: String): ArrayList<SortCondition>
}
```

#### EntityService.cj

构建SQL子句：

```cangjie
public class EntityService {
    // 构建WHERE子句
    private func buildWhereClause(composite: CompositeCondition): String

    // 构建单个字段条件
    private func buildFieldClause(fieldCondition: FieldCondition): String

    // 构建IN子句
    private func buildInClause(field: String, values: ArrayList<String>, isIn: Bool): String

    // 构建BETWEEN子句
    private func buildBetweenClause(field: String, start: String, end: String, isBetween: Bool): String

    // 构建ORDER BY子句
    private func buildOrderByClause(sortConditions: ArrayList<SortCondition>): String
}
```

### 9.6 技术实现细节

#### JSON解析

使用仓颉标准库 `stdx.encoding.json` 进行JSON解析：

```cangjie
import stdx.encoding.json.{Json, JsonValue}

let jsonValue = Json.parse(filterStr)
if (let Some(obj) <- jsonValue.asObject()) {
    // 解析JSON对象
}
```

#### SQL注入防护

所有字符串值在构建SQL时都使用单引号包裹，防止SQL注入：

```cangjie
// 字符串值
return "${field} = '${v}'"  // 自动转义

// 数值直接拼接
return "${field} = ${v}"
```

#### 枚举比较

仓颉语言中枚举不能直接用 `==` 比较，使用 `match` 语句：

```cangjie
match (op) {
    case QueryOperator.Equals => buildEqualsClause(field, value)
    case QueryOperator.Not => buildNotClause(field, value)
    // ...
}
```

### 9.7 已完成的功能清单

- ✅ 所有Prisma风格查询操作符（14个）
- ✅ 逻辑操作符（AND、OR、NOT）
- ✅ 嵌套条件组合
- ✅ 多字段排序
- ✅ 升序和降序排序
- ✅ 分页查询
- ✅ JSON参数解析
- ✅ SQL子句动态构建
- ✅ 类型安全的查询值
- ✅ SQL注入防护

### 9.8 测试验证

所有查询功能已通过测试验证，测试覆盖：

- 简单条件查询（equals、not、lt、gt等）
- 字符串模糊查询（contains、startsWith、endsWith）
- 列表查询（in、notIn）
- 区间查询（between、notBetween）
- NULL值查询（isSet）
- 复合条件查询（AND、OR、NOT）
- 嵌套条件查询
- 多字段排序
- 排序和过滤组合

测试结果：**100% 通过**

## 10. 数据获取最佳实践

### 10.1 概述

**不推荐**使用 `/all` 接口获取所有数据，建议使用以下方式，以保证性能和安全性。

### 10.2 推荐方案

#### 方案1：大 pageSize 分页查询（推荐）

使用较大的 `pageSize`（建议不超过 1000）通过分页获取数据：

```http
GET /api/v1/uctoo/entity/1000/1
```

**示例**：
```http
GET /api/v1/uctoo/entity/1000/1?filter={"status":"active"}&sort=-created_at
```

**优势**：
- 保持 API 一致性
- 支持 `filter` 和 `sort` 参数
- 可控的数据量，避免性能问题
- 与现有分页架构完全兼容

**适用场景**：
- 数据量可控（< 1000 条）
- 需要完整数据用于列表展示
- 非实时场景（如数据导出、批量操作）

**注意事项**：
- 当前系统支持的最大 pageSize 为 1000
- 如果数据量超过 1000 条，建议使用多页查询
- 避免在实时性要求高的场景使用过大的 pageSize

#### 方案2：专门的下拉选择接口（按需实现）

对于下拉列表、选择器等场景，建议使用专门的接口（可按需实现）：

```http
GET /api/v1/uctoo/entity/options?fields=id,name&filter={"status":"active"}
```

**响应示例**：
```json
{
  "options": [
    { "id": "uuid1", "name": "选项1" },
    { "id": "uuid2", "name": "选项2" }
  ],
  "totalCount": 100
}
```

**优势**：
- 专门优化，只返回必要字段
- 性能更好，减少数据传输
- 明确的使用场景
- 避免滥用

**适用场景**：
- 下拉列表组件
- 选择器组件
- 自动完成功能
- 级联选择

#### 方案3：游标分页（大数据量场景）

对于大数据量（> 10000 条）场景，建议使用游标分页：

```http
GET /api/v1/uctoo/entity?cursor=last-id&limit=100
```

（注：此方案为高级特性，可根据实际需求实现）

### 10.3 查询回收站数据

#### 查询已删除的数据（回收站）

使用 `deleted_at` 字段的 `not` 操作符查询已删除的数据：

```http
GET /api/v1/uctoo/entity/20/1?filter={"deleted_at":{"not":null}}
```

**说明**：
- `{"deleted_at": {"not": null}}` 表示查询 `deleted_at` 不为 null 的记录
- 这是实现回收站功能的标准方式

#### 查询未删除的数据（正常数据）

查询 `deleted_at` 为 null 的记录（系统默认查询的就是未删除的数据）：

```http
GET /api/v1/uctoo/entity/20/1?filter={"deleted_at":null}
```

#### 清空回收站

使用专门的清空回收站接口：

```http
POST /api/v1/uctoo/entity/empty-recycle-bin
Content-Type: application/json
Authorization: Bearer <token>
```

**响应**：
```json
{
  "desc": "清空回收站成功"
}
```

**注意事项**：
- 该操作不可逆，会硬删除所有已软删除的数据
- 建议在前端进行二次确认
- 建议记录操作日志，便于审计追踪

### 10.4 性能优化建议

#### 1. 合理使用分页参数

- **小数据量场景**（< 100 条）：`pageSize = 20`
- **中等数据量场景**（100-1000 条）：`pageSize = 100`
- **大数据量场景**（> 1000 条）：使用多页查询或游标分页

#### 2. 充分利用 filter 和 sort

- 使用 `filter` 提前过滤数据，减少数据传输
- 使用 `sort` 让数据按需要的顺序返回，避免前端排序
- 组合使用 `filter` 和 `sort`，减少不必要的计算

#### 3. 字段选择（未来规划）

未来版本将支持字段选择功能，按需获取数据：

```http
GET /api/v1/uctoo/entity/20/1?select=["id","name","created_at"]
```

#### 4. 缓存策略

- 对于不经常变化的数据（如下拉选项），建议前端缓存
- 缓存时间建议：5-30 分钟
- 关键操作后及时清除缓存

### 10.5 安全建议

1. **避免数据泄露**
   - 不要一次性获取所有敏感数据
   - 使用 filter 限制返回的数据范围
   - 实施行级权限控制

2. **防止滥用**
   - 系统已限制最大 pageSize 为 1000
   - 建议前端监控异常大量数据的请求
   - 实施 API 调用频率限制

3. **审计追踪**
   - 记录敏感数据的查询操作
   - 监控异常数据访问模式
   - 定期审查数据访问日志

### 10.6 决策矩阵

| 场景 | 推荐方案 | pageSize | 备注 |
|------|----------|----------|------|
| 列表分页展示 | 标准分页 | 20-50 | 最常用 |
| 下拉选择 | 大 pageSize 分页 | 100-1000 | 按需使用 |
| 数据导出 | 大 pageSize 分页 | 100-1000 | 多页合并 |
| 批量操作 | 分步处理 | 50-100 | 避免超时 |
| 实时搜索 | 标准分页 | 10-20 | 快速响应 |

---

## 11. 参考文档

- [uctoo API设计规范](../../../backend/docs/uctoo-api-design-specification.md)
- [子系统架构说明](./uctoo-v4-architecture.md)
