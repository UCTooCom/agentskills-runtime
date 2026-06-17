# AIAgent 框架与 App 层有机融合需求规格

## 项目背景

agentskills-runtime 项目由两部分组成：
1. **CangjieMagic 框架**（`src/agent/`、`src/agent_executor/`、`src/agent_group/`、`src/memory/`、`src/model/`、`src/skill/`、`src/tool/`、`src/interaction/` 等）：原 cangjiemagic 开源项目的 AI Agent 框架，提供 Agent 创建、多策略执行、多 Agent 协作、记忆、工具、技能、交互事件等能力
2. **UCToo V4 App 层**（`src/app/`）：从 uctoo v3 重写的服务端应用，提供 PostgreSQL 数据库、规范化 CRUD 模块、高性能 Web 服务器、标准 API、CLI、权限系统、同步系统、定时任务等能力

当前两套系统**并行存在但缺乏有机融合**：CangjieMagic 的 Agent 在内存中创建和执行，App 层的 agents 表仅存储 Agent 元数据，两者之间没有运行时桥接。融合后可以：
- 让 CangjieMagic Agent 的运行时状态通过 App 层持久化和可视化管理
- 让 App 层的 Agent CRUD 操作驱动 CangjieMagic Agent 的创建和配置
- 复用已有基础设施覆盖部分"新建 5 个完善建议 specs"的能力
- 增强 CangjieMagic 框架的数据库支撑和人机协作能力

## 现有能力对照分析

### CangjieMagic 已有能力 → 可覆盖的 spec 需求

| CangjieMagic 能力 | 详细说明 | 可覆盖的 spec |
|-------------------|---------|-------------|
| **AgentGroup 多 Agent 协作** | LeaderGroup（领导者调度）、LinearGroup（线性管道）、FreeGroup（自由讨论）、AutoDiscussGroup、RoundRobinDiscussGroup | **agent-orchestration** 的 DAG 调度部分能力（串行、并行、领导者模式已有实现） |
| **PlanReactExecutor** | 先规划（问题分解）再分步执行（ReactWorker），最后结果汇总 | **agent-orchestration** 的执行计划定义部分能力（plan-react 已实现分解-执行-汇总） |
| **ShortMemory + InMemoryVectorDB** | 基于内存向量数据库的语义记忆存储和检索 | **agent-memory-persistence** 的语义检索能力（向量搜索已实现，缺持久化） |
| **AgentWorkspace + MemoryService** | Agent 工作空间管理，记忆文件合并 | **agent-memory-persistence** 的记忆文件管理部分能力 |
| **EventHandlerManager + EventStream** | 12 种事件类型（AgentStart/End/Step、ToolCallStart/End/Repeat、ChatModelStart/End/Failure、SubAgentStart/End、AgentTimeout、UserInput、Notify） | **long-running-task** 的实时进度通知能力（事件流已实现，缺 WebSocket 推送） |
| **Interceptor 拦截器** | Always/Periodic/Conditional 三种拦截模式 | **agent-error-recovery** 的熔断器部分能力（条件拦截可模拟半开状态） |
| **Conversation + ConversationCompactor** | 对话管理及自动压缩 | **long-running-task** 的上下文压缩能力 |
| **BoundedMessageList** | 有界消息列表，防止上下文溢出 | **long-running-task** 的资源限制能力 |
| **SkillToToolAdapter** | 技能适配为工具，技能可作为工具调用 | **skill-composition-engine** 的技能间组合部分能力（技能已可作为工具链式调用） |
| **AgentAsTool / SubAgentTool** | Agent 包装为工具，子 Agent 调用 | **skill-composition-engine** 的技能+Agent 混合编排能力 |
| **HumanAgent** | 人工 Agent，问题转给人类回答 | **人机协作能力**（HITL 已有基础实现） |
| **ToolDispatcher** | 工具调度器，支持 CLI/HTTP/Internal 三种调用 | **skill-composition-engine** 的多入口执行能力 |

### App 层已有能力 → 可覆盖的 spec 需求

| App 层能力 | 详细说明 | 可覆盖的 spec |
|-----------|---------|-------------|
| **agents/agent_contexts/agent_tasks/agent_messages CRUD** | 完整的 Agent 元数据、上下文、任务、消息持久化 | **agent-memory-persistence** 的持久化存储、**long-running-task** 的任务持久化 |
| **SyncManager 双向同步** | AGENTS.md ↔ 数据库自动同步 | **agent-orchestration** 的执行计划持久化（复用同步机制） |
| **SchedulerEngine + CrontabService** | 基于 Ticktock 的 CRON 调度，支持触发/暂停/恢复/重载，含超时、重试、并发控制、日志 | **long-running-task** 的大部分能力（暂停/恢复/取消、超时/重试、任务队列、并发限制） |
| **RetryManager** | 指数退避重试（同步系统） | **agent-error-recovery** 的重试策略能力 |
| **PermissionMiddleware + DataAccessAuthorization** | JWT 认证 + RBAC 权限 + 行级数据权限 | **agent-orchestration** 的资源仲裁部分能力（权限控制已有） |
| **OperateLogMiddleware** | 操作审计日志 | **agent-error-recovery** 的审计日志能力 |
| **WebSocket 路由** | `/api/v1/uctoo/ws/chat` | **long-running-task** 的实时通知通道 |
| **QueryBuilderService + RequestParserService** | Prisma 风格动态查询引擎 | **agent-orchestration** 的执行计划查询能力 |

### 能力缺口总结

| spec 需求 | 已有覆盖 | 仍需新建 |
|----------|---------|---------|
| **agent-orchestration** | AgentGroup(协作模式)、PlanReactExecutor(分解执行)、SyncManager(持久化)、PermissionMiddleware(权限) | DAG 调度引擎、动态重编排、结果聚合框架、执行回滚 |
| **long-running-task** | SchedulerEngine(暂停/恢复/超时/重试/并发)、AgentTasks(持久化)、EventStream(事件)、WebSocket(通道) | 检查点机制、子任务树、优先级队列、SSE 通知 |
| **agent-memory-persistence** | ShortMemory(语义检索)、AgentContexts(持久化)、AgentWorkspace(文件管理) | 记忆分层、跨会话记忆、Agent 间共享、记忆衰减、向量嵌入持久化 |
| **agent-error-recovery** | RetryManager(重试)、Interceptor(拦截)、OperateLog(审计) | 错误分类、降级执行、错误传播控制、自愈诊断、熔断器、补偿事务 |
| **skill-composition-engine** | SkillToToolAdapter(技能→工具)、AgentAsTool(Agent→工具)、ToolDispatcher(调度) | 组合 DSL、技能间数据传递、依赖解析、组合模板、组合验证 |

## 核心融合需求

### FUSION-001: Agent 运行时桥接

**问题**: CangjieMagic 的 Agent（BaseAgent 等）在内存中创建，App 层的 AgentsPO 仅存元数据，两者无运行时关联。

**融合方案**:
1. 创建 `AgentRuntimeBridge` 桥接层：
   - `createRuntimeAgent(definition: AgentDefinition): BaseAgent` - 从 AgentDefinition（App 层加载）创建 CangjieMagic BaseAgent
   - `syncToDatabase(agent: BaseAgent): AgentsPO` - 将运行时 Agent 状态同步到数据库
   - `loadFromDatabase(agentId: String): BaseAgent` - 从数据库加载 Agent 并重建运行时实例
   - `updateRuntimeState(agentId: String, state: AgentState): Unit` - 更新运行时状态到数据库
2. AgentDefinition 的字段与 AgentsPO 的字段建立映射：
   - `name` ↔ `name`
   - `agentType` ↔ `agentType`
   - `model` ↔ `model`
   - `tools` ↔ `tools`
   - `systemPrompt` ↔ `systemPrompt`
   - `maxTurns` ↔ `maxTurns`
   - `memory` ↔ `memoryScope`
   - `background` ↔ `background`
   - `permissions` → 权限系统
3. Agent 执行时自动更新 AgentsPO 的 status 字段

### FUSION-002: AgentGroup 可视化管理

**问题**: CangjieMagic 的 AgentGroup（LeaderGroup/LinearGroup/FreeGroup）在代码中定义，无可视化管理界面。

**融合方案**:
1. 新增 `agent_groups` 数据库表，存储 AgentGroup 定义：
   - `id`, `name`, `group_type`(leader/linear/free/auto_discuss/round_robin), `leader_id`, `member_ids`(JSON), `config`(JSON), `status`, `creator`, 时间戳
2. 新增 AgentGroups CRUD 模块（PO/DAO/Service/Controller/Route）
3. API 支持：
   - `POST /api/v1/uctoo/agent_groups/add` - 创建 Agent 组
   - `POST /api/v1/uctoo/agent_groups/{id}/add-member` - 添加成员
   - `POST /api/v1/uctoo/agent_groups/{id}/remove-member` - 移除成员
   - `POST /api/v1/uctoo/agent_groups/{id}/execute` - 执行 Agent 组任务
   - `GET /api/v1/uctoo/agent_groups/{id}/status` - 查询执行状态
4. 前端管理界面：
   - Agent 组列表和详情页
   - 拖拽式 Agent 组编排（可视化 DAG）
   - 实时执行状态监控

### FUSION-003: Memory 数据库持久化

**问题**: CangjieMagic 的 ShortMemory 基于 InMemoryVectorDatabase，进程重启后丢失。

**融合方案**:
1. 新增 `agent_memories` 数据库表（见 agent-memory-persistence spec）
2. 实现 `DatabaseMemory` 类，实现 Memory 接口：
   - `update(segment)` → 写入 agent_memories 表 + 生成嵌入向量
   - `search(question)` → 向量相似度检索（复用 RAG 的 EmbeddingModel）
3. 记忆分层存储：
   - `scope=working` → AgentContexts 表（已有）
   - `scope=episodic` → agent_memories 表（新建）
   - `scope=semantic` → agent_memories 表（新建，weight 更高）
   - `scope=procedural` → agent_memories 表（新建，tag=procedural）
4. 融合 ShortMemory 和 DatabaseMemory：
   - 写入时同时写入内存（ShortMemory）和数据库（DatabaseMemory）
   - 检索时优先从内存检索，miss 时从数据库加载
5. 记忆与同步集成：agent_memories 变更通过 SyncManager 同步到 Markdown 文件

### FUSION-004: Crontab 驱动长任务

**问题**: 缺乏长时间运行任务的支持，CangjieMagic Agent 执行是同步的。

**融合方案**:
1. 复用 SchedulerEngine 作为长任务调度器：
   - Agent 长任务注册为 Crontab 任务（`task_type=agent_execution`）
   - Crontab 的 `pause/resume/trigger` 直接映射为长任务的暂停/恢复/触发
   - Crontab 的 `timeout/maxRetries/concurrentable` 直接用于长任务控制
2. 新增 `AgentExecutionExecutor` 实现 Crontab 的 Executor 接口：
   - 从 AgentTasks 加载任务定义
   - 创建 AgentRuntimeBridge 创建运行时 Agent
   - 执行 Agent 并将结果写入 AgentTasks
   - 执行进度通过 EventStream → WebSocket 推送
3. 检查点机制：
   - 利用 AgentContexts 的 messages 字段存储对话快照
   - 每完成一个步骤，将当前上下文保存为检查点
   - 恢复时从 AgentContexts 加载最新检查点
4. 子任务树：
   - 复用 AgentTasks 的 parentTaskId 建立层级
   - 新增 `subtask_failure_strategy` 字段（any_fail/majority_success/all_complete）

### FUSION-005: Agent 执行事件 → WebSocket 实时通知

**问题**: CangjieMagic 的 EventHandlerManager 产生事件但未推送到前端。

**融合方案**:
1. 创建 `WebSocketEventBridge`：
   - 注册为 EventHandlerManager 的全局处理器
   - 将 Agent 事件转换为 WebSocket 消息推送
2. 事件映射：
   - `AgentStartEvent` → `{"type": "agent_start", "agent_id": ..., "task_id": ...}`
   - `AgentStepEvent` → `{"type": "agent_step", "step": ..., "content": ...}`
   - `ToolCallStartEvent` → `{"type": "tool_call_start", "tool": ...}`
   - `ToolCallEndEvent` → `{"type": "tool_call_end", "result": ...}`
   - `AgentEndEvent` → `{"type": "agent_end", "result": ...}`
   - `AgentTimeoutEvent` → `{"type": "agent_timeout"}`
   - `UserInputEvent` → `{"type": "user_input_required", "prompt": ...}`（人机协作）
3. 复用已有的 `/api/v1/uctoo/ws/chat` WebSocket 端点

### FUSION-006: 人机协作增强

**问题**: CangjieMagic 的 HumanAgent 仅支持控制台输入，无可视化人机交互。

**融合方案**:
1. 扩展 HumanAgent 为 `WebHumanAgent`：
   - 通过 WebSocket 等待用户输入（而非控制台）
   - 支持富文本输入（代码、文件、图片）
   - 支持审批操作（确认/拒绝/修改建议）
2. 新增 `agent_approvals` 表：
   - `id`, `agent_id`, `task_id`, `approval_type`(confirm/review/edit), `content`, `status`(pending/approved/rejected/modified), `user_response`, 时间戳
3. API 端点：
   - `GET /api/v1/uctoo/agent_approvals/pending` - 查询待审批项
   - `POST /api/v1/uctoo/agent_approvals/{id}/approve` - 批准
   - `POST /api/v1/uctoo/agent_approvals/{id}/reject` - 拒绝
   - `POST /api/v1/uctoo/agent_approvals/{id}/modify` - 修改后批准
4. Interceptor 集成：
   - 配置 `Conditional` 拦截器，在关键步骤前触发 HumanAgent 审批
   - 审批结果决定 Agent 继续执行还是调整策略

### FUSION-007: Skill 组合与 AgentGroup 融合

**问题**: 技能组合和 Agent 协作是两个独立系统，缺乏统一编排。

**融合方案**:
1. 技能组合执行时自动创建 AgentGroup：
   - 串行组合 → LinearGroup
   - 并行组合 → LeaderGroup（leader 为编排器，members 为各技能 Agent）
   - 评估-改进循环 → 自定义 Group（含循环逻辑）
2. AgentGroup 的成员可以是 SkillAsAgent（技能包装为 Agent）：
   - `SkillAsAgent` 继承 BaseAgent，systemPrompt 为 SKILL.md 正文
   - tools 为技能声明的工具 + SkillToToolAdapter 适配的工具
3. 组合执行结果写入 AgentTasks，支持通过 API 查询

### FUSION-008: Agent 可视化监控仪表板

**问题**: 缺乏 Agent 运行状态的可视化监控。

**融合方案**:
1. 新增 Agent 监控 API：
   - `GET /api/v1/uctoo/agents/dashboard` - 仪表板汇总数据
   - `GET /api/v1/uctoo/agents/{id}/execution-log` - 执行日志
   - `GET /api/v1/uctoo/agents/{id}/memory` - 记忆查看
   - `GET /api/v1/uctoo/agents/{id}/conversation` - 对话历史
2. 仪表板数据包含：
   - 活跃 Agent 数量及类型分布
   - 正在执行的任务及进度
   - Agent 组协作拓扑图
   - 记忆使用统计
   - 错误率和重试统计
   - 资源消耗（Token、时间）
3. 前端实现：
   - Agent 列表页（含状态筛选、类型筛选）
   - Agent 详情页（含执行历史、对话、记忆、权限）
   - Agent 组编排页（可视化 DAG 编辑器）
   - 实时监控页（WebSocket 驱动）

## 融合与 5 个 Specs 的覆盖关系

| 融合需求 | 覆盖的 spec 需求 | 覆盖程度 | 说明 |
|---------|-----------------|---------|------|
| FUSION-001 Agent 运行时桥接 | agent-orchestration (部分) | 30% | 建立了 Agent 与数据库的桥接，为编排持久化提供基础 |
| FUSION-002 AgentGroup 可视化管理 | agent-orchestration (部分) | 40% | AgentGroup CRUD + 可视化，覆盖编排的定义和查询 |
| FUSION-003 Memory 数据库持久化 | agent-memory-persistence (大部分) | 75% | 覆盖持久化、语义检索、记忆分层、同步，缺衰减和跨会话自动加载 |
| FUSION-004 Crontab 驱动长任务 | long-running-task (大部分) | 70% | 复用 Crontab 的暂停/恢复/超时/重试/并发，缺检查点自动保存和优先级队列 |
| FUSION-005 事件→WebSocket 通知 | long-running-task (部分) | 50% | 覆盖实时进度通知，缺 SSE 和进度百分比 |
| FUSION-006 人机协作增强 | agent-error-recovery (部分) | 20% | 审批机制可辅助自愈决策，但非核心覆盖 |
| FUSION-007 Skill 组合与 AgentGroup 融合 | skill-composition-engine (部分) | 35% | 覆盖组合→AgentGroup 的映射，缺 DSL 和数据传递 |
| FUSION-008 Agent 可视化监控 | 全部 specs (辅助) | 10% | 监控仪表板为所有 spec 提供可观测性支撑 |

**总体评估**: 融合方案可覆盖 5 个 specs 约 **35-40%** 的需求，主要集中在：
- **long-running-task**: 70% 覆盖（Crontab 复用是最大收益）
- **agent-memory-persistence**: 75% 覆盖（数据库持久化 + 语义检索）
- **agent-orchestration**: 30-40% 覆盖（AgentGroup + PlanReact 已有基础）

仍需独立新建的核心能力：
- **agent-orchestration**: DAG 调度引擎、动态重编排、执行回滚
- **agent-error-recovery**: 错误分类、降级执行、熔断器、补偿事务
- **skill-composition-engine**: 组合 DSL、技能间数据传递、依赖解析

## 实施优先级

| 优先级 | 融合需求 | 依赖 | 预估工时 |
|--------|---------|------|---------|
| P0 | FUSION-001 Agent 运行时桥接 | 无 | 3d |
| P0 | FUSION-003 Memory 数据库持久化 | FUSION-001 | 5d |
| P1 | FUSION-004 Crontab 驱动长任务 | FUSION-001 | 4d |
| P1 | FUSION-005 事件→WebSocket 通知 | FUSION-001 | 2d |
| P1 | FUSION-002 AgentGroup 可视化管理 | FUSION-001 | 5d |
| P2 | FUSION-006 人机协作增强 | FUSION-005 | 3d |
| P2 | FUSION-007 Skill 组合与 AgentGroup 融合 | FUSION-001, FUSION-002 | 4d |
| P2 | FUSION-008 Agent 可视化监控 | FUSION-002, FUSION-005 | 5d |

**总预估工时**: 31 人天

## 验收标准

1. AgentRuntimeBridge 正确创建运行时 Agent 并同步状态到数据库
2. AgentGroup 可通过 API CRUD 管理并执行
3. DatabaseMemory 正确持久化记忆到 PostgreSQL 并支持语义检索
4. Crontab 可驱动 Agent 长任务执行，支持暂停/恢复/超时/重试
5. Agent 执行事件通过 WebSocket 实时推送到前端
6. HumanAgent 可通过 WebSocket 等待用户审批
7. 技能组合可自动创建对应 AgentGroup 执行
8. Agent 监控仪表板正确展示运行状态和执行历史

---

# 全栈有机融合：Web 前端 + Runtime 后端 + CangjieMagic 框架

## 全栈架构现状

### 三层系统组成

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Web Admin 前端 (web-admin/web)                  │
│  Vue 3 + Vite + OpenTiny Vue + TinyRobot + pinia-orm + WebMCP SDK │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │
│  │  pinia-orm   │  │  TinyRobot   │  │  WebMCP Server/Client   │  │
│  │  数据模型层  │  │  AI 聊天 UI  │  │  前端工具注册+MCP通信   │  │
│  └──────────────┘  └──────────────┘  └──────────────────────────┘  │
│                          │ StreamableHTTP / WebSocket               │
│                          ▼                                          │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │              agentskills-runtime 后端 (src/app)               │   │
│  │  PostgreSQL + CRUD + SyncManager + Crontab + 权限 + WebMCP  │   │
│  │                          │                                    │   │
│  │                          ▼                                    │   │
│  │  ┌────────────────────────────────────────────────────────┐ │   │
│  │  │         CangjieMagic 框架 (src/agent/...)              │ │   │
│  │  │  Agent + AgentExecutor + AgentGroup + Memory + Tool    │ │   │
│  │  │  + Skill + Interaction + RAG + Storage                 │ │   │
│  │  └────────────────────────────────────────────────────────┘ │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### Web 前端已有能力

| 能力 | 实现 | 与后端对接方式 |
|------|------|--------------|
| **pinia-orm 数据模型** | 20+ 个 Model（agents、agent_skills、agent_tasks、agent_contexts、entity、crontab、sync_log 等），每个 Model 定义字段和 CRUD API actions | REST API `/api/v1/uctoo/{entity}/*` |
| **Agent CRUD 页面** | `views/database/uctoo/agents/` 列表+新增+编辑 | pinia-orm agents model |
| **Agent Skill 页面** | `views/ai/agent_skills.vue` 卡片列表 + `views/database/uctoo/agent_skills/` CRUD | pinia-orm agent_skills model |
| **TinyRobot AI 聊天** | `@opentiny/tiny-robot` 组件 + CustomAgentModelProvider | WebMCP `/api/v1/uctoo/webmcp/mcp` |
| **WebMCP 前端工具注册** | 7 个工具模块（chat/entity/user/role/permission/menu/locale） | WebMCP Server → WebMcpClient |
| **前端技能** | 6 个技能（entity-operator、tiny-pro-operator、document-writing、code-generation、data-analysis） | SKILL.md 定义 |
| **数据库元信息管理** | db_info model + 代码生成 API（generateCrud/generateWeb） | REST API |
| **状态持久化** | pinia-plugin-persistedstate | localStorage |

### WebMCP 通信架构

当前前端与后端的人机对话交互使用 WebMCP 控制器中的 API：

```
前端 TinyRobot ──→ CustomAgentModelProvider ──→ StreamableHTTPClientTransport
     │                                              │
     │ WebMcpServer (前端工具注册)                   │ /api/v1/uctoo/webmcp/mcp
     │ ├─ chat tools (对话/技能列表/技能执行)        │
     │ ├─ entity tools (CRUD)                       │
     │ ├─ user/role/permission/menu/locale tools    │
     │                                              │
     └──────────────────────────────────────────────┘
```

**已知问题**: 通过 WebMCP 协议将 Web 端注册为工具，以支持 Agent 直接操作 Web 应用的能力还有些 bug，待实现和完善。

## 设计原则

### 原则 1: 数据库为数据流枢纽

用户界面主要与数据库 API 进行对接，内存层和文件系统层的信息都以文件系统与数据库一致性同步（filesystem-database-sync-mvp）的方式汇总到数据库中，实现：
- **清晰的数据流**: 所有数据变更都通过数据库 API，可追踪、可审计
- **数据资产管理**: 数据库作为唯一的数据真相源（Single Source of Truth）
- **行为及数据可观测可管理**: 通过 OperateLog + SyncLog + CrontabLog 实现全链路可观测

```
文件系统 (AGENTS.md/SKILL.md) ──SyncManager──→ 数据库 ←──SyncManager── 运行时内存 (Agent/Skill)
                                           │
                                           ▼
                                     Web 前端 (pinia-orm)
                                           │
                                     REST API / WebMCP
```

### 原则 2: UMI 全栈数据同构（通模一体）

遵循 UMI 全栈数据同构规范——通信和数据模型一体：
- **后端 PO 模型**（AgentsPO.cj）的字段定义与**前端 ORM 模型**（agents.ts）的字段定义保持同构
- **后端 API 的请求/响应格式**与**前端 pinia-orm 的 actions** 保持一致
- **数据库表结构**是前后端共享的"契约"，任何变更通过 SyncManager 双向同步
- 新增实体时，crudgen 自动生成后端 CRUD + crudweb 自动生成前端页面，确保同构

### 原则 3: AI 驱动开发框架最佳实践

基于 `docs/ref/AIDrivenArchitecture.md` 的总结：
- **统一技术栈**: 仓颉（后端）+ TypeScript/Vue3（前端），Monorepo 架构
- **CLI 友好设计**: 所有能力可通过 CLI 访问，便于 AI IDE 集成
- **AI Native 原则**: 原生智能化、天生全场景、高性能、强安全
- **模型同构规范**: 前后端数据模型同构
- **AI 生态集成**: 支持 MCP、AgentSkills、WebMCP 等协议

### 原则 4: 超越 Harness Engineering 最佳实践

基于 `docs/ref/` 中 Harness 对比分析（harness.md、GLM5TharnessVSAIinfra.md、doubaoseed2harnessVSAIinfra.md）和 Claude Code 源码分析（claude-code-rev/），我们的目标是超越而非复制 Harness 模式：

| Harness 12 组件 | Claude Code 实现 | agentskills-runtime 超越方向 |
|----------------|-----------------|---------------------------|
| **编排循环** | while(true) TAO 循环 | **数据库驱动编排**：执行计划持久化到数据库，支持跨会话恢复、可视化管理 |
| **工具** | 54 个工具 | **技能即工具**：SkillToToolAdapter + 内置 20 工具 + WebMCP 前端工具，技能是一等公民 |
| **记忆** | 三层文件记忆 + SessionMemory | **数据库记忆**：四层记忆持久化到 PostgreSQL，语义向量检索，跨会话共享 |
| **上下文管理** | 五层压缩管道 | **数据库+内存双层**：数据库为真相源，内存为缓存，SyncManager 保证一致性 |
| **护栏与安全** | 逐操作安全评估 | **RBAC + 行级权限 + 审计**：数据库驱动的权限体系，比文件级更精细 |
| **验证循环** | VerifyPlanExecutionTool | **评估-改进循环**：skill-creator 的 grader/comparator/analyzer 三 Agent 验证 |
| **子 Agent 编排** | Fork/Teammate/Worktree | **AgentGroup + 数据库**：五种协作模式 + 持久化 + 可视化 DAG 编排 |
| **错误处理** | PTL 重试 + 断路器 | **自愈系统**：错误分类 + 降级执行 + 熔断器 + 补偿事务 + 自愈诊断 |

**核心超越点**: Harness Engineering 以文件和内存为中心，agentskills-runtime 以**数据库为中心**，通过文件系统-数据库双向同步实现声明式管理与运行时查询的统一，这是对 Harness 模式的根本性升级。

## 全栈融合需求

### FUSION-FE-001: WebMCP 协议完善

**问题**: 当前 WebMCP 将 Web 端注册为工具以支持 Agent 直接操作 Web 应用的能力有 bug，待完善。

**融合方案**:
1. 修复 WebMCP Server 工具注册和调用的已知 bug
2. 完善 Agent → WebMCP → 前端工具调用链：
   - Agent 通过 WebMcpClient 调用前端注册的工具（如 entity CRUD、页面导航）
   - 前端工具执行结果通过 WebMCP 协议返回给 Agent
3. 新增 Agent 专用工具：
   - `web_navigate(route)` - 导航到指定前端页面
   - `web_notify(message)` - 向前端推送通知消息
   - `web_request_approval(content)` - 请求用户审批（人机协作）
4. 前端工具注册扩展：
   - `agent_control tools` - Agent 启动/停止/暂停/恢复
   - `task_monitor tools` - 任务进度查看
   - `memory_browse tools` - 记忆浏览和搜索

### FUSION-FE-002: pinia-orm 与后端 API 通模一体

**问题**: 前端 pinia-orm 模型与后端 PO 模型手动维护同构，新增字段需两端同步修改。

**融合方案**:
1. **模型自动生成**: 利用 db_info 表的元数据，crudweb 自动生成 pinia-orm 模型文件
   - 从 db_info 读取表结构和字段类型
   - 生成 `src/store/models/uctoo/{entity}.ts`，包含字段装饰器和 CRUD actions
   - 与后端 crudgen 生成的 PO 保持同构
2. **API 契约验证**: 启动时自动校验前端模型字段与后端 API 响应字段的一致性
3. **新增实体全栈生成**: 一条命令生成后端 CRUD + 前端 ORM 模型 + 前端 CRUD 页面
   ```bash
   crudgen --table agents --full-stack
   # 生成: PO + DAO + Service + Controller + Route + pinia-orm Model + Vue CRUD 页面
   ```

### FUSION-FE-003: Agent 实时监控前端

**问题**: 前端仅有 Agent CRUD 页面，无实时运行状态监控。

**融合方案**:
1. 新增 `views/ai/agent-monitor.vue` 页面：
   - Agent 实时状态卡片（运行中/空闲/错误，WebSocket 驱动）
   - 任务执行进度条（步骤完成数/总步骤数）
   - Agent 组协作拓扑图（可视化 DAG，节点为 Agent，边为消息流）
   - Token 消耗和执行时间实时统计
2. 新增 `views/ai/agent-detail.vue` 页面：
   - Agent 配置详情（来自 agents pinia-orm model）
   - 执行历史时间线（来自 agent_tasks model）
   - 对话历史查看（来自 agent_contexts model）
   - 记忆浏览和搜索（来自 agent_memories model，待 FUSION-003）
   - 权限和审批记录（来自 agent_approvals model，待 FUSION-006）
3. 新增 `views/ai/skill-composer.vue` 页面：
   - 技能组合编排器（拖拽式 DAG 编辑）
   - 技能依赖关系可视化
   - 组合执行和结果查看

### FUSION-FE-004: TinyRobot 与 Agent 系统深度集成

**问题**: 当前 TinyRobot 仅用于对话，未与 Agent 生命周期和任务系统深度集成。

**融合方案**:
1. TinyRobot 对话自动关联 Agent：
   - 每次对话创建或关联一个 Agent 实例（写入 agents 表）
   - 对话历史自动持久化到 agent_contexts 表
   - 对话中的工具调用记录到 agent_tasks 表
2. TinyRobot 支持多 Agent 切换：
   - 模型切换下拉框增加 Agent 选择（选择不同角色/技能的 Agent）
   - 切换 Agent 时加载对应的 systemPrompt 和 tools
3. TinyRobot 支持子 Agent 可视化：
   - 子 Agent 执行时在对话中显示为嵌套卡片
   - 子 Agent 结果折叠/展开查看
   - 子 Agent 执行进度实时更新
4. TinyRobot 支持人机审批：
   - Agent 请求审批时弹出审批对话框
   - 支持"确认"/"拒绝"/"修改后确认"三种操作
   - 审批结果通过 WebSocket 返回给 Agent

### FUSION-FE-005: 前端技能与后端技能统一管理

**问题**: 前端技能（`src/skills/`）和后端技能（`skills/`）独立管理，无统一视图。

**融合方案**:
1. 前端技能通过 WebMCP 注册为工具，后端技能通过 SkillManager 管理
2. 统一技能视图页面 `views/ai/agent_skills.vue` 增强：
   - 显示技能来源（前端/后端）
   - 前端技能标记为 "browser-side"，后端技能标记为 "server-side"
   - 技能详情页显示 SKILL.md 正文、agents 声明、脚本列表
3. 技能安装统一入口：
   - 后端技能：`skill install --git <url>` → SkillManager → agent_skills 表
   - 前端技能：npm install → WebMCP 注册 → 前端技能列表
   - 两端同步：agent_skills 表通过 SyncManager 同步到文件系统

### FUSION-FE-006: 数据库驱动的全链路可观测

**问题**: 当前可观测性分散在各日志表中，缺乏统一的全链路视图。

**融合方案**:
1. 新增 `views/database/uctoo/observability.vue` 页面：
   - 全链路时间线：用户操作 → API 调用 → Agent 执行 → 工具调用 → 数据库变更 → 同步事件
   - 数据来源：operate_log + agent_tasks + sync_log + crontab_log
   - 支持按 Agent、任务、时间范围筛选
2. 数据流可视化：
   - 文件 → 数据库同步流（SyncManager 状态）
   - 数据库 → 前端数据流（pinia-orm API 调用）
   - Agent → 工具 → 结果流（AgentTasks + EventStream）
3. 数据资产仪表板：
   - 各实体表的记录数和增长趋势
   - Agent 活跃度和任务完成率
   - 同步健康状态（synced/pending/error 分布）

## 与业界最佳实践的对比定位

### vs Claude Code (Harness Engineering)

| 维度 | Claude Code | agentskills-runtime 目标 |
|------|------------|------------------------|
| **数据持久化** | 文件系统（MEMORY.md、transcript） | **PostgreSQL 数据库** + 文件系统双向同步 |
| **记忆系统** | 三层文件记忆 + SessionMemory | **四层数据库记忆** + 语义向量检索 + 跨会话共享 |
| **编排模式** | while(true) TAO + Coordinator | **数据库驱动 DAG** + AgentGroup 五种模式 + 可视化编排 |
| **安全模型** | 逐操作权限检查 | **RBAC + 行级权限** + 审计日志 + WASM 沙箱 |
| **人机协作** | AskUserQuestionTool（CLI） | **WebMCP + WebSocket** + 审批工作流 + TinyRobot UI |
| **可观测性** | 终端输出 + transcript 文件 | **数据库全链路** + WebSocket 实时推送 + 前端仪表板 |
| **技能系统** | 54 个硬编码工具 | **Skill 一等公民** + SkillToToolAdapter + 技能组合引擎 |
| **跨平台** | Node.js/TypeScript | **仓颉（国产自主）** + TypeScript 前端 |

### 核心差异化优势

1. **数据库为中心的架构**: 所有数据（Agent、技能、记忆、任务、日志）以 PostgreSQL 为真相源，文件系统通过 SyncManager 保持同步，这是对 Harness "文件为中心"模式的根本性升级
2. **全栈数据同构（通模一体）**: 后端 PO ↔ 前端 ORM 模型自动同构，crudgen + crudweb 一键全栈生成
3. **WebMCP 双向工具调用**: 前端注册为工具供 Agent 调用，Agent 也可调用后端工具，实现真正的全栈 AI 驱动
4. **国产自主可控**: 仓颉语言 + OpenTiny Vue 组件库，不依赖海外技术栈
5. **可视化编排与管理**: Agent Group DAG 编辑器、实时监控仪表板、全链路可观测，超越 CLI-only 的 Harness 模式

## 全栈融合实施优先级

| 优先级 | 融合需求 | 依赖 | 预估工时 |
|--------|---------|------|---------|
| P0 | FUSION-001 Agent 运行时桥接 | 无 | 3d |
| P0 | FUSION-003 Memory 数据库持久化 | FUSION-001 | 5d |
| P0 | FUSION-FE-001 WebMCP 协议完善 | 无 | 3d |
| P1 | FUSION-004 Crontab 驱动长任务 | FUSION-001 | 4d |
| P1 | FUSION-005 事件→WebSocket 通知 | FUSION-001 | 2d |
| P1 | FUSION-FE-002 pinia-orm 通模一体 | FUSION-001 | 3d |
| P1 | FUSION-FE-004 TinyRobot 与 Agent 集成 | FUSION-FE-001, FUSION-005 | 4d |
| P1 | FUSION-002 AgentGroup 可视化管理 | FUSION-001 | 5d |
| P2 | FUSION-006 人机协作增强 | FUSION-005 | 3d |
| P2 | FUSION-FE-003 Agent 实时监控前端 | FUSION-002, FUSION-005 | 5d |
| P2 | FUSION-007 Skill 组合与 AgentGroup 融合 | FUSION-001, FUSION-002 | 4d |
| P2 | FUSION-FE-005 前端/后端技能统一管理 | FUSION-FE-001 | 2d |
| P2 | FUSION-008 Agent 可视化监控仪表板 | FUSION-002, FUSION-005 | 5d |
| P3 | FUSION-FE-006 全链路可观测 | FUSION-008 | 4d |

**总预估工时**: 52 人天（融合） + 17 人天（计费） = 69 人天

## 全栈验收标准

1. AgentRuntimeBridge 正确创建运行时 Agent 并同步状态到数据库
2. AgentGroup 可通过 API CRUD 管理并执行
3. DatabaseMemory 正确持久化记忆到 PostgreSQL 并支持语义检索
4. Crontab 可驱动 Agent 长任务执行，支持暂停/恢复/超时/重试
5. Agent 执行事件通过 WebSocket 实时推送到前端
6. HumanAgent 可通过 WebSocket 等待用户审批
7. 技能组合可自动创建对应 AgentGroup 执行
8. Agent 监控仪表板正确展示运行状态和执行历史
9. WebMCP 前端工具注册和调用链正确工作，Agent 可操作 Web 应用
10. pinia-orm 模型与后端 PO 模型保持同构，全栈生成命令正确工作
11. TinyRobot 对话自动关联 Agent，支持多 Agent 切换和子 Agent 可视化
12. 前端/后端技能统一管理，来源标识清晰
13. 全链路可观测页面正确展示从用户操作到数据库变更的完整数据流
14. Token 统计和计费功能正确记录每次 LLM 调用的 token 消耗和费用
15. 各模型提供商费率配置正确，计费金额计算准确
16. Token 用量仪表板正确展示按 Agent/模型/时间维度的统计

---

# Token 统计与计费系统

## 已有基础

### ChatUsage 数据结构（已实现）

`src/core/model/chat_usage.cj` 中已定义：

```cangjie
public class ChatUsage {
    public let promptTokens: Int64      // 输入 token 数
    public let completionTokens: Int64  // 输出 token 数
    public let totalTokens: Int64       // 总 token 数
    public let timeCost: Option<Duration> // 耗时
}
```

每次 LLM 调用后，`ChatResponse.usage` 和 `AsyncChatResponse.usage` 均返回 `ChatUsage` 实例。所有模型提供商（OpenAI、Ollama、StepFun、Tokendance 等）均已实现 usage 解析。

### 已集成的模型提供商（18个）

| 提供商 | 环境变量 | ChatModel | EmbeddingModel |
|--------|---------|-----------|----------------|
| openai | OPENAI_BASE_URL / OPENAI_API_KEY | ✓ | ✓ |
| dashscope (阿里) | DASHSCOPE_BASE_URL / DASHSCOPE_API_KEY | ✓(兼容) | ✓ |
| ark (火山引擎) | ARK_BASE_URL / ARK_API_KEY | ✓(兼容) | ✓ |
| deepseek | DEEPSEEK_BASE_URL / DEEPSEEK_API_KEY | ✓(兼容) | - |
| siliconflow | SILICONFLOW_BASE_URL / SILICONFLOW_API_KEY | ✓(兼容) | ✓ |
| zhipuai (智谱) | ZHIPUAI_BASE_URL / ZHIPUAI_API_KEY | ✓(兼容) | - |
| maas (华为云) | MAAS_BASE_URL / MAAS_API_KEY | ✓(兼容) | - |
| google | GOOGLE_BASE_URL / GOOGLE_API_KEY | ✓(兼容) | - |
| moonshot | MOONSHOT_BASE_URL / MOONSHOT_API_KEY | ✓(兼容) | - |
| openrouter | OPENROUTER_BASE_URL / OPENROUTER_API_KEY | ✓(兼容) | - |
| stepfun (阶跃) | STEPFUN_BASE_URL / STEPFUN_API_KEY | ✓(兼容) | ✓ |
| sophnet | SOPHNET_BASE_URL / SOPHNET_API_KEY | ✓(兼容) | ✓ |
| orbitai | ORBITAI_BASE_URL / ORBITAI_API_KEY | ✓(兼容) | ✓ |
| atomgit | ATOMGIT_BASE_URL / ATOMGIT_API_KEY | ✓(兼容) | - |
| gmicloud | GMICLOUD_BASE_URL / GMICLOUD_API_KEY | ✓(兼容) | - |
| tokendance | TOKENDENCE_BASE_URL / TOKENDENCE_API_KEY | ✓ | ✓ |
| ollama | OLLAMA_BASE_URL | ✓ | ✓ |
| llamacpp | - | - | ✓ |

### Tokendance 计费网关（已集成）

`src/model/tokendance/` 已实现 Tokendance 计费网关集成，提供统一的 LLM 调用代理和 token 计量能力。Tokendance 作为计费中间层，可对接多个上游模型提供商并统一计量。

## 核心需求

### BILLING-001: Token 使用记录持久化

**问题**: 当前 ChatUsage 仅存在于内存中的 ChatResponse，未持久化到数据库，无法进行历史统计和计费。

**方案**:
1. 新增 `llm_usage_logs` 数据库表：

| 字段 | 类型 | 说明 |
|------|------|------|
| id | bigint | 主键 |
| agent_id | varchar(100) | 调用 Agent 的 ID |
| task_id | varchar(100) | 关联任务 ID |
| provider | varchar(50) | 模型提供商（openai/deepseek/dashscope 等） |
| model | varchar(100) | 模型名称（gpt-4o/deepseek-chat/qwen-plus 等） |
| model_id | varchar(200) | 完整模型标识（provider:model） |
| prompt_tokens | bigint | 输入 token 数 |
| completion_tokens | bigint | 输出 token 数 |
| total_tokens | bigint | 总 token 数 |
| time_cost_ms | integer | 耗时（毫秒） |
| request_type | varchar(20) | 请求类型（chat/embedding/image） |
| is_streaming | boolean | 是否流式请求 |
| tool_calls_count | integer | 工具调用次数 |
| user_id | bigint | 用户 ID |
| session_id | varchar(100) | 会话 ID |
| cost_amount | decimal(12,6) | 计费金额（元） |
| cost_currency | varchar(10) | 货币单位（CNY/USD） |
| rate_prompt | decimal(12,6) | 输入 token 单价 |
| rate_completion | decimal(12,6) | 输出 token 单价 |
| request_id | varchar(100) | 请求唯一标识 |
| error_message | varchar(500) | 错误信息（调用失败时） |
| created_at | timestamp | 创建时间 |

2. 创建 `LlmUsageLogPO` + `LlmUsageLogDAO` + `LlmUsageLogService` CRUD 模块
3. 在 `ChatModel.create()` 和 `ChatModel.asyncCreate()` 的返回路径中插入记录逻辑：
   - 每次成功的 LLM 调用后，将 ChatUsage 写入 llm_usage_logs 表
   - 调用失败时也记录（prompt_tokens 为预估，completion_tokens=0，error_message 非空）
4. 通过 EventHandlerManager 的 `ChatModelEndEvent` 自动触发记录（无需修改各模型实现）

### BILLING-002: 模型提供商费率配置

**问题**: 各模型提供商的 token 单价分散在各提供商官网，缺乏统一配置。

**方案**:
1. 新增 `model_pricing` 数据库表：

| 字段 | 类型 | 说明 |
|------|------|------|
| id | bigint | 主键 |
| provider | varchar(50) | 提供商 |
| model | varchar(100) | 模型名称 |
| model_id | varchar(200) | 完整标识（provider:model） |
| rate_prompt_per_million | decimal(12,6) | 输入 token 单价（每百万 token，元） |
| rate_completion_per_million | decimal(12,6) | 输出 token 单价（每百万 token，元） |
| rate_currency | varchar(10) | 货币单位（CNY/USD） |
| rate_unit | varchar(20) | 计价单位（per_million_tokens） |
| is_active | boolean | 是否生效 |
| effective_from | timestamp | 生效起始时间 |
| effective_to | timestamp | 生效截止时间（可选，支持费率变更） |
| source | varchar(200) | 费率来源（官方定价/手动配置） |
| remark | varchar(500) | 备注 |
| creator | bigint | 创建者 |
| created_at | timestamp | 创建时间 |
| updated_at | timestamp | 更新时间 |

2. 预置各提供商的主流模型费率（2024-2025 官方定价）：

| 提供商 | 模型 | 输入单价(元/百万token) | 输出单价(元/百万token) | 货币 |
|--------|------|----------------------|----------------------|------|
| openai | gpt-4o | 17.5 | 70.0 | USD |
| openai | gpt-4o-mini | 0.15 | 0.6 | USD |
| openai | gpt-4-turbo | 70.0 | 210.0 | USD |
| openai | text-embedding-3-large | 10.0 | - | USD |
| deepseek | deepseek-chat | 1.0 | 2.0 | CNY |
| deepseek | deepseek-reasoner | 4.0 | 16.0 | CNY |
| dashscope | qwen-plus | 0.8 | 2.0 | CNY |
| dashscope | qwen-turbo | 0.3 | 0.6 | CNY |
| dashscope | qwen-max | 20.0 | 60.0 | CNY |
| zhipuai | glm-4 | 50.0 | 50.0 | CNY |
| zhipuai | glm-4-flash | 1.0 | 1.0 | CNY |
| moonshot | moonshot-v1-8k | 12.0 | 12.0 | CNY |
| stepfun | step-2-16k | 3.4 | 13.6 | CNY |
| siliconflow | Qwen/Qwen2.5-72B-Instruct | 4.13 | 4.13 | CNY |
| ark | doubao-pro-32k | 0.8 | 2.0 | CNY |
| ark | doubao-lite-32k | 0.3 | 0.6 | CNY |
| ollama | *(本地模型) | 0.0 | 0.0 | CNY |
| llamacpp | *(本地模型) | 0.0 | 0.0 | CNY |

3. 费率查询 API：
   - `GET /api/v1/uctoo/model_pricing` - 查询所有费率
   - `GET /api/v1/uctoo/model_pricing/{provider}/{model}` - 查询指定模型费率
   - `POST /api/v1/uctoo/model_pricing/add` - 新增费率
   - `POST /api/v1/uctoo/model_pricing/edit` - 更新费率
   - `POST /api/v1/uctoo/model_pricing/refresh` - 从官方刷新费率（预留）

4. 计费计算逻辑：
   ```
   cost = (prompt_tokens / 1,000,000) × rate_prompt_per_million
        + (completion_tokens / 1,000,000) × rate_completion_per_million
   ```
   - 查询 model_pricing 表获取当前生效费率
   - 未配置费率的模型按 0 计费（如 ollama 本地模型）
   - 支持费率生效时间范围，自动选择当前生效的费率

### BILLING-003: Token 用量统计与仪表板

**问题**: 缺乏 token 用量的统计视图，无法了解各 Agent、模型、用户的消耗情况。

**方案**:
1. 后端统计 API：
   - `GET /api/v1/uctoo/llm-usage/summary` - 总量汇总（总 token、总费用、按提供商分布）
   - `GET /api/v1/uctoo/llm-usage/by-agent` - 按 Agent 维度统计
   - `GET /api/v1/uctoo/llm-usage/by-model` - 按模型维度统计
   - `GET /api/v1/uctoo/llm-usage/by-user` - 按用户维度统计
   - `GET /api/v1/uctoo/llm-usage/by-date?from=&to=` - 按时间维度统计（支持日/周/月粒度）
   - `GET /api/v1/uctoo/llm-usage/trends` - 趋势数据（近 7 天/30 天）
   - `GET /api/v1/uctoo/llm-usage/top-agents?limit=10` - 消耗最高的 Agent
   - `GET /api/v1/uctoo/llm-usage/top-models?limit=10` - 消耗最高的模型

2. 前端仪表板页面 `views/ai/token-dashboard.vue`：
   - **概览卡片**: 今日 token 数、今日费用、本月 token 数、本月费用
   - **趋势图**: token 用量和费用随时间变化（折线图）
   - **模型分布饼图**: 各模型 token 用量占比
   - **提供商分布饼图**: 各提供商费用占比
   - **Agent 排行榜**: token 消耗最高的 Agent 列表
   - **费率表**: 各模型当前生效费率一览
   - 支持时间范围筛选（今日/7天/30天/自定义）

3. Agent 详情页增加 Token 消耗标签页：
   - 该 Agent 的历史 token 用量列表
   - 该 Agent 的费用累计
   - 该 Agent 使用的模型分布

### BILLING-004: 用户/租户配额与预算

**问题**: 缺乏 token 用量配额控制，无法限制单个用户或租户的 LLM 调用量。

**方案**:
1. 新增 `usage_quotas` 数据库表：

| 字段 | 类型 | 说明 |
|------|------|------|
| id | bigint | 主键 |
| target_type | varchar(20) | 配额对象类型（user/tenant/agent） |
| target_id | varchar(100) | 对象 ID |
| quota_type | varchar(20) | 配额类型（daily_tokens/monthly_tokens/daily_cost/monthly_cost） |
| quota_limit | decimal(18,2) | 配额上限 |
| quota_used | decimal(18,2) | 已使用量 |
| quota_period_start | timestamp | 当前周期起始时间 |
| is_hard_limit | boolean | 是否硬限制（超限拒绝 vs 超限告警） |
| alert_threshold | float | 告警阈值（如 0.8 表示 80% 时告警） |
| creator | bigint | 创建者 |
| created_at | timestamp | 创建时间 |
| updated_at | timestamp | 更新时间 |

2. 配额检查流程：
   - 每次 LLM 调用前检查配额
   - 硬限制：超限时返回错误，拒绝调用
   - 软限制：超限时允许调用但发送告警通知
   - 告警：达到阈值百分比时通过 WebSocket 推送告警
3. 周期自动重置：通过 Crontab 定时任务每日/每月重置 quota_used

### BILLING-005: 计费报表与导出

**问题**: 缺乏面向财务/管理的计费报表。

**方案**:
1. 报表 API：
   - `GET /api/v1/uctoo/llm-usage/report/daily?date=` - 日报
   - `GET /api/v1/uctoo/llm-usage/report/monthly?year=&month=` - 月报
   - `GET /api/v1/uctoo/llm-usage/report/export?format=xlsx&from=&to=` - 导出
2. 报表内容：
   - 时间范围、总 token 数、总费用
   - 按提供商分项：token 数、费用
   - 按模型分项：token 数、费用
   - 按用户分项：token 数、费用
   - 按 Agent 分项：token 数、费用
3. 导出格式：XLSX（复用已有 xlsx 能力）、CSV
4. 前端报表页面 `views/ai/billing-report.vue`：
   - 日报/月报切换
   - 图表+表格双视图
   - 导出按钮

### BILLING-006: 与 EventHandlerManager 集成

**方案**: 通过事件驱动实现无侵入的 token 记录：

1. 注册 `ChatModelEndEvent` 处理器：
   - 事件中包含 ChatResponse.usage（promptTokens、completionTokens、totalTokens）
   - 事件中包含 Agent 信息（name、id）
   - 处理器将 usage 写入 llm_usage_logs 表
2. 注册 `ChatModelFailureEvent` 处理器：
   - 记录失败的 LLM 调用（error_message 非空）
3. 注册 `AgentEndEvent` 处理器：
   - 汇总该 Agent 本次执行的总 token 消耗
   - 更新 AgentTasks 的 token 统计字段
4. 事件处理异步执行，不阻塞主流程

### BILLING-007: Tokendance 计费网关增强

**方案**: 增强 Tokendance 集成，实现统一计费代理：

1. Tokendance 作为统一网关：
   - 所有 LLM 调用可通过 Tokendance 代理
   - Tokendance 自动记录 token 用量到其计费系统
   - 同时写入本地 llm_usage_logs 表（双重记录）
2. Tokendance 余额查询：
   - `GET /api/v1/uctoo/tokendance/balance` - 查询账户余额
   - `GET /api/v1/uctoo/tokendance/usage` - 查询 Tokendance 侧的用量统计
3. 本地费率与 Tokendance 费率对比：
   - 支持配置使用本地费率或 Tokendance 费率计费
   - 费率差异告警

## 计费系统实施优先级

| 优先级 | 需求 | 依赖 | 预估工时 |
|--------|------|------|---------|
| P0 | BILLING-001 Token 使用记录持久化 | FUSION-001 | 3d |
| P0 | BILLING-002 模型提供商费率配置 | 无 | 2d |
| P1 | BILLING-006 EventHandlerManager 集成 | BILLING-001 | 2d |
| P1 | BILLING-003 Token 用量统计仪表板 | BILLING-001, BILLING-002 | 3d |
| P2 | BILLING-004 用户/租户配额与预算 | BILLING-001 | 3d |
| P2 | BILLING-005 计费报表与导出 | BILLING-003 | 2d |
| P2 | BILLING-007 Tokendance 网关增强 | BILLING-001 | 2d |

**计费系统预估工时**: 17 人天

## 计费系统验收标准

1. 每次 LLM 调用后 ChatUsage 正确写入 llm_usage_logs 表
2. 各模型提供商费率在 model_pricing 表正确配置
3. 计费金额按费率正确计算：cost = prompt_tokens × rate_prompt + completion_tokens × rate_completion
4. 本地模型（ollama/llamacpp）费率为 0，不计费
5. Token 用量仪表板正确展示各维度的统计数据
6. 配额超限时正确拒绝调用或发送告警
7. 计费报表可按日/月生成并导出为 XLSX
8. EventHandlerManager 事件正确触发 token 记录
9. Tokendance 网关余额和用量查询正确工作

---

## 数据流闭环断裂分析（2026-06-09 补充）

### WebMCP 聊天数据流现状

当前前端通过 `POST /api/v1/uctoo/webmcp/mcp`（MCP JSON-RPC 2.0 协议 `completion/complete` 方法）与后端交互，大模型能正确返回响应，但所有聊天过程应触发的数据均未在业务表中生成。

### 完整数据流路径与断裂点

```
前端 POST /api/v1/uctoo/webmcp/mcp
  → WebMCPRoutes.cj:72 → WebMCPController.handleStreamableHttp()
  → WebMCPProtocol.handleMessage() → handleMethod() → handleCompletionComplete()
  → SkillAwareAgent.chat(AgentRequest)    [Agent 推理，事件系统触发]
  → AbsAgent.chat()
    → AgentOp.handle(AgentStartEvent)      → EventHandlerManager.global [空! ❌FP-1]
    → ReactExecutor.run() → AgentTask.chatLLM() → AgentOp.chatLLM()
      → AgentOp.handle(ChatModelStartEvent) → EventHandlerManager.global [空! ❌FP-1]
      → ChatModel.create()                 [实际 LLM 调用]
      → AgentOp.handle(ChatModelEndEvent)  → EventHandlerManager.global [空! ❌FP-1]
          → BillingEventHandler.onChatModelEnd() [未注册! llm_usage_logs 无数据]
    → memory.update()                      [memory=None! ❌FP-3]
        → DatabaseMemory.update()          [未执行! agent_memories 无数据]
    → AgentOp.handle(AgentEndEvent)        → EventHandlerManager.global [空! ❌FP-1]
  → 返回 MCP JSON-RPC 响应                [无数据库写入! ❌FP-6]
```

### 6 个断裂点详情

| 编号 | 断裂点 | 文件 | 影响 | 修复任务 |
|------|--------|------|------|---------|
| FP-1 | BillingEventHandler 未注册 | main.cj | llm_usage_logs 无数据 | TASK-P0-009 |
| FP-2 | WebSocketEventBridge 未注册 | main.cj | WebSocket 事件不推送 | TASK-P0-009 |
| FP-3 | SkillAwareAgent 未设置 memory | WebMCPProtocol.cj:38 | agent_memories 无数据 | TASK-P0-011 |
| FP-4 | SkillAwareAgent 未设置 eventHandlerManager | WebMCPProtocol.cj:38 | Agent 级事件不触发 | TASK-P0-011 |
| FP-5 | 降级路径绕过事件系统 | WebMCPProtocol.cj:492 | 无任何事件触发 | TASK-P0-011 |
| FP-6 | Agent 执行后无数据库同步 | WebMCPProtocol.cj:488 | agents/agent_contexts 无数据 | TASK-P0-011 |

### 修复优先级

1. **TASK-P0-009**（0.5d）：注册 BillingEventHandler + WebSocketEventBridge + QuotaCheckHandler → 修复 FP-1, FP-2
2. **TASK-P0-010**（2d）：实现 AgentPersistenceEventHandler → 新增消息/任务自动持久化
3. **TASK-P0-011**（1d）：WebMCPProtocol 集成 AgentRuntimeBridge + DatabaseMemory → 修复 FP-3, FP-4, FP-5, FP-6
4. **TASK-P0-012**（1d）：WsChatController 同样集成 → WebSocket 通道闭环
5. **TASK-P1-018**（1d）：AIController 集成 Agent 框架 → AI API 通道闭环

**P0 闭环修复总工时：4.5d，P1 闭环修复：1d，合计 5.5d**