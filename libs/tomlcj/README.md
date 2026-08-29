# tomlcj

TOML 解析与编码库，支持 TOML 文件的双向操作（解析 & 序列化）。

## 来源

代码提取自 [cjpm](https://cangjie-lang.cn)（仓颉语言包管理工具）的 TOML 模块，经整理后作为独立库发布。

## 特性

- TOML 文件解析（`Decoder`）
- TOML 文件编码写入（`Encoder`）
- 完整日期/时间类型支持
- 注释保留（读写）
- `DataModel` 双向转换
- 泛型序列化/反序列化（`marshal` / `unmarshal`）

## 依赖

在 `cjpm.toml` 中添加：

```toml
[dependencies]
  tomlcj = { git = "https://github.com/ystyle/tomlcj" }
```

## 使用示例

### 解析 TOML 文件

```cangjie
import std.fs.*
import tomlcj.*

main() {
    // 从文件解析
    let file = File("config.toml", Read)
    let decoder = Decoder(file)
    let obj = decoder.decode()
    println(obj)
}
```

### 解析 TOML 字符串

```cangjie
import tomlcj.*

main() {
    let data = """
        [package]
        name = "tomlcj"
        version = "1.0.0"

        [dependencies]
        stdx = { version = "0.3.2" }
    """
    let parser = parse(data)
    let obj = parser.mapping
    println(obj)
}
```

### 写入 TOML 文件

```cangjie
import std.fs.*
import std.io.*
import tomlcj.*

main() {
    let obj = TomlObject()
    let pkg = TomlObject()
    pkg.put("name", TomlString("myapp"))
    pkg.put("version", TomlString("1.0.0"))
    obj.put("package", pkg)

    let deps = TomlObject()
    deps.put("tomlcj", TomlString("1.0.0"))
    obj.put("dependencies", deps)

    let file = File("output.toml", Write)
    let encoder = Encoder(file)
    encoder.encode(obj)
}
```

### 泛型序列化

```cangjie
import serialization.serialization.*
import tomlcj.*

class Config {
    public let name: String
    public let version: Int64
    init(name: String, version: Int64) {
        this.name = name
        this.version = version
    }
}

extend Config <: Serializable<Config> {
    public func serialize(): DataModel {
        DataModelStruct()
            .add(Field("name", DataModelString(name)))
            .add(Field("version", DataModelInt(version)))
    }
    public static func deserialize(dm: DataModel): Config {
        let dms = (dm as DataModelStruct).getOrThrow()
        Config(
            String.deserialize(dms.get("name")),
            Int64.deserialize(dms.get("version"))
        )
    }
}

main() {
    // 反序列化：TOML 文件 → Config
    let config = unmarshal<Config>("config.toml")

    // 序列化：Config → TOML bytes
    let bytes = marshal(config)
    println(String(bytes))
}
```

## API

### `Decoder`

| 方法 | 说明 |
|------|------|
| `init(r: InputStream)` | 从输入流创建解码器 |
| `decode(): TomlObject` | 解析并返回 TOML 对象 |

### `Encoder`

| 方法 | 说明 |
|------|------|
| `init(w: OutputStream)` | 从输出流创建编码器 |
| `encode(tv: TomlValue): Unit` | 将 TomlValue 写入 TOML |
| `encode(dm: DataModel): Unit` | 将 DataModel 写入 TOML |

### 顶层函数

| 函数 | 说明 |
|------|------|
| `parse(data: String): Parser` | 解析 TOML 字符串，返回 Parser |
| `marshal<T>(object: T): Array<Byte>` | 泛型序列化（需实现 `Serializable<T>`） |
| `unmarshal<T>(path: String): T` | 泛型反序列化，从文件读取 |

### `Parser`

| 属性 | 类型 | 说明 |
|------|------|------|
| `mapping` | `TomlObject` | 解析结果 |
| `keyInfo` | `HashMap<String, KeyInfo>` | 键类型信息 |

### `TomlValue`（抽象基类）

所有 TOML 值类型均继承自此类。

| 子类 | 对应 TOML 类型 |
|------|---------------|
| `TomlString` | 字符串 |
| `TomlInteger` | 整数 |
| `TomlFloat` | 浮点数 |
| `TomlBoolean` | 布尔值 |
| `TomlOffsetDatetime` | 带时区偏移的日期时间 |
| `TomlLocalDatetime` | 本地日期时间 |
| `TomlLocalDate` | 本地日期 |
| `TomlLocalTime` | 本地时间 |
| `TomlArray` | 数组 |
| `TomlObject` | 表 / 内联表 |

类型安全转换方法：`asBool()`, `asInt()`, `asFloat()`, `asString()`, `asArray()`, `asObject()`

每个值都带 `comment: Comment` 属性，支持注释读写。

### `TomlObject`

| 方法 | 说明 |
|------|------|
| `put(key: String, v: TomlValue)` | 插入键值对 |
| `get(key: String): Option<TomlValue>` | 按键取值 |
| `contains(key: String): Bool` | 判断键是否存在 |
| `operator [](key: String): TomlValue` | 下标访问 |

### `TomlArray`

| 方法 | 说明 |
|------|------|
| `append(tv: TomlValue)` | 追加元素 |
| `get(index: Int64): Option<TomlValue>` | 按索引取值 |
| `operator [](index: Int64): TomlValue` | 下标访问 |

### `ToToml` 接口

```cangjie
public interface ToToml {
    static func fromToml(tv: TomlValue): DataModel
    func toToml(): TomlValue
}
```

`DataModel` 已实现此接口，支持 `DataModel ⟷ TomlValue` 双向转换。

### 日期时间结构体

| 结构体 | 字段 |
|--------|------|
| `LocalDate` | `year: Int64`, `month: Month`, `day: Int64` |
| `LocalTime` | `hour: Int64`, `minute: Int64`, `second: Int64`, `nanoSecond: Int64` |
| `LocalDatetime` | `date: LocalDate`, `time: LocalTime` |

### `LinkedHashMap<K, V>`

保持插入顺序的哈希映射，用于表格键的有序输出。

### 异常类

| 类 | 说明 |
|----|------|
| `TomlException` | TOML 通用异常 |
| `ParseException` | 解析异常 |
| `LexException` | 词法分析异常 |

## 许可

Apache-2.0 with Runtime Library Exception
