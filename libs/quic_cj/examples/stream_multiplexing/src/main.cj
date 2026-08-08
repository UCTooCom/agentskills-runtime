package sample_stream_multiplexing

/**
 * stream_multiplexing.cj — QUIC 流多路复用演示
 *
 * 演示 QUIC 如何在单个连接上多路复用多个流。
 * 多个流可以并发打开，具有独立的收发通道。
 * 这是 QUIC 相对于 TCP 的核心优势之一：无队头阻塞（Head-of-Line Blocking）。
 */

import quic_cj.*

main(): Int64 {
    println("=== QUIC 流多路复用演示 ===\n")

    // 创建配置：使用默认参数，支持 QUIC v1 和 v2
    let cfg = defaultConfig()
    if (let Some(conn) <- dialAddr("127.0.0.1:4433", cfg)) {
        // 真实连接模式：演示多路复用能力
        println("已连接到 " + conn.remoteAddr())
        println()

        // 在单个连接上同时打开多个流
        if (let Some(s1) <- conn.openStream()) {
            if (let Some(s2) <- conn.openStream()) {
                // 流 1：发送 3 字节
                s1.write([0x41u8, 0x42u8, 0x43u8])  // "ABC"
                println("流 " + s1.getStreamId().toString() + " 已发送 3 字节")

                // 流 2：发送不同数据，与流 1 互不干扰
                s2.write([0x44u8, 0x45u8, 0x46u8])  // "DEF"
                println("流 " + s2.getStreamId().toString() + " 已发送 3 字节")

                // 关闭流
                s1.close()
                s2.close()
                println("\n所有流已关闭。多个流在单连接上独立传输，无队头阻塞。")
            }
        }

        // 关闭连接
        conn.closeWithError(0u64, "demo done")
        println("连接已关闭。")
    } else {
        // 无服务端时，展示 API 使用模式
        println("未检测到服务端，展示 QUIC 流 API 的基本用法：")
        println()
        println("  dial(addr)           → 建立 QUIC 连接")
        println("  conn.openStream()    → 打开双向流")
        println("  stream.write(data)   → 发送数据")
        println("  stream.read()        → 接收数据")
        println("  stream.close()       → 关闭流")
        println("  conn.closeWithError()→ 关闭连接")
        println()
        println("启动一个 QUIC 服务端后可获得完整演示。")
    }
    0
}
