# uctoo V4.0 模块开发指南 (重构版)

## 文档信息
- **版本**: 4.0.0
- **创建日期**: 2026-03-13
- **更新日期**: 2026-04-17
- **适用范围**: uctoo V4.0 应用服务器
- **重构说明**: 基于entity模块优化重构方案更新

## 1. 概述

本文档介绍如何在 uctoo V4.0 中开发符合 uctoo 架构规范的数据模块。遵循本指南可以确保：
- 与 backend 项目架构一致
- 支持标准 CRUD 操作
- 支持软删除和权限控制
- 遵循 UMI 全栈模型同构设计
- **V4新增**: DAO层分离数据访问逻辑
- **V4优化**: 代码结构优化,更适合作为模板

## 2. 模块结构

每个数据表对应一个完整的模块，包含以下文件：

```
src/app/
├── models/{database}/{Table}PO.cj        # 数据模型
├── dao/{database}/{Table}DAO.cj          # 数据访问层 (V4新增)
├── services/{database}/{Table}Service.cj # 服务层
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
/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.models.{database}

//#region AutoCreateCode

import std.time.DateTime
import f_orm.macros.{QueryMappersGenerator, ORMField}
import f_data.macros.DataAssist
import f_data.{ObjectData, Data, DataConversionFlag, ObjectFields, MutableField, DataObject, f_data_tryFromData}
import f_orm.*
import json4cj.JsonValueSerializable
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonFloat, JsonBool, JsonNull}

/**
 * {Table}PO - {表描述}持久化对象
 * 
 * 对应数据库表: {table_name}
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["{table_name}"]
public class {Table}PO {
    @ORMField['id']
    public var id: String = ""
    
    @ORMField['name']
    public var name: String = ""
    
    @ORMField['description']
    public var description: Option<String> = None<String>
    
    @ORMField['creator']
    public var creator: Option<String> = None<String>
    
    @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()
    
    @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()
    
    @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>
    
    public init() {}
    
    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        addFieldToJson(map, "id", this.id)
        addFieldToJson(map, "name", this.name)
        addOptionFieldToJson(map, "description", this.description)
        addOptionFieldToJson(map, "creator", this.creator)
        addFieldToJson(map, "created_at", this.createdAt)
        addFieldToJson(map, "updated_at", this.updatedAt)
        addOptionFieldToJson(map, "deleted_at", this.deletedAt)
        return JsonObject(map)
    }
    
    /// 辅助方法：添加字段到JSON
    private func addFieldToJson<T>(map: HashMap<String, JsonValue>, name: String, value: T): Unit 
        where T <: JsonValueSerializable<T> {
        map.add(name, value.toJsonValue())
    }
    
    /// 辅助方法：添加Option字段到JSON
    private func addOptionFieldToJson<T>(map: HashMap<String, JsonValue>, name: String, value: Option<T>): Unit 
        where T <: JsonValueSerializable<T> {
        map.add(name, optionToJsonValue(value))
    }
    
    /// 辅助方法：将 Option<T> 转换为 JsonValue
    private static func optionToJsonValue<T>(opt: Option<T>): JsonValue where T <: JsonValueSerializable<T> {
        if (let Some(v) <- opt) {
            return v.toJsonValue()
        } else {
            return JsonNull()
        }
    }
    
    /// 序列化为 JSON 字符串
    public func toJson(): String {
        return this.toJsonValue().toString()
    }
    
    /// 从 JSON 字符串反序列化
    public static func fromJson(json: String): {Table}PO {
        return {Table}PO.fromJsonValue(JsonValue.fromStr(json))
    }
    
    /// 从 JsonValue 反序列化（由@DataAssist自动生成）
    // public static func fromJsonValue(value: JsonValue): {Table}PO { ... }
}
```

**字段类型对应关系**：

| PostgreSQL 类型 | Cangjie 类型 | 默认值 | 说明 |
|----------------|-------------|--------|------|
| uuid | String | "" | UUID主键 |
| text | String | "" | 文本类型 |
| varchar | String | "" | 变长字符串 |
| int4 | Int32 | 0 | 32位整数 |
| int8 | Int64 | 0 | 64位整数 |
| float8 | Float64 | 0.0 | 双精度浮点 |
| bool | Bool | false | 布尔值 |
| timestamptz | DateTime | DateTime.now() | 时区时间戳 |
| jsonb | String | "" | JSON二进制 |

**ORM 注解说明**：

| 注解 | 用途 | 示例 |
|------|------|------|
| `@QueryMappersGenerator["table"]` | 指定表名 | `@QueryMappersGenerator["entity"]` |
| `@ORMField['id']` | 标记主键 | `@ORMField['id']` |
| `@ORMField['column']` | 列名映射 | `@ORMField['privacy_level']` |
| `@DataAssist[fields]` | 自动生成JSON序列化 | `@DataAssist[fields]` |

**V4优化说明**：
- 使用`@DataAssist[fields]`宏自动生成`fromJsonValue`方法,无需手动编写
- 使用辅助方法简化`toJsonValue`实现
- 删除大量重复的JSON序列化代码

### 3.2 步骤二：创建DAO层 (V4新增)

在 `src/app/dao/{database}/` 目录下创建 `{Table}DAO.cj` 文件：

```cangjie
/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
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
    
    //#region AutoCreateCode
    
    // ==================== 插入操作 ====================
    
    /**
     * 插入记录（id由数据库自动生成UUID）
     */
    func insert{Table}(entity: {Table}PO): String {
        executor.setSql('''
            insert into {table_name}(
                name, description, creator, created_at, updated_at
            ) values(
                ${arg(entity.name)}, ${arg(entity.description)},
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
    func find{Table}ById(id: String): Option<{Table}PO> {
        executor.setSql('''
            select * from {table_name} where id = ${arg(id)}
        ''').first<{Table}PO>()
    }
    
    // ==================== 更新操作 ====================
    
    /**
     * 更新记录
     */
    func update{Table}(entity: {Table}PO): Int64 {
        executor.setSql('''
            update {table_name} set
                name = ${arg(entity.name)},
                description = ${arg(entity.description)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }
    
    // ==================== 删除操作 ====================
    
    /**
     * 软删除
     */
    func softDelete{Table}ById(id: String): Int64 {
        executor.setSql('''
            update {table_name} set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 恢复软删除
     */
    func restore{Table}ById(id: String): Int64 {
        executor.setSql('''
            update {table_name} set deleted_at = null where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 硬删除
     */
    func delete{Table}ById(id: String): Int64 {
        executor.setSql('''
            delete from {table_name} where id = ${arg(id)}
        ''').delete
    }
    
    // ==================== 列表查询 ====================
    
    /**
     * 分页查询所有记录
     */
    func findAll{Table}Page(page: Int64, size: Int64): Pagination<{Table}PO> {
        executor.page<{Table}PO>('''
            select * from {table_name} order by created_at desc
        ''', size, page: page)
    }
    
    /**
     * 分页查询记录列表（按创建者）
     */
    func find{Table}ByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<{Table}PO> {
        executor.page<{Table}PO>('''
            select * from {table_name} where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }
    
    /**
     * 查询所有记录（不分页）
     */
    func listAll{Table}(): ArrayList<{Table}PO> {
        executor.setSql('''
            select * from {table_name} order by created_at desc
        ''').list<{Table}PO>()
    }
    
    /**
     * 批量查询记录
     */
    func find{Table}ByIds(ids: ArrayList<String>): ArrayList<{Table}PO> {
        executor.setSql('''
            select * from {table_name} where id ${IN(ids)}
        ''').list<{Table}PO>()
    }
    
    // ==================== 统计操作 ====================
    
    /**
     * 统计创建者的记录数量
     */
    func count{Table}ByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from {table_name} where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }
    
    /**
     * 统计所有记录数量
     */
    func countAll{Table}(): Int64 {
        executor.setSql('''
            select count(*) from {table_name}
        ''').first<Int64>() ?? 0
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
    
    // 在此区域添加自定义查询方法
    // 例如：按条件查询、批量操作等
}
```

**DAO层设计原则**：

1. **使用 `setSql` 方法**：避免使用 `FROM().WHERE().first()` 链式调用
2. **不过滤软删除数据**：所有查询方法返回完整数据集
3. **标准方法在AutoCreateCode区域**：可被crud-generator覆盖
4. **定制方法在AutoCreateCode区域外**：不会被覆盖

**V4优化说明**：
- 明确区分标准方法和定制方法
- 添加方法分类标识,提高可读性
- 标准方法可被crud-generator覆盖,定制方法保留

### 3.3 步骤三：创建服务层

在 `src/app/services/{database}/` 目录下创建 `{Table}Service.cj` 文件：

```cangjie
/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.{database}

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.{database}.{Table}PO
import magic.app.dao.{database}.{Table}DAO
import magic.app.core.response.APIResult
import magic.app.core.query.{RequestParserService, QueryBuilderService}
import magic.log.LogUtils

/**
 * {Table}Service - {表描述}服务类
 * 
 * 提供业务逻辑处理，使用DAO层进行数据访问
 */
public class {Table}Service {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }
    
    // 查询参数解析服务
    private let requestParser = RequestParserService()
    
    // 查询构建服务
    private let queryBuilder = QueryBuilderService()
    
    public init() {}
    
    //#region AutoCreateCode
    
    /**
     * 创建记录
     */
    public func create(entity: {Table}PO, creatorId: String): APIResult<{Table}PO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            // 只有当用户未指定creator时，才使用登录用户ID
            if (entity.creator.isNone()) {
                entity.creator = Some<String>(creatorId)
            }
            
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
            let existing = getExecutor().find{Table}ById(entityId)
            
            if (existing.isNone()) {
                return APIResult<{Table}PO>(false, "记录不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
            if (entity.name.size > 0) {
                existingEntity.name = entity.name
            }
            if (entity.description.isSome()) {
                existingEntity.description = entity.description
            }
            
            // 设置更新时间和ID
            existingEntity.updatedAt = DateTime.now()
            existingEntity.id = entityId
            
            let rows = getExecutor().update{Table}(existingEntity)
            
            if (rows > 0) {
                return APIResult<{Table}PO>(existingEntity)
            } else {
                return APIResult<{Table}PO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<{Table}PO>(false, e.message)
        }
    }
    
    /**
     * 批量更新记录
     */
    public func updateMultiple(entities: ArrayList<{Table}PO>): APIResult<ArrayList<{Table}PO>> {
        try {
            let updatedEntities = ArrayList<{Table}PO>()
            
            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().update{Table}(entity)
                
                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }
            
            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<{Table}PO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<{Table}PO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<{Table}PO>>(false, e.message)
        }
    }
    
    /**
     * 删除记录
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().find{Table}ById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "记录不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().delete{Table}ById(entityId)
            } else {
                rows = getExecutor().softDelete{Table}ById(entityId)
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
            let rows = getExecutor().restore{Table}ById(entityId)
            
            if (rows > 0) {
                let result = getExecutor().find{Table}ById(entityId)
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
     */
    public func getById(entityId: String): APIResult<{Table}PO> {
        try {
            let result = getExecutor().find{Table}ById(entityId)
            
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
    public func getList(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<{Table}PO>, Int64) {
        try {
            // 1. 解析查询参数
            let parsedQuery = requestParser.parseQuery(filter, sort, Int64(page), Int64(pageSize))
            
            // 2. 构建 WHERE 条件（使用工具类）
            var whereClause = ""
            if (let Some(filterCondition) <- parsedQuery.filter) {
                whereClause = queryBuilder.buildWhereClause(filterCondition)
            }
            
            // 3. 构建 ORDER BY 子句（使用工具类）
            let orderByClause = queryBuilder.buildOrderByClause(parsedQuery.sort)
            
            // 4. 执行查询
            let pagination = getExecutor().find{Table}ByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )
            
            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            LogUtils.error("{Table}Service", "Failed to get list: ${e.message}")
            return (ArrayList<{Table}PO>(), 0)
        }
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
    
    // 在此区域添加自定义业务逻辑方法
}
```

**V4优化说明**：
- 使用`QueryBuilderService`工具类处理查询构建,删除250行重复代码
- 简化字段合并逻辑
- 标准方法在AutoCreateCode区域,定制方法在区域外

### 3.4 步骤四：创建控制器

在 `src/app/controllers/{database}/{table}/` 目录下创建 `{Table}Controller.cj` 文件：

```cangjie
/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.{database}.{table}

import magic.app.core.http.{HttpRequest, HttpResponse, ErrorHandler}
import magic.app.core.response.{APIError, APIResult}
import magic.app.models.{database}.{Table}PO
import magic.app.services.{database}.{Table}Service
import magic.log.LogUtils
import std.collection.{HashMap, Map, ArrayList}
import std.convert
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonFloat, JsonBool, JsonArray}

public class {Table}Controller {
    private var service: {Table}Service
    
    public init(service: {Table}Service) {
        this.service = service
    }
    
    //#region AutoCreateCode
    
    public func add(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                ErrorHandler.unauthorized(res, "未登录或登录已过期")
                return
            }
            
            let userIdStr = userId.getOrThrow() as String
            if (let Some(str) <- userIdStr) {
                if (str.isEmpty()) {
                    ErrorHandler.unauthorized(res, "未登录或登录已过期")
                    return
                }
                
                let body = parseBody(req)
                if (let Some(b) <- body) {
                    let entity = mapToEntity(b)
                    let result = service.create(entity, str)
                    if (result.success) {
                        if (result.data.isSome()) {
                            let data = result.data.getOrThrow()
                            res.status(200).json(data.toJson())
                        } else {
                            ErrorHandler.serverError(res, "创建失败")
                        }
                    } else {
                        let reason = result.reason ?? "创建失败"
                        ErrorHandler.businessError(res, "50001", reason)
                    }
                } else {
                    ErrorHandler.badRequest(res, "提交数据格式错误")
                }
            } else {
                ErrorHandler.unauthorized(res, "未登录或登录已过期")
            }
        } catch (e: Exception) {
            ErrorHandler.serverError(res, e.message)
        }
    }
    
    public func edit(req: HttpRequest, res: HttpResponse): Unit {
        // 实现编辑逻辑
    }
    
    public func delete(req: HttpRequest, res: HttpResponse): Unit {
        // 实现删除逻辑
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
        let entity = {Table}PO()
        
        // 使用辅助方法简化字段映射
        mapStringField(map, "name", { v => entity.name = v })
        mapOptionStringField(map, "description", { v => entity.description = v })
        
        return entity
    }
    
    // 辅助方法
    private func mapStringField(map: Map<String, Any>, name: String, setter: (String) -> Unit): Unit {
        if (let Some(value) <- map.get(name)) {
            let valueStr = value as String
            if (let Some(s) <- valueStr) {
                setter(s)
            }
        }
    }
    
    private func mapOptionStringField(map: Map<String, Any>, name: String, setter: (Option<String>) -> Unit): Unit {
        if (let Some(value) <- map.get(name)) {
            let valueStr = value as String
            if (let Some(s) <- valueStr) {
                setter(Some<String>(s))
            }
        }
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
    
    // 在此区域添加自定义接口方法
}
```

**V4优化说明**：
- 使用`ErrorHandler`统一错误处理
- 使用辅助方法简化`mapToEntity`实现
- 删除100行重复代码

### 3.5 步骤五：注册路由

在 `src/app/routes/{database}/{table}/` 目录下创建 `{Table}Route.cj` 文件：

```cangjie
/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.{database}.{table}

import magic.app.controllers.{database}.{table}.{Table}Controller
import magic.app.core.router.Router

public class {Table}Route {
    private var router: Router
    private var controller: {Table}Controller
    
    public init(router: Router, controller: {Table}Controller) {
        this.router = router
        this.controller = controller
    }
    
    //#region AutoCreateCode
    
    public func register(): Router {
        // 按照 uctoo v4 规范，路由路径带 /v1 前缀
        
        // ==================== 标准CRUD路由 ====================
        
        // 新增
        router.post("/api/v1/{database}/{table}/add", controller.add)
        
        // 编辑
        router.post("/api/v1/{database}/{table}/edit", controller.edit)
        
        // 删除
        router.post("/api/v1/{database}/{table}/del", controller.delete)
        
        // 单条查询：必须放在列表查询之前，因为UUID格式与数字不同
        router.get("/api/v1/{database}/{table}/:id", controller.getSingle)
        
        // 列表查询：支持 :limit/:page 和 :limit/:page/:skip 两种格式
        router.get("/api/v1/{database}/{table}/:limit/:page/:skip", controller.getManyWithSkip)
        router.get("/api/v1/{database}/{table}/:limit/:page", controller.getManyWithPathParams)
        
        return router
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义路由）==========
    
    /**
     * 注册定制路由
     */
    public func registerCustomRoutes(): Router {
        // 在此区域添加定制路由
        return router
    }
}
```

**V4优化说明**：
- 标准路由在AutoCreateCode区域,可被覆盖
- 定制路由在区域外,不会被保留
- 添加路由分类标识

## 4. 代码生成区域标识

### 4.1 概述

为了支持标准CRUD代码生成与定制开发的共存，UCToo V4采用注释标识区机制。代码生成器只覆盖特定注释标识区内的内容，区域外是定制开发区域，确保后续的定制开发和个性化拓展不会被标准CRUD生成的代码覆盖。

### 4.2 标识格式

```cangjie
// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

import custom.library.Module1

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========

public class {Table}Controller {
    // ...
    
    //#region AutoCreateCode
    
    // ... 自动生成的标准CRUD代码 ...
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
```

### 4.3 两层保护机制

1. **头部自定义引入区域**：
   - 标识：`// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========`
   - 用途：保护自定义的import引入语句
   - 位置：在package声明之后，标准import之前

2. **尾部定制开发区域**：
   - 标识：`//#region AutoCreateCode` 和 `//#endregion AutoCreateCode`
   - 用途：保护自定义的方法实现
   - 位置：在类定义内部

### 4.4 各层标识位置

| 层级 | 头部引入区 | 尾部方法区 | 说明 |
|------|-----------|-----------|------|
| Model | ✅ | ❌ | 支持自定义import，字段变更时需要整体更新 |
| DAO | ✅ | ✅ | 支持自定义import和查询方法 |
| Service | ✅ | ✅ | 支持自定义import和业务逻辑 |
| Controller | ✅ | ✅ | 支持自定义import和接口方法 |
| Route | ✅ | ✅ | 支持自定义import和路由配置 |

## 5. 公共工具类

### 5.1 QueryBuilderService

**位置**: `src/app/core/query/QueryBuilderService.cj`

**用途**: 提供通用的查询条件构建方法,所有表的Service层都可使用

**主要方法**:
- `buildWhereClause(composite: CompositeCondition): String` - 构建WHERE子句
- `buildFieldClause(fieldCondition: FieldCondition): String` - 构建字段条件
- `buildOrderByClause(sort: ArrayList<SortCondition>): String` - 构建ORDER BY子句

### 5.2 ErrorHandler

**位置**: `src/app/core/http/ErrorHandler.cj`

**用途**: 统一错误处理

**主要方法**:
- `badRequest(res: HttpResponse, message: String): Unit` - 参数错误
- `unauthorized(res: HttpResponse, message: String): Unit` - 认证错误
- `notFound(res: HttpResponse, message: String): Unit` - 资源不存在
- `serverError(res: HttpResponse, message: String): Unit` - 服务器错误
- `businessError(res: HttpResponse, code: String, message: String): Unit` - 业务错误

## 6. 最佳实践

### 6.1 命名规范

| 类型 | 规范 | 示例 |
|------|------|------|
| 模型类 | PascalCase + PO | EntityPO |
| DAO接口 | PascalCase + DAO | EntityDAO |
| 服务类 | PascalCase + Service | EntityService |
| 控制器类 | PascalCase + Controller | EntityController |
| 路由类 | PascalCase + Route | EntityRoute |
| 文件名 | PascalCase | EntityPO.cj |
| 目录名 | 小写 | entity/ |

### 6.2 错误处理

统一使用 ErrorHandler 返回错误：

```cangjie
// 参数错误
ErrorHandler.badRequest(res, "参数错误")

// 认证错误
ErrorHandler.unauthorized(res, "未授权访问")

// 资源不存在
ErrorHandler.notFound(res, "资源不存在")

// 服务器错误
ErrorHandler.serverError(res, "服务器内部错误")

// 业务错误
ErrorHandler.businessError(res, "50001", "业务错误")
```

### 6.3 软删除设计

**DAO层**：不过滤软删除数据
```cangjie
func find{Table}ById(id: String): Option<{Table}PO> {
    executor.setSql('''
        select * from {table_name} where id = ${arg(id)}
    ''').first<{Table}PO>()
}
```

**API使用方**：根据 `deleted_at` 字段判断数据状态
- `deleted_at` 为空：正常数据
- `deleted_at` 有值：已软删除数据

**恢复软删除**：通过 `edit` 接口，设置 `deleted_at = "0"`

### 6.4 ORM查询注意事项

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

## 7. 完整示例

参考已实现的 entity 模块：
- 模型: [EntityPO.cj](../../src/app/models/uctoo/EntityPO.cj)
- DAO: [EntityDAO.cj](../../src/app/dao/uctoo/EntityDAO.cj)
- 服务: [EntityService.cj](../../src/app/services/uctoo/EntityService.cj)
- 控制器: [EntityController.cj](../../src/app/controllers/uctoo/entity/EntityController.cj)
- 路由: [EntityRoute.cj](../../src/app/routes/uctoo/entity/EntityRoute.cj)

## 8. 使用 crud-generator 自动生成 CRUD 模块

### 8.1 概述

`crud-generator` 技能可以自动生成数据库表的标准 CRUD 模块代码，包括 Model、DAO、Service、Controller、Route 五层完整代码，并自动注册路由。

### 8.2 使用方法

```bash
# 进入 crud-generator 脚本目录
cd apps/agentskills-runtime/skills/crud-generator/scripts

# 运行生成脚本
node generate-from-template-v2.js
```

或在代码中调用：

```javascript
import { generateModule } from './generate-from-template-v2.js'
import { parseTable } from './sql-schema-parser.js'

// 解析表结构（从uctooDB.sql）
const tableInfo = parseTable('entity')

// 生成entity模块
await generateModule({
    tableName: 'entity',
    dbName: 'uctoo',
    fields: tableInfo.fields,
    outputDir: './src/app'
})
```

### 8.3 生成内容

`crud-generator` 会自动生成以下文件：

| 文件 | 路径 | 说明 |
|------|------|------|
| Model | `models/{db}/{Table}PO.cj` | 数据模型，包含 ORM 注解 |
| DAO | `dao/{db}/{Table}DAO.cj` | 数据访问接口 |
| Service | `services/{db}/{Table}Service.cj` | 业务逻辑层 |
| Controller | `controllers/{db}/{table}/{Table}Controller.cj` | HTTP 控制器 |
| Route | `routes/{db}/{table}/{Table}Route.cj` | 路由定义 |

### 8.4 V4优化收益

基于重构后的模块开发规范,crud-generator的收益：

| 指标 | 改善 |
|------|------|
| 模板代码量 | 减少51% |
| 生成速度 | 提升约30% |
| 维护成本 | 降低约50% |
| 代码复用 | 大幅提升 |

## 9. 参考文档

- [子系统架构说明](./uctoo-v4-architecture.md)
- [uctoo API设计规范](../../../backend/docs/uctoo-api-design-specification.md)
- [uctoo 模块设计规范](../../../backend/docs/uctoo-module-design-specification.md)
- [Fountain ORM规范](./uctoo-v4-orm-specification.md)
- [Entity模块重构方案](./entity-refactor-plan.md)
