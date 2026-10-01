# loaddbinfo 使用手册

## 概述

`loaddbinfo` 是 agentskills-runtime 的数据库信息加载工具，从数据库结构(information_schema)读取表结构信息，保存到 `db_info` 表。这是确定性代码生成工具链的第一步。

**源码位置**：`src/app/tools/loaddbinfo/loaddbinfo.cj`

## 用法 TODO：bug命令行模式报找不到数据库连接，但是Web端数据库管理页面加载数据库信息功能可用。

```bash 
cjpm run --skip-build --name magic.app.tools.loaddbinfo --run-args "--db <数据库名>"
```

## 选项

| 选项 | 说明 |
|------|------|
| `--db <数据库名>` | 指定要加载的数据库名 |
| `--help, -h` | 显示帮助信息 |

## 示例

```bash
# 加载指定数据库的表结构信息到 db_info 表cjpm run --skip-build --name magic.app.tools.loaddbinfo --run-args "--db uctoo"```

## 工作原理

1. 连接 PostgreSQL 数据库
2. 从 `information_schema` 读取指定数据库的所有表结构信息
3. 将表结构信息写入 `db_info` 表
4. 后续工具（crudgen、crudweb、plugingen）从 `db_info` 读取表结构生成代码

## 工具链工作流

```
数据库结构
    ↓cjpm run --skip-build --name magic.app.tools.loaddbinfo --run-args "--db uctoo" # 加载表结构到 db_info 表
    ↓cjpm run --skip-build --name magic.app.tools.crudgen --run-args "--db uctoo --table entity" # 生成宿主 CRUD 模块
    ↓cjpm run --skip-build --name magic.app.tools.crudweb --run-args "--db uctoo --table entity" # 生成 Web 管理界面
    ↓cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name entity --db uctoo --table entity --mode process" # 生成插件
```

## 注意事项

- 需要先配置 `.env` 文件中的 `orm_*` 数据源配置
- `db_info` 表是 crudgen/crudweb/plugingen 的数据源，表结构变更后需重新执行
