package http_lib.utils

/**
 * 解析后的 URL 组件。由客户端和传输模块共享。
 * 支持协议、主机、端口、路径提取以及可选的
 * 用于代理认证的用户/密码。
 */
public class ParsedUrl {
    public let scheme: String
    public let host: String
    public let port: UInt16
    public let path: String
    public let user: ?String
    public let password: ?String
    public let isSecure: Bool

    public init(scheme!: String, host!: String, port!: UInt16, path!: String, user!: ?String, password!: ?String, isSecure!: Bool) {
        this.scheme = scheme
        this.host = host
        this.port = port
        this.path = path
        this.user = user
        this.password = password
        this.isSecure = isSecure
    }

    /**
     * 将 URL 字符串解析为其组成部分。
     * 处理 http://、https:// 协议，支持可选的 user:password@。
     */
    public static func parse(raw: String): ParsedUrl {
        var remaining = raw
        var isSecure = false
        var scheme = "http"

        // 解析 scheme
        if (remaining.startsWith("https://")) {
            isSecure = true
            scheme = "https"
            remaining = remaining["https://".size..]
        } else if (remaining.startsWith("http://")) {
            remaining = remaining["http://".size..]
        }

        // 提取 user:password@（如果存在）
        var user: ?String = None
        var password: ?String = None
        let firstSlash = remaining.indexOf("/")
        let authorityEnd = if (let Some(idx) <- firstSlash) { idx } else { remaining.size }
        let authoritySection = remaining[..authorityEnd]
        let atIndex = authoritySection.indexOf("@")
        match (atIndex) {
            case Some(ai) =>
                let userInfo = authoritySection[..ai]
                let colonIdx = userInfo.indexOf(":")
                match (colonIdx) {
                    case Some(ci) =>
                        user = Some(userInfo[..ci])
                        password = Some(userInfo[ci + 1..])
                    case None =>
                        user = Some(userInfo)
                }
                // 去除用户信息后重建
                remaining = authoritySection[ai + 1..] + remaining[authorityEnd..]
            case None => ()
        }

        // 查找路径分隔符
        let slashIndex = remaining.indexOf("/")
        let hostPortPart = if (let Some(idx) <- slashIndex) { remaining[..idx] } else { remaining }
        let path = if (let Some(idx) <- slashIndex) { remaining[idx..] } else { "/" }

        // 解析主机和端口（RFC 3986 §3.2.2：方括号中的 IPv6 地址）
        var host: String = hostPortPart
        var port: UInt16 = if (isSecure) { UInt16(443) } else { UInt16(80) }

        // 检查 IPv6 字面量：[::1]:8080 或 [fe80::1]
        if (hostPortPart.startsWith("[")) {
            let closeBracket = hostPortPart.indexOf("]")
            match (closeBracket) {
                case Some(cb) =>
                    // 提取不含方括号的 IPv6 地址
                    host = hostPortPart[1..cb]
                    // 检查右括号后的端口：] :port
                    if (cb + 1 < hostPortPart.size && hostPortPart[cb + 1] == b':') {
                        let portStr = hostPortPart[cb + 2..]
                        port = parsePortFromString(portStr)
                    }
                case None =>
                    // 格式错误 —— 将整个部分视为主机
                    host = hostPortPart
            }
        } else {
            let colonIndex = hostPortPart.indexOf(":")
            host = if (let Some(idx) <- colonIndex) { hostPortPart[..idx] } else { hostPortPart }
            port = if (let Some(idx) <- colonIndex) {
                let portStr = hostPortPart[idx + 1..]
                parsePortFromString(portStr)
            } else {
                if (isSecure) { UInt16(443) } else { UInt16(80) }
            }
        }

        ParsedUrl(scheme: scheme, host: host, port: port, path: path,
            user: user, password: password, isSecure: isSecure)
    }

    /**
     * 从字符串（如 "8080"）中解析端口号。
     * 解析失败时抛出异常（调用方应使用默认端口）。
     */
    private static func parsePortFromString(s: String): UInt16 {
        let bytes = s.toArray()
        var p: UInt64 = 0
        for (b in bytes) {
            if (b >= b'0' && b <= b'9') {
                p = p * 10 + UInt64(b - b'0')
                if (p > 65535) {
                    throw Exception("端口超出范围: '${s}'")
                }
            } else {
                throw Exception("invalid port: '${s}'")
            }
        }
        UInt16(p)
    }
}
