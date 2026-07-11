# WebMCP 完善 - 编码任务规划

## 开发规范

### 仓颉代码开发
- 所有仓颉（.cj）代码必须使用 **cangjie-coder 技能** 编写
- 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考
- 遵循 cangjie-coder 技能的四步工作流程：查阅 CangjieSkills 技能 → 检索代码片段 → 编辑适配 → 写入文件
- 仓颉代码必须符合 CangjieMagic 框架的约定和模式
- 数据库列名使用 snake_case（deleted_at, updated_at），仓颉代码使用 camelCase（createdAt, updatedAt）

### 前端代码开发
- 使用 TypeScript 编写前端代码
- 使用 Vue 3 + Vite 构建前端项目
- 使用 pinia-orm 进行前端 ORM 状态管理

---

## 任务概览

| 统计项 | 数量 |
|--------|------|
| 主任务组 | 5 |
| 子任务数 | 28 |
| 覆盖需求 | REQ-01 ~ REQ-11（全部覆盖） |

---

## Phase 1 - 基础设施

> 建立会话管理、CORS、追踪头等基础设施，为后续核心协议和工具系统提供支撑。

### TASK-01：新增 DeviceInfo 数据模型

- **关联需求**：REQ-04, REQ-11
- **优先级**：P0
- **预估复杂度**：S
- **依赖**：无
- **涉及文件**：
  - **新建文件**：
    - `src/app/services/webmcp/DeviceInfo.cj` — 参考 `src/app/models/uctoo/AgentsPO.cj`（Model 数据结构模式）、`src/app/services/webmcp/WebMCPProtocol.cj`（同目录下已有的 JsonObject 使用模式）
- **任务描述**：
  创建设备信息数据结构，从请求头采集客户端设备信息。包含 ip（来自 x-forwarded-for，支持逗号分隔多IP）、userAgent（来自 user-agent）、acceptLanguage（来自 accept-language）、referer（来自 referer）四个字段。提供 toJson() 方法输出兼容 WebAgent API 格式的 JSON，ip 字段在多 IP 时输出为数组。

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考（特别是同目录下已有的 .cj 文件）
  - 参考文件包括但不限于：
    - 同目录下已有的 WebMCPProtocol.cj 中的 JsonObject 使用和 toJson() 方法模式
    - `src/app/models/uctoo/AgentsPO.cj` 中的 Model 数据结构定义模式
    - CangjieMagic 框架的 JSON 序列化约定
  - 遵循 cangjie-coder 技能的四步工作流程：查阅 CangjieSkills 技能 → 检索代码片段 → 编辑适配 → 写入文件

- **验收标准**：
  1. DeviceInfo 类可正常实例化，支持全参数构造和无参构造（默认空字符串）
  2. toJson() 方法输出格式正确，多 IP 时 ip 字段为数组
  3. 包路径为 `magic.app.services.webmcp`

### TASK-02：新增 SessionInfo 数据模型

- **关联需求**：REQ-04, REQ-08, REQ-11
- **优先级**：P0
- **预估复杂度**：S
- **依赖**：TASK-01
- **涉及文件**：
  - **新建文件**：
    - `src/app/services/webmcp/SessionInfo.cj` — 参考 `src/app/services/webmcp/DeviceInfo.cj`（TASK-01 新建的同类数据模型）、`src/app/services/webmcp/WebMCPProtocol.cj`（同目录下已有的类定义模式）
- **任务描述**：
  创建会话信息数据结构，包含 sessionId（UUID v4）、clientId、status（active/idle/closed）、createdAt（毫秒时间戳）、lastActivityAt、protocol（WebMCPProtocol 引用）、type（SSE/StreamableHTTP/WebSocket）、user（用户信息）、device（DeviceInfo）字段。提供 updateActivity() 方法更新最后活动时间，提供 toJson() 方法输出兼容 WebAgent API 格式的 JSON。

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考（特别是同目录下已有的 .cj 文件）
  - 参考文件包括但不限于：
    - TASK-01 新建的 `DeviceInfo.cj` 中的数据模型和 toJson() 模式
    - `WebMCPProtocol.cj` 中的类定义和成员变量声明模式
    - CangjieMagic 框架的 DateTime 使用约定
  - 遵循 cangjie-coder 技能的四步工作流程：查阅 CangjieSkills 技能 → 检索代码片段 → 编辑适配 → 写入文件

- **验收标准**：
  1. SessionInfo 类可正常实例化，所有字段正确初始化
  2. updateActivity() 方法正确更新 lastActivityAt 时间戳
  3. toJson() 输出包含 sessionId、clientId、status、type、user、device 字段
  4. createdAt 和 lastActivityAt 使用 DateTime 获取毫秒时间戳

### TASK-03：新增 SessionManager 会话管理器

- **关联需求**：REQ-04, REQ-08, REQ-09
- **优先级**：P0
- **预估复杂度**：M
- **依赖**：TASK-02
- **涉及文件**：
  - **新建文件**：
    - `src/app/services/webmcp/SessionManager.cj` — 参考 `src/app/services/webmcp/WebMCPProtocol.cj`（同目录下已有的 HashMap 和日志使用模式）、`src/app/controllers/uctoo/webmcp/WebMCPController.cj`（会话管理相关代码）
- **任务描述**：
  创建会话管理器，使用 HashMap 存储会话，提供以下核心方法：createSession（生成 UUID sessionId，创建 SessionInfo）、getSession、hasSession、removeSession、updateActivity、getAllSessions、getAllSessionIds、getActiveSessionCount、canCreateSession（检查是否超过 maxSessions，默认100）、resetSession、resetAllSessions、checkSessionAlive、findBySuffix（按 sessionId 后6位匹配）、cleanupExpiredSessions（清理超过 sessionTimeoutMs 无活动的会话，默认24小时）。构造函数接受 maxSessions 和 sessionTimeoutMs 可选参数。

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考（特别是同目录下已有的 .cj 文件）
  - 参考文件包括但不限于：
    - `WebMCPProtocol.cj` 中的 HashMap 使用和 LogUtils 日志记录模式
    - `WebMCPController.cj` 中的会话管理相关代码（_sessions 变量使用模式）
    - CangjieMagic 框架的 UUID 生成和 DateTime 时间计算约定
  - 遵循 cangjie-coder 技能的四步工作流程：查阅 CangjieSkills 技能 → 检索代码片段 → 编辑适配 → 写入文件

- **验收标准**：
  1. createSession 生成 UUID v4 格式的 sessionId，不同调用生成不同 ID
  2. getSession 和 hasSession 正确查询会话
  3. removeSession 正确移除会话并记录日志
  4. cleanupExpiredSessions 正确清理超过超时时间的会话
  5. canCreateSession 在会话数达到上限时返回 false
  6. findBySuffix 支持后6位匹配和完整 ID 匹配
  7. 所有操作记录 INFO 级别日志

### TASK-04：重构 WebMCPController 会话管理逻辑

- **关联需求**：REQ-04, REQ-09
- **优先级**：P0
- **预估复杂度**：M
- **依赖**：TASK-03
- **涉及文件**：
  - **修改文件**：
    - `src/app/controllers/uctoo/webmcp/WebMCPController.cj` — 参考同文件中已有的 handleStreamableHttp 和 handleConnection 方法
- **任务描述**：
  1. 新增 `_sessionManager` 成员变量（SessionManager 实例）
  2. 重构 `handleStreamableHttp()` 方法：移除硬编码的 `"webmcp-default"` sessionId，改为从请求头 `Mcp-Session-Id` 或 `stream-session-id` 读取 sessionId；若 sessionId 存在且会话有效则复用 WebMCPProtocol 实例，否则创建新会话；在响应头中返回 `Mcp-Session-Id`
  3. 新增 `_extractDeviceInfo(req)` 私有方法，从请求头提取 x-forwarded-for、user-agent、accept-language、referer 信息
  4. 修改 WebSocket `handleConnection(ctx)` 方法：使用 SessionManager 管理会话，断连时调用 removeSession
  5. 在构造函数中启动定时清理任务（每5分钟调用 cleanupExpiredSessions）
  6. 新连接时检查 canCreateSession，超限时返回 503 错误

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考（特别是同目录下已有的 .cj 文件）
  - 参考文件包括但不限于：
    - 同文件中已有的 `handleStreamableHttp()` 方法中的请求头读取和响应设置模式
    - 同文件中已有的 `handleConnection()` 方法中的 WebSocket 会话管理模式
    - `SessionManager.cj`（TASK-03 新建）中的会话管理 API
    - `DeviceInfo.cj`（TASK-01 新建）中的设备信息数据结构
    - CangjieMagic 框架的 HTTP 请求/响应处理约定
  - 遵循 cangjie-coder 技能的四步工作流程：查阅 CangjieSkills 技能 → 检索代码片段 → 编辑适配 → 写入文件

- **验收标准**：
  1. 不再使用硬编码 "webmcp-default" 作为 sessionId
  2. 首次请求生成 UUID sessionId，响应头包含 Mcp-Session-Id
  3. 后续请求携带 Mcp-Session-Id 时复用已有会话
  4. WebSocket 断连时正确清理会话
  5. 超过最大会话数时返回 503 错误
  6. 定时清理任务正常启动

### TASK-05：新增 CORS 中间件与统一处理

- **关联需求**：REQ-10
- **优先级**：P1
- **预估复杂度**：S
- **依赖**：无
- **涉及文件**：
  - **修改文件**：
    - `src/app/controllers/uctoo/webmcp/WebMCPController.cj` — 参考同文件中已有的 CORS 头设置代码（需移除）
    - `src/app/routes/webmcp/WebMCPRoutes.cj` — 参考同文件中已有的路由注册代码和中间件使用模式
- **任务描述**：
  1. 在 WebMCPRoutes 中新增 `webmcpCorsMiddleware` 中间件函数，对所有 `/webmcp/*` 路径无条件设置 CORS 头（Access-Control-Allow-Origin: *、Access-Control-Allow-Methods: GET,POST,PUT,DELETE,OPTIONS、Access-Control-Allow-Headers: *、Access-Control-Max-Age: 86400）
  2. OPTIONS 请求返回 204 No Content
  3. 移除 WebMCPController.handleStreamableHttp() 中手动设置的 CORS 头代码
  4. 确保所有 WebMCP 路由注册在 CORS 中间件之后

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考（特别是同目录下已有的 .cj 文件）
  - 参考文件包括但不限于：
    - `WebMCPController.cj` 中已有的 CORS 头设置代码（了解当前模式，需移除）
    - `WebMCPRoutes.cj` 中已有的路由注册代码和中间件使用模式
    - 项目中已有的中间件实现（如 `RequirePermissionMiddleware.cj`）的中间件模式
    - CangjieMagic 框架的中间件和路由注册约定
  - 遵循 cangjie-coder 技能的四步工作流程：查阅 CangjieSkills 技能 → 检索代码片段 → 编辑适配 → 写入文件

- **验收标准**：
  1. 所有 WebMCP 端点响应包含正确的 CORS 头
  2. OPTIONS 预检请求返回 204 + CORS 头
  3. Controller 中不再手动设置 CORS 头
  4. 跨域请求正常工作

### TASK-06：新增 McpTracingMiddleware MCP 追踪中间件

- **关联需求**：REQ-11
- **优先级**：P2
- **预估复杂度**：S
- **依赖**：无
- **涉及文件**：
  - **新建文件**：
    - `src/app/middleware/webmcp/McpTracingMiddleware.cj` — 参考 `src/app/middleware/RequirePermissionMiddleware.cj`（已有的中间件实现模式）
- **任务描述**：
  创建 MCP 追踪中间件，提供 `injectTracingHeaders(req, res, method)` 静态方法，在响应中注入三个追踪头：X-MCP-Request-ID（格式 `mcp_{timestamp}_{random}`）、X-MCP-Method（MCP 方法名）、X-Processing-Start（ISO 8601 格式时间戳）。记录 DEBUG 级别日志。

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考（特别是同目录下已有的 .cj 文件）
  - 参考文件包括但不限于：
    - `src/app/middleware/RequirePermissionMiddleware.cj` 中的中间件定义和静态方法模式
    - `WebMCPController.cj` 中的 HTTP 响应头设置模式
    - CangjieMagic 框架的中间件约定和 UUID/DateTime 使用模式
  - 遵循 cangjie-coder 技能的四步工作流程：查阅 CangjieSkills 技能 → 检索代码片段 → 编辑适配 → 写入文件

- **验收标准**：
  1. injectTracingHeaders 正确注入三个追踪头
  2. X-MCP-Request-ID 格式为 mcp_{timestamp}_{random8位}
  3. X-MCP-Method 为传入的 MCP 方法名
  4. X-Processing-Start 为 ISO 8601 格式时间戳
  5. 记录 DEBUG 级别日志

---

## Phase 2 - 核心协议

> 实现 SSE 流式响应、AI 对话闭环、MCP 方法名统一等核心协议功能。

### TASK-07：实现 SSE 流式响应（Protocol 层）

- **关联需求**：REQ-01
- **优先级**：P0
- **预估复杂度**：L
- **依赖**：TASK-04
- **涉及文件**：
  - **修改文件**：
    - `src/app/services/webmcp/WebMCPProtocol.cj` — 参考同文件中已有的 handleMessage 和 handleCompletionComplete 方法
- **任务描述**：
  1. 新增 `handleStreamCompletion(userMessage, requestId)` 方法：调用 SkillAwareAgent.chat() 或 ChatModel.create() 获取 AI 响应，将完整响应拆分为 SSE 格式事件块（每 20 个字符一块），每个块格式为 `data: {"type":"response.output_text.delta","output_index":0,"delta":"..."}\n\n`，最后发送 `data: [DONE]\n\n` 结束标记
  2. 新增 `handleStreamSendMessage(obj)` 私有方法：解析 sendMessage 请求的 params.message 字段，调用 handleStreamCompletion
  3. 新增 `_processChatRequest(userMessage, isStream, requestId)` 私有方法：统一处理流式和非流式对话请求，流式调用 handleStreamCompletion，非流式调用 SkillAwareAgent.chat() 同步返回
  4. Agent 不可用时降级到 ChatModel，ChatModel 也不可用时返回错误响应（错误码 -32603）

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考（特别是同目录下已有的 .cj 文件）
  - 参考文件包括但不限于：
    - 同文件中已有的 `handleCompletionComplete()` 方法中的 SkillAwareAgent.chat() 调用模式
    - 同文件中已有的 `handleMessage()` 方法中的 JSON-RPC 请求解析模式
    - 同文件中已有的 `createSuccessResponse()` 和 `createErrorResponse()` 方法
    - `src/app/controllers/uctoo/AIController.cj` 中的流式响应实现（handleStreamChat 方法）
    - CangjieMagic 框架的 SSE 输出和 StringBuilder 使用约定
  - 遵循 cangjie-coder 技能的四步工作流程：查阅 CangjieSkills 技能 → 检索代码片段 → 编辑适配 → 写入文件

- **验收标准**：
  1. 流式请求返回 Content-Type: text/event-stream 格式
  2. 每个 SSE 事件块以 `data: ` 前缀和 `\n\n` 后缀分隔
  3. 流式响应以 `data: [DONE]\n\n` 结束
  4. 非流式请求返回标准 JSON-RPC 响应
  5. Agent 不可用时正确降级

### TASK-08：重构 SSE 流式响应（Controller 层）

- **关联需求**：REQ-01
- **优先级**：P0
- **预估复杂度**：M
- **依赖**：TASK-07
- **涉及文件**：
  - **修改文件**：
    - `src/app/controllers/uctoo/webmcp/WebMCPController.cj` — 参考同文件中已有的 handleStreamableHttp 方法
- **任务描述**：
  重构 `handleStreamableHttp()` 方法中的流式分支：当 isStream=true 时，设置 SSE 响应头（Content-Type: text/event-stream、Cache-Control: no-cache、Connection: keep-alive、X-Accel-Buffering: no），调用 Protocol 的 handleStreamCompletion 方法获取 SSE 格式响应，通过 res.send() 发送。移除现有的 `spawn + res.send()` 完整响应体发送逻辑。

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考（特别是同目录下已有的 .cj 文件）
  - 参考文件包括但不限于：
    - 同文件中已有的 `handleStreamableHttp()` 方法中的流式分支代码（需重构）
    - 同文件中已有的 `parseStreamFlag()` 方法
    - `src/app/controllers/uctoo/AIController.cj` 中的 SSE 响应头设置和流式输出模式
    - `WebMCPProtocol.cj`（TASK-07 修改后）中的 handleStreamCompletion 方法签名
    - CangjieMagic 框架的 HTTP 响应头设置约定
  - 遵循 cangjie-coder 技能的四步工作流程：查阅 CangjieSkills 技能 → 检索代码片段 → 编辑适配 → 写入文件

- **验收标准**：
  1. 流式响应头包含 Content-Type: text/event-stream
  2. 不再使用 spawn + res.send() 发送完整响应体
  3. 流式响应内容为 SSE 格式（data: {...}\n\n）
  4. 非流式响应保持原有 JSON 格式

### TASK-09：实现 AI 对话闭环（sendMessage 方法）

- **关联需求**：REQ-02
- **优先级**：P0
- **预估复杂度**：M
- **依赖**：TASK-07
- **涉及文件**：
  - **修改文件**：
    - `src/app/services/webmcp/WebMCPProtocol.cj` — 参考同文件中已有的 handleSendMessage 和 handleCompletionComplete 方法
- **任务描述**：
  重写 `handleSendMessage()` 方法：解析 params.message 和 params.stream 字段，调用 `_processChatRequest(userMessage, isStream, requestId)` 统一处理。移除原有的"WebMCP protocol does not support direct model calls"固定返回。sendMessage 和 completion/complete 共享同一个 SkillAwareAgent 实例，确保多轮对话上下文一致。非流式模式加载历史上下文（复用 handleCompletionComplete 中的 CheckpointManager 逻辑），调用 Agent 后异步同步 Agent 状态到数据库。

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考（特别是同目录下已有的 .cj 文件）
  - 参考文件包括但不限于：
    - 同文件中已有的 `handleSendMessage()` 方法（需重写）
    - 同文件中已有的 `handleCompletionComplete()` 方法中的 CheckpointManager 和 Agent 调用模式
    - 同文件中已有的 `_processChatRequest()` 方法（TASK-07 新增）
    - `AgentRuntimeBridge` 的 syncToDatabase 调用模式
    - CangjieMagic 框架的 Agent 对话和上下文管理约定
  - 遵循 cangjie-coder 技能的四步工作流程：查阅 CangjieSkills 技能 → 检索代码片段 → 编辑适配 → 写入文件

- **验收标准**：
  1. sendMessage 请求正确调用 SkillAwareAgent.chat() 返回 AI 响应
  2. 非流式模式返回包含 messageId、streaming=false、response 字段的 JSON-RPC 响应
  3. 流式模式调用 handleStreamCompletion 返回 SSE 格式响应
  4. 同一会话中 sendMessage 和 completion/complete 共享对话历史
  5. Agent 不可用时降级到 ChatModel
  6. 不再返回"WebMCP protocol does not support direct model calls"

### TASK-10：MCP 协议方法名统一与废弃警告

- **关联需求**：REQ-06
- **优先级**：P1
- **预估复杂度**：M
- **依赖**：TASK-09
- **涉及文件**：
  - **修改文件**：
    - `src/app/services/webmcp/WebMCPProtocol.cj` — 参考同文件中已有的 handleMethod 方法和 skillToJson 方法
- **任务描述**：
  1. 新增 `DEPRECATED_METHODS` 静态映射表：getTools→tools/list、listTools→tools/list、invokeTool→tools/call、tools/invoke→tools/call、registerTool→tools/register
  2. 重构 `handleMethod()` 方法：检查方法名是否在废弃映射表中，若是则记录 WARN 日志（"Deprecated method 'xxx', use 'yyy' instead"），转换为标准方法名后调用 handleStandardMethod()
  3. 新增 `handleStandardMethod()` 方法：使用 match 表达式分发到具体处理方法（initialize、tools/list、tools/call、tools/register、sendMessage、completion/complete、listSessions、closeSession、notifications/*）
  4. 新增 `_addDeprecationWarning()` 私有方法：在响应的 result 中添加 deprecationWarning 字段（包含 deprecated: true、method、useInstead）

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考（特别是同目录下已有的 .cj 文件）
  - 参考文件包括但不限于：
    - 同文件中已有的 `handleMethod()` 方法（需重构）
    - 同文件中已有的 `skillToJson()` 方法中的 JsonObject 构建模式
    - 同文件中已有的 `createSuccessResponse()` 和 `createErrorResponse()` 方法
    - CangjieMagic 框架的 match 表达式和 HashMap 静态初始化约定
  - 遵循 cangjie-coder 技能的四步工作流程：查阅 CangjieSkills 技能 → 检索代码片段 → 编辑适配 → 写入文件

- **验收标准**：
  1. 使用标准方法名（tools/list、tools/call）正常处理
  2. 使用废弃方法名（getTools、invokeTool）时正常处理但记录 WARN 日志
  3. 废弃方法名的响应中包含 deprecationWarning 字段
  4. 新增方法必须遵循 domain/action 格式

---

## Phase 3 - 工具系统

> 实现前端工具注册、工具调用闭环，使 Agent 能感知和调用前端工具。

### TASK-11：新增 FrontendToolRegistry 前端工具注册表

- **关联需求**：REQ-03
- **优先级**：P0
- **预估复杂度**：M
- **依赖**：无
- **涉及文件**：
  - **新建文件**：
    - `src/app/services/webmcp/FrontendToolRegistry.cj` — 参考 `src/app/services/webmcp/WebMCPProtocol.cj`（同目录下已有的 skillToJson 方法和 JsonObject 使用模式）
- **任务描述**：
  创建前端工具注册表，包含两个核心类：
  1. `FrontendToolDefinition`：前端工具定义，包含 name、title、description、inputSchema（JsonObject）、route、annotations（JsonObject）字段。提供 toMcpToolJson() 方法转换为 MCP 协议格式的工具对象，annotations 中包含 isFrontendTool: true 和 route 字段
  2. `FrontendToolRegistry`：使用 HashMap<String, FrontendToolDefinition> 存储工具，提供 register（同名工具覆盖注册）、unregister、getTool、getAllTools、clear、contains、size 方法

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考（特别是同目录下已有的 .cj 文件）
  - 参考文件包括但不限于：
    - `WebMCPProtocol.cj` 中的 `skillToJson()` 方法的 JsonObject 构建模式
    - `WebMCPProtocol.cj` 中的 HashMap 使用和 LogUtils 日志记录模式
    - `DeviceInfo.cj`（TASK-01 新建）中的数据模型定义模式
    - CangjieMagic 框架的 JsonObject/JsonArray/JsonString 使用约定
  - 遵循 cangjie-coder 技能的四步工作流程：查阅 CangjieSkills 技能 → 检索代码片段 → 编辑适配 → 写入文件

- **验收标准**：
  1. FrontendToolDefinition 可正常实例化和序列化
  2. toMcpToolJson() 输出包含 name、description、inputSchema、annotations（含 isFrontendTool: true）
  3. register 方法正确存储工具，同名工具覆盖
  4. getAllTools 返回所有已注册工具

### TASK-12：实现 tools/register 方法处理

- **关联需求**：REQ-03
- **优先级**：P0
- **预估复杂度**：M
- **依赖**：TASK-11
- **涉及文件**：
  - **修改文件**：
    - `src/app/services/webmcp/WebMCPProtocol.cj` — 参考同文件中已有的 handleGetTools 和 handleInvokeTool 方法
- **任务描述**：
  1. 新增 `_frontendToolRegistry` 成员变量（FrontendToolRegistry 实例）
  2. 新增 `handleToolsRegister(obj)` 私有方法：解析 params.tool 字段，校验必填字段（name、description、inputSchema），提取可选字段（title、route、annotations），创建 FrontendToolDefinition 并注册到 _frontendToolRegistry，返回成功响应
  3. 修改 `handleGetTools(obj)` 方法：在返回后端技能列表后，追加 _frontendToolRegistry.getAllTools() 的前端工具（带 isFrontendTool 标记）
  4. 修改 `getTools()` 公共方法：同样合并前端工具

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考（特别是同目录下已有的 .cj 文件）
  - 参考文件包括但不限于：
    - 同文件中已有的 `handleGetTools()` 方法中的技能列表构建和 JsonArray 使用模式
    - 同文件中已有的 `handleInvokeTool()` 方法中的参数解析和校验模式
    - `FrontendToolRegistry.cj`（TASK-11 新建）中的注册和查询 API
    - CangjieMagic 框架的 JSON-RPC 请求处理和响应构建约定
  - 遵循 cangjie-coder 技能的四步工作流程：查阅 CangjieSkills 技能 → 检索代码片段 → 编辑适配 → 写入文件

- **验收标准**：
  1. tools/register 请求正确存储前端工具定义
  2. 缺少必填字段时返回 -32602 错误
  3. tools/list 响应包含后端技能和前端工具的合并列表
  4. 前端工具带 annotations.isFrontendTool: true 标记
  5. 同名工具重复注册时覆盖

### TASK-13：实现前端工具调用闭环

- **关联需求**：REQ-05
- **优先级**：P0
- **预估复杂度**：L
- **依赖**：TASK-12
- **涉及文件**：
  - **修改文件**：
    - `src/app/services/webmcp/WebMCPProtocol.cj` — 参考同文件中已有的 handleInvokeTool 方法
    - `src/app/controllers/uctoo/webmcp/WebMCPController.cj` — 参考同文件中已有的 handleStreamableHttp 方法
    - `src/app/routes/webmcp/WebMCPRoutes.cj` — 参考同文件中已有的路由注册代码
- **任务描述**：
  1. 修改 `handleInvokeTool()` 方法：先查后端技能（SkillManager），未找到再查前端工具（FrontendToolRegistry），若为前端工具则调用 `_invokeFrontendTool()`
  2. 新增 `_invokeFrontendTool(toolDef, argsMap, requestId)` 私有方法：生成唯一 callId，构建包含 isFrontendTool: true、toolName、route、input、callId 的响应，由前端 SDK 拦截并执行
  3. 在 WebMCPController 中新增 `_pendingToolCalls` 成员变量（HashMap<String, (String) -> Unit>）和 `handleToolResult(req, res)` 方法：接收前端工具执行结果回传，查找等待中的调用回调并触发
  4. 在 WebMCPRoutes 中新增 POST /api/v1/uctoo/webmcp/tool-result 路由

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考（特别是同目录下已有的 .cj 文件）
  - 参考文件包括但不限于：
    - `WebMCPProtocol.cj` 中已有的 `handleInvokeTool()` 方法中的技能查找和调用模式
    - `WebMCPController.cj` 中已有的 `handleStreamableHttp()` 方法中的请求处理和响应构建模式
    - `WebMCPRoutes.cj` 中已有的路由注册代码模式
    - `FrontendToolRegistry.cj`（TASK-11 新建）中的工具查询 API
    - CangjieMagic 框架的 HashMap、Lambda 和 HTTP 路由注册约定
  - 遵循 cangjie-coder 技能的四步工作流程：查阅 CangjieSkills 技能 → 检索代码片段 → 编辑适配 → 写入文件

- **验收标准**：
  1. tools/call 请求先查后端技能，未找到再查前端工具
  2. 前端工具调用返回包含 isFrontendTool: true 的响应
  3. 前端工具执行结果可通过 tool-result 端点回传
  4. 后端技能调用不受影响

### TASK-14：前端工具注册方法名修改

- **关联需求**：REQ-03, REQ-06
- **优先级**：P0
- **预估复杂度**：S
- **依赖**：TASK-12
- **涉及文件**：
  - **修改文件**：
    - `apps/web-admin/web/src/App.vue` — 参考同文件中已有的 syncFrontendToolsToBackend 函数
- **任务描述**：
  修改 `syncFrontendToolsToBackend()` 函数中所有工具注册请求的 method 字段，从 `registerTool` 改为 `tools/register`。涉及方式1（invoke 方法）、方式2（transport.send）、方式3（transport.postMessage）、方式4（transport.write）中的所有 JSON-RPC 请求构建。

- **验收标准**：
  1. 所有工具注册请求使用 `tools/register` 方法名
  2. 工具同步功能正常工作
  3. 后端正确接收并处理 tools/register 请求

### TASK-15：前端工具调用处理优化

- **关联需求**：REQ-05
- **优先级**：P1
- **预估复杂度**：M
- **依赖**：TASK-13, TASK-14
- **涉及文件**：
  - **修改文件**：
    - `apps/web-admin/web/src/App.vue` — 参考同文件中已有的 handleToolCallResult 函数
    - `apps/web-admin/web/src/mcp-servers/index.ts` — 参考同文件中已有的工具注册协议代码
- **任务描述**：
  1. 优化 `handleToolCallResult()` 函数：当检测到 isFrontendTool 响应时，调用 callPageTool 执行前端工具，然后通过 HTTP POST 将结果回传到后端 /api/v1/uctoo/webmcp/tool-result 端点
  2. 在 mcp-servers/index.ts 中调整工具注册协议，确保 inputSchema 格式符合 MCP 标准（type: object、properties、additionalProperties: false）

- **验收标准**：
  1. 前端工具调用结果正确回传到后端
  2. callId 正确关联请求和响应
  3. 工具执行超时时返回错误信息

---

## Phase 4 - WebAgent 适配

> 实现 SSE Inspector/Proxy 双模式、Remoter 遥控、Ping 检查、健康检查等 WebAgent 核心功能。

### TASK-16：新增 SSEConnectionManager SSE 连接管理器

- **关联需求**：REQ-07, REQ-11
- **优先级**：P1
- **预估复杂度**：M
- **依赖**：无
- **涉及文件**：
  - **新建文件**：
    - `src/app/services/webmcp/SSEConnectionManager.cj` — 参考 `src/app/controllers/uctoo/AIController.cj`（流式响应实现）、`src/app/services/webmcp/WebMCPProtocol.cj`（同目录下已有的 HashMap 和日志使用模式）
- **任务描述**：
  创建 SSE 连接管理器，包含：
  1. `SSEWriter` 接口：抽象 SSE 消息写入能力，提供 write(data: Array<UInt8>) 和 isClosed() 方法
  2. `SSEConnectionManager` 类：使用 HashMap<String, SSEWriter> 存储连接，提供 addConnection、removeConnection、getConnection、pushMessage（发送 event+data 格式消息）、sendHeartbeat（发送 `: ping\n\n` 心跳注释）、getActiveConnectionIds、hasConnection 方法

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考（特别是同目录下已有的 .cj 文件）
  - 参考文件包括但不限于：
    - `src/app/controllers/uctoo/AIController.cj` 中的流式响应和 SSE 输出实现模式
    - `WebMCPProtocol.cj` 中的 HashMap 使用和 LogUtils 日志记录模式
    - `SessionManager.cj`（TASK-03 新建）中的管理器类定义模式
    - CangjieMagic 框架的接口定义和 SSE 消息格式约定
  - 遵循 cangjie-coder 技能的四步工作流程：查阅 CangjieSkills 技能 → 检索代码片段 → 编辑适配 → 写入文件

- **验收标准**：
  1. SSEWriter 接口正确定义
  2. pushMessage 正确发送 SSE 格式消息（event: xxx\ndata: yyy\n\n）
  3. sendHeartbeat 正确发送心跳注释（: ping\n\n）
  4. 连接写入失败时自动移除连接

### TASK-17：新增 RemoterSessionInfo 和 RemoterManager

- **关联需求**：REQ-11
- **优先级**：P1
- **预估复杂度**：M
- **依赖**：TASK-01
- **涉及文件**：
  - **新建文件**：
    - `src/app/services/webmcp/RemoterSessionInfo.cj` — 参考 `src/app/services/webmcp/SessionInfo.cj`（TASK-02 新建的同类数据模型）
    - `src/app/services/webmcp/RemoterManager.cj` — 参考 `src/app/services/webmcp/SessionManager.cj`（TASK-03 新建的管理器模式）
- **任务描述**：
  1. 创建 `RemoterSessionInfo` 类：包含 sessionId（控制端）、clientSessionId（关联的被控端）、user、device（DeviceInfo）、type（SSE/StreamableHTTP）、createdAt 字段，提供 toJson() 方法
  2. 创建 `RemoterManager` 类：使用两个 HashMap 存储（_remoterSessions: remoterSessionId→RemoterSessionInfo，_clientToRemoters: clientSessionId→[remoterSessionId]），提供 registerRemoter、removeRemoter、removeAllRemoters、getRemotersForClient、getAllRemoterSessions、hasRemotersForClient 方法

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考（特别是同目录下已有的 .cj 文件）
  - 参考文件包括但不限于：
    - `SessionInfo.cj`（TASK-02 新建）中的数据模型和 toJson() 模式
    - `SessionManager.cj`（TASK-03 新建）中的管理器类定义和 HashMap 使用模式
    - `DeviceInfo.cj`（TASK-01 新建）中的设备信息引用
    - CangjieMagic 框架的 ArrayList 和 HashMap 操作约定
  - 遵循 cangjie-coder 技能的四步工作流程：查阅 CangjieSkills 技能 → 检索代码片段 → 编辑适配 → 写入文件

- **验收标准**：
  1. RemoterSessionInfo 正确存储控制端会话信息
  2. registerRemoter 正确建立控制端与被控端的映射
  3. getRemotersForClient 正确返回指定被控端的所有控制端
  4. removeRemoter 正确清理映射关系

### TASK-18：实现 SSE Inspector/Proxy 双模式

- **关联需求**：REQ-07, REQ-11
- **优先级**：P1
- **预估复杂度**：XL
- **依赖**：TASK-04, TASK-16, TASK-17
- **涉及文件**：
  - **修改文件**：
    - `src/app/controllers/uctoo/webmcp/WebMCPController.cj` — 参考同文件中已有的 handleStreamableHttp 和 handleConnection 方法
- **任务描述**：
  1. 新增 `_sseConnectionManager` 和 `_remoterManager` 成员变量
  2. 新增 `handleSSEConnection(req, res)` 方法：
     - Proxy 模式（无 sessionId 查询参数）：创建新 WebMCPProtocol 实例，生成 sessionId，注册到 SessionManager，发送 endpoint 事件（`event: endpoint\ndata: /messages?sessionId=xxx\n\n`），存储 SSE 连接，启动心跳循环
     - Inspector 模式（携带 sessionId 查询参数）：验证被控端会话存在，生成控制端 sessionId，注册到 RemoterManager，发送 endpoint 事件，存储 SSE 连接，启动心跳循环
     - 支持 sse-session-id 请求头复用会话标识
  3. 新增 `_startHeartbeatLoop(sessionId, writer)` 私有方法：每30秒发送心跳，连接关闭时清理资源
  4. 新增 `handleSSEMessage(req, res)` 方法：从查询参数获取 sessionId，获取对应 Protocol 实例处理请求，通过 SSE 通道推送响应，同时推送到关联的 Inspector 连接，返回 202 Accepted

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考（特别是同目录下已有的 .cj 文件）
  - 参考文件包括但不限于：
    - 同文件中已有的 `handleStreamableHttp()` 方法中的请求头读取和会话管理模式
    - 同文件中已有的 `handleConnection()` 方法中的 WebSocket 连接管理模式
    - `SSEConnectionManager.cj`（TASK-16 新建）中的 SSE 连接管理和消息推送 API
    - `RemoterManager.cj`（TASK-17 新建）中的控制端注册和查询 API
    - `SessionManager.cj`（TASK-03 新建）中的会话创建和查询 API
    - CangjieMagic 框架的 SSE 响应头设置、spawn 并发和 sleep 定时约定
  - 遵循 cangjie-coder 技能的四步工作流程：查阅 CangjieSkills 技能 → 检索代码片段 → 编辑适配 → 写入文件

- **验收标准**：
  1. GET /sse 无 sessionId 时创建新会话（Proxy 模式）
  2. GET /sse?sessionId=xxx 时关联已有会话（Inspector 模式）
  3. SSE 连接建立后首先发送 endpoint 事件
  4. 心跳每30秒发送一次
  5. Inspector 模式下被控端消息同步推送到控制端
  6. Inspector 模式目标会话不存在时返回 400 错误

### TASK-19：实现 Ping 健康检查

- **关联需求**：REQ-11
- **优先级**：P1
- **预估复杂度**：M
- **依赖**：TASK-04, TASK-16, TASK-17
- **涉及文件**：
  - **修改文件**：
    - `src/app/controllers/uctoo/webmcp/WebMCPController.cj` — 参考同文件中已有的会话管理代码
- **任务描述**：
  新增 `handlePing(req, res)` 方法：遍历所有被控端会话，SSE 类型检查 SSEConnectionManager.hasConnection()，无连接的会话被清理；遍历所有控制端会话，检查 SSE 连接存活，无连接的被清理；返回包含 clientSessions（被清理的客户端会话ID数组）和 remoterSessions（被清理的控制端会话ID数组）的 JSON 响应。内部异常时返回 500 错误。

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考（特别是同目录下已有的 .cj 文件）
  - 参考文件包括但不限于：
    - 同文件中已有的会话管理代码（_sessionManager 使用模式）
    - `SSEConnectionManager.cj`（TASK-16 新建）中的连接检查和清理 API
    - `RemoterManager.cj`（TASK-17 新建）中的控制端查询和清理 API
    - CangjieMagic 框架的 ArrayList 遍历和 JsonObject/JsonArray 构建约定
  - 遵循 cangjie-coder 技能的四步工作流程：查阅 CangjieSkills 技能 → 检索代码片段 → 编辑适配 → 写入文件

- **验收标准**：
  1. GET /ping 正确检查所有会话连通性
  2. 无 SSE 连接的会话被自动清理
  3. 返回被清理的 sessionId 列表
  4. 内部异常时返回 500 错误

### TASK-20：实现 StreamableHTTP 完整方法支持（GET/DELETE /mcp）

- **关联需求**：REQ-11
- **优先级**：P1
- **预估复杂度**：M
- **依赖**：TASK-18
- **涉及文件**：
  - **修改文件**：
    - `src/app/controllers/uctoo/webmcp/WebMCPController.cj` — 参考同文件中已有的 handleStreamableHttp 和 handleSSEConnection 方法
- **任务描述**：
  1. 新增 `handleMcpGet(req, res)` 方法：检查 Accept 头是否包含 text/event-stream，若是则根据 mcp-session-id 头判断 Inspector/Proxy 模式，调用 handleSSEConnection；否则返回 405
  2. 新增 `handleMcpDelete(req, res)` 方法：检查 mcp-session-id 头，调用 SessionManager.removeSession 清理会话，清理 SSE 连接和关联的 Remoter，返回成功响应；缺少 sessionId 头时返回 400 错误

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考（特别是同目录下已有的 .cj 文件）
  - 参考文件包括但不限于：
    - 同文件中已有的 `handleStreamableHttp()` 方法中的请求头读取模式
    - 同文件中已有的 `handleSSEConnection()` 方法（TASK-18 新增）中的 SSE 连接处理模式
    - `SessionManager.cj`（TASK-03 新建）中的会话移除 API
    - `SSEConnectionManager.cj`（TASK-16 新建）中的连接清理 API
    - `RemoterManager.cj`（TASK-17 新建）中的控制端清理 API
    - CangjieMagic 框架的 HTTP 请求头检查和响应状态码设置约定
  - 遵循 cangjie-coder 技能的四步工作流程：查阅 CangjieSkills 技能 → 检索代码片段 → 编辑适配 → 写入文件

- **验收标准**：
  1. GET /mcp (Accept: text/event-stream) 建立 SSE 连接
  2. DELETE /mcp (mcp-session-id: xxx) 关闭指定会话
  3. 缺少 mcp-session-id 头时返回 400 错误
  4. 非 SSE 的 GET /mcp 返回 405

### TASK-21：实现会话管理 REST API

- **关联需求**：REQ-08, REQ-11
- **优先级**：P1
- **预估复杂度**：M
- **依赖**：TASK-04, TASK-17
- **涉及文件**：
  - **修改文件**：
    - `src/app/controllers/uctoo/webmcp/WebMCPController.cj` — 参考同文件中已有的会话管理代码和 HTTP 响应构建模式
- **任务描述**：
  新增以下 Controller 方法：
  1. `handleClientList(req, res)`：GET /list，返回所有被控端会话列表（兼容 WebAgent 格式：sessionId→{user, device, type}）
  2. `handleRemoterList(req, res)`：GET /remoter，返回所有控制端会话列表
  3. `handleResetAll(req, res)`：GET /reset，重置所有客户端与控制端会话
  4. `handleResetSessionAPI(req, res)`：POST /sessions/{sessionId}/reset，重置指定会话
  5. `handleListToolsAPI(req, res)`：GET /tools?sessionId=xxx，返回指定会话的可用工具列表
  6. `handleGetClientInfoAPI(req, res)`：GET /client?sessionId=xxx，查询指定客户端会话信息（支持后6位匹配）

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考（特别是同目录下已有的 .cj 文件）
  - 参考文件包括但不限于：
    - 同文件中已有的会话管理代码（_sessionManager 使用模式）
    - 同文件中已有的 HTTP 响应构建模式（res.status().json() 调用）
    - `RemoterManager.cj`（TASK-17 新建）中的控制端查询 API
    - `SessionManager.cj`（TASK-03 新建）中的 findBySuffix 和 getAllSessions API
    - CangjieMagic 框架的 HTTP 请求查询参数读取和 JsonObject 响应构建约定
  - 遵循 cangjie-coder 技能的四步工作流程：查阅 CangjieSkills 技能 → 检索代码片段 → 编辑适配 → 写入文件

- **验收标准**：
  1. GET /list 返回兼容 WebAgent 格式的会话列表
  2. GET /remoter 返回控制端会话列表
  3. GET /reset 正确重置所有会话
  4. GET /tools 正确返回工具列表
  5. GET /client 支持完整 ID 和后6位匹配

### TASK-22：实现健康检查端点完善

- **关联需求**：REQ-11
- **优先级**：P2
- **预估复杂度**：S
- **依赖**：TASK-04, TASK-16
- **涉及文件**：
  - **修改文件**：
    - `src/app/controllers/uctoo/webmcp/WebMCPController.cj` — 参考同文件中已有的 handleHealthCheck 方法（如存在）
- **任务描述**：
  新增三个健康检查方法：
  1. `handleHealthCheck(req, res)`：GET /health，返回 name、version、status、uptime、environment、endpoints 信息
  2. `handleDetailedHealth(req, res)`：GET /health/detailed，返回 status、version、activeSessions、sseConnections 信息
  3. `handleMetrics(req, res)`：GET /health/metrics，返回 system.process.uptime、activeSessions、sseConnections 指标

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考（特别是同目录下已有的 .cj 文件）
  - 参考文件包括但不限于：
    - 同文件中已有的健康检查方法（如 handleHealthCheck）
    - 同文件中已有的 JsonObject 响应构建模式
    - `SessionManager.cj`（TASK-03 新建）中的 getActiveSessionCount API
    - `SSEConnectionManager.cj`（TASK-16 新建）中的 getActiveConnectionIds API
    - CangjieMagic 框架的 DateTime 使用和 JsonObject/JsonInt 构建约定
  - 遵循 cangjie-coder 技能的四步工作流程：查阅 CangjieSkills 技能 → 检索代码片段 → 编辑适配 → 写入文件

- **验收标准**：
  1. GET /health 返回服务基础信息和端点列表
  2. GET /health/detailed 返回活跃会话数和 SSE 连接数
  3. GET /health/metrics 返回性能和监控指标

---

## Phase 5 - 路由注册与集成验证

> 注册所有新增路由，集成 MCP 追踪头，进行端到端验证。

### TASK-23：注册所有新增路由

- **关联需求**：REQ-07, REQ-08, REQ-11
- **优先级**：P1
- **预估复杂度**：M
- **依赖**：TASK-18, TASK-19, TASK-20, TASK-21, TASK-22
- **涉及文件**：
  - **修改文件**：
    - `src/app/routes/webmcp/WebMCPRoutes.cj` — 参考同文件中已有的路由注册代码
- **任务描述**：
  重构 WebMCPRoutes.register() 方法，拆分为多个子注册方法：
  1. `registerWebSocketRoutes()`：保留现有 WebSocket 路由
  2. `registerHttpRoutes()`：保留现有 HTTP 路由
  3. `registerSSERoutes()`：新增 GET /sse 和 POST /messages 路由
  4. `registerManagementRoutes()`：新增 /ping、/list、/remoter、/reset、/sessions/{sessionId}/reset、/tools、/client、/tool-result、GET /mcp、DELETE /mcp 路由
  5. `registerHealthRoutes()`：新增 /health、/health/detailed、/health/metrics 路由
  6. `registerWebAgentCompatRoutes()`：注册 /api/v1/webmcp/* 兼容路径（ping、list、remoter、reset、tools、client、sse、messages、mcp GET/POST/DELETE）
  7. 所有路由组注册前应用 CORS 中间件

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考（特别是同目录下已有的 .cj 文件）
  - 参考文件包括但不限于：
    - 同文件中已有的路由注册代码（_router.get/post/delete 调用模式）
    - 同文件中已有的 CORS 中间件应用模式（TASK-05 新增的 webmcpCorsMiddleware）
    - CangjieMagic 框架的路由注册和 Lambda 回调约定
  - 遵循 cangjie-coder 技能的四步工作流程：查阅 CangjieSkills 技能 → 检索代码片段 → 编辑适配 → 写入文件

- **验收标准**：
  1. 所有新增端点可通过 /api/v1/uctoo/webmcp/* 路径访问
  2. 兼容路径 /api/v1/webmcp/* 同样可用
  3. CORS 中间件正确应用于所有路由
  4. 路由注册日志正确输出

### TASK-24：集成 MCP 追踪头到 /mcp 端点

- **关联需求**：REQ-11
- **优先级**：P2
- **预估复杂度**：S
- **依赖**：TASK-06, TASK-08
- **涉及文件**：
  - **修改文件**：
    - `src/app/controllers/uctoo/webmcp/WebMCPController.cj` — 参考同文件中已有的 handleStreamableHttp 方法
- **任务描述**：
  在 `handleStreamableHttp()` 方法中，解析请求体获取 MCP 方法名，调用 `McpTracingMiddleware.injectTracingHeaders(req, res, method)` 注入追踪头。确保在响应发送前完成追踪头注入。

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考（特别是同目录下已有的 .cj 文件）
  - 参考文件包括但不限于：
    - 同文件中已有的 `handleStreamableHttp()` 方法中的请求体解析模式
    - `McpTracingMiddleware.cj`（TASK-06 新建）中的 injectTracingHeaders 静态方法
    - CangjieMagic 框架的 HTTP 响应头设置约定
  - 遵循 cangjie-coder 技能的四步工作流程：查阅 CangjieSkills 技能 → 检索代码片段 → 编辑适配 → 写入文件

- **验收标准**：
  1. /mcp 端点所有响应包含 X-MCP-Request-ID 头
  2. /mcp 端点所有响应包含 X-MCP-Method 头
  3. /mcp 端点所有响应包含 X-Processing-Start 头
  4. 追踪头格式符合规范

### TASK-25：修改 WebMCPProtocol 构造函数支持 Agent 实例注入

- **关联需求**：REQ-04
- **优先级**：P1
- **预估复杂度**：S
- **依赖**：TASK-04
- **涉及文件**：
  - **修改文件**：
    - `src/app/services/webmcp/WebMCPProtocol.cj` — 参考同文件中已有的构造函数和 setSessionInfo 方法
- **任务描述**：
  确保 WebMCPProtocol 的构造函数在 SessionManager 创建新会话时被正确调用，传入 skillManager、chatModel 和 agentDef 参数。验证 setSessionInfo 方法在会话创建后被调用，设置正确的 sessionId 和 clientId。

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考（特别是同目录下已有的 .cj 文件）
  - 参考文件包括但不限于：
    - 同文件中已有的构造函数定义和成员变量初始化模式
    - 同文件中已有的 `setSessionInfo()` 方法
    - `WebMCPController.cj` 中已有的 WebMCPProtocol 实例化代码
    - CangjieMagic 框架的类构造函数和依赖注入约定
  - 遵循 cangjie-coder 技能的四步工作流程：查阅 CangjieSkills 技能 → 检索代码片段 → 编辑适配 → 写入文件

- **验收标准**：
  1. 新会话创建时 WebMCPProtocol 正确实例化
  2. Agent 实例正确初始化
  3. sessionId 和 clientId 正确设置

### TASK-26：修改 handleInitialize 方法返回动态 sessionId

- **关联需求**：REQ-04
- **优先级**：P0
- **预估复杂度**：S
- **依赖**：TASK-04, TASK-25
- **涉及文件**：
  - **修改文件**：
    - `src/app/services/webmcp/WebMCPProtocol.cj` — 参考同文件中已有的 handleInitialize 方法
- **任务描述**：
  修改 `handleInitialize()` 方法：确保返回的 sessionId 为 SessionManager 生成的动态 UUID，而非硬编码值。从 _sessionId 成员变量获取（由 setSessionInfo 设置）。在 initialize 响应的 result 中正确返回 sessionId。

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考（特别是同目录下已有的 .cj 文件）
  - 参考文件包括但不限于：
    - 同文件中已有的 `handleInitialize()` 方法（需修改）
    - 同文件中已有的 `_sessionId` 成员变量和 `setSessionInfo()` 方法
    - 同文件中已有的 `createSuccessResponse()` 方法
    - CangjieMagic 框架的 JSON-RPC 响应构建约定
  - 遵循 cangjie-coder 技能的四步工作流程：查阅 CangjieSkills 技能 → 检索代码片段 → 编辑适配 → 写入文件

- **验收标准**：
  1. initialize 响应的 sessionId 为动态 UUID
  2. 不同会话的 sessionId 不同
  3. sessionId 与 SessionManager 中存储的一致

---

## 验证与测试

### TASK-27：后端核心功能集成测试

- **关联需求**：REQ-01 ~ REQ-11
- **优先级**：P0
- **预估复杂度**：L
- **依赖**：TASK-08, TASK-09, TASK-13, TASK-18, TASK-23
- **涉及文件**：
  - 测试文件（手动验证）
- **任务描述**：
  执行以下集成测试场景：
  1. **SSE 流式响应测试**：发送 stream=true 的 completion/complete 请求，验证返回 SSE 格式响应
  2. **AI 对话闭环测试**：发送 sendMessage 请求，验证调用 AI 模型并返回响应
  3. **会话管理测试**：验证 UUID sessionId 生成、会话恢复、超时清理
  4. **前端工具注册测试**：发送 tools/register 请求，验证工具存储和 tools/list 合并返回
  5. **前端工具调用闭环测试**：调用前端工具，验证 isFrontendTool 响应和结果回传
  6. **SSE Inspector/Proxy 测试**：验证双模式 SSE 连接
  7. **Ping 健康检查测试**：验证会话清理
  8. **CORS 测试**：验证跨域请求和 OPTIONS 预检
  9. **MCP 追踪头测试**：验证响应头包含追踪信息
  10. **废弃方法名测试**：验证废弃方法名正常处理并返回警告
- **验收标准**：
  1. 所有测试场景通过
  2. 无内存泄漏
  3. 日志输出正确

### TASK-28：前端端到端集成验证

- **关联需求**：REQ-01 ~ REQ-11
- **优先级**：P0
- **预估复杂度**：M
- **依赖**：TASK-14, TASK-15, TASK-27
- **涉及文件**：
  - 前端测试验证
- **任务描述**：
  执行前端端到端验证：
  1. 启动 agentskills-runtime 后端和 web-admin 前端
  2. 验证 TinyRemoter 对话框正常显示
  3. 发送对话消息，验证 AI 响应正常返回
  4. 验证前端工具同步到后端（tools/register）
  5. 触发前端工具调用，验证执行结果回传
  6. 验证流式响应在前端正确显示
  7. 验证 CORS 跨域正常工作
- **验收标准**：
  1. 前端与后端通信正常
  2. AI 对话功能完整可用
  3. 前端工具注册和调用闭环正常
  4. 流式响应正确显示

---

## 任务依赖关系图

```
Phase 1 (基础设施):
  TASK-01 → TASK-02 → TASK-03 → TASK-04
  TASK-05 (独立)
  TASK-06 (独立)

Phase 2 (核心协议):
  TASK-04 → TASK-07 → TASK-08
  TASK-07 → TASK-09 → TASK-10

Phase 3 (工具系统):
  TASK-11 → TASK-12 → TASK-13
  TASK-12 → TASK-14
  TASK-13 + TASK-14 → TASK-15

Phase 4 (WebAgent 适配):
  TASK-01 → TASK-17
  TASK-04 + TASK-16 + TASK-17 → TASK-18
  TASK-04 + TASK-16 + TASK-17 → TASK-19
  TASK-18 → TASK-20
  TASK-04 + TASK-17 → TASK-21
  TASK-04 + TASK-16 → TASK-22

Phase 5 (路由与验证):
  TASK-18 + TASK-19 + TASK-20 + TASK-21 + TASK-22 → TASK-23
  TASK-06 + TASK-08 → TASK-24
  TASK-04 → TASK-25 → TASK-26
  TASK-08 + TASK-09 + TASK-13 + TASK-18 + TASK-23 → TASK-27
  TASK-14 + TASK-15 + TASK-27 → TASK-28
```

## 需求覆盖追踪矩阵

| 需求ID | 覆盖任务 |
|--------|---------|
| REQ-01 SSE 流式响应 | TASK-07, TASK-08 |
| REQ-02 AI 对话闭环 | TASK-09 |
| REQ-03 前端工具注册与同步 | TASK-11, TASK-12, TASK-14 |
| REQ-04 StreamableHTTP 会话标识动态化 | TASK-01, TASK-02, TASK-03, TASK-04, TASK-25, TASK-26 |
| REQ-05 前端工具调用闭环 | TASK-13, TASK-15 |
| REQ-06 MCP 协议方法名统一 | TASK-10, TASK-14 |
| REQ-07 SSE 传输端点 | TASK-16, TASK-18 |
| REQ-08 会话管理 REST API | TASK-02, TASK-03, TASK-21 |
| REQ-09 会话清理机制 | TASK-03, TASK-04 |
| REQ-10 CORS 与 OPTIONS 预检 | TASK-05 |
| REQ-11 WebAgent 架构适配 | TASK-01, TASK-06, TASK-16, TASK-17, TASK-18, TASK-19, TASK-20, TASK-21, TASK-22, TASK-24 |
