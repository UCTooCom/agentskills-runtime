# 内置工具文档

本文档详细说明 AgentSkills Runtime 中内置的各种工具及其使用方式。

## 工具分类

### 1. Web 工具

#### WebFetchTool
- **名称**: `web_fetch`
- **功能**: 从 URL 获取内容并将 HTML 转换为 Markdown
- **参数**:
  - `url` (必填): 要获取的 URL
  - `timeout` (可选): 超时时间（毫秒，默认 30000）
  - `maxContentLength` (可选): 最大内容长度（字节，默认 1048576）
- **返回值**: 页面内容（Markdown 格式）
- **使用示例**:
  ```json
  {
    "url": "https://example.com/page"
  }
  ```

#### FirecrawlTool
- **名称**: `firecrawl`
- **功能**: 使用 Firecrawl API 进行网络搜索、页面抓取、网站映射和爬取
- **参数**:
  - `action` (必填): 操作类型：`search`、`scrape`、`map` 或 `crawl`
  - `query` (必填): 搜索查询或 URL
  - `apiKey` (可选): Firecrawl API 密钥（默认使用环境变量 `FIRECRAWL_API_KEY`）
  - `apiUrl` (可选): Firecrawl API URL（默认使用环境变量 `FIRECRAWL_API_URL` 或 `https://api.firecrawl.dev`）
- **返回值**: 操作结果（JSON 格式）
- **使用示例**:
  ```json
  {
    "action": "search",
    "query": "latest AI developments"
  }
  ```
- **配置**: 在 `.env` 文件中设置：
  ```ini
  FIRECRAWL_API_KEY=your_api_key
  FIRECRAWL_API_URL=https://api.firecrawl.dev
  FIRECRAWL_DEFAULT_LIMIT=10
  ```

### 2. HTTP 工具

#### HttpTool
- **名称**: `http_request`
- **功能**: 发送 HTTP 请求
- **参数**:
  - `url` (必填): 请求 URL
  - `method` (可选): 请求方法（GET、POST、PUT、DELETE，默认 GET）
  - `headers` (可选): 请求头
  - `body` (可选): 请求体
  - `timeout` (可选): 超时时间（毫秒）
- **返回值**: HTTP 响应内容
- **使用示例**:
  ```json
  {
    "url": "https://api.example.com/data",
    "method": "POST",
    "body": {"key": "value"}
  }
  ```

### 3. 文件工具

#### FileReadTool
- **名称**: `file_read`
- **功能**: 读取文件内容
- **参数**:
  - `filePath` (必填): 文件路径
  - `encoding` (可选): 编码（默认 UTF-8）
- **返回值**: 文件内容

#### FileWriteTool
- **名称**: `file_write`
- **功能**: 写入文件内容
- **参数**:
  - `filePath` (必填): 文件路径
  - `content` (必填): 文件内容
  - `encoding` (可选): 编码（默认 UTF-8）
  - `append` (可选): 是否追加（默认 false）
- **返回值**: 操作结果

#### FileEditTool
- **名称**: `file_edit`
- **功能**: 编辑文件内容
- **参数**:
  - `filePath` (必填): 文件路径
  - `oldString` (必填): 要替换的旧字符串
  - `newString` (必填): 替换的新字符串
- **返回值**: 操作结果

#### FileDeleteTool
- **名称**: `file_delete`
- **功能**: 删除文件
- **参数**:
  - `filePath` (必填): 文件路径
- **返回值**: 操作结果

#### FileCopyTool
- **名称**: `file_copy`
- **功能**: 复制文件
- **参数**:
  - `sourcePath` (必填): 源文件路径
  - `destinationPath` (必填): 目标文件路径
- **返回值**: 操作结果

#### FileMoveTool
- **名称**: `file_move`
- **功能**: 移动文件
- **参数**:
  - `sourcePath` (必填): 源文件路径
  - `destinationPath` (必填): 目标文件路径
- **返回值**: 操作结果

#### FileSearchTool
- **名称**: `file_search`
- **功能**: 搜索文件
- **参数**:
  - `directory` (必填): 搜索目录
  - `pattern` (必填): 搜索模式（支持通配符）
  - `recursive` (可选): 是否递归搜索（默认 true）
- **返回值**: 匹配的文件列表

#### DirectoryListTool
- **名称**: `directory_list`
- **功能**: 列出目录内容
- **参数**:
  - `directoryPath` (必填): 目录路径
  - `includeFiles` (可选): 是否包含文件（默认 true）
  - `includeDirectories` (可选): 是否包含目录（默认 true）
- **返回值**: 目录内容列表

#### DirectoryCreateTool
- **名称**: `directory_create`
- **功能**: 创建目录
- **参数**:
  - `directoryPath` (必填): 目录路径
  - `recursive` (可选): 是否递归创建（默认 true）
- **返回值**: 操作结果

### 4. 代码生成工具

#### TemplateEngineTool
- **名称**: `template_engine`
- **功能**: 模板引擎，用于渲染模板
- **参数**:
  - `template` (必填): 模板字符串
  - `variables` (可选): 模板变量
- **返回值**: 渲染后的结果
- **使用示例**:
  ```json
  {
    "template": "Hello {{name}}!",
    "variables": {"name": "World"}
  }
  ```

#### CodeSnippetGeneratorTool
- **名称**: `code_snippet_generator`
- **功能**: 生成代码片段
- **参数**:
  - `language` (必填): 编程语言
  - `description` (必填): 代码描述
  - `requirements` (可选): 额外要求
- **返回值**: 生成的代码片段

### 5. 技能生命周期工具

#### SkillInitializerTool
- **名称**: `skill_initializer`
- **功能**: 初始化技能
- **参数**:
  - `skillName` (必填): 技能名称
  - `description` (可选): 技能描述
  - `author` (可选): 作者
  - `version` (可选): 版本
- **返回值**: 初始化结果

#### SkillPackagerTool
- **名称**: `skill_packager`
- **功能**: 打包技能
- **参数**:
  - `skillDirectory` (必填): 技能目录
  - `outputPath` (可选): 输出路径
- **返回值**: 打包结果

### 6. 其他工具

#### ChatModelTool
- **名称**: `chat_model`
- **功能**: 调用聊天模型
- **参数**:
  - `prompt` (必填): 提示词
  - `model` (可选): 模型名称
  - `temperature` (可选): 温度参数
- **返回值**: 模型响应

#### AgentAsTool
- **名称**: `agent_as_tool`
- **功能**: 将代理作为工具使用
- **参数**:
  - `agentName` (必填): 代理名称
  - `input` (必填): 输入内容
- **返回值**: 代理执行结果

## 工具使用指南

### 在技能中使用工具

在技能中，您可以通过 `tool_call` 来调用内置工具：

```cangjie
import { Skill, Tool } from "agentskills-runtime";

@Skill(
  name = "example-skill",
  description = "An example skill"
)
public class ExampleSkill {
    @Tool(
      name = "search_web",
      description = "Search the web for information",
      parameters = [
        { name: "query", type: "string", required: true, description: "Search query" }
      ]
    )
    public String searchWeb(String query) {
        // 调用 Firecrawl 工具进行搜索
        let result = this.toolCall("firecrawl", {
            action: "search",
            query: query
        });
        return result;
    }
}
```

### 工具调用参数

工具调用时，参数需要以 JSON 格式传递：

```json
{
  "toolcall": {
    "thought": "I need to search for information about AI trends",
    "name": "firecrawl",
    "params": {
      "action": "search",
      "query": "latest AI trends 2026"
    }
  }
}
```

### 工具配置

部分工具需要在 `.env` 文件中进行配置：

```ini
# Firecrawl 配置
FIRECRAWL_API_KEY=your_api_key
FIRECRAWL_API_URL=https://api.firecrawl.dev

# HTTP 代理配置（可选）
HTTP_PROXY=http://proxy.example.com:8080
```

### 工具执行结果

工具执行后会返回结果，格式如下：

```json
{
  "success": "true",
  "action": "search",
  "query": "latest AI trends",
  "result": "{\"results\": [...]}"
}
```

## 工具优先级和过滤

### 工具过滤

您可以使用 `SimpleToolFilter` 来过滤工具：

```cangjie
let toolManager = SimpleToolManager()
let filter = SimpleToolFilter(allowedTools: ["web_fetch", "firecrawl"])
toolManager.setToolFilter(filter)
```

### 工具优先级

工具执行时会按照注册顺序进行优先级排序，您可以通过调整注册顺序来改变优先级。

## 自定义工具

您可以通过继承 `AbsTool` 来创建自定义工具：

```cangjie
public class MyCustomTool <: AbsTool {
    public static let NAME = "my_custom_tool"
    
    public static let DESC = "My custom tool"

    public prop name: String {
        get() { MyCustomTool.NAME }
    }

    public prop description: String {
        get() { MyCustomTool.DESC }
    }

    public prop parameters: Array<ToolParameter> {
        get() {
            [
                ToolParameter("param1", "Parameter 1", TypeSchema.Str),
                ToolParameter("param2", "Parameter 2", TypeSchema.Int)
            ]
        }
    }

    public prop retType: TypeSchema {
        get() { TypeSchema.Str }
    }

    override public func invoke(args: HashMap<String, JsonValue>): ToolResponse {
        // 工具实现
        let response = JsonObject()
        response.put("success", JsonString("true"))
        response.put("result", JsonString("Tool executed successfully"))
        return ToolResponse(response.toJsonString())
    }
}
```

## 工具最佳实践

1. **参数验证**: 总是验证工具参数的有效性
2. **错误处理**: 妥善处理工具执行过程中的错误
3. **超时设置**: 为网络相关工具设置合理的超时时间
4. **资源管理**: 确保文件操作等资源得到正确释放
5. **安全性**: 避免在工具中处理敏感信息
6. **性能优化**: 对于频繁调用的工具，考虑缓存机制

## 故障排除

### 常见问题

1. **工具调用失败**
   - 检查参数是否正确
   - 检查网络连接
   - 检查 API 密钥是否有效

2. **Firecrawl 工具不工作**
   - 检查 `FIRECRAWL_API_KEY` 是否正确设置
   - 检查 Firecrawl API 服务是否可用
   - 尝试使用不同的 API URL

3. **文件工具权限问题**
   - 检查文件路径是否存在
   - 检查文件权限是否正确
   - 确保运行时具有文件操作权限

### 日志排查

工具执行过程中的日志会输出到配置的日志文件中，您可以通过查看日志来排查问题：

```bash
# 查看日志
cat logs/agentskills-runtime.log
```

## 总结

AgentSkills Runtime 提供了丰富的内置工具，涵盖了 Web 操作、文件操作、HTTP 请求、代码生成等多个领域。这些工具可以帮助您构建功能强大的技能，实现各种复杂的任务。

通过合理使用这些工具，您可以：
- 获取网络信息
- 操作文件系统
- 与外部 API 交互
- 生成代码和内容
- 管理技能生命周期

希望本文档对您使用内置工具有所帮助！