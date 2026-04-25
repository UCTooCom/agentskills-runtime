---
name: cangjie-coder
description: 仓颉代码编写技能。当用户需要编写、修改、重构或优化任何 .cj 仓颉代码文件时,必须使用此技能。包括新建仓颉文件、修改现有代码、重构代码结构、优化代码性能、修复代码错误等所有涉及仓颉代码的操作。遵循四步工作流程:查阅CangjieSkills技能 → 检索代码片段 → 编辑适配 → 写入文件。此技能确保所有仓颉代码完全符合语言规范,并提供最佳实践指导。
version: 2.1.0
author: OpenCangjie Team
dependencies:
  - cangjie-language-guide
  - cangjie-full-docs
---

# Cangjie Coder 技能

## 概述

本技能用于编写、修改、重构和优化符合仓颉(Cangjie)编程语言规范的高质量代码文件(.cj 后缀)。通过整合 CangjieSkills 官方文档资源和代码片段库,确保所有仓颉代码既符合规范又遵循最佳实践。

**适用场景**:
- ✅ 新建仓颉代码文件
- ✅ 修改现有仓颉代码
- ✅ 重构仓颉代码结构
- ✅ 优化仓颉代码性能
- ✅ 修复仓颉代码错误
- ✅ 添加新功能到现有代码
- ✅ 改进代码质量和可维护性

**核心工作流程**: 查阅文档 → 检索代码 → 编辑适配 → 写入文件

## 关键约束

- ⚠️ **必须先查阅文档**: 在编写任何仓颉代码前,必须先查阅 CangjieSkills 技能获取语言规范和最佳实践
- ⚠️ **禁止直接生成代码**: 不得直接使用大模型生成仓颉代码,必须先检索现有代码片段或参考文档示例
- ⚠️ **必须符合规范**: 所有 .cj 文件必须符合仓颉词法和语法规范
- ⚠️ **工作流程**: 查阅(Consult) → 检索(Retrieval) → 编辑(Editing) → 写入(Writing)
- ⚠️ **适用所有场景**: 新建、修改、重构、优化、修复等所有涉及仓颉代码的操作都必须使用此技能

---

## 配置项

### CangjieSkills 技能路径

```
CANGJIE_SKILLS_PATH: D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\CangjieSkills\.opencode\skills
```

### 仓颉编程资料目录

```
CANGJIE_CODE_REPOSITORY: D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\CangjieMagic\resource
```

**重要**: 
- CangjieSkills 技能路径用于查阅官方文档和语言规范
- 仓颉编程资料目录用于检索现有代码片段
- 两个路径可在使用本技能时由用户配置

### 跨平台路径处理

- **Windows 系统**: 使用双反斜杠 `\\` 作为路径分隔符
- **Linux/Mac 系统**: 使用正斜杠 `/` 作为路径分隔符

---

## 四步工作流程

### 步骤 1: 查阅 CangjieSkills 文档 (Consult)

**目的**: 获取仓颉语言规范、最佳实践和 API 文档

#### 1.1 确定需求主题

根据用户请求,确定需要查阅的主题:

| 需求类型 | 查阅主题 | 参考文档路径 |
|---------|---------|-------------|
| 基础语法 | 语言基础 | `cangjie-language-guide/SKILL.md#1-语言基础` |
| 类型定义 | 类型系统 | `cangjie-language-guide/SKILL.md#2-类型系统` |
| 函数编写 | 函数与闭包 | `cangjie-language-guide/SKILL.md#3-函数与闭包` |
| 标准库使用 | 标准库 | `cangjie-language-guide/SKILL.md#4-标准库` |
| 工具使用 | 工具链 | `cangjie-language-guide/SKILL.md#5-工具链` |
| 高级特性 | 高级特性 | `cangjie-language-guide/SKILL.md#6-高级特性` |
| 错误处理 | 错误处理与调试 | `cangjie-language-guide/SKILL.md#7-错误处理与调试` |
| 代码质量 | 最佳实践 | `cangjie-language-guide/SKILL.md#8-最佳实践` |

#### 1.2 查阅主文档

使用 `file_read` 工具查阅 `cangjie-language-guide/SKILL.md`:

```json
{
  "toolcall": {
    "thought": "查阅仓颉语言指南中的HTTP服务器相关内容",
    "name": "file_read",
    "params": {
      "path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\CangjieSkills\\.opencode\\skills\\cangjie-language-guide\\SKILL.md"
    }
  }
}
```

#### 1.3 查阅参考文档

如需深入了解特定主题,查阅 `references/` 目录:

```json
{
  "toolcall": {
    "thought": "查阅HTTP服务器的详细文档",
    "name": "file_read",
    "params": {
      "path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\CangjieSkills\\.opencode\\skills\\cangjie-language-guide\\references\\http_server\\SKILL.md"
    }
  }
}
```

**参考文档索引**:
- **语言基础**: `basic_data_type/`, `function/`, `const/`, `for/`, `pattern_match/`, `error_handle/`, `concurrency/`, `ffi/`
- **类型系统**: `class/`, `struct/`, `enum/`, `interface/`, `generic/`, `extend/`, `type_system/`
- **标准库**: `array/`, `arraylist/`, `hashmap/`, `hashset/`, `string/`, `option/`, `fs/`, `iostream/`, `json/`, `socket/`
- **工具链**: `project_management/`, `compile/`, `cjc/`, `cjfmt/`, `cjlint/`, `unittest/`
- **高级特性**: `macro/`, `reflect_and_annotation/`, `http_client/`, `http_server/`, `websocket/`, `tls/`

#### 1.4 提取关键信息

从文档中提取:
- ✅ 语法规范和关键字
- ✅ API 使用方法
- ✅ 最佳实践建议
- ✅ 常见错误和注意事项
- ✅ 代码示例

---

### 步骤 2: 检索代码片段 (Retrieval)

**目的**: 从代码片段库中找到可复用的代码基础

#### 2.1 确定搜索关键词

基于步骤 1 的文档查阅结果,确定搜索关键词:

**关键词选择策略**:
1. **功能关键词**: 具体功能名称 (如 "HttpServer", "WebSocket", "HashMap")
2. **语法关键词**: 语法结构 (如 "class", "func", "import", "package")
3. **标准库关键词**: 标准库模块 (如 "std.net.http", "std.collection")
4. **组合关键词**: 功能 + 语法 (如 "HttpServer class", "func listen")

#### 2.2 执行搜索

使用 `file_search` 工具搜索代码片段:

```json
{
  "toolcall": {
    "thought": "搜索包含HTTP服务器功能的仓颉代码片段",
    "name": "file_search",
    "params": {
      "path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\CangjieMagic\\resource",
      "query": "HttpServer",
      "recursive": true,
      "caseSensitive": false,
      "filePattern": "*.cj"
    }
  }
}
```

#### 2.3 筛选结果

**筛选标准**:
1. **相关性**: 代码是否实现了所需功能
2. **质量**: 代码结构是否清晰,注释是否完整
3. **规范性**: 代码是否符合仓颉语法规范
4. **可维护性**: 代码是否易于修改和扩展

**优先级排序**:
1. 完全匹配需求的代码
2. 部分匹配但易于修改的代码
3. 通用性强可作为基础的代码

#### 2.4 读取选中代码

使用 `file_read` 工具读取选中的代码片段:

```json
{
  "toolcall": {
    "thought": "读取选中的HTTP服务器代码片段",
    "name": "file_read",
    "params": {
      "path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\CangjieMagic\\resource\\http_server.cj"
    }
  }
}
```

---

### 步骤 3: 编辑适配 (Editing)

**目的**: 根据项目需求和最佳实践修改代码片段

#### 3.1 分析原始代码

对照步骤 1 查阅的文档,分析原始代码:
- ✅ 检查语法是否符合规范
- ✅ 检查是否遵循最佳实践
- ✅ 检查是否有潜在问题
- ✅ 确定需要修改的部分

#### 3.2 应用最佳实践

根据 CangjieSkills 文档中的最佳实践:

**代码风格**:
- 使用有意义的变量名和函数名
- 添加必要的注释和文档
- 遵循仓颉命名规范 (驼峰命名)
- 保持代码缩进和格式一致

**性能优化**:
- 避免不必要的对象创建
- 使用合适的数据结构
- 合理使用不可变变量 (let)
- 注意内存管理

**错误处理**:
- 使用 Option 类型处理可能为空的值
- 使用 try-catch 处理异常
- 提供有意义的错误信息
- 避免忽略错误

**安全性**:
- 验证输入参数
- 避免资源泄漏
- 使用安全的 API
- 处理边界情况

#### 3.3 修改代码

根据项目需求修改代码:

**常见修改类型**:
1. **调整函数签名**: 修改参数类型、返回类型
2. **修改类型声明**: 调整类、结构体定义
3. **适配命名规范**: 修改变量名、函数名
4. **添加功能**: 增加新的方法或属性
5. **优化性能**: 改进算法或数据结构
6. **增强错误处理**: 添加异常处理和验证

**修改示例**:

原始代码:
```cangjie
func startServer(port: Int): Unit {
  let server = http.HttpServer()
  server.listen(port)
  println("Server started")
}
```

修改后代码:
```cangjie
/// 启动HTTP服务器
/// 
/// 参数:
///   - port: 监听端口号,有效范围 1-65535
/// 
/// 返回:
///   - Option<HttpServer>: 成功返回服务器实例,失败返回 None
func startServer(port: Int): Option<HttpServer> {
  // 参数验证
  if (port < 1 || port > 65535) {
    println("Error: Invalid port number ${port}")
    return None
  }
  
  // 创建服务器
  let server = HttpServer()
  
  // 启动监听
  try {
    server.listen(port)
    println("HTTP Server started on port ${port}")
    return Some(server)
  } catch (e: Exception) {
    println("Error: Failed to start server - ${e.message}")
    return None
  }
}
```

#### 3.4 验证语法

确保修改后的代码符合仓颉语法规范:

**词法验证**:
- [ ] 标识符命名符合规范
- [ ] 关键字使用正确
- [ ] 字符串格式正确
- [ ] 注释格式正确

**语法验证**:
- [ ] 包声明正确
- [ ] 导入语句正确
- [ ] 函数定义格式正确
- [ ] 变量声明格式正确
- [ ] 控制语句结构正确
- [ ] 类定义格式正确

**语义验证**:
- [ ] 函数调用参数正确
- [ ] 变量使用合理
- [ ] 错误处理完善
- [ ] 代码逻辑清晰

---

### 步骤 4: 写入文件 (Writing)

**目的**: 将修改后的代码写入正确的文件位置

#### 4.1 确定文件路径

根据项目结构确定文件路径:

**路径规划原则**:
1. **按功能模块组织**: 相关功能放在同一目录
2. **遵循项目约定**: 遵循现有项目的目录结构
3. **便于维护**: 路径清晰,易于查找
4. **避免冲突**: 不覆盖现有文件

**常见目录结构**:
```
project/
├── src/
│   ├── main.cj          # 主入口
│   ├── api/             # API 相关
│   │   ├── http_server.cj
│   │   └── websocket.cj
│   ├── models/          # 数据模型
│   │   ├── user.cj
│   │   └── product.cj
│   ├── services/        # 业务逻辑
│   │   └── auth.cj
│   └── utils/           # 工具函数
│       └── helper.cj
└── tests/
    └── test_main.cj     # 测试文件
```

#### 4.2 创建目录结构

使用 `directory_create` 工具创建必要的目录:

```json
{
  "toolcall": {
    "thought": "创建API模块的目录结构",
    "name": "directory_create",
    "params": {
      "path": "D:\\project\\src\\api",
      "recursive": true
    }
  }
}
```

#### 4.3 写入代码文件

使用 `file_write` 工具写入 .cj 文件:

```json
{
  "toolcall": {
    "thought": "写入修改后的HTTP服务器代码",
    "name": "file_write",
    "params": {
      "path": "D:\\project\\src\\api\\http_server.cj",
      "content": "// HTTP服务器模块\npackage api\n\nimport std.net.http\n\n/// 启动HTTP服务器\nfunc startServer(port: Int): Option<HttpServer> {\n  // 实现代码...\n}\n",
      "mode": "create"
    }
  }
}
```

#### 4.4 验证写入结果

确认文件已正确创建:
- ✅ 文件路径正确
- ✅ 文件内容完整
- ✅ 文件编码正确 (UTF-8)
- ✅ 文件权限正确

---

## 完整使用示例

### 示例 1: 生成 HTTP 服务器代码

**用户请求**: 生成一个监听 8080 端口的 HTTP 服务器代码

#### 步骤 1: 查阅文档

```json
{
  "toolcall": {
    "thought": "查阅仓颉语言指南中的HTTP服务器相关内容",
    "name": "file_read",
    "params": {
      "path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\CangjieSkills\\.opencode\\skills\\cangjie-language-guide\\references\\http_server\\SKILL.md"
    }
  }
}
```

**提取关键信息**:
- 使用 `std.net.http` 模块
- 创建 `HttpServer` 实例
- 使用 `listen(port)` 方法
- 需要处理异常情况

#### 步骤 2: 检索代码

```json
{
  "toolcall": {
    "thought": "搜索HTTP服务器代码片段",
    "name": "file_search",
    "params": {
      "path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\CangjieMagic\\resource",
      "query": "HttpServer listen",
      "recursive": true,
      "filePattern": "*.cj"
    }
  }
}
```

#### 步骤 3: 编辑适配

读取并修改代码,添加:
- 参数验证
- 错误处理
- 详细注释
- 最佳实践

#### 步骤 4: 写入文件

```json
{
  "toolcall": {
    "thought": "写入HTTP服务器代码",
    "name": "file_write",
    "params": {
      "path": "D:\\project\\src\\api\\http_server.cj",
      "content": "package api\n\nimport std.net.http\n\n/// HTTP服务器模块\n/// 提供HTTP服务器的创建和启动功能\n\n/// 启动HTTP服务器\n/// \n/// 参数:\n///   - port: 监听端口号,有效范围 1-65535\n/// \n/// 返回:\n///   - Option<HttpServer>: 成功返回服务器实例,失败返回 None\npublic func startServer(port: Int): Option<HttpServer> {\n  // 参数验证\n  if (port < 1 || port > 65535) {\n    println(\"Error: Invalid port number ${port}\")\n    return None\n  }\n  \n  // 创建服务器实例\n  let server = HttpServer()\n  \n  // 启动监听\n  try {\n    server.listen(port)\n    println(\"HTTP Server started on port ${port}\")\n    return Some(server)\n  } catch (e: Exception) {\n    println(\"Error: Failed to start server - ${e.message}\")\n    return None\n  }\n}\n\n/// 主函数\nmain() {\n  let result = startServer(8080)\n  match (result) {\n    case Some(server) => println(\"Server is running\")\n    case None => println(\"Failed to start server\")\n  }\n}\n",
      "mode": "create"
    }
  }
}
```

---

### 示例 2: 生成数据模型类

**用户请求**: 生成一个 User 数据模型类,包含 id、name、email 字段

#### 步骤 1: 查阅文档

查阅 `cangjie-language-guide/references/class/SKILL.md` 了解:
- class 定义语法
- 成员变量声明
- 构造函数定义
- 属性访问器

#### 步骤 2: 检索代码

搜索 "class User" 或 "data model" 相关代码片段

#### 步骤 3: 编辑适配

根据最佳实践修改:
- 使用 `public` 修饰符
- 添加构造函数
- 添加属性访问器
- 添加文档注释

#### 步骤 4: 写入文件

```cangjie
package models

/// 用户数据模型
/// 
/// 表示系统中的用户实体
public class User {
  /// 用户唯一标识
  public let id: Int64
  
  /// 用户名
  public mut prop name: String
  
  /// 用户邮箱
  public mut prop email: String
  
  /// 构造函数
  /// 
  /// 参数:
  ///   - id: 用户ID
  ///   - name: 用户名
  ///   - email: 用户邮箱
  public init(id: Int64, name: String, email: String) {
    this.id = id
    this.name = name
    this.email = email
  }
  
  /// 验证邮箱格式
  /// 
  /// 返回:
  ///   - Bool: 邮箱格式是否有效
  public func validateEmail(): Bool {
    // 简单的邮箱格式验证
    email.contains("@") && email.contains(".")
  }
}
```

---

## 错误处理指导

### 检索失败处理

当在代码片段库中检索不到相关代码时:

#### 策略 1: 扩展搜索范围
- 扩大搜索关键词范围
- 搜索更通用的功能描述
- 检查目录路径是否正确

#### 策略 2: 基于文档生成
- 如果检索失败,基于 CangjieSkills 文档生成代码
- 严格遵循文档中的语法规范和最佳实践
- 添加详细注释说明代码来源

#### 策略 3: 降级处理
- 向用户说明检索失败的原因
- 告知用户将使用文档指导生成代码
- 提供代码验证建议

### 写入失败处理

当写入文件失败时:

1. **权限检查**: 确保运行时具有文件写入权限
2. **路径验证**: 检查目标路径是否存在且可写
3. **重试机制**: 尝试创建父目录后重试写入
4. **错误报告**: 向用户报告具体的写入错误信息

---

## 代码质量保证

### 质量检查清单

#### 语法规范
- [ ] 使用正确的关键字和标识符
- [ ] 包声明和导入语句正确
- [ ] 函数和变量声明格式正确
- [ ] 控制语句结构正确

#### 最佳实践
- [ ] 使用有意义的命名
- [ ] 添加必要的注释和文档
- [ ] 遵循仓颉命名规范
- [ ] 保持代码格式一致

#### 错误处理
- [ ] 使用 Option 类型处理可能为空的值
- [ ] 使用 try-catch 处理异常
- [ ] 提供有意义的错误信息
- [ ] 验证输入参数

#### 性能优化
- [ ] 避免不必要的对象创建
- [ ] 使用合适的数据结构
- [ ] 合理使用不可变变量
- [ ] 注意内存管理

### 推荐验证工具

- **仓颉编译器**: 使用 `cjpm build` 命令编译代码
- **代码格式化**: 使用 `cjfmt` 格式化代码
- **静态分析**: 使用 `cjlint` 检查代码质量
- **单元测试**: 使用 `cjpm test` 运行测试

---

## 工具使用指南

### 推荐工具

1. **file_read**: 读取 CangjieSkills 文档和代码片段
2. **file_search**: 在代码片段库中搜索相关代码
3. **file_write**: 将修改后的代码写入目标文件
4. **directory_create**: 创建必要的目录结构

### 工具调用顺序

```
1. file_read (查阅 CangjieSkills 文档)
   ↓
2. file_search (检索代码片段)
   ↓
3. file_read (读取选中的代码片段)
   ↓
4. file_write (写入修改后的代码)
```

---

## 版本兼容性说明

- **仓颉语言版本**: 支持 0.53.18 及以上版本
- **CangjieSkills 版本**: v1.1.0 及以上
- **运行时依赖**: 需要 agentskills-runtime 1.0.0 及以上版本
- **工具依赖**: 需要 file_read、file_search、file_write、directory_create 工具

---

## 注意事项

1. **必须先查阅文档**: 在生成代码前,必须先查阅 CangjieSkills 技能获取规范
2. **路径格式**: 在 Windows 系统上,文件路径需要使用双反斜杠 `\\`
3. **编码规范**: 确保所有生成的代码符合仓颉编程语言的词法和语法规范
4. **文件扩展名**: 仓颉代码文件必须使用 `.cj` 扩展名
5. **目录配置**: 用户可以配置 CangjieSkills 路径和代码片段库路径
6. **错误处理**: 当检索失败时,使用文档指导生成代码
7. **代码验证**: 使用仓颉编译器验证生成的代码
8. **最佳实践**: 始终遵循 CangjieSkills 文档中的最佳实践

---

## 适用场景详解

### 场景 1: 新建仓颉代码文件

**触发条件**: 用户请求创建新的 .cj 文件

**示例**:
- "创建一个 HTTP 服务器代码"
- "新建一个 User 数据模型类"
- "生成一个工具函数文件"

**工作流程**:
1. 查阅 CangjieSkills 文档了解相关 API
2. 检索代码片段库找到参考代码
3. 编辑适配为新代码
4. 写入新文件

### 场景 2: 修改现有仓颉代码

**触发条件**: 用户请求修改现有的 .cj 文件

**示例**:
- "修改 http_server.cj,添加日志功能"
- "更新 User 类,增加 age 字段"
- "修改函数签名,增加新参数"

**工作流程**:
1. 查阅 CangjieSkills 文档了解修改涉及的 API
2. 读取现有代码文件
3. 检索相关代码片段作为参考
4. 编辑修改代码,确保符合规范
5. 写入修改后的文件

### 场景 3: 重构仓颉代码结构

**触发条件**: 用户请求重构现有代码

**示例**:
- "重构 User 类,拆分为多个小类"
- "优化代码结构,提取公共方法"
- "重命名变量和函数,改进命名规范"

**工作流程**:
1. 查阅 CangjieSkills 文档了解最佳实践
2. 读取现有代码文件
3. 分析代码结构和依赖关系
4. 按照最佳实践重构代码
5. 验证重构后的代码符合规范
6. 写入重构后的文件

### 场景 4: 优化仓颉代码性能

**触发条件**: 用户请求优化代码性能

**示例**:
- "优化这个排序算法的性能"
- "减少内存分配,提高效率"
- "使用更高效的数据结构"

**工作流程**:
1. 查阅 CangjieSkills 文档了解性能优化建议
2. 读取现有代码文件
3. 分析性能瓶颈
4. 应用性能优化技术
5. 验证优化后的代码正确性
6. 写入优化后的文件

### 场景 5: 修复仓颉代码错误

**触发条件**: 用户请求修复代码错误或 bug

**示例**:
- "修复这个空指针异常"
- "修正类型不匹配错误"
- "解决编译错误"

**工作流程**:
1. 查阅 CangjieSkills 文档了解错误处理机制
2. 读取现有代码文件
3. 分析错误原因
4. 应用正确的修复方案
5. 验证修复后的代码
6. 写入修复后的文件

### 场景 6: 添加新功能

**触发条件**: 用户请求在现有代码中添加新功能

**示例**:
- "在 User 类中添加验证方法"
- "为 HTTP 服务器添加中间件支持"
- "增加新的 API 端点"

**工作流程**:
1. 查阅 CangjieSkills 文档了解新功能的实现方式
2. 读取现有代码文件
3. 检索相关代码片段
4. 编辑添加新功能代码
5. 确保新代码与现有代码兼容
6. 写入更新后的文件

### 场景 7: 改进代码质量

**触发条件**: 用户请求改进代码质量

**示例**:
- "添加详细的文档注释"
- "改进错误处理机制"
- "增强代码可读性"

**工作流程**:
1. 查阅 CangjieSkills 文档了解最佳实践
2. 读取现有代码文件
3. 应用代码质量改进
4. 验证改进后的代码
5. 写入改进后的文件

---

## 参考文档

### CangjieSkills 文档

- **主文档**: `cangjie-language-guide/SKILL.md`
- **参考文档**: `cangjie-language-guide/references/`
- **原始文档**: `cangjie-full-docs/SKILL.md`

### 官方文档

- [仓颉词法结构文档](https://cangjie-lang.cn/docs?url=%2FSpec%2Fsource_zh_cn%2FChapter_01_Lexical_Structure%28zh%29.html)
- [仓颉语法文档](https://cangjie-lang.cn/docs?url=%2FSpec%2Fsource_zh_cn%2FChapter_Appendix_A%28zh%29.html)
- [仓颉标准库文档](https://cangjie-lang.cn/docs/standard_library)

---

## 更新日志

### v2.1.0 (2026-03-13)

**重大更新**:
- ✨ 扩展适用场景:从代码生成扩展到所有仓颉代码编写场景
- ✨ 新增 7 种适用场景详解
- ✨ 更新描述字段,覆盖新建、修改、重构、优化、修复等所有操作

**改进**:
- 📚 更全面的触发条件
- 📚 更详细的工作流程说明
- 📚 更清晰的场景分类

### v2.0.0 (2026-03-13)

**重大更新**:
- ✨ 新增四步工作流程: 查阅 → 检索 → 编辑 → 写入
- ✨ 整合 CangjieSkills 官方文档资源
- ✨ 添加最佳实践指导
- ✨ 增强错误处理和验证
- ✨ 提供完整的代码示例

**改进**:
- 📚 从三步工作流程升级为四步工作流程
- 📚 新增 CangjieSkills 文档查阅步骤
- 📚 增强代码质量保证机制
- 📚 提供更详细的错误处理指导

### v1.1.0

- 初始版本,实现三步工作流程
- 基础的代码检索和生成功能
