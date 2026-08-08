package sample_basic_usage

/**
 * basic_usage.cj — 基本 QUIC 库使用模式
 *
 * 演示 quic_cj 库的核心 API 使用模式。
 * 涵盖配置、连接生命周期、流操作、
 * 以及错误处理。
 */

import quic_cj.*
import quic_cj.protocol.{VERSION_1, VERSION_2}

main(): Int64 {
    println("=== quic_cj Basic Usage Examples ===\n")

    // ── 1. 配置 ──
    println("── 1. Configuration ──")
    let cfg = defaultConfig()
    println("  Default versions: " + cfg.versions.size.toString())
    println("  Default idle timeout: " + cfg.maxIdleTimeoutMs.toString() + "ms")
    println("  Max incoming streams: " + cfg.maxIncomingStreams.toString())
    println("  Config valid: " + cfg.validate().toString())

    // 自定义配置
    let customCfg = Config()
    customCfg.versions = [VERSION_1]       // 仅 QUIC v1
    customCfg.maxIdleTimeoutMs = 120000    // 2 分钟空闲超时
    customCfg.handshakeIdleTimeoutMs = 10000  // 10 秒握手超时
    customCfg.maxIncomingStreams = 500
    customCfg.maxIncomingUniStreams = 500
    customCfg.initialPacketSize = 1200     // RFC 9000 规定的最小 MTU
    customCfg.serverName = "example.com"
    println("  Custom config valid: " + customCfg.validate().toString())

    // ── 2. 传输层 ──
    println("\n── 2. Transport ──")
    let transport = Transport("127.0.0.1:0", cfg)
    let listenerResult = transport.listen()
    if (let Some(listener) <- listenerResult) {
        println("  Listener ready on " + listener.addr())
    } else {
        println("  WARNING: Listen failed (expected in test environments)")
    }

    // ── 3. 客户端拨号 ──
    println("\n── 3. Client Dial ──")
    if (let Some(conn) <- dialAddr("127.0.0.1:4433", cfg)) {
        println("  Connected: local=" + conn.localAddr().toString() + " remote=" + conn.remoteAddr())
        let st = conn.getConnState()
        println("  State: handshakeComplete=" + st.handshakeComplete.toString())

        // ── 4. 流操作 ──
        println("\n── 4. Stream Operations ──")
        // 在连接上打开流
        if (let Some(s1) <- conn.openStream()) {
            println("  Opened bidirectional stream " + s1.getStreamId().toString())
            s1.write([0x61u8, 0x62u8, 0x63u8])  // "abc"
            println("  Wrote 3 bytes")
            s1.close()
        }

        if (let Some(us1) <- conn.openUniStream()) {
            println("  Opened unidirectional send stream")
        }

        // ── 6. 连接生命周期 ──
        println("\n── 6. Connection Lifecycle ──")
        conn.closeWithError(0u64, "demo complete")
        println("  Connection closed with NO_ERROR")
    } else {
        println("  Dial returned (expected if no server running)")
    }

    // ── 5. 错误处理 ──
    println("\n── 5. Error Handling ──")
    let transportErr = newTransportError(0x01u64, "internal error")
    println("  Transport error: code=" + transportErr.transportCode.toString() +
            " msg=" + transportErr.errorMessage +
            " isTransport=" + transportErr.isTransport.toString())

    let appErr = newApplicationError(0x100u64, "app error")
    println("  Application error: code=" + appErr.appCode.toString() +
            " msg=" + appErr.errorMessage +
            " isTransport=" + appErr.isTransport.toString())

    if (let Some(listener) <- listenerResult) {
        listener.close()
        println("  Listener closed")
    }

    println("\n=== Basic Usage Examples Complete ===")
    0
}
