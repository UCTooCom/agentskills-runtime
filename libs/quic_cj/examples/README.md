 # quic_cj 示例代码
 
 本目录包含 quic_cj QUIC 传输协议库的示例代码，
 涵盖配置、连接管理、流多路复用、拥塞控制、错误处理等场景。
 
 每个场景位于独立的子目录中，包含一个 `main.cj` 源文件和本 `README.md` 说明。
 
 ## 示例列表
 
 | 场景 | 说明 |
 |------|------|
 | [basic_usage](basic_usage/) | 基本 QUIC 库使用模式 — 配置、连接、流、错误处理 |
 | [config_customization](config_customization/) | 配置选项调优 — 性能、低资源、版本选择 |
 | [connection_lifecycle](connection_lifecycle/) | 连接状态机 — Initial → Handshake → Established → Closed |
 | [stream_multiplexing](stream_multiplexing/) | 流多路复用 — 单连接上并发多流 |
 | [echo_server](echo_server/) | 回显服务器 — 监听、接受连接、回显数据 |
 | [echo_client](echo_client/) | 回显客户端 — 拨号、发送、验证回显 |
 | [flow_control](flow_control/) | 流量控制 — 流级别和连接级别窗口管理 |
 | [congestion_demo](congestion_demo/) | 拥塞控制演示 — CUBIC 算法、调节器、带宽估计 |
 | [error_handling](error_handling/) | 错误处理 — 传输层/应用层错误、连接关闭 |
 | [tls_integration](tls_integration/) | TLS 1.3 集成 — 初始 AEAD、密码套件、握手 |
 | [version_negotiation](version_negotiation/) | 版本协商 — QUIC v1/v2 选择与兼容性 |
 | [ack_handling](ack_handling/) | ACK 处理与丢包检测 — 已发送/已接收包追踪 |
 | [packet_buffering](packet_buffering/) | 包缓冲与内存管理 — 环形缓冲区、对象池 |
 
 ## 使用方法
 
 每个示例均可作为独立项目运行。
 
 ```bash
 # 构建并运行回显服务器（在一个终端）
 cd sample/echo_server
 cjpm run
 
 # 构建并运行回显客户端（在另一个终端）
 cd sample/echo_client
 cjpm run
 ```
 
 对于仅演示 API 模式的示例，请查看源代码。
