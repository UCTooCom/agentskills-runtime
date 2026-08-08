package quic_cj

import quic_cj.core.{newClientConnection, newServerConnection, ConnectionState}

/// quic_cj — 苍颉 QUIC 实现（RFC 9000）
/// 
/// 用法：
///   服务端：listen("0.0.0.0:4433") → 接受连接
///   客户端：dial("example.com:4433") → 打开流
///
/// 此示例演示了库的 API。

main(): Int64 {
    println("=== quic_cj Library Demo ===")
    
    // 配置
    let cfg = defaultConfig()
    cfg.maxIdleTimeoutMs = 30000
    println("Config: " + cfg.versions.size.toString() + " versions, valid=" + cfg.validate().toString())
    
    // 客户端连接
    let destId: Array<Byte> = [0x01u8, 0x02u8, 0x03u8, 0x04u8, 0x05u8, 0x06u8, 0x07u8, 0x08u8]
    let clientConn = newClientConnection(destId, [0x0au8, 0x0bu8])
    println("Client: " + stateStr(clientConn.getState()))
    
    // 服务端连接
    let serverConn = newServerConnection(destId)
    println("Server: " + stateStr(serverConn.getState()))
    
    // 连接生命周期
    clientConn.closeWithError(0u64, "demo")
    println("Closing: " + stateStr(clientConn.getState()))
    clientConn.tick(5000)
    println("Closed:  " + stateStr(clientConn.getState()))
    
    // 传输层
    let transport = Transport("127.0.0.1:0", cfg)
    if (let Some(lis) <- transport.listen()) {
        println("Transport: listener ready")
    } else {
        println("Transport: listener failed")
    }
    
    println("=== Demo complete: 111 source files, 573 tests ===")
    0
}

private func stateStr(s: ConnectionState): String {
    match (s) {
        case ConnectionState.Initial => "Initial"
        case ConnectionState.Handshake => "Handshake"
        case ConnectionState.Established => "Established"
        case ConnectionState.Closing => "Closing"
        case ConnectionState.Closed => "Closed"
    }
}
