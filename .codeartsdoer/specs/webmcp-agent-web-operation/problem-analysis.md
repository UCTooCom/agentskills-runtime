# Agent 操作 Web 应用链路 —— 现状与问题分析

## 1. 背景

`webmcp-new-completion` 与 `webmcp-tool-chain` 两个 sdd 工程已基本完成 OpenTiny 技术栈与
agentskills-runtime（仓颉）的集成，并用 agentskills-runtime 替代了原开源项目 NestJS 后端中的
WebAgent 角色，充当 MCP 中枢层。

但"Agent 直接操作 Web 应用"这条能力在当前工程里**尚未端到端打通**：后端 Agent 能发现前端工具、
能决策调用，但调用指令送不到前端执行体，执行结果也回不来。

本文基于对以下三处代码的实际勘察，定位断点：

- `apps/agentskills-runtime/src/` 中 WebMCP 相关仓颉实现
- `apps/web-admin/web/src/` 中 TinyRobot / WebMCP 前端实现
- `apps/community-resources` 的 `reference/codelabs-opentiny-next-complete` 分支中的 `codelabs-demo` 完整示例

## 2. 现状盘点

### 2.1 后端 agentskills-runtime（仓颉）

| 组件 | 文件 | 状态 |
|---|---|---|
| WebMCPController | `src/app/controllers/uctoo/webmcp/WebMCPController.cj` | 已实现 |
| WebMCPProtocol | `src/app/services/webmcp/WebMCPProtocol.cj` | 已实现 |
| MenuDataProvider | `src/app/services/webmcp/MenuDataProvider.cj` | 已实现 |
| WebMCPRoutes | `src/app/routes/webmcp/WebMCPRoutes.cj` | 已实现 |
| FrontendToolAdapter | `src/skill/frontend_tool_adapter.cj` | 已实现 |
| WebMCPToolHelper | `src/tool/webmcp/WebMCPToolHelper.cj` | 已实现 |
| SSEConnectionManager | `src/tool/webmcp/SSEConnectionManager.cj` | 已实现 |
| PendingToolCallManager | `src/tool/webmcp/PendingToolCallManager.cj` | 已实现 |
| FrontendToolRegistry | `src/tool/webmcp/FrontendToolRegistry.cj` | 已实现 |
| WebMCPToolContext | `src/tool/webmcp/WebMCPToolContext.cj` | 已实现 |
| 后端内置工具 | `web_navigate_tool` / `web_notify_tool` / `web_request_approval_tool` | 已实现 |

已注册的 HTTP 端点（`WebMCPRoutes.cj`）：

```
POST /api/v1/uctoo/webmcp/mcp            streamableHttp（兼容 /api/v1/webmcp/mcp）
POST /api/v1/uctoo/webmcp/tool-result    前端回传工具执行结果
GET  /api/v1/uctoo/webmcp/sse            工具调用指令推送通道（EventSource）
GET  /api/v1/uctoo/webmcp/events         可重连事件流（lastEventId 回放）
GET  /api/v1/uctoo/webmcp/health
GET  /api/v1/uctoo/webmcp/remote
GET  /api/v1/uctoo/webmcp/client
```

已实现的调用语义（`WebMCPProtocol.handleToolsRegister` → `FrontendToolAdapter.invoke`）：

```
tools/register → FrontendToolRegistry.register()
                → agent.addFrontendTool()  → ToolManager 可发现
Agent 调用      → FrontendToolAdapter.invoke()
                → WebMCPToolHelper.executeToolCall(toolName, args, 120000, route)
                    ├─ 生成 callId
                    ├─ SSEConnectionManager.pushMessage(sessionId, "tool_call", data)
                    ├─ PendingToolCallManager.register(callId, ...)
                    └─ Condition.await 阻塞等待 /tool-result 唤醒（120s 超时）
```

**结论：后端链路是完整的。**

### 2.2 前端 web-admin

- 采用 **vendored NEXT-SDKs 源码**：`src/lib/webmcp-sdk/packages/{next-sdk, next-remoter, webmcp-cli, next-wxt}`，
  `package.json` 中以 `file:./src/lib/webmcp-sdk/packages/...` 引用，非 npm 官方版本。
- `src/App.vue` 已实现：
  - `navigator.modelContext.registerTool` 注册 3 个工具：`get_skill_content`、`navigate_url`、`system-overview`
  - `new WebMcpClient()` + `connect({ agent: true, builtin: true, url: MCP_URL, type: 'sse' })`
  - `handleToolResponse`：监听 `window` 消息 `next-sdk:tool-response` → `POST /tool-result`
- `src/components/ApprovalOptionsCard.vue` 监听 `next-sdk:tool-call`，仅处理审批类工具
- `src/mcp-servers/{entity,user,role,permission,menu,locale,chat}/tools.ts`：遗留的 `server.registerTool` 模式

依赖版本对比（对照参考实现 `codelabs-demo`）：

| 包 | web-admin | codelabs-demo | 差异 |
|---|---|---|---|
| `@opentiny/next-sdk` | `file:` vendored fork | `0.4.11` | fork，未跟随官方 |
| `@opentiny/tiny-robot` | `0.5.1` | `0.5.2-alpha.10` | 落后 |
| `@opentiny/tiny-robot-kit` | `0.5.1` | `0.5.2-alpha.10` | 落后 |
| `@opentiny/tiny-robot-chat` | **缺失** | `0.5.2-alpha.10` | 缺失 |
| GenUI SDK | **缺失** | `1.3.0` | 缺失 |
| `@mcp-b/webmcp-polyfill` | `^2.0.0` | 由 `initializeBuiltinWebMCP()` 提供 | 旧 polyfill |

## 3. 断点定位

### 断点 1【P0】专用 SSE 工具指令通道已被主动关闭

`src/App.vue` 的 `useWebAgentServer()` 中，`connectSSE(sessionId)` 的调用被注释移除，注释原文：

```
// v19 根治：移除 connectSSE(sessionId) 调用
// 根因：connectSSE 创建 EventSource 长连接，占用浏览器 fetch 的 keep-alive 连接池，
// 后续 _chatViaWebMCP 的 fetch 创建的新连接请求体在传输过程中丢失
// → 后端 req.body.size = 0 → 400 "Empty request body"。
```

后果：`GET /api/v1/uctoo/webmcp/sse` 无人连接 → `SSEConnectionManager` 中无该 sessionId 的连接 →
`WebMCPToolHelper.executeToolCall` 的 `pushMessage` 返回 `false` → 工具直接返回
`{"error":"操作推送失败，请刷新页面重试"}`。

即：**后端推送段断开，工具调用在第一步就失败**，且失败是"静默"的（只有 WARN 日志，用户侧表现为 Agent 回复"操作推送失败"）。

### 断点 2【P0】`tool_call` 没有通用执行方

即使 SSE 通道恢复，`App.vue` 收到 `tool_call` 后的处理是：

```js
window.postMessage({
  type: 'next-sdk:tool-call',
  callId, toolName, route, input: args
}, window.location.origin)
```

它只是**广播**出去，并不自己执行。而全局搜索 `next-sdk:tool-call` 的消费方只有两个文件：

- `src/App.vue`（发送方）
- `src/components/ApprovalOptionsCard.vue`（消费方，且只处理审批类工具）

代码中**从未调用** `document.modelContext.executeTool(...)`。

后果：`get_skill_content`、`navigate_url`、`system-overview` 以及任何业务工具都无人执行 →
`/tool-result` 永不触发 → `PendingToolCallManager` 必然等到 120 秒超时。

### 断点 3【P0】前端工具注册是否回传后端未确认

后端 `FrontendToolRegistry` 与 `agent.addFrontendTool` 依赖前端通过 MCP `tools/register` 上报工具定义。
`App.vue` 只调用了 `navigator.modelContext.registerTool`，是否经 `WebMcpClient` 代理模式自动同步到后端
**在当前代码中无法确认**，`webmcp-new-completion/tasks.md` 中 T-005（前端工具调用闭环）状态仍为"进行中"。

### 断点 4【P1】PageTool 未接入

`registerPageAgentTool` / `initializeBuiltinWebMCP` 仅出现在两处：

- vendored `src/lib/webmcp-sdk/packages/next-sdk/page-tools/`
- vendored `src/lib/webmcp-sdk/packages/webmcp-cli/src/inject/page-init.ts`（CLI 注入脚本）

**业务运行时从未调用**。业务页面也没有 `data-page-tool-id` / `data-page-tool-action` 标记。
因此 Agent 无法对未适配页面做元素查询、滚动定位和导航点击。

### 断点 5【P1】缺少 WebSkills 业务技能文档体系

参考实现在 `src/skills/<业务名>/SKILL.md` 中定义业务技能，由 `loadSkillWithDetails` + `skillPlugin` 装载，
让模型知道"什么时候用哪个工具、参数怎么填、结果怎么回答"。

web-admin 目前是把技能文档 raw import 成一个 `skills` 对象，再包成 `get_skill_content` 工具供模型拉取，
**没有按 WebSkills 规范组织，也没有 skillPlugin 装载**。

### 断点 6【P1】GenUI 未真正落地

vendored `next-remoter/src/components/TinyRobotChat.vue` 保留了 `GenUISwitch`，但同一文件注释写明：

```
// 注：genui-sdk-vue 依赖已移除（上一发布版本无此依赖，且会引入整个 OpenTiny 低代码引擎栈）
```

且 `genuiUrl` 硬编码指向 `https://agent.opentiny.design/api/v1/ai/prompt`（OpenTiny 官方服务）。
`package.json` 中无 GenUI SDK 依赖。

### 断点 7【P2】`src/mcp-servers/` 是旧版接入方式

`src/mcp-servers/*` 使用 `server.registerTool` 注册 entity / user / role / permission / menu / locale / chat
等工具，属于 `WebMcpServer` 旧模式。OpenTiny 官方文章《从开发到运行》第 3.2 节已明确接入方式发生演进：

> 现在更推荐开发者围绕标准 `document.modelContext` 注册 WebMCP Tool，NEXT-SDKs 则通过 Polyfill
> 等能力补齐当前浏览器支持。

两套注册方式并存，工具来源不唯一，是后续维护的隐患。

## 4. 根因判断

整条链路可以拆成五段：

```
① 前端注册工具 → ② 上报后端注册表 → ③ Agent 决策并推送指令 → ④ 前端执行 → ⑤ 结果回传
```

当前状态：

| 段 | 状态 | 说明 |
|---|---|---|
| ① 前端注册 | ✅ | `navigator.modelContext.registerTool` 已用（3 个工具） |
| ② 上报后端 | ⚠️ 未确认 | 依赖 WebMcpClient 代理模式自动同步，无显式代码 |
| ③ 推送指令 | ❌ | 专用 SSE 通道被关闭（断点 1） |
| ④ 前端执行 | ❌ | 无执行方，未调用 `executeTool`（断点 2） |
| ⑤ 结果回传 | ⚠️ 空转 | `/tool-result` 端点与前端 `handleToolResponse` 都在，但无结果可回传 |

**根因：③④ 两段同时断开，导致 ⑤ 永远拿不到结果，整条闭环不成立。**
后端实现是完整的，问题集中在前端执行侧与传输通道选型。

## 5. 遗留风险

1. **v19 的规避方案不能直接回退**。当初移除 `connectSSE` 是为了修 "Empty request body"，
   简单恢复 EventSource 会让该问题复发。需要换传输方案或先根治根因。
2. **vendored fork 与官方版本脱节**。`next-sdk` / `next-remoter` 是本地 fork，
   官方 0.4.11 / tiny-robot-chat 0.5.2 的新能力（本地 chat runtime、MCP adapter、PageTool 新 API）拿不到。
3. **`web_navigate` 等后端内置工具与前端工具的边界未收敛**。`webmcp-tool-chain` 已提出
   "后端内置工具应重新定位为前端工具"（REQ-TC-06），但当前仍是两套并存。

## 6. 问题分析结论

需要一次专项工程，目标是把"Agent 操作 Web 应用"做成端到端可用，具体要解决：

1. 选定一条**可靠的指令下行通道**替代被关闭的专用 SSE（候选：MCP 传输复用 / WebSocket / 恢复 SSE 并根治根因）
2. 补上**前端工具执行器**，真正调用 `document.modelContext.executeTool` 并回传结果
3. 明确**工具注册上报后端**的机制并验证
4. 接入 **PageTool**，覆盖未适配页面的查询、定位、导航
5. 建立 **WebSkills 业务技能文档**体系
6. 评估 **GenUI** 与 **tiny-robot-chat 版本升级**的必要性

详细方案见 `research.md`、`spec.md`、`design.md`、`tasks.md`。
