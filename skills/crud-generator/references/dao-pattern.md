# DAO Pattern Reference

Data Access Object pattern for UCToo V4, following the EntityDAO implementation.

## Overview

The DAO layer encapsulates all database operations, providing:
- Clean separation between data access and business logic
- Consistent query patterns using Fountain ORM
- No soft delete filtering (returns complete data set)
- Type-safe operations with compile-time checking

## File Structure

```
src/app/dao/{database}/{Table}DAO.cj
```

## Basic Template

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
    
    // Methods...
}
```

## Standard Methods

### Insert Operations

```cangjie
/**
 * 插入记录（id由数据库自动生成UUID）
 * @param entity 实体对象
 * @return 插入成功返回生成的ID，失败返回空字符串
 */
func insert{Table}(entity: {Table}PO): String {
    executor.setSql('''
        insert into {table_name}(
            field1, field2, creator, created_at, updated_at, deleted_at
        ) values(
            ${arg(entity.field1)}, ${arg(entity.field2)},
            ${arg(entity.creator)}, ${arg(entity.createdAt)},
            ${arg(entity.updatedAt)}, ${arg(entity.deletedAt)}
        )
        returning id
    ''').singleFirst<String>() ?? ""
}
```

### Single Record Queries

```cangjie
/**
 * 根据ID查询（不过滤软删除）
 * @param id 记录ID
 * @return 实体对象（Option类型）
 */
func findById(id: String): Option<{Table}PO> {
    executor.setSql('''
        select * from {table_name} where id = ${arg(id)}
    ''').first<{Table}PO>()
}

/**
 * 根据唯一字段查询
 * @param field 字段值
 * @return 实体对象（Option类型）
 */
func findByUniqueField(field: String): Option<{Table}PO> {
    executor.setSql('''
        select * from {table_name} where unique_field = ${arg(field)}
    ''').first<{Table}PO>()
}
```

### List Queries

```cangjie
/**
 * 分页查询所有记录
 * @param page 页码（从1开始）
 * @param size 每页大小
 * @return 分页结果
 */
func findAllPage(page: Int64, size: Int64): Pagination<{Table}PO> {
    executor.page<{Table}PO>('''
        select * from {table_name} order by created_at desc
    ''', size, page: page)
}

/**
 * 按条件分页查询
 * @param condition 条件值（可选）
 * @param page 页码
 * @param size 每页大小
 * @return 分页结果
 */
func findByConditionPage(
    condition: ?String,
    page: Int64,
    size: Int64
): Pagination<{Table}PO> {
    // 构建动态WHERE条件
    let whereClause = if (let Some(c) <- condition) {
        "where field = ${arg(c)}"
    } else {
        ""
    }
    
    executor.page<{Table}PO>('''
        select * from {table_name} ${whereClause} order by created_at desc
    ''', size, page: page)
}

/**
 * 查询所有记录（不分页）
 * @return 实体列表
 */
func listAll(): ArrayList<{Table}PO> {
    executor.setSql('''
        select * from {table_name} order by created_at desc
    ''').list<{Table}PO>()
}

/**
 * 批量查询
 * @param ids ID列表
 * @return 实体列表
 */
func findByIds(ids: ArrayList<String>): ArrayList<{Table}PO> {
    executor.setSql('''
        select * from {table_name} where id ${IN(ids)}
    ''').list<{Table}PO>()
}
```

### Update Operations

```cangjie
/**
 * 更新记录
 * @param entity 实体对象
 * @return 影响行数
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

/**
 * 更新特定字段
 * @param id 记录ID
 * @param value 新值
 * @return 影响行数
 */
func updateField(id: String, value: String): Int64 {
    executor.setSql('''
        update {table_name} set field = ${arg(value)}, updated_at = ${arg(DateTime.now())} 
        where id = ${arg(id)}
    ''').update
}
```

### Delete Operations

```cangjie
/**
 * 软删除
 * @param id 记录ID
 * @return 影响行数
 */
func softDeleteById(id: String): Int64 {
    executor.setSql('''
        update {table_name} set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
    ''').update
}

/**
 * 恢复软删除的记录
 * @param id 记录ID
 * @return 影响行数
 */
func restoreById(id: String): Int64 {
    executor.setSql('''
        update {table_name} set deleted_at = null where id = ${arg(id)}
    ''').update
}

/**
 * 硬删除
 * @param id 记录ID
 * @return 影响行数
 */
func deleteById(id: String): Int64 {
    executor.setSql('''
        delete from {table_name} where id = ${arg(id)}
    ''').delete
}
```

### Count Operations

```cangjie
/**
 * 统计总数
 * @return 数量
 */
func countAll(): Int64 {
    executor.setSql('''
        select count(*) from {table_name}
    ''').first<Int64>() ?? 0
}

/**
 * 按条件统计
 * @param condition 条件值
 * @return 数量
 */
func countByCondition(condition: String): Int64 {
    executor.setSql('''
        select count(*) from {table_name} where field = ${arg(condition)}
    ''').first<Int64>() ?? 0
}
```

## Query Patterns

### Correct: Use setSql

```cangjie
// ✅ 单条查询
executor.setSql('select * from table where id = ${arg(id)}').first<{Table}PO>()

// ✅ 列表查询
executor.setSql('select * from table where field = ${arg(value)}').list<{Table}PO>()

// ✅ 分页查询
executor.page<{Table}PO>('select * from table order by created_at desc', size, page: page)

// ✅ 更新
executor.setSql('update table set field = ${arg(value)} where id = ${arg(id)}').update

// ✅ 删除
executor.setSql('delete from table where id = ${arg(id)}').delete
```

### Incorrect: Avoid FROM().WHERE().first()

```cangjie
// ❌ 错误：first() 不使用 sqlgen，WHERE条件会被忽略
executor.FROM<{Table}PO>()
    .WHERE{'id = ${arg(id)}'}
    .first<{Table}PO>()

// ❌ 错误：list() 可以工作，但建议统一使用 setSql
executor.FROM<{Table}PO>()
    .WHERE{'field = ${arg(value)}'}
    .list<{Table}PO>()
```

## Design Principles

1. **No Business Logic**: DAO only handles data access, no business rules
2. **No Soft Delete Filtering**: All queries return complete data including soft-deleted records
3. **Use setSql**: Always use `setSql` method for consistent behavior
4. **Type Safety**: Use generic type parameters for compile-time checking
5. **Option Types**: Return `Option<T>` for single record queries
6. **Pagination**: Use `Pagination<T>` for paginated results

## Field Name Mapping

When field names differ between database and Cangjie:

| Database Column | Cangjie Field | In SQL |
|----------------|---------------|--------|
| privacy_level | privacyLevel | privacy_level |
| created_at | createdAt | created_at |
| group_id | groupId | group_id |

In SQL, always use database column names:
```cangjie
executor.setSql('''
    select * from entity where privacy_level = ${arg(level)}
''').list<EntityPO>()
```
