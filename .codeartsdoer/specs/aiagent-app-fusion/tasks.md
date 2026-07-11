# 编码任务规划：AIAgent 框架与 App 层全栈有机融合

## 文档信息
- **项目名称**: agentskills-runtime 全栈有机融合
- **版本**: 1.0.0
- **创建日期**: 2026-06-05
- **基于设计**: design.md v1.0.0
- **基于规格**: spec.md v1.1.0
- **作者**: UCToo
- **状态**: 待执行

## 开发流程规范

### 通用模块开发流程（必须遵循）

1. **数据库建模**：根据业务需求设计表结构 DDL 文件
2. **人工执行 DDL**：在 PostgreSQL 中执行数据库结构新增和变更
3. **刷新 db_info**：调用 `/api/v1/uctoo/db_info/load-db-info` 接口刷新数据库元信息
4. **crudgen 生成后端 CRUD**：使用 `crudgen` 生成新增表的标准 CRUD 模块（PO/DAO/Service/Controller/Route）
5. **crudweb 生成前端 CRUD**：使用 `crudweb` 生成 Web 项目中的数据库表管理界面
6. **迭代开发**：在生成的标准模块基础上进行二次迭代开发

### 仓颉代码编写规范（必须遵循）

- **使用 cangjie-coder 技能**：所有 .cj 文件必须使用 cangjie-coder 技能编写
- **四步工作流程**：查阅文档 → 检索代码片段 → 编辑适配 → 写入文件
- **必须检索已有代码**：编写前必须检索到确定的已有代码作为编程依据，禁止凭空生成
- **仓颉语法规范**：package/import/class/interface/prop/泛型/Option/match/spawn/注解

### 确定性生成 vs AI 生成

| 类型 | 方式 | 适用 |
|------|------|------|
| 数据库 DDL | 人工编写 + 执行 | 所有新增表 |
| 标准 CRUD 五层 | crudgen 确定性生成 | 9 个新增实体 |
| 前端 CRUD 页面 | crudweb 确定性生成 | 9 个新增实体 |
| Bridge/融合逻辑 | cangjie-coder + AI 辅助 | AgentRuntimeBridge/DatabaseMemory 等 |
| 能力开放 Controller | cangjie-coder + AI 辅助 | ExecutorController/ModelController 等 |
| 前端增强页面 | 手动 + AI 辅助 | 监控仪表板/Token Dashboard 等 |

---

## P0 阶段：核心基础（13 人天）

> **实现状态说明**：TASK-P0-001~008 的代码实现已完成，但运行时集成未完成（标注为 ⚠️）。新增 TASK-P0-009~012 为数据流闭环集成任务，优先级最高。

### TASK-P0-001: 数据库 DDL — P0 阶段表结构 ✅已完成

**类型**: 数据库
**工时**: 0.5d
**依赖**: 无
**产出**: `docs/sql/v4_fusion_p0.sql`

**任务**:
1. 编写 DDL 文件，包含以下表：
   - `agent_memories` — Agent 记忆持久化（含 embedding_vector VECTOR(1536)）
   - `llm_usage_logs` — LLM 调用 Token 记录（追加-only）
   - `model_pricing` — 模型费率配置
2. 包含 `CREATE EXTENSION IF NOT EXISTS vector;`（pgvector 扩展）
3. 包含索引定义（agent_id、provider+model、created_at 等）
4. 在 PostgreSQL 中执行 DDL
5. 调用 `/api/v1/uctoo/db_info/load-db-info` 刷新元信息

**验收标准**:
- [ ] 3 张表在数据库中创建成功
- [ ] db_info 表包含新表的元信息
- [ ] pgvector 扩展已启用

---

### TASK-P0-002: crudgen 生成 AgentMemories CRUD 五层 ✅已完成

**类型**: 后端（确定性生成）
**工时**: 0.5d
**依赖**: TASK-P0-001
**产出**: 5 个文件

**任务**:
1. 使用 crudgen 为 `agent_memories` 表生成标准 CRUD 模块：
   - `models/uctoo/AgentMemoriesPO.cj`
   - `dao/uctoo/AgentMemoriesDAO.cj`
   - `services/uctoo/AgentMemoriesService.cj`
   - `controllers/uctoo/agent_memories/AgentMemoriesController.cj`
   - `routes/uctoo/agent_memories/AgentMemoriesRoute.cj`
2. 验证路由注册和 CRUD API 可用

**验收标准**:
- [ ] 5 个文件生成成功
- [ ] `POST /api/v1/uctoo/agent_memories/add` 可用
- [ ] `GET /api/v1/uctoo/agent_memories/:limit/:page` 可用

---

### TASK-P0-003: crudgen 生成 LlmUsageLogs CRUD 五层 ✅已完成

**类型**: 后端（确定性生成）
**工时**: 0.5d
**依赖**: TASK-P0-001
**产出**: 5 个文件

**任务**:
1. 使用 crudgen 为 `llm_usage_logs` 表生成标准 CRUD 模块
2. 验证路由注册和 CRUD API 可用

**验收标准**:
- [ ] 5 个文件生成成功
- [ ] CRUD API 全部可用

---

### TASK-P0-004: crudgen 生成 ModelPricing CRUD 五层 + 费率预置 ✅已完成

**类型**: 后端（确定性生成 + 数据预置）
**工时**: 1d
**依赖**: TASK-P0-001
**产出**: 5 个文件 + 费率数据 SQL

**任务**:
1. 使用 crudgen 为 `model_pricing` 表生成标准 CRUD 模块
2. 编写费率预置 SQL（18 个提供商的主流模型费率，参考 design.md 5.2 节）
3. 执行费率预置 SQL

**验收标准**:
- [ ] 5 个文件生成成功
- [ ] model_pricing 表包含 18 个提供商的费率数据
- [ ] 本地模型（ollama/llamacpp）费率为 0

---

### TASK-P0-005: AgentRuntimeBridge 实现 ⚠️代码完成，集成缺失

**类型**: 后端（cangjie-coder）
**工时**: 3d
**依赖**: 无
**产出**: `src/app/services/bridge/AgentRuntimeBridge.cj`

**任务**:
1. **检索已有代码**：读取 AgentsPO.cj、AgentsService.cj、BaseAgent.cj、AgentLoadManager.cj 的字段和方法
2. **编写 AgentRuntimeBridge**（使用 cangjie-coder 技能）：
   - `createRuntimeAgent(definition: AgentDefinition): APIResult<BaseAgent>` — 从 AgentDefinition 创建运行时 Agent
   - `syncToDatabase(agent: BaseAgent): Unit` — 异步同步运行时状态到数据库
   - `loadFromDatabase(agentId: String): APIResult<BaseAgent>` — 从数据库加载并重建运行时实例
   - `loadAllFromDatabase(): ArrayList<BaseAgent>` — 批量加载
   - `updateRuntimeState(agentId: String, state: String): Unit` — 更新运行时状态
   - `getRuntimeAgent(agentId: String): Option<BaseAgent>` — 获取内存中的运行时实例
   - `removeRuntimeAgent(agentId: String): Unit` — 移除运行时实例
3. **AgentDefinition ↔ AgentsPO 字段映射**：name/agentType/model/tools/systemPrompt/maxTurns/memory/background/permissions
4. **降级模式**：桥接失败时 Agent 仍可在内存中执行
5. **单例模式**：`private static var instance_` + `public static prop instance`
6. **EventHandlerManager 集成**：注册 AgentStartEvent/AgentEndEvent 处理器自动同步状态

**验收标准**:
- [ ] AgentRuntimeBridge 编译通过
- [ ] createRuntimeAgent 正确创建内存 Agent 并写入数据库
- [ ] syncToDatabase 异步更新数据库 status 字段
- [ ] loadFromDatabase 从数据库重建运行时实例
- [ ] 降级模式：数据库不可用时仍可创建内存 Agent

---

### TASK-P0-006: DatabaseMemory + TieredMemory 实现 ⚠️代码完成，集成缺失

**类型**: 后端（cangjie-coder）
**工时**: 3d
**依赖**: TASK-P0-002, TASK-P0-005
**产出**: 2 个文件

**任务**:
1. **检索已有代码**：读取 Memory 接口、ShortMemory.cj、InMemoryVectorDatabase.cj、EmbeddingModel 接口
2. **编写 DatabaseMemory**（实现 Memory 接口）：
   - `update(segment: MemorySegment): Unit` — 写入 agent_memories 表 + 生成嵌入向量
   - `search(question: String, topK: Int64): ArrayList<MemorySegment>` — 向量相似度检索
   - `clear(): Unit` — 清除记忆
3. **编写 TieredMemory**（双层缓存）：
   - 写入时同时写入 ShortMemory（内存）和 DatabaseMemory（数据库）
   - 检索时优先从 ShortMemory 检索，miss 时从 DatabaseMemory 加载
   - 结果去重合并
4. **嵌入向量生成**：复用 ModelManager.createEmbeddingModel() 生成向量

**验收标准**:
- [ ] DatabaseMemory 编译通过且实现 Memory 接口
- [ ] update 写入数据库且生成嵌入向量
- [ ] search 从数据库执行向量相似度检索
- [ ] TieredMemory 双层缓存正确工作
- [ ] 进程重启后记忆不丢失

---

### TASK-P0-007: BillingEventHandler 事件集成 ⚠️代码完成，注册缺失

**类型**: 后端（cangjie-coder）
**工时**: 1d
**依赖**: TASK-P0-003, TASK-P0-004
**产出**: `src/app/services/billing/BillingEventHandler.cj`

**任务**:
1. **检索已有代码**：读取 EventHandlerManager.cj、ChatModelEndEvent、ChatModelFailureEvent、AgentEndEvent
2. **编写 BillingEventHandler**：
   - 注册 ChatModelEndEvent 处理器：将 ChatUsage 写入 llm_usage_logs 表
   - 注册 ChatModelFailureEvent 处理器：记录失败调用
   - 注册 AgentEndEvent 处理器：汇总 Agent 总 token 消耗
   - 计费计算：查询 model_pricing 表获取费率，计算 cost_amount
3. **异步执行**：spawn {} 不阻塞主流程

**验收标准**:
- [ ] 每次 LLM 调用后 ChatUsage 正确写入 llm_usage_logs
- [ ] 计费金额按费率正确计算
- [ ] 事件处理异步执行，不阻塞 LLM 调用

---

### TASK-P0-008: WebMCP 调用链修复 ⚠️部分完成

**类型**: 前端 + 后端
**工时**: 3d
**依赖**: 无
**产出**: 修复 WebMCPController + FrontendToolAdapter

**任务**:
1. **定位 bug**：读取 WebMCPController.cj、FrontendToolAdapter.cj、WsChatController.cj
2. **修复 WebMCP Server 工具注册和调用的已知 bug**
3. **验证 Agent → WebMCP → 前端工具 → 结果返回完整调用链**
4. **新增 Agent 专用工具**：web_navigate、web_notify、web_request_approval

**验收标准**:
- [ ] Agent 可通过 WebMcpClient 调用前端注册的 entity CRUD 工具
- [ ] 前端工具执行结果通过 WebMCP 协议正确返回给 Agent
- [ ] web_navigate/web_notify/web_request_approval 工具可用

---

### TASK-P0-009: main.cj 全局事件处理器注册 🔴最高优先级

**类型**: 后端（cangjie-coder）
**工时**: 0.5d
**依赖**: TASK-P0-007（代码已完成）
**产出**: `src/app/main.cj` 修改
**对应需求**: REQ-FLOW-002

**任务**:
1. **检索已有代码**：读取 main.cj 的 init() 和 setupRoutes() 方法
2. **在 setupRoutes() 末尾添加全局事件处理器注册**：
   - `BillingEventHandler().registerGlobalHandlers()` — 注册 ChatModelEndEvent/ChatModelFailureEvent/AgentEndEvent 处理器
   - `QuotaCheckHandler().registerGlobalHandlers()` — 注册 ChatModelStartEvent 配额检查处理器
   - `WebSocketEventBridge.instance.registerGlobalHandlers()` — 注册 9 种 WebSocket 事件处理器
3. **添加 import 语句**：
   - `import magic.app.services.billing.BillingEventHandler`
   - `import magic.app.services.billing.QuotaCheckHandler`
   - `import magic.app.services.bridge.WebSocketEventBridge`
4. **在 init() 中添加 AgentRuntimeBridge 预加载**：
   - `AgentRuntimeBridge.instance.loadAllFromDatabase()`
5. **注册失败时输出告警日志，不阻塞应用启动**

**验收标准**:
- [ ] 应用启动后 `EventHandlerManager.global` 中已注册 ChatModelEndEvent 处理器
- [ ] 应用启动后 `EventHandlerManager.global` 中已注册 ChatModelStartEvent 处理器
- [ ] 应用启动后 `EventHandlerManager.global` 中已注册 AgentStartEvent/AgentEndEvent 处理器
- [ ] 应用启动后 WebSocket 事件桥接处理器已注册
- [ ] 启动日志包含 "BillingEventHandler registered" 和 "WebSocketEventBridge registered"
- [ ] 注册失败时应用仍可正常启动

---

### TASK-P0-010: AgentPersistenceEventHandler 实现 + 注册 🔴最高优先级

**类型**: 后端（cangjie-coder）
**工时**: 2d
**依赖**: TASK-P0-009
**产出**: `src/app/services/bridge/agent_persistence_event_handler.cj` + main.cj 修改
**对应需求**: REQ-FLOW-004

**任务**:
1. **检索已有代码**：读取 EventHandlerManager.cj、AgentTasksPO.cj、AgentTasksService.cj、AgentMessagesPO.cj、AgentMessagesService.cj、CheckpointManager.cj
2. **编写 AgentPersistenceEventHandler**：
   - `registerGlobalHandlers()` — 注册到 EventHandlerManager.global
   - `onAgentStart(event: AgentStartEvent)` — 创建 agent_tasks 记录（status=running）
   - `onChatModelEnd(event: ChatModelEndEvent)` — 写入 agent_messages（助手响应）
   - `onAgentEnd(event: AgentEndEvent)` — 更新 agent_tasks（status=completed）+ 写入 agent_messages + 调用 CheckpointManager.saveCheckpoint()
3. **在 main.cj 中注册**：`AgentPersistenceEventHandler().registerGlobalHandlers()`
4. **所有写入异步执行**：spawn {} 不阻塞主流程

**验收标准**:
- [ ] AgentStartEvent 触发后 agent_tasks 表有新记录（status=running）
- [ ] ChatModelEndEvent 触发后 agent_messages 表有助手响应记录
- [ ] AgentEndEvent 触发后 agent_tasks 表状态更新为 completed
- [ ] AgentEndEvent 触发后 agent_contexts 表有检查点记录
- [ ] 所有写入异步执行，不阻塞 Agent 执行主流程

---

### TASK-P0-011: WebMCPProtocol 集成 AgentRuntimeBridge + DatabaseMemory 🔴最高优先级

**类型**: 后端（cangjie-coder）
**工时**: 1d
**依赖**: TASK-P0-009, TASK-P0-010
**产出**: `src/app/services/webmcp/WebMCPProtocol.cj` 修改
**对应需求**: REQ-FLOW-003

**任务**:
1. **检索已有代码**：读取 WebMCPProtocol.cj 的 init() 和 handleCompletionComplete()
2. **修改 Agent 创建方式**（init() 第 36-44 行）：
   - 为 SkillAwareAgent 传入 `memory` 参数：`TieredMemory(ShortMemory(), DatabaseMemory(agentId, scope: "episodic"))`
   - 为 SkillAwareAgent 传入 `eventHandlerManager` 参数：`EventHandlerManager.global`
3. **修改 handleCompletionComplete()**（第 488-491 行）：
   - 在 `agent.chat()` 前写入用户消息到 agent_messages
   - 在 `agent.chat()` 后调用 `AgentRuntimeBridge.instance.syncToDatabase()`
4. **修复降级路径**（第 492-497 行）：
   - 直接 ChatModel.create() 前后手动触发 ChatModelStartEvent/ChatModelEndEvent

**验收标准**:
- [ ] WebMCP 聊天后 llm_usage_logs 表有新记录
- [ ] WebMCP 聊天后 agent_memories 表有新记录（Agent 使用记忆时）
- [ ] WebMCP 聊天后 agent_contexts 表有新记录
- [ ] WebMCP 聊天后 agent_messages 表有用户消息和助手响应记录
- [ ] WebMCP 聊天后 agent_tasks 表有执行记录
- [ ] WebMCP 聊天后 agents 表状态更新
- [ ] 降级路径也能触发计费事件
- [ ] 数据写入不阻塞聊天响应返回

---

### TASK-P0-012: WsChatController 集成 AgentRuntimeBridge + DatabaseMemory 🔴最高优先级

**类型**: 后端（cangjie-coder）
**工时**: 1d
**依赖**: TASK-P0-009, TASK-P0-010
**产出**: `src/app/controllers/uctoo/ws/WsChatController.cj` 修改
**对应需求**: REQ-FLOW-003

**任务**:
1. **检索已有代码**：读取 WsChatController.cj 的 init() 和 _handleChatMessage()
2. **修改 Agent 创建方式**（init() 第 43-50 行）：
   - 为 SkillAwareAgent 传入 `memory` 参数
   - 为 SkillAwareAgent 传入 `eventHandlerManager` 参数
3. **修改 _handleChatMessage()**（第 177-211 行）：
   - 在 `agent.chat()` 前写入用户消息到 agent_messages
   - 在 `agent.chat()` 后调用 `AgentRuntimeBridge.instance.syncToDatabase()`

**验收标准**:
- [ ] WebSocket 聊天后 llm_usage_logs 表有新记录
- [ ] WebSocket 聊天后 agent_memories 表有新记录
- [ ] WebSocket 聊天后 agent_contexts 表有新记录
- [ ] WebSocket 聊天后 agent_messages 表有记录
- [ ] WebSocket 聊天后 agent_tasks 表有记录
- [ ] 数据写入不阻塞 WebSocket 响应

---

## P1 阶段：能力扩展（24 人天）

> **实现状态说明**：P1 阶段部分任务代码已完成但集成缺失。新增 TASK-P1-018 为 AIController 数据流闭环任务。

### TASK-P1-001: 数据库 DDL — P1 阶段表结构 ✅已完成

**类型**: 数据库
**工时**: 0.5d
**依赖**: TASK-P0-001
**产出**: `docs/sql/v4_fusion_p1.sql`

**任务**:
1. 编写 DDL 文件，包含：
   - `agent_groups` — Agent 协作组定义
   - `agent_executors` — 执行策略配置
   - `retrievers` — RAG 检索器定义
2. 执行 DDL + 刷新 db_info

---

### TASK-P1-002: crudgen 生成 AgentGroups CRUD 五层 ✅已完成

**类型**: 后端（确定性生成）
**工时**: 0.5d
**依赖**: TASK-P1-001

---

### TASK-P1-003: crudgen 生成 AgentExecutors CRUD 五层 + 预置策略 ✅已完成

**类型**: 后端（确定性生成 + 数据预置）
**工时**: 1d
**依赖**: TASK-P1-001

**任务**:
1. crudgen 生成 CRUD 五层
2. 预置 5 种执行策略配置（naive/react/plan-react/tool-loop/dsl）

---

### TASK-P1-004: crudgen 生成 Retrievers CRUD 五层 ✅已完成

**类型**: 后端（确定性生成）
**工时**: 0.5d
**依赖**: TASK-P1-001

---

### TASK-P1-005: AgentExecutionExecutor 实现

**类型**: 后端（cangjie-coder）
**工时**: 2d
**依赖**: TASK-P0-005

**任务**:
1. **检索已有代码**：读取 CrontabExecutor 接口、SchedulerEngine.cj、ExecutorRegistry.cj
2. **编写 AgentExecutionExecutor**（实现 CrontabExecutor 接口）：
   - 从 AgentTasks 加载任务定义
   - 通过 AgentRuntimeBridge 创建运行时 Agent
   - 执行 Agent 并将结果写入 AgentTasks
   - 执行进度通过 EventStream → WebSocket 推送
3. **注册到 ExecutorRegistry**：`executorRegistry.register("agent_execution", AgentExecutionExecutor)`

---

### TASK-P1-006: 检查点机制实现

**类型**: 后端（cangjie-coder）
**工时**: 2d
**依赖**: TASK-P1-005

**任务**:
1. **检索已有代码**：读取 AgentContextsPO.cj、AgentContextsService.cj
2. **实现检查点保存**：每完成一个步骤，将当前对话上下文保存到 AgentContexts
3. **实现检查点恢复**：任务中断后从最新检查点继续执行

---

### TASK-P1-007: WebSocketEventBridge 实现 ⚠️代码完成，注册缺失

**类型**: 后端（cangjie-coder）
**工时**: 2d
**依赖**: TASK-P0-005

**任务**:
1. **检索已有代码**：读取 EventHandlerManager.cj、WsChatController.cj、所有 13 种事件类型
2. **编写 WebSocketEventBridge**：
   - 注册为 EventHandlerManager.global 的全局处理器
   - 将 Agent 事件转换为 WebSocket 消息推送
   - 事件映射：AgentStart→agent_start, AgentStep→agent_step, ToolCallStart→tool_call_start 等
3. **复用 WsChatController 的 WebSocket 端点**

---

### TASK-P1-008: AgentGroup 执行与状态查询

**类型**: 后端（cangjie-coder）
**工时**: 2d
**依赖**: TASK-P1-002, TASK-P0-005

**任务**:
1. **检索已有代码**：读取 LeaderGroup.cj、LinearGroup.cj、FreeGroup.cj、AutoDiscussGroup.cj、RoundRobinDiscussGroup.cj
2. **在 AgentGroupsController 中添加定制方法**：
   - `execute(req, res)` — 触发 AgentGroup 执行
   - `getStatus(req, res)` — 查询执行状态
   - `addMember(req, res)` / `removeMember(req, res)` — 管理成员
3. **AgentGroup 类型映射**：leader→LeaderGroup, linear→LinearGroup, free→FreeGroup 等

---

### TASK-P1-009: ExecutorController — 执行策略 API

**类型**: 后端（cangjie-coder）
**工时**: 1d
**依赖**: TASK-P1-003

**任务**:
1. **检索已有代码**：读取 AgentExecutorManager.cj、各 Executor 实现
2. **编写 ExecutorController**：
   - `list` — 返回所有已注册执行策略
   - `getByName` — 查询指定策略详情和配置参数
   - `add/edit` — 配置执行策略参数

---

### TASK-P1-010: AgentGroupController 扩展 — 协作模式与 DSL API

**类型**: 后端（cangjie-coder）
**工时**: 2d
**依赖**: TASK-P1-008

**任务**:
1. **检索已有代码**：读取 AgentGroup DSL 操作符（<=/|/管道）、DiscussGroup.cj
2. **添加定制 Controller 方法**：
   - `discuss(req, res)` — 发起讨论（FreeGroup/AutoDiscuss/RoundRobin）
   - `compose(req, res)` — 声明式组合创建（LeaderGroup/LinearGroup/FreeGroup）

---

### TASK-P1-011: MemoryController — 记忆操作 API

**类型**: 后端（cangjie-coder）
**工时**: 1d
**依赖**: TASK-P0-006

**任务**:
1. **检索已有代码**：读取 DatabaseMemory.cj、TieredMemory.cj
2. **编写 MemoryController**：
   - `update` — POST /api/v1/uctoo/agents/{id}/memory/update
   - `search` — POST /api/v1/uctoo/agents/{id}/memory/search
   - `list` — GET /api/v1/uctoo/agents/{id}/memory
   - `delete` — DELETE /api/v1/uctoo/agents/{id}/memory/{memoryId}

---

### TASK-P1-012: ModelController — 模型管理 API

**类型**: 后端（cangjie-coder）
**工时**: 1d
**依赖**: 无

**任务**:
1. **检索已有代码**：读取 ModelManager.cj、ModelConfig struct、各 ChatModel 实现
2. **编写 ModelController**：
   - `list` — 返回所有已注册模型提供商
   - `register` — 动态注册新模型提供商
   - `test` — 测试模型连通性

---

### TASK-P1-013: RetrieverController — RAG 检索器 API

**类型**: 后端（cangjie-coder）
**工时**: 1d
**依赖**: TASK-P1-004

**任务**:
1. **检索已有代码**：读取 Retriever 接口、MarkdownRetriever.cj、SqliteRetriever.cj
2. **编写 RetrieverController**：
   - CRUD 端点 + `search` 端点

---

### TASK-P1-014: Token 统计 API + 仪表板页面

**类型**: 后端 + 前端
**工时**: 3d
**依赖**: TASK-P0-003, TASK-P0-004

**任务**:
1. **后端统计 API**（cangjie-coder）：
   - `GET /api/v1/uctoo/llm-usage/summary` — 总量汇总
   - `GET /api/v1/uctoo/llm-usage/by-agent` — 按 Agent 维度
   - `GET /api/v1/uctoo/llm-usage/by-model` — 按模型维度
   - `GET /api/v1/uctoo/llm-usage/by-date` — 按时间维度
   - `GET /api/v1/uctoo/llm-usage/trends` — 趋势数据
2. **前端仪表板页面**：`views/ai/token-dashboard.vue`
   - 概览卡片、趋势图、分布饼图、Agent 排行榜、费率表

---

### TASK-P1-015: pinia-orm 全栈生成集成

**类型**: 前端 + 后端
**工时**: 2d
**依赖**: TASK-P0-005

**任务**:
1. **增强 crudweb**：从 db_info 读取表结构，自动生成 pinia-orm 模型文件
2. **全栈生成命令**：`crudgen --table <name> --full-stack` 同时生成后端 CRUD + 前端 ORM 模型 + 前端 CRUD 页面
3. **为 P0 阶段 3 张表生成前端 CRUD 页面**

---

### TASK-P1-016: TinyRobot Agent 集成

**类型**: 前端
**工时**: 2d
**依赖**: TASK-P0-008, TASK-P1-007

**任务**:
1. **对话自动关联 Agent**：每次对话创建或关联 Agent 实例，历史持久化到 agent_contexts
2. **多 Agent 切换**：模型切换下拉框增加 Agent 选择
3. **子 Agent 可视化**：子 Agent 执行时显示嵌套卡片，进度实时更新

---

### TASK-P1-017: EventHandlerManager 计费集成完善 ⚠️代码完成，注册缺失

**类型**: 后端（cangjie-coder）
**工时**: 1d
**依赖**: TASK-P0-007

**任务**:
1. 完善 AgentEndEvent 处理器：汇总该 Agent 本次执行总 token 消耗，更新 AgentTasks
2. 确保所有 18 个模型提供商的 usage 正确解析

---

### TASK-P1-018: AIController 集成 Agent 框架 🔴高优先级

**类型**: 后端（cangjie-coder）
**工时**: 1d
**依赖**: TASK-P0-009
**产出**: `src/app/controllers/uctoo/ai/AIController.cj` 修改
**对应需求**: REQ-FLOW-005

**任务**:
1. **检索已有代码**：读取 AIController.cj 的 chat() 和 streamChat() 方法
2. **修改非流式聊天**（第 138-145 行）：
   - 优先通过 SkillAwareAgent.chat() 调用 LLM（触发事件系统）
   - 降级：直接 ChatModel.create() 时手动触发 ChatModelStartEvent/ChatModelEndEvent
3. **修改流式聊天**（第 150-197 行）：
   - 同上，优先通过 Agent 调用
   - 降级时手动触发事件
4. **确保 AI API 聊天后 llm_usage_logs 有数据**

**验收标准**:
- [ ] AI API 聊天请求触发 ChatModelStartEvent/ChatModelEndEvent
- [ ] AI API 聊天后 llm_usage_logs 表有新记录
- [ ] 降级模式仍可正常返回响应
- [ ] 流式聊天同样触发事件

---

## P2 阶段：增强功能（22 人天）

### TASK-P2-001: 数据库 DDL — P2 阶段表结构

**类型**: 数据库
**工时**: 0.5d
**依赖**: TASK-P1-001

**任务**: agent_approvals + usage_quotas + event_handlers 三张表 DDL + 执行 + 刷新 db_info

---

### TASK-P2-002: crudgen 生成 AgentApprovals CRUD 五层

**类型**: 后端（确定性生成）
**工时**: 0.5d
**依赖**: TASK-P2-001

---

### TASK-P2-003: crudgen 生成 UsageQuotas CRUD 五层

**类型**: 后端（确定性生成）
**工时**: 0.5d
**依赖**: TASK-P2-001

---

### TASK-P2-004: crudgen 生成 EventHandlers CRUD 五层

**类型**: 后端（确定性生成）
**工时**: 0.5d
**依赖**: TASK-P2-001

---

### TASK-P2-005: 记忆分层存储实现

**类型**: 后端（cangjie-coder）
**工时**: 2d
**依赖**: TASK-P0-006

**任务**:
1. 实现 4 层记忆存储：working(AgentContexts) / episodic(agent_memories) / semantic(agent_memories,高权重) / procedural(agent_memories,tag=procedural)
2. 各层记忆可独立检索和清理

---

### TASK-P2-006: WebHumanAgent 实现

**类型**: 后端（cangjie-coder）
**工时**: 2d
**依赖**: TASK-P1-007, TASK-P2-002

**任务**:
1. **检索已有代码**：读取 HumanAgent.cj
2. **编写 WebHumanAgent**（继承 HumanAgent）：
   - 通过 WebSocket 等待用户输入（而非控制台）
   - 支持审批操作（确认/拒绝/修改建议）
   - 审批记录持久化到 agent_approvals 表

---

### TASK-P2-007: SkillAsAgent + 组合融合

**类型**: 后端（cangjie-coder）
**工时**: 3d
**依赖**: TASK-P0-005, TASK-P1-002

**任务**:
1. **检索已有代码**：读取 SkillToToolAdapter.cj、BaseAgent.cj、AgentGroup DSL
2. **编写 SkillAsAgent**（继承 BaseAgent）：systemPrompt 为 SKILL.md 正文，tools 为技能声明的工具
3. **组合映射**：串行→LinearGroup, 并行→LeaderGroup, 评估-改进→自定义 Group
4. **组合执行结果写入 AgentTasks**

---

### TASK-P2-008: Agent 监控仪表板 API + 页面

**类型**: 后端 + 前端
**工时**: 3d
**依赖**: TASK-P1-002, TASK-P1-007

**任务**:
1. **后端 Dashboard API**：活跃 Agent 数、类型分布、执行任务、协作拓扑、记忆统计、错误率、Token 消耗
2. **前端页面**：`views/ai/agent-monitor.vue`（WebSocket 驱动实时更新）

---

### TASK-P2-009: Agent 详情 + 历史页面

**类型**: 前端
**工时**: 2d
**依赖**: TASK-P2-008

**任务**: `views/ai/agent-detail.vue` — 配置详情、执行历史时间线、对话、记忆、权限审批

---

### TASK-P2-010: 配额检查 + 周期重置

**类型**: 后端（cangjie-coder）
**工时**: 2d
**依赖**: TASK-P2-003

**任务**:
1. LLM 调用前检查配额（硬限制拒绝/软限制告警）
2. Crontab 定时任务每日/每月重置 quota_used

---

### TASK-P2-011: 计费报表 + 导出

**类型**: 后端 + 前端
**工时**: 2d
**依赖**: TASK-P1-014

**任务**:
1. 日报/月报 API
2. XLSX/CSV 导出
3. 前端 `views/ai/billing-report.vue`

---

### TASK-P2-012: EventHandlers CRUD + Controller

**类型**: 后端（cangjie-coder）
**工时**: 1d
**依赖**: TASK-P2-004

**任务**: 事件处理器注册/注销/历史查询 API

---

### TASK-P2-013: StorageController — 存储系统 API

**类型**: 后端（cangjie-coder）
**工时**: 1d
**依赖**: 无

**任务**:
1. **检索已有代码**：读取 JsonKVStorage.cj、InMemoryVectorDatabase.cj、BaseGraph.cj
2. **编写 StorageController**：KV/Vector/Graph 操作 API

---

### TASK-P2-014: SkillValidationController — 技能验证 API

**类型**: 后端（cangjie-coder）
**工时**: 1d
**依赖**: 无

**任务**:
1. **检索已有代码**：读取 StandardSkillValidator.cj、SkillExecutionEngine.cj、SecurityManager.cj
2. **编写 SkillValidationController**：validate/validate-security/execute-secure 端点

---

### TASK-P2-015: 技能统一管理页面增强

**类型**: 前端
**工时**: 1d
**依赖**: TASK-P0-008

**任务**: 增强 `views/ai/agent_skills.vue`，显示技能来源（browser-side/server-side）

---

### TASK-P2-016: API 契约验证

**类型**: 前端
**工时**: 1d
**依赖**: TASK-P1-015

**任务**: 启动时自动校验前端模型字段与后端 API 响应字段一致性

---

### TASK-P2-017: 执行策略运行时切换

**类型**: 后端（cangjie-coder）
**工时**: 1d
**依赖**: TASK-P1-009

**任务**: 通过 API 动态切换运行中 Agent 的执行策略

---

### TASK-P2-018: P2 阶段前端 CRUD 页面生成

**类型**: 前端（确定性生成）
**工时**: 1d
**依赖**: TASK-P2-001, TASK-P1-015

**任务**: 使用 crudweb 为 agent_approvals/usage_quotas/event_handlers 生成前端 CRUD 页面

---

## P3 阶段：可观测性（4 人天）

### TASK-P3-001: 全链路可观测时间线页面

**类型**: 前端
**工时**: 2d
**依赖**: TASK-P2-008

**任务**: `views/database/uctoo/observability.vue` — 时间线 + 数据流可视化 + 数据资产仪表板

---

### TASK-P3-002: 数据流可视化 + 数据资产仪表板

**类型**: 前端
**工时**: 2d
**依赖**: TASK-P3-001

**任务**: 文件→数据库同步流、数据库→前端数据流、Agent→工具→结果流可视化

---

## 任务统计

| 阶段 | 任务数 | 数据库 | 确定性生成 | cangjie-coder | 前端 | 合计工时 | 已完成 | 集成缺失 |
|------|--------|--------|-----------|--------------|------|---------|--------|---------|
| P0 | 12 | 1 | 3 | 7 | 1 | 18d | 4 | 4+4新增 |
| P1 | 18 | 1 | 3 | 9 | 3 | 25d | 4 | 多项+1新增 |
| P2 | 18 | 1 | 4 | 8 | 5 | 22d | 0 | - |
| P3 | 2 | 0 | 0 | 0 | 2 | 4d | 0 | - |
| **合计** | **50** | **3** | **10** | **24** | **11** | **69d** | **8** | **多项** |

### 数据流闭环专项任务（P0 阶段新增）

| 任务编号 | 任务名称 | 工时 | 优先级 | 对应需求 |
|---------|---------|------|--------|---------|
| TASK-P0-009 | main.cj 全局事件处理器注册 | 0.5d | 🔴最高 | REQ-FLOW-002 |
| TASK-P0-010 | AgentPersistenceEventHandler 实现+注册 | 2d | 🔴最高 | REQ-FLOW-004 |
| TASK-P0-011 | WebMCPProtocol 集成 AgentRuntimeBridge+DatabaseMemory | 1d | 🔴最高 | REQ-FLOW-003 |
| TASK-P0-012 | WsChatController 集成 AgentRuntimeBridge+DatabaseMemory | 1d | 🔴最高 | REQ-FLOW-003 |
| TASK-P1-018 | AIController 集成 Agent 框架 | 1d | 🔴高 | REQ-FLOW-005 |
| **合计** | **5 个闭环任务** | **5.5d** | - | - |

## 依赖关系总览

```
P0:
  TASK-P0-001 (DDL) ✅ ──→ TASK-P0-002 (crudgen AgentMemories) ✅
                       ──→ TASK-P0-003 (crudgen LlmUsageLogs) ✅
                       ──→ TASK-P0-004 (crudgen ModelPricing) ✅
  TASK-P0-005 (AgentRuntimeBridge) ⚠️ ──→ TASK-P0-006 (DatabaseMemory) ⚠️
  TASK-P0-003 + TASK-P0-004 ──→ TASK-P0-007 (BillingEventHandler) ⚠️
  TASK-P0-008 (WebMCP修复) ⚠️ — 独立
  
  🔴 数据流闭环任务（最高优先级）：
  TASK-P0-007 ──→ TASK-P0-009 (main.cj注册) ──→ TASK-P0-010 (AgentPersistenceEventHandler)
  TASK-P0-009 + TASK-P0-010 ──→ TASK-P0-011 (WebMCPProtocol集成)
  TASK-P0-009 + TASK-P0-010 ──→ TASK-P0-012 (WsChatController集成)

P1:
  TASK-P0-001 ──→ TASK-P1-001 (DDL) ✅ ──→ TASK-P1-002/003/004 (crudgen) ✅
  TASK-P0-005 ──→ TASK-P1-005 (AgentExecutionExecutor) ──→ TASK-P1-006 (检查点)
  TASK-P0-005 ──→ TASK-P1-007 (WebSocketEventBridge) ⚠️
  TASK-P1-002 + TASK-P0-005 ──→ TASK-P1-008 (AgentGroup执行) ──→ TASK-P1-010 (discuss/compose)
  TASK-P1-003 ──→ TASK-P1-009 (ExecutorController)
  TASK-P0-006 ──→ TASK-P1-011 (MemoryController)
  TASK-P1-004 ──→ TASK-P1-013 (RetrieverController)
  TASK-P0-003 + TASK-P0-004 ──→ TASK-P1-014 (Token统计+仪表板)
  TASK-P0-005 ──→ TASK-P1-015 (全栈生成)
  TASK-P0-008 + TASK-P1-007 ──→ TASK-P1-016 (TinyRobot集成)
  TASK-P0-007 ──→ TASK-P1-017 (计费集成完善) ⚠️
  
  🔴 AI API 闭环任务：
  TASK-P0-009 ──→ TASK-P1-018 (AIController集成)

P2:
  TASK-P1-001 ──→ TASK-P2-001 (DDL) ──→ TASK-P2-002/003/004 (crudgen)
  TASK-P0-006 ──→ TASK-P2-005 (记忆分层)
  TASK-P1-007 + TASK-P2-002 ──→ TASK-P2-006 (WebHumanAgent)
  TASK-P0-005 + TASK-P1-002 ──→ TASK-P2-007 (SkillAsAgent)
  TASK-P1-002 + TASK-P1-007 ──→ TASK-P2-008 (Dashboard) ──→ TASK-P2-009 (详情页)
  TASK-P2-003 ──→ TASK-P2-010 (配额)
  TASK-P1-014 ──→ TASK-P2-011 (报表)
  TASK-P2-004 ──→ TASK-P2-012 (EventHandler API)

P3:
  TASK-P2-008 ──→ TASK-P3-001 ──→ TASK-P3-002
```

## 数据流闭环验证清单

修复完成后，应按以下清单验证数据闭环：

- [ ] **V1**：启动应用后，日志包含 "BillingEventHandler registered" 和 "WebSocketEventBridge registered"
- [ ] **V2**：通过 WebMCP 聊天发送消息后，`llm_usage_logs` 表有新记录
- [ ] **V3**：通过 WebMCP 聊天发送消息后，`agent_contexts` 表有新记录
- [ ] **V4**：通过 WebMCP 聊天发送消息后，`agent_messages` 表有用户消息和助手响应记录
- [ ] **V5**：通过 WebMCP 聊天发送消息后，`agent_tasks` 表有新记录
- [ ] **V6**：通过 WebMCP 聊天发送消息后，`agent_memories` 表有新记录（Agent 使用记忆时）
- [ ] **V7**：通过 WebMCP 聊天发送消息后，`agents` 表状态更新
- [ ] **V8**：通过 WebSocket 聊天发送消息后，上述表同样有数据
- [ ] **V9**：通过 AI API 聊天发送消息后，`llm_usage_logs` 表有新记录
- [ ] **V10**：前端 Token 仪表板页面能正确显示用量数据
- [ ] **V11**：前端 Agent 监控页面能正确显示 Agent 状态
- [ ] **V12**：WebSocket 事件能推送到前端（agent_start/agent_end/tool_call 等）
- [ ] **V13**：配额超限时能正确拒绝或告警
- [ ] **V14**：数据库不可用时聊天仍可正常进行（降级模式）

## 变更历史
| 版本 | 日期 | 作者 | 变更说明 |
|------|------|------|----------|
| 1.0.0 | 2026-06-05 | weiyoho | 初始版本，基于 design.md v1.0.0 创建 |
| 1.1.0 | 2026-06-09 | weiyoho | 补充数据流闭环集成任务 TASK-P0-009~012、TASK-P1-018，标注已完成/缺失状态，添加验证清单 |