package sample_config_customization

/**
 * config_customization.cj — QUIC 配置示例
 *
 * 展示 quic_cj 连接的各种配置选项。
 * 配置可以调整性能、兼容性和资源使用。
 */

import quic_cj.*
import quic_cj.protocol.{VERSION_1, VERSION_2}

main(): Int64 {
    println("=== QUIC Configuration Customization ===\n")

    // ── 最小配置 ──
    println("── Minimal Config ──")
    let minimal = Config()
    minimal.versions = [VERSION_1]
    minimal.maxIncomingStreams = 10
    println("  Versions: " + minimal.versions.size.toString())
    println("  Max streams: " + minimal.maxIncomingStreams.toString())

    // ── 性能调优配置 ──
    println("\n── Performance Config ──")
    let perf = defaultConfig()
    perf.initialPacketSize = 1450     // 接近以太网 MTU
    perf.initialStreamReceiveWindow = 1024 * 1024      // 初始窗口 1 MB
    perf.maxStreamReceiveWindow = 4 * 1024 * 1024      // 最大窗口 4 MB
    perf.initialConnectionReceiveWindow = 16 * 1024 * 1024   // 16 MB
    perf.maxConnectionReceiveWindow = 64 * 1024 * 1024      // 64 MB
    println("  Packet size: " + perf.initialPacketSize.toString())
    println("  Stream window: " + perf.initialStreamReceiveWindow.toString())
    println("  Connection window: " + perf.initialConnectionReceiveWindow.toString())

    // ── 低资源配置 ──
    println("\n── Low-Resource Config ──")
    let lite = Config()
    lite.maxIncomingStreams = 10
    lite.maxIncomingUniStreams = 10
    lite.initialStreamReceiveWindow = 65536      // 64 KB
    lite.maxStreamReceiveWindow = 262144         // 256 KB
    lite.initialConnectionReceiveWindow = 262144 // 256 KB
    lite.maxIdleTimeoutMs = 15000               // 15 秒超时
    println("  Low memory footprint configuration")
    println("  Valid: " + lite.validate().toString())

    // ── QUIC 版本选择 ──
    println("\n── Version Selection ──")
    let v1Only = Config()
    v1Only.versions = [VERSION_1]
    println("  QUIC v1 only: " + v1Only.validate().toString())

    let v2Only = Config()
    v2Only.versions = [VERSION_2]
    println("  QUIC v2 only: " + v2Only.validate().toString())

    let bothVersions = Config()
    bothVersions.versions = [VERSION_1, VERSION_2]
    println("  QUIC v1+v2: " + bothVersions.validate().toString())

    // ── 服务端特定配置 ──
    println("\n── Server Config ──")
    let serverCfg = defaultConfig()
    serverCfg.maxIncomingStreams = 10000
    serverCfg.maxIdleTimeoutMs = 300000  // 长连接为 5 分钟
    println("  Server with 10000 max streams, 5min idle timeout")

    println("\n=== Configuration Examples Complete ===")
    0
}
