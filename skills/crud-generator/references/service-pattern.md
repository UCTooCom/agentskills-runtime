# Service Pattern Reference

Service layer pattern for UCToo V4, following the EntityService implementation.

## Overview

The Service layer provides:
- Business logic for CRUD operations
- Data validation and transformation
- Transaction coordination
- APIResult wrapper for consistent responses

## File Structure

```
src/app/services/{database}/{Table}Service.cj
```

## Basic Template

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
 */
public class {Table}Service {
    
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }
    
    public init() {}
    
    // CRUD methods...
}
```

## Standard Methods

### Create

```cangjie
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
```

### Update

```cangjie
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
```

### Batch Update

```cangjie
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
```

### Delete

```cangjie
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
```

### Batch Delete

```cangjie
public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
    try {
        var rows: Int64 = 0
        for (id in ids) {
            let existing = getExecutor().findById(id)
            if (existing.isSome()) {
                if (force) {
                    rows = rows + getExecutor().deleteById(id)
                } else {
                    rows = rows + getExecutor().softDeleteById(id)
                }
            }
        }
        
        if (rows > 0) {
            return APIResult<Bool>(true)
        } else {
            return APIResult<Bool>(false, "批量删除失败")
        }
    } catch (e: Exception) {
        return APIResult<Bool>(false, e.message)
    }
}
```

### Restore

```cangjie
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
```

### Get By ID

```cangjie
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
```

### Get List

```cangjie
public func getList(page: Int32, pageSize: Int32): (ArrayList<{Table}PO>, Int64) {
    let pagination = getExecutor().findAllPage(
        Int64(page + 1),
        Int64(pageSize)
    )
    
    return (pagination.list, pagination.rows)
}
```

## APIResult Usage

```cangjie
// Success with data
return APIResult<{Table}PO>(entity)

// Success with boolean
return APIResult<Bool>(true)

// Failure with message
return APIResult<{Table}PO>(false, "错误信息")

// Check result
if (result.success) {
    if (let Some(data) <- result.data) {
        // Use data
    }
} else {
    let reason = result.reason ?? "默认错误"
}
```

## Design Principles

1. **Use DAO for data access**: Never write SQL in Service
2. **Return APIResult**: Consistent response format
3. **Handle exceptions**: Catch and return error messages
4. **Set timestamps**: createdAt, updatedAt
5. **Validate existence**: Check before update/delete
6. **Support batch operations**: updateMultiple, deleteMultiple

## Logging

```cangjie
import magic.log.LogUtils

LogUtils.info("{Table}Service", "操作描述")
LogUtils.error("{Table}Service", "错误: ${e.message}")
```
