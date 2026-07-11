# 需求规格文档：Agent 动态生成与多 Agent 协作系统

## 文档信息
- **项目名称**: Agent 动态生成与多 Agent 协作系统 (Dynamic Agent Generation & Multi-Agent Collaboration System)
- **版本**: 1.0
- **创建日期**: 2026-05-29
- **作者**: SDD Agent
- **状态**: 草稿

---

## 1. 概述

### 1.1 项目背景

参考 claude-code-rev 项目的 agent 运行机制，本项目需要在 `agentskills-runtime` 中实现：
1. 从 `AGENTS.md` 声明文件动态生成主 Agent
2. 支持通过命令行工具和 API 动态生成 SubAgent
3. 实现 Agent 间的独立上下文管理和生命周期管理
4. 集成现有的用户权限体系
5. 设计 Agent 协作系统

### 1.2 项目范围

**包含内容**：
- AGENTS.md 文件格式定义与解析
- 主 Agent 动态加载机制
- SubAgent 命令行工具与 API 接口
- Agent 独立上下文管理
- Agent 生命周期管理
- 数据库模型设计 (agents 表)
- 权限系统集成
- Agent 协作系统设计

**不包含内容**：
- 前端界面开发
- 大模型 API 调用实现
- 现有技能系统改造

### 1.3 术语定义

| 术语 | 定义 |
|------|------|
| Agent | 具备独立身份、上下文和生命周期的 AI 实体 |
| SubAgent | 由主 Agent 或其他 Agent 派生的子 Agent，具备独立运行能力 |
| AGENTS.md | 主 Agent 声明文件，定义 Agent 的元数据和行为 |
| Agent Definition | Agent 的定义描述，包含名称、描述、工具、系统提示等 |
| Context Isolation | 每个 Agent 拥有独立的对话上下文和运行资源 |
| Agent Collaboration | 多个 Agent 之间的任务分配、消息传递和协作机制 |

---

## 2. 系统需求

### 2.1 功能需求

#### 2.1.1 AGENTS.md 文件支持

##### REQ-AGENTS-MD-001: AGENTS.md 格式定义
**需求描述**: 定义 AGENTS.md 文件格式，支持 YAML frontmatter + Markdown 内容结构。

**验收标准**:
- [ ] 支持 YAML frontmatter 定义 Agent 元数据（name, description, tools, model 等）
- [ ] Markdown 内容作为 Agent 的系统提示词
- [ ] 支持多种 Agent 定义在同一文件中

**优先级**: P0

##### REQ-AGENTS-MD-002: AGENTS.md 加载机制
**需求描述**: 系统启动时自动加载根目录的 AGENTS.md 文件生成主 Agent。

**验收标准**:
- [ ] 应用启动时扫描根目录 AGENTS.md 文件
- [ ] 解析 YAML frontmatter 提取 Agent 元数据
- [ ] 将 Markdown 内容作为系统提示词
- [ ] 生成可用的主 Agent 实例

**优先级**: P0

#### 2.1.2 SubAgent 动态生成

##### REQ-SUBAGENT-001: 命令行工具生成 SubAgent
**需求描述**: 提供命令行工具支持从声明文件或内容生成 SubAgent。

**验收标准**:
- [ ] 支持 `skill agent create --file <path>` 从文件创建
- [ ] 支持 `skill agent create --content <json>` 从内容创建
- [ ] 返回创建的 Agent ID 和状态
- [ ] 支持指定 Agent 类型（analyzer/comparator/grader 等）

**优先级**: P0

##### REQ-SUBAGENT-002: API 接口生成 SubAgent
**需求描述**: 提供 REST API 接口支持动态生成 SubAgent。

**验收标准**:
- [ ] POST /api/v1/uctoo/agent/create - 创建 Agent
- [ ] 支持通过文件路径或内容创建
- [ ] 返回 Agent ID 和详细信息
- [ ] 支持批量创建

**优先级**: P0

##### REQ-SUBAGENT-003: SubAgent 声明文件格式
**需求描述**: 支持从 analyzer.md、comparator.md、grader.md 等声明文件生成 SubAgent。

**验收标准**:
- [ ] 解析 YAML frontmatter 中的 role、inputs、output 字段
- [ ] 支持定义 Agent 的职责和工作流程
- [ ] Markdown 内容作为系统提示词

**优先级**: P0

#### 2.1.3 Agent 上下文与生命周期管理

##### REQ-CONTEXT-001: 独立上下文管理
**需求描述**: 每个 Agent/SubAgent 拥有独立的对话上下文。

**验收标准**:
- [ ] 每个 Agent 有独立的消息历史存储
- [ ] 上下文隔离，互不干扰
- [ ] 支持上下文持久化和恢复

**优先级**: P0

##### REQ-LIFECYCLE-001: Agent 生命周期管理
**需求描述**: 实现 Agent 的创建、启动、暂停、销毁生命周期。

**验收标准**:
- [ ] 创建：从声明文件初始化 Agent 实例
- [ ] 启动：加载上下文，准备接收消息
- [ ] 暂停：暂停消息处理，保留上下文
- [ ] 销毁：清理资源，可选保留历史

**优先级**: P0

##### REQ-RESOURCE-001: 资源隔离
**需求描述**: 每个 Agent 拥有独立的运行资源。

**验收标准**:
- [ ] 独立的内存空间
- [ ] 独立的工具调用权限
- [ ] 独立的 API 调用配额

**优先级**: P1

#### 2.1.4 数据库模型

##### REQ-DB-001: agents 表设计
**需求描述**: 在 uctooDB.sql 中添加 agents 表，包含完备的 Agent 属性。

**验收标准**:
- [ ] 包含 Agent ID、名称、类型、状态等基本字段
- [ ] 包含配置、系统提示、工具列表等业务字段
- [ ] 包含创建时间、更新时间等审计字段

**优先级**: P0

##### REQ-DB-002: CRUD 模块生成
**需求描述**: 使用 crudgen 工具生成 agents 表的标准 CRUD 模块。

**验收标准**:
- [ ] 生成 AgentPO 持久化对象
- [ ] 生成 AgentDAO 数据访问对象
- [ ] 生成 AgentService 业务服务
- [ ] 生成 AgentController 控制器

**优先级**: P0

#### 2.1.5 权限系统集成

##### REQ-PERMISSION-001: Agent 用户组管理
**需求描述**: 将 Agent 纳入现有用户权限体系，创建 agents 和 subagents 用户组。

**验收标准**:
- [ ] 创建 agents 用户组
- [ ] 创建 subagents 用户组
- [ ] 每个 Agent 分配独立账号
- [ ] Agent 账号自动加入对应用户组

**优先级**: P0

##### REQ-PERMISSION-002: 精细权限控制
**需求描述**: 支持对 Agent 进行精细的权限管理。

**验收标准**:
- [ ] 支持为用户组分配权限
- [ ] 支持为单个 Agent 分配权限
- [ ] 支持基于角色的访问控制

**优先级**: P1

#### 2.1.6 Agent 协作系统

##### REQ-COLLAB-001: 任务分配机制
**需求描述**: 实现 Agent 之间的任务分配机制。

**验收标准**:
- [ ] 支持主 Agent 向 SubAgent 分配任务
- [ ] 支持任务优先级设置
- [ ] 支持任务状态追踪

**优先级**: P0

##### REQ-COLLAB-002: 消息传递机制
**需求描述**: 实现 Agent 之间的消息传递。

**验收标准**:
- [ ] 支持同步消息传递
- [ ] 支持异步消息传递
- [ ] 支持消息持久化

**优先级**: P0

##### REQ-COLLAB-003: 协作模式支持
**需求描述**: 支持多种协作模式。

**验收标准**:
- [ ] 支持链式协作（顺序执行）
- [ ] 支持并行协作（同时执行）
- [ ] 支持分层协作（层级管理）

**优先级**: P1

### 2.2 非功能需求

#### 2.2.1 性能需求
- Agent 创建时间 < 500ms
- Agent 消息响应时间 < 1s
- 支持并发运行 100+ 个 Agent

#### 2.2.2 可靠性需求
- Agent 崩溃不影响其他 Agent
- 上下文持久化保证数据不丢失
- 支持 Agent 故障恢复

#### 2.2.3 可维护性需求
- Agent 定义格式清晰易读
- 提供详细的日志记录
- 支持 Agent 配置热更新

### 2.3 约束性需求
- 使用仓颉语言实现
- 使用 PostgreSQL 作为数据库
- 遵循现有的 API 规范（/api/v1/uctoo/...）
- 复用现有的用户权限体系

---

## 3. 接口需求

### 3.1 命令行接口

| 命令 | 说明 | 选项 |
|------|------|------|
| `skill agent create` | 创建 Agent | `--file`, `--content`, `--type` |
| `skill agent list` | 列出所有 Agent | `--status`, `--type` |
| `skill agent show <id>` | 显示 Agent 详情 | - |
| `skill agent start <id>` | 启动 Agent | - |
| `skill agent stop <id>` | 停止 Agent | - |
| `skill agent delete <id>` | 删除 Agent | `-f` |
| `skill agent update <id>` | 更新 Agent | `--file`, `--content` |

### 3.2 HTTP API 接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| POST | `/api/v1/uctoo/agent/create` | 创建 Agent | agent:write |
| GET | `/api/v1/uctoo/agent/list` | 列出 Agent | agent:read |
| GET | `/api/v1/uctoo/agent/:id` | 获取 Agent 详情 | agent:read |
| PUT | `/api/v1/uctoo/agent/:id` | 更新 Agent | agent:write |
| DELETE | `/api/v1/uctoo/agent/:id` | 删除 Agent | agent:write |
| POST | `/api/v1/uctoo/agent/:id/start` | 启动 Agent | agent:write |
| POST | `/api/v1/uctoo/agent/:id/stop` | 停止 Agent | agent:write |
| POST | `/api/v1/uctoo/agent/:id/task` | 分配任务 | agent:write |

### 3.3 内部接口

| 接口 | 说明 |
|------|------|
| AgentLoader | 加载 AGENTS.md 文件 |
| AgentFactory | 创建 Agent 实例 |
| AgentContextManager | 管理 Agent 上下文 |
| AgentLifecycleManager | 管理 Agent 生命周期 |
| AgentCollaborationService | Agent 协作服务 |

---

## 4. 数据需求

### 4.1 数据模型

#### 4.1.1 agents 表

| 字段 | 类型 | 说明 | 约束 |
|------|------|------|------|
| id | UUID | 主键 | PRIMARY KEY |
| name | VARCHAR(100) | Agent 名称 | NOT NULL |
| type | VARCHAR(50) | Agent 类型 | NOT NULL |
| description | TEXT | Agent 描述 | - |
| status | INT4 | 状态 (0:停用, 1:运行, 2:暂停) | DEFAULT 0 |
| config | JSON | 配置信息 | - |
| system_prompt | TEXT | 系统提示词 | - |
| tools | JSON | 工具列表 | - |
| model | VARCHAR(50) | 模型名称 | - |
| parent_id | UUID | 父 Agent ID | FOREIGN KEY |
| user_id | UUID | 关联用户 ID | FOREIGN KEY |
| created_at | TIMESTAMPTZ | 创建时间 | DEFAULT NOW() |
| updated_at | TIMESTAMPTZ | 更新时间 | DEFAULT NOW() |
| deleted_at | TIMESTAMPTZ | 删除时间 | - |

#### 4.1.2 agent_contexts 表（上下文存储）

| 字段 | 类型 | 说明 | 约束 |
|------|------|------|------|
| id | UUID | 主键 | PRIMARY KEY |
| agent_id | UUID | 关联 Agent ID | FOREIGN KEY |
| messages | JSON | 消息历史 | - |
| metadata | JSON | 元数据 | - |
| created_at | TIMESTAMPTZ | 创建时间 | DEFAULT NOW() |
| updated_at | TIMESTAMPTZ | 更新时间 | DEFAULT NOW() |

#### 4.1.3 agent_tasks 表（任务管理）

| 字段 | 类型 | 说明 | 约束 |
|------|------|------|------|
| id | UUID | 主键 | PRIMARY KEY |
| agent_id | UUID | 关联 Agent ID | FOREIGN KEY |
| parent_task_id | UUID | 父任务 ID | FOREIGN KEY |
| status | INT4 | 状态 (0:待处理, 1:进行中, 2:完成, 3:失败) | DEFAULT 0 |
| priority | INT4 | 优先级 (1-5) | DEFAULT 3 |
| payload | JSON | 任务内容 | - |
| result | JSON | 任务结果 | - |
| created_at | TIMESTAMPTZ | 创建时间 | DEFAULT NOW() |
| updated_at | TIMESTAMPTZ | 更新时间 | DEFAULT NOW() |
| completed_at | TIMESTAMPTZ | 完成时间 | - |

### 4.2 数据迁移
- 初始化 agents 表
- 初始化 agent_contexts 表
- 初始化 agent_tasks 表
- 创建必要的索引

---

## 5. 验收标准

### 5.1 功能验收
- [ ] AGENTS.md 文件正确解析并生成主 Agent
- [ ] 命令行工具成功创建 SubAgent
- [ ] API 接口成功创建和管理 Agent
- [ ] 每个 Agent 拥有独立的上下文
- [ ] Agent 生命周期管理正常工作
- [ ] 数据库 CRUD 模块正常运行
- [ ] Agent 正确集成到权限系统
- [ ] Agent 协作系统正常工作

### 5.2 性能验收
- [ ] Agent 创建时间 < 500ms
- [ ] Agent 消息响应时间 < 1s
- [ ] 支持并发运行 100+ 个 Agent

### 5.3 可靠性验收
- [ ] Agent 崩溃不影响其他 Agent
- [ ] 上下文持久化正常
- [ ] Agent 故障恢复正常

---

## 6. 附录

### 6.1 参考文档
- claude-code-rev AGENTS.md: `apps/claude-code-rev/AGENTS.md`
- claude-code-rev loadAgentsDir.ts: `apps/claude-code-rev/src/tools/AgentTool/loadAgentsDir.ts`
- claude-code-rev forkSubagent.ts: `apps/claude-code-rev/src/tools/AgentTool/forkSubagent.ts`
- skill-creator agents: `skills/skill-creator/agents/`

### 6.2 变更历史
| 版本 | 日期 | 作者 | 变更说明 |
|------|------|------|----------|
| 1.0  | 2026-05-29 | SDD Agent | 初始版本 |