# Model Pattern Reference

Data Model pattern for UCToo V4, following the EntityPO implementation.

## Overview

The Model layer defines the data structure and provides:
- Type-safe field definitions
- ORM annotations for table mapping
- JSON serialization via `toJson()` method
- Standard fields for audit and soft delete

## File Structure

```
src/app/models/{database}/{Table}PO.cj
```

## Basic Template

```cangjie
/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.models.{database}

import std.time.DateTime
import f_orm.macros.{QueryMappersGenerator, ORMField}
import f_orm.*

/**
 * {Table}PO - {表描述}数据模型
 */
@QueryMappersGenerator["{table_name}"]
public class {Table}PO {
    @ORMField[true]
    public var id: String = ""
    
    public var name: String = ""
    public var description: ?String = None<String>
    public var status: Int32 = 0
    
    public var createdAt: DateTime = DateTime.now()
    public var updatedAt: DateTime = DateTime.now()
    public var deletedAt: ?String = None<String>
    public var creator: String = ""
    
    public init() {}
    
    public func toJson(): String {
        // JSON序列化实现
    }
}
```

## ORM Annotations

### @QueryMappersGenerator

Specifies the database table name:

```cangjie
@QueryMappersGenerator["entity"]  // Maps to "entity" table
public class EntityPO {
    // ...
}
```

### @ORMField

Marks primary key and column name mapping:

```cangjie
@ORMField[true]                    // Primary key
public var id: String = ""

@ORMField[false "privacy_level"]   // Column name mapping
public var privacyLevel: Int32 = 0
```

## Field Types

| Prisma Type | Cangjie Type | Default Value | Notes |
|-------------|--------------|---------------|-------|
| String | String | "" | Required string |
| String? | ?String | None<String> | Nullable string |
| Int | Int32 | 0 | Integer |
| Float | Float64 | 0.0 | Floating point |
| Boolean | Bool | false | Boolean |
| DateTime | DateTime | DateTime.now() | Timestamp |
| DateTime? | ?String | None<String> | Stored as ISO string |
| @db.Uuid | String | "" | UUID |

## Standard Fields

Every model should include these standard fields:

```cangjie
// Primary key
@ORMField[true]
public var id: String = ""

// Audit fields
public var createdAt: DateTime = DateTime.now()
public var updatedAt: DateTime = DateTime.now()
public var creator: String = ""

// Soft delete field
public var deletedAt: ?String = None<String>
```

## toJson() Method

Implement JSON serialization for API responses:

```cangjie
public func toJson(): String {
    let sb = StringBuilder()
    sb.append("{")
    sb.append("\"id\":\"" + id + "\"")
    sb.append(",\"name\":\"" + name + "\"")
    if (let Some(desc) <- description) {
        sb.append(",\"description\":\"" + desc + "\"")
    }
    sb.append(",\"status\":" + status.toString())
    sb.append(",\"createdAt\":\"" + createdAt.toString() + "\"")
    sb.append(",\"updatedAt\":\"" + updatedAt.toString() + "\"")
    if (let Some(da) <- deletedAt) {
        sb.append(",\"deletedAt\":\"" + da + "\"")
    } else {
        sb.append(",\"deletedAt\":\"\"")
    }
    sb.append(",\"creator\":\"" + creator + "\"")
    sb.append("}")
    return sb.toString()
}
```

## Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Class name | PascalCase + PO | EntityPO |
| File name | PascalCase + PO.cj | EntityPO.cj |
| Field name | camelCase | privacyLevel |
| Database column | snake_case | privacy_level |

## Column Name Mapping

When field name differs from column name:

```cangjie
// Database: privacy_level, Cangjie: privacyLevel
@ORMField[false "privacy_level"]
public var privacyLevel: Int32 = 0

// Database: group_id, Cangjie: groupId
@ORMField[false "group_id"]
public var groupId: ?String = None<String>
```

## Best Practices

1. **Always include standard fields**: id, createdAt, updatedAt, deletedAt, creator
2. **Use Option types for nullable fields**: `?String`, `?Int32`
3. **Implement toJson() for all models**: Required for API responses
4. **Use @ORMField for column mapping**: When names differ between DB and Cangjie
5. **Keep models simple**: No business logic, only data structure
