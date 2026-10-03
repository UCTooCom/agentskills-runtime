---
name: uctoo-dev-manual
description: UCToo 开发手册技能。需要了解 agentskills-runtime 内置开发工具（crudgen、crudweb、plugingen、loaddbinfo、pluginuninstall）用法、V4 API 规范、数据库与模块开发规范、权限体系、插件系统三轨架构、长程任务系统（D-P-H-E 分层、6 步 SOP、降级链、数据契约）、技能内置提示词机制、接入新大模型通道（必改 model_manager.cj + ModelController.cj + .env，含出站 IPv6 坑、cron 6 段铁律、接入前先验证 function calling）时使用。
---

# UCToo 开发手册技能

本技能是 agentskills-runtime 项目的开发手册，以渐进式加载方式组织文档，符合 agentskills 开放标准最佳实践。

## 渐进式加载结构

本技能采用分层渐进式加载方案，每一层都是独立文档，通过链接组织：

### 第一层：内置开发工具使用手册

| 工具 | 用途 | 详细文档链接 |
|------|------|-------------|
| `loaddbinfo` | 从数据库结构(information_schema)读取表结构信息，保存到 db_info 表 | [loaddbinfo 使用手册](./tools/loaddbinfo.md) |
| `crudgen` | 从 db_info 读表结构，生成宿主 CRUD 模块到 src/app/ | [crudgen 使用手册](./tools/crudgen.md) |
| `crudweb` | 从 db_info 读表结构，生成 Web 管理界面 CRUD 代码 | [crudweb 使用手册](./tools/crudweb.md) |
| `plugingen` | 从 db_info 读表结构，生成插件到 skills/{name}/（三轨：sync/dylib/process） | [plugingen 使用手册](./tools/plugingen.md) |
| `pluginuninstall` | 与 plugingen 对称的确定性卸载工具（三层卸载模型） | [pluginuninstall 使用手册](./tools/pluginuninstall.md) |

### 第二层：开发规范文档（V4 体系）

| 规范 | 用途 | 详细文档链接 |
|------|------|-------------|
| V4 API 规范 | RESTful API 设计规范、列表键名约定、分页/筛选/排序 | [V4 API 规范](./specs/uctoo-v4-api-specification.md) |
| 数据库设计规范 | 表结构设计、UUID 主键、timestamptz 时间戳、creator 字段行级权限 | [数据库设计规范](../../docs/uctoo-v4/uctoo-database-design-specification.md) |
| **增量 SQL 规范** | **新增/变更表结构必读**：先按 `sql/uctooDB.sql` 基线抄同族表类型，再写 `sql/incremental/` 幂等脚本；含字段类型速查、标准四列、索引命名、上线五步、交付检查清单 | [增量 SQL 规范](./specs/uctoo-database-sql-convention.md) |
| **构建环境 OpenSSL DLL 规范** | **在新机器上搭开发环境后登录 401 必读**：stdx 加载器硬编码 `libcrypto-3-x64.dll`，而 runtime bin 里只有 `libcrypto-3.dll`（少 `-x64`）→ 系统装 4.x 即失败 → `JWTUtil` 吞异常返回空 token → 401。含根因链、三档修复、排查顺序 | [构建环境 OpenSSL DLL 规范](./specs/runtime-openssl-dll-guide.md) |
| 模块开发规范 | 五层 CRUD 架构（PO/DAO/Service/Controller/Route）、@ModuleRoute 注解 | [模块开发规范](../../docs/uctoo-v4/uctoo-v4-module-development.md) |
| 权限体系规范 | 用户/角色/权限三层体系、行级权限（creator 字段）、RBAC 中间件 | [权限体系规范](../../docs/uctoo-v4/user-permission-system.md) |
| 菜单与动态路由机制 | **页面路由地址动态来自 `permissions` 表（菜单即路由）**：runtime 菜单 API、web 动态路由装配、`parent_id` 链拼完整路径、`VITE_CONTEXT` 前缀、agent 导航 URL 必须取自菜单树（不可硬编码） | [菜单与动态路由机制](./specs/menu-routing-from-permissions.md) |
| V4 架构规范 | 整体架构、中间件链、路由注册、事件总线 | [V4 架构规范](../../docs/uctoo-v4/uctoo-v4-architecture.md) |
| V4 ORM 规范 | f_orm 使用规范、SqlExecutor、QueryResultWrap | [V4 ORM 规范](../../docs/uctoo-v4/uctoo-v4-orm-specification.md) |
| V4 中间件指南 | CORS/DeserializeUser/RequirePermission/RowLevel/OperateLog 中间件链 | [V4 中间件指南](../../docs/uctoo-v4/uctoo-v4-middleware-guide.md) |
| 行级权限系统 | creator 字段行级权限、buildRowLevelCondition、admin 通配符 | [行级权限系统](../../docs/uctoo-v4/row-level-permission-system.md) |
| **接入新大模型通道 SOP** | 新增 model provider 必改的 2 个 `.cj` + `.env`（含「漏改 ModelController 导致后台看不到」、出站 IPv6 坑、cron 6 段铁律） | [接入新大模型通道](./specs/model-provider-integration.md) |

### 第三层：插件系统开发指南

| 指南 | 用途 | 详细文档链接 |
|------|------|-------------|
| **一切皆技能的插件机制**（v0.0.27+） | 三轨架构（内嵌轨/L2 动态库轨/L3 进程隔离轨）、去中心化自动发现（PluginDiscoveryService + plugin.yaml 自完备）、cordis-cj L3 集成、六大限制条件、新增插件实操 | [一切皆技能的插件机制](./specs/plugin-system-design.md) |
| 插件系统完整需求规格 | REQ-PS-001~016 需求项、演进路标、验收标准（含「一切皆技能」去中心化 REQ-PS-016、L3 进程隔离轨 REQ-PS-015） | [插件系统需求规格](../../.codeartsdoer/specs/plugin-system/spec.md) |
| 插件轻量化方案 | 三个可行优化方向（插件安装到宿主目录/插件 SDK 精简包/WASM 沙箱插件） | [插件轻量化方案](./specs/plugin-lightweight-plan.md) |
| cordis-cj 可行性报告 | cordis-cj 完整调研、对标 deepseek-harness 的仓颉实现 | [cordis-cj 可行性报告](../../docs/ref/cangjie-plugin-system-feasibility.md) |

### 第四层：仓颉编程语言指南

| 指南 | 用途 | 详细文档链接 |
|------|------|-------------|
| 仓颉语言指南 | 仓颉编程语言完整指南（语言基础、类型系统、标准库、工具链） | [仓颉语言指南](./lang/cangjie-language-guide.md) |
| 仓颉完整文档 | 仓颉语言/标准库/扩展标准库/工具链的原始文档（zip，需先解压） | [仓颉完整文档](../../../../.codeartsdoer/skills/cangjie-full-docs.zip) |
| 仓颉代码编写技能 | 仓颉代码编写四步工作流程（查阅Skills → 检索代码片段 → 编辑适配 → 写入文件） | [仓颉代码编写技能](../cangjie-coder/SKILL.md) |

## 内置开发工具总览

agentskills-runtime 提供以下确定性代码生成工具，均位于 `src/app/tools/` 或 `src/plugin/tools/`：

### 工具链工作流

```
数据库结构
    ↓cjpm run --skip-build --name magic.app.tools.loaddbinfo --run-args "--db uctoo" # 加载表结构到 db_info 表
    ↓cjpm run --skip-build --name magic.app.tools.crudgen --run-args "--db uctoo --table entity" # 生成宿主 CRUD 模块，仅在需要拓展公共基础设施时生成宿主中的模块
    ↓cjpm run --skip-build --name magic.app.tools.crudweb --run-args "--db uctoo --table entity" # 生成 Web 管理界面
    ↓cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name entity --db uctoo --tables <表1>,<表2>" # 生成插件（sync 多表），请优先以插件方式进行功能拓展
    ↓cjpm run --skip-build --name magic.plugin.tools.pluginuninstall --run-args "--name entity" # 卸载插件
```

### 工具详情

#### 1. loaddbinfo（数据库信息加载工具）

**用途**：从数据库结构(information_schema)读取表结构信息，保存到 db_info 表。

**用法**：
```bashcjpm run --skip-build --name magic.app.tools.loaddbinfo --run-args "--db <数据库名>"```

**示例**：
```bash
# 加载指定数据库的表结构信息到 db_info 表cjpm run --skip-build --name magic.app.tools.loaddbinfo --run-args "--db uctoo"```

**选项**：
- `--db <数据库名>`：指定要加载的数据库名
- `--help, -h`：显示帮助信息

**详细文档**：[loaddbinfo 使用手册](./tools/loaddbinfo.md)

#### 2. crudgen（宿主 CRUD 代码生成器）

**用途**：从 db_info 读表结构，生成宿主 CRUD 模块到 src/app/（五层架构：PO/DAO/Service/Controller/Route）。

**用法**：
```bashcjpm run --skip-build --name magic.app.tools.crudgen --run-args "--db <数据库名> --table <表名> [--all] [--output <输出目录>]"```

**示例**：
```bash
# 生成指定表的CRUD代码cjpm run --skip-build --name magic.app.tools.crudgen --run-args "--db uctoo --table entity"
# 生成数据库中所有表的CRUD代码cjpm run --skip-build --name magic.app.tools.crudgen --run-args "--db uctoo --all"```

**选项**：
- `--db <数据库名>`：指定数据库名
- `--table <表名>`：指定表名
- `--all`：生成数据库中所有表的CRUD代码
- `--output <输出目录>`：指定输出目录（默认 src/app/）
- `--help, -h`：显示帮助信息

**详细文档**：[crudgen 使用手册](./tools/crudgen.md)

#### 3. crudweb（Web CRUD 代码生成器）

**用途**：从 db_info 读表结构，生成 Web 管理界面 CRUD 代码（Vue 组件）。

**用法**：
```bashcjpm run --skip-build --name magic.app.tools.crudweb --run-args "--db <数据库名> --table <表名> [--all] [--output <输出目录>]"```

**示例**：
```bash
# 生成指定表的Web CRUD代码cjpm run --skip-build --name magic.app.tools.crudweb --run-args "--db uctoo --table entity"
# 生成数据库中所有表的Web CRUD代码cjpm run --skip-build --name magic.app.tools.crudweb --run-args "--db uctoo --all"```

**选项**：
- `--db <数据库名>`：指定数据库名
- `--table <表名>`：指定表名
- `--all`：生成数据库中所有表的Web CRUD代码
- `--output <输出目录>`：指定输出目录（默认 web/src/views/database/uctoo/）
- `--help, -h`：显示帮助信息

**详细文档**：[crudweb 使用手册](./tools/crudweb.md)

#### 4. plugingen（插件生成器）

**用途**：与 crudgen 同构的确定性插件生成工具，从 db_info 读表结构，生成插件到 skills/{name}/。**本次新增（sync 内嵌轨）：支持一次生成多表、同名插件累积追加新表、同名同表只覆盖 AutoCreateCode 保护区（保留二次开发）**，行为特性与 crudgen 的「保护区 / 多表 / 幂等追加」保持一致。

**用法**：
```bash
# 表驱动（单表）：从 db_info 读表结构，生成五层 CRUD 插件cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name <插件名> --db <数据库名> --table <表名>"
# 表驱动（多表）：逗号分隔一次生成多张表cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name <插件名> --db <数据库名> --tables <表1>,<表2>,<表3>"
# 累积追加：同名插件、不同表名，再次运行只新增这些表的 CRUD，公共产物追加新表（不覆盖旧表）cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name <插件名> --db <数据库名> --tables <新表1>,<新表2>"
# 覆盖保护区：同名插件、相同表名，再次运行只覆盖该表各层 AutoCreateCode 区域，二开保留cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name <插件名> --db <数据库名> --table <已生成表名>"
# 空白骨架：仅生成 SKILL.md + plugin.yaml + 包占位 + 插件入口cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name <插件名> --blank"
# L3 进程隔离轨：独立 cjpm executable 工程（单表，不支持多表累积）cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name <插件名> --mode process"
# L3 进程隔离轨 + 表驱动：生成完整 CRUD 进程插件cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name <插件名> --db <数据库名> --table <表名> --mode process"```

**示例**：
```bash
# 生成 sync 轨插件（默认，单表）cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name entity --db uctoo --table entity"
# 一次生成多表（同一插件聚合多张表）cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name github --db uctoo --tables repository,branch,commit,repository_file"
# 同名累积追加新表（公共产物自动合并，旧表保留）cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name github --db uctoo --tables issue,pull_request"
# 生成空白进程插件骨架cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name mytool --mode process"
# 生成完整 CRUD 进程插件（对标 codelabs）cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name codelabs --db uctoo --table codelabs --mode process"```

**选项**：
- `--name <插件名>`：插件唯一名（小写字母/数字/下划线；连字符自动转下划线）
- `--db <数据库名>`：表驱动模式：数据库名（读 db_info 表结构）
- `--table <表名>`：表驱动模式：单张表名（与 `--tables` 二选一，优先级低于 `--tables`）
- `--tables <表名列表>`：表驱动模式：逗号分隔多张表名（多表生成与累积；与 `--table` 二选一）
- `--mode <轨>`：加载轨：sync（缺省，支持多表）/ dylib / process（单表）
- `--blank`：生成空白插件骨架（跳过表结构）
- `--help, -h`：显示帮助信息

**三轨架构**：
| 轨道 | mode | 编译图归属 | 加载机制 |
|------|------|------------|----------|
| 内嵌轨 | sync | 宿主 magic 包 | build-sync 同步到 src/plugins/{name}/ |
| L2 动态库轨 | dylib | 独立 cjpm 包（动态库） | PackageInfo.load 热加载 |
| L3 进程隔离轨 | process | 不进宿主编译图（独立 cjpm executable 工程） | CordisHostManager stdio 拉起 |

**详细文档**：[plugingen 使用手册](./tools/plugingen.md)

#### 5. pluginuninstall（插件卸载工具）

**用途**：与 plugingen 对称的确定性卸载工具，实现三层卸载模型。

**用法**：
```bashcjpm run --skip-build --name magic.plugin.tools.pluginuninstall --run-args "--name <插件名> [--force]"```

**示例**：
```bash
# 卸载指定插件cjpm run --skip-build --name magic.plugin.tools.pluginuninstall --run-args "--name entity"
# 强制级联卸载（先卸载所有依赖方插件）cjpm run --skip-build --name magic.plugin.tools.pluginuninstall --run-args "--name entity --force"```

**选项**：
- `--name <插件名>`：指定要卸载的插件名
- `--force`：强制级联卸载（按依赖逆序先卸载所有依赖方插件）
- `--help, -h`：显示帮助信息

**三层卸载模型**：
1. **运行时层**：`PluginManager.deactivate(pluginName)` 停用运行时实例 → 触发 `onDeactivate` → `onUnload` → 逆序执行 PluginContext.onCleanup 清理栈
2. **静态资产层**：删除 `skills/{name}/` 源目录 → 删除 build-sync 同步产物 → 删除编译产物 → 从 `config/plugins.yaml` 移除条目 → 从 `generated_anchors.cj` 移除反射锚点
3. **数据库痕迹层**：清理 `agent_skills` 表中该插件的记录 → 清理 `permissions` 表中该插件对应的菜单节点 → 清理 `i18` 表中该插件对应的国际化键

**详细文档**：[pluginuninstall 使用手册](./tools/pluginuninstall.md)

## 开发规范文档总览

### V4 API 规范（§8.2 列表键名约定）

**列表键名 = 表名 + s（复数形式）**：
- `entity` 表 → 列表键名 `entitys`
- `codelabs` 表 → 列表键名 `codelabss`（双 s）

**V4 列表格式**：
```json
{
    "currentPage": 1,
    "totalCount": 56,
    "totalPage": 6,
    "entitys": [...]
}
```

**详细文档**：[V4 API 规范](./specs/uctoo-v4-api-specification.md)

### 数据库设计规范

**表结构约定**：
- 主键：`id` UUID 类型，`DEFAULT gen_random_uuid()`
- 时间戳：`created_at`/`updated_at`/`deleted_at` timestamptz 类型
- 行级权限：`creator` 字段（UUID 类型，关联 uctoo_user.id）
- 软删除：`deleted_at` 字段（NULL = 未删除，NOT NULL = 已软删除）

**⚠️ 新增或变更数据库结构前，先读初始库基线 `apps/agentskills-runtime/sql/uctooDB.sql`**（PostgreSQL 初始库完整导出，207 张表，是表结构与数据类型的唯一基线）。照同族表（同命名前缀）抄字段类型、默认值、索引写法与 COMMENT 风格，再写 `sql/incremental/<YYYYMMDD>_<模块>_<动作>.sql`，保持整库口径一致：

```
确定要加的表/列
    ↓先 grep sql/uctooDB.sql 同族表当模板（类型/默认值/注释/索引）
    ↓写 sql/incremental/<YYYYMMDD>_<模块>_<动作>.sql（幂等、禁 DROP、可直接粘 psql 跑）
    ↓psql 干跑验证（BEGIN; ... ROLLBACK;）
    ↓执行 → loaddbinfo 刷新 db_info（否则 crudgen/crudweb/plugingen 读不到新表）
    ↓plugingen（优先做成插件）/ crudweb（Web 界面）或 crudgen（仅宿主公共基础设施）
    ↓补 permissions + role_has_permission（新增路由必否则 403）
```

**详细文档**：[增量 SQL 规范（新增/变更表结构必读）](./specs/uctoo-database-sql-convention.md) ｜ [数据库设计规范](../../docs/uctoo-v4/uctoo-database-design-specification.md)

### 权限体系规范

**三层权限体系**：
1. 用户（uctoo_user）
2. 角色（roles）+ 用户角色关联（user_has_roles）
3. 权限（permissions）+ 角色权限关联（role_has_permissions）

**行级权限**：
- `creator` 字段控制行级访问权限
- admin 用户或 `*` 通配符权限：无行级限制
- 非 admin 用户：`(creator IS NULL OR creator = '${userId}')`

**详细文档**：[权限体系规范](../../docs/uctoo-v4/user-permission-system.md)

## 插件系统开发指南

### 三轨架构

| 轨道 | mode | 适用场景 | 加载方式 |
|------|------|----------|----------|
| 内嵌轨 | sync | 开发期增量编译 | build-sync 同步到 src/plugins/{name}/ |
| L2 动态库轨 | dylib | 预编译动态库热加载 | PackageInfo.load 热加载 |
| L3 进程隔离轨 | process | 独立可执行文件，故障隔离 | CordisHostManager stdio 拉起 |

### L3 进程隔离轨（cordis-cj 集成）

**插件形态**：独立 cjpm 工程（output-type = "executable"），入口为 `PluginRuntime.run(...)` 显式 API。

**插件依赖**：
- `ystyle::cordis_plugin`（插件侧 SDK）
- `ystyle::cordis_core`（核心库）
- `jsonvalue`（JSON 处理）
- `ystyle::jsonrpc`（JSON-RPC 协议）

**宿主侧服务代理**：
- `host.db`：数据库访问（query/count/execute）
- `host.log`：日志服务
- `host.cache`：缓存服务

**host.db 服务契约**：
| 操作 | subOp | 参数 | 返回 |
|------|-------|------|------|
| query | - | `table`, `where`, `orderBy`, `limit`, `offset`, `userId`, `permissions` | `{ "rows": [...] }` |
| count | - | `table`, `where`, `userId`, `permissions` | `{ "count": N }` |
| execute | insert/update/delete | `table`, `subOp`, `where`, `data`, `userId`, `permissions` | `{ "affected": N }` |

**`$raw:` 前缀约定**：
`jsonValueToSqlLiteral` 对 `JsonValue.String` 检查 `$raw:` 前缀，去除前缀后作为原始 SQL 片段直接输出（不加引号）：
- `"$raw:CURRENT_TIMESTAMP"` → `CURRENT_TIMESTAMP`（SQL 函数）
- `"$raw:gen_random_uuid()"` → `gen_random_uuid()`（SQL 函数）

**详细文档**：[插件系统设计文档](./specs/plugin-system-design.md)

### 插件轻量化方案

**当前问题**：插件发布包过重——编译产物需要将宿主中的大量依赖复制到插件中才能运行。

**三个可行优化方向**：
1. **方向一：插件安装到宿主目录（宿主共享依赖）**——插件安装时不将依赖复制到插件目录，而是将插件二进制复制到宿主中的合适位置运行。宿主提供共享依赖目录，所有插件共享同一份基础库。
2. **方向二：插件 SDK 精简包**——将 `cordis-cj` 拆分为 `cordis-plugin-sdk`（精简 SDK）和 `cordis-host`（完整宿主实现）。插件只依赖精简 SDK，体积大幅减小。
3. **方向三：WASM 沙箱插件（v1.1+ 增强形态）**——插件编译为 WASM 模块，宿主通过 WASM 运行时加载执行。WASM 模块天然轻量。

**推荐实施路径**：
1. **短期（v1.0）**：实施方向一（插件安装到宿主目录），最小改动达到轻量化目标
2. **中期（v1.1）**：实施方向二（插件 SDK 精简包），进一步减小插件体积
3. **长期（v1.2+）**：评估方向三（WASM 沙箱插件），实现极致轻量化

**详细文档**：[插件轻量化方案](./specs/plugin-lightweight-plan.md)

## 仓颉编程语言指南

### 仓颉代码编写工作流程

仓颉代码编写遵循四步工作流程：
1. **查阅 CangjieSkills 技能**：获取仓颉编程语言相关知识
2. **检索代码片段**：从项目已有代码中检索基本符合需求的代码
3. **编辑适配**：对检索到的代码进行二次编辑，使其完全符合项目需求
4. **写入文件**：输出编辑后的代码到项目的指定位置

### 仓颉语言关键约定

- **不支持三元运算符**：`cond ? a : b` 必须用 `if-else` 表达式替代：`let x = if (cond) { a } else { b }`
- **ArrayList 没有 append/add/push 方法**：向集合添加元素改用 `Array + 索引赋值`
- **`.size` 是属性不是方法**：使用 `arr.size` 而非 `arr.size()`
- **`Duration` 在 `std.core` 中**：不是 `std.time.Duration`
- **`JsonValue.parse(s)` 是正确的解析方法**：不是 `JsonValue.fromStr(s)`

**详细文档**：[仓颉语言指南](./lang/cangjie-language-guide.md)

### 第五层：长程任务系统开发指南（v0.0.27+）

| 指南 | 用途 | 详细文档链接 |
|------|------|-------------|
| 长程任务系统 | 组件定位与职责边界、D-P-H-E 四层架构、6 步 SOP 全流程、降级策略链（遇挫不停）、产物校验与防回退、数据契约（DATA_CONTRACT.yaml）、执行内核健壮性、人在回路决策、可观测可回溯、关键数据约束（agent_tasks 状态机 / plugin.yaml 真实字段）、AI 驱动自进化闭环 | [长程任务开发指南](./specs/long-running-task.md) |
| 长程任务完整规格 | spec.md（组件定位/领域术语/核心能力 5.1~5.18/数据约束 6.1~6.7）、design.md（实现细节与已知工程坑） | [长程任务需求规格](../../.codeartsdoer/specs/long-running-task/spec.md) |
| **主 Agent 系统提示词管理** | **禁止在 .cj 里硬编码提示词**：三级来源（AGENTS.md 正文 → agents 表 MAIN.system_prompt → config 表 MAIN_AGENT_FALLBACK_PROMPT）、`MainAgentPromptResolver` 单一入口、代码只允许装配运行时数据（技能/前端工具/菜单） | [系统提示词管理](./specs/system-prompt-management.md) |

> **本质**：长程任务是「一切皆技能」理念下的典型载体 —— 以 **L3 进程隔离轨插件**（`mode:process`）+ 技能内 `SKILL.md` + `COMPOSITION.yaml` 编排，由 AI 自主驱动从分钟级到天级任务的执行闭环。与第三层「一切皆技能的插件机制」配套阅读。

### 第六层：技能内置提示词机制（v0.0.27+）

| 指南 | 用途 | 详细文档链接 |
|------|------|-------------|
| 技能内置提示词机制 | PromptConfig 多目录扫描设计、优先级链（技能内 prompts > 全局 ./prompts > 内置默认）、profile 候选链、文件名约定（含双 .md 扩展名踩坑）、如何为技能新增定制提示词、如何验证生效 | [技能内置提示词机制](./specs/skill-prompt-mechanism.md) |

> **本质**：把硬编码在 `prompts.cj` 的压缩/摘要提示词改为「多目录可覆盖 + profile 再覆盖」，让业务/技能作者直接编辑 `skills/<name>/prompts/*.md` 即可生效，无需改代码重编译。长程任务定制的 `tool-summarize.user.long-running-task.md` 即典型用例。

## 项目结构

```
agentskills-runtime/
├── src/
│   ├── app/                    # 宿主存量模块（存量冻结，只减不增）
│   │   ├── tools/              # 内置开发工具
│   │   │   ├── crudgen/        # 宿主 CRUD 代码生成器
│   │   │   ├── crudweb/        # Web CRUD 代码生成器
│   │   │   └── loaddbinfo/     # 数据库信息加载工具
│   │   └── ...
│   ├── plugin/                 # 插件系统（框架包 magic.plugin）
│   │   ├── cordis_host_manager.cj      # L3 进程隔离轨宿主管理器
│   │   ├── cordis_host_services.cj     # 宿主侧服务代理（host.db/host.log/host.cache）
│   │   ├── external_plugin_route_gateway.cj  # L3 路由网关
│   │   ├── plugin_loader.cj            # 插件加载器
│   │   ├── plugin_registry.cj          # 插件注册表
│   │   ├── plugin_route_scanner.cj     # 插件路由扫描器
│   │   ├── plugin_sync_bridge.cj       # 插件状态库同步
│   │   └── tools/
│   │       ├── plugingen/      # 插件生成器
│   │       └── pluginuninstall/  # 插件卸载工具
│   └── ...
├── skills/                     # 插件目录（三维一体）
│   ├── codelabs/               # L3 进程隔离轨插件示例
│   ├── entity/                 # 内嵌轨插件示例
│   ├── feedback/               # 内嵌轨插件示例
│   ├── uctoo-dev-manual/       # 本技能
│   └── ...
├── libs/                       # 依赖库
│   ├── cordis-cj/              # cordis-cj 库（对标 deepseek-harness）
│   ├── fountain/               # fountain 框架库
│   └── ...
├── docs/                       # 开发文档
│   ├── uctoo-v4/               # V4 规范文档
│   ├── ref/                    # 参考文档
│   ├── standard/               # 标准文档
│   └── ...
├── sql/                        # SQL 脚本
│   ├── uctooDB.sql             # 初始库基线（207 表，新增表结构前必先对照）
│   └── incremental/            # 增量 SQL 脚本（新增/变更表结构落这里）
└── ...
```

## 使用本技能的最佳实践

1. **查找内置工具用法**：直接查看第一层"内置开发工具使用手册"表格中的链接
2. **查找开发规范**：直接查看第二层"开发规范文档（V4 体系）"表格中的链接
3. **查找插件系统开发指南**：直接查看第三层"插件系统开发指南"表格中的链接（重点看「一切皆技能的插件机制」）
4. **查找仓颉编程语言指南**：直接查看第四层"仓颉编程语言指南"表格中的链接
5. **查找长程任务系统**：直接查看第五层"长程任务系统开发指南"表格中的链接
6. **查找技能内置提示词机制**：直接查看第六层"技能内置提示词机制"表格中的链接

每个链接都是独立文档，可以单独加载，符合 agentskills 开放标准最佳实践的渐进式加载方案。
