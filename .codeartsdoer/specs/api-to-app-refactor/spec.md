# API 模块重构至 APP 模块需求规格文档

## 文档信息
- **项目名称**: agentskills-runtime API 模块重构
- **版本**: 1.1.0
- **创建日期**: 2026-03-13
- **最后更新**: 2026-03-13
- **作者**: SDD Agent
- **状态**: 草稿
- **参考文档**: D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\specs\004-agent-skill-runtime

## 1. 概述

### 1.1 项目背景
agentskills-runtime 项目当前存在两个 HTTP 服务模块：
- **api 模块** (`src/api/`): 已实现完整的 HTTP 服务器功能，包括技能管理、WebSocket 聊天、uctoo API 等
- **app 模块** (`src/app/`): 按照 uctoo V4.0 架构规范设计，但部分功能未真实实现

当前问题：
1. 架构不统一，api 模块未遵循 uctoo V4.0 的三层架构设计
2. app 模块功能不完整，缺少 HTTP 服务器实现
3. 两套代码并存，维护成本高

### 1.2 项目范围

#### 包含内容
1. 将 api 模块的 HTTP 服务器功能重构到 app 模块
2. 将 api 模块的技能管理 API 重构到 app 模块
3. 将 api 模块的 WebSocket 聊天功能重构到 app 模块
4. 实现 agent_skills 表的标准 CRUD 功能
5. 按照 uctoo V4.0 架构规范组织代码
6. 保持与 backend 项目架构一致性
7. **将原 api 模块接口重构到 `/api/v1/uctoo/` 路由前缀下**（健康检查 `/hello` 除外）

#### 不包含内容
1. api 模块的删除（保留作为参考）
2. 数据库表结构变更
3. 前端界面开发
4. 其他模块的功能变更

### 1.3 术语定义
| 术语 | 定义 |
|------|------|
| uctoo V4.0 | 基于 Cangjie 语言的 uctoo 应用服务器架构规范 |
| 三层架构 | Controllers → Services → Models 的分层设计 |
| CRUD | Create, Read, Update, Delete 基本数据操作 |
| 软删除 | 通过 deleted_at 字段标记删除，而非物理删除 |
| UMI | 全栈模型同构设计，前后端使用相同的数据模型 |
| uctoo API 规范 | uctoo 系统的 RESTful API 设计规范，路由前缀为 `/api/v1/{database}/{table}` |

### 1.4 参考文档
本项目参考以下 spec-kit 工程文档（位于 `D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\specs\004-agent-skill-runtime`）：

| 文档 | 说明 |
|------|------|
| `uctoo-v4-upgrade.md` | uctoo V4.0 升级方案，包含架构设计和实现方案 |
| `contracts/api-contract.yaml` | API 契约定义，包含接口规范和数据结构 |
| `spec.md` | 原始需求规格文档 |
| `tasks.md` | 原始任务规划文档 |
| `data-model.md` | 数据模型设计文档 |

## 2. 系统需求

### 2.1 功能需求

#### 2.1.1 HTTP 服务器功能

##### REQ-SRV-001: HTTP 服务器启动与停止
**需求描述**: 系统应提供 HTTP 服务器的启动和停止功能。

**验收标准**:
- [ ] 服务器能够成功启动并监听指定端口
- [ ] 服务器能够优雅停止，释放所有资源
- [ ] 启动时显示服务状态和可用端点信息
- [ ] 支持通过配置文件指定监听地址和端口

**优先级**: P0

##### REQ-SRV-002: 路由分发功能
**需求描述**: 系统应支持动态路由分发，包括静态路由和参数化路由。

**验收标准**:
- [ ] 支持静态路由匹配（如 `/api/v1/health`）
- [ ] 支持参数化路由匹配（如 `/api/v1/skills/:id`）
- [ ] 未匹配路由返回 404 错误
- [ ] 路由注册顺序影响匹配优先级

**优先级**: P0

##### REQ-SRV-003: 中间件机制
**需求描述**: 系统应支持中间件链式处理请求。

**验收标准**:
- [ ] 支持全局中间件
- [ ] 支持路由组级别中间件
- [ ] 中间件能够中断请求处理链
- [ ] 中间件能够修改请求和响应

**优先级**: P0

#### 2.1.2 技能管理 API

##### REQ-SKILL-001: 获取技能列表
**需求描述**: 当客户端请求技能列表时，系统应返回分页的技能数据。

**验收标准**:
- [ ] 支持 page 和 limit 参数进行分页
- [ ] 返回当前页、总数量、总页数等分页信息
- [ ] 返回技能的基本信息（id, name, description, version 等）
- [ ] limit 参数最大值为 100

**优先级**: P0

##### REQ-SKILL-002: 获取单个技能详情
**需求描述**: 当客户端请求指定 ID 的技能时，系统应返回该技能的详细信息。

**验收标准**:
- [ ] 通过路径参数获取技能 ID
- [ ] 返回技能的完整信息
- [ ] 技能不存在时返回 404 错误
- [ ] 包含技能的工具列表

**优先级**: P0

##### REQ-SKILL-003: 安装技能
**需求描述**: 当客户端提交技能安装请求时，系统应从本地路径或 Git 仓库安装技能。

**验收标准**:
- [ ] 支持从本地路径安装技能
- [ ] 支持从 Git 仓库 URL 安装技能
- [ ] 支持 branch、tag、commit 参数指定 Git 引用
- [ ] 支持 skill_subpath 参数安装多技能仓库中的特定技能
- [ ] 安装成功后自动重新加载技能
- [ ] 返回安装结果和技能信息
- [ ] Git 不可用时返回明确错误信息

**优先级**: P0

##### REQ-SKILL-004: 更新技能
**需求描述**: 当客户端提交技能更新请求时，系统应更新指定技能的信息。

**验收标准**:
- [ ] 通过请求体中的 id 字段指定技能
- [ ] 支持更新 description、creator、name、version 等字段
- [ ] 更新成功后自动重新加载技能
- [ ] 返回更新结果

**优先级**: P1

##### REQ-SKILL-005: 卸载技能
**需求描述**: 当客户端提交技能卸载请求时，系统应卸载指定技能。

**验收标准**:
- [ ] 通过请求体中的 id 字段指定技能
- [ ] 卸载成功后自动重新加载技能列表
- [ ] 返回卸载结果
- [ ] 技能不存在时返回错误

**优先级**: P1

##### REQ-SKILL-006: 执行技能
**需求描述**: 当客户端提交技能执行请求时，系统应执行指定技能并返回结果。

**验收标准**:
- [ ] 通过 skill_id 字段指定要执行的技能
- [ ] 支持 params 字段传递执行参数
- [ ] 支持 timeout 字段设置超时时间
- [ ] 返回执行结果、执行时间、资源使用情况
- [ ] 技能不存在时返回 404 错误

**优先级**: P1

##### REQ-SKILL-007: 搜索技能
**需求描述**: 当客户端提交技能搜索请求时，系统应从公共仓库搜索技能。

**验收标准**:
- [ ] 支持 query 参数指定搜索关键词
- [ ] 支持 source 参数指定搜索源（github、atomgit、gitee、all）
- [ ] 支持 limit 参数限制返回数量（最大 50）
- [ ] 支持 sort 参数指定排序方式（stars、updated、forks）
- [ ] 返回搜索结果列表

**优先级**: P1

#### 2.1.3 WebSocket 聊天功能

##### REQ-WS-001: WebSocket 连接处理
**需求描述**: 系统应支持 WebSocket 连接，用于实时聊天交互。

**验收标准**:
- [ ] 支持 WebSocket 握手协议
- [ ] 支持消息的发送和接收
- [ ] 支持连接的建立和关闭
- [ ] 处理异常断开情况

**优先级**: P1

##### REQ-WS-002: 聊天消息处理
**需求描述**: 当 WebSocket 连接建立后，系统应处理聊天消息并返回 AI 响应。

**验收标准**:
- [ ] 接收用户消息
- [ ] 调用 AI 模型生成响应
- [ ] 支持技能调用
- [ ] 返回 AI 响应消息

**优先级**: P1

#### 2.1.4 agent_skills 表 CRUD 功能

##### REQ-AS-001: 创建技能记录
**需求描述**: 当客户端提交创建技能记录请求时，系统应在 agent_skills 表中创建新记录。

**验收标准**:
- [ ] 接收 JSON 格式的技能数据
- [ ] 自动生成 UUID 作为主键
- [ ] 自动设置 created_at 和 updated_at 时间戳
- [ ] 验证必填字段（name）
- [ ] 返回创建的记录

**优先级**: P0

##### REQ-AS-002: 更新技能记录
**需求描述**: 当客户端提交更新技能记录请求时，系统应更新 agent_skills 表中的指定记录。

**验收标准**:
- [ ] 通过 id 字段指定要更新的记录
- [ ] 只更新请求中提供的字段
- [ ] 自动更新 updated_at 时间戳
- [ ] 记录不存在时返回 404 错误
- [ ] 返回更新后的记录

**优先级**: P0

##### REQ-AS-003: 删除技能记录
**需求描述**: 当客户端提交删除技能记录请求时，系统应删除 agent_skills 表中的指定记录。

**验收标准**:
- [ ] 通过 id 字段指定要删除的记录
- [ ] 默认执行软删除（设置 deleted_at）
- [ ] 支持 force 参数执行物理删除
- [ ] 记录不存在时返回 404 错误
- [ ] 返回删除结果

**优先级**: P0

##### REQ-AS-004: 查询单个技能记录
**需求描述**: 当客户端请求单个技能记录时，系统应返回 agent_skills 表中的指定记录。

**验收标准**:
- [ ] 通过路径参数获取记录 ID
- [ ] 返回完整的记录信息
- [ ] 默认不返回已软删除的记录
- [ ] 记录不存在时返回 404 错误

**优先级**: P0

##### REQ-AS-005: 查询技能记录列表
**需求描述**: 当客户端请求技能记录列表时，系统应返回分页的记录数据。

**验收标准**:
- [ ] 支持 page 和 limit 参数进行分页
- [ ] 返回当前页、总数量、总页数等分页信息
- [ ] 默认不返回已软删除的记录
- [ ] 支持按条件筛选记录

**优先级**: P0

#### 2.1.5 健康检查与系统信息

##### REQ-SYS-001: 健康检查接口
**需求描述**: 系统应提供健康检查接口，用于监控服务状态。

**验收标准**:
- [ ] 返回服务状态（ok/error）
- [ ] 返回服务版本号
- [ ] 响应时间小于 100ms
- [ ] 不需要认证

**优先级**: P0

##### REQ-SYS-002: 系统信息接口
**需求描述**: 系统应提供系统信息接口，返回服务基本信息。

**验收标准**:
- [ ] 返回服务名称
- [ ] 返回服务版本
- [ ] 返回编程语言信息
- [ ] 不需要认证

**优先级**: P1

### 2.2 非功能需求

#### 2.2.1 性能需求
- API 响应时间应小于 500ms（不含 AI 调用）
- 支持至少 100 个并发连接
- WebSocket 连接应保持稳定，支持长连接

#### 2.2.2 安全需求
- 敏感操作需要认证
- 输入数据必须验证
- 防止 SQL 注入攻击
- 错误信息不应暴露系统内部细节

#### 2.2.3 可用性需求
- API 返回统一的错误格式
- 提供清晰的错误码和错误消息
- 日志记录关键操作和错误

### 2.3 约束性需求

#### 2.3.1 技术约束
- 编程语言：仓颉 (Cangjie)
- HTTP 服务器：基于仓颉标准库
- ORM 框架：fountain ORM
- 数据库：PostgreSQL

#### 2.3.2 架构约束
- 必须遵循 uctoo V4.0 三层架构
- 必须与 backend 项目架构保持一致
- 代码必须放在定制开发区域（非自动生成区域）

#### 2.3.3 兼容性约束
- API 路径必须符合 uctoo API 规范
- 不与模块标准 CRUD 接口冲突
- 保持与现有客户端的兼容性

## 3. 接口需求

### 3.1 用户接口

#### API 路由重构说明
根据 uctoo API 规范，原 api 模块的接口将重构到 `/api/v1/uctoo/` 路由前缀下：
- **健康检查接口** `/hello` 保持不变
- **技能管理接口** 从 `/skills/*` 重构到 `/api/v1/uctoo/skills/*`
- **WebSocket 接口** 从 `/ws/chat` 重构到 `/api/v1/uctoo/ws/chat`
- **MCP 接口** 从 `/mcp/stream` 重构到 `/api/v1/uctoo/mcp/stream`

#### API 端点列表

| 方法 | 原路径 | 新路径 | 描述 | 认证 |
|------|--------|--------|------|------|
| GET | /hello | /hello | 健康检查（保持不变） | 否 |
| GET | /skills | /api/v1/uctoo/skills | 获取技能列表 | 否 |
| GET | /skills/:id | /api/v1/uctoo/skills/:id | 获取技能详情 | 否 |
| POST | /skills/add | /api/v1/uctoo/skills/add | 安装技能 | 否 |
| POST | /skills/edit | /api/v1/uctoo/skills/edit | 更新技能 | 否 |
| POST | /skills/del | /api/v1/uctoo/skills/del | 卸载技能 | 否 |
| POST | /skills/execute | /api/v1/uctoo/skills/execute | 执行技能 | 否 |
| POST | /skills/search | /api/v1/uctoo/skills/search | 搜索技能 | 否 |
| GET | /mcp/stream | /api/v1/uctoo/mcp/stream | MCP 流式接口 | 否 |
| WS | /ws/chat | /api/v1/uctoo/ws/chat | WebSocket 聊天 | 否 |
| GET | - | /api/v1/health | uctoo 健康检查 | 否 |
| GET | - | /api/v1/info | uctoo 系统信息 | 否 |
| POST | - | /api/v1/uctoo/agent_skills/add | 创建技能记录 | 是 |
| POST | - | /api/v1/uctoo/agent_skills/edit | 更新技能记录 | 是 |
| POST | - | /api/v1/uctoo/agent_skills/del | 删除技能记录 | 是 |
| GET | - | /api/v1/uctoo/agent_skills/:id | 查询单个技能记录 | 否 |
| GET | - | /api/v1/uctoo/agent_skills | 查询技能记录列表 | 否 |

#### 路由分组设计
```
/api/v1/
├── health                          # 系统健康检查
├── info                            # 系统信息
└── uctoo/                          # uctoo 数据库模块
    ├── skills/                     # 技能管理（原 api 模块功能）
    │   ├── GET    /                # 获取技能列表
    │   ├── GET    /:id             # 获取技能详情
    │   ├── POST   /add             # 安装技能
    │   ├── POST   /edit            # 更新技能
    │   ├── POST   /del             # 卸载技能
    │   ├── POST   /execute         # 执行技能
    │   └── POST   /search          # 搜索技能
    ├── agent_skills/               # agent_skills 表 CRUD
    │   ├── GET    /                # 查询列表
    │   ├── GET    /:id             # 查询单个
    │   ├── POST   /add             # 创建记录
    │   ├── POST   /edit            # 更新记录
    │   └── POST   /del             # 删除记录
    ├── mcp/                        # MCP 相关
    │   └── GET    /stream          # MCP 流式接口
    └── ws/                         # WebSocket 相关
        └── WS     /chat            # WebSocket 聊天
```

### 3.2 系统接口
- 数据库连接：PostgreSQL
- AI 模型接口：通过 ModelManager 调用
- Git 操作：通过 GitManager 调用

### 3.3 数据接口
- JSON 格式的请求和响应
- WebSocket 消息格式

## 4. 数据需求

### 4.1 数据模型

#### agent_skills 表结构
| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| id | UUID | 是 | 主键 |
| name | String | 是 | 技能名称 |
| description | String | 否 | 技能描述 |
| source | String | 否 | 来源类型 |
| source_url | String | 否 | 来源 URL |
| source_type | String | 否 | 来源类型 |
| branch | String | 否 | Git 分支 |
| tag | String | 否 | Git 标签 |
| commit | String | 否 | Git 提交 |
| version | String | 否 | 版本号 |
| author | String | 否 | 作者 |
| homepage | String | 否 | 主页 |
| license | String | 否 | 许可证 |
| keywords | String | 否 | 关键词 |
| tags | String | 否 | 标签 |
| categories | String | 否 | 分类 |
| install_path | String | 否 | 安装路径 |
| compatibility | String | 否 | 兼容性 |
| allowed_tools | String | 否 | 允许的工具 |
| dependencies | String | 否 | 依赖 |
| permissions | String | 否 | 权限 |
| parameters | String | 否 | 参数 |
| instructions | String | 否 | 指令 |
| scripts_dir_exists | Int | 否 | 脚本目录存在标志 |
| references_dir_exists | Int | 否 | 参考目录存在标志 |
| assets_dir_exists | Int | 否 | 资源目录存在标志 |
| status | Int | 否 | 状态 |
| runtime_status | String | 否 | 运行时状态 |
| validation_status | String | 否 | 验证状态 |
| validation_errors | String | 否 | 验证错误 |
| last_validated_at | DateTime | 否 | 最后验证时间 |
| config | String | 否 | 配置 |
| env_vars | String | 否 | 环境变量 |
| timeout | Int | 否 | 超时时间 |
| retry_count | Int | 否 | 重试次数 |
| run_count | Int | 否 | 运行次数 |
| success_count | Int | 否 | 成功次数 |
| error_count | Int | 否 | 错误次数 |
| last_run_at | DateTime | 否 | 最后运行时间 |
| last_error | String | 否 | 最后错误 |
| avg_execution_time | Int | 否 | 平均执行时间 |
| generation_prompt | String | 否 | 生成提示 |
| generation_model | String | 否 | 生成模型 |
| generation_status | String | 否 | 生成状态 |
| parent_skill_id | UUID | 否 | 父技能 ID |
| extra_metadata | String | 否 | 额外元数据 |
| creator | UUID | 否 | 创建者 |
| created_at | DateTime | 是 | 创建时间 |
| updated_at | DateTime | 是 | 更新时间 |
| deleted_at | DateTime | 否 | 删除时间 |

### 4.2 数据存储
- 数据库：PostgreSQL
- 连接池：DatabaseConnectionPool
- 事务支持：是

### 4.3 数据迁移
- 本次重构不涉及数据库表结构变更
- 使用现有的 agent_skills 表

## 5. 验收标准

### 5.1 功能验收
- [ ] 所有 API 端点正常工作
- [ ] WebSocket 连接正常
- [ ] 技能管理功能完整
- [ ] agent_skills 表 CRUD 功能完整
- [ ] 健康检查接口正常

### 5.2 性能验收
- [ ] API 响应时间符合要求
- [ ] 并发处理能力符合要求
- [ ] 内存使用合理

### 5.3 安全验收
- [ ] 认证机制正常工作
- [ ] 输入验证完整
- [ ] 无 SQL 注入漏洞

## 6. 附录

### 6.1 参考文档

#### 项目文档
- [uctoo V4.0 子系统架构说明](../../../docs/uctoo-v4/uctoo-v4-architecture.md)
- [uctoo V4.0 模块开发指南](../../../docs/uctoo-v4/uctoo-v4-module-development.md)
- [backend 项目 agent_skills 模块](../../../backend/src/app/services/uctoo/agent_skills.ts)

#### spec-kit 工程文档
位于 `D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\specs\004-agent-skill-runtime`：
- `uctoo-v4-upgrade.md` - uctoo V4.0 升级方案，包含架构设计和实现方案
- `contracts/api-contract.yaml` - API 契约定义，包含接口规范和数据结构
- `spec.md` - 原始需求规格文档
- `tasks.md` - 原始任务规划文档
- `data-model.md` - 数据模型设计文档
- `skill_execution_design.md` - 技能执行设计文档
- `builtin-tools-analysis.md` - 内置工具分析文档

### 6.2 变更历史
| 版本 | 日期 | 作者 | 变更说明 |
|------|------|------|----------|
| 1.0  | 2026-03-13 | SDD Agent | 初始版本 |
| 1.1  | 2026-03-13 | SDD Agent | 添加 spec-kit 参考文档；明确 API 路由重构到 `/api/v1/uctoo/` 前缀 |
