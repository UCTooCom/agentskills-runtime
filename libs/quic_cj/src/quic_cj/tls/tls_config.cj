package quic_cj.tls

/// 保存 QUIC 连接的 TLS 配置。
public class TlsConfig {
    public var serverName: String = ""
    public var alpn: Array<String> = []
    public var 密码套件s: Array<UInt16> = DEFAULT_CIPHER_SUITES
    public var maxVersion: Int64 = 0 // 0 = TLS 1.3 默认值
    public var enableEarlyData: Bool = false
}

/// 返回具有合理默认值的 TLS 配置。
public func defaultTlsConfig(): TlsConfig {
    TlsConfig()
}
