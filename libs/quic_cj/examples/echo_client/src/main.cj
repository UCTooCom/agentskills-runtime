package sample_echo_client

/**
 * echo_client.cj — QUIC 回显客户端
 *
 * 连接回显服务器的 QUIC 客户端，
 * 发送数据并验证回显响应。
 *
 * 用法：
 *   cjpm run   （或集成到您的项目中）
 *
 * 此示例演示：
 *   - 拨号连接到远程 QUIC 服务器
 *   - 打开双向流
 *   - 写入和读取流数据
 *   - 错误处理和连接生命周期
 */

import quic_cj.*
import quic_cj.stream.Stream

main(): Int64 {
    println("=== QUIC Echo Client ===")

    // 创建配置
    let cfg = defaultConfig()
    cfg.serverName = "localhost"

    // 拨号连接到回显服务器
    if (let Some(conn) <- dialAddr("127.0.0.1:4433", cfg)) {
        println("Connected to " + conn.remoteAddr())

        // 获取连接状态
        let state = conn.getConnState()
        println("Version: " + state.version.toString())

        // 打开一个双向流
        if (let Some(stream) <- conn.openStream()) {
            println("Opened stream " + stream.getStreamId().toString())

            // 发送数据
            let payload: Array<Byte> = [0x48u8, 0x65u8, 0x6cu8, 0x6cu8, 0x6fu8]  // "Hello"
            let n = stream.write(payload)
            println("Sent " + n.toString() + " bytes")
            stream.close()  // 关闭发送方向

            // 读取回显响应
            let response = stream.read()
            println("Received " + response.size.toString() + " bytes back")

            // 验证回显
            if (response == payload) {
                println("SUCCESS: Echo verified!")
            } else {
                println("WARNING: Echo mismatch")
            }
        } else {
            println("ERROR: Failed to open stream")
            conn.closeWithError(0x01u64, "stream failed")
            return 1
        }

        // 关闭连接
        conn.closeWithError(0u64, "client done")
        println("Connection closed")
    } else {
        println("ERROR: Failed to dial 127.0.0.1:4433")
        return 1
    }
    0
}
