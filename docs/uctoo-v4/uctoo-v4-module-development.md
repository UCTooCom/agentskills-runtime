# uctoo V4.0 模块开发指南

## 文档信息
- **版本**: 3.0.0
- **创建日期**: 2026-03-13
- **更新日期**: 2026-03-24
- **适用范围**: uctoo V4.0 应用服务器

## 1. 概述

本文档介绍如何在 uctoo V4.0 中开发符合 uctoo 架构规范的数据模块。遵循本指南可以确保：
- 与 backend 项目架构一致
- 支持标准 CRUD 操作
- 支持软删除和权限控制
- 遵循 UMI 全栈模型同构设计
- **V4新增**: DAO层分离数据访问逻辑

## 2. 模块结构

每个数据表对应一个完整的模块，包含以下文件：

```
src/app/
├── models/{database}/{Table}PO.cj        # 数据模型
├── dao/{database}/{Table}DAO.cj          # 数据访问层 (V4新增)
├── services/{database}/{Table}.cj        # 服务层
├── controllers/{database}/{table}/       # 控制器目录
│   └── {Table}Controller.cj              # 控制器
└── routes/{database}/{table}/            # 路由目录
    └── {Table}Route.cj                   # 路由定义
```

### 2.1 V4与V3架构差异

| 层级 | V3 (backend) | V4 (agentskills-runtime) |
|------|-------------|-------------------------|
| Model | ✅ | ✅ |
| DAO | ❌ | ✅ **新增** |
| Service | ✅ | ✅ |
| Controller | ✅ | ✅ |
| Route | ✅ | ✅ |

**DAO层的作用**：
- 封装所有数据库操作
- 使用Fountain ORM的`setSql`方法构建查询
- 不过滤软删除数据，返回完整数据集
- Service层通过DAO接口访问数据

## 3. 开发步骤

### 3.1 步骤一：定义数据模型

在 `src/app/models/{database}/` 目录下创建 `{Table}PO.cj` 文件：

```cangjie
package magic.app.models.{database}

import std.time.DateTime
import f_orm.macros.{QueryMappersGenerator, ORMField}
import f_orm.*

@QueryMappersGenerator["{table_name}"]  // 数据库表名
public class {Table}PO {
    @ORMField[true]                      // 主键
    public var id: String = ""
    
    public var name: String = ""         // 普通字段
    
    @ORMField[false "column_name"]       // 列名映射
    public var fieldName: String = ""
    
    public var description: ?String = None<String>  // 可空字段
    
    public var createdAt: DateTime = DateTime.now() // 时间字段
    
    public init() {}
    
    // toJson方法用于API响应
    public func toJson(): String {
        // 实现JSON序列化
    }
}
```

**字段类型对应关系**：

| Prisma 类型 | Cangjie 类型 | 说明 |
|------------|-------------|------|
| String | String | 字符串 |
| Int | Int32 | 整数 |
| Float | Float64 | 浮点数 |
| Boolean | Bool | 布尔值 |
| DateTime | DateTime | 日期时间 |
| String? | ?String | 可空字符串 |

**ORM 注解说明**：

| 注解 | 用途 | 示例 |
|------|------|------|
| `@QueryMappersGenerator["table"]` | 指定表名 | `@QueryMappersGenerator["entity"]` |
| `@ORMField[true]` | 标记主键 | `@ORMField[true]` |
| `@ORMField[false "column"]` | 列名映射 | `@ORMField[false "privacy_level"]` |

### 3.2 步骤二：创建DAO层 (V4新增)

在 `src/app/dao/{database}/` 目录下创建 `{Table}DAO.cj` 文件：

```cangjie
package magic.app.dao.{database}

import std.collection.*
import std.time.DateTime
import f_orm.*
import f_orm.macros.*
import f_orm.sql.{Pagination, SqlPartial}
import magic.app.models.{database}.{Table}PO
import magic.log.LogUtils

/**
 * {Table}DAO - {表描述}数据访问接口
 * 
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface {Table}DAO <: RootDAO {
    prop executor: SqlExecutor
    
    // ==================== 插入操作 ====================
    
    /**
     * 插入记录（id由数据库自动生成UUID）
     */
    func insert{Table}(entity: {Table}PO): String {
        executor.setSql('''
            insert into {table_name}(
                field1, field2, creator, created_at, updated_at
            ) values(
                ${arg(entity.field1)}, ${arg(entity.field2)},
                ${arg(entity.creator)}, ${arg(entity.createdAt)},
                ${arg(entity.updatedAt)}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }
    
    // ==================== 单条查询 ====================
    
    /**
     * 根据ID查询（不过滤软删除）
     */
    func findById(id: String): Option<{Table}PO> {
        executor.setSql('''
            select * from {table_name} where id = ${arg(id)}
        ''').first<{Table}PO>()
    }
    
    // ==================== 列表查询 ====================
    
    /**
     * 分页查询所有记录
     */
    func findAllPage(page: Int64, size: Int64): Pagination<{Table}PO> {
        executor.page<{Table}PO>('''
            select * from {table_name} order by created_at desc
        ''', size, page: page)
    }
    
    // ==================== 更新操作 ====================
    
    /**
     * 更新记录
     */
    func update{Table}(entity: {Table}PO): Int64 {
        executor.setSql('''
            update {table_name} set
                field1 = ${arg(entity.field1)},
                field2 = ${arg(entity.field2)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }
    
    // ==================== 删除操作 ====================
    
    /**
     * 软删除
     */
    func softDeleteById(id: String): Int64 {
        executor.setSql('''
            update {table_name} set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 恢复软删除
     */
    func restoreById(id: String): Int64 {
        executor.setSql('''
            update {table_name} set deleted_at = null where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 硬删除
     */
    func deleteById(id: String): Int64 {
        executor.setSql('''
            delete from {table_name} where id = ${arg(id)}
        ''').delete
    }
    
    // ==================== 统计操作 ====================
    
    /**
     * 统计总数
     */
    func countAll(): Int64 {
        executor.setSql('''
            select count(*) from {table_name}
        ''').first<Int64>() ?? 0
    }
}
```

**DAO层设计原则**：

1. **使用 `setSql` 方法**：避免使用 `FROM().WHERE().first()` 链式调用，因为 `first()` 方法不使用 `sqlgen`，会导致WHERE条件被忽略。

2. **不过滤软删除数据**：所有查询方法返回完整数据集，包括已软删除的数据。软删除数据的显示/过滤由API使用方根据 `deleted_at` 字段决定。

3. **分页查询使用 `executor.page()`**：
   ```cangjie
   executor.page<{Table}PO>('select * from table', size, page: page)
   ```

4. **单条查询使用 `setSql().first()`**：
   ```cangjie
   executor.setSql('select * from table where id = ${arg(id)}').first<{Table}PO>()
   ```

### 3.3 步骤三：创建服务层

在 `src/app/services/{database}/` 目录下创建 `{Table}.cj` 文件：

```cangjie
package magic.app.services.{database}

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.{database}.{Table}PO
import magic.app.dao.{database}.{Table}DAO
import magic.app.core.response.APIResult
import magic.log.LogUtils

/**
 * {Table}Service - {表描述}服务类
 * 
 * 提供业务逻辑处理，使用DAO层进行数据访问
 */
public class {Table}Service {
    private var executor: ?SqlExecutor = None<SqlExecutor>
    
    private func getExecutor(): SqlExecutor {
        if (let Some(exe) <- executor) {
            return exe
        }
        let exe = ORM.executor()
        executor = Some<SqlExecutor>(exe)
        return exe
    }
    
    public init() {}
    
    /**
     * 创建记录
     */
    public func create(entity: {Table}PO): APIResult<{Table}PO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            let id = getExecutor().insert{Table}(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<{Table}PO>(entity)
            } else {
                return APIResult<{Table}PO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<{Table}PO>(false, e.message)
        }
    }
    
    /**
     * 更新记录
     */
    public func update(entityId: String, entity: {Table}PO): APIResult<{Table}PO> {
        try {
            let existing = getExecutor().findById(entityId)
            
            if (existing.isNone()) {
                return APIResult<{Table}PO>(false, "记录不存在")
            }
            
            entity.updatedAt = DateTime.now()
            entity.id = entityId
            
            let rows = getExecutor().update{Table}(entity)
            
            if (rows > 0) {
                return APIResult<{Table}PO>(entity)
            } else {
                return APIResult<{Table}PO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<{Table}PO>(false, e.message)
        }
    }
    
    /**
     * 删除记录
     * @param force true: 硬删除，false: 软删除
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "记录不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteById(entityId)
            } else {
                rows = getExecutor().softDeleteById(entityId)
            }
            
            if (rows > 0) {
                return APIResult<Bool>(true)
            } else {
                return APIResult<Bool>(false, "删除失败")
            }
        } catch (e: Exception) {
            return APIResult<Bool>(false, e.message)
        }
    }
    
    /**
     * 恢复软删除的记录
     */
    public func restore(entityId: String): APIResult<{Table}PO> {
        try {
            let rows = getExecutor().restoreById(entityId)
            
            if (rows > 0) {
                let result = getExecutor().findById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<{Table}PO>(entity)
                } else {
                    return APIResult<{Table}PO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<{Table}PO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<{Table}PO>(false, e.message)
        }
    }
    
    /**
     * 根据ID获取记录
     * 
     * 设计说明：
     * - 返回该ID对应的数据，无论是否被软删除
     * - 这样API使用方可以实现回收站功能
     */
    public func getById(entityId: String): APIResult<{Table}PO> {
        try {
            let result = getExecutor().findById(entityId)
            
            if (let Some(entity) <- result) {
                return APIResult<{Table}PO>(entity)
            } else {
                return APIResult<{Table}PO>(false, "未找到该记录")
            }
        } catch (e: Exception) {
            return APIResult<{Table}PO>(false, e.message)
        }
    }
    
    /**
     * 获取列表（分页）
     */
    public func getList(page: Int32, pageSize: Int32): (ArrayList<{Table}PO>, Int64) {
        let pagination = getExecutor().findAllPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
}
```

### 3.4 步骤四：创建控制器

在 `src/app/controllers/{database}/{table}/` 目录下创建 `{Table}Controller.cj` 文件：

```cangjie
package magic.app.controllers.{database}.{table}

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.response.{APIError, APIResult}
import magic.app.models.{database}.{Table}PO
import magic.app.services.{database}.{Table}Service
import magic.log.LogUtils
import std.collection.{HashMap, Map, ArrayList}
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonFloat, JsonBool, JsonArray}

public class {Table}Controller {
    private var service: {Table}Service
    
    public init(service: {Table}Service) {
        this.service = service
    }
    
    public func add(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = parseBody(req)
            if (let Some(b) <- body) {
                let entity = mapToEntity(b)
                let result = service.create(entity)
                if (result.success) {
                    if (let Some(data) <- result.data) {
                        res.status(200).json(data.toJson())
                    } else {
                        res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"创建失败\"}")
                    }
                } else {
                    let reason = result.reason ?? "创建失败"
                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
                }
            } else {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"提交数据格式错误\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }
    
    public func edit(req: HttpRequest, res: HttpResponse): Unit {
        // 实现编辑逻辑，支持单个编辑和批量编辑
        // 支持恢复软删除数据 (deleted_at === "0")
    }
    
    public func delete(req: HttpRequest, res: HttpResponse): Unit {
        // 实现删除逻辑，支持软删除和硬删除
        // force=1 表示硬删除
    }
    
    public func getSingle(req: HttpRequest, res: HttpResponse): Unit {
        // 实现单个查询逻辑
    }
    
    public func getManyWithPathParams(req: HttpRequest, res: HttpResponse): Unit {
        // 实现分页查询逻辑
    }
    
    private func parseBody(req: HttpRequest): ?Map<String, Any> {
        // 解析请求体
    }
    
    private func mapToEntity(map: Map<String, Any>): {Table}PO {
        // 将Map转换为实体对象
    }
}
```

### 3.5 步骤五：注册路由

在 `src/app/routes/{database}/{table}/` 目录下创建 `{Table}Route.cj` 文件：

```cangjie
package magic.app.routes.{database}.{table}

import magic.app.core.router.Router
import magic.app.controllers.{database}.{table}.{Table}Controller
import magic.app.services.{database}.{Table}Service
import magic.app.middlewares.auth.requireUser

public class {Table}Route {
    public static func register(router: Router): Unit {
        let service = {Table}Service()
        let controller = {Table}Controller(service)
        
        // POST /api/v1/{database}/{table}/add - 新增
        router.post("/api/v1/{database}/{table}/add", controller.add)
        
        // POST /api/v1/{database}/{table}/edit - 编辑
        router.post("/api/v1/{database}/{table}/edit", controller.edit)
        
        // POST /api/v1/{database}/{table}/del - 删除
        router.post("/api/v1/{database}/{table}/del", controller.delete)
        
        // GET /api/v1/{database}/{table}/:id - 查询单条
        router.get("/api/v1/{database}/{table}/:id", controller.getSingle)
        
        // GET /api/v1/{database}/{table}/:limit/:page - 分页查询
        router.get("/api/v1/{database}/{table}/:limit/:page", controller.getManyWithPathParams)
    }
}
```

### 3.6 步骤六：导出模块

在对应的 `pkg.cj` 文件中添加导出：

**models/{database}/pkg.cj**:
```cangjie
public import magic.app.models.{database}.{Table}PO
```

**dao/{database}/pkg.cj** (V4新增):
```cangjie
public import magic.app.dao.{database}.{Table}DAO
```

**services/{database}/pkg.cj**:
```cangjie
public import magic.app.services.{database}.{Table}Service
```

**controllers/{database}/pkg.cj**:
```cangjie
public import magic.app.controllers.{database}.{table}.{Table}Controller
```

**routes/{database}/pkg.cj**:
```cangjie
public import magic.app.routes.{database}.{table}.{Table}Route
```

## 4. 代码生成区域标识

### 4.1 概述

为了支持标准CRUD代码生成与定制开发的共存，UCToo V4采用注释标识区机制。代码生成器只覆盖特定注释标识区内的内容，区域外是定制开发区域，确保后续的定制开发和个性化拓展不会被标准CRUD生成的代码覆盖。

### 4.2 标识格式

```cangjie
//#region AutoCreateCode

// ... 自动生成的标准CRUD代码 ...

//#endregion AutoCreateCode

// ========== 定制开发方法（在此区域添加自定义方法）==========
```

### 4.3 各层标识位置

#### Model层 (无标识区)

Model层通常不需要标识区，因为数据模型结构相对稳定，字段变更时需要整体更新。

#### DAO层

```cangjie
@DAO
public interface {Table}DAO <: RootDAO {
    prop executor: SqlExecutor
    
    //#region AutoCreateCode
    
    // ==================== 插入操作 ====================
    func insert{Table}(entity: {Table}PO): String { ... }
    
    // ==================== 查询操作 ====================
    func findById(id: String): Option<{Table}PO> { ... }
    
    // ==================== 更新操作 ====================
    func update{Table}(entity: {Table}PO): Int64 { ... }
    
    // ==================== 删除操作 ====================
    func softDeleteById(id: String): Int64 { ... }
    func restoreById(id: String): Int64 { ... }
    func deleteById(id: String): Int64 { ... }
    
    // ==================== 统计操作 ====================
    func countAll(): Int64 { ... }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
    
    // 自定义查询方法
    func findByCustomCondition(param: String): ArrayList<{Table}PO> { ... }
}
```

#### Service层

```cangjie
public class {Table}Service {
    private var executor: ?SqlExecutor = None<SqlExecutor>
    
    private func getExecutor(): SqlExecutor { ... }
    
    public init() {}
    
    //#region AutoCreateCode
    
    public func create(entity: {Table}PO): APIResult<{Table}PO> { ... }
    public func update(entityId: String, entity: {Table}PO): APIResult<{Table}PO> { ... }
    public func delete(entityId: String, force: Bool): APIResult<Bool> { ... }
    public func restore(entityId: String): APIResult<{Table}PO> { ... }
    public func getById(entityId: String): APIResult<{Table}PO> { ... }
    public func getList(page: Int32, pageSize: Int32): (ArrayList<{Table}PO>, Int64) { ... }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
    
    // 自定义业务逻辑
    public func customBusinessMethod(param: String): APIResult<{Table}PO> { ... }
}
```

#### Controller层

```cangjie
public class {Table}Controller {
    private var service: {Table}Service
    
    public init(service: {Table}Service) {
        this.service = service
    }
    
    //#region AutoCreateCode
    
    public func add(req: HttpRequest, res: HttpResponse): Unit { ... }
    public func edit(req: HttpRequest, res: HttpResponse): Unit { ... }
    public func delete(req: HttpRequest, res: HttpResponse): Unit { ... }
    public func getSingle(req: HttpRequest, res: HttpResponse): Unit { ... }
    public func getManyWithPathParams(req: HttpRequest, res: HttpResponse): Unit { ... }
    
    // 辅助方法
    private func parseBody(req: HttpRequest): ?Map<String, Any> { ... }
    private func mapToEntity(map: Map<String, Any>): {Table}PO { ... }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
    
    // 自定义接口
    public func customEndpoint(req: HttpRequest, res: HttpResponse): Unit { ... }
}
```

#### Route层

```cangjie
public class {Table}Route {
    private var router: Router
    private var controller: {Table}Controller
    
    public init(router: Router, controller: {Table}Controller) {
        this.router = router
        this.controller = controller
    }
    
    //#region AutoCreateCode
    
    public func register(): Router {
        router.post("/api/v1/{database}/{table}/add", controller.add)
        router.post("/api/v1/{database}/{table}/edit", controller.edit)
        router.post("/api/v1/{database}/{table}/del", controller.delete)
        router.get("/api/v1/{database}/{table}/:id", controller.getSingle)
        router.get("/api/v1/{database}/{table}/:limit/:page", controller.getManyWithPathParams)
        return router
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义路由）==========
    
    // 自定义路由注册
    public func registerCustomRoutes(): Router {
        router.post("/api/v1/{database}/{table}/custom", controller.customEndpoint)
        return router
    }
}
```

### 4.4 代码生成器行为

当使用 `crud-generator` 技能重新生成代码时：

1. **检测标识区**：生成器会检测文件中是否存在 `//#region AutoCreateCode` 和 `//#endregion AutoCreateCode` 标识
2. **保留定制代码**：标识区外的代码会被完整保留
3. **更新自动代码**：只更新标识区内的标准CRUD代码
4. **首次生成**：如果文件不存在，会创建包含完整标识区的新文件

### 4.5 最佳实践

1. **定制代码位置**：始终将定制开发代码放在 `//#endregion AutoCreateCode` 之后
2. **不要修改标识区**：不要修改或删除 `//#region` 和 `//#endregion` 标识
3. **版本控制**：在重新生成代码前，建议提交当前代码到版本控制系统
4. **代码审查**：重新生成后，检查定制代码是否完整保留

## 5. 最佳实践

### 5.1 命名规范

| 类型 | 规范 | 示例 |
|------|------|------|
| 模型类 | PascalCase + PO | EntityPO |
| DAO接口 | PascalCase + DAO | EntityDAO |
| 服务类 | PascalCase + Service | EntityService |
| 控制器类 | PascalCase + Controller | EntityController |
| 路由类 | PascalCase + Route | EntityRoute |
| 文件名 | PascalCase | EntityPO.cj |
| 目录名 | 小写 | entity/ |

### 5.2 错误处理

统一使用 APIError 返回错误：

```cangjie
// 参数错误
res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"参数错误\"}")

// 认证错误
res.status(401).json("{\"errno\":\"40101\",\"errmsg\":\"未授权访问\"}")

// 资源不存在
res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"资源不存在\"}")

// 服务器错误
res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"服务器内部错误\"}")
```

### 5.3 日志记录

使用 LogUtils：

```cangjie
import magic.log.LogUtils

// 信息日志
LogUtils.info("{Table}Service", "操作描述")

// 错误日志
LogUtils.error("{Table}Service", "错误描述: ${e.message}")
```

### 5.4 软删除设计

**DAO层**：不过滤软删除数据
```cangjie
func findById(id: String): Option<{Table}PO> {
    executor.setSql('''
        select * from {table_name} where id = ${arg(id)}
    ''').first<{Table}PO>()
}
```

**API使用方**：根据 `deleted_at` 字段判断数据状态
- `deleted_at` 为空：正常数据
- `deleted_at` 有值：已软删除数据

**恢复软删除**：通过 `edit` 接口，设置 `deleted_at = "0"`

### 5.5 ORM查询注意事项

**正确方式**：使用 `setSql` 方法
```cangjie
// 单条查询
executor.setSql('select * from table where id = ${arg(id)}').first<{Table}PO>()

// 列表查询
executor.setSql('select * from table').list<{Table}PO>()

// 分页查询
executor.page<{Table}PO>('select * from table', size, page: page)
```

**错误方式**：避免使用 `FROM().WHERE().first()`
```cangjie
// ❌ 错误：first() 不使用 sqlgen，WHERE条件会被忽略
executor.FROM<{Table}PO>()
    .WHERE{'id = ${arg(id)}'}
    .first<{Table}PO>()

// ✅ 正确：使用 setSql
executor.setSql('select * from table where id = ${arg(id)}').first<{Table}PO>()
```

## 6. 完整示例

参考已实现的 entity 模块：
- 模型: [EntityPO.cj](../../src/app/models/uctoo/EntityPO.cj)
- DAO: [EntityDAO.cj](../../src/app/dao/uctoo/EntityDAO.cj)
- 服务: [EntityService.cj](../../src/app/services/uctoo/EntityService.cj)
- 控制器: [EntityController.cj](../../src/app/controllers/uctoo/entity/EntityController.cj)
- 路由: [EntityRoute.cj](../../src/app/routes/uctoo/entity/EntityRoute.cj)

## 7. 使用 crud-generator 自动生成 CRUD 模块

### 7.1 概述

`crud-generator` 技能可以自动生成数据库表的标准 CRUD 模块代码，包括 Model、DAO、Service、Controller、Route 五层完整代码，并自动注册路由。

### 7.2 使用方法

```bash
# 进入 crud-generator 脚本目录
cd apps/agentskills-runtime/skills/crud-generator/scripts

# 运行生成脚本
node generate-from-template-v2.js
```

或在代码中调用：

```javascript
import { generateModule } from './generate-from-template-v2.js'

await generateModule({
    tableName: 'my_table',      // 数据库表名
    dbName: 'uctoo',            // 数据库名
    fields: [                   // 字段定义
        { name: 'id', dbName: 'id', camelName: 'id', type: 'String', isPrimaryKey: true, isOptional: false },
        { name: 'name', dbName: 'name', camelName: 'name', type: 'String', isPrimaryKey: false, isOptional: false },
        // ... 更多字段
    ],
    outputDir: '/path/to/src/app'
})
```

### 7.3 生成内容

`crud-generator` 会自动生成以下文件：

| 文件 | 路径 | 说明 |
|------|------|------|
| Model | `models/{db}/{Table}PO.cj` | 数据模型，包含 ORM 注解 |
| DAO | `dao/{db}/{Table}DAO.cj` | 数据访问接口 |
| Service | `services/{db}/{Table}Service.cj` | 业务逻辑层 |
| Controller | `controllers/{db}/{table}/{Table}Controller.cj` | HTTP 控制器 |
| Route | `routes/{db}/{table}/{Table}Route.cj` | 路由定义 |

### 7.4 自动路由注册

生成完成后，`crud-generator` 会自动更新 `AutoRouteConfig.cj`：

1. **添加导入语句**：Route、Controller、Service 的 import
2. **添加路由配置**：在 `initRegistry` 方法中添加 `RouteEntry`
3. **自动计算优先级**：新路由优先级 = 最大优先级 + 10

**无需手动修改任何路由注册文件**。

### 7.5 复合主键支持

对于复合主键表（如 `role_has_permission`），生成器会：

1. 检测多个 `isPrimaryKey: true` 的字段
2. 生成使用复合键的 DAO 方法
3. 在路由配置中添加 `(复合主键)` 注释

### 7.6 关键字冲突处理

生成器会自动检测仓颉保留关键字并重命名：

```
⚠️  检测到关键字冲突，已自动重命名字段：
   type → permissionType (数据库列: type)
```

## 8. 仓颉反射机制限制与路由自动注册

### 8.1 为什么不能实现"纯反射自动发现"

在使用 `crud-generator` 生成新的 CRUD 模块后，必须修改 `AutoRouteConfig.cj` 才能实现路由注册，而不是仅生成标准 CRUD 模块就自动注册。这是由仓颉反射机制的固有限制决定的。

### 8.2 仓颉反射机制的核心限制

#### 限制一：无法发现未加载的类型

```cangjie
// 仓颉反射只能获取已加载包中的类型
let packageInfo = PackageInfo.of("magic.app.routes")

// 问题：如果 Route 类未被任何代码引用，它不会被加载
// 反射无法"发现"一个完全不存在的引用
```

**关键问题**：新生成的 `XxxRoute.cj` 文件，如果没有代码显式 `import` 它，它就不会被加载到运行时，反射也就无法发现它。

#### 限制二：只能访问公共成员

```cangjie
// 反射只能获取 public 成员
let typeInfo = TypeInfo.of(MyClass)
let methods = typeInfo.publicMethods  // 只有 public 方法
let fields = typeInfo.publicFields    // 只有 public 字段
```

#### 限制三：没有类路径扫描能力

Java 可以：
```java
// Java 可以扫描类路径下的所有类
Reflections reflections = new Reflections("com.example.routes");
Set<Class<?>> routes = reflections.getTypesAnnotatedWith(Route.class);
```

仓颉没有类似机制：
- 无法扫描文件系统找到所有 `.cj` 文件
- 无法动态加载未引用的类
- 没有"类路径"概念

#### 限制四：注解无法替代显式引用

即使使用 `@AutoRoute` 注解标记路由：
```cangjie
@AutoRoute(tableName: "user", routePath: "/api/user")
public class UserRoute { ... }
```

**问题**：注解信息只有在类被加载后才能通过反射读取。如果没有任何代码 `import UserRoute`，注解永远不会被处理。

### 8.3 为什么必须修改 AutoRouteConfig.cj

```
┌─────────────────────────────────────────────────────────────┐
│                    生成新 CRUD 模块                          │
│  UserRoute.cj, UserController.cj, UserService.cj            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              问题：这些类没有任何代码引用                       │
│                                                              │
│   AutoRouteConfig.cj 中没有 import UserRoute                 │
│   → UserRoute 不会被加载                                      │
│   → 反射无法发现 @AutoRoute 注解                              │
│   → 路由无法自动注册                                          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              解决方案：显式添加引用                            │
│                                                              │
│   crud-generator 自动修改 AutoRouteConfig.cj                 │
│   → 添加 import UserRoute                                    │
│   → 添加 RouteEntry 配置                                     │
│   → 类被加载，路由被注册                                       │
└─────────────────────────────────────────────────────────────┘
```

### 8.4 与其他语言的对比

| 语言 | 机制 | 是否需要显式引用 |
|------|------|------------------|
| Java Spring | 类路径扫描 + 反射 | ❌ 不需要 |
| Go | `init()` 函数自动执行 | ❌ 不需要（但需要 import） |
| Rust | 过程宏 + 构建时生成 | ❌ 不需要 |
| **仓颉** | 反射 + 配置驱动 | ✅ **需要** |

### 8.5 仓颉的替代方案：配置驱动

由于反射限制，我们采用**配置驱动**方案：

```cangjie
// AutoRouteConfig.cj - 显式列出所有路由
public static func initRegistry(registry: RouteRegistry): Unit {
    registry.add(RouteEntry("user", "/api/user", 10, true, { router =>
        let route = UserRoute(router, UserController(UserService()))
        route.register()
    }))
    // ... 更多路由
}
```

**优点**：
- 编译时类型安全
- 无运行时反射开销
- 明确的依赖关系

**缺点**：
- 需要手动/自动维护配置文件

### 8.6 总结

仓颉反射机制的限制导致无法实现"零配置自动发现"：

1. **无法发现未加载类型** - 新生成的类如果没有被引用，反射无法发现
2. **没有类路径扫描** - 无法自动找到所有路由类
3. **注解依赖类加载** - 注解信息只有在类加载后才能读取

因此，`crud-generator` 必须在生成代码后，**显式修改 AutoRouteConfig.cj** 添加引用，才能让路由被加载和注册。这是仓颉语言设计的固有限制，而非实现问题。

## 9. 参考文档

- [子系统架构说明](./uctoo-v4-architecture.md)
- [uctoo API设计规范](../../../backend/docs/uctoo-api-design-specification.md)
- [uctoo 模块设计规范](../../../backend/docs/uctoo-module-design-specification.md)
- [Fountain ORM规范](./uctoo-v4-orm-specification.md)
