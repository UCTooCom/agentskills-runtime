# http_lib 替换 stdx.net.http 可行性与工作量分析（v2 更新版）

## 〇、关键发现

### 发现1：主项目不依赖f_mvc

agentskills-runtime的cjpm.toml中**没有f_mvc依赖**，只使用了fountain的以下模块：
- f_orm, f_data, f_config, f_util, f_ticktock, f_aspect, f_bean

这些模块**都不依赖stdx.net.http**，因此**fountain f_mvc不是迁移障碍**。

### 发现2：仓颉SDK已升级到1.0.5并编译通过

| 组件 | 版本 | 状态 |
|------|------|------|
| agentskills-runtime | cjc 1.0.5 | ✅ 编译通过 |
| http_lib | cjc 1.1.3 | ✅ 已复制到libs目录 |
| quic_cj | cjc 1.0.5 | ✅ 已复制到libs目录 |
| fountain (主项目使用的模块) | cjc 1.0.5 | ✅ 编译通过 |

### 发现3：http_lib最新版本关键变化

- **cjc-version = "1.1.3"**（非1.0.5，但向下兼容1.0.5）
- **output-type = "static"**（静态库，无DLL导出冲突）
- **1921个测试全部通过**（从1576增长）
- **26个示例程序**
- **新增quic_cj依赖**（HTTP/3 QUIC传输层）
- **6个git依赖**：kaca_json, jinguissl, jinguissl_core, kaca_cookies, compress4cj, quic_cj

### 发现4：http_lib依赖链需要本地化

http_lib有6个git依赖，quic_cj有3个git依赖。为避免cjpm缓存冲突和版本问题，需要将这些依赖也克隆到libs目录作为path依赖。

---

## 一、http_lib vs stdx.net.http API对比

### 1.1 架构对比

| 维度 | stdx.net.http (当前) | http_lib (新) |
|------|---------------------|---------------|
| **协议支持** | HTTP/1.1 | HTTP/1.0 + HTTP/1.1 + HTTP/2 + HTTP/3(QUIC) |
| **依赖基础** | 依赖 stdx 扩展库 | **纯仓颉标准库(std)实现，零stdx依赖** |
| **适配仓颉版本** | 1.0.5 | **1.1.3** (向下兼容1.0.5) |
| **TLS实现** | stdx.net.tls + stdx.crypto.x509 | JinguiSSL (纯仓颉实现，无C FFI) |
| **路由** | 无内置，需自行实现 HttpRequestDistributor | 内置基数树路由器 + 虚拟主机 + 路由分组 |
| **中间件** | 无内置，需自行实现 MiddlewareChain | 洋葱模型 MiddlewareChain，内置10+中间件 |
| **Handler签名** | `(HttpContext) -> Unit` (副作用式) | `(HttpRequest) -> HttpResponse` (函数式) |
| **响应构建** | 命令式: `context.responseBuilder.status(200).header(...).body(...)` | 声明式: `HttpResponse.json(HttpStatus.OK, body)` |
| **WebSocket** | 基础支持 (upgradeFromServer) | RFC 6455完整实现 + PMD压缩 |
| **SSE** | 需手动实现 | 内置 SSEWriter |
| **连接管理** | 框架内部黑盒，10053问题无法控制 | Connection接口 + ConnState回调 + idleTimeout |
| **超时配置** | readTimeout/writeTimeout | readTimeout/writeTimeout/readHeaderTimeout/idleTimeout/drainTimeout |
| **错误处理** | 框架内部WARN日志，应用无法捕获 | HttpException层次体系 + errorLog回调 |
| **HTTP/2** | 不支持 | HPACK + 流多路复用 + 服务端推送 |
| **压缩** | 无内置 | gzip/deflate/brotli 透明压缩中间件 |
| **安全** | 无内置 | HSTS/CSP/CSRF/安全头/速率限制 |
| **测试覆盖** | 未知 | 1921个测试全部通过 + 26个示例 |
| **FFI依赖** | 有（底层C实现） | **无C FFI，纯仓颉语法实现** |

### 1.2 核心API对照表

| 概念 | stdx.net.http | http_lib |
|---|---|---|
| Server启动 | `ServerBuilder().build().start()` | `HttpServer(handler:).listenAndServe(host, port)` |
| HTTPS启动 | `TlsServerConfig(...)` | `HttpServer(handler:, config:).listenAndServeTls(host, port)` |
| Handler签名 | `(HttpContext) -> Unit` | `Handler = (HttpRequest) -> HttpResponse` |
| 路由注册 | 自行实现HttpRequestDistributor | `Router().get/post/put/delete(path, handler)` |
| 中间件 | 自行实现MiddlewareChain | `Middleware = (Handler) -> Handler`，`router.use(m)` |
| 流式响应 | context.responseBuilder.body() | `StreamingHandler = (HttpRequest, ResponseBuilder) -> Unit` |
| WebSocket升级 | WebSocket.upgradeFromServer(ctx) | `ConnectionController(conn).upgradeToWebSocket(req)` + `WebSocketConn(conn)` |
| SSE | 手动实现 | `SSEWriter(resp, conn).sendEvent(...)` |
| HTTP客户端 | `ClientBuilder().build().send(req)` | `HttpClient().get/post/send(req)` |
| 请求构建 | `HttpRequestBuilder().build()` | `HttpRequestBuilder().get().withUrl(u).withJson(j).build()` |
| 响应构建 | `context.responseBuilder.status(200).body(json)` | `HttpResponse.json(HttpStatus.OK, json)` |
| TLS配置 | TlsServerConfig(证书PEM) | `TlsConfig(serverCertPath: "cert.pem", serverKeyPath: "key.pem")` |
| 路径参数 | 自行解析 | `req.pathParams["id"]`（路由`/users/:id`） |
| 查询参数 | 自行解析 | `req.queryParam("q")` / `req.queryParams()` |
| 连接状态 | 无 | `HttpServerConfig.connState: ?(ConnState) -> Unit` |
| 错误日志 | WARN日志 | `HttpServerConfig.errorLog: ?(String) -> Unit` |

### 1.3 http_lib 解决10053问题的关键特性

| 特性 | 说明 | 对10053的影响 |
|------|------|-------------|
| **声明式响应** | Handler返回HttpResponse，框架负责写入 | **框架统一管理响应写入，写入前检测连接可用性——根本解决10053** |
| **Connection接口** | isConnected/canReuseTransport | **框架可检测连接可用性再写入——stdx.net.http缺少此能力** |
| **idleTimeout** | Keep-Alive连接空闲超时，默认60s | 明确控制连接生命周期，避免连接半开 |
| **ConnState回调** | 连接状态变化通知(NEW/ACTIVE/IDLE/HIJACKED/CLOSED) | 可监控连接状态，提前发现异常 |
| **errorLog回调** | 所有框架错误通过回调输出 | 可捕获socket写入错误，而非仅WARN日志 |
| **recoveryMiddleware** | 异常恢复中间件，自动返回500 | 防止未捕获异常导致连接泄漏 |
| **纯仓颉实现** | 无C FFI，连接层代码完全可控 | 出现socket问题时可直接在仓颉层调试修复 |

---

## 二、agentskills-runtime 依赖 stdx.net.http 的范围

### 2.1 直接依赖（src/目录）— 需要修改

| 文件 | 导入类 | 用途 | 迁移难度 |
|------|--------|------|---------|
| `HTTPServer.cj` | Server, ServerBuilder, HttpContext, FuncHandler, HttpRequestDistributor, HttpRequestHandler, TlsServerConfig, X509Certificate, PrivateKey | **核心HTTP服务器** | **中** |
| `WebMCPController.cj` | HttpContext, WebSocket, WebSocketFrameType, HttpHeaders | WebSocket连接 | 低 |
| `WsChatController.cj` | HttpContext, WebSocket, WebSocketFrameType, HttpHeaders | WebSocket聊天 | 低 |
| `AIController.cj` | HttpHeaders | 读取请求头 | 低 |
| `ws_models.cj` | WebSocket, WebSocketFrameType | WebSocket消息模型 | 低 |
| `sse_mcp_server.cj` | stdx.net.http.* | SSE服务 | 中 |
| `http_cj.cj` | Client, ClientBuilder, HttpRequest, HttpRequestBuilder, TlsClientConfig | HTTP客户端 | 低 |
| `http_curl.cj` | HttpHeaders | HTTP响应头 | 低 |
| `http_utils.cj` | HttpHeaders | HTTP工具类 | 低 |

### 2.2 间接依赖（libs/目录）— 不需要修改

| 库 | 说明 |
|----|------|
| **fountain f_orm/f_data/f_config/f_util/f_ticktock/f_aspect/f_bean** | ✅ 主项目使用，不依赖stdx.net.http |
| **fountain f_mvc/f_httpclient/f_jwt** | ❌ 主项目未使用 |
| **activemq4cj/cj_mail/cos-sdk/hyperion** | 独立库，保留stdx依赖 |

---

## 三、http_lib依赖链

### 3.1 http_lib直接依赖

| 依赖 | git地址 | 说明 |
|------|---------|------|
| kaca_json | gitcode.com/changeden/kaca_json (optz) | JSON处理 |
| jinguissl | gitcode.com/changeden/jinguiSSL (optz) | TLS/SSL实现 |
| jinguissl_core | gitcode.com/CjKu/JinguiCore | 加密核心 |
| kaca_cookies | gitcode.com/cangjie_no_1/kaca_cookies | Cookie处理 |
| compress4cj | gitcode.com/changeden/compress4cj | 压缩支持 |
| quic_cj | gitcode.com/changeden/quic_cj | QUIC/HTTP3 |

### 3.2 quic_cj直接依赖

| 依赖 | git地址 | 说明 |
|------|---------|------|
| jinguissl | gitcode.com/changeden/jinguiSSL (optz) | TLS/SSL实现 |
| jinguissl_core | gitcode.com/CjKu/JinguiCore | 加密核心 |
| channel_cj | gitcode.com/changeden/channel_cj | 通道通信 |

### 3.3 依赖本地化策略

将所有git依赖克隆到libs目录，改为path依赖，避免cjpm缓存冲突：
- libs/http_lib → 已复制
- libs/quic_cj → 已复制
- libs/kaca_json, libs/jinguissl, libs/jinguissl_core, libs/kaca_cookies, libs/compress4cj, libs/channel_cj → 需克隆

---

## 四、工作量估算

| 阶段 | 任务 | 文件数 | 工作量(人天) | 风险 |
|------|------|--------|------------|------|
| **Phase 0** | http_lib依赖链本地化（克隆6个git依赖到libs） | 6 | 1 | 低 |
| **Phase 1** | 用http_lib重写HTTPServer.cj | 1 | 3 | 中 |
| **Phase 2** | 迁移WebSocket到http_lib API | 2 | 1.5 | 低 |
| **Phase 3** | 迁移SSE到http_lib内置SSEWriter | 1 | 1 | 中 |
| **Phase 4** | 替换HTTP客户端为http_lib Client | 3 | 1 | 低 |
| **Phase 5** | 修改main.cj服务器初始化 | 1 | 1 | 中 |
| **Phase 6** | cjpm.toml配置+移除stdx.net.http依赖 | 1 | 0.5 | 低 |
| **Phase 7** | 全量集成测试 | - | 2 | 中 |
| **合计** | | **15+** | **11** | **中** |

---

## 五、推荐方案

### 中期（1-2周）：用http_lib替换stdx.net.http

**这是10053问题的根本解决方案**。执行路径：

1. **Phase 0**：http_lib依赖链本地化
2. **Phase 1**：用http_lib重写HTTPServer.cj（最关键，解决10053）
3. **Phase 2-3**：迁移WebSocket和SSE
4. **Phase 4-5**：替换HTTP客户端+修改main.cj
5. **Phase 6-7**：配置+全量测试

### 长期：启用http_lib的HTTP/2

http_lib的HTTP/2支持可显著提升前端性能，只需设置`HttpServerConfig.enableHttp2 = true`。
