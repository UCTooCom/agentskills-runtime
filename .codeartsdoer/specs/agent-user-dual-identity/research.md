# 研究文档：Agent / 用户双账号身份、委派路由与 creator 归属

> 本文件是 `agent-user-dual-identity` 规格的研究底稿，承接 2026-09-19 ~ 09-20 的两次长程任务失败排查。
> 相比 09-20 早先在 `docs/design/agent-user-dual-identity.md` 的初版，本文**修正了两处关键误判**：
> 1. 真实聊天通道是 **WebMCP / MCP**（`/api/v1/uctoo/webmcp/mcp`），**不是** `WsChatController`；
> 2. LRT 委派路由**已经在 `WebMCPProtocol` 里实现**（显式前缀 `长程任务：`/`/lrt`），之前基于
>    `SkillToToolAdapter` → `BaseSkill.execute`（空实现死路）得出的"LRT 被绕过"是**误判**——死路是另一条，
>    活路是前缀路由。

---

## 0. 问题来由（事实链）

- 用户两次让 agent「跑长程任务，查找去年高考物理题并解题」，runtime 端**没跑完**，前端一直 loading。
- 09-19 日志 + `public20260920.sql` 显示：`agent_tasks` 出现 `status=2 result=NULL`（被标完成但无结果）
  与 `status=1 result=None`（连终态都没走到）；`long_running_task` 表行数存疑。
- 09-19 已修复的 **P0 静默死亡 bug**：`ReactExecutor.asyncRun` 的 spawn 块无异常捕获，任何异常冒泡到
  `AsyncAgentResponse.next()` 的 catch → `finishFn(false)` → `AgentEndEvent(None)` → `onAgentEnd` 走
  `case None => 2`（硬编码 completed），任务被标完成但 result 为空。这条死法表现为「前端永远 loading」。
- 配套修了 4 个文件：react_executor（加异常隔离 + `setTerminationReason(Error)`）、
  agent_persistence_event_handler（`case None` 改写 status=3 + 可读失败原因）、
  python_executor_tool（读流容错 + 注入 UTF-8）、checkpoint_manager（合法 filter）；web_tools.cj 已手动覆盖。

> 结论：若用户**没用** `长程任务：`/`/lrt` 前缀，请求走普通 ReAct，命中了 P0 死法；若**用了**前缀，
> 走 `WebMCPProtocol.handleLongRunningTaskRoute` → `LongTaskApiService.submitTask`（活路），但 **creator 归因
> 仍全部记成人类用户 id**（见 §3.4），且 agent 从未以自身身份参与。

---

## 1. 真实聊天 / 委派链路（已核实，修正旧误判）

### 1.1 通道是 WebMCP，不是 WebSocket 聊天控制器

- 前端 `web-admin/web/src/App.vue:44`：`MCP_URL = import.meta.env.VITE_WS_URL || \`${AGENT_URL}/api/v1/uctoo/webmcp/mcp\``。
- 前端 `web-admin/web/src/mcp-servers/chat/tools.ts:26`：`WS_URL = .../webmcp/mcp`。
- 后端 `WebMCPController`（`src/app/controllers/uctoo/webmcp/WebMCPController.cj`）处理 `/webmcp/mcp`
  （streamableHttp + WebSocket + SSE 三路）。
- `WsChatController.cj` 是**另一条未被前端启用的通道**，上一轮据此分析 token 携带是**偏差**，本文以 WebMCP 为准。

### 1.2 userId 的传入方式（非 JWT 解码）

- `WebMCPController._extractUserId(req)`（`cj:1086`）：优先 query 参数 `userId`，其次请求头 `X-User-Id`，
  最后空串。即 **userId 由前端随请求带上**，不是从 access_token 解出。
- `WebMCPProtocol.setSessionInfo(sessionId, clientId, userId)`（`cj:186`）把它存为 `_userId`，
  后续 `handleLongRunningTaskRoute` 直接把 `_userId` 透传给 `submitTask`（`cj:1707`）。

### 1.3 LRT 委派路由（活路，已存在）

- 触发前缀：`LRT_TRIGGER_PREFIXES = ["长程任务:", "长程任务：", "/lrt"]`（`WebMCPProtocol.cj:41`）。
- 抽取：`extractLrtGoal(userMessage)`（`cj:1657`）——必须出现在消息**开头**。
- 路由：`handleMessage` → `extractLrtGoal` 命中 → `handleLongRunningTaskRoute(goal, requestId)`（`cj:1545-1547`、`cj:1685`）。
- 落地：`LongTaskApiService.submitTask(goal, agentId, ..., _userId, _sessionId, "")`（`cj:1701`），
  内部 `建根任务 → 建 crontab 调度 → LrtPluginClient.plan() → 立即首回合`。
- **这条路径是 LRT 子系统真正被调用的方式，与 `SkillToToolAdapter` 那条死路无关。**

### 1.4 另一条死路（作为对照，非本次主因）

- `SkillAwareAgent._registerSkillsAsTools()` 把 `long-running-task` 注册成 MainAgent 的工具；
  `SkillToToolAdapter.invoke()` → `_skill.execute(args)`；但 `BaseSkill.execute` / `AbsSkill.execute`
  是**空实现**（只返回 `"Skill X executed with arguments: ..."`），`LrtCompositionRunner` 全库**无实例化调用**。
  ⇒ 即便模型调 `long-running-task` 工具，也只是空转。**这条是死路**，但前端实际走的是 1.3 的前缀路由，
  所以"LRT 被绕过"的准确含义是：**模型默认的复杂任务不会自动走 LRT，必须用户/模型显式加前缀**（或 AGENTS.md 指导）。

---

## 2. 双账号身份现状（代码实证）

### 2.1 agent 确有独立 uctoo_user 帐号

- `AipIdentityService.registerLocalIdentity`（`src/app/services/aip/AipIdentityService.cj:28/77`）：
  建 `UctooUserPO`，`userType="agent"`、用户名 `agent_<短id>`，挂 `agents` 角色 + `agents` 用户组；
  `AgentsPO.userId` 指向该 uctoo_user。
  ⇒ agent 是 `uctoo_user` 一等公民，有自己的 `id`。

### 2.2 agent 自动登录（仅 AIP 互联端点调用，本地路径未接入）

- `AgentAuthService.agentAutoLogin(agentId)`（`src/app/services/aip/AgentAuthService.cj:27`）：
  - 取 agent 关联 uctoo_user（`userType=="agent"` 才放行，`cj:45`）；
  - `generateAgentToken(user.id)` 给 **agent 自己的 uctoo_user.id** 签发 JWT（`cj:57`）；
  - token 经 HTTP 响应返回（`AipIdentityController.cj:87`），**只返回，不注入运行时**。
- 全库检索：`agentAutoLogin` 唯一调用点在 `AipIdentityController`（AIP `/aip/identity/agent-login`），
  **WebMCP 路径、前端登录链路均无调用**。
  ⇒ "用户登录时 agent 同步自动登录"目前**仅存在于设计意图，未落地**。

### 2.3 JWT 密钥（决策 #2 直接澄清）

| 密钥 | 位置 | 用途 |
|---|---|---|
| config `jwtSecret` | `src/app/main.cj:480` | 用户 token 校验（DeserializeUserMiddleware 实例 A） |
| `uctoo-v4-secret-key`（硬编码） | `src/app/registry/AutoRouteRegistry.cj:110` | AutoRoute 注册的路由的 DeserializeUserMiddleware 实例 B |
| `aip-agent-secret-key` | `src/app/services/aip/AgentAuthService.cj:20` | **仅 AIP 互联模式** agent token |

- 经核对 `aip-implementation/spec.md` 与 `design.md`：`aip-agent-secret-key` 是 **GB/Z 185 智能体互联**
  协议的专用密钥，仅用于 `/aip/identity/agent-login`（互联模式）。**本地独立运行的 agent 不需要 AIP 特性，
  不应使用这把密钥。**
- ⇒ 决策 #2 的准确落地：**密钥统一 = 本地模式下用户与 agent 共用同一把 config 密钥**（使 agent token
  可被现有 DeserializeUserMiddleware 验过）；`aip-agent-secret-key` **保持 AIP 互联专用、不并入本地校验**。
  附带：`AutoRouteRegistry.cj:110` 硬编码 `uctoo-v4-secret-key` 与 config 密钥不同源，是独立 bug，
  应一并统一为 config 密钥（避免 long_running_task 系列路由用错密钥静默 401）。

### 2.4 token 携带真相（断链确证）

- 出站调用取 token：`SessionContext.getAccessToken()`（`src/tool/token_manager.cj:195`）。
- `agentAutoLogin` 的 token 只经 HTTP 响应返回，**全库无任何代码把它写入 `TokenManager`/`SessionContext`**
  （`setToken` 仅出现在 `http_tool.cj:225` 的登录响应解析）。
- ⇒ agent 的"同步登录"目前是**孤立 token**，运行时没接入；agent 出站调用要么无 token，要么借用户身份。

---

## 3. creator 归属现状（决策 #1 的焦点）

### 3.1 LRT 全链路把 userId 当作 creator

`LongTaskApiService.submitTask`（`src/app/services/lrt/long_task_api_service.cj:71`）：
- `taskPO.creator = Some(userId)`（`cj:104`）
- `crontabPO.creator = Some(userId)`（`cj:136`）
- `LrtPluginClient.plan(taskId, goal, userId, …)`（`cj:171`）/`.execute(…, userId, …)`（`cj:187`）传同一 userId。

`userId` 来自 WebMCPProtocol 透传的人类用户 id。**插件侧据此写 `long_running_task`/`artifact`/`evolution` 时
creator = 人类用户 id，agent 从不作为执行者出现。**

### 3.2 审计也不区分 agent 与人类

`OperateLogService.resolveAuditActorType`（`src/app/services/uctoo/OperateLogService.cj:1176`）：
逻辑是"userId 非空 → user，否则 plugin → system"。agent 的 uctoo_user.id 也是 userId，会被记成 `user`，
**不区分「agent 真人」与「人类用户」**。

### 3.3 表结构缺口

- `agent_tasks` 的 `creator` 是 `Option<String>`，无 `owner_user_id`/`actor_type` 区分列
  （`src/app/models/uctoo/AgentTasksPO.cj:50`）。
- `long_running_task` 同理缺 `owner_user_id`。

---

## 4. 三项决策（用户已拍板，2026-09-20）

1. **creator（执行者）+ owner_user_id（所有者）分离模型**：agent 自主执行的产出，creator 写 agent 的
   uctoo_user.id；owner_user_id 写委派/拥有该任务的人类用户 id。
2. **密钥统一，但 `aip-agent-secret-key` 保持 AIP 互联专用**：本地模式 agent 自动登录应使用 config 密钥
   （与用户同钥，DeserializeUserMiddleware 本就接受），不并入 `aip-agent-secret-key`；同时修掉
   `AutoRouteRegistry.cj:110` 硬编码不一致。本地独立运行无需 AIP 特性。
3. **agent 会话接入点 = 用户从 web 登录时同步自动登录**：在 WebMCP 会话建立（携带 userId）处，触发 agent
   本地自动登录（config 密钥签发），把 agent 的 token 接入运行时，供 LRT 写入 creator=agent id。

---

## 5. 修正后的设计要点（详见 design.md）

- **委派路由修正（关键）**：上一轮在 AGENTS.md 加的「复杂任务应调用 `long-running-task` 工具」规则**指向死路**
  （`SkillToToolAdapter`→`BaseSkill.execute` 空实现）。正确指引应是：复杂/多步任务用
  **`长程任务：<目标>` 或 `/lrt <目标>` 前缀**提交，由 `WebMCPProtocol` 路由到 LRT 活路。
  （AGENTS.md 委规章节需同步修正；见 tasks.md T5。）
- **creator/owner 双字段**：`long_running_task` 与 `agent_tasks` 各加 `owner_user_id`；`submitTask` 改写
  `creator = agent 的 uctoo_user.id`、`owner_user_id = 人类 userId`（经 WebMCP 透传）。
- **agent 本地登录接入**：`AgentAuthService.agentAutoLogin` 增加 `mode` 参数，本地模式用 config 密钥；
  WebMCP 会话初始化时调用并把 token 存入 `TokenManager`（独立 agent sessionId）。
- **审计 actorType**：`resolveAuditActorType` 据 `uctoo_user.userType` 区分 `agent`/`user`/`system`。

---

## 6. 待办（转入 tasks.md 跟踪）

- T1 研究写档 ✅（本文件）
- T2 出 spec.md / design.md
- T3 `owner_user_id` 列 + `submitTask` creator/owner 改写
- T4 agent 本地自动登录接入 WebMCP 会话（含 TokenManager 注入）
- T5 AGENTS.md 委派规则修正（前缀而非技能工具）+ SKILL.md 对齐
- T6 审计 actorType 按 userType 区分
- T7 `AutoRouteRegistry.cj:110` 硬编码密钥统一为 config 密钥
- T8 （可选）死路 `SkillToToolAdapter`→`BaseSkill.execute` 的清理/接线决策
