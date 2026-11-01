# 设计文档 v2：Per-User 委托式 Agent 身份（DAI, Delegated Agent Identity）

> **本文与 v1 的关系**：`design.md`（v1，2026-09-20）解决的是「agent 与人类行为对齐」——agent 要有自己的
> `uctoo_user` 帐号、产出要能区分**执行者**（creator）与**归属者**（owner_user_id）。v1 的 D1 已落地
> （`long_task_api_service.cj:145-172`），D2/D3 已于 2026-10-23 落地（默认 `Local` 密钥 + 登录时自动登录主 agent）。
> **v2 不推翻 v1，而是修正 v1 遗留的一个结构性缺口**：v1 里的 agent 是**系统级单例**——所有人类共用同一个
> MainAgent 身份。本文给出「每个人类用户拥有自己的主 agent」的方案，且不付出「每人两行 DB 记录」的代价。
>
> 代码行号基于 2026-10-23 快照。DB 基线以 `sql/uctooDB.sql`（226 张表）为准。

---

## 1. 诉求与矛盾

用户的原话拆成两条硬约束：

| # | 约束 | 含义 |
|---|---|---|
| C1 | **可溯源** | 每个用户登录后有一个归属他的主 agent，能回答「哪个用户，指使归属他的 agent，干了什么」 |
| C2 | **不冗余** | 不要每个用户都在 `uctoo_user` + `agents` 各插一行，「感觉很重复和繁琐」 |

直觉上的做法是「登录时给该用户建两行」（per-user 预建），它满足 C1 但违反 C2。本文的方案同时满足两条，
支点是一个判断：

> **身份是先算出来的，不是先建出来的。**
> 只要 agent 实例的 ID 能从 `(agent 定义 id, 人类用户 id)` 确定性推导出来，它就**在插入任何一行之前就已经存在**——
> 可以被写进 token、被写进审计日志、被写进任务行的 `creator`。落库只是「这个身份后来真的干了活」的存档动作，
> 而不是「它存在」的前提。

把「存在」与「存档」解耦后，C1 和 C2 就不是权衡关系了：1000 个登录用户里只有 50 个真正让 agent 干过活，
库里就只有 50 行，而另外 950 个人的 agent **身份依然可寻址、可溯源**（ID 随时能重算）。

---

## 2. 为什么「每人两行」是错的方向

不只是"繁琐"，它有三处实质性的坏味道：

| 坏味道 | 实证 | 后果 |
|---|---|---|
| **agnent 帐号行是被迫造出来的** | `uctoo_user.password` 是 `NOT NULL`（`sql/uctooDB.sql:7604`），agent 不需要口令，只能塞占位值；`UctooUserAuthController` 还得在 signin 里特判 `AUTH-AGENT-001` 拒绝登录 | 用人类身份模型表达 agent，处处打补丁 |
| **agents 表的一行其实是「定义」不是「身份」** | `agents` 装的是 `system_prompt / model / tools / profile_skills / source_path`（`sql/uctooDB.sql:616-649`），且 `source_path` 上有**唯一索引** `uk_agents_source_path`（`:646`） | 复制 N 份 = 提示词、模型、技能清单被复制 N 份。改一次主 agent 人格要同步 N 行；实例行没有 source_path，只能靠 NULL 钻唯一索引的空子 |
| **同步器会误伤** | `AgentSyncHandler.syncFromFileSystem` 先按 `sourcePath` 匹配、再按 `name` 兜底（`AgentSyncHandler.cj:70-90`），而 `DataMapper.agentDefinitionToPO` 会覆写 `name`/`system_prompt`/`tools`（`DataMapper.cj:15-53`） | 一旦实例行与定义行同名，AGENTS.md 同步会把实例行的提示词一起改掉，per-user 定制被冲掉 |

**根因**：把三个正交维度压进了两行里。

| 维度 | 回答什么 | 基数 | 变化频率 |
|---|---|---|---|
| **定义 Definition** | 这个 agent 是什么、会什么（人格/模型/工具/技能） | 1（共享模板） | 月级 |
| **实例 Instance** | 它属于谁、替谁干活 | = 活跃用户数 | 随用户活跃线性 |
| **凭据 Credential** | 这一次调用以谁的身份执行 | = 会话数 | 秒级 |

三个维度变化频率差一个数量级 ⇒ 必须切开（本项目在多模态架构上用过同一条判据：`specs/multimodal-native-chat`）。
「每人两行」的错误在于把**定义**也 per-user 复制了——真正该 per-user 的只有**实例**，而实例默认**不需要落库**。

---

## 3. 三层模型

```
┌─ 定义层（0 新增行，共享）────────────────────────────────┐
│ agents 表唯一 MainAgent 行                                │
│   agent_type='MAIN', source_path='AGENTS.md'              │
│   system_prompt / model / tools / profile_skills          │
│   instantiation_policy = 'per_user'   ← 新增列，可配       │
│   user_id = 系统级 agent 服务帐号（仅系统任务/AIP 互联用） │
└───────────────────────────────────────────────────────────┘
                    │ 派生（确定性，纯计算）
                    │  instance_id = UUIDv5(ns=def_id, name=owner_user_id)
                    ▼
┌─ 实例层（per-user，默认 0 行，惰性物化）─────────────────┐
│ agent_instance(id = 上面算出的值,                          │
│                agent_def_id, owner_user_id,               │
│                status, config_override, memory_scope,     │
│                materialized_reason, last_active_at)       │
│ UNIQUE(agent_def_id, owner_user_id)                        │
│ 只有「真的产出了需要持久化的东西」才 INSERT                 │
└───────────────────────────────────────────────────────────┘
                    │ 登录时签发
                    ▼
┌─ 凭据层（委托 token，无状态 + 可撤销）───────────────────┐
│ { sub: instance_id,                                        │
│   owner: human_user_id,                                    │
│   def:   agent_def_id,                                     │
│   dlg:   delegation_id,        ← 本次委托的 jti            │
│   act:   { sub: human_user_id, ... }   ← 委托链，可嵌套    │
│   esc:   ["delete","export"]   ← 需人工确认的敏感动作      │
│ }                                                          │
└───────────────────────────────────────────────────────────┘
```

**关键性质**：定义行 1 条 + 实例行「有多少活跃用户就有多少条，且从 0 开始」+ 凭据不落库（只落一条委托记录用于撤销）。

---

## 4. 实例 ID 的确定性派生（UUIDv5）

```
instance_id = UUIDv5(namespace = agent_def_id, name = owner_user_id)
```

即 `SHA1(namespace_bytes ‖ name_bytes)` 取前 16 字节 → 置 version=5、variant=10x。

- **可行性实证**：`stdx.crypto.digest.{SHA1, HMAC, HashType}` 在本仓库已被使用（`libs/cos-sdk/src/sign/CosSigner.cj:5`），
  stdx 1.1.3 的动态库 `libstdx.crypto.digest.dll` 在 `libs/` 内已就位，**不需要新依赖**。
- **性质**：同一 (def, owner) 永远算出同一个 id；不同 (def, owner) 碰撞概率可忽略；**无需查库即可生成**，
  因此登录路径上零额外写库。
- **落库时 id 不漂移**：`agent_instance.id` 直接写入这个派生值，不是数据库生成的 `gen_random_uuid()`。
  这保证「先被引用（写进 token/日志），后被落库」时两处是同一个 id。

### 4.1 什么时候才落库（惰性物化的触发条件）

| 触发事件 | 是否物化 | 理由 |
|---|---|---|
| 人类登录 | **否** | 只签 token，ID 已在 token 里 |
| 发起一次普通对话（无持久化产物） | **否** | 没有需要存档的状态 |
| 提交长程任务 / 落第一条产物 / 装第一个技能 / 写第一条长期记忆 | **是** | 首次产生归属该实例的状态 |
| 用户主动定制（改名、改模型 override、设记忆范围） | **是** | 有 per-user 配置要存 |

**反例也要写清**：只聊天不干活的用户，库里永远没有他的 agent 实例行——这是特性，不是缺陷。

---

## 5. 委托 Token

### 5.1 Claims 设计

现有 JWT 只带 `user` / `session` 两个 claim（`JWTUtil.cj:34-49`），且 `withClaim(name, value: String)` 可用
（`libs/jwt4cj/src/jwt_creator.cj`），所以扩展只需把结构化信息以 JSON 字符串放进自定义 claim：

```jsonc
{
  "user":    "<instance_id>",          // 复用既有 claim：sub 语义 = 执行者（agent 实例）
  "session": "<delegation_id>",        // 复用既有 claim：会话语义 = 本次委托
  "owner":   "<human_user_id>",        // 新增：归属真人
  "def":     "<agent_def_id>",         // 新增：来自哪个定义
  "aty":     "agent_instance",         // 新增：主体类型（区分人类 token）
  "act":     "{\"sub\":\"<human_user_id>\",\"iat\":<ts>}",  // 新增：委托链（可嵌套）
  "esc":     "[\"delete\",\"export\"]" // 新增：需人工确认的动作（Phase 3）
}
```

- **零新表扩展凭据**：不新建 token 体系，沿用 `JWTUtil` + config `jwtSecret`（v1 D2 已统一为 Local 密钥）。
- **中间件改动集中在一处**：`JWTUtil.verifyToken`（`JWTUtil.cj:96-121`）多取 3 个 claim，`JWTPayload`（`:179-191`）
  加字段；`DeserializeUserMiddleware.setUserToLocals`（`:139-143`）往 `req.locals` 多写 `ownerUserId / actorType /
  delegationId`。下游控制器从 locals 读，不需要逐个改。
- **向后兼容**：老 token 没有这些 claim → 解析为空串 → 行为与今天完全一致（人类 token 路径零影响）。

### 5.2 权限取交集（capability intersection）

```
agent token 的有效权限 = agents.permissions（定义声明的能力） ∩ 该人类用户的 RBAC 权限
```

- 定义能读写 `issue/commit`，但该人类只有 `issue` 读权限 ⇒ agent 只能读 `issue`。
- 判定落点：`RequirePermissionMiddleware` 已有超管 `*` 放行；交集计算建议新增一个 `EffectivePermissionResolver`，
  入参 `(ownerUserId, agentDefId)`，结果按 `(owner, def)` 缓存。
- **为什么是交集不是并集/继承**：OBO 模型（继承用户全部权限）会让 agent 拿到人类偶然拥有的高权限；
  service-account 模型（用 agent 自己的权限）会让 agent 越过人类的权限边界去碰别人的数据。**交集是唯一
  同时满足「不越人类的权」和「不越 agent 的职」的算法**。

### 5.3 撤销：复用 `uctoo_session`，不新建表

- 现状：`uctoo_session(id, user_id, valid, ...)`（`sql/uctooDB.sql:7581-7593`），登出走
  `AuthorizeUtil.logout` → `UctooSessionService.updateStatus(sessionId, false)`（`:963`）。
- 方案：每次签发委托 token 时，额外建一条 `uctoo_session` 行（`user_id` = 人类用户 id，
  新增列标记 `delegation_id` 与 `instance_id`）。agent token 的 `session` claim 即该行 id。
- 中间件对 agent token **增加一次委托有效性检查**（按 delegation_id 查 `valid`，带短缓存，命中即放行）。
- 人类登出 ⇒ 把该 user 名下所有委托行置 `valid=false` ⇒ **该用户的 agent token 立即失效，且只影响他这一次委托**，
  不影响别人的。
- 这直接消灭了 v1 遗留的缺陷：token 现在写在 `uctoo_user.access_token` 列上（`AgentAuthService.cj:88-91`），
  per-user 实例下多人并发登录会互相覆盖；改为委托行后，一行一次委托，无覆盖问题。

---

## 6. 归因三元组（回答 C1）

v1 是双列（`creator`=执行者 + `owner_user_id`=归属者）。v2 升级为三元组：

| 字段 | 语义 | 值 |
|---|---|---|
| `creator` | **谁执行的**（actor） | agent 实例的 `instance_id`（原为 agent 的 `uctoo_user.id`） |
| `owner_user_id` | **归谁**（owner） | 人类用户 id（v1 既有，不变） |
| `delegation_id` | **哪一次授权**（新增） | 本次委托的 jti |

三元组能回答的具体问题：

```sql
-- Q1：用户 U 让他的主 agent 干过什么（五张归属表，清单以 PermissionUtils.hasOwnerUserColumn 为准）
SELECT 'agent_tasks' AS kind, id, status, created_at FROM agent_tasks
WHERE owner_user_id = 'U' AND deleted_at IS NULL
UNION ALL SELECT 'crontab', id, status, created_at FROM crontab WHERE owner_user_id = 'U'
UNION ALL SELECT 'lrt_artifact', id, 0, created_at FROM long_running_task_artifact WHERE owner_user_id = 'U'
ORDER BY created_at DESC;

-- Q2：某次登录会话里，agent 到底动了哪些数据（按委托圈选，业界通常只能到 user 级）
SELECT module, operate, route, created_at FROM operate_log
WHERE delegation_id = '<delegation_id>' ORDER BY created_at;

-- Q3：这个 agent 实例是谁的、来自哪个定义
SELECT ai.id, ai.owner_user_id, ai.agent_def_id, a.name, ai.status
FROM agent_instance ai JOIN agents a ON a.id = ai.agent_def_id
WHERE ai.id = '<instance_id>';
```

> Q2 需要 `operate_log` 增加 `owner_user_id` / `delegation_id` / `actor_type` 三列（见 §7.3）。
> 现状 `operate_log` 只有 `creator`（`sql/uctooDB.sql:6219-6232`），**无法按归属者或委托圈选**——这是 v1 留下的
> 审计缺口，Phase 2 必须补。

---

## 7. 数据模型变更（增量 DDL 草案）

> 规范：落 `sql/incremental/<YYYYMMDD>_<模块>_<动作>.sql`，幂等、禁 DROP，执行后 `loaddbinfo`。
> 以下为草案，实现时按实际拆分。

### 7.1 `agents` 加实例化策略列（Phase 1，1 列）

```sql
ALTER TABLE "public"."agents" ADD COLUMN IF NOT EXISTS "instantiation_policy" varchar(20) NOT NULL DEFAULT 'shared';
COMMENT ON COLUMN "public"."agents"."instantiation_policy" IS
  '实例化策略：shared-全体共用单例(默认)；per_user-每人派生一个归属实例；per_session-每次会话一个实例';
```

**为什么需要它**：per-user 实例不是 universal truth。公司级共享客服 bot 就该是 `shared`（所有人共用同一人格与
记忆）；个人助理才是 `per_user`。一刀切 per-user 会让共享场景平白长出 N 份配置。策略写在定义行上，
一种 agent 一个选择。

### 7.2 `agent_instance` 表（Phase 2，惰性物化载体）

```sql
CREATE TABLE IF NOT EXISTS "public"."agent_instance" (
  "id" uuid NOT NULL,                       -- 恒为 UUIDv5(def_id, owner_user_id)，非 gen_random_uuid()
  "agent_def_id" uuid NOT NULL,
  "owner_user_id" uuid NOT NULL,
  "status" varchar(20) NOT NULL DEFAULT 'active',
  "display_name" varchar(100),
  "config_override" json DEFAULT '{}'::json,
  "memory_scope" varchar(20) DEFAULT 'user',
  "materialized_reason" varchar(64),        -- 首次物化的触发原因，便于回溯「为什么这里有行」
  "first_materialized_at" timestamptz,
  "last_active_at" timestamptz,
  "creator" uuid,
  "created_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz,
  PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX IF NOT EXISTS "uk_agent_instance_def_owner"
  ON "public"."agent_instance" ("agent_def_id", "owner_user_id");
CREATE INDEX IF NOT EXISTS "idx_agent_instance_owner" ON "public"."agent_instance" ("owner_user_id");
```

### 7.3 审计与委托列（Phase 2）

```sql
ALTER TABLE "public"."operate_log" ADD COLUMN IF NOT EXISTS "owner_user_id" uuid;
ALTER TABLE "public"."operate_log" ADD COLUMN IF NOT EXISTS "delegation_id" uuid;
ALTER TABLE "public"."operate_log" ADD COLUMN IF NOT EXISTS "actor_type" varchar(16);
-- actor_type: human / agent_instance / agent_service / system

ALTER TABLE "public"."uctoo_session" ADD COLUMN IF NOT EXISTS "delegation_id" uuid;
ALTER TABLE "public"."uctoo_session" ADD COLUMN IF NOT EXISTS "instance_id" uuid;
```

### 7.4 为什么不复用现有表

| 候选 | 复用不成立的理由 |
|---|---|
| 复用 `agents` 表存实例 | ① `uk_agents_source_path`（`:646`）逼实例行用 NULL 钻空子；② `agent_type` 要混装「定义」与「实例」，所有查 `agents` 的地方（含 AGENTS.md 同步器）都要加过滤，漏一处就误伤；③ `user_id` 列现有语义是「agent 自己的 uctoo_user.id」（`AipIdentityService` 双指针），复用来存人类 id 会让同一列在两行上含义不同——这正是 AC-214 比错对象的根因，不能再造一次 |
| 复用 `uctoo_user` 存 agent 身份 | `password NOT NULL`（`:7604`）强制占位密码 + signin 特判；且「登录即建帐号」让人表随登录线性膨胀，是最坏的膨胀模式 |

---

## 8. 改造点清单（file:line）

| # | 位置 | 改动 | 阶段 |
|---|---|---|---|
| 1 | `src/app/utils/auth/JWTUtil.cj:34` `generateAccessToken` | 增加可选命名参 `ownerUserId / agentDefId / actorType / delegationId / act`，用 `withClaim(String)` 写入 | P1 |
| 2 | `src/app/utils/auth/JWTUtil.cj:96` `verifyToken` + `:179` `JWTPayload` | 解析新增 claim（缺失返回空串，老 token 零影响） | P1 |
| 3 | `src/app/middlewares/auth/DeserializeUserMiddleware.cj:139` | `req.locals` 补 `ownerUserId / actorType / delegationId` | P1 |
| 4 | `src/app/services/aip/AgentAuthService.cj:40` `agentAutoLogin` | 增加 `delegateForOwner(agentDefId, ownerUserId)`：算 instance_id → 签委托 token → 建委托 session 行；**旧的按 agentId 登录路径保留**（系统级/AIP 互联仍需要） | P1 |
| 5 | `src/app/controllers/uctoo/uctoo_user/UctooUserAuthController.cj:199` `autoLoginMainAgent` | 改为按 `agents.instantiation_policy` 分流：`per_user` → 走 4 的委托签发；`shared` → 保持现状（单例，向后兼容） | P1 |
| 6 | `src/app/utils/auth/AuthorizeUtil.cj:71/203` | 登录响应增加 `agent_instance_id / delegation_id / instantiation_policy`，保留现有 4 个字段不删 | P1 |
| 7 | `src/app/services/lrt/long_task_api_service.cj:145-172` | `creator` 改写 `instance_id`（无实例时降级为现有 agent uctoo_user.id）；`delegation_id` 透传给 `LrtPluginClient.*`（7 个方法签名） | P2 |
| 8 | `src/app/utils/PermissionUtils.cj:57/64` | `buildOwnershipPredicate` 支持 instance 主体：`(creator = actor OR owner_user_id = owner)`；`hasOwnerUserColumn` 清单同步（加 `operate_log`） | P2 |
| 9 | `src/app/services/uctoo/OperateLogService.cj` `resolveAuditActorType` | 按 `actor_type` claim 区分 `human / agent_instance / system`；写 `owner_user_id` / `delegation_id` | P2 |
| 10 | 登出链路 `AuthorizeUtil.logout` | 新增 `invalidateDelegationsForUser(userId)`，一并置该用户所有委托 session `valid=false` | P2 |
| 11 | 新增 `EffectivePermissionResolver` | 能力交集计算 + 缓存 | P3 |
| 12 | 敏感动作升级（human-in-the-loop） | token `esc` claim + 中间件拦截转人工确认 | P3 |
| 13 | 配额 / 记忆 / 成本按 `owner_user_id` 归集 | 复用 `agent_instance` 行的 `config_override` / `memory_scope` | P3 |

---

## 9. 与业界做法的对比

| 做法 | 代表 | agent 有独立身份吗 | 能归属到人吗 | per-user 实例吗 | 代价 |
|---|---|---|---|---|---|
| **纯 OBO / Token Exchange**（RFC 8693 `act`） | Entra ID OBO、多数 SaaS AI | ❌ 只记人类 | ✅ | ❌ | 答不出「这是哪个 agent 干的」 |
| **服务账号 + impersonation** | GCP SA、K8s SA、OpenAI Assistants | ✅ 全局单例 | ⚠️ 只在日志里 | ❌ | 单例共享，无法 per-user；权限是并集，容易越权 |
| **租户级 agent 配置对象** | M365 Copilot、Agentforce、ServiceNow Now Assist | ❌（仅是配置） | ✅（以调用者身份执行） | ❌（UI 概念，无可寻址身份） | 无独立身份 ⇒ 无 per-user 记忆/配额/偏好 |
| **进程内角色** | AutoGen / CrewAI / LangGraph | ❌ 重启即失 | ❌ | ❌ | 不可审计 |
| **可推导的工作负载身份** | SPIFFE/SPIRE | ✅ 由选择器推导，无需预注册 | ❌ | ❌ | 没有「归属人类 + 委托」语义 |
| **本方案 DAI** | — | ✅ 确定性派生 | ✅ owner 是 token 一等公民 | ✅ 惰性，默认 0 行 | 见 §11 |

本方案不是发明新构件，而是把四种已有思想按「定义 / 实例 / 凭据」三层组合起来，并补上缺的那一块：

| 借来的思想 | 来源 | 补上的东西 |
|---|---|---|
| 身份可推导、无需预注册 | SPIFFE | 加「归属人类」与「委托」语义 |
| 委托链 `act` | RFC 8693 | 从单层扩到多层（含深度上限与 intent），并让它**可撤销** |
| 最小权限 | 通用 | 从「继承」或「并集」改为**交集** |
| 惰性物化 / JIT provisioning | 云 IAM | 首次用在 agent 身份上，把「存在」与「存档」解耦 |

**相对业界多出来的四点**（这是"超越"的具体所指，不是口号）：

1. **零行也有身份**：业界要么预建 N 行（繁琐）、要么完全没有身份（不可溯源）。本方案在两者之间开出第三条路——
   ID 可算 ⇒ 未落库的实例照样能写进 token 和审计。
2. **权限取交集而非继承/并集**：避免「agent 借人类的权越界」和「agent 越过人类的权碰别人数据」。
3. **三元组归因**：`执行者 + 归属者 + 委托` 比业界常见的「只记人类」或「只记服务账号」多出一个维度，
   使得「某次登录期间 agent 做了什么」可以被整体圈选（§6 Q2）。
4. **委托可单独撤销**：一次登出只失效自己那次委托，不影响他人——JWT 无状态导致的「登出后 token 还活两天」
   问题被正面解决，而不是靠缩短 TTL 缓解。

---

## 10. 迁移路径（兼容现状，分三阶段）

| 阶段 | 交付 | 新增 DB 行 | 收益 |
|---|---|---|---|
| **P1 委托凭据** | 登录时按策略签发 per-user 委托 token（sub=instance_id，带 owner/dlg） | **0** | 溯源能力立刻可用；现有单例行为由 `instantiation_policy='shared'` 保持 |
| **P2 惰性物化 + 审计** | `agent_instance` 表、审计三列、委托撤销、PermissionUtils 支持 instance | 仅活跃用户 | per-user 配置/记忆/配额；登出即时失效；审计可圈选 |
| **P3 最小权限** | 能力交集、敏感动作人工确认、成本归集 | 0 | 越权面收敛到交集 |

**v1 资产全部保留**：系统级 MainAgent 行与其 `uctoo_user` 服务账号继续存在（后台任务、cron、AIP 互联仍需
「无人类归属」的执行者身份）；`creator` / `owner_user_id` 双列语义不变，只是 `creator` 的取值从
「agent 服务账号 id」扩展为「instance_id 或 agent 服务账号 id」，**老数据无需迁移**（`owner_user_id` 为 NULL 时
降级为 v1 行为）。

---

## 11. 风险、边界与代价（诚实清单）

| 项 | 说明 | 缓解 |
|---|---|---|
| 中间件要理解两类主体 | 人类 token 与 agent token 都要能过 `DeserializeUserMiddleware` | 新增 claim 缺省为空 ⇒ 老路径零影响；`actor_type` 显式区分 |
| UUIDv5 引入哈希计算 | 登录路径多一次 SHA-1（微秒级） | 实测前先跑一个最小用例；SHA1 已确认可用（`CosSigner.cj:5`） |
| 委托有效性检查多一次查询 | 每个 agent 请求多一次 `uctoo_session` 查 | 按 delegation_id 短缓存（30s），且只在 `actor_type=agent_instance` 时查 |
| 能力交集会「缩权」 | 有些 agent 动作会突然被拒 | P3 前先只记录不拦截（shadow mode），观察一周再开 |
| 实例身份不是 UUID 主键生成的 | 落库时必须显式写入派生值，写错就错位 | 物化入口只有一处（`AgentInstanceService.materialize`），并对 `UNIQUE(def, owner)` 做幂等 upsert |
| **per-user 实例不是万能的** | 共享场景（公司 bot）per-user 会平白长 N 份配置 | `instantiation_policy` 可配，默认 `shared` |
| 只覆盖口令登录 | OAuth 回调走 302，无 JSON 载体 | 与现状一致；需要时在回调落地页补一次显式委托签发 |

---

## 12. 待拍板的决策（请确认后再动代码）

1. **默认策略**：`agents.instantiation_policy` 默认 `shared`（保守，行为不变）还是 `per_user`（直接切到新模型）？
   建议 **`shared`，只在 MainAgent 上手工改为 `per_user` 验证一轮再放开**。
2. **Phase 划分**：一次做完 P1+P2，还是先只做 P1（零新表，一周内可验）？**建议先 P1**——它不加表、不加列
   （除 1 列策略），就能拿到「每个用户有自己的 agent 身份且可溯源」的 80% 收益。
3. **能力交集是否一起做**（P3）：不做则 agent token 的有效权限 = 人类权限（等价于 OBO），越权面较大。
4. **`uctoo_user` 里的 agent 服务账号行是否保留**：建议保留（系统级/AIP 需要），per-user 实例**不建**该类行。

---

## 13. 验收标准

- P1：人类 A 与人类 B 分别登录，各自拿到的 `agent_instance_id` **不同且稳定**（同一人重复登录得到同一个值），
  且都未在库中产生新行（`SELECT COUNT(*) FROM agent_instance` 不增）。
- P1：agent 身份执行的写操作，`owner_user_id` = 对应人类，与 v1 双列语义一致。
- P2：A 让 agent 提交长程任务后，`agent_instance` 恰好新增 **1 行**，且 `id` = 预期派生值、
  `materialized_reason` 有值；B 未干活 ⇒ B 无行。
- P2：A 登出后其 agent token 立即 401；B 的 agent token 不受影响。
- P2：`operate_log` 可按 `delegation_id` 圈选出某次登录期间 agent 的全部动作。
- P3（若做）：越权用例——人类无 `commit` 写权限时，agent 写 commit 被拒，且日志记 `denied_by=intersection`。

---

## 14. 任务拆分（建议）

| ID | 任务 | 依赖 | 阶段 |
|---|---|---|---|
| T-01 | JWT claims 扩展（`JWTUtil` 生成/解析 + `JWTPayload`） | — | P1 |
| T-02 | `DeserializeUserMiddleware` locals 扩展 | T-01 | P1 |
| T-03 | `agents.instantiation_policy` 列 + DAO/PO 字段 | — | P1 |
| T-04 | `AgentAuthService.delegateForOwner`（UUIDv5 + 委托 token + 委托 session） | T-01 | P1 |
| T-05 | 登录链路按策略分流（替换 `autoLoginMainAgent` 单例逻辑） | T-03/T-04 | P1 |
| T-06 | `agent_instance` 表 + `AgentInstanceService.materialize`（幂等 upsert） | T-04 | P2 |
| T-07 | 审计三列 + `resolveAuditActorType` 按 actor_type 区分 | T-02 | P2 |
| T-08 | LRT 链路透传 `instance_id` / `delegation_id`（7 个 PluginClient 签名） | T-04 | P2 |
| T-09 | `PermissionUtils` 支持 instance 主体 | T-06 | P2 |
| T-10 | 登出连带撤销委托 | T-04 | P2 |
| T-11 | 能力交集 resolver（shadow mode 先行） | T-09 | P3 |
| T-12 | 敏感动作人工确认（esc claim） | T-11 | P3 |
