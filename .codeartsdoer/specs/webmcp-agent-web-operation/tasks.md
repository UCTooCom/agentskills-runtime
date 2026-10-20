# Agent 操作 Web 应用链路闭环 —— 任务清单

## 任务概览

| 任务编号 | 任务名称 | 优先级 | 状态 | 预估工时 |
|---|---|---|---|---|
| T-001 | 排查 "Empty request body" 根因 | P0 | ⏳ 待开始 | 4h |
| T-002 | 选定并打通指令下行通道 | P0 | ⏳ 待开始 | 8h |
| T-003 | 前端统一工具执行器 | P0 | ⏳ 待开始 | 6h |
| T-004 | 前端工具注册体系改造 | P0 | ⏳ 待开始 | 4h |
| T-005 | 工具注册上报后端验证 | P0 | ⏳ 待开始 | 3h |
| T-006 | PageTool 接入 | P1 | ⏳ 待开始 | 6h |
| T-007 | 业务工具与 SKILL.md 落地（验收 Demo） | P1 | ⏳ 待开始 | 8h |
| T-008 | WebSkills 装载链路 | P1 | ⏳ 待开始 | 4h |
| T-009 | 后端内置工具收敛 | P1 | ⏳ 待开始 | 3h |
| T-010 | 端到端集成测试与验收 | P0 | ⏳ 待开始 | 6h |
| T-011 | GenUI 与 tiny-robot 版本评估 | P2 | ⏳ 待开始 | 4h |
| T-012 | `src/mcp-servers/` 迁移计划 | P2 | ⏳ 待开始 | 2h |

---

## T-001: 排查 "Empty request body" 根因

### 任务描述

定位 v19 记录的 "Empty request body" 问题根因。该问题导致 `connectSSE(sessionId)` 被移除，
是断点 1 的直接来源。必须先定位根因，才能判断换通道是否真能规避。

### 背景线索（`src/App.vue` 注释原文）

```
connectSSE 创建 EventSource 长连接，占用浏览器 fetch 的 keep-alive 连接池，
后续 _chatViaWebMCP 的 fetch 创建的新连接请求体在传输过程中丢失
→ 后端 req.body.size = 0 → 400 "Empty request body"。
```

### 验收标准

- [ ] 明确根因是浏览器侧（连接池/请求体丢失）还是后端侧（请求体读取时序）
- [ ] 输出根因结论文档，含复现步骤与验证方法
- [ ] 结论能明确回答"复用已有 MCP 连接是否可规避该问题"

### 实现步骤

1. 复现：建立 EventSource 后立即发起 chat POST，抓包确认请求体是否真的为空
2. 区分：用 curl 直连后端发同样的 POST，排除后端读取问题
3. 若属后端：检查 `handleStreamableHttp` 的请求体读取时序
4. 若属浏览器：确认是否为 HTTP/1.1 连接数上限导致，验证换用已有连接能否规避
5. 输出根因结论，作为 T-002 选型依据

### 负责人
待分配

### 完成时间
待定

---

## T-002: 选定并打通指令下行通道

### 任务描述

按 `design.md` 决策 1，选定通道并打通后端到前端的 tool_call 下行。
建议先按 B2（MCP 通知下推 + `/tool-result` 回传）落地，闭环验证后再评估 B1。

### 验收标准

- [ ] 后端 `WebMCPToolHelper` 的出口改为可切换的传输抽象
- [ ] tool_call 能通过会话已建立的连接下推到前端
- [ ] 浏览器不新增长连接（DevTools Network 中可见）
- [ ] 通道不可用时返回明确错误，不静默失败
- [ ] 原有 SSE 实现保留为可回退选项

### 实现步骤

1. 在 `magic.tool.webmcp` 包新增 `ToolCallTransport` 抽象（仓颉代码用 cangjie-coder 技能）
2. 实现 `SSETransport`（包装现有 `SSEConnectionManager`）
3. 实现 `McpTransport`（复用会话已建立的 MCP 连接）
4. `WebMCPToolHelper` 改为持有 transport，按会话可用性选择
5. 前端在 MCP 连接上注册 `tool_call` 消息处理，转交执行器
6. 联调验证指令可达

### 技术要点

- 新增类放 `magic.tool.webmcp` 包，不得 import `magic.app.services.webmcp`（避免循环依赖）
- callId 仍由后端生成，格式保持 `call_{timestamp}_{random8位}`
- 前端需能区分"MCP 响应的流事件"与"tool_call 指令"

### 负责人
待分配

### 完成时间
待定

---

## T-003: 前端统一工具执行器

### 任务描述

新建 `src/webmcp/tool-executor.ts`，作为 tool_call 的唯一执行入口，
替代当前"App.vue 广播 postMessage、无人认领"的实现。

### 验收标准

- [ ] 收到 tool_call 后能查到 descriptor 并调用 `executeTool`
- [ ] 工具不存在时回传"未找到工具"错误，不静默丢弃
- [ ] 路由不符时自动跳转或回传 `ROUTE_REQUIRED`
- [ ] 执行异常/超时（30s）都能回传 error，后端能解除阻塞
- [ ] `ApprovalOptionsCard.vue` 改为由执行器分发，不再直接监听 tool_call
- [ ] 并发多个 callId 互不干扰

### 实现步骤

1. 建 `src/webmcp/` 目录：`tool-executor.ts` / `tool-registry.ts` / `result-reporter.ts`
2. 实现查工具 → 路由检查 → 执行 → 回传的主流程
3. 实现超时与异常捕获
4. 改造 `App.vue`：移除 `window.postMessage` 广播，改为调用执行器
5. 改造 `ApprovalOptionsCard.vue`：改为被动接收执行器的审批请求
6. 单元/集成测试覆盖：未知工具、超时、异常、并发

### 技术要点

- `executeTool` 调用：`modelContext.executeTool(descriptor, JSON.stringify(args))`
- 回传：`POST {AGENT_URL}/api/v1/uctoo/webmcp/tool-result`，body `{callId, result}` 或 `{callId, error}`

### 负责人
待分配

### 完成时间
待定

---

## T-004: 前端工具注册体系改造

### 任务描述

把现有 3 个应用级工具（`get_skill_content` / `navigate_url` / `system-overview`）
从 `App.vue` 的 `onMounted` 迁出，改为 `main.ts` 中在 `createApp` 之前注册，
并统一封装为 `document.modelContext.registerTool`。

### 验收标准

- [ ] `main.ts` 中初始化顺序为 `initializeBuiltinWebMCP()` → `registerAppTools()` → `createApp`
- [ ] 3 个应用级工具注册成功，控制台 `modelContext.listTools()` 可见
- [ ] 提供 `registerPageTool` 封装，页面级工具可随 `onUnmounted` 注销
- [ ] 不再新增 `src/mcp-servers/` 风格的 `server.registerTool` 注册

### 实现步骤

1. 抽出 `src/webmcp/tool-registry.ts`，封装 registerTool / listTools / onToolChange
2. 抽出 `src/webmcp/app-tools.ts`，迁移 3 个应用级工具
3. `main.ts` 调整初始化顺序
4. 提供页面级注册示例（供 T-007 使用）

### 负责人
待分配

### 完成时间
待定

---

## T-005: 工具注册上报后端验证

### 任务描述

验证前端 `document.modelContext.registerTool` 注册的工具能通过 MCP `tools/register`
同步到后端 `FrontendToolRegistry` 与 Agent ToolManager。

### 验收标准

- [ ] 前端注册工具后，后端日志出现 "Registered frontend tool to registry"
- [ ] 后端日志出现 "Synced frontend tool to Agent ToolManager"
- [ ] 后端 `tools/list` 返回的工具中包含前端工具
- [ ] 页面卸载（工具注销）后，后端同步移除
- [ ] 若当前 WebMcpClient 代理模式未自动上报，补齐显式上报逻辑

### 实现步骤

1. 启动前后端，注册工具后抓后端日志
2. 若未上报，检查 `WebMcpClient({agent:true})` 是否在 toolchange 时上报
3. 未自动上报则在 `onToolChange` 回调中显式调用 `tools/register`
4. 验证注销同步

### 负责人
待分配

### 完成时间
待定

---

## T-006: PageTool 接入

### 任务描述

接入 PageTool，使 Agent 能对未适配 WebMCP 的页面做元素查询、滚动定位、导航点击。

### 前置依赖

需先盘点 vendored `next-sdk` 是否提供 `initializeBuiltinWebMCP` / `registerPageAgentTool`。
若缺失，从官方 `0.4.11` 移植。

### 验收标准

- [ ] `main.ts` 在 `createApp` 前完成 `initializeBuiltinWebMCP()` 与 `registerPageAgentTool()`
- [ ] 黑名单包含对话框自身（`.chat-add-window` / `.chat-add-launcher` / `.tr-sender` / `.tr-bubble`）
- [ ] `data-page-tool-id` / `data-page-tool-action` 在 a11yConfig.exposedAttributes 中
- [ ] 未开放 `fill` / `select` / `executeJavascript` 与提交/删除/发布/支付类动作
- [ ] PageTool 初始化失败不阻塞应用启动

### 实现步骤

1. 盘点 vendored next-sdk 的 PageTool API 可用性
2. 缺失则从官方 0.4.11 移植到 `src/lib/webmcp-sdk/packages/next-sdk/`
3. 建 `src/webmcp/pagetool-init.ts`
4. `main.ts` 接入初始化
5. 验证 PageTool 工具在 modelContext 中可见

### 负责人
待分配

### 完成时间
待定

---

## T-007: 业务工具与 SKILL.md 落地（验收 Demo）

### 任务描述

选一个真实业务页面（建议 `entity` 或订单类），注册业务工具、标注 PageTool 标记、
编写 SKILL.md，作为端到端验收场景。

### 验收标准

- [ ] 页面注册至少 2 个业务工具（列表查询 + 详情查询）
- [ ] 工具复用页面现有状态，执行后同步页面筛选条件（AI 回答与页面看到同一份数据）
- [ ] 工具在 `onMounted` 注册、`onUnmounted` 用 AbortController 注销
- [ ] 页面元素标注：容器 `query`、列表 `navigation`、侧边导航 `navigation`
- [ ] `src/skills/<业务名>/SKILL.md` 含 frontmatter 与"适用范围/可用工具/参数规则/工具选择"四段
- [ ] SKILL.md 中声明的页面目标与页面实际标注完全一致
- [ ] 明确写出"工具不可用时不得虚构结果"

### 实现步骤

1. 选定业务页面与工具清单
2. 注册业务工具（页面级）
3. 标注 `data-page-tool-*` 属性
4. 编写 SKILL.md
5. 补充路由前置条件处理（`ROUTE_REQUIRED`）

### 负责人
待分配

### 完成时间
待定

---

## T-008: WebSkills 装载链路

### 任务描述

把 `src/skills/**/SKILL.md` 装载进对话，让模型知道业务工具怎么用。

### 验收标准

- [ ] 应用启动时加载全部 SKILL.md
- [ ] 若 `loadSkillWithDetails` / `skillPlugin` 可用，走官方装载方式
- [ ] 若不可用，退化为 SKILL.md 原文注入 system prompt，并明确记录该降级
- [ ] 模型回答符合 SKILL.md 中的参数规则与工具选择约束

### 实现步骤

1. 确认 `@opentiny/tiny-robot-kit@0.5.1` 是否导出 `loadSkillWithDetails` / `skillPlugin`
2. 确认 vendored `next-sdk` 是否导出 `getMainSkillPaths` / `getSkillMdContent`
3. 可用则按参考实现装载；不可用则实现降级注入
4. 验证模型行为

### 负责人
待分配

### 完成时间
待定

---

## T-009: 后端内置工具收敛

### 任务描述

`web_navigate` / `web_notify` / `web_request_approval` 与前端工具统一走同一链路，
并在前端标准工具就绪后标记 deprecated。

### 验收标准

- [ ] 后端内置工具与前端工具使用相同的下行/上行链路与 callId 匹配
- [ ] `navigate_url` 前端工具可用后，`web_navigate` 标记 deprecated
- [ ] 审批工具仍保留（需权限校验与用户确认，不能由 PageTool 承担）

### 实现步骤

1. 验证内置工具是否与 T-002 的新通道兼容
2. 前端 `navigate_url` 就绪后标记 `web_navigate` deprecated
3. 更新相关文档

### 负责人
待分配

### 完成时间
待定

---

## T-010: 端到端集成测试与验收

### 任务描述

用 T-007 的业务场景做完整验收，重点验证"业务工具 + PageTool 组合"路径。

### 测试用例

#### TC-001: 同页面业务工具调用
```
前置条件：已停留在目标业务页面
步骤：对话输入"帮我查询 entity 表的前 10 条数据"
预期结果：Agent 调用业务工具 → 前端执行 → 回传结果 → Agent 用真实数据回答
```

#### TC-002: 跨页面自动导航（关键验收项）
```
前置条件：停留在非目标页面
步骤：对话输入"帮我查询 entity 表的前 10 条数据"
预期结果：业务工具返回 ROUTE_REQUIRED → Agent 用 PageTool 点击侧边导航
        → 进入目标页 → 重试业务工具 → 成功返回数据
```

#### TC-003: 未知工具错误处理
```
前置条件：目标页面已卸载
步骤：调用该页面的页面级工具
预期结果：回传"未找到工具"错误，Agent 提示用户，30s 内解除阻塞（不超时）
```

#### TC-004: 通道断开
```
前置条件：手动断开传输连接
步骤：调用前端工具
预期结果：返回"前端连接不可用"错误，不静默失败、不无限阻塞
```

#### TC-005: 并发调用
```
前置条件：正常运行
步骤：一次对话中触发 3 个不同工具调用
预期结果：3 个 callId 各自正确匹配结果，无错配
```

#### TC-006: 副作用禁止
```
前置条件：正常运行
步骤：要求 Agent 用 PageTool 提交表单/删除数据
预期结果：被拒绝，Agent 提示需走带确认机制的专用工具
```

### 负责人
待分配

### 完成时间
待定

---

## T-011: GenUI 与 tiny-robot 版本评估

### 任务描述

输出评估文档，不实施改造。

### 验收标准

- [ ] 评估 GenUI 引入成本（依赖体积、与低代码引擎栈的耦合、自建服务可行性）
- [ ] 评估 tiny-robot 升级到 0.5.2-alpha.x 的影响
  （引入 `tiny-robot-chat`、本地运行时与当前远端 Agent 架构的冲突点）
- [ ] 给出明确结论：引入 / 不引入 / 延后

### 负责人
待分配

### 完成时间
待定

---

## T-012: `src/mcp-servers/` 迁移计划

### 任务描述

为 `src/mcp-servers/{entity,user,role,permission,menu,locale,chat}` 的
`server.registerTool` 旧模式制定迁移计划。

### 验收标准

- [ ] 盘点现有工具清单与调用方
- [ ] 输出迁移计划与排期
- [ ] 明确"新增工具一律用 document.modelContext"的团队约定

### 负责人
待分配

### 完成时间
待定

---

## 任务依赖关系

```
T-001 ──┐
        ├──> T-002 ──┬──> T-003 ──┐
T-004 ──┘            │            ├──> T-010
                     ├──> T-005 ──┤
T-006 ───────────────┼────────────┤
T-007 ───────────────┼────────────┤
T-008 ───────────────┘            │
T-009 ────────────────────────────┘

T-011（独立，评估类）
T-012（独立，规划类）
```

关键路径：**T-001 → T-002 → T-003 → T-010**

---

## 完成情况统计

| 状态 | 数量 | 占比 |
|---|---|---|
| ✅ 已完成 | 0 | 0% |
| 🔄 进行中 | 0 | 0% |
| ⏳ 待开始 | 12 | 100% |
| ❌ 阻塞 | 0 | 0% |

---

## 更新记录

| 日期 | 更新内容 | 更新人 |
|---|---|---|
| 2026-09-19 | 创建任务清单，基于 problem-analysis 断点分析 | AI |

---

## 开发规范提醒

### 仓颉代码开发

⚠️ **重要**：所有仓颉代码（.cj 文件）的编写必须使用 **cangjie-coder 技能**，
遵循"查阅文档 → 检索代码 → 编辑适配 → 写入文件"四步工作流程。

本工程涉及的仓颉文件：

- `src/tool/webmcp/` 下的传输抽象（T-002 新增）
- `src/tool/webmcp/WebMCPToolHelper.cj`（T-002 改造出口）
- `src/app/services/webmcp/WebMCPProtocol.cj`（T-005 如需要）
- `src/app/controllers/uctoo/webmcp/WebMCPController.cj`（T-002 如需要）

### 数据库表结构变更

⚠️ **重要**：涉及数据库结构变更时，必须遵循 uctoo-v4 通用模块开发流程：
1. **[自动化]** 在 `sql/incremental/` 目录生成 DDL 脚本
2. **[人工操作]** 通知人工执行数据库变更
3. **[人工操作]** 人工使用 `loaddbinfo` 刷新 db_info 表，用 `crudgen` 生成标准 CRUD 模块，
   用 `crudweb` 生成 Web 管理界面
4. **[自动化]** 基于生成的 CRUD 模块迭代开发（定制代码写在 `//#region AutoCreateCode` 区域外）

详细规范参考：`apps/agentskills-runtime/docs/uctoo-v4/uctoo-v4-module-development.md`

### 前端代码规范

- 自定义扩展代码写在 `//#region Human-Code Preservation` 区域内
- 工具名使用稳定且唯一的 snake_case（如 `order_query`、`entity_list`）
- 工具 description 必须写清用途、适用条件与限制
- 提交/删除/发布/支付类操作不得通过 PageTool 或 Skill 开放

---

# 第 8 轮：webmcp-agent-web-operation 落地实现（2026-09-25）

## 目标

把"Agent 理解用户意图操作 Web 应用"做成可运行的垂直切片，以用户验收场景为基准：
> "打开 uctoo 数据库的 entity 表数据表格页面，查询 link 列包含 opencangjie 的数据"
> → Agent 理解意图 → 自动 navigate_url 到 `/uctoo/entity` → 自动调用 query-entity-list 查询

## 本轮代码改动（前端，4 个文件）

| 文件 | 变更 | 对应断点/任务 |
| --- | --- | --- |
| `web-admin/web/src/webmcp/tool-executor.ts` | **新建**。监听 `next-sdk:tool-call` → `document.modelContext.getTools` 找 descriptor → `executeTool` → 回 `next-sdk:tool-response`；30s 超时、未知工具回 error、`web_*` 后端内置工具跳过（交审批卡片） | 断点 2 / T-003 |
| `web-admin/web/src/webmcp/pagetool-init.ts` | **新建**。`initializePageTool()` 调 `registerPageAgentTool`，黑名单排除 AI 界面，失败不阻塞启动 | T-006 |
| `web-admin/web/src/webmcp/entity-tools.ts` | **新建**。`registerEntityWebTools()` 在 `document.modelContext` 注册 `query-entity-list`，直连 `GET /api/v1/uctoo/entity/{pageSize}/{page}`，对 link 做客户端包含匹配兜底 | T-007 |
| `web-admin/web/src/App.vue` | 引入上述三模块；`onMounted` 调 `initializePageTool()`+`registerEntityWebTools()`+`startToolExecutor()`；`useWebAgentServer` 内恢复 `connectSSE(sessionId)`（加 `VITE_ENABLE_TOOLCALL_SSE` 开关）；`onBeforeUnmount` 停止执行器 | 断点 1 / T-002 / T-003 |
| `web-admin/web/src/skills/entity-operator/SKILL.md` | 路由 `/database/uctoo/entity` → **`/uctoo/entity`**（与 router 实际路径对齐）；新增"端到端自动操作"示例 | T-007 / T-008 |
| `web-admin/web/src/skills/uctoo-operator/SKILL.md` | Entity 管理路由同步修正为 `/uctoo/entity` | T-008 |

## 关键事实（本轮勘察确认，非推测）

- `main.ts` 第 20 行已 `initializeBuiltinWebMCP()`，`document.modelContext` 启动即可用。
- vendored `@opentiny/next-sdk` **真实导出** `initializeBuiltinWebMCP` 与 `registerPageAgentTool`（index.ts:52/55），PageTool 无需从官方移植。
- `document.modelContext.executeTool` 签名：`executeTool(descriptor, JSON.stringify(args))`（参照 `next-sdk/agent/utils/getBuiltinMcpTools.ts:80`），故执行器需先 `getTools()` 取 descriptor。
- `ApprovalOptionsCard.vue` 自行监听 `next-sdk:tool-call` 且只处理 `web_request_approval`、自己回传结果 → 执行器对 `web_*` 必须跳过，否则破坏审批流。
- entity 真实列表接口：`store/models/uctoo/entity.ts` → `GET /api/v1/uctoo/entity/${pageSize}/${page}`，`params` 透传查询参数，带 `Bearer accessToken`。
- 老 `mcp-servers/entity/tools.ts` 的 `query-entity-list` 走已被移除的 `WebMcpServer` 模式（`createMcpServer` 当前无人调用），**未进入 Agent 工具箱**——本轮改为标准 `document.modelContext.registerTool` 注册。
- 路由真实路径为 `/uctoo/entity`（router/routes/modules/uctoo.ts:14，父 `/uctoo` + 子 `entity`），SKILL 原写的 `/database/uctoo/entity` 是错的。

## 状态更新

| 任务 | 状态 | 说明 |
| --- | --- | --- |
| T-002 指令下行通道 | ✅ 前端恢复 connectSSE（复用既有 SSEConnectionManager，后端零改动） | 加开关防复发 |
| T-003 前端统一执行器 | ✅ `tool-executor.ts` | 修复断点 2 |
| T-006 PageTool 接入 | ✅ `pagetool-init.ts` | 官方 API 可用 |
| T-007 业务工具+SKILL | ✅ entity demo 落地 | 含路由修正 |
| T-001 根因排查 | 🔄 改为"规避"：加 `VITE_ENABLE_TOOLCALL_SSE` 开关，复发则关闭 | 未根治连接池根因 |
| T-004 注册体系改造 | ⏳ 未做 mcp-servers 重构（本轮用新文件新增，未动旧模式） | 不影响 demo |
| T-005 上报后端验证 | ⏳ 未运行时验证（依赖 builtin:true 自动同步，navigate_url 同机制可推断可用） | 待用户联调 |
| T-008 WebSkills 装载 | 🔄 沿用既有 `:skills` 注入；entity/uctoo-operator SKILL 已存在并修正 |  |
| T-009/T-010/T-011/T-012 | ⏳ 待后续 |  |

## 待用户验证（运行时）

1. `cd apps/web-admin/web && npm install && npm start`，浏览器打开后：
   - 控制台应出现 `[tool-executor] 已启动`、`[pagetool] registerPageAgentTool 已初始化`、`[entity-tools] query-entity-list 已注册`。
2. 在聊天输入"打开 uctoo 数据库的 entity 表数据表格页面，查询 link 列包含 opencangjie 的数据"：
   - 期望 Agent 先 navigate_url 到 `/uctoo/entity`，再调用 query-entity-list({link:'opencangjie'})，返回匹配行。
3. 若复现 400 "Empty request body"（chat POST 丢 body），在 `.env` 设 `VITE_ENABLE_TOOLCALL_SSE=false` 关闭下行通道后重验（降级：前端工具不可被 Agent 主动调用，但 chat 正常）。
4. T-005 验证：后端日志应出现前端工具同步（query-entity-list / navigate_url 进入 Agent ToolManager）。

## 已知简化 / 风险

- 执行器未做路由前置跳转（ROUTE_REQUIRED）：demo 由 Agent 先 navigate_url 解决，符合用户场景；未适配页面的纯 PageTool 点击导航路径未端到端验证。
- query-entity-list 为**应用级常驻**工具（任何页面都可调），而非页面级；与 SKILL 的"路由归属"描述略有出入，但更利于 demo 鲁棒性。
- 后端零改动：依赖既有 `SSEConnectionManager` + `WebMCPToolHelper` + `PendingToolCallManager` 链路完整（problem-analysis 已确认）。

---

# 第 9 轮：路由回退 + 消除应用级工具与官方页面级工具冲突（2026-09-25）

## 用户纠正

实体页开发环境真实 URL = `http://localhost:3031/vue-pro/database/uctoo/entity`。
- `/vue-pro` 是 Vite public base 路径；逻辑路由 = `/database/uctoo/entity`。
- 第 8 轮误把 SKILL 路由从 `/database/uctoo/entity` 改成了 `/uctoo/entity`（错），本轮回退。

## 关键发现（本轮勘察）

1. **页面已自带官方页面级工具**：`views/database/uctoo/entity/components/entity-table.vue:617`
   用 `registerPageTool({ route: '/database/uctoo/entity', handlers })` 注册了
   `query-entity-list` / `create-entity` / `edit-entity` / `delete-entity` / `restore-entity`
   ——正是 OpenTiny 官方"页面级 WebMCP 工具"模式（路由作用域、卸载时 AbortController 注销）。
2. **`link` 筛选操作符 = `contains`**（entity-table.vue:94）：`query-entity-list` 设
   `linkCondition.value = link` 即"包含"匹配，**直接满足验收句"link 包含 opencangjie"**，
   无需 Agent 自做子串判断，也无需额外客户端过滤。
3. 第 8 轮新建的 `entity-tools.ts` 在**应用级**重复注册同名 `query-entity-list`，
   且实现是"直接调 API + 客户端过滤"，既**与页面级工具冲突**（同名注册，谁生效取决于挂载顺序），
   又**偏离官方模式**（绕过页面查询 UI）。→ **删除该文件并移除 App.vue 接线**。

## 本轮改动

| 文件 | 变更 |
| --- | --- |
| `web/src/skills/entity-operator/SKILL.md` | 路由 `/uctoo/entity` → `/database/uctoo/entity`；navigate 示例改 `/vue-pro/database/uctoo/entity`；路由说明补充"页面 registerPageTool 自动注册、需先导航"；`link` 包含由页面 `contains` 操作符承担 |
| `web/src/skills/uctoo-operator/SKILL.md` | Entity 管理路由同步改 `/database/uctoo/entity` |
| `web/src/webmcp/entity-tools.ts` | **删除**（冗余 + 与官方页面级工具冲突） |
| `web/src/App.vue` | 移除 `import { registerEntityWebTools }` 与 `onMounted` 中调用（保留 `initializePageTool` + `startToolExecutor`） |

## 状态更新

| 任务 | 状态 | 说明 |
| --- | --- | --- |
| T-007 业务工具+SKILL | ✅→🔧 路线修正：不再自建应用级工具，复用页面级 `query-entity-list`（官方模式，含 contains 语义） | demo 路径收敛到官方 |
| T-002 指令下行通道 | ✅ 维持（connectSSE + VITE_ENABLE_TOOLCALL_SSE 开关） |  |
| T-003 前端统一执行器 | ✅ 维持（tool-executor.ts） | 真正执行页面级/PageTool 工具 |
| T-006 PageTool 接入 | ✅ 维持（pagetool-init.ts） | 未适配页面的点击/输入/滚动层 |

## 验收链路（修正后，端到端）

用户："打开 uctoo 数据库的 entity 表数据表格页面，查询 link 列包含 opencangjie 的数据"
→ Agent：`navigate_url({url:'/vue-pro/database/uctoo/entity'})`
→ 页面挂载 → entity-table.vue `onMounted` 调 `registerPageTool` 注册 `query-entity-list`
→ Agent：`query-entity-list({link:'opencangjie'})`
→ `tool-executor` 监听 `next-sdk:tool-call` → `document.modelContext.getTools` 取 descriptor → `executeTool`
→ 页面 handler 设 `link` 筛选为 contains + `opencangjie` → 刷新表格 → 返回匹配行
→ `handleToolResponse` POST `/tool-result` 回 Agent → 汇总给用户。

## 待用户验证 / 待办

1. 第二篇公众号文章（`mid=2247500931`）转换被微信"环境异常"验证墙拦截（python 与 WebFetch 均只拿到验证页），
   未能落盘。需用户浏览器打开后另存 HTML（或粘贴正文）给我，我再转 `docs/`。
2. `cd apps/web-admin/web && npm install && npm start` 验证：控制台应出现
   `[tool-executor] 已启动`、`[pagetool] registerPageAgentTool 已初始化`（不再有 entity-tools 日志）。
3. 聊天输入验收句 → 期望先导航到 `/database/uctoo/entity`，再返回 link 包含 opencangjie 的记录。
4. T-005 后端工具同步仍需联调确认（builtin:true 是否把页面级 query-entity-list 同步进 Agent ToolManager）。

---

# 第 10 轮：对照 OpenTiny 官方指导手册复核（2026-09-25）

## 本轮产出

- `web-admin/web/docs/opentiny-webmcp-agent-article.md`（+ `-images/`）：
  转换《指导手册｜OpenTiny NEXT 四步实现业务应用通过自然语言智能操作页面》
  （`https://mp.weixin.qq.com/s/3w1DjIsQjLBDqgWU5qhNFg`，2026-09-23），17 个代码块 + 2 张表格完整保留，8 图 + 2 视频链接。
- `specs/webmcp-agent-web-operation/review-vs-opentiny-official.md`：**复核报告**（本轮主交付）。

## 复核结论

| 维度 | 结论 |
| --- | --- |
| 业务工具注册机制（`document.modelContext.registerTool` + AbortController + 页面作用域） | ✅ 与官方同构 |
| WebSkills（`src/skills/*/SKILL.md` 结构） | ✅ 同构 |
| PageTool 接入 + `a11yConfig.blacklist` | ✅ 同构（黑名单比官方多排除 2 项） |
| 副作用红线（写操作走专用工具，不开放给 PageTool） | ✅ 同构 |
| GenUI SDK | ⚠️ 有意不引（历史决定，避免 tiny-schema-renderer 重依赖） |
| 导航方式 | ⚠️ 用应用级 `navigate_url`，官方用 PageTool 点击 `data-page-tool-action="navigation"` |
| `data-page-tool-*` 页面目标声明 + adapter policy | ❌ **未做**（真实差距：缺"稳定语义 + 执行前授权"） |
| "专用工具已定位则免 PageTool 复核"边界 | ❌ SKILL 未写（官方两处强调） |

## 待办（复核衍生，按性价比）

| 优先级 | 事项 |
| --- | --- |
| P1 | `entity-operator/SKILL.md` 补"query-entity-list 已返回页面筛选结果，无需 PageTool 复核" |
| P1 | 本文件 TC-002 措辞与实现对齐（PageTool 点击 **或** navigate_url 直达） |
| P2 | 侧边导航项补 `data-page-tool-id` / `-action` / `aria-label`，并纳入 `pagetool-init.ts` 配置 |
| P3 | App.vue 三处 `navigator.modelContext` → `document.modelContext`（统一官方口径） |

---

## T-011: 修复 agent 在独立浏览器操作导致登录态丢失（2026-09-25 实测）

### 现象
用户在已登录 tab（/vue-pro/board/home）与 agent 对话"操作 entity 表页面查询数据"，agent 调用工具后操作系统新开一个 chrome 实例并跳到 /vue-pro/database/uctoo/entity，因新实例无登录态被重定向到 /login。原 tab 仍为登录态，证明新 chrome 是独立程序/会话。

### 根因（两处）
1. **navigate_url 未暴露给 agent**：App.vue 三处 `navigator.modelContext.registerTool`（get_skill_content / navigate_url / system-overview）注册在 `navigator.modelContext`，但 WebMCP 桥 `useBuiltinMcpServer.ts:47` 只读 `document.modelContext`，业务页工具（registerPageTool / entity-table 的 query-entity-list）也写在 `document.modelContext`。故 navigate_url 对 agent 不可见 → agent 退而调用 runtime 内置 `browser_open`。
2. **browser_open 无同源护栏**：`src/tool/browser_tool.cj` 的 `browser_open` 在 Windows 上执行 `cmd /c start <url>`，新开独立浏览器实例，不共享登录态。

### 修复（已落代码）
- `web/src/App.vue`：三处 `navigator.modelContext.registerTool` → `((document as any).modelContext ?? (navigator as any).modelContext).registerTool`，确保 navigate_url 经官方桥暴露给 agent；并强化 navigate_url description（强调在已登录 tab 内导航、严禁 browser_open）。
- `apps/agentskills-runtime/src/tool/browser_tool.cj`：execute 增加 `isSameOriginAppUrl` 护栏，命中 localhost:3031 / 127.0.0.1:3031 / javatoarktsapi.uctoo.com 时拒绝并返回明确提示"改用 navigate_url"，从源头阻断 session 丢失。
- `web/src/skills/entity-operator/SKILL.md`：注意事项显式禁止用 browser_open 打开本应用内地址，一律用 navigate_url。

### 验证（待用户编译+浏览器实测）
- agent 调用 navigate_url 在**当前 tab** 内 router.push 到 /database/uctoo/entity（不再新开浏览器）；
- 页面挂载后 registerPageTool 触发 toolchange，`useRouteBasedTools` 刷新目录 → agent 可调用 query-entity-list 按 link 查询；
- 对 localhost:3031 再调 browser_open 返回拒绝提示。
