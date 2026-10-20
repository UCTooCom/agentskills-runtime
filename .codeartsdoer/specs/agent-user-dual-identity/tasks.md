# 任务清单：Agent / 用户双账号身份、委派路由与 creator 归属

> 状态图例：[ ] 待办  [~] 进行中  [x] 完成
> 关联：spec.md / design.md / research.md

---

## 研究阶段
- [x] **T1** 研究写档：核实 WebMCP 真实聊天通道、LRT 前缀路由活路与双账号身份现状，修正旧误判
  - 修正 1：聊天通道是 WebMCP/MCP（`/webmcp/mcp`），非 `WsChatController`
  - 修正 2：LRT 经 `WebMCPProtocol` 前缀路由（活路），`SkillToToolAdapter`→`BaseSkill.execute` 是另一条死路
  - 实证：creator 全记人类 userId；agent 自动登录仅 AIP 端点调用，本地未接入
  - 产物：research.md

## 文档阶段
- [x] **T2** 出 spec.md / design.md（含 D1/D2/D3 落地与 file:line 锚点）

## 实现阶段
- [x] **T7** `AutoRouteRegistry.cj:110` 硬编码 `uctoo-v4-secret-key` 改为引用 config `jwtSecret`
  - 消除与 main.cj:480 不同源导致的 long_running_task 系列静默 401
  - 低风险，建议最先做

- [x] **T3** creator / owner 双字段归属（对应 FR-2 / D1）— runtime + 插件侧均已落地（2026-09-21）
  - [x] T3.1 `long_running_task` 表新增 `owner_user_id` 列（DDL + PO + DAO）
  - [x] T3.2 `agent_tasks` 表新增 `owner_user_id` 列（DDL + PO + DAO）
  - [x] T3.3 `LongTaskApiService.submitTask`（`long_task_api_service.cj:71`）改写：
        `creator = agent.uctoo_user.id`，`owner_user_id = 人类 userId`（cj:104/136）
  - [x] T3.4 `LrtPluginClient.plan/execute/intervene/verify/evolve/deliver/review` 签名加
        `creator`/`ownerUserId`（cj:171/187/226/387/401/430/470），透传插件侧落库
  - [x] T3.5 核对 L3 插件 `skills/long-running-task` 写库逻辑使用透传的 creator/owner_user_id（2026-09-21 完成，见第二轮实施记录）

- [x] **T5** AGENTS.md / SKILL.md 委派规则修正（对应 FR-1）
  - [x] T5.1 改写 AGENTS.md「长程/复杂任务委派规则」：指引用 `长程任务：<目标>` 或 `/lrt <目标>` 前缀，
        移除误指的「调用 long-running-task 工具」表述（DEV + GITCODE 双副本）
  - [x] T5.2 `skills/long-running-task/SKILL.md` 对齐：本技能由 WebMCP 前缀路由触发（双副本）

- [x] **T4** agent 本地自动登录接入 WebMCP 会话（对应 FR-3 / D3）— 4.1~4.4 全部落地（2026-09-21）
  - [x] T4.1 `AgentAuthService.agentAutoLogin` 增加 `mode` 参数：Local 用 config 密钥，Interconnection 用 aip-agent-secret-key（`AgentAuthService.cj:20/27`）
  - [x] T4.2 `WebMCPController._initProtocolInfrastructure`（`WebMCPController.cj:87`）会话建立时触发 agent 本地登录
  - [x] T4.3 把 agent token 存入 `TokenManager.setToken(agentSessionId, tokenInfo)`（`token_manager.cj:53`），按 userId 缓存，避免串号
  - [x] T4.4 agent 出站调用经 `SessionContext.getAccessToken()`（`token_manager.cj:195`）携带 agent token（2026-09-21 完成：WebMCPController 在 agent 登录后把当前会话重指向 `agent_session_<agentId>`）

- [x] **T6** 审计 actorType 区分（对应 FR-4）
  - [x] T6.1 `OperateLogService.resolveAuditActorType`（`OperateLogService.cj:1176`）按 `uctoo_user.userType` 判定 agent/user/system

- [x] **T8**（可选）死路清理决策
  - [x] T8.1 评估 `SkillToToolAdapter`→`BaseSkill.execute` 空实现与 `LrtCompositionRunner` 未接线：
        清理 / 接线 / 保留为历史包袱，给出结论（不阻塞主链路）
        → **结论（2026-09-21）：保留为历史包袱**。二者确认未被主链路引用；方案 B 已用
        `LongRunningTaskTool` 绕开该死路；删除会牵动 `@Skill` 注册扫描，收益不匹配风险。
        已在 `skill_to_tool_adapter.cj` 类注释写入该决策与两条活路指引，防止后人误用。

---

## 第二轮实施记录（2026-09-21 17:xx，用户拍板：凡需区分 owner/executor 的表一律加列）

> 前置：**必须先人工执行** `sql/incremental/20260921_dual_identity_owner_user_id.sql`，
> 否则 `crontab` 的 owner 感知过滤会生成不存在的列 → SQL 报错（代码里已加注释警示）。
> 全部改动仅落 DEV，未同步 gitcode。

### D1-a DDL：三张表补 owner_user_id（`sql/incremental/20260921_dual_identity_owner_user_id.sql`）
- `crontab`、`long_running_task_artifact`、`long_running_task_evolution` 各加 `owner_user_id uuid` + 索引 + 列注释；
- `agent_tasks` 列已存在，本脚本仅做幂等补齐；
- 历史行回填 `owner_user_id = creator`（改造前 creator 即归属真人，避免老数据归属丢失）；
- F2：为 MainAgent 建 `uctoo_user`（`user_type='agent'`、`agent_id` 回指）并回填 `agents.user_id`。

### F2 agent 绑定 uctoo_user
- 数据：见上（DDL 第 5 节，幂等）。
- 代码兜底：`AgentAuthService.agentAutoLogin` 在 `agents.user_id` 为空时改按
  `uctoo_user.agent_id` 反查（`getExecutor().findUctooUserByAgentId`），避免列未回填即永久无法自动登录。

### F3 插件侧（skills/long-running-task）
- `DATA_CONTRACT.yaml`：`agent_tasks` / `crontab` / 两张 `long_running_task_*` 均补 `owner_user_id` 字段声明；
- `lrt_handlers.cj`：`getWritableColumns` 白名单补 `owner_user_id`；`dispatch` 统一登记请求身份；
  `handleAdd` 不再用 userId 覆盖 body 显式 creator；
- `lrt_persist_service.cj`：新增 `identityCreator/identityOwnerUserId` 静态槽 + `setIdentityFromRequest`；
  `insert` 改为「显式 body 值 > 当前请求身份 > userId」，且**空串一律视为未指定**（防 uuid 22P02），
  `owner_user_id` 同理。→ 插件侧子任务/产物/演进与根任务口径一致。
- 需重新编译并部署 L3 插件（与 runtime 是两个构建单元）。

### F4 剩余调用点透传
- `long_task_api_service.cj`：新增 `resolveAgentUctooUserId` / `resolveTaskIdentity`；
  `submitTask` 复用前者并给 `crontabPO.ownerUserId` 赋值；
  `intervene` / `triggerVerify` / `triggerEvolve` / `deliverTask` / `reviewTask` 五个调用点全部透传 creator/owner。
- `LrtPluginExecutor.cj`（**定时调度驱动**）：新增同名静态方法解析执行者，`execute` 调用补 `creator/ownerUserId`。

### F5 agent 出站身份
- `WebMCPController.cj`：agent 登录后 `SessionContext.getInstance().setCurrentSession(agentSessionId)`；
  新增 `import ...SessionContext`。已知遗留：SessionContext 是单槽全局，多会话并发以最后绑定者为准。

### F1 收尾
- `PermissionUtils.hasOwnerUserColumn` 纳入 `crontab`（须在 DDL 执行后才安全）。

---

## 验收（见 spec.md §4）
- [ ] 用户用「长程任务：查找去年高考物理题并解题」提交，任务进 `long_running_task` 表，
      `creator`=agent id、`owner_user_id`=人类 id，且结合已修 P0 bug 能跑完
- [ ] AGENTS.md / SKILL.md 委派规则与 `WebMCPProtocol.LRT_TRIGGER_PREFIXES` 一致
- [ ] agent 本地自动登录在 WebMCP 会话建立时触发，token 进 `TokenManager`
- [ ] 审计区分 agent/user
- [ ] `AutoRouteRegistry` 与 `main.cj` 用同一把 config 密钥

---

## 实现记录（DEV 副本，2026-09-20）

> 全部改动仅落在 `apps/agentskills-runtime`（DEV），**未同步 gitcode**（按用户要求：DEV→gitcode 归人工复核）。
> 改动均基于 spec/design/research 的 file:line 锚点重新核对当前代码后实施；构建与 DDL 由用户执行。

### T7 密钥统一（已完成）
- `src/config/config.cj`：新增 `public static var jwtSecret = getEnv("JWT_SECRET").getOrDefault("uctoo-v4-secret-key")` 作为全工程唯一来源。
- `src/app/registry/AutoRouteRegistry.cj:110`：`JWTUtil("uctoo-v4-secret-key", ...)` → `JWTUtil(Config.jwtSecret, ...)`（新增 `import magic.config.Config`）。
- `src/app/main.cj`：`let jwtSecret = if (getVariable("JWT_SECRET"))...else "uctoo-v4-secret-key"` → `let jwtSecret = AppConfig.jwtSecret`（main.cj 已 `import magic.config.{Config as AppConfig}`）。

### T3 creator/owner 双字段（runtime 侧 + 插件侧均已完成，2026-09-21）
- `src/app/models/uctoo/AgentTasksPO.cj`：`ownerUserId: Option<String>`（`@ORMField['owner_user_id']`），补 init 参数 + `toJsonValue` 映射。
- `src/app/services/lrt/long_task_api_service.cj`：
  - `submitTask` 内解析 `agentUctooUserId = AgentsService().getById(agentId).userId`（新增 `import ...AgentsService`）；
  - `taskPO.creator = Some(agentUctooUserId)`、`taskPO.ownerUserId = Some(userId)`（原均记人类 userId）；
  - `crontabPO.creator = Some(agentUctooUserId)`（D1 要求）；
  - `LrtPluginClient.plan/execute` 调用透传 `agentUctooUserId, userId`。
- `src/app/services/lrt/lrt_plugin_client.cj`：7 个方法（plan/execute/intervene/verify/evolve/deliver/review）签名加 `creator: String = "", ownerUserId: String = ""`（默认空，不破坏既有调用点），并把二者注入请求 body，供插件侧落库。
- DDL：`sql/incremental/20260920_agent_tasks_owner_user_id.sql`（给 `agent_tasks` 加 `owner_user_id uuid`，含索引；历史行允许 NULL）。
- 说明：运行时长程任务表实际为 `agent_tasks`（spec 的"long_running_task 表"是概念名）；L3 插件侧独立 `long_running_task` 表由插件按其库同步加列（T3.5）。

### T5 委派规则（已完成）
- `AGENTS.md` §长程/复杂任务委派规则（DEV 早前已改写）：路径 A 前缀 + 路径 B `long-running-task` 工具（方案B 已落地真实 `LongRunningTaskTool`），行为一致。
- `skills/long-running-task/SKILL.md` §委派触发规则：原"调用工具已废弃/空实现"措辞已更正为"两条路径均已实现、择一即可"，与 AGENTS.md 对齐（方案B 使工具链路生效）。

### T6 审计 actorType（已完成）
- `src/app/services/uctoo/OperateLogService.cj:1176` `resolveAuditActorType`：userId 非空时改查 `UctooUserService().getById(userId).data`（同包 public，绕过包私有 DAO 的跨包可见性问题），`=="agent"` → `"agent"`，否则 `"user"`；查询异常降级为 `"user"`（不阻断审计写入）。`plugin`/`system` 分支不变。

### T4 agent 本地自动登录接入 WebMCP 会话（4.1~4.3 完成；T4.4 出站携带待接续）
- `src/app/services/aip/AgentAuthService.cj`：
  - 新增 `public enum AgentLoginMode { Local | Interconnection }`；
  - `localJwtUtil = JWTUtil(Config.jwtSecret, ...)`；
  - `agentAutoLogin(agentId, mode = Interconnection)`：Interconnection 走 aip 密钥（原行为），Local 走 config 密钥。
- `src/app/services/webmcp/WebMCPProtocol.cj`：新增 `getAgentId()` 暴露已解析的 `_agentId`。
- `src/app/controllers/uctoo/webmcp/WebMCPController.cj`：`_initProtocolInfrastructure` 在 `setLoginRequired(true)` 后，按 `protocol.getAgentId()` 触发 `agentAutoLogin(agentId, AgentLoginMode.Local)`，并将 token 以独立 `agent_session_<agentId>` 存入 `TokenManager`（幂等：仅当无有效 token 时登录）。
- **T4.4 已完成（2026-09-21）**：`WebMCPController` 在 agent 本地自动登录成功后，把全局
  `SessionContext` 当前会话重指向 `agent_session_<agentId>`（`WebMCPController.cj:120`），
  使 `http_tool` 等经 `SessionContext.getAccessToken()` 出站的调用携带 agent 身份。
  ⚠️ 已知局限：`SessionContext` 是单槽全局，多会话并发以最后绑定者为准（与 `webmcp-default`
  共享 protocol 同源），需待会话隔离改造一并解决。

### T8（可选，未实施）
死路 `SkillToToolAdapter`→`BaseSkill.execute` 清理决策未做（不阻塞主链路）；方案B 已用 `LongRunningTaskTool` 绕过该死路，旧死路可保留为历史包袱。
（`skill_to_tool_adapter.cj:19`、`lrt_composition_runner.cj:209` 均确认存在且未被主链路引用 → 复核建议：保留 + 加注说明，勿直接删除。）

---

## 复核记录（2026-09-21，全清单逐项复跑）

> 产物：`audit-2026-09-21-tasks-review.md`（本报告同目录）。结论以磁盘代码与 `public20260921.sql` 为准。

| 编号 | 严重度 | 摘要 | 状态 |
|---|---|---|---|
| F1 | P0（潜伏） | 行级权限/所有权只认 `creator`，与 D1 的 creator=执行者 冲突 → 委派真人失去可见性与操作权 | ✅ 已修（`PermissionUtils` 双列归属谓词，作用于 `agent_tasks` + `crontab`） |
| F2 | P1 | MainAgent `agents.user_id` 为 NULL，双身份设计目前实际空转 | ✅ 已修（DDL 建 agent 帐号并回填；`AgentAuthService` 增加 `agent_id` 反查兜底） |
| F3 | P1 | T3.5 未完成：插件侧未读透传字段，产物表无 `owner_user_id` 列 | ✅ 已修（2026-09-21）+ DDL 加列 |
| F4 | P2 | `LrtPluginClient` 7 方法中 5 个未透传 creator/owner，含 `LrtPluginExecutor.cj:92` 调度驱动路径 | ✅ 已修（2026-09-21）5 处 + 调度路径全透传 |
| F5 | P2 | T4.4 未做：出站仍取用户会话 token | ✅ 已修（2026-09-21），见 T4.4 备注中的并发局限 |
| F6 | P3 | T8 未做 | ✅ 决策：保留为历史包袱，已写进 `skill_to_tool_adapter.cj` 类注释 |
| F7 | P3 | 文档锚点漂移（如 T3.4 标注 `lrt_plugin_client.cj:171/187/226/387/401/430/470`，实际为 `163/185/208/237/258/284/319`）、验收项全空 | 待线下实跑后勾选 |

### 本次已修项：F1 行级权限「owner 感知」
- `src/app/utils/PermissionUtils.cj`：
  - 新增 `hasOwnerUserColumn(entityType)`（当前仅 `agent_tasks`）+ `buildOwnershipPredicate(userId, entityType)`，
    对含 owner 列的表产出 `(creator = '${userId}'::uuid OR owner_user_id = '${userId}'::uuid)`，其余表维持 `creator = '${userId}'::uuid`；
  - `checkUserHasPermission` 的所有权 SQL 改用该谓词（同时去掉多余的参数绑定）；
  - `appendPermissionFilter` 三处兜底过滤、`buildFilterCondition`（新增 `entityType` 形参）及其两个调用点同步改造。
- 未纳入 `crontab`：该表尚无 `owner_user_id` 列，纳入会导致 SQL 报错。是否加列见报告 §6。

### 校验过、无需改动的事实（避免重复劳动）
- `AgentTasksService.cj` / `CrontabService.cj` 的生成式 `create` 均为 `if (entity.creator.isNone()) { entity.creator = Some(creatorId) }`，
  因此昨日「agent 未绑定时写 `None`」的守卫会**自动回落人类 userId** —— 当前 MainAgent 未绑定，故 creator 暂未错乱；一旦绑定，creator 由 F1 的修复兜住。
- `PermissionMiddleware.cj:159` 也走 `checkUserHasPermission`，故 F1 的修复对中间件链路同样生效。

