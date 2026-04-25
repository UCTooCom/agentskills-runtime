# json4cj 开发踩坑记录

本文档记录了 json4cj 开发过程中遇到的所有编译错误、设计问题和解决方案，供后续开发和社区参考。

---

## 目录

- [1. 仓颉宏编程踩坑](#1-仓颉宏编程踩坑)
  - [1.1 quote() 中插值类型名变为字符串字面量](#11-quote-中插值类型名变为字符串字面量)
  - [1.2 宏属性必须使用方括号 [] 而非圆括号 ()](#12-宏属性必须使用方括号--而非圆括号-)
  - [1.3 quote() 插值语法是 $varName 而非 ${varName}](#13-quote-插值语法是-varname-而非-varname)
  - [1.4 GlobalConfig 全局可变状态导致并行宏展开不安全](#14-globalconfig-全局可变状态导致并行宏展开不安全)
- [2. 仓颉语言 API 踩坑](#2-仓颉语言-api-踩坑)
  - [2.1 isEmpty 是方法调用而非属性访问](#21-isempty-是方法调用而非属性访问)
  - [2.2 DateTime 格式化 API](#22-datetime-格式化-api)
  - [2.3 JsonObject.getFields() 返回元组需解构](#23-jsonobjectgetfields-返回元组需解构)
- [3. 测试相关踩坑](#3-测试相关踩坑)
  - [3.1 JSON 测试比较不能直接用 JsonValue.fromStr()](#31-json-测试比较不能直接用-jsonvaluefromstr)
  - [3.2 三引号字符串中的双引号不需要转义](#32-三引号字符串中的双引号不需要转义)
  - [3.3 严格模式应收集所有未知字段后统一抛出异常](#33-严格模式应收集所有未知字段后统一抛出异常)
- [4. 设计决策记录](#4-设计决策记录)
  - [4.1 JSON Path 异常信息功能推迟到 Phase 2](#41-json-path-异常信息功能推迟到-phase-2)
- [5. Phase 2 Stream 集成踩坑](#5-phase-2-stream-集成踩坑)
  - [5.1 JsonSerializable 命名冲突](#51-jsonserializable-命名冲突)
  - [5.2 cjc 1.0.1 泛型约束传播失败](#52-cjc-101-泛型约束传播失败)
  - [5.3 宏生成代码不支持全限定类型名](#53-宏生成代码不支持全限定类型名)
  - [5.4 struct 中 let obj 不可赋值](#54-struct-中-let-obj-不可赋值)
  - [5.5 集合泛型参数缺失（已通过 Rust-like Option 模式解决）](#55-集合泛型参数缺失已通过-rust-like-option-模式解决)
  - [5.6 HashSet 使用 add() 而非 put()](#56-hashset-使用-add-而非-put)
  - [5.7 extend\<T\> 泛型类型参数声明语法](#57-extendt-泛型类型参数声明语法)
  - [5.8 Cangjie enum 不支持 == 比较](#58-cangjie-enum-不支持--比较)
  - [5.9 Option\<T\> 中泛型内类型的 JsonValue 桥接验证](#59-optiont-中泛型内类型的-jsonvalue-桥接验证)
- [6. Phase 2 有参枚举序列化踩坑](#6-phase-2-有参枚举序列化踩坑)
  - [6.1 enum 体内 match(value.kind) 使用 case JsonString 导致 "enum pattern is not matched"](#61-enum-体内-matchvaluekind-使用-case-jsonstring-导致-enum-pattern-is-not-matched)
  - [6.2 JsonObject.getFields() 返回 HashMap 不可整数索引](#62-jsonobjectgetfields-返回-hashmap-不可整数索引)
  - [6.3 Float64 整数值 JSON 序列化丢失小数点](#63-float64-整数值-json-序列化丢失小数点)

---

## 1. 仓颉宏编程踩坑

### 1.1 quote() 中插值类型名变为字符串字面量

**问题**：在 `quote()` 块中使用 `$(varInfo.typeName)` 插值类型名时，生成的代码中类型名变成了带引号的字符串字面量（如 `"String"`），而非标识符（如 `String`）。

**错误示例**：

```cangjie
// 期望生成: var _name: String
// 实际生成: var _name: "String"  ← 编译错误！
return quote(
    var _name: $(varInfo.typeName)
)
```

**解决方案**：使用 `Token(TokenKind.IDENTIFIER, typeName)` 构造标识符 Token，再在 `quote()` 中插值：

```cangjie
let typeToken = Token(TokenKind.IDENTIFIER, varInfo.typeName)
return quote(
    var _name: $typeToken  // 正确生成: var _name: String
)
```

**根本原因**：`quote()` 中的 `$()` 插值对于 String 类型会自动添加引号，将其视为字符串字面量。需要通过 Token 构造器将其转换为标识符节点。

**相关提交**：`87a1b6d`（@JsonCreator 实现）

---

### 1.2 宏属性必须使用方括号 [] 而非圆括号 ()

**问题**：使用 `@JsonIgnoreUnknown(true)` 语法时编译报错 "expect a plain macro"。

**错误示例**：

```cangjie
// ❌ 错误：圆括号语法
@JsonIgnoreUnknown(true)
public class User { ... }
```

**解决方案**：仓颉宏属性参数使用方括号 `[]`：

```cangjie
// ✅ 正确：方括号语法
@JsonIgnoreUnknown[true]
public class User { ... }
```

**根本原因**：仓颉语言的宏属性语法与 Java 注解不同，属性参数使用 `[]` 而非 `()`。

**相关提交**：`d5a349b`（@JsonIgnoreUnknown 布尔参数）

---

### 1.3 quote() 插值语法是 $varName 而非 ${varName}

**问题**：在 `quote()` 中使用 `${className}` 风格的插值不工作。

**解决方案**：仓颉 `quote()` 使用 `$varName` 语法：

```cangjie
// ❌ 错误
quote(class ${className} { ... })

// ✅ 正确
let classNameToken = Token(TokenKind.IDENTIFIER, className)
quote(class $classNameToken { ... })
```

---

### 1.4 GlobalConfig 全局可变状态导致并行宏展开不安全

**问题**：`GlobalConfig` 使用模块级全局变量 `var globalConfig = GlobalConfig()`，当多个类同时被 `@JsonSerialize` 宏展开时，全局状态会被共享和覆盖，导致交叉污染。

**原始代码**：

```cangjie
// jsonmacro/global_config.cj
var globalConfig = GlobalConfig()  // 模块级全局变量，并行不安全！
```

**解决方案**：在 `@JsonSerialize` 宏入口处创建局部变量，通过参数传递给序列化器/反序列化器：

```cangjie
public macro JsonSerialize(input: Tokens): Tokens {
    let config = GlobalConfig()  // 局部变量，每次宏展开独立
    // ... 传递 config 给 ClassProcessor / Serializer / Deserializer
}
```

**相关提交**：`3f70696`

---

## 2. 仓颉语言 API 踩坑

### 2.1 isEmpty 是方法调用而非属性访问

**问题**：使用 `list.isEmpty` 作为布尔表达式时，编译报错 "invalid unary operator '!' on type '() -> Bool'"。

**错误示例**：

```cangjie
if (!list.isEmpty) { ... }  // ❌ isEmpty 是函数，不是属性
```

**解决方案**：`isEmpty` 是方法，需要加括号调用：

```cangjie
if (!list.isEmpty()) { ... }  // ✅ 正确
```

**根本原因**：仓颉语言中 `isEmpty` 是方法而非属性，不加括号得到的是函数引用而非布尔值。

**相关提交**：`211f90d`（@JsonInclude 实现）

---

### 2.2 DateTime 格式化 API

**问题**：不确定仓颉 DateTime 的格式化 API 用法，`toString(DateTimeFormat)` 已被标记为过时。

**解决方案**：使用较新的 API：

```cangjie
// 序列化：DateTime → 格式化字符串
let str = dt.format("yyyy-MM-dd")

// 反序列化：格式化字符串 → DateTime
let dt = DateTime.parse(str, "yyyy-MM-dd")
```

**注意**：不要使用已过时的 `toString(DateTimeFormat)` API。

**相关提交**：`713ee2f`（@JsonFormat 实现）

---

### 2.3 JsonObject.getFields() 返回元组需解构

**问题**：直接遍历 `JsonObject.getFields()` 报错，因为它返回的是 `Tuple<String, JsonValue>`。

**错误示例**：

```cangjie
for (field in obj.getFields()) { ... }  // ❌ 无法直接遍历
```

**解决方案**：使用元组解构：

```cangjie
for ((key, _) in obj.getFields()) { ... }  // ✅ 正确
```

**相关提交**：`d343f1c`（@JsonIgnoreUnknown 实现）

---

## 3. 测试相关踩坑

### 3.1 JSON 测试比较不能直接用 JsonValue.fromStr() 

**问题**：在测试中使用 `JsonValue.fromStr(jsonString).toString()` 进行 JSON 字符串比较时，可能因格式化差异（空格、字段顺序）导致断言失败或运行时崩溃。

**解决方案**：编写 `compactJson()` 辅助函数，去除 JSON 字符串中非字符串值内的空白字符：

```cangjie
func compactJson(json: String): String {
    var inString = false
    var result = StringBuilder()
    let runes = json.toRuneArray()
    var i = 0
    while (i < runes.size) {
        let c = runes[i]
        if (c == '\\') {
            result.append(runes[i])
            i += 1
            if (i < runes.size) {
                result.append(runes[i])
            }
        } else if (c == '"') {
            inString = !inString
            result.append(c)
        } else if (!inString && (c == ' ' || c == '\n' || c == '\r' || c == '\t')) {
            // 跳过字符串值外的空白
        } else {
            result.append(c)
        }
        i += 1
    }
    return result.toString()
}
```

**关键设计**：使用 `toRuneArray()` 逐字符处理，正确处理转义字符（如 `\"`）和字符串值内的合法空格。

---

### 3.2 三引号字符串中的双引号不需要转义

**问题**：在三引号字符串 `"""..."""` 中对双引号进行转义（`\"`）导致实际输出包含反斜杠。

**错误示例**：

```cangjie
let json = """{\"name\":\"test\"}"""  // ❌ 输出包含反斜杠
```

**解决方案**：三引号字符串中直接写双引号，无需转义：

```cangjie
let json = """{"name":"test"}"""  // ✅ 正确
```

**相关提交**：`0fa0602`

---

### 3.3 严格模式应收集所有未知字段后统一抛出异常

**问题**：最初的严格模式实现在遇到第一个未知字段时立即抛出异常，用户无法一次性看到所有未知字段。

**原始逻辑**：

```cangjie
// 遇到第一个未知字段就抛异常
if (!knownFields.contains(key)) {
    throw Exception("Unknown field: ${key}")
}
```

**优化后**：收集所有未知字段后统一抛出：

```cangjie
let unknownFields = ArrayList<String>()
for ((key, _) in obj.getFields()) {
    if (!knownFields.contains(key)) {
        unknownFields.add(key)  // 收集而非立即抛出
    }
}
if (unknownFields.size > 0) {
    throw Exception("Unknown fields in ${className}: ${unknownFields}")
}
```

**相关提交**：`7b696ad`

---

## 4. 设计决策记录

### 4.1 JSON Path 异常信息功能推迟到 Phase 2

**背景**：在实现 `@JsonIgnoreUnknown[false]` 严格模式的异常信息时，讨论是否在异常中提供从 JSON 根开始的完整路径（如 `$.profile.address.zip`）。

**决策**：推迟到 Phase 2，原因：
1. 实现较复杂，需要修改 `fromJsonValue` 签名传递 path 参数
2. 需要新增 `JsonUnknownFieldsException` 异常类
3. 当前简单字段名列表已能满足基本需求

**TODO**：在 `DESIGN_AND_ROADMAP.md` Phase 2 Step 10 中记录了详细实现方案。

---

## 附录：Phase 1 提交历史

| 提交 | 说明 | 涉及踩坑 |
|------|------|----------|
| `3f70696` | 修复 GlobalConfig 全局状态问题 | 1.4 |
| `e14c6ab` | 补全 UInt 类型扩展 | - |
| `904f5b3` | 修复 Option 静默吞错问题 | - |
| `3b7bf1a` | 三引号字符串转义修复 | 3.2 |
| `0fa0602` | 格式化测试中的 JSON 字符串 | 3.2 |
| `d343f1c` | 新增 @JsonIgnoreUnknown 宏 | 2.3 |
| `d5a349b` | @JsonIgnoreUnknown 支持布尔参数 | 1.2 |
| `7b696ad` | 严格模式收集所有未知字段 | 3.3 |
| `211f90d` | 新增 @JsonInclude 宏 | 2.1 |
| `713ee2f` | 新增 @JsonFormat 宏 | 2.2 |
| `87a1b6d` | 新增 @JsonCreator 宏 | 1.1 |

---

## 5. Phase 2 Stream 集成踩坑

### 5.1 JsonSerializable 命名冲突

**问题**：`json4cj.JsonSerializable<T>` 与 `stdx.encoding.json.stream.JsonSerializable` 同名，当两者同时被 import 时产生歧义：

```cangjie
import json4cj.{JsonSerializable, ...}         // json4cj 的
import stdx.encoding.json.stream.*              // stdx 的，也叫 JsonSerializable

// 宏生成的代码中：
class User <: JsonSerializable<User> { ... }   // ❌ ambiguous!
extend User <: JsonSerializable { ... }         // ❌ ambiguous!
```

**错误信息**：`ambiguous use of 'JsonSerializable'`

**解决方案**：将 `json4cj.JsonSerializable<T>` 重命名为 `json4cj.JsonCodec<T>`：

```cangjie
// 重命名后无歧义：
class User <: JsonCodec<User> { ... }          // json4cj 的
extend User <: JsonSerializable { ... }         // stdx 的，清晰
```

**相关提交**：`e059ffc`

---

### 5.2 cjc 1.0.1 泛型约束传播失败

**问题**：stdx 源码中有：

```cangjie
extend<T> HashSet<T> <: JsonSerializable where T <: JsonSerializable { ... }
extend Int64 <: JsonSerializable { ... }
```

理论上 `HashSet<Int64>` 应满足 `where Int64 <: JsonSerializable` 约束，但 cjc 1.0.1 报错：

```
error: 'Class-HashSet<Int64>' is not a subtype of 'Interface-JsonSerializable'
```

**验证**：直接手写 `writeValue<HashSet<Int64>>()` 也会失败，确认是 cjc/stdx 的约束传播问题，非宏 bug。

**对比**：`writeValue<ArrayList<Int64>>()` 正常工作。

**解决方案**：JsonValue 桥接模式——对于无法通过约束检查的类型，先转为 `JsonValue`，再序列化为字符串写入流：

```cangjie
// 序列化桥接
w.writeName("field").jsonValue(this.field.toJsonValue().toString())

// 反序列化桥接
_field = FieldType.fromJsonValue(JsonValue.fromStr(String.fromUtf8(r.readValueBytes())))
```

**影响范围**：`HashSet<T>`、`HashMap<K,V>`、用户自定义类型均需要桥接。

**相关提交**：`e059ffc`、`6a9f39f`（验证测试）

---

### 5.3 宏生成代码不支持全限定类型名

**问题**：在宏 `quote()` 中使用全限定类型名如 `stdx.encoding.json.stream.JsonSerializable` 时，cjc 将其解析为链式成员访问而非类型名：

```cangjie
// ❌ 在 quote() 中使用全限定名
quote(
    extend $classIdent <: stdx.encoding.json.stream.JsonSerializable { ... }
)
// 报错：undeclared type name 'stdx'
```

**解决方案**：使用短名称（`JsonSerializable`），通过用户代码中的 `import stdx.encoding.json.stream.*` 来解析。

---

### 5.4 struct 中 let obj 不可赋值

**问题**：Stream 反序列化器生成 `let obj = StructType(); obj.field = value`，但 struct 是值类型，`let obj` 使整个对象不可变。

**错误信息**：`cannot assign to immutable value`

**解决方案**：使用 `var obj` 代替 `let obj`：

```cangjie
// ❌ 错误
let obj = StructType()
obj.field = value   // cannot assign to immutable value

// ✅ 正确
var obj = StructType()
obj.field = value   // OK
```

**相关提交**：`e059ffc`

---

### 5.5 集合泛型参数缺失（已通过 Rust-like Option 模式解决）

**问题**：旧版 Stream 反序列化器生成的局部变量声明缺少泛型参数，且需要每种类型的默认值：

```cangjie
// ❌ 旧模式：需要默认值
var _array: ArrayList = ArrayList()      // 编译错误：generic type should be used with type argument
var _data: T = ???                        // 无法提供泛型参数默认值
```

**解决方案**：采用 Rust-like Option<T> 中间变量模式，消除所有默认值：

```cangjie
// ✅ 新模式：Option<T> = None 通用默认值
var _array: Option<ArrayList<String>> = None    // 无需默认值
var _data: Option<T> = None                     // 泛型参数也能工作
// 读取后：_array = Some(r.readValue<ArrayList<String>>())
// 使用时：_array.getOrThrow()  // 缺失字段抛出异常
```

**影响**：
- 删除了整个 `getDefaultValue()` 函数（53行）
- Option<T> 字段不双重包装：`var _nickname: Option<String> = None`（不是 `Option<Option<String>>`）
- 缺失字段通过 `getOrThrow()` 自然抛出异常，语义更清晰

---

### 5.6 HashSet 使用 add() 而非 put()

**问题**：误用 `HashSet.put()` 添加元素，但 HashSet 的方法是 `add()`：

```cangjie
// ❌ 错误
s.put(1)    // 'put' is not a member of class 'HashSet<Int64>'

// ✅ 正确
s.add(1)    // HashSet 用 add()
```

**注意**：`HashMap` 在 Cangjie 中使用 `add(key, value)` 而非 `put(key, value)`。

---

### 5.7 extend<T> 泛型类型参数声明语法

**问题**：泛型类的 Stream extend 块需要声明类型参数，但 Cangjie 要求类型参数在 `extend` 关键字上声明：

```cangjie
// ❌ 错误：类型参数不在 extend 关键字上
extend ClassName<T> <: JsonSerializable where T <: JsonValueSerializable<T> { ... }
// 编译错误：expected '{', found 'T'

// ✅ 正确：类型参数在 extend 关键字上声明
extend<T> ClassName<T> <: JsonSerializable where T <: JsonValueSerializable<T> { ... }
```

**注意**：即使语法正确，cjc 1.0.1 的约束传播 bug 仍然导致 `writeValue<T>()` 和 `readValue<Option<T>>()` 失败（见 5.2）。因此泛型类暂时跳过 Stream 生成。

---

### 5.8 Cangjie enum 不支持 == 比较

**问题**：在宏代码中使用 `==` 比较枚举值导致编译错误：

```cangjie
// ❌ 错误
if (fc.category == FieldCategory.OPTION) { ... }
// 编译错误：invalid binary operator '==' on type 'Enum-FieldCategory'

// ✅ 正确：使用模式匹配
if (let FieldCategory.OPTION <- fc.category) { ... }
```

---

### 5.9 Option<T> 中泛型内类型的 JsonValue 桥接验证

**问题**：Stream 反序列化中 `Option<UserType>` 字段的 `readValue<Option<UserType>>()` 调用，对于用户自定义内类型会触发 cjc 1.0.1 约束传播失败：

```cangjie
// @JsonSerialize class PersonWithAddress { var address: Option<Address> = None }
// 宏生成的 extend 块中：
case "address" => _address = r.readValue<Option<Address>>()  // 可能失败
```

**根因**：cjc 1.0.1 无法将 `Address <: JsonValueSerializable<Address>` 传播到 `Option<Address> <: JsonDeserializable<Option<Address>>`。虽然对于具体的 `Address` 类型通常能工作（stdx 已有 `extend<T> Option<T> <: JsonDeserializable where T <: ...`），但对于泛型类型参数 `T` 则必然失败。

**验证测试**：`cjc_constraint_bug_test.cj` 中包含：
1. 注释掉的 `extend<T>` 块（取消注释可复现两个 bug）
2. JsonValue 桥接路径的正确性验证（4个通过的测试用例）
3. 序列化桥接 `w.jsonValue(value.toJsonValue().toString())` 验证
4. 反序列化桥接 `readValueBytes → JsonValue → T.fromJsonValue()` 验证

**桥接代码**（`emitOptionRead` 生成）：

```cangjie
// 内类型为基础类型或 ArrayList：直接使用 readValue
_address = r.readValue<Option<Address>>()

// 内类型为用户自定义类型：使用 JsonValue 桥接
let _optJsonValue = JsonValue.fromStr(String.fromUtf8(r.readValueBytes()))
if (_optJsonValue is JsonNull) {
    _address = None
} else {
    _address = Some(Address.fromJsonValue(_optJsonValue))
}
```

**相关测试文件**：
- `cjc_constraint_bug_test.cj`：cjc 约束传播 bug 验证 + JsonValue 桥接测试
- `manual_stream_test.cj`（`TestOptionUserTypeStream`）：`Option<UserType>` 完整 round-trip 测试

---

## 附录：Phase 2 提交历史

| 提交 | 说明 | 涉及踩坑 |
|------|------|----------|
| `ebd51d9` | 验证 extend 模式可行 | - |
| `cb2b27b` | 新增 FieldConfig 类型 | - |
| `993978a` | 新增 FieldConfigBuilder | - |
| `6466a2e` | 重构 ClassJsonSerializer 使用 FieldConfig | - |
| `9fdb9d4` | 重构 ClassJsonDeserializer 使用 FieldConfig | - |
| `3b3e19f` | 新增 ClassStreamSerializer | - |
| `c94fdaa` | 新增 ClassStreamDeserializer | - |
| `e059ffc` | 重命名 JsonSerializable→JsonCodec，接入流式生成器 | 5.1, 5.3, 5.4, 5.5 |
| `b77f67d` | 宏生成流式序列化运行时测试 | - |
| `6a9f39f` | 验证 HashSet stream API 限制 | 5.2 |

---

## 6. Phase 2 有参枚举序列化踩坑

### 6.1 enum 体内 match(value.kind) 使用 case JsonString 导致 "enum pattern is not matched"

**错误信息**：
```
error: enum pattern is not matched
  ==> enum_param_test.cj:21:1195
```

**原因**：在 `@JsonSerialize` 宏生成的 `fromJsonValue()` 静态函数中，使用 `match (value.kind)` 配合 `case JsonString =>` 模式匹配。此模式在普通代码（如 `json_serializable.cj` 的 extend 块）中正常工作，但当宏展开代码位于 **enum 体内** 时，编译器无法正确解析 `JsonString` 为 `JsonKind` 枚举变体，导致 "enum pattern is not matched" 错误。

**关键发现**：`case JsonObject =>` 在 enum 体内可以正常工作（纯有参枚举测试通过），但 `case JsonString =>` 失败。仅当混合枚举（同时有 unit 和 parameterized 构造器）触发 `case JsonString` 分支时才出错。

**解决方案**：使用类型模式匹配（type pattern matching）替代 `match (value.kind)`：

```cangjie
// ❌ 不可行：enum 体内 match(value.kind) 的 case JsonString 解析失败
match (value.kind) {
    case JsonString => ...  // error: enum pattern is not matched
    case JsonObject => ...
    case _ => ...
}

// ✅ 可行：使用类型模式匹配 match(value)
match (value) {
    case _s: JsonString =>
        let _str = _s.getValue()
        ...
    case _o: JsonObject =>
        let _fields = _o.getFields()
        ...
    case _ => throw Exception(...)
}
```

**教训**：宏生成的代码在 enum 体内展开时，模式匹配的名称解析行为与普通代码不同。优先使用类型模式匹配（`case v: Type =>`）而非枚举变体匹配（`case VariantName =>`），可避免宏展开上下文中的名称解析问题。

---

### 6.2 JsonObject.getFields() 返回 HashMap 不可整数索引

**错误信息**：
```
error: cannot convert an integer literal to type 'Struct-String'
```

**原因**：`JsonObject.getFields()` 返回 `HashMap<String, JsonValue>`，而非 `ArrayList<(String, JsonValue)>`。`HashMap` 的 `operator[]` 接受 `String` 类型的 key，不能用 `Int64` 索引。尝试 `fields[0]` 时，编译器将 `0` 视为整数字面量，无法转换为 `String`。

**解决方案**：使用迭代而非索引访问：

```cangjie
// ❌ 不可行：HashMap 不支持整数索引
let (key, val) = fields[0]

// ✅ 可行：迭代提取单个键值对
var _key = ""
var _val: JsonValue = _o  // 使用已有变量作为默认值
for ((_k, _v) in _fields) {
    _key = _k
    _val = _v
}
```

**教训**：不要假设 `getFields()` 返回有序列表。`HashMap` 是无序的，只能通过迭代或 `contains()`/`get()` 访问。

---

### 6.3 Float64 整数值 JSON 序列化丢失小数点

**现象**：`Float64` 值为整数时（如 `3.0`、`5.0`），`JsonFloat.toString()` 输出不带小数点：`3` 而非 `3.0`。

**影响**：测试中使用 `@Assert(json.contains("5.0"))` 会失败，因为实际 JSON 输出是 `{"Circle":5}` 而非 `{"Circle":5.0}`。

**解决方案**：测试中使用非整数的 Float64 值（如 `3.14`、`5.5`）避免此问题：

```cangjie
// ❌ 不稳定：5.0 序列化为 "5"
let s = Shape.Circle(5.0)
@Assert(json.contains("5.0"))  // 失败

// ✅ 稳定：5.5 序列化为 "5.5"
let s = Shape.Circle(5.5)
@Assert(json.contains("5.5"))  // 通过
```

**根本原因**：这是 `stdx.encoding.json` 的 `JsonFloat` 序列化行为，json4cj 无法控制。如需保留小数点，需要自定义序列化器。
