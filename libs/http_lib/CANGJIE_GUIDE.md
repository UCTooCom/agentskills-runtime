# 仓颉编程语言AI Agent编程指导

## 仓颉编程语言标准库概述

仓颉编程语言标准库（std）是安装仓颉 SDK 时默认自带的库。标准库预先定义了一组函数、类、结构体等，旨在提供常用的功能和工具，以便开发者能够更快速、更高效地编写程序。

### 使用指导

在仓颉编程语言中，标准库包含了若干包（package），而包是编译的最小单元。每个包可以单独输出 AST（Abstract Syntax Trees，抽象语法树）文件、静态库文件、动态库文件等产物。包可以定义子包，从而构成树形结构。没有父包的包称为 root 包，root 包及其子包（包括子包的子包）构成的整棵树称为模块（module）。模块的名称与 root 包相同，是开发者发布的最小单元。

#### 包的导入规则

可以导入某个包中的一个顶层声明或定义，语法如下：

```
import fullPackageName.itemName
```

其中 `fullPackageName` 为完整路径包名，`itemName` 为声明的名字，例如：

```
import std.collection.ArrayList
```

如果要导入的多个 `itemName` 同属于一个 `fullPackageName`，可以使用：

```
import fullPackageName.{itemName[, itemName]*}
```

例如：

```
import std.collection.{ArrayList, HashMap}
```

还可以将 `fullPackageName` 包中所有 public 修饰的顶层声明或定义全部导入，语法如下：

```
import fullPackageName.*
```

例如：

```
import std.collection.*
```

### 包列表

`std` 含若干包，提供丰富的基础功能：

| 包名 | 功能 |
| --- | --- |
| core | 包是标准库的核心包，提供了适用仓颉语言编程最基本的一些 API 能力。 |
| argopt | 包提供从命令行参数字符串解析出参数名和参数值的相关能力。 |
| ast | 包主要包含了仓颉源码的语法解析器和仓颉语法树节点，提供语法解析函数。 |
| binary | 包提供了基础数据类型和二进制字节数组的不同端序转换接口，以及端序反转接口。 |
| collection | 包提供了常见数据结构的高效实现、相关抽象的接口的定义以及在集合类型中常用的函数功能。 |
| collection.concurrent | 包提供了并发安全的集合类型实现。 |
| console | 包提供和标准输入、标准输出、标准错误进行交互的方法。 |
| convert | 包提供从字符串转到特定类型的 Convert 系列函数以及提供格式化能力，主要为将仓颉类型实例转换为格式化字符串。 |
| crypto.cipher | 包提供对称加解密通用接口。 |
| crypto.digest | 包提供常用摘要算法的通用接口，包括 MD5、SHA1、SHA224、SHA256、SHA384、SHA512、HMAC、SM3。 |
| database.sql | 包提供仓颉访问数据库的接口。 |
| deriving | 包提供一组宏来自动生成接口实现。 |
| env | 包提供当前进程的相关信息与功能，包括环境变量、命令行参数、标准流、退出程序。 |
| fs | 包提供对文件、文件夹、路径、文件元数据信息的一些操作函数。 |
| io | 包提供程序与外部设备进行数据交换的能力。 |
| math | 包提供常见的数学运算，常数定义，浮点数处理等功能。 |
| math.numeric | 包对基础类型可表达范围之外提供扩展能力。 |
| net | 包提供常见的网络通信功能。 |
| objectpool | 包提供了对象缓存和复用的功能。 |
| overflow | 包提供了溢出处理相关能力。 |
| posix | 包封装 POSIX 系统调用，提供跨平台的系统操作接口。 |
| process | 包主要提供 Process 进程操作接口，主要包括进程创建、标准流获取、进程等待、进程信息查询等。 |
| random | 包提供生成伪随机数的能力。 |
| reflect | 包提供了反射功能，使得程序在运行时能够获取到各种实例的类型信息，并进行各种读写和调用操作。 |
| regex | 包使用正则表达式分析处理文本的能力（支持 UTF-8 编码的 Unicode 字符串），支持查找、分割、替换、验证等功能。 |
| runtime | 包的作用是与程序的运行时环境进行交互，提供了一系列函数和变量，用于控制、管理和监视程序的执行。 |
| sort | 包提供数组类型的排序函数。 |
| sync | 包提供并发编程相关的能力。 |
| time | 包提供了与时间相关的类型，包括日期时间、时间间隔、单调时间和时区等，并提供了计算和比较的功能。 |
| unicode | 包提供了按 Unicode 编码标准处理字符的能力。 |
| unittest | 包用于编写仓颉项目单元测试代码，提供包括代码编写、运行和调测在内的基本功能。 |
| unittest.mock | 包提供仓颉单元测试的 mock 框架，提供 API 用于创建和配置 mock 对象，这些 mock 对象与真实对象拥有签名一致的 API。 |
| unittest.testmacro | 为单元测试框架提供了用户所需的宏。 |
| unittest.mock.mockmacro | 为 mock 框架提供了用户所需的宏。 |
| unittest.common | 为单元测试框架提供了打印所需的类型和一些通用方法。 |
| unittest.diff | 为单元测试框架提供了打印差异对比信息所需的 API。 |
| unittest.prop_test | 为单元测试框架提供了参数化测试所需的类型和一些通用方法。 |

## 字符串处理

- 获取字符数组应使用`String.toRuneArray()`而非`String.toArray()`，`String[n]`等效于`String.toArray()[n]`，`String[n..m]`等效于`String.toArray()[n..m]`
- 字符串长度获取应使用`String.toRuneArray().size`而非`String.size`
- `UInt8`等效于`Byte`,`Array<UInt8>`等效于`Array<Byte>`
- 字节数组转字符串为`String.fromUtf8(Array<UInt8>)`，字符数组转字符串为`String(Array<Rune>)`
- 字符串切割应使用`String(String.toRuneArray()[n..m])`
- 字符串拼接应改为`String(String.toRuneArray()[n..m]) + String`
- `String.toAsciiLower()`将该字符串中所有 Ascii 大写字母转化为 Ascii 小写字母
- `String.toAsciiUpper()`将该字符串中所有 Ascii 小写字母转化为 Ascii 大写字母
- `String.toAsciiTitle()`该函数只转换 Ascii 英文字符，当该英文字符是字符串中第一个字符或者该字符的前一个字符不是英文字符，则该字符大写，其他英文字符小写
- 使用`String.trimAscii`、`String.trimAsciiStart`、`String.trimAsciiEnd`、`String.trimStart`、`String.trimEnd`相关函数去除字符串前/后特定的字符/字符串，`String.trimAscii`等效于`String.trimAsciiStart`+`String.trimAsciiEnd`

## 其他语法

- `match` 的 `case` 后不能接`{}`, `case`后直接写多行列表式而不需要`{}`
- 单元测试使用`@Test`、`@TestCase`注解组合
- 基准测试使用`@Test`、`@Bench`注解组合
- 可以使用`if-let`表达式简化代码，`if (let Some(a) <- (fun() as Option<Int64>)) {}`、`if (let Some(a) <- b && a + b > 3) {}`、`if (let m <- 0..generateSomeInt()) {}`、`if (let Some(e) <- a && let Some(f) <- d) {}`、`if (let Some(f) <- d && f > 3) {}`、`if (let Some(_) <- a || let Some(_) <- d) {}`、`if (let Some(_) <- a || g > 1) {}`
- `Option<T>` 不支持 `==` 比较，使用 `.isSome()` / `.isNone()` 配合模式匹配
- 枚举必须显式实现 `==` 和 `!=`；若用作 `HashMap` 键，还需实现 `Hashable & Equatable`
- `panic()` 可能不可用，改用 `throw Exception(...)`。
- Lambda 语法: `{key, value => body}` — 无类型标注、无括号
- 命名参数: 构造函数参数需加 `!` 后缀才能以命名参数方式调用

## Agent工具/技能

- 使用 [`CangjieSkills`](https://gitcode.com/Cangjie-SIG/CangjieSkills) 技能和 [`cangjie-docs`](https://atomgit.com/Cangjie-SIG/cangjie-docs-mcp) MCP 进行 API/文档查找——不要猜测 API
- 在 `cangjie-mem` 没有的直接在文档里查找，不要猜api和语法
- 在提示语法错误时重新使用 `cangjie-mem` 加载语言级记忆
- 在上下文压缩后，如果没有仓颉语法相关的，需要马上使用 `cangjie_mem_list` 工具加载所有仓颉语言级记忆

## 工具链

- 使用`cjfmt`工具格式化文件，使用命令行操作`cjfmt [option] file [option] file`，获取帮助信息`cjfmt -h`，文件格式化`cjfmt -f`，文件夹格式化`cjfmt -d`，格式化配置文件`cjfmt -c`
- 使用`cjlint`进行静态检查，获取帮助信息`cjlint -h`，检查指定目录`cjlint -f`

## 任务指南

- **不要考虑时间，不要简化算法，不要简化测试，按最佳效果进行实现**
- 在实现功能总结后，需记录到`cangjie-mem`项目级记忆里
- 新功能、新特性一定要写单元测试，原则上每个公共函数`public func`有一个或多个单元测试
- 不要在项目外创建仓颉单文件测试，非cjpm项目没法导入当前项目
- 新功能需要做好，且有单元测试后提交, 以仓颉单元测试为主
- 测试发现的新问题需要解决，且要添加新用例到仓颉的单元测试里
- 测试出现语法问题不通过时，可以使用`cangjie_docs`相关工具在手册或lib std查找解决方法
- 需格式化所有`*.cj`文件和项目配置文件
