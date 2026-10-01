# 仓颉语言指南

> 本文档是仓颉编程语言的快速参考指南，涵盖语言基础、类型系统、标准库、工具链等。

## 语言基础

### 变量定义

```cangjie
let x = 10          // 不可变变量
var y = 20          // 可变变量
const PI = 3.14     // 常量
```

### 控制流

```cangjie
// if-else 表达式（替代三元运算符）
let x = if (cond) { a } else { b }

// match 表达式
match (value) {
    case Some(v) => println(v)
    case None => println("none")
    case _ => println("default")
}

// for-in 循环
for (i in 0..10) {
    println(i)
}
```

### 关键约定（项目实测）

- **不支持三元运算符**：`cond ? a : b` 必须用 `if-else` 表达式替代
- **ArrayList 没有 append/add/push 方法**：向集合添加元素改用 `Array + 索引赋值`
- **`.size` 是属性不是方法**：使用 `arr.size` 而非 `arr.size()`
- **`Duration` 在 `std.core` 中**：不是 `std.time.Duration`
- **`JsonValue.parse(s)` 是正确的解析方法**：不是 `JsonValue.fromStr(s)`

## 类型系统

### 类与结构体

```cangjie
public class FieldInfo {
    public var columnName: String = ""
    public var dataType: String = ""
    public init() {}
}
```

### 接口

```cangjie
public interface Plugin {
    func getName(): String
    func onLoad(ctx: PluginContext): Unit
}
```

### 枚举

```cangjie
public enum PluginState {
    Pending | Loading | Active | Error | Disposed
}
```

### 泛型

```cangjie
public func getService<T>(): ?T where T <: Object {
    // ...
}
```

## 标准库

### 常用导入

```cangjie
import std.collection.{HashMap, ArrayList, Array}
import std.convert.*
import std.io.console
import std.fs.{File, Directory, Path}
import std.time.DateTime
import std.core.Duration
```

### Array

```cangjie
let arr = Array<Int64>(10, { _ => 0 })
arr[0] = 42
let slice = arr[0..5]
```

### HashMap

```cangjie
let map = HashMap<String, Int64>()
map["key"] = 42
```

### String

```cangjie
let s = "hello"
s.startsWith("he")
s.replace("l", "r")
s.split(",")
s.trimAscii()
s.isEmpty()
```

## 工具链

### cjpm（仓颉包管理器）

```bash
cjpm build          # 编译项目
cjpm run            # 运行可执行文件
cjpm test           # 运行测试
```

### 编译选项

| 选项 | 说明 |
|------|------|
| `--dy-std` | 动态链接标准库（动态库必需） |
| `-Woff all` | 关闭所有警告 |
| `-O2` | 优化级别 2 |

## JSON 处理

```cangjie
import jsonvalue.*

// 解析
let json = JsonValue.parse('{"key":"value"}')

// 构造
let m = HashMap<String, JsonValue>()
m["key"] = JsonValue.String("value")
let json = JsonValue.from(m)

// 匹配
match (json) {
    case JsonValue.Map(fields) => // ...
    case JsonValue.String(s) => // ...
    case JsonValue.Number(n) => // ...
    case JsonValue.Null => // ...
    case _ => // ...
}
```

## 仓颉代码编写工作流程

仓颉代码编写遵循四步工作流程：

1. **查阅 CangjieSkills 技能**：获取仓颉编程语言相关知识
2. **检索代码片段**：从项目已有代码中检索基本符合需求的代码
3. **编辑适配**：对检索到的代码进行二次编辑，使其完全符合项目需求
4. **写入文件**：输出编辑后的代码到项目的指定位置
