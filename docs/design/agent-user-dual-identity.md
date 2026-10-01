# Agent / 用户双账号身份与 creator 归属设计分析

> 背景：长程任务（LRT）子系统的 `lrt-plan`/`lrt-execute` 路由虽已注册，但 MainAgent 从未委派，
> 根因之一是技能执行体 `BaseSkill.execute` 为空实现、`LrtCompositionRunner` 未接线（见上一轮分析）。
> 接上执行链路需要把 `userId`/`permissions` 从 Agent 请求透传到技能执行体——
> 而这件事牵出更深的问题：**agent 与用户两套帐号的登录、token 携带、creator 归属目前是断链的**。
> 本文档基于代码实证给出现状研判与落地建议，作为"双账号身份"这一悬而未决问题的决策依据。

---

## 一、先澄清：上一轮提的"3 方案"是顺序实施，不是替代方案

三者构成**同一个实现的三个先后步骤**，彼此依赖，缺一不可：

```
方案1 新增 CompositionSkill <: BaseSkill
        └─(被谁实例化?)──▶ 方案2 skill_factory 探测到 COMPOSITION.yaml 时建 CompositionSkill
                              └─(执行体内部怎么调插件?)──▶ 方案3 LrtPluginCaller 按路由映射
                                                          lrt-plan → LrtPluginClient.plan
                                                          lrt-execute → LrtPluginClient.execute
                                                          lrt-verify → LrtPluginClient.verify
```

- **不是**"三选一"：它们不是三套平行设计，而是"定义类 → 接线工厂 → 实现调用映射"的链路。
- **还藏着一个前置条件**（也正是本轮要解决的）：方案 1/2/3 要让 agent 以**自己的身份**调到插件，
  必须先把 `userId`/`permissions` 从 `AgentRequest` 透传到 `CompositionSkill.execute`，
  否则插件侧拿到的是 `None`/`""`，行级权限与 creator 全部失真。

---

## 二、系统现状（代码实证）

### 2.1 双账号：agent 确有独立 uctoo_user 帐号

- 注册本地身份时，`AipIdentityService.registerLocalIdentity`
  （`src/app/services/aip/AipIdentityService.cj:28`）会建一条 `UctooUserPO`，
  `userType = "agent"`、用户名 `agent_<短id>`，并挂 `agents` 角色 + `agents` 用户组；
  `AgentsPO.userId` 指向该 uctoo_user（`AipIdentityService.cj:77`）。
  ⇒ **agent 是真实存在于 `uctoo_user` 表的一等公民，有自己的 `id`**。

- agent 自动登录 `AgentAuthService.agentAutoLogin`
  （`src/app/services/aip/AgentAuthService.cj:27`）：
  - 取 agent 关联的 uctoo_user（`userType == "agent"` 才放行，`cj:45`）；
  - `generateAgentToken(user.id)` 给 **agent 自己的 uctoo_user.id** 签发 JWT（`cj:57`）；
  - 把 token 写回 `user.accessToken` 并经 HTTP 响应返回（`cj:58-63`）。
  ⇒ agent 确实"登录了自己的帐号"，拿到了自己的 token + 自己的 userId。

### 2.2 三把互不认的 JWT 密钥（根因之一）

| 密钥 | 位置 | 用途 |
|---|---|---|
| config `jwtSecret` | `src/app/main.cj:480` | 用户 token 校验（DeserializeUserMiddleware 实例 A） |
| `uctoo-v4-secret-key`（硬编码） | `src/app/registry/AutoRouteRegistry.cj:110` | 路由注册表的 DeserializeUserMiddleware 实例 B |
| `aip-agent-secret-key` | `src/app/services/aip/AgentAuthService.cj:20` | **agent token**（仅 AgentAuthService 用） |

- `DeserializeUserMiddleware` 校验 token 时用的是实例 A / 实例 B 的密钥（用户密钥），
  **绝不认 `aip-agent-secret-key`**（`JWTUtil.verifyToken` 按 secret 校验，`src/app/utils/auth/JWTUtil.cj:97`）。
  ⇒ **即使把 agent token 带上去，任何 HTTP 端点都会因验签失败而 401**。两把锁互不相通。
- ⚠️ 附带风险：`AutoRouteRegistry.cj:110` 硬编码 `uctoo-v4-secret-key`，与 `main.cj` 的 config 密钥不同源。
  若 config 的 `jwtSecret` 实际值 ≠ `uctoo-v4-secret-key`，则经 `AutoRouteRegistry` 注册的路由
  （含 long_running_task 系列）会用错误密钥校验**用户** token，可能导致整类接口静默 401。
  → 需确认 config `jwtSecret` 取值；建议统一为一把 config 密钥。

### 2.3 token 携带真相（断链确证）

- 用户登录 → WebSocket 会话：`WsChatController._handleChatMessage`
  （`src/app/controllers/uctoo/ws/WsChatController.cj:271-272`）在每次对话入口执行
  `sessionContext.setCurrentSession(session.sessionId)`——**currentSession 设的是用户的会话**。
- agent 执行时出站调用经 `SessionContext.getAccessToken()`
  （`src/tool/token_manager.cj:195`）取 currentSession 的 token = **用户的 access_token**。
  ⇒ **agent 从未携带自己的 token；它全程借用用户身份行动**。
- `agentAutoLogin` 产出的 agent token **只通过 HTTP 响应返回给调用方**
  （`AipIdentityController.agentLogin`，`src/app/controllers/aip/AipIdentityController.cj:87`），
  全代码库**没有任何地方**把它写入 `TokenManager`/`SessionContext` 供 agent 运行时使用
  （`setToken` 仅出现在 `http_tool.cj:225` 的登录响应解析里）。
  ⇒ agent 的"同步登录"目前是**孤立 token**，运行时根本没接入。
- 已审查的 `WsChatController` 会话入口**未见调用 `agentAutoLogin`**：所谓"用户登录 agent 同步登录"
  若真发生，应在前端或登录链路另行触发，而非运行时自动完成。

### 2.4 creator 归属现状：所有"agent 行为"都以用户身份落库

- LRT 提交流程 `LongTaskApiService.submitTask`
  （`src/app/services/lrt/long_task_api_service.cj:71`）：`userId` 来自
  `LongRunningTaskController.add` 的 `requireUser(req,res)`（用户 token），
  - `taskPO.creator = Some(userId)`（`cj:104`）
  - `crontabPO.creator = Some(userId)`（`cj:136`）
  - `LrtPluginClient.plan(taskId, goal, userId, …)` / `.execute(…, userId, …)`（`cj:171` / `cj:187`）传同一 userId。
  ⇒ 插件侧据此写 `long_running_task`/`artifact`/`evolution` 时 creator = **人类用户 id**。
- `agent_tasks` 表 `creator` 是 `Option<String>`，无 `owner_user_id`/`actor_type` 区分列
  （`src/app/models/uctoo/AgentTasksPO.cj:50`）。
- 审计日志虽有 `actorType`（`OperateLogService.resolveAuditActorType`，
  `src/app/services/uctoo/OperateLogService.cj:1176`），但逻辑是"userId 非空→user，
  否则 plugin→system"——**agent 的 uctoo_user.id 也是 userId，会被记成 `user`**，
  并不区分"agent 真人"与"人类用户"。
  ⇒ 当前系统**在归因层完全不区分 agent 与人类**，凡是 agent 操作都借用户身份记帐。

---

## 三、建议（对应你的哲学立场）

### 3.1 creator 归属：支持"agent 操作填 agent id"，并补"所有权"字段

你的立场——*agent 与人类行为对齐，agent 操作应如实把 creator 填为 agent 的 uctoo_user.id*——**正确且应落地**。
但"执行者"与"所有者/责任归属"是两件事，建议双字段分离：

| 字段 | 含义 | 取值 |
|---|---|---|
| `creator` | **实际执行写操作的主体** | agent 自主跑 = agent 的 uctoo_user.id；用户手点 = 用户 id |
| `owner_user_id`（新增） | **任务归属的真人** | 始终 = 委派/拥有该任务的人类用户 id |

理由：
- 满足对齐哲学：agent 自主执行（cron 触发、self-evolution、被委派的复杂任务）的产出，creator 写 agent id，责任清晰。
- 保留所有权/责任追溯：合规、数据隔离、审计、权限归属仍锚定到人类 owner，避免"agent 干了啥归不到人"。
- `agent_tasks` 已有 `agentId`，LRT 任务树可再加 `submitter`（= owner_user_id）；宿主建根任务时
  用 `owner_user_id = requireUser 的 userId`、`creator = agent 的 uctoo_user.id`。
- 审计日志 `resolveAuditActorType` 应据 `uctoo_user.userType` 判定 `agent`/`user`/`system`，而非只看 userId 非空。

### 3.2 权限：agent 帐号需独立授权边界

- `DataAccessAuthorizationService` 按 `userId` 做行级权限。agent 用自己的 id 才有独立权限边界；
  若一直借用户 token，agent 能力被该用户权限天花板限制，且无法对 agent 单独审计/封禁。
- agent 的 uctoo_user 目前仅 `agents` 角色（`AipIdentityService.cj:55`），需按"agent 能执行哪些表/技能"
  显式授予 `user_has_roles` / `data_access_authorization`，避免"agent 用自己的 token 却被权限中间件拦死"。

### 3.3 token 携带方案（打通断链，按风险分步）

**前置（必做，低风险）：统一密钥**
- `DeserializeUserMiddleware` 必须能验 agent token：把 `aip-agent-secret-key` 并入可接受密钥集，
  **或**三把合并为一把 config 密钥（同时修掉 2.2 的硬编码 `uctoo-v4-secret-key` 不一致）。
  不做这步，agent token 永远被拒，下面都白搭。

**第一步（中风险，建议先做）：把 agent 登录接入运行时会话**
- 在"用户登录 / agent 会话初始化"处调用 `agentAutoLogin(agentId)`，
  **把返回的 token 存入 `TokenManager`（以一个独立的 agent sessionId）**，而非只返回前端。
- 这样运行时持有 agent 的 token，可被出站调用使用。

**第二步（中风险）：执行上下文切换**
- 明确"谁在行动"的边界：用户直接操作（前端 HTTP）→ 用用户 session；
  agent 真正执行（ReAct 步骤、技能委派、cron）→ 把 `currentSession` 切到 agent 的 session，
  使出站调用带 agent token、落库 creator = agent id。
- 需要界定切换点（如 `SkillToToolAdapter.invoke` 进入技能执行前切到 agent session，退出后还原），
  并防范并发会话串号。

**第三步（承接上一轮 3 方案）：透传 userId/permissions 到技能执行体**
- `SkillToToolAdapter` → `CompositionSkill.execute(args)` 必须把 `AgentRequest` 里的
  `userId`（= agent 的 uctoo_user.id）/ `permissions` 往下传，最终喂给 `LrtPluginCaller` → `LrtPluginClient`。
- in-process 调用（cordis JSON-RPC）已直传 userId、不经 HTTP token，无需 agent token；
  仅当 agent 出站 HTTP 调宿主 CRUD 路由时才需 agent token（见第二步）。

### 3.4 取舍与风险

| 方案 | 优点 | 风险 |
|---|---|---|
| 维持"agent 借用户 token" | 零改动、简单 | 违反对齐哲学；责任模糊；agent 能力受用户权限天花板限制；creator 全记成用户 |
| agent 用自己的 token（本建议） | 责任/权限/审计清晰，对齐哲学 | 需密钥统一 + agent 授权 + 会话切换；agent 越权需靠 DataAccessAuthorization 兜住 |

**推荐路线**：采用"双归属 + agent 自主行为用 agent token"，与你的哲学一致。
分步落地顺序：**统一密钥 → creator 双字段 + 透传 → agent 会话接入 + 切换 → agent 授权**。
（密钥统一与 creator 双字段风险最低、收益最直接，建议先动；agent 会话切换涉及并发边界，放最后。）

---

## 四、待你拍板

1. **creator 双字段**：是否接受 `creator`（执行者）+ `owner_user_id`（所有者）分离模型？
   还是坚持单 `creator` 字段（agent 操作一律写 agent id，所有权靠 `agentId`/`submitter` 推断）？
2. **密钥统一**：是否同意把 `aip-agent-secret-key` 并入 `DeserializeUserMiddleware` 可接受密钥，
   并修掉 `AutoRouteRegistry.cj:110` 的硬编码 `uctoo-v4-secret-key` 不一致？
3. **agent 会话接入点**：agent 自动登录应在"用户登录时由前端触发"还是"运行时 WS 会话建立时自动触发"？
4. 上述决策确定后，我再按"统一密钥 → creator 双字段 + 透传 → agent 会话接入"的顺序出最小改动清单（含 file:line）。
