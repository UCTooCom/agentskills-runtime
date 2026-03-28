---
name: crud-generator
description: Generate standard CRUD modules for UCToo V4 with DAO layer. Use this skill when the user wants to create a new database module, scaffold CRUD operations, or generate boilerplate code for a database table. The skill reads uctooDB.sql to understand table structure, then generates Model, DAO, Service, Controller, Route files and pkg.cj exports in Cangjie language. Trigger when user mentions "generate CRUD", "create module", "scaffold", "new table", "add entity", or asks to create database operations for any table like "为xxx表生成CRUD" or "创建xxx模块".
---

# CRUD Generator Skill

为 UCToo V4 生成标准 CRUD 模块，包含 DAO 层。

## 📚 文档导航

本技能包含以下文档和资源：

### 核心文档
- **SKILL.md** (本文档) - 技能主文档，包含完整的使用说明
- **SQL_SCHEMA_PARSER_USAGE.md** - SQL解析器详细使用说明，包含API文档和类型映射

### 参考文档 (references/)
- **model-pattern.md** - Model层代码模式参考，包含字段定义和ORM注解
- **dao-pattern.md** - DAO层代码模式参考，包含数据访问方法设计
- **service-pattern.md** - Service层代码模式参考，包含业务逻辑封装
- **controller-pattern.md** - Controller层代码模式参考，包含HTTP请求处理
- **route-pattern.md** - Route层代码模式参考，包含路由注册

### 核心脚本 (scripts/)
- **generate-from-template-v2.js** - 核心生成脚本，支持关键字检测和自动路由注册
- **sql-schema-parser.js** - SQL表结构解析器，从uctooDB.sql读取表结构
- **update-auto-route-config.js** - 自动路由注册脚本，更新AutoRouteConfig.cj
- **example-generate-entity.js** - Entity表生成示例，演示完整流程

### 模板文件 (templates/)
- **model-full.cj.tpl** - Model层完整模板，包含ORM注解和toJson方法
- **dao-full.cj.tpl** - DAO层完整模板，包含CRUD操作方法
- **service-full.cj.tpl** - Service层完整模板，包含业务逻辑封装
- **controller-full.cj.tpl** - Controller层完整模板，包含RESTful端点
- **route-full.cj.tpl** - Route层完整模板，包含路由定义

## 🚀 快速开始

### 最简单的使用方式

```bash
# 方式1：使用示例脚本（推荐新手）
node scripts/example-generate-entity.js

# 方式2：使用核心脚本（推荐进阶用户）
# 在代码中导入并调用
import { generateModule } from './scripts/generate-from-template-v2.js'
import { parseTable } from './scripts/sql-schema-parser.js'
```

### 推荐阅读顺序

1. **新手路径**：
   - 阅读本文档 → 了解基本流程
   - 运行 `example-generate-entity.js` → 查看生成结果
   - 阅读生成的代码 → 理解各层结构

2. **进阶路径**：
   - 阅读 `SQL_SCHEMA_PARSER_USAGE.md` → 了解SQL解析
   - 阅读 `references/` 目录 → 理解各层设计模式
   - 自定义生成逻辑 → 修改模板文件

3. **深入路径**：
   - 研究模板文件 → 理解代码生成机制
   - 修改模板 → 适配特殊需求
   - 扩展功能 → 添加新的生成能力

## 📦 技能文件清单

```
crud-generator/
├── SKILL.md                           # 本文档
├── SQL_SCHEMA_PARSER_USAGE.md         # SQL解析器使用说明
├── references/                        # 参考文档目录
│   ├── model-pattern.md               # Model模式参考
│   ├── dao-pattern.md                 # DAO模式参考
│   ├── service-pattern.md             # Service模式参考
│   ├── controller-pattern.md          # Controller模式参考
│   └── route-pattern.md               # Route模式参考
├── scripts/                           # 核心脚本目录
│   ├── generate-from-template-v2.js   # 核心生成脚本
│   ├── sql-schema-parser.js           # SQL解析器
│   ├── update-auto-route-config.js    # 自动路由注册
│   └── example-generate-entity.js     # Entity生成示例
└── templates/                         # 模板文件目录
    ├── model-full.cj.tpl              # Model模板
    ├── dao-full.cj.tpl                # DAO模板
    ├── service-full.cj.tpl            # Service模板
    ├── controller-full.cj.tpl         # Controller模板
    └── route-full.cj.tpl              # Route模板

总计：16个核心文件
```

## 使用场景

当用户需要以下操作时使用此技能：
- 为数据库表创建新的 CRUD 模块
- 生成数据访问层代码
- 创建 RESTful API 接口
- 快速搭建模块骨架

## 生成流程

### 步骤 1: 收集需求

询问用户：
1. **表名** - 要生成代码的数据库表名（如 "agent_skills"）
2. **数据库名** - 默认为 "uctoo"
3. **模块选项**:
   - 需要认证？(默认: 是)
   - 启用缓存？(默认: 否)
   - 生成测试？(默认: 是)

### 步骤 2: 分析 SQL Schema

1. **读取 uctooDB.sql**:
   - 读取 `apps/agentskills-runtime/sql/uctooDB.sql` 获取表结构
   - 解析CREATE TABLE语句提取字段定义
   - 解析字段类型、可空标志、默认值
   - 识别主键和字段注释

2. **PostgreSQL类型映射**:
   - uuid → String
   - text/varchar → String
   - int4/int8 → Int
   - float8 → Float
   - bool → Boolean
   - timestamptz → DateTime
   - jsonb/json → String

> 💡 **详细说明**：SQL解析器的详细使用方法、API文档和类型映射表请参考 [SQL_SCHEMA_PARSER_USAGE.md](./SQL_SCHEMA_PARSER_USAGE.md)

### 步骤 2.5: 关键字检测和处理

**自动检测仓颉关键字**:
- 检测字段名是否为仓颉保留关键字（共70个官方关键字）
- 自动重命名字段以避免冲突
- 保持数据库列名不变（通过@ORMField注解）

**重命名策略**:
- **字段重命名**：添加表名前缀（单数形式）
  - 例如：`type` → `permissionType`（permissions表）
  - 例如：`class` → `userClass`（users表）
- **局部变量重命名**：添加Value后缀
  - 例如：`type` → `typeValue`（Controller的mapToEntity方法）
- **添加重命名注释**：说明重命名原因和数据库列名

**支持的关键字**（共70个官方关键字）:
- **类型关键字**：Bool, Rune, Float16, Float32, Float64, Int8, Int16, Int32, Int64, IntNative, UInt8, UInt16, UInt32, UInt64, UIntNative, Nothing, Unit, VArray, This
- **定义关键字**：class, interface, enum, struct, type, func, init, main, operator, macro, prop
- **访问控制关键字**：public, private, protected, open, static
- **继承扩展关键字**：extend, abstract, override, redef, super
- **控制流关键字**：if, else, match, case, for, while, do, break, continue, return, where
- **异常处理关键字**：try, catch, throw, finally
- **包和导入关键字**：import, package, foreign
- **其他关键字**：as, const, false, finally, in, is, let, mut, quote, spawn, synchronized, unsafe, var, true

**完整关键字列表参考**：仓颉官方文档 `kernel/source_zh_cn/Appendix/keyword.md`

### 步骤 3: 使用模板生成代码

**重要**: 使用完整模板生成，确保与entity标准模块完全一致

**推荐使用脚本**: `scripts/generate-from-template-v2.js`

这是最新版本，包含：
- ✅ 完整的仓颉关键字检测（70个官方关键字）
- ✅ 自动字段重命名机制
- ✅ 局部变量命名优化
- ✅ 基于官方文档验证

1. **读取模板文件**:
   - `templates/model-full.cj.tpl` - Model完整模板
   - `templates/dao-full.cj.tpl` - DAO完整模板
   - `templates/service-full.cj.tpl` - Service完整模板
   - `templates/controller-full.cj.tpl` - Controller完整模板
   - `templates/route-full.cj.tpl` - Route完整模板

2. **动态生成字段相关代码**:
   - Model字段定义（包含完整ORM注解）
   - 构造函数参数和赋值
   - toJson方法字段序列化
   - INSERT/UPDATE SQL字段列表
   - mapToEntity方法字段映射

3. **模板变量替换**:
   - {DATABASE_NAME} → 数据库名
   - {TABLE_NAME} → 表名
   - {TABLE_NAME_CAMEL} → 驼峰表名
   - {TABLE_NAME_PASCAL} → 帕斯卡表名
   - {FIELDS_SECTION} → 字段定义
   - {INSERT_FIELDS} → INSERT字段列表
   - {INSERT_VALUES} → INSERT值列表
   - {UPDATE_SETS} → UPDATE SET部分
   - {MAP_TO_ENTITY_METHOD} → mapToEntity方法
   - {TO_JSON_FIELDS} → toJson字段序列化

4. **生成的文件**:
```
src/app/
├── models/{database}/{Table}PO.cj        # 数据模型
├── dao/{database}/{Table}DAO.cj          # 数据访问层
├── services/{database}/{Table}Service.cj # 服务层
├── controllers/{database}/{table}/       # 控制器目录
│   └── {Table}Controller.cj              # 控制器
├── routes/{database}/{table}/            # 路由目录
│   └── {Table}Route.cj                   # 路由定义
└── pkg.cj files                          # 目录占位文件
```

### 步骤 4: 审查和应用

1. **显示生成的代码**给用户
2. **验证一致性**: 确保生成的代码与entity标准模块完全一致
3. **解释关键决策**:
   - Prisma 到 Cangjie 的字段映射
   - DAO 方法设计
   - 批量操作支持
   - sort和filter参数支持
4. **用户确认后应用更改**

## 代码模式

> 💡 **详细参考**：各层的详细设计模式、代码结构和最佳实践请参考 [references/](./references/) 目录下的文档：
> - [model-pattern.md](./references/model-pattern.md) - Model层详细设计
> - [dao-pattern.md](./references/dao-pattern.md) - DAO层详细设计
> - [service-pattern.md](./references/service-pattern.md) - Service层详细设计
> - [controller-pattern.md](./references/controller-pattern.md) - Controller层详细设计
> - [route-pattern.md](./references/route-pattern.md) - Route层详细设计

### 关键字处理模式

**问题**: 数据库列名是仓颉关键字

```cangjie
// ❌ 错误：type是关键字，编译失败
private var type: ?Int32 = None<Int32>
```

**解决**: 自动重命名字段

```cangjie
// ✅ 正确：自动重命名为 permissionType
// 注意: 数据库列名 'type' 是关键字，已重命名为 'permissionType'
@ORMField['type']  // 数据库列名保持 'type'
private var permissionType: ?Int32 = None<Int32>  // 仓颉字段名改为 permissionType
```

**Controller中的处理**:

```cangjie
// ❌ 错误：局部变量名是关键字
if (let Some(type) <- map.get("type")) {
    // ...
}

// ✅ 正确：自动重命名为 typeValue
if (let Some(typeValue) <- map.get("type")) {
    let typeValueInt64 = typeValue as Int64
    if (let Some(s) <- typeValueInt64) {
        entity.permissionType = Some<Int32>(Int32(s))
    }
}
```

### Model 模式

基于 `EntityPO.cj`:
- 包: `magic.app.models.{database}`
- 使用 Fountain ORM 注解
- 类型安全的字段定义
- 包含 `toJson()` 方法
- 标准字段: id, createdAt, updatedAt, deletedAt, creator

### DAO 模式 (V4新增)

基于 `EntityDAO.cj`:
- 包: `magic.app.dao.{database}`
- 使用 `@DAO` 注解
- 继承 `RootDAO` 接口
- 使用 `setSql` 方法构建查询
- **不过滤软删除数据** - 返回完整数据集
- 标准方法:
  - `insert{Table}(entity): String` - 插入并返回生成的ID
  - `findById(id): Option<{Table}PO>` - 按ID查询（不过滤软删除）
  - `findAllPage(page, size): Pagination<{Table}PO>` - 分页列表
  - `update{Table}(entity): Int64` - 更新记录
  - `softDeleteById(id): Int64` - 软删除
  - `restoreById(id): Int64` - 恢复软删除
  - `deleteById(id): Int64` - 硬删除
  - `countAll(): Int64` - 统计总数

### Service 模式

基于 `EntityService.cj`:
- 包: `magic.app.services.{database}`
- 使用 `APIResult<T>` 包装操作结果
- 使用 DAO 方法进行数据访问
- CRUD 方法:
  - `create(entity): APIResult<{Table}PO>`
  - `update(id, entity): APIResult<{Table}PO>`
  - `updateMultiple(entities): APIResult<ArrayList<{Table}PO>>`
  - `delete(id, force): APIResult<Bool>`
  - `restore(id): APIResult<{Table}PO>`
  - `getById(id): APIResult<{Table}PO>`
  - `getList(page, limit): (ArrayList<{Table}PO>, Int64)`

### Controller 模式

基于 `EntityController.cj`:
- 包: `magic.app.controllers.{database}.{table_name}`
- RESTful 端点:
  - `add(req, res)` - POST /add
  - `edit(req, res)` - POST /edit (支持通过 deleted_at="0" 恢复)
  - `delete(req, res)` - POST /del (force=1 表示硬删除)
  - `getSingle(req, res)` - GET /:id
  - `getManyWithPathParams(req, res)` - GET /:limit/:page
- JSON 错误响应处理
- 请求体解析

### Route 模式

基于 `EntityRoute.cj`:
- 包: `magic.app.routes.{database}.{table_name}`
- 路由注册:
  - POST `/add` → controller.add
  - POST `/edit` → controller.edit
  - POST `/del` → controller.delete
  - GET `/:id` → controller.getSingle
  - GET `/:limit/:page` → controller.getManyWithPathParams

## 使用示例

### ⚠️ 重要：使用通用生成脚本

**不要为每个表创建新的生成脚本！**

使用单一的通用生成脚本 `scripts/generate-from-template-v2.js`，通过不同的配置参数来生成不同表的CRUD模块。

### 方式一：作为模块导入（推荐）

```javascript
import { generateModule } from './scripts/generate-from-template-v2.js'
import { parseTable } from './scripts/sql-schema-parser.js'

// 解析表结构（从uctooDB.sql）
const tableInfo = parseTable('entity')

// 生成entity模块
await generateModule({
  tableName: 'entity',
  dbName: 'uctoo',
  fields: tableInfo.fields,
  outputDir: './src/app'
})

// 生成uctoo_user模块（使用同一个函数）
const uctooUserTableInfo = parseTable('uctoo_user')
await generateModule({
  tableName: 'uctoo_user',
  dbName: 'uctoo',
  fields: uctooUserTableInfo.fields,
  outputDir: './src/app'
})

// 生成任何其他表的模块（都使用同一个函数）
const yourTableInfo = parseTable('your_table')
await generateModule({
  tableName: 'your_table',
  dbName: 'uctoo',
  fields: yourTableInfo.fields,
  outputDir: './src/app'
})
```

### 方式二：通过技能交互

**用户**: "为 entity 表生成 CRUD"

**技能执行流程**:
```
1. 分析 uctooDB.sql 中的 entity 表结构
2. 提取字段定义
3. 调用 generateModule({ tableName: 'entity', ... })
4. 生成 Model, DAO, Service, Controller, Route 文件
5. 显示生成的代码供审查
```

**用户**: "为 uctoo_user 表生成 CRUD"

**技能执行流程**:
```
1. 分析 uctooDB.sql 中的 uctoo_user 表结构
2. 提取字段定义
3. 调用 generateModule({ tableName: 'uctoo_user', ... })  // 使用同一个函数
4. 生成 Model, DAO, Service, Controller, Route 文件
5. 显示生成的代码供审查
```

### 方式三：批量生成多个表

```javascript
import { generateModule } from './scripts/generate-from-template-v2.js'
import { parseTable } from './scripts/sql-schema-parser.js'

const tableNames = ['entity', 'uctoo_user', 'agent_skills', 'db_info']

// 使用循环批量生成
for (const tableName of tableNames) {
  const tableInfo = parseTable(tableName)
  await generateModule({
    tableName: tableName,
    dbName: 'uctoo',
    fields: tableInfo.fields,
    outputDir: './src/app'
  })
  console.log(`✅ ${tableName} 模块生成完成`)
}
```

### ❌ 错误的使用方式

**不要这样做**：

```javascript
// ❌ 错误：为每个表创建单独的生成脚本
// scripts/generate-entity.js
// scripts/generate-uctoo-user.js
// scripts/generate-agent-skills.js
// ... 每个表一个脚本

// ❌ 错误：手动定义字段列表
const entityFields = [
  { name: 'id', dbName: 'id', camelName: 'id', type: 'String', isPrimaryKey: true, isOptional: false },
  // ... 手动维护大量字段定义
]
```

**应该这样做**：

```javascript
// ✅ 正确：使用统一的生成函数和SQL解析器
import { generateModule } from './scripts/generate-from-template-v2.js'
import { parseTable } from './scripts/sql-schema-parser.js'

const tableInfo = parseTable('entity')  // 自动从SQL解析
await generateModule({ tableName: 'entity', fields: tableInfo.fields, ... })

const uctooUserTableInfo = parseTable('uctoo_user')  // 自动从SQL解析
await generateModule({ tableName: 'uctoo_user', fields: uctooUserTableInfo.fields, ... })

const agentSkillsTableInfo = parseTable('agent_skills')  // 自动从SQL解析
await generateModule({ tableName: 'agent_skills', fields: agentSkillsTableInfo.fields, ... })
```

## 字段类型映射

| PostgreSQL类型 | Cangjie类型 | 默认值 | 说明 |
|---------------|-------------|--------|------|
| uuid | String | "" | UUID主键 |
| text | String | "" | 文本类型 |
| varchar | String | "" | 变长字符串 |
| int4 | Int32 | 0 | 32位整数 |
| int8 | Int64 | 0 | 64位整数 |
| float8 | Float64 | 0.0 | 双精度浮点 |
| bool | Bool | false | 布尔值 |
| timestamptz | DateTime | DateTime.now() | 时区时间戳 |
| timestamp | DateTime | DateTime.now() | 时间戳 |
| date | DateTime | DateTime.now() | 日期 |
| jsonb | String | "" | JSON二进制 |
| json | String | "" | JSON文本 |

## SQL Schema 解析

读取 `uctooDB.sql` 时，提取：

```sql
CREATE TABLE "public"."entity" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "link" text COLLATE "pg_catalog"."default" NOT NULL,
  "privacy_level" int4 NOT NULL DEFAULT 0,
  "stars" float8 NOT NULL DEFAULT 0,
  "description" text COLLATE "pg_catalog"."default",
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "creator" uuid,
  CONSTRAINT "entity_pkey" PRIMARY KEY ("id")
);

COMMENT ON COLUMN "public"."entity"."id" IS '主键UUID';
COMMENT ON COLUMN "public"."entity"."link" IS '链接地址';
```

生成对应的 Cangjie 字段:
- `id: String` - 主键UUID
- `link: String` - 必填字符串
- `privacyLevel: Int32` - 从 privacy_level 映射
- `stars: Float64` - 浮点字段
- `description: ?String` - 可空字符串
- `createdAt: DateTime` - 时间戳
- `deletedAt: ?DateTime` - 可空时间戳

## 错误处理

- **表在 uctooDB.sql 中不存在**: 询问用户有效的表名
- **字段类型错误**: 建议手动覆盖
- **生成失败**: 显示详细错误并建议修复

## 最佳实践

1. **严格遵循 entity 模块模式**
2. **使用 DAO 层**进行所有数据访问
3. **在 DAO 中使用 setSql 方法**（避免 FROM().WHERE().first()）
4. **DAO 方法不过滤软删除数据**
5. **所有 Service 操作使用 APIResult**
6. **优雅处理错误**，使用 JSON 错误响应
7. **支持分页**在列表端点
8. **支持批量操作**（updateMultiple）
9. **支持恢复**通过 edit 端点（deleted_at="0"）

## 确定性代码生成

### 核心原则

**使用优化后的crud-generator生成entity模块，结果必须与现有标准entity模块完全一致**

这意味着：
- ✅ 代码结构完全一致
- ✅ 方法签名完全一致
- ✅ 注释内容完全一致
- ✅ 空格和换行完全一致
- ✅ 版权声明完全一致

### 实现方式

1. **完整模板**: 使用基于entity标准模块提取的完整模板
2. **精确替换**: 只替换表名、数据库名、字段名等变量
3. **保持格式**: 保持原有的缩进、空行、注释格式
4. **版权声明**: 每个文件头必须包含标准版权声明

### 版权声明

所有生成的文件必须包含以下版权声明：

```cangjie
/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
```

### 验证方法

生成代码后，使用diff工具对比：
```bash
# 对比生成的entity模块与标准entity模块
diff -r src/app/models/uctoo/EntityPO.cj generated/entity/models/uctoo/EntityPO.cj
diff -r src/app/dao/uctoo/EntityDAO.cj generated/entity/dao/uctoo/EntityDAO.cj
diff -r src/app/services/uctoo/EntityService.cj generated/entity/services/uctoo/EntityService.cj
diff -r src/app/controllers/uctoo/entity/EntityController.cj generated/entity/controllers/uctoo/entity/EntityController.cj
diff -r src/app/routes/uctoo/entity/EntityRoute.cj generated/entity/routes/uctoo/entity/EntityRoute.cj
```

预期结果：无任何差异

## 代码生成区域标识

### 概述

生成的代码使用注释标识区机制，确保定制开发代码不会被覆盖：

```cangjie
/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.{layer}.{database}.{table}

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

import standard.library.Module1
import standard.library.Module2

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========

public class {Table}Controller {
    // ...
    
    //#region AutoCreateCode
    
    // ... 自动生成的标准CRUD代码 ...
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
```

### 两层保护机制

1. **头部自定义引入区域**：
   - 标识：`// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========`
   - 用途：保护自定义的import引入语句
   - 位置：在package声明之后，标准import之前

2. **尾部定制开发区域**：
   - 标识：`//#region AutoCreateCode` 和 `//#endregion AutoCreateCode`
   - 用途：保护自定义的方法实现
   - 位置：在类定义内部

### 重新生成行为

当重新生成代码时：
1. **检测头部区域**：检测文件中是否存在自定义引入区域标识
2. **保留自定义import**：头部自定义引入区域的代码会被完整保留
3. **检测尾部区域**：检测文件中是否存在 `//#region AutoCreateCode` 和 `//#endregion AutoCreateCode`
4. **保留定制代码**：尾部标识区外的代码会被完整保留
5. **更新自动代码**：只更新标识区内的标准CRUD代码
6. **首次生成**：如果文件不存在，创建包含完整标识区的新文件

### 各层标识

| 层级 | 头部引入区 | 尾部方法区 | 说明 |
|------|-----------|-----------|------|
| Model | ✅ | ❌ | 支持自定义import，字段变更时需要整体更新 |
| DAO | ✅ | ✅ | 支持自定义import和查询方法 |
| Service | ✅ | ✅ | 支持自定义import和业务逻辑 |
| Controller | ✅ | ✅ | 支持自定义import和接口方法 |
| Route | ✅ | ✅ | 支持自定义import和路由配置 |

### 定制开发示例

#### 自定义import示例

```cangjie
// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

import magic.app.utils.CustomUtils
import magic.app.services.external.ExternalService

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
```

#### 自定义方法示例

```cangjie
// DAO层自定义查询
//#endregion AutoCreateCode

// ========== 定制开发方法（在此区域添加自定义方法）==========

func findByCustomCondition(param: String): ArrayList<{Table}PO> {
    executor.setSql('''
        select * from {table} where custom_field = ${arg(param)}
    ''').list<{Table}PO>()
}
```

## 集成说明

- 生成的代码遵循与 entity 模块相同的模式
- 兼容现有的中间件和认证
- 使用相同的数据库连接模式（ORM.executor()）
- 遵循 UCToo API 规范
- DAO 层实现更好的可测试性和关注点分离

## 生成后步骤

### 自动路由注册（推荐）

**重要**: 生成的路由会自动通过 `AutoRouteConfig.cj` 注册，无需手动添加！

#### 自动注册机制

项目已实现自动路由注册机制，包含两个关键文件：

1. **AutoRouteConfig.cj** - 路由配置文件
   - 位置：`src/app/registry/AutoRouteConfig.cj`
   - 作用：存储所有 CRUD 路由的配置信息
   - 维护：由 crud-generator 自动更新

2. **AutoRouteRegistry.cj** - 路由注册器
   - 位置：`src/app/registry/AutoRouteRegistry.cj`
   - 作用：读取配置并注册所有路由
   - 使用：在 main.cj 中调用

#### 工作流程

```cangjie
// 1. AutoRouteConfig.cj 中定义路由配置
public static func initRegistry(registry: RouteRegistry): Unit {
    // Entity 路由
    registry.add(RouteEntry(
        "entity",
        "/api/v1/uctoo/entity",
        10,
        true,
        { router: Router =>
            let service = EntityService()
            let controller = EntityController(service)
            let route = EntityRoute(router, controller)
            route.register()
        }
    ))
    
    // 更多路由配置...
}

// 2. AutoRouteRegistry.cj 中注册所有路由
public func registerAllRoutes(): Unit {
    logger.info("=== Starting automatic route registration ===")
    registerCrudRoutes()  // 注册所有 CRUD 路由
    registerAuthRoutes()  // 注册认证路由
    registerMcpRoutes()   // 注册 MCP 路由
    logger.info("=== All routes registered successfully ===")
}

// 3. main.cj 中使用
private func setupRoutes(): Unit {
    let routeRegistry = AutoRouteRegistry(router)
    routeRegistry.registerAllRoutes()
}
```

#### 新增路由的自动注册

当使用 crud-generator 生成新模块时，会自动更新 `AutoRouteConfig.cj`：

**生成前**：
```cangjie
// AutoRouteConfig.cj
import magic.app.routes.uctoo.entity.EntityRoute
import magic.app.controllers.uctoo.entity.EntityController
import magic.app.services.uctoo.{EntityService}

public static func initRegistry(registry: RouteRegistry): Unit {
    // Entity 路由
    registry.add(RouteEntry(...))
}
```

**生成 db_info 模块后**（自动更新）：
```cangjie
// AutoRouteConfig.cj
import magic.app.routes.uctoo.entity.EntityRoute
import magic.app.routes.uctoo.db_info.DbInfoRoute  // 新增
import magic.app.controllers.uctoo.entity.EntityController
import magic.app.controllers.uctoo.db_info.DbInfoController  // 新增
import magic.app.services.uctoo.{
    EntityService,
    DbInfoService  // 新增
}

public static func initRegistry(registry: RouteRegistry): Unit {
    // Entity 路由
    registry.add(RouteEntry(...))
    
    // DbInfo 路由（自动添加）
    registry.add(RouteEntry(
        "db_info",
        "/api/v1/uctoo/db_info",
        130,  // 自动计算的优先级
        true,
        { router: Router =>
            let service = DbInfoService()
            let controller = DbInfoController(service)
            let route = DbInfoRoute(router, controller)
            route.register()
        }
    ))
}
```

#### 复合主键表的特殊处理

对于复合主键表（如 `user_has_group`, `group_has_permission`），路由配置会自动添加注释标记：

```cangjie
// UserHasGroup 路由 (复合主键)
registry.add(RouteEntry(
    "user_has_group",
    "/api/v1/uctoo/user_has_group",
    60,
    true,
    { router: Router =>
        let service = UserHasGroupService()
        let controller = UserHasGroupController(service)
        let route = UserHasGroupRoute(router, controller)
        route.register()
    }
))
```

### 手动注册（不推荐）

**仅在特殊情况下使用手动注册**：

```cangjie
import magic.app.routes.{database}.{table}.{Table}Route

main() {
    let router = Router()
    
    // 手动注册模块路由（不推荐）
    let {table}Service = {Table}Service()
    let {table}Controller = {Table}Controller({table}Service)
    let {table}Route = {Table}Route(router, {table}Controller)
    {table}Route.register()
    
    // ...
}
```

### 验证路由注册

启动应用后，查看日志确认路由已注册：

```
=== Starting automatic route registration ===
Registering CRUD routes...
✓ EntityRoute registered
✓ UctooUserRoute registered
✓ UctooSessionRoute registered
✓ UserGroupRoute registered
✓ PermissionsRoute registered
✓ UserHasAccountRoute registered
✓ DbInfoRoute registered  // 新生成的路由
=== All routes registered successfully ===
```

测试API是否可访问：

```bash
# 测试列表接口
curl http://localhost:8080/api/v1/uctoo/{table}/10/1

# 测试单条查询
curl http://localhost:8080/api/v1/uctoo/{table}/{id}
```

## 参考文档

详细模式请阅读:
- `references/model-pattern.md` - Model 生成详情
- `references/dao-pattern.md` - DAO 生成详情
- `references/service-pattern.md` - Service 生成详情
- `references/controller-pattern.md` - Controller 生成详情
- `references/route-pattern.md` - Route 生成详情
