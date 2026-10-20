# 复核：本实现 vs OpenTiny 官方指导手册

**复核日期**：2026-09-25
**对照原文**：《指导手册｜OpenTiny NEXT 四步实现业务应用通过自然语言智能操作页面》
（`https://mp.weixin.qq.com/s/3w1DjIsQjLBDqgWU5qhNFg`，OpenTiny，2026-09-23）
**本地存档**：`apps/web-admin/web/docs/opentiny-webmcp-agent-article.md`（含 8 张配图 + 2 段视频链接）
**复核对象**：`apps/web-admin/web` 中 webmcp-agent-web-operation 的落地代码
**复核结论（一句话）**：**核心机制与官方同构**（页面级 WebMCP 工具 + WebSkills + PageTool + 黑名单），**两处有意偏离**（不引 GenUI、导航走应用级 `navigate_url` 而非 PageTool 点击），**一处真实差距**（未使用官方 Step 4 的 `data-page-tool-*` 页面目标声明 + policy 授权）。

---

## 一、官方四步 vs 本实现：逐条对照

官方把一个 Vue 3 + Vite 业务应用改造成"可被自然语言操作"分四步。我们逐条对表：

| 官方步骤 | 官方做法 | 本实现 | 判断 |
|---|---|---|---|
| **Step 1** 添加 TinyRobot Chat | `/opentiny-next-app-integration` 生成接入；`.env` 填模型 Key（`VITE_DEEPSEEK_API_KEY` 等） | `next-remoter` 的 TinyRobotChat 已存在；**模型 Key 不落在前端**——对话走远端 agentskills-runtime，前端只持 `AGENT_URL` | 同构、不同部署形态 |
| **Step 2** 集成 GenUI SDK | `.env` 配 `VITE_GENUI_URL` / `VITE_GENUI_PROMPT_ID`，Sender 底部出现 GenUI 按钮，AI 返回可交互 UI | **未接入**：`web/src` 内无 genui 引用（早前为去掉 `@opentiny/tiny-schema-renderer` 重依赖而摘除该链路） | **有意偏离**（历史决定，非缺失） |
| **Step 3** WebMCP + WebSkills | ① 页面挂载时 `document.modelContext.registerTool()` 注册，卸载 `AbortController.abort()` 注销；② 写 `src/skills/<业务>/SKILL.md`；③ 工具四要素 `name`/`description`/`inputSchema`/`execute`；④ **工具由开发者按真实业务定义，Agent 不自行生成** | ① `src/mcp-servers/registerPageTool.ts:39-78` 本地兼容壳，内部正是 `document.modelContext.registerTool(...)` + `AbortController`（`registerPageTool.ts:55-64` / `71-77`），**100+ 业务页面**（含 `entity-table.vue:617`）走同一模式；② `src/skills/{entity-operator,uctoo-operator,tiny-pro-operator,...}/SKILL.md` 已存在；③ 工具元数据齐备；④ 工具来自各页面挂载时的显式声明 | **同构**（API 用法、生命周期、作用域一致） |
| **Step 4** PageTool 页面查询与导航 | ① 页面元素标 `data-page-tool-id` / `data-page-tool-action` / `aria-label`，并配 adapter policy；② `a11yConfig.blacklist` 排除不可访问区；③ 写 PageTool Skill（页面目标 / 允许动作 / 与业务工具边界 / 禁止操作） | ① **未使用 `data-page-tool-*`**（全库 0 处，仅出现在 `pagetool-init.ts` 的 `exposedAttributes` 与 vendored lib 内）；② `pagetool-init.ts:42-50` 已配 `a11yConfig.blacklist`（排除 `.chat-add-window` / `.tr-sender` / `.tr-bubble` 等 AI 界面）；③ PageTool 边界写在 `uctoo-operator/SKILL.md` 的"核心约束" | **部分同构**：② 完全对齐，① **缺失**，③ 等价但未单列章节 |

---

## 二、关键机制对照（同构的部分，值得确认）

### 1. 业务工具注册机制 —— 完全同构

官方示例（`codelabs-demo` 的 `order_query`）：

```
onMounted → document.modelContext.registerTool({name, description, inputSchema, execute}, {signal})
onUnmounted → abortController.abort()
```

本实现（`entity-table.vue:616-698`）：

```ts
onMounted(async () => {
  cleanupPageTool = registerPageTool({
    route: '/database/uctoo/entity',
    handlers: { 'query-entity-list': async (params) => { /* 设筛选 + 刷表 + 返回真实数据 */ }, ... }
  })
})
// registerPageTool 内部：modelContext.registerTool({name,title,description,inputSchema}, handler, {signal})
// 返回 cleanup → 卸载时 abortController.abort()
```

- 注册 API、`signal` 注销、**页面生命周期绑定**三件事与官方一致；
- 工具返回值也是官方的 `{ content: [{ type: 'text', text }] }` 形状；
- 工具作用域是**页面级**（随页面挂载出现、卸载消失），与官方"避免模型看到已不可用的工具"的设计意图相同。

官方特别强调 **"Agent 不根据页面字段、按钮或示例工程自行生成业务工具"**——我们的工具来自 crudgen 生成的页面 + 人工在 `registerPageTool({handlers})` 里显式声明，同样是"开发者定义"，符合该原则。

### 2. WebSkills —— 同构

官方 `src/skills/orders/SKILL.md` 的 frontmatter（`name` / `description`）+ 正文分节（适用范围 / 可用工具 / 参数规则 / 工具选择）——我们的
`src/skills/entity-operator/SKILL.md`、`uctoo-operator/SKILL.md` 结构一致，且额外通过 App.vue 的 `system-overview` 工具
（`App.vue:409-416`）把 `uctoo-operator` 全文注入给 Agent，等价于官方"Skill 给 Agent 业务知识"的第 ③ 层。

### 3. PageTool 黑名单 —— 同构

官方：

```
registerPageAgentTool({ a11yConfig: { blacklist: ['.chat-add-window', '.chat-add-launcher', '[data-page-tool-exclude="true"]'] } })
```

本实现（`pagetool-init.ts:42-50`）：同样的 `a11yConfig.blacklist`，排除项是 `.chat-add-window` / `.chat-add-launcher` / `.tr-sender` / `.tr-bubble` / `.tr-remoter` / `[data-page-tool-exclude="true"]`。
官方说"TinyRobot 对话框已经在 PageTool 配置中排除"，我们用 `.tr-*` 选择器达到同一效果并多加了两条，**属于加强而非偏离**。

### 4. 副作用红线 —— 同构

官方："提交、删除、发布、支付等操作必须使用带权限校验和确认机制的专用工具，不能通过 PageTool 或 Skill 开放。"
本实现：`tasks.md` 前端规范明写同一条；`delete-entity` / `edit-entity` 等是**专用工具**（页面 handler 内调真实业务 API），未下放给 PageTool。

---

## 三、真实差异（需要判断要不要补）

### 差异 1（真实差距）：未声明 `data-page-tool-*` 页面目标，也没有 adapter policy

官方 Step 4 的完整语义是**两件事**，缺一不可：

> "页面属性提供稳定语义，adapter policy 负责执行前授权，**两者不能互相替代**。"

官方做法：在导航项、容器上打 `data-page-tool-id="orders-navigation"` / `data-page-tool-action="navigation"` / `aria-label`，再用**同一份 action/target 声明**配置 adapter policy。

本实现：**只做了黑名单，没做页面目标声明**。PageTool 目前依赖 next-sdk 自动生成的 a11y 树去"发现"可点元素，而非读取我们显式声明的稳定语义。

**影响**：在未适配 WebMCP 的页面上，Agent 定位元素的稳定性弱于官方；且缺少"执行前授权"这一层，安全边界只靠黑名单（白名单语义），而非"显式允许的动作集合"。

**建议**（低风险、渐进）：
1. 先在**导航项**上按官方写法打属性（侧边菜单是最稳的导航入口），例如给 entity 菜单项加 `data-page-tool-id="nav-entity" data-page-tool-action="navigation" aria-label="进入Entity管理"`；
2. 再把 `pagetool-init.ts` 的 `exposedAttributes`（已含 `data-page-tool-id`/`data-page-tool-action`/`aria-label`）与 `whitelist` 配合使用，把这批目标显式纳入；
3. adapter policy 是否引入，取决于 next-sdk 当前版本是否暴露对应配置入口——**先确认再动**，不要凭空写 policy。

### 差异 2（有意偏离）：导航走应用级 `navigate_url`，而非 PageTool 点击

官方 Step 4 的分工是"**PageTool 负责 navigation**"——点击 `orders-navigation` 进入订单页；调用链是
`PageTool 观察当前页 → PageTool 点击订单导航 → order_detail 查询并定位 → 回复`。

本实现的分工是：**导航用应用级 `navigate_url` 工具**（`App.vue:391-407`，`execute` 即 `router.push(url)`），`uctoo-operator/SKILL.md:165` 甚至把它写成硬约束：

> "路由跳转规则：只使用 `navigate_url` 工具进行路由菜单跳转"

**权衡**：
- 好处：`router.push` 是**确定性直达**，不依赖 a11y 定位与元素可见性，长链路更稳；我们的验收句"打开 entity 表页面并查询"只需要一步确定跳转。
- 代价：与官方 policy 授权模型脱节；且 `tasks.md` 的 **T-010 / TC-002 自己写的是"Agent 用 PageTool 点击侧边导航"**——即**规格与实现不一致**，need 对齐（要么改规格，要么补 PageTool 导航路径）。

**建议**：保留 `navigate_url` 作为主路径（已可用），把 TC-002 的措辞改为"PageTool 点击导航 **或** navigate_url 直达，二者取一"，或明确"优先级：navigate_url 直达 → 失败降级 PageTool 点击"。

### 差异 3（缺口）：SKILL 未写"专用工具已定位则免 PageTool 复核"这条边界

官方在业务 Skill 与 PageTool Skill 里**重复强调**同一条，用来压缩调用链：

> "`order_detail` 已返回页面筛选结果时，无需使用 PageTool 重复确认；其他未完成任务不受此限制。"

本实现的两个 SKILL **没有这条**。后果：Agent 可能在 `query-entity-list` 已经把表格筛好之后，又用 PageTool 去"看一眼确认"，产生多余的往返（官方那张 `image06` 截图的核心就是"最短调用链"）。

**建议**：在 `entity-operator/SKILL.md` 的"端到端自动操作"一节补一句等价表述，例如：
> "`query-entity-list` 返回的即为页面当前筛选结果（含 link 包含匹配），拿到结果后直接回答，无需再用 PageTool 复核页面。"

### 差异 4（实现细节，一致性）：`navigator.modelContext` 与 `document.modelContext` 混用

官方通篇用 `document.modelContext.registerTool()`。本实现里：
- 页面级工具（100+ 页）走 `registerPageTool` → **`document.modelContext`**（正确）；
- App.vue 的三个应用级工具（`get_skill_content` / `navigate_url` / `system-overview`）走 **`navigator.modelContext.registerTool`**（3 处，仅 App.vue）。

二者当前是同一对象的别名，功能无差异，但 vendored next-sdk 里已有"`navigator.modelContext` 废弃警告"的兼容测试用例，混用有轻微技术债。

**建议**：统一为 `document.modelContext`（官方口径）。

---

## 四、架构层面的一处本质差异（非对错）

官方截图里 Agent 调用的工具名是 `browser-webmcp__order_detail`、`browser-webmcp__page-agent-tool`——说明**官方把"执行器"内建在 next-sdk 的 TinyRobot adapter 里**，文章 Step 3/4 只管"注册 + 声明"，没有教读者写执行器。

我们的 Agent 跑在**远端**（agentskills-runtime），前端与 Agent 之间是 **SSE 下行 + HTTP 上行**，所以必须自建执行器：

```
后端下推 tool_call（SSE）
  → App.vue:197-227 收到 → window.postMessage('next-sdk:tool-call')
  → tool-executor.ts:79-115 监听 → getTools() 取 descriptor → document.modelContext.executeTool(descriptor, JSON.stringify(args))
  → window.postMessage('next-sdk:tool-response')
  → App.vue:151-177 POST /api/v1/uctoo/webmcp/tool-result 回传
```

对应 `tool-executor.ts` 里几处**官方没有、我们特有**的设计：
- 30s 单工具超时（`TOOL_TIMEOUT_MS`），不无限阻塞；
- 未知工具（页面已卸载）**显式回 error**，不静默失败——正好覆盖 `tasks.md` 的 TC-003；
- `web_*` 前缀后端内置工具**跳过**，把 `web_request_approval` 让给 `ApprovalOptionsCard`，避免抢回传。

这些属于"因为我们架构更分散，所以必须显式化"的部分，方向正确，无需向官方靠拢。

---

## 五、结论与待办

**同构（对齐官方，无需动作）**：页面级 WebMCP 工具注册机制与生命周期、WebSkills 结构、PageTool 黑名单、副作用红线、"开发者定义工具、Agent 不自行生成"原则。

**有意偏离（保留）**：不引 GenUI SDK（依赖成本）；`navigate_url` 作导航主路径（确定性更高）。

**建议补齐（按性价比排序）**：

| 优先级 | 事项 | 落点 |
|---|---|---|
| P1 | SKILL 补"专用工具已返回页面筛选结果则免 PageTool 复核" | `src/skills/entity-operator/SKILL.md` |
| P1 | 对齐规格与实现：TC-002 的"PageTool 点击导航"表述 | `specs/webmcp-agent-web-operation/tasks.md` |
| P2 | 导航项补 `data-page-tool-*` 属性（先只做侧边导航），并把目标显式纳入配置 | `App.vue` 布局 + `pagetool-init.ts` |
| P3 | 统一 `navigator.modelContext` → `document.modelContext` | `App.vue`（3 处） |
| P3 | 评估引入 adapter policy 的可行性（先确认 next-sdk 是否暴露配置入口） | 待勘察 |

**仍未验证（与本文无关但影响验收）**：`npm start` 运行时链路（`[tool-executor] 已启动` / `[pagetool] registerPageAgentTool 已初始化`）+ 验收句端到端；T-005 后端工具同步（`builtin:true` 是否把页面级 `query-entity-list` 同步进 Agent ToolManager）。
