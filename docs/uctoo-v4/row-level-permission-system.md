# uctoo v4 行级数据权限机制

## 文档信息
- **版本**: 4.0
- **创建日期**: 2026-04-04
- **更新日期**: 2026-05-15
- **状态**: 已实现

## 1. 概述

### 1.1 设计目标

uctoo v4 的行级数据权限机制旨在实现细粒度的数据访问控制，确保用户只能访问其有权限的数据行。该机制与 RBAC3 权限体系协同工作，提供完整的数据安全保障。

### 1.2 核心原则

1. **安全优先，默认无权限**：用户只能访问自己创建的数据或被明确授权的数据
2. **最小权限原则**：按需分配权限，避免过度授权
3. **权限分级**：支持读、写、授权三级权限控制
4. **可配置性**：通过环境变量控制是否启用行级权限（全局/表级）
5. **向后兼容**：与 v3 版本的权限机制保持一致，便于迁移

### 1.3 实现状态

| 功能 | 状态 | 说明 |
|------|------|------|
| 单条数据权限检查 | ✅ 已实现 | 支持 READ/WRITE/AUTHORIZE 三级权限 |
| 批量数据权限过滤 | ✅ 已实现 | 查询时自动过滤无权限数据 |
| 数据授权管理 | ✅ 已实现 | 创建/删除授权记录 |
| 权限缓存 | ✅ 已实现 | 内存缓存，支持配置过期时间 |
| 通配符权限 | ✅ 已实现 | 拥有 `*` 权限的用户跳过行级检查 |
| 表级权限开关 | ✅ 已实现 | 支持按表配置是否启用行级权限 |

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
| 1 | READ | 可以读取数据，对应 GET 请求 |
| 2 | WRITE | 可以修改数据，对应 POST/PUT/PATCH 请求 |
| 3 | AUTHORIZE | 可以授权给其他用户，同时具有读写权限 |

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
   - 检查用户是否有通配符权限（`*`），有则直接允许
   - 检查用户是否是数据创建者（creator），是则允许
   - 如果不是，检查是否有授权记录
   - 如果有授权，检查权限级别是否满足要求
   - 如果无权限，返回 403 错误

#### 2.2.2 批量数据访问

```
用户请求 → 中间件检查 API 权限 → Service 层构建权限过滤 → 查询数据库 → 返回数据
```

**详细流程**：

1. **API 权限检查**（中间件）
   - 检查用户是否有访问该 API 的权限（RBAC3）

2. **构建权限过滤**（Service 层）
   - 检查用户是否有通配符权限，有则跳过过滤
   - 获取用户 ID
   - 查询用户被授权的实体 ID 列表（带缓存）
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
├─ 用户是否有通配符权限 (*)？
│   ├─ 是 → 允许访问（跳过行级检查）
│   └─ 否 → 继续
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

## 3. 核心组件实现

### 3.1 PermissionLevel（权限级别枚举）

**文件路径**：`src/app/core/PermissionLevel.cj`

```cangjie
public enum PermissionLevel {
    | READ
    | WRITE
    | AUTHORIZE

    public func value(): Int32 {
        match (this) {
            case READ => 1
            case WRITE => 2
            case AUTHORIZE => 3
        }
    }
}

public func hasPermission(userPermission: PermissionLevel, required: PermissionLevel): Bool {
    return userPermission.value() >= required.value()
}
```

### 3.2 PermissionConfig（配置管理）

**文件路径**：`src/app/core/PermissionConfig.cj`

**环境变量配置**：

```env
# 行级数据权限开关（全局默认）
ROW_LEVEL_PERMISSION_ENABLED=true

# 权限缓存过期时间（秒）
PERMISSION_CACHE_TTL=300

# 权限缓存最大条目数
PERMISSION_CACHE_MAX_SIZE=10000

# 表级行级权限配置（可选）
# 格式：ROW_LEVEL_PERMISSION_<表名>=true|false
ROW_LEVEL_PERMISSION_entity=true
ROW_LEVEL_PERMISSION_uctoo_user=false
```

**核心方法**：

| 方法 | 功能 |
|------|------|
| `isRowLevelPermissionEnabled()` | 检查全局是否启用行级权限 |
| `isRowLevelPermissionEnabledForTable(entityType)` | 检查特定表是否启用行级权限 |
| `getPermissionCacheTTL()` | 获取缓存过期时间 |
| `getPermissionCacheMaxSize()` | 获取缓存最大容量 |

### 3.3 PermissionCache（权限缓存）

**文件路径**：`src/app/core/PermissionCache.cj`

**缓存类型**：

| 缓存类型 | 用途 | Key 格式 |
|----------|------|----------|
| 单条权限缓存 | 存储用户对特定实体的权限级别 | `${userId}:${entityType}:${entityId}` |
| 过滤条件缓存 | 存储用户有权访问的实体 ID 列表 | `${userId}:${entityType}:filter` |

**缓存策略**：
- LRU 淘汰策略（当超过最大容量时淘汰最旧条目）
- 支持按用户/实体类型/实体 ID 失效缓存

### 3.4 PermissionUtils（权限工具类）

**文件路径**：`src/app/utils/PermissionUtils.cj`

**核心方法**：

| 方法 | 功能 | 参数 |
|------|------|------|
| `hasWildcardPermission(userId)` | 检查用户是否有通配符权限 | `userId`: 用户ID |
| `checkReadPermission(userId, entityId, entityType)` | 检查读权限 | 同上 |
| `checkWritePermission(userId, entityId, entityType)` | 检查写权限 | 同上 |
| `checkAuthorizePermission(userId, entityId, entityType)` | 检查授权权限 | 同上 |
| `checkUserHasPermission(userId, entityType, entityId, requiredPermission)` | 通用权限检查 | `requiredPermission`: 所需权限级别 |
| `appendPermissionFilter(userId, entityType)` | 生成权限过滤条件 | 返回 `(WHERE子句, 参数列表)` |
| `autoGrantCreatorPermission(userId, entityId, entityType)` | 自动为创建者授权 | 创建数据后自动调用 |
| `createDataAccessRule(entityType, entityId, userId, permission, authorizerId)` | 创建授权规则 | `authorizerId`: 授权人ID |
| `deleteDataAccessRule(authId, operatorId, entityType, entityId)` | 删除授权规则 | 软删除授权记录 |

## 4. Service 层集成

### 4.1 EntityService 权限方法

**文件路径**：`src/app/services/uctoo/EntityService.cj`

**权限增强方法**：

| 方法 | 功能 | 权限检查 |
|------|------|----------|
| `createWithPermission(entity, creatorId)` | 创建实体并自动授权 | 创建后调用 `autoGrantCreatorPermission` |
| `getByIdWithPermission(entityId, userId)` | 按ID查询（带权限检查） | READ 权限 |
| `getListWithPermission(page, pageSize, sort, filter, userId)` | 列表查询（带权限过滤） | READ 权限 |
| `updateWithPermission(entityId, entity, userId)` | 更新实体（带权限检查） | WRITE 权限 |
| `deleteWithPermission(entityId, force, userId)` | 删除实体（带权限检查） | WRITE 权限 |

**权限检查示例**（`getByIdWithPermission`）：

```cangjie
public func getByIdWithPermission(entityId: String, userId: String): APIResult<EntityPO> {
    try {
        let (hasPermission, reason) = PermissionUtils.checkReadPermission(userId, entityId, "entity")
        if (!hasPermission) {
            return APIResult<EntityPO>(false, reason)
        }
        return getById(entityId)
    } catch (e: Exception) {
        return APIResult<EntityPO>(false, e.message)
    }
}
```

**列表过滤示例**（`getListWithPermission`）：

```cangjie
public func getListWithPermission(page, pageSize, sort, filter, userId): (ArrayList<EntityPO>, Int64) {
    if (PermissionUtils.hasWildcardPermission(userId)) {
        return getListWithFilter(page, pageSize, sort, filter)
    }
    
    let (permFilter, _) = PermissionUtils.appendPermissionFilter(userId, "entity")
    
    if (permFilter == "1=1" || permFilter.isEmpty()) {
        return getListWithFilter(page, pageSize, sort, filter)
    }
    
    // 组合用户过滤条件和权限过滤条件
    var whereClause = ...
    if (whereClause.isEmpty()) {
        whereClause = permFilter
    } else {
        whereClause = "(${whereClause}) AND ${permFilter}"
    }
    
    // 执行查询...
}
```

### 4.2 DataAccessAuthorizationService（授权管理服务）

**文件路径**：`src/app/services/uctoo/DataAccessAuthorizationService.cj`

**核心方法**：

| 方法 | 功能 | 说明 |
|------|------|------|
| `createAuthorization(entityType, entityId, granteeId, permission, authorizerId)` | 创建授权 | 检查授权者是否有授权权限 |
| `deleteAuthorization(authId, operatorId)` | 删除授权 | 检查操作者是否有授权权限 |
| `getEntityAuthorizations(entityType, entityId, operatorId)` | 查询实体授权列表 | 检查操作者是否有读权限 |

## 5. Controller 层集成

### 5.1 EntityController 权限集成

**文件路径**：`src/app/controllers/uctoo/entity/EntityController.cj`

**权限集成示例**：

```cangjie
public func getSingle(req: HttpRequest, res: HttpResponse): Unit {
    let userId = req.getLocals("userId")
    var userIdStr = ""
    if (let Some(u) <- userId) {
        let sOpt = u as String
        if (let Some(s) <- sOpt) { userIdStr = s }
    }
    
    let result = if (userIdStr.isEmpty()) {
        service.getById(idVal)
    } else {
        service.getByIdWithPermission(idVal, userIdStr)
    }
    
    if (result.success) {
        res.status(200).json(data.toJson())
    } else {
        res.status(403).json("{\"errno\":\"40301\",\"errmsg\":\"您没有权限访问该entity\"}")
    }
}
```

## 6. 数据库索引优化

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
```

## 7. 使用示例

### 7.1 创建数据并自动授权

```cangjie
// 创建实体（自动为创建者授予授权权限）
let entity = EntityPO()
entity.link = "https://example.com"
entity.stars = 5.0
entity.description = Some("示例数据")

let result = entityService.createWithPermission(entity, "user-123")
if (result.success) {
    // 创建成功，创建者已自动获得 AUTHORIZE 权限
}
```

### 7.2 查询数据列表（带权限过滤）

```cangjie
// 查询用户有权访问的实体列表
let (entities, total) = entityService.getListWithPermission(
    page = 1,
    pageSize = 10,
    sort = "-created_at",
    filter = "{}",
    userId = "user-123"
)

// 返回的 entities 只包含：
// 1. user-123 创建的数据
// 2. 其他用户授权给 user-123 访问的数据
```

### 7.3 授权给其他用户

```cangjie
// 授权 user-456 对指定实体有可读权限
let authResult = dataAccessAuthorizationService.createAuthorization(
    entityType = "entity",
    entityId = "entity-id-123",
    granteeId = "user-456",
    permission = PermissionLevel.READ,
    authorizerId = "user-123"  // 必须有 AUTHORIZE 权限
)
```

### 7.4 检查权限

```cangjie
// 检查用户是否有写权限
let (hasPermission, reason) = PermissionUtils.checkWritePermission(
    userId = "user-123",
    entityId = "entity-id-123",
    entityType = "entity"
)

if (!hasPermission) {
    // 拒绝访问
}
```

## 8. 权限缓存机制

### 8.1 缓存结构

```
PermissionCache
├── cache: HashMap<String, CacheEntry>      // 单条权限缓存
│   └── Key: "${userId}:${entityType}:${entityId}"
│       └── Value: { permission, createdAt, expireTime }
└── filterCache: HashMap<String, FilterCacheEntry>  // 过滤条件缓存
    └── Key: "${userId}:${entityType}:filter"
        └── Value: { entityIds, createdAt, expireTime }
```

### 8.2 缓存失效策略

| 失效时机 | 失效方法 | 说明 |
|----------|----------|------|
| 创建授权 | `invalidate(userId, entityType, entityId)` | 失效被授权用户的单条缓存 |
| 删除授权 | `invalidateByEntity(entityType, entityId)` | 失效所有相关用户的缓存 |
| 更新授权 | `invalidateByUserAndEntityType(userId, entityType)` | 失效用户的相关缓存 |

## 9. 故障排除

### 9.1 常见问题

| 问题 | 可能原因 | 解决方案 |
|------|----------|----------|
| 查询数据为空 | 行级权限启用但用户无权限 | 检查用户是否是创建者或有授权 |
| 权限检查失败 | 缓存过期或未刷新 | 调用 `PermissionCache.clearAll()` 清空缓存 |
| 创建数据后无权限 | 自动授权失败 | 检查 `autoGrantCreatorPermission` 是否被调用 |
| 授权不生效 | 缓存未失效 | 检查授权后是否调用了缓存失效方法 |

### 9.2 日志调试

启用调试日志可以帮助定位问题：

```cangjie
LogUtils.info("EntityService", "getListWithPermission: userId=${userId}, permFilter=${permFilter}")
LogUtils.info("EntityService", "getListWithPermission: result size=${pagination.list.size}")
```

## 10. API 端点

### 10.1 数据授权端点

| 端点 | 方法 | 功能 |
|------|------|------|
| `/api/v1/uctoo/data_access_authorization/add` | POST | 创建授权 |
| `/api/v1/uctoo/data_access_authorization/del` | POST | 删除授权 |
| `/api/v1/uctoo/data_access_authorization/:entityType/:entityId` | GET | 查询实体授权列表 |

### 10.2 Entity 权限增强端点

所有 Entity CRUD 端点已集成行级权限检查：

| 端点 | 方法 | 权限检查 |
|------|------|----------|
| `/api/v1/uctoo/entity/add` | POST | 创建后自动授权 |
| `/api/v1/uctoo/entity/edit` | POST | WRITE 权限 |
| `/api/v1/uctoo/entity/delete` | POST | WRITE 权限 |
| `/api/v1/uctoo/entity/:id` | GET | READ 权限 |
| `/api/v1/uctoo/entity/:limit/:page` | GET | READ 权限（列表过滤） |

---

**版本**: 4.0  
**更新日期**: 2026-05-15