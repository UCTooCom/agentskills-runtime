# WebMCP 工具链路闭环 - 编码任务规划

## 开发规范

### 仓颉代码开发
- 所有仓颉（.cj）代码必须使用 **cangjie-coder 技能** 编写
- 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考
- 遵循 cangjie-coder 技能的四步工作流程：查阅 CangjieSkills 技能 → 检索代码片段 → 编辑适配 → 写入文件
- 仓颉代码必须符合 CangjieMagic 框架的约定和模式
- 数据库列名使用 snake_case（deleted_at, updated_at），仓颉代码使用 camelCase（createdAt, updatedAt）
- `type` 是保留关键字，用作变量名时用反引号转义 `` `type` ``
- String 的 trim 方法是 `trimAscii()`
- Duration 用 `Duration.second * N` 和 `Duration.millisecond * N`
- HashMap 用 `add()` 而不是 `put()`
- HttpRequest 的 path 通过 `req.uri.path` 访问
- Condition 需要 ReentrantMutex 配合使用：`let mutex = ReentrantMutex(); let condition = mutex.condition()`
- **同包内的类默认可见，不需要显式 import，否则会产生循环依赖**

### 包依赖方向约束
```
magic.tool.webmcp          ← 基础设施层（WebMCPToolContext、PendingToolCallManager、SSEConnectionManager、FrontendToolRegistry、WebNavigateTool 等）
    ↑
magic.app.services.webmcp  ← 服务层（WebMCPProtocol、MenuDataProvider）
    ↑
magic.app.controllers      ← 控制器层（WebMCPController）
```
- `magic.tool.webmcp` 不能 import `magic.app.services.webmcp`
- `magic.app.services.webmcp` 可以 import `magic.tool.webmcp`
- `magic.skill` 可以 import `magic.tool.webmcp`

### 前端代码开发
- 使用 TypeScript 编写前端代码
- 使用 Vue 3 + Vite 构建前端项目
- 使用 pinia-orm 进行前端 ORM 状态管理
- 使用 @opentiny/next-sdk 的标准接口

---

## 任务概览

| 统计项 | 数量 |
|--------|------|
| 主任务组 | 6 |
| 子任务数 | 24 |
| 覆盖需求 | REQ-TC-01 ~ REQ-TC-08（全部覆盖） |

---

## Phase 1 - 工具链路基础设施（magic.tool.webmcp 包）

> 建立 SSEConnectionManager、WebMCPToolContext、PendingToolCallManager、FrontendToolRegistry 四个核心基础设施组件，为工具调用链路提供 SSE 推送能力、上下文注入、阻塞等待机制和前端工具存储。

### TASK-01：新增 SSEConnectionManager SSE 连接管理器

- **关联需求**：REQ-TC-02, REQ-TC-03
- **优先级**：P0
- **预估复杂度**：M
- **依赖**：无
- **涉及文件**：
  - **新建文件**：
    - `src/tool/webmcp/SSEConnectionManager.cj` — 包名 `magic.tool.webmcp`，同包内已有 WebNavigateTool 等类的 HashMap 和 ReentrantMutex 使用模式
- **任务描述**：
  创建 SSE 连接管理器，管理 SSE 连接的注册、移除和消息推送。核心功能：
  1. `private var _connections = HashMap<String, (String) -> Unit>()` — sessionId → SSE 写入回调
  2. `private let _mutex = ReentrantMutex()` — 保护并发访问
  3. `registerConnection(sessionId: String, writer: (String) -> Unit): Unit` — 注册 SSE 连接
  4. `removeConnection(sessionId: String): Unit` — 移除 SSE 连接
  5. `pushMessage(sessionId: String, eventType: String, data: String): Bool` — 向指定会话推送 SSE 消息，返回 true 表示推送成功，false 表示连接不存在或推送失败（推送失败时自动移除该连接）
  6. `hasConnection(sessionId: String): Bool` — 检查指定会话的 SSE 连接是否存在
  7. 所有读写操作用 `_mutex.lock()` / `_mutex.unlock()` 保护
  8. pushMessage 推送格式：`event: ${eventType}\ndata: ${data}\n\n`
  9. 所有操作记录 DEBUG 级别日志

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考
  - 参考文件包括但不限于：
    - `src/tool/webmcp/web_navigate_tool.cj` 中的 HashMap 使用模式
    - `src/skill/skill_aware_agent.cj` 中的 ReentrantMutex 使用模式
    - CangjieMagic 框架的 HashMap.add() 约定（不是 put()）

- **验收标准**：
  1. SSEConnectionManager 可正常实例化
  2. registerConnection/removeConnection 正确管理连接
  3. pushMessage 向存在的连接推送消息并返回 true
  4. pushMessage 向不存在的连接推送消息返回 false
  5. pushMessage 推送失败时自动移除连接
  6. 并发访问安全（mutex 保护）
  7. 包路径为 `magic.tool.webmcp`

### TASK-02：新增 FrontendToolRegistry 前端工具注册表

- **关联需求**：REQ-TC-01
- **优先级**：P0
- **预估复杂度**：M
- **依赖**：无
- **涉及文件**：
  - **新建文件**：
    - `src/tool/webmcp/FrontendToolRegistry.cj` — 包名 `magic.tool.webmcp`，同包内已有类的 HashMap 和 JsonObject 使用模式
- **任务描述**：
  创建前端工具注册表，存储前端通过 MCP 协议注册的工具元数据。包含两个核心类：
  1. **FrontendToolDefinition**：
     - 公开字段：`name: String`、`title: String`、`description: String`、`inputSchema: JsonObject`、`route: String`、`annotations: ?JsonObject`
     - 构造函数：`init(name, title, description, inputSchema, route, annotations)`
  2. **FrontendToolRegistry**：
     - `private var _tools = HashMap<String, FrontendToolDefinition>()` — name → toolDef 映射
     - `private let _mutex = ReentrantMutex()` — 保护并发访问
     - `register(toolDef: FrontendToolDefinition): Unit` — 注册前端工具（覆盖同名工具）
     - `unregister(name: String): Unit` — 注销前端工具
     - `getAllTools(): ArrayList<FrontendToolDefinition>` — 获取所有已注册的前端工具
     - `getTool(name: String): ?FrontendToolDefinition` — 获取指定名称的前端工具
     - `contains(name: String): Bool` — 检查工具是否已注册
     - 所有操作记录 DEBUG 级别日志

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考
  - 参考文件包括但不限于：
    - `src/tool/webmcp/web_navigate_tool.cj` 中的 HashMap 和 JsonObject 使用模式
    - `src/skill/frontend_tool_adapter.cj` 中的 JsonObject.put() 和 JsonString 使用模式

- **验收标准**：
  1. FrontendToolDefinition 可正常实例化
  2. FrontendToolRegistry 正确注册、注销、查询工具
  3. 同名工具注册时覆盖旧工具
  4. getAllTools 返回所有已注册工具
  5. 包路径为 `magic.tool.webmcp`

### TASK-03：新增 WebMCPToolContext 全局单例

- **关联需求**：REQ-TC-02, REQ-TC-03
- **优先级**：P0
- **预估复杂度**：M
- **依赖**：TASK-01, TASK-02
- **涉及文件**：
  - **新建文件**：
    - `src/tool/webmcp/WebMCPToolContext.cj` — 包名 `magic.tool.webmcp`，同包内 SSEConnectionManager（TASK-01）和 PendingToolCallManager（TASK-04）已就绪
- **任务描述**：
  创建 WebMCP 工具执行上下文全局单例，为 WebMCP 工具提供 SSE 推送能力和会话上下文。**此组件必须放在 `magic.tool.webmcp` 包中**，避免 `magic.tool.webmcp` import `magic.app.services.webmcp` 导致循环依赖。核心功能：
  1. `public static let instance = WebMCPToolContext()` — 全局单例
  2. 私有成员变量：`_sessionId: String`、`_sseManager: ?SSEConnectionManager`、`_pendingManager: ?PendingToolCallManager`
  3. `private let _mutex = ReentrantMutex()` — 保护并发访问
  4. `setSessionContext(sessionId, sseManager, pendingManager)` — 设置当前会话上下文
  5. `clearSessionContext()` — 清除当前会话上下文（所有字段重置为默认值/None）
  6. `getSessionId(): ?String` — 获取当前会话 ID（空字符串返回 None）
  7. `getSSEManager(): ?SSEConnectionManager` — 获取 SSE 连接管理器
  8. `getPendingManager(): ?PendingToolCallManager` — 获取待处理工具调用管理器
  9. 所有读写操作用 `_mutex.lock()` / `_mutex.unlock()` 保护
  10. **同包内类默认可见，不需要 import SSEConnectionManager 和 PendingToolCallManager**

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考
  - 参考文件包括但不限于：
    - 同包内 `SSEConnectionManager.cj`（TASK-01 新建）中的类定义模式
    - 同包内 `PendingToolCallManager.cj`（TASK-04 新建）中的类定义模式
    - CangjieMagic 框架的 Option 类型使用约定
  - **特别注意**：同包内的类默认可见，不需要显式 import，否则会产生循环依赖

- **验收标准**：
  1. WebMCPToolContext 可通过 instance 全局访问
  2. setSessionContext/clearSessionContext 正确设置和清除上下文
  3. getSessionId/getSSEManager/getPendingManager 正确返回当前上下文
  4. 上下文未设置时各 getter 返回 None
  5. 包路径为 `magic.tool.webmcp`（不是 `magic.app.services.webmcp`）
  6. 不存在 import `magic.app.services.webmcp` 的语句

### TASK-04：新增 PendingToolCallManager 待处理工具调用管理器

- **关联需求**：REQ-TC-03, REQ-TC-05
- **优先级**：P0
- **预估复杂度**：L
- **依赖**：无
- **涉及文件**：
  - **新建文件**：
    - `src/tool/webmcp/PendingToolCallManager.cj` — 包名 `magic.tool.webmcp`，同包内已有类的 HashMap 和 ReentrantMutex 使用模式
- **任务描述**：
  创建待处理工具调用管理器，包含两个核心类：
  1. **PendingToolCallEntry**：
     - 公开字段：`callId: String`、`toolName: String`、`createdAt: Int64`（毫秒时间戳）、`timeoutMs: Int64`
     - 阻塞等待机制：`public let mutex = ReentrantMutex()`、`public let condition = Condition()`（Condition 需要 ReentrantMutex 配合使用：`mutex.condition()`）
     - 结果字段：`public var result: String = ""`、`public var completed: Bool = false`、`public var timedOut: Bool = false`
     - 构造函数：`init(callId, toolName, timeoutMs)`，createdAt 用 `DateTime.now() - DateTime.UnixEpoch` 获取毫秒时间戳
  2. **PendingToolCallManager**：
     - `private var _entries = HashMap<String, PendingToolCallEntry>()` — callId → entry 映射
     - `private let _mutex = ReentrantMutex()` — 保护 _entries 并发访问
     - `register(callId, toolName, timeoutMs): PendingToolCallEntry` — 创建 entry 并存入 _entries，返回 entry 供调用方阻塞等待
     - `handleResult(callId, result): Bool` — 查找 entry，设置 result、completed=true，调用 `entry.condition.notifyAll()` 唤醒等待线程，然后从 _entries 移除该 callId；未找到返回 false
     - `contains(callId): Bool` — 检查 callId 是否存在
     - `remove(callId): Unit` — 移除指定 callId
     - `cleanupTimedOut(): Unit` — 遍历所有 entry，超时的标记 completed=true、timedOut=true、设置超时错误 result、notifyAll 唤醒，然后从 _entries 移除
  3. **关键实现细节**：
     - `handleResult` 中必须先 `entry.mutex.lock()` 再设置 result/completed，然后 `entry.condition.notifyAll()`，最后 `entry.mutex.unlock()`
     - `cleanupTimedOut` 中也需要先 lock entry.mutex 再修改状态和 notifyAll

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考
  - 参考文件包括但不限于：
    - `src/tool/webmcp/web_navigate_tool.cj` 中的 HashMap 使用模式
    - `src/skill/skill_aware_agent.cj` 中的 ReentrantMutex 使用模式
    - CangjieMagic 框架的 Condition + ReentrantMutex 使用约定
    - 注意：Condition 需要 ReentrantMutex 配合使用，`entry.condition.notifyAll()` 需在 `entry.mutex.lock()` 内调用
    - 注意：HashMap 用 `add()` 而不是 `put()`
    - 注意：Duration 用 `Duration.second * N` 格式

- **验收标准**：
  1. PendingToolCallEntry 可正常实例化，createdAt 为毫秒时间戳
  2. register 正确创建 entry 并存入 _entries
  3. handleResult 正确匹配 callId、设置 result、唤醒等待线程
  4. handleResult 对未知 callId 返回 false
  5. cleanupTimedOut 正确清理超时条目并唤醒等待线程
  6. 所有操作记录 INFO/WARN 级别日志
  7. 包路径为 `magic.tool.webmcp`

---

## Phase 2 - 工具层改造

> 改造 WebMCP 内置工具和 FrontendToolAdapter 的 invoke 方法，通过 SSE 推送指令到前端执行并阻塞等待结果回传。

### TASK-05：新增 WebMCPToolHelper 工具调用辅助类

- **关联需求**：REQ-TC-02, REQ-TC-03, REQ-TC-06
- **优先级**：P0
- **预估复杂度**：L
- **依赖**：TASK-03, TASK-04
- **涉及文件**：
  - **新建文件**：
    - `src/tool/webmcp/WebMCPToolHelper.cj` — 包名 `magic.tool.webmcp`，提取工具调用公共逻辑
- **任务描述**：
  创建 WebMCP 工具调用辅助类，提取 WebNavigateTool、WebNotifyTool、WebRequestApprovalTool、FrontendToolAdapter 共用的工具调用逻辑，避免代码重复。核心功能：
  1. `public static func executeToolCall(toolName: String, args: HashMap<String, JsonValue>, timeoutMs: Int64, route: String): ToolResponse`：
     - 获取工具执行上下文：`WebMCPToolContext.instance` 获取 sessionId、sseManager、pendingManager；任一为 None 则返回错误 ToolResponse（"前端连接不可用，无法执行${toolName}操作"）
     - 生成 callId：`call_{timestamp}_{random8位}` 格式
     - 构建 SSE 推送数据：JsonObject 包含 `toolName`、`arguments`（从 args HashMap 转换）、`callId`、`route`（非空时添加）
     - 通过 SSE 推送指令：`sseManager.pushMessage(sessionId, "tool_call", dataStr)`，失败则返回错误 ToolResponse
     - 注册回调并阻塞等待：`pendingManager.register(callId, toolName, timeoutMs)`，然后 `entry.mutex.lock()` → `while (!entry.completed) { entry.condition.await(entry.mutex, Duration.millisecond * timeoutMs) }` → 超时处理 → `entry.mutex.unlock()`
     - 超时处理：超时时标记 completed=true、timedOut=true、设置超时错误 result、从 pendingManager 移除 callId
     - 返回结果：超时返回 `ToolResponse(result, isError: true)`，正常返回 `ToolResponse(result, isError: false)`
  2. `private static func _generateCallId(): String` — 生成 callId：`call_{timestamp}_{random8位}`

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考
  - 参考文件包括但不限于：
    - `src/tool/webmcp/web_navigate_tool.cj` 中的 ToolResponse 构造和 extractString 方法
    - `src/skill/frontend_tool_adapter.cj` 中的 HashMap 遍历模式
    - `WebMCPToolContext.cj`（TASK-03 新建）中的上下文获取 API
    - `PendingToolCallManager.cj`（TASK-04 新建）中的 register 和阻塞等待模式
  - **特别注意**：同包内的类默认可见，不需要 import

- **验收标准**：
  1. executeToolCall 正确获取上下文、生成 callId、推送 SSE 消息、阻塞等待结果
  2. SSE 连接不可用时返回错误 ToolResponse
  3. SSE 推送失败时返回错误 ToolResponse
  4. 超时时返回超时错误 ToolResponse
  5. 正常返回时返回前端回传的结果
  6. callId 格式为 call_{timestamp}_{random8位}
  7. 包路径为 `magic.tool.webmcp`

### TASK-06：改造 WebNavigateTool invoke 方法

- **关联需求**：REQ-TC-02, REQ-TC-06
- **优先级**：P0
- **预估复杂度**：S
- **依赖**：TASK-05
- **涉及文件**：
  - **修改文件**：
    - `src/tool/webmcp/web_navigate_tool.cj` — 参考同文件中现有的 invoke 方法和 extractString 方法
- **任务描述**：
  改造 WebNavigateTool.invoke() 方法，从返回静态文本改为通过 WebMCPToolHelper.executeToolCall 执行：
  1. 提取参数 url 和 title（保留现有的 extractString 方法）
  2. url 为空时抛出 ToolException（保留现有校验）
  3. 构建 args HashMap，添加 url 和 title 参数
  4. 调用 `WebMCPToolHelper.executeToolCall("web_navigate", args, 30000, "")` 获取结果
  5. 移除原有的静态文本返回逻辑 `"Navigated to: ${url}"`

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考
  - 参考文件包括但不限于：
    - 同文件中现有的 `invoke()` 方法和 `extractString()` 方法
    - `WebMCPToolHelper.cj`（TASK-05 新建）中的 executeToolCall API
  - **特别注意**：同包内的 WebMCPToolHelper 默认可见，不需要 import

- **验收标准**：
  1. invoke 不再返回静态文本 "Navigated to: xxx"
  2. invoke 通过 SSE 推送 tool_call 事件到前端
  3. invoke 阻塞等待前端回传结果
  4. SSE 连接不可用时返回错误 ToolResponse
  5. 超时（30秒）时返回超时错误 ToolResponse

### TASK-07：改造 WebNotifyTool invoke 方法

- **关联需求**：REQ-TC-02, REQ-TC-06
- **优先级**：P0
- **预估复杂度**：S
- **依赖**：TASK-05
- **涉及文件**：
  - **修改文件**：
    - `src/tool/webmcp/web_notify_tool.cj` — 参考同文件中现有的 invoke 方法
- **任务描述**：
  改造 WebNotifyTool.invoke() 方法，与 TASK-06 相同模式：
  1. 提取参数 message、type、duration（保留现有的 extractString/extractInt 方法）
  2. message 为空时抛出 ToolException（保留现有校验）
  3. 构建 args HashMap，添加 message、type、duration 参数
  4. 调用 `WebMCPToolHelper.executeToolCall("web_notify", args, 30000, "")` 获取结果
  5. 移除原有的静态文本返回逻辑

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考
  - 参考文件包括但不限于：
    - 同文件中现有的 `invoke()` 方法
    - `WebMCPToolHelper.cj`（TASK-05 新建）中的 executeToolCall API
  - **特别注意**：同包内的 WebMCPToolHelper 默认可见，不需要 import

- **验收标准**：
  1. invoke 不再返回静态文本
  2. invoke 通过 SSE 推送 tool_call 事件到前端
  3. 超时 30 秒时返回超时错误

### TASK-08：改造 WebRequestApprovalTool invoke 方法

- **关联需求**：REQ-TC-02, REQ-TC-06
- **优先级**：P0
- **预估复杂度**：S
- **依赖**：TASK-05
- **涉及文件**：
  - **修改文件**：
    - `src/tool/webmcp/web_request_approval_tool.cj` — 参考同文件中现有的 invoke 方法
- **任务描述**：
  改造 WebRequestApprovalTool.invoke() 方法，与 TASK-06 相同模式，但超时时间为 120 秒（需要用户审批，等待时间较长）：
  1. 提取参数 action、details、timeout（保留现有的 extractString/extractInt 方法）
  2. action 为空时抛出 ToolException（保留现有校验）
  3. 构建 args HashMap，添加 action、details、timeout 参数
  4. 调用 `WebMCPToolHelper.executeToolCall("web_request_approval", args, 120000, "")` 获取结果（**超时 120 秒**）
  5. 移除原有的静态文本返回逻辑

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考

- **验收标准**：
  1. invoke 不再返回静态文本
  2. invoke 通过 SSE 推送 tool_call 事件到前端
  3. 超时 120 秒时返回超时错误

### TASK-09：改造 FrontendToolAdapter invoke 方法

- **关联需求**：REQ-TC-01, REQ-TC-02
- **优先级**：P0
- **预估复杂度**：M
- **依赖**：TASK-05
- **涉及文件**：
  - **修改文件**：
    - `src/skill/frontend_tool_adapter.cj` — 参考同文件中现有的 invoke 方法和 _name、_route 等成员变量
- **任务描述**：
  改造 FrontendToolAdapter.invoke() 方法，从返回静态文本改为通过 WebMCPToolHelper.executeToolCall 执行：
  1. 调用 `WebMCPToolHelper.executeToolCall(_name, args, 30000, _route)` 获取结果
  2. 移除原有的静态文本返回逻辑 `"前端工具调用请求已发送: ${_name}"`
  3. **注意**：FrontendToolAdapter 在 `magic.skill` 包中，需要 import `magic.tool.webmcp.WebMCPToolHelper`

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考
  - 参考文件包括但不限于：
    - 同文件中现有的 `invoke()` 方法和 _name、_route 等成员变量
    - `WebMCPToolHelper.cj`（TASK-05 新建）中的 executeToolCall API
  - **注意**：FrontendToolAdapter 在 `magic.skill` 包中，需要 `import magic.tool.webmcp.WebMCPToolHelper`

- **验收标准**：
  1. invoke 不再返回 "前端工具调用请求已发送: xxx" 静态文本
  2. invoke 通过 SSE 推送 tool_call 事件到前端
  3. 前端工具的 SSE 推送数据包含 route 字段（非空时）
  4. 超时 30 秒时返回超时错误

---

## Phase 3 - Protocol 与 Controller 集成

> 在 WebMCPProtocol 中处理 tools/register、设置 WebMCPToolContext、同步前端工具到 Agent ToolManager、注入 System Prompt；在 WebMCPController 中新增 /tool-result 端点、SSE 连接管理、初始化基础设施并注入 Protocol。

### TASK-10：WebMCPProtocol 新增 tools/register 处理和基础设施注入

- **关联需求**：REQ-TC-01, REQ-TC-02
- **优先级**：P0
- **预估复杂度**：L
- **依赖**：TASK-01, TASK-02, TASK-03, TASK-04, TASK-13
- **涉及文件**：
  - **修改文件**：
    - `src/app/services/webmcp/WebMCPProtocol.cj` — 参考同文件中现有的 handleMethod 方法和成员变量声明模式
- **任务描述**：
  改造 WebMCPProtocol，新增以下功能：

  **注意**：本任务依赖 TASK-13（MenuDataProvider），因为需要 import `magic.app.services.webmcp.MenuDataProvider` 并声明 `_menuDataProvider` 成员变量。但本任务仅声明成员变量和注入方法，不实际使用 MenuDataProvider 查询菜单（实际使用在 TASK-14）。

  **A. 新增成员变量和注入方法**：
  1. `private var _sseConnectionManager: ?SSEConnectionManager = None`
  2. `private var _pendingToolCallManager: ?PendingToolCallManager = None`
  3. `private var _frontendToolRegistry: ?FrontendToolRegistry = None`
  4. `private var _menuDataProvider: ?MenuDataProvider = None`（供 buildAgentSystemPrompt 查询用户菜单）
  5. `private var _userId: String = ""`（由 setSessionInfo 设置，供 MenuDataProvider 查询用户菜单）
  6. `public func setInfrastructure(sseManager: SSEConnectionManager, pendingManager: PendingToolCallManager, frontendToolRegistry: FrontendToolRegistry): Unit` — 注入基础设施
  7. `public func setMenuDataProvider(provider: MenuDataProvider): Unit` — 注入菜单数据提供者
  8. **修改 setSessionInfo 方法签名**：从 `setSessionInfo(sessionId: String, clientId: String)` 改为 `setSessionInfo(sessionId: String, clientId: String, userId: String)`，新增 `this._userId = userId` 赋值
  9. 在 import 中添加 `magic.tool.webmcp.{SSEConnectionManager, PendingToolCallManager, FrontendToolRegistry, FrontendToolDefinition, WebMCPToolContext}` 和 `magic.app.services.webmcp.MenuDataProvider`

  **B. 新增 handleRegisterTool 方法处理 tools/register 请求**：
  1. 在 `handleMethod()` 中添加 `tools/register` 方法路由
  2. 新增 `handleRegisterTool(obj: JsonObject): String` 方法：
     - 解析 `params.tool` 中的工具定义（name、title、description、inputSchema、annotations）
     - 从 annotations 中提取 route 信息
     - 创建 FrontendToolDefinition
     - 注册到 FrontendToolRegistry：`_frontendToolRegistry.register(toolDef)`
     - 同步到 Agent ToolManager：`_syncFrontendToolToAgent(toolDef)`
     - 返回成功响应

  **C. 新增 _syncFrontendToolToAgent 方法**：
  1. 检查 Agent 是否可用（`_agent.isSome()`），不可用时记录 WARN 日志并返回
  2. 检查重名冲突：调用 `agent.toolManager.findTool(toolDef.name)` 检查是否已存在同名工具，存在时记录 WARN 日志并跳过（**注意：通过公开的 `toolManager` 属性访问，不要直接访问 `_toolManager` 私有成员**）
  3. 调用 `agent.addFrontendTool(name, title, description, route, inputSchema)` 同步到 ToolManager
  4. 记录 INFO 日志

  **D. 改造 handleCompletionComplete 方法**：
  1. 在调用 Agent 前设置 WebMCPToolContext：`WebMCPToolContext.instance.setSessionContext(_sessionId, sseMgr, ptcMgr)`（需要 _sseConnectionManager 和 _pendingToolCallManager 都可用）
  2. 在 try-finally 中确保清除上下文：`WebMCPToolContext.instance.clearSessionContext()`
  3. 现有 Agent 调用逻辑保持不变

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考
  - 参考文件包括但不限于：
    - 同文件中现有的 `handleMethod()` 方法（需添加 tools/register 路由）
    - 同文件中现有的 `handleCompletionComplete()` 方法（需在 Agent 调用前后添加上下文设置/清除）
    - 同文件中现有的成员变量声明和 import 模式
    - `src/skill/skill_aware_agent.cj` 中的 `addFrontendTool()` 方法签名
  - **注意**：WebMCPProtocol 在 `magic.app.services.webmcp` 包中，可以 import `magic.tool.webmcp` 中的类

- **验收标准**：
  1. setInfrastructure 方法正确设置 SSE、PendingToolCallManager 和 FrontendToolRegistry 引用
  2. handleMethod 中存在 tools/register 路由
  3. handleRegisterTool 正确解析工具定义并注册到 FrontendToolRegistry
  4. _syncFrontendToolToAgent 正确同步到 Agent ToolManager
  5. 前端工具与后端技能同名时跳过同步并记录 WARN 日志
  6. Agent 不可用时仅注册到 FrontendToolRegistry，记录 WARN 日志
  7. handleCompletionComplete 在调用 Agent 前设置 WebMCPToolContext
  8. handleCompletionComplete 在 Agent 调用返回后（包括异常）清除 WebMCPToolContext

### TASK-11：WebMCPController 新增 /tool-result 端点和基础设施管理

- **关联需求**：REQ-TC-03, REQ-TC-05
- **优先级**：P0
- **预估复杂度**：L
- **依赖**：TASK-01, TASK-04, TASK-13
- **涉及文件**：
  - **修改文件**：
    - `src/app/controllers/uctoo/webmcp/WebMCPController.cj` — 参考同文件中现有的 handleStreamableHttp 方法和成员变量
- **任务描述**：
  改造 WebMCPController，新增以下功能：

  **注意**：本任务依赖 TASK-13（MenuDataProvider），因为需要新增 `_menuDataProvider` 成员变量并调用 `protocol.setMenuDataProvider(_menuDataProvider)`。

  **A. 新增成员变量**：
  1. `private let _pendingToolCallManager = PendingToolCallManager()` — 待处理工具调用管理器
  2. `private let _sseConnectionManager = SSEConnectionManager()` — SSE 连接管理器
  3. `private let _frontendToolRegistry = FrontendToolRegistry()` — 前端工具注册表
  4. `private let _menuDataProvider = MenuDataProvider()` — 菜单数据提供者（复用 PermissionsService）
  5. 在 import 中添加 `magic.tool.webmcp.{PendingToolCallManager, SSEConnectionManager, FrontendToolRegistry}` 和 `magic.app.services.webmcp.MenuDataProvider`

  **B. 新增 handleToolResult 方法处理 /tool-result 请求**：
  1. 路由：POST /api/v1/uctoo/webmcp/tool-result
  2. 校验 callId 和 result 必填字段
  3. 委托给 `_pendingToolCallManager.handleResult(callId, resultStr)` 处理
  4. handleResult 返回 true 时返回 200 OK
  5. handleResult 返回 false 时返回 404（"未找到对应的工具调用"）
  6. callId 或 result 缺失时返回 400
  7. 回调执行异常时捕获、记录错误日志、返回 500

  **C. 新增公共 getter 方法**：
  1. `getPendingToolCallManager(): PendingToolCallManager`
  2. `getSSEConnectionManager(): SSEConnectionManager`
  3. `getFrontendToolRegistry(): FrontendToolRegistry`
  4. `getMenuDataProvider(): MenuDataProvider`

  **D. 在所有创建 WebMCPProtocol 实例的位置注入基础设施和菜单提供者**：
  1. `handleStreamableHttp()` 中：
     - 从 `req.getLocals("userId")` 获取 userId（参考 `AgentsController.cj` 的模式：`let userId = req.getLocals("userId")` → `if (let Some(u) <- userId) { let sOpt = u as String; if (let Some(s) <- sOpt) { userIdStr = s } }`）
     - 新建 Protocol 后调用 `protocol.setInfrastructure(_sseConnectionManager, _pendingToolCallManager, _frontendToolRegistry)`
     - 调用 `protocol.setMenuDataProvider(_menuDataProvider)`
     - 调用 `protocol.setSessionInfo(sessionId, "", userIdStr)`（**注意：setSessionInfo 新增 userId 参数**）
  2. `handleConnection(HttpContext)` 中：
     - WebSocket 握手阶段从 HTTP 请求中获取 userId（通过 query 参数或 header；若无法获取则传空字符串，buildAgentSystemPrompt 时跳过菜单注入）
     - 新建 Protocol 后调用 `protocol.setInfrastructure(_sseConnectionManager, _pendingToolCallManager, _frontendToolRegistry)`
     - 调用 `protocol.setMenuDataProvider(_menuDataProvider)`
     - 调用 `protocol.setSessionInfo(sessionId, "", userIdStr)`

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考
  - 参考文件包括但不限于：
    - 同文件中现有的 `handleStreamableHttp()` 方法（需在 Protocol 创建后注入基础设施）
    - 同文件中现有的 `handleConnection(HttpContext)` 方法（需在 Protocol 创建后注入基础设施）
    - `PendingToolCallManager.cj`（TASK-04 新建）中的 handleResult API
  - **注意**：WebMCPController 在 `magic.app.controllers.uctoo.webmcp` 包中，可以 import `magic.tool.webmcp` 中的类

- **验收标准**：
  1. handleToolResult 正确处理 /tool-result 请求
  2. callId 不存在时返回 404
  3. callId 和 result 缺失时返回 400
  4. getPendingToolCallManager/getSSEConnectionManager/getFrontendToolRegistry/getMenuDataProvider 方法可被外部调用
  5. 所有 WebMCPProtocol 实例创建后都调用了 setInfrastructure、setMenuDataProvider 和 setSessionInfo（含 userId 参数）
  6. handleStreamableHttp 中能从 req.getLocals("userId") 正确获取 userId 并传入 setSessionInfo

### TASK-12：前端工具注销同步到 Agent ToolManager

- **关联需求**：REQ-TC-01
- **优先级**：P2
- **预估复杂度**：S
- **依赖**：TASK-10
- **涉及文件**：
  - **修改文件**：
    - `src/app/services/webmcp/WebMCPProtocol.cj` — 参考同文件中现有的 handleRegisterTool 方法和 _syncFrontendToolToAgent 方法
- **任务描述**：
  实现前端工具注销时同步从 Agent ToolManager 移除：
  1. 新增 `handleToolsUnregister(obj: JsonObject): String` 方法：解析 params.tool.name，从 FrontendToolRegistry 注销，调用 `_unsyncFrontendToolFromAgent(name)` 从 Agent ToolManager 移除
  2. 新增 `_unsyncFrontendToolFromAgent(name: String): Unit` 私有方法：调用 `agent.removeFrontendTool(name)` 从 ToolManager 移除
  3. 在 `handleMethod()` 中添加 `tools/unregister` 方法路由

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码

- **验收标准**：
  1. 前端工具注销时同时从 Agent ToolManager 移除
  2. 注销后 LLM 不再发现该工具

---

## Phase 4 - System Prompt 与菜单数据集成

> 改造 buildAgentSystemPrompt 注入前端工具信息和页面导航信息；新增 MenuDataProvider 从数据库查询菜单数据。

### TASK-13：新增 MenuDataProvider 菜单数据提供者

- **关联需求**：REQ-TC-04
- **优先级**：P1
- **预估复杂度**：M
- **依赖**：无
- **涉及文件**：
  - **新建文件**：
    - `src/app/services/webmcp/MenuDataProvider.cj` — 包名 `magic.app.services.webmcp`，参考同目录下 WebMCPProtocol.cj 的类定义模式
- **任务描述**：
  创建菜单数据提供者，**复用已有的 `PermissionsService.getUserMenuTree(userId)` 方法**查询菜单数据（该方法已实现完整的"用户角色 → 权限名称 → 菜单权限"查询链路，含菜单通配符 `menu:*` 处理，返回 `ArrayList<PermissionsPO>`）。MenuDataProvider 将 `PermissionsPO` 转换为 `MenuItem` 并构建树形结构。包含两个核心类：
  1. **MenuItem**：
     - 公开字段：`path: String`、`title: String`、`icon: String`、`parentId: ?String`、`children: ArrayList<MenuItem>`
     - 构造函数：`init(path, title, icon, parentId?)`，children 初始化为空 ArrayList
  2. **MenuDataProvider**：
     - 私有成员：`private let _permissionsService = PermissionsService()`
     - `getUserMenuTree(userId: String): ArrayList<MenuItem>` — **复用 `_permissionsService.getUserMenuTree(userId)`** 获取 `ArrayList<PermissionsPO>`，将 `PermissionsPO` 转换为 `MenuItem`（path 来自 `PermissionsPO.path`，title 来自 `PermissionsPO.title`，icon 来自 `PermissionsPO.icon`，parentId 来自 `PermissionsPO.parentId`），根据 parentId 构建树形结构返回
     - `flattenMenuPaths(menuTree: ArrayList<MenuItem>): ArrayList<MenuItem>` — 将菜单树扁平化为路由路径列表，递归遍历，只包含 path 非空的项
     - `private func _flattenRecursive(items: ArrayList<MenuItem>, result: ArrayList<MenuItem>): Unit` — 递归扁平化辅助方法

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考
  - 参考文件包括但不限于：
    - `src/app/services/uctoo/PermissionsService.cj` 中的 `getUserMenuTree(userId)` 方法（**必须复用，不要重新实现 SQL 查询**）
    - `src/app/models/uctoo/PermissionsPO.cj` 中的字段定义（path、title、icon、parentId 等）
    - `src/app/models/uctoo/AgentsPO.cj` 中的 Model 数据结构
    - CangjieMagic 框架的 ArrayList 递归遍历和树形结构构建约定

- **验收标准**：
  1. MenuItem 类可正常实例化
  2. getUserMenuTree 从数据库查询菜单数据并构建树形结构
  3. flattenMenuPaths 正确扁平化菜单树，只包含有 path 的项
  4. 包路径为 `magic.app.services.webmcp`

### TASK-14：改造 buildAgentSystemPrompt 注入前端工具和页面导航信息

- **关联需求**：REQ-TC-04
- **优先级**：P0
- **预估复杂度**：M
- **依赖**：TASK-10, TASK-13
- **涉及文件**：
  - **修改文件**：
    - `src/app/services/webmcp/WebMCPProtocol.cj` — 参考同文件中现有的 buildAgentSystemPrompt 方法
- **任务描述**：
  改造 `buildAgentSystemPrompt()` 方法，注入三类信息：
  1. **后端技能**（已有）：保持现有的 SkillManager 技能信息注入
  2. **前端页面工具**（新增）：从 `_frontendToolRegistry.getAllTools()` 获取前端工具列表，注入 "【前端页面工具】" 分区，包含工具名称、描述、路由
  3. **可访问的页面导航**（新增）：从 `_menuDataProvider.getUserMenuTree(_userId)` 获取菜单数据（`_userId` 由 TASK-10 中的 `setSessionInfo` 方法设置），扁平化后注入 "【可访问的页面导航】" 分区，包含路由路径和页面标题
  4. 新增成员变量：`private var _menuDataProvider: ?MenuDataProvider = None`（**注意**：若 TASK-10 已添加则不重复）
  5. 新增 `setMenuDataProvider(provider: MenuDataProvider): Unit` 方法（**注意**：若 TASK-10 已添加则不重复）
  6. **注意**：`_userId` 成员变量和 `setSessionInfo` 方法由 TASK-10 添加，本任务直接使用 `_userId` 即可

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考
  - 参考文件包括但不限于：
    - 同文件中现有的 `buildAgentSystemPrompt()` 方法（需扩展）
    - `MenuDataProvider.cj`（TASK-13 新建）中的 getUserMenuTree 和 flattenMenuPaths API

- **验收标准**：
  1. system prompt 同时包含后端技能、前端工具和页面导航信息
  2. 前端工具为空时不注入前端工具分区
  3. 菜单数据为空时不注入页面导航分区
  4. 前端工具注册/注销后下一次对话时 system prompt 更新

### TASK-15：WebMCPController 注入 MenuDataProvider 到 Protocol

- **关联需求**：REQ-TC-04
- **优先级**：P1
- **预估复杂度**：S
- **依赖**：TASK-13, TASK-14
- **涉及文件**：
  - **修改文件**：
    - `src/app/controllers/uctoo/webmcp/WebMCPController.cj` — 参考同文件中现有的 WebMCPProtocol 实例化代码
- **任务描述**：
  **注意**：TASK-11 已经在 WebMCPController 中新增了 `_menuDataProvider` 成员变量，并在所有创建 WebMCPProtocol 实例的位置调用了 `protocol.setMenuDataProvider(_menuDataProvider)`。本任务主要验证该集成是否正确完成，并补充 `getMenuDataProvider()` 公共 getter 方法（若 TASK-11 未包含）：
  1. 确认 `private let _menuDataProvider: MenuDataProvider = MenuDataProvider()` 成员变量已存在（TASK-11 已添加）
  2. 确认 `handleStreamableHttp()` 中新建 Protocol 后已调用 `protocol.setMenuDataProvider(_menuDataProvider)`（TASK-11 已添加）
  3. 确认 `handleConnection(HttpContext)` 中新建 Protocol 后已调用 `protocol.setMenuDataProvider(_menuDataProvider)`（TASK-11 已添加）
  4. 若 TASK-11 未包含 `getMenuDataProvider(): MenuDataProvider` 公共 getter 方法，则补充添加

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - **注意**：本任务与 TASK-11 有重叠，开发时先确认 TASK-11 的实现情况，避免重复代码

- **验收标准**：
  1. 所有 WebMCPProtocol 实例都持有 MenuDataProvider 引用
  2. buildAgentSystemPrompt 可通过 MenuDataProvider 获取菜单数据
  3. getMenuDataProvider() 方法可被外部调用

### TASK-16：WebNavigateTool 动态描述注入

- **关联需求**：REQ-TC-06
- **优先级**：P1
- **预估复杂度**：S
- **依赖**：TASK-13
- **涉及文件**：
  - **修改文件**：
    - `src/tool/webmcp/web_navigate_tool.cj` — 参考同文件中现有的 DESC 静态属性和 description prop
- **任务描述**：
  改造 WebNavigateTool 的 description，支持动态注入可用页面列表：
  1. 将 `description` prop 从静态返回 `DESC` 改为返回 `_dynamicDescription`
  2. 新增 `private var _dynamicDescription: String = WebNavigateTool.DESC`
  3. 新增 `updateDescription(formattedPagesString: String): Unit` 方法：
     - 基础描述："导航到指定页面或 URL。使用此工具跳转到用户有权限访问的页面。"
     - 如果 `formattedPagesString` 非空，追加 "\n\n可用的页面路由：\n" + formattedPagesString
     - 设置 `_dynamicDescription`
  4. **关键设计**：为避免循环依赖（`magic.tool.webmcp` 不能 import `magic.app.services.webmcp.MenuItem`），updateDescription 方法**只接收 String 类型参数**（已格式化的页面列表字符串）。格式化逻辑由调用方（WebMCPProtocol，在 `magic.app.services.webmcp` 包中）完成，调用方遍历 `ArrayList<MenuItem>` 并构建格式化字符串（如 `"/database/uctoo/entity（实体管理）\n/system/user（用户管理）"`），然后传给 updateDescription。

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考
  - **特别注意**：updateDescription 参数类型必须是 `String`，不能使用 `ArrayList<MenuItem>` 或任何来自 `magic.app.services.webmcp` 包的类型，以避免循环依赖

- **验收标准**：
  1. description 不再是固定静态文本
  2. updateDescription(formattedPagesString: String) 可动态更新工具描述
  3. 可用页面列表来自菜单数据（由调用方格式化为字符串后传入）
  4. 无菜单数据时（formattedPagesString 为空）description 为基础描述
  5. 不存在 import `magic.app.services.webmcp` 的语句

### TASK-17：WebNavigateTool 与 MenuDataProvider 集成

- **关联需求**：REQ-TC-06
- **优先级**：P1
- **预估复杂度**：S
- **依赖**：TASK-14, TASK-16
- **涉及文件**：
  - **修改文件**：
    - `src/app/services/webmcp/WebMCPProtocol.cj` — 参考同文件中现有的 buildAgentSystemPrompt 方法
- **任务描述**：
  在 `buildAgentSystemPrompt()` 方法中，获取菜单数据后调用 WebNavigateTool 的 `updateDescription()` 方法更新工具描述：
  1. 获取 MenuDataProvider 的菜单数据
  2. 扁平化菜单路径
  3. 将扁平化结果格式化为字符串（path + title 列表，每行格式如 `"/database/uctoo/entity（实体管理）"`）
  4. 查找 Agent ToolManager 中的 web_navigate 工具：`let toolOpt = agent.toolManager.findTool("web_navigate")`
  5. **使用 `is` 检查后再进行类型转换**（仓颉模式匹配安全转换）：
     ```cangjie
     if (let Some(tool) <- toolOpt) {
         if (tool is WebNavigateTool) {
             let webNavTool = tool as WebNavigateTool
             webNavTool.updateDescription(formattedPagesString)
         }
     }
     ```
     **不要直接使用 `as` 转换而不做 `is` 检查**，否则类型不匹配时会抛出异常

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码
  - 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考
  - 参考文件包括但不限于：
    - `src/tool/webmcp/web_navigate_tool.cj`（TASK-16 修改后）中的 updateDescription API
    - `src/app/services/webmcp/WebMCPProtocol.cj` 中现有的 buildAgentSystemPrompt 方法

- **验收标准**：
  1. web_navigate 工具的 description 包含用户可访问的页面列表
  2. 不同用户的页面列表基于权限不同
  3. 类型转换使用 `is` 检查后再 `as` 转换，不直接强制转换
  4. web_navigate 工具不存在时不抛出异常

---

## Phase 5 - 前端适配与菜单数据集成

> 前端 SSE tool_call 事件监听适配、菜单数据缓存优化、navigate_to_page 工具菜单数据注入。

### TASK-18：前端 SSE tool_call 事件监听适配

- **关联需求**：REQ-TC-02, REQ-TC-07
- **优先级**：P1
- **预估复杂度**：M
- **依赖**：TASK-11
- **涉及文件**：
  - **修改文件**：
    - `apps/web-admin/web/src/App.vue` — 参考同文件中现有的 transport.on('message') 和 handleToolCallResult 函数
- **任务描述**：
  适配前端 SSE 监听器处理 `tool_call` 事件：
  1. 在 `transport.on('message')` 监听器中，识别 `tool_call` 事件类型（已有 `message.method === 'tool_call'` 处理逻辑，需验证和完善）
  2. 解析事件数据中的 `toolName`、`arguments`、`callId`、`route` 字段
  3. 如果是前端注册的工具（toolName 在 registeredTools 中），调用对应的前端工具处理器（已有 callPageTool 逻辑）
  4. 如果是后端内置工具（web_navigate、web_notify、web_request_approval），调用对应的前端处理逻辑（已有 handleWebNotify、handleWebRequestApproval 逻辑）
  5. 工具执行完成后，通过 POST /api/v1/uctoo/webmcp/tool-result 回传结果，请求体包含 callId 和 result（已有 fetch 逻辑）
  6. 工具执行失败时，回传包含 error 字段的结果
  7. **验证和完善现有代码**：App.vue 中已有 tool_call 消息处理和 /tool-result 回传逻辑，需确保与后端 SSE 推送格式兼容

  **开发规范**：
  - 使用 TypeScript 编写前端代码
  - 参考 `@opentiny/next-sdk` 的 WebMcpClient API

- **验收标准**：
  1. 前端正确接收和处理 tool_call SSE 事件
  2. 根据 toolName 分发到对应的处理器
  3. 工具执行结果正确回传到后端 /tool-result 端点
  4. callId 正确关联请求和响应
  5. 后端内置工具（web_navigate、web_notify、web_request_approval）的前端处理逻辑正常工作

### TASK-19：前端 mcp-servers/index.ts 注册 navigate_to_page 时注入菜单数据

- **关联需求**：REQ-TC-08
- **优先级**：P1
- **预估复杂度**：S
- **依赖**：无
- **涉及文件**：
  - **修改文件**：
    - `apps/web-admin/web/src/mcp-servers/index.ts` — 参考同文件中现有的 registerNavigateTool 调用和 buildNavigateDescription 函数
- **任务描述**：
  验证和完善 `registerNavigateTool` 注册时注入菜单数据（已有 buildNavigateDescription 函数使用菜单数据）：
  1. 确认 `useMenuStore` 的 `flatMenuList` 正确提供菜单数据
  2. 确认 `buildNavigateDescription()` 正确构建包含可用页面列表的描述
  3. 确认 `updateNavigateToolPages()` 导出函数在菜单数据加载完成后被调用
  4. 如有遗漏，补充菜单数据加载后更新工具描述的逻辑

  **开发规范**：
  - 使用 TypeScript 编写前端代码
  - 参考 `@opentiny/next-sdk` 的 registerNavigateTool API

- **验收标准**：
  1. navigate_to_page 工具的 description 包含用户可访问的页面列表
  2. 菜单数据加载后工具描述动态更新
  3. 不同用户看到的可用页面列表不同（基于权限）

---

## Phase 6 - 集成验证与清理

> 端到端验证工具调用链路闭环，确保所有环节正常工作。

### TASK-20：后端工具调用链路集成测试

- **关联需求**：REQ-TC-01 ~ REQ-TC-06
- **优先级**：P0
- **预估复杂度**：L
- **依赖**：TASK-11, TASK-14
- **涉及文件**：
  - 测试文件（手动验证）
- **任务描述**：
  执行以下集成测试场景：
  1. **前端工具注册同步测试**：发送 tools/register 请求，验证工具同时注册到 FrontendToolRegistry 和 Agent ToolManager
  2. **重名冲突测试**：注册与后端技能同名的前端工具，验证跳过同步并记录 WARN 日志
  3. **WebMCPToolContext 设置/清除测试**：发送对话请求，验证 handleCompletionComplete 中正确设置和清除 WebMCPToolContext
  4. **SSE 推送工具调用指令测试**：Agent 调用 web_navigate 工具，验证 SSE 推送 tool_call 事件到前端
  5. **工具调用结果回传测试**：前端通过 /tool-result 回传结果，验证 PendingToolCallManager 正确匹配并唤醒等待线程
  6. **工具调用超时测试**：模拟前端不回传结果，验证 30 秒后返回超时错误
  7. **SSE 连接不可用测试**：模拟 SSE 连接断开，验证工具返回"前端连接不可用"错误
  8. **System Prompt 注入测试**：验证 system prompt 包含前端工具信息和页面导航信息
  9. **/tool-result 未知 callId 测试**：回传未知 callId，验证返回 404

- **验收标准**：
  1. 所有测试场景通过
  2. 日志输出正确（INFO 级别记录工具名和 callId，WARN 级别记录异常情况）
  3. 无内存泄漏（PendingToolCallManager 超时条目正确清理）

### TASK-21：前端端到端集成验证

- **关联需求**：REQ-TC-01 ~ REQ-TC-08
- **优先级**：P0
- **预估复杂度**：M
- **依赖**：TASK-18, TASK-20
- **涉及文件**：
  - 前端测试验证
- **任务描述**：
  执行前端端到端验证：
  1. 启动 agentskills-runtime 后端和 web-admin 前端
  2. 验证前端工具同步到后端（tools/register）
  3. 验证 TinyRemoter 对话框发送消息后，Agent 可发现前端工具
  4. 触发 Agent 调用前端工具，验证 SSE 推送 tool_call 指令到前端
  5. 验证前端执行工具后通过 /tool-result 回传结果
  6. 验证 Agent 收到结果后继续推理
  7. 验证 navigate_to_page 工具的可用页面列表来自菜单数据
  8. 验证 web_navigate 工具的可用页面列表来自菜单数据

- **验收标准**：
  1. 前端工具注册和调用闭环正常
  2. Agent 可通过 SSE 推送调用前端工具并等待结果
  3. 工具调用超时时 Agent 收到超时错误
  4. 菜单数据正确注入到工具描述和 system prompt

### TASK-22：PendingToolCallManager 超时清理定时任务

- **关联需求**：REQ-TC-03
- **优先级**：P2
- **预估复杂度**：S
- **依赖**：TASK-11
- **涉及文件**：
  - **修改文件**：
    - `src/app/controllers/uctoo/webmcp/WebMCPController.cj`
- **任务描述**：
  在 WebMCPController 中新增定时清理任务，定期清理 PendingToolCallManager 中的超时条目：
  1. 新增 `startCleanupTask()` 方法，使用 spawn 启动定时任务
  2. 定时任务每 5 分钟调用一次 `_pendingToolCallManager.cleanupTimedOut()`
  3. 在 Controller 初始化时启动清理任务

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码

- **验收标准**：
  1. 定时任务每 5 分钟清理 PendingToolCallManager 中的超时条目
  2. 超时条目被标记为 timedOut 并唤醒等待线程
  3. 清理后 _entries 中不再包含超时条目

### TASK-23：WebMCPController SSE 连接管理集成

- **关联需求**：REQ-TC-02
- **优先级**：P1
- **预估复杂度**：M
- **依赖**：TASK-11
- **涉及文件**：
  - **修改文件**：
    - `src/app/controllers/uctoo/webmcp/WebMCPController.cj`
- **任务描述**：
  在 WebMCPController 中集成 SSE 连接管理：
  1. 在 `handleStreamableHttp()` 中，当请求为 SSE 连接时（Accept: text/event-stream），注册到 SSEConnectionManager
  2. SSE 连接关闭时，从 SSEConnectionManager 移除
  3. 在 WebSocket 连接处理中，也注册到 SSEConnectionManager（WebSocket 连接可作为 SSE 推送的通道）
  4. SSE 推送格式：`event: ${eventType}\ndata: ${data}\n\n`

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码

- **验收标准**：
  1. SSE 连接正确注册到 SSEConnectionManager
  2. SSE 连接关闭时正确移除
  3. WebSocket 连接也可作为 SSE 推送通道
  4. 工具调用时可通过 SSEConnectionManager 推送消息到前端

### TASK-24：编译验证与循环依赖检查

- **关联需求**：REQ-TC-02（包依赖方向约束）
- **优先级**：P0
- **预估复杂度**：S
- **依赖**：TASK-01 ~ TASK-17
- **涉及文件**：
  - 所有新建和修改的 .cj 文件
- **任务描述**：
  编译验证所有代码，确保无循环依赖：
  1. 编译 agentskills-runtime 项目，确保无编译错误
  2. 检查所有 `magic.tool.webmcp` 包中的文件，确认不存在 `import magic.app.services.webmcp` 语句
  3. 检查所有 `magic.app.services.webmcp` 包中的文件，确认可以 import `magic.tool.webmcp` 中的类
  4. 检查同包内的类没有显式 import 同包其他类（仓颉同包默认可见）
  5. 运行基本功能测试，确保系统可正常启动

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写仓颉代码

- **验收标准**：
  1. 项目编译通过，无错误
  2. `magic.tool.webmcp` 包中不存在 import `magic.app.services.webmcp` 的语句
  3. 同包内没有不必要的显式 import
  4. 系统可正常启动并处理 MCP 请求

---

## 任务依赖关系图

```
Phase 1 (基础设施):
  TASK-01 (SSEConnectionManager) ──────┐
  TASK-02 (FrontendToolRegistry) ──────┤
  TASK-04 (PendingToolCallManager) ────┤
                                        │
  TASK-01 + TASK-02 → TASK-03 (WebMCPToolContext) ─┐
                                                    │
Phase 2 (工具层改造):                               │
  TASK-03 + TASK-04 → TASK-05 (WebMCPToolHelper) ──┤
  TASK-05 → TASK-06 (WebNavigateTool)              │
  TASK-05 → TASK-07 (WebNotifyTool)                │
  TASK-05 → TASK-08 (WebRequestApprovalTool)        │
  TASK-05 → TASK-09 (FrontendToolAdapter) ──────────┘
                                                       │
Phase 3 (Protocol 与 Controller 集成):                 │
  TASK-01 + TASK-02 + TASK-03 + TASK-04 + TASK-13 → TASK-10 (Protocol 集成)
  TASK-01 + TASK-04 + TASK-13 → TASK-11 (Controller /tool-result + 基础设施)
  TASK-10 → TASK-12 (前端工具注销同步)
  
Phase 4 (System Prompt 与菜单数据):
  TASK-13 (MenuDataProvider) → TASK-14 (buildAgentSystemPrompt 改造)
  TASK-10 + TASK-13 → TASK-14
  TASK-13 + TASK-14 → TASK-15 (Controller 注入 MenuDataProvider)
  TASK-13 → TASK-16 (WebNavigateTool 动态描述)
  TASK-14 + TASK-16 → TASK-17 (WebNavigateTool 与 MenuDataProvider 集成)

Phase 5 (前端适配):
  TASK-11 → TASK-18 (前端 SSE tool_call 适配)
  TASK-19 (前端 navigate_to_page 菜单数据) — 无后端依赖

Phase 6 (集成验证与清理):
  TASK-11 + TASK-14 → TASK-20 (后端集成测试)
  TASK-18 + TASK-20 → TASK-21 (前端端到端验证)
  TASK-11 → TASK-22 (超时清理定时任务)
  TASK-11 → TASK-23 (SSE 连接管理集成)
  TASK-01 ~ TASK-17 → TASK-24 (编译验证与循环依赖检查)
```

## 需求覆盖追踪矩阵

| 需求ID | 覆盖任务 | 验证方式 |
|--------|---------|---------|
| REQ-TC-01 前端工具注册到 Agent ToolManager | TASK-02, TASK-10, TASK-12 | tools/register 请求后 Agent ToolManager 中存在对应工具 |
| REQ-TC-02 前端工具调用指令转发 | TASK-01, TASK-03, TASK-05, TASK-06, TASK-07, TASK-08, TASK-09, TASK-10, TASK-11, TASK-23 | Agent 调用前端工具后 SSE 推送 tool_call 事件到前端 |
| REQ-TC-03 工具调用结果等待与回调机制 | TASK-03, TASK-04, TASK-05, TASK-22 | 工具 invoke 阻塞等待前端回传结果，超时返回错误 |
| REQ-TC-04 Agent System Prompt 工具信息注入 | TASK-10, TASK-13, TASK-14, TASK-15 | system prompt 包含前端工具和页面导航信息 |
| REQ-TC-05 前端工具调用结果回传 | TASK-04, TASK-11 | /tool-result 端点正确匹配 callId 并触发回调 |
| REQ-TC-06 后端 WebMCP 内置工具的重新定位 | TASK-05, TASK-06, TASK-07, TASK-08, TASK-16, TASK-17 | 内置工具 invoke 通过 SSE 推送到前端执行 |
| REQ-TC-07 前端 next-sdk 标准协议对接 | TASK-18, TASK-19 | WebMcpClient 代理模式连接正常，tool_call 消息格式兼容 |
| REQ-TC-08 前端菜单数据与工具集成 | TASK-13, TASK-16, TASK-17, TASK-19 | navigate_to_page 和 web_navigate 工具描述包含菜单数据 |
