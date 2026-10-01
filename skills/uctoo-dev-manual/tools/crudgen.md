# crudgen 使用手册

## 概述

`crudgen` 是 agentskills-runtime 的宿主 CRUD 代码生成器，从 `db_info` 读表结构，生成宿主 CRUD 模块到 `src/app/`（五层架构：PO/DAO/Service/Controller/Route）。

**源码位置**：`src/app/tools/crudgen/crudgen.cj`、`src/app/tools/crudgen/CrudGenerator.cj`

## 用法

```bash 
cjpm run --skip-build --name magic.app.tools.crudgen --run-args "--db <数据库名> --table <表名> [--all] [--output <输出目录>]"
```

## 选项

| 选项 | 说明 |
|------|------|
| `--db <数据库名>` | 指定数据库名 |
| `--table <表名>` | 指定表名 |
| `--all` | 生成数据库中所有表的 CRUD 代码 |
| `--output <输出目录>` | 指定输出目录（默认 `src/app/`） |
| `--help, -h` | 显示帮助信息 |

## 示例

```bash
# 生成指定表的 CRUD 代码cjpm run --skip-build --name magic.app.tools.crudgen --run-args "--db uctoo --table entity"
# 生成数据库中所有表的 CRUD 代码cjpm run --skip-build --name magic.app.tools.crudgen --run-args "--db uctoo --all"```

## 生成产物

crudgen 为每张表生成五层 CRUD 架构：

| 层 | 文件 | 职责 |
|----|------|------|
| PO | `{ClassName}PO.cj` | 持久化对象（数据模型） |
| DAO | `{ClassName}DAO.cj` | 数据访问对象（SQL 操作） |
| Service | `{ClassName}Service.cj` | 业务逻辑层 |
| Controller | `{ClassName}Controller.cj` | HTTP 控制器（API 端点） |
| Route | `{ClassName}Route.cj` | 路由注册（@ModuleRoute 注解） |

## 前置条件

1. 已执行 `cjpm run --skip-build --name magic.app.tools.loaddbinfo --run-args "--db <数据库名>"` 加载表结构到 `db_info` 表
2. `.env` 文件已配置 `orm_*` 数据源

## 与 plugingen 的关系

- **crudgen**：生成宿主 CRUD 模块到 `src/app/`（存量轨，crudgen 生成 + 追加 `AutoRouteConfig.cj`）
- **plugingen**：生成插件到 `skills/{name}/`（插件轨，不触碰 `AutoRouteConfig.cj`）

两条并行通道，模板独立演进，互不依赖。
