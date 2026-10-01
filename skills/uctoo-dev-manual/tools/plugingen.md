# plugingen 使用手册

## 概述

`plugingen` 是 agentskills-runtime 的插件生成器，与 crudgen 同构的确定性插件生成工具，从 `db_info` 读表结构，生成插件到 `skills/{name}/`。

**源码位置**：`src/plugin/tools/plugingen/plugingen.cj`、`src/plugin/tools/plugingen/PluginGenerator.cj`、`src/plugin/tools/plugingen/CrudPluginGenerator.cj`

## 用法

`plugingen` 是宿主工程内的 cjpm 可运行包（包名 `magic.plugin.tools.plugingen`），
**不能作为独立可执行文件直接调用**，必须通过 `cjpm run --skip-build --name <完整包名> --run-args "<参数>"` 运行
（与 loaddbinfo / crudgen / crudweb 的调用方式一致，见 `docs/uctoo-v4/uctoo-v4-module-development.md` 第 8 节）。

```bash
# 表驱动：从 db_info 读表结构，生成五层 CRUD 插件
cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name <插件名> --db <数据库名> --table <表名>"

# 空白骨架：仅生成 SKILL.md + plugin.yaml + 包占位 + 插件入口
cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name <插件名> --blank"

# L3 进程隔离轨：独立 cjpm executable 工程
cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name <插件名> --mode process"

# L3 进程隔离轨 + 表驱动：生成完整 CRUD 进程插件（对标 codelabs）
cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name <插件名> --db <数据库名> --table <表名> --mode process"
```

## 选项

| 选项 | 说明 |
|------|------|
| `--name <插件名>` | 插件唯一名（小写字母/数字/下划线；连字符自动转下划线） |
| `--db <数据库名>` | 表驱动模式：数据库名（读 db_info 表结构） |
| `--table <表名>` | 表驱动模式：表名 |
| `--mode <轨>` | 加载轨：sync（缺省）/ dylib / process |
| `--blank` | 生成空白插件骨架（跳过表结构） |
| `--help, -h` | 显示帮助信息 |

## 示例

```bash
# 生成 sync 轨插件（默认）
cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name entity --db uctoo --table entity"

# 生成空白进程插件骨架
cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name mytool --mode process"

# 生成完整 CRUD 进程插件（对标 codelabs）
cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name codelabs --db uctoo --table codelabs --mode process"
```

## 三轨架构

| 轨道 | mode | 编译图归属 | 加载机制 | 适用场景 |
|------|------|------------|----------|----------|
| 内嵌轨 | sync | 宿主 magic 包 | build-sync 同步到 `src/plugins/{name}/` | 开发期增量编译 |
| L2 动态库轨 | dylib | 独立 cjpm 包（动态库） | `PackageInfo.load` 热加载 | 预编译动态库 |
| L3 进程隔离轨 | process | 不进宿主编译图（独立 cjpm executable 工程） | `CordisHostManager` stdio 拉起 | 故障隔离、第三方发布 |

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

- 输入：数据库名 + 表名
- 输出：完整插件目录（plugin.yaml + cjpm.toml + main.cj + handlers.cj + effects.cj + README.md）
- 对标：已验证通过的 codelabs 插件参考实现

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

两条并行通道，模板独立演进，互不依赖。
