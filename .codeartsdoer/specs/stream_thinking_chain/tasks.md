# 流式思维链升级 - 编码任务清单（tasks.md）

> 依据：`spec.md`（需求规格）+ `design.md`（实现方案）
> 范围：前端 tiny-robot-kit 0.3.3 → 0.5.1 升级 + 后端 WebMCP 流式思维链增强 + AIController 降级 + http_lib 真流式
> 实现优先级：**P0 前端升级 → P1 逐字流式 → P2 真流式 → P3 AIController 降级**（关键路径 P0→P1→P2，P3 可并行）
> 仓颉代码约束：所有 `.cj` 文件编写任务**必须使用 cangjie-coder 技能**，且**必须检索到确定的编码依据后再生成代码**；**严禁运行 `cjpm build`**，如需编译请通知人工在独立 cmd 环境执行并反馈结果

---

## 1. P0：前端依赖升级与 API 迁移（0.3.3 → 0.5.1）

> 目标：将 @opentiny/tiny-robot 系列包统一升级到 0.5.1，迁移 useTinyRobotChat 到 useMessage + ResponseProvider 模式，确保前端编译通过且思维链显示正常。
> 依赖：无（最先执行）
> 验收：package.json 三包版本均为 0.5.1；前端 vue-tsc 类型检查通过；thinkingPlugin 默认注册处理 reasoning_content

### 1.1 升级 package.json 依赖版本到 0.5.1
- [ ] 在 `apps/web-admin/web/package.json` 中将 `@opentiny/tiny-robot`、`@opentiny/tiny-robot-kit`、`@opentiny/tiny-robot-svgs` 三个包版本统一从 `0.3.3` 修改为 `0.5.1`，禁止混版本
- [ ] 执行 `pnpm install` 安装新依赖，确认无 peer dependency 冲突（vue >=3.0.0 满足）；如出现冲突记录冲突详情并解决
- [ ] 在项目文档或 commit message 中记录此前 0.4.x 回退到 0.3.3 的原因（思维链未能实现），并验证 0.5.1 已修复该问题（thinkingPlugin 默认注册）

### 1.2 迁移 useTinyRobotChat 到 0.5.1 useMessage + ResponseProvider 模式
- [ ] 改造 `apps/web-admin/web/src/lib/webmcp-sdk/packages/next-remoter/src/composable/useTinyRobotChat.ts`：移除 0.3.3 的 `new AIClient({providerImplementation})` 模式，改为 0.5.1 的 `useMessage({responseProvider, plugins:[thinkingPlugin, lengthPlugin]})` 模式
- [ ] 在 useTinyRobotChat 中配置 `autoSaveThrottle: 500`（流式输出期间节流保存），保留 `autoSave: true`，保留会话管理逻辑（useConversation + switchConversation + createConversation + deleteConversation）
- [ ] 适配 `abortRequest`：包装为先通过 `cancelChat()` 发送 MCP `notifications/cancelled` 到后端，再调用 0.5.1 的 `abortActiveRequest`；确保 AbortSignal 传递到 ResponseProvider
- [ ] 删除代码中所有 0.3.3 的 `STATUS.INIT`/`STATUS.PROCESSING` 等旧枚举引用，改用 0.5.1 的 `RequestState`（idle/processing/completed/aborted/error）和 `ProcessingState`（requesting/completing）
- [ ] 保持 useTinyRobotChat 返回值结构兼容（messages、inputMessage、sendMessage、abortRequest、handleSendMessage、createConversation、switchConversation 等字段名和类型不变），确保存量调用方无需修改

### 1.3 将 CustomAgentModelProvider 适配为 0.5.1 ResponseProvider 签名
- [ ] 改造 `apps/web-admin/web/src/lib/webmcp-sdk/packages/next-sdk/agent/AgentModelProvider.ts` 中的 CustomAgentModelProvider：新增 `toResponseProvider()` 方法，返回符合 0.5.1 `ResponseProvider = (requestBody: MessageRequestBody, abortSignal: AbortSignal) => AsyncStreamableResult<ChatCompletionChunk>` 签名的函数
- [ ] 在 ResponseProvider 内部调用现有 `_chatViaWebMCP` 构建 ReadableStream，将 SSE 事件（reasoning-delta、response.output_text.delta、tool-call-*）转换为 ChatCompletionChunk enqueue 到 ReadableStream
- [ ] 确保 ResponseProvider 正确处理 AbortSignal：abort 触发时关闭 EventSource、结束 ReadableStream、发送 cancel 信号到后端
- [ ] 保留降级兼容逻辑：如 SSE 未推送 reasoning，从 completion 响应的 `reasoning_content` 独立字段提取并拆分 enqueue；如 SSE 未推送 content 增量，从 `completion.values[0]` 一次性 enqueue

### 1.4 前端 SSE EventSource 监听新增 response.output_text.delta 事件
- [ ] 在 `AgentModelProvider.ts` 的 `_chatViaWebMCP` EventSource 监听器中新增 `response.output_text.delta` 事件处理：将 data.delta 作为正文增量 enqueue 到 ReadableStream 的 `{type:'delta', delta}` chunk
- [ ] 确认现有 `reasoning-start`/`reasoning-delta`/`reasoning-end`/`tool-call-start`/`tool-call-end` 监听器保持不变，与新增的 content delta 事件交替处理
- [ ] 验证 SSE 双通道架构：POST `/api/v1/uctoo/webmcp/mcp`（completion/complete）+ GET `/api/v1/uctoo/webmcp/sse`（EventSource）同时存在

### 1.5 前端类型检查与编译验证
- [ ] 执行 `vue-tsc --noEmit` 进行 TypeScript 类型检查，修复 0.5.1 API 迁移导致的类型错误
- [ ] 执行 `vite build` 验证前端构建通过，确认无 0.3.3 残留引用导致的编译错误
- [ ] 在浏览器中验证：发送聊天消息后"思考过程"折叠面板自动展开并显示思维链内容（thinkingPlugin 生效），正文逐字显示

---

## 2. P1：后端 SSEEventBridge 逐字流式推送（仓颉 .cj）

> 目标：将 SSEEventBridge 的 reasoning-delta 从整段推送改为逐字推送（1-10 字符增量，20-50ms 间隔），新增正文 content 增量推送。
> 依赖：无（可与 P0 并行，但 P2 依赖 P1）
> 验收：SSEEventBridge 推送多个 reasoning-delta 事件每个仅含少量字符增量；新增 response.output_text.delta 事件推送正文增量
> **仓颉代码约束：以下所有任务必须使用 cangjie-coder 技能编写，必须检索到确定的编码依据后再生成代码，严禁运行 cjpm build**

### 2.1 新增 CharDeltaSplitter 工具类（字符增量拆分器）
- [ ] 使用 cangjie-coder 技能，在检索到 `src/app/services/bridge/sse_event_bridge.cj` 现有 SSEEventBridge 实现和 `src/tool/webmcp/SSEConnectionManager.cj` 的 pushMessage 接口依据后，新增 `src/app/services/bridge/char_delta_splitter.cj` 文件
- [ ] 实现 `public static func split(content: String, chunkSize: Int64 = 5): Array<String>` 方法：**先调用 `content.toRuneArray()` 转换为 `Array<Rune>`**，再按 chunkSize 切分 Rune 数组，最后用 `String.fromRuneArray(slice)` 还原为字符串增量块；**禁止直接用 `content[0..chunkSize]` 字节切片**（仓颉 String 为 UTF-8 编码，字节切片会截断多字节中文字符）；空字符串返回 `Array<String>(0, {_ => ""})`；每块长度 ≤ chunkSize（按 Rune 计数）
- [ ] **仓颉 Array 约束**：返回类型 `Array<String>` 为定长数组，需先计算块数量 `blockCount = ceil(runeCount / chunkSize)`，再用 `Array<String>(blockCount, {_ => ""})` 初始化并按索引 `result[idx] = ...` 赋值；**禁止使用 `ArrayList<String>.append`**（仓颉 ArrayList 没有 append/add/push 方法）
- [ ] 编写单元测试验证：中文字符串切分不截断（如 `"中文测试"` chunkSize=2 应得 `["中文","测试"]`）、空字符串返回空数组、切分后拼接等于原字符串、每块长度 ≤ chunkSize

### 2.2 新增 SSEEventBridge.pushReasoningStream 逐字推送方法
- [ ] 使用 cangjie-coder 技能，在检索到 `src/app/services/bridge/sse_event_bridge.cj` 现有 ChatModelEndEventHandler 中整段推送 reasoning 的代码依据（约 line 122-124）后，新增 `pushReasoningStream(sseMgr, sessionId, reasoningId, reason, chunkSize=5, intervalMs=30)` 方法
- [ ] 方法逻辑：调用 CharDeltaSplitter.split 拆分 reason 为增量数组；先 pushMessage(reasoning-start, {id:reasoningId})；循环 pushMessage(reasoning-delta, {id, reasoning:增量}) 并 `sleep(Duration.millisecond * intervalMs)`；最后 pushMessage(reasoning-end, {id:reasoningId})
- [ ] **仓颉 `sleep` 约束**：仓颉标准库 `sleep` 接收 `Duration` 类型而非 `Int64`，禁止直接写 `sleep(intervalMs)`，必须写 `sleep(Duration.millisecond * intervalMs)`。参考 `WebMCPProtocol.cj:1276` 现有写法 `sleep(Duration.second * 15)`
- [ ] **仓颉 JSON 转义约束**：推送 reasoning-delta 前，增量字符串必须经过 JSON 转义。**禁止使用手工 `replace` 链**（遗漏 Unicode 控制字符 `\u0000-\u001F`，存在注入风险）。应使用仓颉标准库的 `JsonString(value).toString()` 标准化转义，或抽取 `escapeJson(str: String): String` 工具方法并覆盖全部控制字符（`\\`、`\"`、`\n`、`\r`、`\t`、`\u0000-\u001F`）
- [ ] 异常处理：推送前检查 `sseMgr.hasConnection(sessionId)`，连接断开时跳过推送并记录 warn 日志；pushMessage 异常时捕获并停止后续推送，记录 error 日志，不阻塞 ReAct 执行

### 2.3 新增 SSEEventBridge.pushContentStream 正文增量推送方法
- [ ] 使用 cangjie-coder 技能，在检索到 `src/app/services/bridge/sse_event_bridge.cj` 现有事件处理逻辑依据后，新增 `pushContentStream(sseMgr, sessionId, content, outputIndex=0)` 方法
- [ ] 方法逻辑：调用 CharDeltaSplitter.split 拆分 content 为增量块；循环 pushMessage("response.output_text.delta", {output_index:outputIndex, delta:增量}) 推送正文增量
- [ ] 异常处理：同 pushReasoningStream，连接断开跳过推送，异常捕获不阻塞 ReAct

### 2.4 改造 SSEEventBridge ChatModelEndEventHandler 为逐字推送
- [ ] 使用 cangjie-coder 技能，在检索到 `src/app/services/bridge/sse_event_bridge.cj` 中 ChatModelEndEventHandler 的整段推送代码依据后，将原有 `sseMgr.pushMessage(sid, "reasoning-delta", 完整reasoning)` 改为调用 `pushReasoningStream(sseMgr, sid, reasoningId, reason)`
- [ ] 在同一 ChatModelEndEventHandler 中新增对 `evt.chatResponse.message.content` 的处理：当 content 非空时调用 `pushContentStream(sseMgr, sid, content)` 推送正文增量
- [ ] 保留 ReAct 多轮独立思维链块逻辑：每轮 LLM 调用使用全局 `_reasoningStepCount` 计数器生成唯一 id `reasoning-sse-{stepCount}`，stepCount++ 用于下一轮
- [ ] 保留 ToolCallStartEventHandler/ToolCallEndEventHandler 现有 tool-call-start/tool-call-end 推送逻辑不变，与 reasoning/content 事件交替推送

### 2.5 后端 SSEEventBridge 逐字推送验证（人工编译）
- [ ] 通知人工在独立 cmd 环境执行 `cjpm build` 编译仓颉代码并反馈编译结果（**严禁在本工具中运行 cjpm build**）
- [ ] 编译通过后，启动后端服务，前端发送聊天消息，验证浏览器 EventSource 收到多个 reasoning-delta 事件（每个 1-10 字符增量），"思考过程"面板逐字显示动画效果
- [ ] 验证 ReAct 多轮 LLM 调用时前端显示多个独立"思考过程"块，每个块有唯一 thinkId；验证 tool-call-start → reasoning-delta → tool-call-end 事件序列正确

---

## 3. P2：后端 WebMCP 真流式响应（仓颉 .cj）

> 目标：将 WebMCPController.handleStreamableHttp 从假流式（spawn + res.send）改造为真流式（http_lib ConnectionController 劫持连接 + conn.write+flush），使用 ChatModel.asyncCreate 异步流式处理。
> 依赖：P1（SSEEventBridge 逐字推送已就绪）
> 验收：handleStreamableHttp 通过 conn.write()+flush() 逐步推送；后端使用 asyncResponse.chunks 迭代器逐块读取；流式响应返回 MCP JSON-RPC 2.0 格式
> **仓颉代码约束：以下所有任务必须使用 cangjie-coder 技能编写，必须检索到确定的编码依据后再生成代码，严禁运行 cjpm build**

### 3.1 确认/扩展 Agent.asyncChat 异步聊天方法
- [ ] 使用 cangjie-coder 技能，检索 `src/core/model/chat_model.cj:37` 的 `asyncCreate` 接口和 `src/core/model/async_chat_response.cj` 的 AsyncChatResponse chunks 迭代器依据，确认 ReactExecutor 内部是否调用 asyncCreate
- [ ] 如 Agent.asyncChat 不存在或 ReactExecutor 未使用 asyncCreate，使用 cangjie-coder 技能按以下 3 个子任务拆分实现：

#### 3.1.1 ReactExecutor 新增 asyncExecute 方法
- [ ] 在 `src/agent_executor/react/react_executor.cj` 中新增 `public func asyncExecute(request: AgentRequest): AsyncAgentResponse` 方法
- [ ] 方法逻辑：与现有同步 `execute()` 方法结构一致，但内部调用 `chatModel.asyncCreate(chatRequest)` 而非 `chatModel.create(chatRequest)`；将返回的 `AsyncChatResponse` 包装为 `AsyncAgentResponse`（复用 `AsyncChatResponse` 的 `chunks: Iterator<AsyncChatChunk>` 迭代器）
- [ ] **仓颉迭代器副作用约束**：`AsyncChatResponse.next()` 内部有 `content.append` 累加副作用，迭代完成后 `asyncResponse.message` 才可安全读取；`next()` 在迭代器耗尽时会 `throw UnsupportedException("Unreachable")`，调用方必须在 `chunk.done == true` 时主动 break 退出循环，或用 `try-catch` 包裹迭代循环
- [ ] 确保每轮 LLM 调用触发 ChatModelEndEvent（供 SSEEventBridge 推送），工具调用触发 ToolCallStartEvent/ToolCallEndEvent
- [ ] 异常降级：如 ChatModel.asyncCreate 不支持，降级为同步 chat() + SSEEventBridge 整段推送（保留兼容）

#### 3.1.2 SkillAwareAgent 新增 asyncChat 方法
- [ ] 在 `src/skill/skill_aware_agent.cj` 中新增 `public func asyncChat(request: AgentRequest): AsyncAgentResponse` 方法
- [ ] 方法逻辑：委托内部 `executor.asyncExecute(request)`，签名与同步 `chat()` 方法对应但返回异步响应
- [ ] 确保 SkillManager 技能加载、TieredMemory 历史上下文加载等前置逻辑与同步 `chat()` 一致

#### 3.1.3 AsyncAgentResponse 类型定义（若不复用 AsyncChatResponse）
- [ ] 若 `AsyncChatResponse` 的 `chunks: Iterator<AsyncChatChunk>` 语义不足以表达 Agent 多轮 ReAct 响应，在 `src/core/agent/async_agent_response.cj` 中定义 `AsyncAgentResponse` 类型，包含 `chunks: Iterator<AsyncAgentChunk>` 迭代器
- [ ] `AsyncAgentChunk` 应包含 `message: Message`（含 content + reason 增量）、`done: Bool`、`usage: Option<ChatUsage>` 字段，与 `AsyncChatChunk` 结构对齐
- [ ] **优先策略**：若 `AsyncChatResponse` 可直接复用（`chunks` 迭代器语义足够），则跳过此子任务，在 3.1.1/3.1.2 中直接返回 `AsyncChatResponse` 类型

### 3.2 新增 WebMCPProtocol.handleCompletionCompleteStream 异步流式分支
- [ ] 使用 cangjie-coder 技能，在检索到 `src/app/services/webmcp/WebMCPProtocol.cj:1154-1357` 现有 handleCompletionComplete 同步实现依据后，新增 `private func handleCompletionCompleteStream(obj: JsonObject): String` 方法
- [ ] 方法逻辑：复用现有参数解析（messages、stream、model）、system prompt 合并（buildAgentSystemPrompt）、历史上下文加载（CheckpointManager.loadLatestCheckpoint）、progress 定时器启动、SSEEventBridge initialize
- [ ] 将同步 `agent.chat(agentRequest)` 改为 `agent.asyncChat(agentRequest)`，迭代 AsyncAgentResponse 的 chunks：每块 chunk 通过 SSEEventBridge 推送 reasoning + content 增量（依赖 P1 的 pushReasoningStream/pushContentStream）
- [ ] chunks 迭代完毕后：推送 response.completed 事件，清理 SSEEventBridge，停止 progress 定时器，提取 reasoning_content 转发到 completion 独立字段，异步同步 Agent 状态到数据库
- [ ] 返回符合 MCP 协议的 JSON-RPC 2.0 响应（`{jsonrpc:"2.0", result:{completion:{values, total, hasMore}}}`），与非流式响应格式一致
- [ ] 异常降级：Agent.asyncChat 不支持时降级调用 handleCompletionComplete 同步分支；大模型 API 错误返回 MCP error 响应并 SSE 推送 response.failed；超时返回 MCP error（timeout）

### 3.3 新增 WebMCPController.handleStreamableHttpRealStream 真流式分支
- [ ] 使用 cangjie-coder 技能，在检索到 `src/app/controllers/uctoo/webmcp/WebMCPController.cj:137-235` 现有 handleStreamableHttp 假流式实现依据和 `libs/http_lib/src/server/hijacker.cj` ConnectionController 劫持连接依据后，新增 `private func handleStreamableHttpRealStream(req, res, body): Unit` 方法
- [ ] 方法逻辑：通过 http_lib ConnectionController 劫持连接（req.takenOver = true）；写入 SSE 响应头（Content-Type: text/event-stream）；初始化 SSEConnectionManager 注册 sessionId→writer 回调（writer = message => conn.write(message.rawData) + conn.flush()）
- [ ] 调用 `protocol.handleCompletionCompleteStream(body)` 异步执行：SSE 事件通过 writer 实时推送到前端，最后 conn.write(MCP JSON-RPC 响应) + flush() 并关闭连接
- [ ] 保留 SSE 心跳保活：每 15 秒 conn.write(": ping\n\n") + flush() 保持连接活跃
- [ ] 异常降级：连接劫持失败（req.connection 为 None）时降级调用现有 handleStreamableHttp 假流式分支（spawn + res.send），SSE 事件仍通过独立 /sse 端点推送

### 3.4 改造 WebMCPController.handleStreamableHttp 调用真流式分支
- [ ] 使用 cangjie-coder 技能，在检索到 `src/app/controllers/uctoo/webmcp/WebMCPController.cj:137-235` 现有流式分支代码依据后，将 `spawn { let response = protocol.handleMessage(body); res.send(response) }` 假流式改为调用 `handleStreamableHttpRealStream(req, res, body)` 真流式分支
- [ ] 保留非流式分支（stream:false）现有同步 handleMessage + res.json 逻辑不变
- [ ] 保留 notifications/* 方法提前返回逻辑不变

### 3.5 后端真流式响应验证（人工编译）
- [ ] 通知人工在独立 cmd 环境执行 `cjpm build` 编译仓颉代码并反馈编译结果（**严禁在本工具中运行 cjpm build**）
- [ ] 编译通过后，前端发送聊天消息，验证：浏览器 Network 面板中 POST `/webmcp/mcp` 响应类型为 text/event-stream，响应逐步到达而非一次性返回
- [ ] 验证流式响应完成后返回的 MCP 响应符合 JSON-RPC 2.0 格式（completion.values 数组），现有非流式调用方不受影响
- [ ] 验证 ReAct 执行时间超过 15 秒时前端每 15 秒收到 progress SSE 事件（resetTimeoutOnProgress 不超时）

---

## 4. P3：AIController 降级为 OpenAI 兼容辅助接口（仓颉 .cj）

> 目标：移除 AIController 中与 WebMCPProtocol 重复的 SkillAwareAgent + ReactExecutor 初始化，改为仅直接调用 ChatModel.create，保留 OpenAI 兼容响应格式但不增强流式思维链。
> 依赖：无（可与 P0-P2 并行）
> 验收：AIController 不包含 SkillAwareAgent 和 ReactExecutor 初始化；handleChatCompletions 直接调用 _chatModel.create；保留 OpenAI 兼容响应格式
> **仓颉代码约束：以下所有任务必须使用 cangjie-coder 技能编写，必须检索到确定的编码依据后再生成代码，严禁运行 cjpm build**

### 4.1 移除 AIController 中重复的 ReAct 执行逻辑
- [ ] 使用 cangjie-coder 技能，在检索到 `src/app/controllers/uctoo/ai/AIController.cj` 现有 SkillAwareAgent + ReactExecutor + TieredMemory 初始化代码依据后，移除这些字段和初始化逻辑
- [ ] 改造构造函数为 `init(chatModel: ChatModel)`，仅保留 ChatModel 依赖（移除 SkillManager 依赖如不再需要）
- [ ] 确认 WebMCPProtocol 中 SkillAwareAgent + ReactExecutor 初始化不受影响（WebMCP 作为主要聊天接口保留完整 ReAct 能力）

### 4.2 改造 AIController.handleChatCompletions 为直接调用 ChatModel
- [ ] 使用 cangjie-coder 技能，在检索到 `src/app/controllers/uctoo/ai/AIController.cj` 现有 handleChatCompletions 代码依据后，将 `agent.chat()` 调用改为直接 `_chatModel.create()` 调用
- [ ] 保留 OpenAI 兼容响应格式（choices[].delta.content / choices[].message.content），供第三方 OpenAI 兼容客户端（Cursor、Continue 等）调用
- [ ] 不推送 reasoning_content（第三方客户端不依赖思维链），不初始化 SSEEventBridge，不调用 SSEConnectionManager
- [ ] 保留 stream/非 stream 分支：stream 分支通过 ChatModel.asyncCreate 获取 chunks 并按 OpenAI SSE 格式推送（data: {choices:[{delta:{content}}]}\n\n）；非 stream 分支同步返回完整响应

### 4.3 改造 AIController.handleResponses 为直接调用 ChatModel
- [ ] 使用 cangjie-coder 技能，在检索到 `src/app/controllers/uctoo/ai/AIController.cj` 现有 handleResponses 代码依据后，同样改为直接 `_chatModel.create()` 调用，移除 agent 依赖
- [ ] 保留 OpenAI Responses API 兼容响应格式

### 4.4 AIController 降级验证（人工编译）
- [ ] 通知人工在独立 cmd 环境执行 `cjpm build` 编译仓颉代码并反馈编译结果（**严禁在本工具中运行 cjpm build**）
- [ ] 验证第三方 OpenAI 兼容客户端调用 `/api/v1/ai/chat/completions` 能正常获取聊天响应（不含 reasoning_content 流式推送）
- [ ] 验证前端聊天请求统一走 `/api/v1/uctoo/webmcp/mcp`，不出现对 `/api/v1/ai/chat/completions` 的调用

---

## 5. 集成测试与端到端验证

> 目标：验证 P0-P3 全部完成后，流式思维链功能端到端可用，会话管理、取消请求、降级兼容等场景正常。
> 依赖：P0 + P1 + P2 + P3 全部完成
> 验收：所有 spec 验收条件通过

### 5.1 流式思维链端到端功能验证
- [ ] 验证流式首字延迟 ≤ 3 秒（大模型 API 响应时间除外）：前端发送消息后首个 reasoning-delta 或正文 SSE 事件到达时间
- [ ] 验证思维链逐字显示：reasoning-delta 每个事件含 1-10 字符增量，间隔 20-50ms，前端"思考过程"面板逐字显示动画效果
- [ ] 验证正文流式显示：response.output_text.delta 事件实时推送正文增量，前端消息气泡逐字显示，非一次性出现
- [ ] 验证 ReAct 多轮独立思维链块：ReAct 执行 N 轮 LLM 调用时前端显示 N 个独立"思考过程"块，每个块有唯一 thinkId
- [ ] 验证工具调用状态推送：ReAct 执行工具调用时前端收到 tool-call-start → reasoning-delta → tool-call-end 事件序列

### 5.2 会话管理与持久化验证
- [ ] 验证会话隔离：会话 A 正在生成时切换到会话 B，会话 B 消息和状态独立，会话 A 在后台继续生成；切回会话 A 时内容继续更新
- [ ] 验证切换会话不取消后台请求：切换会话操作不触发 abortActiveRequest，后台 processing 状态的 Engine 保留
- [ ] 验证自动保存节流：流式输出期间每 500ms 触发一次 LocalStorage 保存（而非每个 chunk 都保存）
- [ ] 验证断线恢复：页面刷新后会话列表和历史消息从 Storage 完整恢复；正在生成的请求刷新后视为中止

### 5.3 请求取消与超时验证
- [ ] 验证请求取消：用户点击"停止生成"后前端 AbortSignal 通过 MCP notifications/cancelled 传递到后端，后端中止大模型 API 调用和 ReAct 循环，已接收内容保留
- [ ] 验证超时协同：runtime HTTP 客户端 readTimeout（2 分钟）< 前端 AbortController timeout（10 分钟），runtime 能在前端超时前返回
- [ ] 验证 SSE 连接保活：SSE 连接每 15 秒收到 ping 心跳，代理/防火墙不超时断开；ReAct 执行期间每 15 秒收到 progress 事件

### 5.4 降级兼容验证
- [ ] 验证大模型不支持 reasoning_content（如 DeepSeek-V3 非推理模型）：thinkingPlugin 不触发，SSEEventBridge 不推送 reasoning 事件，前端不显示"思考过程"面板，仅显示正文
- [ ] 验证 SSE 连接中断：流式输出过程中 SSE 断开，已接收内容保留，completion 响应返回后正文完整显示
- [ ] 验证存量 LocalStorage 数据兼容：升级前已有的会话数据能被 0.5.1 Storage Strategy 正确读取；如格式不兼容则降级返回空会话列表
- [ ] 验证 AIController 降级：前端误调用 `/api/v1/ai/chat/completions` 时正常响应但不包含 reasoning_content 流式推送

### 5.5 安全性与可维护性验证
- [ ] 验证 API Key 不暴露到前端构建产物：大模型 API Key 通过 agentskills-runtime 后端代理转发，前端网络请求不直接调用大模型 API
- [ ] 验证流式内容 JSON 转义：SSE 推送的 reasoning_content 和 content 经过 JSON 转义，防止注入攻击
- [ ] 验证日志可观测：后端每个 reasoning-delta、tool-call-start、tool-call-end 事件记录调试日志（含 sessionId、stepCount、内容长度）
- [ ] 验证错误可追踪：流式输出异常记录完整错误堆栈，向前端推送错误事件而非静默丢弃

---

## 6. 部署配置与文档更新

> 目标：确保升级后的功能可上线，配置正确，文档完备。
> 依赖：P0-P3 完成 + 集成测试通过

### 6.1 环境配置确认
- [ ] 确认大模型 API 连接配置（MODEL_CONFIG、ATOMGIT_BASE_URL、API Key）在后端环境变量中正确配置，不暴露到前端
- [ ] 确认 http_lib ConnectionController 连接劫持能力在生产环境可用（req.connection 非空）
- [ ] 确认 SSE 端点 `/api/v1/uctoo/webmcp/sse` 和 MCP 端点 `/api/v1/uctoo/webmcp/mcp` 路由注册正确

### 6.2 文档更新
- [ ] 更新前端 API 使用文档：记录 tiny-robot-kit 0.5.1 与 0.3.3 的 API 差异点（AIClient → ResponseProvider、STATUS → RequestState、events.onReceiveData → plugins）
- [ ] 记录 0.4.x 回退原因和 0.5.1 修复验证结果，标注 thinkingPlugin 默认注册行为
- [ ] 更新后端 SSE 事件格式文档：新增 `response.output_text.delta` 事件类型说明（data 含 output_index 和 delta）
- [ ] 更新 AIController 接口文档：标注降级为 OpenAI 兼容辅助接口，不再增强流式思维链，主要聊天统一走 WebMCP 接口

### 6.3 监控埋点确认
- [ ] 确认后端流式推送关键指标监控：reasoning-delta 推送次数、推送间隔、SSE 连接数、连接断开率
- [ ] 确认错误指标监控：SSE 写入异常、大模型 API 错误、ReAct 执行超时、连接劫持失败降级次数

---

## 7. 代码审查与最终验证

> 目标：确保交付质量，设计与实现一致性核对。
> 依赖：全部任务完成

### 7.1 代码审查
- [ ] 审查前端 useTinyRobotChat 迁移代码：确认 0.5.1 API 使用正确、返回值结构兼容、无 0.3.3 残留引用
- [ ] 审查 CustomAgentModelProvider ResponseProvider 适配代码：确认 ReadableStream 构建正确、AbortSignal 处理正确、降级兼容逻辑完备
- [ ] 审查后端仓颉代码（cangjie-coder 生成）：确认 CharDeltaSplitter 按 Rune 切分正确、pushReasoningStream/pushContentStream 异常处理完备、handleCompletionCompleteStream 异步流式逻辑正确、handleStreamableHttpRealStream 连接劫持正确
- [ ] 审查 AIController 降级代码：确认 SkillAwareAgent/ReactExecutor 已移除、仅调用 ChatModel.create、OpenAI 兼容响应格式保留

### 7.2 设计一致性核对
- [ ] 核对 spec 5.1（tiny-robot 依赖升级）所有验收条件：package.json 三包 0.5.1、thinkingPlugin 默认注册、ResponseProvider 模式、无 STATUS 旧枚举
- [ ] 核对 spec 5.2（WebMCP 接口统一流式思维链）所有验收条件：统一走 WebMCP、SSE 双通道、reasoning 逐字推送、正文流式推送、ReAct 多轮独立块、工具调用状态推送
- [ ] 核对 spec 5.3（SSEEventBridge 逐字流式优化）所有验收条件：1-10 字符增量、20-50ms 间隔、ReAct 多轮独立 id、正文增量推送、禁止整段推送
- [ ] 核对 spec 5.4（WebMCP completion/complete 流式响应增强）所有验收条件：真流式 conn.write+flush、asyncCreate chunks 迭代、SSE 事件格式统一、MCP 协议响应兼容、progress 保活
- [ ] 核对 spec 5.5（统一聊天接口与工具组合调用）所有验收条件：统一走 WebMCP、AIController 兼容保留、不重复实现 ReAct
- [ ] 核对 spec 5.6（会话管理与持久化）所有验收条件：会话隔离、后台运行保留、自动保存节流、存储策略可替换、切换不取消后台请求

### 7.3 变更范围最终确认
- [ ] 确认变更文件清单：前端（package.json、useTinyRobotChat.ts、AgentModelProvider.ts）+ 后端（char_delta_splitter.cj 新增、sse_event_bridge.cj 修改、WebMCPProtocol.cj 修改、WebMCPController.cj 修改、AIController.cj 修改、可能涉及 chat_model.cj/async_chat_response.cj 扩展）
- [ ] 确认无数据库 schema 变更（本升级仅涉及前端依赖版本和后端接口流式增强）
- [ ] 确认无新业务模块引入，仅增强现有 WebMCP 接口流式能力