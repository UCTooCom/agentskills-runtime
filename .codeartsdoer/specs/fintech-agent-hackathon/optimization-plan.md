# AgentSkills Runtime 投研场景优化实施方案

> **文档定位**：基于 `optimization-report.md` 问题分析 + runtime 源码架构复核，制定的可执行优化方案。
>
> **核心原则**：沿用原有设计架构进行增量优化，复用现有基础设施。**新增 `get_skill_content` 内置工具**，支持渐进式技能加载，通过 CLI/API/MCP 三种方式对外提供调用。
>
> **日期**：2026-08-10 | **基于代码实际分析** | **覆盖用户提出的 5 个必须优化点 + get_skill_content 内置工具实现**

---

## 一、方案总览

| 编号 | 优化项 | 对应用户需求 | 涉及文件数 | 优先级 | 方案策略 |
|------|--------|------------|-----------|--------|---------|
| OPT-1 | 技能内容注入修复 | 2.1 技能3段式加载 | 2 | P0 | 修改 buildAgentSystemPrompt 注入完整 instructions |
| OPT-2 | 思维链传递修复 | 1 思维链显示 | 4 | P0 | 打开 withReason + SSE reasoning-delta 事件 |
| OPT-3 | firecrawl 移除与国产替代 | 2.2 firecrawl替代 | 3 | P1 | 从注册表移除 + 投研技能用 scripts 脚本 |
| OPT-4 | 聊天取消确定性机制 | 5 聊天取消 | 4 | P0 | WS cancel 消息 + stopInfo 触发 AgentCancelException |
| OPT-5 | crontab 长程任务优化 | 3 长程任务 | 3 | P1 | 孤儿任务清理 + response.status 检查 |
| OPT-6 | 日志噪声治理 | 2.3+4 日志清理 | 4 | P2 | eprintln→Logger + findLocked 降级 |
| OPT-7 | get_skill_content 内置工具 | 渐进式技能加载 | 5 | P0 | 实现内置工具 + CLI/API/MCP 对外暴露 |

---

## 二、OPT-1：技能内容注入修复（对应 P0-01 / 用户需求 2.1）

### 2.1 问题根因（代码验证）

| 位置 | 现状 | 问题 |
|------|------|------|
| `src/app/services/webmcp/WebMCPProtocol.cj:1314-1323` | `buildAgentSystemPrompt()` 只注入 `skill.name` + `skill.description` | SKILL.md 正文（instructions）未注入，agent 看不到 SOP 步骤 |
| `src/skill/skill_aware_agent.cj:51-73` | 技能已通过 `SkillToToolAdapter` 注册为工具 | 技能在工具列表中，但 agent 不知道如何使用（缺少参数说明和执行流程） |
| 系统提示生成处 | 包含 `"当需要用到某技能时，请使用 get_skill_content 工具获取该技能的完整文档内容"` | 引用了不存在的 `get_skill_content` 工具，agent 反复调用失败 |

**关键结论**：`get_skill_content` 工具从未实现（全代码库无此工具定义）。系统提示中引用它说明设计意图是支持按需加载技能内容。**正确做法是双管齐下**：① 系统提示注入技能摘要（name+description）；② 实现 `get_skill_content` 内置工具，让 agent 按需获取完整 SKILL.md 内容（渐进式加载，节省 token）。

### 2.2 优化方案（双管齐下）

**策略**：
1. 修改 `buildAgentSystemPrompt()`，注入技能的 `name` + `description` + `instructions` 摘要（前N行），并提示 agent 可调用 `get_skill_content` 获取完整内容
2. 实现 `get_skill_content` 内置工具（详见 OPT-7），让 agent 按需获取完整 SKILL.md

**改动点 1**：`src/app/services/webmcp/WebMCPProtocol.cj` - `buildAgentSystemPrompt()` 方法

```
现状（伪代码）：
  for skill in skills:
    prompt += "- **${skill.name}**: ${skill.description}\n"

改为：
  for skill in skills:
    prompt += "- **${skill.name}**: ${skill.description}\n"
    if skill.instructions.size > 0:
      prompt += "  详细说明:\n${skill.instructions}\n"
```

**改动点 2**：系统提示中将 `"请使用 get_skill_content 工具获取"` 的引导语改为 `"技能的详细使用说明已在上方列出，请直接按照说明中的 SOP 步骤执行。如需查看完整技能文档，可调用 get_skill_content 工具"`。

**改动点 3**（可选，控制 token 消耗）：增加 `.env` 配置 `SKILL_CONTENT_INJECT_MODE=full|summary|off`：
- `full`：注入完整 instructions（默认，确保 agent 看到 SOP）
- `summary`：只注入前 N 行（节省 token）
- `off`：只注入 name+description（回退到现状，依赖 get_skill_content 工具按需加载）

### 2.3 关于"3 段式加载"的说明

**现状**：`PROGRESSIVE_SKILL_LOADING_ENABLED` 配置存在于 `.env.example:198`，但全代码库无任何 `.cj` 文件读取该配置。`ProgressiveSkillLoader` 实际是一次性全量加载。

**方案**：不强制实现完整的 3 段式加载（元数据→内容→资源），因为：
1. 当前技能数量有限（~20 个），全量加载 SKILL.md 的性能开销可接受
2. 真正的问题不是加载方式，而是**加载后内容未注入 agent 上下文**（OPT-1 解决）
3. 如需节省 token，用 `SKILL_CONTENT_INJECT_MODE=summary` 即可

**未来扩展**（不在本次范围）：如需实现真正的 3 段式，可在 `SkillAwareAgent._registerSkillsAsTools()` 中分阶段：
- Stage 1：注册工具时只暴露 name+description（已实现）
- Stage 2：agent 首次调用技能工具时，按需加载完整 instructions 注入上下文
- Stage 3：执行时加载 scripts/COMPOSITION.yaml 资源

---

## 三、OPT-2：思维链传递修复（对应 P1-05 / 用户需求 1）

### 3.1 问题根因（代码验证）

| 位置 | 现状 | 问题 |
|------|------|------|
| `src/model/openai/chat.cj:92,184-218` | 已解析 `reasoning_content` 到 `Message.reason` | 模型层解析正常 |
| `src/agent_executor/react/react_task.cj:200` | `TagStreamParser(asyncChatResp.iter(withReason: false))` | **明确丢弃 reasoning** |
| `src/app/services/bridge/websocket_event_bridge.cj:62-71` | `ChatModelEndEvent` 只提取 model+usage | 不提取 `message.reason` |
| `src/app/controllers/uctoo/ws/WsChatController.cj:227-252` | 只取 `agentResponse.content` | reason 字段未传递 |
| `src/app/controllers/uctoo/webmcp/WebMCPController.cj:619-653` | SSE 只发 `event: connected` | 无 `reasoning-delta` 事件 |

**数据流断点**：大模型 → `reasoning_content` ✅ → `Message.reason` ✅ → `withReason: false` ❌ → SSE 无 reasoning 事件 ❌ → 前端无法显示

### 3.2 优化方案

**改动点 1**：`src/agent_executor/react/react_task.cj:200`

```
现状：TagStreamParser(asyncChatResp.iter(withReason: false))
改为：TagStreamParser(asyncChatResp.iter(withReason: true))
```

增加 `.env` 配置 `REASONING_ENABLED=true` 控制开关，默认开启。

**改动点 2**：`src/app/services/bridge/websocket_event_bridge.cj` - `ChatModelEndEvent` 处理

在事件缓冲中增加 reasoning 内容传递：

```
现状：事件只包含 model, usage
改为：事件增加 reasoning 字段（来自 chatResponse.message.reason）
```

**改动点 3**：`src/app/controllers/uctoo/ws/WsChatController.cj` - `_handleChatMessage`

在返回的 WebSocket 消息中增加 reasoning 字段：

```
现状：只返回 { content: agentResponse.content }
改为：返回 { content: agentResponse.content, reasoning: agentResponse.reason }
```

**改动点 4**：`src/app/controllers/uctoo/webmcp/WebMCPController.cj` - SSE 端点

在 SSE 流中生成 `reasoning-delta` 事件（ai-sdk 格式）：

```
event: reasoning-delta
data: { "textDelta": "思考内容片段" }
```

**改动点 5**（可选）：`src/model/openai/chat.cj` - `request2Json`

增加 `reasoning_effort` 参数传递给大模型：

```
如果 REASONING_EFFORT 配置存在，在 request JSON 中添加 "reasoning_effort": "${effort}"
```

### 3.3 前端配合说明

前端（web-admin）已就绪：
- `TinyRobotChat.vue` 已支持思维链渲染
- `StreamVisitor` 已实现 `reasoning-*` 事件解析
- `CustomAgentModelProvider` 已实现 `collapsible-text` 转换

**只需 runtime 端修复即可**，前端无需改动。

---

## 四、OPT-3：firecrawl 移除与国产替代（对应 P1-03 / 用户需求 2.2）

### 4.1 问题根因（代码验证）

| 位置 | 现状 | 问题 |
|------|------|------|
| `src/tool/firecrawl_tool.cj:41-50` | 支持 search/scrape/map/crawl 4 种 action | 参数 `query` 描述为"Search query or URL"，LLM 容易混淆 |
| `src/tool/builtin_tools_registry.cj:67` | `FirecrawlTool()` 注册为内置工具 | 依赖外部 firecrawl.dev API，token 可能配置不对 |
| 日志 Line 5821 | agent 用 `firecrawl` action=search 搜索中文关键词 | firecrawl.dev 不支持中文搜索或 token 无效，TLS 解析失败 |

### 4.2 优化方案

**策略**：将 firecrawl 从内置工具注册表中移除，投研场景通过 `scripts/*.py` 脚本直接抓取国内数据源。

**改动点 1**：`src/tool/builtin_tools_registry.cj` - `registerWebTools()`

```
现状：
  func registerWebTools(tm: ToolManager) {
    tm.register(WebFetchTool())
    tm.register(FirecrawlTool())    // ← 移除此行
  }

改为：
  func registerWebTools(tm: ToolManager) {
    tm.register(WebFetchTool())
    // firecrawl 已移除，使用 web_fetch + scripts 脚本替代
  }
```

**改动点 2**：投研技能 SKILL.md 更新

将 `skills/investment-research-assistant/SKILL.md` 中的工具引用从 `firecrawl` 改为 `web_fetch` + `scripts`：

```markdown
| 数据源 | 内容 | 推荐工具 |
|--------|------|---------|
| 行情接口 | 收盘价、涨跌幅等 | scripts/fetch_market_data.py（东方财富公开接口）|
| 公司公告 | 定期报告、重大事项 | web_fetch（已知 URL）|
| 财经新闻 | 行业动态、公司新闻 | web_fetch（财联社/东方财富已知 URL）|
```

**改动点 3**：国产搜索工具替代（可选，中期）

如需关键词搜索能力，可创建一个 `baidu_search` 技能（SKILL.md + scripts/baidu_search.py），通过百度搜索 API 获取 URL 列表，再用 `web_fetch` 抓取。这符合"技能是一等公民"的设计理念，而非新增内置工具。

```
skills/baidu-search/
  ├── SKILL.md          # 百度搜索技能定义
  └── scripts/
      └── search.py     # 调用百度搜索 API
```

### 4.3 移除影响评估

- `firecrawl-scraper` 技能（`skills/firecrawl-scraper/`）将失效，可一并移除或改为使用 `web_fetch`
- `test-web-tools` 技能中引用 firecrawl 的测试用例需更新
- 投研场景不受影响，因为 `scripts/fetch_market_data.py` 直接调用东方财富公开接口，不依赖 firecrawl

---

## 五、OPT-4：聊天取消确定性机制（对应用户需求 5）

### 5.1 问题根因（代码验证）

| 位置 | 现状 | 问题 |
|------|------|------|
| `src/core/agent/agent_cancel_exception.cj:9-16` | `AgentCancelException` 已定义 | 异常机制存在 |
| `src/agent_executor/common/agent_task.cj:220-221` | `chatLLM` 检查 `stopInfo` 抛出 `AgentCancelException` | 内部取消机制存在 |
| `src/app/services/webmcp/WebMCPProtocol.cj:357-364,374-388` | `notifications/cancelled` 空实现 | 收到取消通知不传递到 agent |
| `src/app/controllers/uctoo/ws/WsChatController.cj:173-186` | 消息类型无 `cancel` 分支 | WS 协议不支持取消 |
| `src/app/services/bridge/websocket_session_manager.cj` | 无 `cancelAgent` 方法 | 无法中断正在执行的 agent |

**断点**：前端取消 → WebMCP `notifications/cancelled`（空实现）❌ → 无法设置 stopInfo ❌ → agent 继续执行

### 5.2 优化方案

**策略**：复用现有 `AgentCancelException` + `stopInfo` 机制，增加外部触发路径。

**改动点 1**：`src/app/controllers/uctoo/ws/WsChatController.cj` - 消息分发

增加 `cancel` 消息类型：

```
现状 match 分支：chat | execute_skill | list_skills | ping | register_tools | approval_response
增加分支：cancel → 调用 WebSocketSessionManager.cancelAgent(sessionId)
```

**改动点 2**：`src/app/services/bridge/websocket_session_manager.cj`

增加 `cancelAgent(sessionId: String)` 方法：

```
func cancelAgent(sessionId: String): Bool {
  // 1. 查找 session 对应的 agent 执行上下文
  // 2. 设置 stopInfo（触发 AgentTask.chatLLM 中的 AgentCancelException）
  // 3. 返回是否成功取消
}
```

需要在 session 管理中记录每个 session 当前执行的 agent 引用和 stopInfo 设置回调。

**改动点 3**：`src/app/services/webmcp/WebMCPProtocol.cj` - `handleNotification`

将 `notifications/cancelled` 从空实现改为实际取消逻辑：

```
现状：只返回成功响应
改为：提取 sessionId，调用 WebSocketSessionManager.cancelAgent(sessionId)
```

**改动点 4**：`src/app/services/bridge/agent_runtime_bridge.cj`

在 agent 执行时记录 stopInfo 设置回调到 session 上下文，使 cancelAgent 能找到并设置 stopInfo。

### 5.3 取消流程（修复后）

```
前端点击"取消聊天"
  → WS 发送 { type: "cancel", sessionId: "xxx" }
  → WsChatController 收到 cancel 消息
  → WebSocketSessionManager.cancelAgent(sessionId)
  → 设置 stopInfo
  → AgentTask.chatLLM 检测到 stopInfo
  → 抛出 AgentCancelException
  → AbsAgent.chat catch 返回 AgentResponseStatus.Cancelled
  → 前端收到取消确认
```

---

## 六、OPT-5：crontab 长程任务优化（对应 P2-01/P2-02 / 用户需求 3）

### 6.1 问题根因（代码验证）

| 位置 | 现状 | 问题 |
|------|------|------|
| `src/app/services/crontab/SchedulerEngine.cj:205,270` | 任务不存在只输出 error 日志 | 不清理调度表中的孤儿引用 |
| `src/app/services/crontab/executor/AgentExecutionExecutor.cj:53` | 直接标记 status=2（成功） | 未检查 `response.status`，agent 内部失败仍标记成功 |

### 6.2 优化方案

**改动点 1**：`src/app/services/crontab/SchedulerEngine.cj` - `triggerTask()`

任务不存在时自动清理调度记录：

```
现状（第 270 行）：
  LogUtils.error("SchedulerEngine", "任务不存在: ${crontabId}")

改为：
  LogUtils.warn("SchedulerEngine", "任务不存在: ${crontabId}，自动清理调度记录")
  ticktock.remove(crontabId)  // 从调度器移除孤儿引用
  // 可选：更新数据库 crontab 表 status=0
```

**改动点 2**：`src/app/services/crontab/SchedulerEngine.cj` - 增加定期清理

在 `initialize()` 中注册一个定期清理任务（每 10 分钟扫描一次调度表，移除不存在的任务引用）：

```
func scheduleOrphanCleanup() {
  // 每 10 分钟执行一次
  // 遍历所有已注册的 crontabId
  // 查询数据库确认任务是否存在
  // 不存在的从 ticktock 移除
}
```

**改动点 3**：`src/app/services/crontab/executor/AgentExecutionExecutor.cj` - `execute()`

检查 `response.status` 字段：

```
现状（第 53 行）：
  updateTaskStatus(crontabId, Some(2), ...)  // 直接标记成功

改为：
  if (response.status == AgentResponseStatus.Success) {
    updateTaskStatus(crontabId, Some(2), ...)  // 成功
  } else if (response.status == AgentResponseStatus.Cancelled) {
    updateTaskStatus(crontabId, Some(4), ...)  // 取消（新增状态码）
  } else {
    updateTaskStatus(crontabId, Some(3), response.content)  // 失败，记录原因
  }
```

### 6.4 与 goai2026 基础设施适配

fintech-agent-hackathon 技能参考了 goai2026 的基础设施设计，但以下能力未完全适配：

| goai2026 能力 | 当前状态 | 适配建议 |
|-------------|---------|---------|
| 技能组合引擎（COMPOSITION.yaml 解析） | 未实现 | 本次不实现，通过 OPT-1 注入 SKILL.md 让 agent 手动按 SOP 执行 |
| DAG 编排引擎 | 未实现 | 本次不实现，通过 crontab 串行调度近似 |
| 执行证据链 | 部分实现（operate_log） | 本次不增强，保持现状 |
| AgentTeams 分层协作 | 部分实现（LeaderGroup） | 本次不增强，投研场景单 agent 即可 |

**结论**：本次优化聚焦于让现有基础设施稳定运行（crontab 调度、agent 执行），不新增 goai2026 的高级能力。投研场景通过"agent 读取 SKILL.md SOP → 调用 scripts 脚本 → crontab 调度"即可完成。

---

## 七、OPT-6：日志噪声治理（对应 P3-01 / 用户需求 2.3+4）

### 7.1 问题根因（代码验证）

| 位置 | 现状 | 问题 |
|------|------|------|
| `src/app/core/middleware/Middleware.cj:21,26,34,37` | 使用 `eprintln` 直接输出 | 绕过日志系统，无法控制级别，每条请求 4+ 条噪声 |
| `runtime_start.log` | 1703 条 findLocked 日志 | 路由注册时 httprouter 库的调试日志 |
| `src/app/core/log/Logger.cj:136-138` | `addAppender` 空实现 | Logger 类不完整，实际依赖 LogUtilsImpl |

### 7.2 findLocked 日志说明

**findLocked 是什么**：这是 httprouter 路由树库在注册路由时的内部调试日志。每注册一个路由，httprouter 会调用 `findLocked` 方法检查路由树的锁定状态，输出 method、path、root.path、children 数等信息。1703 条对应 ~850 个路由（每个路由 2 行）。

**为什么出现**：httprouter 库在注册路由时默认输出调试信息到 stderr，runtime 代码无法直接控制。

**如何处理**：httprouter 库的日志无法通过 runtime 代码修改，但可以通过以下方式减少噪声：
1. 重定向 stderr 到文件（启动脚本中 `2>logs/stderr.log`）
2. 或在启动脚本中过滤：`2>&1 | findstr /v findLocked`
3. 或升级 httprouter 库版本（如果有支持日志级别配置的新版本）

### 7.3 优化方案

**改动点 1**：`src/app/core/middleware/Middleware.cj` - 替换 eprintln

```
现状：
  eprintln("=== MiddlewareChain.execute: ${middlewares.size} middlewares ===")

改为（使用 LogUtils）：
  LogUtils.debug("Middleware", "MiddlewareChain.execute: ${middlewares.size} middlewares")
```

增加 `.env` 配置 `LOG_MIDDLEWARE=false` 时，完全跳过中间件日志。

**改动点 2**：`src/app/core/log/Logger.cj` - 修复 `addAppender` 空实现

```
现状（第 136-138 行）：
  public func addAppender(appender: LogAppender): Logger {
    return this  // 空实现
  }

改为：
  public func addAppender(appender: LogAppender): Logger {
    appenders.add(appender)
    return this
  }
```

**改动点 3**：启动脚本优化

在 `build_and_release.ps1` 或启动脚本中，将 stderr 重定向过滤 findLocked：

```powershell
# 现状：直接输出所有 stderr
# 改为：过滤 findLocked 噪声
cjpm run 2>&1 | Where-Object { $_ -notmatch 'findLocked' }
```

**改动点 4**：其他噪声日志清理

搜索代码中其他 `eprintln` 和 `println` 调用，替换为 `LogUtils.debug` 或移除：
- `src/app/core/middleware/Middleware.cj` 的所有 eprintln
- 启动期的路由注册日志（如果是 runtime 代码输出的）

---

## 八、P0-02：Agent 消息持久化失败（0x0a 未转义）

### 8.1 问题说明

日志中出现 SQLSTATE 22P02 错误，Agent 消息内容中换行符 `\n`（0x0a）未正确转义，导致无法写入数据库。

### 8.2 优化方案

**定位**：搜索 `agent_messages` 表的 INSERT 操作（`src/app/dao/uctoo/AgentMessagesDAO.cj` 或 `src/app/services/uctoo/AgentMessagesService.cj`）。

**改动**：使用参数化查询替代字符串拼接，或在写入前对 JSON 字符串进行转义：

```
// 写入前转义
let escapedContent = content.replace("\n", "\\n").replace("\r", "\\r")
// 或使用参数化查询（推荐）
// INSERT INTO agent_messages (content) VALUES ($1::jsonb)  ← 参数化
```

---

## 九、实施顺序与依赖

```
Phase 1（P0 阻断修复，立即）:
  OPT-1 技能内容注入修复  ← 修复后 agent 能看到 SOP 步骤
  OPT-2 思维链传递修复    ← 修复后用户能看到思考过程
  OPT-4 聊天取消机制      ← 修复后用户可取消任务
  P0-02 消息持久化修复     ← 修复后对话历史不丢失

Phase 2（P1 严重修复，高优先级）:
  OPT-3 firecrawl 移除    ← 修复后用 scripts 脚本抓取数据
  OPT-5 crontab 优化      ← 修复后长程任务稳定

Phase 3（P2 噪声治理，择机）:
  OPT-6 日志噪声治理      ← 修复后日志可读
```

---

## 十、验证检查清单

修复完成后验证：

- [ ] **OPT-1**：agent 收到投研请求时，系统提示中包含 SKILL.md 的 SOP 步骤，不再调用 `get_skill_content`
- [ ] **OPT-1**：agent 按照 SOP 调用 `cli_execute` 执行 `scripts/fetch_market_data.py`
- [ ] **OPT-2**：SSE 流中包含 `reasoning-delta` 事件
- [ ] **OPT-2**：前端显示"思考过程"折叠块
- [ ] **OPT-3**：工具列表中不再包含 `firecrawl`
- [ ] **OPT-3**：投研技能通过 `scripts/*.py` 直接抓取东方财富数据
- [ ] **OPT-4**：点击"取消聊天"后 agent 在 2 秒内停止执行
- [ ] **OPT-4**：取消后任务状态为 `Cancelled`
- [ ] **OPT-5**：调度器无孤儿任务重复执行
- [ ] **OPT-5**：agent 内部失败时任务状态为 `Failed`
- [ ] **OPT-6**：Middleware 日志不再出现在控制台（DEBUG 级别）
- [ ] **OPT-6**：findLocked 日志被过滤
- [ ] **OPT-7**：`get_skill_content` 工具可被 agent 调用，返回完整 SKILL.md 内容
- [ ] **OPT-7**：CLI `agentskills get-skill <name>` 可获取技能内容
- [ ] **OPT-7**：API `GET /api/v1/skills/:name/content` 可获取技能内容
- [ ] **OPT-7**：MCP `skills/get_content` 方法可获取技能内容
- [ ] **P0-02**：含换行符的消息能正确持久化

---

## 十一、OPT-7：get_skill_content 内置工具实现（渐进式技能加载）

### 11.1 调研结论

| 调研项 | 结论 |
|--------|------|
| DeepSeek API 是否内置 `get_skill_content` | **否**。DeepSeek 使用标准 OpenAI 兼容格式，仅支持标准 Tool Calls（function calling），无内置技能加载机制 |
| `get_skill_content` 来源 | 系统提示词设计中的引用，意图是支持按需加载技能内容，但工具从未实现 |
| 业界类似机制 | Claude Code 有 `skill` 工具；OpenAI Assistant API 有 `function` 工具；按需加载是通用最佳实践 |

### 11.2 设计目标

1. **渐进式加载**：系统提示只注入技能摘要（name+description），agent 按需调用 `get_skill_content` 获取完整 SKILL.md
2. **节省 token**：避免将所有技能的完整 instructions 一次性注入系统提示
3. **三种调用方式**：CLI、REST API、MCP 协议

### 11.3 实现方案

#### 11.3.1 内置工具实现（`src/tool/get_skill_content_tool.cj`）

```
工具名：get_skill_content
参数：
  - skill_name (String, required): 技能名称
  - section (String, optional): 要获取的章节（如 "SOP"、"data_sources"），不传则返回全部
返回：JSON 格式的技能内容
  {
    "name": "investment-research-assistant",
    "description": "...",
    "instructions": "完整 SKILL.md 正文",
    "metadata": {...}
  }
```

#### 11.3.2 工具注册（`src/tool/builtin_tools_registry.cj`）

在 `registerSkillTools()` 中注册 `GetSkillContentTool`，传入 `SkillManager` 引用。

#### 11.3.3 REST API 暴露（`src/app/controllers/uctoo/skill/SkillController.cj`）

```
GET /api/v1/skills/:name/content     → 获取技能完整内容
GET /api/v1/skills/:name/content/:section → 获取技能指定章节
```

#### 11.3.4 MCP 协议暴露（`src/app/services/webmcp/WebMCPProtocol.cj`）

在 `handleMethod()` 中新增 `skills/get_content` 方法处理：
```
method: "skills/get_content"
params: { "name": "investment-research-assistant", "section": "SOP" }
```

#### 11.3.5 CLI 暴露（`src/cli/commands/skill_commands.cj`）

```
agentskills get-skill <name> [--section <section>]
agentskills list-skills
```

### 11.4 涉及文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `src/tool/get_skill_content_tool.cj` | 新建 | GetSkillContentTool 实现 |
| `src/tool/builtin_tools_registry.cj` | 修改 | 注册 GetSkillContentTool |
| `src/app/controllers/uctoo/skill/SkillController.cj` | 修改/新建 | REST API 端点 |
| `src/app/services/webmcp/WebMCPProtocol.cj` | 修改 | MCP skills/get_content 方法 |
| `src/cli/commands/skill_commands.cj` | 修改/新建 | CLI 命令 |

---

## 十二、与 optimization-report.md 的差异说明

| 报告建议 | 本方案调整 | 原因 |
|---------|-----------|------|
| 新增 `get_skill_content` 工具 | **新增**（OPT-7），同时保留 OPT-1 的系统提示注入 | 用户要求实现 get_skill_content 内置工具，支持渐进式加载；系统提示注入技能摘要 + 工具按需加载完整内容 |
| 实现 COMPOSITION.yaml 解析 | **本次不实现** | 通过 OPT-1 注入 SKILL.md 让 agent 手动按 SOP 执行即可完成投研任务 |
| firecrawl 增加参数校验说明 | **直接移除** firecrawl | 用户要求用国产工具替代；投研场景用 scripts 脚本更可靠 |
| 增加 `web_search` 内置工具 | **不新增内置工具**，用技能替代 | 符合"技能是一等公民"设计理念 |

---

## 附录：关键文件索引

| 文件 | 优化项 | 说明 |
|------|--------|------|
| `src/app/services/webmcp/WebMCPProtocol.cj` | OPT-1, OPT-4, OPT-7 | 系统提示构建 + cancel 通知处理 + MCP skills/get_content |
| `src/agent_executor/react/react_task.cj` | OPT-2 | withReason 参数 |
| `src/app/services/bridge/websocket_event_bridge.cj` | OPT-2 | 事件缓冲增加 reasoning |
| `src/app/controllers/uctoo/ws/WsChatController.cj` | OPT-2, OPT-4 | reasoning 传递 + cancel 消息 |
| `src/app/controllers/uctoo/webmcp/WebMCPController.cj` | OPT-2 | SSE reasoning-delta 事件 |
| `src/tool/builtin_tools_registry.cj` | OPT-3, OPT-7 | 移除 firecrawl 注册 + 注册 GetSkillContentTool |
| `src/tool/firecrawl_tool.cj` | OPT-3 | 可移除整个文件 |
| `src/tool/get_skill_content_tool.cj` | OPT-7 | GetSkillContentTool 实现（新建） |
| `src/app/controllers/uctoo/skill/SkillController.cj` | OPT-7 | REST API 端点（新建/修改） |
| `src/cli/commands/skill_commands.cj` | OPT-7 | CLI 命令（新建/修改） |
| `src/app/services/bridge/websocket_session_manager.cj` | OPT-4 | cancelAgent 方法 |
| `src/app/services/bridge/agent_runtime_bridge.cj` | OPT-4 | stopInfo 回调记录 |
| `src/app/services/crontab/SchedulerEngine.cj` | OPT-5 | 孤儿任务清理 |
| `src/app/services/crontab/executor/AgentExecutionExecutor.cj` | OPT-5 | response.status 检查 |
| `src/app/core/middleware/Middleware.cj` | OPT-6 | eprintln → LogUtils |
| `src/app/core/log/Logger.cj` | OPT-6 | addAppender 修复 |
| `skills/investment-research-assistant/SKILL.md` | OPT-3 | 移除 firecrawl 引用 |
| `.env` / `.env.example` | OPT-1,2,6,7 | 新增配置项 |

---

# 第二轮优化实施方案（v2）

> **文档定位**：在 v1 优化落地后，针对 2026-08-10 10:19~10:50 最新一次运行复核，发现 v1 优化已正确落地 runtime 端能力，但 **web 端未集成**思维链显示控件和取消按钮对接，且 **agent 工具调用格式问题**是最新失败的真正阻断点。本方案针对这些**仍然失败**的根因制定迭代修复方案。
>
> **核心原则**：沿用原有设计架构进行增量优化，复用现有基础设施。针对 v1 未覆盖的 web 端集成和解析器 bug 进行精准修复。
>
> **日期**：2026-08-10 | **基于代码实际分析** | **覆盖用户提出的 5 个必须优化点 + v1 遗留问题**

---

## 一、v2 方案总览

| 编号 | 优化项 | 对应用户需求 | 涉及文件数 | 优先级 | 方案策略 |
|------|--------|------------|-----------|--------|---------|
| OPT-V2-1 | 修复 ReAct 工具调用解析格式 | 2.1 agent 没读全技能 | 3 | P0 | 修复 `extractFirstJsonWithHeuristic` 状态跟踪 bug + 系统提示增加工具调用格式说明 |
| OPT-V2-2 | 修复 http_request 流式响应处理 | 2.1 行情抓取失败 | 1 | P0 | `http_tool.cj` 增强 chunk terminator 错误处理，给出可操作的替代建议 |
| OPT-V2-3 | web 端集成思维链显示控件 | 1 思维链显示 | 2 | P0 | 新建 `BubbleThinkingRenderer.vue` + 注册 `collapsible-text` 渲染器 |
| OPT-V2-4 | web 端对接取消聊天按钮 | 5 取消确定性 | 2 | P0 | 新建 `cancel.ts` + 包装 `abortRequest` 发送 cancel 消息到后端 |
| OPT-V2-5 | 清理调度器孤儿任务循环 | 3 长程任务报错 | 1 | P1 | `SchedulerEngine.cj` triggerTask 中任务不存在时从 ticktock 移除 |
| OPT-V2-6 | 日志噪声治理 | 4 次要日志清理 | 2 | P2 | `tls12.cj` 移除 clientPubKey 调试 println + `Middleware.cj` 清理调试日志 |

---

## 二、OPT-V2-1：修复 ReAct 工具调用解析格式（P0 核心）

### 2.1 问题根因（代码验证）

| 位置 | 现状 | 问题 |
|------|------|------|
| `src/parser/parser_utils.cj:61-97` | `extractFirstJsonWithHeuristic` 的字符串状态跟踪存在时序错位 | `escaped` 状态更新与 `"` 处理存在时序错位，导致 `inString` 状态跟踪错误，无法正确识别 JSON 对象边界 |
| `src/app/services/webmcp/WebMCPProtocol.cj:1391-1459` | `buildAgentSystemPrompt()` 注入技能摘要 | 系统提示中未明确告知 agent 工具调用的确切输出格式，agent 按自己的理解生成嵌套转义 JSON |
| `src/agent_executor/react/react_step.cj:106-114` | `ReactStep.fromStr` 解析失败时返回 `Failure` | `failureInfo.suggestion` 回写给 agent 的纠错信息不够具体 |

**关键结论**：`extractFirstJsonWithHeuristic` 的状态跟踪逻辑（原第 91-94 行）在处理嵌套转义 JSON 时存在时序错位，导致 `inString` 状态跟踪错误。

### 2.2 修复方案

**改动点 1**：`src/parser/parser_utils.cj` — 重构 `extractFirstJsonWithHeuristic` 的状态跟踪逻辑

按字符优先级处理（先判 escaped，再判 `"`，再判 `{}`，最后判 inString），确保嵌套转义 JSON 能被正确解析：

```cangjie
for (idx in start..str.size) {
    let ch = str[idx]
    if (escaped) {
        escaped = false
        continue
    }
    if (ch == b'\\') {
        escaped = true
        continue
    }
    if (ch == b'"') {
        inString = !inString
        continue
    }
    if (inString) {
        continue
    }
    if (ch == beginSymbol) {
        numberOfBraces += 1
    } else if (ch == endSymbol) {
        numberOfBraces -= 1
        if (numberOfBraces == 0) {
            let jsonStr = str[start..(idx+1)].trimAscii()
            try {
                let _ = JsonValue.fromStr(jsonStr)
                return jsonStr
            } catch (ex: JsonException) {
                return None
            }
        }
    }
}
```

**改动点 2**：`src/app/services/webmcp/WebMCPProtocol.cj` — `buildAgentSystemPrompt()` 增加工具调用格式说明

在系统提示中明确告知 agent：
- arguments 的值必须是原生 JSON 类型（字符串、数字、布尔、数组、对象）
- 字符串类型的参数值不要再用 JSON 转义
- 提供正确示例和错误示例

**改动点 3**：`src/app/controllers/uctoo/ws/WsChatController.cj` — 同步优化 `_buildAgentSystemPrompt()`

与 `WebMCPProtocol.cj` 保持一致，增加工具调用格式说明。

---

## 三、OPT-V2-2：修复 http_request 流式响应处理（P0）

### 3.1 问题根因（代码验证）

| 位置 | 现状 | 问题 |
|------|------|------|
| `src/tool/http_tool.cj:81-267` | `HttpTool.invoke` 调用 `HttpUtils.get/post` | 底层 `http_lib` 对 chunked transfer-encoding 解析时遇到不规范的 chunk 边界，抛出 "invalid chunk terminator" |
| `src/utils/http/http_cj.cj:60-86` | `sendHttp` 调用 `client.send(req)` | 底层 `http_lib` 是第三方库，无法直接修改其源码 |
| `src/tool/http_tool.cj:260-266` | `catch (ex: Exception)` 仅返回 `ex.message` | 未针对 chunked 解析失败给出可操作的替代建议 |

**关键结论**：`http_lib` 是第三方库，无法直接修改其源码。但可以在 `HttpTool` 层增加容错处理：当底层 HTTP 请求因 chunk terminator 失败时，返回清晰的错误信息并建议使用 scripts 脚本作为替代。

### 3.2 修复方案

**改动点 1**：`src/tool/http_tool.cj` — 增强 chunk terminator 错误处理

在 `catch (ex: Exception)` 块中，针对底层 chunked 解析失败，给出可操作的替代建议：

```cangjie
} catch (ex: Exception) {
    LogUtils.error("[HttpTool] Error executing HTTP request: ${ex.message}")
    let errorJson = JsonObject()
    errorJson.put("success", JsonString("false"))
    errorJson.put("error", JsonString(ex.message))
    // 针对底层 chunked 解析失败，给出可操作的替代建议
    if (ex.message.contains("chunk terminator") || ex.message.contains("chunked")) {
        errorJson.put("suggestion", JsonString("该数据源的 HTTP chunked 响应格式不兼容，请改用技能目录下的 scripts/*.py 脚本（通过 python_execute 工具）获取数据。"))
    }
    return ToolResponse(errorJson.toJsonString())
}
```

---

## 四、OPT-V2-3：web 端集成思维链显示控件（P0）

### 4.1 问题根因（代码验证）

| 位置 | 现状 | 问题 |
|------|------|------|
| `apps/web-admin/web/.../streamVisitor.ts:113-128` | 已解析 `reasoning-start`/`reasoning-delta`/`reasoning-end` 事件 | ✅ 已实现 |
| `apps/web-admin/web/.../CustomAgentModelProvider.ts:486-494` | 已将 reasoning 转为 `collapsible-text` 类型的 uiContent | ✅ 已实现 |
| `apps/web-admin/web/.../TinyRobotChat.vue:468-493` | `contentRenderer` 只注册了 `markdown`、`schema-card`、`image` 三种渲染器 | ❌ **缺少 `collapsible-text` 渲染器** |

**关键结论**：思维链数据链路已通（runtime 端传递 reasoning → web 端 streamVisitor 解析 → CustomAgentModelProvider 转为 collapsible-text），但 `contentRenderer` 未注册 `collapsible-text` 渲染器，导致思维链内容无法显示。

### 4.2 修复方案

**改动点 1**：新建 `apps/web-admin/web/.../BubbleThinkingRenderer.vue` — 思维链折叠显示控件

创建可折叠的"思考过程"显示控件：
- 默认折叠状态，用户点击可展开查看完整思维链
- 思维链内容支持纯文本显示
- 样式与聊天气泡一致

**改动点 2**：修改 `apps/web-admin/web/.../TinyRobotChat.vue` — 注册 `collapsible-text` 渲染器

```typescript
import BubbleThinkingRenderer from './BubbleThinkingRenderer.vue'

const contentRenderer = {
  markdown: new BubbleMarkdownContentRenderer({ mdConfig: { html: true } }),
  'schema-card': ...,
  image: BubbleImageRenderer,
  // 思维链折叠渲染器：展示 agent 的 reasoning_content（思考过程）
  'collapsible-text': (thinkingProps: any) =>
    h(BubbleThinkingRenderer, {
      content: thinkingProps.content || '',
      title: thinkingProps.title || '思考过程'
    })
}
```

---

## 五、OPT-V2-4：web 端对接取消聊天按钮（P0）

### 5.1 问题根因（代码验证）

| 位置 | 现状 | 问题 |
|------|------|------|
| `src/app/controllers/uctoo/ws/WsChatController.cj:557-568` | 已实现 `_handleCancelMessage`，调用 `WebSocketSessionManager.instance.cancelAgent` | ✅ runtime 端已实现 |
| `src/app/services/bridge/websocket_session_manager.cj` | 已实现 `cancelAgent`、`isCancelled`、`clearCancelFlag` | ✅ runtime 端已实现 |
| `apps/web-admin/web/.../TinyRobotChat.vue:87` | `tr-sender` 的 `@cancel="abortRequest"` 仅前端本地中止 HTTP 流 | ❌ **未发送 `cancel` 消息到后端** |

**关键结论**：runtime 端取消功能已完整实现，但 web 端 `abortRequest`（来自 `messageManager`）仅前端本地中止 HTTP/SSE 流，未通过 WebSocket 发送 `cancel` 消息到后端，导致 agent 继续执行。

### 5.2 修复方案

**改动点 1**：新建 `apps/web-admin/web/src/mcp-servers/chat/cancel.ts` — 聊天取消信号发送模块

```typescript
import { sendMessage } from './tools'

/**
 * 发送取消信号到后端
 * 后端 WsChatController._handleCancelMessage 接收后调用 WebSocketSessionManager.cancelAgent
 */
export async function cancelChat(): Promise<void> {
  try {
    await sendMessage('cancel', {})
  } catch (err) {
    // WebSocket 未连接或发送失败时静默降级，仅依赖前端本地中止
    console.warn('[cancelChat] 发送取消信号失败，降级为前端本地中止:', err)
  }
}
```

**改动点 2**：修改 `apps/web-admin/web/.../useTinyRobotChat.ts` — 包装 `abortRequest`

```typescript
import { cancelChat } from '@/mcp-servers/chat/cancel'

const { messageState, inputMessage, sendMessage, abortRequest: _abortRequest, messages, addMessage, send } = messageManager

/**
 * 包装 abortRequest：取消时同时通过 WebSocket 发送 cancel 消息到后端，
 * 让 runtime 确定性终止 agent 执行（触发 AgentCancelException）。
 */
const abortRequest = () => {
  // 1. 异步发送 cancel 信号到后端（不阻塞前端本地中止）
  cancelChat().catch(() => {})
  // 2. 前端本地中止 HTTP/SSE 流
  _abortRequest()
}
```

---

## 六、OPT-V2-5：清理调度器孤儿任务循环（P1）

### 6.1 问题根因（代码验证）

| 位置 | 现状 | 问题 |
|------|------|------|
| `src/app/services/crontab/SchedulerEngine.cj:279-281` | `triggerTask` 的 `case None` 分支仅报错 `LogUtils.error("SchedulerEngine", "任务不存在: ${crontabId}")` | 未从 ticktock 调度器移除孤儿任务，导致每分钟重复报错 |

### 6.2 修复方案

**改动点 1**：`src/app/services/crontab/SchedulerEngine.cj` — 孤儿任务自动清理

在 `triggerTask` 的 `case None` 分支中，从 ticktock 调度器移除孤儿任务，并降级为 WARN 级别日志：

```cangjie
case None =>
    // 孤儿任务：数据库中已不存在，从调度器移除避免重复报错
    match (ticktock) {
        case Some(tk) =>
            tk.removeTask("crontab:${crontabId}")
            LogUtils.warn("SchedulerEngine", "移除孤儿任务（数据库中不存在）: ${crontabId}")
        case None => ()
    }
```

---

## 七、OPT-V2-6：日志噪声治理（P2）

### 7.1 问题根因（代码验证）

| 日志类型 | 来源 | 问题 |
|---------|------|------|
| `clientPubKey` 相关 | `libs/jinguissl_core/src/jinguissl_core/crypto/tls/tls12.cj:412-415` | TLS 握手调试 println 污染日志 |
| `Middleware N returned` | `src/app/core/middleware/Middleware.cj:38` | 每个中间件执行后都打印 DEBUG 日志 |
| `executeRecursive: index=N` | `src/app/core/middleware/Middleware.cj:27` | 递归执行时打印 DEBUG 日志 |
| `MiddlewareChain.execute: N middlewares` | `src/app/core/middleware/Middleware.cj:22` | 每次请求都打印中间件数量 |

### 7.2 修复方案

**改动点 1**：`libs/jinguissl_core/src/jinguissl_core/crypto/tls/tls12.cj` — 移除 `clientPubKey` 等调试 println

移除以下 4 行 println：
- `println("[TLS12-PRF] serverScalar ...")`
- `println("[TLS12-PRF] clientPubKey.x ...")`
- `println("[TLS12-PRF] clientPubKey.y ...")`
- `println("[TLS12-PRF] premasterSecret ...")`

**改动点 2**：`src/app/core/middleware/Middleware.cj` — 清理 Middleware 调试日志

移除 `MiddlewareChain.execute`、`executeRecursive`、`Calling middleware`、`Middleware returned` 等调试日志，简化为仅执行中间件链。

---

## 八、v2 实施优先级与路线图

### Phase 1：P0 阻断修复（立即）

| 序号 | 任务 | 预期效果 |
|------|------|---------|
| 1 | OPT-V2-1 修复 ReAct 工具调用解析格式 | Agent 能成功调用工具，不再报 "There is NO JSON output" |
| 2 | OPT-V2-2 修复 http_request 流式响应处理 | 行情抓取不再报 chunk terminator 错误，给出可操作的替代建议 |
| 3 | OPT-V2-3 web 端集成思维链显示控件 | 用户看到 agent 思考过程（折叠控件，默认折叠，点击展开） |
| 4 | OPT-V2-4 web 端对接取消聊天按钮 | 取消按钮能发送 cancel 消息到后端，agent 确定性终止 |

### Phase 2：P1 严重修复（高优先级）

| 序号 | 任务 | 预期效果 |
|------|------|---------|
| 5 | OPT-V2-5 清理调度器孤儿任务循环 | 消除每分钟重复"任务不存在"错误 |

### Phase 3：P2 低优先级修复（择机）

| 序号 | 任务 | 预期效果 |
|------|------|---------|
| 6 | OPT-V2-6 日志噪声治理 | 日志中 `clientPubKey`、`Middleware returned`、`executeRecursive` 噪声显著减少 |

---

## 九、v2 验证检查清单

修复完成后，请人工在单独 cmd 环境编译仓颉代码并运行 runtime，验证以下清单：

- [ ] Agent 输出的工具调用 JSON 能被 `TagStreamParser` 正确解析（不再报 "There is NO JSON output"）
- [ ] Agent 能成功调用 `http_request` 工具获取行情数据
- [ ] Agent 能调用 `get_skill_content` 工具获取技能完整内容
- [ ] web 端聊天界面显示 agent 思考过程（折叠控件，默认折叠，点击展开）
- [ ] web 端取消按钮能发送 `cancel` 消息到后端，agent 确定性终止
- [ ] 调度器不再每分钟重复 "任务不存在" 错误
- [ ] 日志中 `clientPubKey`、`Middleware returned`、`executeRecursive` 噪声显著减少
- [ ] 投研任务能完整执行六步 SOP：抓取 → 清洗 → 提取 → 生成 → 落库 → 简报

---

## 十、v2 涉及文件清单

### 10.1 新增文件（3 个）

| 文件 | 用途 |
|------|------|
| `.codeartsdoer/specs/fintech-agent-hackathon/optimization-plan-v2.md` | v2 完整优化方案文档 |
| `apps/web-admin/web/.../BubbleThinkingRenderer.vue` | 思维链折叠显示控件 |
| `apps/web-admin/web/src/mcp-servers/chat/cancel.ts` | 聊天取消信号发送模块 |

### 10.2 修改文件（runtime 仓颉，7 个）

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `src/parser/parser_utils.cj` | OPT-V2-1 | 修改：修复 `extractFirstJsonWithHeuristic` 的字符串状态跟踪 bug |
| `src/app/services/webmcp/WebMCPProtocol.cj` | OPT-V2-1 | 修改：`buildAgentSystemPrompt` 增加工具调用格式说明 |
| `src/app/controllers/uctoo/ws/WsChatController.cj` | OPT-V2-1 | 修改：同步优化系统提示 |
| `src/app/services/crontab/SchedulerEngine.cj` | OPT-V2-5 | 修改：孤儿任务自动清理 |
| `src/app/core/middleware/Middleware.cj` | OPT-V2-6 | 修改：清理 Middleware 调试日志 |
| `libs/jinguissl_core/src/jinguissl_core/crypto/tls/tls12.cj` | OPT-V2-6 | 修改：清理 `clientPubKey` 等调试 println |
| `src/tool/http_tool.cj` | OPT-V2-2 | 修改：增强 chunk terminator 错误处理 |

### 10.3 修改文件（web 前端，2 个）

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `apps/web-admin/web/.../useTinyRobotChat.ts` | OPT-V2-4 | 修改：包装 `abortRequest` 发送 cancel 消息 |
| `apps/web-admin/web/.../TinyRobotChat.vue` | OPT-V2-3 | 修改：导入 `BubbleThinkingRenderer`，注册 `collapsible-text` 渲染器 |

---

## 附录：v1 与 v2 实施差异说明

| 维度 | v1 实施 | v2 实施 |
|------|---------|---------|
| **核心目标** | 实现 `get_skill_content` 内置工具 + 系统提示注入完整 instructions | 修复 ReAct 解析器 bug + web 端集成思维链显示控件和取消按钮对接 |
| **runtime 端改动** | 新建 `get_skill_content_tool.cj`、修改 `WebMCPProtocol.cj`/`WsChatController.cj` 等 | 修复 `parser_utils.cj` 解析 bug、增强 `http_tool.cj` 错误处理、清理孤儿任务和日志噪声 |
| **web 端改动** | 无（v1 仅改 runtime 端） | 新建 `BubbleThinkingRenderer.vue`/`cancel.ts`、修改 `TinyRobotChat.vue`/`useTinyRobotChat.ts` |
| **失败根因** | v1 认为是 `get_skill_content` 工具未注册导致 agent 无法获取技能内容 | v2 复核发现 v1 已正确落地，但 **agent 工具调用格式问题**（嵌套转义 JSON 解析失败）是最新失败的真正阻断点 |
| **与 v1 的关系** | v1 是基础能力建设 | v2 是 v1 的迭代完善，**不重复 v1 已正确落地的改动**，仅针对 v1 未覆盖的 web 端集成和解析器 bug 进行精准修复 |

**关键结论**：v1 和 v2 是互补关系，不是替代关系。v1 建设了 runtime 端的基础能力（`get_skill_content` 工具、系统提示注入、思维链传递、cancel 消息处理），v2 修复了 v1 遗留的解析器 bug 和 web 端集成缺失。两者结合才能让投研任务完整执行六步 SOP。

---

# 第三轮优化实施方案（v3）

> **文档定位**：在 v2 优化落地后，针对 2026-08-10 14:32~14:38 最新一次运行复核，发现 v2 已正确落地（agent 能成功调用工具，不再报 JSON 解析错误），但 **工具执行环境故障**（cli_execute 在 Windows 下找不到任何命令、directory_list 返回空）和 **web 端思维链 loading 卡死**是最新失败的真正阻断点。本方案针对这些根因制定迭代修复方案。
>
> **核心原则**：沿用原有设计架构进行增量优化，复用现有基础设施。针对 v2 未覆盖的 Windows 命令执行环境、中文网页编码、web 端思维链流式显示进行精准修复。
>
> **日期**：2026-08-10 | **基于代码实际分析** | **覆盖用户提出的 2 个必须优化点**

---

## 一、v3 方案总览

| 编号 | 优化项 | 对应用户需求 | 涉及文件数 | 优先级 | 方案策略 |
|------|--------|------------|-----------|--------|---------|
| OPT-V3-1 | 修复 cli_execute Windows 命令执行 | 2.1 工具环境故障 | 1 | P0 | Windows 下通过 `cmd.exe /c` 包装命令执行 |
| OPT-V3-2 | 修复 directory_list 路径解析 | 2.1 技能目录找不到 | 1 | P0 | 修复 Windows 反斜杠路径解析，放宽工作目录限制 |
| OPT-V3-3 | 修复 web_fetch 中文网页编码 | 2.1 财经新闻抓取失败 | 1 | P0 | 支持自动检测和多种编码解码（UTF-8、GBK、GB2312） |
| OPT-V3-4 | 修复 web 端思维链 loading 卡死 | 1 思维链显示 | 2~3 | P0 | 确认 SSE 流推送 reasoning + 优化 loading 状态管理 |
| OPT-V3-5 | 集成国产搜索技能 | 2.2 国产搜索工具 | 2 | P1 | 新建 web-search-assistant 技能，封装百度/搜狗搜索 |
| OPT-V3-6 | 增强行情抓取脚本稳定性 | 2.1 行情接口不稳定 | 1 | P1 | scripts/fetch_market_data.py 增加重试和备用源 |

---

## 二、OPT-V3-1：修复 cli_execute Windows 命令执行（P0 核心）

### 2.1 问题根因（日志证据）

日志 4268、4272、4531、4547 行显示：
```
agent 调用 cli_execute 执行 "dir /s /b SKILL.md"
→ observation: {"success": false, "exit_code": -1, "stderr": "Command execution failed: Created process failed, errMessage: \"The system cannot find the file specified.\".. Please ensure 'dir' is installed and available in PATH."}

agent 调用 cli_execute 执行 "where python"
→ observation: {"success": false, "exit_code": -1, "stderr": "Command execution failed: . Please ensure 'where' is installed and available in PATH.", "duration_ms": 10092}
```

agent 尝试了 `dir`、`echo`、`where`、`python` 等命令，**全部报 "The system cannot find the file specified"**。

### 2.2 根因分析

仓颉的 `Process` API 在 Windows 下启动子进程时，**不会自动通过 PATH 环境变量解析命令**。需要传入命令的**完整绝对路径**，或者通过 `cmd.exe /c <command>` 包装执行。

当前 `cli_execute` 工具（`CliTool`）的实现可能是：
1. 直接调用 `Process(command, args)` — 在 Windows 下找不到 `dir`、`where` 等内置命令
2. 未通过 `cmd.exe /c` 或 `powershell -Command` 包装

**关键结论**：这不是工具本身的 bug，而是**仓颉 Process API 在 Windows 下的 PATH 解析问题**。需要修改 `CliTool` 的实现，在 Windows 下通过 `cmd.exe /c <command>` 或 `powershell -Command <command>` 包装执行。

### 2.3 修复方案

**改动点**：`src/tool/cli_tool.cj` — Windows 下通过 `cmd.exe /c` 包装命令

```cangjie
// 伪代码
let actualCommand = if (System.os == "windows") {
    "cmd.exe"
} else {
    command
}
let actualArgs = if (System.os == "windows") {
    ["/c", command, ...args]
} else {
    args
}
Process(actualCommand, actualArgs)
```

**替代方案**：集成一个 `bash` 或 `powershell` 内置工具，专门用于执行 shell 命令。考虑到项目运行在 Windows 环境，建议同时支持：
- `cli_execute`：通用命令执行（Windows 下自动通过 cmd.exe 包装）
- `powershell_execute`：Windows 原生 PowerShell 命令执行
- `bash_execute`：Git Bash 环境命令执行（如果检测到 Git Bash 安装）

---

## 三、OPT-V3-2：修复 directory_list 路径解析（P0）

### 3.1 问题根因（日志证据）

日志显示 agent 调用 `directory_list` 查找以下路径，**全部返回空列表**：
- `skills`（相对路径）
- `D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\skills`
- `D:\UCT`
- `.`（当前目录）

### 3.2 根因分析

`directory_list` 工具（`DirectoryListTool`）的实现可能：
1. 工作目录限制 — 仅允许访问特定目录白名单
2. 路径解析问题 — Windows 反斜杠路径解析失败
3. 工具内部抛出异常但被静默捕获，返回空列表

**关键结论**：agent 无法定位技能目录，因此无法找到 `scripts/*.py` 脚本。需要检查 `DirectoryListTool` 的实现，确认是否有工作目录限制，并修复路径解析问题。

### 3.3 修复方案

**改动点**：`src/tool/directory_list_tool.cj` — 修复 Windows 路径解析

1. 检查是否有工作目录白名单限制，如有则放宽至允许访问项目根目录和技能目录
2. 修复 Windows 反斜杠路径解析问题（确保仓颉的 `Path` 或 `File` API 能正确处理 `D:\UCT\...` 格式）
3. 工具内部异常时返回明确的错误信息，而非静默返回空列表

---

## 四、OPT-V3-3：修复 web_fetch 中文网页编码（P0）

### 4.1 问题根因（日志证据）

agent 调用 `web_fetch` 抓取新浪公司页（`finance.sina.com.cn/realstock/company/sh600519/nc.shtml`）时报错：
```
Invalid utf8 byte sequence
Invalid unicode scalar value
```

### 4.2 根因分析

`web_fetch` 工具（`WebFetchTool`）的实现可能：
1. 强制按 UTF-8 解码响应体 — 中文网页常用 GBK/GB2312 编码
2. 未检测响应头中的 `Content-Type: charset=gbk`
3. 解码失败时直接抛出异常，而非降级为替换字符

**关键结论**：需要修改 `WebFetchTool` 的实现，支持自动检测和多种编码解码（UTF-8、GBK、GB2312）。

### 4.3 修复方案

**改动点**：`src/tool/web_fetch_tool.cj` — 支持多种编码自动检测

```cangjie
// 伪代码
let contentType = response.headers.get("Content-Type")
let charset = detectCharset(contentType, responseBodyBytes)
let decodedString = match (charset) {
    case "utf-8" => String.fromUtf8(responseBodyBytes)
    case "gbk" => String.fromGbk(responseBodyBytes)
    case "gb2312" => String.fromGb2312(responseBodyBytes)
    case _ => String.fromUtf8(responseBodyBytes, errors: "replace")  // 降级为替换字符
}
```

如果仓颉标准库不支持 GBK 解码，需要实现一个 GBK 解码器，或通过 `cli_execute` 调用 `iconv` 或 Python 脚本进行编码转换。

---

## 五、OPT-V3-4：修复 web 端思维链 loading 卡死（P0）

### 5.1 问题根因（日志证据）

- 日志 4307、4308 行显示 `WebSocketEventBridge` 缓冲了 `chat_model_end` 事件，包含 `reasoning` 字段
- 但 web 端用户长时间看到 loading 旋转动画，思维链未显示
- 最终 agent 返回失败报告后，loading 才消失

### 5.2 根因分析

web 端通过 `CustomAgentModelProvider.chatStream` 调用 `agent.chatStream`，走的是 AI SDK 流式接口（HTTP/SSE），而非 WebSocket 事件。

**关键结论**：v2 修复的 `BubbleThinkingRenderer.vue` 和 `collapsible-text` 渲染器是正确的，但 web 端**没有收到思维链数据**，因为：
1. web 端通过 `CustomAgentModelProvider.chatStream` 调用 `agent.chatStream`，走的是 AI SDK 流式接口
2. runtime 端 `CustomAgentModelProvider` 对应的是 `WebMCPController` 的 SSE 流，而非 WebSocket
3. **SSE 流中可能没有包含 reasoning 事件**，或者 web 端 `StreamVisitor` 没有正确解析 runtime 返回的 reasoning 数据

### 5.3 修复方案

**改动点 1**：检查 `WebMCPController.cj` 的 SSE 流实现，确认是否推送 reasoning 事件

如果 SSE 流只推送最终结果，不推送中间思维链，需要增加 reasoning-delta 事件推送。

**改动点 2**：参考 `tiny-robot-skill` 和 `tiny-vue-skill` 技能，确认思维链显示的正确集成方式

需要查阅 `tiny-robot-skill` 确认：
- `StreamVisitor` 如何解析 reasoning 事件
- `tr-bubble-list` 如何渲染 `collapsible-text` 类型的 uiContent
- loading 状态如何正确管理（避免卡死）

**改动点 3**：优化 loading 状态管理

当前 web 端可能只在收到最终响应时才更新 loading 状态。需要改为：
- 收到第一个 reasoning/text delta 时就更新 loading 为"思考中"
- 收到 tool call 时更新为"执行工具中"
- 收到最终 answer 时更新为"完成"

---

## 六、OPT-V3-5：集成国产搜索技能（P1）

### 6.1 问题根因

agent 在日志中尝试抓取多个财经新闻网页，但全部因编码错误或网络问题失败。agent 没有可用的国产搜索工具来获取公司新闻、公告等公开信息。

### 6.2 修复方案

集成一个国产搜索技能到 `skills` 目录，帮助 agent 获取投研信息。

**新建**：`skills/web-search-assistant/SKILL.md` + `skills/web-search-assistant/scripts/search.py`

技能设计：
- **name**: web-search-assistant
- **description**: 国产网页搜索助理，封装百度/搜狗等国产搜索引擎，获取公开网页信息（公司新闻、公告、行业动态等）
- **scripts/search.py**: 使用 `requests` + `BeautifulSoup` 抓取百度搜索结果，解析标题、摘要、URL
- **使用方式**: agent 通过 `python_execute` 工具运行 `search.py --query "贵州茅台 最新新闻"`，获取结构化搜索结果

脚本设计要点：
1. 使用国产搜索引擎（百度、搜狗），合规抓取
2. 设置正确的 User-Agent 和 Referer，避免被反爬
3. 返回结构化 JSON（标题、摘要、URL、来源、时间）
4. 支持多关键词并行搜索
5. 内置重试机制和错误降级

---

## 七、OPT-V3-6：增强行情抓取脚本稳定性（P1）

### 7.1 问题根因（日志证据）

- 新浪行情接口（`hq.sinajs.cn`）返回空响应
- 腾讯行情接口（`qt.gtimg.cn`）报 `invalid chunk terminator`
- 东方财富接口（`push2.eastmoney.com`）第一个请求返回 `rc:102, data:null`，其余请求报 `connection closed by server`

### 7.2 修复方案

**改动点**：`skills/investment-research-assistant/scripts/fetch_market_data.py` — 增强稳定性

1. 增加正确的 Referer 和 User-Agent 头
2. 增加重试机制（3 次，间隔 1 秒）
3. 增加备用数据源（如果主源失败，自动切换到备用源）
4. 增加响应解析容错（如果 JSON 解析失败，尝试文本解析）
5. 增加超时处理（单请求 15 秒，总体 60 秒）

---

## 八、v3 实施优先级与路线图

### Phase 1：P0 阻断修复（立即）

| 序号 | 任务 | 预期效果 |
|------|------|---------|
| 1 | OPT-V3-1 修复 cli_execute Windows 命令执行 | agent 能执行 dir、echo、where、python 等命令 |
| 2 | OPT-V3-2 修复 directory_list 路径解析 | agent 能定位到 skills 目录和 scripts 脚本 |
| 3 | OPT-V3-3 修复 web_fetch 中文网页编码 | agent 能抓取新浪财经等中文网页 |
| 4 | OPT-V3-4 修复 web 端思维链 loading 卡死 | 用户看到 agent 思考过程，不再卡在 loading 动画 |

### Phase 2：P1 严重修复（高优先级）

| 序号 | 任务 | 预期效果 |
|------|------|---------|
| 5 | OPT-V3-5 集成国产搜索技能 | agent 能通过国产搜索引擎获取公司新闻、公告等 |
| 6 | OPT-V3-6 增强行情抓取脚本稳定性 | 行情数据抓取成功率提升 |

---

## 九、v3 验证检查清单

修复完成后，请人工在单独 cmd 环境编译仓颉代码并运行 runtime，验证以下清单：

- [ ] `cli_execute` 能在 Windows 下执行 `dir`、`echo`、`where`、`python` 等命令
- [ ] `directory_list` 能正确列出 `skills` 目录下的文件和子目录
- [ ] `web_fetch` 能正确抓取中文网页（新浪财经等），不再报编码错误
- [ ] web 端聊天界面显示 agent 思考过程（不再卡在 loading 动画）
- [ ] web 端 loading 状态正确管理（收到首个 delta 时更新为"思考中"）
- [ ] agent 能定位到 `skills/investment-research-assistant/scripts/*.py` 脚本
- [ ] agent 能通过 `cli_execute` 或 `python_execute` 运行 scripts 脚本
- [ ] agent 能通过国产搜索技能获取公司新闻、公告等信息
- [ ] 投研任务能完整执行六步 SOP：抓取 → 清洗 → 提取 → 生成 → 落库 → 简报

---

## 十、v3 涉及文件清单

### 10.1 修改文件（runtime 仓颉）

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `src/tool/cli_tool.cj` | OPT-V3-1 | 修改：Windows 下通过 `cmd.exe /c` 包装命令执行 |
| `src/tool/directory_list_tool.cj` | OPT-V3-2 | 修改：修复 Windows 路径解析，放宽工作目录限制 |
| `src/tool/web_fetch_tool.cj` | OPT-V3-3 | 修改：支持自动检测和多种编码解码 |
| `src/app/controllers/uctoo/webmcp/WebMCPController.cj` | OPT-V3-4 | 修改：SSE 流推送 reasoning 事件 |
| `skills/investment-research-assistant/scripts/fetch_market_data.py` | OPT-V3-6 | 修改：增强行情接口稳定性 |

### 10.2 新增文件

| 文件 | 用途 |
|------|------|
| `skills/web-search-assistant/SKILL.md` | 国产搜索技能定义 |
| `skills/web-search-assistant/scripts/search.py` | 百度/搜狗搜索脚本实现 |

### 10.3 修改文件（web 前端）

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `apps/web-admin/web/.../CustomAgentModelProvider.ts` | OPT-V3-4 | 修改：确认 reasoning 事件正确解析和传递 |
| `apps/web-admin/web/.../useTinyRobotChat.ts` 或相关 composable | OPT-V3-4 | 修改：优化 loading 状态管理，避免卡死 |

---

## 附录：v1、v2、v3 实施差异说明

| 维度 | v1 实施 | v2 实施 | v3 实施 |
|------|---------|---------|---------|
| **核心目标** | 实现 `get_skill_content` 内置工具 + 系统提示注入完整 instructions | 修复 ReAct 解析器 bug + web 端集成思维链显示控件和取消按钮对接 | 修复 Windows 命令执行环境 + 中文网页编码 + web 端思维链流式显示 |
| **runtime 端改动** | 新建 `get_skill_content_tool.cj`、修改 `WebMCPProtocol.cj`/`WsChatController.cj` 等 | 修复 `parser_utils.cj` 解析 bug、增强 `http_tool.cj` 错误处理、清理孤儿任务和日志噪声 | 修复 `cli_tool.cj` Windows 命令执行、`directory_list_tool.cj` 路径解析、`web_fetch_tool.cj` 编码处理 |
| **web 端改动** | 无 | 新建 `BubbleThinkingRenderer.vue`/`cancel.ts`、修改 `TinyRobotChat.vue`/`useTinyRobotChat.ts` | 优化 `CustomAgentModelProvider.ts` reasoning 解析、优化 loading 状态管理 |
| **失败根因** | v1 认为是 `get_skill_content` 工具未注册导致 agent 无法获取技能内容 | v2 复核发现 v1 已正确落地，但 **agent 工具调用格式问题**（嵌套转义 JSON 解析失败）是最新失败的真正阻断点 | v3 复核发现 v2 已正确落地，但 **工具执行环境故障**（cli_execute 在 Windows 下找不到任何命令、directory_list 返回空）和 **web 端思维链 loading 卡死**是最新失败的真正阻断点 |
| **与前一轮的关系** | v1 是基础能力建设 | v2 是 v1 的迭代完善，修复 v1 遗留的解析器 bug 和 web 端集成缺失 | v3 是 v2 的迭代完善，修复 v2 未覆盖的 Windows 命令执行环境、中文网页编码、web 端思维链流式显示 |

**关键结论**：v1、v2、v3 是互补的迭代完善关系，不是替代关系。每一轮都基于前一轮已正确落地的能力进行增量修复，不重复已正确落地的改动。三轮结合才能让投研任务完整执行六步 SOP。

---

# 第四轮优化实施方案（v4）

> **文档定位**：在 v3 优化部分落地（directory_list 已生效、runtime 端 reasoning 已传递）后，针对 2026-08-10 19:35~19:50 最新一次运行复核，发现 **v3 的 cli_tool 修复未编译生效**（日志无任何 `[CliTool]` 输出）、**系统提示错误注入了技能完整内容**（违反渐进式加载）、**file_read 读脚本返回空**、**web 端思维链前三轮均未真正落地**（用户明确反馈"web 端聊天组件没有看到任何变化"）是最新失败的真正阻断点。
>
> **核心原则**：沿用原有设计架构进行增量优化，严格遵循 agentskills 开放标准的三段渐进式加载；web 端思维链显示必须查阅 tiny-robot-skill/tiny-vue-skill 技能后正确集成，不再凭猜测修改。
>
> **日期**：2026-08-10 | **基于代码实际分析** | **覆盖用户提出的 2 个必须优化点**

---

## 一、v4 方案总览

| 编号 | 优化项 | 对应用户需求 | 涉及文件数 | 优先级 | 方案策略 |
|------|--------|------------|-----------|--------|---------|
| OPT-V4-1 | skills 三段渐进式加载 | 2.1 系统提示错误注入完整内容 | 2~3 | P0 | `buildAgentSystemPrompt` 仅注入 frontmatter + get_skill_content 工具说明，正文按需加载 |
| OPT-V4-2 | file_read 路径解析修复 | 2.1 读脚本返回空 | 1 | P0 | `FileReadTool` 复用 `normalizePath` + 增加错误诊断日志 |
| OPT-V4-3 | 系统提示引导 agent 使用执行类工具 | 2.1 agent 未调用 cli_execute | 1~2 | P0 | 工具说明中明确引导 cli_execute/python_execute 执行 scripts 脚本 |
| OPT-V4-4 | web 端思维链正确集成 | 1 loading 卡死（前三轮未落地） | 3~5 | P0 | 查阅 tiny-robot-skill/tiny-vue-skill 技能，确认正确集成方式后实施 |
| OPT-V4-5 | 增强搜索脚本反爬策略 | 2.2 搜索抓取失败 | 1 | P1 | search.py 增强浏览器请求头、重试、编码 fallback |

---

## 二、OPT-V4-1：skills 三段渐进式加载（P0 核心）

### 2.1 问题根因（日志证据）

agent 在日志中回复："我已经有了投资研报技能的完整说明（在系统提示中已包含）"——说明系统提示中**已注入了技能的完整内容**（frontmatter + 正文 instructions），而非仅 frontmatter。

用户明确指出："请复核一下之前的修复是不是将 skills 的全部内容加载到了系统提示词，这是不正确的。应该按照 agentskills 开放标准的定义，分成 3 段渐进式加载。"

### 2.2 根因分析

当前 `buildAgentSystemPrompt()`（`WebMCPProtocol.cj` 和 `WsChatController.cj`）的实现是把 `skill.instructions`（技能正文）直接拼接到系统提示中。这违反了 agentskills 开放标准的渐进式加载原则：

**agentskills 开放标准的三段渐进式加载**（参考 `apps/agentskills` 目录）：
1. **第 1 段（frontmatter）**：技能元数据（name、description、version、metadata 等），默认注入系统提示。让 agent 知道有哪些技能可用、各自用途，**不包含正文实现细节**。
2. **第 2 段（工具说明）**：`get_skill_content` 工具的使用说明，告知 agent 如何通过工具调用读取技能完整内容。默认注入系统提示。
3. **第 3 段（完整内容）**：技能正文（instructions、scripts 接口等），**仅当 agent 显式调用 `get_skill_content` 工具时才返回**，不默认注入系统提示。

**关键结论**：当前实现把第 3 段直接注入了系统提示，导致：
- token 浪费（所有技能正文都进系统提示，即使 agent 不需要）
- agent 误以为已掌握全部内容，**不调用 `get_skill_content` 工具**（日志显示 agent 全程未调用该工具）
- 违反渐进式加载原则，agent 无法按需加载

### 2.3 修复方案

**改动点 1**：`src/app/services/webmcp/WebMCPProtocol.cj` `buildAgentSystemPrompt()` — 仅注入 frontmatter + 工具说明

```cangjie
private func buildAgentSystemPrompt(): String {
    let skillInfoBuilder = StringBuilder()
    skillInfoBuilder.append("你是一个智能助手，可以帮助用户完成各种任务。\n\n")

    // 第 1 段：仅注入所有技能的 frontmatter（元数据），不注入正文
    skillInfoBuilder.append("【可用技能】\n")
    for (skill in skillManager.availableSkills()) {
        skillInfoBuilder.append("- ${skill.name}: ${skill.description}\n")
        // 仅 frontmatter，不含 instructions 正文
    }
    skillInfoBuilder.append("\n")

    // 第 2 段：get_skill_content 工具使用说明
    skillInfoBuilder.append("【技能内容获取】\n")
    skillInfoBuilder.append("当你需要使用某个技能时，请调用 get_skill_content 工具获取技能的完整内容（包括 SOP、脚本接口等）。\n")
    skillInfoBuilder.append("调用方式：get_skill_content({\"name\": \"技能名称\"})\n")
    skillInfoBuilder.append("建议在开始执行技能相关任务前，先调用该工具获取完整说明。\n\n")

    // 工具调用格式说明（保留 v2 的修复）
    skillInfoBuilder.append("【工具调用格式说明（严格遵守）】\n")
    // ... 保留 v2 的格式说明
}
```

**改动点 2**：`src/app/controllers/uctoo/ws/WsChatController.cj` `_buildAgentSystemPrompt()` — 同步修改

与 `WebMCPProtocol.cj` 保持一致，仅注入 frontmatter + 工具说明。

**改动点 3**：确认 `SkillManager` 是否提供 `availableSkills()` 或类似接口返回仅 frontmatter

检查 `src/skill/skill_manager.cj`，确认有方法返回技能列表的元数据（不含正文）。如无，需要新增该方法。

---

## 三、OPT-V4-2：file_read 路径解析修复（P0）

### 3.1 问题根因（日志证据）

日志 3116 行附近显示 agent 调用 `file_read` 工具读取 `fetch_market_data.py`，返回内容为空（0 行），agent 无法执行数据抓取流程。

### 3.2 根因分析

`file_read` 工具（`FileReadTool`，位于 `src/tool/file_tools.cj`）读取 `fetch_market_data.py` 返回空内容，可能原因：
1. **路径解析问题** — agent 传递的路径可能含过度转义（`D:\\UCT\\...`），与 v3 的 `directory_list` 问题同源
2. **文件不存在** — 但 `directory_list` 已成功列出该文件，所以文件确实存在
3. **权限限制** — `tool_permission.cj` 可能限制了 file_read 的可访问路径
4. **读取异常被静默** — 工具内部抛异常但被捕获返回空字符串

**关键结论**：需要检查 `FileReadTool` 的实现，确认是否有与 `DirectoryListTool` 类似的路径解析问题，并增加错误诊断日志。

### 3.3 修复方案

**改动点**：`src/tool/file_tools.cj` `FileReadTool` — 复用 v3 的 `normalizePath` 修复路径解析

1. 在 `FileReadTool` 的读取方法中，调用 `DirectoryListTool.normalizePath` 规范化路径
2. 路径不存在时返回明确的错误信息，而非空字符串
3. 增加诊断日志：`[FileReadTool] Reading file: ${rawPath}, normalized: ${normalizedPath}, exists: ${exists}`

---

## 四、OPT-V4-3：系统提示引导 agent 使用执行类工具（P0）

### 4.1 问题根因（日志证据）

日志中**完全没有** `[CliTool]`、`Wrapped cmd.exe builtin`、`Wrapped PowerShell`、`resolveWindowsExe` 任何输出，说明：
- agent 全程从未调用 `cli_execute`/`python_execute`/`bash`/`powershell` 工具
- v3 的 `resolveWindowsExe` 修复**未编译生效**（运行的是旧版编译产物）

### 4.2 根因分析

agent 未调用执行类工具的原因有二：
1. **R0-09 的连锁影响** — 系统提示已注入技能完整内容，agent 误以为已掌握全部，未调用 `get_skill_content`，因此也未看到 scripts 脚本的执行说明，自然不会调用 cli_execute
2. **工具描述不够引导** — `cli_execute`/`python_execute` 的工具描述可能未明确告知 agent "可用于执行技能目录下的 scripts 脚本"

### 4.3 修复方案

**改动点 1**：确保 v3 的 `cli_tool.cj` 修复**真正编译生效**

人工在单独 cmd 环境编译仓颉代码，确认 `resolveWindowsExe` 和 `wrapForWindowsShell` 的新代码被编译进产物。

**改动点 2**：在系统提示中明确引导 agent 使用执行类工具

在 `buildAgentSystemPrompt` 的工具说明中增加：
```
【脚本执行】
技能目录下的 scripts/*.py 是 Python 脚本，请通过 cli_execute 或 python_execute 工具执行。
执行示例：cli_execute({"command": "python", "args": ["scripts/fetch_market_data.py", "--query", "..."]})
在 Windows 环境下，cli_execute 会自动通过 cmd.exe /c 包裹命令，支持 dir/echo/where/python 等命令。
```

---

## 五、OPT-V4-4：web 端思维链正确集成（P0）

### 5.1 问题根因（用户明确反馈）

用户明确指出："此需求在前三轮修复都还没有实现 web 端聊天组件没有看到任何变化。目前现象就是用户对话完之后，agent 回复位置长时间显示一个 loading 动画图标。"

### 5.2 根因分析

前三轮对 web 端思维链的修复尝试：
- v2：新建 `BubbleThinkingRenderer.vue` + 注册 `collapsible-text` 渲染器
- v3：`streamVisitor.ts` 兼容 `delta` 字段 + `AgentModelProvider.ts` 显式转发 reasoning 事件

但用户反馈"web 端聊天组件没有看到任何变化"，说明前三轮修复**均未真正生效**。可能原因：

1. **web 端编译/构建未生效** — 修改了 `.vue`/`.ts` 源码但前端未重新构建，用户看到的是旧版前端
2. **数据通道判断错误** — v3 分析认为 web 端走 AI SDK 直连通道（`AgentModelProvider._chatReActStream`），但实际可能走的是 WebMCP 通道（`_chatViaWebMCP`），两个通道的 reasoning 传递链路不同
3. **loading 状态管理缺陷** — 即使 reasoning 数据正确传递，前端可能在收到最终响应前不更新 loading 状态，用户始终看到旋转动画
4. **TinyRobot 组件渲染机制** — `tr-bubble-list` 可能只在收到完整消息后才渲染，中间的 reasoning delta 不触发渲染

**关键结论**：需要查阅 `tiny-robot-skill` 和 `tiny-vue-skill` 技能，确认思维链显示的正确集成方式，而不是凭猜测修改。

### 5.3 修复方案

**改动点 1**：查阅 `tiny-robot-skill` 技能，确认 TinyRobot 聊天 UI 的思维链显示机制

`tiny-robot-skill` 提供了 TinyRobot Vue AI chat UI 的实现指导，包括消息列表、对话工具、流式处理等。需要查阅该技能确认：
- `tr-bubble-list` 如何渲染 `collapsible-text` 类型的 uiContent
- `StreamVisitor` 如何解析 reasoning 事件
- loading 状态如何正确管理（避免卡死）
- 思维链显示的正确集成方式

**改动点 2**：查阅 `tiny-vue-skill` 技能，确认 TinyVue 组件库的正确使用方式

`tiny-vue-skill` 提供 TinyVue 组件库的代码生成和实施指导。需要查阅该技能确认：
- 是否有现成的折叠/展开组件可用于思维链显示
- `t-collapse`/`t-collapse-item` 的正确 API

**改动点 3**：确认 web 端实际使用的数据通道

检查 `CustomAgentModelProvider.chatStream` 实际调用的是 `_chatReActStream`（AI SDK 直连）还是 `_chatViaWebMCP`（WebMCP 通道），不同通道的 reasoning 传递链路不同。

**改动点 4**：优化 loading 状态管理

确保前端在收到首个 reasoning/text delta 时就更新 loading 状态为"思考中"，而非只在收到最终响应时才更新。

---

## 六、OPT-V4-5：增强搜索脚本反爬策略（P1）

### 6.1 问题根因（日志证据）

- 百度搜索抓取返回仅 15 字节，未能获取有效数据
- 搜狗搜索报 `incomplete chunk data`，网络抓取中断

### 6.2 修复方案

**改动点**：`skills/web-search-assistant/scripts/search.py` — 增强反爬策略

1. 增加更完整的浏览器请求头（Accept、Accept-Encoding、Cookie 等）
2. 增加请求间隔（0.5~1 秒），避免触发限流
3. 增加重试机制（3 次，间隔递增）
4. 对搜索结果页编码做 fallback（先尝试 UTF-8，失败则 GBK）

---

## 七、v4 实施优先级与路线图

### Phase 1：P0 阻断修复（立即）

| 序号 | 任务 | 预期效果 |
|------|------|---------|
| 1 | OPT-V4-1 skills 三段渐进式加载 | 系统提示仅含 frontmatter，agent 调用 get_skill_content 获取完整内容 |
| 2 | OPT-V4-2 file_read 路径解析修复 | agent 能读取 scripts/*.py 脚本内容（非空） |
| 3 | OPT-V4-3 系统提示引导使用执行类工具 | agent 调用 cli_execute/python_execute 执行脚本 |
| 4 | OPT-V4-4 web 端思维链正确集成 | 用户看到 agent 思考过程（不再卡在 loading 动画）—— **用户可见的变化** |

### Phase 2：P1 严重修复（高优先级）

| 序号 | 任务 | 预期效果 |
|------|------|---------|
| 5 | OPT-V4-5 增强搜索脚本反爬策略 | 百度/搜狗搜索能获取有效搜索结果 |

---

## 八、v4 验证检查清单

修复完成后，请人工在单独 cmd 环境编译仓颉代码并运行 runtime，验证以下清单：

- [ ] 系统提示仅包含技能 frontmatter（元数据），不含正文 instructions
- [ ] 系统提示包含 `get_skill_content` 工具使用说明，引导 agent 渐进式加载
- [ ] agent 在执行投研任务前，先调用 `get_skill_content` 工具获取技能完整内容
- [ ] `file_read` 能正确读取 `scripts/fetch_market_data.py` 脚本内容（非空）
- [ ] agent 调用 `cli_execute`/`python_execute` 执行 scripts 脚本（日志出现 `[CliTool]` 输出）
- [ ] `cli_execute` 在 Windows 下能执行 `dir`/`echo`/`where`/`python` 命令（日志出现 `Wrapped cmd.exe builtin`）
- [ ] web 端聊天界面显示 agent 思考过程（不再卡在 loading 动画）—— **用户可见的变化**
- [ ] 百度/搜狗搜索能获取有效搜索结果（非 15 字节，非 incomplete chunk）
- [ ] 投研任务能完整执行六步 SOP：抓取 → 清洗 → 提取 → 生成 → 落库 → 简报

---

## 九、v4 涉及文件清单

### 9.1 修改文件（runtime 仓颉）

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `src/app/services/webmcp/WebMCPProtocol.cj` | OPT-V4-1, OPT-V4-3 | 修改：`buildAgentSystemPrompt` 仅注入 frontmatter + 工具说明 + 脚本执行引导 |
| `src/app/controllers/uctoo/ws/WsChatController.cj` | OPT-V4-1, OPT-V4-3 | 修改：`_buildAgentSystemPrompt` 同步改为渐进式加载 |
| `src/tool/file_tools.cj` | OPT-V4-2 | 修改：`FileReadTool` 复用 `normalizePath` + 增加错误诊断日志 |
| `src/skill/skill_manager.cj` | OPT-V4-1 | 修改：确认或新增 `availableSkills()` 方法返回仅 frontmatter |

### 9.2 修改文件（web 前端）

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `apps/web-admin/web/.../TinyRobotChat.vue` 或相关组件 | OPT-V4-4 | 修改：查阅 tiny-robot-skill 后正确集成思维链显示 |
| `apps/web-admin/web/.../CustomAgentModelProvider.ts` | OPT-V4-4 | 修改：确认数据通道，优化 reasoning 传递和 loading 状态管理 |

### 9.3 修改文件（脚本）

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `skills/web-search-assistant/scripts/search.py` | OPT-V4-5 | 修改：增强反爬策略和重试机制 |

---

## 附录：v1、v2、v3、v4 实施差异说明

| 维度 | v1 | v2 | v3 | v4 |
|------|----|----|----|----|
| **核心目标** | get_skill_content 工具 + 系统提示注入完整 instructions | 修复 ReAct 解析器 bug + web 端集成思维链显示控件和取消按钮 | 修复 Windows 命令执行环境 + 中文网页编码 + web 端思维链流式显示 | skills 三段渐进式加载 + file_read 路径解析 + web 端思维链正确集成（查阅技能） |
| **runtime 改动** | 新建 get_skill_content_tool.cj、修改 WebMCPProtocol.cj/WsChatController.cj | 修复 parser_utils.cj 解析 bug、增强 http_tool.cj 错误处理 | 修复 cli_tool.cj Windows 命令执行、directory_list_tool.cj 路径解析 | 修改 buildAgentSystemPrompt 渐进式加载、FileReadTool 路径解析 |
| **web 改动** | 无 | 新建 BubbleThinkingRenderer.vue/cancel.ts、修改 TinyRobotChat.vue | 优化 streamVisitor.ts reasoning 解析、AgentModelProvider.ts 转发 | 查阅 tiny-robot-skill/tiny-vue-skill 后正确集成思维链显示 |
| **失败根因** | get_skill_content 工具未注册 | agent 工具调用格式问题（嵌套转义 JSON 解析失败） | 工具执行环境故障（cli_execute 在 Windows 下找不到任何命令） | 系统提示错误注入技能完整内容 + file_read 读脚本返回空 + web 端思维链前三轮均未真正落地 |
| **与前一轮的关系** | v1 基础能力建设 | v2 修复 v1 遗留的解析器 bug 和 web 端集成缺失 | v3 修复 v2 未覆盖的 Windows 命令执行环境、中文网页编码 | v4 修复 v3 未正确实现的渐进式加载 + web 端思维链真正落地 |

**关键结论**：v1~v4 是互补的迭代完善关系。v4 重点纠正 v1 的"系统提示注入完整 instructions"错误设计，改为 agentskills 开放标准的三段渐进式加载；并真正落地 web 端思维链显示（前三轮均未生效的用户可见变化）。

---

# 第五轮全量优化实施方案（v5）

> **文档定位**：v4 修复正在人工编译/测试期间，本轮基于 v5 全量日志复核报告（report.md 第四十一至五十一节 + 附录 F）制定**超越投研任务链路的基础设施级**修复方案，针对 AsyncLogWriter、SchedulerEngine、TieredMemory、verifyToken、RequestParserService、ChangeDetector、AgentLoader、WebMCPProtocol 等全量报错制定修复方案。本轮**仅写文档**，不修改代码，完成后通知人工审核。
>
> **核心原则**：沿用原有设计架构进行增量优化，每一项修复都基于日志证据，不凭猜测。SQL 参数绑定、连接池、Embedding model 配置等基础设施修复优先级高于次要噪声治理。
>
> **日期**：2026-08-10 | **基于全量日志分析** | **覆盖 17 个问题点（V5-01~V5-17）**

---

## 一、v5 方案总览

| 编号 | 优化项 | 对应报告 | 优先级 | 方案策略 | 涉及文件数 |
|------|--------|---------|--------|---------|-----------|
| OPT-V5-1 | AsyncLogWriter SQL 参数绑定 + 连接池 | V5-07 | P1 高 | 修 SQL 占位符数 = 参数数 + 引入连接池/异步队列 | 2~3 |
| OPT-V5-2 | SchedulerEngine 元数据更新 + cron 合法性 | V5-08, V5-11 | P1 高 | 修 SQL 绑定 + 修正 cron 表达式 + 启动时告警 | 2 |
| OPT-V5-3 | TieredMemory Embedding model 配置 | V5-05, V5-06 | P0 高 | 配置 Embedding model 或降级为关键词检索 | 1~2 |
| OPT-V5-4 | verifyToken 错误信息明确化 | V5-09 | P1 中 | 检查 token 传递 + 返回明确错误 | 1~2 |
| OPT-V5-5 | RequestParserService filter 解析容错 | V5-10 | P1 中 | 完整输出原文 + lenient 解析 | 1 |
| OPT-V5-6 | ChangeDetector identityStatus 默认值 | V5-12 | P1 中 | 提供默认值 + None 容错 | 1 |
| OPT-V5-7 | Parsing action parser 容错增强 | V5-01 | P0 高 | 确认 v2 编译生效 + trim + 最外层 JSON 提取 | 1 |
| OPT-V5-8 | HttpTool/WebFetchTool 错误降级 + 备用源 | V5-02 | P0 高 | 错误降级 + scripts 脚本备用 | 2 |
| OPT-V5-9 | WebMCPProtocol menu context 噪声降级 | V5-13 | P2 低 | 降级为 DEBUG 或启动时一次性告警 | 1 |
| OPT-V5-10 | 技能和 Agent 加载静默跳过 | V5-14, V5-15 | P2 低 | 检查 SKILL.md + 静默跳过不存在目录 | 2 |

---

## 二、OPT-V5-1：AsyncLogWriter SQL 参数绑定 + 连接池（P1，最高频 28 处）

### 2.1 问题根因（日志证据，28 处）

```
ERROR [AsyncLogWriter] 批量写入失败, 重试一次: no value specified for parameter 1, errorCode: 0
ERROR [AsyncLogWriter] 批量写入失败, 重试一次: parameter index 0 out of range [0, 0), errorCode: 0
ERROR [AsyncLogWriter] 批量写入失败, 重试一次: Socket is already writing: concurrent write is not allowed
ERROR [AsyncLogWriter] 批量写入失败, 重试一次: Socket is already reading: concurrent read is not allowed
```

两类根因：
- **SQL 参数绑定错误**：占位符数 ≠ 参数数（parameter index out of range / no value specified）
- **Socket 并发读写**：多线程争用同一数据库连接 Socket，缺少连接池

### 2.2 修复方案

**改动点 1**：逐一核对 AsyncLogWriter 的 SQL 语句与参数数组长度

定位 `src/app/services/log/async_log_writer.cj`（或类似文件），检查每条 SQL 的 `?` 占位符数量与传入参数数组长度是否一致。特别注意：
- `parameter index 0 out of range [0, 0)` → SQL 有 0 个占位符但传了参数，或反之
- `no value specified for parameter 1` → 第 1 个占位符未传值

**改动点 2**：引入数据库连接池或每线程独立连接

仓颉底层 Socket 不允许并发读写，AsyncLogWriter 的异步批量写入会争用连接。方案：
1. 引入连接池（如 HikariCP 集成，或仓颉原生连接池）
2. 或改为**单线程消费的队列模式**：所有日志写入先入队，由单线程消费者顺序写入，避免并发

**改动点 3**：重试机制增强

当前"重试一次"后仍失败应记录完整错误上下文（SQL 语句、参数数组、时间戳），便于定位。

---

## 三、OPT-V5-2：SchedulerEngine 元数据更新 + cron 合法性（P1，12 处 + 1 处）

### 3.1 问题根因（日志证据）

```
ERROR [SchedulerEngine] 更新执行元数据失败: parameter index 22 out of range [0, 22), errorCode: 0
ERROR [SchedulerEngine] 更新执行元数据失败: Socket is already reading: concurrent read is not allowed
ERROR [SchedulerEngine] CRON表达式不合法, 跳过: system-health-check, cron=0 */600 * * * *
```

- `parameter index 22 out of range [0, 22)` → 传了第 23 个参数，但 SQL 只有 22 个占位符
- Socket 并发 → 同 OPT-V5-1
- cron `0 */600 * * * *` → `*/600` 超出分钟字段范围（0-59），且有 6 个字段（标准 CRON 是 5）

### 3.2 修复方案

**改动点 1**：`src/app/services/crontab/SchedulerEngine.cj` — 修 SQL 绑定

定位更新执行元数据的 SQL 语句，核对占位符数与参数数。`parameter index 22 out of range [0, 22)` 说明传了 23 个参数但 SQL 只有 22 个 `?`，需减少一个参数或增加一个占位符。

**改动点 2**：修正 `system-health-check` 的 cron 表达式

将 `0 */600 * * * *` 改为合法表达式：
- 若要每 10 分钟：`0 */10 * * *`（标准 5 字段 CRON）或 `0 */10 * * * *`（秒级 6 字段 CRON，需确认 SchedulerEngine 支持）
- 若要每 600 秒：不支持 CRON，改为用代码定时器

**改动点 3**：SchedulerEngine 启动时校验所有 cron 表达式

在 `start()` 中遍历所有 cron 配置，非法表达式一次性告警，而非每次 tick 报错。

---

## 四、OPT-V5-3：TieredMemory Embedding model 配置（P0，3 处）

### 4.1 问题根因（日志证据）

```
ERROR TieredMemory.search failed: Embedding model is not set
ERROR TieredMemory.update failed: Embedding model is not set
```

TieredMemory 依赖 Embedding 模型将文本转为向量，当前未配置，导致 agent 无法用记忆系统辅助投研（1602、3070 行 search 失败，3099 行 update 失败）。

### 4.2 修复方案

**改动点 1**：在 `.env` 或配置文件中设置 Embedding model

```env
# Embedding model 配置（选其一）
EMBEDDING_MODEL=text-embedding-3-small
EMBEDDING_API_KEY=sk-xxx
EMBEDDING_BASE_URL=https://api.openai.com/v1

# 或国产替代（如百度 embedding）
EMBEDDING_MODEL=baidu-embedding
EMBEDDING_API_KEY=xxx
EMBEDDING_BASE_URL=https://aip.baidubce.com/rpc/2.0/ai_custom/v1/embeddings
```

**改动点 2**：TieredMemory 在 model 未设置时降级

定位 `src/agent/memory/tiered_memory.cj`（或类似），在 Embedding model 未设置时：
1. `search` 降级为基于关键词的检索（或返回空，而非抛异常）
2. `update` 静默跳过（warn 级别，而非 error）
3. 启动时 warn 一次"Embedding model not set, TieredMemory degraded"，不每次操作都 error

---

## 五、OPT-V5-4：verifyToken 错误信息明确化（P1，3 处）

### 5.1 问题根因（日志证据）

```
ERROR verifyToken failed: The token was expected to have 3 parts, but got 1.
```

JWT token 格式应为 `header.payload.signature`（3 段），但收到只有 1 段的字符串。

### 5.2 修复方案

**改动点 1**：检查前端发送 token 的方式

确认前端是否发送完整 JWT，还是纯 ID/裸字符串。特别检查 WebSocket/SSE 通道的 token 传递（可能被截断）。

**改动点 2**：token 格式不合法时返回明确错误

```cangjie
// 伪代码
if (token.split(".").size != 3) {
    return ToolException("Invalid token format: expected 3 parts (header.payload.signature), got ${token.split(".").size}. Please check token is complete JWT.")
}
```

---

## 六、OPT-V5-5：RequestParserService filter 解析容错（P1，2 处）

### 6.1 问题根因（日志证据）

```
ERROR [RequestParserService] Failed to parse filter JSON: the json data is Non-standard, please check:
```

前端传入了"非标准 JSON"的 filter 参数，可能含 NaN/Infinity/未转义字符/双重序列化。

### 6.2 修复方案

**改动点**：`src/app/services/parser/request_parser_service.cj`（或类似）

1. 在报错日志中**完整输出 filter 原文**，便于定位是哪个请求
2. 对非标准 JSON �容错：先严格解析，失败则尝试 lenient 解析（允许 NaN/Infinity/未转义）
3. 前端检查 filter 序列化逻辑，确认无 NaN/未转义字符

---

## 七、OPT-V5-6：ChangeDetector identityStatus 默认值（P1，1 处）

### 7.1 问题根因（日志证据）

```
ERROR ChangeDetector.detectAgentChanges failed: current value for identityStatus must not be None
```

### 7.2 修复方案

**改动点**：`src/agent/change_detector.cj`（或类似）

1. 确认 `identityStatus` 的合法取值（如 `active`/`inactive`/`draft`），提供默认值
2. ChangeDetector 对 None 值容错（使用默认值而非抛异常）

```cangjie
let identityStatus = current.identityStatus ?? "active"  // 默认值
```

---

## 八、OPT-V5-7：Parsing action parser 容错增强（P0，4 处遗留）

### 8.1 问题根因（日志证据）

```
ERROR Parsing action failed: There is NO JSON output in the string: {
```

v2 修复了 `extractFirstJsonWithHeuristic` 的字符串状态跟踪 bug，但仍有 4 处解析失败。

### 8.2 修复方案

**改动点 1**：确认 v2 的 `src/parser/parser_utils.cj` 修复已编译生效

**改动点 2**：在解析失败时完整输出 agent 的原始字符串，便于定位具体变体

**改动点 3**：增强 parser 容错

```cangjie
// 伪代码
let trimmed = raw.trim()
// 先尝试直接解析
if (let Some(json) <- tryParseJson(trimmed)) { return json }
// 再尝试提取最外层 { 到匹配 } 的内容
if (let Some(json) <- extractFirstJsonWithHeuristic(trimmed, ExtractGoal.Object)) { return json }
// 最后尝试正则提取
if (let Some(json) <- extractByRegex(trimmed, r"\{[\s\S]*\}")) { return json }
return None
```

---

## 九、OPT-V5-8：HttpTool/WebFetchTool 错误降级 + 备用源（P0）

### 9.1 问题根因（日志证据）

```
ERROR [HttpTool] Error executing HTTP request: connection closed by server
ERROR [WebFetchTool] Failed to fetch URL: incomplete chunk data
```

### 9.2 修复方案

**改动点 1**：`src/tool/http_tool.cj` — 错误降级

connection closed / incomplete chunk 时返回明确的错误信息 + 备用源建议（已在 v2 修复 chunk terminator，确认编译生效）。

**改动点 2**：`src/tool/web_fetch_tool.cj` — 编码 fallback

incomplete chunk data 可能是编码问题，先尝试 UTF-8，失败则 GBK，再失败则替换字符。

**改动点 3**：scripts 脚本作为备用源

agent 在 http_request/web_fetch 失败时，应通过 cli_execute 调用 scripts 脚本（Python requests 库）抓取数据。

---

## 十、OPT-V5-9：WebMCPProtocol menu context 噪声降级（P2，18 处）

### 10.1 问题根因（日志证据）

```
WARN [WebMCPProtocol] Cannot inject menu context: menuDataProvider or userId not set
```

### 10.2 修复方案

**改动点**：`src/app/services/webmcp/WebMCPProtocol.cj`

1. 将该 WARN 降级为 DEBUG（菜单上下文是可选的）
2. 或在启动时检查 menuDataProvider 配置，一次性告警而非每次请求 WARN

---

## 十一、OPT-V5-10：技能和 Agent 加载静默跳过（P2，5 处）

### 11.1 问题根因（日志证据）

```
ERROR Failed to load skill from: .../skills/cangjie-refactor/SKILL.md
ERROR Failed to load skill from: .../skills/rg_history/SKILL.md
ERROR Failed to load skill from: .../skills/sdd-test/SKILL.md
ERROR [AgentLoader] Path not found: .../src/agents
ERROR [AgentLoader] Path not found: .../agents
```

### 11.2 修复方案

**改动点 1**：检查 3 个技能的 SKILL.md 文件

确认文件是否存在且 frontmatter 合法。如果是测试/废弃技能，从 skills 目录移除。

**改动点 2**：`src/agent/agent_loader.cj`（或类似）

目录不存在时静默跳过（DEBUG 级别），而非 ERROR。AgentLoader 扫描到不存在的目录是正常行为，不应报错。

---

## 十二、v5 实施优先级与路线图

### Phase 1：P0 阻断修复（立即，投研任务直接相关）

| 序号 | 任务 | 预期效果 |
|------|------|---------|
| 1 | OPT-V5-3 TieredMemory Embedding model 配置 | agent 能用记忆系统辅助投研 |
| 2 | OPT-V5-7 Parsing action parser 容错增强 | agent 工具调用解析不再失败 |
| 3 | OPT-V5-8 HttpTool/WebFetchTool 错误降级 | 行情/新闻抓取有明确错误和备用源 |

### Phase 2：P1 基础设施修复（高优先级，稳定性/合规）

| 序号 | 任务 | 预期效果 |
|------|------|---------|
| 4 | OPT-V5-1 AsyncLogWriter SQL + 连接池 | 审计日志/计费数据不再丢失（最高频 28 处） |
| 5 | OPT-V5-2 SchedulerEngine SQL + cron | 长程任务元数据能落库，cron 合法（12 处） |
| 6 | OPT-V5-4 verifyToken 明确错误 | token 格式错误有明确提示（3 处） |
| 7 | OPT-V5-5 RequestParserService filter 容错 | filter 解析有原文日志和 lenient 降级 |
| 8 | OPT-V5-6 ChangeDetector identityStatus 默认值 | Agent 变更检测不再因 None 失败 |

### Phase 3：P2 噪声治理（择机）

| 序号 | 任务 | 预期效果 |
|------|------|---------|
| 9 | OPT-V5-9 WebMCPProtocol menu context 降级 | 18 处 WARN 噪声消除 |
| 10 | OPT-V5-10 技能/Agent 加载静默跳过 | 5 处 ERROR 消除或降级 |

---

## 十三、v5 验证检查清单

修复完成后，请人工在单独 cmd 环境编译仓颉代码并运行 runtime，验证以下清单：

- [ ] `TieredMemory.search/update` 不再报 "Embedding model is not set"
- [ ] `Parsing action failed` 不再出现（或完整输出原文便于定位）
- [ ] `[AsyncLogWriter] 批量写入失败` 不再出现（28 处 → 0）
- [ ] `[SchedulerEngine] 更新执行元数据失败` 不再出现（12 处 → 0）
- [ ] `system-health-check` 的 cron 表达式合法，不再每 tick 报错
- [ ] `verifyToken failed` 有明确的格式错误提示
- [ ] `Failed to parse filter JSON` 完整输出原文，且有 lenient 降级
- [ ] `ChangeDetector.detectAgentChanges` 不再因 identityStatus=None 失败
- [ ] `[WebMCPProtocol] Cannot inject menu context` 降级为 DEBUG（18 处 WARN → 0）
- [ ] 废弃技能 SKILL.md 移除或修复，AgentLoader 静默跳过不存在目录
- [ ] 投研任务能完整执行六步 SOP：抓取 → 清洗 → 提取 → 生成 → 落库 → 简报

---

## 十四、v5 涉及文件清单（预期）

### 14.1 runtime 仓颉（预期 8~10 个）

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `src/app/services/log/async_log_writer.cj`（待确认） | OPT-V5-1 | 修改：SQL 参数绑定 + 异步队列 |
| `src/app/services/crontab/SchedulerEngine.cj` | OPT-V5-2 | 修改：SQL 绑定 + cron 启动校验 |
| `src/agent/memory/tiered_memory.cj`（待确认） | OPT-V5-3 | 修改：model 未设置时降级 |
| `.env` / `.env.example` | OPT-V5-3 | 新增：Embedding model 配置项 |
| `src/middleware/auth.cj`（待确认） | OPT-V5-4 | 修改：verifyToken 明确错误 |
| `src/app/services/parser/request_parser_service.cj`（待确认） | OPT-V5-5 | 修改：完整输出原文 + lenient |
| `src/agent/change_detector.cj`（待确认） | OPT-V5-6 | 修改：identityStatus 默认值 |
| `src/parser/parser_utils.cj` | OPT-V5-7 | 修改：parser 容错增强 |
| `src/tool/http_tool.cj` / `web_fetch_tool.cj` | OPT-V5-8 | 修改：错误降级 + 编码 fallback |
| `src/app/services/webmcp/WebMCPProtocol.cj` | OPT-V5-9 | 修改：menu context 降级 DEBUG |
| `src/agent/agent_loader.cj`（待确认） | OPT-V5-10 | 修改：静默跳过不存在目录 |

### 14.2 技能目录（预期 1~3 个删除）

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `skills/cangjie-refactor/` | OPT-V5-10 | 删除或修复 SKILL.md |
| `skills/rg_history/` | OPT-V5-10 | 删除或修复 SKILL.md |
| `skills/sdd-test/` | OPT-V5-10 | 删除或修复 SKILL.md |

---

## 附录：v1~v5 实施差异说明

| 维度 | v1 | v2 | v3 | v4 | v5 |
|------|----|----|----|----|----|
| **核心目标** | get_skill_content 工具 | ReAct 解析器 bug | Windows 命令执行 | skills 渐进式加载 + web 思维链 | **全量基础设施修复**（AsyncLogWriter/Scheduler/TieredMemory/token/cron） |
| **覆盖范围** | 投研任务链路 | 投研任务链路 | 投研任务链路 | 投研任务链路 | **全量日志报错**（17 个问题点） |
| **改动性质** | 新增功能 | 修复 bug | 修复环境兼容 | 纠正设计 + 真正落地 | 基础设施稳定性 + 噪声治理 |
| **与前一轮的关系** | 基础能力 | v1 遗留 bug | v2 未覆盖环境 | v3 未真正落地 | v4 之外的**全量遗留问题** |

**关键结论**：v5 是对 v1~v4 的**横向补充**，不再局限于投研任务链路，而是对全量日志报错做一次性整治。v1~v4 是纵向迭代（针对投研任务），v5 是横向整治（针对基础设施）。v5 完成后，runtime 的日志应从 61 ERROR / 21 WARN 降至接近 0（仅保留正常工作日志如孤儿任务清理的 WARN）。

---

# 第五轮迭代实施方案（v5 实测，2026-08-11）

> **文档定位**：基于 v5 实测复核报告（report.md 第五十二至五十七节），针对本轮实测中**依然存在和新发现**的问题制定修复方案。本轮**先更新文档再改代码**，代码修复后需人工在 cmd 环境编译仓颉代码并重新构建 web 前端产物。
>
> **核心原则**：沿用原有设计架构进行增量优化，每一项修复都基于本轮实测日志证据，不凭猜测。投研任务链路（思维链显示、脚本读取、工具调用）优先级最高。
>
> **日期**：2026-08-11 | **基于实测日志分析** | **覆盖 14 个问题点（RV5-01~RV5-14）**

---

## 一、v5 实测方案总览

| 编号 | 优化项 | 对应报告 | 优先级 | 方案策略 | 涉及文件数 |
|------|--------|---------|--------|---------|-----------|
| OPT-RV5-1 | _chatViaWebMCP 增加 reasoning 转发 | RV5-14 | P0 高 | WebMCP complete 改为真正流式 + reasoning 事件转发 | 1 |
| OPT-RV5-2 | file_read 空内容修复 | RV5-12 | P0 高 | readFile 异常包装 + endLine 默认值修正 + 读取后校验 | 1 |
| OPT-RV5-3 | 系统提示引导工具使用 | RV5-13 | P0 高 | 增加脚本执行引导段 | 1~2 |
| OPT-RV5-4 | WebMCP/TLS 超时优化 | RV5-10, RV5-11 | P0 高 | MCP 客户端超时配置 + TLS 超时降级 | 2~3 |
| OPT-RV5-5 | TieredMemory Embedding 配置 | RV5-02, RV5-03 | P0 高 | 配置 Embedding model 或降级 | 1~2 |
| OPT-RV5-6 | verifyToken 明确错误 | RV5-04 | P1 中 | 检查 token 传递 + 返回明确错误 | 1~2 |
| OPT-RV5-7 | RequestParserService filter 容错 | RV5-05 | P1 中 | 完整输出原文 + lenient 解析 | 1 |
| OPT-RV5-8 | CRON 表达式修正 | RV5-06 | P1 中 | 修正 cron 表达式 + 启动时校验 | 1 |
| OPT-RV5-9 | AgentLoader 静默跳过 | RV5-07 | P2 低 | 目录不存在时降级为 DEBUG | 1 |
| OPT-RV5-10 | ChangeDetector identityStatus 默认值 | RV5-08 | P1 中 | 提供默认值 + None 容错 | 1 |
| OPT-RV5-11 | WebMCPProtocol menu context 降级 | RV5-01 | P2 低 | 降级为 DEBUG 或启动时一次性告警 | 1 |

---

## 二、OPT-RV5-1：_chatViaWebMCP 增加 reasoning 转发（P0，思维链显示核心）

### 2.1 问题根因（日志证据）

`web_console.md` 第 34~50 行显示投研任务走的是 WebMCP 通道（`Using WebMCP protocol for chat first`），而非 `_chatReActStream`。源码复核发现 `_chatViaWebMCP`（AgentModelProvider.ts 第 895~1054 行）的流式响应**只发 text 事件，完全未转发 reasoning 事件**：

```typescript
controller.enqueue({ type: 'start' })
controller.enqueue({ type: 'start-step' })
controller.enqueue({ type: 'text-start' })
// 逐字符发送 content
controller.enqueue({ type: 'text-end' })
controller.enqueue({ type: 'finish-step' })
controller.enqueue({ type: 'finish' })
```

**完全没有 reasoning-start/reasoning-delta/reasoning-end 事件**。这正是前四轮修复都未在 web 端看到任何思维链变化的根因——前三轮修复都集中在 `_chatReActStream`（useReActMode=true 走的通道），但投研任务实际走的是 WebMCP 通道。

### 2.2 修复方案

**改动点 1**：`_chatViaWebMCP` 的流式响应增加 reasoning 事件转发

从 `webmcpClient.complete` 返回的 `result` 中提取 `reasoning_content`（或 `reasoning` 字段），在 `text-start` 之前发送 reasoning 事件：

```typescript
// 提取 reasoning 内容
let reasoningContent = ''
if (result.completion && result.completion.reasoning_content) {
  reasoningContent = result.completion.reasoning_content
} else if (result.completion && result.completion.reasoning) {
  reasoningContent = result.completion.reasoning
} else if (result.reasoning_content) {
  reasoningContent = result.reasoning_content
} else if (result.reasoning) {
  reasoningContent = result.reasoning
}

// 发送 reasoning 事件（在 text-start 之前）
if (reasoningContent) {
  controller.enqueue({ type: 'reasoning-start', id: 'reasoning-webmcp-0' })
  // 分段发送 reasoning 内容（避免一次性过大量）
  const reasoningChunks = reasoningContent.match(/[\s\S]{1,100}/g) || []
  for (const chunk of reasoningChunks) {
    controller.enqueue({ type: 'reasoning-delta', id: 'reasoning-webmcp-0', delta: chunk })
  }
  controller.enqueue({ type: 'reasoning-end', id: 'reasoning-webmcp-0' })
}

// 然后发送 text 事件（保持原逻辑）
controller.enqueue({ type: 'text-start' })
// ... 逐字符发送 content ...
```

**改动点 2**：确认 `webmcpClient.complete({ stream: true })` 的返回结构

当前实现是 `await webmcpClient.complete(...)` 后一次性处理完整响应，再逐字符发送——这并非真正的流式。理想方案是改为**真正的流式**（逐 token 发送），但改动较大且需确认 MCP 客户端 SDK 是否支持。本轮先用最小改动方案：从完整响应中提取 reasoning 并转发，后续再改为真正流式。

**改动点 3**：确认 useReActMode 配置

如果投研任务的模型配置开启了 `useReActMode: true`，则应走 `_chatReActStream`（已正确转发 reasoning）。检查 `web-admin/web` 中模型配置的 `useReActMode` 字段，确认是否为 false 或未设置。

---

## 三、OPT-RV5-2：file_read 空内容修复（P0，投研链路）

### 3.1 问题根因（日志证据）

第 2667~2674 行显示 file_read 对 `fetch_market_data.py`（实际 127 行）返回 `content: ""`、`lineCount: 0` 且 `success: "true"`。normalizePath 已正确收敛路径，exists(path) 也返回 true，根因锁定在 `readFile` 本身。

### 3.2 修复方案

**改动点 1**：`src/tool/file_tools.cj` — `endLine` 默认值修正

```cangjie
// 当前：let endLine = FileReadTool.extractInt(args, "endLine", Int64.Max)
// 问题：Int64.Max 可能导致切片异常
// 修复：改为 -1，与参数说明一致，readFile 内部处理 -1 为读到文件末尾
let endLine = FileReadTool.extractInt(args, "endLine", -1)
```

**改动点 2**：readFile 调用异常包装

```cangjie
try {
    let content = readFile(path, withLineNumber: withLineNumber, startLine: finalStartLine, endLine: finalEndLine)
    
    // 读取后校验：若 content 为空但文件存在且大小 > 0，返回警告
    if (content.isEmpty()) {
        let fileInfo = FileInfo(path)
        if (fileInfo.size > 0) {
            LogUtils.warn("[FileReadTool] File exists and has content but readFile returned empty: ${normalizedPathStr}, possible encoding issue")
            let warnResult = JsonObject()
            warnResult.put("success", JsonString("true"))
            warnResult.put("path", JsonString(normalizedPathStr))
            warnResult.put("content", JsonString(""))
            warnResult.put("lineCount", JsonString("0"))
            warnResult.put("warning", JsonString("File exists (size: ${fileInfo.size} bytes) but content is empty, possible encoding issue. Try withLineNumber=false or check file encoding."))
            return warnResult.toJsonString()
        }
    }
    
    // 正常返回
    let result = JsonObject()
    // ...
} catch (ex: Exception) {
    LogUtils.error("[FileReadTool] Failed to read file: ${ex.message}")
    // 返回明确错误而非抛异常，让 agent 能继续处理
    let errResult = JsonObject()
    errResult.put("success", JsonString("false"))
    errResult.put("path", JsonString(normalizedPathStr))
    errResult.put("error", JsonString("Failed to read file: ${ex.message}"))
    return errResult.toJsonString()
}
```

**改动点 3**：确认 readFile 对非 UTF-8 文件的处理

Python 脚本含中文注释，可能非 UTF-8 编码。检查仓颉 `readFile` 是否支持编码参数，或改为先检测编码再读取。

---

## 四、OPT-RV5-3：系统提示引导工具使用（P0，投研链路）

### 4.1 问题根因（日志证据）

agent 全程未调用 `cli_execute`/`python_execute`，根因之一是系统提示未明确引导工具使用。v4 改为渐进式加载后，系统提示仅含 frontmatter + get_skill_content 说明。

### 4.2 修复方案

**改动点**：`src/app/services/webmcp/WebMCPProtocol.cj` 和 `src/app/controllers/uctoo/ws/WsChatController.cj` — `buildAgentSystemPrompt` 增加工具使用引导段

在系统提示末尾增加：
```
## 工具使用引导
- skills 的 scripts 目录中的 Python 脚本，通过 cli_execute 或 python_execute 工具执行
- 例如：cli_execute command="python" args="[\"scripts/fetch_market_data.py\", \"--companies\", \"600519\"]"
- 脚本执行前可先用 file_read 工具查看脚本内容，了解用法和参数
- 脚本执行的工作目录默认为技能目录，即 skills/<skill-name>/
```

---

## 五、OPT-RV5-4：WebMCP/TLS 超时优化（P0，新发现）

### 5.1 问题根因（日志证据）

`runtime_start.log` 第 143~160 行：10 处 `TLS read timed out after 30s`。`web_console.md` 第 49~50 行：`McpError: MCP error -32001: Request timed out`。

### 5.2 修复方案

**改动点 1**：MCP 客户端超时配置

`_chatViaWebMCP` 中 `webmcpClient.complete(..., { timeout: 600000 })` 传入的超时可能被 SDK 默认值覆盖。检查 MCP 客户端 SDK 的超时配置链路，确认 600000ms 是否真正生效。

**改动点 2**：TLS 超时降级

`runtime_start.log` 中的 TLS 超时是连接保活探测，不应报 ERROR。将 `http: readHttpRequestFromConnection error: TLS read timed out after 30s` 降级为 INFO 或 DEBUG。

**改动点 3**：runtime 端 completion/complete 处理耗时监控

如果 runtime 端处理 completion/complete 耗时超 30s，应返回阶段性响应（如 `{ status: 'processing', progress: '...' }`）而非全量超时。

---

## 六、OPT-RV5-5：TieredMemory Embedding 配置（P0）

### 6.1 问题根因（日志证据）

2 处 `TieredMemory.search failed: Embedding model is not set` + 1 处 `TieredMemory.update failed`。

### 6.2 修复方案

**改动点 1**：在 `.env` 或配置文件中设置 Embedding model

**改动点 2**：TieredMemory 在 model 未设置时降级（同前一轮 v5 方案，需确认是否已实施）

---

## 七、OPT-RV5-6~11：次要问题修复（P1/P2）

### 7.1 OPT-RV5-6：verifyToken 明确错误（P1）

检查 token 传递方式，token 格式不合法时返回明确错误信息。

### 7.2 OPT-RV5-7：RequestParserService filter 容错（P1）

完整输出 filter 原文 + lenient 解析。

### 7.3 OPT-RV5-8：CRON 表达式修正（P1）

将 `system-health-check` 的 cron 从 `0 */600 * * * *` 改为合法表达式如 `0 */10 * * *`。

### 7.4 OPT-RV5-9：AgentLoader 静默跳过（P2）

目录不存在时降级为 DEBUG。

### 7.5 OPT-RV5-10：ChangeDetector identityStatus 默认值（P1）

提供默认值 + None 容错。

### 7.6 OPT-RV5-11：WebMCPProtocol menu context 降级（P2）

降级为 DEBUG 或启动时一次性告警。

---

## 八、v5 实施优先级与路线图

### Phase 1：P0 投研链路修复（立即）

| 序号 | 任务 | 预期效果 |
|------|------|---------|
| 1 | OPT-RV5-1 _chatViaWebMCP 增加 reasoning 转发 | web 端思维链显示（用户可见变化） |
| 2 | OPT-RV5-2 file_read 空内容修复 | agent 能读到脚本内容 |
| 3 | OPT-RV5-3 系统提示引导工具使用 | agent 知道用 cli_execute/python_execute 执行脚本 |
| 4 | OPT-RV5-4 WebMCP/TLS 超时优化 | 投研任务不因超时中断 |
| 5 | OPT-RV5-5 TieredMemory Embedding 配置 | agent 记忆系统可用 |

### Phase 2：P1/P2 次要问题修复（择机）

| 序号 | 任务 | 预期效果 |
|------|------|---------|
| 6 | OPT-RV5-6 verifyToken 明确错误 | token 格式错误有明确提示 |
| 7 | OPT-RV5-7 filter 解析容错 | filter 解析有原文日志和 lenient 降级 |
| 8 | OPT-RV5-8 CRON 表达式修正 | system-health-check 不再报错 |
| 9 | OPT-RV5-9 AgentLoader 静默跳过 | 2 处 ERROR 消除 |
| 10 | OPT-RV5-10 identityStatus 默认值 | ChangeDetector 不因 None 失败 |
| 11 | OPT-RV5-11 menu context 降级 | 18 处 WARN 噪声消除 |

---

## 九、v5 验证检查清单

修复完成后，请人工在单独 cmd 环境编译仓颉代码并运行 runtime，重新构建 web 前端产物，验证以下清单：

- [ ] web 端对话提交后，agent 回复位置显示思维链折叠控件（"思考过程"），展开可看 reasoning 内容
- [ ] `file_read fetch_market_data.py` 返回实际脚本内容（127 行），不再返回空
- [ ] agent 调用 `cli_execute`/`python_execute` 执行投研脚本（日志出现 `[CliTool]` 输出）
- [ ] WebMCP 通道不再超时（`McpError -32001` 不再出现）
- [ ] TLS 超时降级为 INFO/DEBUG（不再报 ERROR）
- [ ] `TieredMemory.search/update` 不再报 "Embedding model is not set"
- [ ] `system-health-check` 的 cron 表达式合法，不再报错
- [ ] `AgentLoader` 目录不存在时静默跳过（不再报 ERROR）
- [ ] `ChangeDetector` 不因 identityStatus=None 失败
- [ ] `WebMCPProtocol menu context` 降级为 DEBUG（18 处 WARN → 0）
- [ ] 投研任务能完整执行六步 SOP：抓取 → 清洗 → 提取 → 生成 → 落库 → 简报

---

## 十、v5 涉及文件清单（预期）

### 10.1 web 前端 TypeScript（Phase 1 核心）

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `apps/web-admin/web/src/lib/webmcp-sdk/packages/next-sdk/agent/AgentModelProvider.ts` | OPT-RV5-1 | 修改：_chatViaWebMCP 增加 reasoning 转发 |

### 10.2 runtime 仓颉（Phase 1 + Phase 2）

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `src/tool/file_tools.cj` | OPT-RV5-2 | 修改：endLine 默认值 + readFile 异常包装 + 读取后校验 |
| `src/app/services/webmcp/WebMCPProtocol.cj` | OPT-RV5-3 | 修改：buildAgentSystemPrompt 增加工具使用引导 |
| `src/app/controllers/uctoo/ws/WsChatController.cj` | OPT-RV5-3 | 修改：同步增加工具使用引导 |
| `src/agent/memory/tiered_memory.cj`（待确认） | OPT-RV5-5 | 修改：model 未设置时降级 |
| `.env` / `.env.example` | OPT-RV5-5 | 新增：Embedding model 配置项 |
| `src/app/services/crontab/SchedulerEngine.cj` | OPT-RV5-8 | 修改：修正 cron 表达式 + 启动时校验 |
| `src/agent/agent_loader.cj`（待确认） | OPT-RV5-9 | 修改：静默跳过不存在目录 |
| `src/agent/change_detector.cj`（待确认） | OPT-RV5-10 | 修改：identityStatus 默认值 |
| `src/app/services/webmcp/WebMCPProtocol.cj` | OPT-RV5-11 | 修改：menu context 降级 DEBUG |

---

## 附录：v1~v5 实施差异说明（含本轮实测）

| 维度 | v1 | v2 | v3 | v4 | v5（前一轮） | v5（本轮实测） |
|------|----|----|----|----|----|----|
| **核心目标** | get_skill_content 工具 | ReAct 解析器 bug | Windows 命令执行 | skills 渐进式加载 + web 思维链 | 全量基础设施修复 | **投研链路真正落地 + 剩余报错清理** |
| **覆盖范围** | 投研任务链路 | 投研任务链路 | 投研任务链路 | 投研任务链路 | 全量日志报错 | **实测复核 + 投研链路修复** |
| **改动性质** | 新增功能 | 修复 bug | 修复环境兼容 | 纠正设计 + 真正落地 | 基础设施稳定性 + 噪声治理 | **纠正通道选择 + 脚本读取修复** |
| **与前一轮的关系** | 基础能力 | v1 遗留 bug | v2 未覆盖环境 | v3 未真正落地 | v4 之外的横向整治 | **v5 前一轮方案实测后的迭代** |

**关键结论**：本轮 v5 实测发现前三轮思维链修复都集中在 `_chatReActStream`，但投研任务实际走的是 WebMCP 通道（`_chatViaWebMCP`），导致用户"前四轮修复都还没有实现 web 端聊天组件没有看到任何变化"。本轮核心是**纠正通道选择**，在 `_chatViaWebMCP` 中增加 reasoning 转发，让思维链在 WebMCP 通道也能显示。同时修复 file_read 空内容问题和系统提示引导工具使用，让投研任务链路真正落地。

---

# 第六轮迭代实施方案（v6 实测，2026-08-11）

> **文档定位**：基于 v6 实测复核报告（report.md 第五十八至六十四节），针对本轮实测中**依然存在和新发现**的问题制定修复方案。本轮**先更新文档再改代码**，代码修复后需人工在 cmd 环境编译仓颉代码并重新构建 web 前端产物。
>
> **核心原则**：沿用原有设计架构进行增量优化，每一项修复都基于本轮实测日志证据，不凭猜测。投研任务链路（CliTool PATH、思维链显示、agent 自主持续工作）优先级最高。
>
> **日期**：2026-08-11 | **基于实测日志分析** | **覆盖 14 个问题点（RV6-01~RV6-15）**

---

## 一、v6 实测方案总览

| 编号 | 优化项 | 对应报告 | 优先级 | 方案策略 | 涉及文件数 |
|------|--------|---------|--------|---------|-----------|
| OPT-V6-1 | wrapForWindowsShell 所有命令都走 cmd.exe /C | RV6-09 | P0 高 | 普通可执行文件也用 cmd.exe 包裹，让 cmd.exe 负责 PATH 查找 | 1 |
| OPT-V6-2 | web 端思维链显示根治（WebMCP 超时+前端降级+useReActMode） | RV6-14 | P0 高 | 超时优化 + 前端降级 + 投研任务走 useReActMode | 3~5 |
| OPT-V6-3 | agent 自主持续工作机制（遇挫不停+ReAct fail+AgentLoop） | RV6-15 | P0 高 | 系统提示 + ReAct fail 处理 + loopMax 配置 | 3~4 |
| OPT-V6-4 | TieredMemory Embedding 配置或降级 | RV6-04, RV6-05 | P0 高 | 配置 Embedding model 或降级为关键词检索 | 2~3 |
| OPT-V6-5 | AsyncLogWriter/SchedulerEngine SQL 绑定根治 | RV6-01, RV6-02 | P1 高 | 逐一核对所有 SQL + 连接池 + 异步队列 | 2~3 |
| OPT-V6-6 | parser 容错根治（新变体+工具名缺失） | RV6-06, RV6-07 | P0 高 | 完整输出原文 + 最外层 JSON 提取 + 工具名缺失分支 | 1 |
| OPT-V6-7 | RequestParserService filter lenient 解析 | RV6-03 | P1 中 | lenient 解析实施 | 1 |
| OPT-V6-8 | verifyToken token 传递检查 | RV6-08 | P1 中 | 检查 WebSocket/SSE 通道 token 传递 | 1~2 |
| OPT-V6-9 | CRON 表达式源头修正 | RV6-10 | P1 中 | 修正 system-health-check cron 配置源头 | 1~2 |
| OPT-V6-10 | ChangeDetector identityStatus 默认值实施 | RV6-11 | P1 中 | 提供默认值 + None 容错 | 1 |

---

## 二、OPT-V6-1：wrapForWindowsShell 所有命令都走 cmd.exe /C（P0，投研链路核心）

### 2.1 问题根因（日志证据）

```
ERROR [CliTool] Command execution failed: Created process failed, errMessage: "The system cannot find the file specified."
```

agent 的最终 answer 明确指出 `python` 未在 PATH 中。源码复核发现 `wrapForWindowsShell` 把 `python`/`git`/`npm` 等普通可执行文件**不包裹**，但仓颉 `newProcess` 不走 shell，也不会自动在 PATH 中查找可执行文件。

### 2.2 修复方案

**改动点**：`src/tool/cli_tool.cj` — `wrapForWindowsShell` 改为**所有命令都走 `cmd.exe /C`**

将"普通可执行文件不包裹"的设计改为"所有命令都用 cmd.exe /C 包裹"，让 cmd.exe 负责：
1. 在 PATH 中查找可执行文件（python/git/npm 等）
2. 内建命令执行（echo/dir/where 等）
3. 环境变量展开和引号处理

```cangjie
protected static func wrapForWindowsShell(command: String, args: Array<String>): (String, Array<String>) {
    // PowerShell 显式调用：走 powershell.exe -Command（保持原逻辑）
    let lowerCmd = command.toAsciiLower()
    let isPs = lowerCmd == "powershell" || lowerCmd == "pwsh"
    
    // 拼接原始命令行字符串
    let cmdLine = StringBuilder()
    cmdLine.append(command)
    for (a in args) {
        cmdLine.append(" ")
        if (a.contains(" ") && !a.startsWith("\"")) {
            cmdLine.append("\"")
            cmdLine.append(a)
            cmdLine.append("\"")
        } else {
            cmdLine.append(a)
        }
    }
    let cmdLineStr = cmdLine.toString()
    
    // v6 实测修复：所有命令都走 cmd.exe /C，让 cmd.exe 负责 PATH 查找和内建命令
    // 根因：仓颉 newProcess 不走 shell，普通可执行文件（python/git/npm）找不到文件报错
    let cmdArgs = ["/C", cmdLineStr]
    let cmdExe = resolveWindowsExe("cmd.exe")
    LogUtils.info("[CliTool] Wrapped command via cmd.exe: ${cmdExe} /C \"${cmdLineStr}\"")
    return (cmdExe, cmdArgs)
}
```

**简化设计**：移除 cmdBuiltin/psBuiltin 清单和分支判断，所有命令统一走 cmd.exe /C。PowerShell 显式调用保持原逻辑（走 powershell.exe -Command）。

---

## 三、OPT-V6-2：web 端思维链显示根治（P0，前五轮未根治）

### 3.1 问题根因（日志证据）

`web_console.md` 显示走 WebMCP 通道且 `McpError -32001 Request timed out`。`build.log` 显示前端构建已生效，`dist` 产物含 reasoning 转发代码——v5 的 `_chatViaWebMCP` reasoning 转发已编译生效，但 WebMCP 通道本身超时导致前端收到错误而非流式响应。

### 3.2 修复方案

**改动点 1**：MCP 客户端超时配置检查

`_chatViaWebMCP` 中 `webmcpClient.complete(..., { timeout: 600000 })` 传入的超时可能被 SDK 默认值覆盖。检查 MCP 客户端 SDK 的超时配置链路。

**改动点 2**：前端 `streamVisitor.ts` 对 `McpError -32001` 做降级处理

```typescript
case 'error':
  if (startContent!) {
    startContent.running = false
    startContent!.error = event.error as any
    // v6 实测修复：超时错误降级显示"agent 正在思考中"，而非直接抛异常让用户看到 loading 卡死
    if (event.error && event.error.code === -32001) {
      startContent!.finishReason = 'timeout'
      // 在最后一个 step 的 contents 中插入降级提示
      if (startContent!.steps.size > 0) {
        const lastStep = startContent!.steps[startContent!.steps.size - 1]
        lastStep.contents.push({
          type: 'text',
          id: 'timeout-hint',
          running: false,
          text: '【提示】agent 正在进行长程任务（多轮工具调用），前端通道超时但后端仍在运行。请稍候或查看后端日志了解进展。'
        })
      }
    } else {
      startContent!.finishReason = 'error'
    }
  }
  this.option.onFinish?.()
  break
```

**改动点 3**：投研任务配置 useReActMode: true

投研任务应走 `_chatReActStream`（已正确转发 reasoning 且不依赖 WebMCP 超时）。检查 `web-admin/web` 中模型配置的 `useReActMode` 字段，确认是否为 false 或未设置，改为 true。

---

## 四、OPT-V6-3：agent 自主持续工作机制（P0，新发现）

### 4.1 问题根因（日志证据）

agent 在第 21 步触发 `<fail>` 事件后，直接生成最终 answer 总结"遇到的问题"后停止，没有尝试替代方案（如用 `http_request` 直接抓取东方财富接口）。

### 4.2 修复方案

**改动点 1**：系统提示增加"遇挫不停"引导

`src/app/services/webmcp/WebMCPProtocol.cj` 和 `src/app/controllers/uctoo/ws/WsChatController.cj` 的 `buildAgentSystemPrompt` 增加：
```
## 遇挫不停原则
- 工具失败时尝试替代方案，至少尝试 3 种不同方案后才报告失败
- 例如：cli_execute 失败后，用 http_request 直接抓取接口；http_request 失败后，用 web_fetch 获取网页
- 失败信息加入 observation，让下一轮 ReAct 决定是否继续或换方案
- 只有所有方案都失败后，才生成最终 answer 报告失败
```

**改动点 2**：ReAct loop 的 fail 处理改为不直接终止

`AgentModelProvider.ts` 的 `_chatReActStream` 中，触发 `<fail>` 后不直接进入最终 answer，而是将失败信息加入 observation，让 agent 决定是否继续。

**改动点 3**：投研任务配置 loopMax ≥ 50

启用 AgentLoop 长程任务机制，让 agent 有足够步数完成六步 SOP（抓取 → 清洗 → 提取 → 生成 → 落库 → 简报）。

---

## 五、OPT-V6-4：TieredMemory Embedding 配置或降级（P0）

### 5.1 问题根因（日志证据）

3 处 `TieredMemory.search/update failed: Embedding model is not set`。

### 5.2 修复方案

**改动点 1**：在 `.env` 或配置文件中设置 Embedding model

**改动点 2**：TieredMemory 在 model 未设置时降级

- `ShortMemory` 在 `Config.defaultEmbeddingModel` 为 None 时，search 降级为返回空（而非抛异常）
- `DatabaseMemory` 的 `searchByContent` 降级为基于关键词的 SQL LIKE 查询
- 启动时 warn 一次"Embedding model not set, TieredMemory degraded"

**改动点 3**：通过 uctoo-doc 技能持续完善 Embedding 配置文档

---

## 六、OPT-V6-5：AsyncLogWriter/SchedulerEngine SQL 绑定根治（P1，重现）

### 6.1 问题根因（日志证据）

14 处 SQL 绑定错误，含新变体 `parameter index 14 out of range [0, 14)` 和 `parameter index 22 out of range [0, 22)`。

### 6.2 修复方案

**改动点 1**：逐一核对 AsyncLogWriter 和 SchedulerEngine 的**所有** SQL 语句与参数数组长度

**改动点 2**：引入数据库连接池或每线程独立连接，避免 Socket 并发读写争用

**改动点 3**：AsyncLogWriter 改为单线程消费的队列模式

---

## 七、OPT-V6-6~10：次要问题修复（P0/P1/P2）

### 7.1 OPT-V6-6：parser 容错根治（P0）

`src/parser/parser_utils.cj` — 完整输出原文 + 最外层 JSON 提取 + 工具名缺失分支容错。

### 7.2 OPT-V6-7：RequestParserService filter lenient 解析（P1）

`src/app/core/query/RequestParserService.cj` — lenient 解析实施（先严格解析，失败则尝试 lenient）。

### 7.3 OPT-V6-8：verifyToken token 传递检查（P1）

检查 WebSocket/SSE 通道的 token 传递，确认未截断。

### 7.4 OPT-V6-9：CRON 表达式源头修正（P1）

修正 `system-health-check` 的 cron 配置源头（从 `0 */600 * * * *` 改为合法表达式）。

### 7.5 OPT-V6-10：ChangeDetector identityStatus 默认值实施（P1）

`src/app/services/sync/detector/ChangeDetector.cj` — 提供默认值 + None 容错。

---

## 八、v6 实施优先级与路线图

### Phase 1：P0 投研链路修复（立即）

| 序号 | 任务 | 预期效果 |
|------|------|---------|
| 1 | OPT-V6-1 wrapForWindowsShell 所有命令都走 cmd.exe /C | agent 能调用 python/git/npm 等普通可执行文件 |
| 2 | OPT-V6-2 web 端思维链显示根治 | 前端显示思维链或降级提示，不再 loading 卡死 |
| 3 | OPT-V6-3 agent 自主持续工作机制 | agent 遇挫不停，至少尝试 3 种方案后才报告失败 |
| 4 | OPT-V6-4 TieredMemory Embedding 配置或降级 | agent 记忆系统可用或降级 |
| 5 | OPT-V6-6 parser 容错根治 | 工具调用解析不再失败 |

### Phase 2：P1 基础设施修复（高优先级）

| 序号 | 任务 | 预期效果 |
|------|------|---------|
| 6 | OPT-V6-5 AsyncLogWriter/SchedulerEngine SQL 绑定根治 | 审计日志/元数据不再丢失（14 处 → 0） |
| 7 | OPT-V6-7 filter lenient 解析 | filter 解析有 lenient 降级 |
| 8 | OPT-V6-8 verifyToken token 传递检查 | token 格式错误有明确提示 |
| 9 | OPT-V6-9 CRON 表达式源头修正 | system-health-check 不再报错 |
| 10 | OPT-V6-10 identityStatus 默认值实施 | ChangeDetector 不因 None 失败 |

---

## 九、v6 验证检查清单

修复完成后，请人工在单独 cmd 环境编译仓颉代码并运行 runtime，重新构建 web 前端产物，验证以下清单：

- [ ] agent 调用 `cli_execute` 执行 `python fetch_market_data.py` 成功（日志出现 `[CliTool] Wrapped command via cmd.exe`）
- [ ] web 端对话提交后显示思维链折叠控件或降级提示，不再 loading 卡死
- [ ] agent 遇工具失败时尝试替代方案（如 cli_execute 失败后用 http_request），至少 3 种方案后才报告失败
- [ ] 投研任务能完整执行六步 SOP：抓取 → 清洗 → 提取 → 生成 → 落库 → 简报
- [ ] `TieredMemory.search/update` 不再报 "Embedding model is not set"（配置或降级）
- [ ] `[AsyncLogWriter] 批量写入失败` 和 `[SchedulerEngine] 更新执行元数据失败` 不再出现（14 处 → 0）
- [ ] `Parsing action failed` 不再出现（含新变体和工具名缺失分支）
- [ ] `system-health-check` 的 cron 表达式合法
- [ ] `ChangeDetector` 不因 identityStatus=None 失败

---

## 十、v6 涉及文件清单（预期）

### 10.1 runtime 仓颉（Phase 1 + Phase 2）

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `src/tool/cli_tool.cj` | OPT-V6-1 | 修改：wrapForWindowsShell 所有命令都走 cmd.exe /C |
| `src/app/services/webmcp/WebMCPProtocol.cj` | OPT-V6-3 | 修改：buildAgentSystemPrompt 增加遇挫不停引导 |
| `src/app/controllers/uctoo/ws/WsChatController.cj` | OPT-V6-3 | 修改：同步增加遇挫不停引导 |
| `src/agent/memory/tiered/tiered_memory.cj` | OPT-V6-4 | 修改：model 未设置时降级 |
| `src/memory/short_memory.cj` | OPT-V6-4 | 修改：defaultEmbeddingModel 为 None 时降级 |
| `src/agent/memory/database/database_memory.cj` | OPT-V6-4 | 修改：searchByContent 降级为 SQL LIKE |
| `.env` / `.env.example` | OPT-V6-4 | 新增：Embedding model 配置项 |
| `src/parser/parser_utils.cj` | OPT-V6-6 | 修改：parser 容错根治 |
| `src/app/core/query/RequestParserService.cj` | OPT-V6-7 | 修改：lenient 解析实施 |
| `src/app/services/crontab/SchedulerEngine.cj` | OPT-V6-9 | 修改：cron 源头修正 |
| `src/app/services/sync/detector/ChangeDetector.cj` | OPT-V6-10 | 修改：identityStatus 默认值 |
| AsyncLogWriter 源码（待定位） | OPT-V6-5 | 修改：SQL 绑定根治 + 连接池 |

### 10.2 web 前端 TypeScript（Phase 1）

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `apps/web-admin/web/src/lib/webmcp-sdk/packages/next-remoter/src/composable/streamVisitor.ts` | OPT-V6-2 | 修改：McpError -32001 降级处理 |
| `apps/web-admin/web/src/lib/webmcp-sdk/packages/next-sdk/agent/AgentModelProvider.ts` | OPT-V6-2, OPT-V6-3 | 修改：超时配置 + ReAct fail 处理 |
| 投研任务模型配置 | OPT-V6-2 | 修改：useReActMode: true |

---

## 附录：v1~v6 实施差异说明（含本轮实测）

| 维度 | v1 | v2 | v3 | v4 | v5 | v5 实测 | v6 实测 |
|------|----|----|----|----|----|----|----|
| **核心目标** | get_skill_content | ReAct 解析器 | Windows 命令 | skills 渐进式 | 全量基础设施 | 实测复核 | **投研链路根治 + agent 自主持续** |
| **覆盖范围** | 投研链路 | 投研链路 | 投研链路 | 投研链路 | 全量报错 | 实测复核 | **实测复核 + 长程任务** |
| **改动性质** | 新增功能 | 修复 bug | 修复环境 | 纠正设计 | 基础设施 | 纠正通道 | **根治 PATH + 自主 loop** |

**关键结论**：本轮 v6 实测发现 v3 的 wrapForWindowsShell 设计漏洞（普通可执行文件不包裹导致 PATH 查找失败），这是投研任务无法调用 python 脚本的根因。同时发现 agent 遇挫即停的问题，需启用 AgentLoop 长程任务机制和"遇挫不停"引导。v6 完成后投研任务应能真正完整执行六步 SOP。

---

# 第七轮迭代实施方案（v7 实测，2026-08-11）

> **文档定位**：基于 v7 实测复核报告（report.md 第六十五至六十九节），针对本轮实测中**加剧重现和新发现**的问题制定修复方案。本轮**先更新文档再改代码**，代码修复后需人工在 cmd 环境编译仓颉代码并重新构建 web 前端产物。
>
> **核心原则**：沿用原有设计架构进行增量优化，每一项修复都基于本轮实测日志证据，不凭猜测。投研任务链路（思维链显示根治、agent 遇挫即停根治、WebFetch 编码 fallback）优先级最高。
>
> **日期**：2026-08-11 | **基于实测日志分析** | **覆盖 13 个问题点（RV7-01~RV7-13）**

---

## 一、v7 实测方案总览

| 编号 | 优化项 | 对应报告 | 优先级 | 方案策略 | 涉及文件数 |
|------|--------|---------|--------|---------|-----------|
| OPT-V7-1 | web 端思维链显示根治（前端超时1小时+useReActMode） | RV7-12 | P0 高 | 前端超时改 3600000ms + 投研任务走 useReActMode | 2~3 |
| OPT-V7-2 | agent 遇挫即停根治（ReAct fail处理+替代方案清单+loopMax） | RV7-13 | P0 高 | ReAct fail 不终止 + 具体方案清单 + loopMax≥50 | 3~4 |
| OPT-V7-3 | WebFetchTool 编码 fallback（GBK） | RV7-09 | P0 高 | UTF-8 失败则尝试 GBK/GB2312 解码 | 1 |
| OPT-V7-4 | SQL 绑定根治（蔓延到Billing/Tasks/updateTokens/getFormat） | RV7-01,02,06,07 | P0 高 | 逐一核对所有 SQL + 连接池 + 异步队列 | 4~6 |
| OPT-V7-5 | TieredMemory Embedding 配置或降级 | RV7-04,05 | P0 高 | 配置 Embedding model 或降级为关键词检索 | 2~3 |
| OPT-V7-6 | RequestParserService filter lenient 解析 | RV7-03 | P1 中 | lenient 解析实施 | 1 |
| OPT-V7-7 | verifyToken token 传递检查 | RV7-08 | P1 中 | 检查 WebSocket/SSE 通道 token 传递 | 1~2 |
| OPT-V7-8 | CRON 表达式源头修正 | RV7-10 | P1 中 | 修正 system-health-check cron 配置源头 | 1~2 |
| OPT-V7-9 | ChangeDetector identityStatus 默认值实施 | RV7-11 | P1 中 | 提供默认值 + None 容错 | 1 |

---

## 二、OPT-V7-1：web 端思维链显示根治（P0，前六轮未根治）

### 2.1 问题根因（日志证据）

`web_console.md` 显示走 WebMCP 通道且 `McpError -32001 Request timed out`。`web_connection.md` 确认前端已加载思维链控件和 streamVisitor（v6 改动已编译到产物）。`build.log` 显示前端构建已生效。

**但用户仍看到 loading 卡死**——根因是 WebMCP 通道超时（10 分钟）不够投研任务的多轮工具调用耗时，且投研任务未走 useReActMode（已正确转发 reasoning 的通道）。

### 2.2 修复方案

**改动点 1**：前端超时配置从 10 分钟改为 1 小时

`AgentModelProvider.ts` 第 967/1056 行 `timeout: 600000` 改为 `timeout: 3600000`（1 小时），适配投研任务的多轮工具调用耗时。

**改动点 2**：投研任务配置 `useReActMode: true`

投研任务应走 `_chatReActStream`（已正确转发 reasoning 且不依赖 WebMCP 超时）。检查 `web-admin/web` 中模型配置的 `useReActMode` 字段，改为 true。

**改动点 3**：前端 `streamVisitor.ts` 的 McpError 降级处理已编译（v6 新增），确认超时时间延长后降级提示能正常显示。

---

## 三、OPT-V7-2：agent 遇挫即停根治（P0，v6 引导未根治）

### 3.1 问题根因（日志证据）

v6 的"遇挫不停"引导**已注入系统提示**（日志含完整段），但 agent 仍因 4 种数据源失败而停止。根因：
1. ReAct loop 的 fail 处理仍激进，触发 `<fail>` 后直接进入最终 answer
2. agent 未调用 cli_execute/python_execute 执行脚脚本（v6 的 wrapForWindowsShell 修复未实测生效）
3. agent 未尝试数据库 CRUD 查询（v6 的"数据库查询能力"引导已注入但未生效）
4. 4 种数据源失败后未尝试第 5 种方案

### 3.2 修复方案

**改动点 1**：ReAct loop 的 fail 处理改为不直接终止

`AgentModelProvider.ts` 的 `_chatReActStream` 中，触发 `<fail>` 后不直接进入最终 answer，而是将失败信息加入 observation，让 agent 决定是否继续。

**改动点 2**：系统提示增加**具体替代方案清单**

`WebMCPProtocol.cj` 和 `WsChatController.cj` 的 `buildAgentSystemPrompt` 增加：
```
## 数据源失败时的具体替代方案清单（按顺序尝试）
1. cli_execute 或 python_execute 执行 scripts 脚本（如 fetch_market_data.py）
2. http_request 直接调用其他公开行情 API（如腾讯财经、和风天气等）
3. web_fetch 获取网页内容（注意编码 fallback，GBK 数据源需指定编码）
4. web_search 搜索关键词获取候选公司代码
5. 通过 uctoo-doc 技能查询 API 规范，用 http_request 调用数据库 CRUD API 查询历史数据
6. 询问用户提供具体公司代码（如"600519,000858,300750"）
只有以上 6 种方案全部失败后，才生成最终 answer 报告失败。
```

**改动点 3**：投研任务配置 `loopMax ≥ 50`

启用 AgentLoop 长程任务机制，让 agent 有足够步数完成六步 SOP（抓取 → 清洗 → 提取 → 生成 → 落库 → 简报）。

---

## 四、OPT-V7-3：WebFetchTool 编码 fallback（P0，新发现）

### 4.1 问题根因（日志证据）

```
ERROR [WebFetchTool] Failed to fetch URL: Invalid utf8 byte sequence.
```

新浪财经、财联社等国产金融数据源返回的网页编码是 GBK/GB2312（非 UTF-8），仓颉 `WebFetchTool` 的 `String.fromUtf8` 解码时遇到非法 UTF-8 字节序列直接抛异常。

### 4.2 修复方案

**改动点**：`src/tool/web_fetch_tool.cj`（或类似）— 增加编码 fallback

```cangjie
// 伪代码
let rawBytes = response.body  // 原始字节
let content = try {
    String.fromUtf8(rawBytes)
} catch (_: Exception) {
    // UTF-8 解码失败，尝试 GBK/GB2312（仓颉 charset4cj 库支持）
    try {
        String.fromGbk(rawBytes)
    } catch (_: Exception) {
        // GBK 也失败，替换非法字符为 ? 后返回
        String.fromUtf8(rawBytes, errors: "replace")
    }
}
```

---

## 五、OPT-V7-4：SQL 绑定根治（P0，加剧蔓延）

### 5.1 问题根因（日志证据）

SQL 绑定错误从 v6 的 14 处**加剧蔓延**到 v7 的 50+ 处，新蔓延到 BillingEventHandler、TasksService、updateTokens、getFormat 等多个服务。错误模式统一为 `parameter index 0 out of range [0, 0)` 或 `no value specified for parameter 1`。

### 5.2 修复方案

**改动点 1**：逐一核对**所有**服务的 SQL 语句与参数数组长度

定位 AsyncLogWriter、SchedulerEngine、BillingEventHandler、TasksService、updateTokens、getFormat 的 SQL 语句，确保占位符数 = 参数数。

**改动点 2**：引入数据库连接池或每线程独立连接，避免 Socket 并发读写争用

**改动点 3**：AsyncLogWriter 改为单线程消费的队列模式，避免并发写入

**改动点 4**：`parameter index 0 out of range [0, 0)` 的通用根因

该错误表示 SQL 有 0 个占位符但传了参数，或反之。可能是仓颉 JDBC 驱动对占位符计数方式与预期不一致，或 SQL 拼接时漏了/多了一个占位符。需检查所有传入参数的 SQL 语句。

---

## 六、OPT-V7-5~9：次要问题修复（P0/P1/P2）

### 6.1 OPT-V7-5：TieredMemory Embedding 配置或降级（P0）

配置 Embedding model 或降级为关键词检索（同 v6 方案，需确认是否已实施）。

### 6.2 OPT-V7-6：RequestParserService filter lenient 解析（P1）

`src/app/core/query/RequestParserService.cj` — lenient 解析实施（先严格解析，失败则尝试 lenient）。

### 6.3 OPT-V7-7：verifyToken token 传递检查（P1）

检查 WebSocket/SSE 通道的 token 传递，确认未截断。`first 20 chars: null` 说明 token 为 null 而非截断，需检查前端是否传了 token。

### 6.4 OPT-V7-8：CRON 表达式源头修正（P1）

修正 `system-health-check` 的 cron 配置源头（从 `0 */600 * * * *` 改为合法表达式如 `0 */10 * * *`）。

### 6.5 OPT-V7-9：ChangeDetector identityStatus 默认值实施（P1）

`src/app/services/sync/detector/ChangeDetector.cj` — 提供默认值 + None 容错。

---

## 七、v7 实施优先级与路线图

### Phase 1：P0 投研链路修复（立即）

| 序号 | 任务 | 预期效果 |
|------|------|---------|
| 1 | OPT-V7-1 web 端思维链显示根治 | 前端超时 1 小时 + 投研走 useReActMode，思维链显示 |
| 2 | OPT-V7-2 agent 遇挫即停根治 | ReAct fail 不终止 + 具体方案清单 + loopMax≥50 |
| 3 | OPT-V7-3 WebFetchTool 编码 fallback | GBK 数据源能正常抓取 |
| 4 | OPT-V7-4 SQL 绑定根治 | 审计日志/元数据/计费不再丢失（50+ 处 → 0） |
| 5 | OPT-V7-5 TieredMemory Embedding 配置或降级 | agent 记忆系统可用或降级 |

### Phase 2：P1 基础设施修复（高优先级）

| 序号 | 任务 | 预期效果 |
|------|------|---------|
| 6 | OPT-V7-6 filter lenient 解析 | filter 解析有 lenient 降级 |
| 7 | OPT-V7-7 verifyToken token 传递检查 | token 格式错误有明确提示 |
| 8 | OPT-V7-8 CRON 表达式源头修正 | system-health-check 不再报错 |
| 9 | OPT-V7-9 identityStatus 默认值实施 | ChangeDetector 不因 None 失败 |

---

## 八、v7 验证检查清单

修复完成后，请人工在单独 cmd 环境编译仓颉代码并运行 runtime，重新构建 web 前端产物，验证以下清单：

- [ ] web 端对话提交后显示思维链折叠控件或降级提示，不再 loading 卡死（超时延长到 1 小时）
- [ ] agent 遇工具失败时按 6 种替代方案清单尝试，全部失败后才报告失败
- [ ] agent 调用 cli_execute/python_execute 执行投研脚本（日志出现 `[CliTool] Wrapped command via cmd.exe`）
- [ ] WebFetchTool 能抓取 GBK 编码的数据源（新浪财经、财联社等）
- [ ] `[AsyncLogWriter] 批量写入失败` 和 `[SchedulerEngine] 更新执行元数据失败` 不再出现（50+ 处 → 0）
- [ ] `BillingEventHandler: save llm_usage_log FAILED` 不再出现
- [ ] `TieredMemory.search/update` 不再报 "Embedding model is not set"
- [ ] 投研任务能完整执行六步 SOP：抓取 → 清洗 → 提取 → 生成 → 落库 → 简报

---

## 九、v7 涉及文件清单（预期）

### 9.1 web 前端 TypeScript（Phase 1 核心）

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `apps/web-admin/web/src/lib/webmcp-sdk/packages/next-sdk/agent/AgentModelProvider.ts` | OPT-V7-1, OPT-V7-2 | 修改：超时改 3600000ms + ReAct fail 不终止 |
| 投研任务模型配置 | OPT-V7-1 | 修改：useReActMode: true, loopMax: 50 |

### 9.2 runtime 仓颉（Phase 1 + Phase 2）

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `src/app/services/webmcp/WebMCPProtocol.cj` | OPT-V7-2 | 修改：增加 6 种具体替代方案清单 |
| `src/app/controllers/uctoo/ws/WsChatController.cj` | OPT-V7-2 | 修改：同步替代方案清单 |
| `src/tool/web_fetch_tool.cj`（待确认） | OPT-V7-3 | 修改：编码 fallback（GBK） |
| AsyncLogWriter 源码（待定位） | OPT-V7-4 | 修改：SQL 绑定根治 + 连接池 + 异步队列 |
| SchedulerEngine 源码 | OPT-V7-4 | 修改：SQL 绑定根治 |
| BillingEventHandler 源码（待定位） | OPT-V7-4 | 修改：SQL 绑定修复 |
| TasksService 源码（待定位） | OPT-V7-4 | 修改：SQL 绑定修复 |
| `src/agent/memory/tiered/tiered_memory.cj` | OPT-V7-5 | 修改：model 未设置时降级 |
| `src/memory/short_memory.cj` | OPT-V7-5 | 修改：defaultEmbeddingModel 为 None 时降级 |
| `.env` / `.env.example` | OPT-V7-5 | 新增：Embedding model 配置项 |
| `src/app/core/query/RequestParserService.cj` | OPT-V7-6 | 修改：lenient 解析实施 |
| `src/app/services/crontab/SchedulerEngine.cj` | OPT-V7-8 | 修改：cron 源头修正 |
| `src/app/services/sync/detector/ChangeDetector.cj` | OPT-V7-9 | 修改：identityStatus 默认值 |

### 9.3 技能（已完成本轮）

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `skills/uctoo-doc/SKILL.md` | 重写 | 已完成：完整重写含 README 要点 + docs 全索引 + 数据库 CRUD 查询机制 |

---

## 附录：v1~v7 实施差异说明（含本轮实测）

| 维度 | v1 | v2 | v3 | v4 | v5 | v5 实测 | v6 实测 | v7 实测 |
|------|----|----|----|----|----|----|----|----|
| **核心目标** | get_skill_content | ReAct 解析器 | Windows 命令 | skills 渐进式 | 全量基础设施 | 实测复核 | 投研链路根治 | **思维链根治 + 遇挫即停根治** |
| **覆盖范围** | 投研链路 | 投研链路 | 投研链路 | 投研链路 | 全量报错 | 实测复核 | 实测复核 | **实测复核 + 编码 fallback** |
| **改动性质** | 新增功能 | 修复 bug | 修复环境 | 纠正设计 | 基础设施 | 纠正通道 | 根治 PATH | **根治超时 + 根治 fail** |

**关键结论**：本轮 v7 实测发现 v6 的"遇挫不停"引导已注入但未根治（agent 仍因 4 种数据源失败而停止），WebFetchTool 编码问题导致国产金融数据源全部抓取失败，SQL 绑定问题加剧蔓延到多个新服务。v7 完成后投研任务应能真正完整执行六步 SOP，且 web 端思维链显示能落地（前端超时延长到 1 小时 + 投研走 useReActMode）。

---

# 第八轮迭代实施方案（v8 实测，2026-08-11）

> **文档定位**：基于 v8 实测复核报告（report.md 第七十至七十四节），针对本轮实测中**新发现根因和加剧重现**的问题制定修复方案。本轮**先更新文档再改代码**，代码修复后需人工在 cmd 环境编译仓颉代码并重新构建 web 前端产物。
>
> **核心原则**：沿用原有设计架构进行增量优化，每一项修复都基于本轮实测日志证据，不凭猜测。投研任务链路（CliTool stdout 编码根治、思维链 useReActMode 配置、agent 遇挫即停根治）优先级最高。
>
> **日期**：2026-08-11 | **基于实测日志分析** | **覆盖 15 个问题点（RV8-01~RV8-15）**

---

## 一、v8 实测方案总览

| 编号 | 优化项 | 对应报告 | 优先级 | 方案策略 | 涉及文件数 |
|------|--------|---------|--------|---------|-----------|
| OPT-V8-1 | CliTool stdout 编码根治（chcp 65001 + GBK fallback） | RV8-13 | P0 高 | 命令前加 chcp 65001 + 仓颉端 UTF-8 失败则 GBK 解码 | 1 |
| OPT-V8-2 | web 端思维链显示根治（投研走 useReActMode） | RV8-14 | P0 高 | 投研任务配置 useReActMode=true，走 _chatReActStream | 1~3 |
| OPT-V8-3 | agent 遇挫即停根治（不需要 python 的替代方案清单） | RV8-15 | P0 高 | 系统提示增加 stdout 解码失败时的替代方案 | 2 |
| OPT-V8-4 | SQL 绑定根治（蔓延到 AgentPersistenceEventHandler） | RV8-01,02,06,07 | P0 高 | 逐一核对所有 SQL + 连接池 + 异步队列 | 4~6 |
| OPT-V8-5 | TieredMemory Embedding 配置或降级 | RV8-04,05 | P0 高 | 配置 Embedding model 或降级为关键词检索 | 2~3 |
| OPT-V8-6 | parser 工具名缺失分支根治 | RV8-09 | P0 中 | 工具名缺失时返回明确错误而非抛异常 | 1 |
| OPT-V8-7 | RequestParserService filter lenient 解析 | RV8-03 | P1 中 | lenient 解析实施 | 1 |
| OPT-V8-8 | verifyToken token 为 null 检查 | RV8-08 | P1 中 | 检查前端 token 传递，null 时返回明确错误 | 1~2 |
| OPT-V8-9 | CRON 表达式源头修正 | RV8-10 | P1 中 | 修正 system-health-check cron 配置源头 | 1~2 |
| OPT-V8-10 | ChangeDetector identityStatus 默认值实施 | RV8-11 | P1 中 | 提供默认值 + None 容错 | 1 |

---

## 二、OPT-V8-1：CliTool stdout 编码根治（P0，投研链路核心根因）

### 2.1 问题根因（日志证据）

```
INFO [CliTool] Wrapped command via cmd.exe: C:\Windows\System32\cmd.exe /C "python --version"
INFO [CliTool] Error reading stream: Invalid utf8 byte sequence.

INFO [CliTool] Wrapped command via cmd.exe: C:\Windows\System32\cmd.exe /C "where python python3 py"
INFO [CliTool] Error reading stream: Invalid unicode scalar value.

INFO [CliTool] Wrapped command via cmd.exe: C:\Windows\System32\cmd.exe /C "echo %PATH%"
INFO [CliTool] Error reading stream: Invalid unicode scalar value.
```

v7 的 `wrapForWindowsShell` 修复已生效，所有命令都走 `cmd.exe /C`。但仓颉读取进程 stdout 时按 UTF-8 解码，Windows cmd.exe 的输出含 GBK 字符（中文系统路径、中文用户名、`%PATH%` 展开后的中文环境变量等），UTF-8 解码遇到非法字节序列直接抛异常，agent 收到空 stdout 误以为命令不可用。

**这是投研任务无法调用 python 的真正根因**——不是 python 未安装，而是仓颉 stdout 解码失败。

### 2.2 修复方案

**改动点 1**：`src/tool/cli_tool.cj` — `wrapForWindowsShell` 在命令前加 `chcp 65001 >nul &&`

`chcp 65001` 将 cmd.exe 的控制台代码页切换为 UTF-8（65001），`>nul` 抑制 chcp 自身的输出，`&&` 确保后续命令在 chcp 成功后执行：

```cangjie
// v8 实测修复：在命令前加 chcp 65001 >nul &&，让 cmd.exe 输出 UTF-8 编码
// 根因：仓颉读取进程 stdout 时按 UTF-8 解码，Windows cmd.exe 默认输出 GBK，含中文路径/环境变量时解码失败
let cmdLineStr = "chcp 65001 >nul && " + originalCmdLineStr
let cmdArgs = ["/C", cmdLineStr]
```

**改动点 2**：`src/tool/cli_tool.cj` — 读取 stdout 时增加编码 fallback

即使 `chcp 65001` 设置了，某些命令的输出仍可能含 GBK 字符（如命令自身输出的中文）。仓颉端需做编码 fallback：

```cangjie
// 伪代码
let rawBytes = process.stdout  // 原始字节
let output = try {
    String.fromUtf8(rawBytes)
} catch (_: Exception) {
    // UTF-8 解码失败，尝试 GBK/GB2312（仓颉 charset4cj 库支持）
    try {
        String.fromGbk(rawBytes)
    } catch (_: Exception) {
        // GBK 也失败，替换非法字符为 ? 后返回
        String.fromUtf8(rawBytes, errors: "replace")
    }
}
```

**推荐双保险**：既设置 `chcp 65001` 又在仓颉端做编码 fallback，确保任何情况都能读到 stdout。

---

## 三、OPT-V8-2：web 端思维链显示根治（P0，前七轮未根治）

### 3.1 问题根因（日志证据）

`web_console.md` 第 34 行显示走的是 WebMCP 通道（`Using WebMCP protocol for chat first`），说明 `useReActMode` 为 false。v7 增加了 `_chatViaWebMCP` 的 reasoning 转发，但依赖 runtime 端返回的响应中含 reasoning_content 字段——如果 runtime 端的 SkillAwareAgent 未返回 reasoning_content，前端转发也无法显示。

更根本的修复是**让投研任务走 useReActMode=true**，走 `_chatReActStream`（已正确转发 reasoning 且直接从 AI SDK 流式获取 reasoning）。

### 3.2 修复方案

**改动点 1**：定位 `useReActMode` 的配置位置

检查 `web-admin/web` 中模型配置、技能配置或用户配置的 `useReActMode` 字段。可能是：
- 模型配置（如 `llmConfig.useReActMode`）
- 技能配置（如 `skill.useReActMode`）
- 用户配置（如会话级别的设置）

**改动点 2**：投研任务配置 `useReActMode: true`

在投研任务的配置中设置 `useReActMode: true`，走 `_chatReActStream`（已正确转发 reasoning）。

**改动点 3**：如果 useReActMode 无法开启，需在 `_chatViaWebMCP` 中确认 runtime 端返回的响应是否含 reasoning_content

检查 runtime 端的 SkillAwareAgent 的 complete 方法返回的 completion 对象是否含 reasoning_content 字段。如果不含，需在 runtime 端添加。

---

## 四、OPT-V8-3：agent 遇挫即停根治（P0，v7 引导未根治）

### 4.1 问题根因（日志证据）

v7 的"遇挫不停"引导已注入系统提示，且 ReAct fail 处理已改为不直接终止。但 agent 仍因 stdout 编码失败误判 python 不可用后总结停止。根因：
1. stdout 编码失败导致 agent 误判所有命令不可用（RV8-13）
2. agent 未尝试不需要 python 的替代方案
3. agent 未尝试数据库 CRUD 查询

### 4.2 修复方案

**改动点 1**：修复 stdout 编码问题（OPT-V8-1）→ agent 能正确识别 python 可用

**改动点 2**：系统提示增加**不需要 python 的替代方案清单**

`src/app/services/webmcp/WebMCPProtocol.cj` 和 `src/app/controllers/uctoo/ws/WsChatController.cj` 的 `buildAgentSystemPrompt` 增加：
```
## stdout 解码失败时的替代方案清单（不需要 python）
如果 cli_execute 命令的 stdout 因编码问题返回空或乱码，不要判定命令不可用，尝试以下替代方案：
1. 用 http_request 直接调用东方财富 API（如 push2.eastmoney.com/api/qt/stock/get）抓取行情
2. 用 web_search 搜索"今日A股热点公司"获取候选公司代码
3. 用 web_fetch 获取网页内容（注意编码 fallback）
4. 通过 uctoo-doc 技能查询 API 规范，用 http_request 调用数据库 CRUD API 查询历史数据
5. 询问用户提供具体公司代码（如"600519,000858,300750"）
6. 如果 cli_execute 的命令是 python --version，直接假设 python 可用并尝试执行脚本（python --version 的 stdout 编码失败不代表 python 不可用）
```

**改动点 3**：投研任务配置 `useReActMode: true` + `loopMax ≥ 50`

---

## 五、OPT-V8-4：SQL 绑定根治（P0，加剧蔓延）

### 5.1 问题根因（日志证据）

SQL 绑定错误从 v7 的 50+ 处持续，新蔓延到 AgentPersistenceEventHandler。错误模式统一为 `parameter index 0 out of range [0, 0)` 或 `no value specified for parameter 1` 或 `parameter index 14/22 out of range`。

### 5.2 修复方案

**改动点 1**：逐一核对**所有**服务的 SQL 语句与参数数组长度

定位 AsyncLogWriter、SchedulerEngine、BillingEventHandler、TasksService、AgentPersistenceEventHandler、updateTokens、getFormat 的 SQL 语句，确保占位符数 = 参数数。

**改动点 2**：引入数据库连接池或每线程独立连接，避免 Socket 并发读写争用

**改动点 3**：AsyncLogWriter 改为单线程消费的队列模式，避免并发写入

---

## 六、OPT-V8-5~10：次要问题修复（P0/P1/P2）

### 6.1 OPT-V8-5：TieredMemory Embedding 配置或降级（P0）

配置 Embedding model 或降级为关键词检索（同 v7 方案，需确认是否已实施）。

### 6.2 OPT-V8-6：parser 工具名缺失分支根治（P0）

`src/parser/parser_utils.cj` — 工具名缺失时返回明确错误而非抛异常，让 agent 能继续处理。

### 6.3 OPT-V8-7：RequestParserService filter lenient 解析（P1）

`src/app/core/query/RequestParserService.cj` — lenient 解析实施。

### 6.4 OPT-V8-8：verifyToken token 为 null 检查（P1）

`first 20 chars: null` 说明 token 为 null 而非截断，需检查前端是否传了 token。

### 6.5 OPT-V8-9：CRON 表达式源头修正（P1）

修正 `system-health-check` 的 cron 配置源头（从 `0 */600 * * * *` 改为合法表达式如 `0 */10 * * *`）。

### 6.6 OPT-V8-10：ChangeDetector identityStatus 默认值实施（P1）

`src/app/services/sync/detector/ChangeDetector.cj` — 提供默认值 + None 容错。

---

## 七、v8 实施优先级与路线图

### Phase 1：P0 投研链路修复（立即）

| 序号 | 任务 | 预期效果 |
|------|------|---------|
| 1 | OPT-V8-1 CliTool stdout 编码根治 | agent 能正确识别 python 可用并执行脚本 |
| 2 | OPT-V8-2 web 端思维链显示根治 | 投研走 useReActMode，思维链显示 |
| 3 | OPT-V8-3 agent 遇挫即停根治 | stdout 解码失败时尝试替代方案而非停止 |
| 4 | OPT-V8-4 SQL 绑定根治 | 审计日志/元数据/计费/消息不再丢失 |
| 5 | OPT-V8-5 TieredMemory Embedding 配置或降级 | agent 记忆系统可用或降级 |
| 6 | OPT-V8-6 parser 工具名缺失根治 | 工具名缺失时返回明确错误 |

### Phase 2：P1 基础设施修复（高优先级）

| 序号 | 任务 | 预期效果 |
|------|------|---------|
| 7 | OPT-V8-7 filter lenient 解析 | filter 解析有 lenient 降级 |
| 8 | OPT-V8-8 verifyToken token 为 null 检查 | token 为 null 时返回明确错误 |
| 9 | OPT-V8-9 CRON 表达式源头修正 | system-health-check 不再报错 |
| 10 | OPT-V8-10 identityStatus 默认值实施 | ChangeDetector 不因 None 失败 |

---

## 八、v8 验证检查清单

修复完成后，请人工在单独 cmd 环境编译仓颉代码并运行 runtime，重新构建 web 前端产物，验证以下清单：

- [ ] agent 调用 `cli_execute` 执行 `python --version` 成功返回版本号（日志不再出现 `Invalid utf8 byte sequence`）
- [ ] agent 调用 `cli_execute` 执行 `python fetch_market_data.py` 成功抓取行情数据
- [ ] web 端对话提交后显示思维链折叠控件（投研走 useReActMode=true，_chatReActStream 转发 reasoning）
- [ ] agent 遇 stdout 解码失败时按替代方案清单尝试，不直接判定命令不可用
- [ ] 投研任务能完整执行六步 SOP：抓取 → 清洗 → 提取 → 生成 → 落库 → 简报
- [ ] `[AsyncLogWriter] 批量写入失败` 和 `[SchedulerEngine] 更新执行元数据失败` 不再出现（50+ 处 → 0）
- [ ] `BillingEventHandler` 和 `AgentPersistenceEventHandler` 的 SQL 错误不再出现
- [ ] `TieredMemory.search/update` 不再报 "Embedding model is not set"
- [ ] `Parsing action failed: tool name is missing` 不再出现
- [ ] `system-health-check` 的 cron 表达式合法
- [ ] `ChangeDetector` 不因 identityStatus=None 失败

---

## 九、v8 涉及文件清单（预期）

### 9.1 runtime 仓颉（Phase 1 + Phase 2）

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `src/tool/cli_tool.cj` | OPT-V8-1 | 修改：wrapForWindowsShell 加 chcp 65001 + stdout 编码 fallback |
| `src/app/services/webmcp/WebMCPProtocol.cj` | OPT-V8-3 | 修改：增加 stdout 解码失败替代方案清单 |
| `src/app/controllers/uctoo/ws/WsChatController.cj` | OPT-V8-3 | 修改：同步替代方案清单 |
| AsyncLogWriter 源码（待定位） | OPT-V8-4 | 修改：SQL 绑定根治 + 连接池 + 异步队列 |
| SchedulerEngine 源码 | OPT-V8-4 | 修改：SQL 绑定根治 |
| BillingEventHandler 源码（待定位） | OPT-V8-4 | 修改：SQL 绑定修复 |
| AgentPersistenceEventHandler 源码（待定位） | OPT-V8-4 | 修改：SQL 绑定修复 |
| `src/agent/memory/tiered/tiered_memory.cj` | OPT-V8-5 | 修改：model 未设置时降级 |
| `src/memory/short_memory.cj` | OPT-V8-5 | 修改：defaultEmbeddingModel 为 None 时降级 |
| `.env` / `.env.example` | OPT-V8-5 | 新增：Embedding model 配置项 |
| `src/parser/parser_utils.cj` | OPT-V8-6 | 修改：工具名缺失分支根治 |
| `src/app/core/query/RequestParserService.cj` | OPT-V8-7 | 修改：lenient 解析实施 |
| `src/app/services/crontab/SchedulerEngine.cj` | OPT-V8-9 | 修改：cron 源头修正 |
| `src/app/services/sync/detector/ChangeDetector.cj` | OPT-V8-10 | 修改：identityStatus 默认值 |

### 9.2 web 前端 TypeScript（Phase 1）

| 文件 | 优化项 | 操作 |
|------|--------|------|
| 投研任务模型配置 | OPT-V8-2 | 修改：useReActMode: true |
| `apps/web-admin/web/src/lib/webmcp-sdk/packages/next-sdk/agent/AgentModelProvider.ts` | OPT-V8-2 | 修改：确认 useReActMode 判定逻辑 |

---

## 附录：v1~v8 实施差异说明（含本轮实测）

| 维度 | v1 | v2 | v3 | v4 | v5 | v5 实测 | v6 实测 | v7 实测 | v8 实测 |
|------|----|----|----|----|----|----|----|----|----|
| **核心目标** | get_skill_content | ReAct 解析器 | Windows 命令 | skills 渐进式 | 全量基础设施 | 实测复核 | 投研链路根治 | 思维链根治+遇挫根治 | **stdout 编码根治 + useReActMode** |
| **覆盖范围** | 投研链路 | 投研链路 | 投研链路 | 投研链路 | 全量报错 | 实测复核 | 实测复核 | 实测复核 | **实测复核 + 编码根治** |
| **改动性质** | 新增功能 | 修复 bug | 修复环境 | 纠正设计 | 基础设施 | 纠正通道 | 根治 PATH | 根治超时+根治 fail | **根治 stdout + 根治 useReActMode** |

**关键结论**：本轮 v8 实测发现 v7 的 CliTool PATH 修复已生效，但**新发现仓颉读取进程 stdout 时按 UTF-8 解码，Windows cmd.exe 输出含 GBK 字符导致解码失败**，这是投研任务无法调用 python 的真正根因。同时发现思维链未显示的根因是投研任务未走 useReActMode=true。v8 完成后投研任务应能真正完整执行六步 SOP，且 web 端思维链显示能落地（投研走 useReActMode + stdout 编码根治）。

---

# 第九轮迭代实施方案（v9 实测，2026-08-11）

> **文档定位**：基于 v9 实测复核报告（report.md 第七十五至八十一节），针对本轮实测中**新发现根因和加剧重现**的问题制定修复方案。本轮**先更新文档再改代码**，代码修复后需人工在 cmd 环境编译仓颉代码并重新构建 web 前端产物。
>
> **核心原则**：沿用原有设计架构进行增量优化，每一项修复都基于本轮实测日志证据，不凭猜测。投研任务链路（思维链全链路根治、agent 误判已完成根治、WebMCP 通道 ReAct loop、FileReadTool 编码 fallback、Parse Error 容错）优先级最高。
>
> **日期**：2026-08-11 | **基于实测日志分析** | **覆盖 12 个问题点（RV9-01~RV9-19）**

---

## 一、v9 实测方案总览

| 编号 | 优化项 | 对应报告 | 优先级 | 方案策略 | 涉及文件数 |
|------|--------|---------|--------|---------|-----------|
| OPT-V9-1 | web 端思维链全链路根治（runtime 转发 reasoning_content + 前端提取独立字段） | RV9-13 | P0 高 | runtime WebMCPProtocol complete 转发 message.reasoning_content 到 completion 独立字段 + 前端 _chatViaWebMCP 提取独立字段 | 2~3 |
| OPT-V9-2 | 投研技能避免误判任务已完成（任务完成判定+旧产出清理） | RV9-14 | P0 高 | SKILL.md 增加任务完成判定段+旧产出清理段+fetch --force 参数 | 2 |
| OPT-V9-3 | agent 持续工作直至完成（WebMCP 通道 ReAct loop 或 useReActMode=true） | RV9-15 | P0 高 | 投研任务 useReActMode=true 或 _chatViaWebMCP 实现 WebMCP ReAct loop | 1~2 |
| OPT-V9-4 | FileReadTool 编码 fallback（UTF-8 失败则替换非法字符为 ?） | RV9-16 | P1 高 | file_tools.cj FileReadTool.executeRead 增加编码 fallback | 1 |
| OPT-V9-5 | RequestParserService filter lenient 解析 | RV9-17 | P1 中 | 非中文 JSON 格式时降级为空 filter 而非报错 | 1 |
| OPT-V9-6 | parser_utils 容错首尾空格（extractFirstJsonWithHeuristic trim） | RV9-18 | P0 中 | 提取 JSON 前先 trim 首尾空格/换行 | 1 |
| OPT-V9-7 | parser_utils 工具名缺失容错 | RV9-19 | P0 中 | 工具名缺失时返回明确错误而非抛异常 | 1 |
| OPT-V9-8 | TieredMemory Embedding 配置或降级 | RV9-03,04 | P0 高 | 配置 Embedding model 或降级为关键词检索 | 2~3 |
| OPT-V9-9 | SQL 绑定根治（AsyncLogWriter/SchedulerEngine/Billing 残留） | RV9-02,07,09 | P1 高 | 逐一核对残留 SQL 绑定 | 3~5 |
| OPT-V9-10 | verifyToken token 为 null 检查 | RV9-06 | P1 中 | 检查前端 token 传递，null 时返回明确错误 | 1~2 |
| OPT-V9-11 | ChangeDetector identityStatus 默认值实施 | RV9-12 | P1 中 | 提供默认值 + None 容错 | 1 |

---

## 二、OPT-V9-1：web 端思维链全链路根治（P0，前八轮未根治）

### 2.1 问题根因（日志证据）

本轮 deepseek API 的 response body 明确含 `"reasoning_content":"我们需要回顾..."` 且 `"finish_reason":"stop"`——runtime 端已正确返回。但前端走 `_chatViaWebMCP` 通道，该通道从 `result.completion.values[0]`（字符串数组）提取 reasoning_content——**values 是字符串数组不是对象，无法用 `.reasoning_content` 字段提取**。

全链路 7 节点中 6 节点已通（deepseek API 返回、runtime 转发、streamVisitor、CustomAgentModelProvider、contentRenderer、BubbleThinkingRenderer），**唯一断在节点③**：前端 `_chatViaWebMCP` 的 reasoning 提取逻辑从 `result.completion` 对象的 `.reasoning_content` 字段提取——但 WebMCP 协议的 `result.completion` 是 `{values: [string], total: int, hasMore: bool}` 结构，`values[0]` 是纯文本（agent 的 answer 内容），**不含 reasoning_content 字段**。

### 2.2 修复方案

**改动点 1**：runtime `src/app/services/webmcp/WebMCPProtocol.cj` 的 complete 方法增加转发 `message.reasoning_content` 到 completion 对象的独立字段

```cangjie
// 伪代码
let completion = {
    "values": [message.content],  // 已有
    "total": 1,
    "hasMore": false,
    "reasoning_content": message.reasoning_content  // v9 新增独立字段
}
```

**改动点 2**：前端 `AgentModelProvider.ts` 的 `_chatViaWebMCP` 从 `result.completion.reasoning_content` 独立字段提取（非 `values[0]`）

```typescript
// 修复前（values[0] 是字符串，无 .reasoning_content 字段）
let reasoningContent = result.completion.values[0].reasoning_content  // ❌ undefined

// 修复后（从 completion 独立字段提取）
let reasoningContent = result.completion.reasoning_content || result.reasoning_content || ''
```

---

## 三、OPT-V9-2：投研技能避免误判任务已完成（P0，新发现根因）

### 3.1 问题根因（日志证据）

agent 的 `dir /s /b` 列目录发现 `output\brief\2026-08-11.md`（旧研报，2026-08-11 日）→ 在后续 thinking 中混淆了日期（用户要 2026.08.10，但目录里有 08.11 的旧研报）→ agent 最终 answer 说"已使用 investment-research-assistant 技能生成昨日（2026-08-10）3家热点公司投研简报"——**但实际 SOP 全步并未真正执行**，agent 只看了目录有旧文件就误判任务已完成。

### 3.2 修复方案

**改动点 1**：`SKILL.md` 增加"任务完成判定"段

```markdown
## 任务完成判定（必须遵守）

- **不能因目录有旧研报文件就误判任务已完成**——必须检查产出文件的日期是否匹配用户要求
- 必须实际执行六步 SOP 并确认每步的产出文件存在且内容为本次生成
- 只有 `output/brief/{用户要求日期}.md` 文件存在且内容包含本次抓取的数据才算完成
- 如发现目录有旧日期的研报文件，应忽略（非本次产出），继续执行 SOP
```

**改动点 2**：`SKILL.md` 增加"旧产出清理"段

```markdown
## 旧产出清理（建议）

- 运行 SOP 前可清理 `output/` 目录下的旧文件，避免误判
- 或用 `fetch_market_data.py --force` 覆盖旧产出文件
```

**改动点 3**：`fetch_market_data.py` 增加 `--force` 参数覆盖旧产出

---

## 四、OPT-V9-3：agent 持续工作直至完成（P0，WebMCP 通道无 ReAct loop）

### 4.1 问题根因（日志证据）

本轮实测 agent 走的是 **WebMCP 通道**（`finish_reason:"stop"`），WebMCP 通道的 `complete` 方法是**单次调用返回完整响应**——agent 在单次 LLM 调用中生成了 `<answer>` 标签总结已完成步骤后直接停止。**WebMCP 通道没有 ReAct loop 机制**，maxSteps/loopMax/遇错重试等长程任务配置全在 ReAct 通道（`_chatReActStream`）中，WebMCP 通道完全绕过。

### 4.2 修复方案

**改动点 1**：投研任务配置 `useReActMode: true`，走 `_chatReActStream`（有 ReAct loop 机制）

**改动点 2**：如果 useReActMode 无法开启，需在 `_chatViaWebMCP` 中实现 WebMCP 通道的 ReAct loop——多次调用 complete 方法，每次检查 agent 是否生成 `<answer>`，未生成则继续调用

---

## 五、OPT-V9-4：FileReadTool 编码 fallback（P1，新发现）

### 5.1 问题根因

v8 新建的 `scripts/README.md`（2934 bytes）被 FileReadTool 读取时返回空——仓颉 `File.readFrom` 按 UTF-8 解码，README.md 含中文字符，UTF-8 解码可能失败返回空。

### 5.2 修复方案

`src/tool/file_tools.cj` 的 FileReadTool.executeRead 增加编码 fallback：UTF-8 失败则替换非法字符为 `?` 后返回（非空），避免 agent 误判文件为空。

---

## 六、OPT-V9-5~7：Parse Error 容错（P0/P1）

### 6.1 OPT-V9-5：RequestParserService filter lenient 解析

非中文 JSON 格式时降级为空 filter 而非报错（同 v8 方案）。

### 6.2 OPT-V9-6：parser_utils 容错首尾空格

`extractFirstJsonWithHeuristic` 提取 JSON 前先 trim 首尾空格/换行，解决 agent 输出 `<action> {...} </action>`（JSON 前后有空格）的解析失败。

### 6.3 OPT-V9-7：parser_utils 工具名缺失容错

工具名缺失时返回明确错误让 agent 能继续处理，而非抛异常。

---

## 七、v9 实施优先级与路线图

### Phase 1：P0 投研链路修复（立即）

| 序号 | 任务 | 预期效果 |
|------|------|---------|
| 1 | OPT-V9-1 web 端思维链全链路根治 | 投研走 WebMCP 通道也能显示思维链 |
| 2 | OPT-V9-2 投研技能避免误判任务已完成 | agent 不因旧研报文件误判完成 |
| 3 | OPT-V9-3 agent 持续工作直至完成 | agent 走 ReAct loop 完整执行六步 SOP |
| 4 | OPT-V9-6 parser_utils 容错首尾空格 | agent 输出 JSON 前后有空格时不报错 |
| 5 | OPT-V9-7 parser_utils 工具名缺失容错 | 工具名缺失时返回明确错误 |
| 6 | OPT-V9-8 TieredMemory Embedding 配置或降级 | agent 记忆系统可用或降级 |

### Phase 2：P1 基础设施修复（高优先级）

| 序号 | 任务 | 预期效果 |
|------|------|---------|
| 7 | OPT-V9-4 FileReadTool 编码 fallback | 读取中文文件不返回空 |
| 8 | OPT-V9-5 filter lenient 解析 | filter 非中文时不报错 |
| 9 | OPT-V9-9 SQL 绑定根治（残留） | 审计日志/元数据/计费不再丢失 |
| 10 | OPT-V9-10 verifyToken token 为 null 检查 | token 为 null 时返回明确错误 |
| 11 | OPT-V9-11 identityStatus 默认值实施 | ChangeDetector 不因 None 失败 |

---

## 八、v9 验证检查清单

修复完成后，请人工在单独 cmd 环境编译仓颉代码并运行 runtime，重新构建 web 前端产物，验证以下清单：

- [ ] web 端对话提交后显示思维链折叠控件（投研走 WebMCP 通道也能显示，因 runtime 转发 reasoning_content 到 completion 独立字段 + 前端提取独立字段）
- [ ] agent 不因目录有旧研报文件就误判任务已完成（SKILL.md 任务完成判定段生效）
- [ ] agent 走 ReAct loop 完整执行六步 SOP（useReActMode=true 或 WebMCP ReAct loop）
- [ ] agent 调用 `file_read` 读取 `scripts/README.md` 成功返回内容（非空，编码 fallback 生效）
- [ ] `Parsing action failed: There is NO JSON output in the string` 不再出现（parser 容错首尾空格）
- [ ] `Parsing action failed: tool name is missing` 不再出现（parser 工具名缺失容错）
- [ ] `[RequestParserService] Failed to parse filter JSON` 不再出现（lenient 解析）
- [ ] `TieredMemory.search/update` 不再报 "Embedding model is not set"
- [ ] `[AsyncLogWriter] 批量写入失败` 和 `[SchedulerEngine] 更新执行元数据失败` 残留处不再出现
- [ ] `ChangeDetector` 不因 identityStatus=None 失败

---

## 九、v9 涉及文件清单（预期）

### 9.1 runtime 仓颉（Phase 1 + Phase 2）

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `src/app/services/webmcp/WebMCPProtocol.cj` | OPT-V9-1 | 修改：complete 方法转发 message.reasoning_content 到 completion 独立字段 |
| `src/tool/file_tools.cj` | OPT-V9-4 | 修改：FileReadTool.executeRead 编码 fallback |
| `src/parser/parser_utils.cj` | OPT-V9-6,7 | 修改：extractFirstJsonWithHeuristic trim 首尾空格 + 工具名缺失容错 |
| `src/app/core/query/RequestParserService.cj` | OPT-V9-5 | 修改：filter lenient 解析 |
| `src/agent/memory/tiered/tiered_memory.cj` | OPT-V9-8 | 修改：model 未设置时降级 |
| `src/memory/short_memory.cj` | OPT-V9-8 | 修改：defaultEmbeddingModel 为 None 时降级 |
| AsyncLogWriter 源码 | OPT-V9-9 | 修改：残留 SQL 绑定根治 |
| SchedulerEngine 源码 | OPT-V9-9 | 修改：残留 SQL 绑定根治 |
| `src/app/services/sync/detector/ChangeDetector.cj` | OPT-V9-11 | 修改：identityStatus 默认值 |

### 9.2 web 前端 TypeScript（Phase 1）

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `apps/web-admin/web/src/lib/webmcp-sdk/packages/next-sdk/agent/AgentModelProvider.ts` | OPT-V9-1,3 | 修改：_chatViaWebMCP 提取 reasoning_content 独立字段 + 投研 useReActMode=true |

### 9.3 投研技能（Phase 1）

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `skills/investment-research-assistant/SKILL.md` | OPT-V9-2 | 修改：增加任务完成判定段+旧产出清理段 |
| `skills/investment-research-assistant/scripts/fetch_market_data.py` | OPT-V9-2 | 修改：增加 --force 参数 |

---

## 附录：v1~v9 实施差异说明（含本轮实测）

| 维度 | v1 | v2 | v3 | v4 | v5 | v5 实测 | v6 实测 | v7 实测 | v8 实测 | v9 实测 |
|------|----|----|----|----|----|----|----|----|----|----|
| **核心目标** | get_skill_content | ReAct 解析器 | Windows 命令 | skills 渐进式 | 全量基础设施 | 实测复核 | 投研链路根治 | 思维链根治+遇挫根治 | stdout 编码根治 | **思维链全链路根治+误判已完成根治** |
| **ERROR 趋势** | — | — | — | — | 61→10 | 10→24 | 24→68 | 68→72 | 72→26 | **预期 26→0**（SQL 绑定根治后） |
| **改动性质** | 新增功能 | 修复 bug | 修复环境 | 纠正设计 | 基础设施 | 纠正通道 | 根治 PATH | 根治超时+根治 fail | 根治 stdout | **根治 reasoning 转发+根治误判** |

**关键结论**：本轮 v9 实测发现 v8 的 stdout 编码根治已生效（agent 成功识别 Python 3.14.7），SQL 绑定根治已大幅降报错（AsyncLogWriter 降 80%、SchedulerEngine 降 94%、Billing 降 50%）。但**本轮新发现 4 大根因**：①web 端思维链走 WebMCP 通道但前端从 `values[0]` 字符串数组无法提取 reasoning_content（全链路 7 节点中断在节点③）；②agent 误判任务已完成（混淆日期+看到旧研报文件）；③FileReadTool 读取 README.md 返回空（编码问题）；④agent 走 WebMCP 通道无 ReAct loop 机制，阶段总结后直接停止。v9 完成后投研任务应能真正完整执行六步 SOP，且 web 端思维链显示能落地（runtime 转发 reasoning_content 到 completion 独立字段 + 前端提取独立字段）。

---

# 第十轮迭代实施方案（v10 实测，2026-08-12）

> **文档定位**：基于 v10 实测复核报告（report.md 第八十二至八十七节），针对本轮实测中**新发现根因和加剧重现**的问题制定修复方案。本轮**先更新文档再改代码**，代码修复后需人工在 cmd 环境编译仓颉代码并重新构建 web 前端产物。
>
> **核心原则**：沿用原有设计架构进行增量优化，每一项修复都基于本轮实测日志证据，不凭猜测。投研任务链路（思维链 remote-mcp-server 转发根治、FileReadTool 编码 fallback 根治、agent ReAct loop 根治）优先级最高。
>
> **日期**：2026-08-12 | **基于实测日志分析** | **覆盖 11 个问题点（RV10-01~RV10-15）**

---

## 一、v10 实测方案总览

| 编号 | 优化项 | 对应报告 | 优先级 | 方案策略 | 涉及文件数 |
|------|--------|---------|--------|---------|-----------|
| OPT-V10-1 | web 端思维链根治（remote-mcp-server 同步转发 reasoning_content） | RV10-12 | P0 高 | 定位远程 MCP server complete 方法同步转发 reasoning_content 到 completion 独立字段 | 1~2 |
| OPT-V10-2 | FileReadTool 编码 fallback（剥 UTF-8 BOM + 替换非法字符） | RV10-13 | P0 高 | file_tools.cj FileReadTool.executeRead 增加编码 fallback | 1 |
| OPT-V10-3 | agent 持续工作直至完成（useReActMode=true 或远程 MCP server ReAct loop） | RV10-14 | P0 高 | 投研任务 useReActMode=true 走 _chatReActStream，或远程 MCP server 实现 ReAct loop | 1~2 |
| OPT-V10-4 | 投研技能增加显式脚本执行命令示例段 | RV10-15 | P0 高 | SKILL.md 增加脚本执行的显式命令示例段，让 agent 即使不读完整 SOP 也能从系统提示中知道如何执行 | 1 |
| OPT-V10-5 | parser 工具名缺失容错（`/s` 误解析为工具名） | RV10-08 | P0 中 | parser_utils 工具名缺失时返回明确错误而非误解析 | 1 |
| OPT-V10-6 | TieredMemory Embedding 配置或降级 | RV10-05,06 | P0 高 | 配置 Embedding model 或降级为关键词检索 | 2~3 |
| OPT-V10-7 | SQL 绑定根治（AsyncLogWriter/SchedulerEngine 残留） | RV10-02,03 | P1 高 | 逐一核对残留 SQL 绑定 | 3~5 |
| OPT-V10-8 | verifyToken token 为 null 检查 | RV10-01 | P1 中 | 检查前端 token 传递，null 时返回明确错误 | 1~2 |
| OPT-V10-9 | RequestParserService filter lenient 解析 | RV10-04 | P1 中 | 非 JSON 格式时降级为空 filter 而非报错 | 1 |
| OPT-V10-10 | FileSearchTool 目录成员获取失败修复 | RV10-07 | P1 中 | 检查目录路径有效性 + 容错 | 1 |
| OPT-V10-11 | ChangeDetector identityStatus 默认值实施 | RV10-11 | P1 中 | 提供默认值 + None 容错 | 1 |

---

## 二、OPT-V10-1：web 端思维链根治（P0，前九轮未根治的真正根因）

### 2.1 问题根因（日志证据）

本轮 web_console.md 第 45 行：`使用聊天客户端: remote-mcp-server`——前端用的是**远程 MCP server** 而非 builtin-webmcp。v9 只改了 builtin WebMCPProtocol.cj 转发 reasoning_content 到 completion 独立字段，**未改远程 MCP server 的响应结构**。

deepseek API 明确返回 `"reasoning_content":"用户要求生成3家热点公司..."`（日志第 1827、2643 行），runtime 端已正确返回，但远程 MCP server 的 complete 方法返回的 `result.completion` 可能不含 v9 新增的 `reasoning_content` 独立字段。

### 2.2 修复方案

**改动点 1**：定位远程 MCP server 的 complete 方法实现代码

远程 MCP server 是前端通过 `mcpClients['remote-mcp-server']` 获取的客户端，其 `complete` 方法指向 runtime 的某个 MCP 协议端点。需定位该端点的实现代码，确认其响应结构是否含 reasoning_content 独立字段。

**改动点 2**：如果不含，同步转发 reasoning_content 到 completion 独立字段

---

## 三、OPT-V10-2：FileReadTool 编码 fallback（P0，投研链路断链根因）

### 3.1 问题根因（日志证据，3 处 WARN）

```
WARN [FileReadTool] File exists (size: 14328 bytes) but readFile returned empty, possible encoding issue: SKILL.md
WARN [FileReadTool] File exists (size: 2044 bytes) but readFile returned empty, possible encoding issue: COMPOSITION.yaml
WARN [FileReadTool] File exists (size: 2934 bytes) but readFile returned empty, possible encoding issue: README.md
```

agent 的 reasoning_content 明确说："SKILL.md 文件存在（14328 字节）但有编码问题（UTF-8 BOM 导致 content 为空）"。

**这是投研任务无法渐进式加载 SOP 的真正根因**——agent 通过 `file_read` 读取 SKILL.md 获取技能说明时收到空内容，误判技能内容为空，无法执行六步 SOP。

### 3.2 修复方案

`src/tool/file_tools.cj` 的 FileReadTool.executeRead 增加编码 fallback：
1. 读取原始字节后先检测并剥离 UTF-8 BOM（`EF BB BF` 首三字节）
2. UTF-8 解码失败则替换非法字符为 `?` 后返回（非空）
3. 或改用容错解码方式（如仓颉支持 `errors: "replace"` 参数）

---

## 四、OPT-V10-3：agent 持续工作直至完成（P0，远程 MCP server 总结者角色）

### 4.1 问题根因（日志证据）

agent 的系统提示明确是**总结者角色**（`Given a question and a solving procedure, summarize an answer`），而非执行者角色。agent 在总结解决过程后生成 `<answer>` 直接 `finish_reason:"stop"`，无 ReAct loop 机制让它继续执行未完成的 SOP。

本轮 agent 走的是 **远程 MCP server 的 complete 单次调用**，而非 runtime 内部的 ReAct loop。v7~v9 的 maxSteps 5→50、遇错重试 3 次、failureObservation 加入消息历史等修复**全在 `_chatReActStream`（ReAct 通道）**，但投研任务实际走 `_chatViaWebMCP`（WebMCP 通道）的远程 MCP server，所有长程任务配置未生效。

### 4.2 修复方案

**改动点 1**：投研任务配置 `useReActMode: true`，走 `_chatReActStream`（有 ReAct loop 机制）

**改动点 2**：如果 useReActMode 无法开启，需在远程 MCP server 的 complete 方法中实现 ReAct loop——多次调用 LLM，每次检查 agent 是否生成 `<answer>`，未生成则继续调用

**改动点 3**：远程 MCP server 的系统提示从"总结者角色"改为"执行者角色"，让 agent 知道应继续执行 SOP 直至完成而非总结停止

---

## 五、OPT-V10-4：投研技能增加显式脚本执行命令示例段（P0，让 agent 即使不读完整 SOP 也能执行）

### 5.1 问题根因

agent 全程从未实际调用任何投研脚本（只列了目录就进入总结停止）。根因之一是 FileReadTool 读取 SKILL.md 返回空，agent 无法渐进式加载 SOP 和脚本接口说明。

### 5.2 修复方案

SKILL.md 增加脚本执行的**显式命令示例段**，让 agent 即使不读完整 SOP 也能从系统提示中知道如何执行脚本：

```markdown
## 脚本执行显式命令示例（v10 新增，即使不读完整 SOP 也可直接执行）

# 抓取行情（必填 --companies，支持代码或名称）
cli_execute({"command": "python", "args": ["scripts/fetch_market_data.py", "--companies", "600519,000858,300750", "--date", "2026-08-12", "--force"]})

# 清洗数据
cli_execute({"command": "python", "args": ["scripts/clean_market_data.py", "--input", "output/raw/2026-08-12.json"]})

# 提取要素
cli_execute({"command": "python", "args": ["scripts/extract_factors.py", "--input", "output/clean/2026-08-12.json"]})

# 生成研报
cli_execute({"command": "python", "args": ["scripts/generate_report.py", "--factors", "output/factors/2026-08-12.json"]})

# 落库（仅生成 SQL 文件）
cli_execute({"command": "python", "args": ["scripts/save_report_to_db.py", "--report", "output/brief/2026-08-12.md", "--factors", "output/factors/2026-08-12.json", "--sql-only"]})
```

---

## 六、OPT-V10-5~11：次要问题修复（P0/P1）

### 6.1 OPT-V10-5：parser 工具名缺失容错（`/s` 误解析为工具名）

`src/parser/parser_utils.cj` — agent 输出 `dir /s /b` 命令时 JSON 解析误判 `/s` 为工具名，需工具名缺失时返回明确错误而非误解析。

### 6.2 OPT-V10-6：TieredMemory Embedding 配置或降级（P0）

配置 Embedding model 或降级为关键词检索（同 v9 方案，需确认是否已实施）。

### 6.3 OPT-V10-7：SQL 绑定根治（P1）

AsyncLogWriter/SchedulerEngine 残留 SQL 绑定根治（v9 已降 80%~94%，本轮残留处需逐一核对）。

### 6.4 OPT-V10-8：verifyToken token 为 null 检查（P1）

`first 20 chars: null` 说明 token 为 null 而非截断，需检查前端是否传了 token。

### 6.5 OPT-V10-9：RequestParserService filter lenient 解析（P1）

非 JSON 格式时降级为空 filter 而非报错。

### 6.6 OPT-V10-10：FileSearchTool 目录成员获取失败修复（P1）

检查目录路径有效性 + 容错。

### 6.7 OPT-V10-11：ChangeDetector identityStatus 默认值实施（P1）

`src/app/services/sync/detector/ChangeDetector.cj` — 提供默认值 + None 容错。

---

## 七、v10 实施优先级与路线图

### Phase 1：P0 投研链路修复（立即）

| 序号 | 任务 | 预期效果 |
|------|------|---------|
| 1 | OPT-V10-2 FileReadTool 编码 fallback | agent 能正确读取 SKILL.md 获取 SOP 和脚本接口说明 |
| 2 | OPT-V10-3 agent 持续工作直至完成 | agent 走 ReAct loop 完整执行六步 SOP |
| 3 | OPT-V10-4 投研技能增加显式脚本执行命令示例段 | agent 即使不读完整 SOP 也能从系统提示中知道如何执行脚本 |
| 4 | OPT-V10-1 web 端思维链根治（remote-mcp-server） | 投研走 remote-mcp-server 也能显示思维链 |
| 5 | OPT-V10-5 parser 工具名缺失容错 | `dir /s` 命令时不误解析为工具名 |
| 6 | OPT-V10-6 TieredMemory Embedding 配置或降级 | agent 记忆系统可用或降级 |

### Phase 2：P1 基础设施修复（高优先级）

| 序号 | 任务 | 预期效果 |
|------|------|---------|
| 7 | OPT-V10-7 SQL 绑定根治（残留） | 审计日志/元数据不再丢失 |
| 8 | OPT-V10-8 verifyToken token 为 null 检查 | token 为 null 时返回明确错误 |
| 9 | OPT-V10-9 filter lenient 解析 | filter 非 JSON 时不报错 |
| 10 | OPT-V10-10 FileSearchTool 目录成员获取失败修复 | 目录搜索不报错 |
| 11 | OPT-V10-11 identityStatus 默认值实施 | ChangeDetector 不因 None 失败 |

---

## 八、v10 验证检查清单

修复完成后，请人工在单独 cmd 环境编译仓颉代码并运行 runtime，重新构建 web 前端产物，验证以下清单：

- [ ] agent 调用 `file_read` 读取 `SKILL.md` 成功返回内容（非空，编码 fallback 生效）
- [ ] agent 调用 `cli_execute` 运行 `python scripts/fetch_market_data.py --companies "600519,000858,300750" --force` 成功抓取行情
- [ ] agent 走 ReAct loop 完整执行六步 SOP（不因总结后直接停止）
- [ ] web 端对话提交后显示思维链折叠控件（remote-mcp-server 同步转发 reasoning_content）
- [ ] `Parsing action failed: tool name is missing` 不再出现（`/s` 不误解析为工具名）
- [ ] `TieredMemory.search/update` 不再报 "Embedding model is not set"
- [ ] `[AsyncLogWriter] 批量写入失败` 和 `[SchedulerEngine] 更新执行元数据失败` 残留处不再出现
- [ ] `ChangeDetector` 不因 identityStatus=None 失败

---

## 九、v10 涉及文件清单（预期）

### 9.1 runtime 仓颉（Phase 1 + Phase 2）

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `src/tool/file_tools.cj` | OPT-V10-2 | 修改：FileReadTool.executeRead 编码 fallback（剥 BOM + 替换非法字符） |
| `src/parser/parser_utils.cj` | OPT-V10-5 | 修改：工具名缺失时返回明确错误而非误解析 |
| `src/agent/memory/tiered/tiered_memory.cj` | OPT-V10-6 | 修改：model 未设置时降级 |
| `src/memory/short_memory.cj` | OPT-V10-6 | 修改：defaultEmbeddingModel 为 None 时降级 |
| AsyncLogWriter 源码 | OPT-V10-7 | 修改：残留 SQL 绑定根治 |
| SchedulerEngine 源码 | OPT-V10-7 | 修改：残留 SQL 绑定根治 |
| `src/app/services/sync/detector/ChangeDetector.cj` | OPT-V10-11 | 修改：identityStatus 默认值 |
| 远程 MCP server complete 方法源码（待定位） | OPT-V10-1,3 | 修改：同步转发 reasoning_content + 实现 ReAct loop |

### 9.2 web 前端 TypeScript（Phase 1）

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `apps/web-admin/web/src/lib/webmcp-sdk/packages/next-sdk/agent/AgentModelProvider.ts` | OPT-V10-3 | 修改：投研任务 useReActMode=true 走 _chatReActStream |

### 9.3 投研技能（Phase 1）

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `skills/investment-research-assistant/SKILL.md` | OPT-V10-4 | 修改：增加脚本执行显式命令示例段 |

---

## 附录：v1~v10 实施差异说明（含本轮实测）

| 维度 | v1 | v2 | v3 | v4 | v5 | v5 实测 | v6 实测 | v7 实测 | v8 实测 | v9 实测 | v10 实测 |
|------|----|----|----|----|----|----|----|----|----|----|----|
| **核心目标** | get_skill_content | ReAct 解析器 | Windows 命令 | skills 渐进式 | 全量基础设施 | 实测复核 | 投研链路根治 | 思维链根治+遇挫根治 | stdout 编码根治 | 思维链全链路+误判根治 | **FileReadTool 编码+remote-mcp-server 思维链+ReAct loop** |
| **ERROR 趋势** | — | — | — | — | 61→10 | 10→24 | 24→68 | 68→72 | 72→26 | 26→50 | **预期 50→0**（SQL 绑定根治后） |
| **改动性质** | 新增功能 | 修复 bug | 修复环境 | 纠正设计 | 基础设施 | 纠正通道 | 根治 PATH | 根治超时+根治 fail | 根治 stdout | 根治 reasoning 转发 | **根治 FileReadTool 编码+根治 remote-mcp-server 思维链** |

**关键结论**：本轮 v10 实测发现 v9 的 runtime 端 reasoning_content 转发已生效，但前端走 **remote-mcp-server** 而非 builtin-webmcp，远程 MCP server 的响应结构可能不含独立字段。本轮**新发现 3 大根因**：①FileReadTool 读取含 UTF-8 BOM 的中文文件返回空（SKILL.md/COMPOSITION.yaml/README.md 均3处）→ agent 误判技能内容为空无法渐进式加载 SOP；②远程 MCP server 把 agent 当总结者用单次 complete 调用，绕过了 runtime 内部的 ReAct loop；③agent 全程从未实际调用任何投研脚本（只列了目录就进入总结停止）。v10 完成后投研任务应能真正完整执行六步 SOP，且 web 端思维链显示能落地（remote-mcp-server 同步转发 reasoning_content + FileReadTool 编码 fallback + agent 走 ReAct loop）。

---

## 第11轮优化方案（v11）：全链路思维链 + 硬编码提示词重构 + 长程任务持续执行

> **日期**：2026-08-12 | **基于 v10 实测日志独立分析** | **覆盖用户4项需求**

### 11.1 v10 实测复核结论

| 维度 | v10 状态 | 根因 |
|------|---------|------|
| 思维链显示 | ❌ 仍未显示 | 前端streamVisitor.ts读`event.text`，AgentModelProvider发`delta`字段，字段名不匹配 |
| 硬编码提示词 | ❌ 大量存在 | WebMCPProtocol.cj和WsChatController.cj中有~90行重复硬编码系统提示词 |
| agent执行SOP | ❌ 阶段性返回 | AgentExecutionExecutor是单步执行器，缺少多步循环+CheckpointManager未接入 |
| 投研脚本 | ⚠️ 有5个bug | code错配、PE/PB归一化、新闻未抓取、token硬编码、SQL转义不完整 |
| 内置工具 | ⚠️ 文档不一致 | 文档缺8个工具、多列firecrawl、getToolNames漏返2个 |

### 11.2 OPT-8：思维链全链路显示修复（前端字段名匹配）

**根因**：前端`streamVisitor.ts:124`读`event.text`，但`AgentModelProvider.ts:1021`发`6字段名`delta`，导致reasoning内容无法累加。

**修复方案**：修改`streamVisitor.ts`第124行，兼容`delta`和`text`两种字段名：
```typescript
case 'reasoning-delta':
  reasoningContent!.text += (event as any).delta || (event as any).text || ''
```

**涉及文件**（前端web-admin项目）：
- `apps/web-admin/web/src/lib/webmcp-sdk/packages/next-remoter/src/composable/streamVisitor.ts`

### 11.3 OPT-9：硬编码提示词重构到可配置文件

**根因**：WebMCPProtocol.cj:1411-1498和WsChatController.cj:274-380有~90行重复硬编码系统提示词，违反"不硬编码基础设施"设计原则。

**修复方案**：
1. 在`AGENTS.md`中定义所有系统提示词模板（已有AGENTS.md基础设施）
2. 在`src/config/prompt_config.cj`中创建PromptConfig类，从AGENTS.md或.env加载提示词
3. WebMCPProtocol.cj和WsChatController.cj改为从PromptConfig读取

**涉及文件**：
- `AGENTS.md` - 追加系统提示词配置段
- `src/config/prompt_config.cj` - 新建：提示词配置加载
- `src/app/services/webmcp/WebMCPProtocol.cj` - 修改：从PromptConfig读取
- `src/app/controllers/uctoo/ws/WsChatController.cj` - 修改：从PromptConfig读取

### 11.4 OPT-10：长程任务持续执行（AgentExecutionExecutor多步循环）

**根因**：AgentExecutionExecutor只调用一次`agent.chat(request)`就返回，缺少多步循环和CheckpointManager接入。

**修复方案**：
1. 在AgentExecutionExecutor中接入CheckpointManager
2. 实现多步循环：执行前loadCheckpoint → agent.chat → saveCheckpoint → 检查SOP完成判定 → 未完成则继续
3. 增加maxSteps配置防止无限循环

**涉及文件**：
- `src/app/services/crontab/executor/AgentExecutionExecutor.cj` - 修改：接入CheckpointManager + 多步循环

### 11.5 OPT-11：投研脚本bug修复

| Bug | 修复方案 |
|-----|---------|
| save_report_to_db.py多公司code错配 | 按当前section公司名匹配factors.companies中的code |
| clean_market_data.py PE/PB归一化 | 按字段分别确认单位换算系数 |
| fetch_market_data.py未抓取新闻 | 实现news抓取或更新SKILL.md说明 |
| token硬编码 | 改为从环境变量读取 |
| SQL转义不完整 | 补充反斜杠转义 |

### 11.6 OPT-12：内置工具文档同步

- 更新builtin-tools.md补全8个缺失工具
- 移除firecrawl文档
- 修复getToolNames()补返SubAgentTool和EvalRunnerTool

### 11.7 验收标准

- [ ] **OPT-8**：web端聊天界面显示思维链折叠区域，点击可展开查看reasoning内容
- [ ] **OPT-9**：WebMCPProtocol.cj和WsChatController.cj中无硬编码提示词（>50字符的字符串字面量）
- [ ] **OPT-10**：agent执行投研任务时连续执行6步SOP，不再阶段性返回
- [ ] **OPT-11**：投研脚本5个bug全部修复
- [ ] **OPT-12**：builtin-tools.md与registerAll()完全一致

---

# 第十一轮迭代实施方案（v11 实测，2026-08-12）

> **文档定位**：基于 v11 实测复核报告（report.md 第八十八至九十节），针对 v10 引入的聊天接口 bug 和提示词重构错误制定修复方案。本轮**先更新文档再改代码**，代码修复后需人工在 cmd 环境编译仓颉代码并重新构建 web 前端产物。
>
> **日期**：2026-08-12 | **基于实测日志分析** | **覆盖 2 个问题点（RV11-01~RV11-02）**

---

## 一、v11 实测方案总览

| 编号 | 优化项 | 对应报告 | 优先级 | 方案策略 | 涉及文件数 |
|------|--------|---------|--------|---------|-----------|
| OPT-V11-1 | 回滚 v10 前端强制 ReAct 改动（`_forceReActForLongTask`） | RV11-01 | P0 高 | 删除 `_chat` 入口投研关键词检测段 + 构造器赋值 + 声明 | 1 |
| OPT-V11-2 | 提示词从 prompt_config.cj 迁至 AGENTS.md | RV11-02 | P0 高 | AGENTS.md 追加提示词段 + `skillGuideSection()` 返回空串 | 2 |

---

## 二、OPT-V11-1：回滚 v10 前端强制 ReAct 改动（P0，聊天接口 bug 根因）

### 2.1 问题根因（日志证据）

`web_console.md` 第 49~50 行：`McpError -32001 Request timed out`

v10 在 `AgentModelProvider.ts` 的 `_chat` 入口追加了投研关键词检测逻辑——当 `messages` 含 `investment-research`/`投研`/`研报`/`SOP`/`fetch_market_data` 等关键词时**强制 `useReActMode=true`** 走 `_chatReAct` 通道。但 `_chatReAct` 通道依赖的 ReAct loop 基础设施在 runtime 端可能未完备，导致请求超时报 `McpError -32001`。

此外 v10 在构造器中无条件设置 `this._forceReActForLongTask = true`——这意味着**所有对话**都会触发关键词检测，即使非投研任务也可能误命中，导致正常对话也被强制走 ReAct 通道超时。

### 2.2 修复方案

**回滚 v10 的前端强制 ReAct 改动**：
1. 删除 `_chat` 入口的投研关键词检测段（第 1297~1304 行）
2. 删除构造器中的 `this._forceReActForLongTask = true` 赋值（第 99~104 行）
3. 删除 `private _forceReActForLongTask: boolean = false` 声明（第 107~108 行）

**保留 v10 的其他改动**（非 bug）：
- `WsChatController.cj` 的 reasoning_content 字段名对齐
- `AgentModelProvider.ts` 非流式分支提取 reasoning_content（6 处 fallback）
- `file_tools.cj` 的 FileReadTool 编码 fallback
- `parser_utils.cj` 的工具名容错

---

## 三、OPT-V11-2：提示词从 .cj 硬编码迁至 AGENTS.md（P0，重构错误纠正）

### 3.1 问题根因

v10 将提示词硬编码在 `prompt_config.cj` 中——这仍是静态的，与之前在 WebMCPProtocol.cj/WsChatController.cj 中硬编码无本质区别。按 runtime 设计理念，主 Agent 从 `AGENTS.md` 加载（`main.cj` 第 213~228 行的 `loadFromDirs` + `getMainAgent`），`AgentLoader.loadAgentsMd()` 解析 markdown 内容作为 `systemPrompt`（`design.md` 第 469~503 行）。

### 3.2 修复方案

1. **AGENTS.md 追加提示词段**：在末尾追加"工具调用引导"段（http_request 说明 + 工具调用格式说明 + 遇挫不停原则 + stdout 解码失败替代方案清单 + 数据库查询能力 + 脚本执行优先原则），主 Agent 加载时自动注入 systemPrompt
2. **prompt_config.cj 降级为空实现**：`skillGuideSection()` 改返回空串 `""`，避免双重注入（提示词单一来源在 AGENTS.md 中）。保留 `resilienceGuide()`/`stdoutFallbackGuide()`/`databaseQueryGuide()` 等函数定义（不删除，避免编译报错），但不再通过 `skillGuideSection()` 组合注入

### 3.3 与 .cj 硬编码的区别

| 维度 | .cj 硬编码（v10 前） | AGENTS.md（v11 重构后） |
|------|---------------------|----------------------|
| 来源 | 仓颉源码编译后静态 | markdown 文件运行时加载 |
| 修改方式 | 改 .cj 代码 + 重新编译 | 改 markdown 文件 + 重启 runtime |
| 主 Agent 注入 | 通过 `skillGuideSection()` 在 `buildAgentSystemPrompt` 中拼接 | 主 Agent 从 AGENTS.md 加载 systemPrompt 时自动注入 |
| 单一来源 | 否 | 是（`skillGuideSection()` 返回空串，提示词仅在 AGENTS.md 中） |

---

## 四、v11 验证检查清单

- [ ] web 端对话提交后不再报 `McpError -32001 Request timed out`（回滚强制 ReAct 后聊天接口恢复可用）
- [ ] 主 Agent 加载 AGENTS.md 时 systemPrompt 含"工具调用引导"段（遇挫不停/stdout 替代方案/数据库查询/脚本执行优先）
- [ ] `skillGuideSection()` 返回空串，不再通过 .c 硬编码注入提示词（单一来源在 AGENTS.md）
- [ ] v10 保留的 reasoning_content 转发/编码 fallback/工具名容错 等改动仍生效

---

## 五、v11 涉及文件清单

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `apps/web-admin/web/src/lib/webmcp-sdk/packages/next-sdk/agent/AgentModelProvider.ts` | OPT-V11-1 | 修改：删除 `_forceReActForLongTask` 声明 + 构造器赋值 + `_chat` 入口关键词检测段 |
| `AGENTS.md` | OPT-V11-2 | 修改：追加"工具调用引导"段 |
| `src/config/prompt_config.cj` | OPT-V11-2 | 修改：`skillGuideSection()` 返回空串 |

---

## 第12轮优化方案（v12）：WebMCP超时根治 + directory_list路径修复 + TieredMemory替代 + 基础设施修复

> **日期**：2026-08-12 | **基于 v11 实测日志独立分析** | **覆盖用户6项需求**

### 12.1 v11 实测复核结论

| 维度 | v11 状态 | 根因 |
|------|---------|------|
| 思维链显示 | ❌ 仍未显示 | 前端走`_chatViaWebMCP`（非ReAct），WebMCP请求超时（McpError -32001），后端reasoning_content已生成但前端超时收不到 |
| agent执行SOP | ❌ 失败 | directory_list返回空（Windows路径斜杠问题），agent无法找到scripts目录 |
| filter解析 | ❌ 报错 | RequestParserService filter JSON解析错误（Non-standard JSON） |
| TieredMemory | ❌ 报错 | Embedding model is not set，需用数据库CRUD替代 |
| localhost连接 | ⚠️ 重复请求 | Vite HMR配置clientPort=3031，dev server未运行在该端口 |
| SQL绑定 | ❌ 报错 | AsyncLogWriter/SchedulerEngine SQL参数绑定错误 |
| verifyToken | ❌ 报错 | token为null，前端未传token |

### 12.2 V12-1：WebMCP超时根治 + 思维链全链路显示

**根因**：前端`_chatViaWebMCP`调用`webmcpClient.complete()`，后端agent执行多轮ReAct循环耗时过长（>10分钟），前端MCP SDK默认超时10分钟，导致`McpError -32001: Request timed out`。后端日志确认`reasoning_content`已生成（第2607行），但前端超时收不到。

**修复方案**：
1. 前端`AgentModelProvider.ts`中`_chatViaWebMCP`的`complete`调用增加超时参数到3600000ms（1小时）
2. 前端`StreamableHTTPClientTransport`%`的`requestInit`超时也增加到3600000ms
3. 确保`_chatViaWebMCP`流式分支正确提取`reasoning_content`并构造reasoning事件序列

**涉及文件**：
- `apps/web-admin/web/src/lib/webmcp-sdk/packages/next-sdk/agent/AgentModelProvider.ts` - 增加 complete 超时参数
- `apps/web-admin/web/src/lib/webmcp-sdk/packages/next-sdk/WebMcpClient.ts` - 增加 transport 超时配置

### 12.3 V12-2：directory_list 路径斜杠修复（Windows路径处理）

**根因**：Windows路径使用反斜杠`\`，directory_list工具在处理路径时斜杠重复或未正确规范化，导致返回空目录列表。agent日志明确指出"skills/investment-research-assistant 目录列表返回为空"。

**修复方案**：
1. 在`DirectoryListTool`中规范化路径：将所有反斜杠`\`替换为正斜杠`/`，去除重复斜杠
2. 对相对路径追加工作目录前缀
3. 增加路径存在性检查，不存在时返回明确错误而非空列表

**涉及文件**：
- `src/tool/file_tools.cj` - DirectoryListTool.execute 中路径规范化

### 12.4 V12-3：RequestParserService filter JSON解析错误修复

**根因**：`RequestParserService`解析filter参数时，filter值不是标准JSON格式（可能是URL编码的字符串或空字符串），导致`Failed to parse filter JSON: the json data is Non-standard`。

**修复方案**：
1. filter为空字符串或null时，降级为空filter（不报错）
2. filter非JSON格式时，降级为空filter并记录WARN（不报ERROR）
3. 增加filter格式预检：仅当filter以`{`开头时才尝试JSON解析

**涉及文件**：
- `src/app/core/service/RequestParserService.cj` - filter解析容错

### 12.5 V12-4：TieredMemory用数据库CRUD替代 + 封装内置工具

**根因**：`TieredMemory.search/update`报`Embedding model is not set`，因未配置Embedding模型。用户要求：不配置语义检索，改用数据库CRUD查询`agent_messages`表提供对话历史，封装为大模型可调用的内置工具。

**修复方案**：
1. `TieredMemory.search`在Embedding model未设置时降级为关键词检索（从数据库查询最近N条对话记录）
2. 新建`ConversationHistoryTool`内置工具，输入参数`count`（回溯条数），返回最近N条对话记录
3. 在`BuiltinToolsRegistry.registerAll()`中注册`ConversationHistoryTool`

**涉及文件**：
- `src/agent/memory/tiered/tiered_memory.cj` - search降级为数据库查询
- `src/tool/conversation_history_tool.cj` - 新建：对话历史查询工具
- `src/tool/builtin_tools_registry.cj` - 注册新工具

### 12.6 V12-5：Vite HMR localhost:3031连接拒绝修复

**根因**：`vite.config.dev.ts`中`hmr.clientPort: 3031`，但dev server可能未运行在3031端口，导致HMR WebSocket连接被拒绝（ERR_CONNECTION_REFUSED）。

**修复方案**：
1. 移除`hmr.clientPort`配置，让Vite自动使用dev server端口
2. 或改为`hmr: { overlay: true }`（不指定clientPort，使用默认端口）

**涉及文件**：
- `apps/web-admin/web/config/vite.config.dev.ts` - 移除 hmr.clientPort

### 12.7 V12-6：SQL绑定错误修复（AsyncLogWriter/SchedulerEngine）

**根因**：`AsyncLogWriter`和`SchedulerEngine`的SQL参数绑定不匹配，报`no value specified for parameter 1`和`parameter index 22 out of range [0, 22)`。

**修复方案**：
1. 检查SQL INSERT/UPDATE语句的参数占位符数量与绑定值数量是否匹配
2. `AsyncLogWriter`批量写入时检查参数索引范围
3. `SchedulerEngine`更新执行元数据时检查参数索引范围

**涉及文件**：
- `src/app/services/crontab/async_log_writer.cj` - SQL参数绑定修复
- `src/app/services/crontab/SchedulerEngine.cj` - SQL参数绑定修复

### 12.8 V12-7：verifyToken token为null修复

**根因**：前端请求未携带Authorization头或携带null token，`verifyToken`解析失败报`The token was expected to have 3 parts, but got 1. (first 20 chars: null)`。

**修复方案**：
1. `verifyToken`在token为null或空时返回明确的401错误（不报异常）
2. 对WebMCP端点`/api/v1/uctoo/webmcp/mcp`放宽token校验（允许匿名访问，后端不验证token）

**涉及+涉及文件**：
- `src/app/core/middleware/Middleware.cj` - verifyToken null检查
- `src/app/core/auth/TokenManager.cj` - token为null时返回明确错误

### 12.9 v12 验证检查清单

- [ ] **V12-1**：web端聊天不再报`McpError -32001 Request timed out`，思维链折叠区域显示reasoning内容
- [ ] **V12-2**：`directory_list skills/investment-research-assistant`返回非空目录列表
- [ ] **V12-3**：`Failed to parse filter JSON`不再报ERROR（降级为WARN或静默）
- [ ] **V12-4**：`TieredMemory.search`不再报`Embedding model is not set`（降级为数据库查询）
- [ ] **V12-5**：`ws://localhost:3031/`连接不再ERR_CONNECTION_REFUSED
- [ ] **V12-6**：`AsyncLogWriter`/`SchedulerEngine` SQL绑定不再报参数索引错误
- [ ] **V12-7**：`verifyToken`在token为null时返回明确401（不报异常）

### 12.10 v12 涉及文件清单

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `apps/web-admin/web/src/lib/webmcp-sdk/packages/next-sdk/agent/AgentModelProvider.ts` | V12-1 | 修改：complete超时增加到3600000ms |
| `apps/web-admin/web/src/lib/webmcp-sdk/packages/next-sdk/WebMcpClient.ts` | V12-1 | 修改：transport超时配置 |
| `src/tool/file_tools.cj` | V12-2 | 修改：DirectoryListTool路径规范化 |
| `src/app/core/service/RequestParserService.cj` | V12-3 | 修改：filter解析容错 |
| `src/agent/memory/tiered/tiered_memory.cj` | V12-4 | 修改：search降级为数据库查询 |
| `src/tool/conversation_history_tool.cj` | V12-4 | 新建：对话历史查询工具 |
| `src/tool/builtin_tools_registry.cj` | V12-4 | 修改：注册ConversationHistoryTool |
| `apps/web-admin/web/config/vite.config.dev.ts` | V12-5 | 修改：移除hmr.clientPort |
| `src/app/services/crontab/async_log_writer.cj` | V12-6 | 修改：SQL参数绑定修复 |
| `src/app/services/crontab/SchedulerEngine.cj` | V12-6 | 修改：SQL参数绑定修复 |
| `src/app/core/middleware/Middleware.cj` | V12-7 | 修改：verifyToken null检查 |
| `src/app/core/auth/TokenManager.cj` | V12-7 | 修改：token为null时明确错误 |

---

## 第13轮优化方案（v13）：后端progress通知 + 脚本路径修复 + TieredMemory降级根治 + filter容错增强

> **日期**：2026-08-12 | **基于 v12 实测日志独立分析** | **覆盖4项修复**

### 13.1 v12 实测复核结论

| 维度 | v12 状态 | 根因 |
|------|---------|------|
| 思维链超时 | ❌ 仍超时 | v12设置了`resetTimeoutOnProgress:true`，但后端`agent.chat()`同步执行期间未发送progress通知，progress重置不生效 |
| 脚本输出路径 | ❌ 不一致 | `fetch_market_data.py`默认`--outdir output/raw`是相对路径，agent执行时工作目录不是skill目录，导致输出到项目根目录 |
| TieredMemory | ❌ 仍报错 | v12修了`database_memory.cj`降级，但`ShortMemory.search`先抛出"Embedding model is not set"异常，被`TieredMemory.search`整体catch，降级逻辑从未执行 |
| filter解析 | ⚠️ 部分修复 | v12的`repairJson`处理了单引号/尾逗号/控制字符，但未处理BOM和JavaScript注释 |

### 13.2 V13-1：后端progress通知解决超时

**根因**：`handleCompletionComplete`中`agent.chat(agentRequest)`是同步调用，执行17步ReAct循环耗时约15分钟。前端v12已设置`resetTimeoutOnProgress:true`，但后端未发送任何progress通知，导致progress重置不生效。

**修复方案**：在`agent.chat()`调用前用`spawn`启动progress定时器，每15秒发送SSE progress事件，`agent.chat()`完成后用`AtomicBool`停止定时器。

**涉及文件**：
- `src/app/services/webmcp/WebMCPProtocol.cj` - 添加`std.sync.AtomicBool`导入 + progress定时器

### 13.3 V13-2：脚本输出路径修复

**根因**：`fetch_market_data.py`第152行`--outdir`默认`output/raw`是相对路径。agent执行脚本时工作目录不是`skills/investment-research-assistant/`，导致输出到`apps/agentskills-runtime/output/raw/`。`clean_market_data.py`用绝对路径读取skill目录下的文件，找不到。

**修复方案**：用`os.path.dirname(os.path.abspath(__file__))`获取脚本所在目录作为基准路径，不依赖工作目录。

**涉及文件**：
- `skills/investment-research-assistant/scripts/fetch_market_data.py` - outdir默认值改为基于脚本所在目录
- `skills/investment-research-assistant/scripts/clean_market_data.py` - outdir和input路径同样修复

### 13.4 V13-3：filter JSON容错增强

**根因**：v12的`repairJson`处理了单引号/尾逗号/控制字符，但未处理UTF-8 BOM和JavaScript注释。

**修复方案**：`repairJson`增加去除BOM、JavaScript单行注释、前后空白。

**涉及文件**：
- `src/app/core/query/RequestParserService.cj` - repairJson增强

### 13.5 V13-4：TieredMemory降级根治

**根因**：`ShortMemory`（`src/memory/short_memory.cj:16-18`）使用`Config.defaultEmbeddingModel`，未配置时`vecSet.search`抛出"Embedding model is not set"异常。该异常在`TieredMemory.search`第41行`shortMemory.search(question)`先抛出，被整体catch捕获，导致v12修复的`databaseMemory.search`降级逻辑**从未执行**。

**修复方案**：`TieredMemory.search`分别try-catch`shortMemory.search`和`databaseMemory.search`，确保shortMemory失败时不影响databaseMemory降级。

**涉及文件**：
- `src/agent/memory/tiered/tiered_memory.cj` - search方法分别try-catch

### 13.6 v13 验证检查清单

- [ ] **V13-1**：前端发起投研任务，无`McpError -32001`超时，思维链气泡显示
- [ ] **V13-2**：agent执行`fetch_market_data.py`输出到`skills/investment-research-assistant/output/raw/`，`clean_market_data.py`能找到
- [ ] **V13-3**：前端请求含BOM/注释的非标准filter，无ERROR日志
- [ ] **V13-4**：agent执行时无`TieredMemory.search failed: Embedding model is not set` ERROR，降级为WARN

### 13.7 v13 涉及文件清单

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `src/app/services/webmcp/WebMCPProtocol.cj` | V13-1 | 修改：添加AtomicBool导入 + progress定时器 |
| `skills/investment-research-assistant/scripts/fetch_market_data.py` | V13-2 | 修改：outdir默认值改为基于脚本所在目录 |
| `skills/investment-research-assistant/scripts/clean_market_data.py` | V13-2 | 修改：outdir和input路径同样修复 |
| `src/app/core/query/RequestParserService.cj` | V13-3 | 修改：repairJson增强（BOM+注释+trim） |
| `src/agent/memory/tiered/tiered_memory.cj` | V13-4 | 修改：search分别try-catch shortMemory和databaseMemory |

> **注意**：V13-1/3/4涉及仓颉代码修改，需人工在单独cmd环境执行`cjpm build`编译验证。V13-2涉及Python脚本，无需编译。

---

## 十四、v14 迭代修复（2026-08-13）

### 14.0 v14 问题概述

基于v13修复后最新日志（2026-08-13，2962行）分析，发现以下问题：

| 编号 | 问题 | 优先级 | 根因 |
|------|------|--------|------|
| V14-1 | 思维链全链路/progress定时器未生效 | P1 | web_console.md是旧日志(8/10)；后端已正确转发reasoning_content；McpController未注入SSE连接管理器但HttpResponse不支持SSE流式响应 |
| V14-2 | cli_execute参数空格被吃掉 | P0 | parser_utils.cj第182行.replace(" ","")删除所有空格包括JSON字符串值内部空格 |
| V14-3 | parser工具名缺失 | P0 | react_step.cj总是调用extractToolRequestArray，agent输出单个JSON对象时误提取嵌套数组 |
| V14-4 | filter JSON解析错误 | P1 | checkpoint_manager.cj第50行getListWithFilter sort/filter参数传反 |
| V14-5 | 接口204无数据 | P2 | 日志中未出现204，可能已解决 |
| V14-6 | TLS handler error | P2 | TLS握手超时(30s)，nginx健康检查，不影响功能 |

### 14.1 V14-2：cli_execute参数空格被吃掉根因修复（P0）

**根因**：`parser_utils.cj`第182行`extractFirstJsonValue`方法中：
```cangjie
let trimmedStr = str.trimAscii().replace(" ", "").replace(" ", "")
```
`.replace(" ", "")`删除所有半角空格，包括JSON字符串值内部的空格。agent输出`"args": ["-c", "import requests; print('requests ok')"]`时，`"import requests; print('requests ok')"`被变成`"importrequests;print('requestsok')"`，导致python执行`NameError: name 'importrequests' is not defined`。

这是v9容错修复引入的bug。注释说"JSON前后可能有空格/换行/全角空格"，但修复方式是去掉所有空格，太激进。

**修复方案**：去掉`.replace(" ", "")`，只保留`trimAscii()`。JSON解析器本身能处理JSON内部的空格，不需要全局替换。

**涉及文件**：
- `src/parser/parser_utils.cj` - 第182行去掉.replace(" ", "")

### 14.2 V14-3：parser工具名缺失容错修复（P0）

**根因**：`react_step.cj`第94-98行当`Config.enableParallelToolCall`为true时，总是调用`extractToolRequestArray`。agent输出单个工具调用（JSON对象`{...}`）时，`extractFirstJsonWithHeuristic`找到`args`字段中的嵌套数组`["-c", ...]`，把`"-c"`误当成工具名，报"tool name is missing"。

**修复方案**：修改`react_step.cj`，先检查action首字符，`[`走数组解析，`{`走单个解析；数组解析失败时fallback到单个解析。

**涉及文件**：
- `src/agent_executor/react/react_step.cj` - 添加首字符检查和fallback逻辑

### 14.3 V14-1：思维链全链路分析（无需代码修改）

**分析结论**：
1. `web_console.md`修改时间是2026/8/10（3天前），是**旧日志**，前端超时问题可能已在V12-1修复后解决
2. 后端已正确生成reasoning_content，并通过completion独立字段转发（WebMCPProtocol.cj第1350-1352行）
3. 前端从`result.completion.reasoning_content`提取（AgentModelProvider.ts第1066行）
4. progress定时器未生效因McpController未注入SSE连接管理器，但HttpResponse不支持SSE流式响应，注入了也不工作
5. 实时思维链显示需要SSE流式响应支持，是未来优化方向

### 14.4 V14-4：filter JSON解析根因修复

**根因**：`checkpoint_manager.cj`第50行：
```cangjie
contextsService.getListWithFilter(1, 1, "agent_id='${agentId}'", "created_at DESC")
```
sort和filter参数**传反了**！`"agent_id='${agentId}'"`是filter条件被传入了sort参数，`"created_at DESC"`是sort值被传入了filter参数。

**修复方案**：交换sort和filter参数顺序。第81行`listCheckpoints`方法同样修复。

**涉及文件**：
- `src/app/services/bridge/checkpoint_manager.cj` - 第50行和第81行交换sort/filter参数

### 14.5 V14-5/V14-6：接口204/TLS handler error分析（无需代码修改）

- **V14-5**：日志中未出现204状态码，可能已在之前修复中解决
- **V14-6**：TLS handler error是TLS握手超时（30秒），间歇性出现（约每分钟一次），可能是nginx健康检查或监控连接，不影响正常功能

### 14.6 v14 验证检查清单

- [ ] **V14-2**：agent执行`python -c "import requests; print('requests ok')"`，参数空格保留，无NameError
- [ ] **V14-3**：agent输出单个工具调用（JSON对象），parser正确解析，无"tool name is missing"
- [ ] **V14-4**：后端日志无"Failed to parse filter JSON" WARN，checkpoint正确加载历史消息
- [ ] **V14-1**：前端思维链气泡显示（最终结果中包含reasoning_content）

### 14.7 v14 涉及文件清单

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `src/parser/parser_utils.cj` | V14-2 | 修改：去掉.replace(" ", "")，只保留trimAscii() |
| `src/agent_executor/react/react_step.cj` | V14-3 | 修改：添加首字符检查和fallback逻辑 |
| `src/app/services/bridge/checkpoint_manager.cj` | V14-4 | 修改：第50行和第81行交换sort/filter参数 |

> **注意**：V14-2/3/4涉及仓颉代码修改，需人工在单独cmd环境执行`cjpm build`编译验证。

---

## 十五、v15 优化方案：思维链全链路根治 + 脚本路径/204分析（2026-08-13）

### 15.1 V15-1：思维链全链路根治（P0）

**根因**：ReAct执行器在`getNextReactStep()`中只使用`msg.content`，**完全丢弃了`msg.reason`**（LLM生成的reasoning_content）。`AgentExecutionInfo.chatRound`创建`Message.assistant(answer)`时没有传递reason参数，导致`answerMsg.reason`始终为None，`reasoningContentStr`为空，completion响应中不包含`reasoning_content`字段，前端无法显示思维链。

**修复方案**（4个文件，全链路打通）：

| 文件 | 修改内容 |
|------|---------|
| `src/core/message/message.cj` | `assistant()`工厂方法添加`reason!`参数 |
| `src/agent_executor/common/agent_execution_info.cj` | 添加`_answerReason`字段 + `setAnswerReason()`方法 + `chatRound`传递reason |
| `src/agent_executor/react/react_task.cj` | 添加`_reasoningBuffer`收集所有ReAct步骤的reasoning_content + `getNextReactStep()`捕获`msg.reason` + `handleStep()`返回answer时调用`setAnswerReason()` + `summarize()`也捕获reasoning |
| `src/agent_executor/react/react_executor.cj` | `stopInfo`分支也设置reasoning |

**数据流**：
```
LLM响应(msg.reason) → ReactTask._reasoningBuffer → AgentExecutionInfo.setAnswerReason()
→ chatRound.answer.reason → WebMCPProtocol.reasoningContentStr → completion.reasoning_content
→ AgentModelProvider提取 → reasoning-start/delta/end事件 → StreamVisitor → CustomAgentModelProvider → collapsible-text → BubbleThinkingRenderer
```

### 15.2 V15-2：脚本路径4个斜杠分析（无需代码修改）

**现象**：日志中路径显示`D:\\\\UCT\\\\projects\\\\...`（4个反斜杠）。

**根因**：JSON嵌套转义。Python输出路径含`\`，json.dumps()转义为`\\`，再被外层JSON序列化又转义为`\\\\`。每层JSON序列化都会将反斜杠数量翻倍。这是标准JSON行为，不是bug。

**结论**：非功能性问题，agent已通过使用正斜杠绝对路径绕过。无需代码修改。

### 15.3 V15-3：接口204无数据分析（无需代码修改）

**现象**：web控制台网络tab中POST请求返回204 No Content。

**根因**：JSON-RPC通知（无`id`字段的请求）不需要响应体。MCP协议使用通知进行初始化确认(`notifications/initialized`)、进度更新等。`WebMCPController.cj`第171行和第220行正确地对通知返回204。

**结论**：204是JSON-RPC通知的正确响应，不是错误。无需代码修改。

### 15.4 v15 验证检查清单

- [ ] **V15-1**：agent执行投研任务后，前端聊天界面显示"思考过程"可折叠气泡，包含完整ReAct推理链
- [ ] **V15-1**：后端日志中`reasoning_content`字段非空，completion响应包含`reasoning_content`独立字段

### 15.5 v15 涉及文件清单

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `src/core/message/message.cj` | V15-1 | 修改：`assistant()`添加`reason!`参数 |
| `src/agent_executor/common/agent_execution_info.cj` | V15-1 | 修改：添加`_answerReason`字段 + `setAnswerReason()`方法 + `chatRound`传递reason |
| `src/agent_executor/react/react_task.cj` | V15-1 | 修改：添加`_reasoningBuffer` + `getNextReactStep()`捕获reasoning + `handleStep()`/`summarize()`设置reasoning |
| `src/agent_executor/react/react_executor.cj` | V15-1 | 修改：`stopInfo`分支设置reasoning |

> **注意**：V15-1涉及仓颉代码修改，需人工在单独cmd环境执行`cjpm build`编译验证。

---

## 十六、v16 优化方案：实时思维链显示 + 数据抓取修复（2026-08-13）

### 16.1 问题分析

**V15修复的局限**：V15修复了reasoning_content后端传递的P0根因，但reasoning_content只在agent完全完成后才返回（同步POST响应）。agent执行21步ReAct循环约15分钟，前端在此期间显示loading动画，看不到任何思维链进展。

**用户需求**：大模型返回了4次思维链，应该在对话框按时间顺序分别实时显示这4次思维链，而不是等agent完成后一次性显示。

**根因**：
1. **后端**：`WebMCPProtocol.handleCompletionComplete`在`agent.chat()`返回后才推送`reasoning-delta` SSE事件，不是在ReAct执行过程中实时推送
2. **前端**：`AgentModelProvider._chatViaWebMCP`调用`webmcpClient.complete()`是阻塞调用，返回后才模拟流式发送reasoning，不是实时消费SSE事件

### 16.2 V16-1：实时思维链显示（P0）

**方案**：利用后端已有的SSE基础设施 + 事件处理器机制，在ReAct执行过程中实时推送reasoning到SSE；前端通过EventSource实时消费SSE事件并显示思维链。

**官方参考**：genui-sdk的`response-handler.ts`通过`reasoning_content` delta实时推送思维链，`thinkComponent`通过`emitter.on('notification')`实时显示。

#### 16.2.1 后端：创建SSEEventBridge（新建1文件）

**文件**：`src/app/services/bridge/sse_event_bridge.cj`

**设计**：单例类，类似`WebSocketEventBridge`，注册`ChatModelEndEvent`全局处理器。当ReAct循环中每次LLM调用完成时，`ChatModelEndEvent`自动触发，SSEEventBridge将reasoning实时推送到SSE。

```
SSEEventBridge
  ├── init(sseManager, sessionId)  ← WebMCPProtocol在agent.chat()前调用
  │     └── 注册ChatModelEndEvent处理器到EventHandlerManager.global
  ├── clear()                     ← WebMCPProtocol在agent.chat()后调用
  │     └── 移除SSE引用，停止推送
  └── ChatModelEndEvent处理器
        └── 从evt.chatResponse.message.reason提取reasoning
            └── SSE推送: reasoning-start → reasoning-delta → reasoning-end
```

**关键**：`ChatModelEndEvent`由LLM调用基础设施在每次ReAct步骤完成时自动触发，无需修改`react_task.cj`。

#### 16.2.2 后端：修改WebMCPProtocol（修改1文件）

**文件**：`src/app/services/webmcp/WebMCPProtocol.cj`

**修改点**：在`handleCompletionComplete`中，`agent.chat()`调用前后添加SSEEventBridge初始化/清理：

```
// agent.chat()之前
SSEEventBridge.instance.init(_sseConnectionManager, _sessionId)

let agentResponse = agent.chat(agentRequest)

// agent.chat()之后
SSEEventBridge.instance.clear()
```

同时移除原有的后置SSE reasoning-delta推送（第1293-1307行），因为reasoning已在执行过程中实时推送。

#### 16.2.3 前端：修改AgentModelProvider（修改1文件）

**文件**：`apps/web-admin/web/src/lib/webmcp-sdk/packages/next-sdk/agent/AgentModelProvider.ts`

**修改点**：在`_chatViaWebMCP`流式分支中，`complete()`调用前打开EventSource监听SSE事件，实时enqueue到ReadableStream：

```typescript
// 1. 启动start/start-step
controller.enqueue({ type: 'start' })
controller.enqueue({ type: 'start-step' })

// 2. 打开EventSource监听SSE reasoning事件
const sseUrl = mcpUrl.replace('/mcp', '/sse') + '?sessionId=webmcp-default'
const eventSource = new EventSource(sseUrl)
let reasoningStarted = false
let reasoningId = 0

eventSource.addEventListener('reasoning-start', (e) => {
  const data = JSON.parse(e.data)
  reasoningId = data.id || `reasoning-sse-${Date.now()}`
  controller.enqueue({ type: 'reasoning-start', id: reasoningId })
  reasoningStarted = true
})

eventSource.addEventListener('reasoning-delta', (e) => {
  const data = JSON.parse(e.data)
  if (!reasoningStarted) {
    controller.enqueue({ type: 'reasoning-start', id: 'reasoning-sse-0' })
    reasoningStarted = true
  }
  controller.enqueue({ type: 'reasoning-delta', id: reasoningId, delta: data.reasoning })
})

eventSource.addEventListener('reasoning-end', (e) => {
  if (reasoningStarted) {
    controller.enqueue({ type: 'reasoning-end', id: reasoningId })
    reasoningStarted = false
  }
})

// 3. 调用complete()（SSE事件在await期间异步到达）
const result = await webmcpClient.complete(...)

// 4. 关闭EventSource，结束reasoning，发送最终文本
eventSource.close()
if (reasoningStarted) {
  controller.enqueue({ type: 'reasoning-end', id: reasoningId })
}
controller.enqueue({ type: 'text-start' })
// ... 发送content ...
controller.enqueue({ type: 'text-end' })
controller.enqueue({ type: 'finish-step' })
controller.enqueue({ type: 'finish' })
controller.close()
```

**关键**：JavaScript单线程异步模型保证SSE事件在`await complete()`期间被处理，`controller.enqueue()`在SSE回调中实时调用。

### 16.3 V16-2：数据抓取失败修复（P1）

**问题**：东方财富API返回"Remote end closed connection without response"，3家公司行情数据均为null。

**文件**：`skills/investment-research-assistant/scripts/fetch_market_data.py`

**方案**：增强脚本的错误处理和数据源备选能力：
1. 添加请求重试机制（3次重试，间隔递增）
2. 添加User-Agent和Referer头模拟浏览器请求
3. 添加超时处理（10秒连接超时，30秒读取超时）
4. 当东方财富API失败时，尝试备选数据源（新浪财经API）
5. 所有数据源都失败时，输出带错误信息的空结果（而非完全空结果）

### 16.4 v16 验证检查清单

- [ ] **V16-1**：agent执行投研任务时，前端聊天界面在agent执行过程中实时显示思维链气泡（不是等agent完成后才显示）
- [ ] **V16-1**：4次ReAct步骤的reasoning分别按时间顺序显示为4个思维链块
- [ ] **V16-1**：agent执行期间不再显示loading动画（被实时思维链替代）
- [ ] **V16-2**：数据抓取脚本在东方财富API失败时能尝试备选数据源

### 16.5 v16 涉及文件清单

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `src/app/services/bridge/sse_event_bridge.cj` | V16-1 | 新建：SSEEventBridge单例，注册ChatModelEndEvent处理器实时推送reasoning到SSE |
| `src/app/services/webmcp/WebMCPProtocol.cj` | V16-1 | 修改：agent.chat()前后初始化/清理SSEEventBridge，移除后置SSE reasoning推送 |
| `apps/web-admin/web/src/lib/webmcp-sdk/packages/next-sdk/agent/AgentModelProvider.ts` | V16-1 | 修改：_chatViaWebMCP流式分支添加EventSource监听SSE reasoning事件 |
| `skills/investment-research-assistant/scripts/fetch_market_data.py` | V16-2 | 修改：添加重试机制、备选数据源、错误处理 |

> **注意**：V16-1后端涉及仓颉代码修改，需人工在单独cmd环境执行`cjpm build`编译验证。

---

# 第十七轮迭代实施方案（V17 实测，2026-08-13）

> **文档定位**：基于 V17 实测复核报告（report.md 第十七节），针对本轮实测中**新发现根因和残留**的问题制定修复方案。本轮**先更新文档再改代码**，代码修复后需人工在 cmd 环境编译仓颉代码并重新构建 web 前端产物。
>
> **日期**：2026-08-13 | **基于实测日志分析** | **覆盖 3 个修复项（V17-1~V17-3）**

---

## 一、V17 实测方案总览

| 编号 | 优化项 | 对应报告 | 优先级 | 方案策略 | 涉及文件数 |
|------|--------|---------|--------|---------|-----------|
| OPT-V17-1 | 前端聊天显示空白根治（controller.error → enqueue+close） | RV17-06 | P0 高 | AgentModelProvider.ts catch 块改用 enqueue({type:'error'}) + close()，让 streamVisitor 正确处理错误（含超时降级提示） | 1 |
| OPT-V17-2 | 投研脚本输出物缺失根治（COMPOSITION.yaml 路径模板 + clean /100 bug + SOP 约束） | RV17-02~05 | P0 高 | COMPOSITION.yaml 修复双重路径拼接 + clean_market_data.py 按数据源决定是否 /100 + SKILL.md 添加 SOP 全步完成强制约束 | 3 |
| OPT-V17-3 | prompt_config.cj 废弃重构 | RV17-07 | P1 中 | 删除 prompt_config.cj，系统提示词由 AGENTS.md 统一管理，内联 skillLibraryHeader 字符串 | 3 |

---

## 二、OPT-V17-1：前端聊天显示空白根治（P0，前十六轮未根治）

### 2.1 问题根因（全链路分析）

**现象**：agent 执行约 17 分 38 秒后，后端成功返回 200 OK（content-length 11130 的完整研报），但前端显示空白。

**根因链**：
1. `AgentModelProvider.ts:1306` 的 catch 块调用 `controller.error(error)`
2. `controller.error()` 导致 ReadableStream 错误，`for await` 循环抛出异常
3. streamVisitor 的 `case 'error'` 处理器**永远不会被触发**（它只处理 `enqueue({type:'error'})` 事件，不处理 stream error）
4. UI 显示空白（既无内容也无降级提示）

**streamVisitor 已有的错误处理**（`streamVisitor.ts:193-217`）：
- 检查 `errCode === -32001`（MCP 超时）
- 插入降级提示"agent 正在进行长程任务，前端通道超时但后端仍在运行"
- 但此逻辑只在 `enqueue({type:'error'})` 时触发，`controller.error()` 绕过了它

### 2.2 修复方案

**改动点**：`AgentModelProvider.ts` catch 块（约 1300 行）

```typescript
// 修复前
} catch (error) {
  controller.error(error)  // 导致流错误，streamVisitor 无法处理
}

// 修复后
} catch (error) {
  if (reasoningStarted) {
    controller.enqueue({ type: 'reasoning-end', id: currentReasoningId })
    reasoningStarted = false
  }
  controller.enqueue({ type: 'error', error })  // 让 streamVisitor 正确处理
  controller.close()  // 正常关闭流
}
```

**效果**：
- 超时时 streamVisitor 的 `case 'error'` 处理器被触发，显示降级提示
- SSE reasoning 内容在超时前已 enqueue 到流中，用户可见实时思维链
- 不再显示空白

---

## 三、OPT-V17-2：投研脚本输出物缺失根治（P0，新发现根因）

### 3.1 问题根因（日志证据 + output 目录校验）

**现象**：2026-08-13 运行只产出 raw/clean/factors 三层（Step 1-3），brief 和 sql 目录缺失当日产出物。

**根因 1：COMPOSITION.yaml 路径模板双重拼接**
- `extract-factors.output` 已是 `output/factors`，但 Step 4 的 `factors: "${extract-factors.output}/factors/${input.date}.json"` 再追加 `/factors/`，产生 `output/factors/factors/...`
- Step 5 的 `report: "${generate-report.output}/brief/${input.date}.md"` 同样产生 `output/brief/brief/...`

**根因 2：clean_market_data.py /100 bug**
- `clean_value()` 无条件除以 100（假定东财接口返回值放大 100 倍）
- 但降级到新浪源时，价格已是真实值（如茅台 1355.29），/100 后变成 13.5529

**根因 3：agent 提前终止 SOP**
- agent 在完成 Step 1-3 后直接进入 answer 总结，跳过 Step 4/5
- reasoning 中自认"数据已足够"，违反 SKILL.md 的"必须执行六步 SOP"规则

### 3.2 修复方案

**改动点 1**：`COMPOSITION.yaml` 修复路径模板
```yaml
# 修复前
factors: "${extract-factors.output}/factors/${input.date}.json"  # 双重 factors
# 修复后
factors: "${extract-factors.output}/${input.date}.json"
```

**改动点 2**：`clean_market_data.py` 按数据源决定是否 /100
```python
# 修复前
"price": clean_value(q.get("price"))  # 无条件 /100

# 修复后
source = (q.get("source") or "").lower()
is_sina = "sina" in source
clean_price = clean_raw if is_sina else clean_value  # 新浪不 /100，东财 /100
"price": clean_price(q.get("price"))
```

**改动点 3**：`SKILL.md` 添加"SOP 全步完成强制约束"章节
- 禁止提前终止：必须依次执行 Step 1→2→3→4→5 全部脚本
- 产出文件校验：每步执行后校验产出文件存在且非空
- answer 前终检：生成最终 answer 前确认 brief 和 sql 均已存在

---

## 四、OPT-V17-3：prompt_config.cj 废弃重构（P1）

### 4.1 问题根因

`prompt_config.cj` 定义了 13 个静态方法，但只有 3 个被外部引用，8 个是 dead code。`skillGuideSection()` 已返回空串（v11 迁移残留）。系统提示词应统一由 AGENTS.md 管理。

### 4.2 修复方案

**改动点 1**：`WebMCPProtocol.cj`
- 删除 `import magic.config.PromptConfig`
- 删除 `basePromptSection()` 调用（AGENTS.md 的 systemPrompt 已提供）
- 内联 `skillLibraryHeader()` 为字符串常量
- 删除 `skillGuideSection()` 调用（返回空串）

**改动点 2**：`WsChatController.cj`
- 删除 `import magic.config.PromptConfig`
- 内联 `basePromptSection()` 为 StringBuilder 拼接（WsChatController 的 agent 未走 AGENTS.md 加载路径）
- 内联 `skillLibraryHeader()` 为字符串常量
- 删除 `skillGuideSection()` 调用

**改动点 3**：删除 `src/config/prompt_config.cj`

---

## 五、V17 涉及文件清单（实际修改）

### 5.1 web 前端 TypeScript

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `apps/web-admin/web/src/lib/webmcp-sdk/packages/next-sdk/agent/AgentModelProvider.ts` | OPT-V17-1 | 修改：catch 块改 controller.error 为 enqueue({type:'error'}) + close() |

### 5.2 投研技能脚本和配置

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `skills/investment-research-assistant/COMPOSITION.yaml` | OPT-V17-2 | 修改：修复 Step 4/5/output-brief 路径模板双重拼接 |
| `skills/investment-research-assistant/scripts/clean_market_data.py` | OPT-V17-2 | 修改：按 source 字段决定是否 /100（新浪源不除） |
| `skills/investment-research-assistant/SKILL.md` | OPT-V17-2 | 修改：添加 SOP 全步完成强制约束章节 |

### 5.3 仓颉后端代码

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `src/app/services/webmcp/WebMCPProtocol.cj` | OPT-V17-3 | 修改：删除 PromptConfig import + 内联 skillLibraryHeader + 删除 basePromptSection/skillGuideSection 调用 |
| `src/app/controllers/uctoo/ws/WsChatController.cj` | OPT-V17-3 | 修改：删除 PromptConfig import + 内联 basePromptSection + 内联 skillLibraryHeader + 删除 skillGuideSection 调用 |
| `src/config/prompt_config.cj` | OPT-V17-3 | 删除整个文件 |

---

## 六、V17 验证检查清单

- [ ] **V17-1**：agent 执行投研任务超时后，前端显示降级提示"agent 正在进行长程任务"而非空白
- [ ] **V17-1**：SSE reasoning 内容在超时前已显示在思维链气泡中
- [ ] **V17-2**：COMPOSITION.yaml 编排执行时 Step 4/5 能正确找到输入文件（无双重路径）
- [ ] **V17-2**：新浪源数据 clean 后价格不除以 100（茅台 1355.29 保持不变）
- [ ] **V17-2**：agent 执行完 Step 1-5 全部脚本后才返回 answer（不提前终止）
- [ ] **V17-2**：output/brief/{date}.md 和 output/sql/report_{date}_*.sql 均存在
- [ ] **V17-3**：编译无 `PromptConfig` 未定义错误
- [ ] **V17-3**：WebMCPProtocol 和 WsChatController 的系统提示词正确生成（技能列表正常显示）

> **注意**：V17-3 涉及仓颉代码修改，需人工在单独 cmd 环境执行 `cjpm build` 编译验证。V17-1 涉及前端 TypeScript，需重新构建 web 产物。