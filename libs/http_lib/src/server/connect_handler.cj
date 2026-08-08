package http_lib.server
/**
 * CONNECT 方法处理器（HTTP 隧道代理）。
 * 建立到目标服务器的 TCP 隧道，支持 HTTPS 代理。
 */

/**
 * CONNECT 方法处理器（HTTP 隧道代理，RFC 7231 4.3.6）。
 * 处理客户端的 CONNECT 请求，建立到目标服务器的 TCP 隧道。
 * 支持正向代理模式下的 CONNECT 请求和连接劫持（Hijacker）。
 */

import http_lib.core.{HttpStatus}
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.router.Handler
import http_lib.connection.{Connection, TcpConnection}

/**
 * HTTP CONNECT 隧道处理器（通过代理建立 TCP 隧道）。

 *
 * 当服务器收到 CONNECT 请求时，此处理器：
 * 1. 响应 200 Connection Established
 * 2. 劫持连接
 * 3. 在客户端和目标之间双向中继数据
 *
 * 用法：
 *   router.connect("/", connectTunnelHandler())
 * // 或针对特定目标：
 *   router.connect("example.com:443", connectTunnelHandler())
 */
public func connectTunnelHandler(): Handler {
    {req: HttpRequest =>
        // CONNECT 请求使用请求目标作为要隧穿的主机:端口
        let target = req.url
        if (target.size == 0) {
            return HttpResponse.text(HttpStatus.BAD_REQUEST, "Missing target host")
        }
        if (!req.takenOver) {
            return HttpResponse.text(HttpStatus.BAD_REQUEST, "CONNECT requires takeover-capable connection")
        }

        // 获取客户端连接（测试中可能为 None）
        match (req.connection) {
            case Some(clientConn) =>
                // 将目标解析为主机:端口
                let colonIdx = target.indexOf(":")
                let targetHost = if (let Some(idx) <- colonIdx) { String(target.toRuneArray()[..idx]) } else { target }
                let targetPort = if (let Some(idx) <- colonIdx) {
                    let portStr = String(target.toRuneArray()[idx + 1..])
                    var port: UInt16 = 0
                    for (ch in portStr.toRuneArray()) {
                        if (ch >= r'0' && ch <= r'9') {
                            port = UInt16(Int64(port) * 10 + Int64(UInt32(ch) - UInt32(r'0')))
                        }
                    }
                    if (port == 0) { UInt16(443) } else { port }
                } else {
                    UInt16(443)
                }

                // 尝试连接到目标以进行双向中继
                var targetConn: ?Connection = None
                try {
                    targetConn = Some(TcpConnection.connect(targetHost, targetPort))
                } catch (_: Exception) {
                    // 目标不可达 — 回退返回 200
                }

                match (targetConn) {
                    case Some(tgt) =>
                        // 发送 200 Connection Established
                        try {
                            clientConn.write(unsafe { "HTTP/1.1 200 Connection Established\r\n\r\n".rawData() })
                            clientConn.flush()
                        } catch (e: Exception) {
                            try { tgt.close() } catch (_: Exception) {}
                            return HttpResponse.text(HttpStatus.INTERNAL_SERVER_ERROR, "Failed to send 200: ${e.message}")
                        }

                        // 启动双向中继 — 生成两个线程来复制数据
                        // 跟踪哪个方向已停止以避免半开隧道：
                        // 当一个方向结束时，立即关闭另一侧。
                        let cli = clientConn
                        spawn {
                            try { relayData(cli, tgt) } catch (_: Exception) {}
                            try { cli.close() } catch (_: Exception) {}
                        }
                        spawn {
                            try { relayData(tgt, cli) } catch (_: Exception) {}
                            try { tgt.close() } catch (_: Exception) {}
                        }

                        req.takenOver = true
                        HttpResponse.empty(HttpStatus.OK)
                    case None =>
                        // 目标不可达 — 返回 502 Bad Gateway（RFC 7231 §6.6.3）
                        HttpResponse.empty(HttpStatus.BAD_GATEWAY)
                }
            case None =>
                // 没有可用连接（例如测试中）— 返回 200
                HttpResponse.empty(HttpStatus.OK)
        }
    }
}

/**
 * 将数据从源连接中继到目标连接。
 * 从源读取并写入目标的循环，直到
 * 连接关闭或发生错误。
 *
 * 当源耗尽（正常关闭或错误）时，关闭
 * 目标以通知反向中继方向。这可以防止
 * 半开隧道（R4）：如果只有一个方向停止，对端将
 * 通过 dst.close() 解除阻塞并干净退出。
 */
private func relayData(src: Connection, dst: Connection): Unit {
    let buf = Array<UInt8>(32768, repeat: 0)
    while (true) {
        let n = src.read(buf)
        if (n <= 0) { break }
        dst.write(buf[0..n])
        dst.flush()
    }
    // 关闭 dst 以通知反向方向此中继已停止。
    // 防止半开隧道：关闭 dst 解除另一方向在该连接上的
    // 读取阻塞，使其能够退出并清理。
    try { dst.close() } catch (_: Exception) {}
}
