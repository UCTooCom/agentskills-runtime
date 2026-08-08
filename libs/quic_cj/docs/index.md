# quic_cj 文档

**quic_cj** 是基于仓颉语言实现的 QUIC 传输协议（RFC 9000）。
本文档涵盖从入门到高级用法的全部内容。

## 目录

| 文档 | 说明 |
|----------|-------------|
| [快速入门](getting_started.md) | 安装、构建与第一步 |
| [API 参考](api_reference.md) | 完整 API 文档 |
| [架构设计](architecture.md) | 内部架构与模块设计 |
| [协议指南](protocol_guide.md) | QUIC 协议实现细节 |
| [配置指南](configuration.md) | 配置选项与最佳实践 |
| [测试指南](testing.md) | 运行与编写测试 |
| [性能调优](performance_tuning.md) | 性能优化与参数调整 |
| [故障排除](troubleshooting.md) | 常见问题与解决方案 |
| [FAQ](faq.md) | 常见问题解答 |

## 快速开始

```bash
# 添加到项目
cjpm add quic_cj

# 构建
cjpm build

# 运行测试
cjpm test
```

## 示例代码

完整的示例代码请参阅 [examples/](../examples/) 目录：
- [ack_handling](../examples/ack_handling/) — ACK 处理与丢包检测
- [basic_usage](../examples/basic_usage/) — QUIC 库基本使用模式
- [config_customization](../examples/config_customization/) — QUIC 配置定制
- [congestion_demo](../examples/congestion_demo/) — CUBIC 拥塞控制演示
- [connection_lifecycle](../examples/connection_lifecycle/) — 连接生命周期演示
- [echo_client](../examples/echo_client/) — QUIC 回显客户端
- [echo_server](../examples/echo_server/) — QUIC 回显服务器
- [error_handling](../examples/error_handling/) — 错误处理演示
- [flow_control](../examples/flow_control/) — 流量控制演示
- [packet_buffering](../examples/packet_buffering/) — 包缓冲与内存池
- [stream_multiplexing](../examples/stream_multiplexing/) — 流多路复用
- [tls_integration](../examples/tls_integration/) — TLS 1.3 集成
- [version_negotiation](../examples/version_negotiation/) — 版本协商

## 包信息

- **名称：** quic_cj
- **版本：** 0.1.0
- **测试：** 64 个测试文件，619 个测试用例，81 个基准测试
- **代码行数：** 源码 12395 行 / 测试 7192 行（36.7% 覆盖率）
- **输出：** 静态库
- **许可证：** Apache 2.0

## 依赖项

| 包 | 用途 |
|---------|---------|
| jinguissl_core | AES、ChaCha20、HKDF、X25519、TLS 1.3 |
| jinguissl | 加密操作契约层 |
| 仓颉标准库 | 集合、随机数、时间 |