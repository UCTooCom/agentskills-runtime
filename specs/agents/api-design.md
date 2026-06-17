# Agent 系统 API 设计文档

## 文档信息
- **项目名称**: Agent 动态生成与多 Agent 协作系统
- **版本**: 1.0.0
- **创建日期**: 2026-05-29
- **作者**: SDD Agent
- **状态**: 草稿

---

## 1. API 设计概述

### 1.1 设计原则

本 API 设计严格遵循 uctoo V4.0 API 规范：
- **RESTful 风格**: 采用 RESTful 风格 API
- **路由格式**: `/api/v1/{database}/{table}/{operation}`
- **认证方式**: JWT 认证 + RBAC 权限控制
- **数据格式**: JSON 格式
- **错误码格式**: 5 位数格式 `XXYYZ`

### 1.2 命名规范

- **资源命名**: 使用复数形式（如 `/agents` 而非 `/agent`）
- **路径分隔**: 使用小写字母和连字符（kebab-case）
- **参数命名**: 使用驼峰命名（camelCase）

---

## 2. 标准 CRUD 路由

根据 uctoo V4.0 API 规范，agents 表的标准 CRUD 路由如下：

| 方法 | 路由 | 说明 | 认证 |
|------|------|------|------|
| POST | `/api/v1/uctoo/agents/add` | 新增数据 | 需要 |
| POST | `/api/v1/uctoo/agents/edit` | 更新数据 | 需要 |
| POST | `/api/v1/uctoo/agents/del` | 删除数据 | 需要 |
| POST | `/api/v1/uctoo/agents/empty-recycle-bin` | 清空回收站 | 需要 |
| GET | `/api/v1/uctoo/agents/:id` | 查询单条 | 可选 |
| GET | `/api/v1/uctoo/agents/:limit/:page` | 分页查询 | 可选 |
| GET | `/api/v1/uctoo/agents/:limit/:page/:skip` | 分页查询（带跳过） | 可选 |

### 2.1 关联表路由

| 表名 | 路由前缀 |
|------|----------|
| agent_contexts | `/api/v1/uctoo/agent_contexts` |
| agent_tasks | `/api/v1/uctoo/agent_tasks` |
| agent_messages | `/api/v1/uctoo/agent_messages` |

---

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
    "name": "AnalyzerAgent",
    "type": "analyzer",
    "description": "代码分析 Agent"
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
/api/v1/uctoo/agents/10/1?sort=-created_at,name&filter={"type":{"equals":"analyzer"}}
```

---

## 4. 响应规范

### 4.1 成功响应

**单条数据**：
```json
{
    "id": "uuid-xxx",
    "name": "AnalyzerAgent",
    "type": "analyzer",
    "createdAt": "2026-05-29T10:00:00Z"
}
```

**说明**：单条数据直接返回实体对象，不包装在 `data` 中。

**列表数据**：
```json
{
    "agentss": [
        {
            "id": "uuid-xxx",
            "name": "AnalyzerAgent",
            "type": "analyzer"
        }
    ],
    "currentPage": 1,
    "totalCount": 100,
    "totalPage": 10
}
```

**说明**：列表数据的键名为表名加 `s`（如 `agents` 表对应 `agentss`），符合 UMI 全栈模型同构规范。

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

---

## 5. 接口详情

### 5.1 新增接口

**请求**：
```http
POST /api/v1/uctoo/agents/add
Content-Type: application/json
Authorization: Bearer <token>

{
    "name": "AnalyzerAgent",
    "type": "analyzer",
    "description": "代码分析 Agent",
    "systemPrompt": "你是一个代码分析专家...",
    "tools": ["file_read", "bash"],
    "model": "claude-3-sonnet"
}
```

**响应**：
```json
{
    "id": "generated-uuid",
    "name": "AnalyzerAgent",
    "type": "analyzer",
    "status": 0,
    "createdAt": "2026-05-29T10:00:00Z"
}
```

### 5.2 更新接口

**请求**：
```http
POST /api/v1/uctoo/agents/edit
Content-Type: application/json
Authorization: Bearer <token>

{
    "id": "agent-uuid",
    "name": "UpdatedAnalyzerAgent",
    "status": 1
}
```

**响应**：
```json
{
    "id": "agent-uuid",
    "name": "UpdatedAnalyzerAgent",
    "status": 1,
    "updatedAt": "2026-05-29T11:00:00Z"
}
```

### 5.3 删除接口

**请求**：
```http
POST /api/v1/uctoo/agents/del
Content-Type: application/json
Authorization: Bearer <token>

{
    "id": "agent-uuid"
}
```

**软删除**（默认）：
```json
{
    "id": "agent-uuid"
}
```

**硬删除**：
```json
{
    "id": "agent-uuid",
    "force": 1
}
```

**响应**：
```json
{
    "desc": "删除成功"
}
```

### 5.4 单条查询接口

**请求**：
```http
GET /api/v1/uctoo/agents/:id
```

**响应**：
```json
{
    "id": "agent-uuid",
    "name": "AnalyzerAgent",
    "type": "analyzer",
    "description": "代码分析 Agent",
    "status": 1,
    "config": {},
    "systemPrompt": "你是一个代码分析专家...",
    "tools": ["file_read", "bash"],
    "model": "claude-3-sonnet",
    "parentId": null,
    "userId": "uuid-user",
    "createdAt": "2026-05-29T10:00:00Z",
    "updatedAt": "2026-05-29T10:00:00Z"
}
```

### 5.5 列表查询接口

**请求**：
```http
GET /api/v1/uctoo/agents/:limit/:page
```

**响应**：
```json
{
    "agentss": [
        {
            "id": "uuid-xxx",
            "name": "AnalyzerAgent",
            "type": "analyzer",
            "status": 1,
            "createdAt": "2026-05-29T10:00:00Z"
        }
    ],
    "currentPage": 1,
    "totalCount": 100,
    "totalPage": 10
}
```

---

## 6. Agent 生命周期接口

### 6.1 启动 Agent

**请求**：
```http
POST /api/v1/uctoo/agents/start
Content-Type: application/json
Authorization: Bearer <token>

{
    "id": "agent-uuid"
}
```

**响应**：
```json
{
    "id": "agent-uuid",
    "status": 1
}
```

### 6.2 停止 Agent

**请求**：
```http
POST /api/v1/uctoo/agents/stop
Content-Type: application/json
Authorization: Bearer <token>

{
    "id": "agent-uuid"
}
```

**响应**：
```json
{
    "id": "agent-uuid",
    "status": 0
}
```

### 6.3 暂停 Agent

**请求**：
```http
POST /api/v1/uctoo/agents/pause
Content-Type: application/json
Authorization: Bearer <token>

{
    "id": "agent-uuid"
}
```

**响应**：
```json
{
    "id": "agent-uuid",
    "status": 2
}
```

### 6.4 恢复 Agent

**请求**：
```http
POST /api/v1/uctoo/agents/resume
Content-Type: application/json
Authorization: Bearer <token>

{
    "id": "agent-uuid"
}
```

**响应**：
```json
{
    "id": "agent-uuid",
    "status": 1
}
```

---

## 7. Agent 任务接口

### 7.1 分配任务

**请求**：
```http
POST /api/v1/uctoo/agent_tasks/add
Content-Type: application/json
Authorization: Bearer <token>

{
    "agentId": "agent-uuid",
    "priority": 3,
    "payload": {
        "type": "analysis",
        "target": "/path/to/code"
    }
}
```

**响应**：
```json
{
    "id": "task-uuid",
    "agentId": "agent-uuid",
    "status": 0,
    "priority": 3
}
```

### 7.2 查询 Agent 任务列表

**请求**：
```http
GET /api/v1/uctoo/agent_tasks/:limit/:page?filter={"agentId":"agent-uuid"}
```

**响应**：
```json
{
    "agentTaskss": [
        {
            "id": "task-uuid",
            "agentId": "agent-uuid",
            "status": 1,
            "priority": 3,
            "payload": {},
            "createdAt": "2026-05-29T10:00:00Z"
        }
    ],
    "currentPage": 1,
    "totalCount": 10,
    "totalPage": 1
}
```

---

## 8. Agent 协作接口

### 8.1 创建协作任务

**请求**：
```http
POST /api/v1/uctoo/agent_tasks/add
Content-Type: application/json
Authorization: Bearer <token>

{
    "agentId": "main-agent-uuid",
    "priority": 2,
    "payload": {
        "type": "collaboration",
        "mode": "parallel",
        "childAgents": ["analyzer-uuid", "comparator-uuid"],
        "target": "/path/to/project"
    }
}
```

**响应**：
```json
{
    "id": "collab-task-uuid",
    "agentId": "main-agent-uuid",
    "status": 0,
    "priority": 2
}
```

---

## 9. CLI 命令设计

CLI 命令遵循 skill agent 规范：

### 9.1 命令结构

```
skill agent <command> [options]
```

### 9.2 命令清单

#### 9.2.1 create - 创建 Agent

```bash
skill agent create --name <name> --type <type> [--description <text>] [--file <path>]
```

#### 9.2.2 list - 列出 Agent

```bash
skill agent list [--status <status>] [--type <type>]
```

#### 9.2.3 show - 显示 Agent 详情

```bash
skill agent show <id>
```

#### 9.2.4 update - 更新 Agent

```bash
skill agent update <id> [--name <name>] [--description <text>]
```

#### 9.2.5 delete - 删除 Agent

```bash
skill agent delete <id> [-f]
```

#### 9.2.6 start - 启动 Agent

```bash
skill agent start <id>
```

#### 9.2.7 stop - 停止 Agent

```bash
skill agent stop <id>
```

---

## 10. 错误码定义

### 10.1 通用错误码

| 错误码 | 说明 |
|--------|------|
| 40001 | 参数错误 |
| 40101 | 未授权访问 |
| 40301 | 权限不足 |
| 40401 | 资源不存在 |
| 50001 | 服务器内部错误 |

### 10.2 Agent 相关错误码

| 错误码 | 说明 |
|--------|------|
| 40001 | 参数错误 |
| 40401 | Agent 不存在 |
| 40402 | Agent 已运行 |
| 40403 | Agent 已停止 |
| 50001 | Agent 启动失败 |
| 50002 | Agent 停止失败 |
| 50003 | Agent 配置错误 |

---

## 11. 权限要求

### 11.1 权限列表

| 权限标识 | 说明 | 适用接口 |
|----------|------|----------|
| database.uctoo.agents:read | 读取 Agent 信息 | GET /agents/* |
| database.uctoo.agents:write | 创建/更新/删除 Agent | POST /agents/* |
| database.uctoo.agents:execute | 启动/停止 Agent | POST /agents/start, POST /agents/stop |
| database.uctoo.agent_tasks:read | 读取任务信息 | GET /agent_tasks/* |
| database.uctoo.agent_tasks:write | 创建/更新任务 | POST /agent_tasks/* |

### 11.2 用户组权限

| 用户组 | 权限 |
|--------|------|
| agents | database.uctoo.agents:* |
| subagents | database.uctoo.agent_tasks:* |