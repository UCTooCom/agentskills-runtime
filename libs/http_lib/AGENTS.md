# http_lib 开发指引

## 项目概览

- **名称**: `http_lib` — 仓颉 HTTP 封装库
- **语言**: 仓颉 (Cangjie) v1.0.5 (cjc v1.0.5, cjpm v1.0.5)
- **类型**: 静态库 (`output-type = "static"`)
- **目标**: 基于 TCP 实现 HTTP/1.x + HTTP/2 全协议封装，提供 Server + Client 能力

## 目录布局

```
src/            # 库源码
  core/         # HTTP 核心类型: method, status, headers, errors, context
  buffer/       # 可增长的 ByteBuffer
  message/      # Request/Response 解析、Body、压缩、Range
  router/       # Radix tree 路由器、中间件、CORS
  server/       # TCP HTTP 服务器、TLS、文件服务、安全中间件
  client/       # HTTP 客户端、传输层、连接池、认证
  connection/   # TCP/TLS 连接层、ALPN 解析
  http2/        # HTTP/2: HPACK、帧编码、流量控制、多路复用
  utils/        # 工具函数: bytes, hex, parse, URL 解析
  testutil/     # TestServer 与 mock 连接 (供测试使用)
test/           # 集成、基准、压力、文档示例测试
docs/           # 用户手册 (中英文镜像)
examples/         # 26 个示例程序
```

## 构建、测试与开发命令

```bash
cjpm build              # 完整构建
cjpm build -i           # 增量构建
cjpm test               # 运行所有单元测试 (1921)
cjpm test --filter NAME # 按 TestCase 方法名或 Test 类名筛选运行
cjpm update             # 更新依赖（上游变更后执行）
cjpm bench               # 性能基准测试 (基于 @Bench 宏)
```

编译器: `cjc v1.0.5`，编译选项: `-Woff unused`（在 `cjpm.toml` 中配置）。

## 编码风格

- **注释**: 全部使用简体中文。
- **文档**: 每个 `*.md` 为简体中文，`*.en.md` 为英文翻译。
- **文件**: 仓颉源文件使用 `.cj` 扩展名；类名 PascalCase，方法/变量名 camelCase。
- **match 表达式**: `case` 后不使用 `{}`，多行表达式直接书写。
- **关键字冲突**: `match` 是保留字，不可用作变量名（用 `isMatch`）。
- **断言**: 使用 `src/core/test_helpers.cj` 中的 `assertTrue()` / `assertFalse()`。
- **测试文件**: 命名为 `<module>_test.cj`，与源码同目录放置。

## 文档结构

`docs/` 目录包含完整的中英文镜像文档，按模块组织：

```
docs/
├── README.md              # 文档入口（中文）
├── README.en.md           # 文档入口（英文）
├── manual.md              # 完整使用手册（中文）
├── manual.en.md           # 完整使用手册（英文）
├── core/api.md            # 核心 API 参考（中文）
├── buffer/                # ByteBuffer 文档（中英文）
├── connection/            # Connection 接口与 TCP/TLS 文档（中英文）
├── utils/                 # 工具函数文档（中英文）
├── testutil/              # TestServer、ResponseRecorder 文档（中英文）
├── server/                # Server 使用指南、安全、TLS 文档
├── client/                # Client 使用指南、高级用法文档
└── http2/overview.md      # HTTP/2 概览
```

每个模块目录下均包含 `README.md`（中文）和 `README.en.md`（英文）。
中英文文档保持同步，更新时需同时修改两份。

## 仓颉语言要点

- 阅读[CANGJIE_GUIDE.md](./CANGJIE_GUIDE.md)
- `jinguissl_core` 使用 `import jinguissl_core.crypto.digest.{...}`，而非 `import jinguissl_core.jinguissl.crypto.digest.{...}`。

## 核心设计模式

- **HTTP 协议设计对齐**: `HttpServer` 管理 TCP 监听与请求分发，`ResponseWriter` 提供流式响应写入，`HttpTransport` 实现连接复用与请求传输，`HttpClient` 封装完整请求周期。
- **流式响应**: `ResponseWriter` 支持 `write()`、`writeHeader()`、`flush()` 用于分块/SSE 流式传输，通过 `Hijacker` 支持协议升级。
- **中间件洋葱模型**: `MiddlewareChain` 从外向内包裹处理器，`router.handler()` 自动应用中间件链。
- **连接池**: `HttpTransport` 维护按主机分组的连接池，支持最大空闲连接数限制和空闲超时淘汰。
