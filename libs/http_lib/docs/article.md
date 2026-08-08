开源推荐 | 仓颉语言 HTTP 封装库 http_lib 纯标准库实现，HTTP/1 + HTTP/2 + HTTP/3
写在前面
仓颉编程语言（Cangjie）作为华为自研编程语言，生态正在快速成长。网络编程是绝大多数应用的刚需，然而成熟可用的 HTTP 封装库一直是语言生态里的关键缺口。

这里介绍一个开源项目：http_lib。它是仓颉社区首个完全基于标准库（std）开发的 HTTP 协议封装库，零 stdx 依赖，纯仓颉语法实现，覆盖 HTTP/1.x + HTTP/2 完整协议，以及 HTTP/3 类型定义层（帧编解码 + QPACK 头压缩，QUIC 传输层需外部实现），同时提供 Server 和 Client 完整能力。

项目地址：https://atomgit.com/changeden/http_lib

一句话概括
约 48,000 行纯仓颉源码、1576 个测试全部通过、32 个示例程序。如果你想用仓颉写 HTTP 服务或调用 HTTP API，这是目前社区里功能最完整的库。

对仓颉生态的意义
在 http_lib 出现之前，仓颉社区里要做 HTTP 通信要么依赖 stdx 扩展库，要么手写 TCP + 协议解析。这两种方式各有痛点：stdx 并非官方标准库的一部分，版本兼容性难以保证；手写 TCP 解析则工作量大且容易出错。

http_lib 的价值在于：

• 纯标准库开发，零 stdx 依赖：只用仓颉标准库 std 自带的 net / io / collection 等包，不依赖任何 stdx 扩展。这意味着只要安装了仓颉 SDK 就能编译使用，不存在外部扩展库的版本漂移问题
• 纯仓颉语法实现：不使用 C 语言 FFI 调用，不内嵌其他语言的运行时，完全用仓颉自身的类型系统和特性编写。既保证了代码的可读性和可维护性，也为仓颉社区提供了高质量的"纯正"代码参考
• 高性能：Radix Tree 路由、零拷贝字节缓冲、连接池复用、HPACK Huffman 编码等——所有性能敏感路径都用仓颉原生的方式做了优化，没有因为"纯语法"而牺牲效率
• 协议覆盖面最广：从 HTTP/1.1 的 keep-alive、chunked 编码、管道化，到 HTTP/2 的多路复用、流控制、Server Push，再到 HTTP/3 类型定义层（QUIC 帧编解码 + QPACK 头压缩），是目前仓颉社区协议支持最完整的 HTTP 库
作为仓颉社区较早实现 HTTP/2 多路复用的开源库之一，http_lib 证明了仓颉语言在网络编程领域的可行性——即使没有 C 扩展，纯仓颉代码也能写出高性能的协议实现。

能做什么？
http_lib 按模块划分为几大块：

core — Method、Status、Headers、Version、Date、Error 等 HTTP 核心类型

message — Request/Response 的构建与解析、Body 读写、Chunked 编解码、压缩（gzip/deflate/brotli）、Range 请求、条件请求、缓存控制

buffer — 可动态增长的 ByteBuffer，用于高效字节操作

connection — TCP / TLS 连接层，支持 ALPN 协议协商和双向 mTLS 认证

router — 基于 Radix Tree 的高性能路由，支持 :id 路径参数和 *path 通配路由，配合洋葱模型的中间件链

server — TCP HTTP Server，支持 HTTPS、h2c 升级、WebSocket（RFC 6455）、SSE 推送、文件服务（MIME 嗅探 + Range 断点续传）、虚拟主机、反向代理、优雅关闭

client — HTTP Client，支持连接池复用、Pipelining 管道化、Digest Auth（完整 RFC 7616，SHA-256）、Cookie 管理、流式响应

http2 — 完整的 HTTP/2 实现：10 种帧类型全支持、HPACK Huffman 编码、多路复用、流控制、优先级调度、Server Push、Extended CONNECT 隧道

http3 — HTTP/3 类型定义层，包含 QUIC 帧编解码和 QPACK 头压缩

testutil — TestServer 和 MockConnection，方便写测试

服务端能力
• Radix Tree 路由器，支持静态路由、:id 路径参数、*path 通配路由，查找 O(k)
• 完整中间件链（洋葱模型），内置 logging、CORS（严格预检校验）、安全头（HSTS/CSP/X-Frame-Options）、IP 速率限制
• TLS/HTTPS 开箱即用，ALPN 协议协商自动选择 h2 或 http/1.1
• WebSocket 升级（RFC 6455），32 个示例里包含 websocket_chat 聊天室
• SSE 服务端事件推送
• HTTP/2 Server Push 主动推送资源
• 虚拟主机和反向代理
• 优雅关闭
• 文件服务：MIME 嗅探、Range 请求、条件请求、断点续传
• 流式上传/下载：chunked 编码、流式文件传输
客户端能力
• 全 HTTP 方法：GET / POST / PUT / PATCH / DELETE / HEAD / OPTIONS
• HTTPS + HTTP/2 自动协商，支持 h2 ALPN 协商
• 连接池：按主机分组，空闲超时淘汰
• Pipelining（HTTP/1.1 管道）：单连接流水线批量请求
• Digest Auth：完整 RFC 7616，SHA-256 算法，nonce 计数防重放
• CookieJar 管理
• Builder 模式链式构建请求
• 流式响应分块读取
HTTP/2 完整实现
不是半吊子实现。下面这些全部做了：

• 帧层：DATA / HEADERS / PRIORITY / RST_STREAM / SETTINGS / PUSH_PROMISE / PING / GOAWAY / WINDOW_UPDATE / CONTINUATION 全支持
• HPACK：Huffman 编码/解码，动态表 + 61 条静态表，敏感头自动保护不加入动态表
• 多路复用：单连接并发流
• 流控制：连接级 + 流级窗口精确跟踪
• 优先级调度：PriorityWriteScheduler 权重调度
• 流程安全：WINDOW_UPDATE 零增量拒绝、GOAWAY Last-Stream-ID 单调性校验、CONTINUATION 帧序验证
• Extended CONNECT（RFC 8441）：WebSocket over HTTP/2 隧道
HTTP/3（进行中）
底层 QUIC 传输层需外部实现（如 quic-go），目前库中已完成了 HTTP/3 的类型定义、帧编解码、QPACK 头压缩编码和解码。示例目录里有 http3_server 示例。

代码体验
服务端 5 行启动：

import http_lib.server.{HttpServer, HttpServerConfig}
import http_lib.router.Router
import http_lib.core.{HttpStatus}
import http_lib.message.{HttpRequest, HttpResponse}

let router = Router()
router.get("/", { req => HttpResponse.text(HttpStatus.OK, "Hello, World!") })
HttpServer(handler: router.handler()).listenAndServe("0.0.0.0", 8080)
客户端 3 行请求：

import http_lib.client.HttpClient

let client = HttpClient()
let resp = client.get("https://httpbin.org/json")
println(resp.bodyAsString())
client.close()
构建一个带中间件的 REST API 服务器也是几分钟的事，项目 sample/rest_api 里提供了一个完整的 CRUD 示例，包含 HSTS + CORS + 速率限制 + 访问日志 + JSON 请求处理。

项目质量
• 源码行数约 48,000 行，199 个文件
• 1576 个测试用例全部通过（单元测试 + 集成测试 + 基准测试）
• 32 个示例程序覆盖从 Hello World 到 WebSocket 聊天室、HTTP/2 Push、反向代理等场景
• 编译器 cjc v1.0.5，编译优化 -O2，静态库输出
• 不依赖 stdx，不依赖外部 C 库（TLS 通过纯仓颉实现的 jinguissl）
文档与学习
项目 docs 目录包含完整的中英文镜像文档：

• 完整使用手册，从安装到高级用法
• Server / Client / Router / HTTP/2 每个模块都有独立文档
• 安全指南：HTTPS/TLS 配置、安全中间件使用
• 32 个示例覆盖了几乎所有使用场景，直接可运行
适合谁用？
1. 正在用仓颉写后端服务的团队 — 直接替代手写 TCP + HTTP 解析
2. 想评估仓颉语言生态的人 — http_lib 是衡量社区成熟度的好样本
3. 对 HTTP/2、HTTP/3 协议实现感兴趣的人 — 纯仓颉源码，阅读学习没有语言障碍
4. 需要仓颉 HTTP 客户端的开发者 — 开箱即用，支持连接池和认证
如何参与
项目托管在 atomgit，搜索 changeden/http_lib 即可找到。欢迎提 Issue 和 PR。

最后说两句：一个语言生态的成熟，离不开基础组件库的积累。http_lib 选择了一条更难的路——不用 stdx、不写 C 扩展，完全用仓颉标准库和仓颉语法来实现完整的 HTTP 协议栈。这条路走通了，而且走得很扎实。这本身就说明仓颉语言的表达能力已经足够支撑工业级的网络编程。

如果你也在用仓颉写东西，不妨试试这个库。踩到坑、有想法，直接去提 Issue 就好。

欢迎转发给身边关心仓颉生态的朋友。