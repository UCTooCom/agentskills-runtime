# jsonvalue

通用 JSON Value 类型，对标 Rust serde_json::Value。

## 环境变量
需要配置`CANGJIE_STDX_PATH`
```bash
export CANGJIE_STDX_PATH=/path/to/stdx
```

## 快速开始

```cangjie
import jsonvalue.*

// 解析
let v = JsonValue.parse("{\"name\":\"test\",\"age\":42}")

// 访问
let name = v["name"]?.asString() ?? ""
let age = v["age"]?.asNumber() ?? 0.0

// 序列化
let json = v.stringify()
```

## API 文档

### 类型

```cangjie
public enum JsonValue {
    | Null
    | Boolean(Bool)
    | Number(Float64)
    | String(String)
    | Array(ArrayList<JsonValue>)
    | Map(HashMap<String, JsonValue>)
}
```

### 解析

| 方法 | 说明 |
|------|------|
| `JsonValue.parse(json: String): JsonValue` | 从字符串解析 |
| `JsonValue.parse(bytes: Array<UInt8>): JsonValue` | 从字节数组解析 |

### 序列化

| 方法 | 说明 |
|------|------|
| `v.stringify(): String` | 转为 JSON 字符串 |
| `v.toBytes(): Array<UInt8>` | 转为字节数组 |

### 类型检查

| 方法 | 说明 |
|------|------|
| `v.isNull(): Bool` | 是否为 null |
| `v.isBool(): Bool` | 是否为布尔值 |
| `v.isNumber(): Bool` | 是否为数字 |
| `v.isString(): Bool` | 是否为字符串 |
| `v.isArray(): Bool` | 是否为数组 |
| `v.isMap(): Bool` | 是否为对象 |

### 类型转换

| 方法 | 说明 |
|------|------|
| `v.cast<T>(): Option<T>` | 泛型断言：运行时检查值类型是否 T，匹配解包否则 None |
| `v.asBool(): Option<Bool>` | 转为布尔值 |
| `v.asNumber(): Option<Float64>` | 转为数字 |
| `v.asString(): Option<String>` | 转为字符串 |
| `v.asArray(): Option<ArrayList<JsonValue>>` | 转为数组 |
| `v.asMap(): Option<HashMap<String, JsonValue>>` | 转为对象 |

> `cast<T>()` 是严格类型断言（不自动转换）：`cast<String>` 只匹配字符串值，`cast<Int64>` 不会把 `42.0` 截断为整数。

### 访问

| 方法 | 说明 |
|------|------|
| `v[key: String]: ?JsonValue` | 按键访问对象 |
| `v[index: Int64]: ?JsonValue` | 按索引访问数组 |
| `v.get(key: String, default: JsonValue): JsonValue` | 带默认值访问 |
| `v.getOr(default: JsonValue): JsonValue` | 处理 null |

### 便捷构造

| 方法 | 说明 |
|------|------|
| `JsonValue.from(v: Bool): JsonValue` | 布尔转 JsonValue |
| `JsonValue.from(v: Int64): JsonValue` | 整数转 JsonValue（Number） |
| `JsonValue.from(v: Float64): JsonValue` | 浮点转 JsonValue |
| `JsonValue.from(v: String): JsonValue` | 字符串转 JsonValue |
| `JsonValue.from(v: ArrayList<JsonValue>): JsonValue` | 数组转 JsonValue |
| `JsonValue.from(v: HashMap<String, JsonValue>): JsonValue` | 对象转 JsonValue |
| `JsonValue.from<T>(obj: T): JsonValue` | 对象转 JsonValue（需 JsonSerializable） |

### 泛型转换

| 方法 | 说明 |
|------|------|
| `JsonValue.fromObject<T>(obj: T): JsonValue` | 对象转 JsonValue |
| `JsonValue.toObject<T>(v: JsonValue): T` | JsonValue 转对象 |
| `JsonValue.fromDataModel(dm: DataModel): JsonValue` | DataModel（stdx 序列化模型）转 JsonValue |
| `v.toDataModel(): DataModel` | JsonValue 转 DataModel |

> 泛型转换要求类型实现 `JsonSerializable` 和 `JsonDeserializable<T>` 接口。
> `fromDataModel`/`toDataModel` 用于与 tomlcj 等基于 `stdx.serialization` 的库互操作。

## 示例

### 链式访问

```cangjie
let v = JsonValue.parse("{\"a\":{\"b\":[1,2,3]}}")
let value = v["a"]?["b"]?[0]?.asNumber() ?? 0.0  // 1.0
```

### 泛型断言 + 便捷构造

```cangjie
// cast<T>()：严格类型断言，替代嵌套 match
let v = JsonValue.parse("{\"name\":\"test\",\"age\":42}")
let name = v["name"]?.cast<String>() ?? ""   // "test"
let age = v["age"]?.cast<Int64>()            // None（Number 不自动截断为 Int64）

// from()：便捷构造
let extra = HashMap<String, JsonValue>()
extra["reasoning_effort"] = JsonValue.from("high")
extra["top_p"] = JsonValue.from(0.9)
let obj = JsonValue.from(extra)              // {"reasoning_effort":"high","top_p":0.9}
```

### 数组操作

```cangjie
let v = JsonValue.parse("[1,2,3]")
if (let Some(arr) <- v.asArray()) {
    for (item in arr) {
        println(item.asNumber() ?? 0.0)
    }
}
```

### 对象转 JSON

```cangjie
class User <: JsonSerializable & JsonDeserializable<User> {
    public var name: String = ""
    public var age: Int64 = 0
    
    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("name").writeValue(this.name)
        w.writeName("age").writeValue(this.age)
        w.endObject()
    }
    
    public static func fromJson(r: JsonReader): User {
        let user = User()
        r.startObject()
        while (r.peek() != EndObject) {
            match (r.readName()) {
                case "name" => user.name = r.readValue<String>()
                case "age" => user.age = r.readValue<Int64>()
                case _ => r.skip()
            }
        }
        r.endObject()
        user
    }
}

let user = User("Tom", 25)
let v = JsonValue.fromObject(user)
let user2 = JsonValue.toObject<User>(v)
```

## 依赖

- 仓颉 1.0.0+
- stdx.encoding.json.stream

## License

MIT
