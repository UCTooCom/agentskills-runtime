# API 模块重构至 APP 模块任务规划文档

## 文档信息
- **项目名称**: agentskills-runtime API 模块重构
- **版本**: 1.1.0
- **创建日期**: 2026-03-13
- **最后更新**: 2026-03-13
- **作者**: SDD Agent
- **状态**: 草稿
- **关联需求**: spec.md v1.1.0
- **关联设计**: design.md v1.2.0

## 现有代码调研结果

### 已实现功能（可复用）

#### 1. 配置加载功能 ✅ 已实现
- **位置**: `src/config/config.cj`
- **功能**: `EnvWrapper` 类支持从 .env 文件加载环境变量
- **方法**: `Config.env.load(path)` 加载 .env 文件
- **配置项**: `Config.env["KEY"]` 获取环境变量
- **复用策略**: 直接复用，无需重写

#### 2. HTTP 服务器功能 ✅ 已实现
- **位置**: `src/api/api_router.cj`
- **功能**: 完整的 HTTP 服务器实现
- **路由**: `DefaultHttpRequestDistributor` 支持静态路由和动态路由
- **复用策略**: 将路由注册逻辑迁移到 app 模块

#### 3. 技能管理 API ✅ 已实现
- **位置**: `src/api/api_router.cj`
- **功能**: 完整的技能管理 API（列表、详情、安装、更新、卸载、执行、搜索）
- **复用策略**: 将处理方法迁移到 AgentSkillsController 定制开发区域

#### 4. WebSocket 聊天功能 ✅ 已实现
- **位置**: `src/api/websocket_handler.cj`
- **功能**: 完整的 WebSocket 聊天功能
- **复用策略**: 直接复用 WebSocketChatHandler 类

#### 5. MCP 流式接口 ✅ 已实现
- **位置**: `src/api/api_router.cj` (handleMCPStream)
- **功能**: MCP 流式接口
- **复用策略**: 迁移到 McpController

#### 6. 数据库连接池 ✅ 已实现
- **位置**: `src/app/core/database/DatabaseConnection.cj`
- **功能**: DatabaseConnectionPool 和 DatabaseConfig
- **问题**: `getEnv` 方法返回 None，需要修复
- **复用策略**: 修复 getEnv 方法，复用现有代码

#### 7. Entity 模块 ✅ 已实现
- **位置**: `src/app/models/uctoo/EntityPO.cj`, `src/app/services/uctoo/EntityService.cj`
- **功能**: Entity 数据模型和服务
- **复用策略**: 作为 agent_skills 模块的参考模板

### 需要新增的功能

#### 1. AgentSkillsPO 数据模型
- 需要创建新的数据模型文件

#### 2. AgentSkillsService 服务
- 需要创建新的服务文件
- 标准 CRUD 方法（自动生成区域）
- 技能管理方法（定制开发区域，从 api_router.cj 迁移）

#### 3. AgentSkillsController 控制器
- 需要创建新的控制器文件
- 标准 CRUD 控制器方法（自动生成区域）
- 技能管理控制器方法（定制开发区域，从 api_router.cj 迁移）

#### 4. AgentSkillsRoute 路由
- 需要创建新的路由文件
- 注册 CRUD 路由和技能管理路由

#### 5. 路由路径重构
- 将 `/skills/*` 重构到 `/api/v1/uctoo/skills/*`
- 将 `/ws/chat` 重构到 `/api/v1/uctoo/ws/chat`
- 将 `/mcp/stream` 重构到 `/api/v1/uctoo/mcp/stream`

---

## 任务概述

### 任务目标
将 api 模块的已实现功能完整保留并重构到 app 模块中，**优先复用已有代码**，遵循 uctoo V4.0 三层架构设计规范。

### 任务统计
- **主任务数**: 5
- **子任务数**: 15
- **覆盖需求数**: 17 个功能需求

### 任务依赖关系
```
任务1 (修复现有代码) ──> 任务2 (数据模型) ──> 任务3 (服务层) ──> 任务4 (控制器层) ──> 任务5 (路由层与集成)
```

---

## 任务 1: 修复现有代码问题

### 任务描述
修复现有代码中的问题，确保基础设施正常工作。

### 输入
- 现有 `src/app/core/database/DatabaseConnection.cj`
- 现有 `src/config/config.cj`

### 输出
- 修复后的 DatabaseConfig.fromEnv() 方法

### 子任务

#### 1.1 修复 DatabaseConfig.fromEnv() 方法
**描述**: 修复 `getEnv` 方法返回 None 的问题，使其能正确读取环境变量。

**实现要点**:
- 修改 `src/app/core/database/DatabaseConnection.cj`
- 使用 `magic.config.Config.env["KEY"]` 替代 `getEnv("KEY")`
- 或使用 `std.env.getVariable` 获取环境变量

**验收标准**:
- [ ] DatabaseConfig.fromEnv() 能正确读取环境变量
- [ ] 数据库连接参数从 .env 文件读取

**优先级**: P0

---

## 任务 2: 数据模型层实现 ✅ 已完成

### 任务描述
创建 agent_skills 表的数据模型，参考 EntityPO 的实现方式。

### 输入
- design.md 中的数据模型设计
- agent_skills 表结构定义
- EntityPO.cj 作为参考模板

### 输出
- AgentSkillsPO 数据模型文件

### 子任务

#### 2.1 创建 AgentSkillsPO 数据模型 ✅ 已完成
**描述**: 创建 agent_skills 表的数据模型类，参考 EntityPO 的实现方式。

**实现要点**:
- 创建 `src/app/models/uctoo/AgentSkillsPO.cj`
- 参考 `src/app/models/uctoo/EntityPO.cj` 的实现方式
- 定义所有字段（id, name, description, source, source_url, version, author 等）
- 添加 `//#region AutoCreateCode` 和 `//#endregion AutoCreateCode` 标记
- 在定制开发区域添加 `toJson()` 和 `fromJson()` 方法

**验收标准**:
- [x] 所有字段正确定义
- [x] 包含自动生成区域标记
- [x] 定制开发区域包含 JSON 序列化方法

**优先级**: P0

**完成日期**: 2026-03-13

---

## 任务 3: 服务层实现 ✅ 已完成

### 任务描述
实现 AgentSkillsService 服务层，参考 EntityService 的实现方式，并将 api_router.cj 中的技能管理逻辑迁移过来。

### 输入
- design.md 中的服务层设计
- `src/api/api_router.cj` 中的技能管理逻辑
- `src/app/services/uctoo/EntityService.cj` 作为参考模板

### 输出
- AgentSkillsService 服务文件

### 子任务

#### 3.1 实现标准 CRUD 方法（自动生成区域）✅ 已完成
**描述**: 在自动生成区域实现 agent_skills 表的标准 CRUD 方法，参考 EntityService。

**实现要点**:
- 创建 `src/app/services/uctoo/AgentSkillsService.cj`
- 参考 `src/app/services/uctoo/EntityService.cj` 的实现方式
- 在 `//#region AutoCreateCode` 区域内实现：
  - `create(skill, userId)` - 创建技能记录
  - `update(skillId, skill)` - 更新技能记录
  - `delete(skillId, force)` - 删除技能记录（支持软删除）
  - `getById(skillId)` - 根据 ID 查询
  - `getList(page, limit, filter)` - 分页查询列表

**验收标准**:
- [x] CRUD 方法在自动生成区域内
- [x] 支持软删除功能
- [x] 分页查询返回正确的分页信息

**优先级**: P0

**完成日期**: 2026-03-13

#### 3.2 迁移技能管理方法（定制开发区域）✅ 已完成
**描述**: 将 api_router.cj 中的技能管理逻辑迁移到服务层定制开发区域。

**实现要点**:
- 从 `src/api/api_router.cj` 迁移以下方法：
  - `handleGetSkills` → `getRuntimeSkills(page, limit)`
  - `handleGetSkillById` → `getRuntimeSkillById(skillId)`
  - `handleAddSkill` → `installSkill(source, options)`
  - `handleEditSkill` → `updateSkillInfo(skillId, updates)`
  - `handleDeleteSkill` → `uninstallSkill(skillId)`
  - `handleExecuteSkill` → `executeSkill(skillId, params, timeout)`
  - `handleSearchSkills` → `searchSkills(query, source, limit, sort)`
- 保留原有的业务逻辑，只做架构迁移

**验收标准**:
- [x] 技能管理方法在定制开发区域内
- [x] 完整保留 api 模块的功能
- [x] 功能行为与原实现一致

**优先级**: P0

**完成日期**: 2026-03-13

---

## 任务 4: 控制器层实现 ✅ 已完成

### 任务描述
实现 AgentSkillsController 控制器，参考 EntityController 的实现方式，并将 api_router.cj 中的请求处理逻辑迁移过来。

### 输入
- design.md 中的控制器层设计
- `src/api/api_router.cj` 中的请求处理逻辑
- `src/app/controllers/uctoo/entity/EntityController.cj` 作为参考模板

### 输出
- AgentSkillsController 控制器文件
- WsChatController 控制器文件（复用现有 WebSocketChatHandler）
- McpController 控制器文件

### 子任务

#### 4.1 实现标准 CRUD 控制器方法（自动生成区域）✅ 已完成
**描述**: 在自动生成区域实现 agent_skills 表的 CRUD 控制器方法，参考 EntityController。

**实现要点**:
- 创建 `src/app/controllers/uctoo/agent_skills/AgentSkillsController.cj`
- 参考 `src/app/controllers/uctoo/entity/EntityController.cj` 的实现方式
- 在 `//#region AutoCreateCode` 区域内实现：
  - `add(req, res)` - POST /api/v1/uctoo/agent_skills/add
  - `edit(req, res)` - POST /api/v1/uctoo/agent_skills/edit
  - `delete(req, res)` - POST /api/v1/uctoo/agent_skills/del
  - `getSingle(req, res)` - GET /api/v1/uctoo/agent_skills/:id
  - `getMany(req, res)` - GET /api/v1/uctoo/agent_skills

**验收标准**:
- [x] CRUD 控制器方法在自动生成区域内
- [x] 请求参数验证完善
- [x] 响应格式符合 API 规范

**优先级**: P0

**完成日期**: 2026-03-13

#### 4.2 迁移技能管理控制器方法（定制开发区域）✅ 已完成
**描述**: 将 api_router.cj 中的技能管理请求处理逻辑迁移到控制器定制开发区域。

**实现要点**:
- 从 `src/api/api_router.cj` 迁移请求处理逻辑
- 调用 AgentSkillsService 中对应的方法
- 保持原有的请求/响应格式

**验收标准**:
- [x] 技能管理方法在定制开发区域内
- [x] 完整保留 api 模块的功能
- [x] 响应格式与原实现一致

**优先级**: P0

**完成日期**: 2026-03-13

#### 4.3 创建 WebSocket 控制器 ✅ 已完成
**描述**: 创建 WebSocket 控制器，复用现有的 WebSocketChatHandler。

**实现要点**:
- 创建 `src/app/controllers/uctoo/ws/WsChatController.cj`
- 复用 `src/api/websocket_handler.cj` 中的 `WebSocketChatHandler` 类
- 添加路由路径 `/api/v1/uctoo/ws/chat`

**验收标准**:
- [x] WebSocket 功能正常
- [x] 路由路径符合规范

**优先级**: P1

**完成日期**: 2026-03-13

#### 4.4 创建 MCP 控制器 ✅ 已完成
**描述**: 创建 MCP 控制器，迁移 api_router.cj 中的 MCP 处理逻辑。

**实现要点**:
- 创建 `src/app/controllers/uctoo/mcp/McpController.cj`
- 从 `src/api/api_router.cj` 迁移 `handleMCPStream` 逻辑
- 添加路由路径 `/api/v1/uctoo/mcp/stream`

**验收标准**:
- [x] MCP 流式接口正常
- [x] 路由路径符合规范

**优先级**: P1

**完成日期**: 2026-03-13

---

## 任务 5: 路由层实现与集成 ✅ 已完成

### 任务描述
实现所有路由注册，更新 main.cj 入口文件，完成集成测试。

### 输入
- design.md 中的路由层设计
- 控制器实现
- 现有 `src/api/api_router.cj` 的路由注册逻辑

### 输出
- AgentSkillsRoute 路由文件
- WsRoute 路由文件
- McpRoute 路由文件
- 更新后的 main.cj

### 子任务

#### 5.1 实现 agent_skills 路由 ✅ 已完成
**描述**: 实现 agent_skills 模块的路由注册，包含标准 CRUD 路由和技能管理路由。

**实现要点**:
- 创建 `src/app/routes/uctoo/agent_skills/AgentSkillsRoute.cj`
- 参考 `src/app/routes/uctoo/entity/EntityRoute.cj` 的实现方式
- 在 `//#region AutoCreateCode` 区域内注册 CRUD 路由
- 在定制开发区域注册技能管理路由（使用新路径 `/api/v1/uctoo/skills/*`）

**验收标准**:
- [x] CRUD 路由在自动生成区域内
- [x] 技能管理路由在定制开发区域内
- [x] 路由路径符合 API 规范

**优先级**: P0

**完成日期**: 2026-03-13

#### 5.2 实现 WebSocket 路由 ✅ 已完成
**描述**: 实现 WebSocket 路由注册。

**实现要点**:
- 创建 `src/app/routes/uctoo/ws/WsRoute.cj`
- 注册 WS /api/v1/uctoo/ws/chat 路由

**验收标准**:
- [x] WebSocket 路由正确注册
- [x] 路由路径符合 API 规范

**优先级**: P1

**完成日期**: 2026-03-13

#### 5.3 实现 MCP 路由 ✅ 已完成
**描述**: 实现 MCP 路由注册。

**实现要点**:
- 创建 `src/app/routes/uctoo/mcp/McpRoute.cj`
- 注册 GET /api/v1/uctoo/mcp/stream 路由

**验收标准**:
- [x] MCP 路由正确注册
- [x] 路由路径符合 API 规范

**优先级**: P1

**完成日期**: 2026-03-13

#### 5.4 更新 main.cj 入口文件
**描述**: 更新应用入口文件，复用 api/main.cj 的初始化逻辑。

**实现要点**:
- 修改 `src/app/main.cj`
- 复用 `src/api/main.cj` 的配置加载逻辑
- 复用 `src/api/api_router.cj` 的初始化逻辑
- 注册所有新路由
- 保留 /hello 健康检查路由
- 添加 /api/v1/health 和 /api/v1/info 路由

**验收标准**:
- [ ] 所有配置从 .env 读取
- [ ] 所有路由正确注册
- [ ] 服务启动正常
- [ ] 健康检查路由正常工作

**优先级**: P0

#### 5.5 集成测试与验证
**描述**: 进行集成测试，验证所有功能正常工作。

**测试要点**:
- 验证配置加载功能
- 验证 agent_skills CRUD 功能
- 验证技能管理 API 功能
- 验证 WebSocket 功能
- 验证 MCP 功能
- 验证 API 路由重构

**验收标准**:
- [ ] 所有功能正常工作
- [ ] 与 api 模块功能一致

**优先级**: P0

---

## 附录

### A. 文件创建清单

| 序号 | 文件路径 | 所属任务 | 说明 |
|------|---------|---------|------|
| 1 | src/app/models/uctoo/AgentSkillsPO.cj | 任务 2.1 | 新建 |
| 2 | src/app/services/uctoo/AgentSkillsService.cj | 任务 3 | 新建 |
| 3 | src/app/controllers/uctoo/agent_skills/AgentSkillsController.cj | 任务 4.1, 4.2 | 新建 |
| 4 | src/app/controllers/uctoo/ws/WsChatController.cj | 任务 4.3 | 新建 |
| 5 | src/app/controllers/uctoo/mcp/McpController.cj | 任务 4.4 | 新建 |
| 6 | src/app/routes/uctoo/agent_skills/AgentSkillsRoute.cj | 任务 5.1 | 新建 |
| 7 | src/app/routes/uctoo/ws/WsRoute.cj | 任务 5.2 | 新建 |
| 8 | src/app/routes/uctoo/mcp/McpRoute.cj | 任务 5.3 | 新建 |

### B. 文件修改清单

| 序号 | 文件路径 | 所属任务 | 说明 |
|------|---------|---------|------|
| 1 | src/app/core/database/DatabaseConnection.cj | 任务 1.1 | 修复 getEnv 方法 |
| 2 | src/app/main.cj | 任务 5.4 | 注册新路由，初始化配置 |

### C. 代码复用清单

| 序号 | 源文件 | 复用内容 | 目标位置 |
|------|--------|---------|---------|
| 1 | src/config/config.cj | EnvWrapper, Config.env | 直接复用 |
| 2 | src/api/api_router.cj | 技能管理业务逻辑 | AgentSkillsService |
| 3 | src/api/api_router.cj | 请求处理逻辑 | AgentSkillsController |
| 4 | src/api/websocket_handler.cj | WebSocketChatHandler | WsChatController |
| 5 | src/api/api_router.cj | handleMCPStream | McpController |
| 6 | src/api/api_router.cj | DefaultHttpRequestDistributor | 直接复用 |
| 7 | src/app/models/uctoo/EntityPO.cj | 模型结构 | AgentSkillsPO 参考 |
| 8 | src/app/services/uctoo/EntityService.cj | 服务结构 | AgentSkillsService 参考 |
| 9 | src/app/controllers/uctoo/entity/EntityController.cj | 控制器结构 | AgentSkillsController 参考 |
| 10 | src/app/routes/uctoo/entity/EntityRoute.cj | 路由结构 | AgentSkillsRoute 参考 |

### D. 变更历史
| 版本 | 日期 | 作者 | 变更说明 |
|------|------|------|----------|
| 1.0  | 2026-03-13 | SDD Agent | 初始版本 |
| 1.1  | 2026-03-13 | SDD Agent | 基于现有代码调研，优化任务规划，优先复用已有代码 |
