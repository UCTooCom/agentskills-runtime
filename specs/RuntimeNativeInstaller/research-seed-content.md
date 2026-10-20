# 初始数据内容定档与脱敏机制（research-seed-content）

> 规格：`RuntimeNativeInstaller` ｜ 阶段：research（第二轮补充） ｜ 日期：2026-10-07
> 上游：`research-seed-identity.md`（身份重绑定）、`research-seed-export.md`（导出分层 SEP）
> 触发：用户提出三点质疑——① `db_connection`、`agents` 大概不需要初始数据（已有文件系统↔数据库双向同步）；② `agent_skills` 等类似；③ `config` 一部分来自 `.env` 同步、一部分是初始配置；④ **所有初始数据都必须脱敏**（像现行 `uctooDB.sql` 用 `xxx` 替换那样）。
> 方法：全部结论以**源码行号 + 数据库实测**为据，不凭印象。

---

## 零、本轮四个结论（先看结论）

| # | 结论 | 关键证据 |
|---|---|---|
| **C-1** | **新增 T-F 档「同步派生表」**：`agents`/`agent_skills`/`db_info`/`db_connection` 等由文件系统或运行时**重新生成**的数据，**一律不进初始数据**。带 `source_path` 的行更是明令禁止 | `main.cj:329-342` 启动期 `syncAll(Startup)`；`spec.md §5.1.1` upsert 匹配键 = `source_path`；实测 `agents` **9/9** 行、`agent_skills` **50/56** 行带 `source_path` |
| **C-2** | **`config` 表是双源，必须分治**：带 `env_key` 的行由 `.env` 在**每次启动**同步（且 `.env` 恒赢），**不该进 seed**；不带 `env_key` 的行才是纯初始配置，**该进 seed** | `ConfigSyncHandler.cj:38-109` `startupSync()`；`:242-244` `resolveConflict` **恒返回 envValue**；实测 102 行 = **85 带 env_key + 17 纯初始** |
| **C-3** | **发现一个现实事故隐患**：`.env` 里的明文密钥被原样写进 `config.value`，且 `is_sensitive` **全表 0 行标记**。旧基线侥幸没踩（源自 `uctoov3`，没跑过同步），但新基线要从 `uctoo` 导 ⇒ **必踩** | 实测：`GITHUB_TOKEN`=`ghp_…`(40)、`ORBITAI_API_KEY`=`sk-b…`(67)、`SOPHNET_API_KEY`(86)、`DATABASE_URL`=`post…`(51，连接串含密码)；`is_sensitive` 计数 **f=102 / t=0** |
| **C-4** | **脱敏必须从"手工替换"升级为"流水线强制"**：现行 `uctooDB.sql` 只有 **99 处 `xxx`**，且只覆盖两类（GitHub URL、`source_path` 绝对路径前缀），**没有任何值域脱敏规则** | `grep -o "xxx" sql/uctooDB.sql | wc -l` = 99；样例 `…/xxx/apps/agentskills-runtime/skills/…` |

一句话：**初始数据要"少而净"——同步能再造的不存，`.env` 会给的不存，剩下的必须脱敏后存。**

---

## 一、文件系统 ↔ 数据库双向同步：哪些表不该有初始数据

### 1.1 规格侧取证

`\.codeartsdoer/specs/filesystem-database-sync-mvp/spec.md`：

| 条款 | 原文要点 | 行号 |
|---|---|---|
| 文件系统→数据库 | "When runtime 启动时从文件加载生成 agent/subagent，the system shall 将文件数据写入数据库（**upsert 语义**）" | `:189` |
| 触发时机 | "应用启动初始化、定时扫描检测到变更、手动触发" | `:191` |
| 匹配键 | "以 **source_path** 作为首要的数据唯一标识进行 upsert 匹配" | `:192` |
| 幂等 | "upsert 匹配键为 source_path，同一 source_path 的实体在数据库中唯一" | `:206` |
| 依赖 | "agent_skill 依赖 agent（agent_skill 的 agent_id 字段引用 agent）" | `:211` |
| Agent 实体约束 | `source_path` 有同步需求的实体必填；`sync_status` / `last_sync_at` | `:514-517` |
| AgentSkill 实体约束 | 同上 + "`agent_skill` 的 `agent_id` 引用 agent，agent 必须存在" | `:521-525` |
| 验收 | "启动并从 `AGENTS.md` 加载生成主 agent → 写入 `agents` 表"；"启动并从 `.codeartsdoer/skills` 目录加载技能定义 → 写入 `agent_skills` 表" | `:546-548` |

**推论**：这两张表的内容是**文件的函数**，不是需要版本化分发的资产。往 seed 里塞它们，等于往 git 里塞构建产物。

### 1.2 源码侧取证：启动期到底跑了什么

`src/app/main.cj` 的 HTTP 构造函数尾部（`:301-342`）：

```cj
// 初始化同步管理器
let agentBasePath = getVariable("SYNC_AGENT_BASE_PATH").getOrDefault({ => "./" })
let skillBasePath = getVariable("SYNC_SKILL_BASE_PATH").getOrDefault({ => "./skills" })
SyncManager.initialize(agentBasePath, skillBasePath)                    // :305

spawn {                                                                  // :311
    let configSyncHandler = ConfigSyncHandler()
    let configSyncResult = configSyncHandler.startupSync()               // :315  ← .env → config
}

spawn {                                                                  // :329
    let result = SyncManager.instance?.syncAll(TriggerSource.Startup)    // :332  ← 文件系统 → DB
}
```

`src/app/services/sync/SyncManager.cj`：

- `:51-52` 只注册两个 handler：`"agent" → AgentSyncHandler`、`"agent_skill" → AgentSkillSyncHandler`
- `:106-135` `syncAll` 遍历 handler，先处理 deleted（软删，`:122-123`「**只对有明确 source_path 的记录生效**」），再 `syncFromFileSystem`
- `src/app/services/sync/handler/AgentSkillSyncHandler.cj:209-215` `findAgentSkillBySourcePath` 按 `source_path` 精确比对

**三条硬事实**：

1. **启动即全量同步**——seed 里预置的行，会在第一次启动时被文件系统 upsert 覆盖（若 `source_path` 命中），或被**软删/下线**（若文件不存在）。`SyncManager.cj:122-123` 明确写了软删只对有 `source_path` 的记录生效。
2. **`source_path` 是绝对路径语义**——`AgentSkillSyncHandler.cj:132-135`：`if (sourcePath.startsWith("/") || sourcePath.contains(":")) return normalizePath(sourcePath)`，即**含盘符的 Windows 绝对路径会被直接采用**。
3. 因此旧基线里那种 `xxx/apps/agentskills-runtime/skills/xxx` 的脱敏路径（见 §3.1）是**双重错误**：既不该进 seed，脱敏后又不是合法路径。

### 1.3 实测：本机 `uctoo` 库

```sql
-- agents
select count(*) FILTER (WHERE source_path IS NOT NULL and source_path<>'') as with_sp,
       count(*) FILTER (WHERE source_path IS NULL or source_path='')        as no_sp
  from agents;         -- → with_sp=9,  no_sp=0     （9 行全部带 source_path）

-- agent_skills
同口径                  -- → with_sp=50, no_sp=6

select count(*) from db_connection;  -- → 1
```

- `agents` **9/9 全部**有 `source_path` ⇒ **100% 由文件同步生成**，seed 塞进去必被覆盖或下线。
- `agent_skills` 56 行中 50 行有 `source_path`（同步生成），**6 行没有**：`custom-skills.git`、`rg_history`、`animation-review`、`ai-video-producer`、`brand-guidelines`、`skill-creator`，`sync_status` 全为 `pending` ⇒ 这是**同步尚未覆盖到的历史残留**，不是需要分发的初始数据。
- `db_connection` 仅 1 行，且 `password` 列 **NOT NULL**、存的是明文（实测 `pw_len=8`，即 `uctoo123`）⇒ 既不该进 seed，进了也必须脱敏。

### 1.4 结论：新增 **T-F 档（同步/派生数据，不导）**

对上一章 §3.2 的分层模型补一档，并调整归属：

| 表 | 原档 | **新档** | 理由 |
|---|---|---|---|
| `agents` | T-D（安装器生成） | **T-F** | 9/9 行由 `AGENTS.md` + `agents/*.md` 同步生成；主 agent 那一行仍由安装器按 §2.4 A1~A6 建立（属 T-D 的**例外**，见下） |
| `agent_skills` | T-E | **T-F** | 50/56 行由 `skills/*` 同步生成；6 行无 `source_path` 是同步残留，不分发 |
| `db_connection` | T-B | **T-F** | 1 行，含明文密码；且它描述的是**本机数据源**，跨环境无意义（安装器直接读 `.env`/连接串） |
| `db_info` | T-E | **T-F** | `loaddbinfo` 可完全重算（上一章已列 T-E，此处明确"派生"归因） |

**关于 `agents` 的例外要写清楚**：安装器确实要建一行主 agent（§2.4 的 A1~A6），但那是**运行时按源码逻辑真实建立**的，不是从 seed 导入的。所以 `agents` 同时出现在 T-D（安装器建）与 T-F（不导数据）两处——**两者不矛盾**：T-F 说的是"导出侧不导"，T-D 说的是"导入侧由程序建"。为避免混淆，策略文件里 `installer-generated` 仍保留 `agents`，但在 `sync-derived` 里也列出它，并在注释写明"`agents` 表的数据由同步机制与安装器共同决定，导出侧恒不导"。

### 1.5 旧基线里的反例（本轮要修掉的）

`sql/uctooDB.sql`（源自 `uctoov3`）：

```
agent_skills : 50 行   ← 全是从文件系统同步来的
db_connection:  0 行   ← 恰好没导（正确）
agents      :  0 行   ← 恰好没导（正确）
config      : 98 行   ← 全是纯初始配置（uctoov3 从没跑过 ConfigSyncHandler）
```

也就是说：**旧基线在 `db_connection`/`agents` 上是"碰巧对"的，在 `agent_skills` 上是错的**。本轮把它从"碰巧"变成"有规则"。

---

## 二、`config` 表：双源语义，必须分治

### 2.1 源码取证

`src/app/services/uctoo/ConfigSyncHandler.cj`：

| 行为 | 代码位置 | 事实 |
|---|---|---|
| 启动同步入口 | `:38` `startupSync()` | 读 `.env` → 逐键 upsert 到 `config` |
| 匹配键 | `:64` `executor.findConfigByEnvKey(key)` | **按 `env_key` 匹配**，不是按 `key` 或 `name` |
| 命中 → 更新 | `:66-75` | `entity.value = resolveConflict(...)`，**无条件覆盖** |
| 未命中 → 插入 | `:76-95` | 新建行，`configGroup="other"`、`configType="string"`、 **`isSensitive=false`**、`editable=true`、`displayOrder=0`、`status=1` |
| **冲突裁决** | `:242-244` `resolveConflict(envKey, envValue, dbValue) { envValue }` | **恒返回 `.env` 的值** ⇒ 每次启动 `.env` 都赢，库里的修改会被冲掉 |
| 反向双写 | `:111-162` `dualWrite` | 界面改配置 → 先写 `.env` 再写库 |
| 定时同步 | `:164-236` `scheduledSync` | 同上语义，仅记录差异项 |

调用点：`src/app/main.cj:311-326`（HTTP 构造）、`:531` 附近（HTTPS 构造，同一逻辑两份）。

### 2.2 实测：102 行的构成

```sql
select count(*) total, count(env_key) with_envkey,
       count(*) FILTER (WHERE env_key IS NULL) no_envkey,
       count(*) FILTER (WHERE is_sensitive) sensitive
  from config;
-- → total=102, with_envkey=85, no_envkey=17, sensitive=0
```

**17 行无 `env_key` 的纯初始配置**（这才是 seed 该带的）：

```
other | upload          val_len=0      other | site.name        val_len=5
other | wechat          val_len=0      other | site.API_URL     val_len=32
other | tencentcloud    val_len=0      other | site.start_at    val_len=29
other | saas            val_len=0      other | site.keywords    val_len=5
other | basic           val_len=0      other | site.description val_len=7
other | auth            val_len=0      other | site.upload      val_len=6
other | footer.icp_number  val_len=14   other | footer.copyright  val_len=35
other | footer.contact     val_len=12   other | website.appid     val_len=18
other | EnableVerifyCode   val_len=1
```

注：其中 `website.appid`(18) 与 `site.API_URL`(32) 虽不是密钥，但属于**该部署实例的外网地址/应用标识**，属于应脱敏的"环境标识"（见 §3.3 规则 R2）。

**85 行带 `env_key` 的**：其 `value` 完全由 `.env` 决定，seed 里预置它们毫无意义——**第一次启动就被覆盖**。而且更糟：若 seed 预置了值而开发者 `.env` 里没配，会出现"库里有值、`.env` 里没有"的不一致态，`scheduledSync` 也不会回头补 `.env`。

### 2.3 必须记录的现实隐患（C-3）

实测带 `env_key` 行的值形态（前缀掩码，不打印原文）：

| config_group | key | value 长度 | 前缀 |
|---|---|---|---|
| api_key | `GITHUB_TOKEN` | 40 | `ghp_` |
| api_key | `ORBITAI_API_KEY` | 67 | `sk-b` |
| api_key | `TOKENDANCE_API_KEY` | 51 | `sk-4` |
| api_key | `FIRECRAWL_API_KEY` | 35 | `fc-4` |
| api_key | `SOPHNET_API_KEY` | 86 | `G0Fw` |
| api_key | `MAAS_API_KEY` | 86 | `JWey` |
| api_key | `STEPFUN_API_KEY` | 65 | `4Z0A` |
| api_key | `GITEE_TOKEN` | 32 | `bdb6` |
| api_key | `ATOMGIT_TOKEN` | 24 | `P_jZ` |
| database | `DATABASE_URL` | 51 | `post`（连接串，含密码） |
| database | `opengauss_orm_connectionUrl` | 51 | `post`（同上） |
| api_key | `GMICLOUD_API_KEY` | 26 | `your`（**占位值**，未真实配置） |

而 `is_sensitive` 的统计是 **`f=102 / t=0`**——**一行都没标记**。

三点判断：

1. **`ConfigSyncHandler` 无过滤地同步全部 `.env` 键**（`:55` `for ((key, value) in envValues)`），密钥、URL、连接串一视同仁进库。
2. 自动插入的行 `isSensitive=false`（`:86`）⇒ **连"这是敏感值"的元数据都不生成**，界面也无从遮蔽。
3. **这不在 RuntimeNativeInstaller 的整改范围内**（改 `ConfigSyncHandler` 是另一个议题），但**直接决定了 SEP 必须内建脱敏**：只要从运行库导出基线，这些值就会进开源仓库。

另注：`.env` 里存在 `your…` 形式的**占位值**（如 `GMICLOUD_API_KEY`）——脱敏时不能一刀切置空，否则会把"这里需要一个 key"的语义也抹掉（见 §3.3 规则 R3）。

### 2.4 结论：`config` 的分治规则

| 行类别 | 判据 | 是否进 seed | 说明 |
|---|---|---|---|
| **`.env` 来源行** | `env_key IS NOT NULL` | **否**（T-D′） | 首次启动由 `ConfigSyncHandler.startupSync()` 从开发者自己的 `.env` 重建；seed 预置会被无条件覆盖 |
| **纯初始配置行** | `env_key IS NULL` | **是**（T-B） | 17 行，无 `.env` 对应项，不会启动期重建；缺了则相关模块读不到默认值 |
| **敏感标记** | 依 §3.3 规则 | **导出期回填 `is_sensitive`** | 现库 0 行标记 ⇒ seed 应补上正确标记，使界面能遮蔽 |

---

## 三、脱敏机制（Seed Sanitization）

### 3.1 现状取证：现行 `uctooDB.sql` 只做了 99 处替换

```bash
grep -o "xxx" sql/uctooDB.sql | wc -l    # → 99
```

全部样例只有两类：

```sql
-- ① GitHub 仓库地址
…, 'https://github.com/xxx/xxx.git', 'git', …

-- ② source_path 的绝对路径前缀
'xxx/apps/agentskills-runtime/skills/opentiny-next-app-integration', 'synced', '2026-09-26 10:31:25+08'
```

评价：**方向对，覆盖不够，且是手工的**。

- 只替换了"作者环境的路径前缀"与"作者私有仓库地址"这两类**环境标识**；
- **没有任何值域规则**：密钥、口令、令牌、连接串一律没管（旧基线侥幸没踩，是因为源库 `uctoov3` 根本没跑过 `ConfigSyncHandler`）；
- 靠人记得改，没有门禁 ⇒ 换个人导出就会漏。

### 3.2 敏感列清单（全库实测）

```sql
select table_name||'.'||column_name from information_schema.columns
 where table_schema='public'
   and column_name ~* 'password|secret|token|api_key|apikey|access_key|private_key|credential|passwd'
 order by table_name;
```

命中 **39 个列**，按是否可能进入初始数据分类：

| 类别 | 列 | 处置 |
|---|---|---|
| **凭据/口令** | `db_connection.password`、`ai_client.password`、`uctoo_user.password`、`wechatopen.appsecret`、`wechatopen_applet.appsecret`、`wechatopen_applet.mch_api_key` | **R1 置占位符** |
| **令牌** | `uctoo_user.access_token` / `refresh_token` / `remember_token`、`app_access_token.access_token`、`guest_users.token`、`ai_client.token`、`wechatopen.token` / `component_access_token`、`wechatopen_applet.token` / `authorizer_access_token` / `authorizer_refresh_token`、`wechatopen_miniapp_users.refresh_token` / `access_token` | **R1 置占位符**（若该表进 seed；多数属 T-E/T-D，不进） |
| **密钥** | `wechat_cloud.codesecret`、`config.value`（当 `is_sensitive` 或 `config_group ∈ {api_key, token, ssl, database}`） | **R1 置占位符** |
| **令牌时效** | `ai_client.token_overtime`、`app_access_token.token_overtime`、`wechatopen.token_overtime`、`wechatopen_applet.access_token_overtime` | **R2 归一**（时间戳归一到固定哨兵值，避免暴露运行时序） |
| **凭据元数据** | `aip_agent_credential.credential_type` / `credential_status`、`aip_agent_identity.credential_id` | **R4 逐表判定**（`credential_id` 是指针，归身份/占位符；type/status 是枚举，可留） |
| **误命中** | `*total_tokens` / `prompt_tokens` / `completion_tokens` / `tokens_used` / `avg_tokens`（LLM 用量统计） | **不脱敏**（是计量值不是凭据）⇒ 说明**正则按列名粗筛必须人工复核**，不能全自动 |

**关键教训**：列名正则会误命中（`tokens` vs `token`）。因此敏感列的判定必须是「**列名清单为主 + 正则为辅 + 人工复核留痕**」，而不是纯正则自动脱敏。

### 3.3 四条处置规则

| 规则 | 适用 | 做法 | 占位符 |
|---|---|---|---|
| **R1 置占位符** | 凭据/口令/密钥/令牌 | 值替换为 `{{secret:<column_kind>}}`，导入期由开发者补齐或运行时重建 | `{{secret:password}}`、`{{secret:api_key}}`、`{{secret:token}}` |
| **R2 归一** | 环境标识（主机、端口无关）、外网 URL、应用标识、时间戳 | 替换为固定哨兵：`{{env:host}}`、`{{env:url}}`、`{{env:appid}}`；时间戳归一到 `{{ts:epoch}}` | 保留"这里有值"的语义，抹掉"是谁的" |
| **R3 保留占位值** | 值本身已是占位符（`your…`、`changeme`、`xxx`、`TODO`） | **原样保留**，不二次替换 | — |
| **R4 拒绝导出** | 既不能脱敏又不可缺值的列（如 `db_connection.password` 是 **NOT NULL**） | 该表**整体降级为 T-A（仅结构）**，不导数据 | — |

**R4 是 R1 的兜底**：`db_connection.password` 是 `NOT NULL`（实测 `\d db_connection`）。置占位符能满足 NOT NULL，但会得到一个**连不上库的假数据源**——比没有更糟（界面上显示一个能选但连不通的连接）。所以 `db_connection` 走 R4 整体不导（与 §1.4 的 T-F 结论一致，两条路径殊途同归）。

### 3.4 与 SIC 身份占位符的关系

脱敏占位符与身份占位符是**两套正交的占位符**，必须在词法上一眼可分：

| 命名空间 | 形态 | 导入期解析 |
|---|---|---|
| 身份（principal） | `{{principal:<ref>}}` | 解析为目标环境 `uctoo_user.id` |
| 身份（agent） | `{{agent:<ref>}}` | 解析为目标环境 `agents.id` |
| **脱敏（secret）** | **`{{secret:<kind>}}`** | **不解析**——保持占位符入库，由开发者在界面/`.env` 补齐；或该表本就由运行时重建 |
| **环境（env）** | **`{{env:<kind>}}`** | **不解析**——同上；或由安装器按本机实际值写入 |

**铁律**：`{{secret:…}}` / `{{env:…}}` **绝不能在导入期被"猜值"填充**。宁可留占位符让界面显示"未配置"，也不要填一个看似合理的值——后者会造成"配过了但不对"的假象，排查成本远高于前者。

### 3.5 导出流水线门禁升级（`research-seed-export.md` §3.5 的 E5）

在 E4（身份匿名化）之后、E5（门禁）之前**插入一步 E4.5 脱敏**，并把 E5 的机密扫描从"4 个模式的粗扫"升级为"清单驱动"：

```
E4  身份匿名化（双命名空间）
     │
E4.5 脱敏（新增）
     ├─ 读 sql/seed/sanitize-policy.json（敏感列清单 + 四条规则）
     ├─ R3 先行：已是占位值的原样保留
     ├─ R1 凭据/密钥/令牌 → {{secret:<kind>}}
     ├─ R2 环境标识/时间戳 → {{env:<kind>}} / {{ts:epoch}}
     ├─ R4 整表降级 → 从 bootstrap 移除，落 T-A
     └─ 回填 is_sensitive = true（对 config 表）
     │
E5  门禁
     ├─ 体积/行数
     ├─ 禁用语句
     ├─ 机密扫描（升级：清单驱动 + 模式兜底）
     │     命中 secretScan 任一模式 → 失败
     │     命中 sanitize-policy 敏感列但值非占位符 → 失败（R1/R4 未生效的兜底）
     ├─ 悬空引用（身份列含裸 uuid → 失败）
     ├─ 同步派生残留（新增）
     │     bootstrap 表内出现 source_path 非空的行 → 失败（T-F 兜底）
     └─ FK 自洽
```

**E5 新增的"同步派生残留"门禁**是 C-1 的机器保证：即使有人手滑把 `agent_skills` 加回白名单，只要行里带 `source_path`，导出就失败。

### 3.6 `sanitize-policy.json` 形态（建议）

```json
{
  "schema": "uctoo/seed-sanitize/v1",
  "rules": {
    "R1_secret": {
      "columns": [
        "*.password", "*.passwd", "*.appsecret", "*.codesecret",
        "*.mch_api_key", "*.api_key", "*.secret_ref",
        "config.value"
      ],
      "configValuePredicate": "is_sensitive = true OR config_group IN ('api_key','token','ssl')",
      "action": "replace",
      "placeholder": "{{secret:<kind>}}"
    },
    "R2_env": {
      "columns": ["config.value"],
      "patterns": ["^https?://", "^(ghp_|sk-|fc-)", "^[0-9]{4}-[0-9]{2}-[0-9]{2}"],
      "action": "normalize",
      "placeholder": "{{env:<kind>}}"
    },
    "R3_keep_placeholder": {
      "patterns": ["^your", "^changeme", "^xxx", "^TODO", "^<"],
      "action": "keep"
    },
    "R4_drop_table": {
      "tables": ["db_connection"],
      "reason": "password NOT NULL 且描述本机数据源；置占位符产出连不通的假数据源",
      "action": "downgrade-to-structure-only"
    }
  },
  "scanPatterns": ["$2a$", "$2b$", "eyJ", "BEGIN PRIVATE KEY", "sk-", "ghp_", "fc-", "postgres://", "jdbc:"],
  "isSensitiveBackfill": { "table": "config", "column": "is_sensitive" }
}
```

---

## 四、对上一章（`research-seed-export.md`）的分层修订

| 项 | 上一章 | **本轮修订** |
|---|---|---|
| T-B 引导数据 | 10 张表：`permissions`、`i18`、`config`、`role_has_permission`、`uctoo_role`、`user_group`、`agent_executors`、`crontab_task_registry`、`lang`、`db_connection` | **9 张**：移除 `db_connection`（→ T-F）；`config` 加**行级谓词** `env_key IS NULL`（85 行 → 17 行） |
| T-D 安装器生成 | `uctoo_user`、`user_has_roles`、`user_has_group`、`agents` | 不变；**补充**：`config` 的 `env_key` 行属"运行时生成"，单列 T-D′ |
| T-E 排除 | 其余 88 张有数据表，`agent_skills`、`db_info` 在此 | **新增 T-F 档**：`agents`、`agent_skills`、`db_connection`、`db_info` 明确归 T-F（同步/派生），与 T-E（业务数据）区分开——两者的"为什么不该导"理由不同，处置也不同（T-F 是"会被再造"，T-E 是"不该分发"） |
| 体量账 | T-B 1,716 行 / 0.452 MB | **约 1,633 行 / 0.42 MB**（减 `db_connection` 1 行、`config` 85 行；`config` 那 85 行仅 0.03 MB 量级，可忽略） |
| 门禁 | 4 条（体积/破坏性/机密/悬空） | **6 条**（+同步派生残留、+脱敏未生效兜底） |
| 流水线 | E0~E6 | **E0~E6 + E4.5**（脱敏步） |

**净效果**：初始数据从"1,716 行里混着 50 行同步产物 + 85 行 `.env` 镜像 + 明文密钥"，变成"1,633 行，全部是不会被再造、且已脱敏的控制面数据"。

---

## 五、风险与待确认项（**四项已于 2026-10-07 由用户拍板关闭**）

| # | 项 | 原疑问 | **拍板结论** |
|---|---|---|---|
| ~~**OQ-C1**~~ | `config` 脱敏后会不会让某些模块起不来？17 行纯初始配置中 `website.appid`(18)、`site.API_URL`(32) 若按 R2 归一，依赖它们的模块会读到 `{{env:appid}}` | 未验证这两个 key 的消费方 | **保留原值，不归一**。用户说明：二者是 **uctoo 开发框架 v3 版本的配置项**，当前 v4 虽暂未使用，但**后续开发小程序端产品时需要用到** ⇒ 属跨环境一致的框架常量，非部署实例标识。落地为脱敏策略 `keepVerbatim` 清单（三要素：表/键/理由），新增 REQ-RNI-105 / AC-260~261；导出报告中单独成节标注"需复审" |
| ~~**OQ-C2**~~ | `ConfigSyncHandler` 的 `is_sensitive=false` 与"明文密钥进库"是**既有行为**，是否在本工程范围内整改？ | 本工程只做安装器，改 `ConfigSyncHandler` 属 runtime 侧变更 | **移交 runtime**。本工程**只做防御**（导出期脱敏 + seed 回填 `is_sensitive`），**不改** `ConfigSyncHandler`；"应支持敏感值遮蔽"作为独立议题移交 runtime |
| ~~**OQ-C3**~~ | `{{secret:…}}` 占位符入库后，界面上显示什么？会不会被当成真值用？ | 未定 | **界面统一显示"未配置"**。占位符统一 `{{ }}` 包裹；呈现层加通用识别（凡匹配占位符形态一律显示"未配置"并给补齐入口）。实现落在 web-admin 前端（跨工程），安装器侧只需保证形态统一且不解析 |
| ~~**OQ-C4**~~ | `agent_skills` 那 6 行无 `source_path` 的历史残留（`skill-creator`、`brand-guidelines` 等），是否需要在新环境补建？ | 它们的 `sync_status` 是 `pending`，说明同步机制尚未覆盖 | **确认不补建**（T-F 不导）。若确需，由开发者在自己环境跑一次同步由文件系统生成，不从 seed 导入 |

**保留清单的一条边界（写死，防后续被滥用）**：`keepVerbatim` **只对 R2 生效**，**R1（凭据/口令/密钥/令牌）不受保留清单豁免**——不允许以"历史配置项"为由把真实密钥保留下来。

---

## 六、交接给 spec 的 REQ 建议

| 建议编号 | 需求 | 对应章节 |
|---|---|---|
| REQ-RNI-098 | 同步/派生表（`agents`、`agent_skills`、`db_connection`、`db_info`）**不进初始数据**（T-F 档） | §1.4 |
| REQ-RNI-099 | 导出门禁新增「同步派生残留」：白名单表内出现 `source_path` 非空的行 → 导出失败 | §3.5 |
| REQ-RNI-100 | `config` 表按 `env_key` 分治：带 `env_key` 的行不导出（运行时由 `.env` 同步），不带 `env_key` 的行导出 | §2.4 |
| REQ-RNI-101 | 初始数据脱敏：凭据/密钥/令牌 → `{{secret:<kind>}}`；环境标识 → `{{env:<kind>}}`；占位值保留；不可脱敏的表整表降级为仅结构 | §3.3 |
| REQ-RNI-102 | 脱敏占位符**导入期不解析**（保持占位符入库），且界面层识别 `{{…}}` 为"未配置" | §3.4 |
| REQ-RNI-103 | 导出期回填 `config.is_sensitive`，使敏感项在界面可遮蔽 | §2.4 / §3.6 |
| REQ-RNI-104 | 敏感列判定采用「清单为主 + 正则为辅 + 人工复核留痕」，禁止纯正则全自动脱敏（避免 `tokens` 误伤） | §3.2 |

---

## 附录：本章证据索引

| # | 事实 | 取证方式 | 位置 |
|---|---|---|---|
| E-1 | 文件系统→DB 同步为 upsert，匹配键 `source_path`，启动时触发 | 规格原文 | `filesystem-database-sync-mvp/spec.md:189,192,206,546-548` |
| E-2 | AgentSkill 依赖 Agent，拓扑排序 | 规格原文 | 同上 `:211` |
| E-3 | 启动期 `SyncManager.initialize` + `syncAll(Startup)` | 源码 | `src/app/main.cj:305,332` |
| E-4 | 启动期 `ConfigSyncHandler.startupSync()` | 源码 | `src/app/main.cj:315`（HTTPS 分支同逻辑，`:531` 附近） |
| E-5 | 仅注册 `agent` / `agent_skill` 两个 handler | 源码 | `src/app/services/sync/SyncManager.cj:51-52` |
| E-6 | 软删只对有 `source_path` 的记录生效 | 源码 | `src/app/services/sync/SyncManager.cj:122-123` |
| E-7 | 含盘符的路径视为绝对路径直接采用 | 源码 | `src/app/services/sync/handler/AgentSkillSyncHandler.cj:132-135` |
| E-8 | `ConfigSyncHandler` 按 `env_key` upsert，冲突裁决恒取 `.env` 值 | 源码 | `ConfigSyncHandler.cj:64,66-75,242-244` |
| E-9 | 自动插入的 config 行 `isSensitive=false` | 源码 | `ConfigSyncHandler.cj:86` |
| E-10 | `config` 102 行 = 85 带 `env_key` + 17 纯初始；`is_sensitive` 全 false | 实测 SQL | 本机 `uctoo` 库 |
| E-11 | config 中存在 `ghp_`/`sk-`/`fc-` 前缀密钥与含密码的 `post…` 连接串 | 实测 SQL（前缀掩码） | 同上 |
| E-12 | `agents` 9/9 有 `source_path`；`agent_skills` 50/56 有；`db_connection` 1 行 | 实测 SQL | 同上 |
| E-13 | `db_connection.password` NOT NULL | `\d db_connection` | 同上 |
| E-14 | 全库 39 个敏感列名候选，含 `*_tokens` 误命中 | `information_schema.columns` 正则 | 同上 |
| E-15 | 旧基线仅 99 处 `xxx`，只覆盖 GitHub URL 与 `source_path` 前缀 | `grep -o "xxx" sql/uctooDB.sql \| wc -l` | `sql/uctooDB.sql` |
| E-16 | 旧基线 `agent_skills` 50 行、`db_connection` 0 行、`agents` 0 行、`config` 98 行 | `grep -c "INSERT INTO \"public\".\"<t>\""` | 同上 |
