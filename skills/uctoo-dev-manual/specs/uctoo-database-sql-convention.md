# 增量 SQL 规范（新增 / 变更数据库结构必读）

## 0. 基线文件：先看 `sql/uctooDB.sql`

框架初始库完整导出文件，是**表结构与数据类型的唯一基线**：

```
apps/agentskills-runtime/sql/uctooDB.sql
  └─ Navicat dump / PostgreSQL 16 / schema public / 207 张表
```

**写任何新增表 DDL 之前，先在这个文件里找同族表当模板**：按命名前缀 grep（如 agent_、cms_、aip_、lrt_），照抄它的字段类型、默认值、索引写法和 COMMENT 风格。

反模式（一律打回）：

- 凭记忆新造类型：`int`、`bigserial`、`timestamp`（无时区）、驼峰列名、无长度 `varchar`
- 建完表才发现和既有表字段类型不一致（uuid 变 text、timestamptz 变 timestamp、jsonb 变 text），后面 ORM 映射和行级权限都得返工
- 不写 `COMMENT ON TABLE` / `COMMENT ON COLUMN`（备注还兼作 i18n 资源源，见规范第 3 条）

## 1. 字段类型速查（uctooDB.sql 实测分布）

| 目标类型 | 用途 | 基线里的常见写法 | 反例 |
|---------|------|-----------------|------|
| `uuid` | 主键、外键关联 | `"id" uuid NOT NULL DEFAULT gen_random_uuid()` | `serial` / `varchar(36)` |
| `timestamptz(6)` | created_at / updated_at / deleted_at | `NOT NULL DEFAULT CURRENT_TIMESTAMP` | `timestamp` / `datetime` |
| `varchar(n)` | 短文本、状态枚举 | `"state" varchar(20) NOT NULL DEFAULT 'todo'::character varying`；文本类 `varchar(200)`，允许空时用 `DEFAULT ''` | 无长度 `varchar` |
| `text` | 长文本、Markdown、正文 | `DEFAULT ''::text` | 拿 varchar(2000) 硬凑 |
| `jsonb` | 数组/对象字段 | `jsonb NOT NULL DEFAULT '[]'::jsonb`（对象用 `'{}'::jsonb`） | `text` 存 JSON 再自己 parse |
| `int4` | 状态、小数计数 | `int4 NOT NULL DEFAULT 0` | `int` |
| `int8` | 大计数（文件大小、累计量） | `int8 NOT NULL DEFAULT 0` | `int4` 撑不住 |
| `float8` | 金额、比率、统计值 | 直接 `float8` | `numeric` Pascal 串类型混用 |
| `bool` | 开关 | `bool NOT NULL DEFAULT false` | `int` 0/1 |

## 2. 每张表必有的标准列

规范文档 `apps/agentskills-runtime/docs/uctoo-v4/uctoo-database-design-specification.md` 第 2 条：**所有表都有 `created_at` / `updated_at` / `deleted_at` / `creator` 四列**，`creator` 关联 `uctoo_user.id`。基线实测 207 张表中 creator 217 处、created_at 214、updated_at 204、deleted_at 204。

```
"id"          uuid NOT NULL DEFAULT gen_random_uuid(),
"creator"     uuid,
"created_at"  timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
"updated_at"  timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
"deleted_at"  timestamptz(6)
```

补充约束：

- **`owner_user_id` 不是通用列**：基线里只有 12 处，属白名单表（agent_tasks / crontab / long_running_task_artifact / long_running_task_evolution）。注入前先过 `PermissionUtils.hasOwnerUserColumn`，其余表无脑加会报 `42703 列不存在`。
- **软删除**：删数据一律 `UPDATE ... SET deleted_at = NOW()`，业务表禁物理 `DELETE`。
- `deleted_at IS NULL` 是"没删"的唯一判据，索引和唯一约束都跟着这个口径走。

## 3. 命名与注释

- 小写下划线命名（规范第 1 条），避开 SQL 关键字。
- 表名带域前缀分组（agent_ / cms_ / aip_ / lrt_），新表沿用同前缀，别起孤立名字。
- `COMMENT ON TABLE` 必写（基线 200/207 表有），一句话说清表干什么；`COMMENT ON COLUMN` 必写。
- 备注兼作 i18n 源：含中文句号"。"的取句号前内容，没有句号取全部；无备注则退化用字段名。

## 4. 索引与约束

基线真实写法（dump 原貌，`COLLATE`/`ops` 是 Navicat 导出的冗余项，手写可省略）：

```sql
CREATE INDEX "idx_agents_skill_name" ON "public"."agents" USING btree (
  "name" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE UNIQUE INDEX "uk_agent_skills_source_path" ON "public"."agent_skills" USING btree (
  "source_path" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
) WHERE source_path IS NOT NULL;
```

**命名（基线实测口径，别自创新前缀）**：

| 类型 | 命名 | 基线数量 |
|------|------|---------|
| 普通索引 | `idx_<表>_<字段>` | 180 |
| 唯一索引 | `uk_<表>_<字段>` | 2（`uk_agents_source_path`、`uk_agent_skills_source_path`）|
| 唯一索引（历史遗留） | `unique_<语义>` 如 `unique_email`、`unique_groupname_per_owner` | 8 |
| 唯一索引（历史遗留） | `idx_<表>_<语义>_unique`（用 idx 前缀装唯一，反直觉，勿照抄） | 7 |
| 唯一索引（历史遗留） | `<表名>_<字段>_key`（Postgres 自动生成名） | 4 |

- **新表唯一索引优先 `uk_<表>_<字段>`**，这是基线里唯一成规的一档；`unique_`/`uq_` 都是零星做法。
- **唯一索引必须带 `WHERE <列> IS NOT NULL` 部分索引**（基线 22 个唯一索引全是这个写法）。原因是软删除只置 `deleted_at`，老行还占着唯一键，不加部分索引会导致"删了又建"报唯一冲突。基线用的是 `WHERE <列> IS NOT NULL` 而非 `deleted_at IS NULL`，新表跟随基线用列判空。
- 外键列名统一 `<目标表>_id` uuid 类型；`creator` 关联 `uctoo_user(id)`，外键约束按基线习惯可加可不加（行级权限靠 creator 列判断，不靠数据库 FK）。
- 状态枚举用 `varchar` + COMMENT 列举取值（如 `'看板状态：todo/in_progress/review/done/blocked'`），基线里不加 CHECK 约束，优先兼容性。

## 5. 增量 SQL 落盘位置

新增 / 变更一律写成增量脚本，落到：

```
apps/agentskills-runtime/sql/incremental/<YYYYMMDD>_<模块>_<动作>.sql
```

现成参照：`login_health_check_20261003.sql`、`lrt_scheme_registry_20260915.sql`、`hackathon_github_repository.sql`。

**文件头模板**（照抄现有增量脚本的写法）：

```sql
-- ============================================
-- <模块>：<做了什么>
-- 依据: <design.md 章节 / 需求号>
-- 规范: uctooDB.sql 同族表 + v4 数据库设计规范（UUID 主键 / timestamptz / creator 行级权限 / 软删除）
-- ============================================
```

**硬约束**：

| 约束 | 说明 |
|------|------|
| 幂等 | `CREATE TABLE IF NOT EXISTS` / `ADD COLUMN IF NOT EXISTS` / `CREATE INDEX IF NOT EXISTS`；加约束、改枚举这类非幂等操作用 `DO $$ BEGIN ... EXCEPTION WHEN duplicate_object THEN NULL; END $$;` |
| 禁 DROP | 除非是明确的一次性修复脚本，且文件头写清理由；禁止顺手 `DROP TABLE` 重建 |
| 不内联 uuid 字面量 | 给 uuid 列赋值时类型别写错（曾踩 `操作符不存在: uuid = text`）；授权类 `INSERT` 用单行 `SELECT ... WHERE NOT EXISTS`，`ON CONFLICT DO NOTHING` |
| RBAC 同步 | 新增表若配了新路由/菜单，同一脚本或同批脚本里登记 `permissions` + `role_has_permission`（否则 `RequirePermissionMiddleware` 一律 403） |
| 可粘可跑 | 交付的 SQL 必须能直接粘 psql 执行，不许写伪代码 / 示意片段 |

**上线前干跑**（不改任何数据）：

```bash
psql -h localhost -U <user> -d uctoo -f <增量脚本>.sql   # 看输出
# 或包一层：
# BEGIN; \i <增量脚本>.sql; ROLLBACK;
```

## 6. 新表上线五步（顺序不能乱）

```
1. 照 uctooDB.sql 同族表写 DDL
   → sql/incremental/<YYYYMMDD>_<模块>_<动作>.sql
2. 干跑验证幂等（psql BEGIN/ROLLBACK）
3. 真正执行
   → cjpm run --skip-build --name magic.app.tools.loaddbinfo --run-args "--db uctoo"
   ⚠️ 不重新 loaddbinfo，db_info 里没这张表，crudgen / crudweb / plugingen 全都读不到
   （loaddbinfo 命令行模式有未修 bug，可退 Web 端「数据库管理 → 加载数据库信息」）
4. 按工具链生成代码
   → plugingen（优先做成插件）/ crudweb（Web 管理界面）
   → crudgen 仅用于宿主 src/app/ 公共基础设施（该目录只减不增）
5. 补 permissions + role_has_permission（新增路由/菜单）+ i18n 备注翻译
```

## 7. 变更已有表

- **加列**：`ADD COLUMN IF NOT EXISTS`。可空优先；必须 `NOT NULL` 就带 `DEFAULT` 或先回填历史行。
- **加索引**：`CREATE INDEX IF NOT EXISTS`，普通索引 `idx_<表>_<字段>`、唯一索引 `uk_<表>_<字段>`，唯一索引带 `WHERE <列> IS NOT NULL` 部分索引。
- **改类型 / 删列**：先评估存量数据，禁直接 `ALTER ... TYPE` 截断（会静默丢数据）。
- **加字段到已有表的权限列**：只有白名单表才值得加 `owner_user_id`，其余加完行级权限会失效。

## 8. 交付检查清单

| # | 检查项 | 不合规典型症状 |
|---|--------|---------------|
| 1 | DDL 前 grep 过 `uctooDB.sql` 同族表 | 字段类型与既有表不一致，ORM 映射报错 |
| 2 | 四个标准列齐全（id/creator/三个时间） | 行级权限失效 / 审计缺失 |
| 3 | `COMMENT ON TABLE` + `COMMENT ON COLUMN` 齐全 | i18n 资源缺键 |
| 4 | 索引 `idx_`/`uk_` 命名，唯一索引带 `WHERE <列> IS NOT NULL` | 软删后唯一键冲突 |
| 5 | 脚本幂等、禁 DROP、可直接粘 psql 跑 | 二次执行炸库 |
| 6 | 落在 `sql/incremental/`，命名符合日期前缀 | 找不到上线脚本 |
| 7 | 新增表已 `loaddbinfo` 刷新 | crudgen 生成不出模块 |
| 8 | 新路由已登记 permissions + role_has_permission | 接口 403 |
