# Agent 操作 Web 应用链路闭环 —— 设计文档

## 1. 设计目标

把 `problem-analysis.md` 中定位的六个断点补齐，使"Agent 操作 Web 应用"端到端可用。
核心是解决两件事：**指令怎么可靠地下行**（断点 1）、**下行后谁来执行并回传**（断点 2）。

## 2. 关键设计决策

### 决策 1：指令下行通道选型 —— 复用 MCP 传输（方案 B）

#### 背景

`WebMCPToolHelper` 当前通过 `SSEConnectionManager.pushMessage(sessionId, "tool_call", data)` 下行，
依赖前端建立 `GET /api/v1/uctoo/webmcp/sse` 独立 EventSource。该连接已在 v19 被移除，
原因是它会导致后续 fetch 请求体丢失（"Empty request body"）。

#### 候选对比

| 方案 | 改动量 | 风险 | 结论 |
|---|---|---|---|
| A 恢复独立 SSE + 根治根因 | 小（后端不动） | 根因未明，排查成本高；仍多占一条长连接 | 不采用 |
| **B 复用 MCP 传输** | 中（改后端消息路由 + 前端收发） | 中，需扩展 MCP 层消息 | **采用** |
| C 改用 WebSocket | 中（新增 WS 会话映射） | 中，需维护双通道映射 | 备选 |

#### 方案 B 说明

前端 `WebMcpClient` 已与后端建立 MCP 连接（`client.connect({agent:true, builtin:true, type:'sse'})`）。
该连接本身就是会话级的、双向的：前端用它发 MCP 请求，后端用它推 MCP 响应与通知。
tool_call 可以作为**服务端发起的 MCP 请求**在同一连接上下行，无需新增长连接。

需要解决的核心问题：**MCP 标准中 `tools/call` 是客户端→服务端方向**，
服务端→客户端的主动请求在标准 MCP 中只有 sampling / roots / elicitation 三类。

#### 解决办法（两选一，建议在 T-002 中验证后定稿）

- **B1（推荐）：扩展自定义 MCP 方法 `webmcp/toolCall`**
  后端通过已建立的传输发送 `{jsonrpc:"2.0", id, method:"webmcp/toolCall", params:{callId,toolName,arguments,route}}`，
  前端 `WebMcpClient` 侧注册该方法处理器，执行后以 JSON-RPC 响应回传结果。
  优点：语义清晰、请求-响应天然配对了 callId 问题、不污染标准方法。
  代价：引入一个非标准方法名（但 WebMCP 本身仍在演进，官方也保留了自有扩展空间）。

- **B2：复用 `tools/call` 反向调用 + `/tool-result` 回传**
  后端把 tool_call 作为通知（无 id）下推，前端执行后仍走 `POST /tool-result`。
  优点：后端 `WebMCPToolHelper` 与 `PendingToolCallManager` 完全不用改。
  代价：通知无 id，仍需 callId 做应用层配对；前端仍要发一次 HTTP POST。

**建议先按 B2 落地打通闭环（改动最小、风险最低），在闭环验证通过后再评估是否演进到 B1。**
B1 的价值在于把结果回传也并入同一连接，可省掉一次 HTTP 往返并简化 callId 匹配。

### 决策 2：前端工具执行器 —— 收敛到单一执行入口

#### 现状问题

`App.vue` 收到 tool_call 后 `window.postMessage` 广播，只有 `ApprovalOptionsCard.vue` 消费审批类。
`document.modelContext.executeTool` 从未被调用。

#### 设计

新建前端工具执行器模块，作为 tool_call 的**唯一**执行入口：

```
src/webmcp/
├── tool-executor.ts       # 统一执行入口：查工具 → 执行 → 回传
├── tool-registry.ts       # document.modelContext 读写封装 + 变更监听
├── result-reporter.ts     # 回传结果（/tool-result 或 MCP 响应）
├── pagetool-init.ts       # PageTool 初始化与黑名单
└── index.ts
```

执行流程：

```
收到 tool_call { callId, toolName, arguments, route }
  │
  ├─ 1. 查 modelContext.listTools() 找 descriptor
  │     找不到 → 回传 error="未找到工具 {toolName}"
  │
  ├─ 2. 路由前置检查
  │     descriptor 有 route 且当前路由不符 → 跳转并等待就绪
  │     跳转失败 → 回传 error="ROUTE_REQUIRED:..."
  │
  ├─ 3. 执行 executeTool(descriptor, JSON.stringify(arguments))
  │     抛异常 → 回传 error=异常信息
  │     超时 30s → 回传 error="工具执行超时"
  │
  └─ 4. 回传 { callId, result } 或 { callId, error }
```

#### 与既有 ApprovalOptionsCard 的关系

`ApprovalOptionsCard.vue` 当前直接监听 `next-sdk:tool-call`。改造后：

- 审批类工具（`web_request_approval`）仍走执行器分发，执行器识别到审批工具后
  再 postMessage 给审批卡片渲染 UI，卡片提交后由执行器统一回传
- 即：**执行器是唯一入口，审批卡片退化为审批 UI 组件**，不再直接消费 tool_call

### 决策 3：工具注册体系收敛到 `document.modelContext`

`src/mcp-servers/` 的 `server.registerTool` 属于官方已明确不推荐的旧模式。
新工具一律用 `document.modelContext.registerTool`：

- **应用级常驻工具**：`navigate_url`、`system-overview`、`get_skill_content` → 在 `main.ts` 注册
- **页面级工具**：随页面 `onMounted` 注册、`onUnmounted` 用 AbortController 注销

`src/mcp-servers/` 既有工具排期迁移（REQ-OP-07，P2），本阶段不动。

### 决策 4：后端改动最小化

后端 `WebMCPToolHelper` / `PendingToolCallManager` / `FrontendToolAdapter` 逻辑正确，
本阶段**只改消息出口**，不动阻塞等待与超时逻辑：

```
WebMCPToolHelper.executeToolCall
  ├─ 生成 callId                                 （不变）
  ├─ 【改】pushMessage → 改为通过会话已建立的传输下推
  ├─ PendingToolCallManager.register             （不变）
  └─ Condition.await 阻塞等待                     （不变）
```

建议保留 `SSEConnectionManager` 作为传输实现之一，新增一个传输抽象，
使 tool_call 可走 SSE / MCP / WS 任一实现，便于回退。

> 说明：涉及仓颉代码（.cj）的编写必须使用 **cangjie-coder 技能**。
> 本文中的代码均为结构示意，实际实现以 cangjie-coder 生成的符合语言规范的代码为准。

## 3. 详细设计

### 3.1 前端：工具注册封装

```ts
// src/webmcp/tool-registry.ts
export interface ToolRegistrationOptions {
  route?: string
  signal?: AbortSignal
}

export function getModelContext() {
  return (document as any).modelContext ?? (navigator as any).modelContext
}

export async function listTools(): Promise<WebMcpToolDescriptor[]> {
  const ctx = getModelContext()
  if (!ctx) return []
  const fn = ctx.listTools ?? ctx.getTools
  if (!fn) return []
  const tools = await fn.call(ctx)
  return Array.isArray(tools) ? tools : []
}

export function registerTool(descriptor: WebMcpToolDescriptor, options?: ToolRegistrationOptions) {
  const ctx = getModelContext()
  if (!ctx?.registerTool) throw new Error('document.modelContext 不可用，请先 initializeBuiltinWebMCP()')
  return ctx.registerTool(descriptor, options)
}

export function onToolChange(cb: () => void): () => void {
  const ctx = getModelContext()
  ctx?.addEventListener?.('toolchange', cb)
  return () => ctx?.removeEventListener?.('toolchange', cb)
}
```

### 3.2 前端：统一执行器

```ts
// src/webmcp/tool-executor.ts
const TOOL_TIMEOUT_MS = 30_000

export async function executeToolCall(msg: ToolCallMessage): Promise<ToolResultMessage> {
  const { callId, toolName, arguments: args, route } = msg

  const tools = await listTools()
  const descriptor = tools.find((t) => t.name === toolName)
  if (!descriptor) {
    return { callId, error: `未找到工具 ${toolName}，该工具可能随页面卸载已注销` }
  }

  if (route && !isCurrentRoute(route)) {
    const ok = await navigateTo(route)
    if (!ok) return { callId, error: `ROUTE_REQUIRED：请先进入 ${route} 再重试` }
  }

  try {
    const result = await withTimeout(
      () => executeModelContextTool(descriptor, args),
      TOOL_TIMEOUT_MS,
    )
    return { callId, result }
  } catch (e) {
    return { callId, error: e instanceof Error ? e.message : String(e) }
  }
}
```

### 3.3 前端：PageTool 初始化

```ts
// src/webmcp/pagetool-init.ts
import { registerPageAgentTool } from '@opentiny/next-sdk'

const DEFAULT_BLACKLIST = [
  '.chat-add-window', '.chat-add-launcher', '.tr-sender', '.tr-bubble',
  '[data-page-tool-exclude="true"]',
]

let initialized = false
export function initializePageTool(extra: string[] = []): void {
  if (initialized) return
  initialized = true
  registerPageAgentTool({
    enableHighlight: false,
    removeMaskAfterToolCall: true,
    a11yConfig: {
      blacklist: [...DEFAULT_BLACKLIST, ...extra],
      whitelist: [],
      exposedAttributes: ['data-page-tool-id', 'data-page-tool-action'],
    },
  })
}
```

`main.ts` 中的初始化顺序（顺序不能变）：

```ts
initializeBuiltinWebMCP()   // 1. 先注入 Polyfill
initializePageTool()        // 2. 再注册 PageTool（内部依赖 modelContext）
registerAppTools()          // 3. 最后注册业务工具
createApp(App).use(router).mount('#app')
```

### 3.4 前端：WebSkills 装载

```
src/skills/
├── uctoo-operator/SKILL.md      # 系统操作（导航、概览）
└── <业务名>/SKILL.md            # 业务技能，随业务扩展
```

装载：

```ts
const skillModules = import.meta.glob('../skills/**/SKILL.md', { query: '?raw', import: 'default' })
const paths = await getMainSkillPaths(skillModules)
const skills = await Promise.all(paths.map(loadOne))
skillPlugin({ selection: () => ({ mode: 'manual', skills }) })
```

> 依赖 `@opentiny/next-sdk` 的 `getMainSkillPaths` / `getSkillMdContent`
> 与 `@opentiny/tiny-robot-kit` 的 `loadSkillWithDetails` / `skillPlugin`。
> 当前 vendored fork 与 tiny-robot-kit 0.5.1 是否提供这些 API 需在 T-006 中确认，
> 若不可用则退化为"读取 SKILL.md 原文注入 system prompt"的简化实现。

### 3.5 后端：传输抽象

在 `magic.tool.webmcp` 包中新增传输抽象（仓颉代码须用 cangjie-coder 技能编写）：

```
interface ToolCallTransport {
    func send(sessionId: String, callId: String, payload: String): Bool
    func hasSession(sessionId: String): Bool
}
```

实现：

- `SSETransport`：包装现有 `SSEConnectionManager`（保留，便于回退）
- `McpTransport`：通过会话已建立的 MCP 连接下推（本阶段新增）

`WebMCPToolHelper` 改为持有 `ToolCallTransport`，构造时按会话可用情况选择实现。

**注意包依赖方向**：新增类放在 `magic.tool.webmcp` 包内，
不得让 `magic.tool.webmcp` import `magic.app.services.webmcp`，避免循环依赖。

### 3.6 后端：保持不变的部分

| 组件 | 是否改动 | 说明 |
|---|---|---|
| `FrontendToolAdapter` | 不改动 | invoke 已正确委托给 WebMCPToolHelper |
| `PendingToolCallManager` | 不改动 | 注册/匹配/清理/超时逻辑正确 |
| `WebMCPToolContext` | 不改动 | 会话上下文注入正确 |
| `handleToolsRegister` | 不改动 | 已支持 tools/tool/裸对象三种格式 |
| `/tool-result` 端点 | 不改动 | 已实现 callId 校验与 404/400 |
| `WebMCPToolHelper` | **仅改出口** | pushMessage → transport.send |

## 4. 验收 Demo 场景

对齐参考实现的订单场景，在 UCToo 中选一个**真实业务页面**做端到端验收。
建议选 `entity`（数据库表管理）或订单类页面，要求：

1. 页面注册至少两个业务工具（列表查询 + 详情查询）
2. 页面元素标注 PageTool 标记（页面容器 query、列表 navigation、侧边导航 navigation）
3. 编写对应 SKILL.md
4. 验收路径：

```
用户："帮我查询 entity 表的前 10 条数据"
  → Agent 调用业务工具 → 指令下行 → 前端执行 → 回传结果 → Agent 回答

用户（在非目标页）："帮我查询 entity 表的前 10 条数据"
  → Agent 调用业务工具 → 回传 ROUTE_REQUIRED
  → Agent 用 PageTool 点击侧边导航 → 进入目标页 → 重试业务工具 → 成功
```

第二条路径是本次工程的**关键验收项**，它同时验证了 WebMCP Tool、PageTool、
路由前置条件与多轮重试四个能力。

## 5. 风险与应对

| 风险 | 影响 | 应对 |
|---|---|---|
| MCP 传输不支持服务端主动下推 | 方案 B 不成立 | 回退方案 C（WebSocket），后端已有 WS 实现 |
| vendored fork 缺少 `registerPageAgentTool` 等新 API | PageTool 无法接入 | T-006 先做 API 可用性盘点，缺失则从官方 0.4.11 移植 |
| tiny-robot-kit 0.5.1 无 `loadSkillWithDetails` | WebSkills 无法按官方方式装载 | 退化为 SKILL.md 原文注入 system prompt |
| "Empty request body" 根因未明 | 换通道后仍可能复现 | T-001 增加根因排查任务，先定位再选通道 |
| 审批链路改造影响现有功能 | 审批回归 | 执行器保留审批消息格式，ApprovalOptionsCard 只改消费入口 |

## 6. 与既有任务的关系

`webmcp-new-completion/tasks.md` 中以下任务与本工程重叠，需同步状态：

| 任务 | 原状态 | 本工程处理 |
|---|---|---|
| T-005 前端工具调用闭环 | 进行中 | **由本工程完成** |
| T-006 后端会话管理 | 进行中 | 本工程不涉及，保持 |
| T-007 集成测试与验证 | 待开始 | **由本工程完成**（含验收 Demo） |
| T-009 用户认证机制集成 | 待开始 | 本工程依赖，需先完成 |
