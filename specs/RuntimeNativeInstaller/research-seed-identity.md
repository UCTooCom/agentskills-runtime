# 研究补充章：Seed 数据身份重绑定（Seed Identity Rebinding, SIR）

> feature_name = `RuntimeNativeInstaller`
> 并列章：`research.md`（发行版安装，S0~S6）、`research-devenv.md`（DevKit 与初始化 S7/S8）。
> 立项来源：用户在 gate-design 追加提出——「初始化数据库目前是导入开源项目中的 `sql/uctooDB.sql`，但其中很多数据表的 `creator` 列是我本地超管帐号的 `uctoo_user.id` 的 uuid；其他开发者建号后是新生成的 uuid，与文件里导出的超管 uuid 不一致。需要一套超越业界最佳实践的 seed 数据导入机制，把现有 `uctooDB.sql` 的初始数据正确匹配到开发者环境。」
> 本章所有数字均由本机实测脚本产出（脚本留存 `D:/UCT/tmp/analyze_seed.py`、`analyze_seed2.py`、`analyze_seed3.py`），可复现。
> 日期：2026-10-07

---

## 一、问题陈述：基线库以「整库导出」方式分发，身份引用是硬编码的

### 1.1 基线的客观事实

| 项 | 实测值 | 取证 |
|---|---|---|
| 文件 | `sql/uctooDB.sql`，**3,272,735 B**，23,750 行 | `ls -la sql/uctooDB.sql` |
| 导出工具 / 源 | Navicat Premium Dump SQL；Source Catalog = `uctoov3`（**注意：不是 `.env` 里的 `uctoo` 库**），PostgreSQL 16.8，导出时间 2026-09-26 15:26:15 | 文件头注释 1~13 行 |
| 结构 | `CREATE TABLE` **206** 张（与 `skills/uctoo-dev-manual/SKILL.md:227` 的「207 表基线」口径基本一致） | 脚本解析 |
| 数据 | **28** 张表带数据，共 **6,822** 条 `INSERT INTO "public"."x" VALUES (...)` | 脚本解析 |
| 数据量分布 | `db_info` 2913、`permissions` 2213、`i18` 1071、`entity` 146、`component_setting` 145、`config` 98、`agent_skills` 50… | 脚本解析 |
| 外键 | 29 条 `ALTER TABLE … ADD CONSTRAINT … FOREIGN KEY`，全部集中在 **21,633 行之后**（即**先插数据、后建约束**） | `grep -n "ALTER TABLE"` |

**这条顺序带来一个关键后果**：导入期**没有任何约束会拦住悬空的身份引用**——`psql -f uctooDB.sql` 会一路绿灯返回成功，而库里躺着一批指向不存在用户的 `creator`。「导入成功」与「数据可用」在这里彻底脱钩，这正是本机制要补的洞。

### 1.2 身份引用实测（逐列定位，非估计）

判定口径：列名 ∈ 身份类集合（`creator`/`owner_user_id`/`user_id`/`created_by`/`updated_by`/`updater`/`assignee_id`/`sender_id`/`operator`/`owner`…）**且**取值为 UUID 字面量。结果：

| # | 表.列 | 身份单元格数 | 涉及不同主体数 | Top 取值（次数） |
|---|---|---|---|---|
| 1 | `entity.creator` | 146 | 2 | `505cf909…` 113、`acca5836…` 33 |
| 2 | `config.creator` | 17 | 1 | `505cf909…` 17 |
| 3 | `i18.creator` | 16 | 1 | `505cf909…` 16 |
| 4 | `messages.user_id` | 16 | 6 | `505cf909…` 3、哨兵 `…0005` 3、`…0002` 3 |
| 5 | `minishop_decorate_content.creator` | 15 | 2 | `505cf909…` 14、`8ab510fa…` 1 |
| 6 | `tasks.creator` | 15 | 6 | `505cf909…` 6、哨兵 `…0006` 3 |
| 7 | `component_setting.creator` | 11 | 1 | `505cf909…` 11 |
| 8 | `company.creator` | 10 | 5 | `505cf909…` 6、哨兵 `…0003` 1 |
| 9 | `codelabs.creator` | 7 | 1 | `505cf909…` 7 |
| 10 | `messages.sender_id` | 7 | 5 | `505cf909…` 2、哨兵 `…0005` 2 |
| 11 | `messages.creator` | 7 | 5 | `505cf909…` 2、哨兵 `…0005` 2 |
| 12 | `uctoo_role.creator` | 7 | 1 | `505cf909…` 7 |
| 13 | `agent_skills.creator` | 6 | 1 | `505cf909…` 6 |
| 14 | `tasks.assignee_id` | 6 | 4 | 哨兵 `…0002` 2、`…0005` 2 |
| 15 | `permissions.creator` | 3 | 1 | `505cf909…` 3 |
| 16 | `agent_loop_tuning_configs.creator` | 2 | 1 | `8803ed58…` 2 |
| 17 | `lang.creator` | 2 | 1 | `505cf909…` 2 |
| | **合计** | **293** | **9** | |

**9 个不同主体在本机数据库中的真身**（`psql -d uctoo` 实测）：

| UUID | 次数 | 本机 `uctoo_user.username` | 性质 | 是否需重绑定 |
|---|---|---|---|---|
| `505cf909-5e0e-4dde-b215-74274d2cc548` | **215** | **`admin`（本地超级管理员，2024-06-20 建）** | 真人身分，随环境变化 | **是** → 绑到「开发者新建的超管」 |
| `acca5836-eba4-454b-9a95-a772758271f3` | 33 | `test1` | 演示/测试账号 | 是（可随超管或单建，见 §3.4） |
| `00000000-0000-0000-0000-000000000005` | 11 | `liuyang` | **哨兵演示账号**（id 本身即确定性常量） | 否 → 直接创建，id 保持哨兵值 |
| `00000000-0000-0000-0000-000000000002` | 9 | `liming` | 哨兵演示账号 | 否 → 同上 |
| `00000000-0000-0000-0000-000000000006` | 8 | `zhaoxue` | 哨兵演示账号 | 否 |
| `00000000-0000-0000-0000-000000000003` | 7 | `wangfang` | 哨兵演示账号 | 否 |
| `00000000-0000-0000-0000-000000000004` | 7 | `chenwei` | 哨兵演示账号 | 否 |
| `8803ed58-e72e-4757-9f1e-2852a940e751` | 2 | `mainagent`（`user_type` 非 human 的服务/代理账号） | 服务账号 | 是 → 确定性重建 |
| `8ab510fa-5421-4748-a6f4-1223fd97d977` | 1 | **不存在（本机即悬空）** | **孤儿引用** | 是 → 按孤儿策略处理（§3.4） |

> **用户的判断完全成立且可量化**：`admin` 一个主体占 **215/293 = 73.4%** 的身份单元格，而 `uctooDB.sql` 里 `uctoo_user` 表 **0 行**数据。

### 1.3 连带缺口：比 `creator` 错配更致命的三件事

| # | 事实 | 后果 |
|---|---|---|
| **S-G1** | `uctooDB.sql` 中 `uctoo_user` **0 行** INSERT | 新环境导入后**没有任何账号**。安装流程随后 `create-admin` 建一个**新 uuid** 的超管，于是 215 处 `creator` 指向一个不存在的用户——「我的数据是谁的」失去答案 |
| **S-G2** | `role_has_permission` **0 行** INSERT；但本机库中超管角色 `2338cf7b-82b7-4cf6-b1ae-6a3ca79d683d` 持有通配权限行 `permission_name = '*'`（本机 `role_has_permission` 共 48 行） | 新环境**超管角色没有任何授权**。按既有 RBAC 语义（`PermissionUtils` 两层校验、超管持 `*` 才天然放行），表现为**侧边栏菜单空 / 到处 403**，而安装器却报告"数据库导入成功" |
| **S-G3** | `user_has_roles` **0 行** INSERT（本机 14 行） | 新建的超管**与超管角色无绑定**，即便 S-G2 补上 `*` 也拿不到权限。**必须**由 seed 机制补 `user_has_roles(<新超管>, <超管角色>)` |
| **S-G4** | `entity.creator` 在本机库中已有 FK `Entity_creatorId_fkey → uctoo_user(id) ON DELETE CASCADE`（该约束**不在** `uctooDB.sql` 的 29 条 FK 里，属增量脚本后加） | 一旦该 FK 存在，向空 `uctoo_user` 导入 146 行 `entity` 会**直接违反外键而失败**。今天的"导入成功"只是因为约束还没建上——这是**定时炸弹**，不是可以忽略的边界情况 |

### 1.4 实现侧的硬事实（直接决定怎么做，不能有朴素实现）

1. **474 条 INSERT 语句的文本列内含换行**：实测脚本以引号感知方式切分后，含 `\n` 的语句有 474 条。**禁止**按行读取或按 `);\n` 朴素切分——会把含换行的文本值撕成两半，产出语法错误或被静默跳过。必须做**引号（含 `''` 转义）感知的词法扫描**。
2. **不是所有 UUID 都是身份引用**：`permissions.parent_id` 出现 2,190 处 UUID，`db_info.id` 2,913 处、`permissions.id` 2,213 处、`i18.lang_id` 1,071 处——这些都是**自身主键/结构引用**，绝不能被误当身份重绑定。判定必须走「列名类 + 主体清单命中」的**双条件**，不能走「值长得像 uuid」的单条件。
3. **`permissions` 自引用是完整的**：2,213 行、28 个不同 `parent_id`，根哨兵 `386b8b46-de88-4caf-b6e3-11f747c85cc0` **存在**于本批数据内，缺失父引用 **0**。对照组说明：只要分清「身份引用」与「结构引用」，重绑定的改动面是可控的（293 个单元格 / 28 张表）。
4. **列类型不一致**：身份列既有 `uuid`（如 `entity.creator`）也有 `varchar(36)`（如 `agent_approvals.creator`）。校验 SQL 必须做 `::text` 归一比对，否则类型不匹配会报错或漏判。

---

## 二、业界做法对标：为什么现有方案都不够

| 方案 | 做法 | 解决「跨环境身份」吗 | 缺陷 |
|---|---|---|---|
| **Rails `db/seeds.rb`** | 手写 Ruby，常用 `User.first` / `User.find_by!(email:)` 拿 id 再塞进业务数据 | 半解决 | 依赖"用户已存在"的隐式假设；跨环境 id 不同时靠代码现场查，一旦 seed 数据是**导出的 SQL 文件**（本项目的形态）就完全用不上 |
| **Laravel seeder + factory** | `User::factory()->create()` 生成随机 id，业务数据现场关联 | **不解决** | 工厂生成的 id 每次都变，导出的 SQL 里那些写死的历史数据**关联不到任何用户**——正是本项目的问题 |
| **Django fixture（`dumpdata --natural-keys` / `loaddata`）** | 用自然键（如 `username`）代替主键序列化 | **最接近正解** | ① 仅覆盖**外键列**，覆盖不到 `creator` 这类"语义外键但无约束"的列；② 要求模型层显式支持 `natural_key()`，对 206 张既有表是侵入式改造；③ **没有导出侧匿名化**——导出的仍是真实 id；④ 没有导入后的"零悬空"校验门禁 |
| **EF Core `HasData` / Alembic 数据迁移** | 迁移里硬编码主键常量 | **不解决** | 把某个环境的主键写死进代码，跨环境即错配，与本项目现状是同一类错误 |
| **Supabase / Postgres 生态通用 `seed.sql`** | 纯 SQL，`ON CONFLICT DO NOTHING` 保幂等 | **不解决** | 只解决"能不能重复插"，不解决"插进去归谁" |
| **WordPress 导入器（WXR）** | 导入时提供「作者映射」步骤，把源站作者映射到本站用户 | 部分解决 | 是**人工交互**步骤，无清单、无校验、无报告、不可在无人值守安装中使用 |

**结论**：业界的主流要么**硬编码 id**（跨环境错配），要么**新建随机 id**（seed 内历史引用失效）。唯一方向正确的是 Django 的 natural key，但它在覆盖面（只管 FK）、侵入性（要改模型）、隐私（导出仍带真实 id）、可验收（无校验门禁）四处都不够。本机制要在**不改动 206 张既有表结构**（SDD 铁律 9）、**不侵入模型层**的前提下，把这四件事一次做到。

---

## 三、建议方案：Seed Identity Contract（SIC，种子身份契约）

一句话：**把 seed 里"是谁"这件事，从写死的 UUID 换成具名主体引用；导出时匿名化，导入时按清单解析成本环境的真实 UUID，并对解析不到的引用零容忍。**

### 3.1 三段式（导出 → 分发 → 导入）

```
[作者环境]  uctooDB.sql（真实 uuid）
                │  SIC-1 匿名化：identity.manifest.json 命中的 uuid → {{principal:<ref>}}
                ▼
[开源仓库]  sql/uctooDB.sql（占位符化，不含任何作者环境真实标识；体积已由 SEP 收敛到 ≈0.90 MB）
            sql/seed/identity.manifest.json（主体清单）
            sql/seed/rebind.rules.json（重绑定规则，可由基线自动推导 + 人工覆盖）
                │  SIC-2 解析：{{principal:<ref>}} → 本环境真实 uuid（字符串级重写，零 UPDATE）
                │  SIC-3 校验：全库身份列悬空引用必须为 0
                ▼
[开发者环境] 数据归属正确、可直接登录看到菜单的库
```

**为什么"匿名化"不是多余动作**：① 仓库里不再出现作者环境的真实用户 id（隐私与合规）；② 强制把"哪些 uuid 是主体"这件事显式化——一旦有人往 seed 里塞了新 uuid 而没在清单里声明，匿名化阶段就会被报出来，而不是等到别的开发者装上才发现数据错配；③ 让"作者环境的库"与"开发者环境的库"在结构上对齐，diff 才可读。

### 3.2 主体清单 `identity.manifest.json`（形态示例）

```json
{
  "schema": "uctoo/seed-identity/v1",
  "namespaces": {
    "principal": { "table": "uctoo_user", "note": "人类/服务账号主键。agent 账号也在这个命名空间里，只是 user_type='agent'" },
    "agent":     { "table": "agents",     "note": "智能体实体主键。指向它的列是 agent_id，不是 user_id" }
  },
  "principals": [
    { "ref": "super_admin",  "ns": "principal", "kind": "super_admin", "source": "runtime-created",
      "note": "复用安装流程 create-admin 落库的真实 id；不得另行创建第二个超管" },
    { "ref": "svc_mainagent","ns": "principal", "kind": "service", "username": "mainagent",
      "userType": "agent", "passwordPolicy": "unloginable-random",
      "note": "主 agent 账号。user_type='agent'，不支持密码登录，只能走 agentAutoLogin" },
    { "ref": "main",         "ns": "agent", "kind": "main_agent", "name": "MainAgent",
      "agentType": "MAIN", "status": 1,
      "note": "主 agent 实体。与 svc_mainagent 双向指针：uctoo_user.agent_id = agents.id" }
  ],
  "orphans": [],
  "defaultOrphanPolicy": "fail"
}
```

要点（**2026-10-07 用户裁定后收窄，与 `research-seed-export.md` §2 同口径**）：

- **主体从 8 个缩到 3 个引用（2 个真人/服务账号 + 1 个 agent 实体）**：用户明确"只创建一个超管帐号和一个主 agent 的帐号，**不创建任何演示帐号**"。原先清单里的 5 个哨兵演示号（`demo_liming`…`demo_zhaoxue`）与 `legacy_test1` **全部删除**。理由不是"它们没用"，而是：演示账号的口令要生成、要展示、要维护，而它们的唯一价值是"装完有个能看的数据"——这个价值由 `entity` 示例数据承担更干净（见下）。
- **`agent` 命名空间是新增的，且不可省略**：`uctoo_user.id`（`8803ed58…`）与 `agents.id`（`4dfc6252…`）是两个不同主键，实测引用量分别是 351 与 5078。**`agent_id` 列指向 `agents.id`，不是 `uctoo_user.id`**——搞反会静默写入错的 uuid，导入期不报错、运行期才炸。
- **`super_admin` 的 `source: runtime-created`**：它不接受清单里的 `fixedUuid`，而是**绑定安装流程 `create-admin` 已落库的那一行**（与既有 REQ「只做真路径、真实落库」一致），杜绝"清单里再建一个超管"的双账号事故。
- **孤儿必须显式声明**：清单里没有声明、seed 里却出现的身份引用 → 走 `defaultOrphanPolicy`，默认 `fail`。经 SEP 分层收敛后，保留集内只剩 **393 处引用 / 9 组表.列 / 2 个主体**（见 `research-seed-export.md` §3.7），可逐条人工核对。

### 3.3 导入五步（P0~P4）

```
P0 解析主体标识
   ├─ super_admin  ← create-admin 已落库行的 id（必存在；不存在则先建，与 §5.8 真路径同源）
   └─ 其余主体     ← 按 username 幂等建立（已存在则回读 id，绝不 UPDATE 既有行）
       口令：随机生成 + bcrypt cost 10 + 前缀归一 $2a$（R-21 同口径），报告中一次性展示
P1 结构与非身份数据导入
   └─ 引号感知词法扫描，流式重写到 .tmp（禁按行/按 ");\n" 切分，见 §1.4-1）
P2 身份重绑定（字符串级，零 UPDATE）
   └─ {{principal:<ref>}} → '<uuid>'（含引号，与原字面量形态一致）
      只接受清单已声明的 ref；未命中保持原样并计入 orphan 计数
P3 RBAC 补种（幂等 INSERT，禁 DROP/禁 UPDATE）
   ├─ role_has_permission(超管角色, '*')                 ← 补 S-G2
   └─ user_has_roles(<新超管 id>, <超管角色 id>)         ← 补 S-G3
P4 校验（不通过即判定导入失败）
   ├─ 悬空引用扫描：每个身份列 count(*) where c is not null and c::text not in (select id::text from uctoo_user)
   ├─ 行数对账：导入行数 == 源语句数（被策略处理者单独列出）
   └─ RBAC 断言：超管可解析出菜单树（非空）
```

**为什么是"字符串级替换"而不是"导入后 UPDATE"**：① 一次扫描完成，不产生 293 次 UPDATE 与额外的事务日志；② 可 `--dry-run` 只产出重写后的 SQL 供人工审阅；③ 重写产物可缓存复用；④ 失败时库里不留半截数据（P1 失败即回滚，不存在"插进去了但没重绑定"的中间态——这正是业界 `seed.sql + 事后修数据`的典型事故）。

### 3.4 孤儿策略矩阵

| 策略 | 行为 | 适用 | 是否需出现在报告 |
|---|---|---|---|
| `fail`（默认） | 导入失败，列出每一处 `表.列 = uuid` | 清单未声明的新引用 | 是（失败原因） |
| `map-to` | 映射到指定主体，逐条列出 | 清单显式声明的历史悬空引用（如 `8ab510fa…`） | 是（逐条） |
| `nullify` | 置 NULL（仅当列可空） | 演示数据、可接受"无归属"的列 | 是（逐条） |
| `create-user` | 为该 uuid 建一个占位账号 | 需要保留原 id 形态的场景 | 是（逐条 + 口令处置说明） |

铁律：**无论哪种策略，都必须在报告里逐条可见，绝不静默。** `fail` 是默认，其余三种只有被清单或命令行显式指定才生效。

### 3.5 与既有流程的接缝

| 接缝点 | 现状 | 改为 |
|---|---|---|
| `research-devenv.md` I2「导入数据库基线」 | `psql -f sql/uctooDB.sql` | `ucInstaller.exe seed apply`（内部完成 P0~P4），`psql -f` 退化为 P1 的内部实现细节 |
| DK-4 组件自检判据 | 表数 ≈ 207 | 表数 ≈ 207 **且** `seed verify` 悬空引用 = 0 **且** 超管菜单树非空 |
| `create-admin`（§5.8 真路径） | 建超管后即返回 | 建超管后把 `user.id` 交给 seed 机制作为 `super_admin` 的解析来源（顺序：**先建号，后导 seed**） |
| SDD 铁律 9（不新建表/列） | — | **遵守**：身份映射以**文件**（manifest / 报告）形式存在，不落库、不新建表或列 |

---

## 四、风险与需人工确认项

| # | 风险 / 缺口 | 已查证事实 | 建议与需确认点 |
|---|---|---|---|
| **S-R1** | **上游仓库的 `uctooDB.sql` 与本机文件是否同源** | 本机文件头 Source Catalog = `uctoov3`，而 `.env` 连的是 `uctoo`；本机 `permissions` 442 行 vs 文件内 2,213 行 | 请确认：以哪个为准？建议**以随仓库分发的文件为唯一基线**，并在首次匿名化时把两次产出的 manifest 差异列为人工复核项 |
| **S-R2** | 演示账号（liming/wangfang/chenwei/liuyang/zhaoxue + test1 + mainagent）是否默认创建 | seed 中它们被 56 处引用；不建则这些引用必然悬空 | 建议：**默认创建**（随机初始口令 + 报告中展示 + 标记为演示账号）；请确认是否接受"开发者环境自带演示账号" |
| **S-R3** | 匿名化后是否保留原 `uctooDB.sql` | 保留则仓库同时存在两份 3 MB+ SQL，易混淆 | 建议：**保留一份**——仓库只发占位符化的 `uctooDB.seed.sql`；原文件留在作者本地不入库。请确认 |
| **S-R4** | `8ab510fa…` 孤儿的处理策略 | 本机即为悬空（`uctoo_user` 无此行），出现在 `minishop_decorate_content.creator` 1 处 | 建议：`map-to: super_admin` 并显式记录。请确认 |
| **S-R5** | `entity.creator` 的 FK 定时炸弹（S-G4） | FK `Entity_creatorId_fkey` 存在于本机库、不在基线文件内 | 由于 P0 先建主体、P2 先重绑定后落库，**该 FK 存在时也能导入成功**；但仍建议把「导入前已存在的 FK 全部列出」写入报告，便于排障 |
| **S-R6** | 增量脚本 `sql/incremental/*.sql`（53 个）中是否也含身份引用 | 已抽查：`20260921_*_permission.sql` 等含 `role_has_permission` 写入，但**未见硬编码用户 uuid** | 建议：对 53 个增量脚本跑一次同样的身份扫描，结果并入报告（本期先扫描、不改脚本） |

---

## 五、交接给 spec 的 REQ 建议

| 编号 | REQ 建议 | 验收要点（可测） |
|---|---|---|
| **REQ-S1** | 随仓库分发的种子数据中，身份列一律以具名主体占位符表示，不得出现来源环境的真实账号标识 | grep 种子文件，命中率 = 0 处真实 `505cf909…` 等作者环境 uuid |
| **REQ-S2** | 提供主体清单，声明每个主体的引用名、种类、登录名与标识来源；未声明的主体不得出现在种子中 | 清单解析失败/缺项即报错；种子中出现未声明引用即按孤儿策略处理 |
| **REQ-S3** | 导入时先把占位符解析为本环境真实主体标识再落库 | 导入后每个身份列的悬空引用数 = 0 |
| **REQ-S4** | 超管主体复用安装流程已创建的真实账号，不得另建第二个超管 | `uctoo_user` 中 `username` 唯一约束下超管仅 1 行；seed 报告 `superAdminSource = create-admin` |
| **REQ-S5** | 孤儿引用按策略处理并逐条可见，默认策略为导入失败 | 构造 1 处未声明引用 → 默认策略下退出码非 0 且报告列出 `表.列=uuid` |
| **REQ-S6** | 导入后必须做零悬空校验，不通过即判定导入失败 | 人为置入悬空行 → `seed verify` 退出码非 0 |
| **REQ-S7** | 补种权限骨架：超管角色持通配权限行、新超管与超管角色建立绑定 | 新环境导入后，以超管身份可取得非空菜单树 |
| **REQ-S8** | 随机生成演示/服务账号初始口令并在报告中一次性展示，禁止硬编码 | 报告中口令字段非空；代码库中不存在口令字面量常量 |
| **REQ-S9** | 幂等：重入不产生重复主体与重复业务行 | 连续执行两次，主体数与业务行数不变，第二次报告 `action: reuse` |
| **REQ-S10** | 全程不新建数据库表或列（身份映射以文件承载） | 执行前后 `information_schema.columns` 无新增 |
| **REQ-S11** | 导入失败不留半截数据 | 人为让 P2 失败 → 库中无本轮写入的身份未解析数据 |
| **REQ-S12** | 解析必须做引号感知的词法扫描，禁止按行或按语句分隔符朴素切分 | 含内嵌换行的 474 条语句导入后文本列内容与源一致（抽样比对） |

---

## 附录：本补充章的证据索引

| 证据 | 位置 / 命令 | 用途 |
|---|---|---|
| 基线文件事实 | `sql/uctooDB.sql`（3,272,735 B / 23,750 行）；文件头 Navicat 导出注释（Source Catalog `uctoov3`，2026-09-26 15:26:15） | §1.1 |
| 结构与数据计数 | 解析脚本 `D:/UCT/tmp/analyze_seed.py`：206 张 `CREATE TABLE`、28 表带数据、6,822 条 INSERT | §1.1 |
| 身份列逐列明细（293 单元格 / 18 组 / 9 主体） | 同上脚本输出（列名类 + UUID 字面量双条件判定） | §1.2 |
| 主体真身 | `psql -d uctoo -c "select id,username from uctoo_user where id in (…)"`：`505cf909…=admin`、`acca5836…=test1`、`8803ed58…=mainagent`、哨兵 `…0002~0006 = liming/wangfang/chenwei/liuyang/zhaoxue`、`8ab510fa…` 不存在 | §1.2 |
| `uctoo_user`/`user_has_roles`/`role_has_permission` 零行 | 解析脚本输出（`rows in dump = 0`）；本机库 `role_has_permission` 48 行含超管 `*` 行、`user_has_roles` 14 行 | §1.3 S-G1/S-G2/S-G3 |
| 超管角色 id | `2338cf7b-82b7-4cf6-b1ae-6a3ca79d683d`（`uctoo_role` 表，seed 内含该行） | §3.3 P3 |
| FK 定时炸弹 | `psql -d uctoo -c "\d uctoo_user"` → `Entity_creatorId_fkey → uctoo_user(id) ON DELETE CASCADE`；该约束不在 `uctooDB.sql` 的 29 条 FK 内 | §1.3 S-G4 |
| 内嵌换行 474 条 | 解析脚本 `D:/UCT/tmp/analyze_seed3.py`（引号感知切分后统计含 `\n` 的语句） | §1.4-1 |
| 结构引用对照 | `permissions.parent_id` 2,190 处、根哨兵 `386b8b46…` 存在、缺失父引用 0 | §1.4-2/3 |
| 业界对标 | Rails `db/seeds.rb`、Laravel seeders+factories、Django `--natural-keys`、EF Core `HasData`、Supabase `seed.sql`、WordPress WXR 作者映射 | §二 |
| 铁律约束 | SDD 铁律 9（不新建表/列）；R-21（bcrypt `$2a$` 归一在仓颉侧、不动 vendored 库） | §3.5 |
| 主方案（不改） | `specs/RuntimeNativeInstaller/research.md`、`research-devenv.md` | 前置结论来源 |
