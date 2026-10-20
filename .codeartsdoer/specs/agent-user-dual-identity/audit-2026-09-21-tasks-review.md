# 复核报告：agent-user-dual-identity 任务清单未完项与实际缺陷

> 复核日期：2026-09-21 · 范围：`.codeartsdoer/specs/agent-user-dual-identity/tasks.md` 全部未勾选项 + 已完成项的回归验证
> 参照：`public20260921.sql`（最新库导出）、`logs/agentskills-runtime-20260921-150604.log`
> 全部结论均以**磁盘当前代码 / 库导出**为准，不采信 tasks.md 的自述。
> 改动仅落 DEV（`apps/agentskills-runtime`），未同步 gitcode。

---

## 0. 一句话结论

tasks.md 里未打勾的 **T3.5 / T4.4 / T8 三项确实都未完成**，且复核过程中发现了 **1 个此前从未被记录的结构性缺陷（F1）** 和 **1 个 T3 遗留的透传缺口（F4）**。
**F1 已修**；其余按"是否阻塞主链路"分级列出，其中 F1 属于**一旦给 agent 绑定 uctoo_user 就会立刻爆发的潜伏 P0**。

| 编号 | 严重度 | 摘要 | 状态 |
|---|---|---|---|
| F1 | **P0（潜伏）** | 行级权限/所有权仍只认 `creator`，而 T3 把 `creator` 改成了执行者（agent）→ 委派真人将看不到也管不了自己的任务 | ✅ 已修（`agent_tasks`） |
| F2 | P1 | MainAgent 未绑定 `uctoo_user`（`agents.user_id` 为 NULL），双身份设计目前**实际上未生效** | 待决策 |
| F3 | P1 | T3.5 未完成：插件侧未使用透传字段，且产物表根本没有 `owner_user_id` 列 | 待你确认后实施 |
| F4 | P2 | `LrtPluginClient` 7 个方法里 **5 个未透传** creator/owner；含定时 **调度驱动** 的那次 `execute` | 待你确认后实施 |
| F5 | P2 | T4.4 未完成：出站仍取用户会话 token | 待决策 |
| F6 | P3 | T8 未完成：死路未接线 | 建议保留为历史包袱，给出结论 |
| F7 | P3 | 文档锚点漂移、验收项全空 | 本次同步修正 |

---

## 1. F1（P0，潜伏）——行级权限仍只认 creator，与 D1 的 creator/owner 分离直接冲突

### 证据链

| 环节 | 位置 | 事实 |
|---|---|---|
| 行级权限默认开启 | `PermissionConfig.cj:54-59` | `.env` 未设 `ROW_LEVEL_PERMISSION_*` → `globalEnabled = true` |
| 列表过滤注入点 | `AgentTasksService.cj:659 / 868 / 1052` | `PermissionUtils.appendPermissionFilter(userId, "agent_tasks")` |
| 逐条权限校验 | `PermissionMiddleware.cj:159` | 中间件也回到 `PermissionUtils.checkUserHasPermission` 同一中枢 |
| 归属判定旧实现 | 原 `PermissionUtils.cj:86-87` | `WHERE id = ? AND creator = ?` —— **owner 概念完全缺席** |
| 已完成但致命的改动 | `long_task_api_service.cj:122 / 156` | T3 把 `creator` 由「人类 userId」改为「agent 的 uctoo_user.id」 |

**互斥点**：`creator` 现在的语义是「执行者」，而权限层把它当「归属者」。两者一旦同时成立，委派出去的任务对真人就变成"不存在/无权限"。

### 为什么现在还没爆（这点很重要，别误判为虚报）

`long_task_api_service.cj:122` 修复后，agent 未绑定时写 `None`；而生成式 `create` 有兜底：

```cangjie
// AgentTasksService.cj / CrontabService.cj 的 create 都是同一口径
if (entity.creator.isNone()) { entity.creator = Some(creatorId) }
```

当前 MainAgent **未绑定 uctoo_user**（`agents.user_id` 为 NULL，见 §2），所以 `creator` 此刻会自动回落成人类 userId —— 权限正常。
**但这是"因为设计没生效所以没出问题"**。一旦按 F2 给 agent 绑定了 uctoo_user，所有委派行的 creator 变成 agent id，**委派真人立刻失去可见性与操作权**。故必须在绑定之前修好。

### 已实施的修复（本次改动，仅 DEV）

在 `PermissionUtils.cj` 引入「双列归属谓词」，**只对带 owner 列的表生效，其它表行为一字未改**：

```cangjie
private static func hasOwnerUserColumn(entityType: String): Bool {
    return entityType == "agent_tasks"
}

private static func buildOwnershipPredicate(userId: String, entityType: String): String {
    if (hasOwnerUserColumn(entityType)) {
        return "(creator = '${userId}'::uuid OR owner_user_id = '${userId}'::uuid)"
    }
    return "creator = '${userId}'::uuid"
}
```

替换点（4 类、6 处）：所有权 SQL（`checkUserHasPermission`）、三处无授权时的兜底过滤、`buildFilterCondition` 及其两个调用点。
`crontab` **暂未纳入**（它还没有 owner 列，纳入会导致 SQL 报错），见 §6 待决策。

---

## 2. F2（P1）——MainAgent 未绑定 uctoo_user，双身份设计目前空转

- 库导出中 `agents` 表**只有 1 行** MainAgent，`user_id` 为 **NULL**（`sql/public20260921.sql`）。
- 后果链：昨天那个把整条 LRT 主链路打断的 `invalid input syntax for type uuid: ""` 就是它的下游产物；即便加了 `None` 守卫，`creator` 也恒为 NULL（靠 `create` 兜底回落人类），**D1「creator=执行者」的语义从未真正生效过**。
- 建议二选一：
  - **A（推荐）**：为 MainAgent 建 `uctoo_user`（`userType='agent'`）并回填 `agents.user_id` —— 这样 F1 的修复才有意义，T6 的审计 actorType 也才能真正区分出 agent；
  - **B**：维持现状，接受「creator 恒等于人类 owner」，则本 spec 的 FR-2 事实上降级。

---

## 3. F3（P1）——T3.5 未完成：插件侧完全没用上透传字段

逐项核对 `skills/long-running-task`：

| 检查点 | 位置 | 结果 |
|---|---|---|
| 是否读透传的 creator | `src/lrt_persist_service.cj:134-135` | ❌ 无条件 `dataMap["creator"] = JsonValue.String(userId)`，**覆盖**任何传入值 |
| handleAdd 是否同理 | `src/lrt_handlers.cj:147-149` | ❌ 同样强制赋值 userId |
| 可写列白名单 | `src/lrt_handlers.cj:748-756` | ❌ 含 `creator`，**不含** `owner_user_id` |
| 数据契约 | `DATA_CONTRACT.yaml:41 / 128 / 155` | ❌ 三张表只声明 `creator`，无 `owner_user_id` |
| 库表实际列 | `long_running_task_artifact` / `long_running_task_evolution` | ❌ 均无 `owner_user_id` 列 |

**后果**：同一棵任务树的 creator 口径是**撕裂**的 —— 根任务（runtime 侧 `agent_tasks`）记为执行者，而子任务/产物/演进（插件侧两表）仍记人类 userId；owner 归属在插件侧整条丢失。

需要做的事（跨进程，请你确认后再动）：
1. DDL：给 `long_running_task_artifact`、`long_running_task_evolution` 加 `owner_user_id uuid` + 索引；
2. `DATA_CONTRACT.yaml`：三张表的字段清单补 `owner_user_id`；
3. 插件代码：改为「有 creator 用 creator，否则回落 userId」，并把 `owner_user_id` 加入 `getWritableColumns` 与写库映射；
4. 重新**编译并部署 L3 插件**（与 runtime 是两个构建单元）。

---

## 4. F4（P2）——透传只做了一半：7 个方法里 5 个没带上

`lrt_plugin_client.cj` 签名已全部带上命名可选参数（`163/185/208/237/258/284/319`，注意 tasks.md 里标的 `171/187/226/387/401/430/470` 已经漂移），但调用点：

| 调用点 | 是否透传 |
|---|---|
| `long_task_api_service.cj:191` plan | ✅ `creator: agentUctooUserId, ownerUserId: userId` |
| `long_task_api_service.cj:209` execute（WebMCP 首轮） | ✅ 同上（经不可变快照 `spawnCreator`） |
| `long_task_api_service.cj:248` intervene | ❌ |
| `long_task_api_service.cj:409` verify | ❌ |
| `long_task_api_service.cj:423` evolve | ❌ |
| `long_task_api_service.cj:452` deliver | ❌ |
| `long_task_api_service.cj:492` review | ❌ |
| **`LrtPluginExecutor.cj:92` execute（定时调度驱动）** | ❌ |

最后一处尤其值得注意：**真正周期性跑任务的是调度链路**，`LrtPluginExecutor` 由 `context.parameters` 取 userId（该值在 `long_task_api_service.cj:170-173` 写入，是人类 userId），但没带 creator/owner —— 也就是插件每次按 cron 唤起时，写的还是它自己的默认口径。

---

## 5. F5/F6（P3）——T4.4、T8 现状

- **T4.4**：`WebMCPController.cj:104` 已把 agent token 存成 `agent_session_<agentId>`；但出站时 `http_tool.cj:157` 取的是 `sessionContext.getAccessToken()`，而它（`token_manager.cj:195-208`）解析的是**当前会话 id = 用户会话**。故 agent 身份出站未生效。当前 LRT 的 creator 由 `submitTask` 直接解析保证，**不依赖 T4.4**；但若要让 `host.db` 的写入也以 agent 身份落审核，就必须做这一步。
- **T8**：`SkillToToolAdapter`（`skill_to_tool_adapter.cj:19`）与 `LrtCompositionRunner`（`lrt_composition_runner.cj:209`）均已确认存在且未被主链路引用。方案 B 已用 `LongRunningTaskTool` 绕开。**建议结论：保留为历史包袱**，在两处源码加上"未被引用/勿直接使用"的注释说明，不删除（删除会牵动 `@Skill` 注册扫描，收益不匹配风险）。

---

## 6. 需要你决策的事项

1. **是否给 crontab 加 `owner_user_id` 列？**（影响 LRT 调度记录对真人的可见性）
   - 方案 A：加列 + PO/DAO + 纳入 §1 白名单 → 语义最干净，但需要再跑一次 DDL；
   - 方案 B：`crontabPO.creator` 回落人类 userId（删掉 `:156` 那行改动）→ 零 DDL，但与 D1「creator=执行者」不一致。
   - **当前未动代码**，等你选。
2. **是否现在做 F3/F4（插件侧 + 剩余 5 个调用点）？** 两者都在 LOGIC 侧，需要重编译插件；runtime 侧只占一半工作量。
3. **是否给 MainAgent 绑定 uctoo_user（F2 方案 A）？** 我建议**先于** F3/F4 做，否则双身份依然是空转。

---

## 7. 本次实改动清单（DEV）

| 文件 | 改动 |
|---|---|
| `src/app/utils/PermissionUtils.cj` | 新增 `hasOwnerUserColumn` / `buildOwnershipPredicate`；所有权 SQL 与三处兜底过滤改为双列判定；`buildFilterCondition` 增加 `entityType` 形参并同步两个调用点 |
| `docs` 本报告 | 新增 |

（昨日已修的 `long_task_api_service.cj:122 / 156` 的 uuid 空串守卫不在本次范围内，但本报告确认其**行为正确**：`None` + `create` 兜底 = 未绑定时自动回落人类 userId。）

---

## 8. 第二轮实施记录（F2 / F3 / F4 / F5 + DDL + crontab 补齐）

按用户拍板"需要区分 creator 与 owner_user_id 的都加上"，本轮把 §6 的三项决策全部落地。

### 8.1 增量 DDL（**需人工执行**）

`sql/incremental/20260921_dual_identity_owner_user_id.sql`，全部幂等，可重复执行：

| 段 | 内容 |
|---|---|
| 1–3 | `crontab` / `long_running_task_artifact` / `long_running_task_evolution` 各加 `owner_user_id uuid` + 索引 + 列注释 |
| 4 | `agent_tasks` 幂等补齐（昨日脚本已加，本节为 no-op） |
| 5 | **F2**：`uctoo_user` 插入 `user_type='agent'`、`agent_id` 回指 MainAgent 的帐号，并回填 `agents.user_id` |

历史行统一 `SET owner_user_id = creator` 回填，避免老数据归属丢失。

列名核对依据：`uctoo_user` 实表含 `name/username/email/password`(NOT NULL)、`auth_provider` int4、`status` int4、`user_type` varchar(20) default 'human'、`agent_id` uuid —— 与 DDL 完全一致，非臆造。

### 8.2 crontab 模块按 crudgen 口径补齐

| 层 | 位置 | 内容 |
|---|---|---|
| PO | `CrontabPO.cj:94-95 / 123 / 148 / 177` | `@ORMField['owner_user_id']` + 字段 + init 形参 + 赋值 + toJsonValue（四处齐全，`fromMap` 由宏生成） |
| DAO insert | `CrontabDAO.cj:66 / 90` | 列 + `${arg(entity.ownerUserId)}` |
| DAO update | `CrontabDAO.cj:139` | `owner_user_id = ${arg(...)}` |
| DAO select | `CrontabDAO.cj:105/190/203/213/227/266/339/364` | 8 处显式列全部补上 |
| Service | `CrontabService.cj:152-153` | `if (entity.ownerUserId.isSome()) existingEntity.ownerUserId = ...` |
| 写入 | `long_task_api_service.cj:197` | `crontabPO.ownerUserId = if (userId.isEmpty()) None else Some(userId)` |

`CrontabPO` 全工程只有 `CrontabPO()` 无参构造被调用，加形参不破坏调用点。

### 8.3 F2：MainAgent 绑定 uctoo_user

`AgentAuthService.cj:47-55`：`agents.user_id` 为空时改按 `uctoo_user.agent_id` 反查（DDL 会回填 `user_id`，此分支是历史/手工建 agent 的兜底），随后仍校验 `userType == 'agent'` 与 `agent.status == 1`。

### 8.4 F3：插件侧落库口径

- `DATA_CONTRACT.yaml`：4 张表（agent_tasks / crontab / artifact / evolution）补 `owner_user_id` 字段声明；
- `lrt_handlers.cj:756/759`：两张可写表的白名单补该列；
- `lrt_handlers.cj:65`：`dispatch` 入口统一调用 `LrtPersistService.setIdentityFromRequest(fields)` 登记宿主透传身份；
- `lrt_persist_service.cj:164-193`：`insert` 改为显式 body 值 > 当前请求身份 > userId 三级回落，**空串一律不写**（避免 22P02）；
- `lrt_handlers.cj:150-155`：`handleAdd` 不再无条件用 `userId` 覆盖 body 里的 `creator`。

### 8.5 F4：补齐透传调用点

`LrtPluginClient` 7 个方法全部带 `creator!` / `ownerUserId!` 命名可选参数；补上此前缺失的 5 处：
`intervene`(290) / `verify`(452) / `evolve`(467) / `deliver`(497) / `review`(538)，
以及**定时调度驱动**的 `LrtPluginExecutor.cj:94/98`（新增 `resolveAgentUctooUserId` 静态方法，:126）。

新增 `LongTaskApiService.resolveTaskIdentity(taskId, userId)`（:75）：从既有任务行解析 (creator, owner)，
owner 优先取行内 `owner_user_id` —— 保证任务生命周期内归属不变。

### 8.6 F5：agent 出站 token

`WebMCPController.cj:116-120`：agent 自动登录后，把全局 `SessionContext` 当前会话重指向
`agent_session_<agentId>`，使 `http_tool` 等经 `SessionContext.getAccessToken()` 出站的调用携带 agent 身份。
`import magic.tool.{TokenManager, TokenInfo, SessionContext}`（:16）已补。

⚠️ 已知局限（未修，与 `webmcp-default` 共享 protocol 同源）：`SessionContext` 是单槽全局，
多会话并发以最后绑定者为准，需待会话隔离改造一并解决。

### 8.7 T8（可选）

决策：**保留 `SkillToToolAdapter` 不删除**，已在类注释写明"对 long-running-task 是死路、方案B 已用
`LongRunningTaskTool` 绕开"（`skill_to_tool_adapter.cj:21/25`）。理由：它仍被其它技能的 Tool 适配场景引用。

---

## 9. 你接下来要做的

1. **执行 DDL**：`sql/incremental/20260921_dual_identity_owner_user_id.sql`（人工，DEV 库）；
2. **`cjpm build`**（DEV，独立 cmd）—— runtime 侧改动涉及
   `magic.app.utils` / `magic.app.services.lrt` / `magic.app.services.aip` /
   `magic.app.services.crontab.executor` / `magic.app.models.uctoo` / `magic.app.dao.uctoo` /
   `magic.app.services.uctoo` / `magic.app.controllers.uctoo.webmcp`；
3. 插件是**独立构建单元**：`cd skills/long-running-task && cjpm build`；
4. 重跑一次长程任务，验证 `agent_tasks` / `crontab(lrt-*)` / `long_running_task_artifact` /
   `long_running_task_evolution` 四处落库齐全，且 `creator`=agent 帐号、`owner_user_id`=真人。
