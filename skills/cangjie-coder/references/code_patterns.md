# 仓颉代码模式库

本文件收集常用的仓颉代码模式，供code-searcher subagent和code-editor subagent参考。

## PO数据模型模式

```cangjie
package magic.app.models.uctoo

import encoding.json.*
import std.collection.*
import magic.app.dao.uctoo.*
import magic.app.utils.*

@DataAssist[fields]
public class TableName {
    public var id: Int64 = 0
    public var fieldName: String = ""
    public var status: Int64 = 0
    public var createdAt: String = ""
    public var updatedAt: String = ""
}

@QueryMappersGenerator
public class TableNameQuery {
    public var id: Int64 = 0
}
```

## DAO模式

```cangjie
package magic.app.dao.uctoo

import encoding.json.*
import std.collection.*
import magic.app.models.uctoo.*
import magic.app.dao.*

@DAO
public class TableNameDAO <: RootDAO<TableName> {
    public init() {
        super("table_name", "id")
    }
}
```

## Service模式

```cangjie
package magic.app.service.uctoo

import encoding.json.*
import std.collection.*
import magic.app.models.uctoo.*
import magic.app.dao.uctoo.*
import magic.app.utils.*

public class TableNameService {
    private let dao = TableNameDAO()

    public func findById(id: Int64): APIResult<TableName> {
        let result = dao.findById(id)
        match (result) {
            case Some(entity) => APIResult.success(entity)
            case None => APIResult.error("记录不存在")
        }
    }

    public func findAll(query: TableNameQuery): APIResult<ArrayList<TableName>> {
        let results = dao.findAll(query)
        APIResult.success(results)
    }

    public func create(entity: TableName): APIResult<TableName> {
        let result = dao.insert(entity)
        match (result) {
            case Some(id) => APIResult.success(entity)
            case None => APIResult.error("创建失败")
        }
    }

    public func update(entity: TableName): APIResult<TableName> {
        let result = dao.update(entity)
        match (result) {
            case Some(count) => APIResult.success(entity)
            case None => APIResult.error("更新失败")
        }
    }

    public func deleteById(id: Int64): APIResult<Bool> {
        let result = dao.deleteById(id)
        APIResult.success(result)
    }
}
```

## Controller模式

```cangjie
package magic.app.controller.uctoo

import encoding.json.*
import std.collection.*
import magic.app.models.uctoo.*
import magic.app.service.uctoo.*
import magic.app.utils.*
import magic.app.http.*

public class TableNameController {
    private let service = TableNameService()

    public func handleGetById(request: HttpRequest): HttpResponse {
        let id = request.getPathParam("id")
        match (id) {
            case Some(idStr) =>
                let result = service.findById(Int64.parse(idStr))
                HttpResponse.ok(result.toJson())
            case None =>
                HttpResponse.badRequest("缺少id参数")
        }
    }

    public func handleGetAll(request: HttpRequest): HttpResponse {
        let query = TableNameQuery()
        let result = service.findAll(query)
        HttpResponse.ok(result.toJson())
    }

    public func handleCreate(request: HttpRequest): HttpResponse {
        let body = request.getBody()
        match (TableName.fromJson(body)) {
            case Some(entity) =>
                let result = service.create(entity)
                HttpResponse.ok(result.toJson())
            case None =>
                HttpResponse.badRequest("请求体格式错误")
        }
    }
}
```

## 错误处理模式

```cangjie
public func safeOperation(param: String): Option<ResultType> {
    if (param.isEmpty()) {
        return None
    }

    try {
        let result = doSomething(param)
        Some(result)
    } catch (e: Exception) {
        println("操作失败: ${e.message}")
        None
    }
}

public func operationWithResult(param: String): APIResult<ResultType> {
    if (param.isEmpty()) {
        return APIResult.error("参数不能为空")
    }

    try {
        let result = doSomething(param)
        APIResult.success(result)
    } catch (e: Exception) {
        APIResult.error("操作失败: ${e.message}")
    }
}
```

## 集合操作模式

```cangjie
let list = ArrayList<String>()
list.add("item1")
list.add("item2")

let map = HashMap<String, Int64>()
map.add("key", 1)

let filtered = list.filter { item => item.startsWith("item") }
let mapped = list.map { item => item.toAsciiUpper() }
let found = list.find { item => item == "target" }
```

## JSON处理模式

```cangjie
let json = JsonValue.parse(jsonStr)
let name = json["name"]?.asString().getOrDefault("")
let age = json["age"]?.asInt64().getOrDefault(0)

let obj = JsonObject()
obj["name"] = "value"
obj["age"] = JsonValue.fromInt64(30)
```

## 配置解析模式

```cangjie
public func loadConfig(path: String): Option<Config> {
    try {
        let content = File.readFrom(path)
        let json = JsonValue.parse(content)
        Some(Config.fromJson(json))
    } catch (e: Exception) {
        println("配置加载失败: ${e.message}")
        None
    }
}
```

## HTTP服务器模式

```cangjie
import std.net.http.*

let server = HttpServer(8080)
server.get("/api/hello", { request =>
    HttpResponse.ok("Hello, World!")
})
server.start()
```

## 并发模式

```cangjie
import std.sync.*

let future = spawn {
    heavyComputation()
}

let mutex = Mutex()
mutex.lock()
// 临界区
mutex.unlock()

let counter = AtomicInt64(0)
counter.fetchAdd(1)
```