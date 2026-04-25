# UCToo V4 查询参数解析实现方案

## 文档信息
- **版本**: 1.0.0
- **创建日期**: 2026-04-05
- **适用范围**: uctoo V4.0 agentskills-runtime

## 1. UCToo V3 查询机制分析

### 1.1 核心组件

#### RequestParserService (后端)
位置: `apps/backend/src/app/lib/request-parser/src/lib/services/request-parser.service.ts`

**功能**：
- 解析查询参数中的 `filter`、`sort`、`page`、`limit`
- 将 JSON 字符串格式的 filter 解析为对象
- 将逗号分隔的 sort 字符串解析为数组

**核心代码**：
```typescript
parseQuery(query: any): ParsedQueryModel {
  const page = this.parsePage();
  const limit = this.parseLimit();
  const sort = this.parseSort();
  const filter = this.parseFilter();
  
  return {
    page: page,
    skip: this.calculateSkip(page, limit),
    take: limit,
    sort: sort,
    filter: filter,
  };
}

private parseFilter(): object {
  let filter: object = {};
  const filterRequestData = this.query[this.options.filterParamName];
  
  try {
    filter = JSON.parse(filterRequestData);
  } catch (e) {
    return filter;
  }
  return filter;
}

private parseSort(): ParsedQuerySortModel[] {
  const sort: ParsedQuerySortModel[] = [];
  const sortRequestData = this.query[this.options.orderParamName];
  const sortQuery = (sortRequestData as string).trim();
  
  if (sortQuery.length > 0) {
    const sortParams = sortQuery.split(',');
    
    for (let sortParam of sortParams) {
      sortParam = sortParam.trim();
      let sortDirection = 'asc';
      
      if (sortParam.startsWith('-')) {
        sortParam = sortParam.substring(1);
        sortDirection = 'desc';
      }
      
      sort.push({ [sortParam]: sortDirection });
    }
  }
  
  return sort;
}
```

#### buildPrismaWhere (前端)
位置: `apps/uctoo-app-client-pc/src/utils/prismaUtils.ts`

**功能**：
- 将前端搜索表单转换为 Prisma WHERE 条件
- 支持多种操作符：equals, not, lt, lte, gt, gte, contains, in, isSet
- 支持日期范围查询

**核心代码**：
```typescript
export function buildPrismaWhere(
  searchForm: Record<string, any>,
  searchOperator: Record<string, string | null>
): PrismaWhereCondition {
  const where: PrismaWhereCondition = {};
  
  Object.entries(searchForm).forEach(([field, rawValue]) => {
    const operator = searchOperator[field];
    const value = normalizeValue(rawValue, field);
    
    if (!operator || value === null || value === undefined) return;
    
    const condition = buildCondition(operator, value, field);
    if (condition) where[field] = condition;
  });
  
  return where;
}

function buildCondition(operator: string, value: any): Record<string, any> | null {
  switch (operator) {
    case 'equals': return { equals: value };
    case 'not': return { not: value };
    case 'lt': return { lt: castNumber(value) };
    case 'lte': return { lte: castNumber(value) };
    case 'gt': return { gt: castNumber(value) };
    case 'gte': return { gte: castNumber(value) };
    case 'contains': return { contains: value, mode: 'insensitive' };
    case 'in': return { in: convertToArray(value) };
    case 'isSet': return { isSet: !!value };
    default: return null;
  }
}
```

### 1.2 查询流程

```
前端搜索表单
  ↓ buildPrismaWhere()
Prisma WHERE 条件对象
  ↓ JSON.stringify()
filter 查询参数字符串
  ↓ HTTP GET
后端 RequestParserService.parseQuery()
  ↓ JSON.parse()
Prisma WHERE 条件对象
  ↓ db.entity.findMany({ where: filter })
数据库查询
```

### 1.3 支持的查询操作符

| 操作符 | 说明 | 示例 |
|--------|------|------|
| equals | 等于 | `{ "name": { "equals": "test" } }` |
| not | 不等于 | `{ "status": { "not": "deleted" } }` |
| lt | 小于 | `{ "age": { "lt": 18 } }` |
| lte | 小于等于 | `{ "age": { "lte": 18 } }` |
| gt | 大于 | `{ "age": { "gt": 18 } }` |
| gte | 大于等于 | `{ "age": { "gte": 18 } }` |
| contains | 包含（模糊查询） | `{ "name": { "contains": "test" } }` |
| in | 在列表中 | `{ "id": { "in": ["1", "2"] } }` |
| isSet | 字段是否设置 | `{ "deleted_at": { "isSet": false } }` |

## 2. UCToo V4 实现方案

### 2.1 架构设计

```
┌─────────────────────────────────────────────────────────────┐
│                    ApplicationController                      │
│  接收 HTTP 请求，提取 filter 和 sort 参数                      │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                    RequestParserService                       │
│  解析 filter JSON 字符串和 sort 字符串                          │
│  - parseFilter(): 解析 JSON 为 FilterCondition 对象           │
│  - parseSort(): 解析字符串为 SortCondition 数组                │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                    QueryBuilderService                        │
│  将 FilterCondition 转换为 SQL WHERE 子句                      │
│  - buildWhereClause(): 构建动态 WHERE 子句                     │
│  - buildOrderByClause(): 构建动态 ORDER BY 子句                │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                    ApplicationDAO                             │
│  执行动态 SQL 查询                                              │
│  - findApplicationByCondition(): 条件查询                      │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 核心类设计

#### 2.2.1 FilterCondition (数据模型)

```cangjie
// 文件: src/app/core/query/FilterCondition.cj

package magic.app.core.query

import std.collection.{HashMap, Map, ArrayList}

/**
 * 过滤条件模型
 * 对应 Prisma 的 WHERE 条件
 */
public class FilterCondition {
    public var field: String = ""
    public var operator: String = ""  // equals, not, lt, lte, gt, gte, contains, in, isSet
    public var value: Any? = None<Any>
    
    public init() {}
    
    public init(field: String, operator: String, value: Any) {
        this.field = field
        this.operator = operator
        this.value = Some<Any>(value)
    }
}

/**
 * 组合过滤条件（支持 AND/OR）
 */
public class CompositeFilter {
    public var logic: String = "AND"  // AND, OR
    public var conditions: ArrayList<FilterCondition> = ArrayList<FilterCondition>()
    public var composites: ArrayList<CompositeFilter> = ArrayList<CompositeFilter>()
    
    public init() {}
}

/**
 * 排序条件
 */
public class SortCondition {
    public var field: String = ""
    public var direction: String = "asc"  // asc, desc
    
    public init() {}
    
    public init(field: String, direction: String) {
        this.field = field
        this.direction = direction
    }
}

/**
 * 解析后的查询对象
 */
public class ParsedQuery {
    public var page: Int32 = 1
    public var pageSize: Int32 = 10
    public var filter: ?CompositeFilter = None<CompositeFilter>
    public var sort: ArrayList<SortCondition> = ArrayList<SortCondition>()
    
    public init() {}
}
```

#### 2.2.2 RequestParserService (解析服务)

```cangjie
// 文件: src/app/core/query/RequestParserService.cj

package magic.app.core.query

import std.collection.{HashMap, Map, ArrayList}
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonFloat, JsonBool, JsonArray}
import magic.log.LogUtils

/**
 * 查询参数解析服务
 * 对应 uctoo v3 的 RequestParserService
 */
public class RequestParserService {
    
    /**
     * 解析查询参数
     * @param filterStr filter 参数字符串（JSON 格式）
     * @param sortStr sort 参数字符串（逗号分隔）
     * @param page 页码
     * @param pageSize 每页大小
     * @return 解析后的查询对象
     */
    public func parseQuery(
        filterStr: String,
        sortStr: String,
        page: Int32,
        pageSize: Int32
    ): ParsedQuery {
        let query = ParsedQuery()
        query.page = page
        query.pageSize = pageSize
        
        // 解析 filter
        if (!filterStr.isEmpty()) {
            query.filter = parseFilter(filterStr)
        }
        
        // 解析 sort
        if (!sortStr.isEmpty()) {
            query.sort = parseSort(sortStr)
        }
        
        return query
    }
    
    /**
     * 解析 filter 参数
     * 支持格式: {"name":{"contains":"test"},"status":{"equals":"active"}}
     */
    private func parseFilter(filterStr: String): ?CompositeFilter {
        try {
            let jsonValue = JsonValue.fromStr(filterStr)
            if (!(jsonValue is JsonObject)) {
                return None<CompositeFilter>
            }
            
            let jsonObj = jsonValue.asObject()
            let composite = CompositeFilter()
            composite.logic = "AND"
            
            // 遍历 JSON 对象的每个字段
            for ((field, value) in jsonObj.getFields()) {
                // 解析字段条件
                if (value is JsonObject) {
                    let conditionObj = value.asObject()
                    for ((op, opValue) in conditionObj.getFields()) {
                        let condition = FilterCondition()
                        condition.field = field
                        condition.operator = op
                        condition.value = jsonValueToAny(opValue)
                        composite.conditions.add(condition)
                    }
                }
            }
            
            return Some<CompositeFilter>(composite)
        } catch (e: Exception) {
            LogUtils.error("RequestParserService", "Failed to parse filter: ${e.message}")
            return None<CompositeFilter>
        }
    }
    
    /**
     * 解析 sort 参数
     * 支持格式: "-created_at,name" (负号表示降序)
     */
    private func parseSort(sortStr: String): ArrayList<SortCondition> {
        let sortList = ArrayList<SortCondition>()
        
        let parts = sortStr.split(",")
        for (part in parts) {
            let trimmed = part.trimAscii()
            if (trimmed.isEmpty()) {
                continue
            }
            
            let condition = SortCondition()
            if (trimmed.startsWith("-")) {
                condition.field = trimmed.substring(1)
                condition.direction = "desc"
            } else {
                condition.field = trimmed
                condition.direction = "asc"
            }
            
            sortList.add(condition)
        }
        
        return sortList
    }
    
    /**
     * JSON 值转换为 Any
     */
    private func jsonValueToAny(value: JsonValue): Any {
        if (value is JsonString) {
            return value.asString().getValue()
        } else if (value is JsonInt) {
            return value.asInt().getValue()
        } else if (value is JsonFloat) {
            return value.asFloat().getValue()
        } else if (value is JsonBool) {
            return value.asBool().getValue()
        } else if (value is JsonArray) {
            // 处理 in 操作符的数组
            let arr = value.asArray()
            let list = ArrayList<Any>()
            for (item in arr.getItems()) {
                list.add(jsonValueToAny(item))
            }
            return list
        } else {
            return ""
        }
    }
}
```

#### 2.2.3 QueryBuilderService (SQL 构建服务)

```cangjie
// 文件: src/app/core/query/QueryBuilderService.cj

package magic.app.core.query

import std.collection.{HashMap, Map, ArrayList, StringBuilder}
import std.time.DateTime
import magic.log.LogUtils

/**
 * SQL 查询构建服务
 * 将 FilterCondition 转换为 SQL WHERE 子句
 */
public class QueryBuilderService {
    
    /**
     * 构建 WHERE 子句
     * @param filter 过滤条件
     * @param args SQL 参数列表（输出参数）
     * @return WHERE 子句字符串（不包含 WHERE 关键字）
     */
    public func buildWhereClause(
        filter: CompositeFilter,
        args: ArrayList<Any>
    ): String {
        let sb = StringBuilder()
        
        let conditions = filter.conditions
        let size = conditions.size
        
        for (i in 0..size) {
            let condition = conditions[i]
            let clause = buildConditionClause(condition, args)
            
            if (!clause.isEmpty()) {
                if (sb.size > 0) {
                    sb.append(" ${filter.logic} ")
                }
                sb.append(clause)
            }
        }
        
        // 处理嵌套的组合条件
        let composites = filter.composites
        for (composite in composites) {
            let nestedClause = buildWhereClause(composite, args)
            if (!nestedClause.isEmpty()) {
                if (sb.size > 0) {
                    sb.append(" ${filter.logic} ")
                }
                sb.append("(${nestedClause})")
            }
        }
        
        return sb.toString()
    }
    
    /**
     * 构建单个条件子句
     */
    private func buildConditionClause(
        condition: FilterCondition,
        args: ArrayList<Any>
    ): String {
        let field = condition.field
        let operator = condition.operator
        
        if (let Some(value) <- condition.value) {
            match (operator) {
                case "equals" => {
                    args.add(value)
                    return "${field} = ?"
                }
                case "not" => {
                    args.add(value)
                    return "${field} != ?"
                }
                case "lt" => {
                    args.add(value)
                    return "${field} < ?"
                }
                case "lte" => {
                    args.add(value)
                    return "${field} <= ?"
                }
                case "gt" => {
                    args.add(value)
                    return "${field} > ?"
                }
                case "gte" => {
                    args.add(value)
                    return "${field} >= ?"
                }
                case "contains" => {
                    // 模糊查询，添加 % 通配符
                    if (let Some(str) <- value as String) {
                        args.add("%${str}%")
                        return "${field} like ?"
                    }
                    return ""
                }
                case "in" => {
                    // IN 查询
                    if (let Some(list) <- value as ArrayList<Any>) {
                        let placeholders = ArrayList<String>()
                        for (item in list) {
                            args.add(item)
                            placeholders.add("?")
                        }
                        let inClause = placeholders.join(", ")
                        return "${field} in (${inClause})"
                    }
                    return ""
                }
                case "isSet" => {
                    // 字段是否设置
                    if (let Some(bool) <- value as Bool) {
                        if (bool) {
                            return "${field} is not null"
                        } else {
                            return "${field} is null"
                        }
                    }
                    return ""
                }
                case _ => {
                    LogUtils.warn("QueryBuilderService", "Unknown operator: ${operator}")
                    return ""
                }
            }
        }
        
        return ""
    }
    
    /**
     * 构建 ORDER BY 子句
     * @param sort 排序条件列表
     * @return ORDER BY 子句字符串（不包含 ORDER BY 关键字）
     */
    public func buildOrderByClause(sort: ArrayList<SortCondition>): String {
        if (sort.isEmpty()) {
            return "created_at desc"  // 默认排序
        }
        
        let sb = StringBuilder()
        let size = sort.size
        
        for (i in 0..size) {
            let condition = sort[i]
            if (sb.size > 0) {
                sb.append(", ")
            }
            sb.append("${condition.field} ${condition.direction}")
        }
        
        return sb.toString()
    }
}
```

### 2.3 DAO 层实现

```cangjie
// 文件: src/app/dao/uctoo/ApplicationDAO.cj (扩展)

/**
 * 条件查询 application
 * @param whereClause WHERE 子句（不包含 WHERE 关键字）
 * @param orderByClause ORDER BY 子句（不包含 ORDER BY 关键字）
 * @param args SQL 参数
 * @param page 页码
 * @param size 每页大小
 * @return 分页结果
 */
func findApplicationByCondition(
    whereClause: String,
    orderByClause: String,
    args: ArrayList<Any>,
    page: Int64,
    size: Int64
): Pagination<ApplicationPO> {
    // 构建动态 SQL
    let whereSql = if (whereClause.isEmpty()) {
        ""
    } else {
        " where ${whereClause}"
    }
    
    let sql = "select * from application${whereSql} order by ${orderByClause}"
    
    // 使用 f_orm 的参数化查询
    // 注意：需要根据 f_orm 的实际 API 调整
    executor.page<ApplicationPO>(sql, args, size, page: page)
}
```

### 2.4 Service 层实现

```cangjie
// 文件: src/app/services/uctoo/ApplicationService.cj (修改)

import magic.app.core.query.{RequestParserService, QueryBuilderService, ParsedQuery}

public class ApplicationService {
    private let requestParser = RequestParserService()
    private let queryBuilder = QueryBuilderService()
    
    /**
     * 获取 application 列表（支持动态查询）
     */
    public func getList(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<ApplicationPO>, Int64) {
        try {
            // 1. 解析查询参数
            let parsedQuery = requestParser.parseQuery(filter, sort, page, pageSize)
            
            // 2. 构建 SQL 子句
            let args = ArrayList<Any>()
            var whereClause = ""
            var orderByClause = "created_at desc"
            
            if (let Some(filterCondition) <- parsedQuery.filter) {
                whereClause = queryBuilder.buildWhereClause(filterCondition, args)
            }
            
            if (!parsedQuery.sort.isEmpty()) {
                orderByClause = queryBuilder.buildOrderByClause(parsedQuery.sort)
            }
            
            // 3. 执行查询
            let pagination = getExecutor().findApplicationByCondition(
                whereClause,
                orderByClause,
                args,
                Int64(parsedQuery.page),
                Int64(parsedQuery.pageSize)
            )
            
            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            LogUtils.error("ApplicationService", "Failed to get list: ${e.message}")
            return (ArrayList<ApplicationPO>(), 0)
        }
    }
}
```

## 3. 实现步骤

### 3.1 第一阶段：基础框架

1. **创建核心类**
   - `FilterCondition.cj` - 过滤条件模型
   - `SortCondition.cj` - 排序条件模型
   - `ParsedQuery.cj` - 解析后的查询对象

2. **实现 RequestParserService**
   - `parseFilter()` - 解析 JSON filter 参数
   - `parseSort()` - 解析 sort 参数
   - `jsonValueToAny()` - JSON 值转换

### 3.2 第二阶段：SQL 构建

3. **实现 QueryBuilderService**
   - `buildWhereClause()` - 构建 WHERE 子句
   - `buildConditionClause()` - 构建单个条件
   - `buildOrderByClause()` - 构建 ORDER BY 子句

4. **扩展 DAO 层**
   - `findApplicationByCondition()` - 条件查询方法

### 3.3 第三阶段：集成测试

5. **修改 Service 层**
   - 集成 RequestParserService 和 QueryBuilderService
   - 实现动态查询逻辑

6. **编写测试用例**
   - 测试各种操作符
   - 测试组合条件
   - 测试排序功能

## 4. 支持的查询示例

### 4.1 等于查询
```
GET /api/v1/uctoo/application/10/1?filter={"classify":{"equals":"dev"}}
```
生成 SQL:
```sql
SELECT * FROM application WHERE classify = 'dev' ORDER BY created_at DESC
```

### 4.2 模糊查询
```
GET /api/v1/uctoo/application/10/1?filter={"name":{"contains":"管理"}}
```
生成 SQL:
```sql
SELECT * FROM application WHERE name LIKE '%管理%' ORDER BY created_at DESC
```

### 4.3 组合查询
```
GET /api/v1/uctoo/application/10/1?filter={"classify":{"equals":"dev"},"name":{"contains":"API"}}
```
生成 SQL:
```sql
SELECT * FROM application WHERE classify = 'dev' AND name LIKE '%API%' ORDER BY created_at DESC
```

### 4.4 排序查询
```
GET /api/v1/uctoo/application/10/1?sort=-updated_at,name
```
生成 SQL:
```sql
SELECT * FROM application ORDER BY updated_at DESC, name ASC
```

### 4.5 IN 查询
```
GET /api/v1/uctoo/application/10/1?filter={"classify":{"in":["dev","design"]}}
```
生成 SQL:
```sql
SELECT * FROM application WHERE classify IN ('dev', 'design') ORDER BY created_at DESC
```

## 5. 与 UCToo V3 的对比

| 特性 | UCToo V3 | UCToo V4 |
|------|----------|----------|
| 查询参数格式 | JSON filter + sort 字符串 | JSON filter + sort 字符串 |
| 解析服务 | RequestParserService (TypeScript) | RequestParserService (Cangjie) |
| ORM | Prisma | f_orm |
| WHERE 构建 | Prisma 自动处理 | QueryBuilderService 手动构建 |
| 支持的操作符 | equals, not, lt, lte, gt, gte, contains, in, isSet | equals, not, lt, lte, gt, gte, contains, in, isSet |
| 前端工具 | buildPrismaWhere() | buildPrismaWhere() (复用) |

## 6. 技术要点

### 6.1 JSON 解析
- 使用仓颉标准库的 `stdx.encoding.json`
- 支持 JsonObject、JsonArray、JsonString、JsonInt、JsonFloat、JsonBool

### 6.2 SQL 注入防护
- 使用参数化查询（PreparedStatement）
- 所有用户输入都通过 `args` 参数传递
- 不直接拼接 SQL 字符串

### 6.3 性能优化
- WHERE 子句构建时使用 StringBuilder
- 避免不必要的字符串操作
- 支持索引友好的查询条件

## 7. 后续扩展

### 7.1 支持嵌套条件
```json
{
  "OR": [
    {"classify": {"equals": "dev"}},
    {"classify": {"equals": "design"}}
  ]
}
```

### 7.2 支持关联查询
```json
{
  "creator": {
    "name": {"contains": "admin"}
  }
}
```

### 7.3 支持聚合查询
- count
- sum
- avg
- min
- max

## 8. 参考资料

- [UCToo V3 RequestParserService](../../../backend/src/app/lib/request-parser/src/lib/services/request-parser.service.ts)
- [UCToo V3 buildPrismaWhere](../../../uctoo-app-client-pc/src/utils/prismaUtils.ts)
- [UCToo V4 API 规范](../uctoo-v4-api-specification.md)
- [仓颉 JSON 库文档](https://docs.cangjie-lang.com/)
