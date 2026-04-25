---
name: crud-generator
description: Generate standard CRUD modules for UCToo V4 with DAO layer. Use this skill when the user wants to create a new database module, scaffold CRUD operations, or generate boilerplate code for a database table. The skill uses the crudgen command-line tool to read database structure from db_info table and generate Model, DAO, Service, Controller, Route files in Cangjie language. It also generates permission nodes automatically. Trigger when user mentions "generate CRUD", "create module", "scaffold", "new table", "add entity", "为xxx表生成CRUD" or "创建xxx模块".
---

# CRUD Generator Skill

为 UCToo V4 生成标准 CRUD 模块，基于确定性代码生成器实现。

## 核心特性

### 确定性代码生成

1. **相同输入产生相同输出**: 确定性生成机制，确保生成的代码一致性
2. **数据库驱动**: 从 db_info 表直接读取表结构信息
3. **CLI 工具**: 二进制命令行工具 `magic.app.tools.crudgen.exe`，支持单表和批量生成
4. **关键字处理**: 自动检测和处理 70 个仓颉保留关键字，避免冲突
5. **AutoCreateCode 标记**: 清晰标识自动生成代码区域，支持定制代码保留

### 与旧版本区别

| 特性 | 旧版本 (JS) | 当前版本 (Cangjie) |
|------|------------|-------------------|
| 实现语言 | JavaScript | Cangjie |
| 数据源 | SQL 文件 | db_info 数据库表 |
| 关键字处理 | 不完整 | 70 个关键字完整检测 |
| 生成方式 | 模板替换 | 确定性代码生成器 |
| 权限节点 | 无 | 自动生成 |

## 快速开始

### 运行命令

crudgen 只有一种运行方式：运行编译发布后的二进制命令行工具。

#### 本地开发环境

```bash
# 生成指定表的 CRUD 模块
.\target\release\bin\magic.app.tools.crudgen.exe --db uctoo --table entity

# 生成所有表的 CRUD 模块
.\target\release\bin\magic.app.tools.crudgen.exe --db uctoo --all

# 显示帮助
.\target\release\bin\magic.app.tools.crudgen.exe --help
```

#### 通过 SDK 分发安装

crudgen 二进制工具通过 AgentSkills SDK 分发安装到各种项目中：

| SDK | 安装包名 | 文档 |
|-----|---------|------|
| JavaScript/TypeScript | `@opencangjie/skills` | [README_cn.md](file:///D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime/sdk/javascript/README_cn.md) |
| Python | `agent-skills` | [README_cn.md](file:///D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime/sdk/python/README_cn.md) |
| Java | `com.opencangjie:skills` | [README.md](file:///D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime/sdk/java/README.md) |
| PHP | `opencangjie/skills` | [README_cn.md](file:///D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime/sdk/php/README_cn.md) |

#### Web 项目中使用示例

通过 JavaScript SDK 安装后，crudgen 二进制位于项目 node_modules 中：

```
node_modules/@opencangjie/skills/dist/runtime/win-x64/release/bin/magic.app.tools.crudgen.exe --db uctoo --table entity
```

### 生成结果

执行后会在以下位置生成文件:

```
src/app/
├── models/uctoo/EntityPO.cj           # Model 层
├── dao/uctoo/EntityDAO.cj             # DAO 层
├── services/uctoo/EntityService.cj    # Service 层
├── controllers/uctoo/entity/          # Controller 层
│   └── EntityController.cj
└── routes/uctoo/entity/               # Route 层
    └── EntityRoute.cj
```

### 命令行参数详解

crudgen 命令行工具支持以下参数：

| 参数 | 说明 | 必需 | 默认值 |
|------|------|------|--------|
| `--db <数据库名>` | 指定数据库名称（对应 db_info 表中的 table_catalog） | 是 | - |
| `--table <表名>` | 指定要生成 CRUD 代码的表名 | 与 `--all` 二选一 | - |
| `--all` | 生成指定数据库中所有表的 CRUD 代码 | 与 `--table` 二选一 | - |
| `--output <目录>` | 指定输出目录，即生成文件的父目录 | 否 | `./src/app` |
| `--help` 或 `-h` | 显示帮助信息 | 否 | - |

#### 参数组合规则

1. **`--db` + `--table`**：生成单个表的 CRUD 代码
   ```bash
   crudgen --db uctoo --table entity
   ```

2. **`--db` + `--all`**：生成指定数据库中所有表的 CRUD 代码
   ```bash
   crudgen --db uctoo --all
   ```

3. **`--db` + `--table` + `--output`**：指定输出目录
   ```bash
   crudgen --db uctoo --table entity --output ./custom/path
   ```

#### 参数验证

- 如果未指定 `--db`，工具会报错并显示帮助信息
- 如果未指定 `--table` 且未使用 `--all`，工具会报错并显示帮助信息
- `--table` 和 `--all` 是互斥的，不能同时使用

#### 使用示例

```bash
# 生成单个表的 CRUD 代码
crudgen --db uctoo --table entity

# 生成多个表（分别执行）
crudgen --db uctoo --table user
crudgen --db uctoo --table role
crudgen --db uctoo --table permission

# 生成数据库中所有表的 CRUD 代码
crudgen --db uctoo --all

# 指定输出目录（生成的文件会在 ./custom/app/ 目录下）
crudgen --db uctoo --table entity --output ./custom

# 查看帮助
crudgen --help
```

#### 输出日志说明

执行过程中会输出以下日志：

| 日志 | 含义 |
|------|------|
| `CRUD Generator starting...` | 工具启动 |
| `正在初始化数据库连接...` | 正在连接数据库 |
| `ORM初始化成功` | ORM 初始化完成 |
| `数据库连接成功` | 数据库连接成功 |
| `开始生成 xxx 表的CRUD代码...` | 开始生成指定表 |
| `表 xxx 的CRUD代码生成完成` | 指定表生成完成 |
| `所有表的CRUD代码生成完成！` | 全部完成 |

## 实现位置

### 源代码位置

- **crudgen.cj** - CLI 工具入口点
  - 路径: `apps/agentskills-runtime/src/app/tools/crudgen/crudgen.cj`
  - 负责参数解析和流程控制

- **CrudGenerator.cj** - 核心生成器类
  - 路径: `apps/agentskills-runtime/src/app/tools/crudgen/CrudGenerator.cj`
  - 负责从 db_info 表读取表结构
  - 负责生成各层代码
  - 负责生成权限节点

- **TemplateEngine.cj** - 模板引擎
  - 路径: `apps/agentskills-runtime/src/app/tools/crudgen/TemplateEngine.cj`
  - 负责模板加载和变量替换
  - 负责 AutoCreateCode 区域的增量更新

### 模板文件位置

- **Model.cj.tpl** - Model 层模板
- **DAO.cj.tpl** - DAO 层模板
- **Service.cj.tpl** - Service 层模板
- **Controller.cj.tpl** - Controller 层模板
- **Route.cj.tpl** - Route 层模板

路径: `apps/agentskills-runtime/src/app/tools/crudgen/templates/`

### 发布版本位置

- **二进制包**: `apps/agentskills-runtime/release/agentskills-runtime-win-x64.tar.gz`
- **SDK 源码**: `apps/agentskills-runtime/sdk/`

## 工作原理

### 1. 读取表结构

从 db_info 表读取表结构信息:

```sql
SELECT * FROM db_info
WHERE table_catalog = 'uctoo' AND table_name = 'entity'
ORDER BY ordinal_position
```

### 2. 关键字处理

自动检测和处理 70 个仓颉保留关键字:

| 关键字示例 | 处理方式 |
|-----------|---------|
| type | 重命名为 `dbConnectionType` (根据表名) |
| tableName | 重命名为 `dbTableName` (避免与宏方法冲突) |
| class, func 等 | 添加表名前缀 |

### 3. 类型映射

将数据库类型映射到仓颉类型:

| 数据库类型 | 仓颉类型 | 可空类型 |
|-----------|---------|---------|
| UUID, VARCHAR, TEXT | String | Option<String> |
| INT, INTEGER | Int32 | Option<Int32> |
| BIGINT | Int64 | Option<Int64> |
| FLOAT, DOUBLE | Float64 | Option<Float64> |
| DATETIME, TIMESTAMP | DateTime | Option<DateTime> |
| BOOLEAN | Bool | Option<Bool> |

### 4. 代码生成

#### Model 层
- 字段定义（带 @ORMField 注解）
- 构造函数（全参和无参）
- toJsonValue / toJson 方法
- Option 类型辅助方法

#### DAO 层
- 插入操作 (insert)
- 查询操作 (findById, findAll)
- 更新操作 (update)
- 删除操作 (softDelete, delete, restore)
- 分页查询 (findAllPage, findByFilterPage)
- 批量操作 (batchSoftDelete, batchDelete)
- 动态条件查询 (findByDynamicCondition)

#### Service 层
- 业务逻辑封装
- 查询条件构建
- 数据过滤和合并

#### Controller 层
- RESTful 端点 (add, edit, delete, getSingle, getMany)
- 请求参数解析
- 响应构建
- 导出功能 (export)

#### Route 层
- 路由注册
- 自定义路由扩展点

### 5. 权限节点生成

自动生成权限节点，权限结构:
```
database
  └── database.{dbName}
        └── database.{dbName}.{tableName}
```

幂等性保证:
- 已存在且未删除: 跳过
- 已删除: 恢复
- 不存在: 创建

### 6. AutoCreateCode 标记

所有自动生成的代码都包裹在 AutoCreateCode 区域:

```cangjie
//#region AutoCreateCode

// 自动生成的代码

//#endregion AutoCreateCode
```

定制代码可以添加在 AutoCreateCode 区域外，重新生成时不会被覆盖。

## 相关文档

- **crud-generator-refactor-plan.md** - 重构计划文档
  - 路径: `apps/agentskills-runtime/docs/uctoo-v4/crud-generator-refactor-plan.md`
- **AgentSkills SDK** - 多语言 SDK
  - 路径: `apps/agentskills-runtime/sdk/`

## 注意事项

1. **运行方式**: crudgen 只能通过运行二进制命令行工具 `magic.app.tools.crudgen.exe` 执行，不支持其他方式
2. **关键字冲突**: 如果表中有字段名是仓颉关键字，会自动重命名并在注释中说明
3. **定制代码**: 将定制代码放在 AutoCreateCode 区域外，避免被覆盖
4. **权限节点**: 生成权限节点失败不会影响代码生成

## 更新日志

### v3.0.0 (2026-04-25)

- 重写为纯 Cangjie 实现
- 新增 70 个仓颉关键字自动检测和处理
- 新增权限节点自动生成
- 新增批量生成功能 (--all)
- 改进模板引擎，支持增量更新
- 明确运行方式为二进制命令行工具

### v2.0.0 (2026-04-17)

- 重构为确定性代码生成器
- 从 db_info 表读取表结构
- 提供 crudgen 命令行工具

### v1.0.0

- 初始版本
- JavaScript 脚本生成
