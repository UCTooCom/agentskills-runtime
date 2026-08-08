package http_lib.core

import std.convert.Parsable

// ---------- 协议常量 ----------

public let CRLF = "\r\n"
/// 回车换行 CRLF 字节序列，用于 HTTP 行结束符。
public let CRLF_BYTES: Array<UInt8> = [b'\r', b'\n']
/// 双 CRLF 头部结束标记 (\r\n\r\n)，标示请求/响应头的结束。
public let HEADER_END_BYTES: Array<UInt8> = [b'\r', b'\n', b'\r', b'\n']
/// HTTP 版本前缀常量 "HTTP/"。
public let HTTP_VERSION_PREFIX = "HTTP/"
/// 空格字节，用于请求行和头部行中字段分隔。
public let SPACE_BYTE: UInt8 = b' '
/// 冒号字节，用于头部行中名称与值的分隔。
public let COLON_BYTE: UInt8 = b':'

// ---------- 默认超时（毫秒） ----------

/// 默认连接建立超时。
public let DEFAULT_CONNECT_TIMEOUT: Duration = Duration.second * 30
/// 默认读取超时。
public let DEFAULT_READ_TIMEOUT: Duration = Duration.second * 30
/// 默认写入超时。
public let DEFAULT_WRITE_TIMEOUT: Duration = Duration.second * 30


// ---------- HTTP 协议配置 ----------

/**
 * HttpProtocols 表示一组 HTTP 协议配置，控制服务器/客户端允许的协议。
 * 支持的协议：
 *   - HTTP/1.x：始终支持
 *   - HTTP/2 (h2)：基于 TLS 的 HTTP/2
 *   - Unencrypted HTTP/2 (h2c)：基于 TCP 的 HTTP/2
 */
public class HttpProtocols {
    private var http1Enabled: Bool = true
    private var http2Enabled: Bool = true
    private var unencryptedHttp2Enabled: Bool = false

    public init() {}
    public func isHttp1Enabled(): Bool { http1Enabled }
    public func isHttp2Enabled(): Bool { http2Enabled }
    public func isUnencryptedHttp2Enabled(): Bool { unencryptedHttp2Enabled }
    public func setHttp1(ok: Bool): Unit { http1Enabled = ok }
    public func setHttp2(ok: Bool): Unit { http2Enabled = ok }
    public func setUnencryptedHttp2(ok: Bool): Unit { unencryptedHttp2Enabled = ok }

    public static func all(): HttpProtocols {
        let p = HttpProtocols()
        p.setHttp1(true)
        p.setHttp2(true)
        p.setUnencryptedHttp2(false)
        p
    }
}

/**
 * Http2Config 提供 HTTP/2 的详细配置。
 * 对应 Go 标准库 Server.HTTP2 和 Transport.HTTP2 配置字段。
 */
public class Http2Config {
    public var enabled: Bool = true
    public var allowH2C: Bool = true
    public var maxConcurrentStreams: UInt32 = 100
    public var initialWindowSize: UInt32 = 65535
    public var maxFrameSize: UInt32 = 16384
    public var maxHeaderListSize: UInt32 = 0
    public var enablePush: Bool = false
    public var readIdleTimeout: Duration = Duration.second * 0
    public var pingTimeout: Duration = Duration.second * 15

    public init() {}
}
// ---------- 默认缓冲区大小 ----------

/// 默认缓冲区大小（8 KB），用于 I/O 操作中的临时缓冲区。
public let DEFAULT_BUFFER_SIZE: Int64 = 8192
/// 最大头部大小（64 KB），超过此大小视为恶意请求并断开连接。
public let MAX_HEADER_SIZE: Int64 = 65536
/// 单行最大长度（8 KB），用于限制请求行和头部行的长度。
public let MAX_LINE_LENGTH: Int64 = 8192

// ---------- 工具函数 ----------

/**
 * 使用 std.convert 将十进制字符串解析为 Int64。
 * 解析失败时抛出 ProtocolException，适合在 HTTP 解析上下文中使用。
 */
public func parseDecimal(s: String): Int64 {
    try {
        Int64.parse(s)
    } catch (_: Exception) {
        throw ProtocolException("无效的十进制数: ${s}")
    }
}

/**
 * 解析 Content-Length 响应头值。
 * 将头部字符串转换为 Int64 字节数。如果格式无效则抛出异常。
 */
public func parseContentLength(value: String): Int64 {
    try {
        Int64.parse(value)
    } catch (_: Exception) {
        throw ProtocolException("无效的 Content-Length: ${value}")
    }
}


/**
 * 连接状态枚举，用于 ConnState 回调跟踪连接生命周期。
 * 对应 Go 标准库的 ConnState (StateNew/StateActive/StateIdle/StateHijacked/StateClosed)。
 */
public enum ConnState {
    | STATE_NEW
    | STATE_ACTIVE
    | STATE_IDLE
    | STATE_HIJACKED
    | STATE_CLOSED
}
