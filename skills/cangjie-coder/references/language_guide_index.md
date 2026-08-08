# 仓颉语言指南索引

本文件索引CangjieSkills技能中的仓颉语言文档，供doc-consultant subagent快速定位参考文档。

## CangjieSkills路径

```
D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\CangjieSkills\.opencode\skills\cangjie-language-guide\
```

## 主文档

| 文件 | 描述 |
|------|------|
| `SKILL.md` | 仓颉编程语言完整指南，涵盖所有核心内容 |

## 参考文档索引

### 语言基础

| 目录 | 主题 | 关键内容 |
|------|------|---------|
| `references/basic_data_type/` | 基本数据类型 | Int8/16/32/64, Float16/32/64, Bool, Rune, String, Unit |
| `references/function/` | 函数 | func定义, 默认参数, 可变参数, Lambda, 闭包, 高阶函数 |
| `references/const/` | 常量 | const编译时常量, let不可变变量 |
| `references/for/` | 循环 | for-in, while, do-while, break, continue, 范围遍历 |
| `references/pattern_match/` | 模式匹配 | match表达式, case分支, 通配符, 解构 |
| `references/error_handle/` | 错误处理 | try-catch-finally, throw, Option<T> |
| `references/concurrency/` | 并发编程 | spawn, Future, Mutex, AtomicInt64, SyncCounter |
| `references/ffi/` | 外部函数接口 | foreign func, C互操作 |

### 类型系统

| 目录 | 主题 | 关键内容 |
|------|------|---------|
| `references/class/` | 类 | class定义, open/abstract/public修饰符, prop属性, init构造 |
| `references/struct/` | 结构体 | struct定义, 值类型, 不支持继承 |
| `references/enum/` | 枚举 | enum定义, 关联值, 成员函数 |
| `references/interface/` | 接口 | interface定义, 默认实现, 多接口继承 |
| `references/generic/` | 泛型 | 泛型函数, 泛型类, where约束 |
| `references/extend/` | 扩展 | extend扩展类型, 添加方法 |
| `references/type_system/` | 类型系统 | 值类型/引用类型, 类型转换, as操作符 |

### 标准库

| 目录 | 主题 | 关键内容 |
|------|------|---------|
| `references/array/` | 数组 | Array<T>, 创建/访问/修改, map/filter/fold |
| `references/arraylist/` | 动态数组 | ArrayList<T>, add/remove, 随机访问 |
| `references/hashmap/` | 哈希映射 | HashMap<K,V>, add/get/remove, 遍历 |
| `references/hashset/` | 哈希集合 | HashSet<T>, add/contains, 集合运算 |
| `references/string/` | 字符串 | String, 拼接/分割/替换/查找, 字符串插值 |
| `references/option/` | 可选类型 | Option<T>(?T), Some/None, getOrDefault, 模式匹配 |
| `references/fs/` | 文件系统 | File.readFrom/writeTo, Directory.create/list/delete |
| `references/iostream/` | 输入输出 | print/println/readln, 文件流 |
| `references/json/` | JSON处理 | JsonValue.parse, JsonObject, asString/asInt64 |
| `references/socket/` | 套接字 | TCP/UDP Socket, 网络通信 |

### 工具链

| 目录 | 主题 | 关键内容 |
|------|------|---------|
| `references/project_management/` | 项目管理 | cjpm.toml, 依赖管理, workspace |
| `references/compile/` | 编译 | cjpm build, cjc编译器, 条件编译 |
| `references/cjc/` | 编译器 | cjc命令行选项, 输出配置 |
| `references/cjfmt/` | 代码格式化 | cjfmt格式化代码 |
| `references/cjlint/` | 代码检查 | cjlint静态分析 |
| `references/unittest/` | 单元测试 | @Test, @Expect, @Assert, Mock框架 |

### 高级特性

| 目录 | 主题 | 关键内容 |
|------|------|---------|
| `references/macro/` | 宏编程 | macro定义, quote表达式 |
| `references/reflect_and_annotation/` | 反射与注解 | TypeInfo, 自定义注解, @Annotation |
| `references/http_client/` | HTTP客户端 | HttpClient, get/post请求 |
| `references/http_server/` | HTTP服务器 | HttpServer, 路由注册, 请求处理 |
| `references/websocket/` | WebSocket | WebSocket服务器/客户端 |
| `references/tls/` | TLS/SSL | 安全传输层 |

## 命名规范速查

| 类型 | 规范 | 示例 |
|------|------|------|
| 包名 | 小写点分隔 | `magic.app.models.uctoo` |
| 类名 | PascalCase | `AgentTeam`, `TeamManager` |
| 函数名 | camelCase | `findById`, `executeTeam` |
| 变量名 | camelCase | `teamConfig`, `agentList` |
| 常量名 | PascalCase或全大写 | `MaxRetries`, `DEFAULT_PORT` |
| 枚举值 | PascalCase | `Color.Red`, `Status.Active` |

## 常用类型速查

| 用途 | 类型 | 示例 |
|------|------|------|
| 整数 | Int64 | `var count: Int64 = 0` |
| 浮点数 | Float64 | `var score: Float64 = 0.0` |
| 布尔 | Bool | `var active: Bool = true` |
| 字符串 | String | `var name: String = ""` |
| 可选值 | Option<T> / ?T | `var result: ?Int64 = None` |
| 动态数组 | ArrayList<T> | `var list = ArrayList<Int64>()` |
| 映射 | HashMap<K,V> | `var map = HashMap<String, Int64>()` |
| 集合 | HashSet<T> | `var set = HashSet<Int64>()` |
| JSON | JsonValue | `var json = JsonValue.parse(str)` |