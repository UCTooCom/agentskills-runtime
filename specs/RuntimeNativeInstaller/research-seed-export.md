# 研究补充章（二）：Seed 数据范围、初始帐号二元组与数据库导出机制（SEP）

> 本章是 `research-seed-identity.md`（Seed Identity Contract，SIC）的**后续与收窄**。SIC 解决"seed 里的身份 uuid 怎么在新环境重绑定"，本章解决三个更靠前的问题：**库叫什么**、**seed 里该有几个帐号**、**seed 文件本身怎么从开发环境生成**。
>
> 本章所有数字均由脚本实测（脚本 `D:/UCT/tmp/analyze_public.py`、`analyze_refs2.py`、`tier_calc.py`，可复现），不引用估计值。

> **第二轮修订（2026-10-07）**：用户提出三点质疑——`db_connection` / `agents` 等表因已有**文件系统↔数据库双向同步**而不该保留初始数据；`config` 一部分由 `.env` 同步、一部分是初始配置；**所有初始数据必须脱敏**。经源码与数据库取证**三点全部成立**，据此：新增 **T-F 同步/派生档**（`agents` / `agent_skills` / `db_connection` / `db_info` 不导）、`config` 加**行级谓词** `env_key IS NULL`（102 行 → 17 行）、流水线新增 **E4.5 脱敏步**与两条门禁。完整取证见 **`research-seed-content.md`**；本章只记对既有结论的修订，改动处均以「第二轮」标注。

---

## 零、本轮四个结论（先看结论）

| # | 结论 | 依据 |
|---|---|---|
| **C-1** | **默认数据库名固定为 `uctoo`**。这不是新增约定，而是既有事实：`.env:244` 与 `.env:247` 两条连接串都指向 `...5432/uctoo`。 | §一 |
| **C-2** | 初始帐号是**二元组**，不是"一个超管"：**① 一个人类超管（`user_type='human'`）+ ② 一个主 agent 帐号（`user_type='agent'`）**。后者不是可选项——runtime 把主 agent 当一等公民建模，登录/委派/审计链路都依赖它。 | §二 |
| **C-3** | **主 agent 是"双身份"**：`uctoo_user.id`（`8803ed58…`，351 处引用）与 `agents.id`（`4dfc6252…`，5078 处引用）是**两个独立命名空间**，重绑定必须分命名空间处理，不能混为一谈。 | §二.3 |
| **C-4** | 需要一个**数据库导出机制（SEP）**：现状是 Navicat 整库导出（105.3 MB / 226 表 / 6.08 万条 INSERT），其中 **78% 是 `agent_contexts` 一张表的运行时 blob**。按"结构 + 引导数据 + entity 示例"分层后，目标产物 **≈0.90 MB，是原文件的 0.86%**。 | §三 |
| **C-5**<br>（第二轮） | 初始数据要"**少而净**"：**同步能再造的不存**（`agents`/`agent_skills`/`db_connection`/`db_info` → T-F）、**`.env` 会给的不存**（`config` 中 85 行 `env_key` 行 → T-D′）、**剩下的必须脱敏后存**。并发现现实隐患：`.env` 明文密钥被原样写进 `config.value` 且 `is_sensitive` 全表 0 行标记。 | `research-seed-content.md`；本章 §3.3.1 |

---

## 一、默认数据库名：`uctoo`

### 1.1 事实

```
.env:244  orm_connectionUrl=postgresql://postgres:uctoo123@127.0.0.1:5432/uctoo
.env:247  postgres_orm_connectionUrl=postgresql://postgres:uctoo123@127.0.0.1:5432/uctoo
```

两个数据源配置指向同一个库名 `uctoo`。因此：

- 安装器 DK-2/DK-4 的**默认库名 = `uctoo`**，不是让开发者填空的必填项；开发者可在向导里改，但默认按钮就是 `uctoo`。
- 库不存在时**由安装器创建**（`CREATE DATABASE uctoo`），而不是要求开发者事先手工建库后才发现名字对不上。

### 1.2 顺带关闭一个历史缺口（S-R1）

上一章留了待确认项「基线以哪个库为准」。本轮取证后**关闭**：

| 文件 | Navicat `Source Catalog` | 表数 | 导出时间 |
|---|---|---|---|
| `sql/uctooDB.sql`（现行基线） | **`uctoov3`** | 206 CREATE TABLE | 2026-10-02 |
| `sql/public20261007.sql`（最新全量） | **`uctoo`** | 226 CREATE TABLE | 2026-10-07 |

**结论**：现行 `uctooDB.sql` 来自一个**历史遗留库 `uctoov3`**，比当前 `.env` 实际连接的 `uctoo` 库**少 20 张表**，且表结构已落后 5 天。这就是"基线里的 `uctoo_user`/`role_has_permission`/`user_has_roles` 三张表 0 行"的根因之一——它压根不是从运行库导的。

**处置**：基线以 `uctoo` 库为准；`uctooDB.sql` 由 §三 的导出机制**重新生成**并覆盖，不再手工 Navicat 导出。

---

## 二、初始帐号二元组：一个超管 + 一个主 agent

### 2.1 源码取证：主 agent 帐号是怎么建的、怎么用的

**（1）建号：`AipIdentityService.registerLocalIdentity`**（`src/app/services/aip/AipIdentityService.cj:28-80`）

```cj
let agentId = UUID.random().toString()
let shortId = agentId[0..8]
let username = "agent_${shortId}"
let email    = "agent_${shortId}@agents.internal"
let unloginablePassword = UUID.random().toString() + UUID.random().toString()

user.username = username ; user.email = email
user.password = unloginablePassword
user.userType = "agent"                      // ← 关键：类型标记
user.agentId  = Some<String>(agentId)        // ← uctoo_user → agents 的正向指针
...
userRole.userId = userId ; userRole.roleId = AGENTS_ROLE_ID   // a686ff1f-…-2b2d5267c682
...
userGroup.groupableId = userId ; userGroup.groupId = <user_group where code='agents'>
...
agent.id = agentId ; agent.userId = Some<String>(userId)      // ← agents → uctoo_user 的反向指针
agent.identityStatus = "none" ; agent.discoverable = true
```

即一次注册落 **4 张表**：`uctoo_user`（agent 类型）+ `user_has_roles`（绑定 `agents` 角色）+ `user_has_group`（绑定 `agents` 用户组）+ `agents`（智能体实体）。

**（2）用号：`AgentAuthService.agentAutoLogin`**（`src/app/services/aip/AgentAuthService.cj:39-88`）

```cj
let agentOpt = getExecutor().findAgentsById(agentId)
var userOpt = if (agent.userId.isSome()) { findUctooUserById(agent.userId) }
              else { findUctooUserByAgentId(agentId) }     // ← 双指针互为兜底
if (user.userType != "agent")  → "AUTH-AGENT-001: 该帐号不是智能体帐号"
if (agent.status != 1)         → "智能体未处于运行状态"
user.accessToken = token ; updateUctooUser(user)            // ← token 写回账号行
```

**（3）边界：`UctooUserAuthController.cj:112-116`**

```cj
if (u.userType == "agent") {
    res.status(403).json("AUTH-AGENT-001：该帐号为智能体专用帐号，不支持密码登录")
}
```

**三条硬事实**：

1. agent 帐号**不支持密码登录**（密码字段存的是不可登录随机串），只能走 `agentAutoLogin`；
2. 能否自动登录取决于 **`agents.status == 1`** 且 **`uctoo_user.user_type == 'agent'`**；
3. `agents.user_id` 与 `uctoo_user.agent_id` **必须双向对得上**，任一侧缺失都会退化（另一侧可兜底，但两条都断就彻底登录不了）。

### 2.2 实测：本机 23 个帐号里，只有 2 个该进 seed

```
uctoo_user 共 23 行：
  505cf909-5e0e-4dde-b215-74274d2cc548  admin      UCTooApp   human  status=1   ← 超管
  8803ed58-e72e-4757-9f1e-2852a940e751  mainagent  MainAgent  agent  status=1   ← 主 agent
  00000000-…-0002 ~ 0006                liming/wangfang/chenwei/liuyang/zhaoxue  ← 5 个哨兵演示号
  acca5836(test1)、test/test2/test3/test5/test0002/test06/uctoov4/15980018001/
  testuser/testuser2/testuser5/testuser001/testuser_crud_…/testflow_…/statustest_…  ← 16 个测试号
```

**按用户裁定：不创建任何演示帐号**。因此 seed 里的 `uctoo_user` 数据**一行都不导**，两个帐号全部由安装器在安装期真实落库（与既有 REQ「create-admin 只做真路径」同口径）。

**删掉这 21 个主体的连带影响已量化**（`analyze_refs2.py`）：

| 主体 | 引用数 | 落点 | 是否在保留集内 |
|---|---|---|---|
| test1 | 253 | `data_access_authorization` 101、`uctoo_session` 88、**`entity` 33**、`operate_log` 25、`login_log` 4、`user_has_roles` 1、`user_has_group` 1 | **是（`entity` 33 处）** |
| 5 个哨兵 | 各 25~31 | `user_has_tasks`、`user_has_company`、`messages`、`tasks`、`company`、`user_has_roles`、`user_score` | 否（全为业务/演示表） |
| 其余测试号 | 3~78 | `commit`/`repository_file`/`branch`（代码托管业务）、`uctoo_session`、`operate_log` | 否 |

**唯一需要决策的残留**：`entity` 表的 146 行示例数据里，**113 行 creator 是 admin、33 行 creator 是 test1**。test1 不再建号 ⇒ 这 33 行必须显式处置（见 §五 OQ-S3，默认建议 `map-to: super_admin`）。

### 2.3 主 agent 是"双身份"：两个命名空间不能混

实测引用分布（全库口径）：

```
uctoo_user.id 命名空间：
  505cf909…（admin 超管）    30,700 处   —— operate_log 25811 / uctoo_session 2326 / login_log 644 …
  8803ed58…（mainagent 帐号）   351 处   —— crontab_log 150 / long_running_task_artifact 88 / agent_tasks 50 …

agents.id 命名空间：
  4dfc6252…（MainAgent 实体） 5,078 处   —— agent_messages 3320 / agent_tasks 1458 / agent_contexts 175 …
```

**这是 SIC 的一个实质补丁**：上一章的占位符方案只有 `{{principal:<ref>}}`（隐含"都是 `uctoo_user` 主键"），**对 `agents.id` 不适用**。必须分两个命名空间：

```
{{principal:super_admin}}   → uctoo_user.id（人类/服务账号主键）
{{principal:svc_mainagent}} → uctoo_user.id（agent 账号主键）
{{agent:main}}              → agents.id（智能体实体主键）
```

判定规则沿用上一章的"**列名类 + 清单命中**双条件"，但对 `agent_id` 列要额外落一条：**`agent_id` 列指向 `agents.id`，不是 `uctoo_user.id`**（`uctoo_user.agent_id = 4dfc6252…` 而 `uctoo_user.id = 8803ed58…`，实测确证）。这条如果搞反，重绑定会把 agent 实体的 uuid 填进用户列，导入期不报错、运行期才炸。

### 2.4 安装器要落的 6 行（两帐号 + 绑定）

按顺序、全部幂等（走既有 `AipIdentityService`/`create-admin` 真路径，不自己拼 INSERT）：

```
A1 uctoo_user        超管（human，user_type='human'）          ← create-admin 真路径
A2 uctoo_user        主 agent 账号（user_type='agent'，password=不可登录随机串）
A3 user_has_roles    超管 → 超管角色（2338cf7b-82b7-4cf6-b1ae-6a3ca79d683d，持 '*'）
A4 user_has_roles    主 agent → agents 角色（a686ff1f-7fb4-48df-8609-2b2d5267c682）
A5 user_has_group    主 agent → user_group(code='agents')
A6 agents            MainAgent 实体（agent_type='MAIN'，status=1，user_id=<A2 的 id>）
   + 回填 A2.agent_id = A6.id（双向指针对齐，见 §2.1-(3)）
```

**顺序不可颠倒**：`A6` 需要 `A2` 的 id，`A2.agent_id` 需要 `A6` 的 id ⇒ 先建 A2 → 建 A6 → UPDATE A2.agent_id。

---

## 三、数据库导出机制（Seed Export Policy, SEP）

### 3.1 现状：Navicat 整库导出的四个问题

以 `sql/public20261007.sql`（105.3 MB，2026-10-07 从 `uctoo` 库导出）为样本：

| 问题 | 实测 |
|---|---|
| **① 体积失控，且集中在运行时 blob** | 数据段 103.15 MB，其中 **`agent_contexts` 单表 381 行占 80.66 MB（78.2%）**；`operate_log` 28,426 行占 8.05 MB |
| **② 混进大量日志/会话/派生数据** | `crontab_log` 6,504、`llm_channel_health` 5,795、`llm_usage_logs` 4,484、`uctoo_session` 2,548、`login_log` 656 |
| **③ 含可重生成的派生表** | `db_info` 3,176 行 / 1.12 MB —— 该表由 `loaddbinfo` 从 `information_schema` 重算（`src/app/services/uctoo/DbInfoService.cj:1026-1047`），导出它是纯浪费 |
| **④ 破坏式语句** | 含 **231 条 `DROP TABLE IF EXISTS`**（Navicat 默认行为）。开发者在已有库上误跑 = 数据蒸发 |

补充事实：226 张表中 **128 张本来就只有结构没有数据**，说明"结构"和"数据"本就该分开处理。

### 3.2 分层模型 T-A ~ T-E

| 档 | 含义 | 处理方式 | 判定 |
|---|---|---|---|
| **T-A 结构** | 全部 226 张表 | `CREATE TABLE IF NOT EXISTS` + `COMMENT` + PK/UK/索引 | **默认档**：未在任何白名单出现的表一律落这里 |
| **T-B 引导数据** | 系统启动与运行必需的控制面数据 | 导数据 | 显式白名单（**9 张表**，见 §3.3） |
| **T-C 示例数据** | `entity` 表样例 | 导数据（可配行数上限与过滤条件） | 显式白名单 |
| **T-D 安装器生成** | 帐号与绑定 | **不导**，由 §2.4 的 A1~A6 真实落库 | `uctoo_user` / `user_has_roles` / `user_has_group` / `agents` |
| **T-D′ 运行时生成** | 每次启动由 `.env` 重建的配置 | **不导**（行级谓词） | `config` 中 `env_key IS NOT NULL` 的 85 行（见 §3.3.1） |
| **T-E 排除** | 业务数据、日志、会话 | 仅导结构 | 不在 T-B/T-C/T-D 的其余有数据表 |
| **T-F 同步/派生** | 由文件系统双向同步或工具重算再造的数据 | **不导** | `agents` / `agent_skills` / `db_connection` / `db_info`（见 §3.3.1） |

> **T-E 与 T-F 为什么要分开**：前者是"不该分发"（业务数据/隐私/体量），后者是"不该存"（会被自动再造，存了反而产生冲突与幻觉数据）。两者的判据、门禁与出错症状都不同，混在一档会让后续维护者无法判断"这张表到底能不能加回白名单"。

### 3.3 实测账：105.3 MB → 0.90 MB

| 段 | 内容 | 体量 |
|---|---|---|
| **T-A 结构** | DDL 0.151 MB + `COMMENT ON` 0.205 MB + 约束/索引 0.046 MB | **0.403 MB** |
| **T-B 引导数据** | `i18` 1088 行 0.245、`permissions` 442 行 0.154、`config` **17** 行（仅 `env_key IS NULL`）、`role_has_permission` 48 行 0.011、`crontab_task_registry` 13、`user_group` 8、`agent_executors` 5、`uctoo_role` 7、`lang` 2 | **≈1,633 行 / 0.42 MB** |
| **T-C 示例** | `entity` 146 行 | **0.048 MB** |
| **合计** | | **≈ 0.903 MB（原文件 0.86%）** |

**T-B 为什么是这 10 张表**（逐张给理由，避免拍脑袋）：

| 表 | 缺了会怎样 |
|---|---|
| `permissions` | 菜单/权限节点树为空 ⇒ 侧边栏无入口、RBAC 中间件无处校验 |
| `role_has_permission` | 超管角色没有 `*` 通配 ⇒ 全站 403（上一章 S-G2） |
| `uctoo_role` | 角色定义缺失 ⇒ `user_has_roles` 外键悬空 |
| `i18` | 菜单/权限名无译文 ⇒ 界面显示原始 key |
| `user_group` | `code='agents'` 组缺失 ⇒ 主 agent 建号时的 A5 绑定无处可绑 |
| `config` | 系统配置项为空 ⇒ 依赖 `config` 表的模块读不到默认值 |
| `agent_executors` | LRT 执行器注册表为空 ⇒ 长程任务无执行器可选 |
| `crontab_task_registry` | scheme 注册表为空 ⇒ `lrt://` 等自定义 scheme 无法解析 |
| `lang` | 2 行，语言元数据，随结构带走成本为零 |
| ~~`db_connection`~~ | **已移出**（→ T-F）：1 行描述**本机数据源**且 `password` NOT NULL 存明文，跨环境无意义；详见 §3.3.1 |

### 3.3.1 修订（2026-10-07 第二轮）：T-F 同步/派生档与 `config` 行级谓词

> 完整取证见 `research-seed-content.md`。本节只记对本章结论的修订。

**（1）`db_connection` 移出 T-B**：1 行描述的是**本机数据源**（`host=127.0.0.1 / port=5432 / db=uctoo`），且 `password` 列 **NOT NULL** 存明文（实测长度 8）。跨环境分发既无意义又带明文口令 ⇒ 归 **T-F**，与 `agents` / `agent_skills` / `db_info` 同档。

**（2）`config` 加行级谓词 `env_key IS NULL`**：实测 102 行中 **85 行带 `env_key`**，这些行由 `ConfigSyncHandler.startupSync()` 在**每次启动**从 `.env` upsert，且 `resolveConflict` **恒取 `.env` 的值**（`ConfigSyncHandler.cj:242-244`）⇒ seed 预置必被覆盖，归 **T-D′**。只有 **17 行无 `env_key`** 是纯初始配置，留在 T-B。

**（3）新增 T-F 档的四张表**：

| 表 | 为什么不该导 | 实证 |
|---|---|---|
| `agents` | 启动期由 `AGENTS.md` + `agents/*.md` 同步 upsert（匹配键 `source_path`） | 实测 9/9 行带 `source_path` |
| `agent_skills` | 启动期由 `skills/*` 同步 upsert | 实测 50/56 行带 `source_path`；另 6 行 `sync_status=pending` 是同步残留 |
| `db_connection` | 本机数据源描述 + 明文口令 | 见上文 (1) |
| `db_info` | `loaddbinfo` 可完全重算 | 派生数据 |

**旧基线在这一点上是"碰巧对"的**：`sql/uctooDB.sql` 里 `db_connection` 0 行、`agents` 0 行（正确），但 `agent_skills` **50 行**（错误，且 `source_path` 被手工替换成 `xxx/apps/…` 这种非法路径）。本轮把"碰巧"变成"有规则"。

**（4）门禁与流水线同步升级**：新增 E4.5 脱敏步与「同步派生残留」门禁（白名单表内出现 `source_path` 非空的行即失败），见 §3.5 修订版。

**T-E 排除的典型**（按类别，非逐表列举）：

- 运行时 blob：`agent_contexts`（78%）、`agent_messages`、`agent_memories`、`agent_tasks`、`long_running_task_artifact`、`agent_loop_metrics`
- 日志审计：`operate_log`、`crontab_log`、`llm_usage_logs`、`llm_channel_health`、`login_log`、`lrt_verify_job`、`sms_log`
- 会话令牌：`uctoo_session`、app_access_token``
- 派生：`db_info`（可重算）
- 电商/代码托管/尽调业务：`minishop_*`、`repository*/branch/commit/pull_request/issue_comment/pr_review/milestone/label`、`due_diligence_*`、`codelabs`、`worksheet`、`workbook`
- 微信/支付：`wechatopen*`、`wechatpay_transaction`、`wechat_reply`、`unipay_*`、`point_transactions`

### 3.4 策略文件形态（`sql/seed/export-policy.json`）

```json
{
  "schema": "uctoo/seed-export/v1",
  "defaultDatabase": "uctoo",
  "defaultTier": "structure-only",
  "tiers": {
    "bootstrap": [
      "permissions", "i18", "role_has_permission", "uctoo_role", "user_group",
      "config", "agent_executors", "crontab_task_registry", "lang"
    ],
    "bootstrapRowPredicates": {
      "config": "env_key IS NULL"
    },
    "sample": {
      "entity": { "maxRows": 200, "orderBy": "id" }
    },
    "installer-generated": ["uctoo_user", "user_has_roles", "user_has_group", "agents"],
    "runtime-generated":  { "config": "env_key IS NOT NULL" },
    "sync-derived": ["agents", "agent_skills", "db_connection", "db_info"]
  },
  "identity": {
    "namespaces": {
      "principal": { "table": "uctoo_user", "columns": ["creator", "owner_user_id", "user_id", "created_by", "updated_by"] },
      "agent":     { "table": "agents",     "columns": ["agent_id"] }
    },
    "principals": [
      { "ref": "super_admin",   "kind": "super_admin", "source": "runtime-created" },
      { "ref": "svc_mainagent", "kind": "service",     "username": "mainagent" }
    ],
    "orphanPolicy": {
      "default": "fail",
      "overrides": [
        { "uuid": "acca5836-eba4-454b-9a95-a772758271f3", "to": "super_admin",
          "scope": "entity.creator", "reason": "示例数据原属 test1；test1 不再创建，归位到安装环境超管" }
      ]
    }
  },
  "guards": {
    "maxFileBytes": 2097152,
    "maxRowsPerTable": 5000,
    "forbidStatements": ["DROP TABLE", "TRUNCATE", "DELETE FROM"],
    "secretScan": ["$2a$", "$2b$", "eyJ", "BEGIN PRIVATE KEY", "sk-", "ghp_", "fc-", "postgres://", "jdbc:"],
    "sanitizePolicy": "sql/seed/sanitize-policy.json",
    "forbidSyncDerivedRows": true,
    "failOnUnsanitizedSensitiveColumn": true
  }
}
```

**新增的三个门禁字段**（第二轮补充，取证见 `research-seed-content.md` §3.5）：

- `sanitizePolicy`：指向脱敏策略，导出期强制执行 E4.5 步；
- `forbidSyncDerivedRows`：白名单表内出现 `source_path` 非空的行 ⇒ 导出失败（T-F 的机器保证，防人手滑把 `agent_skills` 加回来）；
- `failOnUnsanitizedSensitiveColumn`：敏感列清单命中的列，若导出值不是 `{{secret:…}}` / `{{env:…}}` 占位符 ⇒ 导出失败（R1/R4 未生效的兜底）。

**`defaultTier: structure-only` 是整个机制里最重要的一个字段**——它把"导出什么"从**黑名单**（"我记得这些表要排除"）翻转为**白名单**（"没被显式批准的只给结构"）。新业务表上线后，如果没人往 `bootstrap` 里加，它自动只导结构，**不可能意外泄漏业务数据**。

### 3.5 导出流水线 E0 ~ E6

```
E0 读策略 sql/seed/export-policy.json（defaultTier=structure-only）
     │
E1 连源库（默认 uctoo）→ 枚举表/列序/注释/约束/索引/行数
     │
E2 结构导出（全部表）
     ├─ CREATE TABLE IF NOT EXISTS（禁 DROP，guards.forbidStatements 兜底）
     ├─ COMMENT ON TABLE / COLUMN
     └─ PK / UNIQUE / INDEX
     │
E3 数据导出（仅 bootstrap + sample）
     ├─ ORDER BY 主键 → 确定性（两次导出 diff 应为空）
     └─ 分页流式读，逐行生成 INSERT（引号感知，不按行切分）
     │
E3.5 行级谓词过滤（第二轮新增）
     ├─ config：仅取 env_key IS NULL 的行（85 行 .env 镜像剔除，留 17 行）
     └─ 同步派生表：即便被误列入白名单，也在这一步整表剔除
     │
E4 身份匿名化（双命名空间）
     ├─ principal 命名空间 → {{principal:<ref>}}
     ├─ agent     命名空间 → {{agent:<ref>}}
     └─ 未命中清单的身份 uuid → 按 orphanPolicy（默认 fail）
     │
E4.5 脱敏（第二轮新增）
     ├─ 读 sql/seed/sanitize-policy.json（敏感列清单 + R1~R4 四条规则）
     ├─ R3 先行：值本身已是占位符（your…/changeme/xxx/TODO）→ 原样保留
     ├─ R1 凭据/口令/密钥/令牌 → {{secret:<kind>}}
     ├─ R2 环境标识（外网 URL、应用标识、时间戳）→ {{env:<kind>}} / {{ts:epoch}}
     ├─ R4 不可脱敏且不可缺值（如 db_connection.password NOT NULL）→ 整表降为 T-A
     └─ 回填 config.is_sensitive = true
     │
E5 门禁（任一不过 → 导出失败，不落盘）
     ├─ 体积/行数：超 maxFileBytes / maxRowsPerTable → 失败
     ├─ 禁用语句扫描：出现 DROP/TRUNCATE/DELETE → 失败
     ├─ 机密扫描：命中 secretScan 任一模式 → 失败
     ├─ 脱敏生效校验（新增）：敏感列值非占位符 → 失败
     ├─ 同步派生残留（新增）：白名单表内出现 source_path 非空的行 → 失败
     ├─ 悬空引用：身份列中仍含裸 uuid → 失败
     └─ FK 自洽：外键引用的表必须在同一文件内
     │
E6 落盘
     ├─ sql/uctooDB.sql            （覆盖，供安装器与开发者使用）
     ├─ sql/seed/seed-manifest.json（表清单/行数/校验和/主体清单/策略版本）
     └─ 人类可读报告（每表导了什么、为什么、被 orphanPolicy 处理了几条）
```

**E5 之后还有一道外部校验**：导出完成后在**临时库** replay 一遍，跑 `表数 == 226` + `悬空身份引用 == 0` + `超管菜单树非空` 三条断言；不过则产物作废。这是"自己验自己"之外的独立验真。

### 3.6 七条硬性质（超越业界最佳实践的部分）

| # | 性质 | 为什么它超越常见做法 |
|---|---|---|
| **1** | **白名单优先、默认拒绝** | 常见的 dump/seed 工具是"导出全部 + 手工排除几张表"（黑名单），漏一张就泄漏。SEP 反过来：没被批准的只给结构 |
| **2** | **策略即代码，且带门禁** | 策略文件进仓库、可 review；体积/行数/禁用语句/机密扫描四条门禁在导出期强制，不是靠人记得 |
| **3** | **确定性（可复现）** | `ORDER BY` 主键 + 时间戳只落文件头不落 SQL 体内 ⇒ 同一库两次导出 **diff 为空**，产物可进 git、可 code review |
| **4** | **身份匿名化前置** | 导出即产出占位符化 SQL + 主体清单，仓库里永不出现作者环境真实 uuid（隐私 + 强制显式化"哪些 uuid 是主体"） |
| **5** | **机密/隐私扫描** | 扫 bcrypt hash、JWT、私钥、手机号、邮箱；命中即失败。业界 seed 泄漏密钥的事故大多源于"没人扫过一遍" |
| **6** | **非破坏性** | 发布版基线**不含 `DROP TABLE`**（旧基线 206 条 DROP 是 Navicat 默认值，不应继承），用 `IF NOT EXISTS` + 幂等导入 |
| **7** | **派生数据不入库** | `db_info` 这类可重算的表明确排除（省 1.12 MB），改为安装后跑一次 `loaddbinfo` 生成 |

### 3.7 与 SIC（上一章）的接缝

上一章的导入五步 P0~P4 **完全不用改**，只需两点收窄：

1. **主体清单从 8 个缩到 2 个**（`super_admin`、`svc_mainagent`），删除全部 `demo_*` 与 `legacy_test1` 条目，并按 §2.3 增加 `agent` 命名空间；
2. **P4 校验的前置条件变了**：因为输入文件已从"整库 105 MB"变为"0.90 MB 白名单产物"，需要校验的身份引用从 293 处降到下表的 **392 处 / 8 组表.列**，量级可控、可逐条人工核对。

**保留集（T-B + T-C，含第二轮修订）内的身份引用实测**（这就是导入期真正要处理的全部工作量）：

```
149  permissions.creator        = admin(超管)
113  entity.creator             = admin(超管)
 47  role_has_permission.creator= admin(超管)
 33  entity.creator             = test1        ← 唯一需策略处置
 17  config.creator             = admin(超管)   ← 全部来自 env_key IS NULL 的 17 行
 16  i18.creator                = admin(超管)
  8  user_group.creator         = admin(超管)
  7  uctoo_role.creator         = admin(超管)
  2  lang.creator               = admin(超管)
─────
392 处，仅 creator 一列，仅 2 个主体
```

（第二轮修订：`db_connection` 移出 T-B ⇒ 减 1 处；`config` 加 `env_key IS NULL` 谓词后仍为 17 处——因为那 85 行 `.env` 镜像的 `creator` 本身为 **NULL**，正是"由 `ConfigSyncHandler` 自动插入、无人归属"的旁证。导入期仍需处理 `entity.creator` 的 33 行 test1 数据，默认 `map-to: super_admin`。）

---

## 四、在版本发布方案中的位置

```
[开发环境 uctoo 库，226 表]
        │  SEP 导出（§三 E0~E6，白名单 + 门禁 + 匿名化）
        ▼
sql/uctooDB.sql            （≈0.90 MB，结构 + 引导数据 + entity 示例，占位符化、无 DROP）
sql/seed/seed-manifest.json（表清单/行数/校验和/主体清单/策略版本）
        │  git 提交 → tag →  Release 介质
        ▼
[开发者环境] 安装器 DK-2/DK-4
        ├─ CREATE DATABASE uctoo（默认名，§一）
        ├─ 导入结构与非身份数据（SIC P1）
        ├─ 建两帐号 + 绑定（§2.4 A1~A6）
        ├─ 身份重绑定（SIC P2，双命名空间）
        ├─ RBAC 补种（SIC P3）
        └─ 校验（SIC P4）+ loaddbinfo 重算 db_info（§3.6-7）
```

**与现行做法的差别**：`sql/uctooDB.sql` 从"某人某天用 Navicat 从某个库手工导出"（历史遗留 `uctoov3`，落后 20 张表）变成"**由策略驱动、可复现、带门禁、可 review 的构建产物**"。

---

## 五、风险与待确认项

| # | 项 | 现状与建议 |
|---|---|---|
| **OQ-S1** | `agents` 表里的 **8 个 SUB agent**（`sdd-researcher` 等，`user_id` 为空）是否算引导数据 | 实测：它们不绑帐号（`user_id` 空），且 `skills/sdd/COMPOSITION.yaml:53` 表明 SUB agent 由 SDD 组合在运行时派生 ⇒ **建议归入 T-D（安装器不建、seed 不导），由 SDD 插件按需注册**。需确认 |
| **OQ-S2** | `component_setting`(145) / `cell`(58) / `vue_editor_*`(49) / `element_components`(6) / `model_pricing`(18) 等 9 张"低代码资产表"合计 0.126 MB | 它们是低代码/表单设计器的配置资产，不是启动必需。建议**留在 T-E（仅结构）**，但作为策略文件里预先列好的"候选白名单"注释保留，需要时一行打开。需确认 |
| **OQ-S3** | `entity` 的 33 行 test1 数据 | 默认建议 `map-to: super_admin`（示例数据归位到安装环境超管，保证 `entity` 零悬空）；备选 `drop`（只留 admin 的 113 行）。**需确认** |
| **OQ-S4** | 导出机制的实现形态 | 三选一：① 安装器子命令 `ucInstaller.exe db export`；② runtime 侧工具（`cjpm run --name …dbexport`）；③ 独立 `tools/dbexport`。**建议 ①**（复用安装器已有的 DB 连接、凭据、日志与 `--json` 报告骨架，且它是"版本发布"动作而非运行时能力）。需确认 |
| **F-1** | 外键在文件末尾统一 `ALTER TABLE ADD CONSTRAINT` | 现状导出是"先插数据后建约束"，导入期**不会**拦悬空引用（上一章已记录）。SEP 保留该形态（否则要拓扑排序），悬空问题由 E5 门禁 + SIC P4 显式扫描兜底 |
| **F-2** | `entity.creator` 在本机库已有 FK `Entity_creatorId_fkey → uctoo_user(id)`（不在导出文件内） | 一旦该约束进入基线，`entity` 的 33 行 test1 数据会直接导入失败 ⇒ OQ-S3 必须在约束落地前决策 |
| **F-3** | 多值 INSERT 含内嵌换行 | 实测 4,002 条语句非单行（含换行文本列）⇒ 任何按行或按 `);\n` 切分的实现都是错的，必须引号感知单遍扫描（与上一章 §1.4-1 同一条铁律） |

---

## 六、交接给 spec 的 REQ 建议

| 建议 REQ | 内容 |
|---|---|
| REQ-RNI-088 | 默认数据库名 `uctoo`；不存在时安装器创建 |
| REQ-RNI-089 | 初始帐号二元组：1 个人类超管 + 1 个主 agent 帐号（含 §2.4 的 A1~A6 落库与顺序） |
| REQ-RNI-090 | 不创建任何演示/测试帐号 |
| REQ-RNI-091 | 身份占位符分 `principal` / `agent` 双命名空间 |
| REQ-RNI-092 | 数据库导出机制 SEP：分层 T-A~T-E + 策略文件 + E0~E6 流水线 |
| REQ-RNI-093 | 导出门禁：体积/行数/禁用语句/机密扫描/悬空引用/FK 自洽，任一不过即失败 |
| REQ-RNI-094 | 导出确定性：同一库两次导出 diff 为空 |
| REQ-RNI-095 | 发布版基线不含 `DROP TABLE`；`db_info` 不导，改由 `loaddbinfo` 重算 |
| REQ-RNI-096 | 导出产物附 `seed-manifest.json`（表清单/行数/校验和/主体清单/策略版本） |
| REQ-RNI-097 | 导出产物在临时库 replay 并跑三条断言（表数/悬空 0/菜单非空） |

---

## 附录：本章证据索引

| 证据 | 位置 |
|---|---|
| 默认库名 `uctoo` | `.env:244`、`.env:247` |
| 新导出来源库 `uctoo` | `sql/public20261007.sql:8` `Source Catalog : uctoo` |
| 旧基线来源库 `uctoov3`（已过期） | `sql/uctooDB.sql:8` `Source Catalog : uctoov3`；206 CREATE TABLE vs 现行 226 |
| 主 agent 建号四张表 | `src/app/services/aip/AipIdentityService.cj:28-80`；`AGENTS_ROLE_ID` :21、`AGENTS_GROUP_CODE` :22 |
| 主 agent 登录与双向指针 | `src/app/services/aip/AgentAuthService.cj:39-88`（:51-55 双指针兜底、:61 userType 校验、:65-71 status 校验） |
| agent 帐号禁止密码登录 | `src/app/controllers/uctoo/uctoo_user/UctooUserAuthController.cj:112-116` |
| `db_info` 可由 information_schema 重算 | `src/app/services/uctoo/DbInfoService.cj:1026-1047` |
| 体积/行数/身份引用全部实测数字 | 脚本 `D:/UCT/tmp/analyze_public.py`、`analyze_refs2.py`、`tier_calc.py` |
