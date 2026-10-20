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

## 易错形态规避模式（编译报错高发，写码时直接按"正确写法"走）

> 完整背景与"一轮排净"规程见 SKILL.md《编译报错「一轮排净」规程》。
> 下面只给**对照写法**，便于编写阶段就避开，而不是等编译报错再改。

### 可选类型：`?` 前置，不是后置

```cangjie
// ❌ Rust 风格 → error: expected ';' or '<NL>', found '?'
private static var logger: Logger? = None

// ✅ 仓颉：? 前置
private static var logger: ?Logger = None
// ✅ 或写全（推荐，与宿主 PO 字段风格一致）
private static var logger: Option<Logger> = None<Logger>
```

> 注意 `None<T>` **不带括号**；形参/返回类型已标注时可直接写裸 `None`。

### match 臂：不要写多语句块

```cangjie
// ❌ `=>` 后的 `{` 会被解析成 lambda 起始
//    error: expected '=>' in lambda expression, found keyword 'let'
match (Log.logger) {
    case Some(l) => l
    case None => {
        let l = Logger(defaultLogPath())
        Log.logger = Some(l)
        l
    }
}

// ✅ 把逻辑外提成函数，match 臂只留单表达式
match (Log.logger) {
    case Some(l) => l
    case None => defaultLogger()
}

func defaultLogger(): Logger {
    let l = Logger(defaultLogPath())
    Log.logger = Some(l)
    return l
}

// ✅ 或者干脆用 if 提前返回（更简单，推荐）
if (let Some(l) <- Log.logger) {
    return l
}
return defaultLogger()
```

> 合法例外：`{` 的下一行紧跟**裸 `=>`**（零参 lambda），见
> `src/app/middlewares/auth/JWTAuthMiddleware.cj`。但
> `src/test/**` 不在主构建图内，其写法不可作先例。

### 定长 Array 无增删方法

```cangjie
// ❌ Array<T> 是定长数组，没有 add
var command: Array<String> = Array<String>(0, {_ => ""})
command.add("install")     // error: 'add' is not a member of class 'Array<T>'

// ✅ 需要动态增删用 ArrayList（属 prelude，无需 import）
var command = ArrayList<String>()
command.add("install")

// ✅ 或保持 Array 用下标赋值
var command: Array<String> = Array<String>(1, {_ => ""})
command[0] = "install"
```

### `let` 不可重新赋值

```cangjie
// ❌ error: cannot assign to immutable value
let cur = StringBuilder()
for (r in runes) {
    if (cond) {
        cur = StringBuilder()   // 重新赋值 let 变量
    }
    cur.append(r)
}

// ✅ 需要重建就声明为 var
var cur = StringBuilder()
// ✅ 或改为不可变拼接后重新绑定另一个名字
let rebuilt = StringBuilder()
```

### 避免在多个分支里给同一个 `let` 赋值

```cangjie
// ❌ 易同时踩"不可变赋值"与"推断失败"两个坑
let report: Report
if (a) { report = f1() } else { report = f2() }

// ✅ 抽出返回值的函数，声明处确定赋值
let report = dispatch(parsed)

func dispatch(parsed: CliArgs): Report {
    if (a) { return f1() }
    return f2()
}
```

> 抽函数时常引入新类型引用，记得回头检查该文件的 `import` 是否齐备。

### prelude 类型（无需 import）

经大库实证，**以下类型在 prelude 内，不要凭直觉补 import**：

| 类型 | 实证数据（本仓 src/，均能编译） |
|------|------------------------------|
| `ArrayList` | 512 个文件使用，248 个从未 import |
| `HashMap` | 430 个文件使用，314 个从未 import |

不确定时用这条命令实证（看有多少在用却未 import 的文件）：

```bash
for f in $(grep -rl "ArrayList<" --include=*.cj src/); do
  grep -q "import std.collection.ArrayList\|import std.collection.\*" "$f" || echo "无import却能用: $f"
done | wc -l
```