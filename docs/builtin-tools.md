# 内置工具 v2.0 文档

> **版本**: v2.0  
> **更新日期**: 2026-06-16  
> **作者**: CodeArts Agent

本文档详细说明 AgentSkills Runtime v2.0 中内置的各种工具及其使用方式。文档与实际实现保持一致。

## 概述

AgentSkills Runtime v2.0 提供了完整的内置工具集,支持三种调用方式:
- **CLI接口**: 通过命令行调用
- **HTTP接口**: 通过RESTful API调用
- **内部API**: 在代码中直接调用

所有工具都集成了RBAC权限体系,确保安全可控。

---

## 一、工具架构

### 1.1 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                    v2.0 工具架构                               │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  CLI 接口   │  │ HTTP 接口   │  │ 内部 API   │         │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘         │
│         │                │                │                 │
│         └────────────────┼────────────────┘                 │
│                          ▼                                  │
│              ┌─────────────────────┐                       │
│              │  ToolDispatcher     │                       │
│              │  (工具调度器)        │                       │
│              └─────────────────────┘                       │
│                          │                                  │
│                          ▼                                  │
│              ┌─────────────────────┐                       │
│              │ PermissionChecker   │                       │
│              │  (权限检查器)        │                       │
│              └─────────────────────┘                       │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 HTTP接口

**基础路径**: `/api/v1/tools`

**接口列表**:
- `GET /api/v1/tools/list` - 获取工具列表
- `GET /api/v1/tools/:toolName/info` - 获取工具信息
- `POST /api/v1/tools/:toolName` - 调用工具

**认证方式**: JWT Bearer Token

---

## 二、工具分类

### 2.1 文件系统工具组 (fs)

#### FileReadTool
- **名称**: `file_read`
- **权限**: `/api/v1/tools/fs/read`
- **敏感级别**: 低 (1)
- **功能**: 读取文件内容
- **参数**:
  - `path` (必填): 文件路径
  - `withLineNumber` (可选): 是否显示行号,默认false
  - `startLine` (可选): 起始行号(从1开始),默认1
  - `endLine` (可选): 结束行号,默认读取到文件末尾
- **HTTP示例**:
  ```bash
  POST /api/v1/tools/file_read
  Authorization: Bearer <token>
  
  {
    "path": "./SKILL.md"
  }
  ```
- **响应**:
  ```json
  {
    "success": "true",
    "path": "./SKILL.md",
    "content": "文件内容...",
    "lineCount": "100"
  }
  ```

#### FileWriteTool
- **名称**: `file_write`
- **权限**: `/api/v1/tools/fs/write`
- **敏感级别**: 中 (2)
- **功能**: 写入文件内容
- **参数**:
  - `path` (必填): 文件路径
  - `content` (必填): 文件内容
  - `mode` (可选): 写入模式(create/append/overwrite),默认create
- **HTTP示例**:
  ```bash
  POST /api/v1/tools/file_write
  
  {
    "path": "./output.txt",
    "content": "Hello World"
  }
  ```
- **响应**:
  ```json
  {
    "success": "true",
    "path": "./output.txt",
    "bytesWritten": "11",
    "mode": "create"
  }
  ```

#### FileEditTool
- **名称**: `file_edit`
- **权限**: `/api/v1/tools/fs/edit`
- **敏感级别**: 中 (2)
- **功能**: 编辑文件内容
- **参数**:
  - `path` (必填): 文件路径
  - `oldText` (必填): 要替换的内容
  - `newText` (必填): 替换后的内容
  - `replaceAll` (可选): 是否替换所有匹配,默认false
  - `createIfNotExists` (可选): 文件不存在时是否创建,默认false
- **响应**:
  ```json
  {
    "success": "true",
    "path": "./file.txt",
    "replacements": "1"
  }
  ```

#### FileDeleteTool
- **名称**: `file_delete`
- **权限**: `/api/v1/tools/fs/delete`
- **敏感级别**: 高 (3)
- **需要确认**: 是
- **功能**: 删除文件或目录
- **参数**:
  - `path` (必填): 文件或目录路径
  - `recursive` (可选): 是否递归删除目录,默认false
  - `force` (可选): 是否强制删除只读文件,默认false
- **响应**:
  ```json
  {
    "success": "true",
    "path": "./file.txt",
    "type": "file"
  }
  ```

#### FileSearchTool
- **名称**: `file_search`
- **权限**: `/api/v1/tools/fs/search`
- **敏感级别**: 低 (1)
- **功能**: 在文件或目录中搜索文本
- **参数**:
  - `path` (必填): 搜索路径(文件或目录)
  - `query` (必填): 搜索关键词
  - `recursive` (可选): 是否递归搜索目录,默认false
- **响应**:
  ```json
  {
    "success": "true",
    "path": "./directory",
    "query": "magic",
    "matchCount": "2",
    "matches": [
      {"file": "./file1.txt", "line": "1", "content": "Contains magic"}
    ]
  }
  ```

#### DirectoryListTool
- **名称**: `directory_list`
- **权限**: `/api/v1/tools/fs/list`
- **敏感级别**: 低 (1)
- **功能**: 列出目录内容
- **参数**:
  - `path` (必填): 目录路径
  - `recursive` (可选): 是否递归列出,默认false
  - `pattern` (可选): 文件名过滤模式(如*.txt)
- **响应**:
  ```json
  {
    "success": "true",
    "path": "./directory",
    "count": "5",
    "entries": [
      {"name": "file.txt", "type": "file", "size": 1024}
    ]
  }
  ```

#### DirectoryCreateTool
- **名称**: `directory_create`
- **权限**: `/api/v1/tools/fs/create`
- **敏感级别**: 中 (2)
- **功能**: 创建目录
- **参数**:
  - `path` (必填): 目录路径
  - `recursive` (可选): 是否递归创建嵌套目录,默认false
- **响应**:
  ```json
  {
    "success": "true",
    "path": "./newdir",
    "created": "true"
  }
  ```

---

### 2.2 网络工具组 (web)

#### HttpTool
- **名称**: `http_request`
- **权限**: `/api/v1/tools/web/http`
- **敏感级别**: 中 (2)
- **功能**: 发送HTTP请求
- **参数**:
  - `url` (必填): 请求URL
  - `method` (可选): 请求方法,默认GET
  - `headers` (可选): 请求头
  - `body` (可选): 请求体
  - `timeout` (可选): 超时时间(毫秒)
- **HTTP示例**:
  ```bash
  POST /api/v1/tools/http_request
  
  {
    "url": "https://api.example.com/data",
    "method": "GET"
  }
  ```

#### WebFetchTool
- **名称**: `web_fetch`
- **权限**: `/api/v1/tools/web/fetch`
- **敏感级别**: 低 (1)
- **功能**: 抓取网页并转换为Markdown
- **参数**:
  - `url` (必填): 网页URL
  - `timeout` (可选): 超时时间,默认30000ms
  - `maxContentLength` (可选): 最大内容长度,默认1MB

#### FirecrawlTool
- **名称**: `firecrawl`
- **权限**: `/api/v1/tools/web/firecrawl`
- **敏感级别**: 中 (2)
- **功能**: 使用Firecrawl API进行网页爬取
- **参数**:
  - `action` (必填): 操作类型(search/scrape/map/crawl)
  - `query` (必填): 搜索查询或URL
  - `apiKey` (可选): API密钥
- **配置**:
  ```ini
  FIRECRAWL_API_KEY=your_api_key
  FIRECRAWL_API_URL=https://api.firecrawl.dev
  ```

---

### 2.3 技能工具组 (skill)

#### SkillInitializerTool
- **名称**: `skill_initializer`
- **权限**: `/api/v1/tools/skill/init`
- **敏感级别**: 中 (2)
- **功能**: 初始化技能项目结构
- **参数**:
  - `name` (必填): 技能名称
  - `path` (必填): 技能路径

#### SkillPackagerTool
- **名称**: `skill_packager`
- **权限**: `/api/v1/tools/skill/package`
- **敏感级别**: 中 (2)
- **功能**: 打包技能为发布包
- **参数**:
  - `path` (必填): 技能路径
  - `output` (必填): 输出文件路径

---

### 2.4 代码生成工具组 (code)

#### TemplateEngineTool
- **名称**: `template_engine`
- **权限**: `/api/v1/tools/code/template`
- **敏感级别**: 低 (1)
- **功能**: 模板渲染引擎
- **参数**:
  - `template` (必填): 模板内容
  - `data` (必填): 模板数据(JSON)
  - `templateFile` (可选): 模板文件路径

#### CodeSnippetGeneratorTool
- **名称**: `code_snippet_generator`
- **权限**: `/api/v1/tools/code/generate`
- **敏感级别**: 低 (1)
- **功能**: 生成代码片段
- **参数**:
  - `language` (必填): 编程语言
  - `type` (必填): 代码类型(function/class/struct)
  - `name` (必填): 名称
  - `params` (可选): 参数列表

---

### 2.5 CLI工具组 (cli)

#### CliTool
- **名称**: `cli_execute`
- **权限**: `/api/v1/tools/cli/execute`
- **敏感级别**: 高 (3)
- **需要确认**: 是
- **功能**: 执行CLI命令
- **参数**:
  - `command` (必填): 命令内容
  - `confirm` (必填): 确认执行,必须为true
- **安全限制**: 危险命令会被拦截

---

## 三、权限体系

### 3.1 敏感级别

| 级别 | 说明 | 示例工具 |
|------|------|----------|
| 1 (低) | 只读操作,低风险 | file_read, file_search, directory_list |
| 2 (中) | 修改操作,中等风险 | file_write, file_edit, directory_create |
| 3 (高) | 危险操作,高风险 | file_delete, cli_execute |

### 3.2 默认权限配置

```json
{
  "default_permissions": {
    "allow": [
      "/api/v1/tools/fs/read",
      "/api/v1/tools/fs/list",
      "/api/v1/tools/web/fetch",
      "/api/v1/tools/code/*"
    ],
    "deny": [
      "/api/v1/tools/fs/delete",
      "/api/v1/tools/cli/execute"
    ]
  }
}
```

### 3.3 角色权限映射

```json
{
  "roles": {
    "admin": {
      "permissions": ["/*"]
    },
    "developer": {
      "permissions": [
        "/api/v1/tools/fs/*",
        "/api/v1/tools/web/*",
        "/api/v1/tools/skill/*",
        "/api/v1/tools/code/*"
      ]
    },
    "viewer": {
      "permissions": [
        "/api/v1/tools/fs/read",
        "/api/v1/tools/fs/list"
      ]
    }
  }
}
```

---

## 四、使用示例

### 4.1 获取工具列表

```bash
curl -X GET https://javatoarktsapi.uctoo.com/api/v1/tools/list \
  -H "Authorization: Bearer <token>"
```

**响应**:
```json
{
  "success": true,
  "tools": [
    {
      "name": "file_read",
      "path": "/api/v1/tools/fs/read",
      "sensitiveLevel": 1,
      "requiresConfirmation": false
    }
  ],
  "total": 22
}
```

### 4.2 调用文件读取工具

```bash
curl -X POST https://javatoarktsapi.uctoo.com/api/v1/tools/file_read \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"path": "./SKILL.md"}'
```

**响应**:
```json
{
  "success": "true",
  "path": "./SKILL.md",
  "content": "# SKILL.md content...",
  "lineCount": "50"
}
```

### 4.3 按行范围读取文件

```bash
curl -X POST https://javatoarktsapi.uctoo.com/api/v1/tools/file_read \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "path": "./file.txt",
    "startLine": 10,
    "endLine": 50,
    "withLineNumber": true
  }'
```

### 4.4 调用HTTP请求工具

```bash
curl -X POST https://javatoarktsapi.uctoo.com/api/v1/tools/http_request \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://api.example.com/data",
    "method": "GET"
  }'
```

---

## 五、审计日志

所有工具调用都会记录审计日志,包括:
- 调用时间
- 用户ID
- 工具名称
- 调用参数
- 执行结果
- 执行时长

审计日志存储在数据库的`operate_log`表中。

---

## 六、错误处理

### 6.1 常见错误

| 错误码 | 说明 | 解决方案 |
|--------|------|----------|
| 401 | 未授权 | 提供有效的JWT Token |
| 403 | 权限不足 | 检查用户权限配置 |
| 404 | 工具不存在 | 检查工具名称 |
| 400 | 参数错误 | 检查参数格式 |

### 6.2 错误响应格式

```json
{
  "success": false,
  "error": "Permission denied: User does not have permission to call file_delete"
}
```

---

## 七、工具总数

当前版本共提供 **19个** 内置工具:
- 文件工具: 7个 (file_read, file_write, file_edit, file_delete, file_search, directory_list, directory_create)
- 网络工具: 3个 (http_request, web_fetch, firecrawl)
- 技能工具: 2个 (skill_initializer, skill_packager)
- 代码生成工具: 2个 (template_engine, code_snippet_generator)
- CLI工具: 1个 (cli_execute)
- WebMCP工具: 4个

---

## 八、更新日志

### v2.0 (2026-06-16)
- ✅ 修复文档与实现不一致问题
- ✅ 更新FileReadTool参数(startLine/endLine/withLineNumber)
- ✅ 更新FileEditTool参数(oldText/newText/replaceAll)
- ✅ 更新FileDeleteTool参数(recursive/force)
- ✅ 更新工具总数统计

### v2.0 (2026-03-26)
- ✅ 新增统一的HTTP接口
- ✅ 集成RBAC权限体系
- ✅ 添加审计日志功能
- ✅ 优化工具描述和参数设计
- ✅ 支持敏感操作二次确认
- ✅ 完善错误处理机制

### v1.0
- 基础工具实现
- CLI接口支持

---

**文档维护**: CodeArts Agent  
**最后更新**: 2026-06-16
