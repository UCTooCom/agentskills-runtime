# quic_cj 快速入门

## 安装

### 添加到项目

在 `cjpm.toml` 中将 `quic_cj` 添加为依赖：

```toml
[dependencies]
quic_cj = { git = "https://gitcode.com/changeden/quic_cj.git", output-type = "static" }
```

依赖项将自动传递解析：
- `jinguissl_core` — AES/ChaCha20/HKDF/X25519 原语
- `jinguissl` — 加密操作契约层

### 从源码构建

```bash
# 克隆并构建
git clone https://gitcode.com/changeden/quic_cj.git
cd quic_cj
cjpm build

# 运行所有测试
cjpm test
```

首次构建因编译依赖需要 30–60 秒。
增量构建约 3–8 秒。

## 第一个 QUIC 客户端

```cangjie
import quic_cj.*

main(): Int64 {
    // 默认配置
    let cfg = defaultConfig()

    // 拨号连接 QUIC 服务器
    let (conn, ok) = dial("example.com:4433", cfg)
    if (!ok) {
        println("连接失败")
        return 1
    }

    // 打开流并发送数据
    let (stream, ok2) = conn.openStream()
    if (ok2) {
        stream.write("Hello QUIC!".toArray())
        let response = stream.read()
        stream.close()
    }

    // 清理
    conn.closeWithError(0u64, "done")
    0
}
```

## 第一个 QUIC 服务器

```cangjie
import quic_cj.*

main(): Int64 {
    let cfg = defaultConfig()
    let transport = Transport("0.0.0.0:4433", cfg)
    let (listener, ok) = transport.listen()
    if (!ok) {
        println("监听失败")
        return 1
    }

    // 接受一个连接
    let (conn, ok2) = listener.accept()
    if (ok2) {
        let (stream, ok3) = conn.acceptStream()
        if (ok3) {
            let data = stream.read()
            stream.write(data)  // 回显
        }
    }

    listener.close()
    0
}
```

## 项目结构

src/quic_cj/
├── client.cj             dial() / dialAddr()
├── server.cj             listen() / listenAddr()
├── transport.cj          Transport 类（UDP 监听器、包路由）
├── config.cj             Config 和 defaultConfig()
├── error.cj              错误类型（QError / StreamError / CryptoError / ...）
├── interface.cj          Conn / Listener / ConnState 基类
├── zz_conn_impl.cj       Conn 实现（包装 core）
├── zz_listener_impl.cj   Listener 实现（接受真实网络连接）
│
├── protocol/             QUIC 协议常量和类型（版本、连接 ID、流 ID）
├── wire/                 线缆编码：变长整数、包头、25 种帧类型
├── tls/                  TLS 1.3 集成（AEAD、包头保护、HKDF、
│                          Stateless Reset、Token Generator、UpdatableAEAD）
├── ack/                  ACK 处理与丢包检测（已发送/已接收追踪、RTT）
├── congestion/           CUBIC + NewReno 拥塞控制（混合慢启动、Pacer）
├── flow/                 流量控制（逐流 + 逐连接窗口管理）
├── stream/               流状态机 / SendStream / ReceiveStream
├── core/                 连接状态机、packer/unpacker、Framer、帧调度、
│                          RetransmissionQueue、MTU Discoverer、Path Manager
├── sys/                  UDP 套接字抽象层（RawConn、Linux 真实实现、Stub）
├── qlog/                 QUIC 事件日志（RFC 9421 Tracer + Event 类型）
├── util/                 RTT 统计、环型缓冲区、传输错误码
 └── tests/                64 个测试文件，619 个测试用例，81 个基准测试
└── package.cj    根包标记
```

## 下一步

- 阅读 [API 参考](api_reference.md) 获取完整文档
- 浏览 [examples/](../examples/) 获取可运行的代码示例
- 查看 [配置指南](configuration.md) 了解调优选项
- 参阅 [测试指南](testing.md) 编写自有测试
