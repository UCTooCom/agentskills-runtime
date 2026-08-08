package sample_http2_extended_connect

import http_lib.http2.{Http2Connection, establishWebSocketTunnel, H2WebSocketTunnel}
import http_lib.connection.{Connection, TcpConnection, TlsConfig, TlsConnection}
import http_lib.message.HttpRequest
import http_lib.core.{HttpMethod, HttpStatus, HttpVersion}

/**
 * WebSocket over HTTP/2 (RFC 8441 Extended CONNECT) 示例。
 *
 * 演示在 HTTP/2 流上建立 WebSocket 隧道的过程：
 * 1. 创建 TLS 连接并协商 HTTP/2
 * 2. 发送 CONNECT + :protocol=websocket 请求
 * 3. 通过隧道进行双向数据帧传输
 *
 * 注意：需要服务端支持 RFC 8441。
 * 实际运行时请将 targetHost 替换为目标主机。
 */
main() {
    let targetHost = "example.com"
    let targetPort: UInt16 = 443

    println("Connecting to ${targetHost}:${targetPort}...")

    // 建立 TCP + TLS 连接
    let tcpConn = TcpConnection.connect(targetHost, targetPort)
    let tlsConn = TlsConnection(tcpConn, targetHost)
    tlsConn.handshake()
    println("TLS handshake complete")

    // 建立 HTTP/2 连接
    let h2conn = Http2Connection(tlsConn, isServer: false)
    h2conn.connect()
    println("HTTP/2 connection established")

    // 建立扩展 CONNECT 隧道
    let tunnel = establishWebSocketTunnel(h2conn, targetHost, targetPort)
    println("WebSocket tunnel established over HTTP/2")

    // 通过隧道发送数据
    let msg = "Hello via HTTP/2 Extended CONNECT"
    tunnel.send(unsafe { msg.rawData() })
    println("Sent: ${msg}")

    // 接收响应
    let (data, closed) = tunnel.recv()
    if (data.size > 0) {
        let response = unsafe { String.withRawData(data) }
        println("Received: ${response}")
    }
    println("Tunnel closed: ${closed}")

    // 清理
    tunnel.close()
    h2conn.close()
}
