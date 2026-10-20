# Agent 操作 Web 应用链路 —— 参考研究

## 1. 研究目标

为打通"Agent 直接操作 Web 应用"，研究两方面的权威依据：

1. OpenTiny 官方文章《从开发到运行：OpenTiny NEXT 如何构建 Agent 时代的 Web 应用？》
   （已转存为 `apps/web-admin/web/docs/opentiny-next-from-dev-to-run.md`）
2. `apps/community-resources` 仓库 `reference/codelabs-opentiny-next-complete` 分支中的
   `events/hc-2026/codelabs-demo` 完整可运行示例

## 2. 官方文章要点

### 2.1 OpenTiny NEXT 的三段式能力

| 阶段 | 产品 | 职责 |
|---|---|---|
| AI 开发 | Agent Skills（TinyVue / TinyRobot / TinyEngine DSL Generator） | 让组件、平台、文档、规范成为 Agent 可消费的资产 |
| AI 交互 | TinyRobot（Components/Chat/Kit/CLI/Skill）+ GenUI SDK（Server/Renderer/Materials/Actions/Theme） | 对话交互 + 按任务动态生成界面 |
| AI 执行 | NEXT-SDKs（WebMCP / Polyfill / WebSkills / webmcp-cli / PageTool） | Agent 进入 Web 应用并完成任务 |

### 2.2 AI 执行的两条路径（关键）

> 对于能够修改源码的业务应用，更推荐通过 WebMCP 将关键业务能力直接暴露给 Agent。
> 对于无法提前适配的网页，则可以使用 PageTool。
> 两条路径并不是互相替代。WebMCP Tool 更适合稳定、明确的业务操作；PageTool 提供更广泛的页面覆盖能力。
> 在一个完整任务中，Agent 也可以同时使用两类工具。

### 2.3 接入方式的演进（关键，直接影响本工程）

> 一年前，WebMCP 尚未形成今天这样的浏览器端标准接口形态，因此 NEXT-SDKs 更侧重通过
> `WebMcpServer`、`WebMcpClient` 和 WebAgent MCP Proxy 建立 Web 应用与外部 Agent 之间的连接。
>
> 随着 WebMCP 标准逐渐形成，接入方式开始变得更加直接。**现在更推荐开发者围绕标准
> `document.modelContext` 注册 WebMCP Tool**，NEXT-SDKs 则通过 Polyfill 等能力补齐当前浏览器支持，
> 在原生 API 尚未完全可用时提供兼容实现。
>
> NEXT-SDKs 的角色逐渐从"建立一套 Web 与 Agent 的连接机制"，转向
> "**优先使用标准 WebMCP 描述页面能力，并负责兼容、连接和执行**"。

**对本项目的影响**：`src/mcp-servers/` 的 `server.registerTool`（WebMcpServer 模式）属于官方已明确
放弃演进的旧接入方式；新工作应统一到 `document.modelContext`。

### 2.4 官方策略

> 尽量拥抱 Web 标准，同时在标准尚未完全落地的阶段提供可用的工程能力。

## 3. 参考实现 `codelabs-demo` 研究

### 3.1 示例定位

电商管理后台（概览大盘 / 库存 / 订单 / 价保），对应官方文章第四章"以电商系统价保单为例"的 Demo，
是官方认可的**完整**接入样例。

### 3.2 四步接入结构

```
Step 1  TinyRobot Chat        对话框、模型选择、流式对话
Step 2  GenUI                 模型返回结构化可交互界面
Step 3  WebMCP + WebSkills    页面注册业务工具 + 业务技能文档
Step 4  PageTool              页面元素查询 / 滚动定位 / 导航点击
```

### 3.3 关键发现：参考示例的 Agent 运行在浏览器内

`src/TinyRobotChat.vue` 使用的是：

```ts
import { TrChat, useLocalChatRuntime } from '@opentiny/tiny-robot-chat'

const runtime = useLocalChatRuntime({
  conversation: {
    useMessageOptions: {
      responseProvider: providerRuntime.responseProvider,
      plugins: [createGenuiSchemaStreamPlugin(isGenuiActive), businessSkillPlugin],
    },
  },
  mcp: webMcpAdapter,
})
```

**这是本项研究最重要的发现**：参考实现里不存在后端 Agent 参与工具执行。

- 模型调用：浏览器直连 DashScope / DeepSeek（`VITE_ALIYUN_DASHSCOPE_KEY` / `VITE_DEEPSEEK_API_KEY`）
- 工具发现：`getModelContext()` → `document.modelContext.listTools()`
- 工具执行：`modelContext.executeTool(tool, JSON.stringify(args))` —— 全部在页面内完成
- 技能装载：`import.meta.glob('../../skills/**/SKILL.md', {query:'?raw'})` → `loadSkillWithDetails` → `skillPlugin`

即参考实现走的是**本地运行时（local chat runtime）**，而 UCToo 走的是**远端 Agent（agentskills-runtime）**。
两者架构不同，参考实现不能直接照搬，但可以借鉴三个部分：工具注册写法、WebSkills 组织方式、PageTool 接入方式。

### 3.4 可借鉴点一：工具注册写法

`src/business/orders.ts`（应用级常驻工具）：

```ts
const modelContext = getModelContext()
modelContext.registerTool({
  name: 'order_query',
  description: '查询订单列表，可按订单号、客户姓名或状态筛选；不传参数时返回全部订单。',
  inputSchema: { type: 'object', properties: {...} },
  execute: async (input) => {
    // 复用页面现有状态，回写筛选条件，让 AI 回复与页面看到同一份数据
    orderFilterStatus.value = status ?? ''
    orderSearchText.value = orderId?.trim() || customerName?.trim() || ''
    return { content: [{ type: 'text', text }] }
  },
})
```

页面级工具（官方手册推荐写法），在 `onMounted` 注册、`onUnmounted` 用 `AbortController` 注销：

```ts
const abortController = new AbortController()
onMounted(() => {
  document.modelContext.registerTool({...}, { signal: abortController.signal })
})
onUnmounted(() => { abortController.abort() })
```

### 3.5 可借鉴点二：路由前置条件

`src/business/orders.ts` 中 `routeRequirement(router)`：当不在目标路由时，工具返回
`ROUTE_REQUIRED：请先使用 PageTool 点击 orders-navigation 进入 /orders，然后重试当前订单工具。`

这是"WebMCP Tool + PageTool 组合"的实用模式：**业务工具声明路由前置条件，由 PageTool 完成导航后重试**。
官方手册同时注明：next-sdk 0.4.11 未导出 `setNavigator`，无法在 adapter 层接路由跳转回调，
跨路由场景就是靠这种"返回前置条件 + 重试"处理的。

### 3.6 可借鉴点三：WebSkills 业务技能文档

`src/skills/orders/SKILL.md`，YAML frontmatter + 四段结构：

```md
---
name: orders
description: 订单查询技能。当用户需要查询订单列表、订单状态、客户订单或指定订单详情时使用。
---
# 订单查询
## 适用范围        <- 工具只在页面挂载后可用，不可用时不虚构结果
## 可用工具        <- order_query / order_detail
## 参数规则        <- 参数如何填、枚举值含义
## 工具选择        <- 什么意图用哪个工具、参数不足怎么办、未找到怎么办
```

装载方式（`src/tiny-robot-chat/skills/business-skills.ts`）：

```ts
const skillModules = import.meta.glob('../../skills/**/SKILL.md', { query: '?raw', import: 'default' })
const paths = await getMainSkillPaths(skillModules)          // @opentiny/next-sdk
const skill = await loadSkillWithDetails({ source: 'browser', fileList: [entry] })  // tiny-robot-kit
skillPlugin({ selection: () => ({ mode: 'manual', skills: skills.value }) })
```

### 3.7 可借鉴点四：PageTool 接入

初始化（`src/main.ts`）：

```ts
import { initializeBuiltinWebMCP } from '@opentiny/next-sdk'
import { registerPageAgentTool } from '@opentiny/next-sdk'

initializeBuiltinWebMCP()
initializePageTool()          // 内部调 registerPageAgentTool
registerOrderTools(router)
```

`src/tiny-robot-chat/pagetool/pagetool-init.ts`：

```ts
registerPageAgentTool({
  enableHighlight: false,
  removeMaskAfterToolCall: true,
  a11yConfig: {
    blacklist: ['.chat-add-window', '.chat-add-launcher', '.tr-sender', '.tr-bubble',
                '[data-page-tool-exclude="true"]', ...],
    whitelist: [...],
    exposedAttributes: ['data-page-tool-id', 'data-page-tool-action', ...],
  },
})
```

页面标记：

```html
<div class="orders-view"
     data-page-tool-id="orders-page"
     data-page-tool-action="query"
     aria-label="订单管理页面"></div>

<router-link to="/orders"
             data-page-tool-id="orders-navigation"
             data-page-tool-action="navigation"
             aria-label="进入订单管理"></router-link>
```

SKILL.md 中补充页面目标边界：

```md
## PageTool 页面目标
- orders-page：订单管理页面；允许动作：query
- orders-navigation：左侧"订单管理"导航；允许动作：navigation

## PageTool 禁止操作
- 不操作未声明的元素
- 不使用 fill、select 或 executeJavascript
- 不使用 PageTool 提交、删除、发布、支付或执行其他副作用
```

### 3.8 安全边界（官方明确要求）

> 提交、删除、发布、支付等操作必须使用带权限校验和确认机制的专用工具，不能通过 PageTool 或 Skill 开放。

这与本项目已有的 `web_request_approval` 审批工具方向一致。

## 4. 两条技术路线的对比

| 维度 | 参考实现（本地运行时） | UCToo（远端 Agent） |
|---|---|---|
| Agent 位置 | 浏览器 | agentskills-runtime（仓颉） |
| 模型调用 | 浏览器直连厂商 | runtime 聚合多厂商 |
| 工具执行 | 页面内 `executeTool` | 需跨进程：后端推送 → 前端执行 → 回传 |
| 后端能力 | 无（不参与） | Skill、记忆、长程任务、审批、权限 |
| 复杂度 | 低 | 高（多一跳网络往返） |
| 现状 | 官方推荐且可运行 | 后端已就绪，前端执行侧断开 |

**结论**：UCToo 不能改用本地运行时（会丢掉后端 Skill / 权限 / 审批 / 长程任务能力），
必须保留远端 Agent 架构，因此**必须解决跨进程工具调用这一跳**。
参考实现中可复用的部分是工具注册写法、WebSkills 组织、PageTool 接入；不可复用的是执行位置。

## 5. 指令下行通道的候选方案

`problem-analysis.md` 断点 1 指出专用 SSE 通道被关闭，且不能简单恢复。候选方案：

### 方案 A：恢复专用 SSE 并根治 "Empty request body"

- 做法：重新启用 `GET /api/v1/uctoo/webmcp/sse`，同时排查 v19 记录的根因
- 优点：改动最小，后端 `WebMCPToolHelper` 不用动
- 缺点：根因是浏览器连接池与后端请求体读取的交互问题，排查成本高；一个页面多一条长连接

### 方案 B：复用已建立的 MCP 传输（推荐）

- 做法：`WebMcpClient` 已与后端建立 MCP 连接（`type:'sse'` 或改为 WebSocket），
  tool_call 作为 MCP 层消息在同一连接上下行，前端执行后用 `tools/call` 结果或 `/tool-result` 回传
- 优点：不新增长连接，天然规避连接池问题；符合"优先使用标准协议"；后端已有 `/mcp` 端点
- 缺点：需要后端在 MCP 传输上支持服务端→客户端的主动请求，改动涉及 `WebMCPProtocol`

### 方案 C：改用 WebSocket 承载工具指令

- 做法：后端 `WebMCPController` 已有 WebSocket 实现，将 tool_call 改走 WS
- 优点：全双工，无连接池问题
- 缺点：需新增 WS 会话与 SSE 会话的映射管理

**建议采用方案 B**，方案 C 作为备选。最终选型在 `design.md` 中确认。

## 6. 研究结论

1. 参考实现证明了"页面注册业务工具 + WebSkills + PageTool"这套组合是官方认可的完成形态，
   其**工具注册写法、技能文档结构、PageTool 标记规范**可直接照搬到 web-admin。
2. 参考实现的执行位置在浏览器，UCToo 的执行位置在后端，**这一跳必须自己实现**，参考实现给不了答案。
3. 官方已明确 `document.modelContext` 是现行标准，`src/mcp-servers/` 的 WebMcpServer 模式应收敛。
4. 指令下行通道建议复用 MCP 传输（方案 B），避免重蹈 v19 的 "Empty request body"。
