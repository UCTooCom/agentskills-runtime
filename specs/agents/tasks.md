# Agent 动态生成与多 Agent 协作系统 - 编码任务

> 基于 design.md v1.0.0 技术设计文档  
> 项目路径: `apps/agentskills-runtime`  
> 生成时间: 2026-05-30  
> 更新时间: 2026-05-30

---

## 🔄 开发流程说明

本任务规划采用**里程碑式开发流程**：

```
阶段1：数据库模型设计与迁移（自动化）
    ↓
里程碑1：数据库迁移脚本完成 ✅
    ↓
阶段2：核心组件实现（自动化）
    ↓
里程碑2：核心组件开发完成
    ↓
阶段3：API与CLI接口开发（自动化）
    ↓
里程碑3：接口开发完成
    ↓
阶段4：编译验证与集成测试（自动化）
```

**关键约定**：
- crudgen 生成的代码写在 `//#region AutoCreateCode` 区域内
- 增量开发代码写在 `//#endregion AutoCreateCode` 之外的区域
- 所有日志输出统一使用 `magic.log.LogUtils`

---

## 1. 数据库迁移脚本（已完成）

- [x] **1.1 创建数据库迁移脚本**  
  已创建 `scripts/migration/agent_system_v1.sql`，包含：  
  - agents 表（Agent 定义）
  - agent_contexts 表（上下文管理）
  - agent_tasks 表（任务管理）
  - agent_messages 表（消息记录）
  涉及文件: `scripts/migration/agent_system_v1.sql`（新增）  

---

## 2. CRUD 模块生成（已完成）

- [x] **2.1 使用 crudgen 生成四个表的 CRUD 模块**  
  - agents → AgentPO/AgentDAO/AgentService/AgentController/AgentRoute
  - agent_contexts → AgentContextPO/AgentContextDAO/AgentContextService/AgentContextController/AgentContextRoute
  - agent_tasks → AgentTaskPO/AgentTaskDAO/AgentTaskService/AgentTaskController/AgentTaskRoute
  - agent_messages → AgentMessagePO/AgentMessageDAO/AgentMessageService/AgentMessageController/AgentMessageRoute

---

## 3. 路由配置（已完成）

- [x] **3.1 在 AutoRouteConfig.cj 中注册四个表的路由**  
  在 `initRegistry()` 方法中添加 agents、agent_contexts、agent_tasks、agent_messages 的路由注册

---

## 4. 核心组件实现

### 4.1 AgentLoader 组件

- [x] **4.1.1 新增 AgentLoader 类**  
  实现从 AGENTS.md 文件和目录加载 Agent 定义：  
  - `loadAgentsMd(filePath: String): Array<AgentDefinition>`
  - `loadFromDirectory(dirPath: String): Array<AgentDefinition>`
  - `parseFromMarkdown(content: String, source: String): AgentDefinition`  
  验收：能正确解析 YAML frontmatter，提取 Agent 元数据  
  涉及文件: `src/app/services/agent/AgentLoader.cj`（新增）  
  预估复杂度: 高  

### 4.2 AgentFactory 组件

- [x] **4.2.1 新增 AgentFactory 类**  
  实现根据定义创建 Agent 实例：  
  - `create(definition: AgentDefinition): AgentInstance`
  - `createAll(definitions: Array<AgentDefinition>): Array<AgentInstance>`  
  验收：能根据定义正确创建 Agent 实例并初始化上下文  
  涉及文件: `src/app/services/agent/AgentFactory.cj`（新增）  
  预估复杂度: 中  

### 4.3 AgentLifecycleManager 组件

- [x] **4.3.1 新增 AgentStatus 枚举**  
  定义 Agent 状态：Stopped、Running、Paused  
  涉及文件: `src/app/services/agent/AgentStatus.cj`（新增）  

- [x] **4.3.2 新增 AgentLifecycleManager 类**  
  实现生命周期管理：  
  - `start(agentId: String): Unit`
  - `stop(agentId: String): Unit`
  - `pause(agentId: String): Unit`
  - `resume(agentId: String): Unit`
  - `getStatus(agentId: String): AgentStatus`  
  验收：状态转换正确，启动/停止/暂停/恢复操作正常  
  涉及文件: `src/app/services/agent/AgentLifecycleManager.cj`（新增）  
  预估复杂度: 中  

### 4.4 AgentContextManager 组件

- [x] **4.4.1 新增 AgentContextManager 类**  
  实现上下文管理：  
  - `getContext(agentId: String): AgentContext`
  - `updateContext(agentId: String, messages: Array<Message>): Unit`
  - `clearContext(agentId: String): Unit`
  - `saveContext(agentId: String, context: AgentContext): Unit`  
  验收：上下文能正确持久化和恢复  
  涉及文件: `src/app/services/agent/AgentContextManager.cj`（新增）  
  预估复杂度: 中  

### 4.5 CollaborationService 组件

- [x] **4.5.1 新增 CollaborationService 类**  
  实现 Agent 协作协调：  
  - `assignTask(mainAgentId: String, subAgentIds: Array<String>, task: Task): Unit`
  - `publishMessage(senderId: String, receiverId: String, message: Message): Unit`
  - `collectResults(taskId: String): Array<TaskResult>`
  - `createCollaboration(collabDef: CollaborationDefinition): Collaboration`  
  验收：支持链式、并行、分层三种协作模式  
  涉及文件: `src/app/services/agent/CollaborationService.cj`（新增）  
  预估复杂度: 高  

### 4.6 AgentManager 主控制器

- [x] **4.6.1 新增 AgentManager 类**  
  整合所有 Agent 管理组件：  
  - `initialize(): Unit` - 初始化所有组件
  - `loadAgents(): Unit` - 从文件和数据库加载 Agent
  - `startAll(): Unit` - 启动所有 Agent
  - `stopAll(): Unit` - 停止所有 Agent
  - `getAgent(agentId: String): Option<AgentInstance>`
  - `getAllAgents(): Array<AgentInstance>`  
  验收：应用启动时能正确初始化和加载所有 Agent  
  涉及文件: `src/app/services/agent/AgentManager.cj`（新增）  
  预估复杂度: 高  

---

## 5. Application 启动集成

- [x] **5.1 修改 Application 类集成 AgentManager**  
  在 `src/app/main.cj` 的 Application 类中：  
  - 新增成员变量 `private var agentManager: AgentManager`
  - init() 中新增 `AgentManager.initialize()`（在 setupRoutes 之后）
  - 日志输出使用 `LogUtils.info("Application", "AgentManager initialized")`  
  验收：应用启动后 AgentManager 单例可获取，AGENTS.md 中的主 Agent 被正确加载  
  涉及文件: `src/app/main.cj`（修改）  
  预估复杂度: 中  

---

## 6. 服务层增强

### 6.1 AgentService 增强

- [x] **6.1.1 增强 AgentService 生命周期方法**  
  在 `AgentService.cj` 的 `//#endregion AutoCreateCode` 之后追加：  
  - `startAgent(agentId: String, userId: String): APIResult<Unit>`
  - `stopAgent(agentId: String, userId: String): APIResult<Unit>`
  - `pauseAgent(agentId: String, userId: String): APIResult<Unit>`
  - `resumeAgent(agentId: String, userId: String): APIResult<Unit>`
  - `getAgentStatus(agentId: String): APIResult<AgentStatus>`  
  验收：生命周期操作受权限保护，状态正确更新  
  涉及文件: `src/app/services/uctoo/AgentService.cj`（修改）  
  预估复杂度: 中  

### 6.2 AgentTaskService 增强

- [x] **6.2.1 增强 AgentTaskService 任务分配方法**  
  在 `AgentTaskService.cj` 的 `//#endregion AutoCreateCode` 之后追加：  
  - `assignTask(agentId: String, task: TaskPayload, userId: String): APIResult<AgentTaskPO>`
  - `getAgentTasks(agentId: String, status: Option<Int32>): APIResult<Array<AgentTaskPO>>`  
  验收：任务能正确分配给指定 Agent  
  涉及文件: `src/app/services/uctoo/AgentTaskService.cj`（修改）  
  预估复杂度: 中  

---

## 7. 控制器层增强

### 7.1 AgentController 增强

- [x] **7.1.1 增强 AgentController 生命周期接口**  
  在 `AgentController.cj` 的 `//#endregion AutoCreateCode` 之后追加：  
  - `start(req, res): POST /api/v1/uctoo/agent/:id/start`
  - `stop(req, res): POST /api/v1/uctoo/agent/:id/stop`
  - `pause(req, res): POST /api/v1/uctoo/agent/:id/pause`
  - `resume(req, res): POST /api/v1/uctoo/agent/:id/resume`
  - `status(req, res): GET /api/v1/uctoo/agent/:id/status`  
  所有接口受 JWT 认证 + RBAC 权限保护  
  验收：所有新增 API 可正确响应  
  涉及文件: `src/app/controllers/uctoo/agent/AgentController.cj`（修改）  
  预估复杂度: 中  

### 7.2 AgentRoute 增强

- [x] **7.2.1 增强 AgentRoute 注册生命周期路由**  
  在 `AgentRoute.cj` 的 `registerCustomRoutes()` 中注册新增路由：  
  - start, stop, pause, resume, status  
  验收：所有新增路由可通过 HTTP 请求正确访问  
  涉及文件: `src/app/routes/uctoo/agent/AgentRoute.cj`（修改）  
  预估复杂度: 低  

### 7.3 协作接口

- [x] **7.3.1 新增 CollaborationController**  
  实现协作相关 API：  
  - `create(req, res): POST /api/v1/uctoo/agent/collaborate`
  - `list(req, res): GET /api/v1/uctoo/agent/collaborations`
  - `detail(req, res): GET /api/v1/uctoo/agent/collaboration/:id`  
  验收：协作任务能正确创建和查询  
  涉及文件: `src/app/controllers/uctoo/agent/CollaborationController.cj`（新增）  
  预估复杂度: 中  

- [x] **7.3.2 新增 CollaborationRoute**  
  注册协作接口路由  
  涉及文件: `src/app/routes/uctoo/agent/CollaborationRoute.cj`（新增）  
  预估复杂度: 低  

---

## 8. CLI 命令实现

- [x] **8.1 新增 AgentCLI 命令处理器**  
  实现 `AgentCLI` 类：  
  - `createCommand`: 创建 Agent
  - `listCommand`: 列出所有 Agent
  - `showCommand`: 显示 Agent 详情
  - `updateCommand`: 更新 Agent
  - `deleteCommand`: 删除 Agent
  - `startCommand`: 启动 Agent
  - `stopCommand`: 停止 Agent
  - `pauseCommand`: 暂停 Agent
  - `resumeCommand`: 恢复 Agent
  - `taskCommand`: 任务管理子命令
  - `collaborateCommand`: 协作管理子命令  
  验收：所有 CLI 子命令可正确执行并输出格式化结果  
  涉及文件: `src/cli/agent_cli.cj`（新增）  
  预估复杂度: 高  

- [x] **8.2 修改 SkillCLI 集成 agent 子命令**  
  在 `SkillCLI.executeCommand()` 的 match 中新增：  
  - `case "agent" => executeAgentCommand(subArgs)`  
  - 新增 `executeAgentCommand()` 方法，委托 `AgentCLI.execute()`  
  验收：`skill agent list` 命令可正确输出 Agent 列表  
  涉及文件: `src/cli/skill_cli.cj`（修改）  
  预估复杂度: 低  

---

## 9. 权限系统集成

- [x] **9.1 创建 Agent 用户组**  
  在数据库初始化时创建：  
  - `agents` 用户组（主 Agent）: agent:read, agent:write, agent:execute
  - `subagents` 用户组（子 Agent）: agent:read, agent:execute  
  涉及文件: `scripts/migration/agent_system_v1.sql`（已包含）  

- [x] **9.2 增强 AgentService 用户创建逻辑**  
  在创建 Agent 时自动：  
  - 创建对应用户账号 (username = "agent_${agentId}")
  - 根据 Agent 类型加入对应用户组
  - 分配默认权限  
  验收：Agent 创建后自动完成用户和权限配置  
  涉及文件: `src/app/services/uctoo/AgentService.cj`（修改）  
  预估复杂度: 中  

---

## 10. 编译验证与集成测试

- [x] **10.1 编译验证**  
  执行 `cjpm build` 确保所有新增和修改文件编译通过  
  验收：`cjpm build` 成功，无错误输出  
  涉及文件: 全部新增和修改文件  

- [ ] **10.2 Agent 系统启动验证**  
  启动应用，验证：  
  - AgentManager 初始化成功
  - AGENTS.md 中的主 Agent 被正确加载
  - Agent 生命周期操作正常  
  验收：Agent 系统可正常初始化和运行  

- [ ] **10.3 端到端功能验证**  
  验证完整功能闭环：  
  - 创建 Agent → 启动 → 分配任务 → 执行 → 结果汇总
  - 协作模式验证（链式、并行、分层）
  - CLI 命令完整可用  
  验收：所有核心能力场景验证通过  

---

## 任务依赖关系图

```
阶段1（已完成）：
  1.1 → 2.1 → 3.1

阶段2（核心组件）：
  4.1.1 → 4.2.1 → 4.3.1 → 4.3.2
  4.4.1 → 4.5.1 → 4.6.1 → 5.1

阶段3（API与CLI）：
  4.6.1 → 6.1.1 → 7.1.1 → 7.2.1
  6.2.1 → 7.3.1 → 7.3.2
  4.6.1 → 8.1 → 8.2
  9.1 → 9.2

阶段4（验证）：
  全部 → 10.1 → 10.2 → 10.3
```

---

## 需求覆盖追踪

| design.md 核心能力 | 对应任务 | 覆盖状态 |
|-------------------|----------|----------|
| AgentLoader 加载 AGENTS.md | 4.1.1, 5.1 | ✅ |
| AgentFactory 创建实例 | 4.2.1 | ✅ |
| AgentLifecycleManager 生命周期管理 | 4.3.1, 4.3.2, 6.1.1, 7.1.1 | ✅ |
| AgentContextManager 上下文管理 | 4.4.1 | ✅ |
| CollaborationService 协作协调 | 4.5.1, 7.3.1 | ✅ |
| AgentManager 主控制器 | 4.6.1, 5.1 | ✅ |
| HTTP API 接口 | 6.1.1, 6.2.1, 7.1.1, 7.2.1, 7.3.1, 7.3.2 | ✅ |
| CLI 命令行管理 | 8.1, 8.2 | ✅ |
| 权限系统集成 | 9.1, 9.2 | ✅ |

---

## 日志基础设施约定

本项目中所有日志输出统一使用 `magic.log.LogUtils`：

```cangjie
import magic.log.LogUtils

// 使用方式（第一个参数为标签，通常为类名）
LogUtils.info("AgentManager", "初始化 AgentManager...")
LogUtils.info("AgentLoader", "加载 AGENTS.md: ${filePath}")
LogUtils.error("AgentFactory", "创建 Agent 失败: ${e.message}")
LogUtils.warn("AgentLifecycleManager", "Agent ${agentId} 状态异常")
LogUtils.debug("CollaborationService", "分配任务: ${taskId}")
```