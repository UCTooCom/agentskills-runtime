# json4cj

json4cj 是一个基于仓颉语言宏系统开发的 JSON 序列化/反序列化库。只需使用宏注解标记类或结构体，即可自动生成序列化/反序列化代码，大幅简化 JSON 数据处理流程。

> **🚧 本项目正在积极开发中！** Phase 1 已完成，Phase 2 进行中（enum 完整支持、Stream 流式 API 已完成）。欢迎提交 Issue、PR 或参与讨论，一起打造仓颉生态最好的 JSON 库！
>
> 📋 完整的架构设计与演进路线请查看 [DESIGN_AND_ROADMAP.md](DESIGN_AND_ROADMAP.md)
>
> 🐛 开发过程中遇到的踩坑记录请查看 [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

## 特性

- **零样板代码**：使用 `@JsonSerialize` 注解即可为类/结构体/枚举自动生成 `fromJson()` 和 `toJson()` 方法
- **自定义字段名**：使用 `@JsonProperty["alias"]` 指定序列化时的字段别名
- **字段忽略**：使用 `@JsonIgnore` 跳过不需要序列化的字段
- **默认值支持**：自动处理 JSON 中的缺失字段，使用声明的默认值
- **Option\<T\> 类型**：原生支持可选类型的序列化/反序列化
- **自定义序列化器**：通过 `@JsonDeserialize[ClassName]` 为特定字段定制序列化逻辑
- **泛型集合支持**：支持 `ArrayList<T>`、`HashSet<T>`、`HashMap<K,V>` 等泛型集合的嵌套序列化
- **结构体支持**：同时支持 `class` 和 `struct` 类型
- **未知字段处理**：`@JsonIgnoreUnknown[true/false]` 控制是否忽略未知字段，严格模式收集所有未知字段后抛出异常
- **包含控制**：`@JsonInclude[ALWAYS/NON_NULL/NON_EMPTY]` 控制序列化输出中 null/空值的包含策略
- **日期格式化**：`@JsonFormat["yyyy-MM-dd"]` 自定义 DateTime 字段的序列化/反序列化格式
- **不可变对象**：`@JsonCreator` 支持基于构造函数的反序列化，允许使用 `let` 不可变字段
- **UInt 类型支持**：UInt8/16/32/64 类型的 JSON 序列化/反序列化扩展
- **简单枚举支持**：`@JsonSerialize` 直接标注 enum，自动将枚举值序列化为字符串（如 `Active → "Active"`），支持 enum 作为类字段
- **有参枚举支持**：`@JsonSerialize` 支持有参构造器枚举（serde externally-tagged），如 `Circle(3.14) → {"Circle":3.14}`、`Rect(3,4) → {"Rect":[3,4]}`，支持混合枚举和递归枚举
- **Stream 流式 API**：宏自动生成 `stdx.encoding.json.stream` 的 `JsonSerializable` / `JsonDeserializable<T>` 实现，支持 `writeValue<T>()` / `readValue<T>()` 流式读写
- **泛型类支持**：支持泛型类的序列化/反序列化，如 `ApiResponse<T>`、`Wrapper<K, V>`，自动生成 where 约束 `where T <: JsonValueSerializable<T>`
- **Bare type param**：支持 bare type param 字段（如 `var data: T`），`@JsonCreator` 路径（`let data: T`）和 var 路径（`var data: T = ...`）均支持
- **嵌套泛型**：支持泛型类型嵌套，如 `Envelope<Container<T>>`、`Option<ArrayList<T>>` 等复杂场景
- **多类型参数**：支持多个类型参数（如 `<K, V>`），正确处理逗号分隔和约束生成
- **多态类型序列化**：`@JsonTypeInfo[tag="type"]` + `@JsonSubTypes` 支持类继承多态，自动类型鉴别和分发（serde 内部标签策略），支持动态分派、`ArrayList<BaseType>` 多态、完整往返测试

## 快速开始

### 添加依赖

在项目的 `cjpm.toml` 中添加 json4cj 依赖：

```toml
[dependencies]
  json4cj = { git = "https://gitcode.com/weixin_42769311/json4cj.git", branch = "main" }
```

### 基本使用

```cangjie
package example

import json4cj.{JsonCodec}
import json4cj.jsonmacro.{JsonSerialize}

@JsonSerialize
public class User {
    var name: String = "default"
    var age: Int64 = 0
    var email: String = ""
}

main() {
    // 序列化：对象 → JSON 字符串
    let user = User()
    user.name = "张三"
    user.age = 25
    user.email = "zhangsan@example.com"

    let jsonString = user.toJson()
    println(jsonString)
    // 输出: {"name":"张三","age":25,"email":"zhangsan@example.com"}

    // 反序列化：JSON 字符串 → 对象
    let jsonInput = "{\"name\":\"李四\",\"age\":30,\"email\":\"lisi@example.com\"}"
    let parsedUser = User.fromJson(jsonInput)
    println(parsedUser.name)  // 输出: 李四
    println(parsedUser.age)   // 输出: 30
}
```

## 高级用法

### 自定义字段名

使用 `@JsonProperty` 注解指定序列化后的字段名：

```cangjie
import json4cj.jsonmacro.{JsonSerialize, JsonProperty}

@JsonSerialize
public class Product {
    @JsonProperty["product_name"]
    var name: String = ""

    @JsonProperty["unit_price"]
    var price: Float64 = 0.0

    var stock: Int64 = 0  // 未指定别名，使用原字段名
}

// 序列化结果:
// {"product_name":"笔记本电脑","unit_price":5999.99,"stock":100}
```

### 忽略字段

使用 `@JsonIgnore` 跳过不需要序列化的字段：

```cangjie
import json4cj.jsonmacro.{JsonSerialize, JsonIgnore}

@JsonSerialize
public class Session {
    var sessionId: String = ""
    var userId: Int64 = 0

    @JsonIgnore
    var internalCache: String = ""  // 不会被序列化
}

// 序列化结果:
// {"sessionId":"abc123","userId":1001}
```

### Option\<T\> 类型

支持可选类型，缺失值自动序列化为 `null`：

```cangjie
import json4cj.jsonmacro.{JsonSerialize}

@JsonSerialize
public class Profile {
    var username: String = ""
    var bio: Option<String> = None
    var avatar: Option<String> = None
}

// 序列化结果（当 bio 和 avatar 为 None 时）:
// {"username":"test","bio":null,"avatar":null}
```

### 自定义序列化器

通过 `@JsonDeserialize` 注解为特定字段定制序列化逻辑：

```cangjie
import std.time.DateTime
import json4cj.{JsonValueSerializable}
import json4cj.jsonmacro.{JsonSerialize, JsonDeserialize}

// 实现自定义序列化器，继承 JsonValueSerializable<T>
class DateTimeSerializer <: JsonValueSerializable<DateTime> {
    public DateTimeSerializer(let value: DateTime) {}

    public func toJsonValue(): JsonValue {
        return JsonString(this.value.toString())
    }

    public static func fromJsonValue(json: JsonValue): DateTime {
        return DateTime.parse(json.asString().getValue())
    }
}

@JsonSerialize
public class Event {
    var title: String = ""

    @JsonDeserialize[DateTimeSerializer]
    var startTime: DateTime = DateTime.now()
}
```

### 泛型集合

支持嵌套集合的序列化：

```cangjie
import json4cj.jsonmacro.{JsonSerialize}

@JsonSerialize
public class Comment {
    var author: String = ""
    var content: String = ""
}

@JsonSerialize
public class Article {
    var title: String = ""
    var comments: ArrayList<Comment> = ArrayList<Comment>()
    var tags: HashSet<String> = HashSet<String>()
    var metadata: HashMap<String, String> = HashMap<String, String>()
}
```

### 未知字段处理

使用 `@JsonIgnoreUnknown` 控制反序列化时对未知字段的处理策略：

```cangjie
import json4cj.jsonmacro.{JsonSerialize, JsonIgnoreUnknown}

@JsonSerialize
@JsonIgnoreUnknown[true]   // 忽略未知字段（默认行为）
public class User {
    var name: String = ""
}
// User.fromJson("""{"name":"test","age":25}""") → 正常工作，忽略 age

@JsonSerialize
@JsonIgnoreUnknown[false]  // 严格模式，遇到未知字段抛出异常
public class StrictUser {
    var name: String = ""
}
// StrictUser.fromJson("""{"name":"test","age":25}""") → 抛出异常：未知字段 [age]
```

### 包含控制

使用 `@JsonInclude` 控制 null/空值是否出现在序列化输出中：

```cangjie
import json4cj.jsonmacro.{JsonSerialize, JsonInclude}

@JsonSerialize
@JsonIgnoreUnknown[true]   // 建议与 JsonInclude 搭配使用
public class Profile {
    var username: String = ""
    var bio: Option<String> = None
    var tags: ArrayList<String> = ArrayList<String>()
}

// ALWAYS（默认）：始终输出所有字段
// {"username":"test","bio":null,"tags":[]}

// NON_NULL：跳过值为 null/None 的字段
// {"username":"test","tags":[]}

// NON_EMPTY：跳过 null/None、空字符串、空集合
// {"username":"test"}
```

### 日期格式化

使用 `@JsonFormat` 自定义 DateTime 字段的序列化/反序列化格式：

```cangjie
import std.time.DateTime
import json4cj.jsonmacro.{JsonSerialize, JsonFormat}

@JsonSerialize
public class Event {
    var title: String = ""

    @JsonFormat["yyyy-MM-dd"]
    var date: DateTime = DateTime.now()

    @JsonFormat["yyyy-MM-dd HH:mm:ss"]
    var startTime: DateTime = DateTime.now()
}
// 序列化：{"title":"会议","date":"2024-01-15","startTime":"2024-01-15 09:00:00"}
// 反序列化：使用相同的格式化模式解析字符串
```

### 不可变对象

使用 `@JsonCreator` 支持基于构造函数的反序列化，允许使用 `let` 不可变字段：

```cangjie
import json4cj.jsonmacro.{JsonSerialize, JsonCreator}

@JsonSerialize
@JsonCreator
public class ImmutableUser {
    let name: String
    let age: Int64

    public init(name: String, age: Int64) {
        this.name = name
        this.age = age
    }
}

// 反序列化
let user = ImmutableUser.fromJson("""{"name":"张三","age":25}""")
println(user.name)  // 张三
println(user.age)   // 25

// 序列化
let json = user.toJson()  // {"name":"张三","age":25}
```

### 结构体支持

`struct` 类型同样支持序列化：

```cangjie
import json4cj.jsonmacro.{JsonSerialize}

@JsonSerialize
public struct Point {
    var x: Float64 = 0.0
    var y: Float64 = 0.0
}
```

### 泛型类支持

支持泛型类的序列化/反序列化，宏会自动生成 `where` 约束：

```cangjie
import json4cj.jsonmacro.{JsonSerialize}

// 单类型参数
@JsonSerialize
class ApiResponse<T> {
    var code: Int64 = 0
    var data: Option<T> = Option<T>.None
}

// 使用
let resp = ApiResponse<String>.fromJson("""{"code":200,"data":"success"}""")
println(resp.code)  // 200
println(resp.data.getOrThrow())  // success

// 多类型参数
@JsonSerialize
class KeyValuePair<K, V> {
    var key: Option<K> = Option<K>.None
    var value: Option<V> = Option<V>.None
}

let kv = KeyValuePair<String, Int64>()
kv.key = Option<String>.Some("age")
kv.value = Option<Int64>.Some(25)
let json = kv.toJson()  // {"key":"age","value":25}
```

**嵌套泛型**也完全支持：

```cangjie
@JsonSerialize
class Container<T> {
    var item: Option<T> = Option<T>.None
    var timestamp: Int64 = 0
}

@JsonSerialize
class Envelope<T> {
    var data: Option<Container<T>> = Option<Container<T>>.None
    var version: String = ""
}

// 使用嵌套泛型
let envelope = Envelope<String>.fromJson("""{
    "data":{"item":"hello","timestamp":1234567890},
    "version":"v1.0"
}""")
println(envelope.data.getOrThrow().item.getOrThrow())  // hello
```

**Bare type param + @JsonCreator** 支持直接使用类型参数作为字段（无需 `Option<T>` 包装）：

```cangjie
import json4cj.jsonmacro.{JsonSerialize, JsonCreator}

@JsonSerialize
@JsonCreator
class ApiResponse<T> {
    let code: Int64
    let data: T

    public init(code: Int64, data: T) {
        this.code = code
        this.data = data
    }
}

// 反序列化
let resp = ApiResponse<String>.fromJson("""{"code":200,"data":"success"}""")
println(resp.code)   // 200
println(resp.data)   // success

// 多类型参数
@JsonSerialize
@JsonCreator
class Pair<K, V> {
    let first: K
    let second: V

    public init(first: K, second: V) {
        this.first = first
        this.second = second
    }
}

let pair = Pair<String, Int64>.fromJson("""{"first":"age","second":25}""")
println(pair.first)   // age
println(pair.second)  // 25
```

### 枚举序列化

简单（无参）枚举可直接使用 `@JsonSerialize`，枚举值自动序列化为 JSON 字符串：

```cangjie
import json4cj.{JsonCodec}
import json4cj.jsonmacro.{JsonSerialize}

@JsonSerialize
enum Status {
    | Active
    | Inactive
    | Pending
}

// 序列化
let s: Status = Active
println(s.toJson())      // "Active"

// 反序列化
let restored = Status.fromJson("\"Pending\"")
// restored == Pending

// 枚举也可以作为类字段使用
@JsonSerialize
public class Task {
    var name: String = ""
    var status: Status = Active
}

let task = Task()
task.name = "Build API"
task.status = Pending
println(task.toJson())
// {"name":"Build API","status":"Pending"}

let parsed = Task.fromJson("""{"name":"Deploy","status":"Active"}""")
// parsed.status == Active
```

### 有参枚举序列化

有参（parameterized）枚举使用 serde externally-tagged 表示方式：
- 无参构造器 → JSON 字符串：`Dot → "Dot"`
- 单参构造器 → JSON 对象：`Circle(3.14) → {"Circle":3.14}`
- 多参构造器 → JSON 对象+数组：`Rect(3,4) → {"Rect":[3,4]}`

```cangjie
@JsonSerialize
enum Shape {
    | Circle(Float64)
    | Rect(Float64, Float64)
    | Dot
}

// 序列化
println(Shape.Circle(3.14).toJson())    // {"Circle":3.14}
println(Shape.Rect(3.5, 4.5).toJson())  // {"Rect":[3.5,4.5]}
let dot: Shape = Dot
println(dot.toJson())                   // "Dot"

// 反序列化
let c = Shape.fromJson(##"{"Circle":2.5}"##)      // Circle(2.5)
let r = Shape.fromJson(##"{"Rect":[1.0,2.0]}"##)  // Rect(1.0, 2.0)
let d = Shape.fromJson(##""Dot""##)                // Dot
```

递归枚举也被支持：

```cangjie
@JsonSerialize
enum Expr {
    | Val(Int64)
    | Negate(Expr)
    | Plus(Expr, Expr)
}

let e = Expr.Plus(Expr.Val(1), Expr.Negate(Expr.Val(2)))
println(e.toJson())
// {"Plus":[{"Val":1},{"Negate":{"Val":2}}]}
```

> **注意**：同名构造器（如 `| Red | Red(UInt8)`）不支持，会抛出明确错误提示。

### 多态类型序列化

使用 `@JsonTypeInfo` + `@JsonSubTypes` 实现类继承多态的自动序列化/反序列化（serde 内部标签策略）：

```cangjie
import json4cj.{JsonCodec}
import json4cj.jsonmacro.{JsonSerialize, JsonTypeInfo, JsonSubTypes, JsonType}

// 基类：定义鉴别字段和子类型映射
@JsonSerialize
@JsonTypeInfo[tag = "type"]
@JsonSubTypes["dog" => Dog, "cat" => Cat]
open class Animal {
    var name: String = ""
}

// 子类：指定鉴别值
@JsonSerialize
@JsonType["dog"]
class Dog <: Animal {
    var breed: String = ""
}

@JsonSerialize
@JsonType["cat"]
class Cat <: Animal {
    var lives: Int64 = 9
}

// 序列化：自动注入 type 鉴别字段
let dog = Dog()
dog.name = "Buddy"
dog.breed = "Labrador"
println(dog.toJson())
// {"type":"dog","name":"Buddy","breed":"Labrador"}

// 反序列化：根据 type 字段自动分发到子类
let json = """{"type":"cat","name":"Whiskers","lives":7}"""
let animal = Animal.fromJson(json)
println(animal.name)  // Whiskers

// 类型检查和下转型
if (animal is Cat) {
    let cat = (animal as Cat).getOrThrow()
    println(cat.lives)  // 7
}

// 支持 ArrayList<BaseType> 多态
var animals = ArrayList<Animal>()
animals.add(Dog())
animals.add(Cat())

let json = animals.toJson()
// [{"type":"dog",...},{"type":"cat",...}]
```

**支持的特性**：
- ✅ 自动类型鉴别字段注入（序列化）
- ✅ 基于类型鉴别的自动分发（反序列化）
- ✅ `open` 方法动态分派
- ✅ `ArrayList<BaseType>` 多态集合
- ✅ 完整往返测试（round-trip）
- ✅ 未知类型错误处理
- ✅ 缺失鉴别字段错误处理

> **注意**：当前实现内部标签策略（internal tagging），JSON 格式为 `{"type":"dog","name":"Buddy"}`。未来将支持外部标签、相邻标签、无标签等策略。

## 使用要求

- **仓颉编译器版本**：cjc >= 1.1.0
- **扩展标准库**：需要配置 stdx 的 `bin-dependencies`（参考下方说明）

### stdx 配置说明

json4cj 依赖 `stdx.encoding.json` 模块，需要设置 `CANGJIE_STDX_PATH` 环境变量并在项目的 `cjpm.toml` 中配置 stdx 二进制依赖：

```bash
# 设置环境变量（添加到 ~/.bashrc 或 ~/.zshrc）
export CANGJIE_STDX_PATH=/opt/cangjie/stdx/linux_x86_64_llvm/static/stdx
```

```toml
[target.x86_64-unknown-linux-gnu]
  [target.x86_64-unknown-linux-gnu.bin-dependencies]
    path-option = ["${CANGJIE_STDX_PATH}"]
```

stdx 安装路径说明：
- 下载地址：https://gitcode.com/Cangjie/cangjie-stdx-bin
- Linux x86_64 版本：https://gitcode.com/Cangjie/cangjie-stdx-bin/releases/download/v1.0.1.1/cangjie-stdx-linux-x64-1.0.1.1.zip
- 解压后配置 `bin-dependencies` 指向静态库目录

## 编译与测试

```bash
# 编译并运行测试（含 cjlint 检查）
cjpm bundle

# 仅编译
cjpm build

# 仅运行单元测试
cjpm test
```

## 项目结构

```
json4cj/
├── src/
│   ├── json_serializable.cj         # 核心接口：JsonCodec<T>、JsonValueSerializable<T> 及类型扩展
│   ├── jsonmacro/                   # 宏系统实现（json4cj.jsonmacro 包）
│   │   ├── json_serialize.cj        # @JsonSerialize 宏（主入口）
│   │   ├── json_property.cj         # @JsonProperty 宏（字段别名）
│   │   ├── json_ignore.cj           # @JsonIgnore 宏（字段忽略）
│   │   ├── json_deserialize.cj      # @JsonDeserialize 宏（自定义序列化器）
│   │   ├── json_ignore_unknown.cj   # @JsonIgnoreUnknown 宏（未知字段处理）
│   │   ├── json_include.cj          # @JsonInclude 宏（包含控制）
│   │   ├── json_format.cj           # @JsonFormat 宏（日期格式化）
│   │   ├── json_creator.cj          # @JsonCreator 宏（构造函数反序列化）
│   │   ├── json_type_info.cj        # @JsonTypeInfo 宏（多态鉴别字段）
│   │   ├── json_sub_types.cj        # @JsonSubTypes 宏（子类型映射）
│   │   ├── json_type.cj             # @JsonType 宏（子类鉴别值）
│   │   ├── polymorphic_processor.cj # 多态类型代码生成器
│   │   ├── enum_processor.cj        # 枚举类型序列化代码生成
│   │   ├── class_json_serializer.cj    # 序列化代码生成（HashMap 体系）
│   │   ├── class_json_deserializer.cj  # 反序列化代码生成（HashMap 体系）
│   │   ├── class_stream_serializer.cj  # 流式序列化代码生成（Stream 体系）
│   │   ├── class_stream_deserializer.cj # 流式反序列化代码生成（Stream 体系）
│   │   └── ...
│   └── test/                        # 单元测试
│       ├── serialization_test.cj
│       ├── custom_name_test.cj
│       ├── ignore_test.cj
│       ├── ignore_unknown_test.cj
│       ├── include_test.cj
│       ├── format_test.cj
│       ├── creator_test.cj
│       ├── option_test.cj
│       ├── deserialize_test.cj
│       ├── enum_test.cj
│       ├── enum_param_test.cj
│       ├── enum_quick_test.cj
│       └── ...
└── cjpm.toml
```

## 测试覆盖

当前包含 173 个测试用例，覆盖以下场景：

- 基础序列化/反序列化
- 自定义字段名（`@JsonProperty`）
- 字段忽略（`@JsonIgnore`）
- 默认值处理
- `Option<T>` 类型
- 自定义序列化器（`@JsonDeserialize`）
- 嵌套对象和集合
- 泛型类型
- 结构体序列化
- `DateTime` 类型处理
- UInt 类型处理（UInt8/16/32/64）
- 未知字段处理（`@JsonIgnoreUnknown[true/false]`）
- 包含控制（`@JsonInclude[NON_NULL/NON_EMPTY]`）
- 日期格式化（`@JsonFormat`）
- 构造函数反序列化（`@JsonCreator` + `let` 字段）
- 泛型类序列化（`Option<T>` 包装 + bare type param + `@JsonCreator` / var 默认值）
- 多态类型测试（协变返回、动态分派、`ArrayList<Base>` 多态）
- 多态类型宏测试（`@JsonTypeInfo` + `@JsonSubTypes` + `@JsonType`，12 个测试用例）
- 简单枚举序列化（`@JsonSerialize` 标注 enum）
- 有参枚举序列化（serde externally-tagged：单参、多参、混合、递归枚举）
- 枚举作为类字段（PRIMITIVE 分类 + JsonValue 桥接）
- Stream 流式序列化/反序列化
- 性能基准测试

## 许可证

本项目采用 Apache-2.0 许可证，详见 [LICENSE](LICENSE) 文件。
