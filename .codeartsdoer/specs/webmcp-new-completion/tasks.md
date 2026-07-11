# WebMCP 新版完善 - 任务清单

## 任务概览

| 任务编号 | 任务名称 | 优先级 | 状态 | 预估工时 |
|----------|----------|--------|------|----------|
| T-001 | 前端 TinyRemoter 组件集成 | P0 | ✅ 已完成 | 1h |
| T-002 | 前端工具注册实现 | P0 | ✅ 已完成 | 1h |
| T-003 | 后端 OpenAI 兼容接口 | P0 | ✅ 已完成 | 2h |
| T-004 | 后端 MCP 协议实现 | P0 | ✅ 已完成 | 4h |
| T-005 | 前端工具调用闭环 | P1 | 🔄 进行中 | 2h |
| T-006 | 后端会话管理 | P1 | 🔄 进行中 | 2h |
| T-007 | 集成测试与验证 | P0 | ⏳ 待开始 | 2h |
| T-008 | 文档完善 | P2 | ⏳ 待开始 | 1h |
| T-009 | 用户认证机制集成 | P0 | ⏳ 待开始 | 1h |
| T-010 | llmConfig 多模型聚合配置 | P0 | ✅ 已完成 | 1h |

---

## T-001: 前端 TinyRemoter 组件集成

### 任务描述
在 App.vue 中正确配置和渲染 TinyRemoter 组件

### 验收标准
- [ ] TinyRemoter 组件正确导入
- [ ] agentRoot 配置正确指向后端 WebAgent 地址
- [ ] llmConfig 配置正确指向 OpenAI 兼容接口
- [ ] mcpServers 配置前端 MCP 服务器
- [ ] 右下角显示 AI 助手悬浮图标

### 实现步骤
1. 在 App.vue 中导入 TinyRemoter 组件
2. 配置 llmConfig 环境变量
3. 配置 mcpServers
4. 添加 TinyRemoter 模板

### 负责人
AI 自动完成

### 完成时间
2026-01-20

---

## T-002: 前端工具注册实现

### 任务描述
使用 navigator.modelContext.registerTool 注册前端工具

### 验收标准
- [ ] navigate_url 工具正确注册
- [ ] system-overview 工具正确注册
- [ ] 工具定义符合 MCP 协议规范
- [ ] 工具可在浏览器控制台查询

### 实现步骤
1. 在 App.vue onMounted 中注册工具
2. 定义工具的 name、title、description
3. 定义工具的 inputSchema
4. 实现 execute 函数

### 负责人
AI 自动完成

### 完成时间
2026-01-20

---

## T-003: 后端 OpenAI 兼容接口

### 任务描述
实现 /api/v1/ai/chat/completions 端点

### 验收标准
- [ ] 支持非流式对话请求
- [ ] 支持流式对话请求
- [ ] 返回符合 OpenAI 格式的响应
- [ ] 正确调用 SkillAwareAgent

### 实现步骤
1. 在 AIController 中添加 handleChatCompletions 方法
2. 处理 messages 参数
3. 调用 SkillAwareAgent.chat()
4. 返回流式或非流式响应

### 负责人
AI 自动完成

### 完成时间
2026-01-19

---

## T-004: 后端 MCP 协议实现

### 任务描述
实现完整的 MCP 协议支持

### 验收标准
- [ ] tools/list 方法返回工具列表
- [ ] tools/call 方法调用工具
- [ ] tools/register 方法注册前端工具
- [ ] tools/unregister 方法注销前端工具
- [ ] 工具去重，避免重复返回

### 实现步骤
1. 在 WebMCPProtocol 中实现 handleGetTools
2. 实现 handleInvokeTool 支持后端技能和前端工具
3. 实现 handleToolsRegister 和 handleToolsUnregister
4. 添加工具去重逻辑

### 负责人
AI 自动完成

### 完成时间
2026-01-19

---

## T-005: 前端工具调用闭环

### 任务描述
确保 Agent 调用的前端工具能正确执行并返回结果

### 验收标准
- [ ] Agent 能识别前端已注册的工具
- [ ] 工具调用请求能正确转发到前端
- [ ] 前端工具执行后结果能返回给 Agent
- [ ] Agent 能继续基于工具结果生成响应

### 实现步骤
1. 验证 tools/list 返回的工具包含前端工具
2. 验证 Agent 能调用前端工具
3. 验证工具执行结果能回传给 Agent
4. 验证多轮对话上下文保持

### 负责人
待分配

### 完成时间
待定

---

## T-006: 后端会话管理

### 任务描述
完善后端会话管理功能

### 验收标准
- [ ] 支持多会话并发
- [ ] 会话超时自动清理
- [ ] 会话列表查询 API
- [ ] 会话统计 API

### 实现步骤
1. 完善 SessionManager 会话管理
2. 添加会话超时清理逻辑
3. 实现 /sessions/count API
4. 实现 /sessions/list API

### 负责人
待分配

### 完成时间
待定

---

## T-007: 集成测试与验证

### 任务描述
完整测试 WebMCP 全链路功能

### 验收标准
- [ ] TinyRemoter 能正常渲染和交互
- [ ] 能与 AI 对话并获得响应
- [ ] 能调用前端工具（如 navigate_url）
- [ ] 页面能正确导航到目标 URL
- [ ] 系统概览工具能返回正确信息

### 测试用例

#### TC-001: TinyRemoter 渲染测试
```
前置条件：前端应用已启动
步骤：打开浏览器访问 http://localhost:5173
预期结果：右下角显示 AI 助手图标
```

#### TC-002: 对话功能测试
```
前置条件：TC-001 已通过
步骤：点击图标展开对话，输入"你好"
预期结果：AI 返回问候语
```

#### TC-003: 页面导航测试
```
前置条件：TC-001 已通过
步骤：输入"跳转到用户管理页面"
预期结果：页面导航到 /vue-pro/userManager/allInfo
```

#### TC-004: 系统概览测试
```
前置条件：TC-001 已通过
步骤：输入"系统有哪些功能"
预期结果：AI 返回系统功能概览
```

### 负责人
待分配

### 完成时间
待定

---

## T-008: 文档完善

### 任务描述
完善 WebMCP 相关开发文档

### 验收标准
- [ ] 更新 README.md 说明
- [ ] 添加 WebMCP 使用指南
- [ ] 记录已知问题和解决方案

### 实现步骤
1. 更新项目 README
2. 添加 WebMCP 集成指南
3. 完善错误处理文档

### 负责人
待分配

### 完成时间
待定

---

## T-009: 用户认证机制集成

### 任务描述
确保 web 端与 runtime 端对接时正确传递和解析用户认证信息，复用已有的 JWTAuthMiddleware 用户 ID 获取机制。

### 验收标准
- [ ] 前端请求携带有效的 access_token
- [ ] JWTAuthMiddleware 正确解析 Token 中的 userId
- [ ] WebMCPController 能通过 `_extractUserId()` 获取 userId
- [ ] userId 能正确传递到 WebMCPProtocol 和 Agent 上下文
- [ ] 用户菜单数据能根据 userId 正确获取并注入

### 实现步骤
1. 前端确保所有请求携带 Authorization 头
2. 验证 JWTAuthMiddleware 已正确注册到 WebMCP 相关路由
3. 确保 `_extractUserId()` 方法能从 JWT Token 解析 userId
4. 验证用户菜单数据注入机制正常工作

### 技术要点
- 后端通过 `BACKEND_URL=https://javatoarktsapi.uctoo.com` 验证 Token 有效性
- userId 获取优先级：查询参数 > 请求头 > JWT Token > 空字符串
- 用户菜单数据通过 `getUserMenuTree(userId)` 获取

### 负责人
待分配

### 完成时间
待定

---

## T-010: llmConfig 多模型聚合配置

### 任务描述
配置前端 llmConfig 指向 agentskills-runtime 的 OpenAI 兼容接口，利用 runtime 的多模型聚合能力。

### 验收标准
- [ ] llmConfig.baseURL 指向 `${AGENT_URL}/api/v1/ai/chat/completions`
- [ ] runtime 端正确配置多模型提供商（Tokendance、StepFun、MaaS、OrbitAI）
- [ ] 前端无需直接配置第三方模型 API Key
- [ ] 支持通过环境变量动态切换模型提供商

### 实现步骤
1. 配置前端 llmConfig.baseURL 指向 runtime
2. 配置 runtime 端 MODEL_PROVIDER 和对应 API Key
3. 验证模型切换功能正常

### 技术要点
- runtime 作为 OpenAI 兼容的多模型聚合网关
- 前端只需配置单一 endpoint，无需关心后端具体模型
- 通过 `MODEL_PROVIDER` 环境变量切换模型提供商

### 负责人
AI 自动完成

### 完成时间
2026-06-20

---

## 任务依赖关系

```
T-001 ─┬─> T-005
T-002 ─┘        │
                 ▼
T-003 ────> T-007
T-004 ────┘     │
                 ▼
            T-006 ──> T-008
```

---

## 完成情况统计

| 状态 | 数量 | 占比 |
|------|------|------|
| ✅ 已完成 | 4 | 50% |
| 🔄 进行中 | 2 | 25% |
| ⏳ 待开始 | 2 | 25% |
| ❌ 阻塞 | 0 | 0% |

---

## 更新记录

| 日期 | 更新内容 | 更新人 |
|------|----------|--------|
| 2026-01-20 | 创建任务清单 | AI |
| 2026-01-20 | 完成 T-001, T-002, T-003, T-004 | AI |
| 2026-06-20 | 添加 T-009, T-010 任务 | AI |
| 2026-06-20 | 添加开发规范章节（仓颉代码、数据库变更） | AI |

---

## 开发规范提醒

### 仓颉代码开发

⚠️ **重要**：如果涉及到开发仓颉代码，必须使用 `cangjie-coder` 技能。

在对话中明确说明需要编写仓颉代码，AI 会自动调用该技能，确保代码符合仓颉语言规范。

### 数据库表结构变更

⚠️ **重要**：如果涉及到新增和变更数据库表结构，必须遵循以下流程：

1. **数据库建模** → 设计表结构和 DDL 文件
2. **执行数据库变更** → 人工执行 DDL
3. **刷新数据库信息** → 调用 `/api/v1/uctoo/db_info/load-db-info`
4. **生成标准模块** → 使用 `crudgen` 和 `crudweb`
5. **迭代开发** → 在生成代码基础上扩展

详细规范请参考：`apps/agentskills-runtime/docs/uctoo-v4/uctoo-v4-module-development.md`
