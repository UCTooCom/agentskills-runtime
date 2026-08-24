# 第十八轮迭代实施方案（V18 实测，2026-08-14）

> **文档定位**：基于 V18 实测复核报告（report.md 第十八轮），针对本轮实测中"修复了但没显示"的根因 + 新发现数据质量问题制定修复方案。本轮**仅更新文档不修改代码**，下一轮需先执行前端重新构建，再根据实测结果决定是否需要代码修复。
>
> **核心原则**：沿用原有设计架构进行增量优化，每一项修复都基于本轮实测日志证据，不凭猜测。前端重新构建部署是最高优先级（前 17 轮修复了但没显示的根因之一）。
>
> **日期**：2026-08-14 | **基于实测日志分析** | **覆盖 7 个修复项（V18-1~V18-7）+ 1 个仓颉代码修复项（V18-8）**

---

## 一、V18 实测方案总览

| 编号 | 优化项 | 对应报告 | 优先级 | 方案策略 | 涉及文件数 |
|------|--------|---------|--------|---------|-----------|
| OPT-V18-1 | 前端重新构建部署（V17-1 修复生效） | RV18-01 | P0 高 | 执行 npm run build 重新构建前端产物，让 V17-1 的 enqueue+close 修复生效 | 0（仅构建） |
| OPT-V18-2 | MCP SDK 超时配置验证 | RV18-02 | P0 高 | 确认 timeout:3600000 是否真正生效，检查 SDK 默认超时覆盖 | 1~2 |
| OPT-V18-3 | 前端 streamVisitor 错误处理全链路 | RV18-01 | P0 高 | streamVisitor 的 for await 循环增加 try-catch，防止 McpError 成为 uncaught rejection | 1 |
| OPT-V18-4 | 数据质量优化 - 公司名称乱码 | RV18-03 | P0 高 | fetch_market_data.py 增加 GBK 解码 fallback + response.encoding 自动检测 | 1 |
| OPT-V18-5 | 数据质量优化 - 估值数据缺失 | RV18-04 | P1 中 | 东财 API 重试策略 + 腾讯财经 qt.gtimg.cn 备选估值源 | 1 |
| OPT-V18-6 | 数据质量优化 - 新闻数据空 | RV18-05 | P1 中 | 新闻数据备选源（新浪财经新闻、腾讯财经新闻）+ web_search 降级 | 1 |
| OPT-V18-7 | generate_report.py LLM 集成 | RV18-06 | P2 低 | 配置 LLM_API_KEY 环境变量，启用昇腾 API 生成深度研报 | 1~2 |

---

## 二、OPT-V18-1：前端重新构建部署（P0，V17-1 修复生效）

### 2.1 问题根因

`web_console.md` 中 50 行左右出现 `McpError -32001 Request timed out`，说明 V17-1 在 `AgentModelProvider.ts` 的 catch 分支已改为 `enqueue({type:'error'})+close()`，但**前端产物 dist/ 未重新构建**——旧产物仍在用 `controller.error()`，它会导致 ReadableStream 错误，streamVisitor 的 `for await` 循环抛出异常，`case 'error'` 处理器不会被触发，UI 显示空白。

### 2.2 修复方案

**执行前端重新构建**（唯一动作，无代码修改）：

```bash
cd apps/web-admin/web
npm run build
```

### 2.3 验证检查

1. `dist/` 中 `AgentModelProvider` 的 catch 分支包含 `enqueue({type:'error'})` 而非 `controller.error()`
2. `dist/` 中 timeout 为 `3600000` 而非 `600000`（避免 MCP SDK 默认 60s 超时）
3. 重新测试聊天，UI 不再空白

### 2.4 结论

V17-1 的代码修复是正确的，但前端产物未重新构建导致修复未生效。**本轮最高优先级是先重新构建前端**，验证 V17-1 的 enqueue+close 修复是否真正解决 UI 空白。

---

## 三、OPT-V18-2：MCP SDK 超时配置验证（P0）

### 3.1 问题根因

`McpError: MCP error -32001: Request timed out` 出现在 agent 第 19 步附近。V17-1 已在前端传 `timeout: 3600000`，但 **MCP SDK 的默认超时可能覆盖了前端配置**。

### 3.2 修复方案

**验证点 1**：`timeout: 3600000` 是否被 MCP SDK 真正使用——检查 `AgentModelProvider.ts` 传参路径：

- `AgentModelProvider` 调用 `MCP Client` 的 `fetch` 请求
- 检查 `fetch` 是否带 `AbortController.timeout` 或 `signal` 超时参数

**验证点 2**：MCP SDK 默认超时覆盖：

- MCP SDK 默认 60s 超时，SDK 内部的 `fetch` 可能覆盖前端传入的 timeout

**验证点 3**：

- 确认 `dist/` 产物中 `3600000` 是否真实存在（V18-1 构建后验证）

---

## 四、OPT-V18-3：前端 streamVisitor 错误处理全链路（P0）

### 4.1 问题根因

`streamVisitor.ts:214 Uncaught (in promise) McpError` 说明 streamVisitor 的 `for await` 循环遇到 McpError 抛出未捕获的 promise rejection。V17-1 的 enqueue+close 修复后，streamVisitor 的 `for await` 循环仍需加 try-catch，防止 McpError 成为 uncaught rejection。

### 4.2 修复方案

**方案**：`streamVisitor.ts` 的 `for await` 循环加 try-catch

参考 genui-sdk 的 `onFinish` + `data?.type === 'error'` 模式：

```typescript
// 参考实现
try {
  for await (const data of stream) {
    if (data?.type === 'error') {
      // 处理错误
      break
    }
    // 正常处理
  }
} catch (error) {
  // 防止 McpError 成为 uncaught rejection
  console.warn('Stream error:', error)
  // 设置 error 状态
}
```

### 4.3 参考资源

- `D:\UCT\products\gitcode\opentiny\genui-sdk` 的 genui-sdk 源码
- https://docs.opentiny.design/genui-sdk/examples/chat/thinking-process.html 思维链在线文档

---

## 五、OPT-V18-4：数据质量优化 - 公司名称乱码（P0）

### 5.1 问题根因

`output/raw/2026-08-14.json` 中 `name='????????????'` 乱码，东财 push2 接口返回 GBK 编码但未正确解码。

### 5.2 修复方案

**方案**：`skills/investment-research-assistant/scripts/fetch_market_data.py` 增加 encoding fallback

```python
# 增加 encoding 自动检测
response = requests.get(url)
# 非 UTF-8 时按 apparent_encoding 解码
if response.encoding and response.encoding.lower() != 'utf-8':
    response.encoding = response.apparent_encoding  # 常见为 'gbk'
content = response.text
```

对 `hq.sinajs.cn` 等 GBK 源显式解码：

```python
response = requests.get(url)
content = response.content.decode('gbk', errors='replace')
```

---

## 六、OPT-V18-5：数据质量优化 - 估值数据缺失（P1）

### 6.1 问题根因

3 家公司 `pe_ratio`/`pb_ratio`/`market_cap` 字段为 null，push2.eastmoney.com 接口未返回估值字段。

### 6.2 修复方案

**方案 1**：东财 API 重试策略

`fetch_market_data.py` 增加重试：

```python
for attempt in range(3):
    try:
        response = requests.get(eastmoney_url, timeout=10)
        if response.status_code == 200:
            break
    except Exception:
        time.sleep(1)
```

**方案 2**：腾讯财经备选估值源

使用 `qt.gtimg.cn`：

```
https://qt.gtimg.cn/q=r600519,r000858,r300750
```

---

## 七、OPT-V18-6：数据质量优化 - 新闻数据空（P1）

### 7.1 问题根因

3 家公司 `news` 数组为空 `[]`，东财新闻接口未返回。

### 7.2 修复方案

**方案 1**：备选新闻源

`fetch_market_data.py` 的 `fetch_news` 增加备选源：
1. https://feed.mix.sina.com.cn/api/...
2. https://news.qq.com/...

**方案 2**：web_search 降级

东财 API 无新闻时用 `web_search` 搜索补足。

---

## 八、OPT-V18-7：generate_report.py LLM 集成（P2）

### 8.1 问题根因

`output/brief/2026-08-14.md` 中 `llm_used=false`，未配置 `LLM_API_KEY`。

### 8.2 修复方案

**方案 1**：配置 `LLM_API_KEY`

在 `.env` 和 `.env.example` 增加：

```
LLM_API_KEY=your_api_key
LLM_API_URL=https://ascend.huawei.com/api/...
```

**方案 2**：接入昇腾 API

`generate_report.py` 检测到 `LLM_API_KEY` 后调用 LLM API 生成深度研报。

---

## 九、V18 涉及文件清单

### Phase 1：前端构建 + TypeScript

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `apps/web-admin/web/dist/` | OPT-V18-1 | 执行 npm run build |
| `apps/web-admin/web/src/lib/webmcp-sdk/packages/next-sdk/agent/AgentModelProvider.ts` | OPT-V18-2 | 验证 timeout:3600000 传参 |
| `apps/web-admin/web/src/lib/webmcp-sdk/packages/next-remoter/src/composable/streamVisitor.ts` | OPT-V18-3 | for await 循环加 try-catch |

### Phase 2：Python 脚本

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `skills/investment-research-assistant/scripts/fetch_market_data.py` | OPT-V18-4,5,6 | encoding fallback + 重试 + 备选源 |

### Phase 3：配置与脚本

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `.env` / `.env.example` | OPT-V18-7 | 增加 LLM_API_KEY/LLM_API_URL |
| `skills/investment-research-assistant/scripts/generate_report.py` | OPT-V18-7 | 检测 LLM_API_KEY 调用 LLM API |

---

## 十、V18 验证检查清单

- [ ] **OPT-V18-1**：执行 `npm run build` 成功
- [ ] **OPT-V18-1**：dist/ 中 AgentModelProvider 的 catch 分支为 `enqueue({type:'error'})` 而非 `controller.error()`
- [ ] **OPT-V18-1**：agent 第 19 步不再超时
- [ ] **OPT-V18-2**：3600000ms 超时对 agent 第 19 步生效
- [ ] **OPT-V18-3**：streamVisitor 的 for await 循环加 try-catch 后 McpError 不再成为 uncaught rejection
- [ ] **OPT-V18-4**：output/raw 中公司名称正确显示中文（贵州茅台、五粮液、宁德时代）
- [ ] **OPT-V18-5**：output/raw 中 PE/PB/market_cap 字段非 null（至少 1 家有值）
- [ ] **OPT-V18-6**：output/raw 中 news 数组非空（至少 1 家有新闻）
- [ ] **OPT-V18-7**：output/brief 中 llm_used=true（LLM 生成研报）
- [ ] **全链路**：agent 第 19 步后 reasoning-start/delta/end 事件正确推送到 UI 并按时间顺序显示

> **关键发现**：前十七轮"修复了但没显示"的真正根因是前端 `npm run build` 产物未重新部署——V15~V17 的代码修复都在 dist/ 之外，未进入构建产物。
>
> **注意**：agent 执行第 6 步 SOP 时的 SSE reasoning 事件经 WebMCP 通道返回 200 OK，但**前端 MCP SDK 默认超时覆盖 + 产物未重建**导致思维链不显示。

---

## 十一、OPT-V18-8：SSE 响应通道修复（P0，仓颉代码）

### 12.1 问题根因

`WebMCPController.handleSSE`（第 619~653 行）使用 `HttpResponse.send()`（数据容器覆盖）而非底层 TCP 连接直接写入，导致 SSE 流式响应失败：

- `HttpResponse.send()` 在 HttpTypes.cj 第 151 行封装为 `bodyContent = text`
- `handleSSE` 经 `HTTPServer.convertResponse`（第 423 行）将 `bodyContent` 一次性发送（只有 connected 事件）
- 后续 reasoning 事件经 `res.send()` 追加到 bodyContent，HTTP 框架一次性发送 → 事件丢失

**正确实现**：参考 `sse_mcp_server.cj`（第 28~52 行），使用 `ConnectionController(conn).write()` + `conn.flush()` + `req.takenOver = true` 直接操作底层 TCP 连接。

### 12.2 修复方案

**方案 A：HttpRequest 增加 connection 字段**

修改 `HttpTypes.cj`：

```cangjie
public class HttpRequest {
    // ... 原有字段 ...
    public var connection: ?Any = None  // http_lib 的 Connection
    public var takenOver: Bool = false  // 是否已劫持连接
}
```

**方案 B：HTTPServer.cj 传递 connection**

HTTPServer 将 LibHttpRequest 的 connection 透传到 HttpRequest。

**方案 C：WebMCPController.cj 的 handleSSE 使用底层连接**

```cangjie
public func handleSSE(req: HttpRequest, res: HttpResponse): Unit {
    let sessionId = req.queryParam("sessionId").getOrThrow()

    // 优先使用底层 TCP 连接直接写入
    match (req.connection) {
        case Some(conn) =>
            let controller = ConnectionController(conn)
            // 裸写 SSE chunked 响应头
            controller.write(unsafe { "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nCache-Control: no-cache\r\nConnection: keep-alive\r\nTransfer-Encoding: chunked\r\n\r\n".rawData() })
            req.takenOver = true  // 标记连接已劫持，HTTP 框架不再接管

            // 注册 writer：底层 TCP 连接直接写入 + flush
            _sseConnectionManager.registerConnection(sessionId, { message: String =>
                controller.write(unsafe { message.rawData() })
                conn.flush()
            })

            // 发送 connected 初始事件
            controller.write(unsafe { "event: connected\ndata: {\"sessionId\":\"${sessionId}\"}\n\n".rawData() })
            conn.flush()

            // spawn 心跳
        case None =>
            res.status(500).send("Connection not available")
    }
}
```

**方案 D：HTTPServer.cj 对 SSE 路由特殊处理**

HTTPServer 对 `/api/v1/uctoo/webmcp/sse` 路由透传 LibHttpRequest 的 connection 到 HttpRequest/HttpResponse。

### 12.3 涉及文件

| 文件 | 操作 |
|------|------|
| `src/app/core/http/HttpTypes.cj` | HttpRequest 增加 connection/takenOver 字段 |
| `src/app/core/server/HTTPServer.cj` | 透传 connection |
| `src/app/controllers/uctoo/webmcp/WebMCPController.cj` | handleSSE 改用 ConnectionController(conn).write() + conn.flush() |

### 12.4 验证要点

- SSE handleSSE 直接操作底层 TCP 连接
- 后续 reasoning 事件经 `controller.write() + conn.flush()` 实时推送
- 前端 EventSource 收到 reasoning-start/delta/end 事件后经 streamVisitor 流向 BubbleThinkingRenderer 显示
- **注意**：OPT-V18-8 涉及仓颉代码修改（1 个文件），需人工在单独 cmd 环境执行 `cjpm build` 编译验证。

---

## 十二、V18 涉及文件清单（含 V18-8 仓颉）

| 文件 | 优化项 | 操作 |
|------|--------|------|
| `src/app/core/http/HttpTypes.cj` | OPT-V18-8 | HttpRequest 增加 connection/takenOver 字段 |
| `src/app/core/server/HTTPServer.cj` | OPT-V18-8 | 透传 connection |
| `src/app/controllers/uctoo/webmcp/WebMCPController.cj` | OPT-V18-8 | handleSSE 改用 ConnectionController(conn).write() + conn.flush() |

> **注意**：OPT-V18-8 涉及仓颉代码修改（3 个文件），需人工在单独 cmd 环境执行 `cjpm build` 编译验证。编译后需重新启动后端服务并测试前端动态思维链显示。
