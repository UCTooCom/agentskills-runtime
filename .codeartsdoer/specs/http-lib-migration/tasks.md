# HTTP 库迁移编码任务清单（stdx.net.http → http_lib）

> 本文档基于 `spec.md` 需求规格与 `design.md` 技术设计生成，按 design.md §5 的 7 阶段执行顺序排列任务。每个阶段完成后可独立编译验证。
>
> **执行约束**：
> - 严禁在开发工具中运行 `cjpm build`（编译超时）。编译验证须由人工在独立 cmd 环境执行并反馈结果。
> - **编写仓颉代码必须使用 cangjie-coder 技能**。在生成任何代码之前，必须先从已有代码库或 cangjie-coder/cangjie-language-guide/cangjie-full-docs 技能中**检索到确定的编码依据**（API签名、类型定义、语法规范等），确认依据后再生成代码。严禁凭记忆或猜测编写仓颉代码。
> - 所有路径相对于 `apps/agentskills-runtime/`。

---

## Phase 0：http_lib 依赖链本地化

> **目标**：将 http_lib 及其传递依赖全部本地化为 path 依赖，消除 git 网络请求与 cjpm 缓存冲突。
> **前置依赖**：无
> **设计参考**：design.md §3.11、§3.12

### T0.1 克隆 6 个 git 依赖至 libs 目录

- **任务ID**：T0.1
- **标题**：克隆 kaca_json、jinguissl、jinguissl_core、kaca_cookies、compress4cj、channel_cj 到 libs/
- **前置任务**：无
- **涉及文件**：
  - `libs/kaca_json/`（新建）
  - `libs/jinguissl/`（新建）
  - `libs/jinguissl_core/`（新建）
  - `libs/kaca_cookies/`（新建）
  - `libs/compress4cj/`（新建）
  - `libs/channel_cj/`（新建）
- **操作步骤**：
  1. 在 `apps/agentskills-runtime/libs/` 目录下执行以下克隆命令：
     ```bash
     git clone https://gitcode.com/changeden/kaca_json.git -b optz libs/kaca_json
     git clone https://gitcode.com/changeden/jinguiSSL.git -b optz libs/jinguissl
     git clone https://gitcode.com/CjKu/JinguiCore.git libs/jinguissl_core
     git clone https://gitcode.com/cangjie_no_1/kaca_cookies.git libs/kaca_cookies
     git clone https://gitcode.com/changeden/compress4cj.git libs/compress4cj
     git clone https://gitcode.com/changeden/channel_cj.git libs/channel_cj
     ```
  2. 检查每个克隆结果目录是否含 `cjpm.toml` 文件。若为 monorepo 子目录结构，调整 path 指向含 cjpm.toml 的子目录。
  3. 检查各依赖的 `cjc-version`，确认兼容主项目 1.0.5。若某依赖为 1.1.x 且不向下兼容，记录并人工评估降级 tag。
- **验收条件**：
  - libs/ 下存在 6 个新目录，各含 cjpm.toml
  - 各依赖 cjc-version 与 1.0.5 兼容（http_lib 1.1.3 已声明向下兼容）
- **风险**：gitcode.com 不可达 → 配置代理或人工在可联网环境克隆后拷贝

### T0.2 修改 libs/http_lib/cjpm.toml 的 git 依赖为 path 依赖

- **任务ID**：T0.2
- **标题**：http_lib 的 6 个 git 依赖改为 path 指向本地副本
- **前置任务**：T0.1
- **涉及文件**：`libs/http_lib/cjpm.toml`
- **操作步骤**：
  1. 读取 `libs/http_lib/cjpm.toml`，定位 `[dependencies]` 段中 6 个 git 依赖声明（kaca_json、jinguissl、jinguissl_core、kaca_cookies、compress4cj、quic_cj）。
  2. 将每个 git 声明替换为 path 声明：
     ```toml
     [dependencies]
       kaca_json = { path = "../kaca_json", output-type = "static" }
       jinguissl = { path = "../jinguissl", output-type = "static" }
       jinguissl_core = { path = "../jinguissl_core", output-type = "static" }
       kaca_cookies = { path = "../kaca_cookies", output-type = "static" }
       compress4cj = { path = "../compress4cj", output-type = "static" }
       quic_cj = { path = "../quic_cj", output-type = "static" }
     ```
  3. 保留其余依赖与配置不变。
- **验收条件**：
  - `libs/http_lib/cjpm.toml` 中无 git 依赖声明
  - 6 个 path 指向的目录均存在

### T0.3 修改 libs/quic_cj/cjpm.toml 的 git 依赖为 path 依赖

- **任务ID**：T0.3
- **标题**：quic_cj 的 3 个 git 依赖改为 path 指向本地副本
- **前置任务**：T0.1
- **涉及文件**：`libs/quic_cj/cjpm.toml`
- **操作步骤**：
  1. 读取 `libs/quic_cj/cjpm.toml`，定位 `[dependencies]` 段中 3 个 git 依赖声明（jinguissl、jinguissl_core、channel_cj）。
  2. 替换为：
     ```toml
     [dependencies]
       jinguissl = { path = "../jinguissl", output-type = "static" }
       jinguissl_core = { path = "../jinguissl_core", output-type = "static" }
       channel_cj = { path = "../channel_cj", output-type = "static" }
     ```
  3. 保留其余配置不变。
- **验收条件**：
  - `libs/quic_cj/cjpm.toml` 中无 git 依赖声明
  - 3 个 path 指向的目录均存在

### T0.4 修改主 cjpm.toml 添加 http_lib 依赖链 path 声明

- **任务ID**：T0.4
- **标题**：主项目 cjpm.toml 新增 8 个 path 依赖
- **前置任务**：T0.1、T0.2、T0.3
- **涉及文件**：`cjpm.toml`
- **操作步骤**：
  1. 读取 `cjpm.toml`，定位 `[dependencies]` 段。
  2. 新增 8 个 path 依赖声明（http_lib、quic_cj、kaca_json、jinguissl、jinguissl_core、kaca_cookies、compress4cj、channel_cj）：
     ```toml
     http_lib = { path = "./libs/http_lib" }
     quic_cj = { path = "./libs/quic_cj" }
     kaca_json = { path = "./libs/kaca_json" }
     jinguissl = { path = "./libs/jinguissl" }
     jinguissl_core = { path = "./libs/jinguissl_core" }
     kaca_cookies = { path = "./libs/kaca_cookies" }
     compress4cj = { path = "./libs/compress4cj" }
     channel_cj = { path = "./libs/channel_cj" }
     ```
  3. **保留**所有现有依赖（fountain 各模块、charset4cj、jwt4cj、logcj、pgsql、blowfish、json4cj、cos、cj_mail、activemq4cj、hyperion 等）。
  4. **保留**所有 `[target.*.bin-dependencies]` 的 stdx 动态库 path-option（独立库仍依赖 stdx）。
  5. 保留 `compile-option` 中 `--cfg "faiss=disable,sqlite=disable,llamacpp=disable,http=cj"`。
- **验收条件**：
  - cjpm.toml 含 8 个 http_lib 依赖链 path 声明
  - 现有依赖与 bin-dependencies 均保留
  - 人工执行 `cjpm update` 成功，依赖链全部通过 path 解析

---

## Phase 1：HTTPServer.cj 重写

> **目标**：用 http_lib 的 HttpServer + Router 替换 stdx 的 Server + ServerBuilder，实现声明式 Handler 桥接，根本解决 10053。
> **前置依赖**：Phase 0
> **设计参考**：design.md §3.1、§2.1

### T1.1 替换 HTTPServer.cj 的 import

- **任务ID**：T1.1
- **标题**：stdx.net.http 服务端 import 整体替换为 http_lib import
- **前置任务**：T0.4
- **涉及文件**：`src/app/core/server/HTTPServer.cj`
- **操作步骤**：
  1. 移除以下 import：
     ```cangjie
     import stdx.net.http.{Server, ServerBuilder, HttpContext, HttpRequest, HttpResponse, HttpResponseBuilder, FuncHandler, HttpRequestDistributor, HttpRequestHandler}
     import stdx.net.tls.TlsServerConfig
     import stdx.crypto.x509.{X509Certificate, PrivateKey}
     ```
  2. 新增以下 import：
     ```cangjie
     import http_lib.server.{HttpServer, HttpServerConfig}
     import http_lib.connection.{TlsConfig, Connection}
     import http_lib.router.{Router as HttpLibRouter, Middleware as HttpLibMiddleware}
     import http_lib.message.{HttpRequest as HttpLibRequest, HttpResponse as HttpLibResponse, HttpMethod as HttpLibMethod}
     import http_lib.core.{HttpStatus, ConnState}
     ```
  3. 保留应用层 import（AppHttpRequest、AppHttpResponse、Router、MiddlewareChain、Route 等）不变。
- **验收条件**：
  - 文件中无 `stdx.net.http`、`stdx.net.tls`、`stdx.crypto.x509` import
  - 新增 http_lib import 语法正确

### T1.2 移除 DefaultHttpRequestDistributor 类

- **任务ID**：T1.2
- **标题**：整体删除自实现 DefaultHttpRequestDistributor 类及相关方法
- **前置任务**：T1.1
- **涉及文件**：`src/app/core/server/HTTPServer.cj`
- **操作步骤**：
  1. 删除私有类 `DefaultHttpRequestDistributor <: HttpRequestDistributor` 的完整定义。
  2. 删除 `extractPathParams`、`matchesDynamicRoute`、`createNotFoundHandler` 方法（http_lib Router 内置路径参数注入与 404 处理）。
  3. 删除 `createRouteHandler` 中基于 FuncHandler 的包装逻辑。
- **验收条件**：
  - 文件中无 `DefaultHttpRequestDistributor`、`HttpRequestDistributor`、`FuncHandler` 符号
  - 无 `extractPathParams`、`matchesDynamicRoute`、`createNotFoundHandler` 方法

### T1.3 重构 HTTPServer 类字段

- **任务ID**：T1.3
- **标题**：HTTPServer 类字段从 stdx Server 适配为 http_lib HttpServer
- **前置任务**：T1.2
- **涉及文件**：`src/app/core/server/HTTPServer.cj`
- **操作步骤**：
  1. **移除字段**：`_server: Any`、`_distributor`、`_requestTimeout`。
  2. **新增字段**：
     - `_httpLibRouter: HttpLibRouter`（http_lib 路由器实例）
     - `_serverConfig: HttpServerConfig`
     - `_tlsConfig: ?TlsConfig`
     - `_httpServer: ?HttpServer`（延迟构造）
  3. **保留字段**：`router`（应用层 Router）、`middlewareChain`、`port`、`host`、`isHttps`、`running`、`logger`。
- **验收条件**：
  - 类字段定义无 `_server: Any`、`_distributor`、`_requestTimeout`
  - 新增 4 个 http_lib 相关字段

### T1.4 合并 HTTPServer 构造函数

- **任务ID**：T1.4
- **标题**：4 个构造函数合并为统一构造 + 委托构造
- **前置任务**：T1.3
- **涉及文件**：`src/app/core/server/HTTPServer.cj`
- **操作步骤**：
  1. 实现主构造函数 `init(port, host, requestTimeout!, idleTimeout!, certPath!, keyPath!)`：
     - 构造 `HttpServerConfig`，设置 `readTimeout = requestTimeout`、`writeTimeout = requestTimeout`、`idleTimeout`（默认 `Duration.second * 60`）。
     - 若 `certPath`/`keyPath` 提供：构造 `TlsConfig(serverCertPath: certPath, serverKeyPath: keyPath)` 存入 `_tlsConfig`，置 `isHttps = true`。
     - 配置 `connState` 回调：`_serverConfig.connState = { s => logger.info("conn state: ${s}") }`。
     - 配置 `errorLog` 回调：`_serverConfig.errorLog = { msg => logger.error(msg) }`。
     - 初始化 `_httpLibRouter = HttpLibRouter()`。
  2. 旧 4 个构造函数改为委托构造，保持 main.cj 调用点签名不变：
     - `init(port, host, requestTimeout)` → 委托主构造，idleTimeout 默认 60s，无 TLS。
     - `init(port, host, certPath, keyPath, requestTimeout)` → 委托主构造，带 TLS。
     - 其余 2 个构造函数按需委托。
- **验收条件**：
  - 主构造函数显式配置 readTimeout/writeTimeout/idleTimeout/connState/errorLog
  - 旧构造函数签名不变，内部委托主构造
  - idleTimeout 默认 60s

### T1.5 实现 bridgeHandler 桥接函数

- **任务ID**：T1.5
- **标题**：实现应用层 Handler 到 http_lib 声明式 Handler 的桥接
- **前置任务**：T1.4
- **涉及文件**：`src/app/core/server/HTTPServer.cj`
- **操作步骤**：
  1. 实现 `bridgeHandler(appRoute: Route): (HttpLibRequest) -> HttpLibResponse`：
     ```cangjie
     private func bridgeHandler(appRoute: Route): (HttpLibRequest) -> HttpLibResponse {
         return { req =>
             let appReq = convertRequest(req)
             let appRes = AppHttpResponse()
             try {
                 middlewareChain.execute(appReq, appRes, { => appRoute.handler(appReq, appRes) })
                 var resp = HttpResponse.text(HttpStatus.fromCode(UInt16(appRes.getStatusCode())), appRes.getBody())
                 for ((k, v) in appRes.getHeaders()) { resp = resp.withHeader(k, v) }
                 return resp
             } catch (ex: Exception) {
                 logger.error("Error handling request: ${ex.message}")
                 return HttpResponse.json(HttpStatus.INTERNAL_SERVER_ERROR, "{\"error\":\"${ex.message}\"}")
             }
         }
     }
     ```
  2. 改造 `convertRequest(req: HttpLibRequest): AppHttpRequest`：
     - method：`convertMethod(req.method)`，HttpLibMethod 枚举 → 应用层 HttpMethod。
     - path：`req.url.path`。
     - query：`req.queryParams()` → `appReq.queryParams`。
     - pathParams：`req.params` → `appReq.pathParams`（http_lib Router 自动注入）。
     - headers：`req.headers` → `appReq.headers`。
     - body：`req.bodyAsString()` → `appReq.body`。
  3. 改造 `convertMethod(method: HttpLibMethod): HttpMethod`：`match (method) { case HttpLibMethod.GET => HttpMethod.GET ... }`。
  4. `readRequestBody` 改用 `req.bodyAsString()` 替代 `StringReader(req.body).readToEnd()`。
- **验收条件**：
  - bridgeHandler 返回 `(HttpLibRequest) -> HttpLibResponse` 函数
  - 路径参数从 `req.params` 读取，无手工 extractPathParams
  - 异常被捕获，返回 500 声明式响应

### T1.6 改造 setRouter / use / registerWebSocketRoute

- **任务ID**：T1.6
- **标题**：路由注册与中间件方法适配 http_lib Router
- **前置任务**：T1.5
- **涉及文件**：`src/app/core/server/HTTPServer.cj`
- **操作步骤**：
  1. `setRouter(router)`：遍历 `router.getRoutes()`，按 method 调 `_httpLibRouter.get/post/put/delete(path, bridgeHandler(route))` 同步注册到 http_lib Router。
  2. `use(middleware)`：向 `middlewareChain` 注册；同时将应用层 Middleware 包装为 http_lib `Middleware = (Handler) -> Handler` 注册到 `_httpLibRouter.use(...)`。
  3. `registerWebSocketRoute(path, handler)`：改为 `_httpLibRouter.get(path, { req => handleWebSocketUpgrade(req, handler) })`。
  4. 实现 `handleWebSocketUpgrade(req, handler)`：
     - `match (req.connection) { case Some(conn) => let controller = ConnectionController(conn); controller.upgradeToWebSocket(req); let wsConn = WebSocketConn(conn); handler(wsConn); return HttpResponse.empty() case None => return HttpResponse.text(HttpStatus.INTERNAL_SERVER_ERROR, "takeover not supported") }`。
- **验收条件**：
  - setRouter 将应用层路由同步到 _httpLibRouter
  - registerWebSocketRoute 走 http_lib Router GET 注册
  - WebSocket 升级通过 ConnectionController.upgradeToWebSocket

### T1.7 改造 start / stop 方法

- **任务ID**：T1.7
- **标题**：服务启停方法适配 http_lib HttpServer
- **前置任务**：T1.6
- **涉及文件**：`src/app/core/server/HTTPServer.cj`
- **操作步骤**：
  1. `start()`：
     ```cangjie
     public func start(): Unit {
         running = true
         setupRoutes()
         _httpServer = HttpServer(handler: _httpLibRouter.handler(), config: _serverConfig)
         match (_httpServer) {
             case Some(s) =>
                 if (isHttps) { s.listenAndServeTls(host, UInt16(port)) }
                 else { s.listenAndServe(host, UInt16(port)) }
             case None => handleErrorInStart()
         }
     }
     ```
  2. `stop()`：`match (_httpServer) { case Some(s) => s.shutdown(); s.close() case None => }`。
  3. `setupRoutes()` 保留遍历应用层 router 注册逻辑，但注册目标改为 `_httpLibRouter`。
- **验收条件**：
  - start 构造 HttpServer 并调用 listenAndServe/listenAndServeTls
  - stop 调用 shutdown + close
  - 无 `server.serve()` / `server.close()` 的 stdx 调用

### T1.8 改造健康检查 Handler 为声明式

- **任务ID**：T1.8
- **标题**：handleHealth / handleInfo / handleHello 改为声明式 Handler
- **前置任务**：T1.7
- **涉及文件**：`src/app/core/server/HTTPServer.cj`
- **操作步骤**：
  1. `handleHealth` 改为：`{ req => HttpResponse.json(HttpStatus.OK, "{\"status\":\"ok\"}") }`，直接注册到 `_httpLibRouter`。
  2. `handleInfo`、`handleHello` 同理改为声明式返回 HttpResponse。
  3. 移除原 `context.responseBuilder.status().body()` 命令式调用链。
- **验收条件**：
  - 3 个健康检查 Handler 返回 HttpResponse 声明式对象
  - 无 `responseBuilder` 命令式调用

---

## Phase 2：WebSocket 迁移

> **目标**：将 WebSocket 升级与消息循环从 stdx WebSocket 迁移至 http_lib ConnectionController + WebSocketConn。
> **前置依赖**：Phase 1
> **设计参考**：design.md §3.2、§3.3、§3.4、§2.2
> **执行顺序**：先迁移 ws_models.cj（被 Controller 依赖），再迁移两个 Controller。

### T2.1 ws_models.cj import 替换与 WebSocketSession 改造

- **任务ID**：T2.1
- **标题**：ws_models.cj 的 WebSocket 类型从 stdx 迁移至 http_lib
- **前置任务**：T1.8
- **涉及文件**：`src/app/services/ws_support/ws_models.cj`
- **操作步骤**：
  1. 移除 `import stdx.net.http.{WebSocket, WebSocketFrameType}`。
  2. 新增 `import http_lib.server.{WebSocketConn, WebSocketOpcode}`。
  3. `class WebSocketSession` 字段 `websocket: WebSocket` 改为 `wsConn: WebSocketConn`。
  4. `sendMessage(message)`：`wsConn.writeText(jsonStr)` 替代 `websocket.write(WebSocketFrameType.TextWebFrame, bytes)`。
  5. `close()`：`wsConn.close()` 或通过持有 Connection 调用 `conn.close()`。
  6. 应用层 `WebSocketMessage` 类保留（若与 http_lib `WebSocketMessage` 冲突，重命名为 `AppWebSocketMessage`）。
- **验收条件**：
  - 文件中无 `stdx.net.http` import
  - WebSocketSession 字段为 `wsConn: WebSocketConn`
  - sendMessage/close 使用 http_lib API

### T2.2 WebMCPController.cj import 替换与 handleConnection 改造

- **任务ID**：T2.2
- **标题**：WebMCPController 的 WebSocket 升级与消息循环迁移
- **前置任务**：T2.1
- **涉及文件**：`src/app/controllers/uctoo/webmcp/WebMCPController.cj`
- **操作步骤**：
  1. 移除 `import stdx.net.http.{HttpContext, WebSocket, WebSocketFrameType, HttpHeaders}`。
  2. 新增：
     ```cangjie
     import http_lib.server.{ConnectionController, WebSocketConn, WebSocketMessage, WebSocketOpcode}
     import http_lib.connection.Connection
     import http_lib.message.{HttpRequest, HttpResponse}
     import http_lib.core.{HttpHeaders, HttpStatus}
     ```
  3. `handleConnection(ctx: HttpContext)` 改为声明式 `handleConnection(req: HttpRequest): HttpResponse`：
     - `match (req.connection) { case Some(conn) => ... case None => return HttpResponse.text(HttpStatus.INTERNAL_SERVER_ERROR, "takeover not supported") }`。
     - `let controller = ConnectionController(conn)`，`controller.upgradeToWebSocket(req)`。
     - **subProtocols 协商**：若 http_lib `upgradeToWebSocket` 不支持 subProtocols 参数，使用方案A——`upgradeToWebSocket(secWebSocketKey)` 重载，手动构造 101 响应头追加 `Sec-WebSocket-Protocol: <selected>` 行；封装为 `upgradeToWebSocketWithSubProtocols(req, subProtocols)` 工具函数。
     - `let wsConn = WebSocketConn(conn)`，创建 protocol、sessionId，`handleMessageLoop(wsConn, sessionId, protocol)`。
     - 返回 `HttpResponse.empty()`。
  4. `handleMessageLoop(websocket: WebSocket, ...)` 改为 `handleMessageLoop(wsConn: WebSocketConn, ...)`：
     - `while (true) { match (wsConn.readMessage()) { case Some(msg) => ... case None => break } }`。
     - `msg.isText()` → `msg.text()` 替代 `String.fromUtf8(frame.payload)`。
     - `msg.isBinary()` → 处理二进制消息。
     - `msg.isClose()` → `conn.close(); break`。
     - **移除** `case PingWebFrame` 分支（http_lib readMessage 内部自动回复 Pong）。
  5. `processMessage(message, wsConn, protocol)`：`wsConn.writeText(responseStr)` 替代 `websocket.write(WebSocketFrameType.TextWebFrame, bytes)`。
  6. `_extractUserIdFromContext(ctx)` 改为 `_extractUserId(req: HttpRequest)`，从 `req.headers.get("x-user-id")` 读取。
- **验收条件**：
  - 文件中无 `stdx.net.http` import、无 `WebSocket.upgradeFromServer`
  - 升级走 ConnectionController.upgradeToWebSocket
  - 消息循环用 wsConn.readMessage，无 PingWebFrame 分支

### T2.3 WsChatController.cj import 替换与 handleChat 改造

- **任务ID**：T2.3
- **标题**：WsChatController 的 WebSocket 升级与消息循环迁移
- **前置任务**：T2.1
- **涉及文件**：`src/app/controllers/uctoo/ws/WsChatController.cj`
- **操作步骤**：
  1. 移除 `import stdx.net.http.{HttpContext, WebSocket, WebSocketFrameType, HttpHeaders}`。
  2. 新增 http_lib import（同 T2.2 步骤2）。
  3. `handleChat(ctx: HttpContext)` 改为声明式 `handleChat(req: HttpRequest): HttpResponse`：
     - 取 `req.connection`，`ConnectionController(conn).upgradeToWebSocket(req)`，`WebSocketConn(conn)`。
     - 构造 `WebSocketSession(sessionId, wsConn)`（依赖 T2.1 改造）。
     - 注册到 `WebSocketSessionManager`，`_sendWelcomeMessage`，`_messageLoop`，清理。
     - 返回 `HttpResponse.empty()`。
  4. `_messageLoop(session)`：
     - `match (session.wsConn.readMessage()) { case Some(msg) => if (msg.isText()) _handleTextMessage(session, msg.text()) else if (msg.isBinary()) _handleBinaryMessage(session, msg.data) else if (msg.isClose()) { session.close(); break } case None => break }`。
     - 移除 PingWebFrame 分支。
  5. `_handleBinaryMessage(session, payload: Array<UInt8>)`：保留，payload 来源改为 `msg.data`。
- **验收条件**：
  - 文件中无 `stdx.net.http` import、无 `WebSocket.upgradeFromServer`
  - WebSocketSession 使用 wsConn 字段
  - 消息循环无 PingWebFrame 分支

---

## Phase 3：SSE 迁移

> **目标**：用 http_lib 内置 SSEWriter 替换 sse_mcp_server.cj 的手动 SSE 分帧实现。
> **前置依赖**：Phase 1
> **设计参考**：design.md §3.5、§2.3

### T3.1 sse_mcp_server.cj import 替换与 SSEWriter 改造

- **任务ID**：T3.1
- **标题**：sse_mcp_server.cj 手动 SSE 分帧替换为 http_lib SSEWriter
- **前置任务**：T1.8
- **涉及文件**：`src/mcp/sse_mcp_server.cj`
- **操作步骤**：
  1. 移除 `import stdx.net.http.*`。
  2. 新增：
     ```cangjie
     import http_lib.server.{HttpServer, HttpServerConfig, SSEWriter}
     import http_lib.router.Router
     import http_lib.message.{HttpRequest, HttpResponse}
     import http_lib.connection.Connection
     import http_lib.core.HttpStatus
     ```
  3. 移除 `extend HttpContext { func startSSE() { ... } }`（SSEWriter 构造器自动设置 Content-Type/Cache-Control/Connection 头）。
  4. `client_map` 类型从 `ConcurrentHashMap<String, HttpResponseWriter>()` 改为 `ConcurrentHashMap<String, SSEWriter>`（或 `ConcurrentHashMap<String, (SSEWriter, Connection)>` 以便检测连接可用性）。
  5. `start(host, port)` 改造：
     - `let router = Router()`。
     - SSE 路由 `router.get("/sse", { req => handleSseHandshake(req) })`：
       - `handleSseHandshake` 取 `req.connection`，构造 `HttpResponse.empty()` + `SSEWriter(resp, conn)`。
       - `sseWriter.sendEvent("endpoint", "/messages/?session_id=${uuid}")`。
       - 存入 `client_map`，`while (true) { sleep(...); sseWriter.sendComment("ping - ...") }`。
       - 返回 `resp`。
     - messages 路由 `router.post("/messages/", { req => handleMessages(req) })`：
       - 从 `req.queryParams()["session_id"]` 取 uuid，`req.bodyAsString()` 取 msg。
       - `spawn { this.loop(msg, uuid) }`，返回 `HttpResponse.text(HttpStatus.ACCEPTED, "Accepted")`。
     - `let config = HttpServerConfig()`，`HttpServer(handler: router.handler(), config: config).listenAndServe(host, port)`。
  6. `send(msg, uuid)`：`client_map.get(uuid).getOrThrow().sendEvent("message", msg)`。
  7. `send<T>(response, uuid)`：`this.send(response.toJsonValue().toString(), uuid)`。
- **验收条件**：
  - 文件中无 `stdx.net.http` import
  - 无手动 `data: ...\n\n` 拼接逻辑
  - SSE 头由 SSEWriter 自动设置
  - 事件格式（id/event/data）与迁移前一致

---

## Phase 4：HTTP 客户端替换

> **目标**：将出站 HTTP 客户端从 stdx Client/ClientBuilder 替换为 http_lib HttpClient，HttpHeaders 类型统一替换。
> **前置依赖**：Phase 0
> **设计参考**：design.md §3.6、§3.7、§3.8、§3.9、§2.4

### T4.1 http_cj.cj import 替换与 HttpClient 改造

- **任务ID**：T4.1
- **标题**：http_cj.cj 的 HTTP 客户端从 stdx Client 迁移至 http_lib HttpClient
- **前置任务**：T0.4
- **涉及文件**：`src/utils/http/http_cj.cj`
- **操作步骤**：
  1. 移除 `import stdx.net.tls.{TlsClientConfig, CertificateVerifyMode}` 和 `import stdx.net.http.*`。
  2. 新增：
     ```cangjie
     import http_lib.client.{HttpClient, HttpClientConfig, HttpRequestBuilder}
     import http_lib.message.{HttpRequest, HttpResponse, HttpMethod}
     import http_lib.connection.TlsConfig
     import http_lib.core.HttpStatus
     ```
  3. `buildHttpClient(url, verify)` 改为 `buildHttpClientConfig(url, verify): HttpClientConfig`：
     - `let config = HttpClientConfig()`，`config.readTimeout = Duration.minute * 10`，`config.writeTimeout = ...`，`config.connectTimeout = ...`。
     - 若 `url.startsWith("https")`：`config.tlsConfig = if (verify) TlsConfig() else TlsConfig.insecure()`。
     - 移除 `TcpSocketConnector` 自定义连接器（用默认 dialer）。
  4. `prepareHttpRequest(method, url, header, body)`：
     - `let builder = HttpRequestBuilder().withUrl(url)`。
     - 若 `body.isSome()`：`builder.withJson(b.toJsonString())`。
     - method 匹配：`"POST" => builder.post()`、`"GET" => builder.get()`、`"PUT" => builder.put()`、`"DELETE" => builder.delete()`、`"PATCH" => builder.patch()`。
     - `for ((k,v) in header) builder.withHeader(k, v)`。
     - `return builder.build()`。
  5. `sendHttp(...)`：
     - `let client = HttpClient(buildHttpClientConfig(url, verify))`。
     - `let response = client.send(req)`。
     - `if (!response.isSuccess() && response.status.code != 202u16)`：`readHttpBody(response)`，抛 `HttpException`。
  6. `readHttpBody(resp)`：`return resp.bodyAsString()`。
  7. `processStream`：用 `response.readBody(buffer)` 或 `response.readLine()` 流式读取。
  8. `HttpResult` 类的 `header: HttpHeaders` 字段类型改为 http_lib `HttpHeaders`。
- **验收条件**：
  - 文件中无 `stdx.net.http`、`stdx.net.tls` import
  - 无 `ClientBuilder`、`TlsClientConfig`、`TcpSocketConnector` 引用
  - 请求构建用 withUrl/withJson/withHeader

### T4.2 http_curl.cj import 替换与 HttpHeaders 映射

- **任务ID**：T4.2
- **标题**：http_curl.cj 的 HttpHeaders 类型替换为 http_lib
- **前置任务**：T0.4
- **涉及文件**：`src/utils/http/http_curl.cj`
- **操作步骤**：
  1. 移除 `import stdx.net.http.HttpHeaders`。
  2. 新增 `import http_lib.core.HttpHeaders`。
  3. `parseCurlVerboseOutput` 返回类型改为 `(Int64, http_lib.core.HttpHeaders)`。
  4. `let header = HttpHeaders()`，`header.add(k, v)` 保留（http_lib HttpHeaders 支持 add 追加多值）。
  5. 其余 curl 子进程逻辑不变。
- **验收条件**：
  - 文件中无 `stdx.net.http` import
  - HttpHeaders 类型为 http_lib.core.HttpHeaders

### T4.3 http_utils.cj import 替换与 HttpHeaders 映射

- **任务ID**：T4.3
- **标题**：http_utils.cj 的 HttpHeaders 类型替换为 http_lib
- **前置任务**：T0.4
- **涉及文件**：`src/utils/http/http_utils.cj`
- **操作步骤**：
  1. 移除 `import stdx.net.http.HttpHeaders`。
  2. 新增 `import http_lib.core.HttpHeaders`。
  3. `HttpResult.header` 类型改为 `http_lib.core.HttpHeaders`。
  4. 3 个构造函数中 `this.header = HttpHeaders()` + `for ((k,v) in header) this.header.add(k, v)` 逻辑保留。
  5. `HttpException`、`HttpResultOption`、`HttpUtils` 对外 API 不变。
  6. `sseConnect` 内部调用 `HttpUtils.asyncGet` 不变。
- **验收条件**：
  - 文件中无 `stdx.net.http` import
  - HttpResult.header 类型为 http_lib HttpHeaders
  - 对外 API 不变

### T4.4 AIController.cj 移除无用 import

- **任务ID**：T4.4
- **标题**：AIController.cj 移除 stdx.net.http.HttpHeaders 残留 import
- **前置任务**：T0.4
- **涉及文件**：`src/app/controllers/uctoo/ai/AIController.cj`
- **操作步骤**：
  1. 移除 `import stdx.net.http.HttpHeaders`（第 16 行，实际未使用的残留 import）。
  2. 若编译发现实际有 HttpHeaders 类型引用，改为 `import http_lib.core.HttpHeaders`。
  3. 其余逻辑不变。
- **验收条件**：
  - 文件中无 `stdx.net.http` import

---

## Phase 5：main.cj 服务器初始化修改

> **目标**：适配 main.cj 的服务器初始化调用，确保 HttpServerConfig 与 TlsConfig 正确注入。
> **前置依赖**：Phase 1
> **设计参考**：design.md §3.10

### T5.1 main.cj 服务器初始化适配

- **任务ID**：T5.1
- **标题**：main.cj 调用点签名适配 http_lib HTTPServer
- **前置任务**：T1.8
- **涉及文件**：`src/app/main.cj`
- **操作步骤**：
  1. `Application.init` 构造函数调用点不变（HTTPServer 构造函数签名已保留）。
  2. `setupMiddlewares()` 不变（`server.use(middleware)` API 保留，内部已改为 http_lib Middleware 包装）。
  3. `setupRoutes()`：
     - `AutoRouteRegistry`、各 *Routes.register() 不变（应用层 Router API 保留）。
     - `server.registerWebSocketRoute("/api/v1/uctoo/ws/chat", wsChatController.handleChat)`：`handleChat` 签名已改为声明式，`registerWebSocketRoute` 内部已适配。
     - `router.get("/api/v1/health", { req, res => ... })`：应用层 Router 保留 `(AppHttpRequest, AppHttpResponse) -> Unit` 签名，由桥接函数适配。
  4. `start()`：`server.start()` 不变（内部已改为 `listenAndServe/listenAndServeTls`）。
  5. `stop()`：`server.stop()` 不变（内部已改为 `shutdown + close`）。
  6. main() 顶层函数中读取配置、初始化 ORM、创建 Application 的逻辑不变。
- **验收条件**：
  - main.cj 中无 stdx.net.http 引用
  - 服务启动调用 server.start()，内部走 http_lib listenAndServe
  - 构造函数调用点签名不变

---

## Phase 6：配置清理

> **目标**：清理 cjpm.toml 中残留的 stdx.net.http 显式依赖（若存在）与源码中无用 import。
> **前置依赖**：Phase 1-5
> **设计参考**：design.md §3.11、spec.md §4.4

### T6.1 cjpm.toml 移除 stdx.net.http 显式依赖

- **任务ID**：T6.1
- **标题**：主项目 cjpm.toml 移除 stdx.net.http 显式依赖声明
- **前置任务**：T5.1
- **涉及文件**：`cjpm.toml`
- **操作步骤**：
  1. 读取 `cjpm.toml`，检查 `[dependencies]` 段是否有 `stdx.net.http` 显式声明。
  2. 若有，移除该声明（主项目源码已不再引用 stdx.net.http）。
  3. **保留**独立库（activemq4cj/cj_mail/cos-sdk/hyperion）的 stdx 依赖。
  4. **保留**所有 `[target.*.bin-dependencies]` 的 stdx 动态库 path-option（独立库仍依赖 stdx）。
- **验收条件**：
  - cjpm.toml `[dependencies]` 中无 stdx.net.http 显式声明
  - 独立库的 stdx 依赖与 bin-dependencies 保留

### T6.2 清理源码中残留的 stdx.net.http import

- **任务ID**：T6.2
- **标题**：全局扫描并清理 src/ 下残留的 stdx.net.http import
- **前置任务**：T5.1
- **涉及文件**：`src/` 下所有 .cj 文件
- **操作步骤**：
  1. 执行 `grep -r "stdx.net.http\|stdx.net.tls\|stdx.crypto.x509" src/` 扫描残留 import。
  2. 排除 `src/examples/arkts_syntax_assistant_skill/`（示例，非主项目）。
  3. 排除独立库目录（activemq4cj/cj_mail/cos-sdk/hyperion，保留 stdx 依赖）。
  4. 对残留的 import，按 design.md §2 映射表替换为 http_lib 对应 import。
- **验收条件**：
  - `grep -r "stdx.net.http" src/` 仅命中 `src/examples/` 目录
  - `grep -r "stdx.net.tls\|stdx.crypto.x509" src/` 无命中

---

## Phase 7：集成测试

> **目标**：全量编译验证与功能回归测试，确认 10053 根除。
> **前置依赖**：Phase 0-6
> **设计参考**：design.md §6、spec.md §4

### T7.1 编译验证

- **任务ID**：T7.1
- **标题**：主项目 cjc 1.0.5 全量编译验证
- **前置任务**：T6.2
- **涉及文件**：整个项目
- **操作步骤**：
  1. **通知人工**在独立 cmd 环境执行 `cjpm update` 验证依赖解析。
  2. **通知人工**在独立 cmd 环境执行 `cjpm build` 全量编译。
  3. 人工反馈编译结果。若有编译错误，使用 cangjie-coder 技能分析并修复。
  4. 验证各目标平台（x86_64-unknown-linux-gnu、x86_64-w64-mingw32、aarch64-apple-darwin）编译通过。
- **验收条件**：
  - `cjpm update` 成功，依赖链全部 path 解析
  - 主项目 cjc 1.0.5 编译通过
  - 各目标平台编译通过

### T7.2 10053 复现场景验证

- **任务ID**：T7.2
- **标题**：客户端中途断开后服务端不出现 10053 SocketException
- **前置任务**：T7.1
- **涉及文件**：无（运行时验证）
- **操作步骤**：
  1. 启动服务，发起 HTTP 请求后立即断开客户端连接。
  2. 观察服务端日志：应可见 `errorLog` 回调输出，`connState` 输出 CLOSED。
  3. 确认进程不崩溃，监听端口不失效。
  4. 重复 Keep-Alive 超时、网络中断两类场景验证。
- **验收条件**：
  - 客户端中途断开后服务端 errorLog 输出，进程不崩溃
  - 无应用层无法捕获的 SocketException

### T7.3 功能回归验证

- **任务ID**：T7.3
- **标题**：REST API、WebSocket、SSE、HTTP 客户端功能回归
- **前置任务**：T7.1
- **涉及文件**：无（运行时验证）
- **操作步骤**：
  1. **REST API 回归**：验证现有所有 REST 路径、HTTP 方法、请求/响应 JSON 结构与迁移前一致。
  2. **WebSocket 回归**：验证 WebSocket 握手、消息收发、关闭行为与迁移前一致；前端 WebSocket 客户端无需修改。
  3. **SSE 回归**：验证 SSE 事件下发、事件格式（id/event/data）与迁移前一致；首事件下发延迟 < 500ms。
  4. **HTTP 客户端回归**：验证出站 HTTP/HTTPS 调用（LLM、MCP、第三方 API）行为与迁移前一致。
  5. **HTTPS 握手**：验证 TLS 握手成功，证书通过配置注入。
- **验收条件**：
  - 所有 REST API 路径/方法/响应结构不变
  - WebSocket 消息格式不变，前端无感知
  - SSE 事件格式不变，首事件延迟 < 500ms
  - 出站 HTTP 调用行为不变
  - HTTPS 握手成功

### T7.4 性能与稳定性验证

- **任务ID**：T7.4
- **标题**：P95 延迟与 24h 稳定性验证
- **前置任务**：T7.3
- **涉及文件**：无（运行时验证）
- **操作步骤**：
  1. 对比迁移前后核心 REST API P95 响应延迟，确认不劣于基线 110%。
  2. 对比 WebSocket 消息往返延迟 P95，确认不劣于基线 110%。
  3. 服务连续运行 24 小时，观察是否出现崩溃、端口失效、连接泄漏。
- **验收条件**：
  - 核心 REST API P95 延迟 ≤ 基线 110%
  - WebSocket P95 延迟 ≤ 基线 110%
  - SSE 首事件延迟 < 500ms
  - 24h 无崩溃、无端口失效

---

## Phase 8：静态文件服务实现（runtime 0.0.26 新增）

> **目标**：基于 http_lib 实现静态文件服务，使 runtime ≥ 0.0.26 能够直接托管 web-admin 构建产物等静态资源。
> **前置依赖**：Phase 1（HTTPServer.cj 重写完成）
> **设计参考**：design.md §3.13、spec.md §5.8（REQ-SFS-01 ~ REQ-SFS-07）
> **架构参考**：`docs/uctoo-v4/static-file-service-architecture.md`

### T8.1 实现 StaticFileConfig 配置类

- **任务ID**：T8.1
- **标题**：创建 StaticFileConfig 类，从 .env 读取静态文件服务配置
- **前置任务**：T1.8
- **涉及文件**：`src/app/core/server/StaticFileConfig.cj`（新建）
- **操作步骤**：
  1. 创建 `StaticFileConfig.cj`，定义配置字段：root（默认 `./public`）、urlPrefix（默认 `/`）、enableSpaFallback（默认 true）、cacheMaxAge（默认 3600）、compressionEnabled（默认 true）、compressionMinSize（默认 1024）、compressionLevel（默认 6）、allowedExtensions（默认白名单集合）。
  2. 实现 `loadFromEnv()` 方法：从 `Env.get("STATIC_FILE_ROOT")` 等环境变量读取配置，使用默认值兜底。
  3. 实现 `resolvePath(baseDir: String): String` 方法：将相对路径转换为基于 baseDir 的绝对路径。
- **验收条件**：
  - StaticFileConfig 可正确从 .env 读取所有 STATIC_FILE_* 配置项
  - 未配置时使用默认值
  - 相对路径可正确解析

### T8.2 实现 MimeTypeResolver MIME 类型解析器

- **任务ID**：T8.2
- **标题**：创建 MimeTypeResolver 类，实现文件扩展名到 MIME 类型的映射
- **前置任务**：T1.8
- **涉及文件**：`src/app/core/server/MimeTypeResolver.cj`（新建）
- **操作步骤**：
  1. 创建 `MimeTypeResolver.cj`，内部维护 `HashMap<String, String>` 扩展名→MIME 类型映射表。
  2. 支持以下文件类型：css/text/css、js/application/javascript、json/application/json、html/text/html; charset=utf-8、png/image/png、jpg/image/jpeg、jpeg/image/jpeg、gif/image/gif、svg/image/svg+xml、ico/image/x-icon、webp/image/webp、woff/font/woff、woff2/font/woff2、ttf/font/ttf、eot/application/vnd.ms-fontobject、xml/application/xml、txt/text/plain、pdf/application/pdf、map/application/json。
  3. 实现 `resolve(extension: String): String` 方法，未知扩展名返回 `application/octet-stream`。
  4. 实现 `isCompressible(mimeType: String): Bool` 方法，判断 MIME 类型是否适合压缩（text/*、application/javascript、application/json、application/xml、image/svg+xml）。
- **验收条件**：
  - 所有支持的扩展名可正确返回 MIME 类型
  - 未知扩展名返回 application/octet-stream
  - isCompressible 正确区分可压缩和不可压缩类型

### T8.3 实现 StaticFileHandler 静态文件处理器核心逻辑

- **任务ID**：T8.3
- **标题**：创建 StaticFileHandler 类，实现静态文件请求处理、安全防护、SPA Fallback
- **前置任务**：T8.1、T8.2
- **涉及文件**：`src/app/core/server/StaticFileHandler.cj`（新建）
- **操作步骤**：
  1. 创建 `StaticFileHandler.cj`，实现 `handle(req: HttpRequest): HttpResponse` 声明式 Handler。
  2. **安全防护**：
     - 实现 `validatePath(path: String): Bool`：路径规范化，检测 `..` 路径遍历，返回 403。
     - 隐藏文件过滤：路径包含 `/.` 时返回 404。
     - 所有响应添加 `X-Content-Type-Options: nosniff` 头。
  3. **文件服务**：
     - 根据 `STATIC_FILE_ROOT` 和请求路径构建文件系统路径。
     - 检查文件是否存在且是普通文件。
     - 扩展名白名单检查（不在白名单内返回 403）。
     - 读取文件内容，设置 Content-Type（通过 MimeTypeResolver）。
  4. **SPA History Fallback**：
     - 实现 `isSpaFallbackCandidate(path, req): Bool`：GET 请求 + 路径不以文件扩展名结尾。
     - Fallback 时返回 `STATIC_FILE_ROOT/index.html`。
  5. **缓存控制**：
     - ETag 生成：基于文件内容哈希（MD5 或简单哈希）。
     - Last-Modified：基于文件修改时间，RFC 1123 格式。
     - 条件请求：检查 If-None-Match 和 If-Modified-Since，匹配时返回 304。
     - Cache-Control：`public, max-age={cacheMaxAge}`。
  6. **范围请求**：
     - 解析 Range 头（`bytes=start-end`）。
     - 返回 206 Partial Content + Content-Range 头。
     - 所有响应添加 `Accept-Ranges: bytes` 头。
- **验收条件**：
  - 路径遍历请求返回 403
  - 隐藏文件请求返回 404
  - 正常文件请求返回正确内容和 MIME 类型
  - SPA Fallback 对非文件路径返回 index.html
  - ETag/If-None-Match 条件请求返回 304
  - Range 请求返回 206

### T8.4 实现压缩支持

- **任务ID**：T8.4
- **标题**：基于 compress4cj 实现 Gzip/Brotli 压缩响应
- **前置任务**：T8.3
- **涉及文件**：`src/app/core/server/StaticFileHandler.cj`（修改）
- **操作步骤**：
  1. 在 StaticFileHandler 中引入 compress4cj 的 GzipCompressor 和 BrotliCompressor。
  2. 实现 `compressResponse(content, acceptEncoding, mimeType, config): (Array<UInt8>, String)` 方法：
     - 检查文件大小是否 >= compressionMinSize。
     - 检查 MIME 类型是否可压缩（MimeTypeResolver.isCompressible）。
     - 检查 Accept-Encoding 头：优先 Brotli（`br`），其次 Gzip。
     - 压缩失败时回退为未压缩响应，日志记录压缩错误。
  3. 在 serveFile 方法中集成压缩：压缩后设置 Content-Encoding 头，更新 Content-Length。
- **验收条件**：
  - CSS/JS 请求带 Accept-Encoding: gzip 时返回压缩响应
  - 图片请求不压缩
  - 小文件（< 1KB）不压缩
  - 压缩失败时回退为未压缩响应

### T8.5 HTTPServer.cj 集成静态文件路由

- **任务ID**：T8.5
- **标题**：在 HTTPServer.start() 中注册静态文件兜底路由
- **前置任务**：T8.3
- **涉及文件**：`src/app/core/server/HTTPServer.cj`（修改）
- **操作步骤**：
  1. 在 HTTPServer 类中新增 `private var staticFileConfig: ?StaticFileConfig` 字段。
  2. 新增 `setStaticFileConfig(config: StaticFileConfig)` 方法。
  3. 在 `start()` 方法中，`setupRoutes()` 之后注册静态文件路由：
     - 检查 `staticFileConfig` 是否存在。
     - 检查 `STATIC_FILE_ROOT` 目录是否存在。
     - 目录存在时创建 `StaticFileHandler` 实例，注册兜底路由 `_httpLibRouter.get("/*", handler.handle)`。
     - 目录不存在时输出 WARN 日志，跳过注册。
  4. 确保静态文件路由在所有 API 路由之后注册（http_lib Router 按注册顺序匹配，先注册优先）。
- **验收条件**：
  - STATIC_FILE_ROOT 目录存在时静态文件路由注册成功
  - API 路由优先级高于静态文件路由
  - STATIC_FILE_ROOT 目录不存在时输出 WARN 日志，API 路由正常工作

### T8.6 main.cj 集成 STATIC_FILE_ROOT 配置

- **任务ID**：T8.6
- **标题**：在 main.cj 中读取 STATIC_FILE_ROOT 配置并注入 HTTPServer
- **前置任务**：T8.5
- **涉及文件**：`src/app/main.cj`（修改）
- **操作步骤**：
  1. 在 `Application.init` 中读取 `Env.get("STATIC_FILE_ROOT")`。
  2. 若配置存在且非空：创建 `StaticFileConfig`，调用 `loadFromEnv()`，调用 `server.setStaticFileConfig(sfsConfig)`。
  3. 若配置不存在：不设置 StaticFileConfig，静态文件服务不启用。
  4. 在 `.env.example` 中添加 `STATIC_FILE_ROOT=./public` 配置项及注释。
- **验收条件**：
  - .env 中配置 STATIC_FILE_ROOT 后 runtime 启动时启用静态文件服务
  - .env 中未配置时静态文件服务不启用，不影响 API 服务

### T8.7 静态文件服务集成验证

- **任务ID**：T8.7
- **标题**：静态文件服务功能验证（安全/缓存/压缩/SPA Fallback）
- **前置任务**：T8.6
- **涉及文件**：无（运行时验证）
- **操作步骤**：
  1. **基础文件服务**：在 `./public/` 目录放置测试文件（test.css、test.js、test.png），验证请求返回正确内容和 MIME 类型。
  2. **API 路由优先级**：验证 `GET /api/v1/uctoo/health` 返回 JSON，不被静态文件路由拦截。
  3. **SPA History Fallback**：请求 `GET /vue-pro/aibuilder`（非文件路径），验证返回 index.html。
  4. **路径遍历防护**：请求 `GET /../../../etc/passwd`，验证返回 403。
  5. **隐藏文件过滤**：请求 `GET /.env`，验证返回 404。
  6. **ETag 条件请求**：首次请求获取 ETag，再次请求带 If-None-Match，验证返回 304。
  7. **Gzip 压缩**：请求 CSS/JS 文件带 Accept-Encoding: gzip，验证响应包含 Content-Encoding: gzip。
  8. **图片不压缩**：请求 PNG 文件带 Accept-Encoding: gzip，验证响应无 Content-Encoding。
  9. **STATIC_FILE_ROOT 不存在**：配置不存在的目录，验证 runtime 启动输出 WARN 日志，API 服务正常。
- **验收条件**：
  - 所有 9 项验证通过

---

## 任务依赖关系总览

```
Phase 0 (依赖链本地化)
  T0.1 → T0.2 → T0.4
  T0.1 → T0.3 → T0.4
  T0.4 ──────────────────────┐
                              │
Phase 1 (HTTPServer.cj 重写)  │
  T0.4 → T1.1 → T1.2 → T1.3 → T1.4 → T1.5 → T1.6 → T1.7 → T1.8
                                                              │
Phase 2 (WebSocket 迁移)                                      │
  T1.8 → T2.1 → T2.2                                         │
  T2.1 → T2.3                                                 │
                                                              │
Phase 3 (SSE 迁移)                                            │
  T1.8 → T3.1                                                 │
                                                              │
Phase 4 (HTTP 客户端替换)                                     │
  T0.4 → T4.1                                                 │
  T0.4 → T4.2                                                 │
  T0.4 → T4.3                                                 │
  T0.4 → T4.4                                                 │
                                                              │
Phase 5 (main.cj 修改)                                        │
  T1.8 → T5.1                                                 │
                                                              │
Phase 6 (配置清理)                                            │
  T5.1 → T6.1                                                 │
  T5.1 → T6.2                                                 │
                                                              │
Phase 7 (集成测试)                                            │
  T6.2 → T7.1 → T7.2 → T7.3 → T7.4                           │
                                                              │
Phase 8 (静态文件服务 — runtime 0.0.26 新增)                   │
  T1.8 → T8.1 → T8.3 → T8.5 → T8.6 → T8.7                    │
  T1.8 → T8.2 → T8.3                                         │
  T8.3 → T8.4                                                 │
```

## 验收检查清单

- [ ] `grep -r "stdx.net.http" src/` 仅命中 `src/examples/` 目录
- [ ] `grep -r "stdx.net.tls\|stdx.crypto.x509" src/` 无命中
- [ ] `grep -r "ServerBuilder\|FuncHandler\|HttpRequestDistributor\|HttpContext" src/app/core/server/HTTPServer.cj` 无命中
- [ ] `grep -r "WebSocket.upgradeFromServer" src/` 无命中
- [ ] cjpm.toml 含 8 个 http_lib 依赖链 path 声明，无 git 声明
- [ ] 主项目 cjc 1.0.5 编译通过
- [ ] 10053 复现场景：客户端中途断开后服务端 errorLog 输出，进程不崩溃
- [ ] 核心 REST API P95 延迟不劣于基线 110%
- [ ] WebSocket 消息往返延迟 P95 不劣于基线 110%
- [ ] SSE 首事件下发延迟 < 500ms（本地环境）
- [ ] 服务连续运行 24h 无崩溃、无端口失效
- [ ] 静态文件服务：`STATIC_FILE_ROOT=./public` 配置后，`GET /vue-pro/aibuilder` 返回 index.html
- [ ] 静态文件服务：API 路由优先级验证，`GET /api/v1/uctoo/health` 返回 JSON
- [ ] 静态文件服务：路径遍历防护验证，`GET /../../../etc/passwd` 返回 403
- [ ] 静态文件服务：隐藏文件过滤验证，`GET /.env` 返回 404
- [ ] 静态文件服务：ETag 条件请求验证，返回 304
- [ ] 静态文件服务：Gzip 压缩验证，CSS/JS 响应包含 Content-Encoding: gzip
- [ ] 静态文件服务：SPA History Fallback 验证，非文件路径返回 index.html