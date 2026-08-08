package http_lib.client
/**
 * MASQUE（多路复用 QUIC 流隧道）支持。
 * 在 HTTP/3 之上建立 UDP 代理隧道。
 */

/**
 * MASQUE（QUIC 隧道）支持，基于 HTTP/3 的 UDP/TCP 代理协议。
 * 提供符合 MASQUE 规范的 CONNECT-UDP 和 CONNECT-IP 方法，
 * 用于在 HTTP/3 连接上建立 UDP/TCP 隧道。
 * 参考：RFC 9298（CONNECT-UDP）和 RFC 9484（CONNECT-IP）。
 */
import http_lib.message.HttpRequest
import http_lib.http2.{buildDatagramCapsule, Capsule, CapsuleType, encodeCapsule, decodeCapsule}

import http_lib.core.{HttpMethod, HttpHeaders}

/**
 * RFC 9300 MASQUE（多路复用应用安全 QUIC 扩展）。
 *
 * MASQUE 定义了通过 HTTP 代理传输非 TCP 流量的机制。
 * 本实现提供 CONNECT-UDP 方法支持，允许客户端通过
 * HTTP 代理发送和接收 UDP 数据报。
 *
 * 核心概念：
 * - CONNECT-UDP：在 HTTP 流上建立 UDP 代理隧道
 * - 使用 Capsule Protocol (RFC 9298) 封装 UDP 数据报
 * - 在 HTTP/2 或 HTTP/3 上运行
 */

/**
 * MASQUE CONNECT-UDP 方法常量。
 * 在 HTTP 请求中使用 ":method" = "CONNECT-UDP"。
 */
public let MASQUE_METHOD_CONNECT_UDP = "CONNECT-UDP"

/**
 * MASQUE 上下文标识常量。
 */
public let MASQUE_DEFAULT_CONTEXT_ID: UInt64 = 0u64

/**
 * MASQUE UDP 代理的客户端上下文。
 * 管理与 HTTP 代理之间的 UDP 数据报隧道。
 */
public class MasqueUdpProxyClient {
    private var contextId: UInt64
    private var maxDatagramSize: Int64

    public init(contextId!: UInt64 = MASQUE_DEFAULT_CONTEXT_ID, maxDatagramSize!: Int64 = 1400) {
        this.contextId = contextId
        this.maxDatagramSize = maxDatagramSize
    }

    /**
     * 构建 CONNECT-UDP 请求。
     * RFC 9300 §3：CONNECT-UDP 请求使用 :method = CONNECT-UDP
     * 和 :authority = target_host:port。
     */
    public func buildConnectUdpRequest(targetHost: String, targetPort: UInt16): HttpRequest {
        let headers = HttpHeaders()
        // :protocol pseudo-header 由 H2 处理层添加
        // :method 由 H2 请求映射到 CONNECT-UDP
        // :authority 由 H2 请求映射
        // 请求路径包含目标 host:port
        let req = HttpRequest(
            method: HttpMethod.CONNECT,
            url: "${targetHost}:${targetPort}"
        )
        req.headers.set(":method", MASQUE_METHOD_CONNECT_UDP)
        req
    }

    /**
     * 将 UDP 数据报封装为 HTTP Datagram 胶囊。
     */
    public func encapsulateDatagram(datagram: Array<UInt8>): Array<UInt8> {
        let capsule = buildDatagramCapsule(datagram)
        encodeCapsule(capsule)
    }

    /**
     * 从胶囊中提取 UDP 数据报。
     */
    public func decapsulateDatagram(capsuleData: Array<UInt8>): ?Array<UInt8> {
        try {
            let capsule = decodeCapsule(capsuleData)
            if (capsule.capsuleType == CapsuleType.DATAGRAM) {
                Some(capsule.payload)
            } else if (capsule.capsuleType == CapsuleType.DATAGRAM_WITH_CONTEXT) {
                // 前 2 字节为上下文 ID，后续为数据报
                if (capsule.payload.size > 2) {
                    Some(capsule.payload[2..capsule.payload.size])
                } else { None }
            } else {
                None
            }
        } catch (_: Exception) { None }
    }
}
