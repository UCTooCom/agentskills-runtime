# 多态策略设计文档 - 对齐 Rust Serde

## 📊 Serde vs json4cj 对比分析

### 1. 设计哲学对比

| 维度 | Rust Serde | json4cj (当前) | json4cj (目标) |
|------|-----------|---------------|---------------|
| **实现机制** | 编译期派生宏（derive macros） | 编译期宏（@JsonSerialize） | ✅ 保持一致 |
| **配置方式** | 属性宏（`#[serde(...)]`） | 注解（`@JsonTypeInfo`） | ✅ 保持一致 |
| **全局状态** | ❌ 无 | ❌ 已删除 ObjectMapper | ✅ 对齐 |
| **类型安全** | 编译期类型检查 | 编译期类型检查 | ✅ 保持一致 |
| **运行时开销** | 零开销 | 零开销 | ✅ 保持一致 |

### 2. 多态策略对比

#### 2.1 Internal Tagging (内部标签) ✅ 已完成

**Serde:**
```rust
#[derive(Serialize, Deserialize)]
#[serde(tag = "type")]
enum Message {
    Request { id: String, method: String },
    Response { id: String, result: String },
}
```

**生成的 JSON:**
```json
{
  "type": "Request",
  "id": "123",
  "method": "get_user"
}
```

**json4cj (当前):**
```cangjie
@JsonTypeInfo[tag="type"]
@JsonSubTypes["request" => Request, "response" => Response]
@JsonSerialize
open class Message {
    var id: String = ""
}

@JsonType["request"]
class Request <: Message {
    var method: String = ""
}
```

**生成的 JSON:**
```json
{
  "type": "request",
  "id": "123",
  "method": "get_user"
}
```

**对比结论**: ✅ **完全对齐**，命名略有不同但语义一致

---

#### 2.2 External Tagging (外部标签) ❌ 待实现

**Serde:**
```rust
#[derive(Serialize, Deserialize)]
#[serde(tag = "type")]
enum Message {
    Request { id: String },
    Response { id: String },
}
```

**注意**: Serde 的 `tag` 实际上生成的是 **Internal Tagging**，External Tagging 在 Serde 中是默认的 enum 行为：

```rust
#[derive(Serialize, Deserialize)]
enum Message {
    Request { id: String },
    Response { id: String },
}
```

**生成的 JSON (External):**
```json
{
  "Request": {
    "id": "123"
  }
}
```

**json4cj 设计:**
```cangjie
@JsonTypeInfo[EXTERNAL]  // 新策略
@JsonSubTypes["request" => Request, "response" => Response]
@JsonSerialize
open class Message {
    // 基类字段为空或很少
}

@JsonType["request"]
class Request <: Message {
    var id: String = ""
    var method: String = ""
}
```

**目标 JSON:**
```json
{
  "Request": {
    "id": "123",
    "method": "get_user"
  }
}
```

**实现难点:**
- ❌ 类型名称作为最外层 key
- ❌ 所有字段嵌套在内部对象
- ❌ 反序列化时需要先读取 type key，再分发到子类

---

#### 2.3 Adjacent Tagging (相邻标签) ❌ 待实现

**Serde:**
```rust
#[derive(Serialize, Deserialize)]
#[serde(tag = "type", content = "data")]
enum Message {
    Request { id: String, method: String },
    Response { id: String, result: String },
}
```

**生成的 JSON:**
```json
{
  "type": "Request",
  "data": {
    "id": "123",
    "method": "get_user"
  }
}
```

**json4cj 设计:**
```cangjie
@JsonTypeInfo[ADJACENT, tag="type", content="data"]
@JsonSubTypes["request" => Request, "response" => Response]
@JsonSerialize
open class Message {
    // 基类字段为空
}

@JsonType["request"]
class Request <: Message {
    var id: String = ""
    var method: String = ""
}
```

**目标 JSON:**
```json
{
  "type": "request",
  "data": {
    "id": "123",
    "method": "get_user"
  }
}
```

**实现难点:**
- ❌ type 和 data 在同一层级
- ❌ 所有业务字段嵌套在 content 对象内
- ❌ 反序列化时需要读取 type，然后在 data 对象中解析字段

---

#### 2.4 Untagged (无标签) ❌ 待实现

**Serde:**
```rust
#[derive(Serialize, Deserialize)]
#[serde(untagged)]
enum Message {
    Request { id: String, method: String },
    Response { id: String, result: String },
}
```

**生成的 JSON (Request):**
```json
{
  "id": "123",
  "method": "get_user"
}
```

**生成的 JSON (Response):**
```json
{
  "id": "123",
  "result": "user_data"
}
```

**json4cj 设计:**
```cangjie
@JsonTypeInfo[UNTAGGED]
@JsonSubTypes[Request, Response]  // 不需要 discriminator
@JsonSerialize
open class Message {
    // 基类字段为空
}

class Request <: Message {
    var id: String = ""
    var method: String = ""
}

class Response <: Message {
    var id: String = ""
    var result: String = ""
}
```

**目标 JSON:**
```json
// Request 实例
{
  "id": "123",
  "method": "get_user"
}

// Response 实例
{
  "id": "123",
  "result": "user_data"
}
```

**实现难点:**
- ❌ 没有 type 字段，需要通过字段特征推断类型
- ❌ 反序列化时需要尝试每个子类，直到匹配成功
- ❌ 字段重叠可能导致歧义（如都有 `id` 字段）

---

## 🎯 实现计划

### 阶段 1: External Tagging (2 天)

**需要修改的文件:**
1. `global_config.cj` - 添加 `TaggingStrategy` 枚举
2. `class_config_builder.cj` - 解析新注解参数
3. `polymorphic_processor.cj` - 实现 External 策略的代码生成

**核心实现:**
```cangjie
// External Tagging - toJsonValue()
public func toJsonValue(): JsonValue {
    var innerMap = HashMap<String, JsonValue>()
    innerMap.add("id", this.id.toJsonValue())
    innerMap.add("method", this.method.toJsonValue())
    
    var outerMap = HashMap<String, JsonValue>()
    outerMap.add("Request", JsonObject(innerMap))  // 类型名作为 key
    JsonObject(outerMap)
}

// External Tagging - fromJsonValue()
public static func fromJsonValue(json: JsonValue, _path: String): Message {
    let jsonObject = json.asObject()
    let fields = jsonObject.getFields()
    
    // 遍历所有已知的类型名
    if (fields.contains("Request")) {
        let innerJson = jsonObject.get("Request").getOrThrow()
        return Request.fromJsonValue(innerJson, _path)
    } else if (fields.contains("Response")) {
        let innerJson = jsonObject.get("Response").getOrThrow()
        return Response.fromJsonValue(innerJson, _path)
    }
    
    throw Exception("unknown Message type")
}
```

---

### 阶段 2: Adjacent Tagging (2 天)

**核心实现:**
```cangjie
// Adjacent Tagging - toJsonValue()
public func toJsonValue(): JsonValue {
    var dataMap = HashMap<String, JsonValue>()
    dataMap.add("id", this.id.toJsonValue())
    dataMap.add("method", this.method.toJsonValue())
    
    var outerMap = HashMap<String, JsonValue>()
    outerMap.add("type", JsonString("request"))
    outerMap.add("data", JsonObject(dataMap))
    JsonObject(outerMap)
}

// Adjacent Tagging - fromJsonValue()
public static func fromJsonValue(json: JsonValue, _path: String): Message {
    let jsonObject = json.asObject()
    
    // 读取 type
    let typeStr = match (jsonObject.get("type")) {
        case Some(typeValue) => (typeValue as JsonString).getOrThrow().getValue()
        case None => throw Exception("missing type discriminator")
    }
    
    // 读取 data 对象
    let dataJson = match (jsonObject.get("data")) {
        case Some(dataValue) => dataValue
        case None => throw Exception("missing content field: data")
    }
    
    // 分发到子类
    if (typeStr == "request") {
        return Request.fromJsonValue(dataJson, _path)
    } else if (typeStr == "response") {
        return Response.fromJsonValue(dataJson, _path)
    }
    
    throw Exception("unknown Message type: " + typeStr)
}
```

---

### 阶段 3: Untagged (2 天)

**核心实现:**
```cangjie
// Untagged - toJsonValue() (简单，直接序列化)
public func toJsonValue(): JsonValue {
    var map = HashMap<String, JsonValue>()
    map.add("id", this.id.toJsonValue())
    map.add("method", this.method.toJsonValue())
    JsonObject(map)
}

// Untagged - fromJsonValue() (复杂，需要尝试匹配)
public static func fromJsonValue(json: JsonValue, _path: String): Message {
    // 策略 1: 尝试每个子类，直到成功
    // 注意：这可能会有副作用，需要 clone json
    
    // 尝试 Request (有 method 字段)
    let jsonObject = json.asObject()
    if (jsonObject.getFields().contains("method")) {
        return Request.fromJsonValue(json, _path)
    }
    
    // 尝试 Response (有 result 字段)
    if (jsonObject.getFields().contains("result")) {
        return Response.fromJsonValue(json, _path)
    }
    
    throw Exception("cannot determine Message type from fields")
}
```

---

## 📝 注解设计

### 方案 A: 枚举策略（推荐）

```cangjie
@JsonTypeInfo[
    strategy = INTERNAL,  // 新参数：INTERNAL | EXTERNAL | ADJACENT | UNTAGGED
    tag = "type",
    content = "data"      // 仅 ADJACENT 需要
]
@JsonSubTypes["request" => Request, "response" => Response]
@JsonSerialize
open class Message { ... }
```

**优点:**
- ✅ 显式声明策略，清晰明了
- ✅ 与 Serde 的语义对齐
- ✅ 编译期可以验证参数合法性

---

### 方案 B: 独立注解

```cangjie
@JsonTypeInfo[tag="type"]
@JsonTaggingStrategy[EXTERNAL]  // 独立注解
@JsonSubTypes["request" => Request]
@JsonSerialize
open class Message { ... }
```

**缺点:**
- ❌ 注解过多，配置分散
- ❌ 可能出现冲突（如同时指定 INTERNAL 和 EXTERNAL）

**结论**: ✅ 采用方案 A

---

## 🔧 技术实现细节

### 1. TaggingStrategy 枚举

```cangjie
public enum TaggingStrategy {
    | INTERNAL    // {"type":"request","id":"123"}
    | EXTERNAL    // {"Request":{"id":"123"}}
    | ADJACENT    // {"type":"request","data":{"id":"123"}}
    | UNTAGGED    // {"id":"123"}
}
```

### 2. ClassConfig 扩展

```cangjie
class ClassConfig {
    // 现有字段
    public var typeInfoTag: String = ""
    public let subTypeMapping: HashMap<String, String> = HashMap()
    public var typeValue: String = ""
    
    // 新增字段
    public var taggingStrategy: TaggingStrategy = TaggingStrategy.INTERNAL
    public var contentField: String = "data"  // 仅 ADJACENT 使用
}
```

### 3. 注解解析

```cangjie
// 解析 @JsonTypeInfo[INTERNAL, tag="type"]
// 或 @JsonTypeInfo[EXTERNAL]
// 或 @JsonTypeInfo[ADJACENT, tag="type", content="payload"]
// 或 @JsonTypeInfo[UNTAGGED]
```

---

## 🧪 测试用例设计

### External Tagging 测试

```cangjie
@JsonTypeInfo[EXTERNAL]
@JsonSubTypes["dog" => Dog, "cat" => Cat]
@JsonSerialize
open class Animal { }

@JsonType["dog"]
class Dog <: Animal {
    var name: String = ""
    var breed: String = ""
}

// 测试序列化
let dog = Dog()
dog.name = "Buddy"
dog.breed = "Golden Retriever"
let json = dog.toJson()
// 期望: {"Dog":{"name":"Buddy","breed":"Golden Retriever"}}

// 测试反序列化
let dog2 = Animal.fromJson(json) as Dog
assert(dog2.name == "Buddy")
assert(dog2.breed == "Golden Retriever")
```

### Adjacent Tagging 测试

```cangjie
@JsonTypeInfo[ADJACENT, tag="type", content="data"]
@JsonSubTypes["dog" => Dog, "cat" => Cat]
@JsonSerialize
open class Animal { }

@JsonType["dog"]
class Dog <: Animal {
    var name: String = ""
    var breed: String = ""
}

// 测试序列化
let json = dog.toJson()
// 期望: {"type":"dog","data":{"name":"Buddy","breed":"Golden Retriever"}}

// 测试反序列化
let dog2 = Animal.fromJson(json) as Dog
assert(dog2.name == "Buddy")
```

### Untagged 测试

```cangjie
@JsonTypeInfo[UNTAGGED]
@JsonSubTypes[Request, Response]
@JsonSerialize
open class Message { }

class Request <: Message {
    var id: String = ""
    var method: String = ""
}

class Response <: Message {
    var id: String = ""
    var result: String = ""
}

// 测试序列化
let req = Request()
req.id = "123"
req.method = "get_user"
let json = req.toJson()
// 期望: {"id":"123","method":"get_user"}

// 测试反序列化
let msg = Message.fromJson(json) as Request
assert(msg.method == "get_user")
```

---

## ⚠️ 已知限制和边界情况

### 1. External Tagging
- ❌ 基类不能有字段（或字段会被忽略）
- ✅ 适合标记联合（tagged union）场景

### 2. Adjacent Tagging
- ❌ content 字段名不能与业务字段冲突
- ✅ 适合需要明确类型和数据分离的场景

### 3. Untagged
- ❌ 子类必须有明显区分的字段
- ❌ 反序列化性能较差（需要多次尝试）
- ⚠️ 字段重叠可能导致匹配错误
- ✅ 适合简洁的 API 响应

---

## 📚 参考资源

- [Serde Representation](https://serde.rs/enum-representations.html)
- [Serde Attributes](https://serde.rs/attributes.html)
- json4cj 现有实现: `polymorphic_processor.cj`
- 测试用例: `polymorphic_macro_test.cj`

---

## ✅ 决策总结

| 策略 | 优先级 | 预计工期 | 难度 | 备注 |
|------|--------|---------|------|------|
| Internal | ✅ 已完成 | - | - | 已对齐 Serde |
| External | 🥇 P0 | 2 天 | 中 | 简单，适合标记联合 |
| Adjacent | 🥈 P1 | 2 天 | 中 | 类型和数据分离 |
| Untagged | 🥉 P2 | 2 天 | 高 | 需要字段推断逻辑 |

**总计**: 6 天工作量，分 3 个阶段实现
