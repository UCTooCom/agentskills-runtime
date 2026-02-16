# 仓颉 (Cangjie) 编程语言编码规范

## 概述
本文档规定了在Uctoo API MCP Server项目中使用仓颉编程语言的编码规范和最佳实践。

## 1. 语法和词法规范

### 1.1 文件结构
- 每个文件必须以版权声明和包声明开始：
  ```cangjie
  /*
   * Copyright (c) 2025. All rights reserved.
   */
  package magic.examples.uctoo_api_mcp_server

  import magic.prelude.*
  import magic.examples.uctoo_api_mcp_server.models.*
  ```

### 1.2 导入语句
- 必须使用 `import` 语句导入必要的模块
- 不允许使用 `java.*` 或其他非仓颉标准库的导入
- 所有导入必须来自真实存在的仓颉标准库或项目内部模块
- 按照以下顺序组织导入：
  1. 仓颉标准库 (`magic.*`)
  2. 项目内部模块 (`magic.examples.*`)

### 1.3 类和接口定义
- 类使用 `class` 关键字定义
- 接口使用 `interface` 关键字定义
- 访问修饰符：`public`, `private`, `protected`
- 不能使用 `public` 修饰顶级类（除非必要）

### 1.4 方法定义
- 方法使用 `func` 关键字定义
- 访问修饰符：`public`, `private`, `protected`
- 静态方法使用 `static func` 定义
- 方法参数类型声明在参数名后面：`paramName: ParamType`

### 1.5 变量和常量
- 变量使用 `var` 关键字定义
- 值使用 `val` 关键字定义
- 静态变量使用 `static var` 定义
- 静态常量使用 `static val` 定义
- 类成员变量应在类体中显式声明

### 1.6 注释规范
- 类和公共方法必须有 Javadoc 风格的注释
- 复杂逻辑必须添加解释性注释
- 使用 `/** */` 进行文档注释
- 使用 `//` 进行单行注释

## 2. 数据类型和集合

### 2.1 基本类型
- `Bool`, `Int8`, `Int16`, `Int32`, `Int64`, `UInt8`, `UInt16`, `UInt32`, `UInt64`, `Float32`, `Float64`, `String`

### 2.2 集合类型
- 使用仓颉标准库的集合类型：`List<T>`, `Map<K,V>`, `Set<T>`
- 创建集合使用标准构造函数：`ArrayList<T>()`, `HashMap<K,V>()`, `HashSet<T>()`

### 2.3 泛型使用
- 泛型类型参数使用大写字母（如 `T`, `K`, `V`）
- 泛型类和方法必须有适当的边界约束

## 3. 异常处理
- 使用 `try-catch-finally` 语句处理异常
- 使用 `Exception` 或其适当子类
- 不要忽略捕获的异常，应该记录或适当地处理

## 4. 字符串处理
- 使用双引号定义字符串：`"string"`
- 使用模板字符串：`"Hello ${name}"`
- 避免字符串拼接，优先使用模板字符串

## 5. 控制流
- 使用 `if-else` 进行条件判断
- 使用 `while` 和 `for` 循行循环
- 使用 `when` 进行多重条件判断
- 避免深层嵌套，深度不应超过3层

## 6. 命名规范
- 包名：小写字母，单词之间用点分隔：`magic.examples.uctoo_api_mcp_server`
- 类名：大驼峰命名法：`NaturalLanguageProcessor`
- 方法名：小驼峰命名法：`processRequest`
- 变量名：小驼峰命名法：`backendUrl`
- 常量名：全大写字母，单词之间用下划线分隔：`MAX_CONNECTIONS`

## 7. 代码组织
- 每个文件专注于单一职责
- 类的方法按功能分组，公共方法在前，私有方法在后
- 避免过长的方法，单个方法不应该超过50行

## 8. 性能考虑
- 使用适当的集合类型以优化性能
- 避免不必要的对象创建
- 考虑内存使用，特别是在循环中

## 9. 安全考虑
- 输入验证：所有外部输入必须验证
- 输出转义：生成输出时应防止注入攻击
- 避免硬编码敏感信息（密码、密钥等）

## 10. 国际化和本地化
- 所有用户可见字符串必须支持中文
- 使用统一的错误消息和日志格式

## 11. 仓颉标准库
### Package List

The std library includes several packages that provide rich foundational functionalities:

| Package Name | Functionality |
|-------------|--------------|
| [core](./core/core_package_overview.md) | The core package of the standard library, providing the most fundamental API capabilities for Cangjie programming. |
| [argopt](./argopt/argopt_package_overview.md) | The argopt package provides capabilities for parsing parameter names and values from command-line argument strings. |
| [ast](./ast/ast_package_overview.md) | The ast package mainly includes Cangjie source code syntax parsers and Cangjie syntax tree nodes, offering syntax parsing functions. |
| [binary](./binary/binary_package_overview.md) | The binary package provides interfaces for converting between basic data types and binary byte arrays with different endianness, as well as endianness reversal. |
| [collection](./collection/collection_package_overview.md) | The collection package offers efficient implementations of common data structures, definitions of related abstract interfaces, and frequently used functions in collection types. |
| [collection.concurrent](./collection_concurrent/collection_concurrent_package_overview.md) | The collection.concurrent package provides thread-safe implementations of collection types. |
| [console](./console/console_package_overview.md) | The console package provides methods for interacting with standard input, output, and error streams. |
| [convert](./convert/convert_package_overview.md) | The convert package offers Convert series functions for converting strings to specific types, as well as formatting capabilities, primarily for converting Cangjie type instances to formatted strings. |
| [crypto.cipher](./crypto/cipher/cipher_package_overview.md) | The crypto.cipher package provides generic interfaces for symmetric encryption and decryption. |
| [crypto.digest](./crypto/digest/digest_package_overview.md) | The crypto.digest package offers generic interfaces for common digest algorithms, including MD5, SHA1, SHA224, SHA256, SHA384, SHA512, HMAC, and SM3. |
| [database.sql](./database_sql/database_sql_package_overview.md) | The database.sql package provides interfaces for Cangjie to access databases. |
| [deriving](./deriving/deriving_package_overview.md) | The deriving package provides a set of macros for automatically generating interface implementations. |
| [env](./env/env_package_overview.md) | The env package offers information and functionalities related to the current process, including environment variables, command-line arguments, standard streams, and program termination. |
| [fs](./fs/fs_package_overview.md) | The fs (file system) package provides functions for operating on files, directories, paths, and file metadata. |
| [io](./io/io_package_overview.md) | The io package enables data exchange between programs and external devices. |
| [math](./math/math_package_overview.md) | The math package provides common mathematical operations, constant definitions, floating-point number handling, and other functionalities. |
| [math.numeric](./math_numeric/math_numeric_package_overview.md) | The math.numeric package extends capabilities beyond the expressible range of basic types. |
| [net](./net/net_package_overview.md) | The net package provides common network communication functionalities. |
| [objectpool](./objectpool/objectpool_package_overview.md) | The objectpool package offers capabilities for object caching and reuse. |
| [overflow](./overflow/overflow_package_overview.md) | The overflow package provides functionalities related to overflow handling. |
| [posix](./posix/posix_package_overview.md) | The posix package encapsulates POSIX system calls, offering cross-platform system operation interfaces. |
| [process](./process/process_package_overview.md) | The process package mainly provides Process operation interfaces, including process creation, standard stream acquisition, process waiting, and process information querying. |
| [random](./random/random_package_overview.md) | The random package provides capabilities for generating pseudo-random numbers. |
| [reflect](./reflect/reflect_package_overview.md) | The reflect package offers reflection functionalities, enabling programs to obtain type information of various instances at runtime and perform read/write and invocation operations. |
| [regex](./regex/regex_package_overview.md) | The regex package provides capabilities for analyzing and processing text using regular expressions (supporting UTF-8 encoded Unicode strings), including search, split, replace, and validation functionalities. |
| [runtime](./runtime/runtime_package_overview.md) | The runtime package interacts with the program's runtime environment, providing a series of functions and variables for controlling, managing, and monitoring program execution. |
| [sort](./sort/sort_package_overview.md) | The sort package provides sorting functions for array types. |
| [sync](./sync/sync_package_overview.md) | The sync package offers capabilities related to concurrent programming. |
| [time](./time/time_package_overview.md) | The time package provides time-related types, including date-time, time intervals, monotonic time, and time zones, along with functionalities for calculation and comparison. |
| [unicode](./unicode/unicode_package_overview.md) | The unicode package provides capabilities for handling characters according to the Unicode encoding standard. |
| [unittest](./unittest/unittest_package_overview.md) | The unittest package is used for writing unit test code for Cangjie projects, providing basic functionalities including code writing, execution, and debugging. |
| [unittest.mock](./unittest_mock/unittest_mock_package_overview.md) | The unittest.mock package provides a mock framework for Cangjie unit tests, offering APIs to create and configure mock objects that have API signatures consistent with real objects. |
| [unittest.testmacro](./unittest_testmacro/unittest_testmacro_package_overview.md) | The unittest.testmacro package provides macros required by users for the unit testing framework. |
| [unittest.mock.mockmacro](./unittest_mock_mockmacro/unittest_mock_mockmacro_package_overview.md) | The unittest.mock.mockmacro package provides macros required by users for the mock framework. |
| [unittest.common](./unittest_common/unittest_common_package_overview.md) | The unittest.common package provides types and general methods required for printing in the unit testing framework. |
| [unittest.diff](./unittest_diff/unittest_diff_package_overview.md) | The unittest.diff package provides APIs required for printing difference comparison information in the unit testing framework. |
| [unittest.prop_test](./unittest_prop_test/unittest_prop_test_package_overview.md) | The unittest.prop_test package provides types and general methods required for parameterized testing in the unit testing framework. |

## 12. 仓颉拓展库
### Package List

stdx includes several packages that offer rich extension functionalities:

| Package Name                                                     | Functionality      |
| ---------------------------------------------------------- | --------- |
| [actors](./actors/actors_package_overview.md)    | The `actors` package provides the foundational capabilities for the actor programming model. |
| [actors.macros](./actors/macros/macros_package_overview.md) | The `actors.macros` package provides the ability to transform a class into an active object. |
| [aspectCJ](./aspectCJ/aspectCJ_package_overview.md) | The aspectCJ package provides Aspect-Oriented Programming (AOP) capabilities in Cangjie. |
| [compress.zlib](./compress/zlib/zlib_package_overview.md)                        | The compress package provides compression and decompression functionalities. |
| [crypto.crypto](./crypto/crypto/crypto_package_overview.md)                        | The crypto package provides secure encryption capabilities. |
| [crypto.digest](./crypto/digest/crypto_digest_package_overview.md)                        | The digest package provides commonly used message digest algorithms. |
| [crypto.keys](./crypto/keys/keys_package_overview.md)                        | The keys package provides asymmetric encryption and signature algorithms. |
| [crypto.x509](./crypto/x509/x509_package_overview.md)                        | The x509 package provides functionalities for handling digital certificates. |
| [encoding.base64](./encoding/base64/base64_package_overview.md)                        | The base package provides Base64 encoding and decoding for strings.|
| [encoding.hex](./encoding/hex/hex_package_overview.md)                        | The hex package provides Hex encoding and decoding for strings.|
| [encoding.json](./encoding/json/json_package_overview.md)                        | The json package is used for processing JSON data, enabling mutual conversion between String, JsonValue, and DataModel.|
| [encoding.json.stream](./encoding/json_stream/json_stream_package_overview.md)                        | The json.stream package is primarily used for mutual conversion between Cangjie objects and JSON data streams.|
| [encoding.url](./encoding/url/url_package_overview.md)                        | The url package provides URL-related capabilities, including parsing URL components, encoding and decoding URLs, and merging URLs or paths.|
| [fuzz](./fuzz/fuzz_package_overview.md)                        | The fuzz package provides developers with a coverage-guided fuzz engine for Cangjie and corresponding interfaces, allowing developers to write code to test APIs. |
| [log](./log/log_package_overview.md) | The log package provides logging-related capabilities. |
| [logger](./logger/logger_package_overview.md) | The logger package provides text and JSON format logging functionalities. |
| [net.http](./net/http/http_package_overview.md)                        | The http package provides server and client implementations for HTTP/1.1, HTTP/2, and WebSocket protocols. |
| [net.tls](./net/tls/tls_package_overview.md)                        | The tls package is used for secure encrypted network communication, providing capabilities such as creating TLS servers, performing TLS handshakes based on protocols, sending and receiving encrypted data, and resuming TLS sessions.|
| [serialization](./serialization/serialization_package_overview.md)                        | The serialization package provides serialization and deserialization capabilities. |
| [unittest.data](./unittest/data/data_package_overview.md)                        | The unittest module provides extended unit testing capabilities. |


## 字符串操作

### 替换操作
- 使用 `replace(old: String, new: String): String` 方法替代 `replaceAll` 方法进行字符串替换操作
- 示例：`str.replace("\"", "\\\"")` 而不是 `str.replaceAll("\"", "\\\"")`

### 修剪操作
- 使用 `trimAscii(): String` 方法替代 `trim(): String` 方法进行字符串首尾空白字符修剪
- 示例：`str.trimAscii()` 而不是 `str.trim()`

### 分割操作
- `split` 方法只接受单个字符串作为分隔符，不支持数组形式的多个分隔符
- 示例：`str.split(" ")` 而不是 `str.split([" ", ":"])`

## 集合操作

### HashMap操作
- 使用 `add(key: K, value: V): Unit` 方法替代 `insert(key: K, value: V): Unit` 方法向HashMap添加键值对
- 示例：`map.add("key", "value")` 而不是 `map.insert("key", "value")`
- HashMap的entries字段是私有的，不能直接访问，应使用`iterator()`方法遍历
- 示例：`for ((key, value) in map.iterator())` 而不是 `for (entry in map.entries)`

## 数值类型处理

### 类型一致性
- 确保函数返回类型与实际返回值类型一致
- 显式声明变量类型以避免类型推断错误
- 示例：`var score: Int32 = 0` 而不是 `var score = 0`

## StringBuilder使用

### 方法调用
- StringBuilder类提供`append`方法用于追加各种类型的数据
- 可以链式调用，但建议分行书写以提高可读性
- 示例：
  ```cangjie
  let sb = StringBuilder()
  sb.append("Hello ")
  sb.append("World")
  let result = sb.toString()
  ```

## 枚举和模式匹配

### 枚举比较
- 枚举值比较应使用 `==` 操作符
- 示例：`value.kind == JsonKind.JsObject` 而不是 `value.kind.equals(JsonKind.JsObject)`
- 在match表达式中，分支使用 `=>` 语法，不要在分支内嵌套复杂的控制流

### Option类型处理
- 使用 `match` 表达式处理 `Option<T>` 类型
- 示例：
  ```cangjie
  match (optionValue) {
      case Some(value) => // 处理有值的情况
      case None => // 处理无值的情况
  }
  ```

## 循环依赖处理

### 问题描述
当两个或多个包相互导入时，会产生循环依赖错误（cyclic dependency），例如：
```
package A -> package B
package B -> package A
```

### 解决方案
1. **依赖注入模式**：将具体实现类的注册从框架层移到应用层
   - 框架层定义接口和注册机制（如 `SkillFactory` 接口和 `SkillRegistry` 类）
   - 应用层在初始化时注册具体实现（如 `UctooAPISkillFactory`）

2. **示例代码**：
   ```cangjie
   // 框架层：magic.skill.application 包
   public class SkillManagementService {
       private let skillRegistry: SkillRegistry

       public func getSkillRegistry(): SkillRegistry {
           return this.skillRegistry
       }
   }

   // 应用层：magic.examples.uctoo_api_mcp_server 包
   main(): Unit {
       let skillLoader = ProgressiveSkillLoader(skillBaseDirectory: examplesDir)

       // 在应用层注册工厂，避免框架层直接依赖具体实现
       let skillRegistry = skillLoader.getSkillRegistry()
       skillRegistry.registerFactory("uctoo-api-skill", UctooAPISkillFactory())

       // 继续加载技能...
   }
   ```

3. **设计原则**：
   - 框架层（magic.skill.application）只定义抽象接口，不依赖具体实现
   - 具体实现（magic.examples.uctoo_api_skill）依赖框架层的接口
   - 应用程序（magic.examples.uctoo_api_mcp_server）负责协调两者，注册具体实现
   - 这样形成单向依赖链：具体实现 -> 框架接口 <- 应用程序，无循环依赖
- 使用 `isSome()` 和 `getOrThrow()` 方法也是可行的替代方案

## 函数和方法

### Match表达式
- Match表达式的各个分支需要返回相同类型或Unit
- 在需要返回值的上下文中，确保所有分支都返回相同类型
- 空的match分支应使用 `()`

### Option类型处理
- Option类型没有`unwrap()`方法，应使用`getOrThrow()`方法获取值
- 示例：
  ```cangjie
  let optValue = Some(42)
  if (optValue.isSome()) {
      let value = optValue.getOrThrow()
      // 处理值
  }
  ```

### 枚举比较
- 枚举值比较应使用match表达式而不是==操作符
- 示例：
  ```cangjie
  match (enumValue) {
      case EnumType.Value1 => // 处理Value1情况
      case EnumType.Value2 => // 处理Value2情况
      case _ => // 默认情况
  }
  ```

### 字符比较
- 字符比较可能需要转换为字符串进行比较
- 示例：
  ```cangjie
  let char = string[i]
  let charStr = String([char])  // 将字符转换为字符串
  if (charStr >= "a" && charStr <= "z") {
      // 处理小写字母
  }
  ```

### 枚举类型处理
- 在处理枚举类型时，需要确保match表达式涵盖所有可能的枚举值
- 示例：
  ```cangjie
  match (enumValue) {
      case EnumType.Value1 =>
          // 处理Value1情况
      case EnumType.Value2 =>
          // 处理Value2情况
      case EnumType.Value3 =>
          // 处理Value3情况
      case EnumType.Value4 =>
          // 处理Value4情况
      case EnumType.Value5 =>
          // 处理Value5情况
      case EnumType.Value6 =>
          // 处理Value6情况
      case EnumType.Value7 =>
          // 处理Value7情况
      case _ =>
          // 处理其他情况
  }
  ```

### 字符类型处理
- 在处理字符串索引操作符返回的字符时，可能需要使用Rune类型进行比较
- 示例：
  ```cangjie
  let char = string[i]  // char is UInt8
  let runeValue = UInt32(Rune(char))  // Convert to Rune then to UInt32 for comparison
  let aValue = UInt32(r'a')  // Character code for 'a' using Rune literal
  let zValue = UInt32(r'z')  // Character code for 'z' using Rune literal
  if (runeValue >= aValue && runeValue <= zValue) {
      // 处理小写字母
  }
  ```

- 使用Rune字面量语法（如r'a'）而不是字符字面量（如'a'）进行转换
  ```cangjie
  let runeA = r'a'  // 正确的Rune字面量语法
  let codeA = UInt32(runeA)  // 转换为UInt32进行比较
  ```

### 构造函数
- 在构造函数中，必须先初始化所有成员变量，然后才能调用实例方法
- 示例：
  ```cangjie
  public init() {
      // 先初始化所有成员变量
      field1 = Value1()
      field2 = Value2()

      // 然后再调用方法
      initializeMappings()
  }
  ```

### 类型转换
- 仓颉语言中的类型转换使用 `as` 操作符，语法为 `(expression) as Type`，而不是方法调用形式 `_server.as(Type)`
- 示例：
  ```cangjie
  let server = _server as Server  // 正确的类型转换语法
  // 而不是 _server.as(Server)
  ```
- 类型转换操作符返回一个 `Option` 类型，必须用 `match` 来处理
- 示例：
  ```cangjie
  let result = value as Int32
  match (result) {
      case Some(num) => // 处理转换成功的情况
      case None => // 处理转换失败的情况
  }
  ```

### Option类型处理
- 仓颉语言中许多操作返回 `Option<T>` 类型（如类型转换 `(expression) as Type`）
- 必须使用 `match` 表达式处理 `Option<T>` 类型，不能直接使用返回值
- 示例：
  ```cangjie
  match (_server as Server) {
      case Some(server) => {
          // 使用转换成功的 server 对象
          server.get("/endpoint", handler)
      }
      case None => {
          // 处理转换失败的情况
          LogUtils.error("Failed to cast _server to Server type")
      }
  }
  ```
- 在函数中如果需要返回Option类型中的值，必须在match表达式的每个分支中都有返回或适当的处理

## 遵循检查
为确保代码符合上述规范，所有代码必须通过以下检查：
1. 无 Java 导入语句
2. 仅使用仓颉标准库和项目内部模块
3. 代码格式符合仓颉语言规范
4. 注释完整且准确
5. 命名符合规范
6. 安全考虑已实施

## 字符串操作

### 替换操作
- 使用 `replace(old: String, new: String): String` 方法替代 `replaceAll` 方法进行字符串替换操作
- 示例：`str.replace("\"", "\\\"")` 而不是 `str.replaceAll("\"", "\\\"")`

### 修剪操作
- 使用 `trimAscii(): String` 方法替代 `trim(): String` 方法进行字符串首尾空白字符修剪
- 示例：`str.trimAscii()` 而不是 `str.trim()`

### 分割操作
- `split` 方法只接受单个字符串作为分隔符，不支持数组形式的多个分隔符
- 示例：`str.split(" ")` 而不是 `str.split([" ", ":"])`

## 集合操作

### HashMap操作
- 使用 `add(key: K, value: V): Unit` 方法替代 `insert(key: K, value: V): Unit` 方法向HashMap添加键值对
- 示例：`map.add("key", "value")` 而不是 `map.insert("key", "value")`
- HashMap的entries字段是私有的，不能直接访问，应使用`iterator()`方法遍历
- 示例：`for ((key, value) in map.iterator())` 而不是 `for (entry in map.entries)`

## 数值类型处理

### 类型一致性
- 确保函数返回类型与实际返回值类型一致
- 显式声明变量类型以避免类型推断错误
- 示例：`var score: Int32 = 0` 而不是 `var score = 0`

## StringBuilder使用

### 方法调用
- StringBuilder类提供`append`方法用于追加各种类型的数据
- 可以链式调用，但建议分行书写以提高可读性
- 示例：
  ```cangjie
  let sb = StringBuilder()
  sb.append("Hello ")
  sb.append("World")
  let result = sb.toString()
  ```

## 枚举和模式匹配

### 枚举比较
- 枚举值比较应使用 `==` 操作符
- 示例：`value.kind == JsonKind.JsObject` 而不是 `value.kind.equals(JsonKind.JsObject)`
- 在match表达式中，分支使用 `=>` 语法，不要在分支内嵌套复杂的控制流

### Option类型处理
- 使用 `match` 表达式处理 `Option<T>` 类型
- 示例：
  ```cangjie
  match (optionValue) {
      case Some(value) => // 处理有值的情况
      case None => // 处理无值的情况
  }
  ```
- 使用 `isSome()` 和 `getOrThrow()` 方法也是可行的替代方案

## 函数和方法

### Match表达式
- Match表达式的各个分支需要返回相同类型或Unit
- 在需要返回值的上下文中，确保所有分支都返回相同类型
- 空的match分支应使用 `()`

### Option类型处理
- Option类型没有`unwrap()`方法，应使用`getOrThrow()`方法获取值
- 示例：
  ```cangjie
  let optValue = Some(42)
  if (optValue.isSome()) {
      let value = optValue.getOrThrow()
      // 处理值
  }
  ```

### 枚举比较
- 枚举值比较应使用match表达式而不是==操作符
- 示例：
  ```cangjie
  match (enumValue) {
      case EnumType.Value1 => // 处理Value1情况
      case EnumType.Value2 => // 处理Value2情况
      case _ => // 默认情况
  }
  ```

### 字符比较
- 字符比较可能需要转换为字符串进行比较
- 示例：
  ```cangjie
  let char = string[i]
  let charStr = String([char])  // 将字符转换为字符串
  if (charStr >= "a" && charStr <= "z") {
      // 处理小写字母
  }
  ```

### 枚举比较
- 枚举值比较应使用match表达式而不是==操作符
- 示例：
  ```cangjie
  match (enumValue) {
      case EnumType.Value1 => // 处理Value1情况
      case EnumType.Value2 => // 处理Value2情况
      case _ => // 默认情况
  }
  ```

### 字符类型处理
- 在处理字符串索引操作符返回的字符时，可能需要使用Rune类型进行比较
- 示例：
  ```cangjie
  let char = string[i]  // char is UInt8
  let runeValue = UInt32(Rune(char))  // Convert to Rune then to UInt32 for comparison
  let aValue = UInt32(r'a')  // Character code for 'a' using Rune literal
  let zValue = UInt32(r'z')  // Character code for 'z' using Rune literal
  if (runeValue >= aValue && runeValue <= zValue) {
      // 处理小写字母
  }
  ```

- 使用Rune字面量语法（如r'a'）而不是字符字面量（如'a'）进行转换
  ```cangjie
  let runeA = r'a'  // 正确的Rune字面量语法
  let codeA = UInt32(runeA)  // 转换为UInt32进行比较
  ```

### 枚举类型处理
- 在处理枚举类型时，需要确保match表达式涵盖所有可能的枚举值
- 示例：
  ```cangjie
  match (enumValue) {
      case EnumType.Value1 =>
          // 处理Value1情况
      case EnumType.Value2 =>
          // 处理Value2情况
      case EnumType.Value3 =>
          // 处理Value3情况
      case EnumType.Value4 =>
          // 处理Value4情况
      case EnumType.Value5 =>
          // 处理Value5情况
      case EnumType.Value6 =>
          // 处理Value6情况
      case EnumType.Value7 =>
          // 处理Value7情况
      case _ =>
          // 处理其他情况
  }
  ```

### 枚举类型处理
- 在处理枚举类型时，需要确保match表达式涵盖所有可能的枚举值
- 示例：
  ```cangjie
  match (enumValue) {
      case EnumType.Value1 =>
          // 处理Value1情况
      case EnumType.Value2 =>
          // 处理Value2情况
      case EnumType.Value3 =>
          // 处理Value3情况
      case EnumType.Value4 =>
          // 处理Value4情况
      case EnumType.Value5 =>
          // 处理Value5情况
      case EnumType.Value6 =>
          // 处理Value6情况
      case EnumType.Value7 =>
          // 处理Value7情况
      case _ =>
          // 处理其他情况
  }
  ```

### 枚举比较
- 当需要检查特定枚举值时，可以使用match表达式进行模式匹配
- 示例：
  ```cangjie
  match (enumValue) {
      case SpecificEnum.Value =>
          // 处理特定枚举值
      case _ =>
          // 处理其他情况
  }
  ```

- 如果需要使用条件判断，可以使用函数调用形式：
  ```cangjie
  if (enumValue.kind() == SpecificEnum.Value) {
      // 处理特定枚举值
  } else {
      // 处理其他情况
  }
  ```

### 字符类型处理
- 在处理字符串索引操作符返回的字符时，可能需要使用UInt32(char)进行转换
- 示例：
  ```cangjie
  let char = string[i]  // char is UInt8
  let charCode = UInt32(char)  // Convert to UInt32 for comparison
  let aCode = UInt32('a')  // Character code for 'a'
  if (charCode >= aCode && charCode <= UInt32('z')) {
      // 处理小写字母
  }
  ```

### 构造函数
- 在构造函数中，必须先初始化所有成员变量，然后才能调用实例方法
- 示例：
  ```cangjie
  public init() {
      // 先初始化所有成员变量
      field1 = Value1()
      field2 = Value2()

      // 然后再调用方法
      initializeMappings()
  }
  ```

### 类型转换
- 仓颉语言中的类型转换使用 `as` 操作符，语法为 `(expression) as Type`，而不是方法调用形式 `_server.as(Type)`
- 示例：
  ```cangjie
  let server = _server as Server  // 正确的类型转换语法
  // 而不是 _server.as(Server)
  ```
- 类型转换操作符返回一个 `Option` 类型，必须用 `match` 来处理
- 示例：
  ```cangjie
  let result = value as Int32
  match (result) {
      case Some(num) => // 处理转换成功的情况
      case None => // 处理转换失败的情况
  }
  ```

### Option类型处理
- 仓颉语言中许多操作返回 `Option<T>` 类型（如类型转换 `(expression) as Type`）
- 必须使用 `match` 表达式处理 `Option<T>` 类型，不能直接使用返回值
- 示例：
  ```cangjie
  match (_server as Server) {
      case Some(server) => {
          // 使用转换成功的 server 对象
          server.get("/endpoint", handler)
      }
      case None => {
          // 处理转换失败的情况
          LogUtils.error("Failed to cast _server to Server type")
      }
  }
  ```
- 在函数中如果需要返回Option类型中的值，必须在match表达式的每个分支中都有返回或适当的处理

## 字符串操作

### 替换操作
- 使用 `replace(old: String, new: String): String` 方法替代 `replaceAll` 方法进行字符串替换操作
- 示例：`str.replace("\"", "\\\"")` 而不是 `str.replaceAll("\"", "\\\"")`

### 修剪操作
- 使用 `trimAscii(): String` 方法替代 `trim(): String` 方法进行字符串首尾空白字符修剪
- 示例：`str.trimAscii()` 而不是 `str.trim()`

### 分割操作
- `split` 方法只接受单个字符串作为分隔符，不支持数组形式的多个分隔符
- 示例：`str.split(" ")` 而不是 `str.split([" ", ":"])`

## 集合操作

### HashMap操作
- 使用 `add(key: K, value: V): Unit` 方法替代 `insert(key: K, value: V): Unit` 方法向HashMap添加键值对
- 示例：`map.add("key", "value")` 而不是 `map.insert("key", "value")`
- HashMap的entries字段是私有的，不能直接访问，应使用`iterator()`方法遍历
- 示例：`for ((key, value) in map.iterator())` 而不是 `for (entry in map.entries)`

## 数值类型处理

### 类型一致性
- 确保函数返回类型与实际返回值类型一致
- 显式声明变量类型以避免类型推断错误
- 示例：`var score: Int32 = 0` 而不是 `var score = 0`

## StringBuilder使用

### 方法调用
- StringBuilder类提供`append`方法用于追加各种类型的数据
- 可以链式调用，但建议分行书写以提高可读性
- 示例：
  ```cangjie
  let sb = StringBuilder()
  sb.append("Hello ")
  sb.append("World")
  let result = sb.toString()
  ```

## 枚举和模式匹配

### 枚举比较
- 枚举值比较应使用 `==` 操作符
- 示例：`value.kind == JsonKind.JsObject` 而不是 `value.kind.equals(JsonKind.JsObject)`
- 在match表达式中，分支使用 `=>` 语法，不要在分支内嵌套复杂的控制流
