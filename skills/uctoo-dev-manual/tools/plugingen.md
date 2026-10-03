# plugingen 使用手册

## 概述

`plugingen` 是 agentskills-runtime 的插件生成器，与 `crudgen` 同构的确定性插件生成工具，从 `db_info` 读表结构，生成插件到 `skills/{name}/`。

**本次新增能力（sync 内嵌轨）**：支持「一次生成多张表」「同名插件分多次累积追加新表」「同名同表只覆盖 `AutoCreateCode` 保护区（保留二次开发）」三项特性，行为特性与 `crudgen` 的「保护区 / 多表 / 幂等追加」保持一致。

**源码位置**：`src/plugin/tools/plugingen/plugingen.cj`、`src/plugin/tools/plugingen/PluginGenerator.cj`、`src/plugin/tools/plugingen/CrudPluginGenerator.cj`

## 用法

`plugingen` 是宿主工程内的 cjpm 可运行包（包名 `magic.plugin.tools.plugingen`），
**不能作为独立可执行文件直接调用**，必须通过 `cjpm run --skip-build --name <完整包名> --run-args "<参数>"` 运行
（与 loaddbinfo / crudgen / crudweb 的调用方式一致，见 `docs/uctoo-v4/uctoo-v4-module-development.md` 第 8 节）。

```bash
# 表驱动（单表）：从 db_info 读表结构，生成五层 CRUD 插件
cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name <插件名> --db <数据库名> --table <表名>"

# 表驱动（多表）：一次生成多张表，逗号分隔
cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name <插件名> --db <数据库名> --tables <表1>,<表2>,<表3>"

# 累积追加：同名插件、不同表名，再次运行只新增这些表的 CRUD，公共产物追加新表（不覆盖旧表）
cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name <插件名> --db <数据库名> --tables <新表1>,<新表2>"

# 覆盖保护区：同名插件、相同表名，再次运行只覆盖该表各层 AutoCreateCode 区域，二开保留
cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name <插件名> --db <数据库名> --table <已生成表名>"

# 空白骨架：仅生成 SKILL.md + plugin.yaml + 包占位 + 插件入口
cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name <插件名> --blank"

# L3 进程隔离轨（单表，不支持多表累积，见下文说明）
cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name <插件名> --mode process"

# L3 进程隔离轨 + 表驱动：生成完整 CRUD 进程插件（对标 codelabs，单表）
cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name <插件名> --db <数据库名> --table <表名> --mode process"
```

## 选项

| 选项 | 说明 |
|------|------|
| `--name <插件名>` | 插件唯一名（小写字母/数字/下划线；连字符自动转下划线） |
| `--db <数据库名>` | 表驱动模式：数据库名（读 db_info 表结构） |
| `--table <表名>` | 表驱动模式：单张表名（与 `--tables` 二选一，优先级低于 `--tables`） |
| `--tables <表名列表>` | 表驱动模式：逗号分隔的多张表名（多表生成与累积；与 `--table` 二者至少其一，优先级高于 `--table`） |
| `--mode <轨>` | 加载轨：sync（缺省）/ dylib / process |
| `--blank` | 生成空白插件骨架（跳过表结构） |
| `--contract` / `--contract-only` | 数据契约骨架（§14.1）；同样接受 `--table` / `--tables` 多表 |
| `--help, -h` | 显示帮助信息 |

> 参数解析：`resolveTableList(tableName, tablesRaw)` 在同时给定 `--tables` 与 `--table` 时以 `--tables` 为准；仅给定 `--table` 时退化为单表列表。表驱动模式要求 `--db` 与「`--table` 或 `--tables`」同时具备，否则报错引导使用 `--blank`。

## 示例

```bash
# 生成 sync 轨插件（默认，单表）
cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name entity --db uctoo --table entity"

# 一次生成多表（同一插件聚合多张表）
cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name github --db uctoo --tables repository,branch,commit,repository_file"

# 同名插件累积追加新表（公共产物自动合并，旧表信息保留）
cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name github --db uctoo --tables issue,pull_request"

# 同名同表重生成（仅刷新 AutoCreateCode 保护区，二开与公共产物表清单不变）
cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name github --db uctoo --table repository"

# 生成空白进程插件骨架
cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name mytool --mode process"

# 生成完整 CRUD 进程插件（对标 codelabs，单表）
cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name codelabs --db uctoo --table codelabs --mode process"
```

## 三轨架构

| 轨道 | mode | 编译图归属 | 加载机制 | 适用场景 |
|------|------|------------|----------|----------|
| 内嵌轨 | sync | 宿主 magic 包 | build-sync 同步到 `src/plugins/{name}/` | 开发期增量编译（**支持多表累积**） |
| L2 动态库轨 | dylib | 独立 cjpm 包（动态库） | `PackageInfo.load` 热加载 | 预编译动态库 |
| L3 进程隔离轨 | process | 不进宿主编译图（独立 cjpm executable 工程） | `CordisHostManager` stdio 拉起 | 故障隔离、第三方发布（**单表**） |

> **范围说明**：本次新增的「多表一次生成 / 同名追加 / 同名同表保护区覆盖」三项能力**仅作用于 sync 内嵌轨**。`--mode process`（经 `CrudPluginGenerator`）仍按单表生成，不累积；多表需求请走 sync 轨。

## 多表生成与累积能力（新增核心）

### 三个行为特性

1. **一次生成多表**：`--tables a,b,c` 一次生成 a/b/c 三张表的五层 CRUD 产物；公共产物（聚合入口/路由、`plugin.yaml`、`SKILL.md`、`cjpm.toml`、workspace member、`plugins.yaml` 条目、权限节点）正确生成并衔接。
2. **同名 + 不同表追加**：再次生成传入相同插件名、不同表名时，新表 CRUD 产物正常生成；公共产物基于「历史表清单 + 本次请求表」去重保序合并后整体重渲——旧表信息与二开保留、新表加入、表名不重复。
3. **同名 + 相同表只覆盖保护区**：再次生成传入相同插件名、相同表名时，只覆盖该表各层（`PO/DAO/Service/Controller/Route`）`//#region AutoCreateCode ... //#endregion AutoCreateCode` 区间内的自动生成内容，区间外的二次开发保留；公共产物中的表清单不变（不含重复项）。

### 实现机制

- **表清单还原**：`PluginGenerator.readExistingTables` 解析聚合路由文件 `src/{PascalName}Route.cj` 中以 `// table: <表名>` 标记的注释行，还原该插件已生成的全部历史表清单（避免对表名做逆 PascalCase 推导带来的歧义）。
- **去重保序合并**：`mergeTableList(existing, requested)` 保持历史表顺序在前、本次新表追加在后，整体去重。
- **保护区机制**：`writeRendered` → `TemplateEngine.updateFile` 仅替换 `AutoCreateCode` 区间内容，文件头尾（含手动接线代码）原样保留；每张 per-table 模板与聚合模板均带该保护区。
- **聚合入口 / 路由**：宿主 `PluginHostManager.loadSingle` 每插件条目仅反射实例化单一 `entry.className`、仅登记单一 `routeClass`（`PluginRouteScanner.scanAndRegister` 只遍历 `routeClassNames()`）。因此同名多表插件**必须**产出「聚合入口 Plugin + 聚合路由 Route」（name-based，循环装配/注册所有表的 PO/Service/Controller/Route）。公共产物 `plugins.yaml` 条目在重名时整体替换为聚合类（保留原 `order`），不会新增重复条目。

### 与 crudgen 的一致性

本次改造对齐 `src/app/tools/crudgen` 已有的「保护区 + 多表 + 幂等追加」行为：公共产物（如 `AutoRouteConfig.cj`、权限节点）逐表幂等追加；各层二次开发通过 `AutoCreateCode` 区域隔离，重新生成不丢失。plugingen 的 `plugin.yaml` / `SKILL.md` / 聚合入口 / 聚合路由等价于 crudgen 的聚合注册器角色。

## 生成产物（sync 内嵌轨，支持多表）

生成目录：`skills/{name}/`

| 文件 | 职责 |
|------|------|
| `src/pkg.cj` | 包声明 `package skill_{name}` |
| `src/{PascalName}Plugin.cj` | 聚合入口 Plugin（`@PluginAnnotation`，onLoad 循环装配所有表 Service 并接线 Controller，带 AutoCreateCode 保护区） |
| `src/{PascalName}Route.cj` | 聚合路由 Route（`@ModuleRouteAnnotation`，register 循环注册所有表路由；含 `// table:` 标记行，带 AutoCreateCode 保护区） |
| `src/{TableName}PO.cj` | 逐表 Model 层（含 AutoCreateCode 保护区） |
| `src/{TableName}DAO.cj` | 逐表 DAO 层 |
| `src/{TableName}Service.cj` | 逐表 Service 层 |
| `src/{TableName}Controller.cj` | 逐表 Controller 层（含 `wiredService` 接线点） |
| `src/{TableName}Route.cj` | 逐表 Route 层 |
| `plugin.yaml` | 聚合 V4 API 路由（entry = 聚合 Plugin；tableWhitelist / tables 为合并表清单；routes 为各表 Route） |
| `SKILL.md` | 聚合技能说明（多表能力、服务调用类名 `<Pascal表名>Service`） |
| `cjpm.toml` | 独立 cjpm 包配置（workspace 成员模式，幂等覆盖） |

> 命名约定：`{PascalName}` 为插件名 Pascal 化（如 `github` → `Github`）；`{TableName}` 为表名 Pascal 化（如 `repository_file` → `RepositoryFile`）。
> 权限节点：`generatePermissionNodes` 按表幂等生成 `database → database.{dbName} → database.{dbName}.{tableName}` 三级菜单节点与 i18 数据，已存在节点跳过。

## 生成产物（L3 进程隔离轨）

| 文件 | 职责 |
|------|------|
| `plugin.yaml` | V4 API 路由（6 条路由：add/edit/del/empty-recycle-bin/:id/:limit/:page） |
| `cjpm.toml` | 独立 executable 工程配置（`--dy-std -Woff all`） |
| `main.cj` | `PluginRuntime.run` 显式入口 |
| `handlers.cj` | 完整 CRUD handler 框架（dispatch 路由 + host.db 调用） |
| `effects.cj` | `ctx.effect` 可逆效果注册框架 |
| `README.md` | 第三方开发者手册 |

## CrudPluginGenerator（表驱动 CRUD 进程插件生成器）

`CrudPluginGenerator` 是 plugingen 的增强组件，可从数据库结构生成完整 CRUD 进程插件：

- 输入：数据库名 + 单张表名
- 输出：完整插件目录（plugin.yaml + cjpm.toml + main.cj + handlers.cj + effects.cj + README.md）
- 对标：已验证通过的 codelabs 插件参考实现
- **限制**：仅支持单表，不支持 `--tables` 多表累积（进程插件经 `host.db` 服务代理访问数据，设计上按单表契约生成）

生成的插件包含完整 V4 CRUD 接口：
- `GET /:limit/:page`：分页列表，返回 `{name}s`（表名+s 复数）
- `GET /:id`：单条查询
- `POST /add`：创建
- `POST /edit`：更新（含批量/恢复）
- `POST /del`：删除（含批量/硬删）
- `POST /empty-recycle-bin`：清空回收站

## 前置条件

1. 已执行 `cjpm run --skip-build --name magic.app.tools.loaddbinfo --run-args "--db <数据库名>"` 加载表结构到 `db_info` 表
2. `.env` 文件已配置 `orm_*` 数据源

## 与 crudgen 的关系

- **crudgen**：生成宿主 CRUD 模块到 `src/app/`（存量轨，crudgen 生成 + 追加 `AutoRouteConfig.cj`）
- **plugingen**：生成插件到 `skills/{name}/`（插件轨，不触碰 `AutoRouteConfig.cj`）

两条并行通道，模板独立演进，互不依赖。plugingen 的多表/保护区/幂等追加行为以 crudgen 为基准保持一致。
