---
name: cangjie-coder
description: 仓颉代码生成技能。当用户请求生成以 .cj 为后缀名的仓颉代码时，必须使用此技能。遵循检索-编辑-写入的工作流程：首先从仓颉编程资料目录检索相关代码片段，然后根据仓颉词法和语法规范编辑修改，最后写入正确的文件位置。此技能确保生成的代码完全符合仓颉编程语言规范。
version: 1.1.0
author: Cangjie Team
---

# Cangjie Coder 技能

## 概述

本技能用于生成符合仓颉(Cangjie)编程语言规范的代码文件（.cj 后缀）。

**核心工作流程**：检索 → 编辑 → 写入

## 关键约束

- ⚠️ **禁止直接生成代码**：不得直接使用大模型生成仓颉代码，必须先检索现有代码片段
- ⚠️ **必须符合规范**：所有生成的 .cj 文件必须符合仓颉词法和语法规范
- ⚠️ **工作流程**：检索(Retrieval) → 编辑(Editing) → 写入(Writing)

---

## 配置项

### 仓颉编程资料目录

```
CANGJIE_CODE_REPOSITORY: D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\CangjieMagic\resource
```

**重要**：此目录路径可在使用本技能时由用户配置。默认路径为 `./cangjie-codes`。

### 跨平台路径处理

**Windows 系统**：使用双反斜杠 `\\` 作为路径分隔符
**Linux/Mac 系统**：使用正斜杠 `/` 作为路径分隔符

**环境变量检测**：优先使用 `CANGJIE_CODE_REPOSITORY` 环境变量，其次使用默认路径。

---

## 工作流程

### 步骤 1：检索代码片段 (Retrieval)

1. **确定需求**：分析用户请求，确定需要生成什么样的仓颉代码
2. **检索匹配**：在仓颉编程资料目录中搜索相关的代码片段
   - 使用 `file_search` 工具进行递归搜索
   - 搜索关键词：函数名、类型名、功能描述等
3. **筛选结果**：选择最符合需求的代码片段作为基础

**检索策略**：
- **关键词选择**：
  - 使用具体的功能关键词（如 "HttpServer"、"WebSocket"）
  - 结合语法结构关键词（如 "class"、"func"、"import"）
  - 使用项目特定的命名规范关键词

- **结果筛选**：
  - 按相关性排序：优先选择与需求最匹配的代码
  - 按代码质量筛选：选择结构清晰、注释完整的代码
  - 按文件大小筛选：优先选择适中长度的代码片段

- **相关性判断**：
  - 功能匹配度：代码是否实现了所需功能
  - 结构匹配度：代码结构是否符合项目需求
  - 规范符合性：代码是否符合仓颉语法规范

**检索示例**：
```json
{
  "toolcall": {
    "thought": "搜索包含HTTP服务器功能的仓颉代码片段",
    "name": "file_search",
    "params": {
      "path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\CangjieMagic",
      "query": "HttpServer",
      "recursive": true,
      "caseSensitive": false,
      "filePattern": "*.cj"
    }
  }
}
```

### 步骤 2：编辑代码片段 (Editing)

1. **读取原始代码**：使用 `file_read` 工具读取选中的代码片段
2. **分析规范**：根据仓颉词法和语法规范检查代码
   - 词法规范参考：https://cangjie-lang.cn/docs?url=%2FSpec%2Fsource_zh_cn%2FChapter_01_Lexical_Structure%28zh%29.html
   - 语法规范参考：https://cangjie-lang.cn/docs?url=%2FSpec%2Fsource_zh_cn%2FChapter_Appendix_A%28zh%29.html
3. **修改适配**：根据项目需求修改代码片段
   - 调整函数签名和参数
   - 修改类型声明
   - 适配项目特定的命名规范
4. **验证语法**：确保修改后的代码符合仓颉语法规范

**编辑示例**：
```json
{
  "toolcall": {
    "thought": "读取选中的HTTP服务器代码片段",
    "name": "file_read",
    "params": {
      "path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\CangjieMagic\\src\\api\\http_server.cj"
    }
  }
}
```

### 步骤 3：写入文件 (Writing)

1. **确定路径**：根据项目结构确定正确的文件路径
2. **创建目录**：使用 `directory_create` 创建必要的目录
3. **写入代码**：使用 `file_write` 工具写入 .cj 文件
4. **验证结果**：确认文件已正确创建

**写入示例**：
```json
{
  "toolcall": {
    "thought": "写入修改后的HTTP服务器代码",
    "name": "file_write",
    "params": {
      "path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\src\\api\\http_server.cj",
      "content": "// 符合仓颉规范的HTTP服务器代码\nimport std.net.http\n\nfunc startServer(port: Int): Unit {\n  let server = http.HttpServer()\n  server.listen(port)\n  println(\"Server started on port ${port}\")\n}\n",
      "mode": "create"
    }
  }
}
```

---

## 完整使用示例

### 端到端示例：生成一个简单的HTTP服务器

**用户请求**：生成一个监听8080端口的HTTP服务器代码

**步骤1：检索相关代码**
```json
{
  "toolcall": {
    "thought": "搜索包含HTTP服务器功能的仓颉代码片段",
    "name": "file_search",
    "params": {
      "path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\CangjieMagic",
      "query": "HttpServer listen",
      "recursive": true,
      "caseSensitive": false,
      "filePattern": "*.cj"
    }
  }
}
```

**步骤2：读取并分析代码**
```json
{
  "toolcall": {
    "thought": "读取选中的HTTP服务器代码片段",
    "name": "file_read",
    "params": {
      "path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\src\\demo.cj"
    }
  }
}
```

**步骤3：创建目标目录**
```json
{
  "toolcall": {
    "thought": "创建HTTP服务器代码的目录结构",
    "name": "directory_create",
    "params": {
      "path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\src\\api"
    }
  }
}
```

**步骤4：写入修改后的代码**
```json
{
  "toolcall": {
    "thought": "写入修改后的HTTP服务器代码",
    "name": "file_write",
    "params": {
      "path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\src\\api\\http_server.cj",
      "content": "package api\n\nimport std.net.http\n\nfunc startServer(port: Int): Unit {\n  let server = http.HttpServer()\n  server.listen(port)\n  println(\"HTTP Server started on port ${port}\")\n}\n\nfunc main(): Unit {\n  startServer(8080)\n}\n",
      "mode": "create"
    }
  }
}
```

---

## 错误处理指导

### 检索失败处理

当在仓颉编程资料目录中检索不到相关代码片段时：

1. **扩展搜索范围**：
   - 扩大搜索关键词范围
   - 搜索更通用的功能描述
   - 检查目录路径是否正确

2. **降级策略**：
   - 如果检索失败，允许基于仓颉语法规范直接生成代码
   - 确保生成的代码严格遵循仓颉词法和语法规范
   - 添加详细注释说明代码来源

3. **错误提示**：
   - 向用户说明检索失败的原因
   - 告知用户将使用降级策略生成代码
   - 提供代码验证建议

### 写入失败处理

当写入文件失败时：

1. **权限检查**：确保运行时具有文件写入权限
2. **路径验证**：检查目标路径是否存在且可写
3. **重试机制**：可以尝试创建父目录后重试写入
4. **错误报告**：向用户报告具体的写入错误信息

---

## 代码验证方法

### 代码验证检查清单

1. **词法验证**：
   - [ ] 标识符命名符合规范
   - [ ] 关键字使用正确
   - [ ] 字符串格式正确
   - [ ] 注释格式正确

2. **语法验证**：
   - [ ] 包声明正确
   - [ ] 导入语句正确
   - [ ] 函数定义格式正确
   - [ ] 变量声明格式正确
   - [ ] 控制语句结构正确
   - [ ] 类定义格式正确

3. **语义验证**：
   - [ ] 函数调用参数正确
   - [ ] 变量使用合理
   - [ ] 错误处理完善
   - [ ] 代码逻辑清晰

### 推荐验证工具

- **仓颉编译器**：使用 `cjpm build` 命令编译代码
- **代码编辑器**：使用支持仓颉语言的编辑器进行语法检查
- **静态分析工具**：使用仓颉语言的静态分析工具检查代码质量

---

## 仓颉代码规范参考

### 词法规范要点

| 元素 | 规范说明 |
|------|----------|
| 标识符 | 由字母、数字、下划线组成，首字符不能是数字 |
| 关键字 | 保留字，不能用作标识符 |
| 运算符 | 一元运算符、二元运算符、位运算符等 |
| 分隔符 | 括号、花括号、分号、逗号等 |
| 字符串 | 支持 Unicode 字符，用双引号包围 |
| 注释 | 单行注释 // ，多行注释 /* */ |

### 语法规范要点

| 语法结构 | 说明 |
|----------|------|
| 包声明 | package 包名 |
| 导入语句 | import 模块名 |
| 函数定义 | func 函数名(参数列表): 返回类型 { 函数体 } |
| 变量声明 | let 变量名: 类型 = 值 |
| 条件语句 | if (条件) { 代码块 } else { 代码块 } |
| 循环语句 | for 变量 in 范围 { 代码块 } |
| 类定义 | class 类名 { 成员变量和方法 } |

---

## 工具使用指南

### 推荐工具

1. **file_search**：用于在仓颉编程资料目录中搜索相关代码片段
2. **file_read**：用于读取选中的代码片段内容
3. **file_write**：用于将修改后的代码写入目标文件
4. **directory_create**：用于创建必要的目录结构

### 工具参数说明

**file_search 参数**：
- `path`：搜索路径（必填）
- `query`：搜索关键词（必填）
- `recursive`：是否递归搜索（可选，默认 true）
- `caseSensitive`：是否区分大小写（可选，默认 false）
- `filePattern`：文件匹配模式（可选，默认 "*"）

**file_read 参数**：
- `path`：文件路径（必填）
- `withLineNumber`：是否显示行号（可选，默认 false）
- `startLine`：起始行（可选，默认 1）
- `endLine`：结束行（可选，默认 -1 表示全部）

**file_write 参数**：
- `path`：文件路径（必填）
- `content`：文件内容（必填）
- `mode`：写入模式（可选，默认 "create"，支持 "append"、"overwrite"）

**directory_create 参数**：
- `path`：目录路径（必填）
- `recursive`：是否递归创建父目录（可选，默认 true）

### 工具调用格式

```json
{
  "toolcall": {
    "thought": "工具使用的思考过程",
    "name": "工具名称",
    "params": {
      "参数1": "值1",
      "参数2": "值2"
    }
  }
}
```

---

## 版本兼容性说明

- **仓颉语言版本**：支持 0.53.18 及以上版本
- **运行时依赖**：需要 agentskills-runtime 1.0.0 及以上版本
- **工具依赖**：需要 file_search、file_read、file_write、directory_create 工具

---

## 注意事项

1. **路径格式**：在Windows系统上，文件路径需要使用双反斜杠 `\\`
2. **编码规范**：确保所有生成的代码符合仓颉编程语言的词法和语法规范
3. **文件扩展名**：仓颉代码文件必须使用 `.cj` 扩展名
4. **目录配置**：用户可以通过 `CANGJIE_CODE_REPOSITORY` 配置项指定仓颉编程资料目录
5. **错误处理**：当检索失败时，使用降级策略生成代码
6. **代码验证**：使用仓颉编译器验证生成的代码

---

## 参考文档

- [仓颉词法结构文档](https://cangjie-lang.cn/docs?url=%2FSpec%2Fsource_zh_cn%2FChapter_01_Lexical_Structure%28zh%29.html)
- [仓颉语法文档](https://cangjie-lang.cn/docs?url=%2FSpec%2Fsource_zh_cn%2FChapter_Appendix_A%28zh%29.html)