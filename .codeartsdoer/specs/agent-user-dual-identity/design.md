# 设计文档：Agent / 用户双账号身份、委派路由与 creator 归属

> 配套 `spec.md` 与 `research.md`。本文把已拍板的三项决策（creator/owner 分离、密钥统一且 aip 密钥 AIP 专用、
> agent 登录接入 WebMCP 会话）落到具体改动点。所有 file:line 基于 2026-09-20 代码快照。

---

## 1. 总体设计

```
用户(web-admin 登录)
   │  access_token (人类) + userId (query/X-User-Id)
   ▼
WebMCPController (/webmcp/mcp)
   │  _initProtocolInfrastructure(sessionId, userId)
   ▼
WebMCPProtocol.handleMessage
   ├─ extractLrtGoal(userMessage) 命中 "长程任务："/"/lrt" 前缀
   │     ▼
   │  handleLongRunningTaskRoute → LongTaskApiService.submitTask(goal, agentId, _userId, _sessionId)
   │        ├─ taskPO.creator      = agent.uctoo_user.id   ← (改) 原=人类 userId
   │        ├─ taskPO.owner_user_id= 人类 userId            ← (新增列)
   │        ├─ crontabPO.creator   = agent.uctoo_user.id   ← (改)
   │        └─ LrtPluginClient.plan(taskId, goal, creator, owner_user_id, …)
   │
   └─ 普通 ReAct（无前缀）：结合已修 P0 异常隔离，不再静默死亡

【新增】WebMCP 会话建立时：
   agentAutoLogin(agentId, mode=Local)  → config 密钥签发 agent token
   → TokenManager.setToken(agentSessionId, agentToken)  ← (改) 原本孤立返回
```

**核心修正**：LRT 的活路由是 WebMCP 前缀，不是 `SkillToToolAdapter` 那条死路。`BaseSkill.execute` 空实现
对应的「调用 long-running-task 工具」规则必须改写。

---

## 2. 决策落地（D1 / D2 / D3）

### D1 — creator（执行者）+ owner_user_id（所有者）分离

**数据模型变更**
- `long_running_task`：新增 `owner_user_id VARCHAR(64) DEFAULT NULL`。
- `agent_tasks`：新增 `owner_user_id VARCHAR(64) DEFAULT NULL`（已有 `agentId`、`creator`）。
- 历史行 `owner_user_id` 允许 NULL。

**落库改写点**（`src/app/services/lrt/long_task_api_service.cj`）
- `submitTask`（`cj:71`）：
  - 现有 `taskPO.creator = Some(userId)`（`cj:104`）→ 改为 `creator = Some(agentUctooUserId)`，
    `owner_user_id = Some(userId)`。
  - 现有 `crontabPO.creator = Some(userId)`（`cj:136`）→ 同上改 `creator=agentId`、`owner_user_id=userId`。
  - `LrtPluginClient.plan(taskId, goal, userId, …)`（`cj:171`）→ 入参改为 `(taskId, goal, creator=agentId,
    ownerUserId=userId, …)`；需同步 `LrtPluginClient.plan/execute/intervene/verify/evolve/deliver/review`
    签名（`cj:171/187/226/387/401/430/470`）。
- agent 的 `uctoo_user.id` 来源：WebMCP 会话对应 agent（默认 `long-running-task` 技能名映射的 agent）的
  `AgentsPO.userId`；建议 `submitTask` 增 `executorAgentId` 入参，由 `WebMCPProtocol` 传入 `_agentId`
  （`WebMCPProtocol.cj:1692` 已有 `_agentId` 回退逻辑）。

**插件侧**：`LrtPluginClient` 经 cordis JSON-RPC 调插件，插件写 `long_running_task` 时须使用透传的
`creator`/`owner_user_id`，而非自行取 userId。需核对插件 `skills/long-running-task` 的写库逻辑（L3 进程）。

### D2 — 密钥统一，但 aip-agent-secret-key 保持 AIP 专用

**原则**（依据 `aip-implementation/spec.md` / `design.md`）：`aip-agent-secret-key` 仅用于 GB/Z 185 互联模式
的 `/aip/identity/agent-login`。**本地独立运行的 agent 不需要 AIP 特性，用 config 密钥即可。**

**改动点**
- `AgentAuthService.agentAutoLogin(agentId, mode: AgentLoginMode = Local)`（`cj:27`）：
  - `Local`：`generateAgentToken(user.id)` 用 **config `jwtSecret`** 签发（与用户同钥）；
  - `Interconnection`：保持现有 `aip-agent-secret-key`（不变）。
- `DeserializeUserMiddleware`：**无需并入 aip 密钥**（本地 agent token 已是 config 密钥，本就可验）。
- `AutoRouteRegistry.cj:110`：硬编码 `uctoo-v4-secret-key` 改为引用 `Config.jwtSecret`，消除与 `main.cj:480`
  不同源的静默 401（影响 long_running_task 系列经 AutoRoute 注册的路由）。

### D3 — agent 会话接入点 = 用户 web 登录时同步自动登录

**触发点选择**：在 WebMCP 会话建立处接入（最贴合「用户从 web 登录发起会话即同步」的语义），而非前端登录页额外调用。
- `WebMCPController._initProtocolInfrastructure(protocol, sessionId, userId)`（`cj:87`）：
  在 `protocol.setSessionInfo(sessionId, "", userId)` 之后，调用
  `agentAutoLogin(agentIdForSession, Local)`，把返回 token 经 `TokenManager.setToken(agentSessionId, tokenInfo)`
  存入运行时（现有 `token_manager.cj:53` `setToken` 复用）。
- agent sessionId 与用户 sessionId 隔离，避免 `SessionContext` 串号。
- `userId → agent` 映射：当前会话 agent 由 `getMainAgentDef()` 决定；agent 的 `uctoo_user.id` 取自其
  `AgentsPO.userId`（与 D1 同源）。建议建一个轻量缓存（agentId → tokenInfo），避免每次请求重签。

**出站携带**：agent 真正执行（ReAct 步骤、技能委派、cron、LRT 插件回调）时，出站 HTTP 取 agent session 的 token
（经 `SessionContext.getAccessToken()`，`token_manager.cj:195`），使写入 creator 自然为 agent id。
in-process 的 cordis JSON-RPC（LrtPluginClient）已直传 userId、不经 HTTP token，无需 agent token。

---

## 3. 审计 actorType 区分（FR-4）

`OperateLogService.resolveAuditActorType`（`src/app/services/uctoo/OperateLogService.cj:1176`）：
- 现状：`userId` 非空 → `user`，否则 `plugin` → `system`。
- 改为：先查 `uctoo_user.userType`；`userType=="agent"` → `agent`，普通用户 → `user`，无 userId → `system`。

---

## 4. 风险与取舍

| 项 | 风险 | 缓解 |
|----|------|------|
| agent 自身 token 出站越权 | agent 用自己 token 可调其权限内的所有表 | 依赖 `data_access_authorization` 行级权限；需为 agent uctoo_user 显式授予角色/数据权限（当前仅 `agents` 角色） |
| WebMCP 会话并发 | 多用户会话共用默认 `webmcp-default` session（`WebMCPController.cj:198`），agent 登录需按 userId 区分 | agent token 缓存以 userId 为 key，避免串号 |
| 历史数据 `owner_user_id` 为空 | 旧任务无所有者信息 | 查询/展示层对 NULL 降级为 creator 用户，不影响新流程 |
| D1 改 `LrtPluginClient` 签名波及多调用点 | plan/execute/intervene/verify/evolve/deliver/review 共 7 处 | 集中改签名 + 同步插件侧；cjpm build 由用户执行回传日志 |

---

## 5. 实现顺序建议

1. **T7** `AutoRouteRegistry` 密钥统一（低风险，先消 401 隐患）
2. **T3** `owner_user_id` 列 + `submitTask` creator/owner 改写（收益直接，依赖 D1 数据模型）
3. **T5** AGENTS.md / SKILL.md 委派规则修正（前缀而非工具，立即见效、零编译风险）
4. **T4** agent 本地自动登录接入 WebMCP 会话（D3，需 agentAutoLogin mode 改造）
5. **T6** 审计 actorType 按 userType 区分
6. **T8**（可选）死路 `SkillToToolAdapter`/`LrtCompositionRunner` 清理决策

> 注：09-19 已修的 P0 静默死亡（react_executor / agent_persistence_event_handler 等 5 文件）是本次任务跑完的
> 前置条件，须先合入并 cjpm build 通过。
