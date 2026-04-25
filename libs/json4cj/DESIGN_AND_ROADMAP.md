# json4cj 架构设计与演进路线

打造仓颉语言版本的 Jackson —— 完整的 JSON 序列化/反序列化解决方案

## 目录

- [概述](#概述)
- [1. stdx 能力评估](#1-stdxencodingjson-能力评估)
- [2. 多语言 JSON 库对比](#2-多语言-json-库设计模式对比)
- [3. 当前状态评估](#3-当前状态评估)
- [4. 代码级设计分析](#4-代码级设计分析)
- [5. 命名规范设计](#5-命名规范设计)
- [6. 推荐架构设计](#6-推荐架构设计)
  - [6.5 Stream 流式序列化架构](#65-stream-流式序列化架构phase-2-已实现)
- [7. 演进路线](#7-演进路线)
- [8. 实施建议](#8-实施建议)

---

## 概述

json4cj 的目标是成为仓颉语言生态中"默认选择"的 JSON 库，就像 serde 之于 Rust，Jackson 之于 Java。

### 设计原则

- **编译时宏生成**：零运行时开销（类似 Rust serde）
- **ObjectMapper 全局配置**：灵活性（类似 Java Jackson）
- **复用 stdx 底层能力**：避免重复造轮子
- **渐进增强**：从简单到复杂，按需使用

---

## 1. stdx.encoding.json 能力评估

### 1.1 stdx 已提供的能力

| 层级 | 能力 | 说明 |
|------|------|------|
| **数据层** | `JsonValue.fromStr()` | 解析 JSON 字符串为树结构 |
| （stdx.encoding.json） | `JsonObject` / `JsonArray` | 构建和操作 JSON 树 |
| | `get()` / `operator[]` | 安全/直接访问 |
| **流式层** | `JsonWriter` / `JsonReader` | 令牌流式序列化/反序列化 |
| （stdx.encoding.json.stream） | `JsonSerializable` / `JsonDeserializable<T>` | 自定义类型接口 |
| | `writeValue<T>()` / `readValue<T>()` | 泛型读写 |
| | `WriteConfig` | 格式控制（compact/pretty） |

**stdx 已内置支持的类型**：
- 整数：`Int8` ~ `Int64`, `UInt8` ~ `UInt64`
- 浮点：`Float16` ~ `Float64`
- 布尔、字符串
- 集合：`Array<T>`, `ArrayList<T>`, `HashMap<String, T>`（⚠️ `HashSet<T>` 有泛型约束传播问题，见 6.5 节）
- 可选：`Option<T>`
- 其他：`BigInt`, `Decimal`, `DateTime`（RFC 3339）

### 1.2 stdx 缺失的能力（json4cj 的价值所在）

| 缺失能力 | json4cj 解决方案 |
|---------|--------------|
| 自动注解驱动 | `@JsonSerialize` 宏自动生成代码 |
| 字段映射 | `@JsonProperty` 注解 |
| 字段忽略 | `@JsonIgnore` 注解 |
| 默认值处理 | 宏自动生成默认值逻辑 |
| 未知字段处理 | `@JsonIgnoreUnknown[true/false]` ✅ |
| 包含控制 | `@JsonInclude[NON_NULL/NON_EMPTY]` ✅ |
| 日期格式化 | `@JsonFormat["yyyy-MM-dd"]` ✅ |
| 不可变对象 | `@JsonCreator` ✅ |
| 简单枚举序列化 | `@JsonSerialize` 支持无参 enum ✅ |
| 有参枚举序列化 | `@JsonSerialize` 支持有参 enum（serde externally-tagged）✅ |
| 全局配置 | `ObjectMapper`（需新增） |
| 多态类型 | `@JsonTypeInfo`（需新增） |
| 模块系统 | `JsonModule`（需新增） |

**结论**：stdx 提供了**底层基础设施**，json4cj 在此基础上提供**高层抽象**（注解驱动 + 自动代码生成 + 全局配置）。

---

## 2. 多语言 JSON 库设计模式对比

### 2.1 设计模式分类

| 模式 | 代表 | 特点 |
|------|------|------|
| **反射驱动** | Jackson (Java), Gson | 运行时反射，零注解也可工作 |
| **宏/代码生成** | serde (Rust), json4cj, easyjson (Go) | 编译时生成，零运行时开销 |
| **手动实现** | stdx 基础用法, Go encoding/json | 手动写序列化逻辑，灵活但繁琐 |
| **混合模式** | Jackson + ObjectMapper | 自动 + 手动可切换 |

### 2.2 json4cj 的定位

```
应用层（json4cj）
  ├─ @JsonXXX 注解驱动
  ├─ ObjectMapper 全局配置
  └─ JsonModule 模块系统
        ↓
基础设施层（stdx.encoding.json）
  ├─ 数据层：JsonValue, JsonObject, JsonArray
  └─ 流式层：JsonWriter, JsonReader
        ↓
编译器（cjc）
  └─ 宏展开 → 代码生成 → 编译优化
```

### 2.3 与主流库对比

| 特性 | Rust serde | Java Jackson | Go encoding/json | json4cj (当前) | json4cj (目标) |
|------|-----------|--------------|------------------|-------------|---------------|
| **代码生成** | ✅ 派生宏 | ❌ 反射 | ❌ 反射 | ✅ 宏 | ✅ 宏 |
| **运行时开销** | 零 | 中 | 中 | 零 | 零 |
| **字段重命名** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **字段忽略** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **默认值** | ✅ | ✅ | ❌ | ✅ | ✅ |
| **包含控制** | ✅ | ✅ | ✅ (omitempty) | ✅ `@JsonInclude` | ✅ |
| **enum 序列化** | ✅ | ✅ | ❌ | ✅ (简单+有参枚举) | ✅ |
| **未知字段处理** | ✅ | ✅ | ❌ | ✅ `@JsonIgnoreUnknown` | ✅ |
| **全局配置** | ❌ | ✅ | ❌ | ❌ | ⏳ ObjectMapper |
| **日期格式化** | ❌ | ✅ | ❌ | ✅ `@JsonFormat` | ✅ |
| **不可变对象** | ✅ | ✅ | ❌ | ✅ `@JsonCreator` | ✅ |
| **多态类型** | ✅ 4种策略 | ✅ 注解+反射 | ❌ 手动 | ❌ | ⏳ **serde 对齐** |
| **自定义序列化** | ✅ | ✅ | ✅ | ✅ (per-field) | ✅ |
| **模块系统** | ❌ | ✅ | ❌ | ❌ | ⏳ JsonModule |
| **Tree Model** | serde_json::Value | JsonNode | map[string]interface{} | ✅ (stdx) | ✅ |
| **流式 API** | ✅ | ✅ | ✅ | ✅ (stdx) | ✅ |

### 2.4 多态序列化方案深度对比

多态序列化是指：**根据 JSON 中的鉴别字段（discriminator），自动选择具体的子类型进行反序列化**。这是企业级 API 的核心需求。

#### Rust serde：4 种标签策略（编译期最优）

serde 提供了最灵活的多态方案，通过注解选择标签位置：

```rust
// 1. Externally Tagged（外部标签）- 默认
#[derive(Serialize, Deserialize)]
enum Animal {
    Dog { name: String },
    Cat { lives: i32 }
}
// JSON: {"Dog": {"name": "Buddy"}}

// 2. Internally Tagged（内部标签）
#[derive(Serialize, Deserialize)]
#[serde(tag = "type")]
enum Animal {
    Dog { name: String },
    Cat { lives: i32 }
}
// JSON: {"type": "Dog", "name": "Buddy"}

// 3. Adjacently Tagged（相邻标签）
#[derive(Serialize, Deserialize)]
#[serde(tag = "type", content = "data")]
enum Animal {
    Dog { name: String },
    Cat { lives: i32 }
}
// JSON: {"type": "Dog", "data": {"name": "Buddy"}}

// 4. Untagged（无标签）- 按顺序尝试
#[derive(Serialize, Deserialize)]
#[serde(untagged)]
enum Animal {
    Dog { name: String },
    Cat { lives: i32 }
}
// JSON: {"name": "Buddy"} （根据字段推断）
```

**Trait Object 多态**（接口多态）：
```rust
// 非常复杂，需要自定义序列化器
#[derive(Serialize, Deserialize)]
struct Zoo {
    #[serde(with = "animal_map")]
    animals: Vec<Box<dyn AnimalTrait>>
}
```

**优势**：
- ✅ 编译期类型安全，零运行时开销
- ✅ 4 种标签策略灵活选择
- ✅ 宏展开生成 match 分支，性能最优
- ❌ Trait Object 多态非常复杂（需手动实现）

---

#### Java Jackson：注解 + 运行时反射（最成熟）

Jackson 使用注解注册子类型映射表：

```java
// 基类定义
@JsonTypeInfo(
    use = JsonTypeInfo.Id.NAME,        // 使用名称
    include = JsonTypeInfo.As.PROPERTY, // 作为属性
    property = "type"                   // 字段名
)
@JsonSubTypes({
    @JsonSubTypes.Type(value = Dog.class, name = "dog"),
    @JsonSubTypes.Type(value = Cat.class, name = "cat")
})
public abstract class Animal {
    public String name;
}

public class Dog extends Animal {
    public String breed;
}

public class Cat extends Animal {
    public int lives;
}

// JSON: {"type": "dog", "name": "Buddy", "breed": "Labrador"}
```

**其他策略**：
```java
// 1. 使用完整类名
@JsonTypeInfo(use = JsonTypeInfo.Id.CLASS)
// JSON: {"@class": "com.example.Dog", ...}

// 2. 推断模式 (Jackson 2.12+)
@JsonTypeInfo(use = JsonTypeInfo.Id.DEDUCTION)
// 无类型字段，根据字段存在推断
```

**优势**：
- ✅ 成熟的注册表机制，支持继承层次
- ✅ DEDUCTION 模式无需类型字段
- ❌ 运行时反射开销
- ❌ 需要显式注册所有子类型

---

#### Go：手动实现（最透明但最繁琐）

Go **没有内置多态支持**，需要手动实现 `UnmarshalJSON`：

```go
// 1. 定义接口
type Animal interface {
    GetName() string
}

// 2. 定义具体类型
type Dog struct {
    Kind  string `json:"type"`
    Name  string `json:"name"`
    Breed string `json:"breed"`
}

// 3. 手动实现反序列化器
func UnmarshalAnimal(data []byte) (Animal, error) {
    // 第一步：读取类型鉴别字段
    var discriminator struct {
        Type string `json:"type"`
    }
    json.Unmarshal(data, &discriminator)
    
    // 第二步：根据类型创建实例
    var animal Animal
    switch discriminator.Type {
    case "Dog":
        animal = &Dog{}
    case "Cat":
        animal = &Cat{}
    default:
        return nil, fmt.Errorf("unknown type: %s", discriminator.Type)
    }
    
    // 第三步：反序列化到具体类型
    json.Unmarshal(data, animal)
    return animal, nil
}
```

**序列化时手动添加类型标签**：
```go
func (d *Dog) MarshalJSON() ([]byte, error) {
    type Alias Dog
    return json.Marshal(&struct {
        Type string `json:"type"`
        *Alias
    }{
        Type:  "Dog",
        Alias: (*Alias)(d),
    })
}
```

**优势**：
- ✅ 完全控制，逻辑透明
- ✅ 无运行时反射
- ❌ 大量样板代码（50+ 行/类型）
- ❌ 每个多态类型都需要手动实现

---

#### 对比总结表

| 特性 | Rust serde | Java Jackson | Go | json4cj (目标) |
|------|-----------|-------------|-----|---------------|
| **实现方式** | 编译期宏 | 运行时反射 | 手动实现 | **编译期宏** |
| **标签策略** | 4种（外部/内部/相邻/无） | 5种（名称/类名/最小类名/属性/推断） | 手动编码 | **内部标签（推荐）** |
| **类型注册** | 不需要（编译期推断） | 需要 `@JsonSubTypes` 注册 | 手动 switch-case | **声明式注解** |
| **代码量** | 1行注解 | 2-3行注解 | 50+行手动代码 | **1-2行注解** |
| **性能** | 零开销 | 反射开销 | 零开销 | **零开销** |
| **类型安全** | 编译期保证 | 运行时检查 | 编译期保证 | **编译期保证** |
| **学习曲线** | 中等 | 低 | 高 | **低（对齐 serde）** |

---

#### json4cj 设计方案（对齐 serde）

基于三语言实践，**推荐采用 serde 的声明式注解方案**：

```cangjie
// 方案A: 内部标签（推荐，最常用）
@JsonTypeInfo[tag = "type"]
@JsonSubTypes[["dog" => Dog, "cat" => Cat]]
class Animal {
    var name: String = ""
}

class Dog : Animal {
    var breed: String = ""
}

class Cat : Animal {
    var lives: Int64 = 9
}

// JSON: {"type": "dog", "name": "Buddy", "breed": "Labrador"}
```

**生成的代码**（宏展开后）：
```cangjie
// 序列化：自动注入 type 字段
public func toJsonValue(): JsonObject {
    let obj = JsonObject(HashMap())
    obj.add("type", JsonString("dog"))  // 自动注入
    obj.add("name", JsonString(this.name))
    obj.add("breed", JsonString(this.breed))
    return obj
}

// 反序列化：读取 type 字段 → 选择子类
public static func fromJsonValue(json: JsonValue, path: String): Animal {
    let obj = json.asObject()
    let typeVal = obj.get("type")
    match (typeVal) {
        case Some(JsonString(t)) => {
            match (t) {
                case "dog" => return Dog.fromJsonValue(json, path)
                case "cat" => return Cat.fromJsonValue(json, path)
                case _ => throw Exception("Unknown type: " + t)
            }
        }
        case _ => throw Exception("Missing type discriminator")
    }
}
```

**未来可扩展的标签策略**（对齐 serde）：
```cangjie
// 外部标签（enum 专用）
@JsonTaggedEnum[external]  // 默认
enum Animal {
    | Dog(String, Int64)
    | Cat(Int64)
}
// JSON: {"Dog": ["Buddy", 5]} 或 {"Cat": 9}

// 相邻标签
@JsonTypeInfo[tag = "type", content = "data"]
class Animal { ... }
// JSON: {"type": "dog", "data": {"name": "Buddy"}}

// 无标签（按顺序尝试）
@JsonTypeInfo[untagged]
class Animal { ... }
// JSON: {"name": "Buddy", "breed": "Labrador"}
```

---

## 3. 当前状态评估

### 3.1 当前设计的核心优势

| 设计点 | 评价 |
|--------|------|
| 宏生成 + 零运行时开销 | 与 serde 一致，正确选择 |
| 嵌套宏通信（`setItem`/`getChildMessages`） | 优雅解决了 `@JsonCust` 参数传递 |
| `IJsonValueSerializable<T>` 接口 + extend 扩展 | 利用了 Cangjie extend 特性，类似 serde 的 trait impl |
| Visitor 模式遍历 AST | 符合 Cangjie 宏编程最佳实践 |
| class + struct 双支持 | 完善 |

### 3.2 已实现功能

| Jackson 特性 | json4cj 等价实现 | 状态 |
|-------------|---------------|------|
| `@JsonSerialize` / POJO 自动检测 | `@JsonSerialize` | ✅ |
| `@JsonProperty` | `@JsonProperty["name"]` | ✅ |
| `@JsonIgnore` | `@JsonIgnore` | ✅ |
| `@JsonDeserialize`（自定义反序列化器） | `@JsonDeserialize[XxxSerializer]` | ✅ |
| `@JsonIgnoreProperties(ignoreUnknown)` | `@JsonIgnoreUnknown[true/false]` | ✅ |
| `@JsonInclude(NON_NULL)` | `@JsonInclude[NON_NULL/NON_EMPTY/ALWAYS]` | ✅ |
| `@JsonFormat(pattern=...)` | `@JsonFormat["yyyy-MM-dd"]` | ✅ |
| `@JsonCreator`（构造函数反序列化） | `@JsonCreator` | ✅ |
| 默认值处理 | 默认值自动处理 | ✅ |
| 嵌套对象 | 嵌套序列化 | ✅ |
| 集合（List, Set, Map） | ArrayList, HashSet, HashMap | ✅ |
| 结构体支持 | `class` 和 `struct` 均支持 | ✅ |
| 可选类型 | `Option<T>` 支持 | ✅ |
| 泛型集合 | 泛型嵌套序列化 | ✅ |
| UInt 类型 | UInt8/16/32/64 扩展 | ✅ |
| 简单枚举序列化 | `@JsonSerialize` 支持无参 enum | ✅ |
| 有参枚举序列化 | `@JsonSerialize` 支持有参 enum（serde externally-tagged） | ✅ |

### 3.3 设计评估

**当前设计在以下场景是最优的**：
- ✅ 简单 POJO 序列化/反序列化
- ✅ 性能敏感场景（零运行时开销）
- ✅ 类型明确的场景

**当前设计在以下场景不够用**：
- ❌ API 网关/代理（需要 Tree Model 封装）
- ❌ 多态事件系统（需要 `@JsonTypeInfo`）
- ❌ 第三方类型序列化（需要 Module/Mixin）
- ✅ ~~不可变对象（需要构造函数反序列化）~~ 已通过 `@JsonCreator` 解决
- ✅ ~~版本兼容 API（需要 ignoreUnknown）~~ 已通过 `@JsonIgnoreUnknown` 解决
- ✅ ~~enum 类型（完全不支持）~~ 简单枚举和有参枚举均已通过 `@JsonSerialize` 支持（serde externally-tagged 表示）

---

## 4. 代码级设计分析

基于对全部 35 个源文件的深入审查，对标 serde 和 Jackson 的设计模式，以下是具体的代码级优化点。

### 4.1 设计优化点（现有代码可改进）

#### ~~问题 1：序列化中间层使用 HashMap 拼装，应使用 stdx JsonWriter 流式写入~~ ✅ 已解决

> **已解决**（Phase 2，commit `e059ffc`）：宏现在额外生成 `extend Clazz <: JsonSerializable { toJson(w) }` 和 `extend Clazz <: JsonDeserializable<Clazz> { static fromJson(r) }` 实现，直接使用 stdx stream API 流式读写。对于 stdx 约束传播不支持的字段类型（如 `HashSet<T>`、`HashMap<K,V>`），使用 JsonValue 桥接模式回退。

**当前实现**（`ClassJsonSerilizer.cj`）：

```cangjie
// 当前宏生成的代码模式
func toJsonValue(): JsonValue {
    let jMap = HashMap<String, JsonValue>()
    jMap["name"] = this.name.toJsonValue()
    jMap["age"] = this.age.toJsonValue()
    return JsonObject(jMap)  // 先构建中间 HashMap，再包装
}
```

**serde 的做法**：不构建中间 HashMap，直接流式写入 Serializer：

```rust
fn serialize<S: Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
    let mut state = serializer.serialize_struct("User", 2)?;
    state.serialize_field("name", &self.name)?;
    state.serialize_field("age", &self.age)?;
    state.end()
}
```

**建议**：宏应额外生成 stdx `JsonSerializable` 接口实现，直接使用 `JsonWriter` 流式写入：

```cangjie
// 优化后：宏额外生成 stdx JsonSerializable 实现
public func serialize(w: JsonWriter): Unit {
    w.startObject()
    w.writeName("name"); w.writeValue(this.name)
    w.writeName("age"); w.writeValue(this.age)
    w.endObject()
}
```

**收益**：大对象零中间分配，内存占用降低，与 stdx 生态无缝集成。

---

#### ~~问题 2：GlobalConfig 使用全局可变状态~~ ✅ 已修复

> **已修复**（commit `3f70696`）：GlobalConfig 已改为在 `@JsonSerialize` 宏入口处创建局部变量，通过参数传递给序列化器/反序列化器，不再使用全局可变状态。

**当前实现**（`GlobalConfig.cj`）：

```cangjie
var globalConfig = GlobalConfig()  // 模块级全局变量
```

Cangjie 宏文档明确指出："**避免在宏中使用全局可变状态（并行展开不安全）**"。当多个类同时被宏展开时，`globalConfig` 会被共享和覆盖。

**serde 的做法**：每个 derive 调用是独立的，不共享任何状态。

**建议**：将 `GlobalConfig` 作为局部变量在 `@JsonSerializable` 宏入口处创建，通过参数传递：

```cangjie
public macro JsonSerializable(input: Tokens): Tokens {
    let config = GlobalConfig()  // 局部，非全局
    // ... 传递 config 给 ClassProcessor / Serializer / Deserializer
}
```

---

#### ~~问题 3：反序列化 Option 错误处理~~ ✅ 已修复

> **已修复**（commit `904f5b3`）：已区分"字段不存在"和"字段值格式错误"，生成 `containsKey` + `JsonValueKind.JsNull` 检查的精确错误处理代码。

**当前实现**（`ClassJsonDeserilizer.cj`）：

```cangjie
// 当前生成的代码
try {
    inst.field = Some(T.fromJsonValue(obj["field"]))
} catch(_: Exception) {
    inst.field = None  // 静默吞掉所有错误，包括格式错误
}
```

**问题**：无法区分"字段不存在"（正常）和"字段值格式错误"（应报错）。

**Jackson 的做法**：区分字段不存在 → 使用默认值；字段值格式错误 → 抛出 `JsonMappingException`。

**serde 的做法**：所有错误通过 `Result<T, E>` 传播，调用方决定处理方式。

**建议**：生成更精确的错误处理代码：

```cangjie
// 优化后
if (obj.containsKey("field")) {
    let jv = obj["field"]
    if (jv.kind == JsonValueKind.JsNull) {
        inst.field = None
    } else {
        inst.field = Some(T.fromJsonValue(jv))  // 格式错误时自然抛异常
    }
} else {
    inst.field = None  // 字段不存在才使用默认值
}
```

---

#### ~~问题 4：类型扩展不完整~~ 部分修复

> **已修复**（commit `e14c6ab`）：UInt8/16/32/64 类型扩展已补全。
>
> **待补充**：`Rune`、`Array<T>` 仍未支持。

**当前实现**（`IJsonSerializable.cj`）：

只扩展了 `Int8/16/32/64` 和 `Float16/32/64`，但缺少：

| 缺失类型 | 说明 |
|---------|------|
| `UInt8/16/32/64` | stdx 已支持，json4cj 未扩展 |
| `Rune` | 单字符，应序列化为字符串 |
| `Array<T>` | 原生数组，与 `ArrayList<T>` 不同 |

**serde 的做法**：为所有基本类型实现 `Serialize`/`Deserialize`。

**建议**：补全所有 stdx 已支持的类型扩展。

---

#### 问题 5：宏生成代码中的硬编码字符串拼接

**当前实现**：序列化/反序列化代码通过大量 `cangjieLex` 字符串拼接生成代码，脆弱且难以维护。

**建议**：更多使用 `quote(...)` + `$(...)` 插值的结构化方式，减少 `cangjieLex` 的使用。对于动态标识符，使用 `Token(TokenKind.IDENTIFIER, name)` 而非字符串拼接。

---

### 4.2 需要补充的功能

#### P0 — 核心缺失（影响日常使用）

**1. `@JsonIgnoreUnknown` — 未知字段处理** ✅ 已实现

> **已实现**（commit `d343f1c` / `d5a349b` / `7b696ad`）：
> - `@JsonIgnoreUnknown[true]` 忽略未知字段（默认行为）
> - `@JsonIgnoreUnknown[false]` 严格模式，收集所有未知字段后抛出异常
> - 严格模式异常包含完整的未知字段列表

当前反序列化时如果 JSON 包含类中不存在的字段，行为不明确。这是 Jackson/serde 最常用的特性之一。

```cangjie
// serde: 默认忽略未知字段（或 #[serde(deny_unknown_fields)]）
// Jackson: @JsonIgnoreProperties(ignoreUnknown = true)

@JsonSerializable
@JsonIgnoreUnknown  // 新增
public class User {
    var name: String = ""
}
// User.fromJson("""{"name":"test","age":25}""") → 正常工作，忽略 age
```

**实现方式**：属性宏，在反序列化代码生成时，只遍历已知字段，跳过 JSON 中多余的 key。

---

**2. `@JsonInclude` — 序列化包含控制** ✅ 已实现

> **已实现**（commit `211f90d`）：支持 ALWAYS / NON_NULL / NON_EMPTY 三种模式。

控制 null/空值/默认值是否出现在 JSON 中。

```cangjie
// serde: #[serde(skip_serializing_if = "Option::is_none")]
// Jackson: @JsonInclude(Include.NON_NULL)

@JsonSerializable
@JsonInclude[NON_NULL]
public class User {
    var name: String = ""
    var bio: Option<String> = None  // None 时不输出 "bio":null
}
```

**支持的模式**：
- `ALWAYS` — 始终包含（默认）
- `NON_NULL` — 跳过 null / None
- `NON_EMPTY` — 跳过 null 和空集合/空字符串
- `NON_DEFAULT` — 跳过默认值

**实现方式**：属性宏，在序列化生成时添加条件判断。

---

**3. enum 类型序列化支持** ✅ 已完成

> **已实现**：
> - 简单枚举（Phase 1）：`@JsonSerialize` 宏支持无参（unit-variant）枚举，自动生成字符串序列化/反序列化代码。
> - 有参枚举（Phase 2）：支持有参构造器的枚举，采用 serde externally-tagged 表示。

```cangjie
// 简单枚举：所有构造器无参数 ✅ 已支持
@JsonSerialize
enum Status {
    | Active
    | Inactive
    | Pending
}
// Active → "Active"
// Status.fromJson("\"Active\"") → Active

// 有参枚举：带参数的构造器 ✅ 已支持（serde externally-tagged）
@JsonSerialize
enum Shape {
    | Circle(Float64)
    | Rect(Float64, Float64)
    | Dot
}
// Circle(3.14)       → {"Circle":3.14}
// Rect(3.0, 4.0)     → {"Rect":[3.0,4.0]}
// Dot                 → "Dot"
// Shape.fromJson(##"{"Circle":2.5}"##) → Circle(2.5)
```

**已完成的实现**：
- `TokenVerifier` 已扩展支持 `EnumDecl`（`verifyClassOrEnumDecl()` 方法）
- `EnumProcessor` 生成完整的序列化代码：`toJsonValue()` / `toJson()` / `fromJsonValue()` / `fromJson()`
- 同时生成 `extend <: JsonSerializable` 和 `extend <: JsonDeserializable<T>` 流式 API 实现
- enum 作为类字段时自动工作（归类为 PRIMITIVE，通过 JsonValue 桥接）
- 有参枚举支持单参数、多参数、混合（unit + parameterized）和递归枚举
- 同名构造器（不同参数个数）会抛出明确错误信息

---

#### P1 — 进阶功能（影响企业场景）

**4. 构造函数反序列化（不可变对象支持）** ✅ 已实现

> **已实现**（commit `87a1b6d`）：`@JsonCreator` 宏支持 `let` 不可变字段的构造函数反序列化，生成基于构造函数参数的反序列化代码。**

当前强制要求无参构造函数 + `var` 可变字段。这与 Cangjie 推荐的 `let` 不可变设计冲突。

```cangjie
// serde: 天然支持构造函数反序列化
// Jackson: @JsonCreator + @JsonProperty

@JsonSerializable
public class User {
    let name: String   // let 不可变
    let age: Int64

    @JsonCreator
    public init(name: String, age: Int64) {
        this.name = name
        this.age = age
    }
}
```

**实现方式**：宏检测类中是否有 `@JsonCreator` 标注的构造函数，如果有则生成基于构造函数参数的反序列化代码，而非 setter 注入。

---

**5. 泛型类的序列化支持** ✅ 已实现

> **已实现**：`@JsonSerialize` 支持泛型类的完整序列化/反序列化：
> - `Option<T>` 容器字段：`var data: Option<T> = Option<T>.None`
> - Bare type param + `@JsonCreator`：`let data: T`（使用 `Option<T>` 中间变量避免 `T()` 构造函数）
> - Bare type param + `var data: T = someDefault`：也支持，不需要 @JsonCreator
> - 多类型参数：`KeyValuePair<K, V>`
> - 嵌套泛型：`Envelope<Container<T>>`
> - 自动生成 `where T <: JsonValueSerializable<T>` 约束
>
> **注意**：bare type param 字段不强制要求 `@JsonCreator`。`where T <: JsonValueSerializable<T>` 约束保证 `T.fromJsonValue()` 在运行时可用。Cangjie 编译器自身会拒绝无效的类定义（如 `let data: T` 无初始化器且无 @JsonCreator）。

当前 `Option<T>` 容器字段的泛型类已完全支持：

```cangjie
@JsonSerialize
class ApiResponse<T> {
    var code: Int64 = 0
    var data: Option<T> = Option<T>.None  // ✅ Option<T> 字段已支持
}

let resp = ApiResponse<String>.fromJson("""{"code":200,"data":"success"}""")
// resp.data.getOrThrow() == "success"
```

**bare type param + @JsonCreator 已支持**：

```cangjie
@JsonSerialize
@JsonCreator
class ApiBareResponse<T> {
    let code: Int64
    let data: T  // ✅ bare type param + @JsonCreator 已支持
    public init(code: Int64, data: T) {
        this.code = code
        this.data = data
    }
}

let resp = ApiBareResponse<String>.fromJson("""{"code":200,"data":"success"}""")
// resp.data == "success"
```

**实现原理**：对 bare type param 字段，`@JsonCreator` 路径使用 `Option<T>` 中间变量：
- 声明：`var _data: Option<T> = Option<T>.None`（避免 `T()` 构造函数）
- 赋值：`_data = Option<T>.Some(T.fromJsonValue(...))`
- 校验：`if(_data.isNone()) { throw ... "required field is missing" }`（对标 serde required field）
- 传参：`ApiBareResponse(_code, _data.getOrThrow())`（安全，因为已校验 isNone）

#### Bare Type Param 跨语言对比分析

Bare type param（如 `let data: T`）的序列化/反序列化是泛型支持的核心难点。以下是三种主流语言的解法对比：

**Rust serde — 编译时单态化（最优雅）**

```rust
#[derive(Serialize, Deserialize)]
struct ApiResponse<T> {
    code: i64,
    data: T,          // bare type param，无需任何包装
}
// Serde 自动生成：impl<T> Deserialize for ApiResponse<T> where T: Deserialize
```

核心机制：
- `#[derive]` 自动推断泛型约束：`T: Serialize` / `T: Deserialize<'de>`
- **无需默认值**：Rust 的 `Deserialize` trait 直接从 `Deserializer` 流式构建 `T`，不需要 `T::default()`
- 编译器对每个具体类型 `ApiResponse<String>` 单态化（monomorphize）生成独立代码
- `#[serde(bound = "...")]` 允许手动覆盖自动推断的约束
- 缺失字段时：默认要求字段必须存在（编译时保证），或用 `#[serde(default)]` 显式标注（额外约束 `T: Default`）

```rust
// 方式1：必须字段（默认）→ 约束 T: Deserialize
// 方式2：缺失时用默认值 → 约束 T: Deserialize + Default
#[derive(Deserialize)]
struct ApiResponse<T> {
    code: i64,
    #[serde(default)]   // 额外约束 T: Default
    data: T,
}
```

**Go — 反射 + 零值机制（最透明）**

```go
type Response[T any] struct {
    Code int64 `json:"code"`
    Data T     `json:"data"`  // bare type param，直接工作
}

var resp Response[string]
json.Unmarshal([]byte(`{"code":200,"data":"hello"}`), &resp)
```

核心机制：
- Go 1.18+ 泛型 + `encoding/json` 反射自动工作
- **零值机制**：Go 的 `var data T` 自动获得零值（`""` for string, `0` for int），不需要构造函数
- 反射能获取泛型参数的实际类型（不同于 Java 的类型擦除）
- 缺失字段自动使用零值 — 这是 Go 的语言特性，不需要 `Default` trait

**Java Jackson — 类型擦除 + 超级类型标记（最复杂）**

```java
public class ApiResponse<T> {
    public int code;
    public T data;     // 编译后变成 Object data（类型擦除）
}

// 必须携带类型信息
ApiResponse<String> resp = mapper.readValue(json,
    new TypeReference<ApiResponse<String>>() {});
```

核心机制：
- Java 泛型运行时被擦除为 `Object`，Jackson 无法通过反射知道 `T` 的实际类型
- `TypeReference<T>` 利用匿名子类保留泛型参数信息（超级类型标记 / Super Type Token）
- 缺失字段使用 `null`（Java 引用类型的默认值）
- Jackson 内部用 `JavaType` 携带完整的泛型参数链
- 不使用 TypeReference 时 `T` 会被反序列化为 `LinkedHashMap`，而非目标类型

**Cangjie json4cj — 编译时约束 + Option 中间变量**

```cangjie
@JsonSerialize
@JsonCreator
class ApiResponse<T> {
    let code: Int64
    let data: T
    public init(code: Int64, data: T) { ... }
}
// 宏自动生成：where T <: JsonValueSerializable<T>
```

核心机制：
- 编译时 `where T <: JsonValueSerializable<T>` 约束确保 `T` 有 `fromJsonValue` / `toJsonValue` 方法
- Cangjie 无零值机制（≠ Go），无 `Default` trait（≠ Rust），无法生成 `T()` 默认值
- **Option<T> 中间变量模式**：用 `Option<T>.None` 作为安全初始值，避免 `T()` 构造函数问题
- 缺失字段时抛出明确错误（对标 serde required field 行为），而非静默使用默认值
- 类似 Rust 的编译时单态化：`ApiResponse<String>` 在编译时生成独立代码

**对比总结表**

| 特性 | Rust serde | Go | Java Jackson | Cangjie json4cj |
|------|-----------|-----|-------------|----------------|
| **类型信息** | 编译时单态化 | 运行时反射+泛型 | TypeToken 擦除补偿 | 编译时 where 约束 |
| **bare `T` 字段** | ✅ 天然支持 | ✅ 零值机制 | ⚠️ 需 TypeReference | ✅ Option 中间变量 |
| **默认值策略** | 不需要(T: Deserialize) | 零值(any) | null(引用类型) | Option\<T\>.None + required 校验 |
| **缺失字段** | 编译时约束/Default | 零值 | null | 明确错误(required field missing) |
| **约束表达** | `where T: Deserialize` | `T any` | TypeReference | `where T <: JsonValueSerializable<T>` |
| **类型安全** | 编译期保证 | 运行时 panic | 运行时 ClassCastException | 编译期保证 |

**设计决策理由**：
1. 选择 Option\<T\> 中间变量而非 `T.fromJsonValue(JsonValue.fromStr("{}"))` — 后者不保证有效（空 JSON 不一定是合法默认值）
2. 选择缺失字段报错而非静默默认值 — 对标 serde 的 required field 行为，避免运行时数据不一致
3. `var data: T`（非 @JsonCreator）暂不支持 — Cangjie 无零值机制，无法生成安全默认值，建议用户使用 `Option<T>` 包装

#### Cangjie 默认值机制调研

在调研 Cangjie 是否有类似 Rust `Default` trait 的机制时，发现以下结果：

**1. `zeroValue<T>()` — unsafe 零初始化（不可用）**

```cangjie
public unsafe func zeroValue<T>(): T
```

- 功能：获取一个已全零初始化的 T 类型实例
- ⚠️ 文档明确警告："通过该函数获取到的实例一定要赋值为正常初始化的值再使用，否则将引发程序崩溃"
- 本质类似 Go 的零值机制，但标记为 `unsafe`，不能作为安全默认值使用
- 仅适用于 Array 初始化等场景，先占位后赋值

**2. `@Derive` 宏 — 不支持 Default**

当前 `std.deriving` 仅支持 4 种接口的自动派生：
- `ToString`
- `Hashable`
- `Equatable`
- `Comparable`

**不支持 `Default`**，且文档明确说明"暂不支持用户自定义的接口"。因此无法用 `@Derive[Default]` 实现类似 Rust 的自动默认值生成。

**3. `@Derive` 的泛型约束机制 — 可借鉴**

`@Derive` 对泛型类型自动推断约束（如 `@Derive[ToString]` 自动添加 `where T <: ToString`），并支持 `where` 覆盖：

```cangjie
// 自动推断约束
@Derive[ToString]
class Cell<T> { ... }
// 等价于：extend<T> Cell<T> <: ToString where T <: ToString { ... }

// 手动覆盖约束
@Derive[ToString where T <: PrintableCellValue]
class Cell<T> { ... }
```

这种 where 约束传播机制与 json4cj 的 `where T <: JsonValueSerializable<T>` 设计一致。

**4. 未来可能性：自定义 Default 接口**

如果 Cangjie 未来支持 `@Derive` 自定义接口，可以设计：

```cangjie
// 假设未来 Cangjie 支持 @Derive 自定义接口
interface Default<T> {
    static func default(): T
}

@Derive[Default]
class ApiResponse<T> {
    let code: Int64 = 0
    let data: T  // 需要 T <: Default<T>
}
```

在当前限制下，json4cj 的 `Option<T>` 中间变量方案是最安全的选择。

**结论**：Cangjie 当前**没有**安全的 Default 机制。`zeroValue<T>()` 是 unsafe 的，`@Derive` 不支持 Default。json4cj 采用 `Option<T>` 中间变量 + required field 校验是当前最优解，对标 serde 的 required field 行为。

---

**6. `@JsonFormat` — 日期/数值格式化** ✅ 已实现

> **已实现**（commit `713ee2f`）：`@JsonFormat["yyyy-MM-dd"]` 宏支持自定义 DateTime 序列化/反序列化格式化模式。

```cangjie
@JsonSerializable
public class Event {
    @JsonFormat["yyyy-MM-dd HH:mm:ss"]
    var startTime: DateTime = DateTime.now()
}
```

---

**7. 错误处理增强**

当前错误信息不包含字段路径。应生成带路径上下文的异常：

```cangjie
// 优化后
throw JsonDeserializeException("Failed to deserialize field 'user.address.city': expected String, got Int64")
```

---

#### P2 — 高级功能

**8. 多态类型（接口/抽象类序列化）**

```cangjie
// serde: #[serde(tag = "type")]
// Jackson: @JsonTypeInfo + @JsonSubTypes

@JsonTypeInfo[property = "type"]
@JsonSubTypes[Dog = "dog", Cat = "cat"]
@JsonSerializable
public interface Animal {
    func speak(): String
}
```

---

**9. 模块系统（全局序列化器注册）**

```cangjie
// Jackson: ObjectMapper.registerModule()
public interface JsonModule {
    func register(registry: JsonRegistry)
}
let mapper = ObjectMapper()
mapper.registerModule(DateTimeModule())
```

---

**10. prop 属性序列化支持**

当前宏只处理 `VarDecl`，应扩展支持 `PropDecl`（只读 prop 仅序列化，不反序列化）。

```cangjie
@JsonSerializable
public class Circle {
    var radius: Float64 = 0.0

    @JsonName["area"]
    public prop area: Float64 {
        get() { 3.14159 * radius * radius }
    }
}
// 序列化时包含计算属性 area
```

---

### 4.3 利用 Cangjie 语言特性的独特优化

以下是 serde/Jackson 都做不到，但 Cangjie 可以做到的：

#### 1. 利用 `extend` 实现开放式类型支持（替代 Jackson Mixin）

Cangjie 的 `extend` 可以为第三方类型添加序列化支持，**无需 Mixin**：

```cangjie
// 比 Jackson Mixin 更简洁，比 serde #[serde(remote)] 更自然
extend ThirdPartyClass <: IJsonValueSerializable<ThirdPartyClass> {
    public func toJsonValue(): JsonValue { ... }
    public static func fromJsonValue(v: JsonValue): ThirdPartyClass { ... }
}
```

**建议**：在文档中推广这种模式，作为 json4cj 的差异化优势。

#### 2. 利用泛型约束 `where` 提供编译时类型检查

```cangjie
// serde 做到了这一点（DeserializeOwned trait bound）
// Jackson 做不到（运行时 Class<T> 参数）
public func readValue<T>(json: String): T where T <: IJsonSerializable<T> {
    return T.fromJson(json)
}
```

#### 3. 利用 `enum` + `match` 实现类型安全的 JSON 路径

```cangjie
// 比 Jackson 的字符串路径 "/users/0/name" 更安全
enum JsonPath {
    | Field(String)
    | Index(Int64)
    | Nested(String, JsonPath)
}
```

#### 4. 利用 `prop` 属性支持计算属性序列化

只读 `prop` 仅序列化，不反序列化 — 这在 Jackson/serde 中都需要额外注解。

---

### 4.4 优先级总结

| 优先级 | 改进项 | 类型 | 难度 | 价值 | 状态 |
|--------|--------|------|------|------|------|
| **P0** | 修复 GlobalConfig 全局状态问题 | 优化 | 低 | 正确性 | ✅ 已修复 |
| **P0** | 补全 UInt 系列类型扩展 | 补充 | 低 | 完整性 | ✅ 已修复 |
| **P0** | `@JsonIgnoreUnknown` 未知字段处理 | 补充 | 中 | 兼容性 | ✅ 已实现 |
| **P0** | `@JsonInclude` 包含控制 | 补充 | 中 | 实用性 | ✅ 已实现 |
| **P1** | 生成 stdx `JsonSerializable` 流式实现 | 优化 | 中 | 性能 | ✅ 已实现 |
| **P1** | 改进 Option 错误处理（不静默吞错） | 优化 | 低 | 正确性 | ✅ 已修复 |
| **P1** | enum 类型序列化 | 补充 | 高 | 完整性 | ✅ 简单+有参枚举已实现 |
| **P1** | 构造函数反序列化（let 不可变） | 补充 | 高 | 设计 | ✅ 已实现 |
| **P1** | `@JsonFormat` 日期格式化 | 补充 | 中 | 实用性 | ✅ 已实现 |
| **P2** | 泛型类序列化（含 bare type param + @JsonCreator） | 补充 | 高 | 通用性 | ✅ 已实现 |
| **P2** | 泛型类 Stream 序列化 | 补充 | 中 | 完整性 | ⚠️ 受 cjc 约束传播限制（所有泛型类，非仅 Option） |
| **P2** | Stream 反序列化 Rust-like Option<T> 重构 | 优化 | 高 | 正确性 | ✅ 已实现 |
| **P2** | 错误处理增强（JSON Path 传播） | 优化 | 中 | 正确性 | ✅ 已实现（10 个测试用例） |
| **P2** | cjc 约束传播 bug 验证 + JsonValue 桥接测试 | 验证 | 中 | 正确性 | ✅ 已验证 |
| **P2** | ~~泛型类 bare type param @JsonCreator 验证~~ | 验证 | - | - | ❌ 已取消（不需要） |
| **P2** | prop 属性序列化 | 补充 | 中 | 灵活性 | ❌ |
| **P2** | 多态类型（内部标签） | 补充 | 高 | 企业级 | ✅ 已完成（`ac45a8d`，12 测试用例） |
| **P2** | ObjectMapper + 模块系统 | 补充 | 高 | 架构 | ❌ |

---

## 5. 命名规范设计

遵循 **Cangjie 规范**（G.NAM.03: 类/接口/枚举用 PascalCase，G.NAM.04: 函数用 camelCase），同时**借鉴 Jackson 命名惯例**，降低 Java 开发者的迁移成本。

### 5.1 核心原则

| 原则 | 说明 |
|------|------|
| 遵循 Cangjie 规范 | PascalCase 类名、camelCase 方法名、SCREAMING_SNAKE_CASE 常量 |
| 借鉴 Jackson 前缀 `Json` | 注解/类统一使用 `Json` 前缀，与 Jackson `@JsonXxx` 保持一致 |
| 接口不用 `I` 前缀 | Cangjie 规范推荐 PascalCase，不使用匈牙利命名 |
| 宏名与接口名不同 | 避免宏展开时名称歧义：宏用 `@JsonSerialize`，接口用 `JsonSerializable<T>` |
| 语义清晰 > 缩写简短 | `JsonSerializable` 而非 `JsonSer`，`JsonIgnoreUnknown` 而非 `JsonIU` |

### 5.2 宏符号引用约束（重要）

Cangjie 宏 `quote()` 生成的代码在**调用方上下文**中展开，编译器无法解析跨包的完全限定名（FQN）。

此外，宏名与接口名不可相同，否则宏展开代码中的短名称会解析为宏而非接口。因此宏 `@JsonSerialize` 与接口 `JsonSerializable<T>` 使用不同名称。

```cangjie
// ❌ 以下方式均不可行（cjc 1.1.0 实测）
// 1. 直接文本 FQN
quote(public func toJsonValue(): stdx.encoding.json.JsonObject { ... })
//   → error: undeclared type name 'stdx'

// 2. Token 序列构建 FQN
let tkn = fqn("stdx.encoding.json.JsonObject")  // IDENT + DOT + IDENT + ...
quote(public func toJsonValue(): $tkn { ... })
//   → error: undeclared type name 'stdx'（输出正确但编译器不识别）

// 3. 宏名与接口名相同
macro JsonSerializable(...)  // 宏
interface JsonSerializable<T>  // 接口
// → 宏展开代码中 JsonSerializable<T> 被解析为宏而非接口
// → error: 'JsonSerializable' is not a type
```

**因此，宏生成的代码必须使用短名称（如 `JsonObject`），调用方必须导入对应包。宏名与接口名必须不同。**

这是当前的设计约束：

```cangjie
// 宏生成代码中的短名称
return quote(
    public func toJsonValue(): JsonObject {      // ← 短名称
        var map: HashMap<String, JsonValue> = HashMap()  // ← 短名称
        ...
        return JsonObject(map)
    }
)

// 调用方必须导入这些包
internal import stdx.encoding.json.{JsonValue, JsonObject, JsonNull}
import std.collection.{HashMap}
```

> 若未来 Cangjie 编译器支持宏内 FQN 解析，可移除此约束，届时用户将不再需要手动导入 stdx 包。

### 5.3 注解（宏）命名对照

| Jackson 注解 | json4cj 当前 | 说明 |
|-------------|-------------|------|
| `@JsonSerialize` + `@JsonDeserialize` | **`@JsonSerialize`** | 一个宏同时生成序列化+反序列化，与 Jackson @JsonSerialize 对齐 |
| `@JsonProperty("name")` | **`@JsonProperty["name"]`** | 与 Jackson 完全一致，降低迁移成本 |
| `@JsonIgnore` | **`@JsonIgnore`** | 已与 Jackson 一致 |
| `@JsonDeserialize(using=...)` | **`@JsonDeserialize[XxxSerializer]`** | 借鉴 Jackson 命名，语义清晰 |
| `@JsonIgnoreProperties(ignoreUnknown)` | **`@JsonIgnoreUnknown[true/false]`** | ✅ 已实现；简化 Jackson 的长命名 |
| `@JsonInclude(NON_NULL)` | **`@JsonInclude[NON_NULL]`** | ✅ 已实现；与 Jackson 一致 |
| `@JsonCreator` | **`@JsonCreator`** | ✅ 已实现；与 Jackson 一致 |
| `@JsonFormat(pattern=...)` | **`@JsonFormat["yyyy-MM-dd"]`** | ✅ 已实现；与 Jackson 一致 |
| `@JsonTypeInfo` | **`@JsonTypeInfo[property="type"]`** *(待新增)* | 与 Jackson 一致 |
| `@JsonSubTypes` | **`@JsonSubTypes[...]`** *(待新增)* | 与 Jackson 一致 |
| `@JsonView` | **`@JsonView[...]`** *(待新增)* | 与 Jackson 一致 |

### 5.4 接口与类命名对照

| Jackson 类型 | json4cj 当前 | 说明 |
|-------------|-------------|------|
| `Serializer<T>` | — | **`JsonSerializer<T>`** *(待新增)* 自定义序列化器接口 |
| `Deserializer<T>` | — | **`JsonDeserializer<T>`** *(待新增)* 自定义反序列化器接口 |
| — | **`JsonSerializable<T>`** | 去掉 `I` 前缀，遵循 Cangjie 规范 |
| — | **`JsonValueSerializable<T>`** | 去掉 `I` 前缀 |
| `ObjectMapper` | — | **`ObjectMapper`** *(待新增)* 与 Jackson 完全一致 |
| `JsonNode` | — | **`JsonNode`** *(待新增)* 封装 stdx `JsonValue` |
| `JsonModule` | — | **`JsonModule`** *(待新增)* 与 Jackson 一致 |
| `JsonMappingException` | — | **`JsonMappingException`** *(待新增)* 与 Jackson 一致 |

### 5.5 方法命名对照

| Jackson 方法 | json4cj 当前 | json4cj 建议 | 说明 |
|-------------|-------------|-------------|------|
| `mapper.writeValueAsString(obj)` | `obj.toJson()` | **保留 `toJson()`**，新增 `mapper.writeValueAsString()` | 两种 API 并存 |
| `mapper.readValue(json, T.class)` | `T.fromJson(json)` | **保留 `fromJson()`**，新增 `mapper.readValue<T>()` | 两种 API 并存 |
| `mapper.readTree(json)` | — | **`mapper.readTree(json)`** | 新增，与 Jackson 一致 |
| `mapper.configure(feature, val)` | — | **`mapper.configure(feature, val)`** | 新增，与 Jackson 一致 |
| `mapper.registerModule(module)` | — | **`mapper.registerModule(module)`** | 新增，与 Jackson 一致 |
| `node.asString()` | — | `node.asString()` | stdx JsonValue 已有 |
| `serialize(writer)` | — | **`serialize(writer: JsonWriter)`** | 新增，流式序列化方法 |

### 5.6 枚举/常量命名

| Jackson 常量 | json4cj 建议 | 说明 |
|-------------|-------------|------|
| `Include.NON_NULL` | **`JsonIncludeMode.NON_NULL`** | enum PascalCase + 成员 SCREAMING_SNAKE |
| `Include.NON_EMPTY` | **`JsonIncludeMode.NON_EMPTY`** | |
| `Include.NON_DEFAULT` | **`JsonIncludeMode.NON_DEFAULT`** | |
| `Include.ALWAYS` | **`JsonIncludeMode.ALWAYS`** | |
| `DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES` | **`JsonFeature.FAIL_ON_UNKNOWN`** | 简化 Jackson 过长命名 |
| `SerializationFeature.INDENT_OUTPUT` | **`JsonFeature.INDENT_OUTPUT`** | |

### 5.7 自定义序列化器命名约定

```cangjie
// 当前命名（已对齐 Jackson XxxSerializer/XxxDeserializer 惯例）
class Int64JsonSerializer <: JsonValueSerializable<Int64> { ... }
class DateTimeJsonSerializer <: JsonValueSerializable<DateTime> { ... }

// 用法：与 Jackson 一致 
@JsonDeserialize[DateTimeJsonSerializer]
var birthday: DateTime = DateTime.now()
```

### 5.8 包结构（当前）

```
json4cj/
  src/
    ├─ json_serializable.cj         # json4cj 根包：JsonSerializable<T>、JsonValueSerializable<T> 接口及内置类型扩展
    ├─ jsonmacro/                   # json4cj.jsonmacro 包：全部宏实现
    │   ├─ json_serialize.cj        # @JsonSerialize（主宏，触发代码生成）
    │   ├─ json_property.cj         # @JsonProperty（字段别名映射）
    │   ├─ json_ignore.cj           # @JsonIgnore（跳过序列化字段）
    │   ├─ json_deserialize.cj      # @JsonDeserialize（自定义序列化器注入）
    │   ├─ class_json_serializer.cj    # 序列化 token 生成（toJsonValue/toJson）
    │   ├─ class_json_deserializer.cj  # 反序列化 token 生成（fromJson/fromJsonValue）
    │   └─ ...                      # 辅助类：ClassProcessor、ClassVarDeclVisitor、GlobalConfig 等
    └─ test/                        # json4cj.test 包：单元测试
```

> 随功能增长，可按职责从 `json4cj.jsonmacro` 中拆分出 `json4cj.mapper`（ObjectMapper）等子包。

### 5.9 cjlint 合规状态

当前 `cjpm bundle` 已通过（无 MANDATORY 错误），剩余 WARNING 分类如下：

| 规则 | 数量 | 原因 | 是否可消除 |
|------|------|------|------------|
| G.ITF.02 extend 实现接口 | ~15 | 对 std 类型（Int64, String 等）extend 实现接口是 json4cj 核心设计 | ❌ 不可消除 |
| G.NAM.01 包名与目录不一致 | ~11 | `test` 目录 → `json4cj.test` 包名；Cangjie 允许但 lint 建议一致 | ❌ 目录结构约束 |
| G.PKG.01 通配符导入 | ~2 | `import std.convert.*` 因 Int16/Int8 等为内部类型，无法单独导入 | ❌ 编译器限制 |

---

## 6. 推荐架构设计

### 6.1 三层架构

```
┌─────────────────────────────────────────────────────────┐
│                    应用层（json4cj）                       │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐ │
│  │ @JsonXXX    │  │ ObjectMapper │  │ JsonModule     │ │
│  │ 注解驱动    │  │ 全局配置     │  │ 模块系统       │ │
│  └─────────────┘  └──────────────┘  └────────────────┘ │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│              基础设施层（stdx.encoding.json）              │
│  ┌─────────────────┐  ┌──────────────────────────────┐ │
│  │ 数据层           │  │ 流式层                        │ │
│  │ JsonValue       │  │ JsonWriter / JsonReader      │ │
│  │ JsonObject      │  │ JsonSerializable             │ │
│  │ JsonArray       │  │ JsonDeserializable           │ │
│  └─────────────────┘  └──────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│                    编译器（cjc）                          │
│  宏展开 → 代码生成 → 编译优化                            │
└─────────────────────────────────────────────────────────┘
```

### 6.2 核心 API 设计

#### 保留现有便捷 API

```cangjie
@JsonSerialize
class User {
    var name: String = ""
    var age: Int64 = 0
}

// 仍然有效
user.toJson()
User.fromJson(json)
```

#### 新增 ObjectMapper（参考 Jackson）

```cangjie
let mapper = ObjectMapper()
mapper.configure(Feature.IGNORE_UNKNOWN, true)
mapper.configure(Feature.INCLUDE_NULL, false)

let json = mapper.writeValueAsString(user)
let user = mapper.readValue<User>(json)
```

#### 增强注解系统（参考 serde + Jackson）

```cangjie
@JsonSerialize
@JsonInclude[NON_NULL]
class User {
    @JsonProperty["user_name"]
    var name: String = ""

    @JsonIgnore
    var internalCache: String = ""

    @JsonDeserialize[DateTimeJsonSerializer]
    var birthday: DateTime = DateTime.now()
}
```

### 6.3 宏生成策略优化

#### 当前策略

```
@JsonSerialize → 生成 toJson() / fromJson()
  → 使用 JsonSerializable 接口
  → HashMap 中间层拼装
```

#### 优化后策略

```
@JsonSerialize → 生成两套实现：
  1. toJsonValue() / fromJsonValue() — 兼容现有 API
  2. stdx JsonSerializable 接口 — 流式写入，高性能

ObjectMapper.writeValueAsString(obj)
  → 调用 obj.serialize(JsonWriter)  // 流式，零中间分配

ObjectMapper.readValue<T>(json)
  → JsonReader → T.deserialize(JsonReader)  // 流式，高性能
```

### 6.4 与 stdx 的边界

**json4cj 不应该做的**：
- ❌ 重新实现 JSON 解析器（stdx 已有）
- ❌ 重新实现 JsonWriter/JsonReader（stdx 已有）
- ❌ 重新实现 Tree Model（stdx 已有 JsonValue）

**json4cj 应该做的**：
- ✅ 注解驱动的自动代码生成
- ✅ ObjectMapper 全局配置
- ✅ 模块系统
- ✅ 多态类型处理
- ✅ 高级特性（enum、泛型类、prop）

### 6.5 json4cj 的独特优势

1. **编译时宏 + 运行时灵活性的混合**
   - 宏生成代码保证零开销
   - ObjectMapper 提供全局配置灵活性

2. **Cangjie extend 替代 Mixin**
   - 比 Jackson Mixin 更简洁
   - 比 serde `#[serde(remote)]` 更自然

3. **Cangjie 语言特性**
   - `Option<T>` 原生支持
   - `enum` 代数类型（类似 Rust）
   - 泛型约束 `where` 编译时检查
   - `prop` 计算属性序列化

---

### 6.5 Stream 流式序列化架构（Phase 2 已实现）

`@JsonSerialize` 宏为每个类同时生成两套序列化/反序列化实现：

#### 生成的代码结构

```cangjie
@JsonSerialize
class User {
    public var name: String = ""
    public var age: Int64 = 0
}

// 宏展开后生成：

// 1. HashMap 体系（原有，类内部）
class User <: JsonCodec<User> {
    public var name: String = ""
    public var age: Int64 = 0

    public static func fromJsonValue(value: JsonValue): User { ... }
    public func toJsonValue(): JsonValue { ... }
    public static func fromJson(json: String): User { ... }
    public func toJson(): String { ... }
}

// 2. Stream 体系（新增，extend 块）
extend User <: JsonSerializable {
    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("name").writeValue<String>(this.name)
        w.writeName("age").writeValue<Int64>(this.age)
        w.endObject()
    }
}
extend User <: JsonDeserializable<User> {
    public static func fromJson(r: JsonReader): User {
        r.startObject()
        var _name: String = ""
        var _age: Int64 = 0
        while (let Some(token) <- r.peek()) {
            if (token == EndObject) { break }
            match (r.readName()) {
                case "name" => _name = r.readValue<String>()
                case "age" => _age = r.readValue<Int64>()
                case _ => r.skip()
            }
        }
        r.endObject()
        var obj = User()
        obj.name = _name
        obj.age = _age
        return obj
    }
}
```

#### JsonValue 桥接模式

对于 stdx stream API 约束传播不支持的字段类型，使用 JsonValue 桥接：

**问题**：`writeValue<T>()` 要求 `T <: JsonSerializable`，但 cjc 1.0.1 无法传播 `HashSet<T> <: JsonSerializable` 的泛型约束（即使 `T <: JsonSerializable` 已满足）。

**验证结果**：

| 类型 | `writeValue<T>()` | 结果 |
|------|-------------------|------|
| `Int64` / `String` / `Bool` | `writeValue<Int64>()` | ✅ 通过 |
| `ArrayList<Int64>` | `writeValue<ArrayList<Int64>>()` | ✅ 通过 |
| `HashSet<Int64>` | `writeValue<HashSet<Int64>>()` | ❌ 失败 |
| `HashMap<String, Int64>` | `writeValue<HashMap<String, Int64>>()` | ❌ 失败 |
| 用户自定义类型 | `writeValue<CustomType>()` | ❌ 失败 |

**桥接方案**：

```
序列化直接路径（HashSet 不可用）:
  this.field  →  writeValue<T>(field)  →  JsonWriter

序列化桥接路径（绕过约束）:
  this.field  →  .toJsonValue()  →  .toString()  →  w.jsonValue(str)  →  JsonWriter

反序列化直接路径（HashSet 不可用）:
  JsonReader  →  readValue<T>()  →  T

反序列化桥接路径（绕过约束）:
  JsonReader  →  .readValueBytes()  →  String  →  JsonValue  →  T.fromJsonValue()  →  T
```

**桥接代码示例**：

```cangjie
// 序列化：JsonValue 桥接
w.writeName("int64Set").jsonValue(this.int64Set.toJsonValue().toString())

// 反序列化：JsonValue 桥接
_int64Set = HashSet<Int64>.fromJsonValue(
    JsonValue.fromStr(String.fromUtf8(r.readValueBytes()))
)
```

#### 接口命名：JsonCodec vs JsonSerializable

`json4cj.JsonSerializable<T>` 已重命名为 `json4cj.JsonCodec<T>`，原因是与 `stdx.encoding.json.stream.JsonSerializable` 命名冲突：

- `JsonCodec<T>`：HashMap 体系的序列化接口（`toJson()` / `fromJson()`）
- `JsonSerializable`：stdx stream 体系的序列化接口（`toJson(w: JsonWriter)`）
- `JsonDeserializable<T>`：stdx stream 体系的反序列化接口（`static fromJson(r: JsonReader): T`）

#### FieldConfig 两阶段代码生成

Stream 生成器与 HashMap 生成器共享 `FieldConfig` 基础设施：

1. **Phase 1（配置提取）**：`FieldConfigBuilder` 分析字段注解和类型，生成 `FieldConfig` 列表
2. **Phase 2（代码发射）**：4 个生成器（HashMap 序列化/反序列化 + Stream 序列化/反序列化）各自根据 `FieldConfig.category` 选择代码模板

```
VarDecl + GlobalConfig
       ↓
 FieldConfigBuilder.build()
       ↓
 ArrayList<FieldConfig>
       ↓
 ┌─────────────────────────────────────────────┐
 │ ClassJsonSerializer    → makeToJsonFunc()    │
 │ ClassJsonDeserializer  → makeFromJsonFunc()  │
 │ ClassStreamSerializer  → makeStreamToJsonExtend()   │
 │ ClassStreamDeserializer → makeStreamFromJsonExtend() │
 └─────────────────────────────────────────────┘
```

---

## 7. 演进路线

### Phase 1: 核心对齐 + 代码质量 ✅ 已完成

**目标**：修复设计问题，补齐最常用功能

| # | 任务 | 工期 | 说明 | 状态 |
|---|------|------|------|------|
| 1 | 修复 GlobalConfig 全局状态 | 0.5 天 | 改为局部变量传递 | ✅ `3f70696` |
| 2 | 补全 UInt 类型扩展 | 0.5 天 | UInt8/16/32/64 | ✅ `e14c6ab` |
| 3 | 改进 Option 错误处理 | 1 天 | 区分"不存在"和"格式错误" | ✅ `904f5b3` |
| 4 | `@JsonIgnoreUnknown` | 1 天 | 含严格模式，聚合未知字段异常 | ✅ `d343f1c` → `7b696ad` |
| 5 | `@JsonInclude` | 2 天 | NON_NULL / NON_EMPTY 控制 | ✅ `211f90d` |
| 6 | `@JsonFormat` 日期格式化 | 2 天 | 自定义 DateTime 格式化模式 | ✅ `713ee2f` |
| 7 | 构造函数反序列化 | 3 天 | `@JsonCreator` + let 支持 | ✅ `87a1b6d` |

### Phase 2: 高级特性（3-4 周）

**目标**：支持企业级场景，发挥 Cangjie 语言优势

| # | 任务 | 工期 | 说明 |
|---|------|------|------|
| 8 | ~~enum 类型序列化~~ | 4 天 | ✅ 简单枚举已完成（`EnumProcessor`）；✅ 有参枚举 serde externally-tagged 已完成 |
| 9 | ~~stdx JsonWriter 流式生成~~ | 3 天 | ✅ 已完成；宏生成 extend <: JsonSerializable + extend <: JsonDeserializable；HashSet/HashMap 使用 JsonValue 桥接 |
| ~~10~~ | ~~错误处理增强~~ | ~~2 天~~ | ✅ 已完成；JSON Path 传播 + 10 个测试用例 |
| 11 | ObjectMapper 基础 API | 3 天 | 全局配置入口 |
| 12 | 模块系统 | 3 天 | JsonModule trait |
| 13 | prop 属性序列化 | 2 天 | 只读 prop 支持 |

### Phase 3: 生态系统（4-6 周）

**目标**：完善生态，成为仓颉 JSON 标准

| # | 任务 | 工期 | 说明 | 状态 |
|---|------|------|------|------|
| 14 | **多态类型（serde 对齐）** | 5 天 | `@JsonTypeInfo[tag="type"]` + `@JsonSubTypes`，支持内部标签/外部标签/相邻标签/无标签 4 种策略 | ✅ 内部标签已完成，3 种策略待实现 |
| 15 | ~~泛型类序列化~~ | 4 天 | ✅ 完成（含 bare type param + @JsonCreator） | ✅ |
| 16 | JSON Schema 生成 | 4 天 | 类型 → Schema 转换 | ❌ |
| 17 | HTTP 库集成 | 4 天 | 与 stdx HTTP 自动 JSON 处理 | ❌ |
| 18 | 验证框架 | 3 天 | @JsonRequired, @JsonNotNull | ❌ |

#### 多态类型详细设计（serde 对齐）

**✅ 策略 1: 内部标签（Internal Tagging）- 已完成**
```cangjie
@JsonTypeInfo[tag = "type"]
@JsonSubTypes[["dog" => Dog, "cat" => Cat]]
@JsonSerialize
class Animal {
    var name: String = ""
}

class Dog : Animal {
    var breed: String = ""
}
// JSON: {"type": "dog", "name": "Buddy", "breed": "Labrador"}
```

**实现细节**：
- `PolymorphicProcessor` 生成完整的序列化/反序列化代码
- 基类：`open func toJsonValue()` 支持动态分派，`fromJsonValue()` 根据 type 字段分发
- 子类：`@JsonType["dog"]` 指定鉴别值，自动注入 type 字段
- 支持 `ArrayList<BaseType>` 多态集合
- 12 个测试用例覆盖所有关键场景（commit `ac45a8d`）

**⏳ 策略 2: 外部标签（External Tagging）- enum 专用，待实现**
```cangjie
@JsonTaggedEnum[external]  // 默认
@JsonSerialize
enum Animal {
    | Dog(String, Int64)
    | Cat(Int64)
}
// JSON: {"Dog": ["Buddy", 5]} 或 {"Cat": 9}
```

**策略 3: 相邻标签（Adjacent Tagging）**
```cangjie
@JsonTypeInfo[tag = "type", content = "data"]
@JsonSerialize
class Animal { ... }
// JSON: {"type": "dog", "data": {"name": "Buddy"}}
```

**策略 4: 无标签（Untagged）- 按顺序尝试**
```cangjie
@JsonTypeInfo[untagged]
@JsonSerialize
class Animal { ... }
// JSON: {"name": "Buddy", "breed": "Labrador"} （推断为 Dog）
```

**实现要点**：
1. 编译期生成 match 分支（零运行时开销）
2. 子类型自动注册（不需要手动映射）
3. 错误信息包含未知类型值
4. 支持与泛型类组合（如 `ApiResponse<Animal>`）

---

### 2.5 Cangjie 语言限制评估（2026-04-10）

在尝试实现 serde 对齐的多态序列化时，最初发现了 **Cangjie 1.0.1 的两个关键限制**。但经过深入实测（2026年4月），**两个限制均不成立**，类继承多态方案可行。

#### ~~限制 1：泛型不变性（Generic Invariance）~~ ✅ 实测可行

**~~问题~~**：~~`ArrayList<Animal>` 不能接受 `Dog` 或 `Cat`，即使 `Dog <: Animal`~~

> **实测结论（2026-04）**：Cangjie **支持隐式向上转型（upcast）**，`ArrayList<GeoShape>` 可以添加 `GeoCircle` 和 `GeoRect` 实例。`is` 类型检查和 `as` 下转型（返回 `Option<T>`）均正常工作。

```cangjie
open class GeoShape { ... }
class GeoCircle <: GeoShape { ... }
class GeoRect <: GeoShape { ... }

let shapes = ArrayList<GeoShape>()
shapes.add(GeoCircle())  // ✅ 隐式 upcast
shapes.add(GeoRect())    // ✅ 隐式 upcast

@Assert(shapes[0] is GeoCircle, true)  // ✅ 类型检查
let c = (shapes[0] as GeoCircle).getOrThrow()  // ✅ 下转型（返回 Option<T>）
```

**实测通过的测试用例**：
- `testArrayListOfBaseType` ✅
- `testArrayListSerializationDynamicDispatch` ✅  
- `testMixedArrayListRoundTrip` ✅

---

#### ~~限制 2：不支持协变返回类型（No Covariant Return Types）~~ ✅ 实测可行

> **实测结论（2026-04）**：Cangjie **支持协变返回类型（隐式 upcast）**。函数声明返回 `Animal`，可以直接 `return Dog()` 无需任何转型语法。

```cangjie
open class Animal { ... }
class Dog <: Animal { ... }

public static func fromJsonValue(json: JsonValue): Animal {
    let typeStr = extractType(json)
    if (typeStr == "dog") {
        return Dog.fromJsonValue(json, path)  // ✅ 直接返回子类实例
    } else {
        return Cat.fromJsonValue(json, path)  // ✅ if-else 返回不同子类
    }
}
```

**关键发现**：
- ✅ `return Dog()` 在返回 `Animal` 的函数中可行（隐式 upcast）
- ✅ `if-else` 返回不同子类实例可行
- ✅ 动态分派有效：`shape.toJsonValue()` 正确调用子类的实现（需要 `open` 修饰）
- ✅ `is` 类型检查有效：`shape is GeoCircle`
- ⚠️ `as` 下转型返回 `Option<T>`：`(shape as GeoCircle).getOrThrow()`
- ⚠️ 基类必须标记 `open`，需要重写的方法必须标记 `open`

```cangjie
func fromJson(json: String): Animal {
    if (type == "dog") {
        return Dog.fromJson(json)  // ❌ 错误：expected 'Class-Animal', found 'Class-Dog'
    }
}
```

**影响**：
- ❌ 无法在基类的 `fromJson` 中 dispatch 到子类
- ❌ 多态反序列化的核心机制受阻
- ❌ serde 的 `deserialize` 返回 `Result<T>` 模式无法直接实现

**Java Jackson 对比**：
```java
// Java 支持协变返回
public Animal deserialize(...) {
    if (type.equals("dog")) {
        return objectMapper.readValue(json, Dog.class);  // ✅ 可行
    }
}
```

**Workaround**：
- 使用 enum 包装所有变体（推荐）
- 使用 `Option<Dog> | Option<Cat>` 联合类型

---

#### 可行方案：Enum-based 多态（推荐）

基于以上限制，**推荐采用 enum 代数数据类型实现多态**，而非类继承：

```cangjie
@JsonSerialize
enum Animal {
    | Dog(String name, String breed)
    | Cat(String name, Int64 lives)
}

// JSON: {"Dog": ["Buddy", "Labrador"]} 或 {"Cat": ["Whiskers", 7]}

// 使用
let animal = Animal.fromJson("""{"Dog":["Buddy","Labrador"]}""")
match (animal) {
    case Animal.Dog(name, breed) => println("Dog: " + name)
    case Animal.Cat(name, lives) => println("Cat: " + name)
}
```

**优势**：
- ✅ 完全支持（已实现有参枚举序列化）
- ✅ 编译期类型安全
- ✅ 模式匹配穷尽检查
- ✅ 零运行时开销

**劣势**：
- ⚠️ 需要预先知道所有变体（不开放）
- ⚠️ 无法在运行时添加新变体

---

#### 结论（2026-04 修正）

| 方案 | 可行性 | 说明 |
|------|------|------|
| 类继承 + `@JsonTypeInfo`（内部标签） | ✅ **已完成** | 泛型集合支持 + 协变返回 + 动态分派均验证通过，12 个测试用例 |
| 类继承 + `@JsonTypeInfo`（外部/相邻/无标签） | ⏳ **待实现** | 预计 3 天工作量 |
| Enum 代数数据类型 | ✅ 完全可行 | 已有支持，适合封闭类型 |
| Interface + manual dispatch | ⚠️ 部分可行 | 需要大量手动代码 |

**建议**：将 `@JsonTypeInfo` + 类继承方案**升级为 P2（近期目标）**，与 enum 方案并行支持。

**实现注意事项**：
1. 基类必须 `open`，`toJsonValue()` 必须 `open`
2. `as` 下转型返回 `Option<T>`，宏生成代码需用 `.getOrThrow()`
3. 基类 `fromJsonValue` 中的 dispatch 代码需引用子类类型（宏需处理前向引用）
4. `case Some(JsonString(s))` 不可用，需用 `case Some(v) => (v as JsonString).getOrThrow().getValue()`

### 工作量总结

| 阶段 | 范围 | 预计工作量 | 说明 |
|------|------|-----------|------|
| Phase 1 | 7 项（修复 + 核心） | 2-3 周 | ✅ 已完成；修复设计问题 + 补齐常用功能 |
| Phase 2 | 6 项（高级特性） | 3-4 周 | enum、流式、ObjectMapper |
| Phase 3 | 5 项（生态） | 4-6 周 | 多态、泛型类、Schema、HTTP |
| **总计** | **18 项** | **2-3 个月** | 复用 stdx 可减少 30% 工作量 |

---

## 8. 实施建议

### 8.1 宏架构调整

```
jsonmacro/
├── json_serialize.cj          # 现有（已优化：局部 Config）
├── json_property.cj           # 现有
├── json_ignore.cj             # 现有
├── json_deserialize.cj        # 现有
├── json_include.cj            # ✅ 已实现 (P0)
├── json_ignore_unknown.cj     # ✅ 已实现 (P0)
├── json_creator.cj            # ✅ 已实现 (P1)
├── json_format.cj             # ✅ 已实现 (P1)
├── json_type_info.cj          # ✅ 已实现 (P3-14a, 内部标签)
├── json_sub_types.cj          # ✅ 已实现 (P3-14a, 子类型映射)
├── json_type.cj               # ✅ 已实现 (P3-14a, 子类鉴别值)
├── polymorphic_processor.cj   # ✅ 已实现 (P3-14a, 多态代码生成)
├── JsonTypeInfo.cj            # 待实现 (外部/相邻/无标签策略)
├── enum_processor.cj          # ✅ 已实现 (简单+有参枚举序列化，serde externally-tagged)
└── StreamSerializer.cj        # ✅ 已实现 (class_stream_serializer.cj / class_stream_deserializer.cj)

# 非宏文件
ObjectMapper.cj                # 新增 (P1)
JsonModule.cj                  # 新增 (P1)
JsonException.cj               # 新增 (P1)
```

### 8.2 技术可行性

**优势**：
- ✅ 编译时代码生成，零运行时开销
- ✅ 已有宏基础设施（AST 访问、Token 生成）
- ✅ Cangjie enum 类似 Rust enum，可借鉴 serde 模式
- ✅ stdx 提供 Tree Model 和 Streaming API

**挑战**：
- ⚠️ 多态类型需要运行时类型注册
- ⚠️ 泛型类序列化需要处理类型参数和 where 约束
- ⚠️ ObjectMapper 需要设计配置继承链

### 8.3 与 stdx 的边界

**集成策略**：
1. json4cj 宏生成代码使用 `JsonWriter` / `JsonReader`
2. ObjectMapper 封装 `JsonValue.fromStr()` 提供便捷 API
3. 自定义序列化器实现 stdx 的 `JsonSerializable` / `JsonDeserializable` 接口
4. 推广 `extend` 模式替代 Jackson Mixin

---

## 总结

### 核心结论

json4cj 的**宏生成架构是正确的**（对标 serde），但需要：

1. **修复**：GlobalConfig 并行安全、Option 错误处理精度 ✅ 已完成
2. **补全**：~~类型覆盖（UInt/enum）~~ UInt ✅、简单 enum ✅、有参 enum ✅（serde externally-tagged）、常用注解 ✅、多态类型（内部标签）✅
3. **发挥 Cangjie 优势**：extend 替代 Mixin、enum 序列化、泛型约束编译时检查、prop 属性

### 最优设计原则

1. **编译时优先**：宏生成代码，零运行时开销（已实现）
2. **运行时可选**：ObjectMapper 提供灵活配置（需新增）
3. **分层清晰**：stdx 提供底层，json4cj 提供高层抽象（已对齐）
4. **渐进增强**：零注解也能工作 → 注解增强 → 自定义扩展（需改进）
5. **生态兼容**：与 stdx 无缝集成，避免重复造轮子（需对齐）

### 最终目标

让 json4cj 成为：
- **对新手**：`@JsonSerialize` 一键序列化（当前已实现）
- **对进阶用户**：ObjectMapper 全局配置，enum 支持，多态类型（需新增 ObjectMapper）
- **对企业场景**：多态（外部/相邻/无标签）、模块系统、验证（多态内部标签已完成）
- **对性能敏感**：零运行时开销，stdx 流式 API（需对齐）

**成为仓颉语言生态中"默认选择"的 JSON 库**，就像 serde 之于 Rust，Jackson 之于 Java。

---

## 参考

- Jackson 官方文档：https://github.com/FasterXML/jackson-docs
- Rust serde 文档：https://serde.rs/
- json4cj 源代码：`src/jsonmacro/`
- stdx JSON 文档：`.qoder/skills/cangjie-stdx/json/README.md`
