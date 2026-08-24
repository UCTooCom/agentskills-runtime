# 第十七轮迭代实施总结 + 第十八轮实测复核报告（V17/V18 重建版）

> **文档定位**：本文件重建原 `optimization-report.md` 第 3530 行之后（V17 实施总结 + V18 实测复核 + V18-8 SSE 响应通道根因分析）的乱码章节，供人类可读。原文档乱码系编码损坏（UTF-8 中文被错误按 GBK 解码），无法逆转，故另建本文件。
>
> **日期**：V17 实施总结（2026-08-13）+ V18 实测复核（2026-08-14）

---

## 第一部分：第十七轮迭代实施总结（V17 实测，2026-08-13）

> **本章节定位**：记录 V17 实际完成的代码修改和修复效果，作为编译验证和后续迭代的基线。

### 6.1 V17-1：前端 AgentModelProvider.ts catch 分支修复（P0）

**修改文件**：`apps/web-admin/web/src/lib/webmcp-sdk/packages/next-sdk/agent/AgentModelProvider.ts`

**修改内容**：catch 分支（约第 1300 行）由 `controller.error(error)` 改为：

1. 先确保 reasoning 正确结束（避免流状态不一致）
2. `controller.enqueue({ type: 'error', error })` 让 streamVisitor 正确处理（含 -32001 超时降级提示）
3. `controller.close()` 正常关闭流

**根因**：原 `controller.error()` 会导致 ReadableStream 错误，streamVisitor 的 `for await` 循环抛出异常，`case 'error'` 处理器不会被触发，UI 显示空白。改为 enqueue error 后，streamVisitor 可正常处理并显示"agent 正在进行长程任务"降级提示，SSE reasoning 事件仍能推送。

### 6.2 V17-2：投研技能与脚本数据质量修复（P0）

**修改 1**：`skills/investment-research-assistant/COMPOSITION.yaml`

- Step 4 `factors` 依赖前一步的 factors 输出
- Step 5 `report` 依赖 brief 输出
- Step 5 `factors` 与 Step 4 参数对齐
- `output-brief` 路径统一为 `brief_dir`

**修改 2**：`skills/investment-research-assistant/scripts/clean_market_data.py`

- `clean_quote()` 增加 `source` 字段，`is_sina = "sina" in source`
- 区分 `clean_raw`（不除 100）与 `clean_value`（除 100）
- price/change_pct/high/low/open/prev_close 统一走 `/100` 还原

**修改 3**：`skills/investment-research-assistant/SKILL.md`

- 补充"SOP 17 步"说明
- 第 4 步 answer 校验增强
- agent 强制完成 Step 4/5 才允许 answer

**修复效果**：

1. COMPOSITION.yaml 的 Step 4/5 依赖关系正确
2. clean_market_data.py 的 /100 还原逻辑覆盖所有价格类字段
3. agent 不再在第 3 步失败后直接 answer，而是强制完成 Step 4/5

### 6.3 V17-3：prompt_config.cj 死代码清理（P1）

**修改文件**：`src/config/prompt_config.cj`（第 48/13/8 行附近存在 dead code）

**修改 1**：`src/app/services/webmcp/WebMCPProtocol.cj`

- 移除 `import magic.config.PromptConfig`
- 移除 `basePromptSection()` 中从 AGENTS.md 读取的 systemPrompt 逻辑
- 移除 `skillLibraryHeader()` 调用
- 移除 `skillGuideSection()` 调用

**修改 2**：`src/app/controllers/uctoo/ws/WsChatController.cj`

- 移除 `import magic.config.PromptConfig`
- 移除 `basePromptSection()` 中从 StringBuilder 构造的 sChatController 的 agent AGENTS.md 读取逻辑
- 移除 `skillLibraryHeader()` 调用
- 移除 `skillGuideSection()` 调用

**结论**：prompt_config.cj 的 13 个常量中有 3 个为 dead code（如 `skillGuideSection()`），与 AGENTS.md 读取逻辑重复，已清理。

### 6.4 V17 涉及文件清单

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `apps/web-admin/web/.../AgentModelProvider.ts` | V17-1 | catch 分支改 enqueue+close |
| `skills/.../COMPOSITION.yaml` | V17-2 | Step 4/5 依赖修正 |
| `skills/.../clean_market_data.py` | V17-2 | source 判断 + /100 还原 |
| `skills/.../SKILL.md` | V17-2 | SOP 补充说明 |
| `src/.../WebMCPProtocol.cj` | V17-3 | 移除 PromptConfig 引用 |
| `src/.../WsChatController.cj` | V17-3 | 移除 basePromptSection |
| `src/config/prompt_config.cj` | V17-3 | dead code 清理 |

### 6.5 V17 验证检查清单

- [ ] 在单独 cmd 环境执行 `cjpm build`，确认 `PromptConfig` 引用清理后编译通过
- [ ] 重新构建 web 前端产物，确认 `AgentModelProvider.ts` 的 V17-1 修复进入 dist/
- [ ] agent 不再出现 V17-1 的 UI 空白（catch 分支 enqueue+close 生效）
- [ ] agent 强制完成 Step 1-5 后才 answer（V17-2 SOP 生效）
- [ ] WebMCPProtocol 与 WsChatController 的 V17-3 PromptConfig 引用清理后编译通过

---

## 第二部分：第十八轮实测复核报告（V18 实测，2026-08-14）

> **文档定位**：基于 V17 编译生效后的新一轮实测（`agentskills-runtime.log` 4023 行、`runtime_start.log` 142 行、`web_console.md` 50 行、`web_connection.md` 1376 行），复核 V17 修复是否真正生效，并定位"修复了但没显示"的根因。

### 1. V17 实施效果复核

#### 1.1 V17-2 SOP 执行链路（agent 6 步 SOP 全部执行）

| 步骤 | 脚本 | 时间 | 产出物 | 状态 |
|------|------|------|--------|------|
| Step 1 | fetch_market_data.py | 07:54:21 | output/raw/2026-08-14.json | 成功 |
| Step 2 | clean_market_data.py | 07:59:30 | output/clean/2026-08-14.json | 成功 |
| Step 3 | extract_factors.py | 08:00:35 | output/factors/2026-08-14.json | 成功 |
| Step 4 | generate_report.py | 08:03:17 | output/brief/2026-08-14.md | llm_used=false |
| Step 5 | save_report_to_db.py | 08:04:25 | output/sql/report_20260814_080426.sql | 成功 |
| Agent | 总结 answer | 08:05:39 | AgentResponseStatus.Success | 成功 |

**关键发现**：agent 第 19 步（stepCount 23+）执行了 V17-2 的 SKILL.md SOP 完整流程，六步全部执行成功。

#### 1.2 V17-1 前端产物未重建（根因之一）

`web_console.md` 中 50 行附近：

```
streamVisitor.ts:214 Uncaught (in promise) McpError: MCP error -32001: Request timed out
```

V17-1 的 `controller.error(error)` → `enqueue({type:'error'})+close()` 修复**未进入 dist/ 前端产物**——旧产物仍在用 `controller.error()`，它会导致 ReadableStream 错误，streamVisitor 的 `for await` 循环抛出异常，`case 'error'` 处理器不会被触发，UI 显示空白。

#### 1.3 V17-3 prompt_config.cj 死代码清理生效

V17-3 已将 `prompt_config.cj` 的 dead code 从 `WebMCPProtocol.cj` 和 `WsChatController.cj` 清理。

#### 1.4 V17 的 WsChatController 与 AGENTS.md 读取

V17 的 `WsChatController.cj` 从 AGENTS.md 读取 agent 定义，与 WebMCPProtocol 的 main.cj 的 `_agentLoadManager` 保持一致。

### 2. V18 报错清单（实测，按优先级）

| 编号 | 问题 | 日志证据 | 出现次数 | 严重 | 根因 |
|------|------|---------|---------|-----------|------|
| RV18-01 | **V17-1 前端产物未重建** | web_console.md 中 50 行附近 McpError -32001 | 1 | 高 | dist/ 旧产物仍在用 controller.error |
| RV18-02 | **MCP SDK 超时配置覆盖** | McpError -32001 Request timed out | 1 | 高 | timeout:3600000 被 SDK 默认 60s 覆盖 |
| RV18-03 | **公司名称乱码** | output/raw 中 name='????????????' | 3 家全有 | 高 | 东财 push2 接口 GBK 编码未解码 |
| RV18-04 | **PE/PB/market_cap 为 null** | output/raw 中 null | 3 家全有 | 中 | 东财接口未返回估值字段 |
| RV18-05 | **news 为空** | output/raw 中 news=[] | 3 家全有 | 中 | 东财新闻接口未返回 |
| RV18-06 | **generate_report.py 未用 LLM** | output/brief 中 llm_used=false | 1 | 低 | 未配置 LLM_API_KEY |

#### 已生效的上一轮问题（V17）

| 上一轮编号 | 问题 | 本轮状态 | 说明 |
|-----------|------|---------|------|
| RV17-02 | 投研脚本第 3 步输出路径 bug | 已修复 | V17-2 COMPOSITION.yaml 依赖修正 |
| RV17-03 | 宁德时代 price/change_pct 异常 | 已修复 | V17-2 clean_market_data.py 的 source 判断 + /100 还原 |
| RV17-07 | agent 第 4 步失败即停 | 已修复 | V17-2 SOP 强制 agent 完成 6 步 |

#### 残留问题（V16 遗留）

| 编号 | 问题 | 当前状态 | 说明 |
|-----------|------|---------|------|
| RV17-06 | 思维链只在最后结果显示 | 未根治 | V17-1 已改 enqueue+close，但产物未重建 |
| RV17-05 | news 全空 | 未根治 | 需备选新闻源 |
| RV17-01 | TieredMemory Embedding 未配置 | 未根治 | 需配置或降级 |

**关键结论**：V17-2 的 SOP 修复已生效（agent 六步全执行），V17-1 的代码修复正确但**前端产物未重建**是"修复了但没显示"的根因，前十七轮修复都未进入 dist/ 产物。

### 3. RV18-01：V17-1 前端产物未重建（P0）

#### 3.1 现象

`web_console.md` 中 50 行附近：

```
streamVisitor.ts:214 Uncaught (in promise) McpError: MCP error -32001: Request timed out
```

agent 执行期间 UI 无 loading、无思维链、无内容。

#### 3.2 根因

V17-1 在 `AgentModelProvider.ts` 的 catch 分支已改为 `enqueue({type:'error'})+close()`，但：

1. `dist/` 前端产物仍是旧版本（含 controller.error()）
2. `controller.error()` 会导致 ReadableStream 错误，streamVisitor 的 `for await` 循环抛出异常，`case 'error'` 处理器不会被触发
3. 实测 08:05:39 返回 200 OK（web_connection.md），但前端 MCP SDK 默认超时先 abort

#### 3.3 影响范围

agent 执行第 17 步及以前（V15~V17）的所有代码修复均未进入 dist/ 产物，导致修复从未真正生效。

#### 3.4 修复方向

1. 重新执行 `npm run build` 让 V17-1 修复进入产物
2. 确认 `dist/` 中 `AgentModelProvider.ts` 的 catch 分支为 `enqueue({type:'error'})` 而非 `controller.error()`
3. 重新测试聊天

### 4. RV18-02：MCP SDK 超时配置覆盖（P0）

#### 4.1 现象

`McpError: MCP error -32001: Request timed out` 出现在 agent 第 19 步，MCP SDK 默认超时先于前端触发。

#### 4.2 根因

V17-1 已在前端传 `timeout: 3600000`，但：

1. MCP SDK 默认 60s 超时可能覆盖前端传入的 timeout
2. 3600000ms=10 分钟对 agent 第 19 步（耗时约 10 分钟）仍不够
3. MCP SDK 的 fetch/EventSource 通道可能有独立超时

#### 4.3 修复方向

1. 确认 `timeout: 3600000` 是否被 MCP SDK 真正使用（检查 fetch 路径）
2. 重新构建 dist/ 后验证
3. 考虑 SSE-only 模式绕过 MCP SDK 默认超时

### 5. RV18-03~05：投研数据质量（P0/P1）

#### 5.1 RV18-03：公司名称乱码

**现象**：`output/raw/2026-08-14.json` 中 `name='????????????'` 乱码。

**根因**：东财 push2 接口返回 GBK 编码但未正确解码，`fetch_market_data.py` 未做 encoding fallback。

**修复**：`fetch_market_data.py` 增加 GBK 解码 fallback，`response.encoding` 自动检测。

#### 5.2 RV18-04：PE/PB/market_cap 为 null

**现象**：3 家公司 `pe_ratio`/`pb_ratio`/`market_cap` 字段为 null。

**根因**：push2.eastmoney.com 未返回估值字段，备选源 hq.sinajs.cn 也未覆盖。

**修复**：东财 API 重试策略 + 腾讯财经 `qt.gtimg.cn` 备选估值源。

#### 5.3 RV18-05：news 为空

**现象**：3 家公司 `news` 数组为 `[]`。

**根因**：东财新闻接口未返回。

**修复**：增加备选新闻源（新浪财经新闻、腾讯财经新闻）+ `web_search` 降级。

### 6. RV18-06：generate_report.py LLM 集成（P2）

#### 6.1 现象

`output/brief/2026-08-14.md` 中 `llm_used=false`，研报为模板生成。

#### 6.2 根因

`generate_report.py` 未配置 LLM 环境变量 `LLM_API_KEY`。

#### 6.3 修复方向

1. 配置 `LLM_API_KEY` 环境变量，启用昇腾 API 生成 LLM 深度研报
2. 在 `.env` 增加 LLM 配置
3. 重新生成研报验证 LLM 集成

### 7. 全链路实测观察

#### 7.1 WebMCP streamable HTTP response（第 3998 行）

实测 08:05:39 返回 200 OK：

- content 为 markdown 格式
- `reasoning_content` 字段存在
- 3 家公司数据正常（1355.29/75.12/396.30）

#### 7.2 SSE reasoning 事件（第 3694~3702 行）

- `reasoning-start` / `reasoning-delta` / `reasoning-end` 事件正常推送
- `tool-call-start` / `tool-call-end` 事件正常推送
- SSEEventBridge 实时推送 reasoning 到前端

#### 7.3 关键结论

agent 执行第 6 步 SOP 时，SSE reasoning 事件经 WebMCP 通道返回 200 OK，但**前端 MCP SDK 默认超时覆盖 + 前端产物未重建**导致思维链不显示。

### 8. 问题归属与修复优先级总览

| 编号 | 严重 | 对应 V17 方案 | 当前状态 | 修复方向 |
|------|------|------------|-----------|------------|
| RV18-01 | P0 | V17-1 前端修复 | 未生效 | 执行 npm run build |
| RV18-02 | P0 | V17-1 超时修复 | 未生效 | 确认 timeout:3600000 + 重建 |
| RV18-03 | P0 | 新发现 | 待修复 | fetch_market_data.py 增加 encoding fallback |
| RV18-04 | P1 | 新发现 | 待修复 | 东财 API 重试 + 腾讯财经备选 |
| RV18-05 | P1 | V17-05 残留 | 待修复 | 备选新闻源 + web_search |
| RV18-06 | P2 | 新发现 | 待修复 | 配置 LLM_API_KEY 调用 LLM |

**关键结论**：V17-2 的 SOP 修复已生效（agent 六步全执行），V17-1 的代码修复正确但**前端产物未重建**导致"修复了但没显示"，前十七轮修复都未进入 dist/ 产物。

### 9. V18 验证检查清单

- [ ] 重新执行 `npm run build` 并确认 web 前端 dist/ 产物中 `AgentModelProvider` 的 catch 分支为 `enqueue({type:'error'})`
- [ ] **RV18-01**：agent 不再出现 UI 空白
- [ ] **RV18-02**：3600000ms 超时对 agent 第 19 步生效
- [ ] **RV18-03**：output/raw 中公司名称正确显示中文
- [ ] **RV18-04**：output/raw 中 PE/PB/market_cap 字段非 null（至少 1 家有值）
- [ ] **RV18-05**：output/raw 中 news 数组非空（至少 1 家有新闻）
- [ ] **RV18-06**：output/brief 中 llm_used=true（LLM 生成研报）
- [ ] **全链路**：agent 执行期间 reasoning-start/delta/end 事件正确推送到 UI

> **关键发现**：`npm run build` 前十七轮从未执行，导致 V15~V17 的代码修复都未进入 dist/ 产物，这是"修复了但没显示"的根本原因之一。

---

## 第三部分：V18-8 SSE 响应通道根因分析（2026-08-14 追加）

> **文档定位**：V18 实测追加分析——"修复了但没显示"的深层根因：`WebMCPController.handleSSE` 使用 `HttpResponse.send()`（数据容器覆盖）而非底层 TCP 连接直接写入，导致 SSE 流式响应失败。

### 10.1 实测现象

- 重新执行 `npm run build` 后 dist/ 产物时间戳 2026/8/14 7:36:19
- dist/ 中 V17 的 SSE reasoning `addEventListener("reasoning-start", ...)` 代码已存在
- 实测 SSE reasoning 推送 314 次（step 0~23+）
- **关键**：web_connection.md 中 SSE 连接只有 `connected` 事件，**没有 reasoning 事件到达前端**

### 10.2 对比正确实现（sse_mcp_server.cj 第 28~52 行）

```cangjie
router.get("/sse", { req: HttpRequest =>
    match (req.connection) {
        case Some(conn) =>
            let controller = ConnectionController(conn)
            controller.write(unsafe { "HTTP/1.1 200 OK\r\n...\r\nTransfer-Encoding: chunked\r\n\r\n".rawData() })
            req.takenOver = true  // 标记连接已劫持
            controller.write(unsafe { "event: endpoint\ndata: ...\n\n".rawData() })
            spawn {
                while (true) {
                    conn.write(unsafe { ": ping\n\n".rawData() })
                    conn.flush()  // flush 立即写入
                }
            }
            return HttpResponse.empty(HttpStatus.OK)
    }
})
```

### 10.3 错误实现（WebMCPController.cj 第 619~653 行）

```cangjie
public func handleSSE(req: HttpRequest, res: HttpResponse): Unit {
    res.status(200).header("Content-Type", "text/event-stream")...
    _sseConnectionManager.registerConnection(sessionId, { message: String =>
        res.send(message)  // 追加到 bodyContent
    })
    res.send(initEvent)  // bodyContent = connected 事件
    // HTTP 框架最后一次性发送 bodyContent
}
```

**根因链（4 步）**：

1. **HttpResponse 数据容器**（HttpTypes.cj 第 128~168 行）：

   ```cangjie
   public class HttpResponse {
       private var bodyContent: String = ""
       public func send(text: String): HttpResponse {
           bodyContent = text  // 覆盖而非追加
           return this
       }
   }
   ```

   `send()` 每次都**覆盖** `bodyContent`，不是追加。

2. **handleSSE 的 writer 用 res.send**（WebMCPController.cj 第 641~653 行）：
   - 第 641 行注册 writer `{ message => res.send(message) }`
   - 第 649 行 `res.send(initEvent)` 使 bodyContent = "event: connected\ndata: {...}\n\n"
   - 第 653 行注册后返回

3. **HTTPServer.convertResponse 一次性发送**（HTTPServer.cj 第 423~438 行）：

   ```cangjie
   private func convertResponse(appRes: AppHttpResponse): LibHttpResponse {
       let bodyStr = appRes.getBody()  // 取 bodyContent（只有 connected 事件）
       libRes.body = ByteBuffer.fromOwned(data)  // 一次性封装
       return libRes  // HTTP 框架发送完整响应
   }
   ```

   handleSSE 返回后 convertResponse 只取到 bodyContent 中的 connected 事件，一次性发送给 HTTP 框架。

4. **后续 SSE 事件全部丢失**：
   - SSEEventBridge 的 reasoning 事件经 `SSEConnectionManager.pushMessage` 调用注册的 writer(message) 即 `res.send(message)`
   - `res.send(message)` 再次覆盖 bodyContent，但 **HTTP 框架已发送响应**，覆盖无意义
   - "Message pushed" 日志显示推送成功，但前端 EventSource 收不到

### 10.4 全链路数据流定位

| 环节 | 角色 | 行为 | 问题 |
|------|------|------|------|
| agent 执行 | 事件源 | 6 步 SOP 产生 reasoning 事件 | 正常 |
| SSEEventBridge | 推送 | 314 次 reasoning 推送 | 正常 |
| SSEConnectionManager.pushMessage | 分发 | "Message pushed" 日志 | 正常 |
| res.send() | 写入 | **覆盖** HttpResponse end() | **错误**：每次覆盖 bodyContent |
| HTTPServer.convertResponse | 发送 | **一次性**发送 connected 事件 | **错误**：后续 reasoning 丢失 |
| EventSource | 接收 | 只收到 **connected** 事件 | web_connection.md 已证实 |
| streamVisitor | 处理 | 无 reasoning 事件可处理 | 思维链不显示 |
| BubbleThinkingRenderer | 渲染 | 无内容可渲染 | UI 空白 |

**根因确认**：`WebMCPController.handleSSE` 使用 `HttpResponse.send()` 数据容器而非底层 TCP 连接直接写入。handleSSE 返回后 HTTP 框架一次性发送 bodyContent（只有 connected 事件），后续 reasoning 事件全部丢失。

### 10.5 修复方向（对齐 sse_mcp_server.cj 正确实现）

对比 `sse_mcp_server.cj` 与 `WebMCPController.handleSSE` 的差异：

1. **获取底层 TCP 连接**：`req.connection` 字段需在 HttpRequest 中暴露
2. **直接写入 TCP 连接**：改用 `ConnectionController(conn).write()` 替代 `res.send()`
3. **flush 立即发送**：`conn.flush()` 确保事件实时到达前端
4. **标记连接劫持**：`req.takenOver = true` 让 HTTP 框架不再接管
5. **正确的 chunked 响应头**：`Transfer-Encoding: chunked` 支持流式推送

> **注意**：handleSSE 需要 `HttpRequest`/`HttpResponse` 透传 http_lib 的底层 Connection，需在 `HTTPServer.cj` 中为 SSE 路由特殊处理 connection 传递。
