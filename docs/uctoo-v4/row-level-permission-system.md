# uctoo v4 行级数据权限机制

## 文档信息
- **版本**: 4.0
- **创建日期**: 2026-04-04
- **更新日期**: 2026-04-04
- **状态**: 初稿

## 1. 概述

### 1.1 设计目标

uctoo v4 的行级数据权限机制旨在实现细粒度的数据访问控制，确保用户只能访问其有权限的数据行。该机制与 RBAC3 权限体系协同工作，提供完整的数据安全保障。

### 1.2 核心原则

1. **安全优先，默认无权限**：用户只能访问自己创建的数据或被明确授权的数据
2. **最小权限原则**：按需分配权限，避免过度授权
3. **权限分级**：支持读、写、授权三级权限控制
4. **可配置性**：通过环境变量控制是否启用行级权限
5. **向后兼容**：与 v3 版本的权限机制保持一致，便于迁移

### 1.3 与 v3 版本的对比

| 特性 | v3 版本 | v4 版本 | 改进说明 |
|------|---------|---------|----------|
| 权限模型 | RBAC3 + 行级权限 | RBAC3 + 行级权限 | 保持一致 |
| 实现语言 | TypeScript | 仓颉 (Cangjie) | 性能提升 |
| 权限检查位置 | Service 层 | Service 层 + 中间件 | 多层防护 |
| 缓存机制 | Redis | 内存缓存 | 减少依赖 |
| 配置方式 | .env 文件 | .env 文件 | 保持一致 |

## 2. 架构设计

### 2.1 权限模型

#### 2.1.1 数据归属

所有业务数据表必须包含 `creator` 字段，用于标识数据的归属用户：

```sql
-- 示例：entity 表
CREATE TABLE "public"."entity" (
  "id" uuid PRIMARY KEY,
  "link" varchar(255),
  "stars" float8 NOT NULL DEFAULT 0,
  "privacy_level" int4,
  "description" text,
  "price" float8,
  "creator" uuid,  -- 数据归属用户
  "created_at" timestamptz(6),
  "updated_at" timestamptz(6),
  "deleted_at" timestamptz(6)
);
```

#### 2.1.2 数据授权

通过 `data_access_authorization` 表实现数据授权：

```sql
CREATE TABLE "public"."data_access_authorization" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  "entity_id" varchar NOT NULL,        -- 实体ID
  "entity_type" varchar(50) NOT NULL,   -- 实体类型（表名）
  "user_id" uuid NOT NULL,             -- 被授权用户ID
  "permission" int4 NOT NULL,           -- 权限级别：1=可读，2=可写，3=可授权
  "creator" uuid,                       -- 授权创建人
  "created_at" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
);
```

**权限级别说明**：

| permission 值 | 权限级别 | 说明 |
|--------------|---------|------|
| 1 | 可读 | 可以读取数据，对应 GET 请求 |
| 2 | 可写 | 可以修改数据，对应 POST/PUT/PATCH 请求 |
| 3 | 可授权 | 可以授权给其他用户，同时具有读写权限 |

**权限继承关系**：
- 可授权权限 (3) 包含可写权限 (2) 和可读权限 (1)
- 可写权限 (2) 包含可读权限 (1)

### 2.2 权限检查流程

#### 2.2.1 单条数据访问

```
用户请求 → 中间件检查 API 权限 → Service 层检查行级权限 → 返回数据
```

**详细流程**：

1. **API 权限检查**（中间件）
   - 检查用户是否有访问该 API 的权限（RBAC3）
   - 如果无权限，返回 403 错误

2. **行级权限检查**（Service 层）
   - 检查用户是否是数据创建者（creator）
   - 如果不是，检查是否有授权记录
   - 如果有授权，检查权限级别是否满足要求
   - 如果无权限，返回空结果或 403 错误

#### 2.2.2 批量数据访问

```
用户请求 → 中间件检查 API 权限 → Service 层构建权限过滤 → 查询数据库 → 返回数据
```

**详细流程**：

1. **API 权限检查**（中间件）
   - 检查用户是否有访问该 API 的权限（RBAC3）

2. **构建权限过滤**（Service 层）
   - 获取用户 ID
   - 查询用户被授权的实体 ID 列表
   - 构建 WHERE 条件：`creator = userId OR id IN (authorizedIds)`

3. **查询数据库**
   - 使用构建的 WHERE 条件查询数据
   - 返回用户有权访问的数据

### 2.3 权限检查决策树

```
用户访问数据
├─ 是否启用行级权限？
│   ├─ 否 → 直接返回所有数据
│   └─ 是 → 继续
├─ 用户是否是数据创建者？
│   ├─ 是 → 允许访问（完全权限）
│   └─ 否 → 继续
├─ 是否有授权记录？
│   ├─ 否 → 拒绝访问
│   └─ 是 → 继续
└─ 权限级别是否满足要求？
    ├─ 是 → 允许访问
    └─ 否 → 拒绝访问
```

## 3. 实现方案

### 3.1 核心组件

#### 3.1.1 DataAccessAuthorizationPO（数据模型）

**文件路径**：`src/app/models/uctoo/DataAccessAuthorizationPO.cj`

```cangjie
package magic.app.models.uctoo

import std.time.DateTime
import f_orm.macros.{QueryMappersGenerator, ORMField}
import f_data.macros.DataAssist
import f_data.{ObjectData, Data, DataConversionFlag, ObjectFields, MutableField, DataObject, f_data_tryFromData}
import f_orm.*
import json4cj.JsonValueSerializable
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonFloat, JsonBool, JsonNull}

@DataAssist[fields]
@QueryMappersGenerator["data_access_authorization"]
public class DataAccessAuthorizationPO {
    @ORMField['id']
    public var id: String = ""

    @ORMField['entity_id']
    public var entityId: String = ""

    @ORMField['entity_type']
    public var entityType: String = ""

    @ORMField['user_id']
    public var userId: String = ""

    @ORMField['permission']
    public var permission: Int32 = 0

    @ORMField['creator']
    public var creator: Option<String> = None<String>

    @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

    @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

    @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

    public init() {}

    // 其他方法：toJson, fromJson 等
}
```

#### 3.1.2 PermissionLevel（权限级别枚举）

**文件路径**：`src/app/core/PermissionLevel.cj`

```cangjie
package magic.app.core

public enum PermissionLevel {
    READ = 1,       // 可读
    WRITE = 2,      // 可写
    AUTHORIZE = 3   // 可授权
}

public func getPermissionLevelName(level: PermissionLevel): String {
    match (level) {
        case PermissionLevel.READ => "可读"
        case PermissionLevel.WRITE => "可写"
        case PermissionLevel.AUTHORIZE => "可授权"
        case _ => "未知"
    }
}

public func hasPermission(userPermission: PermissionLevel, requiredPermission: PermissionLevel): Boolean {
    return userPermission >= requiredPermission
}
```

#### 3.1.3 PermissionUtils（权限工具类）

**文件路径**：`src/app/utils/PermissionUtils.cj`

```cangjie
package magic.app.utils

import magic.app.models.uctoo.DataAccessAuthorizationPO
import magic.app.core.PermissionLevel
import magic.app.dao.uctoo.DataAccessAuthorizationDAO
import f_orm.*
import std.collection.ArrayList
import std.log.Log

public class PermissionUtils {
    private static let logger = Log("PermissionUtils")

    /**
     * 检查用户是否有权限访问特定数据
     * @param userId 用户ID
     * @param entityType 实体类型（表名）
     * @param entityId 实体ID
     * @param requiredPermission 所需权限级别
     * @return (hasPermission: Boolean, reason: String)
     */
    public static func checkUserHasPermission(
        userId: String,
        entityType: String,
        entityId: String,
        requiredPermission: PermissionLevel
    ): (Boolean, String) {
        // 检查表级行级权限是否启用
        if (!PermissionConfig.isRowLevelPermissionEnabledForTable(entityType)) {
            return (true, "")
        }

        try {
            // 1. 检查实体是否存在
            let executor = getExecutor()
            let tableName = entityType
            let query = "SELECT id, creator FROM ${tableName} WHERE id = ? AND deleted_at IS NULL"
            let result = executor.executeQuery(query, [entityId])

            if (result.isEmpty()) {
                return (false, "实体不存在: ${entityId}")
            }

            let entityCreator = result[0]["creator"] as String

            // 2. 检查是否是创建者
            if (entityCreator == userId) {
                return (true, "")
            }

            // 3. 检查是否有授权
            let dao = DataAccessAuthorizationDAO()
            let authorizations = dao.findByUserIdAndEntityTypeAndEntityId(userId, entityType, entityId)

            if (authorizations.isEmpty()) {
                return (false, "您没有访问此数据的权限")
            }

            // 4. 检查权限级别
            for (auth in authorizations) {
                let userPermission = PermissionLevel.from(auth.permission)
                if (hasPermission(userPermission, requiredPermission)) {
                    return (true, "")
                }
            }

            let permissionName = getPermissionLevelName(requiredPermission)
            return (false, "您没有${permissionName}此数据的权限")
        } catch (e: Exception) {
            logger.error("权限检查失败: ${e.message}")
            return (false, "权限检查过程中发生错误")
        }
    }

    /**
     * 获取用户有权访问的实体ID列表
     * @param userId 用户ID
     * @param entityType 实体类型（表名）
     * @param requiredPermission 所需权限级别
     * @return 实体ID列表
     */
    public static func getUserAuthorizedDataIds(
        userId: String,
        entityType: String,
        requiredPermission: PermissionLevel
    ): ArrayList<String> {
        // 检查表级行级权限是否启用
        if (!PermissionConfig.isRowLevelPermissionEnabledForTable(entityType)) {
            return ArrayList<String>()
        }

        try {
            let dao = DataAccessAuthorizationDAO()
            let authorizations = dao.findByUserIdAndEntityTypeAndPermissionGte(
                userId, 
                entityType, 
                requiredPermission
            )

            let authorizedIds = ArrayList<String>()
            for (auth in authorizations) {
                authorizedIds.add(auth.entityId)
            }

            return authorizedIds
        } catch (e: Exception) {
            logger.error("获取授权数据ID列表失败: ${e.message}")
            return ArrayList<String>()
        }
    }

    /**
     * 生成行级权限过滤条件
     * @param userId 用户ID
     * @param entityType 实体类型（表名）
     * @param requiredPermission 所需权限级别
     * @return WHERE 条件字符串和参数
     */
    public static func generateRowLevelPermissionFilter(
        userId: String,
        entityType: String,
        requiredPermission: PermissionLevel
    ): (String, ArrayList<String>) {
        // 检查表级行级权限是否启用
        if (!PermissionConfig.isRowLevelPermissionEnabledForTable(entityType)) {
            return ("1=1", [])
        }

        try {
            let authorizedIds = getUserAuthorizedDataIds(userId, entityType, requiredPermission)

            if (authorizedIds.isEmpty()) {
                // 只有用户创建的数据
                return ("creator = ?", [userId])
            } else {
                // 用户创建的数据或被授权的数据
                let idList = authorizedIds.join(",")
                return ("(creator = ? OR id IN (${idList}))", [userId])
            }
        } catch (e: Exception) {
            logger.error("生成权限过滤条件失败: ${e.message}")
            return ("creator = ?", [userId])
        }
    }

    /**
     * 创建数据访问权限规则
     * @param entityType 实体类型（表名）
     * @param entityId 实体ID
     * @param userId 被授权用户ID
     * @param permission 权限级别
     * @param creator 授权创建人ID
     * @return 是否创建成功
     */
    public static func createDataAccessRule(
        entityType: String,
        entityId: String,
        userId: String,
        permission: PermissionLevel,
        creator: String
    ): Boolean {
        try {
            let dao = DataAccessAuthorizationDAO()
            let auth = DataAccessAuthorizationPO()
            auth.entityId = entityId
            auth.entityType = entityType
            auth.userId = userId
            auth.permission = permission
            auth.creator = Some<String>(creator)
            auth.createdAt = DateTime.now()
            auth.updatedAt = DateTime.now()

            let id = dao.insert(auth)
            return !id.isEmpty()
        } catch (e: Exception) {
            logger.error("创建数据访问权限规则失败: ${e.message}")
            return false
        }
    }

    /**
     * 删除数据访问权限规则
     * @param authId 授权记录ID
     * @return 是否删除成功
     */
    public static func deleteDataAccessRule(authId: String): Boolean {
        try {
            let dao = DataAccessAuthorizationDAO()
            return dao.softDelete(authId)
        } catch (e: Exception) {
            logger.error("删除数据访问权限规则失败: ${e.message}")
            return false
        }
    }

    /**
     * 检查权限级别是否满足要求
     */
    private static func hasPermission(userPermission: PermissionLevel, requiredPermission: PermissionLevel): Boolean {
        return userPermission >= requiredPermission
    }
}
```

#### 3.1.4 DataAccessAuthorizationDAO（数据访问层）

**文件路径**：`src/app/dao/uctoo/DataAccessAuthorizationDAO.cj`

```cangjie
package magic.app.dao.uctoo

import magic.app.models.uctoo.DataAccessAuthorizationPO
import f_orm.*
import f_orm.sql.*
import magic.app.core.PermissionLevel
import std.collection.ArrayList
import std.time.DateTime

public class DataAccessAuthorizationDAO {
    private let executor: SQLExecutor

    public init() {
        this.executor = getExecutor()
    }

    /**
     * 根据用户ID、实体类型和实体ID查询授权记录
     */
    public func findByUserIdAndEntityTypeAndEntityId(
        userId: String,
        entityType: String,
        entityId: String
    ): ArrayList<DataAccessAuthorizationPO> {
        try {
            let query = """
                SELECT * FROM data_access_authorization
                WHERE user_id = ? AND entity_type = ? AND entity_id = ?
                AND deleted_at IS NULL
            """
            let result = executor.executeQuery(query, [userId, entityType, entityId])
            return mapToDataAccessAuthorizationList(result)
        } catch (e: Exception) {
            return ArrayList<DataAccessAuthorizationPO>()
        }
    }

    /**
     * 根据用户ID、实体类型和权限级别查询授权记录
     */
    public func findByUserIdAndEntityTypeAndPermissionGte(
        userId: String,
        entityType: String,
        permission: PermissionLevel
    ): ArrayList<DataAccessAuthorizationPO> {
        try {
            let query = """
                SELECT * FROM data_access_authorization
                WHERE user_id = ? AND entity_type = ? AND permission >= ?
                AND deleted_at IS NULL
            """
            let result = executor.executeQuery(query, [userId, entityType, permission])
            return mapToDataAccessAuthorizationList(result)
        } catch (e: Exception) {
            return ArrayList<DataAccessAuthorizationPO>()
        }
    }

    /**
     * 根据实体ID和实体类型查询所有授权记录
     */
    public func findByEntityIdAndEntityType(
        entityId: String,
        entityType: String
    ): ArrayList<DataAccessAuthorizationPO> {
        try {
            let query = """
                SELECT * FROM data_access_authorization
                WHERE entity_id = ? AND entity_type = ?
                AND deleted_at IS NULL
            """
            let result = executor.executeQuery(query, [entityId, entityType])
            return mapToDataAccessAuthorizationList(result)
        } catch (e: Exception) {
            return ArrayList<DataAccessAuthorizationPO>()
        }
    }

    /**
     * 插入授权记录
     */
    public func insert(auth: DataAccessAuthorizationPO): String {
        try {
            let query = """
                INSERT INTO data_access_authorization
                (entity_id, entity_type, user_id, permission, creator, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                RETURNING id
            """
            let result = executor.executeQuery(query, [
                auth.entityId,
                auth.entityType,
                auth.userId,
                auth.permission,
                auth.creator.getOr(""),
                auth.createdAt,
                auth.updatedAt
            ])
            if (!result.isEmpty()) {
                return result[0]["id"] as String
            }
            return ""
        } catch (e: Exception) {
            return ""
        }
    }

    /**
     * 软删除授权记录
     */
    public func softDelete(authId: String): Boolean {
        try {
            let query = """
                UPDATE data_access_authorization
                SET deleted_at = ?, updated_at = ?
                WHERE id = ?
            """
            let now = DateTime.now()
            executor.executeUpdate(query, [now, now, authId])
            return true
        } catch (e: Exception) {
            return false
        }
    }

    /**
     * 将查询结果映射为 DataAccessAuthorizationPO 列表
     */
    private func mapToDataAccessAuthorizationList(result: ArrayList<HashMap<String, Any>>): ArrayList<DataAccessAuthorizationPO> {
        let list = ArrayList<DataAccessAuthorizationPO>()
        for (row in result) {
            let auth = DataAccessAuthorizationPO()
            auth.id = row["id"] as String
            auth.entityId = row["entity_id"] as String
            auth.entityType = row["entity_type"] as String
            auth.userId = row["user_id"] as String
            auth.permission = row["permission"] as Int32
            auth.creator = Some<String>(row["creator"] as String)
            auth.createdAt = row["created_at"] as DateTime
            auth.updatedAt = row["updated_at"] as DateTime
            list.add(auth)
        }
        return list
    }
}
```

#### 3.1.5 DataAccessAuthorizationService（服务层）

**文件路径**：`src/app/services/uctoo/DataAccessAuthorizationService.cj`

```cangjie
package magic.app.services.uctoo

import magic.app.models.uctoo.DataAccessAuthorizationPO
import magic.app.dao.uctoo.DataAccessAuthorizationDAO
import magic.app.core.PermissionLevel
import magic.app.utils.PermissionUtils
import magic.app.core.response.APIResult
import std.collection.ArrayList
import std.time.DateTime

public class DataAccessAuthorizationService {
    private let dao: DataAccessAuthorizationDAO

    public init() {
        this.dao = DataAccessAuthorizationDAO()
    }

    /**
     * 创建数据访问授权
     */
    public func createAuthorization(
        entityType: String,
        entityId: String,
        userId: String,
        permission: PermissionLevel,
        creatorId: String
    ): APIResult<DataAccessAuthorizationPO> {
        try {
            // 检查是否已有授权
            let existing = dao.findByUserIdAndEntityTypeAndEntityId(userId, entityType, entityId)
            if (!existing.isEmpty()) {
                return APIResult<DataAccessAuthorizationPO>(false, "授权已存在")
            }

            let auth = DataAccessAuthorizationPO()
            auth.entityId = entityId
            auth.entityType = entityType
            auth.userId = userId
            auth.permission = permission
            auth.creator = Some<String>(creatorId)
            auth.createdAt = DateTime.now()
            auth.updatedAt = DateTime.now()

            let id = dao.insert(auth)
            if (!id.isEmpty()) {
                auth.id = id
                return APIResult<DataAccessAuthorizationPO>(auth)
            } else {
                return APIResult<DataAccessAuthorizationPO>(false, "创建授权失败")
            }
        } catch (e: Exception) {
            return APIResult<DataAccessAuthorizationPO>(false, e.message)
        }
    }

    /**
     * 删除数据访问授权
     */
    public func deleteAuthorization(authId: String, userId: String): APIResult<Boolean> {
        try {
            let success = dao.softDelete(authId)
            if (success) {
                return APIResult<Boolean>(true)
            } else {
                return APIResult<Boolean>(false, "删除授权失败")
            }
        } catch (e: Exception) {
            return APIResult<Boolean>(false, e.message)
        }
    }

    /**
     * 查询实体的所有授权记录
     */
    public func getEntityAuthorizations(
        entityType: String,
        entityId: String
    ): APIResult<ArrayList<DataAccessAuthorizationPO>> {
        try {
            let authorizations = dao.findByEntityIdAndEntityType(entityId, entityType)
            return APIResult<ArrayList<DataAccessAuthorizationPO>>(authorizations)
        } catch (e: Exception) {
            return APIResult<ArrayList<DataAccessAuthorizationPO>>(false, e.message)
        }
    }
}
```

#### 3.1.6 DataAccessAuthorizationController（控制器层）

**文件路径**：`src/app/controllers/uctoo/data_access_authorization/DataAccessAuthorizationController.cj`

```cangjie
package magic.app.controllers.uctoo.data_access_authorization

import magic.app.services.uctoo.DataAccessAuthorizationService
import magic.app.core.PermissionLevel
import magic.app.utils.PermissionUtils
import magic.app.core.response.APIResult
import magic.app.core.http.{HttpRequest, HttpResponse}
import stdx.encoding.json.{JsonValue, JsonObject}

public class DataAccessAuthorizationController {
    private let service: DataAccessAuthorizationService

    public init() {
        this.service = DataAccessAuthorizationService()
    }

    /**
     * 创建数据访问授权
     * POST /api/v1/uctoo/data_access_authorization/add
     */
    public func add(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }

            let userIdStr = userId.getOrThrow() as String
            if (let Some(str) <- userIdStr) {
                let body = parseBody(req)
                if (let Some(b) <- body) {
                    let entityType = b.get("entity_type") as String
                    let entityId = b.get("entity_id") as String
                    let targetUserId = b.get("user_id") as String
                    let permission = PermissionLevel.from(b.get("permission") as Int32)

                    // 检查用户是否有授权权限
                    let (hasPermission, reason) = PermissionUtils.checkUserHasPermission(
                        str, entityType, entityId, PermissionLevel.AUTHORIZE
                    )

                    if (!hasPermission) {
                        res.status(403).json("{\"errno\":\"40300\",\"errmsg\":\"${reason}\"}")
                        return
                    }

                    let result = service.createAuthorization(
                        entityType,
                        entityId,
                        targetUserId,
                        permission,
                        str
                    )

                    if (result.success) {
                        if (result.data.isSome()) {
                            let data = result.data.getOrThrow()
                            res.status(200).json(data.toJson())
                        } else {
                            res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"创建授权失败\"}")
                        }
                    } else {
                        let reason = result.reason ?? "创建授权失败"
                        res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
                    }
                } else {
                    res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"提交数据格式错误\"}")
                }
            } else {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    /**
     * 删除数据访问授权
     * POST /api/v1/uctoo/data_access_authorization/del
     */
    public func del(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }

            let userIdStr = userId.getOrThrow() as String
            if (let Some(str) <- userIdStr) {
                let body = parseBody(req)
                if (let Some(b) <- body) {
                    let authId = b.get("id") as String

                    let result = service.deleteAuthorization(authId, str)
                    if (result.success) {
                        res.status(200).json("{\"errno\":\"0\",\"errmsg\":\"删除成功\"}")
                    } else {
                        let reason = result.reason ?? "删除失败"
                        res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
                    }
                } else {
                    res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"提交数据格式错误\"}")
                }
            } else {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    /**
     * 查询实体的所有授权记录
     * GET /api/v1/uctoo/data_access_authorization/:entityType/:entityId
     */
    public func getEntityAuthorizations(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }

            let userIdStr = userId.getOrThrow() as String
            if (let Some(str) <- userIdStr) {
                let entityType = req.getParam("entityType")
                let entityId = req.getParam("entityId")

                let result = service.getEntityAuthorizations(entityType, entityId)
                if (result.success) {
                    if (result.data.isSome()) {
                        let data = result.data.getOrThrow()
                        let jsonArray = ArrayList<JsonValue>()
                        for (auth in data) {
                            jsonArray.add(auth.toJsonValue())
                        }
                        res.status(200).json(JsonArray(jsonArray).toString())
                    } else {
                        res.status(200).json("[]")
                    }
                } else {
                    let reason = result.reason ?? "查询失败"
                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
                }
            } else {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    private func parseBody(req: HttpRequest): Option<JsonObject> {
        try {
            let body = req.body()
            let json = JsonValue.fromStr(body)
            if (json is JsonObject) {
                return Some<JsonObject>(json.asObject())
            }
            return None<JsonObject>
        } catch (e: Exception) {
            return None<JsonObject>
        }
    }
}
```

### 3.2 Service 层集成

在现有 Service 层中集成行级权限检查，以 EntityService 为例：

**文件路径**：`src/app/services/uctoo/EntityService.cj`

```cangjie
package magic.app.services.uctoo

import magic.app.models.uctoo.EntityPO
import magic.app.dao.uctoo.EntityDAO
import magic.app.core.PermissionLevel
import magic.app.utils.PermissionUtils
import magic.app.core.response.APIResult
import std.collection.ArrayList
import std.time.DateTime

public class EntityService {
    private let dao: EntityDAO

    public init() {
        this.dao = EntityDAO()
    }

    /**
     * 创建实体
     */
    public func create(entity: EntityPO, creatorId: String): APIResult<EntityPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            // 只有当用户未指定creator时，才使用登录用户ID
            if (entity.creator.isNone()) {
                entity.creator = Some<String>(creatorId)
            }
            
            let id = dao.insert(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<EntityPO>(entity)
            } else {
                return APIResult<EntityPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<EntityPO>(false, e.message)
        }
    }

    /**
     * 根据ID查询实体
     */
    public func findById(id: String, userId: String): APIResult<EntityPO> {
        try {
            // 检查行级权限
            let (hasPermission, reason) = PermissionUtils.checkUserHasPermission(
                userId, "entity", id, PermissionLevel.READ
            )

            if (!hasPermission) {
                return APIResult<EntityPO>(false, reason)
            }

            let entity = dao.findById(id)
            if (entity.isNone()) {
                return APIResult<EntityPO>(false, "实体不存在")
            }

            return APIResult<EntityPO>(entity.getOrThrow())
        } catch (e: Exception) {
            return APIResult<EntityPO>(false, e.message)
        }
    }

    /**
     * 查询实体列表（分页）
     */
    public func findAll(limit: Int32, page: Int32, userId: String): APIResult<ArrayList<EntityPO>> {
        try {
            // 生成行级权限过滤条件
            let (whereClause, params) = PermissionUtils.generateRowLevelPermissionFilter(
                userId, "entity", PermissionLevel.READ
            )

            let entities = dao.findAllWithFilter(limit, page, whereClause, params)
            return APIResult<ArrayList<EntityPO>>(entities)
        } catch (e: Exception) {
            return APIResult<ArrayList<EntityPO>>(false, e.message)
        }
    }

    /**
     * 更新实体
     */
    public func update(entity: EntityPO, userId: String): APIResult<EntityPO> {
        try {
            // 检查行级权限
            let (hasPermission, reason) = PermissionUtils.checkUserHasPermission(
                userId, "entity", entity.id, PermissionLevel.WRITE
            )

            if (!hasPermission) {
                return APIResult<EntityPO>(false, reason)
            }

            entity.updatedAt = DateTime.now()
            let success = dao.update(entity)

            if (success) {
                return APIResult<EntityPO>(entity)
            } else {
                return APIResult<EntityPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<EntityPO>(false, e.message)
        }
    }

    /**
     * 删除实体
     */
    public func delete(id: String, userId: String): APIResult<Boolean> {
        try {
            // 检查行级权限
            let (hasPermission, reason) = PermissionUtils.checkUserHasPermission(
                userId, "entity", id, PermissionLevel.WRITE
            )

            if (!hasPermission) {
                return APIResult<Boolean>(false, reason)
            }

            let success = dao.softDelete(id)

            if (success) {
                return APIResult<Boolean>(true)
            } else {
                return APIResult<Boolean>(false, "删除失败")
            }
        } catch (e: Exception) {
            return APIResult<Boolean>(false, e.message)
        }
    }

    // TODO: 实现行级数据权限机制
    // 1. 在查询方法中添加权限过滤
    // 2. 在更新和删除方法中添加权限检查
    // 3. 支持数据授权功能
}
```

### 3.3 配置管理

#### 3.3.1 环境变量配置

在 `.env` 文件中添加配置：

```env
# 行级数据权限开关（全局默认）
ROW_LEVEL_PERMISSION_ENABLED=true

# 权限缓存过期时间（秒）
PERMISSION_CACHE_TTL=300

# 表级行级权限配置（可选）
# 格式：ROW_LEVEL_PERMISSION_<表名>=true|false
# 示例：
# ROW_LEVEL_PERMISSION_entity=true
# ROW_LEVEL_PERMISSION_uctoo_user=false
```

#### 3.3.2 配置读取

**文件路径**：`src/app/config/PermissionConfig.cj`

```cangjie
package magic.app.config

import std.env.Env
import std.collection.HashMap

public class PermissionConfig {
    private static let ROW_LEVEL_PERMISSION_ENABLED: Boolean = Env.get("ROW_LEVEL_PERMISSION_ENABLED") == "true"
    private static let PERMISSION_CACHE_TTL: Int32 = Int32.parse(Env.get("PERMISSION_CACHE_TTL", "300"))
    private static let tableLevelPermissions: HashMap<String, Boolean> = buildTableLevelPermissions()

    public static func isRowLevelPermissionEnabled(): Boolean {
        return ROW_LEVEL_PERMISSION_ENABLED
    }

    /**
     * 检查特定表是否启用行级权限
     * @param tableName 表名
     * @return 是否启用
     */
    public static func isRowLevelPermissionEnabledForTable(tableName: String): Boolean {
        let tableConfig = tableLevelPermissions.get(tableName)
        if (tableConfig.isSome()) {
            return tableConfig.getOrThrow()
        }
        return ROW_LEVEL_PERMISSION_ENABLED
    }

    public static func getPermissionCacheTTL(): Int32 {
        return PERMISSION_CACHE_TTL
    }

    /**
     * 构建表级权限配置
     */
    private static func buildTableLevelPermissions(): HashMap<String, Boolean> {
        let configs = HashMap<String, Boolean>()
        let envVars = Env.getAll()
        
        for (envVar in envVars) {
            let key = envVar.key
            if (key.startsWith("ROW_LEVEL_PERMISSION_")) {
                let tableName = key.substring(23)  // 移除 "ROW_LEVEL_PERMISSION_" 前缀
                let value = envVar.value == "true"
                configs.put(tableName, value)
            }
        }
        
        return configs
    }
}
```

### 3.4 性能优化

#### 3.4.1 权限缓存

为了避免每次查询都访问数据库，实现权限缓存机制：

**文件路径**：`src/app/utils/PermissionCache.cj`

```cangjie
package magic.app.utils

import std.collection.HashMap
import std.time.DateTime
import magic.app.core.PermissionLevel

public class PermissionCache {
    private static let cache: HashMap<String, CacheEntry> = HashMap<String, CacheEntry>()
    private static let lock = Mutex()

    public static func get(
        userId: String,
        entityType: String,
        entityId: String,
        requiredPermission: PermissionLevel
    ): Option<(Boolean, String)> {
        lock.lock()
        defer {
            lock.unlock()
        }

        let key = "${userId}:${entityType}:${entityId}:${requiredPermission}"
        let entry = cache.get(key)

        if (entry.isSome()) {
            let cacheEntry = entry.getOrThrow()
            if (cacheEntry.isExpired()) {
                cache.remove(key)
                return None<(Boolean, String)>
            }
            return Some<(Boolean, String)>(cacheEntry.value)
        }

        return None<(Boolean, String)>
    }

    public static func set(
        userId: String,
        entityType: String,
        entityId: String,
        requiredPermission: PermissionLevel,
        value: (Boolean, String)
    ): Unit {
        lock.lock()
        defer {
            lock.unlock()
        }

        let key = "${userId}:${entityType}:${entityId}:${requiredPermission}"
        let ttl = magic.app.config.PermissionConfig.getPermissionCacheTTL()
        let entry = CacheEntry(value, DateTime.now().addSeconds(ttl))
        cache.put(key, entry)
    }

    public static func clear(): Unit {
        lock.lock()
        defer {
            lock.unlock()
        }

        cache.clear()
    }

    private class CacheEntry {
        public let value: (Boolean, String)
        public let expireTime: DateTime

        public init(value: (Boolean, String), expireTime: DateTime) {
            this.value = value
            this.expireTime = expireTime
        }

        public func isExpired(): Boolean {
            return DateTime.now() > this.expireTime
        }
    }
}
```

#### 3.4.2 批量查询优化

在查询大量数据时，使用批量查询减少数据库访问次数：

```cangjie
/**
 * 批量检查用户是否有权限访问多个实体
 */
public static func batchCheckUserHasPermission(
    userId: String,
    entityType: String,
    entityIds: ArrayList<String>,
    requiredPermission: PermissionLevel
): HashMap<String, (Boolean, String)> {
    try {
        let result = HashMap<String, (Boolean, String)>()

        // 1. 批量查询用户被授权的实体ID
        let dao = DataAccessAuthorizationDAO()
        let authorizedIds = dao.findAuthorizedEntityIdsByUserIdAndEntityTypeAndPermissionGte(
            userId, 
            entityType, 
            requiredPermission
        )

        // 2. 批量查询实体的创建者
        let executor = getExecutor()
        let idList = entityIds.join(",")
        let query = "SELECT id, creator FROM ${entityType} WHERE id IN (${idList}) AND deleted_at IS NULL"
        let entities = executor.executeQuery(query, [])

        // 3. 构建实体ID到创建者的映射
        let entityCreators = HashMap<String, String>()
        for (entity in entities) {
            let id = entity["id"] as String
            let creator = entity["creator"] as String
            entityCreators.put(id, creator)
        }

        // 4. 检查每个实体的权限
        for (entityId in entityIds) {
            let creator = entityCreators.get(entityId)
            if (creator.isSome()) {
                if (creator.getOrThrow() == userId) {
                    result.put(entityId, (true, ""))
                } else if (authorizedIds.contains(entityId)) {
                    result.put(entityId, (true, ""))
                } else {
                    result.put(entityId, (false, "您没有访问此数据的权限"))
                }
            } else {
                result.put(entityId, (false, "实体不存在"))
            }
        }

        return result
    } catch (e: Exception) {
        logger.error("批量权限检查失败: ${e.message}")
        return HashMap<String, (Boolean, String)>()
    }
}
```

### 3.5 数据库索引优化

为提高权限查询性能，添加必要的索引：

```sql
-- data_access_authorization 表索引
CREATE INDEX "idx_data_access_auth_user_entity" 
ON "public"."data_access_authorization" (user_id, entity_type, entity_id) 
WHERE deleted_at IS NULL;

CREATE INDEX "idx_data_access_auth_entity_perm" 
ON "public"."data_access_authorization" (entity_type, entity_id, permission) 
WHERE deleted_at IS NULL;

CREATE INDEX "idx_data_access_auth_user_perm" 
ON "public"."data_access_authorization" (user_id, entity_type, permission) 
WHERE deleted_at IS NULL;

-- 业务表索引（以 entity 表为例）
CREATE INDEX "idx_entity_creator" 
ON "public"."entity" (creator) 
WHERE deleted_at IS NULL;

CREATE INDEX "idx_entity_creator_deleted" 
ON "public"."entity" (creator, deleted_at);
```

## 4. 使用示例

### 4.1 创建数据并授权

```cangjie
// 1. 创建实体
let entity = EntityPO()
entity.link = "https://example.com"
entity.stars = 5.0
entity.description = "示例数据"
entity.creator = Some<String>("user-123")

let createResult = entityService.create(entity, "user-123")

// 2. 授权给其他用户
let authResult = PermissionUtils.createDataAccessRule(
    "entity",                    // 实体类型
    createResult.data.getOrThrow().id,  // 实体ID
    "user-456",                  // 被授权用户ID
    PermissionLevel.READ,        // 权限级别
    "user-123"                   // 授权创建人ID
)
```

### 4.2 查询数据

```cangjie
// 查询单条数据
let result = entityService.findById("entity-id", "user-456")
if (result.success) {
    let entity = result.data.getOrThrow()
    println("实体数据: ${entity.description}")
} else {
    println("查询失败: ${result.reason}")
}

// 查询数据列表
let listResult = entityService.findAll(10, 0, "user-456")
if (listResult.success) {
    let entities = listResult.data.getOrThrow()
    println("查询到 ${entities.size} 条数据")
}
```

### 4.3 更新和删除数据

```cangjie
// 更新数据
let entity = EntityPO()
entity.id = "entity-id"
entity.description = "更新后的描述"

let updateResult = entityService.update(entity, "user-456")

// 删除数据
let deleteResult = entityService.delete("entity-id", "user-456")
```

### 4.4 API 调用示例

#### 4.4.1 创建授权

```bash
POST /api/v1/uctoo/data_access_authorization/add
Content-Type: application/json
Authorization: Bearer <token>

{
  "entity_type": "entity",
  "entity_id": "entity-123",
  "user_id": "user-456",
  "permission": 1
}
```

#### 4.4.2 删除授权

```bash
POST /api/v1/uctoo/data_access_authorization/del
Content-Type: application/json
Authorization: Bearer <token>

{
  "id": "auth-123"
}
```

#### 4.4.3 查询实体的授权记录

```bash
GET /api/v1/uctoo/data_access_authorization/entity/entity-123
Authorization: Bearer <token>
```

## 5. 表级行级权限配置

### 5.1 设计理念

表级行级权限配置允许管理员为不同的业务表单独控制是否启用行级权限，提供更细粒度的权限管理控制。这种设计基于以下考虑：

1. **灵活性**：不同业务表可能有不同的权限需求
2. **性能优化**：对于不需要行级权限的表，可以跳过权限检查，提高性能
3. **兼容性**：可以逐步迁移到行级权限，而不是一次性启用所有表
4. **管理便利性**：通过环境变量配置，无需修改代码即可调整权限策略

### 5.2 配置方法

#### 5.2.1 环境变量配置

在 `.env` 文件中，除了全局配置外，还可以为特定表添加配置：

```env
# 全局行级权限开关（默认值）
ROW_LEVEL_PERMISSION_ENABLED=true

# 表级行级权限配置
# 格式：ROW_LEVEL_PERMISSION_<表名>=true|false

# 启用行级权限的表
ROW_LEVEL_PERMISSION_entity=true
ROW_LEVEL_PERMISSION_i18=true
ROW_LEVEL_PERMISSION_lang=true

# 禁用行级权限的表
ROW_LEVEL_PERMISSION_uctoo_user=false
ROW_LEVEL_PERMISSION_permissions=false
ROW_LEVEL_PERMISSION_uctoo_role=false
```

#### 5.2.2 配置优先级

配置优先级从高到低：
1. **表级配置**：特定表的配置覆盖全局配置
2. **全局配置**：默认的行级权限开关
3. **代码默认值**：如果未配置，默认为 `true`

### 5.3 使用示例

#### 5.3.1 场景1：全部启用行级权限

```env
# 全局启用
ROW_LEVEL_PERMISSION_ENABLED=true

# 无需表级配置，所有表都启用
```

#### 5.3.2 场景2：部分启用行级权限

```env
# 全局禁用
ROW_LEVEL_PERMISSION_ENABLED=false

# 只对特定表启用
ROW_LEVEL_PERMISSION_entity=true
ROW_LEVEL_PERMISSION_i18=true
```

#### 5.3.3 场景3：部分禁用行级权限

```env
# 全局启用
ROW_LEVEL_PERMISSION_ENABLED=true

# 对特定表禁用
ROW_LEVEL_PERMISSION_uctoo_user=false
ROW_LEVEL_PERMISSION_permissions=false
```

### 5.4 实现原理

#### 5.4.1 配置加载

1. 应用启动时，`PermissionConfig` 类会扫描所有环境变量
2. 识别以 `ROW_LEVEL_PERMISSION_` 开头的环境变量
3. 提取表名和配置值，构建表级权限配置映射
4. 当检查特定表的权限时，优先使用表级配置

#### 5.4.2 权限检查流程

1. 当请求访问数据时，`PermissionUtils` 会检查表级行级权限是否启用
2. 如果表级权限未启用，直接返回授权成功
3. 如果表级权限启用，继续执行正常的权限检查流程
4. 对于批量查询，会根据表级配置决定是否添加权限过滤条件

### 5.5 最佳实践

#### 5.5.1 推荐配置策略

| 表类型 | 推荐配置 | 理由 |
|--------|----------|------|
| 业务数据 | `true` | 需要保护用户数据，确保数据安全 |
| 系统配置 | `false` | 系统配置通常需要全局访问，不需要行级权限 |
| 权限管理 | `false` | 权限管理表本身需要管理员全局访问 |
| 用户表 | `false` | 用户信息可能需要跨用户访问（如管理员查看所有用户） |
| 日志表 | `false` | 日志通常需要管理员全局访问 |

#### 5.5.2 性能优化建议

1. **禁用不需要的表**：对于不需要行级权限的表，明确禁用以提高性能
2. **合理分组**：将需要相同权限策略的表归为一类
3. **定期审查**：定期审查表级权限配置，确保配置与业务需求一致
4. **监控性能**：对于大数据量的表，监控行级权限对性能的影响

#### 5.5.3 迁移策略

1. **初始阶段**：全局禁用，仅对核心业务表启用
2. **过渡阶段**：全局启用，对不需要的表单独禁用
3. **成熟阶段**：根据业务需求精细配置每个表的权限策略

### 5.6 常见问题

#### 5.6.1 配置不生效

**问题**：表级配置未生效

**解决方案**：
- 检查环境变量名称是否正确（`ROW_LEVEL_PERMISSION_<表名>`）
- 确认表名是否与数据库表名一致（区分大小写）
- 重启应用使配置生效
- 检查应用日志是否有配置加载错误

#### 5.6.2 性能影响

**问题**：启用行级权限后性能下降

**解决方案**：
- 对不需要行级权限的表禁用
- 确保数据库有适当的索引
- 启用权限缓存
- 优化批量查询

#### 5.6.3 权限冲突

**问题**：表级配置与业务需求冲突

**解决方案**：
- 重新评估业务需求
- 调整表级配置
- 考虑使用更细粒度的权限控制

## 6. 测试方案

### 6.1 单元测试

**文件路径**：`tests/PermissionUtilsTest.cj`

```cangjie
package tests

import magic.app.utils.PermissionUtils
import magic.app.core.PermissionLevel
import magic.app.config.PermissionConfig
import std.testing.Assert

public class PermissionUtilsTest {
    public static func testCheckUserHasPermission(): Unit {
        // 测试创建者权限
        let (hasPermission, reason) = PermissionUtils.checkUserHasPermission(
            "user-123", "entity", "entity-123", PermissionLevel.READ
        )
        Assert.assertTrue(hasPermission)

        // 测试授权权限
        let (hasPermission2, reason2) = PermissionUtils.checkUserHasPermission(
            "user-456", "entity", "entity-123", PermissionLevel.READ
        )
        Assert.assertTrue(hasPermission2)

        // 测试无权限
        let (hasPermission3, reason3) = PermissionUtils.checkUserHasPermission(
            "user-789", "entity", "entity-123", PermissionLevel.READ
        )
        Assert.assertFalse(hasPermission3)
    }

    public static func testTableLevelPermission(): Unit {
        // 测试表级权限配置
        let enabledForEntity = PermissionConfig.isRowLevelPermissionEnabledForTable("entity")
        let enabledForUser = PermissionConfig.isRowLevelPermissionEnabledForTable("uctoo_user")
        
        // 根据配置断言结果
        // Assert.assertTrue(enabledForEntity)
        // Assert.assertFalse(enabledForUser)
    }

    public static func testGetUserAuthorizedDataIds(): Unit {
        let ids = PermissionUtils.getUserAuthorizedDataIds(
            "user-456", "entity", PermissionLevel.READ
        )
        Assert.assertTrue(ids.size > 0)
    }

    public static func testGenerateRowLevelPermissionFilter(): Unit {
        let (whereClause, params) = PermissionUtils.generateRowLevelPermissionFilter(
            "user-456", "entity", PermissionLevel.READ
        )
        Assert.assertTrue(whereClause.contains("creator"))
        Assert.assertTrue(params.size > 0)
    }
}
```

### 6.2 集成测试

**文件路径**：`tests/EntityServiceIntegrationTest.cj`

```cangjie
package tests

import magic.app.services.uctoo.EntityService
import magic.app.models.uctoo.EntityPO
import magic.app.utils.PermissionUtils
import magic.app.core.PermissionLevel
import magic.app.config.PermissionConfig
import std.testing.Assert

public class EntityServiceIntegrationTest {
    public static func testCreateAndQuery(): Unit {
        let service = EntityService()

        // 1. 创建实体
        let entity = EntityPO()
        entity.link = "https://example.com"
        entity.stars = 5.0
        entity.description = "测试数据"

        let createResult = service.create(entity, "user-123")
        Assert.assertTrue(createResult.success)

        let entityId = createResult.data.getOrThrow().id

        // 2. 授权给其他用户
        let authResult = PermissionUtils.createDataAccessRule(
            "entity", entityId, "user-456", PermissionLevel.READ, "user-123"
        )
        Assert.assertTrue(authResult)

        // 3. 使用被授权用户查询
        let queryResult = service.findById(entityId, "user-456")
        Assert.assertTrue(queryResult.success)

        let queriedEntity = queryResult.data.getOrThrow()
        Assert.assertEquals(entity.description, queriedEntity.description)
    }

    public static func testUpdateWithoutPermission(): Unit {
        let service = EntityService()

        // 1. 创建实体
        let entity = EntityPO()
        entity.link = "https://example.com"
        entity.stars = 5.0
        entity.description = "测试数据"

        let createResult = service.create(entity, "user-123")
        Assert.assertTrue(createResult.success)

        let entityId = createResult.data.getOrThrow().id

        // 2. 授权给其他用户（只读权限）
        let authResult = PermissionUtils.createDataAccessRule(
            "entity", entityId, "user-456", PermissionLevel.READ, "user-123"
        )
        Assert.assertTrue(authResult)

        // 3. 尝试更新（应该失败）
        let updateEntity = EntityPO()
        updateEntity.id = entityId
        updateEntity.description = "更新后的描述"

        let updateResult = service.update(updateEntity, "user-456")
        Assert.assertFalse(updateResult.success)
    }

    public static func testTableLevelPermissionBypass(): Unit {
        // 假设 uctoo_user 表禁用了行级权限
        let service = UserService()  // 假设存在 UserService

        // 尝试访问其他用户的数据
        // 应该成功，因为表级权限已禁用
        let user = service.findById("other-user-id", "current-user-id")
        Assert.assertTrue(user.success)
    }
}
```

## 7. 迁移指南

### 7.1 从 v3 迁移到 v4

#### 7.1.1 数据迁移

```sql
-- 1. 迁移 data_access_authorization 表数据（如果需要）
-- v3 和 v4 的表结构相同，无需迁移

-- 2. 确保所有业务表都有 creator 字段
-- 示例：为 entity 表添加 creator 字段（如果不存在）
ALTER TABLE "public"."entity" 
ADD COLUMN IF NOT EXISTS "creator" uuid;

-- 3. 为现有数据设置 creator 字段（根据业务逻辑）
-- UPDATE "public"."entity" SET "creator" = 'default-user-id' WHERE "creator" IS NULL;
```

#### 7.1.2 代码迁移

1. **Service 层迁移**
   - 在所有 Service 的查询、更新、删除方法中添加权限检查
   - 使用 `PermissionUtils.checkUserHasPermission()` 检查单条数据权限
   - 使用 `PermissionUtils.generateRowLevelPermissionFilter()` 生成批量查询过滤条件

2. **Controller 层迁移**
   - 在需要授权管理的接口中添加授权创建和删除功能
   - 使用 `DataAccessAuthorizationController` 提供的 API

3. **配置迁移**
   - 在 `.env` 文件中添加 `ROW_LEVEL_PERMISSION_ENABLED=true`
   - 为需要单独控制的表添加表级配置
   - 配置权限缓存过期时间

### 7.2 最佳实践

1. **权限设计原则**
   - 默认无权限，按需分配
   - 最小权限原则
   - 定期审计权限

2. **性能优化**
   - 使用权限缓存减少数据库访问
   - 批量查询优化
   - 合理使用数据库索引
   - 对不需要行级权限的表禁用

3. **安全建议**
   - 敏感操作需要二次确认
   - 记录权限变更日志
   - 定期清理过期的授权记录

## 8. 常见问题

### 8.1 如何判断是否需要启用行级权限？

**答**：如果您的应用需要满足以下任一条件，建议启用行级权限：
- 多用户共享数据，但每个用户只能访问自己的数据
- 需要实现数据共享和协作功能
- 需要细粒度的数据访问控制
- 对数据安全性要求较高

### 8.2 行级权限会影响性能吗？

**答**：会有一定影响，但通过以下优化可以最小化影响：
- 使用权限缓存
- 批量查询优化
- 合理使用数据库索引
- 只在必要时启用行级权限
- 对不需要行级权限的表禁用

### 8.3 如何处理权限继承？

**答**：v4 版本不支持角色权限继承，但支持数据权限继承：
- 可授权权限 (3) 包含可写权限 (2) 和可读权限 (1)
- 可写权限 (2) 包含可读权限 (1)

### 8.4 如何批量授权？

**答**：可以通过以下方式批量授权：
1. 使用循环调用 `PermissionUtils.createDataAccessRule()`
2. 创建批量授权 API 接口
3. 使用数据库批量插入

### 8.5 如何撤销授权？

**答**：通过以下方式撤销授权：
1. 调用 `PermissionUtils.deleteDataAccessRule()` 删除授权记录
2. 调用 `DataAccessAuthorizationController.del()` API
3. 直接删除 `data_access_authorization` 表中的记录

## 9. 未来扩展

### 9.1 计划中的功能

1. **权限组管理**
   - 支持将多个用户组成权限组
   - 支持将权限组授权给数据

2. **权限模板**
   - 预定义常用权限模板
   - 快速应用权限模板

3. **权限审计**
   - 记录所有权限变更操作
   - 支持权限变更历史查询

4. **权限推荐**
   - 基于用户行为推荐权限
   - 智能权限分配

5. **动态权限配置**
   - 支持运行时修改表级权限配置
   - 提供权限配置管理界面

### 9.2 性能优化方向

1. **分布式缓存**
   - 使用 Redis 等分布式缓存
   - 支持多实例共享权限缓存

2. **权限预计算**
   - 预计算用户权限集合
   - 减少实时权限检查

3. **权限索引优化**
   - 使用更高效的索引结构
   - 支持复合索引

## 10. 参考资料

### 10.1 相关文档

- [uctoo v4 用户权限体系](./user-permission-system.md)
- [uctoo v3 行级数据权限机制](../../../backend/docs/user-permission-system.md)
- [RBAC 权限模型](https://en.wikipedia.org/wiki/Role-based_access_control)

### 10.2 技术文档

- [仓颉编程语言指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/)
- [PostgreSQL 文档](https://www.postgresql.org/docs/)
- [数据库索引优化](https://www.postgresql.org/docs/current/indexes.html)

---

**文档维护**：本文档由 uctoo v4 技术团队维护，如有问题请联系技术负责人。
