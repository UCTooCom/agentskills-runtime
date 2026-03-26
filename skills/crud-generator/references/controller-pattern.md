# Controller Pattern Reference

Controller layer pattern for UCToo V4, following the EntityController implementation.

## Overview

The Controller layer provides:
- HTTP request handling
- Request body parsing
- Response formatting
- Error handling

## File Structure

```
src/app/controllers/{database}/{table}/{Table}Controller.cj
```

## Basic Template

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
    
    // Endpoint methods...
}
```

## Standard Endpoints

### add - POST /add

```cangjie
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
```

### edit - POST /edit

Supports single update, batch update, and restore:

```cangjie
public func edit(req: HttpRequest, res: HttpResponse): Unit {
    try {
        let body = parseBody(req)
        if (let Some(b) <- body) {
            let ids = b.get("ids")
            let id = b.get("id")
            
            // Check for restore (deleted_at === "0")
            let deletedAt = b.get("deleted_at")
            let isRestore = if (let Some(da) <- deletedAt) {
                let daStr = da as String
                if (let Some(s) <- daStr) { s == "0" } else { false }
            } else { false }
            
            if (let Some(idsVal) <- ids) {
                // Batch operation
            } else if (let Some(idVal) <- id) {
                // Single operation
                if (isRestore) {
                    // Restore soft deleted
                } else {
                    // Update
                }
            }
        }
    } catch (e: Exception) {
        res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
    }
}
```

### delete - POST /del

Supports soft delete and hard delete:

```cangjie
public func delete(req: HttpRequest, res: HttpResponse): Unit {
    try {
        let body = parseBody(req)
        if (let Some(b) <- body) {
            let id = b.get("id")
            let forceOpt = b.get("force")
            let force = parseForce(forceOpt)
            
            if (let Some(idVal) <- id) {
                let idStrOpt = idVal as String
                if (let Some(idStr) <- idStrOpt) {
                    let result = service.delete(idStr, force)
                    if (result.success) {
                        res.status(200).json("{\"desc\":\"删除成功\"}")
                    } else {
                        let reason = result.reason ?? "删除失败"
                        res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
                    }
                }
            }
        }
    } catch (e: Exception) {
        res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
    }
}
```

### getSingle - GET /:id

```cangjie
public func getSingle(req: HttpRequest, res: HttpResponse): Unit {
    try {
        let id = req.pathParam("id")
        
        if (let Some(idVal) <- id) {
            let result = service.getById(idVal)
            
            if (result.success) {
                if (let Some(data) <- result.data) {
                    res.status(200).json(data.toJson())
                } else {
                    res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"未找到该记录\"}")
                }
            } else {
                res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"未找到该记录\"}")
            }
        } else {
            res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少ID参数\"}")
        }
    } catch (e: Exception) {
        res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
    }
}
```

### getManyWithPathParams - GET /:limit/:page

```cangjie
public func getManyWithPathParams(req: HttpRequest, res: HttpResponse): Unit {
    try {
        let limitParam = req.pathParam("limit")
        let pageParam = req.pathParam("page")
        
        let limitNum = if (let Some(l) <- limitParam) { Int32.parse(l) } else { Int32(10) }
        let pageNum = if (let Some(p) <- pageParam) { Int32.parse(p) } else { Int32(1) }
        
        if (limitNum > 100) {
            res.status(400).json("{\"errno\":\"40004\",\"errmsg\":\"请求数量不能超过100条\"}")
            return
        }
        
        let (entities, total) = service.getList(pageNum - 1, limitNum)
        
        let totalPage = if (limitNum > 0) {
            Int32((total + Int64(limitNum) - 1) / Int64(limitNum))
        } else { Int32(0) }
        
        var entitiesJson = ""
        for (e in entities) {
            if (entitiesJson.isEmpty()) {
                entitiesJson = e.toJson()
            } else {
                entitiesJson = entitiesJson + "," + e.toJson()
            }
        }
        res.status(200).json("{\"currentPage\":${pageNum},\"totalCount\":${total},\"totalPage\":${totalPage},\"{table}s\":[${entitiesJson}]}")
    } catch (e: Exception) {
        res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
    }
}
```

## Helper Methods

### parseBody

```cangjie
private func parseBody(req: HttpRequest): ?Map<String, Any> {
    try {
        let body = req.body
        if (body.isEmpty()) { return None<Map<String, Any>> }
        
        let jsonValue = JsonValue.fromStr(body)
        if (!(jsonValue is JsonObject)) { return None<Map<String, Any>> }
        
        let jsonObj = jsonValue.asObject()
        let map = HashMap<String, Any>()
        
        for ((key, value) in jsonObj.getFields()) {
            let anyValue = jsonValueToAny(value)
            map.add(key, anyValue)
        }
        
        return Some<Map<String, Any>>(map)
    } catch (e: Exception) {
        return None<Map<String, Any>>
    }
}
```

### jsonValueToAny

```cangjie
private func jsonValueToAny(value: JsonValue): Any {
    if (value is JsonString) {
        return value.asString().getValue()
    } else if (value is JsonInt) {
        return value.asInt().getValue()
    } else if (value is JsonFloat) {
        return value.asFloat().getValue()
    } else if (value is JsonBool) {
        return value.asBool().getValue()
    } else {
        return ""
    }
}
```

### mapToEntity

```cangjie
private func mapToEntity(map: Map<String, Any>): {Table}PO {
    let entity = {Table}PO()
    
    if (let Some(id) <- map.get("id")) {
        let idStr = id as String
        if (let Some(s) <- idStr) { entity.id = s }
    }
    
    if (let Some(name) <- map.get("name")) {
        let nameStr = name as String
        if (let Some(s) <- nameStr) { entity.name = s }
    }
    
    // Map other fields...
    
    return entity
}
```

### parseForce

```cangjie
private func parseForce(forceOpt: ?Any): Bool {
    if (let Some(f) <- forceOpt) {
        let fInt64 = f as Int64
        if (let Some(v) <- fInt64) {
            v == 1
        } else {
            let fInt32 = f as Int32
            if (let Some(v) <- fInt32) {
                v == 1
            } else {
                let fStr = f as String
                if (let Some(s) <- fStr) {
                    s == "true" || s == "1"
                } else { false }
            }
        }
    } else { false }
}
```

## Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| 40001 | 400 | 提交数据格式错误 |
| 40002 | 400 | 缺少ID参数 |
| 40004 | 400 | 请求数量超过限制 |
| 40401 | 404 | 未找到该记录 |
| 50000 | 500 | 服务器内部错误 |
| 50001 | 500 | 操作失败 |

## Design Principles

1. **Use Service for business logic**: Never access DAO directly
2. **Parse request body safely**: Handle null and format errors
3. **Return consistent error format**: Use JSON with errno/errmsg
4. **Support batch operations**: Check for "ids" parameter
5. **Support restore**: Check for deleted_at="0"
6. **Limit page size**: Prevent excessive data retrieval
