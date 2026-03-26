---
name: crud-generator
description: Generate standard CRUD modules for UCToo V4 with DAO layer. Use this skill when the user wants to create a new database module, scaffold CRUD operations, or generate boilerplate code for a database table. The skill reads Prisma schema to understand table structure, then generates Model, DAO, Service, Controller, Route files and pkg.cj exports in Cangjie language. Trigger when user mentions "generate CRUD", "create module", "scaffold", "new table", "add entity", or asks to create database operations for any table like "为xxx表生成CRUD" or "创建xxx模块".
---

# CRUD Generator Skill

为 UCToo V4 生成标准 CRUD 模块，包含 DAO 层。

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

### 步骤 2: 分析 Schema

1. **读取 Prisma schema**:
   - 读取 `apps/backend/prisma/uctoo/schema.prisma` 获取表结构
   - 解析字段类型、可空标志、默认值
   - 识别主键和关系

2. **字段类型映射**:
   - String → String / ?String
   - Int → Int32 / ?Int32
   - Float → Float64 / ?Float64
   - Boolean → Bool / ?Bool
   - DateTime → DateTime / ?DateTime

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

// 准备字段定义
const fields = [
  { name: 'id', dbName: 'id', camelName: 'id', type: 'String', isPrimaryKey: true, isOptional: false },
  { name: 'name', dbName: 'name', camelName: 'name', type: 'String', isPrimaryKey: false, isOptional: false },
  // ... 其他字段
]

// 生成entity模块
await generateModule({
  tableName: 'entity',
  dbName: 'uctoo',
  fields: fields,
  outputDir: './src/app'
})

// 生成uctoo_user模块（使用同一个函数）
await generateModule({
  tableName: 'uctoo_user',
  dbName: 'uctoo',
  fields: uctooUserFields,
  outputDir: './src/app'
})

// 生成任何其他表的模块（都使用同一个函数）
await generateModule({
  tableName: 'your_table',
  dbName: 'uctoo',
  fields: yourTableFields,
  outputDir: './src/app'
})
```

### 方式二：通过技能交互

**用户**: "为 entity 表生成 CRUD"

**技能执行流程**:
```
1. 分析 Prisma schema 中的 entity 表结构
2. 提取字段定义
3. 调用 generateModule({ tableName: 'entity', ... })
4. 生成 Model, DAO, Service, Controller, Route 文件
5. 显示生成的代码供审查
```

**用户**: "为 uctoo_user 表生成 CRUD"

**技能执行流程**:
```
1. 分析 Prisma schema 中的 uctoo_user 表结构
2. 提取字段定义
3. 调用 generateModule({ tableName: 'uctoo_user', ... })  // 使用同一个函数
4. 生成 Model, DAO, Service, Controller, Route 文件
5. 显示生成的代码供审查
```

### 方式三：批量生成多个表

```javascript
import { generateModule } from './scripts/generate-from-template-v2.js'

const tables = [
  { tableName: 'entity', fields: entityFields },
  { tableName: 'uctoo_user', fields: uctooUserFields },
  { tableName: 'agent_skills', fields: agentSkillsFields },
  // ... 其他表
]

// 使用循环批量生成
for (const table of tables) {
  await generateModule({
    tableName: table.tableName,
    dbName: 'uctoo',
    fields: table.fields,
    outputDir: './src/app'
  })
  console.log(`✅ ${table.tableName} 模块生成完成`)
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

// ❌ 错误：复制粘贴生成逻辑
function generateEntity() { /* 复制的代码 */ }
function generateUctooUser() { /* 复制的代码 */ }
function generateAgentSkills() { /* 复制的代码 */ }
```

**应该这样做**：

```javascript
// ✅ 正确：使用统一的生成函数
import { generateModule } from './scripts/generate-from-template-v2.js'

await generateModule({ tableName: 'entity', ... })
await generateModule({ tableName: 'uctoo_user', ... })
await generateModule({ tableName: 'agent_skills', ... })
```

## 字段类型映射

| Prisma 类型 | Cangjie 类型 | 默认值 |
|-------------|--------------|--------|
| String | String | "" |
| String? | ?String | None<String> |
| Int | Int32 | 0 |
| Float | Float64 | 0.0 |
| Boolean | Bool | false |
| DateTime | DateTime | DateTime.now() |
| DateTime? | ?String | "" (ISO字符串) |
| @db.Uuid | String | "" |

## Prisma Schema 解析

读取 `schema.prisma` 时，提取：

```prisma
model entity {
  id            String     @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  link          String     @db.VarChar
  privacy_level Int        @default(0)
  stars         Float      @default(0)
  description   String?    @db.VarChar
  created_at    DateTime   @default(now()) @db.Timestamptz(6)
  updated_at    DateTime   @default(now()) @db.Timestamptz(6)
  deleted_at    DateTime?  @db.Timestamptz(6)
  creator       String     @db.Uuid
}
```

生成对应的 Cangjie 字段:
- `id: String` - 主键
- `link: String` - 必填字符串
- `privacyLevel: Int32` - 从 privacy_level 映射
- `stars: Float64` - 浮点字段
- `description: ?String` - 可空字符串
- `createdAt: DateTime` - 时间戳
- `deletedAt: ?String` - 可空，存储为 ISO 字符串

## 错误处理

- **表在 schema 中不存在**: 询问用户有效的表名
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

**重要**: 生成的路由会自动通过 `AutoRouteRegistry` 注册，无需手动添加！

#### 自动注册机制

项目已实现自动路由注册机制（位于 `src/app/registry/AutoRouteRegistry.cj`），会自动注册所有CRUD路由：

```cangjie
// main.cj 中已配置
private func setupRoutes(): Unit {
    // 使用自动路由注册器注册所有路由
    let routeRegistry = AutoRouteRegistry(router)
    routeRegistry.registerAllRoutes()
    
    // 所有生成的CRUD路由都会自动注册
    // 无需手动添加！
}
```

#### 新增路由的自动注册

当使用 crud-generator 生成新模块时，只需在 `AutoRouteRegistry.cj` 的 `registerCrudRoutes()` 方法中添加一行注册代码：

```cangjie
// 在 AutoRouteRegistry.cj 的 registerCrudRoutes() 方法中添加：

// {Table}路由
let {table}Service = {Table}Service()
let {table}Controller = {Table}Controller({table}Service)
let {table}Route = {Table}Route(router, {table}Controller)
{table}Route.register()
logger.info("✓ {Table}Route registered")
```

**示例**：生成 `uctoo_session` 模块后，添加：

```cangjie
// UctooSession路由
let uctooSessionService = UctooSessionService()
let uctooSessionController = UctooSessionController(uctooSessionService)
let uctooSessionRoute = UctooSessionRoute(router, uctooSessionController)
uctooSessionRoute.register()
logger.info("✓ UctooSessionRoute registered")
```

#### 复合主键表的特殊处理

对于复合主键表（如 `user_has_group`, `group_has_permission`），需要特殊处理：

```cangjie
// 复合主键表需要DAO参数
let userHasGroupDAO = // TODO: 解决DAO实例化问题
let userHasGroupService = UserHasGroupService(userHasGroupDAO)
let userHasGroupController = UserHasGroupController(userHasGroupService)
let userHasGroupRoute = UserHasGroupRoute(router, userHasGroupController)
userHasGroupRoute.register()
logger.info("✓ UserHasGroupRoute registered")
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
