# tool - 工具管理模块

> **包路径**: `magic.tool`  
> **描述**: 内置工具管理系统,提供CLI、HTTP和内部API三种调用方式

## 概述

`magic.tool` 是AgentSkills Runtime的工具管理模块,提供22个内置工具,支持多种调用方式,集成RBAC权限体系和审计日志功能。

## 核心组件

### ToolDispatcher

**描述**: 工具调度器,处理工具调用请求

**功能**:
- 支持CLI、HTTP、内部API三种调用方式
- 统一参数解析和结果格式化
- 错误处理和日志记录

**接口**:
```cangjie
public class ToolDispatcher {
    // CLI调用入口
    public func dispatchFromCli(
        toolName: String,
        args: Array<String>
    ): ToolResponse
    
    // HTTP调用入口
    public func dispatchFromHttp(
        toolName: String,
        args: HashMap<String, JsonValue>,
        userId: String
    ): ToolResponse
    
    // 内部API调用入口
    public func dispatchFromInternal(
        toolName: String,
        args: HashMap<String, JsonValue>,
        userId: String
    ): ToolResponse
}
```

---

### PermissionChecker

**描述**: 权限检查器

**功能**:
- 检查用户工具调用权限
- 支持敏感操作验证
- 记录审计日志

---

### BuiltinToolsRegistry

**描述**: 内置工具注册中心

**功能**:
- 注册所有内置工具
- 管理工具元数据
- 提供工具查询接口

---

## 工具分类

### 文件系统工具 (9个)

#### file_read
- **权限**: `/api/v1/tools/fs/read`
- **敏感级别**: 低 (1)
- **功能**: 读取文件内容
- **参数**:
  - `path` (必填): 文件路径
  - `encoding` (可选): 文件编码
  - `offset` (可选): 起始行号
  - `limit` (可选): 读取行数

#### file_write
- **权限**: `/api/v1/tools/fs/write`
- **敏感级别**: 中 (2)
- **功能**: 写入文件内容
- **参数**:
  - `path` (必填): 文件路径
  - `content` (必填): 文件内容
  - `append` (可选): 是否追加

#### file_edit
- **权限**: `/api/v1/tools/fs/edit`
- **敏感级别**: 中 (2)
- **功能**: 编辑文件内容
- **参数**:
  - `path` (必填): 文件路径
  - `old` (必填): 要替换的内容
  - `new` (必填): 替换后的内容

#### file_delete
- **权限**: `/api/v1/tools/fs/delete`
- **敏感级别**: 高 (3)
- **需要确认**: 是
- **功能**: 删除文件

#### file_copy
- **权限**: `/api/v1/tools/fs/copy`
- **敏感级别**: 低 (1)
- **功能**: 复制文件

#### file_move
- **权限**: `/api/v1/tools/fs/move`
- **敏感级别**: 中 (2)
- **功能**: 移动文件

#### file_search
- **权限**: `/api/v1/tools/fs/search`
- **敏感级别**: 低 (1)
- **功能**: 搜索文件

#### directory_list
- **权限**: `/api/v1/tools/fs/list`
- **敏感级别**: 低 (1)
- **功能**: 列出目录内容

#### directory_create
- **权限**: `/api/v1/tools/fs/create`
- **敏感级别**: 中 (2)
- **功能**: 创建目录

---

### 网络工具 (4个)

#### http_request
- **权限**: `/api/v1/tools/web/http`
- **敏感级别**: 中 (2)
- **功能**: 发送HTTP请求
- **参数**:
  - `url` (必填): 请求URL
  - `method` (可选): 请求方法
  - `headers` (可选): 请求头
  - `body` (可选): 请求体

#### web_fetch
- **权限**: `/api/v1/tools/web/fetch`
- **敏感级别**: 低 (1)
- **功能**: 抓取网页并转Markdown

#### firecrawl
- **权限**: `/api/v1/tools/web/firecrawl`
- **敏感级别**: 中 (2)
- **功能**: Firecrawl网页爬取

#### browser_tool
- **权限**: `/api/v1/tools/web/browser`
- **敏感级别**: 中 (2)
- **功能**: 浏览器工具

---

### 技能工具 (2个)

#### skill_initializer
- **权限**: `/api/v1/tools/skill/init`
- **敏感级别**: 中 (2)
- **功能**: 初始化技能项目

#### skill_packager
- **权限**: `/api/v1/tools/skill/package`
- **敏感级别**: 中 (2)
- **功能**: 打包技能

---

### 代码生成工具 (2个)

#### template_engine
- **权限**: `/api/v1/tools/code/template`
- **敏感级别**: 低 (1)
- **功能**: 模板渲染

#### code_snippet_generator
- **权限**: `/api/v1/tools/code/generate`
- **敏感级别**: 低 (1)
- **功能**: 生成代码片段

---

### CLI工具 (1个)

#### cli_execute
- **权限**: `/api/v1/tools/cli/execute`
- **敏感级别**: 高 (3)
- **需要确认**: 是
- **功能**: 执行CLI命令

---

## HTTP API

### 获取工具列表

**端点**: `GET /api/v1/tools/list`

**描述**: 获取所有可用工具列表

**认证**: 需要Bearer Token

**请求示例**:
```bash
curl -X GET https://javatoarktsapi.uctoo.com/api/v1/tools/list \
  -H "Authorization: Bearer <access_token>"
```

**响应示例**:
```json
{
  "success": true,
  "tools": [
    {
      "name": "file_read",
      "path": "/api/v1/tools/fs/read",
      "sensitiveLevel": 1,
      "requiresConfirmation": false,
      "auditEnabled": true
    }
  ],
  "total": 22
}
```

---

### 获取工具信息

**端点**: `GET /api/v1/tools/:toolName/info`

**描述**: 获取指定工具详细信息

**认证**: 需要Bearer Token

**请求示例**:
```bash
curl -X GET https://javatoarktsapi.uctoo.com/api/v1/tools/file_read/info \
  -H "Authorization: Bearer <access_token>"
```

**响应示例**:
```json
{
  "success": true,
  "name": "file_read",
  "path": "/api/v1/tools/fs/read",
  "sensitiveLevel": 1,
  "requiresConfirmation": false,
  "auditEnabled": true
}
```

---

### 调用工具

**端点**: `POST /api/v1/tools/:toolName`

**描述**: 调用指定工具

**认证**: 需要Bearer Token

#### 文件读取示例

**请求**:
```bash
curl -X POST https://javatoarktsapi.uctoo.com/api/v1/tools/file_read \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{"path": "./SKILL.md"}'
```

**响应**:
```json
{
  "success": true,
  "result": "# SKILL.md content...",
  "isError": false
}
```

---

#### 文件写入示例

**请求**:
```bash
curl -X POST https://javatoarktsapi.uctoo.com/api/v1/tools/file_write \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{"path": "./output.txt", "content": "Hello World"}'
```

---

#### HTTP请求示例

**请求**:
```bash
curl -X POST https://javatoarktsapi.uctoo.com/api/v1/tools/http_request \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://api.example.com", "method": "GET"}'
```

---

## 权限体系

### 敏感级别

| 级别 | 说明 | 示例工具 |
|------|------|----------|
| 1 (低) | 只读操作 | file_read, directory_list |
| 2 (中) | 修改操作 | file_write, http_request |
| 3 (高) | 危险操作 | file_delete, cli_execute |

### 权限配置

```json
{
  "roles": {
    "admin": {
      "permissions": ["/*"]
    },
    "developer": {
      "permissions": [
        "/api/v1/tools/fs/*",
        "/api/v1/tools/web/*"
      ]
    },
    "viewer": {
      "permissions": [
        "/api/v1/tools/fs/read"
      ]
    }
  }
}
```

---

## 审计日志

所有工具调用都会记录审计日志:
- 调用时间
- 用户ID
- 工具名称
- 调用参数
- 执行结果
- 执行时长

---

## 目录结构

```
src/tool/
├── tool_dispatcher.cj          # 工具调度器
├── permission_checker.cj       # 权限检查器
├── builtin_tools_registry.cj   # 内置工具注册
├── tool_permission.cj          # 工具权限定义
├── file_tools.cj               # 文件工具实现
├── web_tools.cj                # 网络工具实现
├── http_tool.cj                # HTTP工具
├── firecrawl_tool.cj           # Firecrawl工具
├── skill_lifecycle_tools.cj    # 技能工具
├── code_generation_tools.cj    # 代码生成工具
├── cli_tool.cj                 # CLI工具
└── tool_audit_log.cj           # 审计日志
```

---

## 工具总数

当前版本共提供 **22个** 内置工具:
- 文件工具: 9个
- 网络工具: 4个
- 技能工具: 2个
- 代码生成工具: 2个
- CLI工具: 1个
- 其他工具: 4个

---

**包文档维护**: CodeArts Agent  
**最后更新**: 2026-03-26

---

## 核心 API 参考

以下是工具系统的核心类和接口的详细API文档。

---

## Package tool

- [Package tool](#package-tool)
  - [class AgentAsTool](#class-agentastool)
    - [prop description](#prop-description)
    - [prop examples](#prop-examples)
    - [func init](#func-init)
    - [func invoke](#func-invoke)
    - [prop name](#prop-name)
    - [prop parameters](#prop-parameters)
    - [prop retType](#prop-rettype)
  - [class NativeFuncTool](#class-nativefunctool)
    - [prop description](#prop-description-1)
    - [prop examples](#prop-examples-1)
    - [func init](#func-init-1)
    - [func invoke](#func-invoke-1)
    - [prop name](#prop-name-1)
    - [prop parameters](#prop-parameters-1)
    - [prop retType](#prop-rettype-1)
  - [class SimpleToolManager](#class-simpletoolmanager)
    - [func addTool](#func-addtool)
    - [func addTools](#func-addtools)
    - [func clear](#func-clear)
    - [func delTool](#func-deltool)
    - [prop enableFilter](#prop-enablefilter)
    - [func filterTool](#func-filtertool)
    - [func findTool](#func-findtool)
    - [func init](#func-init-2)
    - [func init](#func-init-3)
    - [prop tools](#prop-tools)
  - [enum SubAgentMode](#enum-subagentmode)
    - [enumeration Isolated](#enumeration-isolated)
    - [enumeration WithContext](#enumeration-withcontext)

### class AgentAsTool

将Agent包装为Tool的适配器类。

#### prop description
```
prop description: String
```
- Description: Gets the description of the agent, defaults to the agent's name if description is empty

#### prop examples
```
prop examples: Array<String>
```
- Description: Gets the examples for the tool, returns an empty array

#### func init
```
init(agent: Agent, mode!: SubAgentMode = SubAgentMode.Isolated)
```
- Description: Initializes the AgentAsTool with an agent and a mode
- Parameters:
  - `agent`: `Agent`, The agent to be used as a tool
  - `mode!`: `SubAgentMode`, The execution mode for the sub-agent, defaults to Isolated

#### func invoke
```
func invoke(args: HashMap<String, JsonValue>): ToolResponse
```
- Description: Invokes the tool with the provided arguments
- Parameters:
  - `args`: `HashMap<String, JsonValue>`, The arguments for the tool invocation

#### prop name
```
prop name: String
```
- Description: Gets the name of the agent

#### prop parameters
```
prop parameters: Array<ToolParameter>
```
- Description: Gets the parameters required by the tool based on the sub-agent mode

#### prop retType
```
prop retType: TypeSchema
```
- Description: Gets the return type schema of the tool


### class NativeFuncTool

原生函数工具类,用于包装原生函数为工具。

#### prop description
```
prop description: String
```
- Description: Gets the description of the tool.

#### prop examples
```
prop examples: Array<String>
```
- Description: Gets the examples of the tool.

#### func init
```
init(name: String, description: String, parameters: Array<(String, String, TypeSchema)>, retType: TypeSchema, examples: Array<String>, extra: HashMap<String, String>, execFn: Option<ExecFn>)
```
- Description: Constructor for NativeFuncTool class.
- Parameters:
  - `name`: `String`, Name of the tool.
  - `description`: `String`, Description of the tool.
  - `parameters`: `Array<(String, String, TypeSchema)>`, List of parameters for the tool.
  - `retType`: `TypeSchema`, Return type schema of the tool.
  - `examples`: `Array<String>`, List of examples for the tool.
  - `extra`: `HashMap<String, String>`, Extra information for the tool.
  - `execFn`: `Option<ExecFn>`, Optional execution function for the tool.

#### func invoke
```
func invoke(args: HashMap<String, JsonValue>): ToolResponse
```
- Description: Invokes the tool with the given arguments.
- Parameters:
  - `args`: `HashMap<String, JsonValue>`, Arguments for the tool invocation.

#### prop name
```
prop name: String
```
- Description: Gets the name of the tool.

#### prop parameters
```
prop parameters: Array<ToolParameter>
```
- Description: Gets the parameters of the tool.

#### prop retType
```
prop retType: TypeSchema
```
- Description: Gets the return type schema of the tool.


### class SimpleToolManager

简单工具管理器,用于管理工具集合。

#### func addTool
```
override public func addTool(tool: Tool): Unit
```
- Description: Adds a tool to the manager.
- Parameters:
  - `tool`: `Tool`, The tool to be added.

#### func addTools
```
override public func addTools(tools: Collection<Tool>): Unit
```
- Description: Adds multiple tools to the manager.
- Parameters:
  - `tools`: `Collection<Tool>`, A collection of tools to be added.

#### func clear
```
override public func clear(): Unit
```
- Description: Removes all tools from the manager.

#### func delTool
```
override public func delTool(tool: Tool): Unit
```
- Description: Removes a tool from the manager.
- Parameters:
  - `tool`: `Tool`, The tool to be removed.

#### prop enableFilter
```
override public prop enableFilter: Bool
```
- Description: Gets a value indicating whether tool filtering is enabled.

#### func filterTool
```
override public func filterTool(question: String, filter: ToolFilter): Array<Tool>
```
- Description: Filters tools based on a question and a filter.
- Parameters:
  - `question`: `String`, The question used for filtering.
  - `filter`: `ToolFilter`, The filter to apply to the tools.

#### func findTool
```
override public func findTool(name: String): Option<Tool>
```
- Description: Finds a tool by its name.
- Parameters:
  - `name`: `String`, The name of the tool to find.

#### func init
```
public init()
```
- Description: Initializes a SimpleToolManager with default settings.

#### func init
```
public init(tools: Collection<Tool>, enableFilter: Bool = false)
```
- Description: Initializes a SimpleToolManager with a collection of tools and an optional filter setting.
- Parameters:
  - `tools`: `Collection<Tool>`, A collection of tools to be managed.
  - `enableFilter`: `Bool`, A flag to enable or disable tool filtering. Defaults to false.

#### prop tools
```
override public prop tools: Array<Tool>
```
- Description: Gets an array of all tools managed by this SimpleToolManager.


### enum SubAgentMode

子代理执行模式枚举。

####  Isolated
```
Isolated
```
- Description: Sub-agent executes independently without any context from the main agent

####  WithContext
```
WithContext
```
- Description: Sub-agent inherits the full context (state, history, data, etc.) from the main agent
