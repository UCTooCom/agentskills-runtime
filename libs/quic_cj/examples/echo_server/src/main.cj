package sample_echo_server

/**
 * echo_server.cj — QUIC 回显服务器
 *
 * 一个简单的回显服务器，监听 QUIC 连接，
 * 接收流，读取数据并将其发送回去。
 *
 * 用法：
 *   cjpm run   （或集成到您的项目中）
 *
 * 此示例演示：
 *   - 使用配置创建传输层
 *   - 监听传入的 QUIC 连接
 *   - 接收双向流
 *   - 读取和写入流数据
 *   - 优雅地关闭连接
 */

import quic_cj.*
import quic_cj.stream.Stream

main(): Int64 {
    println("=== QUIC Echo Server ===")

    // 创建默认配置
    let cfg = defaultConfig()
    cfg.maxIdleTimeoutMs = 60000       // 60 秒空闲超时
    cfg.initialPacketSize = 1450       // MTU 友好的包大小
    cfg.maxIncomingStreams = 1000      // 支持最多 1000 个并发流

    // 创建传输层并开始监听
    let transport = Transport("0.0.0.0:4433", cfg)
    if (let Some(listener) <- transport.listen()) {
        println("Listening on " + listener.addr())

        // 接收循环
        var activeConns: Int64 = 0
        while (activeConns < 10) {
            if (let Some(conn) <- listener.accept()) {
                activeConns += 1
                println("Accepted connection #" + activeConns.toString() + " from " + conn.remoteAddr())

                // 在此连接上接收流
                var streamCount: Int64 = 0
                while (streamCount < 5) {
                    if (let Some(stream) <- conn.acceptStream()) {
                        streamCount += 1

                        // 回显：读取数据并写回
                        let data = stream.read()
                        if (data.size > 0) {
                            stream.write(data)
                            println("Echoed " + data.size.toString() + " bytes on stream " + streamCount.toString())
                        }
                        stream.close()
                    } else { break }
                }

                // 优雅地关闭连接
                conn.closeWithError(0u64, "server done")
                println("Connection #" + activeConns.toString() + " closed")
            } else {
                println("ERROR: Failed to accept connection")
                break
            }
        }

        listener.close()
        println("Server shutting down")
    } else {
        println("ERROR: Failed to listen on 0.0.0.0:4433")
        return 1
    }
    0
}
